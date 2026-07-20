# TPBot serial-command firmware for micro:bit (MicroPython).
# Implements the wire protocol described in PROTOCOL.md:
# line-based commands over USB serial, one response line per
# command. The reply to "M" is sent after the movement completes,
# which gives the host its blocking semantics.
#
# Motor control: I2C address 0x10, formats taken from the official
# ElecFreaks extension (github.com/elecfreaks/pxt-TPBot). Like the
# official extension, we send both the V1 and the V2 command for
# every motor change; each board revision executes its own format
# and ignores the other, so no hardware version detection is needed.

from microbit import i2c, sleep, uart
import micropython

I2C_ADDR = 0x10
MAX_LINE = 64
SPEED_MIN, SPEED_MAX = -100, 100
MS_MIN, MS_MAX = 1, 30000


def motors(left, right):
    direction = 0
    if left < 0:
        direction |= 0x01
        left = -left
    if right < 0:
        direction |= 0x02
        right = -right
    # V1 board: raw 4-byte command
    i2c.write(I2C_ADDR, bytes([0x01, left, right, direction]))
    # V2 board: framed command (header FF F9, cmd 0x10, param len)
    i2c.write(I2C_ADDR,
              bytes([0xFF, 0xF9, 0x10, 0x03, left, right, direction]))


def parse_int(token):
    try:
        return int(token)
    except ValueError:
        return None


def handle(line):
    """Handle one command line (bytes, no terminator).

    Returns the response line (bytes, no terminator)."""
    try:
        # Decode before parsing: int() on bytes works in CPython
        # but is not guaranteed across MicroPython builds.
        parts = str(line, "utf-8").split()
    except UnicodeError:
        return b"ERR parse"
    if parts == ["PING"]:
        return b"PONG"
    if len(parts) == 4 and parts[0] == "M":
        left = parse_int(parts[1])
        right = parse_int(parts[2])
        ms = parse_int(parts[3])
        if left is None or right is None or ms is None:
            return b"ERR parse"
        if not (SPEED_MIN <= left <= SPEED_MAX
                and SPEED_MIN <= right <= SPEED_MAX
                and MS_MIN <= ms <= MS_MAX):
            return b"ERR range"
        try:
            motors(left, right)
        except OSError:
            # I2C NACK: the TPBot chassis is off or not connected.
            return b"ERR i2c"
        sleep(ms)
        try:
            motors(0, 0)
        except OSError:
            # The stop write is the safety-critical one: if it is
            # lost, the wheels keep their last speed. Retry a few
            # times before giving up.
            stopped = False
            for _ in range(5):
                sleep(20)
                try:
                    motors(0, 0)
                    stopped = True
                    break
                except OSError:
                    pass
            if not stopped:
                return b"ERR i2c"
        return b"OK"
    return b"ERR parse"


def run():
    # uart is routed to USB serial by default; pin the baud rate
    # to the protocol value.
    uart.init(115200)
    # After init, not before: make sure re-initializing the UART
    # cannot restore the default interrupt behavior. A stray 0x03
    # byte on serial would otherwise raise KeyboardInterrupt and
    # kill this loop mid-lesson.
    micropython.kbd_intr(-1)

    buf = b""
    overflow = False
    while True:
        chunk = uart.read()
        if chunk is None:
            sleep(10)
            continue
        buf += chunk
        while True:
            newline = buf.find(b"\n")
            if newline < 0:
                if len(buf) >= MAX_LINE:
                    # Oversized line: drop bytes until we see the
                    # terminator, then answer ERR parse once.
                    buf = b""
                    overflow = True
                break
            line = buf[:newline].rstrip(b"\r")
            buf = buf[newline + 1:]
            if overflow:
                overflow = False
                uart.write(b"ERR parse\n")
                continue
            uart.write(handle(line) + b"\n")


run()
