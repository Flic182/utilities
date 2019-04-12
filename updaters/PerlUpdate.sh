#!/usr/bin/env bash

################################################################################
# This script keeps Perl up-to-date.  If you are using the previous stable
# version, it will install the latest one and optionally remove the previous.
#
# The program can be called with the following argument (which is optional):
# -c Indicates the script should remove the previous stable version if a new
#    one is successfully installed and the program can switch to it.
################################################################################


################################################################################
# File and command info
################################################################################
readonly USAGE="${0} [-c(leanup old versions)]"
readonly ALLOWED_FLAGS="^-[c]$"
readonly PERLBREW_EXE="${HOME}/perl5/perlbrew/bin/perlbrew"
readonly WORKING_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"

# Include command-line & error handling functionality.
. "${WORKING_DIR}/ArgumentHandling.sh"


################################################################################
# Script-specific exit states.
################################################################################
readonly PERLBREW_UPGRADE_ERROR=93
readonly INSTALL_ERROR=94
readonly CLONE_ERROR=95
readonly SWITCH_ERROR=96
readonly UNINSTALL_ERROR=97


################################################################################
# Cleans up the Perlbrew environment.  If the Perl version currently in use is
# the same as the old version, the function will tell Perlbrew to switch to the
# new version.  When the user specifies the -c flag on the command line, it will
# additionally uninstall the old version (but ONLY if the switch was
# successful).  If the user is already using the latest version, old versions
# will be removed when the command flag is set.
#
# @param OLD_VERSION The previous 'latest' version of Perl managed by Perlbrew.
# @param NEW_VERSION The latest version of Perl managed by Perlbrew.
################################################################################
clean_installations() {
  local -r NEW_VERSION="${2}"
  local -r OLD_VERSION="${1}"
  local -r IN_USE="$("${PERLBREW_EXE}" "list" | \
                     "awk" '/^[ ][ ]*\*[ ][ ]*perl-..*$/ {print $(NF)}')"

  if (( clean_installs == TRUE )); then
    "${PERLBREW_EXE}" clean

    if [[ "${IN_USE}" == "${OLD_VERSION}" ]]; then
      "${PERLBREW_EXE}" switch "${NEW_VERSION}"
      if [[ "${?}" != "${SUCCESS}" ]]; then
        exit_with_error "${SWITCH_ERROR}" \
                        "Switch from ${OLD_VERSION} to ${NEW_VERSION} failed."
      fi

      uninstall_version "${OLD_VERSION}"
      if [[ "${?}" != "${SUCCESS}" ]]; then
        exit_with_error "${UNINSTALL_ERROR}" \
                        "Uninstall of version ${OLD_VERSION} failed."
      fi
    elif [[ "${IN_USE}" == "${NEW_VERSION}" ]]; then
      local old_versions=("$("${PERLBREW_EXE}" "list" | \
                             "awk" '/^[ ][ ]*perl-..*$/ {print $(NF);}')")

      for outdated_version in "${old_versions[@]}"; do
        uninstall_version "${old_version[${version_index}]}"
      done
    fi
  elif [[ "${IN_USE}" == "${OLD_VERSION}" ]]; then
    "${PERLBREW_EXE}" switch "${NEW_VERSION}"
    if [[ "${?}" != "${SUCCESS}" ]]; then
      exit_with_error "${SWITCH_ERROR}" \
                      "Switch from ${OLD_VERSION} to ${NEW_VERSION} failed."
    fi
  fi
}


################################################################################
# Tells Perlbrew to copy all Perl modules installed in the old version to the
# new version.
#
# @param OLD_VERSION The previous 'latest' version of Perl managed by Perlbrew.
# @param NEW_VERSION The latest version of Perl managed by Perlbrew.
################################################################################
clone_modules() {
  local -r NEW_VERSION="${2}"
  local -r OLD_VERSION="${1}"

  "${PERLBREW_EXE}" clone-modules "${OLD_VERSION}" "${NEW_VERSION}"

  if [[ "${?}" != "${SUCCESS}" ]]; then
    exit_with_error "${CLONE_ERROR}" \
                    "Module clone from ${OLD_VERSION} to ${NEW_VERSION} failed."
  fi
}


################################################################################
# Retrieves the version number from the passed Perl version string.
#
# @param PERL_VERSION The Perlbrew-reported version, in the form perl-#.##.##.
################################################################################
get_version_no() {
  local -r PERL_VERSION="${1}"
  sed -n 's/^perl-//p' <<< "${PERL_VERSION}"
}


################################################################################
# Installs the nominated Perl version with Perlbrew.
#
# @params PERL_VERSION The new version to be installed.
################################################################################
install_version() {
  local -r PERL_VERSION="${1}"

  "${PERLBREW_EXE}" install "${PERL_VERSION}"

  if [[ "${?}" != "${SUCCESS}" ]]; then
    exit_with_error "${INSTALL_ERROR}" "Failed to install ${PERL_VERSION}."
  fi
}


################################################################################
# Uninstalls the nominated Perl version with Perlbrew.
#
# @params PERL_VERSION The old version to be uninstalled.
################################################################################
uninstall_version() {
  local -r PERL_VERSION="${1}"

  "${PERLBREW_EXE}" uninstall "${PERL_VERSION}"

  if [[ "${?}" != "${SUCCESS}" ]]; then
    exit_with_error "${UNINSTALL_ERROR}" "Failed to uninstall ${PERL_VERSION}."
  fi
}


################################################################################
# Checks latest stable (even-numbered minor) version against latest installed
# version & updates the installed version if required.
#
# The following command only seems to upgrade sub-version (last part of version
# triplet):
# "${PERLBREW_EXE}" upgrade-perl
# ...hence the need for this function.
################################################################################
upgrade_perl() {
  local -r LATEST_INSTALLED="$("${PERLBREW_EXE}" "list" | \
                               "awk" '/^[ ][ ]*(\*[ ][ ]*)?perl-..*$/ {print $(NF); exit}')"
  local -r LATEST_STABLE="$("${PERLBREW_EXE}" "available" | \
                            "awk" '/^i?[ ][ ]*perl-[0-9][0-9]*.[0-9]*[02468]\..*$/ {print $(NF); exit}')"

  if [[ "${LATEST_INSTALLED}" != "${LATEST_STABLE}" ]]; then
    install_version "${LATEST_STABLE}"
    clone_modules "$("get_version_no" "${LATEST_INSTALLED}")" \
                  "$("get_version_no" "${LATEST_STABLE}")"
 fi

  clean_installations "${LATEST_INSTALLED}" "${LATEST_STABLE}"
}


################################################################################
# Upgrades the current version of Perlbrew.
################################################################################
upgrade_perlbrew() {
  "${PERLBREW_EXE}" self-upgrade

  if [[ "${?}" != "${SUCCESS}" ]]; then
    exit_with_error "${PERLBREW_UPGRADE_ERROR}" "Perlbrew upgrade failed."
  fi
}


################################################################################
# Entry point to the program.
#
# @param ARGS Command line flags, including -c (for cleanup), which is optional.
################################################################################
main() {
  local -r ARGS=("${@}")

  check_args "${USAGE}" "${ARGS[@]}"
  upgrade_perlbrew
  upgrade_perl
}


################################################################################
# Set up for bomb-proof exit, then run the script
################################################################################
trap_with_signal cleanup HUP INT QUIT ABRT TERM EXIT

main "${@}"

exit ${SUCCESS}