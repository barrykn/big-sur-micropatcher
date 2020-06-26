#!/bin/bash

# Any command line arguments are passed to InstallAssistant.

# As of micropatcher v0.0.4, this script is left present as a potential
# convenience but is otherwise deprecated. Instead of running this script,
# users should quit Terminal and run the Installer as normal.


BASE='/Volumes/Image Volume'
APPNAME='Install macOS Beta.app'

# Regarding the choice of InstallAssistant binary, there is also one
# at /Install macOS Beta/Contents/MacOS/InstallAssistant -- but if you
# use that one, it fails with:
# "Installation requires downloading important content. That content can't
# be downloaded at this time. Try again later."
INSTALLERNAME="$BASE/$APPNAME/Contents/MacOS/InstallAssistant"

# As of micropatcher version 0.0.4, it is the user's responsibility to
# run insert-hax.sh before running this script. Users should generally
# run set-vars.sh, which will itself invoke insert-hax.sh; furthermore,
# this script is now deprecated. So, this should not be a problem.
#
# In the event that I turn out to be mistaken, I'll reintroduce error
# checking in this script in a future micropatcher release. (I think it's
# more likely that this script will be removed entirely, however.)

# The installer **MUST** be backgrounded using &, or else the "Close Other
# Applications" button in the installer fails to close Terminal and the
# installer fails to reboot.
"$INSTALLERNAME" $* &

