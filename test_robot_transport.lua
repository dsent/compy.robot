--- Transport tests, run under LuaJIT (the target VM).
--- 1) posix backend end-to-end via the unified interface,
---    against the fake firmware pty (arg[1] = device);
--- 2) android backend selection via a stubbed love.system;
--- 3) android open fails STAGED (not crashes) off-device.

require("robot_transport")

local failures = 0
local function check(name, got, want)
  local ok = got == want
  print(string.format("%-36s %s (got %s)",
    name, ok and "PASS" or "FAIL", tostring(got)))
  if not ok then failures = failures + 1 end
end

check("backend off-love", transportBackendName(), "posix")

local port = transportOpen(arg[1])
check("posix open via transport",
  port and port.backend or "nil", "posix")
check("posix ping", transportCommand(port, "PING", 2), "PONG")
check("posix move",
  transportCommand(port, "M 20 80 300", 2), "OK")
transportClose(port)

love = { system = { getOS = function() return "Android" end } }
check("backend stubbed android",
  transportBackendName(), "android")

local aport, aerr = transportOpen()
local staged = aport == nil and
  aerr ~= nil and aerr:find("^stage ") ~= nil
check("android fails staged off-device", staged, true)
print("  (error was: " .. tostring(aerr) .. ")")

check("jni offsets", jniSelfCheck(), true)

print(failures == 0 and "ALL PASS" or
  failures .. " FAILURES")
os.exit(failures == 0 and 0 or 1)
