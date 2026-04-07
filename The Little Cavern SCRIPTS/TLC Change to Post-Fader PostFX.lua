-- @description TLC Set sends to Post-Fader (Post-FX) on selected tracks
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Sets all sends on selected tracks to Post-Fader (Post-FX) mode.
-- @changelog
--   # Initial release
--   * Set sends on selected tracks to Post-Fader mode.

function set_sends_selected_tracks_postfader_postfx()
  local num_tracks = reaper.CountSelectedTracks(0)
  for i = 0, num_tracks-1 do
    local track = reaper.GetSelectedTrack(0, i)
    local num_sends = reaper.GetTrackNumSends(track, 0)
    for j = 0, num_sends-1 do
      reaper.SetTrackSendInfo_Value(track, 0, j, "I_SENDMODE", 0) -- 0 = Post-Fader (Post-FX)
    end
  end
end

reaper.Undo_BeginBlock()
set_sends_selected_tracks_postfader_postfx()
reaper.Undo_EndBlock("EnvÃ­os a Post-Fader (Post-FX)", -1)


