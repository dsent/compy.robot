--- Robot transport: one interface, per-platform backends.
---
--- Backends implement open() -> port | nil, err;
--- command(port, line, timeout_s) -> reply | nil, err;
--- close(port). The posix backend is device-verified on
--- Linux; the android backend is blind-coded pending a
--- device test.

dofile("robot_serial.lua")
dofile("robot_usb_android.lua")

local function posixOpen(dev)
  dev = dev or serialFindDevice()
  if not dev then
    return nil, "no /dev serial device found"
  end
  return serialOpen(dev)
end

TRANSPORT_BACKENDS = {
  posix = {
    open = posixOpen,
    command = serialCommand,
    close = serialClose,
  },
  android = {
    open = usbAndroidOpen,
    command = usbAndroidCommand,
    close = usbAndroidClose,
  },
}

function transportBackendName()
  if love and love.system.getOS() == "Android" then
    return "android"
  end
  return "posix"
end

--- dev is optional: an explicit device path for the
--- posix backend (tests, unusual device names).
function transportOpen(dev)
  local name = transportBackendName()
  local port, err = TRANSPORT_BACKENDS[name].open(dev)
  if port then port.backend = name end
  return port, err
end

function transportCommand(port, line, timeout_s)
  local b = TRANSPORT_BACKENDS[port.backend]
  return b.command(port, line, timeout_s)
end

function transportClose(port)
  TRANSPORT_BACKENDS[port.backend].close(port)
end
