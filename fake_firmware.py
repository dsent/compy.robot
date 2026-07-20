#!/usr/bin/env python3
"""Simulates the micro:bit firmware on a pty.

Creates a pseudo-terminal; the slave end acts as /dev/ttyACM0.
Protocol: "M <left> <right> <ms>" -> waits ms (simulated movement,
capped for the test), then replies "OK". Malformed -> "ERR parse".
"""
import os, pty, sys, time, tty

master, slave = pty.openpty()
tty.setraw(master)
slave_name = os.ttyname(slave)
with open("/tmp/pty_name", "w") as f:
    f.write(slave_name)
print("SLAVE:", slave_name, flush=True)

buf = b""
while True:
    try:
        chunk = os.read(master, 256)
    except OSError:
        break
    if not chunk:
        break
    buf += chunk
    while b"\n" in buf:
        line, buf = buf.split(b"\n", 1)
        text = line.decode(errors="replace").strip()
        print("FW got:", repr(text), flush=True)
        parts = text.split()
        if len(parts) == 4 and parts[0] == "M":
            try:
                l, r, ms = int(parts[1]), int(parts[2]), int(parts[3])
                time.sleep(min(ms, 600) / 1000.0)  # simulated movement
                os.write(master, b"OK\n")
            except ValueError:
                os.write(master, b"ERR parse\n")
        elif text == "PING":
            os.write(master, b"PONG\n")
        else:
            os.write(master, b"ERR parse\n")
