#!/usr/bin/env bash

################################################################################
# This script is a library of common command-line-related functions for use by
# other scripts.
################################################################################


################################################################################
# File and command info
################################################################################
readonly ALLOWED_FLAGS="^-[c]$"
readonly HANDLERS_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)/../handlers"

################################################################################
# Include error handling functionality.
################################################################################
. "${HANDLERS_DIR}/ErrorHandling.sh"


################################################################################
# Exit states.
################################################################################
readonly BAD_ARGUMENT_ERROR=98


################################################################################
# Command line switch environment variables.
################################################################################
clean_installs="${FALSE}"


################################################################################
# Checks command line arguments are valid and have valid arguments.  Currently
# handles -c (for clean) in updaters scripts.
#
# @param $@ All arguments passed on the command line.
################################################################################
check_args() {
  local -r CMD_USAGE="$("shift")"
  local option=""

  shift
  while [[ ${#} -gt 0 ]]; do
    option="${1}"
    case "${option}" in
      -c)
         if ! [[ "${2}" =~ ${ALLOWED_FLAGS} ]] && [[ ${#} -gt 1 ]]; then
           exit_with_error "${BAD_ARGUMENT_ERROR}" \
                           "Option ${1} does not require an argument.  Usage:  ${CMD_USAGE}"
         else
           clean_installs="${TRUE}"
         fi
        ;;
      *)
        exit_with_error "${BAD_ARGUMENT_ERROR}" \
                        "Invalid option: ${option}.\n${CMD_USAGE}"
        ;;
    esac
    shift
  done
}

