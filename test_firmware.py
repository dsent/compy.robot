"""Sandbox tests for firmware.py protocol logic.

Mocks the microbit/micropython modules, then exercises handle()
and the line-assembly loop. I2C writes are recorded, sleep is
instant. This verifies everything except the real I2C bus and
real UART timing, which need the device.
"""
import sys
import types

i2c_writes = []
sleeps = []

microbit = types.ModuleType("microbit")
microbit.i2c = types.SimpleNamespace(
    write=lambda addr, data: i2c_writes.append((addr, bytes(data))))
microbit.sleep = lambda ms: sleeps.append(ms)
microbit.uart = types.SimpleNamespace(
    read=lambda: None, write=lambda b: None, init=lambda baud: None)
sys.modules["microbit"] = microbit

micropython = types.ModuleType("micropython")
micropython.kbd_intr = lambda n: None
sys.modules["micropython"] = micropython

# Import without executing run(): strip the trailing call.
src = open("/home/claude/firmware.py").read()
src = src.replace("\nrun()\n", "\n")
fw = types.ModuleType("fw")
exec(compile(src, "firmware.py", "exec"), fw.__dict__)

failures = []


def check(name, got, want):
    ok = got == want
    print("%-38s %s  (got %r)" % (name, "PASS" if ok else "FAIL", got))
    if not ok:
        failures.append(name)


# --- command handling ---
check("PING", fw.handle(b"PING"), b"PONG")
check("move forward", fw.handle(b"M 30 30 1000"), b"OK")
check("turn in place (negative)", fw.handle(b"M -50 50 500"), b"OK")
check("both backward", fw.handle(b"M -20 -20 300"), b"OK")
check("range: speed >100", fw.handle(b"M 200 0 100"), b"ERR range")
check("range: ms 0", fw.handle(b"M 10 10 0"), b"ERR range")
check("range: ms >30000", fw.handle(b"M 10 10 40000"), b"ERR range")
check("parse: garbage", fw.handle(b"HELLO"), b"ERR parse")
check("parse: float ms", fw.handle(b"M 10 10 1.5"), b"ERR parse")
check("parse: missing arg", fw.handle(b"M 10 10"), b"ERR parse")
check("parse: extra arg", fw.handle(b"M 1 2 3 4"), b"ERR parse")
check("parse: empty line", fw.handle(b""), b"ERR parse")

# --- i2c payloads: verify against the ElecFreaks formats ---
i2c_writes.clear()
fw.handle(b"M -50 50 100")
check("i2c addr", {a for a, _ in i2c_writes}, {0x10})
check("V1 payload (left back)", i2c_writes[0][1],
      bytes([0x01, 50, 50, 0x01]))
check("V2 payload (left back)", i2c_writes[1][1],
      bytes([0xFF, 0xF9, 0x10, 0x03, 50, 50, 0x01]))
check("stop after move: V1 zeros", i2c_writes[2][1],
      bytes([0x01, 0, 0, 0x00]))
check("blocking sleep used", sleeps[-1], 100)

# --- i2c failure -> ERR i2c ---
def nack(addr, data):
    raise OSError(19)
microbit.i2c.write = nack
check("chassis off -> ERR i2c", fw.handle(b"M 10 10 100"), b"ERR i2c")

# --- stop write fails once, then recovers -> still OK ---
state = {"calls": 0}
def flaky(addr, data):
    state["calls"] += 1
    # calls 1-2: movement start (V1+V2) succeed; call 3 (stop V1)
    # fails once; the retry succeeds.
    if state["calls"] == 3:
        raise OSError(19)
    i2c_writes.append((addr, bytes(data)))
microbit.i2c.write = flaky
check("stop glitch recovered -> OK", fw.handle(b"M 10 10 50"), b"OK")

# --- stop fails permanently -> ERR i2c after retries ---
def start_ok_stop_dead(addr, data):
    state["calls"] += 1
    if state["calls"] > 2:
        raise OSError(19)
state["calls"] = 0
microbit.i2c.write = start_ok_stop_dead
check("stop dead -> ERR i2c", fw.handle(b"M 10 10 50"), b"ERR i2c")

# --- invalid utf-8 -> ERR parse, no crash ---
microbit.i2c.write = lambda addr, data: i2c_writes.append((addr, bytes(data)))
check("invalid utf-8 -> ERR parse", fw.handle(b"M \xff\xfe 10 10"),
      b"ERR parse")

# --- line assembly: feed the run() loop via a scripted uart ---
class ScriptedUart:
    def __init__(self, chunks):
        self.chunks = list(chunks)
        self.out = b""
        self.reads = 0
    def read(self):
        self.reads += 1
        if self.reads > 500:
            raise StopIteration  # end the endless loop
        return self.chunks.pop(0) if self.chunks else None
    def write(self, b):
        self.out += b
    def init(self, baud):
        pass

def run_with(chunks):
    u = ScriptedUart(chunks)
    microbit.uart = u
    fw.uart = u
    try:
        fw.run()
    except (StopIteration, IndexError):
        pass
    return u.out

check("split across chunks",
      run_with([b"PI", b"NG\nM 1", b"0 10 50\n"]),
      b"PONG\nOK\n")
check("crlf tolerated",
      run_with([b"PING\r\n"]), b"PONG\n")
check("two commands in one chunk",
      run_with([b"PING\nPING\n"]), b"PONG\nPONG\n")
check("oversized line -> one ERR",
      run_with([b"X" * 80, b"\nPING\n"]),
      b"ERR parse\nPONG\n")

print()
print("FAILURES:", failures if failures else "none")
sys.exit(1 if failures else 0)
