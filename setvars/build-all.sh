#!/bin/sh
set -e

make clobber
make
setarch i386 make

for x in setvars setvars-verboseboot
do
    grub-glue-efi -3 $x-ia32.efi -6 $x-x86_64.efi -o $x.efi
done

mkdir -p EFI/boot
cp *.efi EFI/boot

cp -r EFI EFI-verboseboot
mv setvars-x86_64.efi EFI/boot/bootx64.efi
mv setvars-ia32.efi EFI/boot/bootia32.efi
mv setvars.efi EFI/boot/boot.efi
mv setvars-verboseboot-x86_64.efi EFI-verboseboot/boot/bootx64.efi
mv setvars-verboseboot-ia32.efi EFI-verboseboot/boot/bootia32.efi
mv setvars-verboseboot.efi EFI-verboseboot/boot/boot.efi
