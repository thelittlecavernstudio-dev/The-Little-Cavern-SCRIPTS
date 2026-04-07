-- @description TLC Copy and paste focused FX to a specific position
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Copies the focused FX or container from one track to selected tracks at a specified position.
-- @changelog
--   # Initial release
--   * Added support for copying focused FX or containers to a target position.

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- 1. Obtener el FX seleccionado/enfocado actualmente
local _, track_idx, item_idx, fx_idx = reaper.GetFocusedFX()

if track_idx == 0 or item_idx ~= -1 then
    reaper.ShowMessageBox("Selecciona un plugin en una ventana de FX primero.", "Error", 0)
    reaper.Undo_EndBlock("Error foco FX", -1)
    return
end

local src_track = reaper.GetTrack(0, track_idx - 1)
local _, fx_name = reaper.TrackFX_GetFXName(src_track, fx_idx, "")

-- 2. Pedir posiciÃ³n (VacÃ­o o 0 = Al final)
local retval, user_input = reaper.GetUserInputs("Copiar: " .. fx_name, 1, "PosiciÃ³n (Vacio = final):", "")

if not retval then 
    reaper.Undo_EndBlock("Cancelar", -1) 
    return 
end

local dest_pos = tonumber(user_input)

-- 3. LÃ³gica para detectar Containers
local function is_fx_container(track, idx)
    local ret, val = reaper.TrackFX_GetNamedConfigParm(track, idx, "container_count")
    return ret and tonumber(val) and tonumber(val) > 0
end

local fx_indices_to_copy = {fx_idx}
if is_fx_container(src_track, fx_idx) then
    local total_fx = reaper.TrackFX_GetCount(src_track)
    local i = fx_idx + 1
    while i < total_fx and not is_fx_container(src_track, i) do
        table.insert(fx_indices_to_copy, i)
        i = i + 1
    end
end

-- 4. Procesar pistas seleccionadas
local num_sel_tracks = reaper.CountSelectedTracks(0)
local success_count = 0

for i = 0, num_sel_tracks - 1 do
    local dest_track = reaper.GetSelectedTrack(0, i)
    
    if dest_track ~= src_track then
        -- Determinar posiciÃ³n final para esta pista especÃ­fica
        local target_pos
        if not dest_pos or dest_pos <= 0 then
            target_pos = reaper.TrackFX_GetCount(dest_track) -- Al final
        else
            target_pos = dest_pos - 1 -- PosiciÃ³n especÃ­fica (ajustada a Ã­ndice 0)
        end

        for _, fidx in ipairs(fx_indices_to_copy) do
            reaper.TrackFX_CopyToTrack(src_track, fidx, dest_track, target_pos, false)
            target_pos = target_pos + 1
        end
        success_count = success_count + 1
    end
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Copiar FX enfocado", -1)

-- Feedback en la consola
if success_count > 0 then
    reaper.ShowConsoleMsg("OK: '" .. fx_name .. "' copiado a " .. success_count .. " pistas.\n")
end
