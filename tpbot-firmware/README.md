# TPBot firmware

`MICROBIT.hex` is the micro:bit firmware for driving an ElecFreaks TPBot
from a Compy: the TPBot Edu, or the original TPBot, the TPBot Classic.
It turns the micro:bit into a Lua 5.1 REPL on its USB serial port, with
the TPBot library, `robot_info`, `robot_move`, `turn` and `straight`
built in, and a radio link to a second micro:bit. Numbers
are 32-bit floats: whole numbers are exact up to 16,777,216, and
fractions keep about seven significant digits.

It is `MICROBIT.hex` from a build of
<https://github.com/dsent/microbit-lua>, commit `57e54f9`, which carries
<https://github.com/nagydani/microbit-lua> `TPBotEdu-v2` (`b168247`)
with its TPBot library extended to both robots. The Lua script embedded
in the file is identical to `source/lua-script.lua` at that commit.

The `microbit` program on a Compy carries the same file, and its
`upload()` puts it on the micro:bit.

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

The micro:bit has to sit in the robot with the chassis switched on.
`robot_info()` says whether a robot answers, and which one:
`{connected = true, robot = "TPBot Edu"}` or `"TPBot Classic"`, or
`{connected = false}`. A robot that is switched off takes about five
seconds to show as not connected.

`robot_move(left, right, seconds)` sets both wheel speeds, waits the
given number of seconds, and stops the motors. A negative speed turns
that wheel the other way. `tpbot.set_car_light(r, g, b)` sets the
headlights. Each of these sends both robots' commands, and each robot
ignores the other's. When no robot answers, they stop with a message
saying so.

`turn(h)` turns the robot by `h` hours of a clock face, 30 degrees an
hour, the short way round: `turn(3)` is a quarter turn to the right.
`straight(l)` drives `l` steps of 11 cm forward. These two need a TPBot
Edu, which measures its own wheels; a TPBot Classic ignores them.

Reading from the robot with `microbit.i2c.read` locks up a TPBot
Classic until it is switched off and on.

The `robot`, `robot_c` and `robot_w` programs speak a line protocol and
need [their own firmware](../robot/tpbot-old-firmware/README.md).

## The radio link

Two micro:bits with this firmware can talk over the radio. On one,
`listen(name)` waits for a call and then serves a REPL over the radio.
On the other, `connect(name, timeout)` makes the call and carries its
USB serial console over the link: what you type there reaches the first
one, and its answers come back.
