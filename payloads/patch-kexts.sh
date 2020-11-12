#!/bin/bash

### begin function definitions ###

# Check for errors, and handle any errors appropriately, after a command
# invocation. Takes the name of the command as its only parameter.
errorCheck() {
    if [ $? -ne 0 ]
    then
        echo "$1 failed. See above output for more information."
        echo "patch-kexts.sh cannot continue."
        exit 1
    fi
}

# In the current directory, check for kexts which have been renamed from
# *.kext to *.kext.original, then remove the new versions and rename the
# old versions back into place.
restoreOriginals() {
    if [ -n "`ls -1d *.original`" ]
    then
        for x in *.original
        do
            BASENAME=`echo $x|sed -e 's@.original@@'`
            echo 'Unpatching' $BASENAME
            rm -rf "$BASENAME"
            mv "$x" "$BASENAME"
        done
    fi
}

# Fix permissions on the specified kexts.
fixPerms() {
    chown -R 0:0 "$@"
    chmod -R 755 "$@"
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
    if [ -d "/Volumes/Install macOS Big Sur" ]
    then
        IMGVOL="/Volumes/Install macOS Big Sur"
    elif [ -d "/Volumes/Install macOS Big Sur Beta" ]
    then
        IMGVOL="/Volumes/Install macOS Big Sur Beta"
    else
        # if this is inaccurate, there's an error check in the next top-level
        # if-then block which will catch it and do the right thing
        IMGVOL="/Volumes/Install macOS Beta"
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
while [[ $1 = -* ]]
do
    case $1 in
    --create-snapshot)
        SNAPSHOT=YES
        ;;
    --no-create-snapshot)
        SNAPSHOT=NO
        ;;
    --old-kmutil)
        # More verbose error messages, so very very helpful for
        # debugging or patch development.
        echo "Using old kmutil (beta 7/8 version)."
        OLD_KMUTIL=YES
        ;;
    --un*|-u)
        echo "Uninstalling kexts (-u command line option)."
        PATCHMODE="-u"
        ;;
    --no-wifi)
        echo "Disabling WiFi patch (--no-wifi command line option)."
        INSTALL_WIFI=NO
        ;;
    --wifi=hv12v-old)
        echo "Using old highvoltage12v WiFi patch to override default."
        INSTALL_WIFI="hv12v-old"
        ;;
    --wifi=hv12v-new)
        echo "Using new highvoltage12v WiFi patch to override default."
        INSTALL_WIFI="hv12v-new"
        ;;
    --wifi=mojave-hybrid)
        echo "Using mojave-hybrid WiFi patch to override default."
        INSTALL_WIFI="mojave-hybrid"
        ;;
    --useOC)
        echo "Assuming usage of iMac 2011 with OpenCore (K610, K1100M, K2100M, AMD Polaris"
        echo "GPU)."
        IMACUSE_OC=YES
        ;;
    --force)
        FORCE=YES
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

if [ "x$RECOVERY" = "xNO" ]
then
    # Outside the recovery environment, we need to check SIP &
    # authenticated-root (both need to be disabled)
    if [ "x$FORCE" != "xYES" ]
    then
        CSRVAL="`nvram csr-active-config|sed -e 's/^.*	//'`"
        case $CSRVAL in
        w%0[89f]* | %[7f]f%0[89f]*)
            ;;
        *)
            echo csr-active-config appears to be set incorrectly:
            nvram csr-active-config
            echo
            echo "To fix this, please boot the setvars EFI utility, then boot back into macOS"
            echo "and try again. Or if you believe you are seeing this message in error, try the"
            echo '`--force` command line option.'
            exit 1
            ;;
        esac
    fi
fi

# Check if --2010 patch mode was specified on command line without a
# WiFi option in addition. If so, go ahead and use mojave-hybrid.
# (This is a situation where patch-kexts.sh is probably being used to
# patch a Big Sur installation for another older Mac, and it's very clearly
# best to err on the side of including the WiFi patch in this case.)
#
# Otherwise, if we're not unpatching and there is no WiFi option, go
# ahead and autodetect whether the WiFi patch is necessary.
if [[ "x$PATCHMODE" = "x--2010" && -z "$INSTALL_WIFI" ]]
then
    echo '--2010 patch mode was specified on command line without a WiFi option, so'
    echo 'using mojave-hybrid WiFi patch.'
    INSTALL_WIFI=mojave-hybrid
