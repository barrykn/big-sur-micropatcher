#!/bin/bash
# Undo changes to boot-args and SIP/authenticated root, changing the
# settings back to normal. Intended for testing purposes, but it may also
# be useful if you want to give up on running unsupported macOS versions
# and just want to take the blue pill and return to your previous reality.

csrutil authenticated-root enable
csrutil enable
nvram -d boot-args
echo
echo boot-args and csrutil settings restored to defaults. Please reboot.
