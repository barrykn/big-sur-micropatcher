#!/bin/bash
# This script adds user-specified parameters to the boot args, such as -v
# for verbose boot.

# Avoid adding a trailing space to boot-args in the general case,
# just to be hyper-cautious.
if [ -z "$*" ]
then
    # no command line parameters
    nvram boot-args="-no_compat_check amfi_get_out_of_my_way=1"
else
    # add command line parameters, such as -v, to boot-args
    nvram boot-args="-no_compat_check amfi_get_out_of_my_way=1 $*"
fi

# Show the boot-args setting to the user.
nvram -p | grep boot-args

# Sanity check before we continue. Yes, this detects an actual bug
# that happened during patcher development.
if [ -n "`nvram -p | grep boot-args | grep \'-no`" ]
then
    echo
    echo boot-args setting failed. This is a patcher bug which must be fixed.
    echo Clearing boot-args and exiting script. csrutil settings remain
    echo untouched.
    nvram -d boot-args
    exit 1
fi

csrutil disable
csrutil authenticated-root disable
echo
echo 'Now rebooting. Make sure to hold down Option for the startup selector!'

# In my testing, it seems that the reboot can actually shut down Terminal
# before it refreshes, so pause for a second to make sure all output is
# visible before the reboot.
sleep 1

reboot