elif [[ "x$PATCHMODE" != "x-u" && -z "$INSTALL_WIFI" ]]
then
    echo "No WiFi option specified on command line, so checking for 802.11ac..."

    if [ -z "`ioreg -l | fgrep 802.11 | fgrep ac`" ]
    then
        echo "No 802.11ac WiFi card detected, so installing mojave-hybrid WiFi patch."
        INSTALL_WIFI=mojave-hybrid
    else
        echo "Found 802.11ac WiFi card, so not installing a WiFi patch."
        INSTALL_WIFI=NO
    fi
fi

# Check if patch mode was specified on command line, and if not, detect
# the Mac model and use that to choose.
if [ -z "$PATCHMODE" ]
then
    echo "No patch mode specified on command line. Detecting Mac model..."
    echo "(Use --2010, --2011, or --2012 command line option to override.)"
    MODEL=`sysctl -n hw.model`
    echo "Detected model: $MODEL"
    case $MODEL in
    # Macs which are incompatible because of pre-Penryn CPUs.
    # This script is highly unlikely to ever execute on these, but I have
    # some uncertainty about how the default case should behave, so I want
    # to catch darn near everything in a non-default case if possible.
    iMac,1|Power*|RackMac*|[0-9][0-9][0-9])
        echo "Big Sur cannot run on PowerPC Macs."
        exit 1
        ;;
    MacBookPro1,?|MacBook1,1|Macmini1,1)
        echo "Big Sur cannot run on 32-bit Macs."
        exit 1
        ;;
    MacBook[23],1|Macmini2,1|MacPro[12],1|MacBookAir1,1|MacBookPro[23],?|Xserve1,?)
        echo "This Mac has a very old Intel Core 2 CPU which cannot run Big Sur."
        exit 1
        ;;
    MacBookPro6,?)
        echo "This Mac has a 1st gen Intel Core CPU which cannot boot Big Sur."
        exit 1
        ;;
    # Macs which are not supported by Apple but supported by this patcher.
    # This currently errs on the side of blindly assuming the Mac will work.
    # (i.e. it doesn't warn about a socketed pre-Penryn CPU needing
    # replacement, or about USB problems which have not been fixed yet)
    MacBook[4-7],?|Macmini[34],1|MacBookAir[23],?|MacBookPro[457],?|MacPro3,1)
        # I may need to separate this into different patch modes later,
        # but this will do for now.
        echo "Detected a 2008-2010 Mac. Using --2010 patch mode."
        PATCHMODE=--2010
        ;;
    iMac[0-9],?|iMac10,?)
        echo "Detected a 2006-2009 iMac. Using --2010 patch mode."
        PATCHMODE=--2010
        ;;
    Macmini5,?|MacBookAir4,?|MacBookPro8,?)
        echo "Detected a 2011 Mac. Using --2011 patch mode."
        PATCHMODE=--2011
        ;;
    iMac11,?)
        echo "Detected a Late 2009 or Mid 2010 11,x iMac. Using special iMac 11,x patch mode."
        PATCHMODE=--IMAC11
        INSTALL_IMAC0910="YES"
        INSTALL_AGC="YES"
        IMACUSE_OC=YES
        ;;
    iMac12,?)
        echo "Detected a Mid 2011 12,x iMac. Using --2011 patch mode."
        PATCHMODE=--2011
        INSTALL_IMAC2011="YES"
        INSTALL_AGC="YES"
        INSTALL_MCCS="YES"
        ;;
    Macmini6,?|MacBookAir5,?|MacBookPro9,?|MacBookPro10,?|iMac13,?)
        echo "Detected a 2012-2013 Mac. Using --2012 patch mode."
        PATCHMODE=--2012
        ;;
    MacPro[45],1)
        echo "Detected a 2009-2012 Mac Pro. Using --2012 patch mode."
        PATCHMODE=--2012
        ;;
    iMac14,[123])
        echo "Detected a Late 2013 iMac. patch-kexts.sh is not necessary on this model."
        exit 1
        ;;
    # Macs which are supported by Apple and which do not need this patcher.
    # These patterns will potentially match new Mac models which do not
    # exist yet.
    iMac14,4|iMac1[5-9],?|iMac[2-9][0-9],?|iMacPro*|MacPro[6-9],?|Macmini[7-9],?|MacBook[89],1|MacBook[1-9][0-9],?|MacBookAir[6-9],?|MacBookAir[1-9][0-9],?|MacBookPro1[1-9],?)
        echo "This Mac is supported by Big Sur and does not need this patch."
        exit 1
        ;;
    # Default case. Ideally, this code will never execute.
    *)
        echo "Unknown Mac model. This may be a patcher bug, or a recent Mac model which is"
        echo "already supported by Big Sur and does not need this patch."
        exit 1
        ;;
    esac
