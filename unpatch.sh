#!/bin/bash

stty -echo

# For this script, root permissions are vital.
if [ "$EUID" -ne 0 ]
  then
    echo "Please note, that the unpatcher requires root privileges to remove the patch using this script."
    echo "Restarting with root privileges"
    exec sudo "$0" "$@"
fi

echo 'Unpatcher starting. If this fails, try recreating the installer USB using'
echo 'createinstallmedia.'
echo

# Check for --no-sync option
if [ "x$1" = "x--no-sync" ]
then
    SKIP_SYNC="YES"
    shift
fi

# Allow the user to drag-and-drop the USB stick in Terminal, to specify the
# path to the USB stick in question. (Otherwise it will try hardcoded paths
# for a presumed Big Sur Golden Master/public release, beta 2-or-later,
# and beta 1, in that order.)
if [ -z "$1" ]
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
        echo "Failed to locate Big Sur recovery USB stick for unpatching."
        echo "If all else fails, try specifying the path to the USB stick"
        echo "as a command line parameter to this script."
        echo
        echo "Unpatcher cannot continue and will now exit."
        stty echo
        exit 1
    fi
else
    VOLUME="$1"
    # The use of `echo` here is to force globbing.
    APPPATH=`echo -n "$VOLUME"/Install\ macOS*.app`
    if [ ! -d "$APPPATH" ]
    then
        echo "Failed to locate Big Sur recovery USB stick for unpatching."
        echo "Make sure you specified the correct volume. You may also try"
        echo "not specifying a volume and allowing the unpatcher to find"
        echo "the volume itself."
        echo
        echo "Unpatcher cannot continue and will now exit."
        stty echo
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
    echo 'Boot-time compatibility check patch not present; continuing.'
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
if [ -d "$APPPATH/Contents/MacOS/InstallAssistant.app" ]
then
    echo 'Removing trampoline.'
    TEMPAPP="$VOLUME/tmp.app"
    mv -f "$APPPATH/Contents/MacOS/InstallAssistant.app" "$TEMPAPP"
    rm -rf "$APPPATH"
    mv -f "$TEMPAPP" "$APPPATH"
else
    echo 'Looked for trampoline (v0.2.0+) but trampoline is not present. Continuing...'
fi

echo 'Removing kexts, shell scripts, patcher version info, etc.'
# For v0.0.9 and earlier
rm -rf "$VOLUME"/*.kext
rm -f "$VOLUME"/*.kext.zip
# For v0.0.10 and later
rm -rf "$VOLUME"/kexts
# For v0.3.3 and later
rm -f "$VOLUME"/kmutil*
# For v0.4.2 and later
rm -f "$VOLUME"/bless*
# For v0.4.5pre
rm -f "$VOLUME"/patch.*
# For v0.5.0 and later
rm -rf "$VOLUME"/bin
# For all versions
rm -f "$VOLUME"/*.sh "$VOLUME/Patch-Version.txt"

echo 'Remvoing Hax dylibs...'
rm -f "$VOLUME"/Hax*.dylib
rm -rf "$VOLUME"/Hax*.app

if [ "x$SKIP_SYNC" != "xYES" ]
then
    echo
    echo 'Syncing.'
    sync
fi

echo
echo 'Unpatcher finished.'
stty echo
exit 0
