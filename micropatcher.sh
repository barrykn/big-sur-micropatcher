#!/bin/bash
VERSIONNUM="0.0.21pre"
VERSION="BarryKN Big Sur Micropatcher v$VERSIONNUM"

### begin function definitions ###

# Handle permissions failure that happened during a copy (cp). This has
# usually been due to the user needing root permissions for some reason.
# (It used to be possible to hit this code path for other reasons, but
# I believe I have fixed that now.)
handleCopyPermissionsFailure() {
    if [ $UID != 0 ]
    then
        echo 'cp failed. Probably a permissions error. This is not expected, but'
        echo 'patcher will attempt workaround by trying again as root.'
        exec sudo "$0" "$@"
    else
        echo 'cp failed, even as root. This is unexpected.'
        echo 'Patcher cannot continue.'
        exit 1
    fi
}

# Check that we can access the directory that ocntains this script, as well
# as the root directory of the installer USB. Access to both of these
# directories is vital, and Catalina's TCC controls for Terminal are
# capable of blocking both. Therefore we must check access to both
# directories before proceeding.
checkDirAccess() {
    # List the two directories, but direct both stdout and stderr to
    # /dev/null. We are only interested in the return code.
    ls "$VOLUME" . &> /dev/null
}

### end function definitions ###

echo $VERSION
echo 'Thanks to jackluke, ASentientBot, highvoltage12v, testheit, and'
echo 'ParrotGeek for their hard work to get Big Sur running on unsupported'
echo 'Macs! (See the README for more information.)'
# Add a blank line of output to make things easier on the eyes.
echo

# Check for --force option on the command line
# (currently does nothing, but that will change in the near future)
if [ "x$1" = "x--force" ]
then
    FORCE="YES"
    shift
fi

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

# Check to make sure we can access both our own directory and the root
# directory of the USB stick. Terminal's TCC permissions in Catalina can
# prevent access to either of those two directories. However, only do this
# check on Catalina or higher. (I can add an "else" block later to handle
# Mojave and earlier, but Catalina is responsible for every single bug
# report I've received due to this script lacking necessary read permissions.)
if [ `uname -r | sed -e 's@\..*@@'` -ge 19 ]
then
    echo 'Checking read access to necessary directories...'
    if ! checkDirAccess
    then
        echo 'Access check failed. Resetting Transparency, Consent, and Control (TCC)'
        echo 'permissions for Terminal and retrying.'
        tccutil reset All com.apple.Terminal
        if ! checkDirAccess
        then
            echo 'Access check failed again. Giving up.'
            echo 'Next time, please give Terminal permissions to access removable drives,'
            echo 'as well as the location where this patcher is stored (for example, Downloads.)'
            exit 1
        else
            echo 'Access check succeeded on second attempt.'
        fi
    else
        echo 'Access check succeeded.'
    fi
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
    cp "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist" "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist.original" || handleCopyPermissionsFailure
fi
cat payloads/com.apple.Boot.plist > "$VOLUME/Library/Preferences/SystemConfiguration/com.apple.Boot.plist"

# Copy the shell scripts into place so that they may be used once the
# USB stick is booted.
echo 'Adding shell scripts...'
cp -f payloads/*.sh "$VOLUME"

# Copy Hax dylibs into place
echo "Adding Hax dylibs..."
cp -f payloads/ASentientBot-Hax/BarryKN-fork/Hax*.dylib "$VOLUME"

# Let's play it safe and ensure the shell scripts are executable.
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
