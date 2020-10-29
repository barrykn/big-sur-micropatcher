#!/bin/bash

# Any command line arguments are passed to InstallAssistant.

# Users should generally quit Terminal and start the Installer normally,
# but this script may be useful under certain circumstances.


BASE='/Volumes/Image Volume'

# Figure out what the installer app is called (similar to how micropatcher.sh
# figures out the installer USB's name).
for x in "Install macOS Big Sur" "Install macOS Big Sur Beta" "Install macOS Beta"
do
    if [ -d "$BASE/$x.app" ]
    then
        APPNAME="$x.app"
        break
    fi
done

# Micropatcher v0.0.4 introduced a requirement for insert-hax.sh to be
# run before this script. However, the installer trampoline introduced in
# v0.2.0 now handles this automatically.

# Regarding the choice of InstallAssistant binary, there is also one at
# /Volumes/(name of USB stick)/Contents/MacOS/InstallAssistant -- but if you
# use that one, it fails with:
# "Installation requires downloading important content. That content can't
# be downloaded at this time. Try again later."
INSTALLERNAME="$BASE/$APPNAME/Contents/MacOS/InstallAssistant"

# The installer **MUST** be backgrounded using &, or else the "Close Other
# Applications" button in the installer fails to close Terminal and the
# installer fails to reboot.
"$INSTALLERNAME" $* &

# Try hiding output from the installer binary...
#2>/dev/null >/dev/null "$INSTALLERNAME" $* &

