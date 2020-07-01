#!/bin/bash

BASE='/Volumes/Image Volume'

# I should clean this up at a later point in patcher development, but
# for now (late June/early July) I'll keep it flexible.
if [ -e "$BASE/Hax3.app" ]
then
    echo 'Found Hax3.app, so using embedded HaxLib.dylib'
    LIBPATH="$BASE/Hax3.app/Contents/Resources/HaxLib.dylib"
if [ -e "$BASE/Hax2.app" ]
then
    echo 'Found Hax2.app, so using embedded Hax2Lib.dylib'
    LIBPATH="$BASE/Hax2.app/Contents/Resources/Hax2Lib.dylib"
elif [ -e "$BASE/HaxLib.dylib" ]
then
    echo 'Found HaxLib.dylib (presumably from Hax3)'
    LIBPATH="$BASE/HaxLib.dylib"
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

# On unsupported Macs, system sleep and display sleep often don't work
# properly in the Recovery environment. So, disable them before
# starting the installer.
pmset -a displaysleep 0 sleep 0

launchctl setenv DYLD_INSERT_LIBRARIES "$LIBPATH"

echo
echo 'You may now quit Terminal and start the Installer as normal.'
