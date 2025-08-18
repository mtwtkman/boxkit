#!/bin/bash
here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"

source "${here}/../../util.sh"

actual=$(run_boxkit "" "--help")
result="$?"

if is_failed "$?"; then
  exit $?
elif [[ $(echo "${actual}" | grep -E 'USAGE:') ]]; then
  exit $PASSED
else
  exit $FAILED
fi
