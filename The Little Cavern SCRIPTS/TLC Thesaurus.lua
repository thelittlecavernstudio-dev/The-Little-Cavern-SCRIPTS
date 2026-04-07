-- @description TLC Thesaurus
-- @version 1.9
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @website https://ko-fi.com/thelittlecavern
-- @provides
--   [main] .
--   [nomain] TLC_logo_transparent_white.png > TLC Thesaurus_logo.png
-- @about
--   # Plugin renaming and database tool
--   * Tool for plugin naming and database management.
-- @changelog
--   # v1.9
--   * Clarified keyword matching with examples in Add New and Help.
--   # v1.8
--   * Refined Help copy and clarified behavior of renaming and tools.
--   # v1.7
--   * Added Help section (EN/ES).
--   # v1.6
--   * Unified dark UI theme with other TLC tools.
--   * Switched logo to white variant and preserved aspect ratio.
--   # v1.5
--   * FULL RESTORATION of logic.
--   * Moved Support link to header (#0000EE).
--   * Standardized alignment and white text legibility.

-- =====================================================================
--  REQUISITOS
-- =====================================================================
if not reaper.ImGui_CreateContext then
  reaper.MB("This script requires ReaImGui.", "Error", 0)
  return
end

local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local db_path = script_path .. "TLC Thesaurus_DB.txt"
local dump_path = script_path .. "Thesaurus_Dump.txt"
local logo_path = script_path .. "TLC Thesaurus_logo.png"

local function EnsureFile(path)
    local f = io.open(path, "r")
    if f then f:close(); return end
    f = io.open(path, "w")
    if f then f:write(""); f:close() end
end

EnsureFile(db_path)

-- =====================================================================
--  ESTADO Y COLORES (TLC Standard)
-- =====================================================================
local ctx = reaper.ImGui_CreateContext('TLC Thesaurus')
local current_mode = 0 -- 0:Add, 1:Manage, 2:Run, 3:Categories, 4:Tools, 5:Help
local last_report = "Ready."
local filter_text = ""
local filter_cat = "ALL"

function GetColor(r, g, b, a) return reaper.ImGui_ColorConvertDouble4ToU32(r/255, g/255, b/255, a or 1.0) end
local COL_BG = GetColor(27, 27, 27)
local COL_PANEL = GetColor(35, 35, 35)
local COL_FRAME = GetColor(42, 42, 42)
local COL_FRAME_H = GetColor(52, 52, 52)
local COL_FRAME_A = GetColor(63, 63, 63)
local COL_ACCENT = GetColor(51, 204, 255)
local COL_ACCENT_D = GetColor(30, 111, 210)
local COL_ACCENT_H = GetColor(42, 167, 216)
local COL_BLUE = COL_ACCENT_D
local COL_BLUE_LIGHT = COL_ACCENT_H
local COL_MAROON = GetColor(120, 35, 35)
local COL_GREEN = GetColor(44, 138, 75)
local COL_BLACK = GetColor(230, 230, 230)
local COL_WHITE = GetColor(255, 255, 255)
local COL_TEXT_DIM = GetColor(160, 160, 160)

local FONT_SMALL = 13
local FONT_BASE = 14
local FONT_HEADER = 16

local BTN_H_SM = 28
local BTN_H = 36
local BTN_H_LG = 44

local function VSpace(h)
    if reaper.ImGui_Dummy then reaper.ImGui_Dummy(ctx, 0, h) else reaper.ImGui_Spacing(ctx) end
end

local function PushTheme()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), COL_BG)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), COL_PANEL)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), GetColor(58, 58, 58))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), GetColor(58, 58, 58))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(), COL_TEXT_DIM)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), COL_FRAME)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), COL_FRAME_H)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), COL_FRAME_A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_FRAME)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COL_FRAME_H)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), COL_FRAME_A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), GetColor(42, 58, 74))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), GetColor(51, 80, 112))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), GetColor(58, 97, 133))
    return 15
end

local function PopTheme(count)
    reaper.ImGui_PopStyleColor(ctx, count)
end

