-- @description TLC Select tracks containing Print
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about
--   # Track Selection
--   * Identifies and selects tracks containing the word "Print" in their name.
--   # Selection State
--   * Resets the project's selection state before performing the search.
--   # Processing Preparation
--   * Useful for stem exports or processing for projects with "Print" track naming.
-- @changelog
--   # Initial Release
--   * Selects tracks with names containing the word 'Print'.
--   * Uses case-insensitive matching.

local function track_has_word(name, word)
  return string.find(string.lower(name), string.lower(word), 1, true) ~= nil
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local proj = 0
local track_count = reaper.CountTracks(proj)

-- Deseleccionar todas las pistas primero
reaper.Main_OnCommand(40297, 0)  -- Unselect all tracks

-- Seleccionar pistas con "Print" en el nombre
for i = 0, track_count - 1 do
  local track = reaper.GetTrack(proj, i)
  local _, name = reaper.GetTrackName(track, "")
  if track_has_word(name, "Print") then
    reaper.SetTrackSelected(track, true)
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Select Print tracks", -1)
