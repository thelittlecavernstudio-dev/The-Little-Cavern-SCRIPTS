-- @description TLC Export track FX list and plugin usage to CSV
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about Generates reports on FX chains per track and overall plugin frequency. Saves Tracks_FX.txt and FX_Usage.txt in the project directory.
-- @changelog
--   # Initial release
--   * Added FX usage export to text files.

local project = reaper.EnumProjects(-1, "")
local fx_usage_count = {}
local track_fx_output = {}
local max_fx_per_track = 0

local function escape_tab(val)
  return tostring(val):gsub("\t", " ")  -- elimina tabuladores internos, por si acaso
end

-- Recorrer todas las pistas y sus FX, guardar mÃ¡ximo nÃºmero de FX encontrados en una pista
for i = 0, reaper.CountTracks(project)-1 do
  local track = reaper.GetTrack(project, i)
  local retval, track_name = reaper.GetTrackName(track, "")
  local track_fx_list = {}
  for j = 0, reaper.TrackFX_GetCount(track)-1 do
    local _, fxname = reaper.TrackFX_GetFXName(track, j, "")
    table.insert(track_fx_list, fxname)
    fx_usage_count[fxname] = (fx_usage_count[fxname] or 0) + 1
  end
  if #track_fx_list > max_fx_per_track then max_fx_per_track = #track_fx_list end
  table.insert(track_fx_output, {track_number = i+1, track_name = track_name, fx_list = track_fx_list})
end

-- Obtener ruta raÃ­z exacta del archivo .rpp del proyecto
local _, projfn = reaper.EnumProjects(-1, "")
local proj_path = projfn:match("^(.*[\\/])") or ""

local path_tracks_fx = proj_path .. "Tracks_FX.txt"
local path_fx_usage = proj_path .. "FX_Usage.txt"

-- Guardar TXT pista + FX, cada plugin en su columna (tabulado)
local f1 = io.open(path_tracks_fx, "w")
if not f1 then
  reaper.ShowMessageBox("Error: No se pudo crear archivo " .. path_tracks_fx, "Error", 0)
  return
end

-- Escribir encabezado dinÃ¡mico segÃºn el mÃ¡ximo de FX
local header = "Track #\tTrack"
for c = 1, max_fx_per_track do
  header = header .. "\tFX" .. c
end
f1:write(header .. "\n")

for _, row in ipairs(track_fx_output) do
  local line = escape_tab(row.track_number) .. "\t" .. escape_tab(row.track_name)
  for i = 1, max_fx_per_track do
    local fx = row.fx_list[i] or ""
    line = line .. "\t" .. escape_tab(fx)
  end
  f1:write(line .. "\n")
end
f1:close()

-- Guardar TXT FX usados + cantidad de pistas, separado por tabulador
local f2 = io.open(path_fx_usage, "w")
if not f2 then
  reaper.ShowMessageBox("Error: No se pudo crear archivo " .. path_fx_usage, "Error", 0)
  return
end
f2:write("FX\tTracks Used\n")
for fxname, count in pairs(fx_usage_count) do
  f2:write(escape_tab(fxname) .. "\t" .. tostring(count) .. "\n")
end
f2:close()

reaper.ShowMessageBox("ExportaciÃ³n completada.\nArchivos:\n" .. path_tracks_fx .. "\n" .. path_fx_usage, "Exportar FX", 0)

