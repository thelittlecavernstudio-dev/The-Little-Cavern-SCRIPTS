-- @description TLC Rename "Stereo Out" tracks to match track #1
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Renames tracks named "Stereo Out" to the name of the first track in the project.
-- @changelog
--   # Initial release
--   * Added track renaming based on track #1.

local src_track = reaper.GetTrack(0, 0) -- Obtiene la pista 1 (Ã­ndice 0)

if src_track then
    -- Obtener el nombre de la pista de origen
    local _, src_name = reaper.GetSetMediaTrackInfo_String(src_track, 'P_NAME', '', false)
    
    -- Recorrer todas las pistas
    for i = 0, reaper.CountTracks(0) - 1 do
        local dest_track = reaper.GetTrack(0, i)
        local _, dest_name = reaper.GetSetMediaTrackInfo_String(dest_track, 'P_NAME', '', false)
        
        -- USAMOS string.upper para que no importe si es "Stereo Out", "STEREO OUT" o "stereo out"
        -- USAMOS string.match para que funcione incluso si hay espacios accidentales
        if dest_name:upper():gsub("%s+", "") == "STEREOOUT" then
            reaper.GetSetMediaTrackInfo_String(dest_track, 'P_NAME', src_name, true)
            reaper.TrackList_AdjustWindows(false) -- Refresca la interfaz de Reaper
            break
        end
    end
else
    reaper.ShowConsoleMsg("Error: No se encontrÃ³ la pista 1.")
end
