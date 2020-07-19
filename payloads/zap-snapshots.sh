#!/bin/bash
# Delete all snapshots from the specified volume EXCEPT THE MOST RECENT.
# (The combination of grep and awk used in this script automatically
# excludes the most recent snapshot. I mention this because it is not
# at all obvious that it does this, unless you try it against actual
# `diskutil apfs listsnapshots` output.

VOLUME="$1"

# Make sure a volume has been specified.
if [ -z "$VOLUME" ]
then
    echo 'You must specify a target volume (such as /Volumes/Macintosh\ HD)'
    echo 'on the command line.'
    exit 1
fi

if mount -uw "$VOLUME"
then
    # Remount succeeded. Do nothing in this block, and keep going.
    true
else
    echo "Remount failed. Cannot proceed."
    exit 1
fi

for XID in `diskutil apfs listSnapshots "$VOLUME"|fgrep XID|awk '{print $3}'`
do
    echo $XID
    diskutil apfs deleteSnapshot "$VOLUME" -xid $XID
done
