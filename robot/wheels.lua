--- The wheel bench: two gauges, a clock, and one move.
---
--- Q and A raise and lower the left wheel, P and L the
--- right one, the up and down arrows the seconds, and
--- Enter sends the move the screen is showing.
---
--- The gauges step through the powers the TPBot answers
--- to. Below 40 percent the wheels do not turn at all, so
--- the ladder jumps straight from 0 to 40 rather than
--- offering numbers that do nothing.
---
--- The console line for the same move is printed across
--- the screen, so the gauges and m"40 -40 1" are visibly
--- one thing.

require("robot.move")

--- wheel powers in gauge order; index 5 is the still wheel
WHEEL_STEPS = { -100, -80, -60, -40, 0, 40, 60, 80, 100 }
WHEEL_ZERO = 5
TIME_STEP = 0.25
TIME_MIN = 0.25
TIME_MAX = 10

BENCH = { }
BENCH.left = WHEEL_ZERO
BENCH.right = WHEEL_ZERO
BENCH.seconds = 1
BENCH.note = ""
BENCH.sending = 0

BENCH_W = gfx.getWidth()
BENCH_H = gfx.getHeight()
GAUGE_TOP = 50
GAUGE_BOT = BENCH_H - 300
GAUGE_MID = (GAUGE_TOP + GAUGE_BOT) / 2
GAUGE_HALF = (GAUGE_BOT - GAUGE_TOP) / 2
LEFT_X = BENCH_W * 0.2
RIGHT_X = BENCH_W * 0.8
MID_X = BENCH_W / 2

--- Text baselines, top down, sized for a 48px numeral.
NUM_Y = GAUGE_BOT + 8
KEYS_Y = GAUGE_BOT + 76
CMD_Y = BENCH_H - 180
NOTE_Y = BENCH_H - 110
HINT_Y = BENCH_H - 40

BIG_FONT = gfx.newFont(48)
MID_FONT = gfx.newFont(26)
SMALL_FONT = gfx.newFont(16)

function leftPower()
  return WHEEL_STEPS[BENCH.left]
end

function rightPower()
  return WHEEL_STEPS[BENCH.right]
end

--- The same move written the way the console takes it.
function commandLine()
  return "m\"" .. leftPower() .. " " .. rightPower()
    .. " " .. BENCH.seconds .. "\""
end

function nudgeWheel(side, delta)
  local v = BENCH[side] + delta
  if v < 1 then v = 1 end
  if v > #WHEEL_STEPS then v = #WHEEL_STEPS end
  BENCH[side] = v
end

function nudgeTime(delta)
  local t = BENCH.seconds + delta
  if t < TIME_MIN then t = TIME_MIN end
  if t > TIME_MAX then t = TIME_MAX end
  BENCH.seconds = t
end

function raiseLeft()
  nudgeWheel("left", 1)
end

function lowerLeft()
  nudgeWheel("left", -1)
end

function raiseRight()
  nudgeWheel("right", 1)
end

function lowerRight()
  nudgeWheel("right", -1)
end

function raiseTime()
  nudgeTime(TIME_STEP)
end

function lowerTime()
  nudgeTime(-TIME_STEP)
end

--- Enter only arms the move. love.update sends it once the
--- screen has shown what is about to run.
function armMove()
  BENCH.note = ""
  BENCH.sending = 1
end

BENCH_KEYS = { }
BENCH_KEYS.q = raiseLeft
BENCH_KEYS.a = lowerLeft
BENCH_KEYS.p = raiseRight
BENCH_KEYS.l = lowerRight
BENCH_KEYS.up = raiseTime
BENCH_KEYS.down = lowerTime
BENCH_KEYS["return"] = armMove
BENCH_KEYS.kpenter = armMove

--- Key repeat is left on, so a held key walks the gauge.
function love.keypressed(key)
  if BENCH.sending > 0 then return end
  local action = BENCH_KEYS[key]
  if action then
    action()
  end
end

