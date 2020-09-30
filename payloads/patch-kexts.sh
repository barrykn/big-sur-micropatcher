#!/bin/bash

### begin function definitions ###
# There's only one function for now, but there will probably be more
# in the future.

# Check for errors, and handle any errors appropriately, after any kmutil
# invocation.
kmutilErrorCheck() {
    if [ $? -ne 0 ]
    then
        echo 'kmutil failed. See above output for more information.'
        echo 'patch-kexts.sh cannot continue.'
        exit 1
    fi
}

### end function definitions ###

# Make sure this script is running as root, otherwise use sudo to try again
# as root.
[ $UID = 0 ] || exec sudo "$0" "$@"

IMGVOL="/Volumes/Image Volume"
if [ -d "$IMGVOL" ]
then
    RECOVERY="YES"
else
    RECOVERY="NO"
    # Not in the recovery environment, so we need a different path to the
    # patched USB.
    if [ -d "/Volumes/Install macOS Big Sur Beta" ]
    then
        IMGVOL="/Volumes/Install macOS Big Sur Beta"
    else
        # if this is inaccurate, there's an error check in the next top-level
        # if-then block which will catch it and do the right thing
        IMGVOL="/Volumes/Install macOS Beta"
    fi

    # While we're at it, we need to check SIP & authenticated-root
    # (both need to be disabled)
    if ! nvram csr-active-config | grep -q 'w%0[89]%00%00$'
    then
        echo csr-active-config appears to be set incorrectly:
        nvram csr-active-config
        echo
        echo "To fix this, please boot the setvars EFI utility, then boot back into macOS"
        echo "and try again."
        exit 1
    fi
fi

# Now that $IMGVOL has hopefully been corrected, check again.
if [ ! -d "$IMGVOL" ]
then
    echo "You must run this script from a patched macOS Big Sur"
    echo "installer USB."
    exit 1
fi


# Check for command line options.
while [[ $1 = --* ]]
do
    case $1 in
        --create-snapshot)
            SNAPSHOT=YES
            ;;
        --no-create-snapshot)
            SNAPSHOT=NO
            ;;
        --no-wifi)
            echo "Disabling WiFi patch (--no-wifi command line option)"
            INSTALL_WIFI=NO
            ;;
        --2009)
            echo "--2009 specified; using equivalent --2010 mode."
            PATCHMODE=--2010
            ;;
        --2010)
            echo "Using --2010 mode."
            PATCHMODE=--2010
            ;;
        --2011)
            echo "Using --2011 mode."
            PATCHMODE=--2011
            ;;
        --2012)
            echo "Using --2012 mode."
            PATCHMODE=--2012
            ;;
        --2013)
            echo "--2013 specified; using equivalent --2012 mode."
            PATCHMODE=--2012
            ;;
        *)
            echo "Unknown command line option: $1"
            exit 1
            ;;
    esac

    shift
done

# If no mode option on command line, default to --2012 for now.
# (Later I'll add automatic detection of Mac model.)
if [ -z "$PATCHMODE" ]
then
    echo "No patch mode specified on command line; defaulting to --2012."
    PATCHMODE=--2012
fi

# Figure out which kexts we're installing.
# (There is some duplication of code below, but this will make it easier
# to use different WiFi patches on different models later.)

case $PATCHMODE in
    --2010)
        [ -z "$INSTALL_WIFI" ] && INSTALL_WIFI="YES"
        INSTALL_HDA="YES"
        INSTALL_HD3000="YES"
        INSTALL_LEGACY_USB="YES"
        INSTALL_GFTESLA="YES"
        INSTALL_NVENET="YES"
        INSTALL_BCM5701="YES"
        DEACTIVATE_TELEMETRY="YES"
        ;;
    --2011)
        [ -z "$INSTALL_WIFI" ] && INSTALL_WIFI="YES"
        INSTALL_HDA="YES"
        INSTALL_HD3000="YES"
        INSTALL_LEGACY_USB="YES"
        INSTALL_BCM5701="YES"
        ;;
    --2012)
        [ -z "$INSTALL_WIFI" ] && INSTALL_WIFI="YES"
        if [ "$INSTALL_WIFI" = "NO" ]
        then
            echo "Attempting --2012 mode without WiFi, which means no patch will be installed."
            echo "Exiting."
            exit 2
        fi
        ;;
    *)
        echo "patch-kexts.sh has encountered an internal error while attempting to"
        echo "determine patch mode. This is a patcher bug."
        echo
        echo "patch-kexts.sh cannot continue."
        exit 1
        ;;
esac

# Now figure out what volume we're installing to.
VOLUME="$1"

