-- miniapps.lua - Teléfono, Reloj, Calculadora, Calendario, Rendimiento, Notas y 2048 para miOS Next
local M = {}
local ctx, fonts, DAYS, MONTHS
local music = require("music")

-- ============ utilidades ============
local regs, held, curAct = {}, nil, nil

local function begin(act)
  regs = {}
  curAct = act
end

local function reg(name, x, y, w, h)
  regs[#regs + 1] = {n = name, x = x, y = y, w = w, h = h}
end

local function regAt(x, y)
  for i = #regs, 1, -1 do
    local r = regs[i]
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return r end
  end
  return nil
end

local function isHeld(name)
  return held ~= nil and held.n == name
end

local function press(id, x, y)
  held = nil
  local r = regAt(x, y)
  if r then held = {id = id, n = r.n} end
end

local function move(id, x, y)
  return held ~= nil and held.id == id
end

local function release(id, x, y)
  if not held or held.id ~= id then return false end
  local n = held.n
  held = nil
  local r = regAt(x, y)
  if r and r.n == n and curAct then curAct(n) end
  return true
end

local function setc(r, g, b, a, ca)
  love.graphics.setColor(r, g, b, (a or 1) * ca)
end

local function ctext(f, str, cx, cy, ca, r, g, b, a, maxw)
  love.graphics.setFont(f)
  setc(r or 1, g or 1, b or 1, a or 1, ca)
  local sc = 1
  if maxw then sc = math.min(1, maxw / math.max(1, f:getWidth(str))) end
  love.graphics.print(str, cx - f:getWidth(str) * sc / 2, cy - f:getHeight() * sc / 2, 0, sc, sc)
end

local function disc(cx, cy, r, ca, cr, cg, cb, a)
  setc(cr, cg, cb, a, ca)
  love.graphics.circle("fill", cx, cy, r, 40)
end

local function pill(x, y, w, h, ca, cr, cg, cb, a)
  setc(cr, cg, cb, a, ca)
  love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2)
end

local function area()
  local W, H, U = ctx.size()
  return W, H, U, 104 * U, H - 92 * U
end

local function mmss(t)
  t = math.max(0, math.floor(t))
  return string.format("%02d:%02d", math.floor(t / 60), t % 60)
end

local function hand(cx, cy, ang, len, w)
  love.graphics.setLineWidth(w)
  love.graphics.line(cx, cy, cx + math.sin(ang) * len, cy - math.cos(ang) * len)
end

-- auricular blanco centrado en (cx, cy); s = tamaño de la caja
local function handset(cx, cy, s, ca, rot)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(rot or 0)
  setc(1, 1, 1, 1, ca)
  love.graphics.setLineWidth(s * 0.15)
  love.graphics.arc("line", "open", s * 0.23, -s * 0.21, s * 0.36, math.rad(100), math.rad(170), 16)
  love.graphics.circle("fill", -s * 0.125, -s * 0.147, s * 0.105, 20)
  love.graphics.circle("fill", s * 0.168, s * 0.145, s * 0.105, 20)
  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

-- ============ iconos ============
-- radio de las esquinas de los íconos (lo elige el usuario en Ajustes > Personalización)
local function iconRadius()
  return (ctx and ctx.iconRadius and ctx.iconRadius()) or 0.22
end

local function iconBase(x, y, s, alpha, r, g, b)
  love.graphics.setColor(r, g, b, alpha)
  local rr = s * iconRadius()
  love.graphics.rectangle("fill", x, y, s, s, rr, rr)
end

local function iconPhone(x, y, s, alpha)
  iconBase(x, y, s, alpha, 0.20, 0.78, 0.35)
  local k = (iconRadius() > 0.45) and 0.84 or 1
  handset(x + s / 2, y + s / 2, s * 0.8 * k, alpha)
end

local function iconClock(x, y, s, alpha)
  iconBase(x, y, s, alpha, 0.08, 0.08, 0.10)
  local cx, cy, R = x + s / 2, y + s / 2, s * 0.38
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.circle("fill", cx, cy, R, 48)
  love.graphics.setColor(0.08, 0.08, 0.10, alpha)
  love.graphics.setLineWidth(math.max(1, s * 0.02))
  for i = 0, 11 do
    local a = i * math.pi / 6
    local l = (i % 3 == 0) and s * 0.08 or s * 0.04
    local sx, sy = math.sin(a), -math.cos(a)
    local r1 = R - s * 0.03
    love.graphics.line(cx + sx * r1, cy + sy * r1, cx + sx * (r1 - l), cy + sy * (r1 - l))
  end
  local t = os.date("*t")
  hand(cx, cy, ((t.hour % 12) + t.min / 60) / 12 * 2 * math.pi, R * 0.5, s * 0.035)
  hand(cx, cy, (t.min + t.sec / 60) / 60 * 2 * math.pi, R * 0.75, s * 0.028)
  love.graphics.setColor(1, 0.6, 0.1, alpha)
  hand(cx, cy, t.sec / 60 * 2 * math.pi, R * 0.82, s * 0.014)
  love.graphics.circle("fill", cx, cy, s * 0.03, 16)
  love.graphics.setLineWidth(1)
end

local function iconCalc(x, y, s, alpha)
  iconBase(x, y, s, alpha, 0.12, 0.12, 0.14)
  local k = (iconRadius() > 0.45) and 0.80 or 1
  love.graphics.push()
  love.graphics.translate(x + s / 2, y + s / 2)
  love.graphics.scale(k)
  love.graphics.translate(-(x + s / 2), -(y + s / 2))
  local m = s * 0.13
  love.graphics.setColor(0.30, 0.30, 0.34, alpha)
  love.graphics.rectangle("fill", x + m, y + s * 0.14, s - 2 * m, s * 0.16, s * 0.04, s * 0.04)
  local b, g = s * 0.15, s * 0.045
  for r = 0, 2 do
    for c = 0, 3 do
      if c == 3 then
        love.graphics.setColor(1, 0.6, 0.1, alpha)
      else
        love.graphics.setColor(0.35, 0.35, 0.39, alpha)
      end
      love.graphics.rectangle("fill", x + m + c * (b + g), y + s * 0.37 + r * (b + g), b, b, s * 0.04, s * 0.04)
    end
  end
  love.graphics.pop()
end

local ABBR = {"DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"}

local function iconCal(x, y, s, alpha)
  iconBase(x, y, s, alpha, 0.97, 0.97, 0.98)
  local t = os.date("*t")
  local f = fonts.label
  local sc1 = (s * 0.14) / f:getHeight()
  love.graphics.setFont(f)
  love.graphics.setColor(1, 0.27, 0.23, alpha)
  love.graphics.print(ABBR[t.wday], x + (s - f:getWidth(ABBR[t.wday]) * sc1) / 2, y + s * 0.12, 0, sc1, sc1)
  local f2 = fonts.title
  local num = tostring(t.day)
  local sc2 = (s * 0.46) / f2:getHeight()
  love.graphics.setFont(f2)
  love.graphics.setColor(0.08, 0.08, 0.10, alpha)
  love.graphics.print(num, x + (s - f2:getWidth(num) * sc2) / 2, y + s * 0.30, 0, sc2, sc2)
end

-- ============ TELÉFONO ============
local KEYS = {{"1", ""}, {"2", "ABC"}, {"3", "DEF"}, {"4", "GHI"}, {"5", "JKL"}, {"6", "MNO"},
              {"7", "PQRS"}, {"8", "TUV"}, {"9", "WXYZ"}, {"*", ""}, {"0", "+"}, {"#", ""}}
local ph = {num = "", calling = false, conn = false, t = 0}

local function phAct(n)
  if n:sub(1, 1) == "k" then
    if not ph.calling and #ph.num < 15 then
      ph.num = ph.num .. KEYS[tonumber(n:sub(2))][1]
      ctx.buzz(0.008)
    end
  elseif n == "bk" then
    ph.num = ph.num:sub(1, -2)
  elseif n == "call" then
    if ph.num ~= "" then
      ph.calling, ph.conn, ph.t = true, false, 0
      ctx.buzz(0.03)
    end
  elseif n == "end" then
    ph.calling, ph.conn = false, false
    ctx.buzz(0.03)
  end
end

