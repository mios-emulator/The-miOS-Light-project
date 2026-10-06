-- conf.lua - ventana con proporción de celular para probar en PC
function love.conf(t)
    t.identity = "mios_next"
    t.window.title = "miOS Next"
    t.window.fullscreen = true
    t.window.fullscreentype = "desktop"
    t.window.width = 390
    t.window.height = 844
    t.window.minwidth = 280
    t.window.minheight = 560
    t.window.resizable = true
    t.window.vsync = 1
end
-- nota: podés también cambiar el VSync a 0 para que sea de unlock fps
