-- @description TLC Create project markers from item cues
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Imports CUE and BWF metadata cues from selected items as project markers.
-- @changelog
--   # Initial release
--   * Added marker extraction from media items.

local item = reaper.GetSelectedMediaItem(0, 0)
if not item then return end

local take = reaper.GetActiveTake(item)
local source = reaper.GetMediaItemTake_Source(take)
local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

reaper.Undo_BeginBlock()

local encontrados = 0

-- Intentamos invocar la acciÃ³n nativa de REAPER que "explota" los marcadores del archivo
-- Esto suele forzar a REAPER a reconocerlos si estÃ¡n en el chunk CUE o BWF
reaper.Main_OnCommand(40920, 0) -- Item: Import item media cues as project markers

-- Si la acciÃ³n nativa no hace nada (a veces falla segÃºn la versiÃ³n), 
-- probamos este mÃ©todo manual de bajo nivel:
local i = 0
while true do
    local retval, key, val = reaper.GetMediaFileMetadata(source, i)
    if retval == 0 then break end
    
    -- Buscamos patrones de tiempo en los metadatos (ej: 0:00.040)
    if val:match("%d+:%d+%.%d+") then 
        -- Si encontramos una cadena de tiempo, intentamos convertirla
        local mins, secs = val:match("(%d+):(%d+%.%d+)")
        local total_secs = (tonumber(mins) * 60) + tonumber(secs)
        
        -- Buscamos la siguiente clave para el nombre
        local _, _, next_val = reaper.GetMediaFileMetadata(source, i + 1)
        reaper.AddProjectMarker(0, false, item_pos + total_secs, 0, next_val or "Cue", -1)
        encontrados = encontrados + 1
    end
    i = i + 1
end

reaper.UpdateTimeline()
reaper.Undo_EndBlock("Importar CUEs Forzado", -1)

if encontrados == 0 then
    reaper.ShowMessageBox("REAPER no estÃ¡ exponiendo los CUEs. Prueba esto:\n\n1. BotÃ³n derecho en el Item\n2. Item processing\n3. Import media cues from items as project markers", "Aviso", 0)
end
