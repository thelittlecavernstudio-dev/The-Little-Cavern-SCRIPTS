-- @description TLC Adjust send volume to 0dB on selected tracks
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Sets all sends on selected tracks to 0 dB.
-- @changelog
--   # Initial release
--   * Set sends on selected tracks to 0 dB.

-- Start undo block
reaper.Undo_BeginBlock()

-- Get the number of selected tracks
local num_sel_tracks = reaper.CountSelectedTracks(0)

for i = 0, num_sel_tracks - 1 do
  local track = reaper.GetSelectedTrack(0, i)
  if track then
    -- Get the number of sends for this track
    local num_sends = reaper.GetTrackNumSends(track, 0) -- 0 = sends

    for send_idx = 0, num_sends - 1 do
      -- Set send volume to 1.0 (0 dB)
      reaper.SetTrackSendInfo_Value(track, 0, send_idx, "D_VOL", 1.0)
    end
  end
end

-- End undo block
reaper.Undo_EndBlock("Set Sends to 0 dB on selected tracks", -1)

