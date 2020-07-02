#!/bin/bash

IMGVOL="/Volumes/Image Volume"
# Make sure we're inside the recovery environment. This may not be the best
# way to check, but it's simple and should work in the real world.
if [ ! -d "$IMGVOL" ]
then
    echo 'You must use this script from inside the Recovery environment.'
    echo 'Please restart your Mac from the patched Big Sur installer'
    echo 'USB drive, then open Terminal and try again.'
    echo
    echo '(The ability to use this script without rebooting into the'
    echo 'Recovery environment is planned for a future patcher release.)'
    exit 1
fi


# We're uninstalling *all* of the patched kexts that can be installed
# by patch-kexts.sh. If there's any reason to add partial uninstallation,
# that can be implemented in the future.
echo 'Uninstalling patched kexts on volume:'
VOLUME="$1"
echo "$VOLUME"
echo

# Sanity check to make sure that $VOLUME isn't an obvious mistake
#
# DO NOT check for /Syste/Library/CoreServices here, or Big Sur data drives
# as well as system drives will pass the check!
if [ ! -d "$VOLUME/System/Library/Extensions" ]
then
    echo "Unable to find /System/Library/Extensions on the volume."
    echo "Cannot proceed. Make sure you specified the correct volume."
    exit 1
fi

# Check that the $VOLUME has macOS version "10.16" [sic]. This version
# check will likely need an update for future Big Sur seeds, but that's OK.
SVPL="$VOLUME"/System/Library/CoreServices/SystemVersion.plist
SVPL_VER=`fgrep '<string>10' "$SVPL" | sed -e 's@^.*<string>10@10@' -e 's@</string>@@' | uniq -d`
SVPL_BUILD=`grep '<string>[0-9][0-9][A-Z]' "$SVPL" | sed -e 's@^.*<string>@@' -e 's@</string>@@'`

if [ "x$SVPL_VER" = "x10.16" ]
then
    echo -n "Volume appears to have a Big Sur installation (build" $SVPL_BUILD
    echo "). Continuing."
else
    if [ -z "$SVPL_VER" ]
    then
        echo 'Unable to detect macOS version on volume. Make sure you chose'
        echo 'the correct volume. Or, perhaps a newer patcher is required.'
    else
        echo 'Volume appears to have an older version of macOS. Probably'
        echo 'version' "$SVPL_VER" "build" "$SVPL_BUILD"
        echo 'Please make sure you specified the correct volume.'
    fi

    exit 1
fi

# Also check to make sure $VOLUME is an actual volume and not a snapshot.
# Maybe I'll add code later to handle the snapshot case, but in the recovery
# environment for Developer Preview 1, I've always seen it mount the actual
# volume and not a snapshot.
DEVICE=`df "$VOLUME" | tail -1 | sed -e 's@ .*@@'`
echo 'Volume is mounted from device: ' $DEVICE
# The following code is somewhat convoluted for just checking if there's
# a slice within a slice, but it should make things easier for future
# code that will actually handle this case.
POPSLICE=`echo $DEVICE | sed -E 's@s[0-9]+$@@'`
POPSLICE2=`echo $POPSLICE | sed -E 's@s[0-9]+$@@'`

if [ $POPSLICE = $POPSLICE2 ]
then
    echo 'Mounted volume is an actual volume, not a snapshot. Proceeding.'
else
    echo
    echo 'ERROR:'
    echo 'Mounted volume appears to be an APFS snapshot, not the underlying'
    echo 'volume. The patcher was not expecting to encounter this situation'
    echo 'within the Recovery environment, and an update to the patcher will'
    echo 'be required. Kext installation will not proceed.'
    exit 1
fi

# (The following block of code may not be necessary for the kext patch
# uninstaller, but there's nothing to gain and definitely some risk if
# we remove it.)
#
# It's likely that at least one of these was reenabled during installation.
# But as we're in the recovery environment, there's no need to check --
# we'll just redisable these. If they're already disabled, then there's
# no harm done.
csrutil disable
csrutil authenticated-root disable


# Remount the volume read-write
echo "Remounting volume as read-write..."
if mount -uw "$VOLUME"
then
    # Remount succeeded. Do nothing in this block, and keep going.
    true
else
    echo "Remount failed. Kext installation cannot proceed."
    exit 1
fi

# Now remove the new kexts and move the old ones back into place.
pushd "$VOLUME/System/Library/Extensions"

# This alone won't be sufficient once graphics kexts enter the picture,
# but that's an issue to deal with in the future, not at this moment.

if [ -z "`ls -1d *.original`" ]
then
    echo 'No patched kexts found.'
    # Don't exit the script here. That way, the kernel caches can still
    # be rebuilt.
else
    for x in *.original
    do
        BASENAME=`echo $x|sed -e 's@.original@@'`
        echo 'Unpatching' $BASENAME
        rm -rf "$BASENAME"
        mv "$x" "$BASENAME"
    done
fi

popd


# According to jackluke on the MacRumors Forums, kextcache -i is "required
# to update the prelinkedkernel" (the old way of doing things) and kmutil
# is "required to update the BootKernelExtensions.kc" (the new way of doing
# things).
# 
# All of my testing so far has been on installations using the new way,
# but as far as I can tell, kextcache -i is at worst a no-op for kernel
# collection users, so I may as well keep it there for the benefit of
# prelinkedkernel users out there.
kextcache -i "$VOLUME"
kmutil install --volume-root "$VOLUME" --update-all

# The way you control kcditto's *destination* is by choosing which volume
# you run it *from*. I'm serious. Read the kcditto manpage carefully if you
# don't believe me!
"$VOLUME/usr/sbin/kcditto"

bless --folder "$VOLUME"/System/Library/CoreServices --bootefi --create-snapshot

echo 'Done uninstalling kexts.'
