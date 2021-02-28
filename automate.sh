#!/bin/bash
# A script that will automate the micropatcher, which will make it a lot easier to use.
# Created by Solomon Wood on 27/02/2021

echo "You want to run the action $1 to the disk $2"
echo "Now running the Micropatcher..."

function do_download {
  ONLINEAPPLOCATION = $(cat ./bigsuraddress)
  curl -O -# $ONLINEAPPLOCATION
  sudo installer -pkg ./InstallAssistant.pkg
  APPLOCATION="/Applications/Install macOS Big Sur.app"
}

function find_app {
  echo "Finding install app..."
  if [[ -d "/Applications/Install macOS Big Sur.app" ]]
    APPLOCATION="/Applications/Install macOS Big Sur.app"
  else
    echo "Please enter the location for the Install macOS Big Sur App. If you don't have one, enter 0"
    read $APPLOCATION
    if [[ $APPLOCATION = 0 ]]
      do_download
    fi
  fi
}

function cim_function {
  echo "Erasing disk and creating install media. All volumes on this disk will be lost."
  diskutil eraseDisk JHFS+ PATCH $2
  $APPLOCATION/Contents/Resources/createinstallmedia --volume /Volumes/PATCH
}

function patch_disk {
  ./micropatcher.sh "/Volumes/Install macOS Big Sur/"
  ./install-setvars.sh "/Volumes/Install macOS Big Sur/"
  echo "All done. Reboot your Mac, and install by first booting off EFI Boot, and then Install macOS Big Sur."
}


function full_patch {
  find_app
  cim_function
  patch_disk
}

function final_patch {
  "/Volumes/Install macOS Big Sur/patch-kexts.sh" "/Volumes/Macintosh HD"
  reboot
}

if [[ $1 = "usb" ]]
  full_patch
elif [[ $1 = "hdd" ]]
  final_patch
fi
