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

# Before actually running the installer, run insert-dylib.sh to
# set things up.
"$BASE/insert-hax.sh"

# The obvious, sane, and efficient approach would be to use the return
# value of insert-dylib.sh to determine whether to proceed or stop. However,
# it won't do any harm to waste a few milliseconds here, and we won't be
# able to use the insert-dylib.sh return value once the v0.0.4 refactoring
# is complete, so we'll check using launchctl getenv.
if [ -z "`launchctl getenv DYLD_INSERT_LIBRARIES`" ]
then
    # Error message will go here toward the end of v0.0.4 refactoring, but
    # currently the error message is printed by insert-dylib.sh, so just
    # stop the script here.
    exit 1
fi

# The installer **MUST** be backgrounded using &, or else the "Close Other
# Applications" button in the installer fails to close Terminal and the
# installer fails to reboot.
"$INSTALLERNAME" $* &