fi

# Figure out which kexts we're installing.
case $PATCHMODE in
--IMAC11)
    INSTALL_HDA="YES"
    INSTALL_LEGACY_USB="YES"
    INSTALL_BCM5701="YES"
    ;;
--2010)
    INSTALL_HDA="YES"
    INSTALL_HD3000="YES"
    INSTALL_LEGACY_USB="YES"
    INSTALL_GFTESLA="YES"
    INSTALL_NVENET="YES"
    INSTALL_BCM5701="YES"
    DEACTIVATE_TELEMETRY="YES"
    ;;
--2011)
    INSTALL_HDA="YES"
    INSTALL_HD3000="YES"
    INSTALL_LEGACY_USB="YES"
    INSTALL_BCM5701="YES"
    ;;
--2012)
    if [ "x$INSTALL_WIFI" = "xNO" ]
    then
        echo "Attempting --2012 mode without WiFi, which means no patch will be installed."
        echo "Exiting."
        exit 2
    fi
    ;;
-u)
    # Don't need to do anything in this case-statement. Some upcoming
    # if-statements will handle it.
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

if [ "x$PATCHMODE" != "x-u" ]
then
    echo 'Installing kexts to:'
else
    echo 'Uninstalling patched kexts on volume:'
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
    #VOLUME=`mktemp -d`
    # Use the same mountpoint as Apple's own updaters. This is probably
    # more user-friendly than something randomly generated with mktemp.
    VOLUME=/System/Volumes/Update/mnt1
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
    #
    # Actually, in October 2020 it's now apparent that we need to avoid doing
    # `csrutil disable` on betas that are too old (due to a SIP change
    # that happened in either beta 7 or beta 9). So avoid it on beta 1-6.
    case $SVPL_BUILD in
    20A4[0-9][0-9][0-9][a-z] | 20A53[0-6][0-9][a-z])
        ;;
    *)
        csrutil disable
        ;;
    esac
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

