#!/bin/bash

here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"
source "${here}/../../util.sh"

testname="test-full-option"

op1="DISTROBOX_CONTAINER_NAME=${testname}"
op2="BOX_ENTRYPOINT_NAME=${testname}-entrypoiunt.sh"
op3="DISTROBOX_HOME_NAME=${testname}-home"
op4="BOX_SCRIPT_NAME=${testname}-box"
op5="DISTROBOX_IMAGE_NAME=${testname}-img"

options="${op1} ${op2} ${op3} ${op4} ${op5}"

workspace=$(setup_testing_workspace "${testname}")

echo "Test in ${workspace}"
pushd "${workspace}"
popd

# teardown_testing_workspace "${workspace}"
