# Readme notes

https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT

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
https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf Document management — Portable document format — Part 1: PDF 1.7
https://www.pdfa.org/norm-refs/5116.DCT_Filter.pdf
https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
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

