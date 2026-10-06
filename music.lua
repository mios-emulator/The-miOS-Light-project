-- music.lua - reproductor de música para miOS Next (usa love.audio.newSource)
-- Busca canciones en la carpeta "music/" (mp3, ogg, wav, flac). Si no hay ninguna,
-- genera una pista de prueba sintética para que el reproductor se pueda probar igual.
local M = {}

local okU, utf8 = pcall(require, "utf8")

M.tracks = {}
M.idx = 0              -- pista actual (0 = ninguna cargada todavía)
M.playing = false
M.pos, M.dur = 0, 0    -- posición y duración en segundos
M.pausedFor = 0        -- segundos que lleva en pausa (la isla se esconde pasado un rato)
M.hasFiles = false     -- true si encontró canciones reales en music/
M.onChange = nil       -- function(kind, track): "play", "pause" o "resume"
M.icons = {}

local MUSIC_DIR = "music"
local EXT = {mp3 = true, ogg = true, wav = true, flac = true}
local PAUSE_SHOW = 12
local src = nil
local interrupted = false

-- ============ utilidades ============
local function hsv(h, s, v)
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  i = i % 6
  if i == 0 then return v, t, p
  elseif i == 1 then return q, v, p
  elseif i == 2 then return p, v, t
  elseif i == 3 then return p, q, v
  elseif i == 4 then return t, p, v
  end
  return v, p, q
end

-- cada canción tiene un color propio, sacado del nombre
local function colorFor(name)
  local h = 0
  for k = 1, #name do h = (h * 31 + name:byte(k)) % 9973 end
  local r, g, b = hsv((h % 360) / 360, 0.55, 0.85)
  return {r, g, b}
end

-- "Artista - Título.mp3" -> título, artista
local function parseName(file)
  local base = (file:gsub("%.%w+$", ""))
  base = (base:gsub("_", " "))
  local a, t = base:match("^(.-)%s+%-%s+(.+)$")
  if a and a ~= "" then return t, a end
  return base, "Música"
end

