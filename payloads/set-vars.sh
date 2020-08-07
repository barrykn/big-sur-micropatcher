#!/bin/bash
# This script adds user-specified parameters to the boot args, such as -v
# for verbose boot.

# Use --seal as the first argument to have the installer do volume sealing.
if [ "x$1" = "x--seal" ]
then
    SEAL="--seal"
    shift
fi

# Avoid adding a trailing space to boot-args in the general case,
# just to be hyper-cautious.
if [ -z "$*" ]
then
    # no command line parameters
    nvram boot-args="-no_compat_check"
else
    # add command line parameters, such as -v, to boot-args
    nvram boot-args="-no_compat_check $*"
fi

# Show the boot-args setting to the user.
nvram boot-args

# Sanity check before we continue. Yes, this detects an actual bug
# that happened during patcher development.
if [ -n "`nvram boot-args | grep \'-no`" ]
then
    echo
    echo boot-args setting failed. This is a patcher bug which must be fixed.
    echo Clearing boot-args and exiting script. csrutil settings remain
    echo untouched.
    nvram -d boot-args
    exit 1
fi

# Hide the reboot messages, because the Installer will reboot when needed,
# and rebooting earlier undoes insert-hax.sh, preventing the Installer
# from working properly.
(csrutil disable; csrutil authenticated-root disable) |
sed -e 's@Please restart the machine for the changes to take effect.@@'

echo
echo 'Done changing boot-args and csrutil settings.'
echo

# Now set things up to run the installer.
"/Volumes/Image Volume/insert-hax.sh" $SEAL
