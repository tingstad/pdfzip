#!/bin/sh
set -e

echo "Copy first part of jpeg.pdf (>part1.pdf)"
sed -n '/%PDF-/,/REPLACE/p' jpeg.pdf | sed /REPLACE/d > part1.pdf
cp part1.pdf pure.pdf

echo "Copy magic.jpg"
dd if=magic.jpg >> pure.pdf