function sendMove()
  local ok, err = pcall(robot_move, leftPower(),
    rightPower(), BENCH.seconds)
  BENCH.note = ok and "ok" or tostring(err)
end

--- robot_move returns only when the wheels stop, so the
--- screen cannot move during a move. Wait for the armed
--- command to be drawn first: the frozen frame the room
--- watches is then the command that is running.
function love.update()
  if BENCH.sending < 1 then return end
  if BENCH.sending < 3 then
    BENCH.sending = BENCH.sending + 1
    return
  end
  BENCH.sending = 0
  sendMove()
end

function drawBar(x, power, shade)
  local h = GAUGE_HALF * power / 100
  local top = GAUGE_MID - h
  if h < 0 then
    top = GAUGE_MID
    h = -h
  end
  gfx.setColor(Color[shade + Color.bright])
  gfx.rectangle("fill", x - 40, top, 80, h)
end

function drawGauge(x, power, shade, keys)
  gfx.setColor(Color[Color.white])
  gfx.rectangle("line", x - 50, GAUGE_TOP, 100,
    GAUGE_BOT - GAUGE_TOP)
  drawBar(x, power, shade)
  gfx.setColor(Color[Color.white + Color.bright])
  gfx.rectangle("fill", x - 50, GAUGE_MID - 1, 100, 3)
  gfx.setFont(BIG_FONT)
  gfx.setColor(Color[shade + Color.bright])
  gfx.printf(tostring(power), x - 150, NUM_Y, 300,
    "center")
  gfx.setFont(SMALL_FONT)
  gfx.setColor(Color[Color.white])
  gfx.printf(keys, x - 150, KEYS_Y, 300, "center")
end

function drawClockBar()
  local w = 240 * BENCH.seconds / TIME_MAX
  gfx.setColor(Color[Color.yellow + Color.bright])
  gfx.rectangle("fill", MID_X - 120, GAUGE_MID + 25, w, 16)
  gfx.setColor(Color[Color.white])
  gfx.rectangle("line", MID_X - 120, GAUGE_MID + 25, 240,
    16)
end

--- The third number, with a bar that grows beside it: a
--- too-big time looks too big before it is ever sent.
function drawClock()
  gfx.setColor(Color[Color.white])
  gfx.setFont(SMALL_FONT)
  gfx.printf("SEC", MID_X - 150, GAUGE_MID - 80, 300,
    "center")
  gfx.setFont(BIG_FONT)
  gfx.setColor(Color[Color.yellow + Color.bright])
  gfx.printf(tostring(BENCH.seconds), MID_X - 150,
    GAUGE_MID - 50, 300, "center")
  drawClockBar()
  gfx.setColor(Color[Color.white])
  gfx.setFont(SMALL_FONT)
  gfx.printf("UP / DOWN", MID_X - 150, GAUGE_MID + 53, 300,
    "center")
end

function drawCommand()
  gfx.setColor(Color[Color.cyan + Color.bright])
  gfx.setFont(BIG_FONT)
  gfx.printf(commandLine(), 0, CMD_Y, BENCH_W, "center")
end

function drawNote()
  gfx.setFont(MID_FONT)
  if BENCH.sending > 0 then
    gfx.setColor(Color[Color.yellow + Color.bright])
    gfx.printf("...", 0, NOTE_Y, BENCH_W, "center")
    return
  end
  gfx.setColor(Color[Color.white])
  gfx.printf(BENCH.note, 0, NOTE_Y, BENCH_W, "center")
end

function drawHint()
  gfx.setColor(Color[Color.white])
  gfx.setFont(SMALL_FONT)
  gfx.printf("ENTER", 0, HINT_Y, BENCH_W, "center")
end

function love.draw()
  gfx.setColor(Color[Color.black])
  gfx.rectangle("fill", 0, 0, BENCH_W, BENCH_H)
  drawGauge(LEFT_X, leftPower(), Color.green, "Q / A")
  drawGauge(RIGHT_X, rightPower(), Color.magenta, "P / L")
  drawClock()
  drawCommand()
  drawNote()
  drawHint()
end
