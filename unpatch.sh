#!/bin/bash
VERSIONNUM="0.0.11pre"
VERSION="BarryKN Big Sur Micropatcher Unpatcher v$VERSIONNUM"

echo $VERSION
# Add a blank line of output to make things easier on the eyes.
echo

# Add disclaimer
echo "It's really best to recreate the USB stick using createinstallmedia,"
echo "but this takes much less time and is useful for patcher development."
echo

# Hardcoded for now. (The assumptions are that the recovery USB stick was
# created using createinstallmedia and was not renamed afterward -- and that
# there is only one Big Sur recovery USB stick plugged into this Mac.)
#
# As of v0.0.9, changed to first check for the name that will probably be
# used throughout the majority of the beta cycle.
VOLUME='/Volumes/Install macOS Big Sur Beta'
if [ ! -d "$VOLUME/Install macOS Big Sur Beta.app" ]
then
    # Check for beta 1 before giving up
    VOLUME='/Volumes/Install macOS Beta'
    if [ ! -d "$VOLUME/Install macOS Beta.app" ]
    then
        echo "Failed to locate Big Sur recovery USB stick for unpatching."
        echo
        echo "Patcher cannot continue and will now exit."
        exit 1
    fi
fi

if [ ! -e "$VOLUME/Patch-Version.txt" ]
then
    echo 'Patch not detected on USB stick, but proceeding with unpatch anyway.'
    echo 'This should do no harm. Any subsequent error messages are,'
    echo 'in all likelihood, harmless.'
    echo
fi

# Undo the boot-time compatibility check patch, if present
echo 'Checking for boot-time compatibility check patch (v0.0.1/v0.0.2).'
if [ -e "$VOLUME/System/Library/CoreServices/PlatformSupport.plist.inactive" ]
then
    echo 'Removing boot-time compatibility check patch.'
    mv "$VOLUME/System/Library/CoreServices/PlatformSupport.plist.inactive" \
       "$VOLUME/System/Library/CoreServices/PlatformSupport.plist"
else
    echo 'Boot-time compatibility check not present; continuing.'
fi

echo

# Undo the com.apple.Boot.plist patch, if present
echo 'Checking for com.apple.Boot.plist patch (v0.0.3+).'
if [ -e "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist.original" ]
then
    echo 'Removing com.apple.Boot.plist patch.'
    cat "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist.original" > "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist"
    rm "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist.original"
else
    echo 'com.apple.Boot.plist patch not present; continuing.'
fi

echo
echo 'Removing kexts, shell scripts, and patcher version info.'
# For v0.0.9 and earlier
rm -rf "$VOLUME"/*.kext
# For v0.0.10 and later
rm -rf "$VOLUME"/kexts
rm -f "$VOLUME"/*.kext.zip "$VOLUME"/*.sh "$VOLUME/Patch-Version.txt"

# Now that the patcher is going to add the dylib itself, go ahead and
# remove that too.
echo 'Remvoing Hax dylibs...'
rm -f "$VOLUME"/Hax*.dylib
rm -rf "$VOLUME"/Hax*.app

echo
echo 'Syncing.'
sync

echo
echo 'Unpatcher finished.'
