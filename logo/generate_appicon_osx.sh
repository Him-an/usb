#!/bin/sh

sizes="16 32 128 256 512"

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <image_path_with_extension>"
	exit
fi

file=$(basename "$1")
filename="${file%.*}"
extension="${file##*.}"

echo "Processing $filename with extension $extension"

for size in $sizes; do
	dsize="$(($size * 2))"
	echo "Creating size $size, @2x $dsize"
	pfile="${filename}_${size}x${size}.${extension}"
	echo "File $pfile"
	cp "$1" "$pfile"
	sips -Z $size "$pfile"
	pfile="${filename}_${size}x${size}@2x.${extension}"
	echo "File $pfile"
	cp "$1" "$pfile"
	sips -Z $dsize "$pfile"
done
