#!/bin/bash
VERSIONNUM="0.0.2pre"
VERSION="BarryKN Big Sur Micropatcher v$VERSIONNUM"

echo $VERSION
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


# Patch out the boot-time compatibility check
echo 'Patching boot-time compatibility check (thanks to jackluke)...'
mv "$VOLUME/System/Library/CoreServices/PlatformSupport.plist" \
   "$VOLUME/System/Library/CoreServices/PlatformSupport.plist.inactive"

# Copy the shell scripts into place so that they may be used once the
# USB stick is booted.
echo 'Adding shell scripts...'
cp -f payloads/*.sh "$VOLUME"

# Not sure if this is actually necessary, but let's play it safe and ensure
# the shell scripts are executable.
chmod u+x "$VOLUME"/*.sh

# Save a file onto the USB stick that says what patcher & version was used,
# so it can be identified later (e.g. for troubleshooting purposes).
echo 'Saving patcher version info...'
echo "$VERSION" > "$VOLUME/Patch-Version.txt"

echo
echo 'Micropatcher finished.'


# Finally, if necessary, remind the user of the last step that's needed
# before the USB stick will actually be usable -- installation of a dylib
# from ASentientBot.
if [ ! -e "$VOLUME/Hax2Lib.dylib" ] && [ ! -e "$VOLUME/Hax.dylib" ]
then
    echo "Remember to copy one of ASentientBot's Hax dylibs, either Hax.dylib"
    echo "or Hax2Lib.dylib, onto your USB stick!"
fi
