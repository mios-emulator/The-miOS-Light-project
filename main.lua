-- main.lua - miOS Next v1.0 (Liquid Glass + Dynamic Island + Rendimiento, Notas y 2048)
local apps = {
  {name="WhatsApp", file="icon_whatsapp.png", color={0.15,0.75,0.40}, dock=true, url="https://web.whatsapp.com"},
  {name="Google",   file="icon_google.png",   color={0.26,0.52,0.96}, dock=true, url="https://www.google.com"},
  {name="TikTok",   file="icon_tiktok.png",   color={0.10,0.10,0.14}, url="https://www.tiktok.com"},
  {name="YouTube",  file="icon_youtube.png",  color={0.90,0.12,0.12}, url="https://m.youtube.com"},
  {name="Ajustes",  icon="gear", color={0.56,0.58,0.64}, settings=true},
}
local miniapps = require("miniapps")

local FONT_FILE = nil
local LOCK_TEXT = "Deslizá para desbloquear"
local ASK_BEFORE_OPEN = true
local LIQUID_GLASS = true

local DAYS = {"Domingo","Lunes","Martes","Miércoles","Jueves","Viernes","Sábado"}
local MONTHS = {"enero","febrero","marzo","abril","mayo","junio","julio",
                "agosto","septiembre","octubre","noviembre","diciembre"}

local W, H, U
local fonts, wall = {}, nil
local current, prog, target = nil, 0, 0
local pressed, pressedId, swipe = nil, nil, nil
local opened = false
local ha = 1

-- bloqueo
local locked = true
local lockP, lockTarget = 0, 0
local lockDrag = nil

-- cartel de confirmación
local dialogP, dialogTarget = 0, 0
local dpress, dpressId = nil, nil

-- centro de control
local ccP, ccTarget = 0, 0
local ccDrag, ccPress, ccSlider, ccClose = nil, nil, nil, nil
local ccNames = {"Avión", "Datos", "Wi-Fi", "Bluetooth", "No molestar", "Linterna", "Rotación", "Ahorro"}
local ccOn = {false, true, true, true, false, false, false, false}
local ccColors = {
  {1.00, 0.58, 0.10},
  {0.20, 0.78, 0.35},
  {0.25, 0.55, 1.00},
  {0.25, 0.55, 1.00},
  {0.50, 0.35, 0.95},
  {0.95, 0.75, 0.10},
  {0.95, 0.30, 0.30},
  {0.95, 0.75, 0.10},
}
local ccVal = {1.0, 0.7}

-- dynamic island
local ISLAND_ENABLED = true
local ISLAND_TOP = 10 -- separación desde el borde de arriba (en U)
local island = {mode = "idle", modeT = 0, w = 0, h = 0, wv = 0, hv = 0,
                notice = nil, noticeT = 0, noticeDur = 2, cardT = 0, touch = nil}

-- liquid glass
local glass, shaderErr = nil, nil
local px, orb = nil, nil
local bgCanvas, sceneCanvas, c4, c8
local lastBg = nil

local GLASS_SRC = [==[
uniform Image bg;
uniform vec2 screenSize;
uniform vec4 rect;
uniform float radius;
uniform vec4 tint;
uniform float refr;
uniform float blur;
uniform float rim;
uniform float glow;

float sdBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec2 hs = rect.zw * 0.5;
  float r = min(radius, min(hs.x, hs.y));
  vec2 p = tc * rect.zw - hs;
  float d = sdBox(p, hs, r);
  float mask = 1.0 - smoothstep(-1.0, 1.0, d);
  if (mask <= 0.001) { return vec4(0.0); }

  vec2 g = vec2(
    sdBox(p + vec2(1.0, 0.0), hs, r) - sdBox(p - vec2(1.0, 0.0), hs, r),
    sdBox(p + vec2(0.0, 1.0), hs, r) - sdBox(p - vec2(0.0, 1.0), hs, r));
  float gl = length(g);
  if (gl > 0.0001) { g = g / gl; } else { g = vec2(0.0); }

  float depth = clamp(-d / max(rim, 1.0), 0.0, 1.0);
  float bend = pow(1.0 - depth, 3.0);

  vec2 base = rect.xy + tc * rect.zw;
  vec2 pos = base - g * bend * refr;

  vec3 acc = vec3(0.0);
  for (int i = 0; i < 12; i++) {
    float fi = float(i);
    float a = fi * 2.39996;
    float rr = sqrt((fi + 0.5) / 12.0) * blur;
    vec2 o = vec2(cos(a), sin(a)) * rr;
    acc += Texel(bg, (pos + o) / screenSize).rgb;
  }
  vec3 c = acc / 12.0;

  vec2 disp = g * bend * refr * 0.35;
  float cr = Texel(bg, (pos + disp) / screenSize).r;
  float cb = Texel(bg, (pos - disp) / screenSize).b;
  float k = clamp(bend * 1.5, 0.0, 1.0);
  c.r = mix(c.r, cr, k);
  c.b = mix(c.b, cb, k);

  float lum = dot(c, vec3(0.299, 0.587, 0.114));
  c = mix(vec3(lum), c, 1.35);
  c = mix(c, tint.rgb, tint.a);
  c += vec3(0.05);

  vec2 L = normalize(vec2(-0.6, -0.8));
  float s1 = max(dot(g, L), 0.0);
  float s2 = max(dot(g, -L), 0.0);
  float edge = pow(1.0 - depth, 4.0);
  float spec = edge * (0.75 * pow(s1, 1.5) + 0.35 * pow(s2, 1.5) + 0.12);
  float line = smoothstep(-2.0, -1.0, d) * (1.0 - smoothstep(-1.0, 0.0, d));
  float sheen = (1.0 - tc.y) * 0.06;

  c += vec3(1.0) * (spec + line * (0.20 + 0.5 * s1) + sheen) * glow;

  return vec4(clamp(c, 0.0, 1.0), mask * color.a);
}
]==]

local orbs = {
  {0.20, 0.22, 0.75, {0.95, 0.30, 0.65}, 0.31, 0.23, 0.0},
  {0.85, 0.40, 0.70, {0.15, 0.70, 0.95}, 0.27, 0.19, 2.0},
  {0.30, 0.78, 0.80, {0.55, 0.35, 1.00}, 0.21, 0.29, 4.0},
  {0.75, 0.90, 0.55, {1.00, 0.55, 0.25}, 0.25, 0.22, 1.0},
}

local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function col(r, g, b, a) love.graphics.setColor(r, g, b, (a or 1) * ha) end
local function buzz(sec)
  if love.system.vibrate then pcall(love.system.vibrate, sec or 0.01) end
end
local function inrect(r, x, y)
  return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function mkfont(sz)
  sz = math.floor(sz * U)
  if FONT_FILE then
    local ok, f = pcall(love.graphics.newFont, FONT_FILE, sz)
    if ok then return f end
  end
  return love.graphics.newFont(sz)
end

local function loadImage(name)
  for _, p in ipairs({name, "assets/" .. name}) do
    if love.filesystem.getInfo(p) then
      local okd, data = pcall(love.image.newImageData, p)
      if okd then
        local img = love.graphics.newImage(data)
        img:setFilter("linear", "linear")
        -- recorte al área visible (ignora bordes transparentes)
        local quad, qs
        local iw, ih = data:getDimensions()
        local x0, y0, x1, y1 = iw, ih, -1, -1
        for y = 0, ih - 1, 2 do
          for x = 0, iw - 1, 2 do
            local _, _, _, al = data:getPixel(x, y)
            if al > 0.05 then
              if x < x0 then x0 = x end
              if x > x1 then x1 = x end
              if y < y0 then y0 = y end
              if y > y1 then y1 = y end
            end
          end
        end
        if x1 >= x0 then
          qs = math.min(math.max(x1 - x0 + 1, y1 - y0 + 1), iw, ih)
          local qx = math.max(0, math.min(iw - qs, (x0 + x1) / 2 - qs / 2))
          local qy = math.max(0, math.min(ih - qs, (y0 + y1) / 2 - qs / 2))
          quad = love.graphics.newQuad(qx, qy, qs, qs, iw, ih)
        end
        return img, quad, qs
      end
    end
  end
end

local function makeGradient(c1, c2)
  return love.graphics.newMesh({
    {0, 0, 0, 0, c1[1], c1[2], c1[3], 1},
    {1, 0, 1, 0, c1[1], c1[2], c1[3], 1},
    {1, 1, 1, 1, c2[1], c2[2], c2[3], 1},
    {0, 1, 0, 1, c2[1], c2[2], c2[3], 1},
  }, "fan", "static")
end

