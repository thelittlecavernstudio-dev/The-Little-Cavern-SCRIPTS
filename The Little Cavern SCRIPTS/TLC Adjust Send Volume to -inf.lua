-- @description TLC Adjust receive volume to -inf on all tracks
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Sets the volume of all receives on all tracks in the project to -inf dB.
-- @changelog
--   # Initial release
--   * Set volume of receives on all tracks to -inf dB.

reaper.Undo_BeginBlock()
local track_count = reaper.CountTracks(0)
for i = 0, track_count-1 do
  local track = reaper.GetTrack(0, i)
  local recv_count = reaper.GetTrackNumSends(track, -1) -- -1 para receives
  for j = 0, recv_count-1 do
    -- "D_VOL" volumen del receive (0.0 es -inf)
    reaper.SetTrackSendInfo_Value(track, -1, j, "D_VOL", 0.0)
  end
end
reaper.Undo_EndBlock("Receives a -inf", -1)

