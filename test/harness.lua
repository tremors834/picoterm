-- MAME test driver: loads PICOTERM.BIN into the stand-in machine, starts
-- it, types keys, and writes screen dumps.  Scenario file from $SCEN.
local cpu = manager.machine.devices[":maincpu"]
local sp = cpu.spaces["program"]
local ports = manager.machine.ioport.ports
local scen = dofile(os.getenv("SCEN"))
local out = io.open(os.getenv("OUT") or "result.txt", "w")

-- serial port settings: 1200 baud 8N1
local function setport(tag, want)
  local p = ports[tag]
  for _, f in pairs(p.fields) do
    for v, name in pairs(f.settings) do
      if name == want then f.user_value = v end
    end
  end
end
setport(":rs232:null_modem:RS232_TXBAUD", "1200")
setport(":rs232:null_modem:RS232_RXBAUD", "1200")
setport(":rs232:null_modem:RS232_DATABITS", "8")
setport(":rs232:null_modem:RS232_PARITY", "None")
setport(":rs232:null_modem:RS232_STOPBITS", "1")
for _, f in pairs(ports[":screen_config"].fields) do
  for v, name in pairs(f.settings) do if name:match("RGB") then f.user_value = v end end
end

-- character -> {port, field, shift}
local keys = {}
for tag, p in pairs(ports) do
  if tag:match("^:row%d$") then
    for name, f in pairs(p.fields) do
      local a, b = name:match("^(%S+)%s%s(%S+)")
      if a and #a == 1 then
        keys[a:upper()] = { f, false }
        keys[b] = keys[b] or { f, true }
        if a:match("%a") then keys[a] = { f, true } end
      elseif #name == 1 then
        keys[name] = { f, false }
      else
        keys[name] = { f, false }
      end
    end
  end
end
keys["\r"] = keys["ENTER"]
keys[" "] = keys["SPACE"]
local shift = keys["SHIFT"][1]
local ctrl = keys["CTRL"][1]

local queue = {}   -- {field, mods...} presses waiting
local function typestr(s)
  for i = 1, #s do
    local ch = s:sub(i, i)
    local k = keys[ch]
    if not k then error("no key for " .. ch) end
    queue[#queue + 1] = { k[1], k[2] and shift or nil }
  end
end

local function hex(a) return string.format("%04X", a) end
local function vars()
  local function w(a) return sp:read_u8(a) * 256 + sp:read_u8(a + 1) end
  return {
    rxcnt = w(0x4F0A), ferr = sp:read_u8(0x4F0C), ovf = sp:read_u8(0x4F0D),
    top = sp:read_u8(0x4F0E), currow = sp:read_u8(0x4F17), curcol = sp:read_u8(0x4F18),
    voff = w(0x4F15),
  }
end
local function dump(label)
  local v = vars()
  out:write(string.format("=== %s  t=%.1f  rxcnt=%d ferr=%d ovf=%d top=%d row=%d col=%d voff=%s PC=%s\n",
    label, manager.machine.time:as_double(), v.rxcnt, v.ferr, v.ovf, v.top, v.currow, v.curcol,
    hex(v.voff), hex(cpu.state["PC"].value)))
  -- read what the GIME shows: from voff
  local base = 0xA000 + (v.voff - 0xC000) * 8
  for r = 0, 23 do
    local t = {}
    for c = 0, 79 do
      local a = base + r * 160 + c * 2
      local ch = sp:read_u8(a)
      local at = sp:read_u8(a + 1)
      if at >= 0xC0 then t[#t + 1] = "_" elseif ch >= 32 and ch < 127 then t[#t + 1] = string.char(ch) else t[#t + 1] = "?" end
    end
    out:write(string.format("%02d|%s|\n", r, table.concat(t)))
  end
  out:flush()
end

local started = false
local step = 1
local hold, gap = 0, 0
local cur = nil
emu.register_frame_done(function()
  local t = manager.machine.time:as_double()
  if not started and t > 0.5 then
    -- load the DECB binary
    local f = io.open(os.getenv("BIN"), "rb")
    local d = f:read("a"); f:close()
    local i = 1
    while true do
      local typ = d:byte(i)
      local len = d:byte(i + 1) * 256 + d:byte(i + 2)
      local addr = d:byte(i + 3) * 256 + d:byte(i + 4)
      i = i + 5
      if typ == 0xFF then break end
      for j = 0, len - 1 do sp:write_u8(addr + j, d:byte(i + j)) end
      i = i + len
    end
    sp:write_u8(0x0181, 0)
    sp:write_u8(0x0180, 1)
    started = true
  end
  -- key presses: hold 4 frames, then 4 frames gap
  if cur then
    hold = hold - 1
    if hold == 0 then
      cur[1]:clear_value()
      if cur[2] then cur[2]:clear_value() end
      cur = nil
      gap = 4
    end
  elseif gap > 0 then
    gap = gap - 1
  elseif #queue > 0 then
    cur = table.remove(queue, 1)
    if cur[2] then cur[2]:set_value(1) end
    cur[1]:set_value(1)
    hold = 4
  end
  local s = scen[step]
  if s and t >= s.t then
    step = step + 1
    if s.type then typestr(s.type) end
    if s.key then queue[#queue + 1] = { keys[s.key][1], s.mod and keys[s.mod][1] or nil } end
    if s.dump then dump(s.dump) end
    if s.snap then manager.machine.video:snapshot() end
    if s.check then
      out:write(string.format("exited=%d PC=%s\n", sp:read_u8(0x0181), hex(cpu.state["PC"].value)))
    end
    if s.exit then out:close(); manager.machine:exit() end
  end
end)
