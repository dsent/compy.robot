# TPBot Edu firmware

`MICROBIT.hex` is the micro:bit firmware for driving an ElecFreaks TPBot
Edu from a Compy. It turns the micro:bit into a Lua 5.1 REPL on its USB
serial port, with the TPBot Edu library and a `robot_move` function
built in.

It is a build of <https://github.com/nagydani/microbit-lua>, branch
`TPBotEdu`, commit `6cfa541` ("robot_move for exercises"). The Lua
script embedded in the file is identical to `source/lua-script.lua` at
that commit.

## Flashing

1. Connect the micro:bit to a Linux computer with a USB cable. It shows
   up as a USB drive named `MICROBIT`.
2. Copy `MICROBIT.hex` onto that drive. A desktop usually mounts it by
   itself; from a terminal:

   ```shell
   drive=$(lsblk -o NAME,LABEL | awk '$2=="MICROBIT"{print "/dev/"$1}')
   udisksctl mount -b "$drive" && cp MICROBIT.hex /run/media/${USER}/MICROBIT/
   ```

   `udisksctl` prints the folder it mounted the drive at; copy there if
   it differs.
3. The orange LED next to the USB connector blinks fast while the
   firmware is written. A few seconds later the micro:bit starts the new
   firmware.

## Checking it

Open the serial console from the Linux computer, type `print(1+1)` and
press Enter. The micro:bit answers `2`.

```shell
screen /dev/ttyACM0 115200
```

If `/dev/ttyACM0` is missing, watch `dmesg --follow` while plugging the
micro:bit in.

## Driving the robot

`robot_move(left, right, seconds)` sets both wheel speeds, waits the
given number of seconds, and stops the motors. A negative speed turns
that wheel the other way. The micro:bit has to sit in the TPBot Edu with
the chassis switched on.
