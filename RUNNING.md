# Running and testing the robot code

Three ways to exercise this code, in rising order of what they need:
the suites need nothing but LuaJIT, a development machine with the
micro:bit plugged in runs the real thing from a shell, and a Compy runs
it either as a Compy program or straight from the console prompt.

## The suites

`run_tests.sh` runs everything from the repository root, so the dotted
require paths resolve as they do inside a build. It starts
`robot/fakeFirmware.py` on a pseudo-terminal, hands the device to each
suite, and kills the firmware when a suite asks for it (the mid-session
device-death case):

    ./run_tests.sh

Individual suites, when a failure needs a closer look:

    ./run_tests.sh robot/testSerial.lua
    luajit robot/testLineReader.lua        # needs no firmware
    uv run python test_firmware.py         # firmware protocol logic

`test_firmware.py` mocks the `microbit` and `micropython` modules, so it
covers everything in `firmware.py` except the real I2C bus and real UART
timing. Those need the device.

## A real robot from a development machine

Flash `firmware.py` to the micro:bit (`FLASHING.md`), plug it into the
machine, and the posix backend drives it from bare LuaJIT:

    luajit robot/main.lua

That runs the starter program. For a single move:

    luajit -e 'require("robot.move"); print(robot_move(20, 80, 1))'

This exercises the whole stack — protocol, framing, timeouts, error
messages — except the Android backend, which needs a Compy.

## As Compy projects

`.compy/build` emits two projects, which are copied onto a device like
any other program — no Compy build involved:

- `robot` — the runtime plus a `main.lua` a child edits and runs.
- `robot_c` — the same runtime plus the console front end.

A Compy project is a flat folder whose loader resolves a module name
straight to `<name>.lua`, so the build flattens `robot/move.lua` to
`robot_move.lua` and rewrites the requires to match. The prefix stays so
that a child's own files cannot collide with the runtime.

### As a program

`main.lua` calls `robot_move` directly:

    require("robot_move")

    robot_move(-40, 40, 1)   -- spin one way
    robot_move(40, -40, 1)   -- and back again

Speeds are percentages from -100 to 100, and a negative speed runs that
wheel backwards, so opposite speeds turn the robot in place. Time is in
seconds and may be fractional.

The robot connects on the first move. `robot_connect()` exists to make
the connection, and any error about it, happen at a predictable point.

### From the console

Open the console project, load the front end, and drive the robot a line
at a time. Lua calls a function with a single string without
parentheses, so a move is three numbers in quotes:

    project"robot_c"
    require"robot_console"
    m"40 -40 1"

`m` reports `ok`, or the same kid-readable message a program would
raise, so nothing needs wrapping in `print()`.

## What to expect

**The USB permission dialog.** The first connection after an install
asks the child to allow access, naming the device *BBC micro:bit
CMSIS-DAP*. While the dialog is up `robot_connect` polls for the
permission and continues once granted. The dialog's checkbox makes the
answer permanent — worth ticking during testing. Without it this is one
dialog per child per session.

**Blocking moves.** `robot_move` returns when the wheels stop, so a
four-second move freezes the screen for four seconds. Measured on the
device: no Android "not responding" dialog, even with input arriving
throughout. `LINE_READER_IDLE` in `robot/lineReader.lua` is the hook for
an event pump if longer moves ever need one.

**A few milliseconds per move.** Each command opens the port, talks, and
closes it. Measured on the device: about 40 ms on top of the movement.
That is what makes a program safe to stop at any line — see below.

## Bringing up a device

Seat the micro:bit in the TPBot, switch the chassis on, and plug it into
the Compy. Then, from the console:

    project"robot_c"
    require"robot_console"
    m"30 30 1"

The robot drives forward for a second. Run a move from a program as
well — that exercises the other environment, the one lessons use.

## When something fails

Errors from the Android path name the stage they failed at, for example
`stage endpoints: CDC set incomplete`, which locates the problem without
a debugger on the device. The stages, in order:

`selfcheck`, `env`, `activity`, `manager`, `scan`, `permission`, `open`,
`endpoints`, `claim`, `acm`.

`stage scan: no micro:bit on the bus` with the cable plugged in usually
means the device is not powered from the port — check that the Compy end
really is a host port.

## Constraints worth knowing

**Nothing is held between commands, on purpose.** On Android an open USB
connection owns its interface claims, and the claims belong to the app
rather than to the Lua state. A program that stops on an error takes its
connection with it, and no cleanup we could write would ever run: the
robot would stay locked until the app was restarted. Opening per command
costs milliseconds and cannot leak. Programs need no cleanup line, and a
child can run a program that crashes as often as they like.

**The serial device node is not reachable on Android.** The micro:bit
does appear as `/dev/ttyACM0`, world-writable, but its SELinux label
puts it out of reach of an ordinary app — the shell cannot open it
either. The Android USB host API is the only route, which is what
`robot/usbAndroid.lua` uses.

**A module's globals live where it was first loaded.** A module loaded
by a running program lands in the program's environment; loaded from the
prompt, it lands in the console's. Whoever loads first wins, so a
session that first runs a robot program and then tries `m"..."` at the
prompt gets `attempt to call a nil value`. Restart the IDE when
switching between the two.

**The modules must be loadable more than once per process.** The IDE
drops a project's modules after every run, so every file here is written
to survive being loaded again — notably the `ffi.cdef` in
`robot/jni.lua`, which would otherwise fail on the second load with a
redefinition error.
