#!/bin/bash

here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"
source "${here}/../util.sh"

testname="$(echo $(basename $0) | awk -F '.' '{print $1}')"

function testbody
{
  magenta "Test in ${workspace}"
  box_entrypoint_name="${testname}-entryopint"
  options="BOX_ENTRYPOINT_NAME=${box_entrypoint_name}"
  printf '\r' | run_boxkit "${options}"
  [[ ! -e "${workspace}/${box_entrypoint_name}" ]] && return $FAILED
  return $PASSED
}

with_workspace "${testname}" "testbody"
exit $?