local function drawPhone(ca)
  begin(phAct)
  local W, H, U, top, bot = area()
  local hh = bot - top
  ctext(fonts.clock, ph.num, W / 2, top + 36 * U, ca, 1, 1, 1, 1, W - 40 * U)

  local g = 14 * U
  local kd = math.min(72 * U, (hh - 100 * U - 4 * g) / 5, (W - 40 * U - 2 * g) / 3)
  local gx0 = (W - (3 * kd + 2 * g)) / 2
  local gy0 = top + 100 * U
  local callY = gy0 + 4 * (kd + g) + kd / 2

  if ph.calling then
    local status
    if ph.conn then
      status = mmss(ph.t)
    else
      status = "Llamando" .. string.rep(".", math.floor(love.timer.getTime() * 2) % 4)
    end
    ctext(fonts.hint, status, W / 2, top + 84 * U, ca, 1, 1, 1, 0.7)
    local cx, cy = W / 2, top + hh * 0.38
    disc(cx, cy, 46 * U, ca, 1, 1, 1, 0.14)
    disc(cx, cy - 10 * U, 16 * U, ca, 1, 1, 1, 0.55)
    setc(1, 1, 1, 0.55, ca)
    love.graphics.arc("fill", cx, cy + 34 * U, 30 * U, math.pi, 2 * math.pi)
    local ey = top + hh * 0.72
    disc(W / 2, ey, kd / 2, ca, 1, 0.23, 0.19, isHeld("end") and 0.7 or 1)
    handset(W / 2, ey, kd * 0.6, ca, math.rad(135))
    reg("end", W / 2 - kd / 2, ey - kd / 2, kd, kd)
    return
  end

  for i, k in ipairs(KEYS) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local cx = gx0 + col * (kd + g) + kd / 2
    local cy = gy0 + row * (kd + g) + kd / 2
    disc(cx, cy, kd / 2, ca, 1, 1, 1, isHeld("k" .. i) and 0.32 or 0.14)
    ctext(fonts.title, k[1], cx, cy - (k[2] ~= "" and 7 * U or 0), ca)
    if k[2] ~= "" then
      ctext(fonts.label, k[2], cx, cy + 12 * U, ca, 1, 1, 1, 0.6)
    end
    reg("k" .. i, cx - kd / 2, cy - kd / 2, kd, kd)
  end

  disc(W / 2, callY, kd / 2, ca, 0.20, 0.78, 0.35, isHeld("call") and 0.7 or 1)
  handset(W / 2, callY, kd * 0.6, ca)
  reg("call", W / 2 - kd / 2, callY - kd / 2, kd, kd)

  if ph.num ~= "" then
    local bx = gx0 + 2 * (kd + g) + kd / 2
    setc(1, 1, 1, isHeld("bk") and 0.6 or 0.9, ca)
    love.graphics.setLineWidth(2 * U)
    love.graphics.line(bx - 14 * U, callY, bx - 6 * U, callY - 9 * U, bx + 14 * U, callY - 9 * U,
      bx + 14 * U, callY + 9 * U, bx - 6 * U, callY + 9 * U, bx - 14 * U, callY)
    love.graphics.line(bx - 2 * U, callY - 4 * U, bx + 7 * U, callY + 4 * U)
    love.graphics.line(bx + 7 * U, callY - 4 * U, bx - 2 * U, callY + 4 * U)
    love.graphics.setLineWidth(1)
    reg("bk", bx - kd / 2, callY - kd / 2, kd, kd)
  end
end

local function phUpdate(dt)
  if ph.calling then
    ph.t = ph.t + dt
    if not ph.conn and ph.t > 2.5 then
      ph.conn, ph.t = true, 0
    end
  end
end

local function phText(t)
  if t:match("^[%d%*#%+]$") and not ph.calling and #ph.num < 15 then
    ph.num = ph.num .. t
  end
end

local function phKey(k)
  if k == "backspace" then
    ph.num = ph.num:sub(1, -2)
    return true
  end
  if k == "return" or k == "kpenter" then
    phAct(ph.calling and "end" or "call")
    return true
  end
  return false
end

-- ============ RELOJ ============
local ck = {tab = 1, swRun = false, swT0 = 0, swAcc = 0, laps = {}, lastLap = 0,
            tmLeft = 0, tmEnd = 0, tmRun = false, tmDone = false}

local function swElapsed()
  return ck.swAcc + (ck.swRun and (love.timer.getTime() - ck.swT0) or 0)
end

local function swStr(t)
  return string.format("%02d:%05.2f", math.floor(t / 60), t % 60)
end

local function ckAct(n)
  if n == "t1" or n == "t2" or n == "t3" then
    ck.tab = tonumber(n:sub(2))
  elseif n == "sw_s" then
    if ck.swRun then
      ck.swAcc = swElapsed()
      ck.swRun = false
    else
      ck.swT0 = love.timer.getTime()
      ck.swRun = true
    end
  elseif n == "sw_r" then
    if ck.swRun then
      local t = swElapsed()
      table.insert(ck.laps, 1, t - ck.lastLap)
      ck.lastLap = t
    else
      ck.swAcc, ck.lastLap, ck.laps = 0, 0, {}
    end
  elseif n == "p1" or n == "p5" or n == "p10" then
    local add = tonumber(n:sub(2)) * 60
    ck.tmLeft = ck.tmLeft + add
    if ck.tmRun then ck.tmEnd = ck.tmEnd + add end
    ck.tmDone = false
  elseif n == "tm_s" then
    if ck.tmRun then
      ck.tmRun = false
    elseif ck.tmLeft > 0 then
      ck.tmEnd = love.timer.getTime() + ck.tmLeft
      ck.tmRun = true
    end
  elseif n == "tm_r" then
    ck.tmRun, ck.tmLeft, ck.tmDone = false, 0, false
  end
  ctx.buzz(0.008)
end

