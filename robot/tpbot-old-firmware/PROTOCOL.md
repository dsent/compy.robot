# Robot Wire Protocol

Serial protocol between the Compy netbook and the micro:bit firmware
driving the TPBot. Text-based, line-oriented, human-readable: it can
be exercised by hand from any serial terminal, without any Compy-side
software.

The protocol is transport-agnostic. The initial transport is direct
USB serial; a BLE bridge can replace the transport later without any
change to this protocol.

## Transport parameters

- Serial over USB, `115200` baud, 8N1 (micro:bit UART defaults).
- On the netbook the device appears as `/dev/ttyACM<n>`.

## Framing

- A message is a single line terminated by `\n` (LF).
- The firmware tolerates `\r\n` (CR is stripped).
- Encoding is plain ASCII.
- Maximum line length is 64 bytes including the terminator; longer
  lines are answered with `ERR parse` and discarded. The limit
  matches the micro:bit's internal UART RX buffer (64 bytes), so a
  valid command line always fits in the buffer even if the firmware
  is busy when it arrives.
- The firmware never sends unsolicited output: no startup banner, no
  progress messages. Every line it emits is a response to exactly one
  command. This keeps host-side parsing trivial: write one line, read
  one line.

## Commands

### `M <left> <right> <ms>` — move

Drive the wheels for a fixed duration.

- `<left>`, `<right>`: integers in `-100..100`, percent of motor
  power. Negative values spin that wheel backwards. `0` stops the
  wheel.
- `<ms>`: integer in `1..30000`, movement duration in milliseconds.
  The upper cap is a safety limit against runaway values.

The firmware starts the motors, waits `<ms>`, stops the motors, and
only then replies `OK`. The reply therefore doubles as the "movement
finished" signal: the blocking semantics of the Compy-side
`robot_move` fall out of the protocol itself.

Note the unit difference: the protocol carries integer milliseconds
(no float parsing in the firmware); the Lua API accepts seconds and
converts on the Compy side.

While a movement is in progress the firmware does not read the
serial port. Incoming bytes accumulate in the micro:bit's 64-byte
UART RX buffer (plus host-side OS buffers) and are processed after
the movement completes. A host that follows strict request-response
discipline — never sending the next command before reading the
previous response — can never overflow that buffer; hand-testers
typing during a long movement theoretically can.

### `PING` — connection check

Replies `PONG` immediately. Used by the Compy side to verify the
robot is connected and the firmware is responsive, and useful as a
first smoke test when setting up hardware.

## Responses

Every command produces exactly one response line:

- `OK` — command executed (for `M`, sent after the movement ends).
- `PONG` — response to `PING`.
- `ERR <reason>` — command rejected, nothing was executed. Reasons:
  - `ERR parse` — malformed or unknown command, wrong number of
    arguments, non-integer argument, or oversized line.
  - `ERR range` — integers parsed but out of the allowed ranges.
  - `ERR i2c` — the motor controller did not acknowledge: the TPBot
    chassis is switched off or the micro:bit is not seated in it.

Hosts should treat any `ERR` uniformly (report and continue); the
reason string is for humans debugging, not for program logic.

## Timeouts (host side)

The firmware replies to `M` only after the movement completes, so
the host read timeout must exceed the requested duration. Suggested:
`<ms> + 2000` milliseconds. For `PING`, 2000 ms is plenty. A read
timeout means the device is unresponsive or unplugged; the host
should surface a clear error to the user.

## Extensibility

New capabilities are added as new single-letter commands with the
same line discipline (one command line, one response line). A
firmware receiving an unknown command replies `ERR parse`, so an
older firmware degrades loudly rather than silently.

## Testing by hand

The protocol is plain text, so it can be exercised from a shell
with no extra tools installed. Start a reader in the background,
configure the port, then send command lines to it. On Linux the
device is `/dev/ttyACM0` and the stty flag is `-F`; on macOS the
device is `/dev/cu.usbmodemNNNN` and the flag is `-f`.

    cat /dev/cu.usbmodem2102 &
    stty -f /dev/cu.usbmodem2102 115200 raw -echo
    printf 'PING\n'        > /dev/cu.usbmodem2102
    printf 'M 30 30 1000\n' > /dev/cu.usbmodem2102

Responses appear in the terminal as the firmware sends them.
Expected results:

    PING             -> PONG
    M 30 30 1000     -> robot drives forward ~1s, then OK
    M -50 50 500     -> robot turns in place, then OK
    M -30 -30 500    -> robot reverses, then OK
    M 200 0 100      -> ERR range
    HELLO            -> ERR parse

With the micro:bit alone (not seated in the TPBot, or with the
chassis switched off) `PING` still works and `M` commands answer
`ERR i2c` — a useful way to check the firmware before involving
the robot.

Stop the reader with `kill %1` when done.

Note: an interactive terminal such as `screen` does not work
here. Its Enter key sends CR only, while the protocol terminates
lines with LF, so commands are never completed. `picocom -b
115200 --omap crlf` does map Enter correctly if it is installed.
