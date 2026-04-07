-- @description TLC Prepare tracks for stem export
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Mutes the "Mixbus" track and selects tracks with "Print" in their name.
-- @changelog
--   # Initial release
--   * Added track preparation for exporting stems.

local function track_has_word(name, word)
  name = name:lower()
  word = word:lower()
  return name:find(word, 1, true) ~= nil
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local proj = 0
local track_count = reaper.CountTracks(proj)

-- 1. Encontrar y mutear el track "Mixbus"
for i = 0, track_count - 1 do
  local track = reaper.GetTrack(proj, i)
  local _, name = reaper.GetTrackName(track, "")
  if name == "Mixbus" then
    -- I_MUTE: 1 = mute, 0 = unmute
    reaper.SetMediaTrackInfo_Value(track, "I_MUTE", 1)
    break
  end
end

-- 2. Encontrar y seleccionar los tracks que contengan "Print"
-- Primero deseleccionamos todas las pistas
reaper.Main_OnCommand(40297, 0) -- Unselect all tracks

for i = 0, track_count - 1 do
  local track = reaper.GetTrack(proj, i)
  local _, name = reaper.GetTrackName(track, "")
  if track_has_word(name, "Print") then
    reaper.SetTrackSelected(track, true)
  end
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Mute Mixbus and select Print tracks", -1)
