#!/bin/bash


# For this script, root permissions are vital (as this automates creating the installation medium).
[ $UID = 0 ] || exec sudo "$0" "$@"


VERSIONNUM=0.5.2
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


echo $VERSION
echo 'Thanks to jackluke, ASentientBot, highvoltage12v, testheit, and'
echo 'ParrotGeek for their hard work to get Big Sur running on unsupported'
echo 'Macs! (See the README for more information.)'
# Add a blank line of output to make things easier on the eyes.
echo


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
            echo 'Cannot continue because you did not approve permissions.'
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

read -p "Would you like to download Big Sur macOS 11.1 (20C69)? [y]: " install
printf '\e[K'

if [[ "$install" == *"y"* ]]
    then
        printf '\e[K'
        printf '\e[K'
        
            #mark="12886109321"
            #printf 'Evalulating Base System checksum...'
            #checksum=$(stat ~/Downloads/InstallAssistant.pkg | awk '{printf $2}')
                        #if [ $checksum != $mark ]

           # if [ "1" == "1" ]
                #then
                    rm -Rf ~/Downloads/InstallAssistant.pkg
                    curl http://swcdn.apple.com/content/downloads/00/55/001-86606-A_9SF1TL01U7/5duug9lar1gypwunjfl96dza0upa854qgg/InstallAssistant.pkg -o ~/Downloads/InstallAssistant.pkg 
                    printf '\e[K'
                    echo
                    printf '\e[K'
                    echo 'Installing the Install macOS Big Sur.app via InstallAssistant.pkg'
                    installer -pkg ~/Downloads/InstallAssistant.pkg -target /
                #else
                    printf "\nDownload Complete.\n"
                    
            #fi


echo

# Check for --force option on the command line
# (currently does nothing, but that will change in the near future)
if [ "x$1" = "x--force" ]
then
    FORCE="YES"
    shift
fi

# Allow the user to drag-and-drop the USB stick in Terminal, to specify the
# path to the USB stick in question. (Otherwise it will try hardcoded paths
# for a presumed Big Sur Golden Master/public release, beta 2-or-later,
# and beta 1, in that order.)
if [ -z "$1" ]
then
    VOLUME="/Volumes/$x"
    APPPATH="$VOLUME/$x.app"
    break
fi

echo "Creating installation medium on $VOLUME ..."
sudo /Applications/Install\ macOS\ Big\ Sur.app/Contents/Resources/createinstallmedia --volume "$VOLUME" --nointeraction

do
  do
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
    VOLUME="$1"
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
     echo "USB stick has already been patched. Running unpatch.sh to remove the"
     echo "existing patches before continuing."
     echo
     if ./unpatch.sh --no-sync "$VOLUME"
     then
         echo 'Patcher is now continuing.'
     else
         echo 'Unpatcher failed. Patcher cannot continue.'
         exit 1
     fi
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

# Add the trampoline.
echo 'Installing trampoline...'
TEMPAPP="$VOLUME/tmp.app"
mv -f "$APPPATH" "$TEMPAPP"
cp -r payloads/trampoline.app "$APPPATH"
mv -f "$TEMPAPP" "$APPPATH/Contents/MacOS/InstallAssistant.app"
cp "$APPPATH/Contents/MacOS/InstallAssistant" "$APPPATH/Contents/MacOS/InstallAssistant_plain"
cp "$APPPATH/Contents/MacOS/InstallAssistant" "$APPPATH/Contents/MacOS/InstallAssistant_springboard"
pushd "$APPPATH/Contents" > /dev/null
for item in `cd MacOS/InstallAssistant.app/Contents;ls -1 | fgrep -v MacOS`
do
    ln -s MacOS/InstallAssistant.app/Contents/$item .
done
popd > /dev/null
touch "$APPPATH"

# Copy the shell scripts into place so that they may be used once the
# USB stick is booted.
echo 'Copying shell scripts...'
cp -f payloads/*.sh "$VOLUME"

# Copy Hax dylibs into place
echo "Adding Hax dylibs..."
cp -f payloads/ASentientBot-Hax/BarryKN-fork/Hax*.dylib "$VOLUME"

echo 'Adding kexts and other binaries...'
cp -rf payloads/kexts payloads/bin "$VOLUME"

# Let's play it safe and ensure the shell scripts, dylibs, etc. are executable.
chmod -R u+x "$VOLUME"/*.sh "$VOLUME"/Hax*.dylib "$VOLUME"/bin

# Save a file onto the USB stick that says what patcher & version was used,
# so it can be identified later (e.g. for troubleshooting purposes).
echo 'Saving patcher version info...'
echo "$VERSION" > "$VOLUME/Patch-Version.txt"

echo
echo 'Syncing.'
sync

echo
echo 'Micropatcher finished, running install-setvars.sh.'

sudo ./install-setvars.sh "$VOLUME"

exit 0
