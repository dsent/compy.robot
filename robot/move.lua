--- robot_move(left, right, seconds): the function kids
--- call from a compy program to drive the TPBot.
---
--- Blocking by design: it returns only after the movement
--- has finished (the firmware replies OK when the wheels
--- stop), so a program reads top to bottom as a sequence
--- of actions. Negative speeds spin a wheel backwards:
--- robot_move(-50, 50, 1) turns in place.
---
--- Errors are raised with error(msg, 0): short, readable
--- messages without file positions, for children.
---
--- Loading the module defines robot_move and robot_connect
--- as globals: a program requires it, and the console front
--- end requires it for the prompt.

require("robot.transport")

--- extra read time on top of the movement itself
ROBOT_EXTRA_WAIT_S = 2
ROBOT_SECONDS_MAX = 30
--- kid-readable hints for firmware error replies
ROBOT_HINTS = {
  ["ERR i2c"] = "is the robot switched on?",
}

--- Remembered device path for the posix backend; nil lets
--- the backend find the robot itself.
local robot_dev = nil

local function robotError(msg)
  error(msg, 0)
end

--- Lua stamps "file.lua:12:" in front of a raised message.
--- Kids should never see that, so strip it.
local function plainly(msg)
  return (tostring(msg):gsub("^%S-%.lua:%d+:%s*", ""))
end

--- tonumber rather than a type check, so a value that reads
--- as a number is accepted however it arrived. Rejections
--- quote what came in: a child sees which of their arguments
--- was wrong, and during bring-up it shows what the runtime
--- actually passed.
local function checkSpeed(value, side)
  local speed = tonumber(value)
  if not speed or speed < -100 or speed > 100 then
    robotError(side .. " wheel speed must be a number from "
      .. "-100 to 100, got " .. tostring(value))
  end
  return math.floor(speed + 0.5)
end

local function checkSeconds(value)
  local seconds = tonumber(value)
  if not seconds or seconds <= 0
      or seconds > ROBOT_SECONDS_MAX then
    robotError("time must be a number of seconds up to "
      .. ROBOT_SECONDS_MAX .. ", got " .. tostring(value))
  end
  local ms = math.floor(seconds * 1000 + 0.5)
  if ms < 1 then ms = 1 end
  return ms
end

--- A refused ACM setup on the last port opened, phrased for
--- the end of a message. Reported only when the robot then
--- fails to answer, since a refusal on its own is harmless.
local robot_refused = nil

local function refusal()
  return robot_refused
      and (" (port setup refused: " .. robot_refused .. ")")
      or ""
end

--- Every command stands on its own: open, talk, close, even
--- when the talking raises. Nothing is held between calls.
---
--- This is what makes a program safe to stop at any line. On
--- Android an open connection owns its USB interface claims,
--- and the claims belong to the app rather than to the Lua
--- state: a program that ends on an error takes the port
--- with it and the robot would stay locked until the next
--- app start, out of reach of any cleanup we could write.
--- Opening per command costs a few milliseconds against a
--- movement measured in seconds, and it cannot leak.
---
--- Returns the reply, or nil plus the reason the port could
--- not be opened or the reply never came.
local function withPort(fn)
  --- pcall: a device node that vanished mid-session makes
  --- the posix backend raise rather than return.
  local opened, port, err = pcall(transportOpen, robot_dev)
  if not opened then return nil, plainly(port) end
  if not port then return nil, err end
  robot_refused = port.acmRefused
  local ok, reply, cerr = pcall(fn, port)
  transportClose(port)
  if not ok then robotError(reply) end
  return reply, cerr
end

--- Check that the robot is there and answering. Optional:
--- a move connects on its own. dev is optional too (tests,
--- unusual device names) and is remembered for later moves.
function robot_connect(dev)
  robot_dev = dev
  local pong, err = withPort(function(port)
    return transportCommand(port, "PING", 2)
  end)
  if pong == "PONG" then return true end
  if not pong and err then
    robotError("robot not connected (" .. tostring(err) .. ")")
  end
  robotError("the robot is not answering, "
    .. "check the cable and try again" .. refusal())
end

function robot_move(left, right, seconds)
  local l = checkSpeed(left, "left")
  local r = checkSpeed(right, "right")
  local ms = checkSeconds(seconds)
  local line = "M " .. l .. " " .. r .. " " .. ms
  local wait = ms / 1000 + ROBOT_EXTRA_WAIT_S
  local reply, err = withPort(function(port)
    return transportCommand(port, line, wait)
  end)
  if reply == "OK" then return true end
  local why = reply and (ROBOT_HINTS[reply] or reply)
      or ("connection lost: " .. tostring(err) .. refusal())
  robotError("robot problem: " .. why)
end
