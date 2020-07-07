# big-sur-micropatcher (Version 0.0.9)
A primitive USB patcher for installing macOS Big Sur on unsupported Macs

(Note that [ParrotGeek has a Big Sur patcher](https://parrotgeek.com/bigsur/) now; it is an alternative that you should consider.)

Thanks to ASentientBot and jackluke for their hard work to get Big Sur running on unsupported Macs! In particular:

- Thanks to ASentientBot for developing the Hax series of installer patches which are so incredibly helpful for installing Big Sur on unsupported Macs.
- Thanks to jackluke for figuring out how to patch the Recovery USB to bypass compatibility checks and AMFI enforcement in the absence of NVRAM boot-args settings.

This documentation is bare-bones at the moment, but hopefully it's better than nothing. Remember that you *do this at your own risk*, you could easily lose your data, expect bugs and crashes, Big Sur is still under development (as is this patcher), etc.

Quick instructions for use:

1. Obtain a copy of the macOS Big Sur Developer Preview and use `createinstallmedia` as usual to create a bootable USB stick with the installer and recvoery environment, as you would on a supported Mac. (This patcher currently requires that the name of the USB stick remain "Install macOS Beta". Do not rename the USB stick at any point.) This patcher has only been tested with beta 1, but it's possible that it will also work with beta 2.
2. Download this micropatcher, then run `micropatcher.sh` to patch the USB stick. (If you are viewing this on GitHub, and you probably are, then click "Clone" then "Download ZIP".)
3. Since Disk Utility in Big Sur may have new bugs, this may be a good time to use Disk Utility in High Sierra/Mojave/Catalina to do any partitioning or formatting you may need.
4. Boot from the USB stick.
5. If you need to do any partitioning or formatting with Disk Utility, and you didn't do it in step 5, it's best to do it now.
6. Open Terminal (in the Utilities menu), then run `/Volumes/Image\ Volume/set-vars.sh`. This script will change boot-args and csrutil settings as needed, and also set things up so the Installer will run properly. Don't forget that tab completion is your friend! You can type `/V<tab>/I<tab>/se<tab>` at the command prompt -- that's much less typing! (Run `/Volumes/Image\ Volume/set-vars.sh -v` instead if you want verbose boot. Note that verbose boot in Big Sur is *very* verbose, to the point that it actually slows down boot considerably -- but it's also very useful for troubleshooting.)
7. Quit Terminal then start the Installer as you would on a supported Mac.
8. Come back in an hour or two and you should be at the macOS setup region prompt! (If you actually watch the installation process, don't be surprised if it seems to get stuck at "Less than a minute remaining..." for a long time. Allow it well over half an hour. It should eventually reboot on its own and keep going.)
9. If you're on a Late 2013 iMac, or you've replaced the 802.11n card in your 2012 Mac with an 802.11ac card, you're done. Otherwise, press Command-Q and wait a few seconds, then the Setup Assistant should let you shut down. After you shut down, start up again and boot from the patched installer USB again, then open Terminal again. This time, run `/Volumes/Image\ Volume/patch-kexts.sh /Volumes/<name of Big Sur volume>`, for example `/Volumes/Image\ Volume/patch-kexts.sh /Volumes/Macintosh\ HD`. It needs to be the name of the *system* volume. This will patch your Big Sur installation to add working Wi-Fi. (On 2011 MacBook Pro 13" and 2011 MacBook Air, add a "--2011" option after the ".sh" and before the volume name, for example `/Volumes/Image\ Volume/patch-kexts.sh --2011 /Volumes/Macintosh\ HD`, to fix sound, brightness control, and sleep as well as Wi-Fi.) Once that finishes, reboot into your Big Sur installation.
10. On 2011 Macs, once you have installed Big Sur, make sure to enable Reduce Transparency to eliminate many seemingly random crashes, and if icons on the right-hand side of the menu bar are invisible afterward, try Dark mode.

If this patcher turns out to be compatible with beta 2, then to update, it should be possible to create a beta 2 USB, patch it with this patcher, then follow the directions above (except skip Disk Utility, i.e. skip steps 3 and 5) to boot from the patched USB and install it on top of beta 1. (Allow something like 60-90 minutes for the update, even if it looks like it froze up at some point, especially on a 2011 Mac.) This *will* uninstall the Wi-Fi, etc. kexts that were installed on beta 1 in step 9, so (again, assuming the patcher turns out to be compatible with beta 2) you will need to redo that step as well. Perhaps a more convenient update method will be found, but if not, this method should suffice.

This patcher can now handle Wi-Fi on 2011 and later Macs, and also sound, sleep, and display brightness control on 2011 MacBook Pro 13" and probably (I don't have one to test) 2011 MacBook Air. (See step 9 above.) However, it still won't fix many other post-installation issues, like missing graphics acceleration on 2011 Macs or removing the telemetry plugin on systems with Penryn CPUs, but at least it will get a basic installation done on 2011/2012/2013 Macs. It is essentially certain that USB support (necessary for booting off the USB stick, as well as keyboard and trackpad) will fail to work on 2010 or earlier MacBooks right now, but I have not done any testing on those yet.

If you want to undo the patcher's changes to boot-args and csrutil settings, then boot from the USB stick, open Terminal, and run `/Volumes/Image\ Volume/reset-vars.sh`. For what it's worth, there is also a script for undoing the kext additions (such as 802.11n Wi-Fi), at `/Volumes/Image\ Volume/unpatch-kexts.sh`. (It is dependent on implementation details of patch-kexts.sh and may not be able to undo kext changes applied through other means.)

The best way to remove the patch from the USB stick is to redo `createinstallmedia`, but if you are working on patcher development or otherwise need a faster way to do it, you can run `unpatch.sh`.
