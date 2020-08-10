#!/bin/bash

BASE='/Volumes/Image Volume'

if [ "x$1" = "x--seal" ]
then
    echo 'Using HaxSeal.dylib to enable volume sealing'
    LIBPATH="$BASE/HaxSeal.dylib"
else
    echo 'Using HaxDoNotSeal.dylib which will inhibit volume sealing'
    LIBPATH="$BASE/HaxDoNotSeal.dylib"
fi

# Check to make sure the dylib exists now, so we don't run the risk of
# the user getting a mystery meat error message from the installer later.
if [ ! -e "$LIBPATH" ]
then
    echo "Could not find the Hax. (This is most likely a patcher bug.)"
    echo "For diagnostic purposes, the desired LIBPATH was:"
    echo "$LIBPATH"
    exit 1
fi

# On unsupported Macs, system sleep and display sleep often don't work
# properly in the Recovery environment. So, disable them before
# starting the installer.
pmset -a displaysleep 0 sleep 0

launchctl setenv DYLD_INSERT_LIBRARIES "$LIBPATH"

echo
echo 'You may now quit Terminal and start the Installer as normal.'
