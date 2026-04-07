-- @description TLC Select stereo tracks
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about
--   # Stereo Identification
--   * Scans tracks in the project to identify those containing at least one stereo audio item (2 channels).
--   # Selection
--   * Appends identified stereo tracks to the existing selection.
--   # Validation
--   * Checks the channel count of the active take while filtering out MIDI.
-- @changelog
--   # Initial Release
--   * Selects tracks containing at least one stereo audio item.
--   * Checks source channel counts while ignoring MIDI items.

reaper.Undo_BeginBlock()

local track_count = reaper.CountTracks(0)

for i = 0, track_count-1 do
  local track = reaper.GetTrack(0, i)
  local item_count = reaper.CountTrackMediaItems(track)
  local found_stereo = false

  for j = 0, item_count-1 do
    local item = reaper.GetTrackMediaItem(track, j)
    local take = reaper.GetActiveTake(item)

    if take ~= nil then
      local src = reaper.GetMediaItemTake_Source(take)
      
      -- Ignorar MIDI completamente
      if reaper.GetMediaSourceType(src, "") ~= "MIDI" then
        local channels = reaper.GetMediaSourceNumChannels(src)
        if channels == 2 then
          found_stereo = true
          break
        end
      end
    end
  end

  -- SOLO seleccionar si encuentra estéreo (nunca deselecciona)
  if found_stereo then
    reaper.SetTrackSelected(track, true)
  end
end

reaper.Undo_EndBlock("Seleccionar pistas con items estéreo", -1)
