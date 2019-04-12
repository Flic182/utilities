#!/usr/bin/env bash

################################################################################
# This script runs JMeter, using the JMETER_HOME environment variable to find
# the executable.
#
# Using this in preference to hardcoding the executable's path in IntelliJ as an
# External Tool.
################################################################################

jmeter "${@}"
JMETER_RETURN="${?}"

if (( JMETER_RETURN != 0 )); then
  echo "\$JAVA_HOME is currently *${JAVA_HOME}*.  This MAY NOT be compatible with JMeter!"
fi

exit ${JMETER_RETURN}