if [ -z "$VOLUME" ]
then
    if [ "x$RECOVERY" = "xYES" ]
    then
        # Make sure a volume has been specified. (Without this, other error
        # checks eventually kick in, but the error messages get confusing.)
        echo 'You must specify a target volume (such as /Volumes/Macintosh\ HD)'
        echo 'on the command line.'
        exit 1
    else
        # Running under live installation, so use / as default
        VOLUME="/"
    fi
fi

echo 'Installing kexts to:'
echo "$VOLUME"
echo

# Sanity checks to make sure that the specified $VOLUME isn't an obvious mistake

# First, make sure the volume exists. (If it doesn't exist, the next check
# will fail anyway, but having a separate check for this case might make
# troubleshooting easier.
if [ ! -d "$VOLUME" ]
then
    echo "Unable to find the volume."
    echo "Cannot proceed. Make sure you specified the correct volume."
    exit 1
fi

# Next, check that the volume has /System/Library/Extensions (i.e. make sure
# it's actually the system volume and not the data volume or something).
# DO NOT check for /System/Library/CoreServices here, or Big Sur data drives
# as well as system drives will pass the check!
if [ ! -d "$VOLUME/System/Library/Extensions" ]
then
    echo "Unable to find /System/Library/Extensions on the volume."
    echo "Cannot proceed. Make sure you specified the correct volume."
    echo "(Make sure to specify the system volume, not the data volume.)"
    exit 1
fi

# Check that the $VOLUME has macOS build 20*.
SVPL="$VOLUME"/System/Library/CoreServices/SystemVersion.plist
SVPL_VER=`fgrep '<string>10' "$SVPL" | sed -e 's@^.*<string>10@10@' -e 's@</string>@@' | uniq -d`
SVPL_BUILD=`grep '<string>[0-9][0-9][A-Z]' "$SVPL" | sed -e 's@^.*<string>@@' -e 's@</string>@@'`

if echo $SVPL_BUILD | grep -q '^20'
then
    echo -n "Volume appears to have a Big Sur installation (build" $SVPL_BUILD
    echo "). Continuing."
else
    if [ -z "$SVPL_VER" ]
    then
        echo 'Unable to detect macOS version on volume. Make sure you chose'
        echo 'the correct volume. Or, perhaps a newer patcher is required.'
    else
        echo 'Volume appears to have an older version of macOS. Probably'
        echo 'version' "$SVPL_VER" "build" "$SVPL_BUILD"
        echo 'Please make sure you specified the correct volume.'
    fi

    exit 1
fi

# Check whether the mounted device is actually the underlying volume,
# or if it is a mounted snapshot.
DEVICE=`df "$VOLUME" | tail -1 | sed -e 's@ .*@@'`
echo 'Volume is mounted from device: ' $DEVICE

POPSLICE=`echo $DEVICE | sed -E 's@s[0-9]+$@@'`
POPSLICE2=`echo $POPSLICE | sed -E 's@s[0-9]+$@@'`

if [ $POPSLICE = $POPSLICE2 ]
then
    WASSNAPSHOT="NO"
    echo 'Mounted device is an actual volume, not a snapshot. Proceeding.'
else
    WASSNAPSHOT="YES"
    VOLUME=`mktemp -d`
    echo "Mounted device is a snapshot. Will now mount underlying volume"
    echo "from device $POPSLICE at temporary mountpoint:"
    echo "$VOLUME"
    # Blank line for legibility
    echo
    if ! mount -o nobrowse -t apfs "$POPSLICE" "$VOLUME"
    then
        echo 'Mounting underlying volume failed. Cannot proceed.'
        exit 1
    fi
fi

if [ "x$RECOVERY" = "xYES" ]
then
    # It's likely that at least one of these was reenabled during installation.
    # But as we're in the recovery environment, there's no need to check --
    # we'll just redisable these. If they're already disabled, then there's
    # no harm done.
    csrutil disable
    csrutil authenticated-root disable
fi

if [ "x$WASSNAPSHOT" = "xNO" ]
then
    echo "Remounting volume as read-write..."
    if ! mount -uw "$VOLUME"
    then
        echo "Remount failed. Kext installation cannot proceed."
        exit 1
    fi
fi

# Move the old kext out of the way, or delete if needed. Then unzip the
# replacement.
pushd "$VOLUME/System/Library/Extensions" > /dev/null

