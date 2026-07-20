--- Serial transport to the robot micro:bit.
---
--- Host side of PROTOCOL.md over a tty device, in pure
--- Lua 5.1: io for the device, stty (via os.execute) for
--- port configuration. No luaposix, no C module.
---
--- stty is used with `min 0 time 2`: a read(1) on the port
--- returns after at most 0.2s when no data is available
--- (Lua sees nil, same as EOF). serialReadLine turns that
--- into a deadline loop, so blocking-with-timeout reads
--- need no OS-specific machinery.
---
--- Backend role: development machines, CI, and any future
--- Linux-based Compy hardware. The classroom target is
--- Android (see robot_usb_android.lua). `stty -F` is the
--- Linux spelling of the flag.

require("robot_line_reader")

SERIAL_BAUD = 115200
SERIAL_GLOB = "/dev/ttyACM*"

--- First matching tty device, or nil if none is plugged in.
function serialFindDevice()
  local list = "ls " .. SERIAL_GLOB .. " 2>/dev/null"
  local pipe = assert(io.popen(list))
  local dev = pipe:read("*l")
  pipe:close()
  return dev
end

function serialConfigure(dev)
  local flags = " raw -echo -echoe -echok min 0 time 2"
  local cmd = "stty -F " .. dev .. " " .. SERIAL_BAUD
  local code = os.execute(cmd .. flags)
  assert(code == 0, "stty failed on " .. dev)
end

--- Open a configured port. Fails loudly if the device is
--- absent (node missing = robot not plugged in).
function serialOpen(dev)
  serialConfigure(dev)
  local tx = assert(io.open(dev, "w"))
  local rx = assert(io.open(dev, "r"))
  tx:setvbuf("no")
  return { dev = dev, tx = tx, rx = rx, pending = "" }
end

--- One read slice: a single byte, or "" after the 0.2s
--- stty timeout. Framing and deadlines live in the shared
--- line reader.
local function posixSlice(port)
  return port.rx:read(1) or ""
end

--- Read one protocol line; see lineReaderRead for the
--- timeout semantics (only quiet slices count).
function serialReadLine(port, timeout_s)
  return lineReaderRead(port, posixSlice, timeout_s)
end

--- Send one command line, await one response line.
--- Returns the response, or nil plus an error string
--- ("write: ..." means the device vanished mid-session).
function serialCommand(port, line, timeout_s)
  local ok, err = port.tx:write(line .. "\n")
  if not ok then
    return nil, "write: " .. tostring(err)
  end
  return serialReadLine(port, timeout_s)
end

function serialClose(port)
  port.tx:close()
  port.rx:close()
end
