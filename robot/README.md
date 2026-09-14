# Compy robot for the TPBot

Driving an ElecFreaks TPBot from a Compy program, so that children
can move a real robot by calling one function.

Two halves talk over a plain-text serial protocol: a firmware on
the micro:bit that turns command lines into motor movement, and a
Lua transport on the Compy side that ships those lines and exposes
`robot_move` to lesson programs. The protocol is the contract
between them, and it is deliberately text-based so it can be
driven by hand from a terminal.

This approach is being replaced; see
[tpbot-old-firmware](tpbot-old-firmware/README.md).

## Getting it running

1. Flash the micro:bit with `tpbot-old-firmware/firmware.py` — see
   `tpbot-old-firmware/FLASHING.md` — and smoke-test it from a
   terminal using the recipe at the end of
   `tpbot-old-firmware/PROTOCOL.md`. This needs no Compy device and
   proves the firmware and the robot independently of everything
   else.
2. Emit the three Compy projects with `robot/.compy/build <out-dir>`
   and copy them onto a device like any other program — no Compy
   build involved. `robot` is the program a child edits; `robot_c`
   adds the console front end; `robot_w` is the wheel bench.
3. Open `robot_c` on the device and drive the robot from the prompt —
   see RUNNING.md.

## Contents

| Path | What it is |
| --- | --- |
| `tpbot-old-firmware/` | The micro:bit firmware, its wire protocol, flashing steps and tests |
| `*.lua` | Compy-side Lua modules, their suites, and the `main.lua` each emitted project starts from |
| `fakeFirmware.py` | A firmware simulator on a pseudo-terminal, for the suites |
| `.compy/build` | Emits the `robot`, `robot_c` and `robot_w` Compy projects from these modules |
| `run_tests.sh` | Runs the suites and the firmware tests |
| `RUNNING.md` | Running the suites, a real robot from a shell, the three Compy projects, bring-up and failure stages |

## Status

Working on hardware end to end: a `robot_move` call on a Compy
device drives a real TPBot — the call goes through the Lua
module, LuaJIT FFI into JNI, the Android USB host API, a CDC-ACM
serial link, the firmware, and I2C to the motors. Forward, turn in
place, reverse and full speed all behave.

The I2C motor format was reconstructed from the official
ElecFreaks extension; it matches the one in `nagydani/microbit-lua`
and it drives the real chassis.

Sandbox only: the POSIX serial backend, which exists for
development and CI rather than for the classroom, is exercised
against a pseudo-terminal firmware simulator.

Not started: calibration figures for the lesson — how far the
robot travels at a given percentage, how much it drifts — which
need a tape measure and a floor.

## Running the tests

From the repository root, with `lua` 5.1 or `luajit`:

    python3 robot/tpbot-old-firmware/test_firmware.py
    luajit robot/testLineReader.lua

The suites that talk to a serial port need the simulator running
and its device path passed in:

    python3 robot/fakeFirmware.py &      # prints the pty path
    luajit robot/testSerial.lua /dev/pts/N
    luajit robot/testTransport.lua /dev/pts/N
    luajit robot/testMove.lua /dev/pts/N