local function drawClock(ca)
  begin(ckAct)
  local W, H, U, top, bot = area()

  local tw, names = (W - 40 * U) / 3, {"Reloj", "Cronómetro", "Timer"}
  pill(20 * U, top, W - 40 * U, 34 * U, ca, 1, 1, 1, 0.10)
  for i = 1, 3 do
    local x = 20 * U + (i - 1) * tw
    if ck.tab == i then
      pill(x + 2 * U, top + 2 * U, tw - 4 * U, 30 * U, ca, 1, 1, 1, 0.22)
    end
    ctext(fonts.label, names[i], x + tw / 2, top + 17 * U, ca, 1, 1, 1, ck.tab == i and 1 or 0.6)
    reg("t" .. i, x, top, tw, 34 * U)
  end
  local t2 = top + 54 * U

  if ck.tab == 1 then
    local R = math.min((W - 80 * U) / 2, (bot - t2 - 120 * U) / 2)
    local cx, cy = W / 2, t2 + R + 6 * U
    disc(cx, cy, R, ca, 1, 1, 1, 0.08)
    setc(1, 1, 1, 0.7, ca)
    love.graphics.setLineWidth(2 * U)
    for i = 0, 11 do
      local a = i * math.pi / 6
      local l = (i % 3 == 0) and 12 * U or 6 * U
      local sx, sy = math.sin(a), -math.cos(a)
      local r1 = R - 6 * U
      love.graphics.line(cx + sx * r1, cy + sy * r1, cx + sx * (r1 - l), cy + sy * (r1 - l))
    end
    local t = os.date("*t")
    setc(1, 1, 1, 1, ca)
    hand(cx, cy, ((t.hour % 12) + t.min / 60) / 12 * 2 * math.pi, R * 0.5, 5 * U)
    hand(cx, cy, (t.min + t.sec / 60) / 60 * 2 * math.pi, R * 0.75, 3.5 * U)
    setc(1, 0.6, 0.1, 1, ca)
    hand(cx, cy, t.sec / 60 * 2 * math.pi, R * 0.85, 1.5 * U)
    love.graphics.setLineWidth(1)
    disc(cx, cy, 5 * U, ca, 1, 0.6, 0.1, 1)
    ctext(fonts.clock, os.date("%H:%M:%S"), W / 2, cy + R + 44 * U, ca, 1, 1, 1, 1, W - 40 * U)
    ctext(fonts.date, string.format("%s %d de %s", DAYS[t.wday], t.day, MONTHS[t.month]),
      W / 2, cy + R + 80 * U, ca, 1, 1, 1, 0.6)

  elseif ck.tab == 2 then
    ctext(fonts.clock, swStr(swElapsed()), W / 2, t2 + 50 * U, ca, 1, 1, 1, 1, W - 40 * U)
    local by, bd = t2 + 170 * U, 76 * U
    local lx, rx = W * 0.3, W * 0.7
    disc(lx, by, bd / 2, ca, 1, 1, 1, isHeld("sw_r") and 0.35 or 0.18)
    ctext(fonts.hint, ck.swRun and "Vuelta" or "Reiniciar", lx, by, ca)
    reg("sw_r", lx - bd / 2, by - bd / 2, bd, bd)
    if ck.swRun then
      disc(rx, by, bd / 2, ca, 1, 0.23, 0.19, isHeld("sw_s") and 0.6 or 0.4)
      ctext(fonts.hint, "Detener", rx, by, ca, 1, 0.5, 0.45)
    else
      disc(rx, by, bd / 2, ca, 0.20, 0.78, 0.35, isHeld("sw_s") and 0.6 or 0.4)
      ctext(fonts.hint, "Iniciar", rx, by, ca, 0.55, 1, 0.65)
    end
    reg("sw_s", rx - bd / 2, by - bd / 2, bd, bd)

    local ly = by + bd / 2 + 24 * U
    for i, lt in ipairs(ck.laps) do
      if ly + 26 * U > bot then break end
      setc(1, 1, 1, 0.12, ca)
      love.graphics.rectangle("fill", 20 * U, ly, W - 40 * U, 1)
      love.graphics.setFont(fonts.hint)
      setc(1, 1, 1, 0.9, ca)
      love.graphics.print("Vuelta " .. (#ck.laps - i + 1), 24 * U, ly + 6 * U)
      love.graphics.printf(swStr(lt), 20 * U, ly + 6 * U, W - 48 * U, "right")
      ly = ly + 28 * U
    end

  else
    local done = ck.tmDone and (math.floor(love.timer.getTime() * 2) % 2 == 0)
    ctext(fonts.clock, mmss(math.ceil(ck.tmLeft)), W / 2, t2 + 50 * U, ca,
      1, done and 0.6 or 1, done and 0.1 or 1, 1, W - 40 * U)
    if ck.tmDone then
      ctext(fonts.hint, "¡Listo!", W / 2, t2 + 92 * U, ca, 1, 0.6, 0.1, 1)
    end
    local g = 10 * U
    local pw = (W - 40 * U - 2 * g) / 3
    local pn, pl = {"p1", "p5", "p10"}, {"+1 min", "+5 min", "+10 min"}
    for i = 1, 3 do
      local x = 20 * U + (i - 1) * (pw + g)
      pill(x, t2 + 110 * U, pw, 44 * U, ca, 1, 1, 1, isHeld(pn[i]) and 0.30 or 0.14)
      ctext(fonts.hint, pl[i], x + pw / 2, t2 + 132 * U, ca)
      reg(pn[i], x, t2 + 110 * U, pw, 44 * U)
    end
    local by, bd = t2 + 230 * U, 76 * U
    local lx, rx = W * 0.3, W * 0.7
    disc(lx, by, bd / 2, ca, 1, 1, 1, isHeld("tm_r") and 0.35 or 0.18)
    ctext(fonts.hint, "Borrar", lx, by, ca)
    reg("tm_r", lx - bd / 2, by - bd / 2, bd, bd)
    local can = ck.tmRun or ck.tmLeft > 0
    if ck.tmRun then
      disc(rx, by, bd / 2, ca, 1, 0.6, 0.1, isHeld("tm_s") and 0.6 or 0.4)
      ctext(fonts.hint, "Pausa", rx, by, ca, 1, 0.75, 0.4)
    else
      disc(rx, by, bd / 2, ca, 0.20, 0.78, 0.35, (can and (isHeld("tm_s") and 0.6 or 0.4)) or 0.12)
      ctext(fonts.hint, "Iniciar", rx, by, ca, 0.55, 1, 0.65, can and 1 or 0.4)
    end
    reg("tm_s", rx - bd / 2, by - bd / 2, bd, bd)
  end
end

local function ckUpdate(dt)
  if ck.tmRun then
    ck.tmLeft = ck.tmEnd - love.timer.getTime()
    if ck.tmLeft <= 0 then
      ck.tmLeft, ck.tmRun, ck.tmDone = 0, false, true
      ctx.buzz(0.5)
    end
  end
end

-- ============ CALCULADORA ============
local calc = {cur = "0", acc = nil, op = nil, fresh = false}
local OPS = {
  ["+"] = function(a, b) return a + b end,
  ["-"] = function(a, b) return a - b end,
  ["×"] = function(a, b) return a * b end,
  ["÷"] = function(a, b) return a / b end,
}
local CROWS = {
  {"AC", "±", "%", "÷"},
  {"7", "8", "9", "×"},
  {"4", "5", "6", "-"},
  {"1", "2", "3", "+"},
  {"0", ".", "="},
}

local function fmt(n)
  if n ~= n or n == math.huge or n == -math.huge then return "Error" end
  local s = string.format("%.10g", n)
  if s == "-0" then s = "0" end
  return s
end

local function calcNum()
  return tonumber(calc.cur) or 0
end

local function calcAct(n)
  local k = n:sub(2)
  local c = calc
  ctx.buzz(0.006)
  if c.cur == "Error" and k ~= "AC" then
    c.cur, c.acc, c.op, c.fresh = "0", nil, nil, false
  end
  if k:match("^%d$") then
    if c.fresh or c.cur == "0" then
      c.cur = k
    elseif #c.cur < 12 then
      c.cur = c.cur .. k
    end
    c.fresh = false
  elseif k == "." then
    if c.fresh then
      c.cur = "0."
    elseif not c.cur:find(".", 1, true) then
      c.cur = c.cur .. "."
    end
    c.fresh = false
  elseif k == "AC" then
    c.cur, c.acc, c.op, c.fresh = "0", nil, nil, false
  elseif k == "±" then
    c.cur = fmt(-calcNum())
  elseif k == "%" then
    c.cur = fmt(calcNum() / 100)
    c.fresh = true
  elseif OPS[k] then
    if c.op and not c.fresh then
      c.acc = OPS[c.op](c.acc, calcNum())
      c.cur = fmt(c.acc)
      if c.cur == "Error" then
        c.op, c.acc, c.fresh = nil, nil, true
        return
      end
    else
      c.acc = calcNum()
    end
    c.op, c.fresh = k, true
  elseif k == "=" then
    if c.op then
      c.cur = fmt(OPS[c.op](c.acc, calcNum()))
      c.acc, c.op, c.fresh = nil, nil, true
    end
  end
end

local function drawCalc(ca)
  begin(calcAct)
  local W, H, U, top, bot = area()
  local hh = bot - top

  local f = fonts.lockClock
  local txt = calc.cur
  local sc = math.min(1, (W - 40 * U) / math.max(1, f:getWidth(txt)))
  love.graphics.setFont(f)
  setc(1, 1, 1, 1, ca)
  love.graphics.print(txt, W - 20 * U - f:getWidth(txt) * sc, top + 100 * U - f:getHeight() * sc, 0, sc, sc)

  local g = 12 * U
  local ks = math.min((W - 40 * U - 3 * g) / 4, (hh - 120 * U - 4 * g) / 5)
  local x0 = (W - (4 * ks + 3 * g)) / 2
  local y0 = top + 120 * U

  for r, row in ipairs(CROWS) do
    for c, label in ipairs(row) do
      local col = c
      if r == 5 and c > 1 then col = c + 1 end
      local x = x0 + (col - 1) * (ks + g)
      local y = y0 + (r - 1) * (ks + g)
      local w = (label == "0") and (2 * ks + g) or ks
      local held_ = isHeld("c" .. label)
      local tr, tg, tb = 1, 1, 1
      if OPS[label] or label == "=" then
        if calc.op == label and calc.fresh then
          setc(1, 1, 1, 1, ca)
          tr, tg, tb = 1, 0.6, 0.1
        else
          setc(1, 0.6, 0.1, held_ and 0.7 or 1, ca)
        end
      elseif label == "AC" or label == "±" or label == "%" then
        setc(1, 1, 1, held_ and 0.50 or 0.30, ca)
      else
        setc(1, 1, 1, held_ and 0.30 or 0.14, ca)
      end
      love.graphics.rectangle("fill", x, y, w, ks, ks / 2, ks / 2)
      ctext(fonts.title, label, x + w / 2, y + ks / 2, ca, tr, tg, tb, 1)
      reg("c" .. label, x, y, w, ks)
    end
  end
end

local function calcText(t)
  local map = {["*"] = "×", ["/"] = "÷", [","] = "."}
  local k = map[t] or t
  if k:match("^%d$") or k == "." or k == "+" or k == "-" or k == "×" or k == "÷" or k == "=" or k == "%" then
    calcAct("c" .. k)
  end
end

local function calcKey(k)
  if k == "backspace" then
    if calc.fresh or calc.cur == "Error" then
      calc.cur, calc.fresh = "0", false
    else
      local s = calc.cur:sub(1, -2)
      if s == "" or s == "-" then s = "0" end
      calc.cur = s
    end
    return true
  end
  if k == "return" or k == "kpenter" then
    calcAct("c=")
    return true
  end
  return false
end

-- ============ CALENDARIO ============
local today0 = os.date("*t")
local cal = {y = today0.year, m = today0.month,
             sel = {y = today0.year, m = today0.month, d = today0.day}}

local function calAct(n)
  if n == "prev" then
    cal.m = cal.m - 1
    if cal.m < 1 then
      cal.m = 12
      cal.y = cal.y - 1
    end
  elseif n == "next" then
    cal.m = cal.m + 1
    if cal.m > 12 then
      cal.m = 1
      cal.y = cal.y + 1
    end
  elseif n == "today" then
    local t = os.date("*t")
    cal.y, cal.m = t.year, t.month
    cal.sel = {y = t.year, m = t.month, d = t.day}
  else
    local d = n:match("^d(%d+)$")
    if d then cal.sel = {y = cal.y, m = cal.m, d = tonumber(d)} end
  end
  ctx.buzz(0.006)
end

local function drawCal(ca)
  begin(calAct)
  local W, H, U, top, bot = area()
  local t = os.date("*t")

  local mname = MONTHS[cal.m]
  mname = mname:sub(1, 1):upper() .. mname:sub(2)
  ctext(fonts.dTitle, mname .. " " .. cal.y, W / 2, top + 14 * U, ca, 1, 1, 1, 1)

  setc(1, 0.35, 0.30, 1, ca)
  love.graphics.setLineWidth(2.5 * U)
  love.graphics.line(34 * U, top + 6 * U, 26 * U, top + 14 * U, 34 * U, top + 22 * U)
  love.graphics.line(W - 34 * U, top + 6 * U, W - 26 * U, top + 14 * U, W - 34 * U, top + 22 * U)
  love.graphics.setLineWidth(1)
  reg("prev", 10 * U, top - 6 * U, 60 * U, 40 * U)
  reg("next", W - 70 * U, top - 6 * U, 60 * U, 40 * U)

  local cw = (W - 40 * U) / 7
  local wn = {"L", "M", "M", "J", "V", "S", "D"}
  for i = 1, 7 do
    ctext(fonts.label, wn[i], 20 * U + (i - 0.5) * cw, top + 50 * U, ca, 1, 1, 1, i > 5 and 0.30 or 0.55)
  end

  local first = os.date("*t", os.time{year = cal.y, month = cal.m, day = 1, hour = 12}).wday
  local off = (first + 5) % 7
  local dim = os.date("*t", os.time{year = cal.y, month = cal.m + 1, day = 0, hour = 12}).day
  local gy = top + 66 * U
  local ch = math.min(cw * 1.1, (bot - gy - 80 * U) / 6)
  local rad = math.min(cw, ch) * 0.42

  for d = 1, dim do
    local idx = off + d - 1
    local cx = 20 * U + (idx % 7) * cw + cw / 2
    local cy = gy + math.floor(idx / 7) * ch + ch / 2
    local isToday = (cal.y == t.year and cal.m == t.month and d == t.day)
    local isSel = (cal.sel.y == cal.y and cal.sel.m == cal.m and cal.sel.d == d)
    local tr, tg, tb = 1, 1, 1
    if isToday then
      disc(cx, cy, rad, ca, 1, 0.27, 0.23, 1)
    elseif isSel then
      disc(cx, cy, rad, ca, 1, 1, 1, 0.9)
      tr, tg, tb = 0.08, 0.08, 0.10
    end
    if isToday and isSel then
      setc(1, 1, 1, 1, ca)
      love.graphics.setLineWidth(2 * U)
      love.graphics.circle("line", cx, cy, rad + 2 * U, 40)
      love.graphics.setLineWidth(1)
    end
    ctext(fonts.hint, tostring(d), cx, cy, ca, tr, tg, tb, 0.95)
    reg("d" .. d, cx - cw / 2, cy - ch / 2, cw, ch)
  end

  local s = cal.sel
  local wd = os.date("*t", os.time{year = s.y, month = s.m, day = s.d, hour = 12}).wday
  local cy = bot - 34 * U
  setc(1, 1, 1, 0.08, ca)
  love.graphics.rectangle("fill", 20 * U, cy - 30 * U, W - 40 * U, 60 * U, 16 * U, 16 * U)
  love.graphics.setFont(fonts.hint)
  setc(1, 1, 1, 0.95, ca)
  love.graphics.print(DAYS[wd], 36 * U, cy - 20 * U)
  love.graphics.setFont(fonts.label)
  setc(1, 1, 1, 0.6, ca)
  love.graphics.print(s.d .. " de " .. MONTHS[s.m] .. " de " .. s.y, 36 * U, cy + 2 * U)
  pill(W - 96 * U, cy - 14 * U, 66 * U, 28 * U, ca, 1, 0.27, 0.23, isHeld("today") and 0.6 or 0.35)
  ctext(fonts.label, "Hoy", W - 63 * U, cy, ca, 1, 0.6, 0.55, 1)
  reg("today", W - 96 * U, cy - 14 * U, 66 * U, 28 * U)
end

-- ============ RENDIMIENTO ============
local PERF_N = 90
local perf = {hist = {}, idx = 0, n = 0, t0 = 0}

local function perfUpdate(dt)
  perf.idx = perf.idx % PERF_N + 1
  perf.hist[perf.idx] = love.timer.getDelta() * 1000
  if perf.n < PERF_N then perf.n = perf.n + 1 end
end

local function perfStats()
  if perf.n == 0 then return 16.7, 16.7 end
  local sum, mx = 0, 0
  for i = 1, perf.n do
    local v = perf.hist[i] or 0
    sum = sum + v
    if v > mx then mx = v end
  end
  return sum / perf.n, mx
end

local function perfColor(avg)
  if avg <= 18.5 then return 0.30, 0.85, 0.45 end
  if avg <= 34 then return 1.0, 0.75, 0.20 end
  return 1.0, 0.35, 0.30
end

-- mismo trazo para el ícono de la app y para el aviso de la isla (u = mitad del tamaño)
local function perfGlyph(cx, cy, u, a, r, g, b)
  love.graphics.setColor(r or 0.30, g or 0.90, b or 0.50, a)
  love.graphics.setLineWidth(u * 0.22)
  love.graphics.setLineJoin("bevel")
  love.graphics.line(
    cx - u,        cy + u * 0.15,
    cx - u * 0.45, cy + u * 0.15,
    cx - u * 0.15, cy - u * 0.75,
    cx + u * 0.25, cy + u * 0.70,
    cx + u * 0.55, cy - u * 0.20,
    cx + u * 0.70, cy + u * 0.05,
    cx + u,        cy + u * 0.05)
  love.graphics.setLineJoin("miter")
  love.graphics.setLineWidth(1)
end

local function iconPerf(x, y, s, alpha)
  iconBase(x, y, s, alpha, 0.07, 0.14, 0.17)
  perfGlyph(x + s / 2, y + s / 2, s * 0.34, alpha)
end

local function hms(t)
  t = math.max(0, math.floor(t))
  local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%02d:%02d", m, s)
end

local POWER = {charging = "cargando", charged = "cargada", battery = "con batería"}

local function perfRows(avg, mx)
  local _, _, U = ctx.size()
  local rows = {}
  rows[#rows + 1] = {"Tiempo de frame", string.format("%.1f ms · máx %.0f", avg, mx)}
  rows[#rows + 1] = {"Memoria Lua", string.format("%.1f MB", collectgarbage("count") / 1024)}

  local okp, pw, ph = pcall(love.graphics.getPixelDimensions)
  rows[#rows + 1] = {"Resolución", okp and (pw .. " × " .. ph .. " px") or "?"}

  local okd, dpi = pcall(love.window.getDPIScale)
  rows[#rows + 1] = {"Densidad", string.format("%.2f× · U = %.2f", okd and dpi or 1, U)}

  local okr, _, _, _, dev = pcall(love.graphics.getRendererInfo)
  rows[#rows + 1] = {"GPU", (okr and dev) or "?"}

  local okb, st, pct = pcall(love.system.getPowerInfo)
  local bs = "—"
  if okb and pct then
    bs = pct .. "%" .. (POWER[st] and (" · " .. POWER[st]) or "")
  elseif okb and st == "nobattery" then
    bs = "sin batería"
  end
  rows[#rows + 1] = {"Batería", bs}

  rows[#rows + 1] = {"Tiempo activo", hms(love.timer.getTime() - perf.t0)}

  local ma, mi, rev = love.getVersion()
  rows[#rows + 1] = {"LÖVE", string.format("%d.%d.%d", ma, mi, rev)}
  return rows
end

local function perfAct(n)
  if n == "gc" then
    ctx.buzz(0.008)
    local before = collectgarbage("count") / 1024
    collectgarbage("collect")
    collectgarbage("collect")
    local after = collectgarbage("count") / 1024
    if ctx.notify then
      ctx.notify({
        iconfn = function(cx, cy, u, a) perfGlyph(cx, cy, u, a) end,
        name = "Memoria liberada",
        sub = string.format("%.1f → %.1f MB", before, after),
        dot = {0.30, 0.85, 0.45},
        dur = 2.2,
      })
    end
  end
end

local function drawPerf(ca)
  begin(perfAct)
  local W, H, U, top, bot = area()
  local avg, mx = perfStats()
  local cr, cg, cb = perfColor(avg)

  -- FPS grande
  ctext(fonts.clock, tostring(love.timer.getFPS()), W / 2, top + 34 * U, ca, cr, cg, cb, 1)
  ctext(fonts.label, "FPS", W / 2, top + 76 * U, ca, 1, 1, 1, 0.55)

  -- gráfica de tiempo por frame
  local gx, gy, gw, gh = 20 * U, top + 96 * U, W - 40 * U, 104 * U
  setc(1, 1, 1, 0.07, ca)
  love.graphics.rectangle("fill", gx, gy, gw, gh, 16 * U, 16 * U)

  local pad = 10 * U
  local px0, py0, pw, ph = gx + pad, gy + pad, gw - 2 * pad, gh - 2 * pad
  local MAXMS = 50
  local function yOf(ms) return py0 + ph - math.min(ms, MAXMS) / MAXMS * ph end

  love.graphics.setFont(fonts.label)
  for _, ref in ipairs({{16.7, "60"}, {33.3, "30"}}) do
    local y = yOf(ref[1])
    setc(1, 1, 1, 0.15, ca)
    love.graphics.rectangle("fill", px0, y, pw, 1)
    setc(1, 1, 1, 0.40, ca)
    love.graphics.print(ref[2], px0 + pw - fonts.label:getWidth(ref[2]), y - fonts.label:getHeight() - 1 * U)
  end

  if perf.n >= 2 then
    local pts = {}
    for k = 1, perf.n do
      local i = (perf.idx - perf.n + k - 1) % PERF_N + 1
      pts[#pts + 1] = px0 + (k - 1) / (PERF_N - 1) * pw
      pts[#pts + 1] = yOf(perf.hist[i] or 0)
    end
    setc(cr, cg, cb, 1, ca)
    love.graphics.setLineWidth(2 * U)
    love.graphics.setLineJoin("bevel")
    love.graphics.line(pts)
    love.graphics.setLineJoin("miter")
    love.graphics.setLineWidth(1)
  end

  -- datos del sistema
  local rows = perfRows(avg, mx)
  local ry0 = gy + gh + 14 * U
  local rh = math.max(18 * U, math.min(34 * U, (bot - ry0 - 56 * U) / #rows))
  local cardH = rh * #rows
  setc(1, 1, 1, 0.07, ca)
  love.graphics.rectangle("fill", gx, ry0, gw, cardH, 16 * U, 16 * U)

  love.graphics.setFont(fonts.hint)
  local fh = fonts.hint:getHeight()
  for i, r in ipairs(rows) do
    local cy = ry0 + (i - 0.5) * rh
    setc(1, 1, 1, 0.60, ca)
    love.graphics.print(r[1], gx + 16 * U, cy - fh / 2)
    local vw = fonts.hint:getWidth(r[2])
    local maxw = gw - 32 * U - fonts.hint:getWidth(r[1]) - 12 * U
    local sc = math.min(1, maxw / math.max(1, vw))
    setc(1, 1, 1, 0.95, ca)
    love.graphics.print(r[2], gx + gw - 16 * U - vw * sc, cy - fh * sc / 2, 0, sc, sc)
    if i < #rows then
      setc(1, 1, 1, 0.08, ca)
      love.graphics.rectangle("fill", gx + 16 * U, ry0 + i * rh, gw - 32 * U, 1)
    end
  end

  -- botón
  local bw, bh = 200 * U, 40 * U
  local bx, by = (W - bw) / 2, ry0 + cardH + 14 * U
  pill(bx, by, bw, bh, ca, 0.30, 0.85, 0.45, isHeld("gc") and 0.50 or 0.28)
  ctext(fonts.hint, "Liberar memoria", W / 2, by + bh / 2, ca, 0.65, 1, 0.75, 1)
  reg("gc", bx, by, bw, bh)
end

-- ============ utilidades extra (Notas y 2048) ============
local okU, utf8 = pcall(require, "utf8")

local function mix(a, b, t) return a + (b - a) * t end
local function clampn(v, a, b) return math.max(a, math.min(b, v)) end

local function curU()
  local _, _, u = ctx.size()
  return u
end

-- texto alineado a la izquierda, centrado en vertical sobre cy
local function ltext(f, str, x, cy, ca, r, g, b, a, maxw)
  love.graphics.setFont(f)
  setc(r or 1, g or 1, b or 1, a or 1, ca)
  local sc = 1
  if maxw then sc = math.min(1, maxw / math.max(1, f:getWidth(str))) end
  love.graphics.print(str, x, cy - f:getHeight() * sc / 2, 0, sc, sc)
end

local function trashIcon(cx, cy, s, ca, r, g, b)
  setc(r or 1, g or 0.35, b or 0.30, 1, ca)
  love.graphics.setLineWidth(math.max(1, s * 0.1))
  love.graphics.line(cx - s * 0.5, cy - s * 0.35, cx + s * 0.5, cy - s * 0.35)
  love.graphics.line(cx - s * 0.18, cy - s * 0.35, cx - s * 0.18, cy - s * 0.5,
    cx + s * 0.18, cy - s * 0.5, cx + s * 0.18, cy - s * 0.35)
  love.graphics.line(cx - s * 0.38, cy - s * 0.2, cx - s * 0.3, cy + s * 0.5,
    cx + s * 0.3, cy + s * 0.5, cx + s * 0.38, cy - s * 0.2)
  love.graphics.line(cx - s * 0.1, cy - s * 0.05, cx - s * 0.1, cy + s * 0.35)
  love.graphics.line(cx + s * 0.1, cy - s * 0.05, cx + s * 0.1, cy + s * 0.35)
  love.graphics.setLineWidth(1)
end

-- ============ NOTAS ============
local NOTES_FILE = "notes.dat"
local notesApp
local nt = {list = {}, sel = nil, scroll = 0, maxScroll = 0, eoff = 0, maxOff = 0,
            lh = 20, dirty = false, saveT = 0, drag = nil}

local function noteEsc(s)
  return (s:gsub("\\", "\\\\"):gsub("\n", "\\n"))
end

local function noteUnesc(s)
  return (s:gsub("\\(.)", function(c)
    if c == "n" then return "\n" end
    return c
  end))
end

local function notesSave()
  local out = {}
  for _, n in ipairs(nt.list) do
    out[#out + 1] = n.t .. "|" .. noteEsc(n.text)
  end
  pcall(love.filesystem.write, NOTES_FILE, table.concat(out, "\n"))
  nt.dirty = false
  nt.saveT = 0
end

local function notesLoad()
  nt.list = {}
  local seeded = false
  if love.filesystem.getInfo(NOTES_FILE) then
    local ok, str = pcall(love.filesystem.read, NOTES_FILE)
    if ok and str then
      for line in (str .. "\n"):gmatch("(.-)\n") do
        local t, body = line:match("^(%d+)|(.*)$")
        if t then nt.list[#nt.list + 1] = {t = tonumber(t), text = noteUnesc(body)} end
      end
      seeded = true
    end
  end
  if not seeded then
    nt.list[1] = {t = os.time(), text = "Bienvenido a Notas\nTocá + para crear una nota nueva y el tacho para borrarla."}
    notesSave()
  end
end

local function nDate(ts)
  local now, d = os.date("*t"), os.date("*t", ts)
  if d.year == now.year and d.month == now.month and d.day == now.day then
    return os.date("%H:%M", ts)
  end
  return os.date("%d/%m/%y", ts)
end

local function nLines(text, f, w)
  local lines = {}
  for par in (text .. "\n"):gmatch("(.-)\n") do
    if par == "" then
      lines[#lines + 1] = ""
    else
      local _, wl = f:getWrap(par, w)
      if #wl == 0 then
        lines[#lines + 1] = ""
      else
        for _, l in ipairs(wl) do lines[#lines + 1] = l end
      end
    end
  end
  return lines
end

local function nTitleOf(n)
  local first, second
  for line in (n.text .. "\n"):gmatch("(.-)\n") do
    if not line:match("^%s*$") then
      if not first then
        first = line
      elseif not second then
        second = line
        break
      end
    end
  end
  return first, second
end

local function nStartEdit(i)
  nt.sel = i
  nt.eoff = 0
  pcall(love.keyboard.setKeyRepeat, true)
  pcall(love.keyboard.setTextInput, true)
end

local function nStopEdit()
  if not nt.sel then return end
  local n = nt.list[nt.sel]
  if n and n.text:match("^%s*$") then
    table.remove(nt.list, nt.sel)
    nt.dirty = true
  elseif n and n.mod then
    n.mod = nil
    table.remove(nt.list, nt.sel)
    table.insert(nt.list, 1, n)
    nt.dirty = true
  end
  nt.sel = nil
  nt.scroll = 0
  pcall(love.keyboard.setTextInput, false)
  pcall(love.keyboard.setKeyRepeat, false)
  notesSave()
end

local function nAct(name)
  ctx.buzz(0.006)
  if name == "new" then
    table.insert(nt.list, 1, {t = os.time(), text = ""})
    nt.dirty = true
    nStartEdit(1)
  elseif name == "back" then
    nStopEdit()
  elseif name == "kb" then
    pcall(love.keyboard.setTextInput, true)
  elseif name == "trash" then
    if nt.sel then
      table.remove(nt.list, nt.sel)
      nt.sel = nil
      nt.scroll = 0
      pcall(love.keyboard.setTextInput, false)
      pcall(love.keyboard.setKeyRepeat, false)
      notesSave()
      if ctx.notify then
        ctx.notify({
          iconfn = function(cx, cy, u, a) trashIcon(cx, cy, u * 1.9, a, 1, 0.45, 0.40) end,
          name = "Nota eliminada",
          sub = #nt.list .. (#nt.list == 1 and " nota" or " notas"),
          dot = {1, 0.35, 0.30},
          dur = 1.8,
        })
      end
    end
  else
    local i = name:match("^n(%d+)$")
    if i and nt.list[tonumber(i)] then nStartEdit(tonumber(i)) end
  end
end

local function nText(t)
  if not nt.sel then return end
  local n = nt.list[nt.sel]
  if not n then return end
  t = (t:gsub("%c", ""))
  if t == "" or #n.text > 20000 then return end
  n.text = n.text .. t
  n.t = os.time()
  n.mod = true
  nt.dirty, nt.saveT, nt.eoff = true, 0, 0
end

local function nKey(k)
  if not nt.sel then return false end
  local n = nt.list[nt.sel]
  if not n then return false end
  if k == "backspace" then
    local s = n.text
    if s ~= "" then
      local ok, off = false, nil
      if okU then ok, off = pcall(utf8.offset, s, -1) end
      n.text = (ok and off) and s:sub(1, off - 1) or s:sub(1, -2)
      n.t = os.time()
      n.mod = true
      nt.dirty, nt.saveT, nt.eoff = true, 0, 0
    end
    return true
  elseif k == "return" or k == "kpenter" then
    if #n.text <= 20000 then
      n.text = n.text .. "\n"
      n.t = os.time()
      n.mod = true
      nt.dirty, nt.saveT, nt.eoff = true, 0, 0
    end
    return true
  elseif k == "escape" then
    nStopEdit()
    return true
  end
  return false
end

local function nUpdate(dt)
  if nt.dirty then
    nt.saveT = nt.saveT + dt
    if nt.saveT > 1.5 then notesSave() end
  end
  -- si la app se cerró con el gesto, soltar teclado y guardar
  if nt.sel and ctx.current and ctx.current() ~= notesApp then nStopEdit() end
end

local function nPress(id, x, y)
  held = nil
  local r = regAt(x, y)
  nt.drag = {id = id, sy = y, s0 = nt.scroll, e0 = nt.eoff, moved = 0}
  if r then held = {id = id, n = r.n} end
end

local function nMove(id, x, y)
  local d = nt.drag
  if not d or d.id ~= id then return false end
  local U = curU()
  d.moved = math.max(d.moved, math.abs(y - d.sy))
  if d.moved > 8 * U then
    held = nil
    if nt.sel then
      nt.eoff = clampn(math.floor(d.e0 + (y - d.sy) / math.max(1, nt.lh) + 0.5), 0, nt.maxOff)
    else
      nt.scroll = clampn(d.s0 + (d.sy - y), 0, nt.maxScroll)
    end
  end
  return true
end

local function nRelease(id, x, y)
  local d = nt.drag
  if not d or d.id ~= id then return false end
  nt.drag = nil
  local U = curU()
  local name = held and held.n
  held = nil
  if d.moved < 10 * U and name then
    local r = regAt(x, y)
    if r and r.n == name then nAct(name) end
  end
  return true
end

-- contorno de un rectángulo redondeado como lista de puntos
local function rrPoints(x, y, w, h, r, seg)
  r = math.min(r, w / 2, h / 2)
  local pts = {}
  local function arc(cx, cy, a0)
    for i = 0, seg do
      local a = a0 + (math.pi / 2) * i / seg
      pts[#pts + 1] = {cx + math.cos(a) * r, cy + math.sin(a) * r}
    end
  end
  arc(x + w - r, y + r, -math.pi / 2)
  arc(x + w - r, y + h - r, 0)
  arc(x + r, y + h - r, math.pi / 2)
  arc(x + r, y + r, math.pi)
  return pts
end

-- se queda con la parte del polígono que está por debajo de la línea yc
local function clipBelow(pts, yc)
  local out, n = {}, #pts
  for i = 1, n do
    local a, b = pts[i], pts[i % n + 1]
    local ain, bin = a[2] >= yc, b[2] >= yc
    if ain then out[#out + 1] = a end
    if ain ~= bin then
      local t = (yc - a[2]) / (b[2] - a[2])
      out[#out + 1] = {a[1] + (b[1] - a[1]) * t, yc}
    end
  end
  return out
end

local function iconNotes(x, y, s, alpha)
  local r = s * iconRadius()
  setc(1.0, 0.80, 0.15, 1, alpha)
  love.graphics.rectangle("fill", x, y, s, s, r, r)
  setc(0.99, 0.97, 0.90, 1, alpha)
  local pts = clipBelow(rrPoints(x, y, s, s, r, 8), y + s * 0.28)
  if #pts >= 3 then
    local flat = {}
    for _, p in ipairs(pts) do
      flat[#flat + 1] = p[1]
      flat[#flat + 1] = p[2]
    end
    love.graphics.polygon("fill", flat)
  end
  setc(0.80, 0.76, 0.62, 1, alpha)
  for i = 1, 3 do
    love.graphics.rectangle("fill", x + s * 0.2, y + s * 0.28 + i * s * 0.17, s * 0.6, math.max(1, s * 0.025))
  end
end

local function drawNoteEdit(ca)
  local W, H, U, top, bot = area()
  local n = nt.list[nt.sel]
  if not n then
    nt.sel = nil
    return
  end

  -- barra superior
  local ty = top + 14 * U
  setc(1.0, 0.80, 0.15, 1, ca)
  love.graphics.setLineWidth(2.5 * U)
  love.graphics.line(28 * U, ty - 8 * U, 20 * U, ty, 28 * U, ty + 8 * U)
  love.graphics.setLineWidth(1)
  ltext(fonts.dTitle, "Todas", 36 * U, ty, ca, 1.0, 0.80, 0.15, 1)
  reg("back", 10 * U, top - 6 * U, 110 * U, 40 * U)
  ctext(fonts.label, nDate(n.t), W / 2, ty, ca, 1, 1, 1, 0.45)
  trashIcon(W - 34 * U, ty, 20 * U, ca)
  reg("trash", W - 70 * U, top - 6 * U, 60 * U, 40 * U)
  setc(1, 1, 1, 0.10, ca)
  love.graphics.rectangle("fill", 20 * U, ty + 22 * U, W - 40 * U, 1)

  -- área de texto (en celular se deja lugar al teclado)
  local f = fonts.dTitle
  local lh = f:getHeight() * 1.2
  nt.lh = lh
  local sys = love.system.getOS()
  local mobile = (sys == "Android" or sys == "iOS")
  local vtop = top + 44 * U
  local vbot = mobile and (H * 0.56) or bot
  if vbot - vtop < 4 * lh then vbot = vtop + 4 * lh end
  local tx, tw = 20 * U, W - 40 * U
  reg("kb", tx, vtop, tw, vbot - vtop)

  local lines = nLines(n.text, f, tw)
  local total = #lines
  local maxVis = math.max(1, math.floor((vbot - vtop) / lh))
  nt.maxOff = math.max(0, total - maxVis)
  nt.eoff = clampn(nt.eoff, 0, nt.maxOff)
  local first = math.max(1, total - maxVis + 1 - nt.eoff)
  local last = math.min(total, first + maxVis - 1)

  love.graphics.setFont(f)
  if n.text == "" then
    setc(1, 1, 1, 0.30, ca)
    love.graphics.print("Escribí algo…", tx, vtop)
  end
  setc(1, 1, 1, 0.95, ca)
  for i = first, last do
    love.graphics.print(lines[i], tx, vtop + (i - first) * lh)
  end

  -- cursor al final del texto
  if nt.eoff == 0 and math.floor(love.timer.getTime() * 2) % 2 == 0 then
    local row = last - first
    local cx = tx + f:getWidth(lines[last] or "")
    setc(1.0, 0.80, 0.15, 1, ca)
    love.graphics.rectangle("fill", cx + 1 * U, vtop + row * lh + lh * 0.12, 2 * U, lh * 0.76)
  end
end

local function drawNoteList(ca)
  local W, H, U, top, bot = area()
  local cardH, gap = 66 * U, 8 * U
  local list = nt.list
  local total = #list * (cardH + gap)
  local vh = bot - top - 8 * U
  nt.maxScroll = math.max(0, total - vh)
  nt.scroll = clampn(nt.scroll, 0, nt.maxScroll)

  if #list == 0 then
    ctext(fonts.hint, "No hay notas", W / 2, top + 110 * U, ca, 1, 1, 1, 0.7)
    ctext(fonts.label, "Tocá + para crear una", W / 2, top + 134 * U, ca, 1, 1, 1, 0.4)
  end

  for i, n in ipairs(list) do
    local y = top + (i - 1) * (cardH + gap) - nt.scroll
    if y + cardH > top and y < bot - 4 * U then
      local fa = clampn((y + cardH - top) / cardH, 0, 1) * clampn((bot - 4 * U - y) / cardH, 0, 1)
      local a = ca * fa
      local held_ = isHeld("n" .. i)
      setc(1, 1, 1, held_ and 0.16 or 0.08, a)
      love.graphics.rectangle("fill", 20 * U, y, W - 40 * U, cardH, 16 * U, 16 * U)
      local t1, t2 = nTitleOf(n)
      local dstr = nDate(n.t)
      love.graphics.setFont(fonts.label)
      local dw = fonts.label:getWidth(dstr)
      ltext(fonts.hint, t1 or "Nueva nota", 36 * U, y + 22 * U, a, 1, 1, 1, t1 and 0.95 or 0.4, W - 72 * U - dw - 8 * U)
      ltext(fonts.label, t2 or "Sin texto adicional", 36 * U, y + 44 * U, a, 1, 1, 1, 0.5, W - 72 * U)
      ltext(fonts.label, dstr, W - 36 * U - dw, y + 22 * U, a, 1, 1, 1, 0.45)
      local ry0, ry1 = math.max(y, top), math.min(y + cardH, bot - 4 * U)
      if ry1 > ry0 then reg("n" .. i, 20 * U, ry0, W - 40 * U, ry1 - ry0) end
    end
  end

  -- botón +
  local cx, cy, r = W - 50 * U, bot - 34 * U, 26 * U
  disc(cx, cy, r, ca, 1.0, 0.80, 0.15, isHeld("new") and 0.75 or 1)
  setc(0.15, 0.12, 0.02, 1, ca)
  love.graphics.rectangle("fill", cx - 10 * U, cy - 1.5 * U, 20 * U, 3 * U, 1.5 * U, 1.5 * U)
  love.graphics.rectangle("fill", cx - 1.5 * U, cy - 10 * U, 3 * U, 20 * U, 1.5 * U, 1.5 * U)
  reg("new", cx - r, cy - r, 2 * r, 2 * r)
end

local function drawNotes(ca)
  begin(nAct)
  if nt.sel then
    drawNoteEdit(ca)
  else
    drawNoteList(ca)
  end
end

-- ============ 2048 ============
local G2_FILE = "g2048.txt"
local g2 = {b = {}, score = 0, best = 0, over = false, won = false, anim = nil, pops = {}, sw = nil}

local G2COL = {
  [2] = {0.93, 0.89, 0.85}, [4] = {0.93, 0.88, 0.78}, [8] = {0.95, 0.69, 0.47},
  [16] = {0.96, 0.58, 0.39}, [32] = {0.96, 0.49, 0.37}, [64] = {0.96, 0.37, 0.23},
  [128] = {0.93, 0.81, 0.45}, [256] = {0.93, 0.80, 0.38}, [512] = {0.93, 0.78, 0.31},
  [1024] = {0.93, 0.77, 0.25}, [2048] = {0.93, 0.76, 0.18},
}

local function g2SaveBest()
  pcall(love.filesystem.write, G2_FILE, "best=" .. g2.best)
end

local function g2LoadBest()
  g2.best = 0
  if love.filesystem.getInfo(G2_FILE) then
    local ok, str = pcall(love.filesystem.read, G2_FILE)
    local v = ok and str and str:match("best=(%d+)")
    g2.best = tonumber(v) or 0
  end
end

local function g2Spawn()
  local empt = {}
  for r = 1, 4 do
    for c = 1, 4 do
      if g2.b[r][c] == 0 then empt[#empt + 1] = {r, c} end
    end
  end
  if #empt == 0 then return nil end
  local e = empt[love.math.random(#empt)]
  g2.b[e[1]][e[2]] = (love.math.random() < 0.9) and 2 or 4
  return e
end

local function g2New()
  g2.b = {}
  for r = 1, 4 do g2.b[r] = {0, 0, 0, 0} end
  g2.score, g2.over, g2.won, g2.anim = 0, false, false, nil
  g2.pops = {}
  for _ = 1, 2 do
    local e = g2Spawn()
    if e then g2.pops[#g2.pops + 1] = {r = e[1], c = e[2], t = 0, kind = "spawn"} end
  end
end

local function g2CanMove()
  for r = 1, 4 do
    for c = 1, 4 do
      local v = g2.b[r][c]
      if v == 0 then return true end
      if c < 4 and g2.b[r][c + 1] == v then return true end
      if r < 4 and g2.b[r + 1][c] == v then return true end
    end
  end
  return false
end

-- dir: 1 izquierda, 2 derecha, 3 arriba, 4 abajo
local function lineCoords(dir, i)
  local t = {}
  for k = 1, 4 do
    if dir == 1 then t[k] = {i, k}
    elseif dir == 2 then t[k] = {i, 5 - k}
    elseif dir == 3 then t[k] = {k, i}
    else t[k] = {5 - k, i} end
  end
  return t
end

local function g2Do(dir)
  if g2.over then return end
  g2.anim = nil
  local mv, merges, gained = {}, {}, 0
  local nb = {}
  for r = 1, 4 do nb[r] = {0, 0, 0, 0} end

  for i = 1, 4 do
    local co = lineCoords(dir, i)
    local items = {}
    for k = 1, 4 do
      local r, c = co[k][1], co[k][2]
      if g2.b[r][c] ~= 0 then items[#items + 1] = {v = g2.b[r][c], r = r, c = c} end
    end
    local out, k = 0, 1
    while k <= #items do
      out = out + 1
      local tr, tc = co[out][1], co[out][2]
      local it, nx = items[k], items[k + 1]
      if nx and nx.v == it.v then
        nb[tr][tc] = it.v * 2
        gained = gained + it.v * 2
        mv[#mv + 1] = {fr = it.r, fc = it.c, tr = tr, tc = tc, v = it.v}
        mv[#mv + 1] = {fr = nx.r, fc = nx.c, tr = tr, tc = tc, v = nx.v}
        merges[#merges + 1] = {tr, tc}
        k = k + 2
      else
        nb[tr][tc] = it.v
        mv[#mv + 1] = {fr = it.r, fc = it.c, tr = tr, tc = tc, v = it.v}
        k = k + 1
      end
    end
  end

  local moved = false
  for _, m in ipairs(mv) do
    if m.fr ~= m.tr or m.fc ~= m.tc then moved = true break end
  end
  if not moved then return end

  g2.b = nb
  g2.score = g2.score + gained
  if g2.score > g2.best then
    g2.best = g2.score
    g2SaveBest()
  end
  local e = g2Spawn()
  g2.anim = {t = 0, mv = mv, merges = merges, spawn = e}
  ctx.buzz(0.004)

  if not g2.won then
    for r = 1, 4 do
      for c = 1, 4 do
        if g2.b[r][c] >= 2048 then g2.won = true end
      end
    end
    if g2.won and ctx.notify then
      ctx.notify({
        iconfn = function(cx, cy, u, a)
          setc(0.93, 0.76, 0.18, 1, a)
          love.graphics.rectangle("fill", cx - u, cy - u, 2 * u, 2 * u, u * 0.4, u * 0.4)
        end,
        name = "¡Llegaste a 2048!",
        sub = g2.score .. " puntos",
        dot = {0.93, 0.76, 0.18},
        dur = 2.6,
      })
    end
  end
  if not g2CanMove() then
    g2.over = true
    if ctx.notify then
      ctx.notify({
        iconfn = function(cx, cy, u, a)
          setc(1, 0.45, 0.40, 1, a)
          love.graphics.rectangle("fill", cx - u, cy - u, 2 * u, 2 * u, u * 0.4, u * 0.4)
        end,
        name = "Fin del juego",
        sub = g2.score .. " puntos",
        dot = {1, 0.35, 0.30},
        dur = 2.6,
      })
    end
  end
end

local function g2Update(dt)
  local a = g2.anim
  if a then
    a.t = a.t + dt / 0.11
    if a.t >= 1 then
      g2.anim = nil
      for _, m in ipairs(a.merges) do
        g2.pops[#g2.pops + 1] = {r = m[1], c = m[2], t = 0, kind = "merge"}
      end
      if a.spawn then
        g2.pops[#g2.pops + 1] = {r = a.spawn[1], c = a.spawn[2], t = 0, kind = "spawn"}
      end
    end
  end
  for i = #g2.pops, 1, -1 do
    local p = g2.pops[i]
    p.t = p.t + dt / 0.16
    if p.t >= 1 then table.remove(g2.pops, i) end
  end
end

local function g2Act(name)
  if name == "new" then
    ctx.buzz(0.008)
    g2New()
  end
end

local function g2Tile(x, y, s, v, ca, scale)
  local c = G2COL[v] or {0.24, 0.22, 0.20}
  local sc = scale or 1
  local ss = s * sc
  local xx, yy = x + (s - ss) / 2, y + (s - ss) / 2
  setc(c[1], c[2], c[3], 1, ca)
  love.graphics.rectangle("fill", xx, yy, ss, ss, s * 0.1, s * 0.1)
  local dark = (v <= 4)
  ctext(fonts.title, tostring(v), x + s / 2, y + s / 2, ca,
    dark and 0.40 or 1, dark and 0.36 or 1, dark and 0.34 or 1, 1, ss * 0.82)
end

local function drawG2(ca)
  begin(g2Act)
  local W, H, U, top, bot = area()

  local y0 = top + 4 * U
  pill(20 * U, y0, 100 * U, 40 * U, ca, 1, 0.70, 0.20, isHeld("new") and 0.55 or 0.30)
  ctext(fonts.hint, "Nuevo juego", 70 * U, y0 + 20 * U, ca, 1, 0.86, 0.50, 1, 90 * U)
  reg("new", 20 * U, y0, 100 * U, 40 * U)

  local bw = 92 * U
  local bx2 = W - 20 * U - bw
  local bx1 = bx2 - 8 * U - bw
  local boxes = {{bx1, "PUNTOS", g2.score}, {bx2, "MEJOR", g2.best}}
  for _, bx in ipairs(boxes) do
    setc(1, 1, 1, 0.10, ca)
    love.graphics.rectangle("fill", bx[1], y0 - 2 * U, bw, 44 * U, 10 * U, 10 * U)
    ctext(fonts.label, bx[2], bx[1] + bw / 2, y0 + 9 * U, ca, 1, 1, 1, 0.55)
    ctext(fonts.hint, tostring(bx[3]), bx[1] + bw / 2, y0 + 28 * U, ca, 1, 1, 1, 1, bw - 12 * U)
  end

  local gap = 8 * U
  local by = y0 + 60 * U
  local bs = math.min(W - 40 * U, bot - by - 40 * U)
  local cs = (bs - 5 * gap) / 4
  local bx = (W - bs) / 2
  local function cxOf(c) return bx + gap + (c - 1) * (cs + gap) end
  local function cyOf(r) return by + gap + (r - 1) * (cs + gap) end

  setc(0.20, 0.19, 0.23, 1, ca)
  love.graphics.rectangle("fill", bx, by, bs, bs, 14 * U, 14 * U)
  setc(1, 1, 1, 0.07, ca)
  for r = 1, 4 do
    for c = 1, 4 do
      love.graphics.rectangle("fill", cxOf(c), cyOf(r), cs, cs, cs * 0.1, cs * 0.1)
    end
  end

  local a = g2.anim
  if a then
    local e = 1 - (1 - a.t) ^ 3
    for _, m in ipairs(a.mv) do
      g2Tile(mix(cxOf(m.fc), cxOf(m.tc), e), mix(cyOf(m.fr), cyOf(m.tr), e), cs, m.v, ca)
    end
  else
    for r = 1, 4 do
      for c = 1, 4 do
        local v = g2.b[r][c]
        if v > 0 then
          local scale = 1
          for _, p in ipairs(g2.pops) do
            if p.r == r and p.c == c then
              if p.kind == "spawn" then
                scale = 0.2 + 0.8 * (1 - (1 - p.t) ^ 3)
              else
                scale = 1 + 0.18 * math.sin(math.pi * p.t)
              end
            end
          end
          g2Tile(cxOf(c), cyOf(r), cs, v, ca, scale)
        end
      end
    end
  end

  if g2.over then
    setc(0, 0, 0, 0.55, ca)
    love.graphics.rectangle("fill", bx, by, bs, bs, 14 * U, 14 * U)
    ctext(fonts.title, "Fin del juego", W / 2, by + bs / 2 - 10 * U, ca, 1, 1, 1, 1)
    ctext(fonts.hint, "Tocá «Nuevo juego»", W / 2, by + bs / 2 + 22 * U, ca, 1, 1, 1, 0.7)
  end

  ctext(fonts.label, "Deslizá para mover las fichas", W / 2, by + bs + 18 * U, ca, 1, 1, 1, 0.45)
end

local function g2Key(k)
  local map = {left = 1, right = 2, up = 3, down = 4, a = 1, d = 2, w = 3, s = 4}
  if map[k] then
    g2Do(map[k])
    return true
  end
  return false
end

local function gPress(id, x, y)
  held = nil
  local r = regAt(x, y)
  if r then
    held = {id = id, n = r.n}
  else
    g2.sw = {id = id, x = x, y = y, done = false}
  end
end

local function gMove(id, x, y)
  local s = g2.sw
  if s and s.id == id then
    if not s.done then
      local dx, dy = x - s.x, y - s.y
      if math.max(math.abs(dx), math.abs(dy)) > 24 * curU() then
        s.done = true
        if math.abs(dx) > math.abs(dy) then
          g2Do(dx < 0 and 1 or 2)
        else
          g2Do(dy < 0 and 3 or 4)
        end
      end
    end
    return true
  end
  return held ~= nil and held.id == id
end

local function gRelease(id, x, y)
  if g2.sw and g2.sw.id == id then
    g2.sw = nil
    return true
  end
  return release(id, x, y)
end

local function iconG2(x, y, s, alpha)
  iconBase(x, y, s, alpha, 0.93, 0.76, 0.18)
  local f = fonts.title
  local sc = (s * 0.74) / math.max(1, f:getWidth("2048"))
  love.graphics.setFont(f)
  setc(1, 1, 1, 1, alpha)
  love.graphics.print("2048", x + s / 2 - f:getWidth("2048") * sc / 2, y + s / 2 - f:getHeight() * sc / 2, 0, sc, sc)
end

-- ============ MÚSICA ============
local mu = {scroll = 0, maxScroll = 0, drag = nil, seek = nil, seekF = 0, bar = nil, cs = 0.88}

local function iconMusic(x, y, s, alpha)
  iconBase(x, y, s, alpha, 0.98, 0.24, 0.38)
  music.note(x + s / 2, y + s / 2, s * 0.30, alpha)
end

local function muAct(n)
  if n == "play" then
    music.toggle()
  elseif n == "prev" then
    music.prev()
  elseif n == "next" then
    music.next()
  elseif n:sub(1, 1) == "t" then
    local i = tonumber(n:sub(2))
    if i and i == music.idx then
      music.toggle()
    elseif i then
      music.play(i)
    end
  end
  ctx.buzz(0.008)
end

local function muUpdate(dt)
  mu.cs = mix(mu.cs, music.playing and 1 or 0.88, 1 - math.exp(-dt * 10))
end

local function muKey(k)
  if k == "space" then
    music.toggle()
    return true
  elseif k == "right" then
    music.next()
    return true
  elseif k == "left" then
    music.prev()
    return true
  end
  return false
end

local function drawMusic(ca)
  begin(muAct)
  local W, H, U, top, bot = area()
  local tr = music.current()
  local n = #music.tracks

  -- portada (se agranda un poco cuando está sonando)
  local cs = clampn((bot - top) * 0.27, 80 * U, 150 * U)
  local s = cs * mu.cs
  local cx, cy = W / 2, top + 6 * U + cs / 2
  setc(0, 0, 0, 0.28, ca)
  love.graphics.rectangle("fill", cx - s / 2 + 3 * U, cy - s / 2 + 8 * U, s, s, s * 0.22, s * 0.22)
  music.cover(cx - s / 2, cy - s / 2, s, ca, tr)

  -- título y artista
  local ty = cy + cs / 2 + 26 * U
  ctext(fonts.dTitle, tr and tr.title or "Sin reproducción", W / 2, ty, ca, 1, 1, 1, 1, W - 48 * U)
  ctext(fonts.hint, tr and tr.artist or "Elegí una canción", W / 2, ty + 24 * U, ca, 1, 1, 1, 0.6, W - 48 * U)

  -- barra de progreso (tocá o arrastrá para moverte en la canción)
  local by = ty + 60 * U
  local bx, bw, bh = 28 * U, W - 56 * U, 5 * U
  mu.bar = {x = bx, y = by - bh / 2, w = bw, h = bh}
  local f = mu.seek and mu.seekF or music.progress()
  setc(1, 1, 1, 0.18, ca)
  love.graphics.rectangle("fill", bx, by - bh / 2, bw, bh, bh / 2, bh / 2)
  setc(1, 1, 1, 0.92, ca)
  love.graphics.rectangle("fill", bx, by - bh / 2, math.max(bh, bw * f), bh, bh / 2, bh / 2)
  if mu.seek then disc(bx + bw * f, by, 8 * U, ca, 1, 1, 1, 1) end
  local cur = (music.dur > 0) and (f * music.dur) or music.pos
  ltext(fonts.label, music.fmt(cur), bx, by + 18 * U, ca, 1, 1, 1, 0.55)
  local ds = (music.dur > 0) and music.fmt(music.dur) or "--:--"
  ltext(fonts.label, ds, bx + bw - fonts.label:getWidth(ds), by + 18 * U, ca, 1, 1, 1, 0.55)

  -- anterior / reproducir-pausar / siguiente
  local cy2 = by + 64 * U
  local R, gx = 30 * U, 92 * U
  music.icons.prev(W / 2 - gx, cy2, 13 * U, ca * (isHeld("prev") and 0.55 or 1))
  disc(W / 2, cy2, R, ca, 1, 1, 1, isHeld("play") and 0.75 or 1)
  if music.playing then
    music.icons.pause(W / 2, cy2, 13 * U, ca, 0.10, 0.10, 0.14)
  else
    music.icons.play(W / 2 + 1 * U, cy2, 13 * U, ca, 0.10, 0.10, 0.14)
  end
  music.icons.next(W / 2 + gx, cy2, 13 * U, ca * (isHeld("next") and 0.55 or 1))
  reg("prev", W / 2 - gx - 32 * U, cy2 - 32 * U, 64 * U, 64 * U)
  reg("play", W / 2 - R, cy2 - R, 2 * R, 2 * R)
  reg("next", W / 2 + gx - 32 * U, cy2 - 32 * U, 64 * U, 64 * U)

  -- lista de canciones
  local ly = cy2 + R + 18 * U
  local hdr = music.hasFiles and ("LISTA · " .. n) or "DEMO · copiá tus canciones a la carpeta music/"
  ltext(fonts.label, hdr, 28 * U, ly + 6 * U, ca, 1, 1, 1, 0.5, W - 56 * U)
  local lt = ly + 20 * U
  local vh = bot - lt - 4 * U
  local rowH = 48 * U
  mu.maxScroll = math.max(0, n * rowH - vh)
  mu.scroll = clampn(mu.scroll, 0, mu.maxScroll)

  if n == 0 then
    ctext(fonts.hint, "No hay canciones", W / 2, lt + 30 * U, ca, 1, 1, 1, 0.7)
    ctext(fonts.label, "Copiá mp3, ogg, wav o flac a la carpeta music/", W / 2, lt + 54 * U, ca, 1, 1, 1, 0.4, W - 40 * U)
  elseif vh > 20 * U then
    love.graphics.setScissor(0, lt, W, vh)
    for i, t in ipairs(music.tracks) do
      local y = lt + (i - 1) * rowH - mu.scroll
      if y + rowH > lt and y < lt + vh then
        local isCur = (i == music.idx)
        setc(1, 1, 1, isHeld("t" .. i) and 0.16 or (isCur and 0.12 or 0.06), ca)
        love.graphics.rectangle("fill", 20 * U, y + 2 * U, W - 40 * U, rowH - 4 * U, 12 * U, 12 * U)
        music.cover(30 * U, y + (rowH - 32 * U) / 2, 32 * U, ca, t)
        ltext(fonts.hint, t.title, 74 * U, y + rowH / 2 - 8 * U, ca, 1, 1, 1, isCur and 1 or 0.9, W - 74 * U - 70 * U)
        ltext(fonts.label, t.artist, 74 * U, y + rowH / 2 + 10 * U, ca, 1, 1, 1, 0.5, W - 74 * U - 70 * U)
        if isCur then
          music.bars(W - 52 * U, y + rowH / 2 - 8 * U, 18 * U, 16 * U, ca, music.playing, t.color)
        end
        local ry0, ry1 = math.max(y, lt), math.min(y + rowH, lt + vh)
        if ry1 > ry0 then reg("t" .. i, 20 * U, ry0, W - 40 * U, ry1 - ry0) end
      end
    end
    love.graphics.setScissor()
    if mu.maxScroll > 0 then
      local sh = math.max(30 * U, vh * vh / (n * rowH))
      local sy = lt + (vh - sh) * (mu.scroll / mu.maxScroll)
      setc(1, 1, 1, 0.25, ca)
      love.graphics.rectangle("fill", W - 5 * U, sy, 3 * U, sh, 1.5 * U, 1.5 * U)
    end
  end
end

local function muPress(id, x, y)
  held = nil
  local U = curU()
  local b = mu.bar
  if b and music.current() and x >= b.x - 12 * U and x <= b.x + b.w + 12 * U
     and y >= b.y - 18 * U and y <= b.y + b.h + 18 * U then
    mu.seek = {id = id}
    mu.seekF = clampn((x - b.x) / b.w, 0, 1)
    return
  end
  mu.drag = {id = id, sy = y, s0 = mu.scroll, moved = 0}
  local r = regAt(x, y)
  if r then held = {id = id, n = r.n} end
end

local function muMove(id, x, y)
  if mu.seek and mu.seek.id == id then
    local b = mu.bar
    if b then mu.seekF = clampn((x - b.x) / b.w, 0, 1) end
    return true
  end
  local d = mu.drag
  if not d or d.id ~= id then return false end
  d.moved = math.max(d.moved, math.abs(y - d.sy))
  if d.moved > 8 * curU() then
    held = nil
    mu.scroll = clampn(d.s0 + (d.sy - y), 0, mu.maxScroll)
  end
  return true
end

local function muRelease(id, x, y)
  if mu.seek and mu.seek.id == id then
    music.seekFrac(mu.seekF)
    mu.seek = nil
    return true
  end
  local d = mu.drag
  if not d or d.id ~= id then return false end
  mu.drag = nil
  local name = held and held.n
  held = nil
  if d.moved < 10 * curU() and name then
    local r = regAt(x, y)
    if r and r.n == name then muAct(name) end
  end
  return true
end

-- ============ registro ============
local function mk(def)
  def.press, def.move, def.release = press, move, release
  return def
end

function M.init(c)
  ctx = c
  perf.t0 = love.timer.getTime()
  fonts, DAYS, MONTHS = c.fonts, c.DAYS, c.MONTHS
  M.apps = {
    mk{name = "Teléfono", color = {0.20, 0.78, 0.35}, dock = true, iconfn = iconPhone,
       draw = drawPhone, update = phUpdate, text = phText, key = phKey},
    mk{name = "Reloj", color = {0.20, 0.20, 0.24}, iconfn = iconClock,
       draw = drawClock, update = ckUpdate},
    mk{name = "Calculadora", color = {0.15, 0.15, 0.18}, iconfn = iconCalc,
       draw = drawCalc, text = calcText, key = calcKey},
    mk{name = "Calendario", color = {0.45, 0.15, 0.15}, iconfn = iconCal,
       draw = drawCal},
    mk{name = "Rendimiento", color = {0.12, 0.60, 0.50}, iconfn = iconPerf,
       draw = drawPerf, update = perfUpdate},
  }

  -- Notas y 2048 usan su propio manejo de toques (scroll / deslizar)
  local nApp = mk{name = "Notas", color = {0.30, 0.26, 0.12}, iconfn = iconNotes,
                  draw = drawNotes, update = nUpdate, text = nText, key = nKey}
  nApp.press, nApp.move, nApp.release = nPress, nMove, nRelease
  notesApp = nApp
  local gApp = mk{name = "2048", color = {0.30, 0.24, 0.14}, iconfn = iconG2,
                  draw = drawG2, update = g2Update, key = g2Key}
  gApp.press, gApp.move, gApp.release = gPress, gMove, gRelease
  M.apps[#M.apps + 1] = nApp
  M.apps[#M.apps + 1] = gApp

  -- Música: lista con scroll y barra de progreso arrastrable
  local muApp = mk{name = "Música", color = {0.55, 0.14, 0.26}, iconfn = iconMusic,
                   draw = drawMusic, update = muUpdate, key = muKey}
  muApp.press, muApp.move, muApp.release = muPress, muMove, muRelease
  M.apps[#M.apps + 1] = muApp

  notesLoad()
  g2LoadBest()
  g2New()
  return M.apps
end

return M
