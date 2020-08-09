#!/bin/sh
strings "$1" | fgrep -A1 PrelinkBundlePath |
    sed -n -e 's@^.*<string>@@' -e 's@</string>.*@@p'
