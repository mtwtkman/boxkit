#!/bin/bash

here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"
source "${here}/../util.sh"

testname="$(echo $0 | awk -F '.' '{print $1}')"

function testbody
{
  magenta "Test in ${workspace}"
  distrobox_container_name="${testname}-container"
  options="DISTROBOX_CONTAINER_NAME=${distrobox_container_name}"
  root="{workspace}/"
  run_boxkit "${options}"
  return $PASSED
}

with_workspace "${testname}" "testbody"
exit $?
