-- @description TLC Select mono tracks
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about
--   # Track Selection
--   * Scans tracks in the project to select those containing at least one mono audio item.
--   # Source Detection
--   * Checks the media source channel count (1 channel) to determine if a track is mono.
--   # Content Filtering
--   * Ignores MIDI items and empty tracks to focus on mono audio.
-- @changelog
--   # Initial Release
--   * Selects tracks containing at least one mono audio item.
--   * Checks source channel counts while ignoring MIDI items.

reaper.Undo_BeginBlock()

local track_count = reaper.CountTracks(0)

for i = 0, track_count-1 do
  local track = reaper.GetTrack(0, i)
  local item_count = reaper.CountTrackMediaItems(track)
  local found_mono = false

  for j = 0, item_count-1 do
    local item = reaper.GetTrackMediaItem(track, j)
    local take = reaper.GetActiveTake(item)

    if take ~= nil then
      local src = reaper.GetMediaItemTake_Source(take)
      
      -- Saltar si es MIDI
      if reaper.GetMediaSourceType(src, "") ~= "MIDI" then
        local channels = reaper.GetMediaSourceNumChannels(src)
        if channels == 1 then
          found_mono = true
          break
        end
      end
    end
  end

  reaper.SetTrackSelected(track, found_mono)
end

reaper.Undo_EndBlock("Seleccionar pistas con items mono", -1)
