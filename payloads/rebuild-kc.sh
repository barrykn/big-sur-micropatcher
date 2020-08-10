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

# Prepare $BUNDLE_PATH variable for rebuilding the boot kc, if
# LegacyUSBInjector was installed.
if [ -d "$VOLUME/System/Library/Extensions/LegacyUSBInjector.kext" ]
then
    BUNDLE_PATH="--bundle-path /System/Library/Extensions/LegacyUSBInjector.kext"
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
    --volume-root / $BUNDLE_PATH \
    --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
kmutilErrorCheck

# When creating SystemKernelExtensions.kc, kmutil requires *both* --boot-path
# and --system-path!
echo 'Using kmutil to rebuild system collection...'
chroot "$VOLUME" kmutil create -n sys \
    --kernel /System/Library/Kernels/kernel \
    --volume-root / \
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
    bless --folder "$VOLUME"/System/Library/CoreServices --bootefi --create-snapshot
else
    echo 'Booted directly from volume, so skipping snapshot creation.'
fi

# Don't unmount the volume; that will be handled by remount-sysvol.sh once
# the user exits the subshell.

echo 'Rebuilt kernel/kext collections successfully.'
echo "You may now run 'exit' to exit the subshell."