if [ "x$PATCHMODE" != "x-u" ]
then
    # Need to back up the original KernelCollections before we modify them.
    # This is necessary for unpatch-kexts.sh to be able to accomodate
    # the type of filesystem verification that is done by Apple's delta
    # updaters.
    #
    # (But also need to check if there's already a backup. If there's already
    # a backup, don't do it again. It would be dangerous to overwrite a
    # backup that already exists -- the existence of the backup means
    # the KernelCollections have already been modified!
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

        # Check for errors. Print an error message *and clean up* if necessary.
        if [ $? -ne 0 ]
        then
            echo "tar or compression_tool failed. See above output for more information."

            echo "Attempting to remove incomplete backup..."
            rm -f "$BACKUP_FILE"

            echo "patch-kexts.sh cannot continue."
            exit 1
        fi
    fi
    popd > /dev/null

    # For each kext:
    # Move the old kext out of the way, or delete if needed. Then unzip the
    # replacement.
    pushd "$VOLUME/System/Library/Extensions" > /dev/null

    if [ "x$INSTALL_WIFI" != "xNO" ]
    then
        echo 'Beginning patched IO80211Family.kext installation'
        if [ -d IO80211Family.kext.original ]
        then
            rm -rf IO80211Family.kext
        else
            mv IO80211Family.kext IO80211Family.kext.original
        fi

        case $INSTALL_WIFI in
        hv12v-old)
            echo 'Installing old highvoltage12v WiFi patch'
            unzip -q "$IMGVOL/kexts/IO80211Family-highvoltage12v-old.kext.zip"
            ;;
        hv12v-new)
            echo 'Installing new highvoltage12v WiFi patch'
            unzip -q "$IMGVOL/kexts/IO80211Family-highvoltage12v-new.kext.zip"
            ;;
        mojave-hybrid)
            echo 'Installing mojave-hybrid WiFi patch'
            unzip -q "$IMGVOL/kexts/IO80211Family-18G6032.kext.zip"
            pushd IO80211Family.kext/Contents/Plugins > /dev/null
            unzip -q "$IMGVOL/kexts/AirPortAtheros40-17G14033+pciid.kext.zip"
            popd > /dev/null
            ;;
        *)
            echo 'patch-kexts.sh encountered an internal error while installing the WiFi patch.'
            echo "Invalid value for INSTALL_WIFI variable:"
            echo "INSTALL_WIFI=$INSTALL_WIFI"
            echo 'This is a patcher bug. patch-kexts.sh cannot continue.'
            exit 1
            ;;
        esac

        # The next line is really only here for the highvoltage12v zip
        # files, but it does no harm in other cases.
        rm -rf __MACOSX

        fixPerms IO80211Family.kext
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
        fixPerms AppleHDA.kext
    fi

    if [ "x$INSTALL_HD3000" = "xYES" ]
    then
        echo 'Installing High Sierra Intel HD 3000 kexts'
        rm -rf AppleIntelHD3000* AppleIntelSNB*

        unzip -q "$IMGVOL/kexts/AppleIntelHD3000Graphics.kext-17G14033.zip"
        unzip -q "$IMGVOL/kexts/AppleIntelHD3000GraphicsGA.plugin-17G14033.zip"
        unzip -q "$IMGVOL/kexts/AppleIntelHD3000GraphicsGLDriver.bundle-17G14033.zip"
        unzip -q "$IMGVOL/kexts/AppleIntelSNBGraphicsFB.kext-17G14033.zip"
        fixPerms AppleIntelHD3000* AppleIntelSNB*
    fi

    if [ "x$INSTALL_LEGACY_USB" = "xYES" ]
    then
        echo 'Installing LegacyUSBInjector.kext'
        rm -rf LegacyUSBInjector.kext

        unzip -q "$IMGVOL/kexts/LegacyUSBInjector.kext.zip"
        fixPerms LegacyUSBInjector.kext

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

        fixPerms *Tesla*
    fi

    if [ "x$INSTALL_NVENET" = "xYES" ]
    then
        echo 'Installing High Sierra nvenet.kext'
        pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null
        rm -rf nvenet.kext
        unzip -q "$IMGVOL/kexts/nvenet-17G14033.kext.zip"
        fixPerms nvenet.kext
        popd > /dev/null
    fi

    if [ "x$INSTALL_BCM5701" = "xYES" ]
    then
        case $SVPL_BUILD in
        20A4[0-9][0-9][0-9][a-z])
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
            fixPerms AppleBCM5701Ethernet.kext

            popd > /dev/null
            ;;
        esac
    fi

    if [ "x$INSTALL_MCCS" = "xYES" ]
    then
        echo 'Installing Catalina (for iMac 2011) AppleMCCSControl.kext'
        if [ -d AppleMCCSControl.kext.original ]
        then
            rm -rf AppleMCCSControl.kext
        else
            mv AppleMCCSControl.kext AppleMCCSControl.kext.original
        fi

        unzip -q "$IMGVOL/kexts/AppleMCCSControl.kext.zip"
        chown -R 0:0 AppleMCCSControl.kext
        chmod -R 755 AppleMCCSControl.kext
    fi

    #
    # install patches needed by the iMac 2011 family (metal GPU, only)
    #
    if [ "x$INSTALL_IMAC2011" = "xYES" ]
    then
        # this will any iMac 2011 need
        # install the iMacFamily extensions
        echo "Installing highvoltage12v patches for iMac 2011 family"
        echo "Using SNB and HD3000 VA bundle files"

        unzip -q "$IMGVOL/kexts/AppleIntelHD3000GraphicsVADriver.bundle-17G14033.zip"
        unzip -q "$IMGVOL/kexts/AppleIntelSNBVA.bundle-17G14033.zip"
        
        chown -R 0:0 AppleIntelHD3000* AppleIntelSNB*
        chmod -R 755 AppleIntelHD3000* AppleIntelSNB*

        # AMD=`/usr/sbin/ioreg -l | grep Baffin`
        # NVIDIA=`/usr/sbin/ioreg -l | grep NVArch`

        AMD=`chroot "$VOLUME" ioreg -l | grep Baffin`
        NVIDIA=`chroot "$VOLUME" ioreg -l | grep NVArch`
    
        if [ "$AMD" ]
        then
            echo $CARD "Polaris Card found"
            echo "Using iMacPro1,1 enabled version of AppleIntelSNBGraphicsFB.kext"
            echo "WhateverGreen and Lilu need to be injected by OpenCore"
            rm -rf AppleIntelSNBGraphicsFB.kext
            unzip -q "$IMGVOL/kexts/AppleIntelSNBGraphicsFB-AMD.kext.zip"
            # rename AppleIntelSNBGraphicsFB-AMD.kext
            mv AppleIntelSNBGraphicsFB-AMD.kext AppleIntelSNBGraphicsFB.kext
            chown -R 0:0 AppleIntelSNBGraphicsFB.kext
            chmod -R 755 AppleIntelSNBGraphicsFB.kext

        elif [ "$NVIDIA" ]
        then
            INSTALL_BACKLIGHT = "YES"
            # INSTALL_AGC="YES"

            if [ "x$IMACUSE_OC"=="xYES" ]
            then
                echo "AppleBacklightFixup, WhateverGreen and Lilu need to be injected by OpenCore"
            else
                INSTALL_BACKLIGHTFIXUP="YES"
                INSTALL_VIT9696="YES"
            fi
        else
            echo "No metal supported video card found in this system!"
            echo "Big Sur may boot, but will be barely usable due to lack of any graphics acceleration"
        fi
    fi

    #
    # install patches needed by the iMac 2009-2010 family (metal GPU, only)
    # OC has to be used in any case, assuming injection of
    # AppleBacklightFixup, FakeSMC, Lilu, WhateverGreen
    #
    if [ "x$INSTALL_IMAC0910" = "xYES" ]
    then
        AMD=`chroot "$VOLUME" ioreg -l | grep Baffin`
        NVIDIA=`chroot "$VOLUME" ioreg -l | grep NVArch`

        # AMD=`/usr/sbin/ioreg -l | grep Baffin`
        # NVIDIA=`/usr/sbin/ioreg -l | grep NVArch`
    
        if [ "$AMD" ]
        then
            echo $CARD "AMD Polaris Card found"
        elif [ "$NVIDIA" ]
        then
            INSTALL_BACKLIGHT="YES"
            # INSTALL_AGC="YES"
            echo $CARD "NVIDIA Kepler Card found"
        else
            echo "No metal supported video card found in this system!"
            echo "Big Sur may boot, but will be barely usable due to lack of any graphics acceleration"
        fi
    fi


    if [ "x$INSTALL_AGC" = "xYES" ]
    then
        # we need the original file because we do an in place Info.plist patching....
        if [ -f AppleGraphicsControl.kext.zip ]
        then
           rm -rf AppleGraphicsControl.kext
           unzip -q AppleGraphicsControl.kext.zip
           rm -rf AppleGraphicsControl.kext.zip
        else
           # create a backup using a zip archive on disk
           # could not figure out how to make a 1:1 copy of an kext folder using cp, ditto and others
           zip -q -r -X AppleGraphicsControl.kext.zip AppleGraphicsControl.kext
        fi

        echo 'Patching AppleGraphicsControl.kext with iMac 2009-2011 board-id'
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-942B59F58194171B string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-942B5BF58194151B string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-F2268DAE string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-F2238AC8 string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-F2238BAE string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        
        chown -R 0:0 AppleGraphicsControl.kext
        chmod -R 755 AppleGraphicsControl.kext
        
    fi

    if [ "x$INSTALL_AGCOLD" = "xYES" ]
    then
        if [ -d AppleGraphicsControl.kext.original ]
        then
            rm -rf AppleGraphicsControl.kext
            mv AppleGraphicsControl.kext.original AppleGraphicsControl.kext
        else
            cp -R AppleGraphicsControl.kext AppleGraphicsControl.kext.original
        fi
        
        unzip -q "$IMGVOL/kexts/AppleGraphicsControl.kext.zip"
        chown -R 0:0 AppleGraphicsControl.kext
        chmod -R 755 AppleGraphicsControl.kext
    fi

    if [ "x$INSTALL_BACKLIGHT" = "xYES" ]
    then
        echo 'Installing (for iMac NVIDIA 2009-2011) Catalina AppleBacklight.kext'
        if [ -d AppleBacklight.kext.original ]
        then
            rm -rf AppleBacklight.kext
        else
            mv AppleBacklight.kext AppleBacklight.kext.original
        fi

        unzip -q "$IMGVOL/kexts/AppleBacklight.kext.zip"
        chown -R 0:0 AppleBacklight.kext
        chmod -R 755 AppleBacklight.kext
    fi

    if [ "x$INSTALL_BACKLIGHTFIXUP" = "xYES" ]
    then
        echo 'Installing (for iMac NVIDIA 2009-2011) AppleBacklightFixup.kext'

        unzip -q "$IMGVOL/kexts/AppleBacklightFixup.kext.zip"
        chown -R 0:0 AppleBacklightFixup.kext
        chmod -R 755 AppleBacklightFixup.kext
    fi

    if [ "x$INSTALL_VIT9696" = "xYES" ]
    then
        echo 'Installing (for iMac 2009-2011) WhateverGreen.kext and Lilu.kext'

        rm -rf WhateverGreen.kext
        unzip -q "$IMGVOL/kexts/WhateverGreen.kext.zip"

        rm -rf Lilu.kext
        unzip -q "$IMGVOL/kexts/Lilu.kext.zip"
 
        chown -R 0:0 WhateverGreen* Lilu*
        chmod -R 755 WhateverGreen* Lilu*
    fi

    popd > /dev/null

    if [ "x$DEACTIVATE_TELEMETRY" = "xYES" ]
    then
        echo 'Deactivating com.apple.telemetry.plugin'
        pushd "$VOLUME/System/Library/UserEventPlugins" > /dev/null
        mv -f com.apple.telemetry.plugin com.apple.telemetry.plugin.disabled
        popd > /dev/null
    fi

    # Get ready to use kmutil
    if [ "x$OLD_KMUTIL" = "xYES" ]
    then
        cp -f "$IMGVOL/bin/kmutil.beta8re" "$VOLUME/usr/bin/kmutil.old"
        KMUTIL=kmutil.old
    else
        KMUTIL=kmutil
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
    chroot "$VOLUME" $KMUTIL create -n boot \
        --kernel /System/Library/Kernels/kernel \
        --variant-suffix release --volume-root / $BUNDLE_PATH \
        --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
    errorCheck kmutil

    # When creating SystemKernelExtensions.kc, kmutil requires *both*
    # --both-path and --system-path!
    echo 'Using kmutil to rebuild system collection...'
    chroot "$VOLUME" $KMUTIL create -n sys \
        --kernel /System/Library/Kernels/kernel \
        --variant-suffix release --volume-root / \
        --system-path /System/Library/KernelCollections/SystemKernelExtensions.kc \
        --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
    errorCheck kmutil
