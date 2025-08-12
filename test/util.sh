#!/bin/bash
function _message
{
  color=$1
  shift
  echo -e "\033[0;${color}${@}\033[0m"
}

function green
{
  _message "32m" $@
}

function red
{
  _message "31m" $@
}

function yellow
{
  _message "33m" $@
}

function cyan
{
  _message "36m" $@
}

function run_boxkit
{
  test "${BOXKIT_TEST_VERBOSE}" && set -x
  options=$1
  argument=$2
  here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"
  boxkit="${here}/../boxkit"
  cmd="sh ${boxkit} ${argument}"
  test "${options}" && cmd="${options} ${cmd}"
  yellow "Run: ${cmd}" >&2
  eval "${cmd}"
  result=$?
  test "{BOXKIT_TEST_VERBOSE}" && set +x
  return "${result}"
}

function passed
{
  echo "0"
}

function failed
{
  echo "1"
}

function is_passed
{
  test "$1" == $(passed)
}

function is_failed
{
  ! is_passed "$1"
}

function setup_testing_workspace
{
  testname="${1}"
  unique_id="$(date +%s)"
  workspace="${here}/../testing-workspace/${testname}.${unique_id}"
  mkdir -p "${workspace}"
  cd "${workspace}"
  return "${workspace}"
}

function teardown_testing_workspace
{
  workspace="${1}"
  /bin/rm -rm ${workspace}
}
