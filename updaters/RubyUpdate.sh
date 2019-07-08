#!/usr/bin/env bash -l

################################################################################
# This script keeps Ruby up-to-date.   If you are using the previous stable
# version, it will install the latest one and optionally remove the previous.
#
# The program can be called with the following argument (which is optional):
# -c Indicates the script should remove the previous stable version if a new
#    one is successfully installed and the program can switch to it.
#
# It is assumed rbenv and ruby-build are installed and configured for a login
# shell.  If you have aliases in your login profile, please take extra care to
# review this script and ensure it doesn't unintentionally invoke any of those
# aliases.
################################################################################


################################################################################
# File and command info
################################################################################
readonly USAGE="${0} [-c(leanup old versions)]"
readonly WORKING_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"

readonly ALLOWED_VERSION_REGEX="[ ][ ]*[0-9][0-9]*\.([0-9][0-9]*\.?)*"
readonly RBENV_EXE="/usr/local/bin/rbenv"


################################################################################
# Include command-line, error & version handling functionality.
################################################################################
. "${WORKING_DIR}/../handlers/UpdaterArgumentHandling.sh"


################################################################################
# Script-specific exit states.
################################################################################
readonly INSTALL_ERROR=94
readonly COPY_ERROR=95
readonly SWITCH_ERROR=96
readonly UNINSTALL_ERROR=97


################################################################################
# Cleans up the rbenv environment.  If the Ruby version currently in use is
# the same as the old version, the function will tell rbenv to switch to the
# new version.  When the user specifies the -c flag on the command line, it will
# additionally uninstall the old version (but ONLY if the switch was
# successful).  If the user is already using the latest version, old versions
# will be removed when the command flag is set.
#
# @param OLD_VERSION The previous 'latest' version of Ruby managed by rbenv.
# @param NEW_VERSION The latest version of Ruby managed by rbenv.
################################################################################
clean_installations() {
  local -r NEW_VERSION="${2}"
  local -r OLD_VERSION="${1}"
  local -r IN_USE="$("${RBENV_EXE}" "versions" | \
                     "awk" '/^\*[ ][ ]*(..*)/ {print $2}')"

  if (( clean_installs == TRUE )); then
    if [[ "${IN_USE}" == "${NEW_VERSION}" ]]; then
      "${RBENV_EXE}" versions | awk -v regex="${ALLOWED_VERSION_REGEX}$" '$0 ~ regex {sub(/^\*/," "); version=$1; print version}' | \
      while read -r outdated_version; do
        uninstall_version "${outdated_version}"
      done
    elif [[ "${IN_USE}" == "${OLD_VERSION}" ]]; then
      "${RBENV_EXE}" global "${NEW_VERSION}"
      if [[ "${?}" -ne "${SUCCESS}" ]]; then
        exit_with_error "${SWITCH_ERROR}" \
                        "Switch from ${OLD_VERSION} to ${NEW_VERSION} failed."
      fi

      echo "Now running Ruby version ${NEW_VERSION} globally."

      uninstall_version "${OLD_VERSION}"
    else
      echo "Current Ruby version unchanged.  Running ${IN_USE}."
    fi
  elif [[ "${IN_USE}" == "${OLD_VERSION}" ]]; then
    "${RBENV_EXE}" global "${NEW_VERSION}"
    if [[ "${?}" -ne "${SUCCESS}" ]]; then
      exit_with_error "${SWITCH_ERROR}" \
                      "Switch from ${OLD_VERSION} to ${NEW_VERSION} failed."
    fi

    echo "Now running Ruby version ${NEW_VERSION} globally."
  else
    echo "Current Ruby version unchanged.  Running ${IN_USE}."
  fi
}


################################################################################
# Copies all Ruby gems installed in the old version to the new version -
# downloading the latest version of each gem for the new environment.
#
# @param OLD_VERSION The previous 'latest' version of Ruby managed by rbenv.
# @param NEW_VERSION The latest version of Ruby managed by rbenv.
################################################################################
copy_gems() {
  local -r NEW_VERSION="${2}"
  local -r OLD_VERSION="${1}"

  local -r GEM_LIST_FILE="/tmp/gem-list.txt"

  "${RBENV_EXE}" shell "${OLD_VERSION}"
  gem list --no-versions > "${GEM_LIST_FILE}"

  if [[ "${?}" -ne "${SUCCESS}" ]]; then
     exit_with_error "${COPY_ERROR}" \
                     "Failed to retrieve gem list from version ${OLD_VERSION}."
  fi

  "${RBENV_EXE}" shell "${NEW_VERSION}"
  gem in "$("cat" "${GEM_LIST_FILE}")"

  if [[ "${?}" -ne "${SUCCESS}" ]]; then
     exit_with_error "${COPY_ERROR}" \
                     "Failed to import gem list from ${GEM_LIST_FILE} to version ${NEW_VERSION}."
  fi

  rm -rf "${GEM_LIST_FILE}"
}


################################################################################
# Installs the nominated Ruby version with rbenv.
#
# @params RUBY_VERSION The new version to be installed.
################################################################################
install_version() {
  local -r RUBY_VERSION="${1}"

  "${RBENV_EXE}" install "${RUBY_VERSION}"

  if [[ "${?}" -ne "${SUCCESS}" ]]; then
    exit_with_error "${INSTALL_ERROR}" "Failed to install ${RUBY_VERSION}."
  fi

  echo "Installed new Ruby version ${RUBY_VERSION}."
}


################################################################################
# Uninstalls the nominated Ruby version with rbenv.
#
# @params RUBY_VERSION The old version to be uninstalled.
################################################################################
uninstall_version() {
  local -r RUBY_VERSION="${1}"

  "${RBENV_EXE}" uninstall -f "${RUBY_VERSION}"

  if [[ "${?}" -ne "${SUCCESS}" ]]; then
    exit_with_error "${UNINSTALL_ERROR}" "Failed to uninstall ${RUBY_VERSION}."
  fi

  echo "Uninstalled old Ruby version ${RUBY_VERSION}."
}


################################################################################
# Checks latest stable version against latest installed version & updates the
# installed version if required.
################################################################################
upgrade_ruby() {
  local -r LATEST_INSTALLED="$("${RBENV_EXE}" "versions" | \
                               "awk" "-v" "regex=^\\*?${ALLOWED_VERSION_REGEX}" \
                               '$0 ~ regex {sub(/^\*/," "); version=$1} END{print version}')"
  local -r LATEST_STABLE="$("${RBENV_EXE}" "install" "-l" | \
                            "awk" "-v" "regex=${ALLOWED_VERSION_REGEX}$" \
                            '$0 ~ regex {version=$1} END{print version}')"

  if [[ "${LATEST_INSTALLED}" != "${LATEST_STABLE}" ]]; then
    install_version "${LATEST_STABLE}"
    copy_gems "${LATEST_INSTALLED}" "${LATEST_STABLE}"
  fi

  clean_installations "${LATEST_INSTALLED}" "${LATEST_STABLE}"
}


################################################################################
# Entry point to the program.
#
# @param ARGS Command line flags, including -c (for cleanup), which is optional.
################################################################################
main() {
  local -r ARGS=("${@}")

  check_args "${USAGE}" "${ARGS[@]}"
  upgrade_ruby
}


################################################################################
# Set up for bomb-proof exit, then run the script
################################################################################
trap_with_signal cleanup HUP INT QUIT ABRT TERM EXIT

main "${@}"

exit ${SUCCESS}