local function addTrack(t)
  t.color = colorFor(t.title)
  M.tracks[#M.tracks + 1] = t
end

-- pista de prueba: arpegio simple de 12 segundos
local function makeDemo()
  local rate, secs = 16000, 12
  local n = rate * secs
  local sd = love.sound.newSoundData(n, rate, 16, 1)
  local scale = {261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25}
  local seq = {1, 3, 5, 8, 2, 4, 6, 8, 3, 5, 7, 8, 2, 4, 5, 6}
  local noteLen = 0.25
  local tau = 2 * math.pi
  for i = 0, n - 1 do
    local t = i / rate
    local k = math.floor(t / noteLen)
    local lt = t - k * noteLen
    local f = scale[seq[k % #seq + 1]]
    local env = math.exp(-7 * lt) * math.min(1, lt * 400)
    local v = (math.sin(tau * f * t) + 0.35 * math.sin(2 * tau * f * t)) * env
    -- bajo suave al comienzo de cada compás
    local bl = t % 1
    v = v + 0.5 * math.sin(tau * 130.81 * t) * math.exp(-3 * bl)
    sd:setSample(i, v * 0.28)
  end
  return sd
end

local function fire(kind)
  if M.onChange then pcall(M.onChange, kind, M.tracks[M.idx]) end
end

-- ============ control ============
function M.init()
  M.tracks, M.idx, M.playing, M.pos, M.dur = {}, 0, false, 0, 0
  src = nil
  local ok, items = pcall(love.filesystem.getDirectoryItems, MUSIC_DIR)
  if ok and items then
    table.sort(items)
    for _, f in ipairs(items) do
      local ext = f:match("%.(%w+)$")
      if ext and EXT[ext:lower()] then
        local info = love.filesystem.getInfo(MUSIC_DIR .. "/" .. f)
        if info and info.type == "file" then
          local title, artist = parseName(f)
          addTrack({title = title, artist = artist, path = MUSIC_DIR .. "/" .. f})
        end
      end
    end
  end
  M.hasFiles = #M.tracks > 0
  if not M.hasFiles then
    local okd, sd = pcall(makeDemo)
    if okd and sd then
      addTrack({title = "Tono de prueba", artist = "miOS Next", data = sd})
    end
  end
end

function M.current()
  return M.tracks[M.idx]
end

function M.play(i, tries)
  local t = M.tracks[i]
  if not t then return false end
  if src then pcall(src.stop, src) end
  src = nil
  local ok, s = pcall(function()
    if t.data then return love.audio.newSource(t.data) end
    return love.audio.newSource(t.path, "stream")
  end)
  if not ok or not s then
    -- archivo roto: probar con la siguiente (máximo una vuelta)
    t.bad = true
    tries = (tries or 0) + 1
    if tries < #M.tracks then return M.play(i % #M.tracks + 1, tries) end
    M.playing = false
    return false
  end
  src = s
  M.idx = i
  local okd, d = pcall(s.getDuration, s, "seconds")
  M.dur = (okd and type(d) == "number" and d > 0) and d or 0
  M.pos, M.pausedFor, interrupted = 0, 0, false
  local okp, res = pcall(s.play, s)
  M.playing = (okp and res ~= false) and true or false
  fire("play")
  return M.playing
end

function M.toggle()
  if not src then
    if #M.tracks == 0 then return end
    M.play(M.idx > 0 and M.idx or 1)
    return
  end
  if M.playing then
    pcall(src.pause, src)
    M.playing = false
    M.pausedFor = 0
    fire("pause")
  else
    if interrupted then
      pcall(src.seek, src, M.pos, "seconds")
      interrupted = false
    end
    local okp, res = pcall(src.play, src)
    M.playing = (okp and res ~= false) and true or false
    M.pausedFor = 0
    fire("resume")
  end
end

function M.next()
  if #M.tracks == 0 then return end
  M.play(M.idx % #M.tracks + 1)
end

function M.prev()
  if #M.tracks == 0 then return end
  -- pasados 3 segundos, "anterior" reinicia la canción (como en los reproductores reales)
  if src and M.dur > 0 and M.pos > 3 then
    M.seekFrac(0)
    return
  end
  local n = M.idx - 1
  if n < 1 then n = #M.tracks end
  M.play(n)
end

function M.seekFrac(f)
  if not src or M.dur <= 0 then return end
  f = math.max(0, math.min(1, f))
  local t = math.min(f * M.dur, M.dur - 0.05)
  pcall(src.seek, src, t, "seconds")
  M.pos = t
end

function M.progress()
  if M.dur <= 0 then return 0 end
  return math.max(0, math.min(1, M.pos / M.dur))
end

-- ¿la isla dinámica tiene que mostrar la música?
function M.active()
  return src ~= nil and (M.playing or M.pausedFor < PAUSE_SHOW)
end

function M.update(dt)
  if not src then return end
  if M.playing then
    if src:isPlaying() then
      M.pos = src:tell("seconds")
    else
      -- el source se detuvo solo: ¿terminó la canción o la cortó el sistema?
      if M.dur <= 0 or M.pos >= M.dur - 1 then
        M.next()
      else
        M.playing = false
        interrupted = true
        M.pausedFor = 0
      end
    end
  else
    M.pausedFor = M.pausedFor + dt
  end
end

-- ============ texto ============
function M.fmt(t)
  t = math.max(0, math.floor(t or 0))
  return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

-- recorta el texto con "…" para que entre en maxw (respeta UTF-8)
function M.fit(f, s, maxw)
  if f:getWidth(s) <= maxw then return s end
  if not okU then return s end
  local okl, len = pcall(utf8.len, s)
  if not okl or not len then return s end
  for n = len - 1, 1, -1 do
    local cut = utf8.offset(s, n + 1)
    local t = s:sub(1, cut - 1) .. "…"
    if f:getWidth(t) <= maxw then return t end
  end
  return "…"
end

-- ============ dibujo (todas reciben alpha explícito) ============
local function setcol(a, r, g, b)
  love.graphics.setColor(r or 1, g or 1, b or 1, a)
end

-- corchea de música centrada en (cx, cy); u = escala
function M.note(cx, cy, u, a)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(u)
  love.graphics.ellipse("fill", -0.3, 0.7, 0.42, 0.32, 20)
  love.graphics.rectangle("fill", 0.06, -0.95, 0.14, 1.62)
  love.graphics.polygon("fill", 0.2, -0.95, 0.85, -0.55, 0.85, -0.05, 0.2, -0.45)
  love.graphics.pop()
end

-- portada generada por código (cuadrado de color con una nota)
function M.cover(x, y, s, a, tr)
  local c = (tr and tr.color) or {0.38, 0.38, 0.46}
  love.graphics.setColor(c[1], c[2], c[3], a)
  love.graphics.rectangle("fill", x, y, s, s, s * 0.22, s * 0.22)
  love.graphics.setColor(1, 1, 1, 0.18 * a)
  love.graphics.rectangle("fill", x + s * 0.04, y + s * 0.03, s * 0.92, s * 0.34, s * 0.18, s * 0.18)
  M.note(x + s / 2, y + s / 2, s * 0.26, a)
end

-- ecualizador animado (quieto y bajito si está en pausa)
function M.bars(x, y, w, h, a, playing, color)
  local c = color or {1, 1, 1}
  local n = 4
  local gap = w * 0.12
  local bw = (w - gap * (n - 1)) / n
  local t = love.timer.getTime()
  love.graphics.setColor(c[1], c[2], c[3], a)
  for i = 1, n do
    local lv = 0.22
    if playing then
      lv = 0.30 + 0.70 * (0.5 + 0.5 * math.sin(t * (5.5 + i * 1.9) + i * 1.7))
    end
    local bh = math.max(bw, h * lv)
    love.graphics.rectangle("fill", x + (i - 1) * (bw + gap), y + (h - bh) / 2, bw, bh, bw / 2, bw / 2)
  end
end

function M.icons.play(cx, cy, u, a, r, g, b)
  setcol(a, r, g, b)
  love.graphics.polygon("fill", cx - 0.55 * u, cy - 0.85 * u, cx - 0.55 * u, cy + 0.85 * u, cx + 0.9 * u, cy)
end

function M.icons.pause(cx, cy, u, a, r, g, b)
  setcol(a, r, g, b)
  love.graphics.rectangle("fill", cx - 0.75 * u, cy - 0.85 * u, 0.55 * u, 1.7 * u, 0.12 * u, 0.12 * u)
  love.graphics.rectangle("fill", cx + 0.20 * u, cy - 0.85 * u, 0.55 * u, 1.7 * u, 0.12 * u, 0.12 * u)
end

function M.icons.next(cx, cy, u, a, r, g, b)
  setcol(a, r, g, b)
  love.graphics.polygon("fill", cx - 0.9 * u, cy - 0.75 * u, cx - 0.9 * u, cy + 0.75 * u, cx + 0.4 * u, cy)
  love.graphics.rectangle("fill", cx + 0.5 * u, cy - 0.75 * u, 0.28 * u, 1.5 * u, 0.08 * u, 0.08 * u)
end

function M.icons.prev(cx, cy, u, a, r, g, b)
  setcol(a, r, g, b)
  love.graphics.polygon("fill", cx + 0.9 * u, cy - 0.75 * u, cx + 0.9 * u, cy + 0.75 * u, cx - 0.4 * u, cy)
  love.graphics.rectangle("fill", cx - 0.78 * u, cy - 0.75 * u, 0.28 * u, 1.5 * u, 0.08 * u, 0.08 * u)
end

return M
