compy.serial.onBytes = function(bytes)
  io.write(bytes)
end

assert(compy.serial.isConnected(), "Connect the microbit.")
local code = assert(readfile("r.lua"), "Cannot read r.lua")
code = code:gsub("\r\n", "\n"):gsub("\n", "\r")
assert(compy.serial.send(code .. "\r"))
