#!/usr/bin/env bash

################################################################################
# This script keeps Python, pyenv references & packages installed via
# pip up-to-date.  Prefer to update Python 3 packages first - some caching
# issues in Pip3, Pip2 seems OK.
#
# Beware if you choose to install editable packages.  See this post for details:
# https://stackoverflow.com/questions/2720014/upgrading-all-packages-with-pip
################################################################################
# Make sure Python versions are symlinked & old symlinks removed
# TODO - Add this code!
# Require https://stackoverflow.com/questions/30499795/how-can-i-make-homebrews-python-and-pyenv-live-together
# & https://stackoverflow.com/questions/22097130/delete-all-broken-symbolic-links-with-a-line

PIP2_EXE="/usr/local/bin/pip2"
PIP3_EXE="/usr/local/bin/pip3"

"${PIP3_EXE}" list --no-cache-dir --outdated | awk '!/^(---|Package)/ {print $1;}' | xargs -n1 "${PIP3_EXE}" install -U
"${PIP2_EXE}" list --outdated | awk '!/^(---|Package)/ {print $1;}' | xargs -n1 "${PIP2_EXE}" install --upgrade pip
