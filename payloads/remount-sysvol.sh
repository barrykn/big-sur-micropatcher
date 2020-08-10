#!/bin/bash

### begin function definitions ###

# Like echo, but goes to stderr instead of stdout. Nearly all invocations
# of what would be echo in this script actually need to be this instead, so
# that stdout can be reserved for setting environment variables.
#
# (it's echo + err)
ecrr() {
    >&2 echo "$@"
}

##( end function definitions ###

# Make sure this script is running as root, otherwise use sudo to try again
# as root.
[ $UID = 0 ] || exec sudo --preserve-env=SHELL "$0" "$@"

IMGVOL="/Volumes/Image Volume"
if [ -d "$IMGVOL" ]
then
    RECOVERY="YES"
else
    RECOVERY="NO"

    # While we're at it, we need to check SIP & authenticated-root
    # (both need to be disabled)
    if ! csrutil status | grep -q 'disabled.$'
    then
        MUSTEXIT="YES"
        >&2 csrutil status
    fi

    if ! csrutil authenticated-root status | grep -q 'disabled$'
    then
        MUSTEXIT="YES"
        >&2 csrutil authenticated-root status
    fi

    if [ "x$MUSTEXIT" = "xYES" ]
    then
        ecrr "Please boot from the patched Big Sur installer USB and run the"
        ecrr "following command in Terminal to fix this:"
        ecrr "/Volumes/Image\ Volume/set-vars.sh"
        ecrr "(or boot from the installer USB and fix it yourself)"
        exit 1
    fi
fi

VOLUME="$1"

if [ -z "$VOLUME" ]
then
    if [ "x$RECOVERY" = "xYES" ]
    then
        # Make sure a volume has been specified. (Without this, other error
        # checks eventually kick in, but the error messages get confusing.)
        ecrr 'You must specify a target volume (such as /Volumes/Macintosh\ HD)'
        ecrr 'on the command line.'
        exit 1
    else
        # Running under live installation, so use / as default
        VOLUME="/"
    fi
fi

ecrr "$VOLUME"
ecrr

# Sanity checks to make sure that the specified $VOLUME isn't an obvious mistake

# First, make sure the volume exists. (If it doesn't exist, the next check
# will fail anyway, but having a separate check for this case might make
# troubleshooting easier.
if [ ! -d "$VOLUME" ]
then
    ecrr "Unable to find the volume."
    ecrr "Cannot proceed. Make sure you specified the correct volume."
    exit 1
fi

# Next, check that the volume has /System/Library/Extensions (i.e. make sure
# it's actually the system volume and not the data volume or something).
# DO NOT check for /System/Library/CoreServices here, or Big Sur data drives
# as well as system drives will pass the check!
if [ ! -d "$VOLUME/System/Library/Extensions" ]
then
    ecrr "Unable to find /System/Library/Extensions on the volume."
    ecrr "Cannot proceed. Make sure you specified the correct volume."
    ecrr "(Make sure to specify the system volume, not the data volume.)"
    exit 1
fi

# Check that the $VOLUME has macOS build 20*.
SVPL="$VOLUME"/System/Library/CoreServices/SystemVersion.plist
SVPL_VER=`fgrep '<string>10' "$SVPL" | sed -e 's@^.*<string>10@10@' -e 's@</string>@@' | uniq -d`
SVPL_BUILD=`grep '<string>[0-9][0-9][A-Z]' "$SVPL" | sed -e 's@^.*<string>@@' -e 's@</string>@@'`

if echo $SVPL_BUILD | grep -q '^20'
then
    ecrr -n "Volume appears to have a Big Sur installation (build" $SVPL_BUILD
    ecrr "). Continuing."
else
    if [ -z "$SVPL_VER" ]
    then
        ecrr 'Unable to detect macOS version on volume. Make sure you chose'
        ecrr 'the correct volume. Or, perhaps a newer patcher is required.'
    else
        ecrr 'Volume appears to have an older version of macOS. Probably'
        ecrr 'version' "$SVPL_VER" "build" "$SVPL_BUILD"
        ecrr 'Please make sure you specified the correct volume.'
    fi

    exit 1
