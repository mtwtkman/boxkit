#!/bin/bash

here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"
source "${here}/../util.sh"

testname="$(echo $(basename $0) | awk -F '.' '{print $1}')"

function testbody
{
  magenta "Test in ${workspace}"
  distrobox_container_name="${testname}-container"
  box_entrypoint_name="${testname}-entrypoint"
  distroboxy_home_name="${testname}-home"
  box_script_name="${testname}-script"
  distrobox_iamge_name="${testname}-image"
  op1="DISTROBOX_CONTAINER_NAME=${distrobox_container_name}"
  op2="BOX_ENTRYPOINT_NAME=${box_entrypoint_name}"
  op3="DISTROBOX_HOME_NAME=${distroboxy_home_name}"
  op4="BOX_SCRIPT_NAME=${box_script_name}"
  op5="DISTROBOX_IMAGE_NAME=${distrobox_iamge_name}"
  options="${op1} ${op2} ${op3} ${op4} ${op5}"
  root="${workspace}/${box_entrypoint_name}"
  stdout="$(run_boxkit "${options}")"
  ! assert_matches_string "${stdout}" "^Your development container name is .*${distrobox_container_name}.*" && return $FAILED
  ! assert_matches_string "${stdout}" "create .*${root}/${distroboxy_home_name}.*" && return $FAILED
  ! assert_matches_string "${stdout}" "create .*${root}/distrobox\.ini.*" && return $FAILED
  ! assert_matches_string "${stdout}" "create .*${root}/${box_script_name}.*" && return $FAILED
  ! assert_matches_string "${stdout}" "Now you can run \`./box enter\` to start distrobox.$" && return $FAILED
  ! assert_exists_file "${root}/${distroboxy_home_name}" && return $FAILED
  ! assert_exists_file "${root}/distrobox.ini" && return $FAILED
  ! assert_exists_file "${root}/${box_script_name}" && return $FAILED
  return $PASSED
}

with_workspace "${testname}" "testbody"
exit $?
