-- @description TLC Maximize mixer window
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Forces the mixer window to a maximized state. Requires JS_API.
-- @changelog
--   # Initial release
--   * Added mixer window maximization.

function main()
    -- 1. Obtenemos el nombre localizado de "Mixer" (evita fallos si Reaper estÃ¡ en otro idioma)
    local mixer_name = reaper.JS_Localize("Mixer", "common")
    
    -- 2. Buscamos el "tirador" (handle) de la ventana del Mezclador
    local hwnd = reaper.JS_Window_Find(mixer_name, true)

    if hwnd then
        -- 3. Aplicamos el estado maximizado (SW_MAXIMIZE = 3)
        reaper.JS_Window_Show(hwnd, "MAXIMIZE")
    else
        -- Si no lo encuentra a la primera, lo abrimos y reintentamos una vez
        reaper.Main_OnCommand(40078, 0) -- View: Show mixer window
        local hwnd_retry = reaper.JS_Window_Find(mixer_name, true)
        if hwnd_retry then
            reaper.JS_Window_Show(hwnd_retry, "MAXIMIZE")
        end
    end
end

main()
