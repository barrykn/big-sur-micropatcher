#!/bin/sh
rm -f *.efi
make clean
make
make clean
setarch i386 make
make clean
make fat

rm -rf EFI
mkdir -p EFI/boot
cp setvars-x86_64.efi EFI/boot/bootx64.efi
cp setvars-ia32.efi EFI/boot/bootia32.efi
cp *.efi EFI/boot/
