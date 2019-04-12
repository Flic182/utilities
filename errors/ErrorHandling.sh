#!/usr/bin/env bash

################################################################################
# This script is a library of common error-related functions for use by other
# scripts.
################################################################################


################################################################################
# Define booleans.
################################################################################
readonly FALSE=0
readonly TRUE=1

################################################################################
# Exit states.
################################################################################
readonly SUCCESS=0
readonly UNDEFINED_ERROR=1
readonly SCRIPT_INTERRUPTED=99


################################################################################
# Executes clean up tasks required before exiting - basically writing the
# interrupt signal to stderr.
#
# @param SIGNAL The signal that triggered the cleanup.
#
# Note:  This function is assigned to signal trapping for the script so any
#        unexpected interrupts are handled gracefully.
################################################################################
cleanup() {
  local -r SIGNAL="${1}"

  # Exit and indicate what caused the interrupt
  if [[ "${SIGNAL}" != "EXIT" ]]; then
    write_log "Script interrupted by '${SIGNAL}' signal"

    if [[ "${SIGNAL}" != "INT" ]] && [[ "${SIGNAL}" != "QUIT" ]]; then
      exit ${SCRIPT_INTERRUPTED}
    else
      kill -"${SIGNAL}" "$$"
    fi
  fi
}


################################################################################
# Exits with the given value after logging an error message (if supplied).
#
# @param ERROR_EXIT    The value with which to exit if RETURN_VAL was non-zero.
# @param ERROR_MESSAGE The error message to log if an exit is required.
################################################################################
exit_with_error() {
  local -r ERROR_EXIT="${1}"
  local -r ERROR_MESSAGE="${2}"

  if [[ "${ERROR_MESSAGE}" != "" ]]; then
    write_log "${ERROR_MESSAGE}"
  fi

  exit ${ERROR_EXIT}
}


################################################################################
# Sets up a trap to execute the nominated function for passed signals.
#
# @param TRAP_FUNCTION The function to execute when a signal is trapped by the
#                      script.
################################################################################
trap_with_signal() {
  local -r TRAP_FUNCTION="${1}"

  shift
  for trapped_signal; do
    trap "${TRAP_FUNCTION} ${trapped_signal}" "${trapped_signal}"
  done
}


################################################################################
# Writes log messages (for the script) with a date prefix to a known place.  For
# now, stderr will do.
#
# @param LOG_MESSAGE The message to write.
################################################################################
write_log() {
  local -r LOG_MESSAGE="${1}"
  local -r LOG_DATE_FORMAT='+%Y-%m-%d %H:%M:%S'

  printf "$("date" "${LOG_DATE_FORMAT}") - ${LOG_MESSAGE}\n" 1>&2
}