-- Data
local db_rules = {}
local available_categories = {}
local in_original = ""
local in_new = ""
local in_cat = "GENERAL"
local editing_idx = -1
local in_new_cat = ""
local editing_cat_idx = -1

-- Carga de Logo
local logo_img = nil
if reaper.ImGui_CreateImage then
    local f = io.open(logo_path, "r")
    if f then f:close() logo_img = reaper.ImGui_CreateImage(logo_path) end
end

local function DrawLogo()
    if not logo_img then
        reaper.ImGui_Text(ctx, "THE LITTLE CAVERN")
        return
    end
    local w, h = 462, 355 -- fallback proportions
    if reaper.ImGui_ImageGetSize then
        w, h = reaper.ImGui_ImageGetSize(logo_img)
    end
    local max_w = 220
    local max_h = 70
    local scale = 1
    if w > 0 and h > 0 then
        local sw = max_w / w
        local sh = max_h / h
        scale = (sw < sh) and sw or sh
    end
    reaper.ImGui_Image(ctx, logo_img, w * scale, h * scale)
end

-- =====================================================================
--  LÓGICA DE DATOS
-- =====================================================================
function RefreshData()
    db_rules = {}
    available_categories = {"GENERAL"}
    local cats_seen = {GENERAL = true}
    local file = io.open(db_path, "r")
    if not file then return end
    
    local current_cat = "GENERAL"
    local in_cat_list = false
    for line in file:lines() do
        local clean = line:gsub("^%s*(.-)%s*$", "%1")
        local header = line:match("^%-%-%-%s*(.+)")
        if header then
            if header:upper():find("CATEGORIAS") then in_cat_list = true
            else
                current_cat = header:upper()
                if not cats_seen[current_cat] then table.insert(available_categories, current_cat) cats_seen[current_cat] = true end
                in_cat_list = false
            end
        elseif in_cat_list then
            if clean ~= "" then
                if not cats_seen[clean:upper()] then table.insert(available_categories, clean:upper()) cats_seen[clean:upper()] = true end
            end
        elseif line:find("|") then
            local s, n = line:match("([^|]+)|([^|]*)")
            if s then table.insert(db_rules, {original = s, new = n or "", cat = current_cat}) end
        end
    end
    file:close()
    table.sort(available_categories)
end

function SaveMasterDB()
    table.sort(available_categories)
    local sections = {}
    for _, r in ipairs(db_rules) do
        local c = r.cat:upper()
        if not sections[c] then sections[c] = {} end
        table.insert(sections[c], r.original .. "|" .. r.new)
    end
    local file = io.open(db_path, "w")
    local order = {}
    for c in pairs(sections) do table.insert(order, c) end
    table.sort(order)
    for _, c in ipairs(order) do
        file:write("--- " .. c .. "\n")
        for _, entry in ipairs(sections[c]) do file:write(entry .. "\n") end
        file:write("\n")
    end
    file:write("--- CATEGORIAS\n")
    for _, c in ipairs(available_categories) do file:write(c .. "\n") end
    file:close()
end

-- =====================================================================
--  VISTAS
-- =====================================================================
function DrawSupportLink()
    reaper.ImGui_PushFont(ctx, nil, FONT_SMALL)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_ACCENT)
    reaper.ImGui_Text(ctx, "Support the TLC Team")
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
        if reaper.ImGui_IsMouseClicked(ctx, 0) then
            local url = "https://ko-fi.com/thelittlecavern"
            local os = reaper.GetOS()
            if os:match("Win") then reaper.ExecProcess('cmd.exe /C start "" "' .. url .. '"', 0)
            else reaper.ExecProcess('/usr/bin/open "' .. url .. '"', 0) end
        end
    end
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_PopFont(ctx)
end

