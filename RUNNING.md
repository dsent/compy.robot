# Running and testing the robot code

Three ways to exercise this code, in rising order of what they need:
the test suites need nothing but LuaJIT, a development machine with the
micro:bit plugged in runs the real thing from a shell, and the Compy runs
it as a Compy program or straight from the console prompt.

## The test suites

`run_tests.sh` runs everything. It starts `fake_firmware.py` on a
pseudo-terminal, hands the device to each suite, and kills the firmware
when a suite asks for it (the mid-session device-death case):

    ./run_tests.sh

Individual suites, when a failure needs a closer look:

    ./run_tests.sh test_robot_serial.lua
    luajit test_robot_line_reader.lua          # needs no firmware
    uv run python test_firmware.py             # firmware protocol logic

`test_firmware.py` mocks the `microbit` and `micropython` modules, so it
covers everything in `firmware.py` except the real I2C bus and real UART
timing. Those need the device.

## A real robot from a development machine

Flash `firmware.py` to the micro:bit (`FLASHING.md`), plug it into the
machine, and the posix backend drives it from bare LuaJIT:

    luajit main.lua

That runs the starter program. For a single move:

    luajit -e 'require("robot_move"); print(robot_move(20, 80, 1))'

This exercises the whole stack — protocol, framing, timeouts, error
messages — except the Android backend, which needs the Compy.

## On the Compy

The `.compy/build` script emits two Compy projects:

- `robot` — the runtime plus a `main.lua` a child edits and runs.
- `robot_c` — the same runtime plus `robot_console.lua`, for driving the
  robot from the console prompt.

### As a program

`main.lua` calls `robot_move` directly:

    require("robot_move")

    robot_move(-40, 40, 1)   -- spin one way
    robot_move(40, -40, 1)   -- and back again

The robot connects on the first move. `robot_connect()` exists to check
that the robot is there and answering, and is never required.

### From the console

Open the console project, load the front end, and drive it a line at a
time. Lua calls a function with a single string without parentheses, so
a move is three numbers in quotes:

    project"robot_c"
    require"robot_console"
    m"40 -40 1"

`m` reports `ok`, or the same kid-readable message a program would raise,
so nothing needs wrapping in `print()`.

## What to expect

**The USB permission dialog.** The first connection after an install asks
the child to allow access to the micro:bit. Android remembers the answer.

**Blocking moves.** `robot_move` returns when the wheels stop, so a
four-second move freezes the screen for four seconds. Measured on the
device: no Android "not responding" dialog, even with input arriving
throughout. `LINE_READER_IDLE` in `robot_line_reader.lua` is the hook for
an event pump if longer moves ever need one.

**A few milliseconds per move.** Each command opens the port, talks, and
closes it. Measured on the device: about 40 ms on top of the movement.
That is what makes a program safe to stop at any line — see below.

## Constraints worth knowing

**Nothing is held between commands, on purpose.** On Android an open USB
connection owns its interface claim, and the claim belongs to the app
rather than to the Lua state. A program that stops on an error takes its
connection with it, and no cleanup we could write would ever run: the
robot would stay locked until the app was restarted. Opening per command
costs milliseconds and cannot leak. Programs need no cleanup line, and a
child can run a program that crashes as often as they like.

**The serial device node is not reachable on Android.** The micro:bit does
appear as `/dev/ttyACM0`, world-writable, but its SELinux label puts it
out of reach of an ordinary app — the shell cannot open it either. The
Android USB host API is the only route, which is what
`robot_usb_android.lua` uses.

**A module's globals live where it was first loaded.** A module loaded by
a running program lands in the program's environment; loaded from the
prompt, it lands in the console's. Whoever loads first wins, so a session
that first runs a robot program and then tries `m"..."` at the prompt gets
`attempt to call a nil value`. Restart the IDE when switching between the
two. Loading the runtime from the platform instead of from a project
removes the split entirely.

**The modules must be loadable more than once per process.** The IDE drops
a project's modules after every run, so every file here is written to
survive being loaded again — notably the `ffi.cdef` in `robot_jni.lua`,
which would otherwise fail on the second load with a redefinition error.