-- ajustes: temas de fondo y guardado en disco
local themes = {
  {name = "Noche",     c1 = {0.10, 0.07, 0.22}, c2 = {0.02, 0.02, 0.06},
   orbs = {{0.95, 0.30, 0.65}, {0.15, 0.70, 0.95}, {0.55, 0.35, 1.00}, {1.00, 0.55, 0.25}}},
  {name = "Océano",    c1 = {0.03, 0.12, 0.22}, c2 = {0.01, 0.03, 0.08},
   orbs = {{0.10, 0.60, 0.95}, {0.10, 0.85, 0.75}, {0.30, 0.40, 1.00}, {0.60, 0.90, 1.00}}},
  {name = "Atardecer", c1 = {0.22, 0.08, 0.12}, c2 = {0.06, 0.02, 0.05},
   orbs = {{1.00, 0.40, 0.35}, {1.00, 0.65, 0.20}, {0.90, 0.25, 0.60}, {0.60, 0.30, 0.90}}},
  {name = "Bosque",    c1 = {0.04, 0.16, 0.10}, c2 = {0.01, 0.05, 0.03},
   orbs = {{0.20, 0.80, 0.45}, {0.75, 0.90, 0.30}, {0.10, 0.60, 0.60}, {0.95, 0.85, 0.35}}},
}
local themeIdx = 1

local function applyTheme(i)
  themeIdx = i
  local t = themes[i]
  wall = makeGradient(t.c1, t.c2)
  for k, o in ipairs(orbs) do o[4] = t.orbs[k] end
end

local SAVE_FILE = "settings.txt"

local function saveSettings()
  local t = {
    "theme=" .. themeIdx,
    "ask=" .. (ASK_BEFORE_OPEN and 1 or 0),
    "island=" .. (ISLAND_ENABLED and 1 or 0),
    string.format("bright=%.3f", ccVal[1]),
    string.format("vol=%.3f", ccVal[2]),
  }
  for i = 1, #ccOn do t[#t + 1] = "cc" .. i .. "=" .. (ccOn[i] and 1 or 0) end
  pcall(love.filesystem.write, SAVE_FILE, table.concat(t, "\n"))
end

local function loadSettings()
  if not love.filesystem.getInfo(SAVE_FILE) then return end
  local ok, str = pcall(love.filesystem.read, SAVE_FILE)
  if not ok or not str then return end
  local kv = {}
  for k, v in str:gmatch("(%w+)=([%d%.%-]+)") do kv[k] = tonumber(v) end
  if kv.theme and themes[kv.theme] then applyTheme(kv.theme) end
  if kv.ask then ASK_BEFORE_OPEN = (kv.ask == 1) end
  if kv.island then ISLAND_ENABLED = (kv.island == 1) end
  if kv.bright then ccVal[1] = clamp(kv.bright, 0, 1) end
  if kv.vol then ccVal[2] = clamp(kv.vol, 0, 1) end
  for i = 1, #ccOn do
    if kv["cc" .. i] then ccOn[i] = (kv["cc" .. i] == 1) end
  end
end

local function layout()
  W, H = love.graphics.getDimensions()
  U = W / 360
  fonts.clock     = mkfont(64)
  fonts.date      = mkfont(15)
  fonts.label     = mkfont(11)
  fonts.title     = mkfont(26)
  fonts.lockClock = mkfont(86)
  fonts.lockDate  = mkfont(18)
  fonts.hint      = mkfont(14)
  fonts.dTitle    = mkfont(17)
  fonts.dMsg      = mkfont(13)
  fonts.dBtn      = mkfont(17)
  fonts.ccTime    = mkfont(18)
  fonts.ccLabel   = mkfont(10)
  fonts.ccSlider  = mkfont(14)
  fonts.isl       = mkfont(13)
  fonts.islS      = mkfont(10)
  fonts.islMed    = mkfont(15)
  fonts.islBig    = mkfont(44)
  island.w, island.h, island.wv, island.hv = 0, 0, 0, 0

  lastBg = nil
  if glass then pcall(glass.send, glass, "screenSize", {W, H}) end

  bgCanvas    = love.graphics.newCanvas(W, H)
  sceneCanvas = love.graphics.newCanvas(W, H)
  c4 = love.graphics.newCanvas(math.max(1, math.floor(W / 4)), math.max(1, math.floor(H / 4)))
  c8 = love.graphics.newCanvas(math.max(1, math.floor(W / 8)), math.max(1, math.floor(H / 8)))

  local size, cellW = 60 * U, W / 4
  local gi, di = 0, 0
  local dh = 84 * U
  local dy = H - dh - 20 * U
  for _, a in ipairs(apps) do
    a.s = size
    if a.dock then
      local slot = (W - 32 * U) / 4
      a.x = 16 * U + di * slot + (slot - size) / 2
      a.y = dy + (dh - size) / 2
      di = di + 1
    else
        a.x = (gi % 4) * cellW + (cellW - size) / 2
        a.y = 200 * U + math.floor(gi / 4) * 100 * U
        gi = gi + 1
      end
    end

    
  end
  
function love.load()
  miniapps.init({
    size = function() return W, H, U end,
    fonts = fonts, buzz = buzz, DAYS = DAYS, MONTHS = MONTHS,
    notify = function(n) island.notify(n) end,
    current = function() return current and apps[current] or nil end,
  })
  for i, a in ipairs(miniapps.apps) do table.insert(apps, 2 + i, a) end

  wall = makeGradient({0.10, 0.07, 0.22}, {0.02, 0.02, 0.06})

  local pd = love.image.newImageData(1, 1)
  pd:setPixel(0, 0, 1, 1, 1, 1)
  px = love.graphics.newImage(pd)

  local od = love.image.newImageData(64, 64)
  od:mapPixel(function(x, y)
    local dx, dy = (x - 31.5) / 32, (y - 31.5) / 32
    local d = math.sqrt(dx * dx + dy * dy)
    local a = math.max(0, 1 - d)
    a = a * a * (3 - 2 * a)
    return 1, 1, 1, a
  end)
  orb = love.graphics.newImage(od)
  orb:setFilter("linear", "linear")

  if LIQUID_GLASS then
    local ok, res = pcall(love.graphics.newShader, GLASS_SRC)
    if ok then
      glass = res
    else
      shaderErr = tostring(res)
    end
  end

  layout()
  for _, a in ipairs(apps) do
    if a.file then
      a.img, a.quad, a.qs = loadImage(a.file)
    end
  end
  loadSettings()
  love.audio.setVolume(ccVal[2])
end

function love.resize()
  layout()
end

-- dibuja un panel de vidrio en coordenadas de pantalla (sin transformaciones activas)
local DEFAULT_TINT = {1, 1, 1, 0.10}
local uRect = {0, 0, 0, 0}

local function sendGlass(src, x, y, w, h, r, o)
  if lastBg ~= src then
    glass:send("bg", src)
    lastBg = src
  end
  uRect[1], uRect[2], uRect[3], uRect[4] = x, y, w, h
  glass:send("rect", uRect)
  glass:send("radius", r)
  glass:send("tint", o.tint or DEFAULT_TINT)
  glass:send("refr", (o.refr or 10) * U)
  glass:send("blur", (o.blur or 4) * U)
  glass:send("rim", (o.rim or 16) * U)
  glass:send("glow", o.glow or 1)
end

local EMPTY = {}
local function drawGlass(src, x, y, w, h, r, o)
  o = o or EMPTY
  local a = o.alpha or 1
  if a <= 0.003 or w <= 0 or h <= 0 then return end

  if glass then
    local ok, err = pcall(sendGlass, src, x, y, w, h, r, o)
    if not ok then
      shaderErr = tostring(err)
      glass = nil
    end
  end

  if glass then
    love.graphics.setShader(glass)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(px, x, y, 0, w, h)
    love.graphics.setShader()
  else
    love.graphics.setColor(1, 1, 1, 0.15 * a)
    love.graphics.rectangle("fill", x, y, w, h, r, r)
  end
end

local function drawBackground()
  love.graphics.setCanvas(bgCanvas)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(wall, 0, 0, 0, W, H)
  love.graphics.setBlendMode("add")
  local t = love.timer.getTime()
  for _, o in ipairs(orbs) do
    local x = (o[1] + 0.10 * math.sin(t * o[5] + o[7])) * W
    local y = (o[2] + 0.08 * math.cos(t * o[6] + o[7])) * H
    local s = o[3] * W * 2 / 64
    love.graphics.setColor(o[4][1], o[4][2], o[4][3], 0.55)
    love.graphics.draw(orb, x, y, 0, s, s, 32, 32)
  end
  love.graphics.setBlendMode("alpha")
  love.graphics.setCanvas()
end

local function blurScene()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setCanvas(c4)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.draw(sceneCanvas, 0, 0, 0, c4:getWidth() / W, c4:getHeight() / H)
  love.graphics.setCanvas(c8)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.draw(c4, 0, 0, 0, c8:getWidth() / c4:getWidth(), c8:getHeight() / c4:getHeight())
  love.graphics.setCanvas()
end

-- iconos dibujados por código (no necesitan imagen)
local ICONS = {}

