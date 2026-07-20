--- Unit tests for the shared line reader with scripted
--- slices. This is what makes the android command path
--- sandbox-testable: same code, stubbed readSlice.
dofile("robot_line_reader.lua")

local failures = 0
local function check(name, got, want)
  local ok = got == want
  print(string.format("%-36s %s (got %s)",
    name, ok and "PASS" or "FAIL", tostring(got)))
  if not ok then failures = failures + 1 end
end

local function scripted(slices)
  local st = { pending = "", i = 0 }
  local function slice(state)
    state.i = state.i + 1
    local v = slices[state.i]
    if v == false then return nil, "io error" end
    return v or ""
  end
  return st, slice
end

local st, sl = scripted({ "PO", "NG\n" })
check("split across slices",
  lineReaderRead(st, sl, 2), "PONG")

st, sl = scripted({ "OK\nPONG\n" })
check("two lines: first", lineReaderRead(st, sl, 2), "OK")
check("two lines: second (no read)",
  lineReaderRead(st, sl, 2), "PONG")

st, sl = scripted({ "OK\r\n" })
check("crlf stripped", lineReaderRead(st, sl, 2), "OK")

st, sl = scripted({})
local r, e = lineReaderRead(st, sl, 0.6)
check("quiet timeout", e, "timeout")

st, sl = scripted({ false })
local r2, e2 = lineReaderRead(st, sl, 2)
check("dead device propagates", e2, "io error")

st, sl = scripted({ "", "ER", "", "R parse\n" })
check("quiet gaps inside a line ok",
  lineReaderRead(st, sl, 0.8), "ERR parse")

print(failures == 0 and "ALL PASS" or
  failures .. " FAILURES")
os.exit(failures == 0 and 0 or 1)
