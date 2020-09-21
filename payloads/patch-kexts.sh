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
    if ! csrutil status | grep -q 'disabled.$'
    then
        MUSTEXIT="YES"
        csrutil status
    fi

    if ! csrutil authenticated-root status | grep -q 'disabled$'
    then
        MUSTEXIT="YES"
        csrutil authenticated-root status
    fi

    if [ "x$MUSTEXIT" = "xYES" ]
    then
        echo "Please boot from the patched Big Sur installer USB and run the"
        echo "following command in Terminal to fix this:"
        echo "/Volumes/Image\ Volume/set-vars.sh"
        echo "(or boot from the installer USB and fix it yourself)"
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


# See if there's an option on the command line. If so, put it into OPT.
if echo "$1" | grep -q '^--'
then
    OPT="$1"
    shift
fi

# Figure out which kexts we're installing and where we're installing
# them to.
if [ "x$OPT" = "x--2011-no-wifi" ]
then
    INSTALL_WIFI="NO"
    INSTALL_HDA="YES"
    INSTALL_HD3000="YES"
    INSTALL_LEGACY_USB="YES"
    INSTALL_BCM5701="YES"
    echo 'Installing AppleHDA, HD3000, and LegacyUSBInjector to:'
elif [ "x$OPT" = "x--2011" ]
then
    INSTALL_WIFI="YES"
    INSTALL_HDA="YES"
    INSTALL_HD3000="YES"
    INSTALL_LEGACY_USB="YES"
    INSTALL_BCM5701="YES"
    echo 'Installing IO80211Family, AppleHDA, HD3000, and LegacyUSBInjector to:'
elif [ "x$OPT" = "x--all" ]
then
    INSTALL_WIFI="YES"
    INSTALL_HDA="YES"
    INSTALL_HD3000="YES"
    INSTALL_LEGACY_USB="YES"
    INSTALL_GFTESLA="YES"
    INSTALL_NVENET="YES"
    INSTALL_BCM5701="YES"
    DEACTIVATE_TELEMETRY="YES"
    echo 'Installing all kext patches to:'
elif [ "x$OPT" = "x--hda" ]
then
    INSTALL_WIFI="YES"
    INSTALL_HDA="YES"
    INSTALL_HD3000="NO"
    echo 'Installing IO80211Family and AppleHDA to:'
else
    INSTALL_WIFI="YES"
    INSTALL_HDA="NO"
    INSTALL_HD3000="NO"
    echo 'Installing IO80211Family to:'
fi

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
    echo 'Installing highvoltage12v patched IO80211Family.kext'
    if [ -d IO80211Family.kext.original ]
    then
        rm -rf IO80211Family.kext
    else
        mv IO80211Family.kext IO80211Family.kext.original
    fi

    unzip -q "$IMGVOL/kexts/IO80211Family-highvoltage12v.kext.zip"
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

    unzip -q "$IMGVOL/kexts/AppleHDA-17G14019.kext.zip"
    chown -R 0:0 AppleHDA.kext
    chmod -R 755 AppleHDA.kext
fi

if [ "x$INSTALL_HD3000" = "xYES" ]
then
    echo 'Installing High Sierra Intel HD 3000 kexts'
    rm -rf AppleIntelHD3000* AppleIntelSNB*

    unzip -q "$IMGVOL/kexts/HD3000-17G14019.zip"
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

    unzip -q "$IMGVOL/kexts/GeForceTesla-17G14019.zip"
    unzip -q "$IMGVOL/kexts/NVDANV50HalTesla-17G14019.kext.zip"

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
    unzip -q "$IMGVOL/kexts/nvenet-17G14019.kext.zip"
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

        unzip -q "$IMGVOL/kexts/AppleBCM5701Ethernet-19G73.kext.zip"
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

# If $VOLUME = "/" at this point in the script, then we are running in a
# live installation and the system volume is not booted from a snapshot.
# Otherwise, assume snapshot booting is configured and use bless to create
# a new snapshot. (This behavior can be refined in a future release...)
if [ "$VOLUME" != "/" ]
then
    echo 'Creating new root snapshot.'
    bless --folder "$VOLUME"/System/Library/CoreServices --bootefi --create-snapshot --setBoot
else
    echo 'Booted directly from volume, so skipping snapshot creation.'
fi

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
