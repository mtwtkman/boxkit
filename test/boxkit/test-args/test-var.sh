#!/bin/bash
here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"

source "${here}/../../util.sh"

actual=$(run_boxkit "" "help")
result="$?"

if is_failed "$?"; then
  echo $?
elif [[ $(echo "${actual}" | grep -E 'USAGE:') ]]; then
  passed
else
  failed
fi
