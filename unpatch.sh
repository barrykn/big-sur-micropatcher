#!/bin/bash
VERSIONNUM="0.0.2pre"
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
VOLUME='/Volumes/Install macOS Beta'

# A couple of quick sanity checks before we begin.
if [ ! -d "$VOLUME/Install macOS Beta.app" ]
then
    echo "Failed to properly locate Big Sur recovery USB stick for unpatching."
    echo
    echo "Patcher cannot continue and will now exit."
    exit 1
fi


# Undo the boot-time compatibility check patch
mv "$VOLUME/System/Library/CoreServices/PlatformSupport.plist.inactive" \
   "$VOLUME/System/Library/CoreServices/PlatformSupport.plist"

# Delete the shell scripts, patcher version info, and dylibs
rm "$VOLUME"/*.sh "$VOLUME/Patch-Version.txt"

echo 'Unpatcher finished.'
echo 'Remember to manually delete any Hax dylibs on your USB stick, if you'
echo 'are not immediately repatching.'