function ICONS.gear(x, y, s, alpha)
  local bg = {0.56, 0.58, 0.64}
  love.graphics.setColor(bg[1], bg[2], bg[3], alpha)
  love.graphics.rectangle("fill", x, y, s, s, s * 0.22, s * 0.22)
  love.graphics.setColor(1, 1, 1, 0.16 * alpha)
  love.graphics.rectangle("fill", x + s * 0.04, y + s * 0.03, s * 0.92, s * 0.34, s * 0.18, s * 0.18)

  local cx, cy = x + s / 2, y + s / 2
  local ro = s * 0.235
  local tw, tl = s * 0.13, s * 0.10
  love.graphics.setColor(0.17, 0.18, 0.22, alpha)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  for i = 0, 7 do
    love.graphics.push()
    love.graphics.rotate(i * math.pi / 4)
    love.graphics.rectangle("fill", -tw / 2, -(ro + tl), tw, tl + ro * 0.3, tw * 0.25, tw * 0.25)
    love.graphics.pop()
  end
  love.graphics.pop()
  love.graphics.circle("fill", cx, cy, ro, 40)
  love.graphics.setColor(bg[1], bg[2], bg[3], alpha)
  love.graphics.circle("fill", cx, cy, s * 0.095, 32)
end

local function drawIcon(a, x, y, s, alpha)
  if a.img then
    love.graphics.setColor(1, 1, 1, alpha)
    if a.quad then
      love.graphics.draw(a.img, a.quad, x, y, 0, s / a.qs, s / a.qs)
    else
      love.graphics.draw(a.img, x, y, 0, s / a.img:getWidth(), s / a.img:getHeight())
    end
  elseif a.iconfn then
    a.iconfn(x, y, s, alpha)
  elseif a.icon and ICONS[a.icon] then
    ICONS[a.icon](x, y, s, alpha)
  else
    love.graphics.setColor(a.color[1], a.color[2], a.color[3], alpha)
    love.graphics.rectangle("fill", x, y, s, s, s * 0.22, s * 0.22)
  end
end

local function drawDockGlass(alpha)
  local sc = (1 + 0.08 * prog) * (0.94 + 0.06 * lockP)
  local dh = 84 * U
  local x, y, w, h = 16 * U, H - dh - 20 * U, W - 32 * U, dh
  local cx, cy = W / 2, H / 2
  drawGlass(bgCanvas, cx + (x - cx) * sc, cy + (y - cy) * sc, w * sc, h * sc, 26 * U * sc,
    {alpha = alpha, blur = 7, refr = 14, rim = 18, tint = {1, 1, 1, 0.08}})
end

local function drawHome()
  col(1, 1, 1)
  love.graphics.setFont(fonts.clock)
  love.graphics.printf(os.date("%H:%M"), 0, 60 * U, W, "center")
  love.graphics.setFont(fonts.date)
  col(1, 1, 1, 0.7)
  local t = os.date("*t")
  love.graphics.printf(string.format("%s %d de %s", DAYS[t.wday], t.day, MONTHS[t.month]),
    0, 60 * U + fonts.clock:getHeight(), W, "center")

  for i, a in ipairs(apps) do
    local s, x, y = a.s, a.x, a.y
    if pressed == i then
      s = s * 0.9
      x = a.x + (a.s - s) / 2
      y = a.y + (a.s - s) / 2
    end
    drawIcon(a, x, y, s, ha)
    if not a.dock then
      love.graphics.setFont(fonts.label)
      col(1, 1, 1, 0.9)
      love.graphics.printf(a.name, a.x - 10 * U, a.y + a.s + 6 * U, a.s + 20 * U, "center")
    end
  end
end

-- pantalla de Ajustes
local setScroll = 0

local SROWS = {
  {k = "head", t = "Conexiones"},
  {k = "tog", t = "Modo avión", i = 1},
  {k = "tog", t = "Datos móviles", i = 2},
  {k = "tog", t = "Wi-Fi", i = 3},
  {k = "tog", t = "Bluetooth", i = 4},
  {k = "head", t = "General"},
  {k = "tog", t = "No molestar", i = 5},
  {k = "tog", t = "Ahorro de batería", i = 8},
  {k = "tog", t = "Avisar antes de abrir links", ask = true},
  {k = "tog", t = "Isla dinámica", island = true},
  {k = "head", t = "Pantalla y sonido"},
  {k = "sld", t = "Brillo", i = 1},
  {k = "sld", t = "Volumen", i = 2},
  {k = "theme", t = "Fondo"},
  {k = "head", t = "Acerca de"},
  {k = "info", t = "miOS Light", v = "v1.0"},
}
local ROWH = {head = 30, tog = 48, sld = 64, theme = 76, info = 44}

local function setViewport()
  return 104 * U, H - 104 * U - 92 * U
end

local function setLayout()
  local y = 0
  for _, r in ipairs(SROWS) do
    r.y = y
    r.h = ROWH[r.k] * U
    y = y + r.h + (r.k == "head" and 0 or 6 * U)
  end
  return y
end

local function drawSettings(ca)
  local top, vh = setViewport()
  local total = setLayout()
  local maxS = math.max(0, total - vh)
  setScroll = clamp(setScroll, 0, maxS)
  local x0, w = 20 * U, W - 40 * U

  love.graphics.setScissor(0, top, W, vh)
  for _, r in ipairs(SROWS) do
    local y = top + r.y - setScroll
    if y + r.h >= top and y <= top + vh then
      if r.k == "head" then
        love.graphics.setFont(fonts.label)
        love.graphics.setColor(1, 1, 1, 0.55 * ca)
        love.graphics.print(r.t, x0 + 6 * U, y + r.h - fonts.label:getHeight() - 4 * U)
      else
        love.graphics.setColor(1, 1, 1, 0.08 * ca)
        love.graphics.rectangle("fill", x0, y, w, r.h, 16 * U, 16 * U)
        love.graphics.setFont(fonts.hint)
        love.graphics.setColor(1, 1, 1, 0.95 * ca)
        local lh = fonts.hint:getHeight()

        if r.k == "tog" then
          love.graphics.print(r.t, x0 + 16 * U, y + (r.h - lh) / 2)
          local on
          if r.ask then
            on = ASK_BEFORE_OPEN
          elseif r.island then
            on = ISLAND_ENABLED
          else
            on = ccOn[r.i]
          end
          local tw, th = 46 * U, 26 * U
          local tx, ty = x0 + w - 16 * U - tw, y + (r.h - th) / 2
          if on then
            love.graphics.setColor(0.20, 0.78, 0.35, ca)
          else
            love.graphics.setColor(1, 1, 1, 0.22 * ca)
          end
          love.graphics.rectangle("fill", tx, ty, tw, th, th / 2, th / 2)
          love.graphics.setColor(1, 1, 1, ca)
          love.graphics.circle("fill", on and (tx + tw - th / 2) or (tx + th / 2), ty + th / 2, th / 2 - 2 * U, 24)

        elseif r.k == "sld" then
          love.graphics.print(r.t, x0 + 16 * U, y + 10 * U)
          love.graphics.setFont(fonts.label)
          love.graphics.setColor(1, 1, 1, 0.6 * ca)
          love.graphics.printf(string.format("%d%%", math.floor(ccVal[r.i] * 100 + 0.5)),
            x0, y + 12 * U, w - 16 * U, "right")
          local sx, sw, sy = x0 + 16 * U, w - 32 * U, y + r.h - 20 * U
          love.graphics.setColor(1, 1, 1, 0.20 * ca)
          love.graphics.rectangle("fill", sx, sy - 3 * U, sw, 6 * U, 3 * U, 3 * U)
          love.graphics.setColor(0.45, 0.70, 1, ca)
          love.graphics.rectangle("fill", sx, sy - 3 * U, math.max(6 * U, sw * ccVal[r.i]), 6 * U, 3 * U, 3 * U)
          love.graphics.setColor(1, 1, 1, ca)
          love.graphics.circle("fill", sx + sw * ccVal[r.i], sy, 9 * U, 24)

        elseif r.k == "theme" then
          love.graphics.print(r.t, x0 + 16 * U, y + 10 * U)
          love.graphics.setFont(fonts.label)
          love.graphics.setColor(1, 1, 1, 0.6 * ca)
          love.graphics.printf(themes[themeIdx].name, x0, y + 12 * U, w - 16 * U, "right")
          for i, t in ipairs(themes) do
            local cx, cy = x0 + 16 * U + (i - 1) * 44 * U + 14 * U, y + r.h - 26 * U
            local c = t.orbs[1]
            love.graphics.setColor(c[1], c[2], c[3], ca)
            love.graphics.circle("fill", cx, cy, 14 * U, 28)
            if i == themeIdx then
              love.graphics.setColor(1, 1, 1, ca)
              love.graphics.setLineWidth(2 * U)
              love.graphics.circle("line", cx, cy, 18 * U, 28)
              love.graphics.setLineWidth(1)
            end
          end

        else
          love.graphics.print(r.t, x0 + 16 * U, y + (r.h - lh) / 2)
          love.graphics.setFont(fonts.label)
          love.graphics.setColor(1, 1, 1, 0.6 * ca)
          love.graphics.printf(r.v or "", x0, y + (r.h - fonts.label:getHeight()) / 2, w - 16 * U, "right")
        end
      end
    end
  end

  if maxS > 0 then
    local bh = math.max(30 * U, vh * vh / total)
    local by = top + (vh - bh) * (setScroll / maxS)
    love.graphics.setColor(1, 1, 1, 0.25 * ca)
    love.graphics.rectangle("fill", W - 5 * U, by, 3 * U, bh, 1.5 * U, 1.5 * U)
  end
  love.graphics.setScissor()
