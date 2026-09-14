-- Robot wire protocol for microbit-lua
--
-- Insert this block into source/lua-script.lua, after the
-- on_event definition and before the script-level setup calls
-- (prompt() / getCharAsync() / eventAfterAsync()). It needs the
-- file-scope locals write, getChar, buffer, prompt and handler,
-- so it has to live in that file rather than in a module.
--
-- Nothing existing is modified: the protocol takes over the
-- serial port by swapping one entry in the handler table, and
-- restores the original handler on EXIT.
--
-- Serves the Compy robot protocol (PROTOCOL.md in
-- educationmatters/robot) alongside the human REPL:
--   robot_protocol()  from the REPL hands the port over
--   M <left> <right> <ms>  drive the wheels, reply after they stop
--   PING                   liveness check
--   EXIT                   back to the REPL
-- Replies: OK, PONG, ERR parse, ERR range, ERR i2c.
--
-- The reply to M is sent after the wheels stop, which is what
-- makes the Compy-side robot_move blocking: a child's program
-- then reads top to bottom as a sequence of actions. Sleeping
-- here is safe because on_codal_event runs each handler in its
-- own fiber, so the scheduler keeps running.

local SPEED_MIN, SPEED_MAX = -100, 100
local MS_MIN, MS_MAX = 1, 30000

local TPBOT_I2C_ADDR = 32
local TPBOT_CMD_MOTORS = "\001"

local sleep = uBit.sleep
local i2c_write = uBit.i2c.write
local char = string.char
local repl_serial = handler[microbit.DEVICE_ID_SERIAL]

-- Same wire format as tpbot.set_motors_speed in source/tpbot.lua,
-- inlined because that file is not part of the embedded payload:
-- magnitudes plus a direction mask (1 = left back, 2 = right
-- back). Swap this for tpbot.set_motors_speed once the library
-- is wired into the payload.
local function set_motors_speed(left, right)
  local direction = 0
  if left < 0 then
    direction = direction + 1
    left = -left
  end
  if right < 0 then
    direction = direction + 2
    right = -right
  end
  i2c_write(TPBOT_I2C_ADDR, TPBOT_CMD_MOTORS ..
    char(left) .. char(right) .. char(direction))
end

local function in_range(left, right, ms)
  return left >= SPEED_MIN and left <= SPEED_MAX
    and right >= SPEED_MIN and right <= SPEED_MAX
    and ms >= MS_MIN and ms <= MS_MAX
end

-- i2c.write raises a Lua error when the bus does not
-- acknowledge, which is what happens with the chassis switched
-- off, so both motor writes go through pcall.
local function move(left, right, ms)
  if not pcall(set_motors_speed, left, right) then
    return "ERR i2c"
  end
  sleep(ms)
  -- The stop write is the safety-critical one: if it is lost,
  -- the wheels keep their last speed.
  if not pcall(set_motors_speed, 0, 0) then
    return "ERR i2c"
  end
  return "OK"
end

local function command(line)
  if line == "PING" then
    return "PONG"
  end
  local l, r, ms = line:match("^M +(-?%d+) +(-?%d+) +(-?%d+)$")
  if not l then
    return "ERR parse"
  end
  l, r, ms = tonumber(l), tonumber(r), tonumber(ms)
  if not in_range(l, r, ms) then
    return "ERR range"
  end
  return move(l, r, ms)
end

-- The host terminates lines with \n; a hand tester in a
-- terminal may send \r. Accept either.
local function line_done()
  local line = buffer
  buffer = ""
  if line == "EXIT" then
    handler[microbit.DEVICE_ID_SERIAL] = repl_serial
    prompt()
  elseif line ~= "" then
    write(command(line) .. "\n")
  end
end

local protocol_keypress = {
  ["\r"] = line_done,
  ["\n"] = line_done
}

local function protocol_serial(value)
  if value == microbit.CODAL_SERIAL_EVT_HEAD_MATCH then
    local c = getChar()
    while c do
      local input = protocol_keypress[c]
      if input then
        input()
      else
        buffer = buffer .. c
      end
      c = getChar()
    end
    uBit.serial.eventAfterAsync(1)
  end
end

-- Called once from the REPL by the host (or by hand) to put the
-- port into protocol mode. No echo from here on, so the host
-- reads exactly one response line per command.
function robot_protocol()
  buffer = ""
  handler[microbit.DEVICE_ID_SERIAL] = protocol_serial
end
