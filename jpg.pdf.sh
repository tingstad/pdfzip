#!/bin/sh
set -e

echo "Copy first part of jpeg.pdf (>part1.pdf)"
sed -n '/%PDF-/,/REPLACE/p' jpeg.pdf | sed /REPLACE/d > part1.pdf
cp part1.pdf pure.pdf

echo "Copy magic.jpg"
dd if=magic.jpg >> pure.pdf

echo "" > part2.pdf #newline before `endstream`

echo "Copy last part of jpeg.pdf (>part2.pdf)"
sed -n '/REPLACE/,/EOF/p' jpeg.pdf | sed /REPLACE/d >> part2.pdf
dd if=part2.pdf >> pure.pdf

echo "Wrote pure.pdf"
open pure.pdf

echo "Create frank.zip with part2.pdf as zipfile comment (-z)"
[ -e frank.zip ] && rm frank.zip
[ -e end.zip ] && rm end.zip
len=$(wc -c part1.pdf | awk '{ print $1 }')
dd bs=1 count=$((len-1)) if=part1.pdf of=begin.pdf

# The zip command adds carriage returns to comment, which we don't want,
# so replace temporarily with '=' (to keep byte count right):
tr '\n' '=' < part2.pdf > part2.txt #FIXME: replace back
zip -0 end.zip magic.jpg -z < part2.txt
cp begin.pdf frank.zip
dd if=end.zip >> frank.zip
zip -A frank.zip  #fix offset addresses after prepending data

# replace '=' (3d) back to \n (0a):
len=$(wc -c part2.pdf | awk '{ print $1 }')
total=$(wc -c frank.zip | awk '{ print $1 }')
xxd -c 1 frank.zip | awk -v line=$((total-len)) '{ if (NR>=line) sub(": 3d",": 0a"); print }' | xxd -c 1 -r > tmp && mv tmp frank.zip

echo "Wrote frank.zip"

echo "Commence byte hacking"
# xxd -g 2 -c 32 frank.zip
#000003c0: 6874 2032 3733 380a 2f4c 656e 6774 6820 3537 3637 3332 0a2f 4669 6c74 6572 202f  ht 2738./Length 576732./Filter /
#000003e0: 4443 5444 6563 6f64 650a 2f43 6f6c 6f72 5370 6163 6520 2f44 6576 6963 6552 4742  DCTDecode./ColorSpace /DeviceRGB
#00000400: 0a2f 4269 7473 5065 7243 6f6d 706f 6e65 6e74 2038 0a3e 3e0a 7374 7265 616d 504b  ./BitsPerComponent 8.>>.streamPK
#00000420: 0304 0a00 0000 0000 f575 7753 711c b347 dccc 0800 dccc 0800 0900 1c00 6d61 6769  .........uwSq..G............magi
#00000440: 632e 6a70 6755 5409 0003 fdf0 9c61 4586 a261 7578 0b00 0104 f501 0000 0414 0000  c.jpgUT......aE..aux............
#00000460: 00ff d8ff e000 104a 4649 4600 0101 0000 0100 0100 00ff db00 4300 0806 0607 0605  .......JFIF.............C.......

< frank.zip > modified.zip ./bytes.sh $(
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
)
xxd -g 2 -c 32 modified.zip | awk '
/^00000440/ {
# replace extra fields with our own, 0x6375 ("uc"), unicode file comment:  TODO: add file comment (central dir file header) as fallback? ("If the CRC check fails, this Unicode Comment extra field SHOULD be ignored and the File Comment field in the header SHOULD be used instead."")
#         U T len=9 (timestamp)            ux  11 (unix uid/gid)
    sub("55 5409 00.. .... .... .... .... 7578 0b00 0104 f501 0000 0414 0000",
        "75 6318 0001 01f0 9c61 0000 0000 0000 0000 0a3e 3e0a 7374 7265 616d")
#         u c 24   v. CRC32 CHK bla bla bla         \n > > \n  s t  r e  a m
}
/^00000460/ {
#     comment[JPEG_IMAGE_DATA...
#00000460: 00ff d8ff e000 104a 4649 4600 0101 0000 0100 0100 00ff db00 4300 0806 0607 0605  .......JFIF.............C.......
    sub(": 00ff",
        ": 0aff")
}
/^0008d260/ {
#          \n 5  7 7  8 0  5 <- xref address
#0008d260: 0a35 3737 3830 350a 2525 454f 460a       .577805.%%EOF.
    sub(": 0a35 3737 3830 350a",
        ": 0a35 3737 3937 320a")
#          \n 5  7 7  9 7  2
}
{ print }
' | xxd -g 2 -c 32 -r > frank.zip.pdf
echo "Wrote frank.zip.pdf"

unzip -t frank.zip.pdf
zip -T frank.zip.pdf
echo "Use ghostscript (gs) to check PDF offsets etc"

echo "zip -F frank.zip.pdf --out fixed.zip #to find more warnings/problems."

