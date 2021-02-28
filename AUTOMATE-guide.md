### The automator.sh script will automate the installation process of the micropatcher. 
Before beginning, insert an external disk that you are happy to have erased.
**Step 1**
To begin, open a terminal window, and run the following:
```
git clone https://github.com/solomon-wood/big-sur-micropatcher/
cd big-sur-micropatcher
```
Then, type in `diskutil list`
and you should see a result similar to this:
```
/dev/disk0 (internal, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      GUID_partition_scheme                        *251.0 GB   disk0
   1:                        EFI EFI                     209.7 MB   disk0s1
   2:                 Apple_APFS Container disk2         250.8 GB   disk0s2

/dev/disk1 (synthesized):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      APFS Container Scheme -                      +250.8 GB   disk1
                                 Physical Store disk0s2
   1:                APFS Volume macOS                   95.1 GB    disk1s1
   2:                APFS Volume Preboot                 22.3 MB    disk1s2
   3:                APFS Volume Recovery                516.2 MB   disk1s3
   4:                APFS Volume VM                      2.1 GB     disk1s4

/dev/disk2 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      GUID_partition_scheme                        *15.9 GB    disk2
   1:                        EFI EFI                     209.7 MB   disk2s1
   2:                  Apple_HFS Install macOS Big Sur   15.6 GB    disk2s2
```
Then look for the name of your external disk, here mine is Install macOS Big Sur.
The whole disk identifier is `disk2`.

**Step 2**
Now, type in `./automate.sh usb disk2` with disk2 as the disk identifier.
This will take some time to run.

**Step 3**
Now, reboot while holding Option, and select EFI Boot. Press power on your mac while
holding Option, and then select Install macOS Big Sur. Then install as normal.

**Step 4**
Reboot into Install macOS Big Sur, open terminal, then type:
`"/Volumes/Image Volume/patcher/automator.sh" "hdd" "/Volumes/macOS"`
With macOS as your Hard Disk.
