#!/usr/bin/env bash

################################################################################
# This script keeps AWS sessions alive by requesting a new token with saml2aws.
# The first time the script is run for a given profile, it will try to create an
# automated job that recalls the script for that profile five minutes before the
# session is due to expire.  It re-uses the account last used with the nominated
# profile, keeping track of the profile+account+timeout triplet in
# ~/.aws/history.
#
# NOTE:  If the timeout for a given account is invalid, the settings are NOT
#        saved to ~/.aws/history.
#
# The program can be called with the following arguments (both are optional):
# -a <account> The name of the AWS account to use.  The first time a new profile
#              is nominated, the account MUST be specified as well.  If you
#              change the account in use for a profile, you must specify the
#              timeout as well or the default timeout will be used.
# -p <profile> The name of the AWS profile to use.  If not set, the script will
#              use 'default'.
# -t <timeout> Desired session timeout (in seconds).  Max is 12 hours - 43200,
#              default is the minimum session length of 1 hour - 3600.
#
# If you wish to change the account or timeout used with a given profile, simply
# run the script manually to update the schedule.
################################################################################


################################################################################
# Usage, file path & miscellaneous constants.
################################################################################
readonly USAGE="USAGE:  $0 [-a <account>] [-p <profile>] [-t <timeout>]"
readonly ALLOWED_FLAGS="^-[apt]$"

readonly WORKING_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"
readonly SCRIPT_NAME="$("basename" "${BASH_SOURCE[0]}")"

readonly AWS_DIR="${HOME}/.aws"
readonly AWS_CREDENTIALS="${AWS_DIR}/credentials"
readonly AWS_HISTORY="${AWS_DIR}/history"

readonly TOKEN_EXPIRY_REGEX="^x_security_token_expires..*"


################################################################################
# Include error handling functionality.
################################################################################
. "${WORKING_DIR}/../handlers/ErrorHandling.sh"


################################################################################
# Session-related time constants, in seconds.
################################################################################
readonly MAX_SESSION=43200
readonly MIN_SESSION=3600
readonly REFRESH_BUFFER=300


################################################################################
# Script-specific exit states.
################################################################################
readonly NO_SESSION_ERROR=96
readonly UNHANDLED_OS_ERROR=97


################################################################################
# Command line switch environment variables.
################################################################################
account=""
profile="default"
timeout=""


################################################################################
# Tracker to determine if a new timeout is mandatory.  If so and one is not
# supplied, the default value of ${MIN_SESSION} is used.
################################################################################
reset_timeout="${FALSE}"


