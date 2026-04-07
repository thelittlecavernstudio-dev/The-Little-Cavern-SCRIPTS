-- @description TLC Adjust receive volume to -inf on selected tracks
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Sets the volume of all receives on selected tracks to -inf dB. Includes undo support.
-- @changelog
--   # Initial release
--   * Set volume of receives on selected tracks to -inf dB.

reaper.Undo_BeginBlock()

num_tracks = reaper.CountSelectedTracks(0)
for t = 0, num_tracks-1 do
  track = reaper.GetSelectedTrack(0, t)
  num_receives = reaper.GetTrackNumSends(track, -1)
  for r = 0, num_receives-1 do
    -- Forzar valor de volumen a -inf dB
    reaper.SetTrackSendInfo_Value(track, -1, r, "D_VOL", 0.0)
  end
end

reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Silenciar receives de pistas seleccionadas", -1)

