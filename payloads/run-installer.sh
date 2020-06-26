#!/bin/bash

# Any command line arguments are passed to InstallAssistant.

BASE='/Volumes/Image Volume'
APPNAME='Install macOS Beta.app'

# Regarding the choice of InstallAssistant binary, there is also one
# at /Install macOS Beta/Contents/MacOS/InstallAssistant -- but if you
# use that one, it fails with:
# "Installation requires downloading important content. That content can't
# be downloaded at this time. Try again later."
INSTALLERNAME="$BASE/$APPNAME/Contents/MacOS/InstallAssistant"

if [ -e "$BASE/Hax2.app" ]
then
    echo 'Found Hax2.app, so using embedded Hax2Lib.dylib'
    LIBPATH="$BASE/Hax2.app/Contents/Resources/Hax2Lib.dylib"
elif [ -e "$BASE/Hax2Lib.dylib" ]
then
    echo 'Found Hax2Lib.dylib'
    LIBPATH="$BASE/Hax2Lib.dylib"
elif [ -e "$BASE/Hax.dylib" ]
then
    echo 'Found Hax.dylib'
    LIBPATH="$BASE/Hax.dylib"
else
    echo 'Could not find Hax2.app, Hax2Lib.dylib, or Hax.dylib.'
    echo 'Please copy one of them onto your USB stick.'
    exit 1
fi

launchctl setenv DYLD_INSERT_LIBRARIES "$LIBPATH"

# The installer **MUST** be backgrounded using &, or else the "Close Other
# Applications" button in the installer fails to close Terminal and the
# installer fails to reboot.
"$INSTALLERNAME" $* &

