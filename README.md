# PDF + Zip

sed -n '/^```shell/,/^```$/{/^```/!p;}' <<"DOC" | /bin/sh -e

1. [Summary](#summary)
2. [About this document](#about-this-document)
3. [Introduction](#introduction)
4. [Overview](#overview)
5. [Beginning](#beginning)
6. [Second half](#second-half)
7. [Construct xref table](#construct-xref-table)
8. [PDF trailer](#pdf-trailer)
9. [Correcting bytes](#correcting-bytes)
10. [Validate file](#validate-file)
11. [Minimal ZIP header](#minimal-zip-header)
12. [Conclusion](#conclusion)

## Summary

Proof of Concept of a PDF file containing an image, which is also contained as a ZIP entry (not duplicated).
The file is 100% valid PDF _and_ ZIP file.

* [magic1.zip.pdf](https://github.com/tingstad/pdfzip/raw/master/magic1.zip.pdf)
* [magic0.zip.pdf](https://github.com/tingstad/pdfzip/raw/master/magic0.zip.pdf) <sub>(no initial zip bytes, not all applications detect zip format)</sub>

## About this document

This file explains how the zip/pdf file is created, and it is also an attempt at Literate Programming.

You are reading a Markdown document that is also a Shell script (hence the strange line at the beginning). It can be run like:

```
sh README.md
```

<details><summary> It is a valid script without a shebang line. </summary><p>

POSIX [specifies](https://pubs.opengroup.org/onlinepubs/9699919799/functions/execl.html):

> In the cases [...] [ENOEXEC], the execlp() and execvp() functions shall execute a command interpreter and the environment of the executed command shall be as if the process invoked the [sh](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sh.html) utility
>
> [ENOEXEC]: The new process image file has the appropriate access permission but has an unrecognized format.
</p></details>

This approach fits this project nicely because there's a lot of documentation relavant for different parts of the code.
Keeping it all intermixed makes it easily available and up to date.
This helps myself as much as others.
Written text is plausibly _the_ best way of preserving and sharing knowledge.

The document lives at https://github.com/tingstad/pdfzip

## Introduction

When learning about the [PDF][2] format, I noticed this standard stream object filter:

> **DCTDecode**   Decompresses data encoded using a DCT (discrete cosine transform) technique based on the JPEG standard

<details><summary> It references another document that explains the filter's support of JFIF. </summary><p>

> The DCTDecode filter decodes grayscale or colour image data that has been encoded in the JPEG baseline format. See Adobe Technical Note #5116 for additional information about the use of JPEG “markers.”
>
>—[Portable Document Format 1.7 specification][2]

> A JPEG Interchange Format compressed image begins with an SOI (start-of-image)
marker followed by a number of marker segments that define
compressed image parameters. This is followed by the coded body of the
compressed image and, finally, by an EOI (end-of-image) marker. [...]
>
> It [DCTDecode] will decode any file produced by the DCTEncode filter. [...]
>
> An important application of the DCTEncode Markers string is to include a
JFIF marker in a DCT encoded image; a JFIF marker is a JPEG APP0 marker
>
>—[Technical Note 5116](https://www.pdfa.org/norm-refs/5116.DCT_Filter.pdf)
</p></details>

So embedding a normal [JFIF](https://www.w3.org/Graphics/JPEG/jfif3.pdf) JPEG file in the object stream should just work!

I knew a bit about ZIP files already, including their ability to "merge" with other file formats, and wondered if I could get both file formats to reference the same JPG file.
Is this extremely useful? Probably not, but it's interesting.

It turns out this project relates to several of my interests:

1. Standalone/self-contained formats ([example](https://observablehq.com/@tingstad/data-url))
2. Shell programming ([example](https://github.com/tingstad/nyancat))
3. Polyglot files ([example](https://github.com/tingstad/polyscript))
4. Executable documentation

<details><summary> Aren't these techs outdated; PDF(1993), ZIP(1989), Bourne Shell(1979)? No... </summary><p>

First: Even outdated tech can be educational.

Second: Old ≠ obsolete.

In fact, in some cases the opposite is true; this is known as _Lindy's Law_ ([wikipedia](https://en.wikipedia.org/wiki/Lindy_effect)) which proposes that:

> the future life expectancy of some non-perishable things, like a technology or an idea, is proportional to their current age

The three mentioned technologies have been remarkable successfull, are still widely used, and will probably be supported for many years to come.

It can be said that:

> In software, the best way to *future*-proof is to *past*-proof.
>
> —[Chris Wellons](https://nullprogram.com/blog/2018/04/13/), software engineer

By *coding agains the standards* and keeping dependencies to a minimum, this project could actually survive bit-rot for a very long time.
I guess I could have performed this experiment in the 1990s, which almost makes me a bit nostalgic :)

</p></details>

## Overview

The [PDF][2] and [ZIP][1] file formats laid out side-by-side:

```
    PDF                        ZIP
    ┌───────────────────┐      ┌───────────────────┐
    │      Header       │      │     Preamble      │
    ├───────────────────┤      │                   │
    │       Body        │      │                   │
    │            obj 1  │<╮    │                   │
    │                   │ │    ├───────────────────┤
    │            obj n  │<┤    │  File header i    │<╮
    │                   │ │    │  File data        │ │
    │                   │ │    ├───────────────────┤ │
    │                   │ │    │ Central directory │─╯
    │                   │ │    ├───────────────────┤
    ├───────────────────┤ │    │                   │
  ╭>│  Cross-reference  │ │    │  Archive comment  │
  │ │      table        │─╯    │                   │
  │ ├───────────────────┤      │                   │
  ╰─│      Trailer      │      │                   │
    └───────────────────┘      └───────────────────┘
```

This also displays how I plan to combine the two: the file starts with the beginning of the PDF, the ZIP headers will reside inside the PDF body, and the final PDF parts are contained in the ZIP archive comment.

<details><summary> Much of the work will be performed by simple shell commands. </summary><p>

This project a good example of what initially starts out as a couple of manual shell commands, and ends up as a fully automated script.

> Semi-automation is how you gradually achieve automation.
>
> [Oilshell blog — Shell: The Good Parts](http://www.oilshell.org/blog/2020/02/good-parts-sketch.html#semi-automation-with-runsh-scripts)

> Shell scripts are a unique form executable documentation. No other mechanism reflects **exactly** what you're supposed to type on the command line!
>
> [Oilshell blog — Shell Scripts Are Executable Documentation](http://www.oilshell.org/blog/2021/01/shell-doc.html)

Even if small or large parts of the code end up in other programming languages, I often *start out* in the shell.
The shell is *"the glue language"*. The shell treats other languages and processes as "first class".

</p></details>

## Beginning

<details><summary> 1st_half.pdf </summary><p>

```shell
trim_last_newline() {
    awk 'NR>1{print s} {s=$0} END{printf(s)}'
}
cat <<FIRSTHALF | trim_last_newline > 1st_half.pdf
%PDF-1.3
%$(printf '\253\266\245\261\277\273')
1 0 obj
  << /Type /Catalog
     /Pages 2 0 R
  >>
endobj

2 0 obj
  << /Type /Pages
     /Kids [3 0 R]
     /Count 1
     /MediaBox [0 0 595 842]
  >>
endobj

3 0 obj
  <<  /Type /Page
      /Parent 2 0 R
      /Resources
       << /Font
           << /F1
               << /Type /Font
                  /Subtype /Type1
                  /BaseFont /Times-Roman
               >>
           >>
           /XObject <</I1 5 0 R>>
       >>
      /Contents 4 0 R
      /Annots [
         << /Type /Annot
            /Subtype /Link
            /Rect [ 90 482 295 506 ]
            /A <<
                /S /URI
                /URI (https://github.com/tingstad/pdfzip)
            >>
         >> ]
  >>
endobj

4 0 obj
  << /Length 671 >>
stream
  BT
    /F1 14 Tf
    95 610 Td
    30 TL
    0.12549 0.129412 0.133333 rg
    (Hello, World!) Tj
    (This file is both a valid PDF and ZIP file, with common content.) '
    (Rename the file extension to .ZIP and see what lies inside.) '
    (For more details, see:) '
    0.2 0.4 0.8 rg
    (https://github.com/tingstad/pdfzip) '
    0.12549 0.129412 0.133333 rg
    (Best regards,) '
    (Richard H. Tingstad) '
  ET
  q
    600 0 0 600 -200 100 cm
    0.7 0 1.0 0.45 re
    W
    n
    /I1 Do
  Q
  q
    -400 0 0 400 360 300 cm
    0.767698 0.640812 -0.640812 0.767698 0 0 cm
    0.3 0.8 m
    0.7 0.5  0.7 1 y
    0.2 1  0.3 0.8 y
    h
    W
    n
    /I1 Do
  Q
endstream
endobj

5 0 obj
<<
/Name /I1
/Type /XObject
/Subtype /Image
/Width 1838
/Height 2738
/Length 336070
/Filter /DCTDecode
/ColorSpace /DeviceRGB
/BitsPerComponent 8
>>
stream
FIRSTHALF
```

</p></details>

```shell
# 1. Store jpg file in zip:
printf 'curious' > comment.txt
zip -c -0 image.zip magic.jpg < comment.txt

# 2. Prepend 1st_half.pdf to zip:
cat 1st_half.pdf image.zip > magic.zip

# 3. Adjust zip entry offsets after prepending data:
zip -A magic.zip

# Next up:
# 4. Append "2nd_half.pdf"
# 5. Mutate specific bytes to fix errors
```
We now have a valid ZIP file, but the PDF is both incomplete and invalid.

## Second half

First we need to finish the body part of the PDF:

```shell
end_body() {
    echo ""
    echo "endstream"
    echo "endobj"
}
end_body > 2nd_half.pdf
```

Then we need to add an xref table and a trailer.

## Construct xref table

<details><summary> The PDF spec describes the table as: </summary><p>

> The cross-reference table contains information that permits random access to indirect objects within the file [...]
>
> The table shall contain a one-line entry for each indirect object, specifying the byte offset of that object within the body of the file. [...]
>
> Each cross-reference section shall begin with a line containing the keyword **xref**.
> Following this line shall be one or more _cross-reference subsections_ [...]. For a file that has never been incrementally updated, the cross-reference section shall contain only one subsection, whose object numbering begins at 0. [...]
>
> The subsection shall begin with a line containing two numbers separated by a SPACE (20h), denoting the object number of the first object in this subsection and the number of entries in the subsection. [...]
>
> Following this line are the cross-reference entries themselves [...]
>
> There are two kinds of cross-reference entries: one for objects that are in use and another for objects that have been deleted and therefore are free. [...] The first entry in the table (object number 0) shall always be free
>
>— [PDF 1.7 specification][2]
</p></details>

```shell
xref_table() { pdf="$1"; cat <<-EOF
	xref
	0 $(number_of_entries "$pdf")
	$(xref_entries "$pdf")
EOF
}
```

I implement these somewhat sloppily:

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
<details><summary>(Note)</summary><p>

This `number_of_entries` will not work for every PDF. The Locale [POSIX](https://pubs.opengroup.org/onlinepubs/009695399/basedefs/xbd_chap07.html#tag_07_03_01) specifies exactly all PDF's whitespace characters (but could contain more). `grep` assumes `obj`s not across lines.
</p></details>

<details><summary>To finish the table:</summary><p>

> the cross-reference entries themselves, one per line. Each entry shall be exactly 20
bytes long, including the end-of-line marker. [...]
>
> The byte offset in the decoded stream shall be a 10-digit number, padded with leading zeros if necessary, giving the number of bytes from the beginning of the file to the beginning of the object. It shall be separated from the generation number by a single SPACE. The generation number shall be a 5-digit number, also padded with leading zeros if necessary. Following the generation number shall be a single SPACE, the keyword **n**, and a 2-character end-of-line sequence consisting of one of the following: SP CR, SP LF, or CR LF. [...]
>
> (object number 0) shall always be free and shall have a generation number of 65,535
</p></details>

```shell
xref_entries() { pdf="$1"
    printf '0000000000 65535 f \n'
    number_of_objs=$(( $(number_of_entries "$pdf") - 1 ))
    for i in $(seq 1 $number_of_objs); do
        printf "%010d 00000 n \n" $(obj_offset $i "$pdf")
    done
}
obj_offset() { i=$1 pdf="$2"
    # Another approximation. Not POSIX!
    grep -m1 --byte-offset --only-matching --text "^$i 0 obj" "$pdf" | cut -d: -f1
}
```

We are going to need the byte offset address to `xref`, which we can conveniently get now, before appending the rest:

```shell
tr '\n' '=' < 2nd_half.pdf > comment.txt # to avoid \n -> \r\n
zip -z magic.zip < comment.txt
xref_offset=$(wc -c magic.zip | awk '{ print $1 }')
```

The offset should not change with a new comment, because of fixed size ([spec][1]):

```
        file comment length             2 bytes
```

Now, the table can be added, and we only miss the trailer:

```shell
xref_table magic.zip >> 2nd_half.pdf
```

## PDF trailer

The file trailer can be pretty short:

```shell
size=$(number_of_entries magic.zip)

pdf_trailer() {
    cat <<-TRAILER
	trailer << /Root 1 0 R /Size ${size} >>
	startxref
	${xref_offset}
	%%EOF
TRAILER
}
pdf_trailer >> 2nd_half.pdf

# add the final data to the file:
add_archive_comment() { file="$1"
    tr '\n' '=' > comment.txt
    zip -z "$file" < comment.txt

    # replace '=' (3d) back to \n (0a):
    len=$(wc -c comment.txt | awk '{ print $1 }')
    total=$(wc -c "$file" | awk '{ print $1 }')
    xxd -c 1 "$file" | awk -v line=$((total-len)) '{ if (NR>=line) sub(": 3d",": 0a"); print }' \
    | xxd -c 1 -r > tmp && mv tmp "$file"
}
add_archive_comment <2nd_half.pdf magic.zip
```

All the data has now been added. The file is valid ZIP, but not yet completely valid PDF.

## Correcting bytes

The PDF can't display the image, which is not so strange, the contents now look like this:

```
/Length 336070
/Filter /DCTDecode
/ColorSpace /DeviceRGB
/BitsPerComponent 8
>>
streamPK^C^D
^@^@^@^@^@sI<82.Sq^\³GÜÌ^H^@ÜÌ^H^@>·^@^\^@magic.jpgUT>··^@[...]JFIF
```

These `PK..` zip header bytes have to be hidden from the PDF data. Relavant parts from the PDF [spec][2] are:

> Any occurrence of the PERCENT SIGN (25h) outside a string or stream introduces a comment. The comment
> consists of all characters after the PERCENT SIGN and up to but not including the end of the line [...]
> A conforming reader shall ignore comments, and treat them as single white-space characters.

> The keyword **stream** that follows the stream dictionary shall be followed by an end-of-line marker

<details><summary> End-of-line is a linefeed character (or CR, or CRLF). </summary><p>

> The CARRIAGE RETURN (0Dh) and LINE FEED (0Ah) characters, also called newline characters, shall be
> treated as end-of-line (EOL) markers. The combination of a CARRIAGE RETURN followed immediately by a
> LINE FEED shall be treated as one EOL marker. EOL markers may be treated the same as any other white-
> space characters. However, sometimes an EOL marker is required or recommended—that is, preceding a
> token that must appear at the beginning of a line.
</p></details>

Just as the ZIP central directory conveniently ends with a "free form" text field (archive comment),
so does the Local file header (extra field) ([spec][1]):

```
      local file header signature     4 bytes  (0x04034b50)
      version needed to extract       2 bytes
      [...                           20 bytes]
      file name length                2 bytes
      extra field length              2 bytes

      file name (variable size)
      extra field (variable size)
```
The extra field is described as:
```
       header1+data1 + header2+data2 . . .

   Each header MUST consist of:

       Header ID - 2 bytes
       Data Size - 2 bytes
```

We currently have the following data (annotated):

```
00000400: 0a 2f 42 69 74 73 50 65 72 43 6f 6d 70 6f 6e 65  ./BitsPerCompone
00000410: 6e 74 20 38 0a 3e 3e 0a 73 74 72 65 61 6d 50 4b  nt 8.>>.streamPK
00000420: 03 04 0a 00 00 00 00 00 f5 75 77 53 71 1c b3 47  .........uwSq..G
00000430: dc cc 08 00 dc cc 08 00 09 00 1c 00 6d 61 67 69  ............magi
                   filename length-^    28 0  m  a  g  i  <= extra field length = 28
00000440: 63 2e 6a 70 67 55 54 09 00 03 fd f0 9c 61 5f c2  c.jpgUT......a_.
           c  .  j  p  g  U  T  LEN  (1 2  3  4  5  6  7
00000450: a0 61 75 78 0b 00 01 04 f5 01 00 00 04 14 00 00  .aux............
         ..8 9)  u x  len=0b=11 ..3  4..             ..10
00000460: 00 ff d8 ff e0 00 10 4a 46 49 46 00 01 01 00 00  .......JFIF.....
       ..11)|DATA-JPEG-IMAGE... J  F  I  F
```

<details><summary> The extra-field is 28 bytes with (currently) two values. </summary><p>

The first one, `UT`, is mentioned in the ZIP [spec][1]:

```
   4.6.1 Third party mappings commonly used are:

          [...]
          0x5455        extended timestamp
```

The second one, `ux`/`0x7875`, is described by [libzip](https://libzip.org/specifications/extrafld.txt)
as an Info-ZIP field that "stores Unix UIDs/GIDs".

</p></details>

<details><summary> There is another suitable mapping we can use: 0x6375 — Info-ZIP Unicode Comment Extra Field. </summary><p>

[Specified][1] as:
```
   4.6.8 -Info-ZIP Unicode Comment Extra Field (0x6375):

      Stores the UTF-8 version of the file comment as stored in the
      central directory header. (Last Revision 20070912)

         Value         Size        Description
         -----         ----        -----------
  (UCom) 0x6375        Short       tag for this extra block type ("uc")
         TSize         Short       total data size for this block
         Version       1 byte      version of this extra field, currently 1
         ComCRC32      4 bytes     Comment Field CRC32 Checksum
         UnicodeCom    Variable    UTF-8 version of the entry comment

       Currently Version is set to the number 1.
```
</p></details>

I wrote a script, [bytes.sh](bytes.sh), to substitute byte sequences.

```shell
correct_pdf() {
  ./bytes.sh $(
    #                 L  e  n  g  t  h     3  3  6  0  7  0
    printf '_%s=%s ' 4c_65_6e_67_74_68_20_33_33_36_30_37_30_0a \
                     4c_65_6e_67_74_68_20_33_33_36_31_37_38_0a
    # increased because of PK after End of Image (FF D9)

    #                \n  >  > \n  s  t  r  e  a  m
    printf '_%s=%s ' 0a_3e_3e_0a_73_74_72_65_61_6d \
                     0a_25_3e_0a_25_74_72_65_61_6d
    #                \n  %  > \n  %  t  r  e  a  m

    # avoid newline: minimum required version 0a->0b
    #                 P  K 03 04 10  0
    printf '_%s=%s ' 50_4b_03_04_0a_00 \
                     50_4b_03_04_0b_00 # 10=1.0 -> 11=1.1

    # replace extra fields with our own, 0x6375 ("uc"), unicode file comment:
    printf '_%s=%s ' \
      `# U T len=9 (timestamp)                  u x  11 (unix uid/gid)` \
        55_54_09_00_xx_xx_xx_xx_xx_xx_xx_xx_xx_75_78_0b_00_xx_xx_xx_xx_xx_xx_xx_xx_xx_xx_xx \
        75_63_18_00_01_01_f0_9c_61_20_20_20_20_20_20_20_20_0a_3e_3e_0a_73_74_72_65_61_6d_0a
       # u c  24    v. CRC32 CHK bla bla bla               \n  > >  \n  s  t  r  e  a  m \n

    #                 P  K 01 02 = Central directory signature
    #                 |  |  |  | 30 = made by spec v3.0
    #                 |  |  |  |  | 03 = UNIX lines
    #                 |  |  |  |  |  | 10 00 = v1.0 needed to extract
    #                 |  |  |  |  |  |  |
    printf '_%s=%s ' 50_4b_01_02_1e_03_0a_00 \
                     50_4b_01_02_1e_03_0b_00 # 0a->0b to match ver. in local file header
  )
}
correct_pdf < magic.zip > magic0.zip.pdf
```

The file should now be valid!

## Validate file

```shell
validate_zip() {
    unzip -t "$1"
    zip  -T  "$1"
    # zip -F "$1" --out fixed # may also report some errors
}
validate_zip magic0.zip.pdf
```

To validate the PDF, other than opening it in different readers, `ghostscript` can be tried:

```
gs -dBATCH -dNOPAUSE -dPDFSTOPONERROR magic0.zip.pdf
```

## Minimal ZIP header

Even though the file is valid, some applications struggle with opening the ZIP when the first bytes are not `PK` (magic bytes). How cool is a Proof of Concept if it often doesn't work?

The PDF 1.7 [specification][2] states that:

> The first line of a PDF file shall be a header consisting of the 5 characters %PDF– followed by a version number

That does not leave much flexibility. The specs for [1.5][4] and [1.6][3] (and [1.4][5] and [1.3][6], but not [1.2][7]), however, say:

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

<details><summary> CRC-32 implementation </summary><p>

```shell
# https://rosettacode.org/wiki/CRC-32#POSIX
# @Author: Léa Gris <lea.gris@noiraude.net>
crc32() {
  crc=0xFFFFFFFF # The Initial CRC32 value
  p=0xedb88320   # The CRC32 polynomial
  r=0            # The polynomial reminder
  c=''           # The current character
  byte=0         # The byte value of the current character
  i=0
  while [ $((i+=1)) -le $1 ]; do
    c="$(dd bs=1 count=1 2>/dev/null)"
    if [ -n "$c" ]; then
    byte=$(printf '%d' "'$c")  # Converts the character into its byte value
    else byte=10; fi
    r=$(((crc & 0xff) ^ byte)) # XOR LSB of CRC with current byte
    # 8-bit lsb shift with XOR polynomial reminder when odd
    for _ in _ _ _ _ _ _ _ _; do
      t=$((r >> 1))
      r=$(((r & 1) ? t ^ p : t))
    done
    crc=$(((crc >> 8) ^ r)) # XOR MSB of CRC with Reminder
  done

  # Output CRC32 integer XOR mask 32 bits
  echo $((crc ^ 0xFFFFFFFF))
}

crc32hex() {
    printf %s "$1" | crc32 ${#1} \
        | xargs echo 'obase=16;' | bc \
        | sed 's/../& /g; # split' \
        | awk '{ for (i=1; i<=NF; i++) s = $i " " s; print s } # reverse'
}
```

</p></details>

We need to write bytes to a file.
(My understanding is that `\u`,`\x` are less portable than `printf`'s `\ddd` (octal) ([ref.](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/printf.html#tag_20_94_13)).)

```shell
write() {
    for arg; do
        hex=$(printf $arg | tr '[:lower:]' '[:upper:]')
        oct=$(echo "ibase=16; obase=8; $hex" | bc)
        printf \\$oct
    done
}
create_zip_header() {
    data='%PDF-1.3
'
    crc_32=$(crc32hex "$data")
    # little-endian byte order:
    write  50 4b 03 04  # signature 'PK\03\04'
    write  0b           # version, avoiding 0a (Line Feed), so v=1.1 not 1.0
    write  00           # version upper byte, 0=MS-DOS and OS/2 compatible
    write  00 00 00 00  # compression method 0=uncompressed
    write  50 57 13 55  # last mod file time/date
    write  ${crc_32}    # crc-32
    write  09 00 00 00 09 00 00 00 # compressed/uncompressed size
    write  01 00        # file name length
    write  00 00        # extra field length
    printf 'x'          # file name
    printf '%s' "$data"
}
create_zip_header > header.zip
```

That's it, a valid ZIP file header in 40 bytes (including `%PDF-1.3` data).
It's not a valid zip _file_ without a Central directory, but it's a valid header.

Let's complete the file with zip header:

```shell
file_header() {
    cat header.zip
    sed '1{/%PDF/d;}' 1st_half.pdf | trim_last_newline
    cat image.zip
    rm image.zip
}
file_header > magic.zip
zip -A magic.zip
end_body > 2nd_half.pdf
tr '\n' '=' < 2nd_half.pdf > comment.txt
zip -z magic.zip < comment.txt
xref_offset=$(wc -c magic.zip | awk '{ print $1 }')
xref_table magic.zip >> 2nd_half.pdf
pdf_trailer >> 2nd_half.pdf
add_archive_comment <2nd_half.pdf magic.zip
correct_pdf < magic.zip > magic1.zip.pdf
validate_zip magic1.zip.pdf
```

## Conclusion

It is possible to create a valid PDF+ZIP file containing the same JPG file without duplication:

* [magic0.zip.pdf](https://github.com/tingstad/pdfzip/raw/master/magic0.zip.pdf) (no initial zip bytes)
* [magic1.zip.pdf](https://github.com/tingstad/pdfzip/raw/master/magic1.zip.pdf) (with initial zip signature)

What does this give us?
ZIP files offer an interface for accessing archived files that is more accessible to most users than handling raw bytes.
PDFs containing resized or otherwise transformed images may present the original image files in the ZIP archive.

The technique has been documented in an executable README+Shell file.
I mostly like the result[^1].

[^1]: But I did sometimes miss a smarter (faster) build system like `make`[[ref](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/make.html)].

[1]: https://pkware.cachefly.net/webdocs/APPNOTE/APPNOTE-6.3.9.TXT
[2]: https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf
[3]: https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.6.pdf
[4]: https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.5_v6.pdf
[5]: https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.4.pdf
[6]: https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.3.pdf
[7]: https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.2.pdf

"DOC"

