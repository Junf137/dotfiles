#!/bin/bash

# __author__ == Junfeng Lei
# --------------------------------
# Description:
#   Apply the macOS preferences I deliberately changed from default.
#   Scope is intentionally minimal: every line below is a confirmed
#   deviation from the macOS factory default (verified by diffing a
#   fresh install). Anything not here is left at the system default.
#   iCloud-synced settings (passwords, wifi, mail, safari...) and
#   per-app privacy permissions are out of scope.
# usage:
#   ./macos-defaults.sh
# --------------------------------

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This script is macOS-only." >&2
    exit 1
fi

echo "---* Trackpad & mouse *---"
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true                     # tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1
defaults write -g com.apple.mouse.scaling -float 3                                        # mouse tracking speed

echo "---* Keyboard *---"
defaults write -g AppleKeyboardUIMode -int 2                                              # full keyboard access

echo "---* Dock *---"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 55
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 61
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true                          # minimize into app icon
defaults write com.apple.dock expose-group-apps -bool true                                # Mission Control: group by app

echo "---* Hot corners *---"
defaults write com.apple.dock wvous-tl-corner -int 2    # top-left:     Mission Control
defaults write com.apple.dock wvous-tr-corner -int 12   # top-right:    Notification Center
defaults write com.apple.dock wvous-bl-corner -int 3    # bottom-left:  Application Windows
defaults write com.apple.dock wvous-br-corner -int 4    # bottom-right: Desktop

echo "---* Finder *---"
defaults write -g AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"                       # Nlsv = List view
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder NewWindowTarget -string "PfDe"                            # new windows open to Desktop

echo "---* Screenshots *---"
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"

echo "---* Restarting affected apps *---"
killall Dock Finder SystemUIServer 2>/dev/null || true

echo "Done. Some changes may need a logout/login to fully apply."
