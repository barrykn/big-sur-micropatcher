#!/bin/sh -x
# Maybe I should make an actual Makefile, but this script compiles one
# source file to two different binary files using two different sets of
# compiler flags. In fact, considering that's nearly *all* this file does,
# I'm not even sure that Make is the right tool for the job.

FLAGS="-dynamiclib -fmodules"
export MACOSX_DEPLOYMENT_TARGET=10.9

rm -f Hax*.dylib

if [ "x$1" = "x--clean" ]
then
    exit 0
fi

clang $FLAGS -DDO_NOT_SEAL HaxLib.m -o HaxDoNotSeal.dylib
clang $FLAGS -DSEAL HaxLib.m -o HaxSeal.dylib
clang $FLAGS -DBYPASS_APFS_ROM_CHECK -DDO_NOT_SEAL HaxLib.m -o HaxDoNotSealNoAPFSROMCheck.dylib
clang $FLAGS -DBYPASS_APFS_ROM_CHECK -DSEAL HaxLib.m -o HaxSealNoAPFSROMCheck.dylib
codesign -f -s - Hax*.dylib