function DrawNavBar()
    reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    local labels = {"ADD NEW", "BROWSE & EDIT", "RUN", "CATEGORIES", "TOOLS", "HELP"}
    for i, label in ipairs(labels) do
        local idx = i - 1; local active = current_mode == idx
        local btn_w = reaper.ImGui_CalcTextSize(ctx, label) + 30
        local cur_x, cur_y = reaper.ImGui_GetCursorScreenPos(ctx)
        local btn_col = active and COL_ACCENT_D or COL_FRAME
        local btn_h = active and COL_ACCENT_H or COL_FRAME_H
        local btn_a = active and COL_ACCENT or COL_FRAME_A
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), btn_col)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), btn_h)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), btn_a)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), active and COL_WHITE or COL_TEXT_DIM)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)
        if reaper.ImGui_Button(ctx, label .. "##nav", btn_w, BTN_H_LG) then current_mode = idx end
        if active then reaper.ImGui_DrawList_AddRectFilled(reaper.ImGui_GetWindowDrawList(ctx), cur_x, cur_y + 47, cur_x + btn_w, cur_y + 50, COL_ACCENT_D) end
        reaper.ImGui_PopStyleVar(ctx); reaper.ImGui_PopStyleColor(ctx, 4); reaper.ImGui_SameLine(ctx, nil, 5)
    end
    reaper.ImGui_PopFont(ctx)
end

function DrawHelp()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK)
    reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    if reaper.ImGui_BeginTabBar(ctx, "help_tabs") then
        if reaper.ImGui_BeginTabItem(ctx, "EN") then
            reaper.ImGui_TextWrapped(ctx, [[
# TLC THESAURUS HELP

OVERVIEW
Producers often rename FX so the name describes what it does instead of brand or marketing names. This tool creates a reusable renaming database and applies it per project (non-destructive).

ADD NEW
Create a rule by entering the original name (keyword), the new name, and a category. The original name is a partial match: if a plugin name contains that keyword, it will be renamed.
Example: Original "Compres FET" -> New "FET Comp" will rename any plugin that contains "Compres FET".

BROWSE & EDIT
Search and filter rules. This list is your renamed plugin catalog. Edit or delete entries here.

RUN
Applies your rules to all tracks and the master track in the current project. It does not rename plugins permanently; it only renames inside the project.

CATEGORIES
Categories are for grouping and filtering only. Create, rename or delete categories. Deleting a category moves rules to GENERAL.

TOOLS
Scan installed plugins to build a dump list. You can then open that TXT file. Open DB File shows the category + original name + renamed name mapping.
]])
            reaper.ImGui_EndTabItem(ctx)
        end
        if reaper.ImGui_BeginTabItem(ctx, "ES") then
            reaper.ImGui_TextWrapped(ctx, [[
# AYUDA TLC THESAURUS

RESUMEN
Muchos productores renombran FX para que el nombre describa su funcion y no la marca. Esta herramienta crea una base de datos reutilizable y la aplica por proyecto (no destructivo).

ADD NEW
Crea una regla con nombre original (keyword), nuevo nombre y categoria. El nombre original funciona por coincidencia parcial: si un plugin contiene ese texto, se renombra.
Ejemplo: Original "Compres FET" -> Nuevo "FET Comp" renombra cualquier plugin que contenga "Compres FET".

BROWSE & EDIT
Busca y filtra reglas. Esta lista es tu catalogo de plugins renombrados. Edita o elimina entradas existentes.

RUN
Aplica las reglas a todas las pistas y al master del proyecto actual. No renombra plugins de forma permanente; solo dentro del proyecto.

CATEGORIES
Las categorias solo sirven para agrupar y filtrar. Crea, renombra o elimina categorias. Al borrar, las reglas pasan a GENERAL.

TOOLS
Escanea plugins instalados para generar una lista. Luego puedes abrir ese TXT. Open DB File muestra la correlacion de categorias, nombre original y nombre renombrado.
]])
            reaper.ImGui_EndTabItem(ctx)
        end
        reaper.ImGui_EndTabBar(ctx)
    end
    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_PopStyleColor(ctx)
end