end

local function drawWindow()
  local a = apps[current]
  local e = prog
  local x, y = lerp(a.x, 0, e), lerp(a.y, 0, e)
  local w, h = lerp(a.s, W, e), lerp(a.s, H, e)
  local r = lerp(a.s * 0.22, 0, e)

  local bgA = clamp(e * 5, 0, 1)
  love.graphics.setColor(a.color[1] * 0.3 + 0.06, a.color[2] * 0.3 + 0.06, a.color[3] * 0.3 + 0.06, bgA)
  love.graphics.rectangle("fill", x, y, w, h, r, r)

  local isz = lerp(a.s, 84 * U, e)
  local ia = 1 - clamp((e - 0.55) / 0.35, 0, 1)
  if ia > 0 then
    drawIcon(a, x + (w - isz) / 2, y + (h - isz) / 2, isz, ia)
  end

  local ca = clamp((e - 0.7) / 0.3, 0, 1)
  if ca > 0 then
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 1, 1, ca)
    love.graphics.print(a.name, 24 * U, 64 * U)
    if a.settings then
      drawSettings(ca)
    elseif a.draw then
      a.draw(ca)
    else
      for i = 0, 2 do
        love.graphics.setColor(1, 1, 1, 0.07 * ca)
        love.graphics.rectangle("fill", 20 * U, 130 * U + i * 106 * U, W - 40 * U, 90 * U, 20 * U, 20 * U)
      end
    end
    love.graphics.setColor(1, 1, 1, 0.5 * ca)
    love.graphics.rectangle("fill", W / 2 - 60 * U, H - 14 * U, 120 * U, 5 * U, 3 * U, 3 * U)
  end
end

-- cartel
local function dialogRects()
  local bw, bh = 270 * U, 150 * U
  local bx, by = (W - bw) / 2, (H - bh) / 2
  local btnH = 44 * U
  return bx, by, bw, bh, btnH
end

local function dialogHit(x, y)
  local bx, by, bw, bh, btnH = dialogRects()
  local ry = by + bh - btnH
  if y >= ry and y <= by + bh then
    if x >= bx and x < bx + bw / 2 then return 1 end
    if x >= bx + bw / 2 and x <= bx + bw then return 2 end
  end
  return nil
end

local function drawDialog()
  local p = dialogP
  if p < 0.01 or not current then return end
  local a = apps[current]
  local bx, by, bw, bh, btnH = dialogRects()
  local ry = by + bh - btnH

  love.graphics.setColor(0, 0, 0, 0.35 * p)
  love.graphics.rectangle("fill", 0, 0, W, H)

  local sc = 0.85 + 0.15 * p
  local cx, cy = W / 2, H / 2
  drawGlass(c8, cx + (bx - cx) * sc, cy + (by - cy) * sc, bw * sc, bh * sc, 24 * U * sc,
    {alpha = p, blur = 3, refr = 16, rim = 22, tint = {0.05, 0.05, 0.10, 0.30}})

  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(sc)
  love.graphics.translate(-cx, -cy)

  love.graphics.setFont(fonts.dTitle)
  love.graphics.setColor(1, 1, 1, p)
  love.graphics.printf("Abrir en el navegador", bx, by + 20 * U, bw, "center")

  love.graphics.setFont(fonts.dMsg)
  love.graphics.setColor(1, 1, 1, 0.75 * p)
  love.graphics.printf(a.name .. " se abrirá fuera de miOS Next. ¿Querés continuar?",
    bx + 16 * U, by + 50 * U, bw - 32 * U, "center")

  if dpress then
    love.graphics.setColor(1, 1, 1, 0.12 * p)
    local hx = (dpress == 1) and bx or (bx + bw / 2)
    love.graphics.rectangle("fill", hx, ry, bw / 2, btnH)
  end

  love.graphics.setColor(1, 1, 1, 0.18 * p)
  love.graphics.rectangle("fill", bx, ry, bw, 1)
  love.graphics.rectangle("fill", bx + bw / 2, ry, 1, btnH)

  love.graphics.setFont(fonts.dBtn)
  local ty = ry + (btnH - fonts.dBtn:getHeight()) / 2
  love.graphics.setColor(1, 1, 1, 0.9 * p)
  love.graphics.printf("Cancelar", bx, ty, bw / 2, "center")
  love.graphics.setColor(0.45, 0.7, 1, p)
  love.graphics.printf("Abrir", bx + bw / 2, ty, bw / 2, "center")

  love.graphics.pop()
end

local function drawLock()
  local a = 1 - lockP
  love.graphics.push()
  love.graphics.translate(0, -lockP * H * 0.35)

  love.graphics.setColor(1, 1, 1, a)
  love.graphics.draw(bgCanvas, 0, 0)

  local cx, by = W / 2, 78 * U
  love.graphics.setColor(1, 1, 1, 0.9 * a)
  love.graphics.setLineWidth(2.5 * U)
  love.graphics.arc("line", "open", cx, by, 7 * U, math.pi, 2 * math.pi)
  love.graphics.line(cx - 7 * U, by, cx - 7 * U, by + 4 * U)
  love.graphics.line(cx + 7 * U, by, cx + 7 * U, by + 4 * U)
  love.graphics.rectangle("fill", cx - 11 * U, by + 3 * U, 22 * U, 17 * U, 4 * U, 4 * U)
  love.graphics.setLineWidth(1)

  local t = os.date("*t")
  local dateStr = string.format("%s %d de %s", DAYS[t.wday], t.day, MONTHS[t.month])
  love.graphics.setFont(fonts.lockDate)
  love.graphics.setColor(1, 1, 1, 0.75 * a)
  love.graphics.printf(dateStr, 0, 125 * U, W, "center")
  love.graphics.setFont(fonts.lockClock)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.printf(os.date("%H:%M"), 0, 125 * U + fonts.lockDate:getHeight(), W, "center")

  local pulse = 0.55 + 0.3 * math.sin(love.timer.getTime() * 3)
  love.graphics.setFont(fonts.hint)
  love.graphics.setColor(1, 1, 1, pulse * a)
  love.graphics.printf(LOCK_TEXT, 0, H - 88 * U, W, "center")

  love.graphics.setColor(1, 1, 1, 0.6 * a)
  love.graphics.rectangle("fill", W / 2 - 60 * U, H - 14 * U, 120 * U, 5 * U, 3 * U, 3 * U)

  love.graphics.pop()
end

-- íconos del centro de control (vectoriales, no necesitan imágenes)
-- todas reciben (cx, cy, u, alpha) donde u = mitad del tamaño del ícono
local CCI = {}
local moonTris

