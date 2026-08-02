--- Android USB serial backend for the robot transport.
---
--- Talks to the micro:bit (DAPLink CDC-ACM, VID 0x0D28)
--- through android.hardware.usb, reached entirely from Lua
--- via robot_jni.lua. Works in a non-rooted, non-privileged
--- app; Android will show the user a permission dialog on
--- first connect.
---
--- Every setup step is a named stage. usbAndroidOpen
--- returns a port, or nil plus "stage <name>: <why>" so a
--- single remote run pinpoints exactly how far it got.
---
--- Library-level code: core style rules (80 cols) apply.
--- BLIND-CODED: not yet verified on a device.
---
--- THREADING CONSTRAINT: JNIEnv is thread-local, and the
--- port caches it. Port and all calls on it must stay on
--- the thread that opened it. If the ANR fix (ticket 4)
--- moves robot work to a love.thread, the whole transport
--- must live inside that thread, opened there.

require("robot.jni")
require("robot.lineReader")

USB_VENDOR_MICROBIT = 0x0D28
USB_CLASS_CDC_COMM = 2
USB_CLASS_CDC_DATA = 10
USB_ENDPOINT_BULK = 2
USB_DIR_IN = 0x80
USB_SLICE_MS = SERIAL_SLICE * 1000
USB_PERMISSION_WAIT_S = 60
--- PendingIntent.FLAG_IMMUTABLE, required on Android 12+
USB_PI_IMMUTABLE = 0x04000000
--- CDC-ACM control requests (USB CDC PSTN spec)
ACM_REQTYPE_CLASS_IFACE = 0x21
ACM_SET_LINE_CODING = 0x20
ACM_SET_CONTROL_LINE_STATE = 0x22
ACM_DTR_AND_RTS = 0x03
ACM_CTRL_TIMEOUT_MS = 1000

local function stageFail(stage, why)
  return nil, "stage " .. stage .. ": " .. tostring(why)
end

--- android.content.Context.getSystemService("usb")
local function usbManager(env, activity)
  local ctx = jniClass(env, "android/content/Context")
  local gss = jniMethod(env, ctx, "getSystemService",
    "(Ljava/lang/String;)Ljava/lang/Object;")
  local m = jniCallObj(env, activity, gss, jniStr(env, "usb"))
  assert(m ~= nil, "no UsbManager")
  return m
end

--- Iterate manager.getDeviceList() values, return the first
--- device with the micro:bit vendor id.
local function findDevice(env, manager)
  local mgr = jniClass(env, "android/hardware/usb/UsbManager")
  local dl = jniMethod(env, mgr, "getDeviceList",
    "()Ljava/util/HashMap;")
  local map = jniCallObj(env, manager, dl)
  local mapCls = jniClass(env, "java/util/HashMap")
  local values = jniMethod(env, mapCls, "values",
    "()Ljava/util/Collection;")
  local coll = jniCallObj(env, map, values)
  local collCls = jniClass(env, "java/util/Collection")
  local itm = jniMethod(env, collCls, "iterator",
    "()Ljava/util/Iterator;")
  local it = jniCallObj(env, coll, itm)
  local itCls = jniClass(env, "java/util/Iterator")
  local hasNext = jniMethod(env, itCls, "hasNext", "()Z")
  local nextM = jniMethod(env, itCls, "next",
    "()Ljava/lang/Object;")
  local devCls = jniClass(env, "android/hardware/usb/UsbDevice")
  local getVid = jniMethod(env, devCls, "getVendorId", "()I")
  while jniCallBool(env, it, hasNext) do
    local dev = jniCallObj(env, it, nextM)
    if jniCallInt(env, dev, getVid) == USB_VENDOR_MICROBIT then
      return dev
    end
    jniDropLocal(env, dev)
  end
  return nil
end

local function sleepS(seconds)
  if love and love.timer then
    love.timer.sleep(seconds)
  else
    os.execute("sleep " .. seconds)
  end
end

--- Ask for USB permission and poll until the user grants it
--- (Android delivers the result via broadcast; polling
--- hasPermission avoids needing a Java-side receiver).
local function ensurePermission(env, activity, manager, dev)
  local mgr = jniClass(env, "android/hardware/usb/UsbManager")
  local has = jniMethod(env, mgr, "hasPermission",
    "(Landroid/hardware/usb/UsbDevice;)Z")
  if jniCallBool(env, manager, has, dev) then return true end
  local intCls = jniClass(env, "android/content/Intent")
  local ctor = jniMethod(env, intCls, "<init>",
    "(Ljava/lang/String;)V")
  local intent = jniNewObj(env, intCls, ctor,
    jniStr(env, "net.compy.USB_PERMISSION"))
  local piCls = jniClass(env, "android/app/PendingIntent")
  local getB = jniStaticMethod(env, piCls, "getBroadcast",
    "(Landroid/content/Context;ILandroid/content/Intent;I)" ..
    "Landroid/app/PendingIntent;")
  local pi = jniCallStaticObj(env, piCls, getB,
    activity, 0, intent, USB_PI_IMMUTABLE)
  local req = jniMethod(env, mgr, "requestPermission",
    "(Landroid/hardware/usb/UsbDevice;" ..
    "Landroid/app/PendingIntent;)V")
  jniCallVoid(env, manager, req, dev, pi)
  for _ = 1, USB_PERMISSION_WAIT_S * 2 do
    if jniCallBool(env, manager, has, dev) then return true end
    sleepS(0.5)
  end
  return false
