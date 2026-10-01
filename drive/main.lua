-- drive: drive the robot with the keys.
--
-- While you hold keys, drive sends the micro:bit one line,
-- robot_move(left, right, 0.5), each time it shows its
-- prompt. Every line goes into r.lua; stop drive, then
-- dofile("replay.lua") drives it again.

-- Left hand, left wheel; right hand, right wheel. Up is
-- forward, and the outer keys are fast.
LEFT = {
  ["1"] = 100,
  q = 50,
  a = -50,
  z = -100
}
RIGHT = {
  ["-"] = 100,
  p = 50,
  [";"] = -50,
  ["/"] = -100
}
-- How long one line drives, in seconds
STEP = 0.5
-- Two keys pressed together go down a few frames apart: with
-- the robot standing, wait this long for the second, so it
-- goes straight. A line sent at the prompt does not wait.
TOGETHER = 0.07

-- The speed each wheel's key asks for while it is held
held = {
  left = 0,
  right = 0
}
-- The speed a key asked for since the last line, even if it
-- is up again: a quick tap still drives
tapped = {
  left = 0,
  right = 0
}
-- When a wheel key first went down since the last line
pressed_at = nil
-- The micro:bit shows its prompt and waits for a line
ready = false
-- The end of what the micro:bit said, to find its prompt
heard = ""
clock = 0

-- The lines this run drove, for r.lua, and the last of them
route = { }
last = nil

-- A held key repeats; only its first press counts
function love.keypressed(key, scancode, isrepeat)
  if not isrepeat then
    press("left", LEFT[scancode])
    press("right", RIGHT[scancode])
  end
  return true
end

function love.keyreleased(key, scancode)
  release("left", LEFT[scancode])
  release("right", RIGHT[scancode])
  return true
end

-- @param side string
-- @param speed number? nil: not this wheel's key
function press(side, speed)
  if speed then
    held[side] = speed
    tapped[side] = speed
    pressed_at = pressed_at or clock
  end
end

-- @param side string
-- @param speed number? nil: not this wheel's key
function release(side, speed)
  local driving = speed and held[side] == speed
  if driving then
    held[side] = 0
  end
end

-- Letters typed for the wheels stay out of the console
function love.textinput()
  return true
end

function love.update(dt)
  clock = clock + dt
  local waited = pressed_at and TOGETHER <= clock - pressed_at
  local due = ready and waited
  if due then
    sendLine()
  end
end

function compy.serial.onBytes(bytes)
  io.write(bytes)
  heard = (heard .. bytes):sub(-2)
  if heard == "> " then
    ready = true
    keepGoing()
  end
end

-- A key still held, or tapped while the robot moved, drives
-- the next line at once
function keepGoing()
  local asked = wheel("left") ~= 0 or wheel("right") ~= 0
  if asked then
    sendLine()
  end
end

-- @param side string
-- @return number
function wheel(side)
  if held[side] ~= 0 then
    return held[side]
  end
  return tapped[side]
end

function sendLine()
  local left, right = wheel("left"), wheel("right")
  tapped = {
    left = 0,
    right = 0
  }
  pressed_at = nil
  ready = false
  compy.serial.send(moveLine(left, right, STEP) .. "\r")
  record(left, right)
end

-- @return string
function moveLine(left, right, seconds)
  return ("robot_move(%d, %d, %g)"):format(left, right, seconds)
end

-- A line at the same speeds as the last one adds its seconds
-- to it; another speed starts a new line
function record(left, right)
  local same = last and last.left == left
       and last.right == right
  if not same then
    last = {
      left = left,
      right = right,
      seconds = 0
    }
    table.insert(route, "")
  end
  last.seconds = last.seconds + STEP
  route[#route] = moveLine(left, right, last.seconds)
end

-- r.lua is written when drive stops
function saveRoute()
  writefile("r.lua", route)
end

compy.before_exit = saveRoute
print("drive: left wheel 1 Q A Z, right wheel - P ; /")
compy.serial.send("\r")
