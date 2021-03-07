#!/bin/bash
# Undo changes to boot-args and SIP/authenticated root, changing the
# settings back to normal. Intended for testing purposes, but it may also
# be useful if you want to give up on running unsupported macOS versions
# and just want to take the blue pill and return to your previous reality.

# As mentioned in the README, you can also reset NVRAM
# by pressing Command-Option-P-R before the Apple logo appears.
# That's probably better, but may be useful for certain circumstances.

stty -echo

if [ ! -d '/Install macOS *.app' ]
then
    echo "You need to run this script on your USB."
    stty echo
    exit 1
fi

Escape_Variables()
{
	# Source: https://github.com/seyoon20087/macos-downloader/blob/master/macOS%20Downloader.sh#L38

    text_progress="\033[38;5;113m"
	text_success="\033[38;5;113m"
	text_warning="\033[38;5;221m"
	text_error="\033[38;5;203m"
	text_message="\033[38;5;75m"

	text_bold="\033[1m"
	text_faint="\033[2m"
	text_italic="\033[3m"
	text_underline="\033[4m"

	erase_style="\033[0m"
	erase_line="\033[0K"

	move_up="\033[1A"
	move_down="\033[1B"
	move_foward="\033[1C"
	move_backward="\033[1D"
}

Escape_Variables
csrutil authenticated-root enable
csrutil enable
nvram -d boot-args
echo
echo "boot-args and csrutil settings restored to defaults."
echo "Your computer with reboot automatically after 5 seconds.";sleep 1
echo -e ${move_up}${erase_line}"Your computer with reboot automatically after 4 seconds."${erase_style}
echo -e ${move_up}${erase_line}"Your computer with reboot automatically after 3 seconds."${erase_style}
echo -e ${move_up}${erase_line}"Your computer with reboot automatically after 2 seconds."${erase_style}
echo -e ${move_up}${erase_line}"Your computer with reboot automatically after a second."${erase_style}
echo -e ${move_up}${erase_line}""${erase_style}
echo -e ${erase_line}"Now rebooting..."${erase_style};shutdown -r now
