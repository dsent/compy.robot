--- One-line robot control for the console.
---
--- Lua calls a function with a single string without
--- parentheses, so with this loaded a move is:
---     m"40 -40 1"
--- left wheel, right wheel, seconds -- the three numbers
--- robot_move takes. The robot connects on its own and every
--- move answers, so nothing needs wrapping in print().
---
--- Only the console needs this. A program calls robot_move
--- directly.

require("robot.move")

local NUM = "(-?%d+%.?%d*)"
local MOVE = "^%s*" .. NUM .. "%s+" .. NUM .. "%s+" .. NUM
    .. "%s*$"
local USAGE = 'say it like this: m"40 -40 1"'
    .. ' -- left, right, seconds'

function m(command)
  if type(command) ~= "string" then
    print(USAGE)
    return
  end
  local left, right, seconds = command:match(MOVE)
  if not left then
    print(USAGE)
    return
  end
  local ok, err = pcall(robot_move, tonumber(left),
    tonumber(right), tonumber(seconds))
  print(ok and "ok" or err)
end
