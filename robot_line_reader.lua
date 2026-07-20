--- Shared response-line reader for robot transports.
---
--- Both backends read the port in slices of at most
--- SERIAL_SLICE seconds; they differ only in the primitive
--- that fetches one slice of bytes. This module owns the
--- shared logic -- accumulating chunks, tolerating CR,
--- splitting lines, counting only quiet slices against the
--- timeout -- so it is written and tested exactly once.
---
--- readSlice(state) -> chunk string ("" when the slice
--- timed out with no data), or nil, err on a dead device.

--- One read slice lasts at most this long, in seconds.
--- The posix backend enforces it via stty `time 2`; the
--- android backend passes it to bulkTransfer as ms.
SERIAL_SLICE = 0.2

--- Pull one line out of state.pending, if complete.
local function takeLine(state)
  local nl = state.pending:find("\n", 1, true)
  if not nl then return nil end
  local line = state.pending:sub(1, nl - 1)
  state.pending = state.pending:sub(nl + 1)
  return (line:gsub("\r", ""))
end

--- Read one response line. The timeout counts only quiet
--- slices, so an actively arriving response never times
--- out mid-line regardless of its length.
--- Optional hook called once per quiet slice during a
--- blocking read. Integration can point it at an event
--- pump so long robot moves keep the UI responsive
--- (Android ANR mitigation). nil = no hook.
LINE_READER_IDLE = nil

--- Account for one slice: an empty slice counts against
--- the quiet deadline, data does not.
local function absorbSlice(state, chunk)
  if chunk == "" then
    if LINE_READER_IDLE then LINE_READER_IDLE() end
    return 1
  end
  state.pending = state.pending .. chunk
  return 0
end

function lineReaderRead(state, readSlice, timeout_s)
  local quiet = 0
  while quiet * SERIAL_SLICE < timeout_s do
    local line = takeLine(state)
    if line then return line end
    local chunk, err = readSlice(state)
    if chunk == nil then return nil, err end
    quiet = quiet + absorbSlice(state, chunk)
  end
  return nil, "timeout"
end
