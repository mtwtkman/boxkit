#!/bin/bash

function _message
{
  color="${1}m"
  shift
  echo -e "\033[0;${color}${@}\033[0m"
}

function green
{
  _message "32" $@
}

function red
{
  _message "31" $@
}

function yellow
{
  _message "33" $@
}

function cyan
{
  _message "36" $@
}

function magenta
{
  _message "35" $@
}

function run_boxkit
{
  test "${BOXKIT_TEST_VERBOSE}" && set -x
  options="${1}"
  argument="${2:-}"
  here="$(readlink -m $(dirname ${BASH_SOURCE[0]}))"
  boxkit="$(readlink -f ${here}/../boxkit)"
  cmd="sh ${boxkit} ${argument}"
  test "${options}" && cmd="${options} ${cmd}"
  yellow "Run: ${cmd}" >&2
  eval "${cmd}"
  result=$?
  test "{BOXKIT_TEST_VERBOSE}" && set +x
  return "${result}"
}

PASSED="0"
FAILED="1"

function is_passed
{
  test "$1" == "$PASSED" &> /dev/null
}

function is_failed
{
  ! is_passed "$1"
}

function assert_matches_string
{
  actual="${1}"
  expected="${2}"
  echo "${actual}" | grep -E "${expected}" &> /dev/null
}

function assert_exists_file
{
  actual="${1}"
  [[ -e "${actual}" ]]
}

function assert_includes_string
{
  actual="${1}"
  expected="${2}"
  cat "${1}" | grep -E "${expected}" &> /dev/null
}

function setup_testing_workspace
{
  testname="${1}"
  unique_id="$(date +%s)"
  workspace="/tmp/boxkit-test/${testname}.${unique_id}"
  mkdir -p "${workspace}"
  echo "${workspace}"
}

function teardown_testing_workspace
{
  workspace="${1}"
  /bin/rm -rf ${workspace}
}

function with_workspace
{
  testname="${1}"
  testfunc="${2}"
  shift
  shift
  workspace=$(setup_testing_workspace "${testname}")
  pushd "${workspace}" &> /dev/null
  eval "${testfunc} ${@}"
  result=$?
  popd &> /dev/null
  teardown_testing_workspace "${workspace}"
  return ${result}
}
