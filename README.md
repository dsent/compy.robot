# Compy robot

Driving ElecFreaks TPBot robots from a Compy.

| Path | What it is |
| --- | --- |
| `tpbot-firmware/` | micro:bit firmware for the TPBot Edu and the TPBot Classic, a Lua REPL with `robot_move` built in, and how to flash it |
| `robot/` | Superseded: the TPBot on a line-protocol firmware, its Compy-side Lua runtime, and the `robot`, `robot_c` and `robot_w` Compy projects built from it |
| `slalom/` | The `slalom` Compy project for the TPBot Edu: `main.lua` sends the robot instructions in `r.lua` over serial |