local function moonTriangles()
  if moonTris then return moonTris end
  local R0, r, d, phi = 1.0, 1.0, 0.55, -math.pi / 4
  local a = (R0 * R0 - r * r + d * d) / (2 * d)
  local al = math.acos(clamp(a / R0, -1, 1))
  local c1x, c1y = d * math.cos(phi), d * math.sin(phi)
  local N = 28
  local pts = {}
  local t0, t1 = phi + al, phi + 2 * math.pi - al
  for k = 0, N do
    local th = t0 + (t1 - t0) * k / N
    pts[#pts + 1] = math.cos(th) * R0
    pts[#pts + 1] = math.sin(th) * R0
  end
  local ex, ey = math.cos(t1) * R0, math.sin(t1) * R0
  local sx, sy = math.cos(t0) * R0, math.sin(t0) * R0
  local psi0 = phi + math.pi
  local function wrap(x)
    while x > math.pi do x = x - 2 * math.pi end
    while x < -math.pi do x = x + 2 * math.pi end
    return x
  end
  local dE = wrap(math.atan2(ey - c1y, ex - c1x) - psi0)
  local dS = wrap(math.atan2(sy - c1y, sx - c1x) - psi0)
  for k = 1, N - 1 do
    local ps = psi0 + dE + (dS - dE) * k / N
    pts[#pts + 1] = c1x + math.cos(ps) * r
    pts[#pts + 1] = c1y + math.sin(ps) * r
  end
  local ok, tris = pcall(love.math.triangulate, pts)
  moonTris = ok and tris or {}
  return moonTris
end

function CCI.plane(cx, cy, u, a)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(math.pi / 4)
  love.graphics.scale(u * 1.05)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.rectangle("fill", -0.12, -1, 0.24, 2, 0.12, 0.12)
  love.graphics.polygon("fill", -0.1, -0.2, -1.0, 0.45, -1.0, 0.62, -0.1, 0.32)
  love.graphics.polygon("fill", 0.1, -0.2, 1.0, 0.45, 1.0, 0.62, 0.1, 0.32)
  love.graphics.polygon("fill", -0.08, 0.62, -0.5, 0.92, -0.5, 1.02, -0.08, 0.86)
  love.graphics.polygon("fill", 0.08, 0.62, 0.5, 0.92, 0.5, 1.02, 0.08, 0.86)
  love.graphics.pop()
end

function CCI.cell(cx, cy, u, a)
  love.graphics.setColor(1, 1, 1, a)
  local bw, gap = u * 0.34, u * 0.17
  local x0 = cx - (4 * bw + 3 * gap) / 2
  local bottom = cy + u * 0.85
  for i = 1, 4 do
    local h = u * (0.5 + (i - 1) * 0.4)
    love.graphics.rectangle("fill", x0 + (i - 1) * (bw + gap), bottom - h, bw, h, bw * 0.3, bw * 0.3)
  end
end

function CCI.wifi(cx, cy, u, a)
  love.graphics.setColor(1, 1, 1, a)
  local oy = cy + u * 0.68
  love.graphics.setLineWidth(u * 0.24)
  for _, r in ipairs({0.6, 1.05, 1.5}) do
    love.graphics.arc("line", "open", cx, oy, u * r, -math.pi * 0.75, -math.pi * 0.25, 24)
  end
  love.graphics.setLineWidth(1)
  love.graphics.circle("fill", cx, oy, u * 0.17, 16)
end

function CCI.bt(cx, cy, u, a)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.setLineWidth(u * 0.2)
  love.graphics.line(
    cx - 0.6 * u, cy - 0.45 * u,
    cx + 0.6 * u, cy + 0.40 * u,
    cx,           cy + 0.95 * u,
    cx,           cy - 0.95 * u,
    cx + 0.6 * u, cy - 0.40 * u,
    cx - 0.6 * u, cy + 0.45 * u)
  love.graphics.setLineWidth(1)
end

function CCI.moon(cx, cy, u, a)
  local tris = moonTriangles()
  love.graphics.push()
  love.graphics.translate(cx - u * 0.1, cy + u * 0.1)
  love.graphics.scale(u * 0.95)
  love.graphics.setColor(1, 1, 1, a)
  for _, t in ipairs(tris) do
    love.graphics.polygon("fill", t)
  end
  love.graphics.pop()
end

function CCI.torch(cx, cy, u, a)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(u)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.polygon("fill", -0.55, -1, 0.55, -1, 0.36, -0.45, -0.36, -0.45)
  love.graphics.rectangle("fill", -0.36, -0.36, 0.72, 1.36, 0.16, 0.16)
  love.graphics.setColor(0, 0, 0, 0.3 * a)
  love.graphics.rectangle("fill", -0.09, -0.1, 0.18, 0.36, 0.09, 0.09)
  love.graphics.pop()
end

function CCI.rotate(cx, cy, u, a)
  love.graphics.setColor(1, 1, 1, a)
  local R = u * 0.95
  local s, e = math.rad(-55), math.rad(215)
  love.graphics.setLineWidth(u * 0.17)
  love.graphics.arc("line", "open", cx, cy, R, s, e, 40)
  love.graphics.setLineWidth(1)
  -- punta de flecha al final del arco (sentido horario)
  local ex, ey = cx + math.cos(e) * R, cy + math.sin(e) * R
  local tx, ty = -math.sin(e), math.cos(e)
  local nx, ny = math.cos(e), math.sin(e)
  love.graphics.polygon("fill",
    ex + tx * u * 0.42, ey + ty * u * 0.42,
    ex + nx * u * 0.30, ey + ny * u * 0.30,
    ex - nx * u * 0.30, ey - ny * u * 0.30)
  -- candado en el centro
  local ly = cy - u * 0.12
  love.graphics.rectangle("fill", cx - u * 0.34, ly, u * 0.68, u * 0.5, u * 0.1, u * 0.1)
  love.graphics.setLineWidth(u * 0.11)
  love.graphics.arc("line", "open", cx, ly, u * 0.2, math.pi, 2 * math.pi, 12)
  love.graphics.setLineWidth(1)
end

function CCI.battery(cx, cy, u, a, fill)
  love.graphics.setColor(1, 1, 1, a)
  local w, h = u * 1.75, u * 0.95
  local x, y = cx - w / 2 - u * 0.07, cy - h / 2
  love.graphics.setLineWidth(u * 0.14)
  love.graphics.rectangle("line", x, y, w, h, u * 0.26, u * 0.26)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("fill", x + w + u * 0.06, cy - u * 0.17, u * 0.13, u * 0.34, u * 0.05, u * 0.05)
  local pad = u * 0.26
  love.graphics.rectangle("fill", x + pad, y + pad, (w - 2 * pad) * (fill or 0.55), h - 2 * pad, u * 0.08, u * 0.08)
end

function CCI.sun(cx, cy, u, a)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.circle("fill", cx, cy, u * 0.42, 24)
  love.graphics.setLineWidth(u * 0.14)
  for i = 0, 7 do
    local th = i * math.pi / 4
    local c, s = math.cos(th), math.sin(th)
    love.graphics.line(cx + c * u * 0.66, cy + s * u * 0.66, cx + c * u * 0.95, cy + s * u * 0.95)
  end
  love.graphics.setLineWidth(1)
end

function CCI.speaker(cx, cy, u, a)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.push()
  love.graphics.translate(cx - u * 0.15, cy)
  love.graphics.scale(u)
  love.graphics.rectangle("fill", -0.85, -0.3, 0.45, 0.6)
  love.graphics.polygon("fill", -0.45, -0.3, 0.1, -0.75, 0.1, 0.75, -0.45, 0.3)
  love.graphics.pop()
  love.graphics.setLineWidth(u * 0.14)
  love.graphics.arc("line", "open", cx + u * 0.05, cy, u * 0.45, -math.pi * 0.3, math.pi * 0.3, 12)
  love.graphics.arc("line", "open", cx + u * 0.05, cy, u * 0.85, -math.pi * 0.3, math.pi * 0.3, 12)
  love.graphics.setLineWidth(1)
end

function CCI.lock(cx, cy, u, a, open)
  love.graphics.setColor(1, 1, 1, a)
  local bw, bh = u * 1.15, u * 0.9
  local by = cy - bh / 2 + u * 0.3
  love.graphics.rectangle("fill", cx - bw / 2, by, bw, bh, u * 0.16, u * 0.16)
  love.graphics.setLineWidth(u * 0.17)
  local sr = u * 0.36
  if open then
    local sy = by - u * 0.48
    love.graphics.arc("line", "open", cx, sy, sr, math.pi, 2 * math.pi, 16)
    love.graphics.line(cx - sr, sy, cx - sr, by)
    love.graphics.line(cx + sr, sy, cx + sr, by - u * 0.3)
  else
    local sy = by - u * 0.2
    love.graphics.arc("line", "open", cx, sy, sr, math.pi, 2 * math.pi, 16)
    love.graphics.line(cx - sr, sy, cx - sr, by)
    love.graphics.line(cx + sr, sy, cx + sr, by)
  end
  love.graphics.setLineWidth(1)
end

-- mismo orden que ccNames
local CC_ICON = {CCI.plane, CCI.cell, CCI.wifi, CCI.bt, CCI.moon, CCI.torch, CCI.rotate, CCI.battery}

-- barra diagonal cuando Datos / Wi-Fi / Bluetooth están apagados
local function slashMark(cx, cy, u, a)
  love.graphics.setLineWidth(u * 0.42)
  love.graphics.setColor(0, 0, 0, 0.28 * a)
  love.graphics.line(cx - u * 0.9, cy - u * 0.9, cx + u * 0.9, cy + u * 0.9)
  love.graphics.setLineWidth(u * 0.16)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.line(cx - u * 0.9, cy - u * 0.9, cx + u * 0.9, cy + u * 0.9)
  love.graphics.setLineWidth(1)
end

-- centro de control
local ccCache, ccCacheW, ccCacheH
local function ccGeom()
  if ccCache and ccCacheW == W and ccCacheH == H then return ccCache end
  local gap = 12 * U
  local tw = (W - 40 * U - 3 * gap) / 4
  local tiles = {}
  for i = 1, 8 do
    local c, r = (i - 1) % 4, math.floor((i - 1) / 4)
    tiles[i] = {x = 20 * U + c * (tw + gap), y = 70 * U + r * (tw + gap), w = tw, h = tw}
  end
  local sy = 70 * U + 2 * (tw + gap) + 8 * U
  local sliders = {}
  for i = 1, 2 do
    sliders[i] = {x = 20 * U, y = sy + (i - 1) * (64 * U + gap), w = W - 40 * U, h = 64 * U}
  end
  ccCache, ccCacheW, ccCacheH = {tiles = tiles, sliders = sliders}, W, H
  return ccCache
end

local function setSlider(i, x)
  local s = ccGeom().sliders[i]
  ccVal[i] = clamp((x - s.x) / s.w, 0, 1)
  if i == 2 then
    love.audio.setVolume(ccVal[2])
  end
end

local function toggleTile(i, silent)
  buzz(0.01)
  ccOn[i] = not ccOn[i]
  if i == 1 and ccOn[1] then
    ccOn[2], ccOn[3], ccOn[4] = false, false, false
  elseif (i == 2 or i == 3 or i == 4) and ccOn[i] then
    ccOn[1] = false
  end
  if not silent then
    local fn = CC_ICON[i]
    island.notify({
      iconfn = function(cx, cy, u, a) if fn then fn(cx, cy, u, a) end end,
      name = ccNames[i],
      sub = ccOn[i] and "Activado" or "Desactivado",
      dot = ccOn[i] and ccColors[i] or {0.5, 0.5, 0.55},
    })
  end
end

local function drawCC()
  local p = ccP
  if p < 0.01 then return end

  -- fondo desenfocado
  drawGlass(c8, -2, -2, W + 4, H + 4, 0,
    {alpha = p, blur = 5, refr = 0, rim = 1, glow = 0, tint = {0.02, 0.02, 0.06, 0.30}})

  local yo = (p - 1) * 40 * U
  local g = ccGeom()

  for i, t in ipairs(g.tiles) do
    local sc = (ccPress and ccPress.i == i) and 0.92 or 1
    local cx, cy = t.x + t.w / 2, t.y + t.h / 2 + yo
    local w, h = t.w * sc, t.h * sc
    local tint
    if ccOn[i] then
      local c = ccColors[i]
      tint = {c[1], c[2], c[3], 0.62}
    else
      tint = {1, 1, 1, 0.10}
    end
    drawGlass(c8, cx - w / 2, cy - h / 2, w, h, 22 * U * sc,
      {alpha = p, blur = 3, refr = 9, rim = 14, tint = tint})
  end

  for i, s in ipairs(g.sliders) do
    drawGlass(c8, s.x, s.y + yo, s.w, s.h, s.h / 2,
      {alpha = p, blur = 3, refr = 8, rim = 12, tint = {1, 1, 1, 0.10}})
    local fw = math.max(s.h, s.w * ccVal[i])
    drawGlass(c8, s.x, s.y + yo, fw, s.h, s.h / 2,
      {alpha = p, blur = 3, refr = 8, rim = 12, tint = {1, 1, 1, 0.50}})
  end

  love.graphics.push()
  love.graphics.translate(0, yo)

  love.graphics.setFont(fonts.ccTime)
  love.graphics.setColor(1, 1, 1, p)
  love.graphics.print(os.date("%H:%M"), 20 * U, 24 * U)

  love.graphics.setFont(fonts.ccLabel)
  local lh = fonts.ccLabel:getHeight()
  for i, t in ipairs(g.tiles) do
    local _, lines = fonts.ccLabel:getWrap(ccNames[i], t.w - 6 * U)
    local shift = (math.max(1, #lines) - 1) * lh * 0.5
    local cx = t.x + t.w / 2
    local fn = CC_ICON[i]
    if fn then
      local icy = t.y + 27 * U - shift
      fn(cx, icy, 13 * U, ccOn[i] and p or p * 0.85)
      if not ccOn[i] and (i == 2 or i == 3 or i == 4) then
        slashMark(cx, icy, 13 * U, p)
      end
    end
    love.graphics.setColor(1, 1, 1, p)
    love.graphics.printf(ccNames[i], t.x + 3 * U, t.y + 49 * U - shift, t.w - 6 * U, "center")
  end

  local sNames = {"Brillo", "Volumen"}
  local sIcons = {CCI.sun, CCI.speaker}
  love.graphics.setFont(fonts.ccSlider)
  for i, s in ipairs(g.sliders) do
    sIcons[i](s.x + 30 * U, s.y + s.h / 2, 10 * U, p)
    love.graphics.setColor(1, 1, 1, p)
    love.graphics.print(string.format("%s  %d%%", sNames[i], math.floor(ccVal[i] * 100 + 0.5)),
      s.x + 54 * U, s.y + (s.h - fonts.ccSlider:getHeight()) / 2)
  end

  love.graphics.pop()
end

-- dynamic island
-- tamaño objetivo según el modo (idle = píldora, notice = aviso, card = tarjeta)
local function islandTarget()
  if island.mode == "card" then
    return W - 24 * U, 146 * U
  elseif island.mode == "notice" and island.notice then
    local n = island.notice
    if n.name then
      local tw = math.max(fonts.isl:getWidth(n.name), fonts.islS:getWidth(n.sub or ""))
      local w = 16 * U + 26 * U + 10 * U + tw + 12 * U + (n.dot and 14 * U or 0) + 16 * U
      return math.min(W - 24 * U, math.max(w, 150 * U)), 46 * U
    end
    return 132 * U, 38 * U
  end
  return 118 * U, 34 * U
end

function island.setMode(m)
  island.mode = m
  island.modeT = 0
  island.cardT = 0
end

-- n = {iconfn = function(cx, cy, u, alpha, t), name = "...", sub = "...", dot = {r,g,b}, dur = seg}
-- sin name: muestra solo el ícono centrado
function island.notify(n)
  if not ISLAND_ENABLED then return end
  island.notice = n
  island.noticeT = 0
  island.noticeDur = n.dur or 2.2
  island.setMode("notice")
end

function island.update(dt)
  if not ISLAND_ENABLED or not fonts.isl then return end
  island.modeT = island.modeT + dt
  if island.mode == "notice" then
    island.noticeT = island.noticeT + dt
    if island.noticeT >= island.noticeDur then island.setMode("idle") end
  elseif island.mode == "card" then
    island.cardT = island.cardT + dt
    if island.cardT >= 7 and not island.touch then island.setMode("idle") end
  end

  local tw, th = islandTarget()
  if island.w <= 0 then island.w, island.h = tw, th end
  -- resorte con un poco de rebote
  local k, c = 280, 21
  local e = math.exp(-c * dt)
  island.wv = (island.wv + (tw - island.w) * k * dt) * e
  island.w = island.w + island.wv * dt
  island.hv = (island.hv + (th - island.h) * k * dt) * e
  island.h = island.h + island.hv * dt
end

function island.rect()
  local tw, th = islandTarget()
  local w, h = (island.w > 0) and island.w or tw, (island.h > 0) and island.h or th
  return (W - w) / 2, ISLAND_TOP * U, w, h
end

-- botones rápidos de la tarjeta (índices de ccNames)
function island.cardButtons()
  local tw, th = W - 24 * U, 146 * U
  local x0, y0 = (W - tw) / 2, ISLAND_TOP * U
  local idx = {1, 3, 4, 6}
  local r = 21 * U
  local span = tw - 40 * U - 2 * r
  local out = {}
  for k, i in ipairs(idx) do
    out[k] = {i = i, cx = x0 + 20 * U + r + span * (k - 1) / (#idx - 1), cy = y0 + th - 32 * U, r = r}
  end
  return out
end

function island.buttonAt(x, y)
  for _, b in ipairs(island.cardButtons()) do
    local dx, dy = x - b.cx, y - b.cy
    if dx * dx + dy * dy <= (b.r + 6 * U) ^ 2 then return b.i end
  end
end

function island.press(id, x, y)
  if not ISLAND_ENABLED or island.touch then return false end
  if ccP > 0.02 or ccTarget == 1 or ccDrag or lockDrag then return false end
  local x0, y0, w, h = island.rect()
  local pad = (island.mode == "card") and 0 or 8 * U
  if x >= x0 - pad and x <= x0 + w + pad and y >= y0 - pad and y <= y0 + h + pad then
    island.touch = {id = id, sx = x, sy = y, moved = 0}
    return true
  end
  if island.mode == "card" then island.setMode("idle") end
  return false
end

function island.move(id, x, y)
  local t = island.touch
  if t and t.id == id then
    t.moved = math.max(t.moved, math.abs(x - t.sx), math.abs(y - t.sy))
    return true
  end
  return false
end

function island.release(id, x, y)
  local t = island.touch
  if not t or t.id ~= id then return false end
  island.touch = nil
  if island.mode == "card" then
    if t.sy - y > 25 * U then
      island.setMode("idle")
    elseif t.moved < 10 * U then
      local b = island.buttonAt(x, y)
      if b then
        toggleTile(b, true)
        island.cardT = 0
      else
        island.setMode("idle")
      end
    end
  elseif t.moved < 10 * U or y - t.sy > 25 * U then
    island.setMode("card")
    buzz(0.01)
  end
  return true
end

function island.draw()
  if not ISLAND_ENABLED or island.w <= 0 or not fonts.isl then return end
  local w, h = math.max(island.w, 24 * U), math.max(island.h, 20 * U)
  local x, y = (W - w) / 2, ISLAND_TOP * U
  local r = math.min(h / 2, 34 * U)

  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle("fill", x, y, w, h, r, r)
  love.graphics.setColor(1, 1, 1, 0.08)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, r, r)

  local a
  if island.mode == "idle" then
    a = clamp((island.modeT - 0.15) / 0.2, 0, 1)
  else
    a = clamp((island.modeT - 0.08) / 0.15, 0, 1)
  end
  if a <= 0 then return end
-- sin setScissor: el contenido aparece recién cuando la isla casi llegó a su tamaño final
  local tw, th = islandTarget()
  a = a * clamp((math.min(w / tw, h / th) - 0.82) / 0.16, 0, 1)
  if a <= 0 then return end

  if island.mode == "idle" then
    -- cámara frontal
    local cx, cy = x + w - 20 * U, y + h / 2
    love.graphics.setColor(0.07, 0.07, 0.10, a)
    love.graphics.circle("fill", cx, cy, 5.5 * U, 24)
    love.graphics.setColor(0.12, 0.14, 0.26, a)
    love.graphics.circle("fill", cx, cy, 3.2 * U, 24)
    love.graphics.setColor(0.55, 0.65, 1.0, 0.6 * a)
    love.graphics.circle("fill", cx - 1 * U, cy - 1 * U, 0.9 * U, 12)

  elseif island.mode == "notice" and island.notice then
    local n = island.notice
    if n.name then
      if n.iconfn then n.iconfn(x + 29 * U, y + h / 2, 11 * U, a, island.noticeT) end
      local lh1, lh2 = fonts.isl:getHeight(), fonts.islS:getHeight()
      local ty = y + (h - lh1 - lh2) / 2
      local tx = x + 52 * U
      love.graphics.setFont(fonts.isl)
      love.graphics.setColor(1, 1, 1, a)
      love.graphics.print(n.name, tx, ty)
      love.graphics.setFont(fonts.islS)
      love.graphics.setColor(1, 1, 1, 0.55 * a)
      love.graphics.print(n.sub or "", tx, ty + lh1)
      if n.dot then
        love.graphics.setColor(n.dot[1], n.dot[2], n.dot[3], a)
        love.graphics.circle("fill", x + w - 21 * U, y + h / 2, 5 * U, 20)
      end
    elseif n.iconfn then
      n.iconfn(x + w / 2, y + h / 2, 11 * U, a, island.noticeT)
    end

  elseif island.mode == "card" then
    local tw = W - 24 * U
    local cx0 = (W - tw) / 2
    local t = os.date("*t")
    love.graphics.setFont(fonts.islBig)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.print(os.date("%H:%M"), cx0 + 20 * U, y + 10 * U)
    love.graphics.setFont(fonts.islMed)
    love.graphics.setColor(1, 1, 1, 0.6 * a)
    love.graphics.print(string.format("%s %d de %s", DAYS[t.wday], t.day, MONTHS[t.month]),
      cx0 + 22 * U, y + 10 * U + fonts.islBig:getHeight() - 4 * U)

    local okp, _, pct = pcall(love.system.getPowerInfo)
    if okp and pct then
      CCI.battery(cx0 + tw - 32 * U, y + 28 * U, 10 * U, a, clamp(pct / 100, 0, 1))
      love.graphics.setFont(fonts.islMed)
      love.graphics.setColor(1, 1, 1, 0.85 * a)
      love.graphics.printf(pct .. "%", cx0 + tw - 120 * U, y + 19 * U, 70 * U, "right")
    end

    for _, b in ipairs(island.cardButtons()) do
      if ccOn[b.i] then
        local c = ccColors[b.i]
        love.graphics.setColor(c[1], c[2], c[3], 0.95 * a)
      else
        love.graphics.setColor(1, 1, 1, 0.16 * a)
      end
      love.graphics.circle("fill", b.cx, b.cy, b.r, 32)
      local fn = CC_ICON[b.i]
      if fn then fn(b.cx, b.cy, b.r * 0.5, a) end
    end
  end

end

function love.draw()
  drawBackground()

  -- escena completa a un canvas
  love.graphics.setCanvas(sceneCanvas)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(bgCanvas, 0, 0)

  ha = (1 - prog) * lockP
  drawDockGlass(ha)

  love.graphics.push()
  love.graphics.translate(W / 2, H / 2)
  love.graphics.scale((1 + 0.08 * prog) * (0.94 + 0.06 * lockP))
  love.graphics.translate(-W / 2, -H / 2)
  drawHome()
  love.graphics.pop()

  ha = 1
  if current then
    drawWindow()
  end
  if lockP < 1 then
    drawLock()
  end
  love.graphics.setCanvas()

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(sceneCanvas, 0, 0)

  -- capas de vidrio encima
  if dialogP > 0.01 or ccP > 0.01 then
    blurScene()
  end
  if current then
    drawDialog()
  end
  drawCC()
  island.draw()

  if ccVal[1] < 1 then
    love.graphics.setColor(0, 0, 0, (1 - ccVal[1]) * 0.7)
    love.graphics.rectangle("fill", 0, 0, W, H)
  end

  if shaderErr then
    love.graphics.setFont(fonts.label)
    love.graphics.setColor(1, 0.4, 0.4, 1)
    love.graphics.printf(string.sub(shaderErr, 1, 300), 8 * U, 40 * U, W - 16 * U, "left")
  end
end

function love.update(dt)
  if ccOn[8] then love.timer.sleep(math.max(0, 1 / 30 - dt)) end
  dt = math.min(dt, 0.05)
  for _, a in ipairs(apps) do
    if a.update then a.update(dt) end
  end
  island.update(dt)

  dialogP = dialogP + (dialogTarget - dialogP) * (1 - math.exp(-dt * 16))
  if math.abs(dialogP - dialogTarget) < 0.002 then
    dialogP = dialogTarget
  end

  if not ccDrag then
    ccP = ccP + (ccTarget - ccP) * (1 - math.exp(-dt * 16))
    if math.abs(ccP - ccTarget) < 0.002 then
      ccP = ccTarget
    end
  end

  if lockDrag then return end

  lockP = lockP + (lockTarget - lockP) * (1 - math.exp(-dt * 12))
  if math.abs(lockP - lockTarget) < 0.002 then
    lockP = lockTarget
  end

  if target ~= 1 then
    dialogTarget = 0
  end

  if swipe then return end

  prog = prog + (target - prog) * (1 - math.exp(-dt * 14))
  if math.abs(prog - target) < 0.002 then
    prog = target
    if target == 0 then
      current = nil
    elseif current and not opened then
      local a = apps[current]
      if a.url then
        if ASK_BEFORE_OPEN then
          dialogTarget = 1
        else
          opened = true
          love.system.openURL(a.url)
        end
      end
    end
  end
end

local function hit(a, x, y)
  return x >= a.x and x <= a.x + a.s and y >= a.y and y <= a.y + a.s
end

local function ccPressed(id, x, y)
  local g = ccGeom()
  for i, t in ipairs(g.tiles) do
    if inrect(t, x, y) then
      ccPress = {i = i, id = id}
      return
    end
  end
  for i, s in ipairs(g.sliders) do
    if inrect(s, x, y) then
      ccSlider = {id = id, i = i}
      setSlider(i, x)
      return
    end
  end
  ccClose = {id = id, sy = y, moved = 0, up = 0}
end

-- entrada de Ajustes
local sDrag, sSlider = nil, nil

local function sliderFromX(r, x)
  local v = clamp((x - 36 * U) / (W - 72 * U), 0, 1)
  ccVal[r.i] = v
  if r.i == 2 then love.audio.setVolume(v) end
end

local function settingsRowAt(x, y)
  local top, vh = setViewport()
  if y < top or y > top + vh then return nil end
  setLayout()
  for _, r in ipairs(SROWS) do
    local ry = top + r.y - setScroll
    if y >= ry and y <= ry + r.h then return r end
  end
  return nil
end

local function settingsActivate(r, x)
  if r.k == "tog" then
    if r.ask then
      ASK_BEFORE_OPEN = not ASK_BEFORE_OPEN
      buzz(0.01)
    elseif r.island then
      ISLAND_ENABLED = not ISLAND_ENABLED
      island.notice = nil
      island.setMode("idle")
      buzz(0.01)
    else
      toggleTile(r.i)
    end
    saveSettings()
  elseif r.k == "theme" then
    for i = 1, #themes do
      local cx = 36 * U + (i - 1) * 44 * U + 14 * U
      if math.abs(x - cx) < 22 * U then
        applyTheme(i)
        buzz(0.01)
        saveSettings()
        break
      end
    end
  end
end

local function settingsPress(id, x, y)
  local r = settingsRowAt(x, y)
  if r and r.k == "sld" then
    sSlider = {id = id, r = r}
    sliderFromX(r, x)
  else
    sDrag = {id = id, sy = y, s0 = setScroll, moved = 0}
  end
end

local function settingsMove(id, x, y)
  if sSlider and sSlider.id == id then
    sliderFromX(sSlider.r, x)
    return true
  end
  if sDrag and sDrag.id == id then
    sDrag.moved = math.max(sDrag.moved, math.abs(sDrag.sy - y))
    if sDrag.moved > 8 * U then
      local _, vh = setViewport()
      local total = setLayout()
      setScroll = clamp(sDrag.s0 + (sDrag.sy - y), 0, math.max(0, total - vh))
    end
    return true
  end
  return false
end

local function settingsRelease(id, x, y)
  if sSlider and sSlider.id == id then
    sSlider = nil
    saveSettings()
    return true
  end
  if sDrag and sDrag.id == id then
    local d = sDrag
    sDrag = nil
    if d.moved < 10 * U then
      local r = settingsRowAt(x, y)
      if r then settingsActivate(r, x) end
    end
    return true
  end
  return false
end

function love.wheelmoved(dx, dy)
  if current and apps[current].settings and prog > 0.85 then
    local _, vh = setViewport()
    local total = setLayout()
    setScroll = clamp(setScroll - dy * 40 * U, 0, math.max(0, total - vh))
  end
end

local function pointerPressed(id, x, y)
  if island.press(id, x, y) then return end
  if locked then
    if not lockDrag then
      lockDrag = {id = id, sy = y, ly = y, lt = love.timer.getTime(), v = 0}
    end
    return
  end

  if ccP > 0.02 or ccTarget == 1 or ccDrag then
    if ccP > 0.6 and ccTarget == 1 then
      ccPressed(id, x, y)
    end
    return
  end

  if y < 60 * U and x > W * 0.5 then
    ccDrag = {id = id, sy = y, ly = y, lt = love.timer.getTime(), v = 0}
    return
  end

  if current then
    if dialogTarget == 1 and dialogP > 0.6 then
      local b = dialogHit(x, y)
      if b then
        dpress, dpressId = b, id
        return
      end
    end
    if prog > 0.85 and y > H - 90 * U then
      swipe = {id = id, sy = y, moved = 0}
    elseif apps[current].settings and prog > 0.85 then
      settingsPress(id, x, y)
    elseif apps[current].press and prog > 0.85 then
      apps[current].press(id, x, y)
    end
    return
  end
  for i, a in ipairs(apps) do
    if hit(a, x, y) then
      pressed, pressedId = i, id
      return
    end
  end
end

local function pointerMoved(id, x, y)
  if island.move(id, x, y) then return end
  if settingsMove(id, x, y) then return end
  local ap = current and apps[current]
  if ap and ap.move and ap.move(id, x, y) then return end
  if ccDrag and ccDrag.id == id then
    local now = love.timer.getTime()
    local dt = now - ccDrag.lt
    if dt > 0 then
      ccDrag.v = (y - ccDrag.ly) / dt
    end
    ccDrag.ly, ccDrag.lt = y, now
    if ccDrag.closing then
      ccP = clamp(1 + (y - ccDrag.sy) / (H * 0.45), 0, 1)
    else
      ccP = clamp((y - ccDrag.sy) / (H * 0.45), 0, 1)
    end
    ccTarget = ccP
    return
  end
  if ccSlider and ccSlider.id == id then
    setSlider(ccSlider.i, x)
    return
  end
  if ccClose and ccClose.id == id then
    ccClose.moved = math.max(ccClose.moved, math.abs(ccClose.sy - y))
    ccClose.up = ccClose.sy - y
    if ccClose.up > 10 * U then
      -- se promueve a arrastre: el panel sigue al dedo
      ccDrag = {id = id, sy = ccClose.sy, ly = y, lt = love.timer.getTime(), v = 0, closing = true}
      ccClose = nil
    end
    return
  end

  if lockDrag and lockDrag.id == id then
    local now = love.timer.getTime()
    local dt = now - lockDrag.lt
    if dt > 0 then
      lockDrag.v = (lockDrag.ly - y) / dt
    end
    lockDrag.ly, lockDrag.lt = y, now
    lockP = clamp((lockDrag.sy - y) / (H * 0.6), 0, 1)
    lockTarget = lockP
    return
  end
  if swipe and swipe.id == id then
    swipe.moved = math.max(swipe.moved, math.abs(swipe.sy - y))
    local d = clamp((swipe.sy - y) / (H * 0.6), 0, 1)
    prog = 1 - d * 0.85
    target = prog
  end
  if pressed and pressedId == id and not hit(apps[pressed], x, y) then
    pressed, pressedId = nil, nil
  end
end

local function pointerReleased(id, x, y)
  if island.release(id, x, y) then return end
  if settingsRelease(id, x, y) then return end
  local ap = current and apps[current]
  if ap and ap.release and ap.release(id, x, y) then return end
  if ccDrag and ccDrag.id == id then
    if ccDrag.closing then
      ccTarget = (ccP > 0.65 and ccDrag.v > -1200 * U) and 1 or 0
    elseif ccP > 0.35 or ccDrag.v > 1200 * U then
      ccTarget = 1
    else
      ccTarget = 0
    end
    ccDrag = nil
    return
  end
  if ccSlider and ccSlider.id == id then
    local si = ccSlider.i
    ccSlider = nil
    island.notify({
      iconfn = function(cx, cy, u, a) (si == 1 and CCI.sun or CCI.speaker)(cx, cy, u, a) end,
      name = si == 1 and "Brillo" or "Volumen",
      sub = math.floor(ccVal[si] * 100 + 0.5) .. "%",
      dur = 1.6,
    })
    return
  end
  if ccPress and ccPress.id == id then
    local t = ccGeom().tiles[ccPress.i]
    if inrect(t, x, y) then
      toggleTile(ccPress.i)
    end
    ccPress = nil
    return
  end
  if ccClose and ccClose.id == id then
    if ccClose.up > 20 * U or ccClose.moved < 10 * U then
      ccTarget = 0
    end
    ccClose = nil
    return
  end

  if lockDrag and lockDrag.id == id then
    if lockP > 0.3 or lockDrag.v > 1200 * U then
      lockTarget = 1
      locked = false
      buzz(0.015)
      island.notify({
        iconfn = function(cx, cy, u, a, t) CCI.lock(cx, cy, u, a, t > 0.25) end,
        dur = 1.3,
      })
    else
      lockTarget = 0
    end
    lockDrag = nil
    return
  end

  if dpress and dpressId == id then
    local p = dpress
    dpress, dpressId = nil, nil
    if dialogHit(x, y) == p and current then
      dialogTarget = 0
      if p == 1 then
        target = 0
      else
        opened = true
        local u = apps[current].url
        if u then love.system.openURL(u) end
      end
    end
    return
  end

  if swipe and swipe.id == id then
    if swipe.moved < 10 * U or prog < 0.8 then
      target = 0
    else
      target = 1
    end
    swipe = nil
    return
  end

  if pressed and pressedId == id then
    if hit(apps[pressed], x, y) then
      current = pressed
      target = 1
      opened = false
      setScroll = 0
    end
    pressed = nil
  end
end

function love.keypressed(key)
  if current and apps[current].key and apps[current].key(key) then return end
  if key == "escape" or key == "back" then
    if ccTarget == 1 or ccP > 0.02 then
      ccTarget = 0
    elseif current then
      target = 0
      dialogTarget = 0
    elseif not locked then
      locked = true
      lockTarget = 0
      island.notify({
        iconfn = function(cx, cy, u, a) CCI.lock(cx, cy, u, a, false) end,
        dur = 1.2,
      })
    end
  end
end

function love.textinput(t)
  local a = current and apps[current]
  if a and a.text and prog > 0.85 then a.text(t) end
end

-- touch (celular)
love.touchpressed  = pointerPressed
love.touchmoved    = pointerMoved
love.touchreleased = pointerReleased

-- mouse (PC): mismo comportamiento que un dedo; ignora el mouse emulado por touch
local mouseDown = false
function love.mousepressed(x, y, button, istouch)
  if istouch or button ~= 1 then return end
  mouseDown = true
  pointerPressed("mouse", x, y)
end
function love.mousemoved(x, y, dx, dy, istouch)
  if istouch or not mouseDown then return end
  pointerMoved("mouse", x, y)
end
function love.mousereleased(x, y, button, istouch)
  if istouch or button ~= 1 or not mouseDown then return end
  mouseDown = false
  pointerReleased("mouse", x, y)
end
