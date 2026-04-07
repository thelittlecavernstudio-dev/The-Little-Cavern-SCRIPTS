-- @description TLC Show plugin in Monitor FX slot 3
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Opens the floating window for the plugin in the 3rd slot of the Monitor FX chain.
-- @changelog
--   # Initial release
--   * Added direct access to Monitor FX slot 3.

function ShowMonitorFXByPosition()
    -- Definimos la posiciÃ³n (3Âª posiciÃ³n = Ã­ndice 2)
    local target_index = 2 
    
    local master_track = reaper.GetMasterTrack(0)
    
    -- Verificamos si existe un plugin en esa posiciÃ³n antes de intentar abrirlo
    local monitor_fx_count = reaper.TrackFX_GetRecCount(master_track)
    
    if target_index < monitor_fx_count then
        -- Aplicamos el offset 0x1000000 para Monitor FX
        local fx_idx = target_index + 0x1000000
        
        -- Modo 3: Abre la ventana flotante y la trae al frente
        reaper.TrackFX_Show(master_track, fx_idx, 3)
    else
        -- Opcional: Avisar si el slot estÃ¡ vacÃ­o
        -- reaper.ShowMessageBox("No hay ningÃºn plugin en el slot " .. (target_index + 1), "Aviso", 0)
    end
end

reaper.Undo_BeginBlock()
ShowMonitorFXByPosition()
reaper.Undo_EndBlock("Mostrar Monitor FX por posiciÃ³n", -1)
