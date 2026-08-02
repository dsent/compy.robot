--- End-to-end tests for robot_move against
--- the fake firmware pty (arg[1] = device). The harness
--- kills the firmware when /tmp/kill_now appears.

require("robot.move")

local failures = 0
local function check(name, got, want)
  local ok = got == want
  print(string.format("%-38s %s (got %s)",
    name, ok and "PASS" or "FAIL", tostring(got)))
  if not ok then failures = failures + 1 end
end

local function errorOf(...)
  local ok, err = pcall(...)
  return ok and "(no error)" or err
end

check("connect refused on wrong device",
  errorOf(robot_connect, "/dev/null") ~= "(no error)", true)

robot_connect(arg[1])
check("move", robot_move(20, 80, 0.3), true)
check("turn in place", robot_move(-50, 50, 0.2), true)
check("rounding accepted", robot_move(50.4, 49.6, 0.25), true)
check("tiny time clamps to 1ms",
  robot_move(10, 10, 0.0001), true)

check("speed out of range",
  errorOf(robot_move, 200, 0, 1),
  "left wheel speed must be a number from -100 to 100, got 200")
check("numeric strings accepted (console)",
  robot_move("30", "30", "0.2"), true)
check("speed wrong type",
  errorOf(robot_move, "fast", 0, 1),
  "left wheel speed must be a number from -100 to 100, got fast")
check("right side named",
  errorOf(robot_move, 0, -101, 1),
  "right wheel speed must be a number from -100 to 100, got -101")
check("zero seconds",
  errorOf(robot_move, 10, 10, 0),
  "time must be a number of seconds up to 30, got 0")
check("too long",
  errorOf(robot_move, 10, 10, 31),
  "time must be a number of seconds up to 30, got 31")

check("idle hook wired",
  type(LINE_READER_IDLE) == "nil", true)

os.execute("touch /tmp/kill_now; sleep 2")
local msg = errorOf(robot_move, 10, 10, 0.1)
check("dead device raises kid error",
  msg:find("robot problem:") == 1, true)
print("  (message was: " .. msg .. ")")

print(failures == 0 and "ALL PASS" or
  failures .. " FAILURES")
os.exit(failures == 0 and 0 or 1)
