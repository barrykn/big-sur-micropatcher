#!/bin/sh
# This script builds the setvars EFI code for both 64-bit and 32-bit.
# I (Barry) used GNU EFI on Debian 10.5 on x86_64 for compiling, although
# I imagine GNU EFI running on other recent Linux distributions should work
# too.
# 
# In theory it should also be possible to use Debian on i386 (32-bit)
# instead of x86_64 for compiling, but it would probably need considerable
# changes to the Makefile, so it's probably not worth it.
#
# The 32-bit setvars EFI code is probably superfluous -- even my MacBook4,1
# seems to have 64-bit EFI -- but it wasn't really much effort to build
# both variants, and maybe it'll help someone out there who is really
# determined to run Big Sur on a 2007 iMac with an upgraded CPU or whatever,
# so I may as well do it.

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