end

--- Walk the device's interfaces: remember the CDC control
--- interface id (control-transfer wIndex) and the CDC data
--- interface with its bulk in/out endpoints.
local function findEndpoints(env, dev)
  local devCls = jniClass(env, "android/hardware/usb/UsbDevice")
  local ifCount = jniMethod(env, devCls,
    "getInterfaceCount", "()I")
  local getIf = jniMethod(env, devCls, "getInterface",
    "(I)Landroid/hardware/usb/UsbInterface;")
  local ifCls = jniClass(env,
    "android/hardware/usb/UsbInterface")
  local ifClass = jniMethod(env, ifCls,
    "getInterfaceClass", "()I")
  local ifId = jniMethod(env, ifCls, "getId", "()I")
  local epCount = jniMethod(env, ifCls,
    "getEndpointCount", "()I")
  local getEp = jniMethod(env, ifCls, "getEndpoint",
    "(I)Landroid/hardware/usb/UsbEndpoint;")
  local epCls = jniClass(env,
    "android/hardware/usb/UsbEndpoint")
  local epType = jniMethod(env, epCls, "getType", "()I")
  local epDir = jniMethod(env, epCls, "getDirection", "()I")
  local found = {}
  for i = 0, jniCallInt(env, dev, ifCount) - 1 do
    local iface = jniCallObj(env, dev, getIf, i)
    local cls = jniCallInt(env, iface, ifClass)
    if cls == USB_CLASS_CDC_COMM and not found.commId then
      found.commId = jniCallInt(env, iface, ifId)
      found.comm = iface
    elseif cls == USB_CLASS_CDC_DATA and not found.data then
      found.data = iface
      for j = 0, jniCallInt(env, iface, epCount) - 1 do
        local ep = jniCallObj(env, iface, getEp, j)
        if jniCallInt(env, ep, epType) == USB_ENDPOINT_BULK then
          local isIn =
            jniCallInt(env, ep, epDir) == USB_DIR_IN
          if isIn then found.epIn = ep
          else found.epOut = ep end
        end
      end
    end
  end
  return found
end

