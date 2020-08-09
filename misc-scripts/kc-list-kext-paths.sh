#!/bin/sh
# This script should work under both Linux and macOS. Either way, the
# strings command is required. Under Linux, you'll probably find it in the
# binutils package. Under macOS, you'll need either full Xcode or the
# Xcode Command Line Tools.
strings - "$1" | fgrep -A1 PrelinkBundlePath |
    sed -n -e 's@^.*<string>@@' -e 's@</string>.*@@p'
