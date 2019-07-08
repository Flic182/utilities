#!/usr/bin/env bash

################################################################################
# This script verifies the integrity of a file by validating its checksum and
# signature (if available).  GPG must already be installed.
#
# The script expects the following arguments:
# -a <algorithm> This can be either MD5 (md5) or any SHA supported by shasum,
#                expressed as 'sha' followed by the number - e.g. sha1, sha256,
#                sha512.  
# -h <hash>      The hash value expected for the file.  (Provided by the
#                software author.)
# <target_file>  The file to be checked.
#
# NOTE:  This script does not perform a virus scan (which should also be done)
#        and only verifies a signature against a previously saved public key.
#        It is up to the end user to ensure the public key used to verify a
#        signature is legitimate - GPG will mention this to the user.
################################################################################


################################################################################
# File and command info
################################################################################
readonly USAGE="USAGE:  $0 -a <checksum algorithm - e.g. sha256/sha512/md5> -h <expected hash> <target file>"
readonly WORKING_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"


################################################################################
# User feedback messages.
################################################################################
readonly GOOD_SUM="Checksum OK."
readonly LOG_DATE_FORMAT='+%Y-%m-%d %H:%M:%S'


################################################################################
# Include error handling functionality.
################################################################################
. "${WORKING_DIR}/../handlers/ErrorHandling.sh"


################################################################################
# Exit states.
################################################################################
readonly UNSUPPORTED_ALGORITHM=97


################################################################################
# Environment variables set from command line options.
################################################################################
algorithm=""
expected_hash=""
target_file=""


################################################################################
# Checks command line arguments are valid and have valid arguments.
#
# @param $@ All arguments passed on the command line.
################################################################################
check_args() {
  if [ "$#" -ne 5 ]
  then
    echo "${USAGE}"
    exit ${BAD_ARGUMENT_ERROR}
  fi

  while getopts ":a:h:" opt; do
    case $opt in
      a)
        algorithm="$("tr" "[:upper:]" "[:lower:]" <<< "${OPTARG}")"
        ;;
      h)
        expected_hash="${OPTARG}"
        ;;
      \?)
        echo "${USAGE}"
        exit ${BAD_ARGUMENT_ERROR}
        ;;
    esac
  done

  shift $((OPTIND - 1))
  target_file="${1}"
}


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
# Verifies checksum is OK.
#
# It is assumed the script is being run on either a Linux or Mac machine and the
# MD5 executable is either md5sum (Linux) or md5 (Mac).
################################################################################
verify_checksum() {
  local md5_prog=""

  if [[ "${algorithm}" =~ ^sha[0-9]+$ ]]; then
    algorithm="$("sed" "-E" "s/sha([0-9]+)/\\1/" <<< "${algorithm}")"
    shasum -a "${algorithm}" "${target_file}" | \
     awk -v expected_hash="${expected_hash}" -v ok_msg="${GOOD_SUM}" \
         'tolower($1) == tolower(expected_hash) {print ok_msg}'
  elif [[ "${algorithm}" == "md5" ]]; then
    md5_prog="$("command" "-v" "md5sum" &> "/dev/null" && \
                "echo" "md5sum" || "echo" "md5")"
    "${md5_prog}" "${target_file}" | \
     awk -v expected_hash="${expected_hash}" -v ok_msg="${GOOD_SUM}" \
         'tolower($4) == tolower(expected_hash) {print ok_msg}'
  else
    echo "Unsupported algorithm!"
    exit ${UNSUPPORTED_ALGORITHM}
  fi
}


################################################################################
# Verifies signature is OK, if one exists in the same directory.  Should be same
# name as target, with .asc or .sig extension.
################################################################################
verify_signature() {
  if [[ -f "${target_file}.asc" ]]; then
    gpg --verify "${target_file}.asc" "${target_file}"
  elif [[ -f "${target_file}.sig" ]]; then
    gpg --verify "${target_file}.sig" "${target_file}"
  else
    echo "No signature found to verify."
  fi
}


################################################################################
# Writes log messages (for the script) with a date prefix to a known place.  For
# now, stderr will do.
#
# @param LOG_MESSAGE The message to write.
################################################################################
write_log() {
  local -r LOG_MESSAGE="${1}"

  echo "$("date" "${LOG_DATE_FORMAT}") - ${LOG_MESSAGE}" 1>&2;
}


################################################################################
# Entry point to the program.  Valid command line options are described at the
# top of the script.
#
# @param ARGS Command line arguments, including -a <algorithm>,
#             -h <expected hash> and the target file.
################################################################################
main() {
  local -r ARGS=("${@}")

  check_args "${ARGS[@]}"
  verify_checksum
  verify_signature
}


################################################################################
# Set up for bomb-proof exit, then run the script
################################################################################
trap_with_signal cleanup HUP INT QUIT ABRT TERM EXIT

main "${@}"

exit ${SUCCESS}
