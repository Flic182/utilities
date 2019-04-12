#!/usr/bin/env bash

################################################################################
# This script takes a Kinesis data block, decodes and unzips it, and pretty
# prints its original JSON content.
################################################################################

USAGE="USAGE:  $0 -d <kinesis_data_block>"

if [ "$#" -ne 2 ]
then
  echo "${USAGE}"
  exit 1
fi

while getopts "d:" opt; do
  case $opt in
    d)
      ENCRYPTED_DATA="${OPTARG}"
      ;;
    \?)
      echo "${USAGE}"
      exit 1
      ;;
  esac
done

base64 -D <<< "${ENCRYPTED_DATA}" | zcat | python -m json.tool
echo ""

exit 0
