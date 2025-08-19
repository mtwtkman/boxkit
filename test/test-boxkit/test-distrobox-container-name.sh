#!/bin/bash

here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"
source "${here}/../util.sh"

testname="test-distrobox-container-name"

function testbody
{
  magenta "Test in ${workspace}"
  distrobox_container_name="${testname}-container"
  options="DISTROBOX_CONTAINER_NAME=${distrobox_container_name}"
  root="{workspace}/"
  return $PASSED
}

with_workspace "${testname}" "testbody"
exit $?
