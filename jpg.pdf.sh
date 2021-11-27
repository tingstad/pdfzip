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



cp frank.zip frank.zip.pdf
echo "Wrote frank.zip[.pdf]"

