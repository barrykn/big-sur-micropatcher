#!/bin/bash
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
        echo
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

if [ -z "$1" ]
then
    echo "Please drag-and-drop this script, then an update zip file, into Terminal,"
    echo "then press Enter/Return."
    exit 1
fi

if [ ! -e "$1" ]
then
    echo "Update zip file does not appear to exist."
    exit 1
fi

UPDATEZIP="$1"

# FIXME: The following comment needs an update.
#
# Allow the user to drag-and-drop the USB stick in Terminal, to specify the
# path to the USB stick in question. (Otherwise it will try hardcoded paths
# for a presumed Big Sur Golden Master/public release, beta 2-or-later,
# and beta 1, in that order.)
if [ -z "$2" ]
then
    for x in "Install macOS Big Sur" "Install macOS Big Sur Beta" "Install macOS Beta"
    do
        if [ -d "/Volumes/$x/$x.app" ]
        then
            VOLUME="/Volumes/$x"
            APPPATH="$VOLUME/$x.app"
            break
        fi
    done

    if [ ! -d "$APPPATH" ]
    then
        echo "Failed to locate Big Sur recovery USB stick."
        echo "Remember to create it using createinstallmedia, and do not rename it."
        echo "If all else fails, try specifying the path to the USB stick"
        echo "as a command line parameter to this script."
        echo
        echo "Patcher cannot continue and will now exit."
        exit 1
    fi
else
    VOLUME="$2"
    # The use of `echo` here is to force globbing.
    APPPATH=`echo -n "$VOLUME"/Install\ macOS*.app`
    if [ ! -d "$APPPATH" ]
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

# FIXME: Consider if this check is necessary or desirable.
#
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

# FIXME: I may need to add an access check for the zip file.
#
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
        echo 'Access check failed.'
        tccutil reset All com.apple.Terminal
        echo 'Retrying access check...'
        if ! checkDirAccess
        then
            echo
            echo 'Access check failed again. Giving up.'
            echo 'Next time, please give Terminal permission to access removable drives,'
            echo 'as well as the location where this patcher is stored (for example, Downloads).'
            exit 1
        else
            echo 'Access check succeeded on second attempt.'
            echo
        fi
    else
        echo 'Access check succeeded.'
        echo
    fi
fi

echo "Updating BaseSystem. This may take a while."
pushd "$VOLUME"
mv -f BaseSystem BaseSystem.original
mkdir BaseSystem
cd BaseSystem
unzip -j "$UPDATEZIP" AssetData/Restore/BaseSystem.\*

echo
echo "Copying update zip onto USB stick. This may take a long while."
cd ..
rm -rf update-zip
mkdir update-zip
cd update-zip
cp "$UPDATEZIP" .

echo
echo 'Syncing.'
sync

echo
echo "Verifying update zip file. This may take a while."
unzip -tq *.zip

if [ $? -ne 0 ]
then
    echo "Unfortunately, update zip verification failed."
    exit 1
fi

echo
echo 'Update zip added to patched USB stick.'