if [ "x$INSTALL_WIFI" = "xYES" ]
then
    echo 'Installing patched IO80211Family.kext'
    if [ -d IO80211Family.kext.original ]
    then
        rm -rf IO80211Family.kext
    else
        mv IO80211Family.kext IO80211Family.kext.original
    fi

    # Uncomment this line for the old highvoltage12v patch
    #unzip -q "$IMGVOL/kexts/IO80211Family-highvoltage12v-old.kext.zip"

    # Uncomment this line for the new highvoltage12v patch
    #unzip -q "$IMGVOL/kexts/IO80211Family-highvoltage12v-new.kext.zip"

    # Comment out the next *4* lines if uncommenting either of the above
    # lines for highvoltage12v.
    unzip -q "$IMGVOL/kexts/IO80211Family-18G6032.kext.zip"
    pushd IO80211Family.kext/Contents/Plugins > /dev/null
    unzip -q "$IMGVOL/kexts/AirPortAtheros40-17G14033+pciid.kext.zip"
    popd > /dev/null

    # The next line is really only here for the highvoltage12v zip
    # files, but it does no harm in other cases.
    rm -rf __MACOSX
    chown -R 0:0 IO80211Family.kext
    chmod -R 755 IO80211Family.kext
fi

if [ "x$INSTALL_HDA" = "xYES" ]
then
    echo 'Installing High Sierra AppleHDA.kext'
    if [ -d AppleHDA.kext.original ]
    then
        rm -rf AppleHDA.kext
    else
        mv AppleHDA.kext AppleHDA.kext.original
    fi

    unzip -q "$IMGVOL/kexts/AppleHDA-17G14033.kext.zip"
    chown -R 0:0 AppleHDA.kext
    chmod -R 755 AppleHDA.kext
fi

if [ "x$INSTALL_HD3000" = "xYES" ]
then
    echo 'Installing High Sierra Intel HD 3000 kexts'
    rm -rf AppleIntelHD3000* AppleIntelSNB*

    unzip -q "$IMGVOL/kexts/HD3000-17G14033.zip"
    chown -R 0:0 AppleIntelHD3000* AppleIntelSNB*
    chmod -R 755 AppleIntelHD3000* AppleIntelSNB*
fi

if [ "x$INSTALL_LEGACY_USB" = "xYES" ]
then
    echo 'Installing LegacyUSBInjector.kext'
    rm -rf LegacyUSBInjector.kext

    unzip -q "$IMGVOL/kexts/LegacyUSBInjector.kext.zip"
    chown -R 0:0 LegacyUSBInjector.kext
    chmod -R 755 LegacyUSBInjector.kext

    # parameter for kmutil later on
    BUNDLE_PATH="--bundle-path /System/Library/Extensions/LegacyUSBInjector.kext"
fi

if [ "x$INSTALL_GFTESLA" = "xYES" ]
then
    echo 'Installing GeForce Tesla (9400M/320M) kexts'
    rm -rf *Tesla*

    unzip -q "$IMGVOL/kexts/GeForceTesla-17G14033.zip"
    unzip -q "$IMGVOL/kexts/NVDANV50HalTesla-17G14033.kext.zip"

    unzip -q "$IMGVOL/kexts/NVDAResmanTesla-ASentientBot.kext.zip"
    rm -rf __MACOSX

    chown -R 0:0 *Tesla*
    chmod -R 755 *Tesla*
fi

if [ "x$INSTALL_NVENET" = "xYES" ]
then
    echo 'Installing High Sierra nvenet.kext'
    pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null
    rm -rf nvenet.kext
    unzip -q "$IMGVOL/kexts/nvenet-17G14033.kext.zip"
    chown -R 0:0 nvenet.kext
    chmod -R 755 nvenet.kext
    popd > /dev/null
fi

if [ "x$INSTALL_BCM5701" = "xYES" ]
then
    case $SVPL_BUILD in
    20A4*)
        # skip this on Big Sur dev beta 1 and 2
        ;;
    *)
        echo 'Installing Catalina AppleBCM5701Ethernet.kext'
        pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null

        if [ -d AppleBCM5701Ethernet.kext.original ]
        then
            rm -rf AppleBCM5701Ethernet.kext
        else
            mv AppleBCM5701Ethernet.kext AppleBCM5701Ethernet.kext.original
        fi

        unzip -q "$IMGVOL/kexts/AppleBCM5701Ethernet-19H2.kext.zip"
        chown -R 0:0 AppleBCM5701Ethernet.kext
        chmod -R 755 AppleBCM5701Ethernet.kext

        popd > /dev/null
        ;;
    esac
fi

popd > /dev/null

if [ "x$DEACTIVATE_TELEMETRY" = "xYES" ]
then
    echo 'Deactivating com.apple.telemetry.plugin'
    pushd "$VOLUME/System/Library/UserEventPlugins" > /dev/null
    mv -f com.apple.telemetry.plugin com.apple.telemetry.plugin.disabled
    popd > /dev/null
