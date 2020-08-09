#!/bin/bash
# For each kext that exists in /System/Library/Extensions on the
# macOS Base System, replace it with a copy of the corresponding kext
# from the running (Big Sur) system. Be careful; this script may have bugs,
# particularly if macOS Base System is running low on disk space.
# 
# Assumption: read-write BaseSystem.dmg is already mounted

if [ ! -d "/Volumes/macOS Base System" ]
then
    echo "Make sure read-write BaseSystem is mounted!"
    exit 1
fi

# This seems to be necessary, at least sometimes, even though the image
# is already in read-write format.
mount -uw "/Volumes/macOS Base System" || exit 1

# Delete the KernelCollections because we need the disk space!
echo 'Deleting KernelCollections on macOS Base System.'
rm -f "/Volumes/macOS Base System/System/Library/KernelCollections/"*.kc

cd "/Volumes/macOS Base System/System/Library/Extensions" || exit 1
for x in *
do
    # This reuses the same line of console output repeatedly
    # so progress is visible without printing 400+ lines
    # (but errors from cp will still be visible)
    echo -n "Removing old $x..."
    rm -rf "$x"
    echo -ne "\033[2K" ; printf "\r"

    echo -n "Copying new $x..."
    cp -r "/System/Library/Extensions/$x" "$x"
    echo -ne "\033[2K" ; printf "\r"
done

chmod -R 755 "/Volumes/macOS Base System/System/Library/Extensions"
chown -R 0:0 "/Volumes/macOS Base System/System/Library/Extensions"