################################################################################
# Checks command line arguments are valid and have valid arguments.
#
# @param $@ All arguments passed on the command line.
################################################################################
check_args() {
  local new_profile=""
  local new_timeout=""
  local option=""

  while [[ ${#} -gt 0 ]]; do
    option="${1}"
    case "${option}" in
      -a)
        while ! [[ "${2}" =~ ${ALLOWED_FLAGS} ]] && [[ ${#} -gt 1 ]]; do
          account="${2}"
          shift
        done

        if [[ "${account}" == "" ]]; then
          exit_with_error "${BAD_ARGUMENT_ERROR}" \
                          "Option ${option} requires an argument.\n${USAGE}"
        fi
        ;;
      -p)
        while ! [[ "${2}" =~ ${ALLOWED_FLAGS} ]] && [[ ${#} -gt 1 ]]; do
          new_profile="${2}"
          shift
        done

        if [[ "${new_profile}" != "" ]]; then
          profile="${new_profile}"
        else
          exit_with_error "${BAD_ARGUMENT_ERROR}" \
                          "Option ${option} requires an argument.\n${USAGE}"
        fi
        ;;
      -t)
        while ! [[ "${2}" =~ ${ALLOWED_FLAGS} ]] && [[ ${#} -gt 1 ]]; do
          new_timeout="${2}"
          shift
        done

        if [[ "${new_timeout}" != "" ]]; then
          timeout="${new_timeout}"

          if ((timeout < MIN_SESSION || timeout > MAX_SESSION)); then
            exit_with_error "${BAD_ARGUMENT_ERROR}" \
                            "Option ${option} must be between ${MIN_SESSION} & ${MAX_SESSION} seconds.\n${USAGE}"
          fi
        else
          exit_with_error "${BAD_ARGUMENT_ERROR}" \
                          "Option ${option} requires an argument.\n${USAGE}"
        fi
        ;;
      *)
        exit_with_error "${BAD_ARGUMENT_ERROR}" \
                        "Invalid option: ${option}.\n${USAGE}"
        ;;
    esac
    shift
  done
}


################################################################################
# Removes the token expiry line from the AWS credentials file for the nominated
# profile.
#
# This line only seems to be used by saml2aws to stop requests for new tokens
# within the timeout, so removing it before expiry should not interfere with
# AWSCLI calls using the old token while we retrieve a new one.
################################################################################
clear_token() {
  sed -i "" -e '/^\['"${profile}"'\]$/,/'"${TOKEN_EXPIRY_REGEX}"'/{/'"${TOKEN_EXPIRY_REGEX}"'/d;};' \
      "${AWS_CREDENTIALS}"
}


################################################################################
# Creates a recurring job so the session for the current profile is kept
# active.  Currently only works for macos.
################################################################################
create_job () {
  local -r KERNEL_NAME="$("uname" "-s" | "tr" "[:upper:]" "[:lower:]")"

  case "${KERNEL_NAME}" in
    darwin)
          create_mac_agent
          ;;
    *)
          exit_with_error "${UNHANDLED_OS_ERROR}" \
                          "Unknown operating system - ${KERNEL_NAME}.  Exiting."
  esac
}


################################################################################
# Creates a recurring launchctl job on macos so the session for the current
# profile is kept active.
#
# Note:  The job will write both stdout and stderr streams to /dev/null.  If the
#        script does not appear to run from launchd, you can change the
#        StandardErrorPath and StandardOutPath keys at the bottom of the file to
#        redirect output to log files.  Please ensure any such files are subject
#        to external log maintenance (rotation/clearing via logrotate, for
#        example) as this script makes no attempt to manage logs.
################################################################################
create_mac_agent() {
  local -r PLIST_FILE="${HOME}/Library/LaunchAgents/com.flic.AwsKeepAlive.plist"
  local -r PLIST_SERVICE="com.flic.awskeepalive.activator"
  local -r SERVICE_LOADED="$("launchctl" "list" | "grep" "${PLIST_SERVICE}")"
  local -r SESSION_REFRESH_SECS="$((timeout - REFRESH_BUFFER))"

  if [[ -f "${PLIST_FILE}" ]]; then
    if [[ "${SERVICE_LOADED}" != "" ]]; then
      launchctl unload "${PLIST_FILE}"
      launchctl remove "${PLIST_SERVICE}"
    fi
    rm -f -- "${PLIST_FILE}"
  fi

  cat << EOF > "${PLIST_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${PLIST_SERVICE}</string>
    <key>ProgramArguments</key>
    <array>
      <string>${WORKING_DIR}/${SCRIPT_NAME}</string>
      <string>-p</string>
      <string>${profile}</string>
    </array>

    <key>Nice</key>
    <integer>1</integer>

    <key>StartInterval</key>
    <integer>${SESSION_REFRESH_SECS}</integer>

    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
  </dict>
</plist>
EOF

  launchctl load "${PLIST_FILE}"
}


################################################################################
# Prints the account last used for the current profile as stored in the history
# file.
################################################################################
get_account() {
  sed -n 's/^'"${profile}"' \([^ ][^ ]*\).*$/\1/p' < "${AWS_HISTORY}"
}


################################################################################
# Prints the session timeout last used for the current profile as stored in the
# history file.
################################################################################
get_timeout() {
  sed -n 's/^'"${profile}"' [^ ][^ ]* \(..*\)$/\1/p' < "${AWS_HISTORY}"
}


################################################################################
# Sets the account according to the last one used for the nominated profile if
# no account supplied on the command line.  We need both when calling saml2aws.
# If the account has been set from the command line, the function also sets an
# environment variable that forces a timeout reset.
################################################################################
set_account() {
  if [[ "${account}" == "" ]]; then
    # Read account from login history, based on profile.
    account="$("get_account")"

    if [[ "${account}" == "" ]]; then
      exit_with_error "${BAD_ARGUMENT_ERROR}" \
                      "Profile *${profile}* not previously logged - account must be nominated.\n${USAGE}"
    fi
  else
     reset_timeout="${TRUE}"
  fi
}


################################################################################
# Ensures the credentials and history files exist and the history file only
# contains valid profile+account+timeout triplets.
################################################################################
set_aws_files() {
  if [[ ! -f "${AWS_CREDENTIALS}" ]]; then
    mkdir -p "${AWS_DIR}" && touch "${AWS_CREDENTIALS}"
  fi

  if [[ ! -f "${AWS_HISTORY}" ]]; then
    touch "${AWS_HISTORY}"
  else
    sed -i "" -e '/^[^ ][^ ]* [^ ][^ ]* [0-9][0-9]*$/!d' ${AWS_HISTORY}
  fi
}


################################################################################
# Records the account and profile used for this login to the history file.  If
# the profile is not in the history file or the timeout has changed, the program
# will also (re)create a job to keep the session active.
################################################################################
set_history() {
  local -r OLD_ACCOUNT="$("get_account")"
  local -r OLD_TIMEOUT="$("get_timeout")"

  if [[ "${OLD_ACCOUNT}" != "" ]]; then
    # Subsequent run for profile
    if (( OLD_TIMEOUT != timeout )); then
      sed -i "" "s/^\(${profile}\) ${OLD_ACCOUNT} ${OLD_TIMEOUT}$/\1 ${account} ${timeout}/" "${AWS_HISTORY}"
      create_job
    else
      sed -i "" "s/^\(${profile}\) ${OLD_ACCOUNT}\(..*\)$/\1 ${account}\2/" "${AWS_HISTORY}"
    fi
  else
    # First run for profile.  Only keep active profile in history.
    > "${AWS_HISTORY}"
    echo "${profile} ${account} ${timeout}" >> "${AWS_HISTORY}"
    create_job
  fi
}


################################################################################
# Sets the timeout according to the last one used for the nominated profile if
# the account has not changed AND no timeout was supplied on the command line
# (in which case, $timeout is empty).  We need to ensure we don't overwrite a
# previous timeout setting if we have not changed the account or explicitly set
# a new value.
################################################################################
set_timeout() {
  if [[ "${timeout}" == "" ]]; then
    if (( reset_timeout == FALSE )); then
      # Read account from login history, based on profile.
      timeout="$("get_timeout")"
    fi

    if [[ "${timeout}" == "" ]]; then
      timeout="${MIN_SESSION}"
    fi
  fi
}


################################################################################
# Creates a saml2aws session.
################################################################################
start_session() {
  echo -ne "${account}\n" | \
       /usr/local/bin/saml2aws login -p "${profile}" --session-duration ${timeout} --skip-prompt

  if [[ "${?}" != "${SUCCESS}" ]]; then
    exit_with_error "${NO_SESSION_ERROR}" \
                    "Could not connect with profile ${profile}, account ${account} & timeout ${timeout}."
  fi
}


################################################################################
# Entry point to the program.  Valid command line options are described at the
# top of the script.
#
# @param ARGS Command line flags, including -a <account name> and
#             -p <profile name>.  Both are optional.
################################################################################
main() {
  local -r ARGS=("${@}")

  check_args "${ARGS[@]}"
  set_aws_files
  set_account
  set_timeout
  clear_token
  start_session
  set_history
}


################################################################################
# Set up for bomb-proof exit, then run the script
################################################################################
trap_with_signal cleanup HUP INT QUIT ABRT TERM EXIT

main "${@}"

exit ${SUCCESS}
