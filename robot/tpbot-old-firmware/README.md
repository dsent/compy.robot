# TPBot line-protocol firmware

The micro:bit side of the `robot` programs: firmware that reads
plain-text command lines over USB serial and drives an ElecFreaks
TPBot's motors.

This whole approach, a line-protocol firmware on the micro:bit and a
USB stack inside each Compy program, is superseded by a custom micro:bit
firmware and the serial API built into Compy: see
[tpbot-firmware](../../tpbot-firmware/README.md). The
`robot`, `robot_c` and `robot_w` programs are the only ones that still
need this firmware.

| Path | What it is |
| --- | --- |
| `PROTOCOL.md` | The wire protocol: commands, replies, framing, timeouts, hand-testing recipe |
| `firmware.py` | MicroPython firmware for the micro:bit — reads command lines, drives the TPBot over I2C |
| `test_firmware.py` | Protocol-logic tests for the firmware, with the micro:bit runtime stubbed |
| `FLASHING.md` | Flashing the firmware and running the smoke test |
| `microbit-lua/` | The same protocol for the Lua firmware in <https://github.com/nagydani/microbit-lua>, as a patch to its `lua-script.lua`, with a sandbox test |

## Running the tests

From the repository root, with `lua` 5.1 or `luajit`:

    uv run python robot/tpbot-old-firmware/test_firmware.py
    lua robot/tpbot-old-firmware/microbit-lua/testProtocolPatch.lua