fi

# Need to back up the original KernelCollections before we modify them.
# This is necessary for unpatch-kexts.sh to be able to accomodate
# the type of filesystem verification that is done by Apple's delta updaters.
echo "Checking for KernelCollections backup..."
pushd "$VOLUME/System/Library/KernelCollections" > /dev/null

BACKUP_FILE_BASE="KernelCollections-$SVPL_BUILD.tar"
BACKUP_FILE="$BACKUP_FILE_BASE".lz4
#BACKUP_FILE="$BACKUP_FILE_BASE".lzfse
#BACKUP_FILE="$BACKUP_FILE_BASE".zst

if [ -e "$BACKUP_FILE" ]
then
    echo "Backup found, so not overwriting."
else
    echo "Backup not found. Performing backup now. This may take a few minutes."
    echo "Backing up original KernelCollections to:"
    echo `pwd`/"$BACKUP_FILE"
    tar cv *.kc | "$VOLUME/usr/bin/compression_tool" -encode -a lz4 > "$BACKUP_FILE"
    #tar cv *.kc | "$VOLUME/usr/bin/compression_tool" -encode > "$BACKUP_FILE"
    #tar c *.kc | "$IMGVOL/zstd" --long --adapt=min=0,max=19 -T0 -v > "$BACKUP_FILE"
fi
popd > /dev/null

# Update the kernel/kext collections.
# kmutil *must* be invoked separately for boot and system KCs when
# LegacyUSBInjector is being used, or the injector gets left out, at least
# as of Big Sur beta 2. So, we'll always do it that way (even without
# LegacyUSBInjector, it shouldn't do any harm).
#
# I suspect it's not supposed to require the chroot, but I was getting weird
# "invalid argument" errors, and chrooting it eliminated those errors.
# BTW, kmutil defaults to "--volume-root /" according to the manpage, so
# it's probably redundant, but whatever.
echo 'Using kmutil to rebuild boot collection...'
chroot "$VOLUME" kmutil create -n boot \
    --kernel /System/Library/Kernels/kernel \
    --variant-suffix release --volume-root / $BUNDLE_PATH \
    --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
kmutilErrorCheck

# When creating SystemKernelExtensions.kc, kmutil requires *both* --boot-path
# and --system-path!
echo 'Using kmutil to rebuild system collection...'
chroot "$VOLUME" kmutil create -n sys \
    --kernel /System/Library/Kernels/kernel \
    --variant-suffix release --volume-root / \
    --system-path /System/Library/KernelCollections/SystemKernelExtensions.kc \
    --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
kmutilErrorCheck

# The way you control kcditto's *destination* is by choosing which volume
# you run it *from*. I'm serious. Read the kcditto manpage carefully if you
# don't believe me!
"$VOLUME/usr/sbin/kcditto"

# First, check if there was a snapshot-related command line option.
# If not, pick a default as follows:
#
# If $VOLUME = "/" at this point in the script, then we are running in a
# live installation and the system volume is not booted from a snapshot.
# Otherwise, assume snapshot booting is configured and use bless to create
# a new snapshot.
if [ -z "$SNAPSHOT" ]
then
    if [ "$VOLUME" != "/" ]
    then
        SNAPSHOT=YES
        CREATE_SNAPSHOT="--create-snapshot"
        echo 'Creating new root snapshot.'
    else
        SNAPSHOT=NO
        echo 'Booted directly from volume, so skipping snapshot creation.'
    fi
elif [ SNAPSHOT = YES ]
    CREATE_SNAPSHOT="--create-snapshot"
    echo 'Creating new root snapshot due to command line option.'
else
    echo 'Skipping creation of root snapshot due to command line option.'
fi

# Get the volume label and supply it to bless, to work around the
# Big Sur bug where everything gets called "EFI Boot".
VOLLABEL=`diskutil info -plist "$VOLUME" | fgrep -A1 '<key>VolumeName</key>'|tail -1|sed -e 's+^.*<string>++' -e 's+</string>$++'`

# Now run bless
bless --folder "$VOLUME"/System/Library/CoreServices --label "$VOLLABEL" $CREATE_SNAPSHOT --setBoot

# Try to unmount the underlying volume if it was mounted by this script.
# (Otherwise, trying to run this script again without rebooting causes
# errors when this script tries to mount the underlying volume a second
# time.)
if [ "x$WASSNAPSHOT" = "xYES" ]
then
    echo "Attempting to unmount underlying volume (don't worry if this fails)."
    echo "This may take a minute or two."
    umount "$VOLUME" || diskutil unmount "$VOLUME"
fi

echo 'Installed patch kexts successfully.'