local function byteArrayFrom(env, s)
  local ffi = require("ffi")
  local arr = env[0].NewByteArray(env, #s)
  local buf = ffi.new("int8_t[?]", #s)
  ffi.copy(buf, s, #s)
  env[0].SetByteArrayRegion(env, arr, 0, #s, buf)
  return arr
end

--- CDC line coding: 115200 baud (LE), 1 stop, no parity,
--- 8 data bits -- then raise DTR/RTS.
---
--- Both requests address the control interface, which is why
--- that interface has to be claimed as well; without the claim
--- Android refuses the transfer with -1.
---
--- Neither request is fatal. The micro:bit interface chip
--- already runs its target UART at the protocol baud rate, and
--- some stacks refuse these requests while the data path works
--- perfectly. The PING handshake in robot_connect is the real
--- test, so a refusal is recorded and reported only if the
--- handshake then fails.
local function configureAcm(env, port)
  local coding = string.char(0x00, 0xC2, 0x01, 0x00, 0, 0, 8)
  local arr = byteArrayFrom(env, coding)
  local rc = jniCallInt(env, port.conn, port.ctrlM,
    ACM_REQTYPE_CLASS_IFACE, ACM_SET_LINE_CODING, 0,
    port.commId, arr, #coding, ACM_CTRL_TIMEOUT_MS)
  local rc2 = jniCallInt(env, port.conn, port.ctrlM,
    ACM_REQTYPE_CLASS_IFACE, ACM_SET_CONTROL_LINE_STATE,
    ACM_DTR_AND_RTS, port.commId, nil, 0,
    ACM_CTRL_TIMEOUT_MS)
  if rc < 0 or rc2 < 0 then
    port.acmRefused = "line coding " .. rc .. ", dtr " .. rc2
  end
end

--- Open the robot over Android USB. Returns a port table
--- for usbAndroidCommand, or nil plus a staged error.
function usbAndroidOpen()
  local okc, err = pcall(jniSelfCheck)
  if not okc then return stageFail("selfcheck", err) end
  local ok, env = pcall(jniEnv)
  if not ok then return stageFail("env", env) end
  local oka, activity = pcall(jniActivity)
  if not oka then return stageFail("activity", activity) end
  local okm, manager = pcall(usbManager, env, activity)
  if not okm then return stageFail("manager", manager) end
  local okd, dev = pcall(findDevice, env, manager)
  if not okd then return stageFail("scan", dev) end
  if not dev then
    return stageFail("scan", "no micro:bit on the bus")
  end
  local okp, granted =
    pcall(ensurePermission, env, activity, manager, dev)
  if not okp then return stageFail("permission", granted) end
  if not granted then
    return stageFail("permission", "user did not grant")
  end
  return usbAndroidFinishOpen(env, manager, dev)
end

--- Second half of open: connection, endpoints, ACM setup.
function usbAndroidFinishOpen(env, manager, dev)
  local mgr = jniClass(env, "android/hardware/usb/UsbManager")
  local openM = jniMethod(env, mgr, "openDevice",
    "(Landroid/hardware/usb/UsbDevice;)" ..
    "Landroid/hardware/usb/UsbDeviceConnection;")
  local conn = jniCallObj(env, manager, openM, dev)
  if conn == nil then
    return stageFail("open", "openDevice returned null")
  end
  local oke, eps = pcall(findEndpoints, env, dev)
  if not oke then return stageFail("endpoints", eps) end
  if not (eps.data and eps.comm and eps.epIn and eps.epOut
      and eps.commId) then
    return stageFail("endpoints", "CDC set incomplete")
  end
  local connCls = jniClass(env,
    "android/hardware/usb/UsbDeviceConnection")
  local port = {
    kind = "android", env = env,
    conn = jniGlobal(env, conn),
    ifaceComm = jniGlobal(env, eps.comm),
    ifaceData = jniGlobal(env, eps.data),
    epIn = jniGlobal(env, eps.epIn),
    epOut = jniGlobal(env, eps.epOut),
    commId = eps.commId,
    pending = "",
    claimM = jniMethod(env, connCls, "claimInterface",
      "(Landroid/hardware/usb/UsbInterface;Z)Z"),
    releaseM = jniMethod(env, connCls, "releaseInterface",
      "(Landroid/hardware/usb/UsbInterface;)Z"),
    closeM = jniMethod(env, connCls, "close", "()V"),
    bulkM = jniMethod(env, connCls, "bulkTransfer",
      "(Landroid/hardware/usb/UsbEndpoint;[BII)I"),
    ctrlM = jniMethod(env, connCls, "controlTransfer",
      "(IIII[BII)I"),
  }
  -- Both interfaces: the data one carries the bulk endpoints,
  -- the control one is the target of the ACM setup requests.
  if not jniCallBool(env, port.conn, port.claimM,
      port.ifaceComm, true) then
    usbAndroidClose(port)
    return stageFail("claim", "control interface refused")
  end
  if not jniCallBool(env, port.conn, port.claimM,
      port.ifaceData, true) then
    usbAndroidClose(port)
    return stageFail("claim", "data interface refused")
  end
  local okc, cerr = pcall(configureAcm, env, port)
  if not okc then
    usbAndroidClose(port)
    return stageFail("acm", cerr)
  end
  port.rxArr = jniGlobal(env, env[0].NewByteArray(env, 64))
  return port
end

local function usbWrite(port, s)
  local env = port.env
  local arr = byteArrayFrom(env, s)
  local n = jniCallInt(env, port.conn, port.bulkM,
    port.epOut, arr, #s, 1000)
  jniDropLocal(env, arr)
  return n == #s
end

--- One bulk-in read slice; returns "" when the slice timed
--- out with no data (bulkTransfer < 0).
local function usbReadSlice(port)
  local ffi = require("ffi")
  local env = port.env
  local n = jniCallInt(env, port.conn, port.bulkM,
    port.epIn, port.rxArr, 64, USB_SLICE_MS)
  if n <= 0 then return "" end
  local buf = ffi.new("int8_t[?]", n)
  env[0].GetByteArrayRegion(env, port.rxArr, 0, n, buf)
  return ffi.string(buf, n)
end

--- Same contract and timeout semantics as serialCommand:
--- one command line out, one response line back; framing
--- and deadlines live in the shared line reader.
function usbAndroidCommand(port, line, timeout_s)
  if not usbWrite(port, line .. "\n") then
    return nil, "write: bulk transfer failed"
  end
  return lineReaderRead(port, usbReadSlice, timeout_s)
end

--- Android keeps the interface claims and the connection
--- alive until they are handed back explicitly; dropping the
--- Lua port is not enough. A claim left behind survives for
--- the life of the app process and makes the next open fail
--- its ACM setup, so release both interfaces before letting
--- go. Safe on a half-built port: open calls it when a stage
--- fails, before rxArr exists.
function usbAndroidClose(port)
  if port.closed then return end
  port.closed = true
  local env = port.env
  jniCallBool(env, port.conn, port.releaseM, port.ifaceComm)
  jniCallBool(env, port.conn, port.releaseM, port.ifaceData)
  jniCallVoid(env, port.conn, port.closeM)
  env[0].DeleteGlobalRef(env, port.conn)
  env[0].DeleteGlobalRef(env, port.ifaceComm)
  env[0].DeleteGlobalRef(env, port.ifaceData)
  env[0].DeleteGlobalRef(env, port.epIn)
  env[0].DeleteGlobalRef(env, port.epOut)
  if port.rxArr then
    env[0].DeleteGlobalRef(env, port.rxArr)
  end
end
