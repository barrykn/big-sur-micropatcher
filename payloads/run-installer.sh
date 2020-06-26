#!/bin/bash

# Any command line arguments are passed to InstallAssistant.

BASE='/Volumes/Image Volume'
APPNAME='Install macOS Beta.app'
INSTALLERNAME="$BASE/$APPNAME/Contents/MacOS/InstallAssistant"

if [ -f "$BASE/Hax2Lib.dylib" ]
then
    echo 'Found Hax2Lib.dylib'
    LIBPATH="$BASE/Hax2Lib.dylib"
elif [ -f "$BASE/Hax.dylib" ]
then
    echo 'Found Hax.dylib'
    LIBPATH="$BASE/Hax.dylib"
else
    echo 'Neither Hax2Lib.dylib nor Hax.dylib were found. Please copy one'
    echo 'of them onto your USB stick.'
    exit
fi

launchctl setenv DYLD_INSERT_LIBRARIES "$LIBPATH"

# The installer **MUST** be backgrounded using &, or else the "Close Other
# Applications" button in the installer fails to close Terminal and the
# installer fails to reboot.
"$INSTALLERNAME" $* &

