lines = { }
heard = ""
for line in readfile("r.lua"):gmatch("[^\r\n]+") do
  table.insert(lines, line)
end

function compy.serial.onBytes(bytes)
  io.write(bytes)
  heard = (heard .. bytes):sub(-2)
  local ready = heard == "> " and 0 < #lines
  if ready then
    compy.serial.send(table.remove(lines, 1) .. "\r")
  end
end

compy.serial.send("\r")
