# drive

Drive a TPBot robot (Edu or Classic) with the Compy's keys. Every move goes
into `r.lua`, and `replay.lua` drives it again.

1. Put the robot firmware on the robot's micro:bit: in the `microbit`
   project, type `require("tools")`, then `upload()`.
2. Seat the micro:bit in the robot, switch the robot on, plug the micro:bit
   into the Compy with a data cable, and run `drive`.
3. Hold the keys. Your left hand drives the left wheel, your right hand the
   right wheel:

| Left wheel | Right wheel | While you hold it |
| --- | --- | --- |
| `1` | `-` | fast forward |
| `Q` | `P` | slow forward |
| `A` | `;` | slow back |
| `Z` | `/` | fast back |

While you hold keys, `drive` sends the micro:bit `robot_move(left, right,
0.5)` each time it is ready for a line, and the screen shows it. The robot
stops within half a second of letting go. A key tapped while the robot moves
drives its own half second after the move under way. Press `Ctrl+S` to stop
`drive`: the moves of this run are written into `r.lua` in place of what it
held, the same speeds held on as one longer line.

To drive the moves again, type at the console:

```lua
dofile("replay.lua")
```

`replay.lua` is the `slalom` project's program, put into this project by
the build: it sends `r.lua` to the micro:bit a line at a time, each when it
shows its prompt. A run straight from a checkout of this repository has no
`replay.lua`.

If the robot does not move, stop `drive`, switch the robot on, and run
`drive` again. A new run also starts `r.lua` afresh, without the moves the
robot did not make.
