-- @description TLC Set sends to Pre-Fader (Post-FX) on selected tracks
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Sets all sends on selected tracks to Pre-Fader (Post-FX) mode and reports the number of sends changed.
-- @changelog
--   # Initial release
--   * Set sends on selected tracks to Pre-Fader mode with a summary report.

function set_sends_selected_tracks_postfx_prefader_verbose()
  local total_changed = 0
  local num_tracks = reaper.CountSelectedTracks(0)
  for i = 0, num_tracks-1 do
    local track = reaper.GetSelectedTrack(0, i)
    local num_sends = reaper.GetTrackNumSends(track, 0)
    total_changed = total_changed + num_sends
    for j = 0, num_sends-1 do
      reaper.SetTrackSendInfo_Value(track, 0, j, "I_SENDMODE", 3)
    end
  end
  reaper.ShowMessageBox("EnvÃ­os afectados: " .. total_changed, "Informe de cambios", 0)
end

reaper.Undo_BeginBlock()
set_sends_selected_tracks_postfx_prefader_verbose()
reaper.Undo_EndBlock("Envios a Post-FX (Pre-Fader) con informe", -1)