fi

# Check whether the mounted device is actually the underlying volume,
# or if it is a mounted snapshot.
DEVICE=`df "$VOLUME" | tail -1 | sed -e 's@ .*@@'`
ecrr 'Volume is mounted from device: ' $DEVICE

POPSLICE=`echo $DEVICE | sed -E 's@s[0-9]+$@@'`
POPSLICE2=`echo $POPSLICE | sed -E 's@s[0-9]+$@@'`

if [ $POPSLICE = $POPSLICE2 ]
then
    WASSNAPSHOT="NO"
    ecrr 'Mounted device is an actual volume, not a snapshot. Proceeding.'
else
    WASSNAPSHOT="YES"
    VOLUME=`mktemp -d`
    ecrr "Mounted device is a snapshot. Will now mount underlying volume"
    ecrr "from device $POPSLICE at temporary mountpoint:"
    ecrr "$VOLUME"
    # Blank line for legibility
    ecrr
    if ! mount -o nobrowse -t apfs "$POPSLICE" "$VOLUME"
    then
        ecrr 'Mounting underlying volume failed. Cannot proceed.'
        exit 1
    fi
fi

if [ "x$RECOVERY" = "xYES" ]
then
    # It's likely that at least one of these was reenabled during installation.
    # But as we're in the recovery environment, there's no need to check --
    # we'll just redisable these. If they're already disabled, then there's
    # no harm done.
    >&2 csrutil disable
    >&2 csrutil authenticated-root disable
fi

if [ "x$WASSNAPSHOT" = "xNO" ]
then
    ecrr "Remounting volume as read-write..."
    if ! mount -uw "$VOLUME"
    then
        ecrr "Remount failed. Kext installation cannot proceed."
        exit 1
    fi
fi

# Output the variables to stdout
# (or maybe not)
#echo export RECOVERY=\""$RECOVERY"\"\;
#echo export WASSNAPSHOT=\""$WASSNAPSHOT"\"\;
#echo export VOLUME=\""$VOLUME"\"\;

export RECOVERY WASSNAPSHOT VOLUME
echo RECOVERY=\""$RECOVERY"\"\;
echo WASSNAPSHOT=\""$WASSNAPSHOT"\"\;
echo VOLUME=\""$VOLUME"\"\;
echo

if [ -z "$SHELL" ]
then
    echo 'Unable to determine current shell. This may be a patcher bug.'
    echo 'Assuming /bin/bash.'
    echo
    NEXTSHELL=/bin/bash
elif [ "x$SHELL" = "x/bin/sh" ]
then
    # Probably in recovery environment, but bash is also available, so
    # that might be a more humane choice of shell for the user
    NEXTSHELL=/bin/bash
else
    NEXTSHELL=$SHELL
fi

export REBUILD_KC=`echo "$0" | sed -e 's@remount-sysvol@rebuild-kc@'`
echo "Dropping into subshell. Run 'exit' when done."
echo "Don't forget to run either" '"$REBUILD_KC"' "(including quotation marks)"
echo "or:" \""$REBUILD_KC"\"
echo "(copy and paste it, including the quotation marks)"
echo "before you exit."
pushd "$VOLUME/System/Library/Extensions" > /dev/null
$NEXTSHELL
popd > /dev/null

# Try to unmount the underlying volume if it was mounted by this script.
# (Otherwise, trying to run this script again without rebooting causes
# errors when this script tries to mount the underlying volume a second
# time.)
if [ "x$WASSNAPSHOT" = "xYES" ]
then
    echo "Attempting to unmount underlying volume (don't worry if this fails)."
    echo "This may take a minute or two."
    umount "$VOLUME" || diskutil unmount "$VOLUME"
fi

echo 'Done.'
