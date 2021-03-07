#!/bin/sh
stty -echo
defaults delete -g NSAutomaticWindowAnimationsEnabled
defaults delete -g NSScrollAnimationEnabled
defaults delete -g NSWindowResizeTime
defaults delete -g QLPanelAnimationDuration
defaults delete -g NSScrollViewRubberbanding
defaults delete -g NSDocumentRevisionsWindowTransformAnimation
defaults delete -g NSToolbarFullScreenAnimationDuration
defaults delete -g NSBrowserColumnAnimationSpeedMultiplier
defaults delete com.apple.dock autohide-time-modifier
defaults delete com.apple.dock autohide-delay
defaults delete com.apple.dock expose-animation-duration
defaults delete com.apple.dock springboard-show-duration
defaults delete com.apple.dock springboard-hide-duration
defaults delete com.apple.dock springboard-page-duration
defaults delete com.apple.finder DisableAllAnimations
defaults delete com.apple.Mail DisableSendAnimations
defaults delete com.apple.Mail DisableReplyAnimations
defaults delete NSGlobalDomain NSWindowResizeTime
stty echo
