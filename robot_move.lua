--- robot_move(left, right, seconds): the built-in kids
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
--- Integration: require this from the platform, then
--- expose robot_move (and optionally robot_connect) in the
--- user program environment
--- (ConsoleController.prepare_env).

require("robot_transport")

--- extra read time on top of the movement itself
ROBOT_EXTRA_WAIT_S = 2
ROBOT_SECONDS_MAX = 30
--- kid-readable hints for firmware error replies
ROBOT_HINTS = {
  ["ERR i2c"] = "is the robot switched on?",
}

local robot_port = nil

local function robotError(msg)
  error(msg, 0)
end

local function checkSpeed(value, side)
  if type(value) ~= "number"
      or value < -100 or value > 100 then
    robotError(side .. " wheel speed must be a number "
      .. "from -100 to 100")
  end
  return math.floor(value + 0.5)
end

local function checkSeconds(value)
  if type(value) ~= "number" or value <= 0
      or value > ROBOT_SECONDS_MAX then
    robotError("time must be a number of seconds "
      .. "up to " .. ROBOT_SECONDS_MAX)
  end
  local ms = math.floor(value * 1000 + 0.5)
  if ms < 1 then ms = 1 end
  return ms
end

--- Open the transport and verify our firmware answers.
--- dev is optional (tests, unusual device names).
function robot_connect(dev)
  local port, err = transportOpen(dev)
  if not port then
    robotError("robot not connected (" .. err .. ")")
  end
  local pong = transportCommand(port, "PING", 2)
  if pong ~= "PONG" then
    transportClose(port)
    robotError("the robot is not answering, "
      .. "check the cable and try again")
  end
  robot_port = port
end

local function dropPort()
  if robot_port then
    transportClose(robot_port)
    robot_port = nil
  end
end

local function ensureConnected()
  if not robot_port then robot_connect() end
  return robot_port
end

function robot_move(left, right, seconds)
  local l = checkSpeed(left, "left")
  local r = checkSpeed(right, "right")
  local ms = checkSeconds(seconds)
  local port = ensureConnected()
  local line = "M " .. l .. " " .. r .. " " .. ms
  local wait = ms / 1000 + ROBOT_EXTRA_WAIT_S
  local reply, err = transportCommand(port, line, wait)
  if reply == "OK" then return true end
  if reply == nil then dropPort() end
  local why = reply and (ROBOT_HINTS[reply] or reply)
      or ("connection lost: " .. tostring(err))
  robotError("robot problem: " .. why)
end
