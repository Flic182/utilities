#!/usr/bin/env bash

################################################################################
# This script updates Homebrew and its formulae and casks.  It removes old
# versions as well - you may want to leave this part out if you worry about
# breaking changes.
#
# Use cron to run this daily and keep all software up to date.
################################################################################
BREW_EXE="/usr/local/bin/brew"

# "${BREW_EXE}" update - No longer needed as it's done by cask upgrade.
"${BREW_EXE}" upgrade
"${BREW_EXE}" cu --cleanup -y < /dev/null  # See https://github.com/buo/homebrew-cask-upgrade for details
"${BREW_EXE}" cleanup