function DrawAdd(is_edit)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK)
    reaper.ImGui_PushFont(ctx, nil, FONT_HEADER)
    reaper.ImGui_Text(ctx, (is_edit and "EDIT RULE:" or "ADD NEW RULE:"))
    reaper.ImGui_PopFont(ctx)
    VSpace(6); reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    reaper.ImGui_Text(ctx, "Original Name (keyword):"); reaper.ImGui_SetNextItemWidth(ctx, -1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    _, in_original = reaper.ImGui_InputText(ctx, "##orig", in_original); reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_TEXT_DIM)
    reaper.ImGui_TextWrapped(ctx, "Example: Original \"Compres FET\" -> New \"FET Comp\" renames any plugin that contains \"Compres FET\".")
    reaper.ImGui_PopStyleColor(ctx)
    VSpace(6); reaper.ImGui_Text(ctx, "New Name:"); reaper.ImGui_SetNextItemWidth(ctx, -1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    _, in_new = reaper.ImGui_InputText(ctx, "##new", in_new); reaper.ImGui_PopStyleColor(ctx)
    VSpace(6); reaper.ImGui_Text(ctx, "Category:"); reaper.ImGui_SetNextItemWidth(ctx, -1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    if reaper.ImGui_BeginCombo(ctx, "##cat", in_cat) then
        for _, cat in ipairs(available_categories) do if reaper.ImGui_Selectable(ctx, cat, in_cat == cat) then in_cat = cat end end
        reaper.ImGui_EndCombo(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx); VSpace(8)
    if in_original ~= "" and in_new ~= "" then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_GREEN); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
        if reaper.ImGui_Button(ctx, (is_edit and "SAVE CHANGES" or "ADD RULE"), -1, BTN_H) then
            if is_edit then db_rules[editing_idx] = {original = in_original, new = in_new, cat = in_cat}
            else table.insert(db_rules, {original = in_original, new = in_new, cat = in_cat}) end
            SaveMasterDB(); in_original, in_new, editing_idx = "", "", -1; if is_edit then current_mode = 1 end
            reaper.MB("Success!", "TLC", 0)
        end
        reaper.ImGui_PopStyleColor(ctx, 2)
    end
    if is_edit and reaper.ImGui_Button(ctx, "CANCEL", -1, BTN_H_SM) then editing_idx = -1; current_mode = 1 end
    reaper.ImGui_PopFont(ctx); reaper.ImGui_PopStyleColor(ctx)
end

function DrawManage()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK)
    reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    reaper.ImGui_Text(ctx, "Search:"); reaper.ImGui_SameLine(ctx); reaper.ImGui_SetNextItemWidth(ctx, 180)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    _, filter_text = reaper.ImGui_InputText(ctx, "##f", filter_text); reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, "Filter by Categories:"); reaper.ImGui_SameLine(ctx); reaper.ImGui_SetNextItemWidth(ctx, -1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    if reaper.ImGui_BeginCombo(ctx, "##fc", filter_cat) then
        if reaper.ImGui_Selectable(ctx, "ALL", filter_cat == "ALL") then filter_cat = "ALL" end
        for _, c in ipairs(available_categories) do if reaper.ImGui_Selectable(ctx, c, filter_cat == c) then filter_cat = c end end
        reaper.ImGui_EndCombo(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx); VSpace(6)
    if reaper.ImGui_BeginChild(ctx, "list", 0, 0, 1) then
        for i = #db_rules, 1, -1 do
            local r = db_rules[i]
            local mt = filter_text == "" or r.original:lower():find(filter_text:lower()) or r.new:lower():find(filter_text:lower())
            local mc = filter_cat == "ALL" or r.cat == filter_cat
            if mt and mc then
                reaper.ImGui_PushID(ctx, i); reaper.ImGui_Text(ctx, string.format("[%s] %s -> %s", r.cat, r.original, r.new))
                reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) - 160)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_BLUE)
                if reaper.ImGui_Button(ctx, "EDIT", 70, BTN_H_SM) then editing_idx = i; in_original, in_new, in_cat = r.original, r.new, r.cat; current_mode = 0 end
                reaper.ImGui_PopStyleColor(ctx); reaper.ImGui_SameLine(ctx)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_MAROON)
                if reaper.ImGui_Button(ctx, "DEL", 70, BTN_H_SM) then table.remove(db_rules, i); SaveMasterDB() end
                reaper.ImGui_PopStyleColor(ctx, 2); reaper.ImGui_Separator(ctx); reaper.ImGui_PopID(ctx)
            end
        end
        reaper.ImGui_EndChild(ctx)
    end
    reaper.ImGui_PopFont(ctx); reaper.ImGui_PopStyleColor(ctx)
