#!/usr/bin/env bash
#
# Run the test suites. With no argument, runs all of them.
#
# Everything runs from the repository root so that the dotted
# require paths resolve the same way they do inside a Compy
# build.
#
# The pty suites need a firmware to talk to: this starts
# robot/fakeFirmware.py on a pseudo-terminal, hands the device
# to the suite as arg[1], and kills the firmware when the suite
# touches /tmp/kill_now -- which is how the suites test a device
# that dies mid-session.
#
set -uo pipefail

cd "$(dirname "$0")"

PTY_SUITES=(robot/testSerial.lua robot/testTransport.lua
            robot/testMove.lua)

# One pty suite: firmware up, suite, firmware down.
run_pty_suite() {
  local suite=$1 fw_pid dev watch_pid rc
  rm -f /tmp/kill_now /tmp/pty_name

  # setsid: uv starts python as a child, so the whole process
  # group has to die, not just the wrapper.
  setsid uv run python robot/fakeFirmware.py \
    >/tmp/fake_fw.log 2>&1 &
  fw_pid=$!

  for _ in $(seq 1 50); do
    [[ -s /tmp/pty_name ]] && break
    sleep 0.1
  done
  dev=$(cat /tmp/pty_name 2>/dev/null)
  if [[ -z $dev ]]; then
    echo "firmware did not start:"
    cat /tmp/fake_fw.log
    kill -9 -"$fw_pid" 2>/dev/null
    return 1
  fi

  ( while kill -0 "$fw_pid" 2>/dev/null; do
      [[ -e /tmp/kill_now ]] && { kill -9 -"$fw_pid" 2>/dev/null; break; }
      sleep 0.1
    done ) &
  watch_pid=$!

  luajit "$suite" "$dev"
  rc=$?

  kill -9 -"$fw_pid" "$watch_pid" 2>/dev/null
  rm -f /tmp/kill_now /tmp/pty_name
  return $rc
}

needs_pty() {
  local s
  for s in "${PTY_SUITES[@]}"; do
    [[ $s == "$1" ]] && return 0
  done
  return 1
}

run_suite() {
  local suite=$1
  echo "=== $suite ==="
  if needs_pty "$suite"; then
    run_pty_suite "$suite"
  else
    luajit "$suite"
  fi
}

failed=0

if [[ $# -gt 0 ]]; then
  run_suite "$1" || failed=1
else
  for suite in robot/testLineReader.lua "${PTY_SUITES[@]}"; do
    run_suite "$suite" || failed=1
  done
  echo "=== test_firmware.py ==="
  uv run python test_firmware.py || failed=1
fi

echo
if [[ $failed -eq 0 ]]; then
  echo "ALL SUITES PASS"
else
  echo "SUITE FAILURES"
fi
exit $failed
