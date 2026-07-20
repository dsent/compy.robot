# Flashing the firmware

The firmware is a single MicroPython script, `firmware.py`. Flashing
it puts MicroPython plus the script onto the micro:bit in one step.

## Easiest: the online micro:bit Python editor

1. Open https://python.microbit.org in Chrome or Edge (WebUSB is
   needed; Firefox and Safari can't flash directly).
2. Replace the editor content with the content of `firmware.py`.
3. Plug the micro:bit in via USB, click "Send to micro:bit", pick
   the device in the browser prompt.

## Alternative: uflash from the command line

    pip install uflash
    uflash firmware.py

`uflash` finds the mounted MICROBIT drive and writes a combined
MicroPython + script hex to it.

## Smoke test

Unplug and replug the micro:bit after flashing, then follow the
"Testing by hand" section of PROTOCOL.md. `PING` -> `PONG` works
with the micro:bit alone; `M` commands additionally need the
micro:bit seated in the TPBot with the chassis switched ON,
otherwise they answer `ERR i2c`.

Note: the firmware disables the serial Ctrl-C interrupt and prints
no banner, so a freshly opened terminal shows nothing until you
send a command. That's expected.