end

function DrawRun()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK); reaper.ImGui_PushFont(ctx, nil, FONT_HEADER)
    reaper.ImGui_Text(ctx, "RENAMER ENGINE"); reaper.ImGui_PopFont(ctx)
    reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    reaper.ImGui_Text(ctx, "Status: " .. last_report)
    reaper.ImGui_TextWrapped(ctx, "Applies your rename rules to every FX in the current project (tracks + master). This does not change plugin names permanently.");
    VSpace(8)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_GREEN); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    if reaper.ImGui_Button(ctx, "RUN GLOBAL RENAMING", -1, BTN_H_LG) then
        local rename_map = {}; local count = 0
        for _, r in ipairs(db_rules) do rename_map[r.original:lower():gsub("%s+$", "")] = r.new:gsub("^%s+", "") end
        local function proc(track)
            local total = reaper.TrackFX_GetCount(track) + reaper.TrackFX_GetRecCount(track)
            for i = 0, total - 1 do
                local idx = i < reaper.TrackFX_GetCount(track) and i or (i - reaper.TrackFX_GetCount(track) + 0x1000000)
                local _, fn = reaper.TrackFX_GetFXName(track, idx, "")
                local cn = fn:gsub("^%w+:%s*", ""):lower()
                for s, n in pairs(rename_map) do
                    if cn:find(s, 1, true) then
                        local _, cr = reaper.TrackFX_GetNamedConfigParm(track, idx, "renamed_name")
                        if cr ~= n then reaper.TrackFX_SetNamedConfigParm(track, idx, "renamed_name", n); count = count + 1 end
                        break
                    end
                end
            end
        end
        reaper.Undo_BeginBlock(); reaper.PreventUIRefresh(1)
        for i = 0, reaper.CountTracks(0)-1 do proc(reaper.GetTrack(0, i)) end
        proc(reaper.GetMasterTrack(0)); reaper.PreventUIRefresh(-1); reaper.UpdateArrange()
        last_report = "Finished: " .. count .. " updated."; reaper.Undo_EndBlock("TLC Thesaurus Rename", -1)
    end
    reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopFont(ctx)
end

function DrawCats()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK); reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    reaper.ImGui_Text(ctx, (editing_cat_idx ~= -1 and "Rename Category:" or "Add New Category:"))
    reaper.ImGui_SetNextItemWidth(ctx, reaper.ImGui_GetWindowWidth(ctx) - 150); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    _, in_new_cat = reaper.ImGui_InputText(ctx, "##nc", in_new_cat); reaper.ImGui_PopStyleColor(ctx); reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_GREEN); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    if reaper.ImGui_Button(ctx, (editing_cat_idx ~= -1 and "UPDATE" or "ADD"), -1, BTN_H) then
        if in_new_cat ~= "" then
            if editing_cat_idx ~= -1 then
                local old = available_categories[editing_cat_idx]; local new = in_new_cat:upper()
                for _, r in ipairs(db_rules) do if r.cat == old then r.cat = new end end
                available_categories[editing_cat_idx] = new; editing_cat_idx = -1
            else table.insert(available_categories, in_new_cat:upper()) end
            SaveMasterDB(); in_new_cat = ""; RefreshData()
        end
    end
    reaper.ImGui_PopStyleColor(ctx, 2); VSpace(6)
    if reaper.ImGui_BeginChild(ctx, "clist", 0, 0, 1) then
        for i = 1, #available_categories do
            local c = available_categories[i]; reaper.ImGui_PushID(ctx, i); reaper.ImGui_Text(ctx, c); reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) - 200)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_BLUE); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
            if reaper.ImGui_Button(ctx, "Edit", 80, BTN_H_SM) then editing_cat_idx = i; in_new_cat = c end
            reaper.ImGui_PopStyleColor(ctx, 2); reaper.ImGui_SameLine(ctx)
            if c ~= "GENERAL" then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_MAROON); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
                if reaper.ImGui_Button(ctx, "Delete", 80, BTN_H_SM) then 
                    for _, rule in ipairs(db_rules) do if rule.cat == c then rule.cat = "GENERAL" end end
                    table.remove(available_categories, i); SaveMasterDB(); RefreshData() 
                end
                reaper.ImGui_PopStyleColor(ctx, 2)
            end
            reaper.ImGui_Separator(ctx); reaper.ImGui_PopID(ctx)
        end
        reaper.ImGui_EndChild(ctx)
    end
    reaper.ImGui_PopFont(ctx); reaper.ImGui_PopStyleColor(ctx)
