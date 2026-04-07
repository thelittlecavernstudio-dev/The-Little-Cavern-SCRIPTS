-- @description TLC Select Mixbus track only
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about
--   # Mixbus Selection
--   * Clears current track selections and selects the track named "Mixbus".
--   # Name Matching
--   * Uses case-insensitive comparison to find the mixbus.
--   # Navigation
--   * Useful for navigating to the main output stage of a project.
-- @changelog
--   # Initial Release
--   * Selects the track named 'Mixbus'.
--   * Uses case-insensitive name matching.

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local proj = 0
local track_count = reaper.CountTracks(proj)

-- Deseleccionar todas las pistas primero
reaper.Main_OnCommand(40297, 0)  -- Unselect all tracks

-- Buscar y seleccionar Mixbus (de forma insensible a mayúsculas)
for i = 0, track_count - 1 do
  local track = reaper.GetTrack(proj, i)
  local _, name = reaper.GetTrackName(track, "")
  
  -- Convertimos el nombre de la pista a minúsculas para la comparación
  if name:lower() == "mixbus" then
    reaper.SetTrackSelected(track, true)
    -- Si solo esperas tener UN mixbus, dejamos el break. 
    -- Si tienes varios y quieres seleccionarlos todos, quita el 'break'.
    break 
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Select Mixbus track (case-insensitive)", -1)
