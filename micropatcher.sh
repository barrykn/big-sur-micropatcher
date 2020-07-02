#!/bin/bash
VERSIONNUM="0.0.6pre"
VERSION="BarryKN Big Sur Micropatcher v$VERSIONNUM"

echo $VERSION
echo Thanks to jackluke and ASentientBot for their hard work to get Big Sur
echo running on unsupported Macs!
# Add a blank line of output to make things easier on the eyes.
echo

# Hardcoded for now. (The assumptions are that the recovery USB stick was
# created using createinstallmedia and was not renamed afterward -- and that
# there is only one Big Sur recovery USB stick plugged into this Mac.)
VOLUME='/Volumes/Install macOS Beta'


# A couple of quick sanity checks before we begin.
if [ ! -d payloads ]
then
    echo '"payloads" folder was not found.'
    echo
    echo "Patcher cannot continue and will now exit."
    exit 1
fi

if [ ! -d "$VOLUME/Install macOS Beta.app" ]
then
    echo "Failed to properly locate Big Sur recovery USB stick."
    echo Remember to create it using createinstallmedia, and do not rename it.
    echo
    echo "Patcher cannot continue and will now exit."
    exit 1
fi

if [ -e "$VOLUME/Patch-Version.txt" ]
then
    echo "Cannot patch a USB stick which has already been patched."
    echo "Ideally run createinstallmedia again, or at least run unpatch.sh"
    echo "first."
    echo
    echo "Patcher cannot continue and will now exit."
    exit 1
fi


# Patch com.apple.Boot.plist
echo 'Patching com.apple.Boot.plist (thanks to jackluke)...'
# It would seem more obvious to do mv then cp, but doing cp then cat lets us
# use cat as a permissions-preserving Unix trick, just to be extra cautious.
if [ ! -e "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist.original" ]
then
    cp "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist" "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist.original"
fi
cat payloads/com.apple.Boot.plist > "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist"

# Copy the shell scripts into place so that they may be used once the
# USB stick is booted.
echo 'Adding shell scripts...'
cp -f payloads/*.sh "$VOLUME"

# Copy Hax dylibs into place
echo "Adding Hax dylibs..."
cp -f payloads/ASentientBot-Hax/Hax*.dylib "$VOLUME"

# Not sure if this is actually necessary, but let's play it safe and ensure
# the shell scripts are executable.
chmod u+x "$VOLUME"/*.sh
# Same for the dylib
chmod u+x "$VOLUME"/Hax*.dylib

echo 'Adding kexts...'
cp -f payloads/*.kext.zip "$VOLUME"

# Save a file onto the USB stick that says what patcher & version was used,
# so it can be identified later (e.g. for troubleshooting purposes).
echo 'Saving patcher version info...'
echo "$VERSION" > "$VOLUME/Patch-Version.txt"

echo
echo 'Syncing.'
sync

echo
echo 'Micropatcher finished.'