end

function DrawTools()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK); reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_BLUE); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    if reaper.ImGui_Button(ctx, "SCAN PLUGINS", -1, BTN_H) then
        local l, s, c, i = {}, {}, 0, 0
        while true do
            local rv, n = reaper.EnumInstalledFX(i); if not rv then break end
            local cn = n:gsub("^%w+: ", ""); if not s[cn] then table.insert(l, cn); s[cn] = true; c = c + 1 end
            i = i + 1
        end
        table.sort(l); local f = io.open(dump_path, "w")
        if f then f:write("--- PLUGIN DUMP\n"); for _, p in ipairs(l) do f:write(p.."|\n") end; f:close() end
        reaper.MB("Found " .. c .. " plugins. Dump created.", "TLC", 0)
    end
    reaper.ImGui_PopStyleColor(ctx, 2)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_TEXT_DIM)
    reaper.ImGui_Text(ctx, "Scan Plugins creates a dump list (TXT).")
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_FRAME)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_TEXT_DIM)
    if reaper.ImGui_Button(ctx, "OPEN PLUGIN DUMP", -1, BTN_H_SM) then reaper.ExecProcess('cmd.exe /C start "" "' .. dump_path .. '"', 0) end
    reaper.ImGui_PopStyleColor(ctx, 2)
    if reaper.ImGui_Button(ctx, "OPEN DB FILE", -1, BTN_H) then reaper.ExecProcess('cmd.exe /C start "" "' .. db_path .. '"', 0) end
    reaper.ImGui_PopStyleColor(ctx); reaper.ImGui_PopFont(ctx)
end

function MainLoop()
    local color_count = PushTheme()
    local style_count = 0
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 20, 20); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 4); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 6); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 8, 6); style_count = style_count + 1
    reaper.ImGui_SetNextWindowSize(ctx, 750, 600, 1)
    local v, o = reaper.ImGui_Begin(ctx, 'TLC THESAURUS v1.8', true, 64)
    if v then
        local img_ok = logo_img and (not reaper.ImGui_ValidatePtr or reaper.ImGui_ValidatePtr(logo_img, 'ImGui_Image*'))
        if not img_ok and logo_img then logo_img = reaper.ImGui_CreateImage(logo_path) end
        DrawLogo()
        reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) - 150); DrawSupportLink()
        reaper.ImGui_Spacing(ctx); reaper.ImGui_Separator(ctx); reaper.ImGui_Spacing(ctx); DrawNavBar(); reaper.ImGui_Spacing(ctx); reaper.ImGui_Separator(ctx); reaper.ImGui_Spacing(ctx)
        if current_mode == 0 then DrawAdd(editing_idx ~= -1)
        elseif current_mode == 1 then DrawManage()
        elseif current_mode == 2 then DrawRun()
        elseif current_mode == 3 then DrawCats()
        elseif current_mode == 4 then DrawTools()
        elseif current_mode == 5 then DrawHelp() end
        reaper.ImGui_End(ctx)
    end
    reaper.ImGui_PopStyleVar(ctx, style_count); PopTheme(color_count); if o then reaper.defer(MainLoop) end
end
RefreshData(); MainLoop()
