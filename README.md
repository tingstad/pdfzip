# PDF + Zip

sed -n '/^```shell/,/^```$/{/^```/!p;}' <<"DOC" | /bin/sh -e

1. [Summary](#summary)
2. [About this document](#about-this-document)
3. [Introduction](#introduction)

## Summary

Proof of Concept of a PDF file containing an image, which is also contained as a ZIP entry (not duplicated).
The file is 100% valid PDF _and_ ZIP file.

## About this document

This file explains how the zip/pdf file is created, and it is also an attempt at Literate Programming.

You are reading a Markdown document that is also a Shell script (hence the strange line at the beginning). It can be run like:

```
sh README.md
```

<details><summary>It is a valid script without a shebang line.</summary><p>

POSIX [specifies](https://pubs.opengroup.org/onlinepubs/9699919799/functions/execl.html):

> In the cases [...] [ENOEXEC], the execlp() and execvp() functions shall execute a command interpreter and the environment of the executed command shall be as if the process invoked the [sh](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sh.html) utility
>
> [ENOEXEC]: The new process image file has the appropriate access permission but has an unrecognized format.
</p></details>

## Introduction


## Minimal ZIP header

Even though the file is valid, some applications struggle with opening the ZIP when the first bytes are not `PK`. Can we improve the situation?

The PDF 1.7 [specification][2] states that:

> The first line of a PDF file shall be a header consisting of the 5 characters %PDF– followed by a version number

That does not leave much wiggle room. The spec for 1.5, however, says:

> The first line of a PDF file is a header identifying the version of the PDF specification to which the file conforms. For a file conforming to PDF version 1.5, the header should be
>
> `%PDF−1.5`
>
> [...] (See also implementation notes 13 and 14 in Appendix H.) [...]
>
> 13. Acrobat viewers require only that the header appear somewhere within the first 1024 bytes of the file.

Let's try to construct a minimal ZIP header. The [ZIP File Format Specification][1] defines:

```
   4.3.7  Local file header:

      local file header signature     4 bytes  (0x04034b50)
      version needed to extract       2 bytes
      general purpose bit flag        2 bytes
      compression method              2 bytes
      last mod file time              2 bytes
      last mod file date              2 bytes
      crc-32                          4 bytes
      compressed size                 4 bytes
      uncompressed size               4 bytes
      file name length                2 bytes
      extra field length              2 bytes

      file name (variable size)
      extra field (variable size)
```

We need to write bytes to a file. My understanding is that `\u`,`\x` are less portable than `printf`'s `\ddd` (octal) ([ref.](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/printf.html#tag_20_94_13)).

```shell
write() {
    for arg; do
        hex=$(printf $arg | tr '[:lower:]' '[:upper:]')
        oct=$(echo "ibase=16; obase=8; $hex" | bc)
        printf \\$oct
    done
}
create_zip_header() {
    # little-endian byte order:
    write  50 4b 03 04  # signature 'PK\03\04'
    write  0b           # version, avoiding 0a (Line Feed), so v=1.1 not 1.0
    write  00           # version upper byte, 0=MS-DOS and OS/2 compatible
    write  00 00 00 00  # compression method 0=uncompressed
    write  50 57 13 55  # last mod file time/date
    write  a8 69 91 77  # crc-32
    write  09 00 00 00 09 00 00 00 # compressed/uncompressed size
    write  01 00        # file name length
    write  00 00        # extra field length
    write  78           # file name, 78=x
    write  25 50 44 46 2d 31 2e 31 0a  # file data: %PDF-1.1\n
    #       %  P  D  F  -  1  .  1 \n
}
create_zip_header > header.zip
```

That's it, a valid ZIP file header in 40 bytes (including `%PDF-1.1` data). It's not a valid zip _file_ without a Central directory, but it's a valid header.

## Construct xref table

The PDF 1.7 [specification][2] says:

> The cross-reference table contains information that permits random access to indirect objects within the file [...]
>
> The table shall contain a one-line entry for each indirect object, specifying the byte offset of that object within the body of the file. [...]
>
> Each cross-reference section shall begin with a line containing the keyword **xref**.
> Following this line shall be one or more _cross-reference subsections_ [...]. For a file that has never been incrementally updated, the cross-reference section shall contain only one subsection, whose object numbering begins at 0. [...]
>
> The subsection shall begin with a line containing two numbers separated by a SPACE (20h), denoting the object number of the first object in this subsection and the number of entries in the subsection. [...]
>
> Following this line are the cross-reference entries themselves

```shell
xref_table() { pdf="$1"; cat <<-EOF
	xref
	0 $(number_of_entries "$pdf")
	$(xref_entries "$pdf")
EOF
}
```

> There are two kinds of cross-reference entries: one for objects that are in use and another for objects that have been deleted and therefore are free. [...] The first entry in the table (object number 0) shall always be free

```shell
number_of_entries() {
    strings "$1" \
    | sed 's/%.*//; #remove comments' \
    | LC_CTYPE=POSIX grep -oE "$pdf_obj_pattern" \
    | wc -l \
    | awk '{ print $1 + 1 }' # add 1 for free obj 0
} # this is an approximation
pdf_obj_pattern='(^|[[:space:]])[0-9]+[[:space:]]+0[[:space:]]+obj($|[[:space:]])'
```
This `number_of_entries` will not work for every PDF. The Locale [POSIX](https://pubs.opengroup.org/onlinepubs/009695399/basedefs/xbd_chap07.html#tag_07_03_01) specifies exactly all PDF's whitespace characters (but could contain more). (`grep` assumes `obj`s not across lines.)

To finish the table:
> the cross-reference entries themselves, one per line. Each entry shall be exactly 20
bytes long, including the end-of-line marker. [...]
>
> The byte offset in the decoded stream shall be a 10-digit number, padded with leading zeros if necessary, giving the number of bytes from the beginning of the file to the beginning of the object. It shall be separated from the generation number by a single SPACE. The generation number shall be a 5-digit number, also padded with leading zeros if necessary. Following the generation number shall be a single SPACE, the keyword **n**, and a 2-character end-of-line sequence consisting of one of the following: SP CR, SP LF, or CR LF. [...]
>
> (object number 0) shall always be free and shall have a generation number
of 65,535
```shell
xref_entries() { file="$1"
    printf '0000000000 65535 f \n'
    number_of_objs=$(( $(number_of_entries "$file") - 1 ))
    for i in $(seq 1 $number_of_objs); do
        printf "%010d 00000 n \n" $(obj_offset $i "$file")
    done
}
obj_offset() { i=$1 pdf="$2"
    # Another approximation. Not POSIX!
    grep -m1 --byte-offset --only-matching --text "^$i 0 obj" "$pdf" | cut -d: -f1
}
xref_table magic.zip.pdf
```

## PDF trailer

The file trailer can be pretty short:

```shell
# assuming object '1' is root
pdf_trailer() { cat <<-EOF
	trailer << /Root 1 0 R /Size $(number_of_entries "$pdf") >>
	startxref
	$(offset_xref)
	%%EOF
EOF
}
```

```shell
pdf=magic.zip.pdf
offset_xref() { # assume only one xref
    < "$pdf" od                               \
      -v          `# write all input data`    \
      -A n        `# no input address`        \
      -t x1       `# output type hex size 1`  \
    | tr ' ' '\n' `# max 1 hex byte per line` \
    | grep .      `# no empty lines/records`  \
    | awk '
        /0a/ && m != 5 { m=1; next; }  # \n
        /78/ && m == 1 { m++; next; }  # x
        /72/ && m == 2 { m++; next; }  # r
        /65/ && m == 3 { m++; next; }  # e
        /66/ && m == 4 { m++; next; }  # f
        /0a/ && m == 5 {               # \n
            print NR - 5; exit
        }
        { m = 0 }'
}

pdf_trailer

cp header.zip test.pdf
dd bs=1 if=begin.pdf skip=9 >> test.pdf
rm -f end.zip
zip -0 end.zip magic.jpg
dd if=end.zip >> test.pdf
zip -A test.pdf

< test.pdf > test2.pdf ./bytes.sh $(
    #                 L  e  n  g  t  h     5  7  6  7  3  2    /increased because of PK after End of Image (FF D9)   TODO: remove Data descriptor?
    printf '_%s=%s ' 4c_65_6e_67_74_68_20_35_37_36_37_33_32_0a \
                     4c_65_6e_67_74_68_20_35_37_36_38_33_33_0a

    #                \n  >  > \n  s  t  r  e  a  m
    printf '_%s=%s ' 0a_3e_3e_0a_73_74_72_65_61_6d \
                     0a_25_3e_0a_25_74_72_65_61_6d
    #                \n  %  > \n  %  t  r  e  a  m

    # avoid newline: minimum required version 0a->0b   TODO should match ver. in central dir
    #                 P  K 03 04 10  0
    printf '_%s=%s ' 50_4b_03_04_0a_00 \
                     50_4b_03_04_0b_00 # 10=1.0 -> 11=1.1

    # replace extra fields with our own, 0x6375 ("uc"), unicode file comment:
    # "If the CRC check fails, this Unicode Comment extra field SHOULD be ignored and the File Comment field in the header SHOULD be used instead."
    # TODO: add file comment (central dir file header) as fallback?
    #                 U T len=9 (timestamp)                  u x  11 (unix uid/gid)
    printf '_%s=%s ' 55_54_09_00_xx_xx_xx_xx_xx_xx_xx_xx_xx_75_78_0b_00_xx_xx_xx_xx_xx_xx_xx_xx_xx_xx_xx \
                     75_63_18_00_01_01_f0_9c_61_20_20_20_20_20_20_20_20_0a_3e_3e_0a_73_74_72_65_61_6d_0a
    #                 u c  24    v. CRC32 CHK bla bla bla               \n  > >  \n  s  t  r  e  a  m \n
)

echo "" > tail.txt
echo endstream >> tail.txt
echo endobj >> tail.txt

pdf=test2.pdf
xref_table test2.pdf >> tail.txt

offset_xref() {
    wc -c test2.pdf | awk '{
        print $1 + 1 + 10 + 7
    }'
}

pdf=test2.pdf
pdf_trailer >> tail.txt

tr '\n' '=' < tail.txt > tail2.txt
cp test2.pdf test2.zip
zip -z test2.zip < tail2.txt

#< test2.zip > test3.zip ./bytes.sh

echo done

```

## Work in Progress

## Appendix


```
00000410: 6e 74 20 38 0a 3e 3e 0a 73 74 72 65 61 6d 50 4b  nt 8.>>.streamPK
00000420: 03 04 0a 00 00 00 00 00 f5 75 77 53 71 1c b3 47  .........uwSq..G
00000430: dc cc 08 00 dc cc 08 00 09 00 1c 00 6d 61 67 69  ............magi
                                        28 0  m  a  g  i <= 28 bytes long extra field length
00000440: 63 2e 6a 70 67 55 54 09 00 03 fd f0 9c 61 5f c2  c.jpgUT......a_.
           c  .  j  p  g  U  T  LEN  (1 2  3  4  5  6  7   UT/5455=extended timestamp
                          1  2  3  4  5  6  7  8  9 10 11
 extrafield8..9)  ID, len=0b=11  => "Unix UID/GID"
00000450: a0 61 75 78 0b 00 01 04 f5 01 00 00 04 14 00 00  .aux............
          12 13........................................27
00000460: 00 ff d8 ff e0 00 10 4a 46 49 46 00 01 01 00 00  .......JFIF.....
          28 DATA-JPEG-IMAGE... J  F  I  F
```


```
the following structure MUST be used for all
   programs storing data in this field:

       header1+data1 + header2+data2 . . .

   Each header MUST consist of:

       Header ID - 2 bytes
       Data Size - 2 bytes

   Note: all fields stored in Intel low-byte/high-byte order.
```

https://www.artpol-software.com/ZipArchive/KB/0610242300.aspx
https://www.pdfa.org/norm-refs/5116.DCT_Filter.pdf
https://users.cs.jmu.edu/buchhofp/forensics/formats/pkzip.html
https://en.wikipedia.org/wiki/JPEG_File_Interchange_Format#File_format_structure
https://www.fileformat.info/format/zip/corion.htm
https://pubs.opengroup.org/onlinepubs/9699919799/utilities/od.html
https://opensource.apple.com/source/zip/zip-6/unzip/unzip/proginfo/extra.fld
https://commons.apache.org/proper/commons-compress/apidocs/org/apache/commons/compress/archivers/zip/X5455_ExtendedTimestamp.html
https://blog.didierstevens.com/2008/04/29/pdf-let-me-count-the-ways/
https://libzip.org/specifications/extrafld.txt
https://www.w3.org/Graphics/JPEG/jfif3.pdf
https://www.verypdf.com/document/pdf-format-reference/index.htm
http://benno.id.au/refs/PDFReference15_v5.pdf

[1]: https://pkware.cachefly.net/webdocs/APPNOTE/APPNOTE-6.3.9.TXT
[2]: https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf

"DOC"

