#!/bin/bash

### begin function definitions ###
# Make sure the specified environment variable exists.
checkVar() {
    if [ -z ${!1} ]
    then
        echo "Error: $1 is not defined"
        exit 1
    fi
}

# Check for errors, and handle any errors appropriately, after any kmutil
# invocation.
kmutilErrorCheck() {
    if [ $? -ne 0 ]
    then
        echo 'kmutil failed. See above output for more information.'
        echo 'rebuild-kc.sh cannot continue, but you may make further'
        echo 'changes and try rebuild-kc.sh again.'
        exit 1
    fi
}

### end function definitions ###

# Make sure this script is running as root, otherwise use sudo to try again
# as root.
[ $UID = 0 ] || exec sudo "$0" "$@"

checkVar VOLUME
checkVar WASSNAPSHOT
checkVar RECOVERY
# Maybe I should rename SVPL_BUILD at some point. It's the macOS
# build number, as detected by remount-sysvol.sh.
checkVar SVPL_BUILD

# Need to back up the original KernelCollections before we modify them.
# This is necessary for unpatch-kexts.sh to be able to accomodate
# the type of filesystem verification that is done by Apple's delta updaters.
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
fi
popd > /dev/null


# Prepare $BUNDLE_PATH variable for rebuilding the boot kc, if
# LegacyUSBInjector was installed.
if [ -d "$VOLUME/System/Library/Extensions/LegacyUSBInjector.kext" ]
then
    BUNDLE_PATH="--bundle-path /System/Library/Extensions/LegacyUSBInjector.kext"
fi

# Get ready to use kmutil
if [ "x$OLD_KMUTIL" = "xYES" ]
then
    if /usr/bin/which -s kmutil.old
    then
        echo 'Using old kmutil as requested.'
        KMUTIL=kmutil.old
    else
        echo 'Cannot find kmutil.old. Continuing with current kmutil.'
        KMUTIL=kmutil
    fi
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
kmutilErrorCheck

# When creating SystemKernelExtensions.kc, kmutil requires *both* --boot-path
# and --system-path!
echo 'Using kmutil to rebuild system collection...'
chroot "$VOLUME" $KMUTIL create -n sys \
    --kernel /System/Library/Kernels/kernel \
    --variant-suffix release --volume-root / \
    --system-path /System/Library/KernelCollections/SystemKernelExtensions.kc \
    --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
kmutilErrorCheck

# The way you control kcditto's *destination* is by choosing which volume
# you run it *from*. I'm serious. Read the kcditto manpage carefully if you
# don't believe me!
"$VOLUME/usr/sbin/kcditto"
if [ $? -ne 0 ]
then
    echo
    echo 'kcditto failed. See above output for more information.'
    echo 'patch-kexts.sh cannot continue.'
    exit 1
fi

# If $VOLUME = "/" at this point in the script, then we are running in a
# live installation and the system volume is not booted from a snapshot.
# Otherwise, assume snapshot booting is configured and use bless to create
# a new snapshot. (This behavior can be refined in a future release...)
if [ "$VOLUME" != "/" ]
then
    echo 'Creating new root snapshot.'
    bless --folder "$VOLUME"/System/Library/CoreServices --create-snapshot --bootefi
    if [ $? -ne 0 ]
    then
        echo
        echo 'bless failed. See above output for more information.'
        echo 'rebuild-kc.sh cannot continue.'
        exit 1
    fi
else
    echo 'Booted directly from volume, so skipping snapshot creation.'
fi

# Don't unmount the volume; that will be handled by remount-sysvol.sh once
# the user exits the subshell.

echo 'Rebuilt kernel/kext collections successfully.'
echo "You may now run 'exit' to exit the subshell."
