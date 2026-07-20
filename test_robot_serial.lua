--- Tests for robot_serial.lua against a fake firmware on a
--- pty (see fake_firmware.py). Device path comes in arg[1];
--- the harness kills the firmware when /tmp/kill_now
--- appears, which lets us test mid-session device death.

dofile("robot_serial.lua")

local failures = 0

local function check(name, got, want)
  local ok = got == want
  local verdict = ok and "PASS" or "FAIL"
  print(string.format("%-34s %s (got %s)",
    name, verdict, tostring(got)))
  if not ok then failures = failures + 1 end
end

local port = serialOpen(arg[1])

check("ping", serialCommand(port, "PING", 2), "PONG")
check("move", serialCommand(port, "M 20 80 500", 2.5), "OK")
-- regression: quiet slices during movement plus response
-- bytes must not jointly exhaust the deadline; the old
-- try-per-read code failed this with timeout 0.8
check("tight timeout still enough",
  serialCommand(port, "M 20 80 500", 0.8), "OK")
check("neg speeds",
  serialCommand(port, "M -50 50 300", 2.5), "OK")
check("bad command",
  serialCommand(port, "GARBAGE", 2), "ERR parse")

local resp, err = serialReadLine(port, 0.6)
check("silent read times out", err, "timeout")

os.execute("touch /tmp/kill_now; sleep 2")

local resp2, err2 = serialCommand(port, "M 1 1 100", 1)
local died = (resp2 == nil and err2 ~= nil)
check("dead device detected", died, true)
print("  (error was: " .. tostring(err2) .. ")")

serialClose(port)

check("absent device find",
  serialFindDevice() and "found" or "none", "none")

print(failures == 0 and "ALL PASS" or
  failures .. " FAILURES")
os.exit(failures == 0 and 0 or 1)
