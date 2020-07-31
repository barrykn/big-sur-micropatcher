#!/bin/bash
VERSIONNUM="0.0.18pre"
VERSION="BarryKN Big Sur Micropatcher v$VERSIONNUM"

echo $VERSION
echo 'Thanks to jackluke, ASentientBot, highvoltage12v, testheit, and'
echo 'ParrotGeek for their hard work to get Big Sur running on unsupported'
echo 'Macs! (See the README for more information.)'
# Add a blank line of output to make things easier on the eyes.
echo

# Allow the user to drag-and-drop the USB stick in Terminal, to specify the
# path to the USB stick in question. (Otherwise it will try a hardcoded path
# for beta 2 and up, followed by a hardcoded path for beta 1.)
if [ -z "$1" ]
then
    VOLUME='/Volumes/Install macOS Big Sur Beta'
    if [ ! -d "$VOLUME/Install macOS Big Sur Beta.app" ]
    then
        # Check for beta 1 before giving up
        VOLUME='/Volumes/Install macOS Beta'
        if [ ! -d "$VOLUME/Install macOS Beta.app" ]
        then
            echo "Failed to locate Big Sur recovery USB stick."
            echo Remember to create it using createinstallmedia, and do not rename it.
            echo "If all else fails, try specifying the path to the USB stick"
            echo "as a command line parameter to this script."
            echo
            echo "Patcher cannot continue and will now exit."
            exit 1
        fi
    fi
else
    VOLUME="$1"
    if [ ! -d "$VOLUME/Install macOS"*.app ]
    then
        echo "Failed to locate Big Sur recovery USB stick for patching."
        echo "Make sure you specified the correct volume. You may also try"
        echo "not specifying a volume and allowing the patcher to find"
        echo "the volume itself."
        echo
        echo "Patcher cannot continue and will now exit."
        exit 1
    fi
fi

# Check if the payloads directory is inside the current directory. If not,
# it's probably inside the same directory as this script, so find that
# directory.
if [ ! -d payloads ]
then
    BASEDIR="`echo $0|sed -E 's@/[^/]*$@@'`"
    [ -z "$BASEDIR" ] || cd "$BASEDIR"
fi

# Check again in case we changed directory after the first check
if [ ! -d payloads ]
then
    echo '"payloads" folder was not found.'
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
echo 'Patching com.apple.Boot.plist...'
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
# Same for the dylibs
chmod u+x "$VOLUME"/Hax*.dylib

echo 'Adding kexts...'
cp -rf payloads/kexts "$VOLUME"

# Save a file onto the USB stick that says what patcher & version was used,
# so it can be identified later (e.g. for troubleshooting purposes).
echo 'Saving patcher version info...'
echo "$VERSION" > "$VOLUME/Patch-Version.txt"

echo
echo 'Syncing.'
sync

echo
echo 'Micropatcher finished.'
