#!/bin/sh

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
cp setvars-x86_64.efi EFI/boot/bootx64.efi
cp setvars-ia32.efi EFI/boot/bootia32.efi
cp setvars.efi EFI/boot/boot.efi
cp setvars-verboseboot-x86_64.efi EFI-verboseboot/boot/bootx64.efi
cp setvars-verboseboot-ia32.efi EFI-verboseboot/boot/bootia32.efi
cp setvars-verboseboot.efi EFI-verboseboot/boot/boot.efi
