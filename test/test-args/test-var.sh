#!/bin/bash

here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"

source "${here}/../util.sh"

actual=$(run_boxkit "" "help")
result="$?"

if is_failed "${result}"; then
  exit $?
elif $(assert_matches_string "${actual}" 'USAGE:') ; then
  exit $PASSED
else
  exit $FAILED
fi
