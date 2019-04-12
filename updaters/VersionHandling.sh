#!/usr/bin/env bash

################################################################################
# This script is a library of common installation, uninstallation & other
# software version management functions for use by other scripts.
################################################################################


################################################################################
# File and command info
################################################################################

# Include error handling functionality.
. "${WORKING_DIR}/ErrorHandling.sh"


################################################################################
# Script-specific exit states.
################################################################################
readonly UPGRADE_ERROR=93
readonly INSTALL_ERROR=94
readonly CLONE_ERROR=95
readonly SWITCH_ERROR=96
readonly UNINSTALL_ERROR=97


################################################################################
# Cleans up the environment.  If the software version currently in use is the
# same as the old version, the function will tell the installer to switch to the
# new version.  When the user specifies the -c flag on the command line, it will
# additionally uninstall the old version (but ONLY if the switch was
# successful).  If the user is already using the latest version, old versions
# will be removed when the command flag is set.
#
# @param INSTALLER   The command used to install new software versions.
# @param SET_ARG     The argument required by the installer to set a version.
# @param IN_USE      The version of software currently in use.
# @param OLD_VERSION The previous 'latest' version managed by the installer.
# @param NEW_VERSION The latest version managed by the installer.
################################################################################
clean_installations() {
  local -r NON_ARRAY_ARGS=5
  local -r INSTALLER="${1}"
  local -r IN_USE="${3}"
  local -r NEW_VERSION="${5}"
  local -r OLD_VERSION="${4}"
  local -r SET_ARG="${2}"
  shift ${NON_ARRAY_ARGS}
  local -r OBSOLETE_VERSIONS=("${1}")

  if (( clean_installs == TRUE )); then
    if [[ "${IN_USE}" == "${OLD_VERSION}" ]]; then
      "${INSTALLER}" "${SET_ARG}" "${NEW_VERSION}"
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
      for outdated_version in "${OBSOLETE_VERSIONS[@]}"; do
        uninstall_version "${outdated_version}"
      done
    fi
  elif [[ "${IN_USE}" == "${OLD_VERSION}" ]]; then
    "${INSTALLER}" "${SET_ARG}" "${NEW_VERSION}"
    if [[ "${?}" != "${SUCCESS}" ]]; then
      exit_with_error "${SWITCH_ERROR}" \
                      "Switch from ${OLD_VERSION} to ${NEW_VERSION} failed."
    fi
  fi
}


################################################################################
# Tells the environment management software to copy all libraries (gems,
# modules, etc.) installed in the old version to the new version.
#
# @param CLONER      The command used to clone modules - e.g. rbenv, perlbrew
# @param ARG         The argument required by the command to perform a clone.
# @param OLD_VERSION The previous 'latest' version of the target software.
# @param NEW_VERSION The latest version of the software under management.
################################################################################
clone_libraries() {
  local -r ARG="${2}"
  local -r CLONER ="${1}"
  local -r NEW_VERSION="${4}"
  local -r OLD_VERSION="${3}"

  "${CLONER}" "${ARG}" "${OLD_VERSION}" "${NEW_VERSION}"

  if [[ "${?}" != "${SUCCESS}" ]]; then
    exit_with_error "${CLONE_ERROR}" \
                    "Library clone from ${OLD_VERSION} to ${NEW_VERSION} failed."
  fi
}


################################################################################
# Installs the nominated software version with the required installer.
#
# @param INSTALLER The command used to install new software versions.
# @param VERSION   The new version to be installed.
################################################################################
install_version() {
  local -r INSTALLER="${1}"
  local -r VERSION="${2}"

  "${INSTALLER}" install "${VERSION}"

  if [[ "${?}" != "${SUCCESS}" ]]; then
    exit_with_error "${INSTALL_ERROR}" "Failed to install version ${VERSION}."
  fi
}


################################################################################
# Uninstalls the nominated Perl version with Perlbrew.
#
# @params UNINSTALLER The command used to uninstall new software versions.
#         VERSION     The new version to be uninstalled.
################################################################################
uninstall_version() {
  local -r INSTALLER="${1}"
  local -r VERSION="${2}"

  "${INSTALLER}" uninstall "${VERSION}"

  if [[ "${?}" != "${SUCCESS}" ]]; then
    exit_with_error "${UNINSTALL_ERROR}" "Failed to uninstall version ${VERSION}."
  fi
}


################################################################################
# Checks latest stable version against latest installed version & updates the
# installed version if required.
################################################################################
upgrade {
  local -r LATEST_INSTALLED="${1}""
  local -r LATEST_STABLE="${2}"

  if [[ "${LATEST_INSTALLED}" != "${LATEST_STABLE}" ]]; then
    install_version "${LATEST_STABLE}"
    clone_libraries "${LATEST_INSTALLED}" "${LATEST_STABLE}"
 fi

  clean_installations "${LATEST_INSTALLED}" "${LATEST_STABLE}"
}
