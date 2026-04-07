-- @description TLC Track on middle of MCP
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about
--   # Mixer Centering
--   * Centers the selected track in the Mixer Control Panel (MCP) using a visual offset.
--   # Background Monitoring
--   * Runs in the background and monitors track selection changes.
--   # Offset
--   * Uses a customizable offset to position the selected track in the mixer view.
--   # Visual Context
--   * Calculates the scroll position based on the selection.
-- @changelog
--   # Initial Release
--   * Centers the selected track in the Mixer Control Panel (MCP).
--   * Background process monitors track selection and adjusts mixer scroll.

local last_track = nil
local offset = 7 -- Ajustado por el usuario para centrado perfecto

function center_mcp_final()
    local selected_track = reaper.GetSelectedTrack(0, 0)
    
    -- Solo actuamos si la selección cambia y no es nula
    if selected_track and selected_track ~= last_track then
        -- Obtenemos el número de orden de la pista (1-based)
        local track_index = reaper.GetMediaTrackInfo_Value(selected_track, "IP_TRACKNUMBER")
        
        -- Calculamos la pista "objetivo" para el scroll (offset pistas atrás)
        local target_index = track_index - offset
        
        if target_index < 1 then 
            target_index = 1 
        end
        
        local target_track = reaper.GetTrack(0, target_index - 1)
        
        if target_track then
            -- Forzamos el scroll a la pista compensada
            reaper.SetMixerScroll(target_track)
        else
            -- Si no hay pista previa suficiente, hacemos scroll a la seleccionada
            reaper.SetMixerScroll(selected_track)
        end
        
        last_track = selected_track
    end
    
    reaper.defer(center_mcp_final)
end

-- Iniciar el proceso en segundo plano
center_mcp_final()
