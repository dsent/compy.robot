-- Sandbox test: splice the patch into a stubbed lua-script.lua
-- environment and exercise it through the serial handler, the
-- way the real firmware would.
local out, i2c_writes, slept = {}, {}, {}
i2c_ok = true

-- runtime stubs
microbit = {
  DEVICE_ID_SERIAL = 1,
  CODAL_SERIAL_EVT_HEAD_MATCH = 7,
  sleep = function(ms) slept[#slept+1] = ms end,
  serial = { eventAfterAsync = function() end },
  i2c = { write = function(addr, s)
    if not i2c_ok then error("i2c write error") end
    i2c_writes[#i2c_writes+1] = { addr = addr, bytes = s }
  end },
}
uBit = microbit

-- file-scope locals the patch borrows from lua-script.lua
buffer = ""
local rx = ""
function getChar()
  if #rx == 0 then return nil end
  local c = rx:sub(1, 1)
  rx = rx:sub(2)
  return c
end
function write(s) out[#out+1] = s end
function prompt() out[#out+1] = "> " end
handler = { [1] = function() out[#out+1] = "REPL" end }

local src = io.open("robot/tpbot-old-firmware/microbit-lua/protocolPatch.lua"):read("*a")
-- the patch uses `local` at file scope; exec in this env
local chunk = loadstring(src:gsub("^", ""))
chunk()

local fails = 0
local function check(name, got, want)
  local ok = got == want
  print(string.format("%-34s %s (got %s)", name,
    ok and "PASS" or "FAIL", tostring(got)))
  if not ok then fails = fails + 1 end
end

-- before switching, serial goes to the REPL handler
handler[1](7)
check("repl untouched before switch", out[1], "REPL")

robot_protocol()
local function feed(s)
  out = {}
  rx = s
  handler[microbit.DEVICE_ID_SERIAL](7)
  return table.concat(out)
end

check("ping", feed("PING\n"), "PONG\n")
check("no echo of input", feed("PING\n"), "PONG\n")
check("cr also terminates", feed("PING\r"), "PONG\n")
check("move", feed("M 20 80 300\n"), "OK\n")
check("negative", feed("M -50 50 200\n"), "OK\n")
check("range", feed("M 200 0 100\n"), "ERR range\n")
check("parse", feed("HELLO\n"), "ERR parse\n")
check("float ms", feed("M 10 10 1.5\n"), "ERR parse\n")
check("empty line ignored", feed("\n"), "")
check("split across events",
  feed("M 10 ") .. feed("10 50\n"), "OK\n")
check("two commands one event",
  feed("PING\nPING\n"), "PONG\nPONG\n")

slept, i2c_writes = {}, {}
feed("M -50 50 250\n")
check("start, then stop", #i2c_writes, 2)
check("i2c address", i2c_writes[1].addr, 32)
check("motor payload matches tpbot.lua",
  i2c_writes[1].bytes,
  string.char(1) .. string.char(50) .. string.char(50)
    .. string.char(1))
check("slept the movement", slept[1], 250)
check("stop payload zeroed", i2c_writes[2].bytes,
  string.char(1) .. string.char(0) .. string.char(0)
    .. string.char(0))

i2c_ok = false
check("chassis off", feed("M 10 10 100\n"), "ERR i2c\n")
i2c_ok = true
check("recovers when chassis on",
  feed("M 10 10 50\n"), "OK\n")

out = {}
rx = "EXIT\n"
handler[microbit.DEVICE_ID_SERIAL](7)
check("exit restores repl", out[1], "> ")
out = {}
handler[1](7)
check("repl handler back", out[1], "REPL")

print(fails == 0 and "ALL PASS" or fails .. " FAILURES")
