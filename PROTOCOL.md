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
serial port; commands sent during a movement are buffered by the OS
and processed after the current movement completes.

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

Any serial terminal works. For example, with `picocom`:

    picocom -b 115200 --omap crlf /dev/ttyACM0

or with `screen`:

    screen /dev/ttyACM0 115200

Then type:

    PING            -> expect: PONG
    M 30 30 1000    -> robot drives forward ~1s, then: OK
    M -50 50 500    -> robot turns in place, then: OK
    M 200 0 100     -> expect: ERR range
    HELLO           -> expect: ERR parse

Exit `screen` with `Ctrl-A` then `k`, `picocom` with `Ctrl-A`
then `Ctrl-X`.