else
    # Instead of updating the kernel/kext collections (later), restore the backup
    # that was previously saved (now).

    pushd "$VOLUME/System/Library/KernelCollections" > /dev/null

    BACKUP_FILE_BASE="KernelCollections-$SVPL_BUILD.tar"
    BACKUP_FILE="$BACKUP_FILE_BASE".lz4
    #BACKUP_FILE_BASE="$BACKUP_FILE_BASE".lzfse
    #BACKUP_FILE_BASE="$BACKUP_FILE_BASE".zst

    if [ ! -e "$BACKUP_FILE" ]
    then
        echo "Looked for KernelCollections backup at:"
        echo "`pwd`"/"$BACKUP_FILE"
        echo "but could not find it. unpatch-kexts.sh cannot continue."
        exit 1
    fi

    echo "Restoring KernelCollections backup from:"
    echo "`pwd`"/"$BACKUP_FILE"
    rm -f *.kc

    "$VOLUME/usr/bin/compression_tool" -decode < "$BACKUP_FILE" | tar xpv
    #"$IMGVOL/zstd" --long -d -v < "$BACKUP_FILE" | tar xp
    errorCheck tar

    # Must remove the KernelCollections backup now, or the mere existence
    # of it causes filesystem verification to fail.
    rm -f "$BACKUP_FILE"

    popd > /dev/null

    # Now remove the new kexts and move the old ones back into place.
    # First in /System/Library/Extensions, then in
    # /S/L/E/IONetworkingFamily.kext/Contents/Plugins
    # (then go back up to /System/Library/Extensions)
    pushd "$VOLUME/System/Library/Extensions" > /dev/null
    restoreOriginals

    pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null
    restoreOriginals
    popd > /dev/null

    # And remove kexts which did not overwrite newer versions.
    if [ -f AppleGraphicsControl.kext.zip ]
    then
        echo 'Restoring patched AppleGraphicsControl extension'
        rm -rf AppleGraphicsControl.kext
        unzip -q AppleGraphicsControl.kext.zip
        rm AppleGraphicsControl.kext.zip
    fi
    rm -rf AppleGraphicsControl.kext
    echo 'Removing kexts for Intel HD 3000 graphics support'
    rm -rf AppleIntelHD3000* AppleIntelSNB*
    echo 'Removing LegacyUSBInjector'
    rm -rf LegacyUSBInjector.kext
    echo 'Removing nvenet'
    rm -rf IONetworkingFamily.kext/Contents/Plugins/nvenet.kext
    echo 'Removing GeForceTesla.kext and related kexts'
    rm -rf *Tesla*
    echo 'Removing @vit9696 Whatevergreen.kext and Lilu.kext'
    rm -rf Whatevergreen.kext Lilu.kext
    echo 'Removing iMac AppleBacklightFixup'
    rm -rf AppleBacklightFixup.kext
    echo 'Reactivating telemetry plugin'
    mv -f "$VOLUME/System/Library/UserEventPlugins/com.apple.telemetry.plugin.disabled" "$VOLUME/System/Library/UserEventPlugins/com.apple.telemetry.plugin"

    popd > /dev/null

    # Also, remove kmutil.old (if it exists, it was installed by patch-kexts.sh)
    rm -f "$VOLUME/usr/bin/kmutil.old"
fi

# The way you control kcditto's *destination* is by choosing which volume
# you run it *from*. I'm serious. Read the kcditto manpage carefully if you
# don't believe me!
"$VOLUME/usr/sbin/kcditto"
errorCheck kcditto

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
then
    CREATE_SNAPSHOT="--create-snapshot"
    echo 'Creating new root snapshot due to command line option.'
else
    echo 'Skipping creation of root snapshot due to command line option.'
fi

# Now run bless
bless --folder "$VOLUME"/System/Library/CoreServices --bootefi $CREATE_SNAPSHOT --setBoot
errorCheck bless

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

if [ "x$PATCHMODE" != "x-u" ]
then
    echo 'Installed patch kexts successfully.'
else
    echo 'Uninstalled patch kexts successfully.'
fi
