#!/bin/bash
# Delete all snapshots from the specified volume EXCEPT THE MOST RECENT.
# (The combination of grep and awk used in this script automatically
# excludes the most recent snapshot. I mention this because it is not
# at all obvious that it does this, unless you try it against actual
# `diskutil apfs listsnapshots` output.

# Check whether we have already been provided a volume via the VOLUME
# environment variable set by remount-sysvol.sh.
if [ -z "$VOLUME" ]
then
    VOLUME="$1"

    # Make sure a volume has been specified.
    if [ -z "$VOLUME" ]
    then
        echo 'You must specify a target volume (such as /Volumes/Macintosh\ HD)'
        echo 'on the command line, or you must first use remount-sysvol.sh,'
        echo 'then run zap-snapshots.sh from inside the remount-sysvol.sh'
        echo 'subshell.'
        exit 1
    fi

    # This check certainly needs to be skipped if we're inside the
    # remount-sysvol subshell (hence why it's inside another if-then block).
    # However, there may be other situations where this check also needs
    # to be skipped. Just figured I'd mention it here in case it trips
    # anyone up later.
    if ! mount -uw "$VOLUME"
    then
        echo "Remount failed. Cannot proceed."
        exit 1
    fi
fi

for XID in `diskutil apfs listSnapshots "$VOLUME"|fgrep XID|awk '{print $3}'`
do
    echo $XID
    diskutil apfs deleteSnapshot "$VOLUME" -xid $XID
done
