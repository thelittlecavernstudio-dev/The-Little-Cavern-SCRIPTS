-- @description TLC Cycle through Monitor FX plugins
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Cycles through all plugins in the Monitor FX chain, showing one at a time.
-- @changelog
--   # Initial release
--   * Added cycling for Monitor FX plugins.

function CycleMonitorFXRobust()
    local master_track = reaper.GetMasterTrack(0)
    local monitor_fx_count = reaper.TrackFX_GetRecCount(master_track)
    
    if monitor_fx_count == 0 then return end

    -- 1. Recuperar el Ãºltimo Ã­ndice usado de la memoria de Reaper
    -- Si es la primera vez, el valor serÃ¡ nil
    local last_idx = reaper.GetExtState("LittleCavernStudio", "LastMonitorIndex")
    local current_idx

    if last_idx == "" then
        -- PRIMERA EJECUCIÃ“N: Empezamos por trueBalance (PosiciÃ³n 3 = Ãndice 2)
        current_idx = 2
    else
        -- SIGUIENTES: Sumamos 1 al anterior y hacemos el ciclo (0, 1, 2)
        current_idx = (tonumber(last_idx) + 1) % monitor_fx_count
    end

    -- 2. LIMPIEZA TOTAL: Cerramos todas las ventanas de Monitor FX primero
    -- Esto asegura que no se amontonen y que el foco sea real
    for i = 0, monitor_fx_count - 1 do
        reaper.TrackFX_Show(master_track, i + 0x1000000, 2) -- 2 = Ocultar
    end

    -- 3. ACTIVACIÃ“N: Abrimos el plugin que toca en este paso del ciclo
    -- 3 = Mostrar ventana flotante y traer al frente (Focus)
    reaper.TrackFX_Show(master_track, current_idx + 0x1000000, 3)

    -- 4. GUARDAR: Anotamos en la memoria quÃ© Ã­ndice hemos abierto
    reaper.SetExtState("LittleCavernStudio", "LastMonitorIndex", tostring(current_idx), false)
end

-- EjecuciÃ³n limpia
reaper.Undo_BeginBlock()
CycleMonitorFXRobust()
reaper.Undo_EndBlock("Ciclo Monitor FX Robusto", -1)
