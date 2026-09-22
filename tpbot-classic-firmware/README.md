# TPBot Classic firmware

`MICROBIT.hex` is the micro:bit firmware for driving the original
ElecFreaks TPBot, the TPBot Classic, from a Compy. It turns the
micro:bit into a Lua 5.1 REPL on its USB serial port, with the TPBot
library and `robot_move` built in, and the same radio link as the
[TPBot Edu firmware](../tpbot-edu-firmware/README.md#the-radio-link).
`turn` and `straight` are TPBot Edu only.

It is a build of <https://github.com/nagydani/microbit-lua>, branch
`TPBotClassic`, commit `3488321` ("Backport to TPBot Classic"). The Lua
script embedded in the file is identical to `source/lua-script.lua` at
that commit.

Flashing and checking it go as for the TPBot Edu: see
[Flashing](../tpbot-edu-firmware/README.md#flashing) and
[Checking it](../tpbot-edu-firmware/README.md#checking-it).

## Driving the robot

`robot_move(left, right, seconds)` sets both wheel speeds, waits the
given number of seconds, and stops the motors. A negative speed turns
that wheel the other way. The micro:bit has to sit in the TPBot with the
chassis switched on.

The `robot`, `robot_c` and `robot_w` programs speak a line protocol and
need [their own firmware](../robot/tpbot-old-firmware/README.md).
