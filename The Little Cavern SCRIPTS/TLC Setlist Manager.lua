-- @description TLC Setlist Manager
-- @version 1.3
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @website https://ko-fi.com/thelittlecavern
-- @provides
--   [main] .
--   [nomain] TLC_logo_transparent_white.png > TLC Setlist Manager_logo.png
-- @about
--   # Setlist Loading
--   * Manages project files (.RPP) into project tabs for live sets or sessions.
--   # Asynchronous Engine
--   * Handles project loading without freezing the REAPER interface.
--   # Drag-and-Drop
--   * Add songs by dragging .RPP files directly onto the interface.
-- @changelog
--   # v1.3
--   * Manager starts with empty list (no default setlist).
--   * Switched logo to white variant.
--   * Minor UI copy and sizing improvements.
--   # v1.2
--   * FULL RESTORATION of logic.
--   * Improved legibility: Dark text on light backgrounds.
--   * Expanded window width to 850px.
--   * Integrated Support link in header (#0000EE).

local reaper = reaper
local ctx = reaper.ImGui_CreateContext('TLC Setlist Manager')

local script_path = debug.getinfo(1,'S').source:match([[^@?(.*[\/])]])
local config_file = script_path .. "TLC Setlist manager data.lua"
local logo_path = script_path .. "TLC Setlist Manager_logo.png"

-- =================================================================
--  THEME (match JSFX look)
-- =================================================================
local COL_BG = 0x1B1B1BFF
local COL_PANEL = 0x232323FF
local COL_FRAME = 0x2A2A2AFF
local COL_FRAME_H = 0x343434FF
local COL_FRAME_A = 0x3F3F3FFF
local COL_TEXT = 0xE6E6E6FF
local COL_TEXT_DIM = 0xA0A0A0FF
local COL_ACCENT = 0x33CCFFFF
local COL_ACCENT_D = 0x1E6FD2FF
local COL_ACCENT_H = 0x2AA7D8FF
local COL_GREEN = 0x2C8A4BFF

local function PushTheme()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), COL_BG)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), COL_PANEL)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), 0x3A3A3AFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), 0x3A3A3AFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_TEXT)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(), COL_TEXT_DIM)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), COL_FRAME)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), COL_FRAME_H)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), COL_FRAME_A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_FRAME)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COL_FRAME_H)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), COL_FRAME_A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), 0x2A3A4AFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), 0x335070FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), 0x3A6185FF)
    return 15
end

local function PopTheme(count)
    reaper.ImGui_PopStyleColor(ctx, count)
end

-- =================================================================
--  LÓGICA DE DATOS
-- =================================================================
local function serialize_table(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false; depth = depth or 0
    local tmp = string.rep(" ", depth)
    if name then
        if type(name) == "number" then tmp = tmp .. "[" .. name .. "] = "
        else tmp = tmp .. "[\"" .. tostring(name) .. "\"] = " end
    end
    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do tmp = tmp .. serialize_table(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "") end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then tmp = tmp .. tostring(val)
    elseif type(val) == "string" then tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then tmp = tmp .. (val and "true" or "false")
    else tmp = tmp .. "\"[inserializeable]\"" end
    return tmp
end

local data = { selected_group = 0, groups = {} }
local editing_group_idx = nil
local rename_buf = ""
local current_mode = 0 -- 0:Manager, 1:Help

function SaveConfig()
    local file = io.open(config_file, "w")
    if file then file:write("return " .. serialize_table(data)); file:close() end
end

function LoadConfig()
    local chunk = loadfile(config_file)
    if chunk then
        data = chunk()
        if type(data) ~= "table" or not data.groups then data = { selected_group = 0, groups = {} } end
        if type(data) == "table" and type(data.groups) == "table" and #data.groups == 1 then
            local g = data.groups[1]
            if g and (g.name == "Default Band" or g.name == "New Band") and (not g.songs or #g.songs == 0) then
                data = { selected_group = 0, groups = {} }
                SaveConfig()
            end
        end
    else
        data = { selected_group = 0, groups = {} }
        SaveConfig()
    end
end

-- =================================================================
-- ASYNCHRONOUS DEPLOY ENGINE
-- =================================================================
local deploy_state = 0
local deploy_group = nil
local deploy_frame_wait = 0
local deploy_last_count = -1
local deploy_state2_attempted = false

function HandleAsyncDeploy()
    if deploy_state == 0 then return end
    if deploy_frame_wait > 0 then deploy_frame_wait = deploy_frame_wait - 1; return end
    local count = 0
    while reaper.EnumProjects(count, "") do count = count + 1 end
    if deploy_state == 1 then
        if count > 1 then
            if deploy_last_count ~= -1 and count == deploy_last_count then deploy_state = 0; return end
            deploy_last_count = count; reaper.Main_OnCommand(40860, 0); deploy_frame_wait = 3; return
        else deploy_state = 2; deploy_state2_attempted = false; return end
    elseif deploy_state == 2 then
        local proj, path = reaper.EnumProjects(0, ""); local dirty = reaper.IsProjectDirty(proj)
        if path ~= "" or dirty ~= 0 then
            if deploy_state2_attempted then deploy_state = 0; return end
            deploy_state2_attempted = true; reaper.Main_OnCommand(40860, 0); deploy_frame_wait = 3; return
        else deploy_state = 3; return end
    elseif deploy_state == 3 then
        for i, song in ipairs(deploy_group.songs) do
            if reaper.file_exists(song.path) then
                if i == 1 then reaper.Main_openProject(song.path)
                else reaper.Main_OnCommand(40859, 0); reaper.Main_openProject(song.path) end
            end
        end
        reaper.Main_OnCommand(41929, 0); deploy_state = 0 
    end
end

-- =================================================================
--  VISTAS
-- =================================================================
local logo_img = nil
if reaper.ImGui_CreateImage then
    local f = io.open(logo_path, "r"); if f then f:close(); logo_img = reaper.ImGui_CreateImage(logo_path) end
end

local function DrawLogo()
    if not logo_img then
        reaper.ImGui_Text(ctx, "THE LITTLE CAVERN")
        return
    end
    local w, h = 462, 355 -- fallback to keep aspect if size API is unavailable
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

function DrawSupportLink()
    reaper.ImGui_PushFont(ctx, nil, 14)
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
    reaper.ImGui_PushFont(ctx, nil, 16)
    local labels = {"MANAGER", "HELP"}
    for i, label in ipairs(labels) do
        local idx = i - 1; local active = current_mode == idx
        local btn_w = 120
        local btn_col = active and COL_ACCENT_D or COL_FRAME
        local btn_h = active and COL_ACCENT_H or COL_FRAME_H
        local btn_a = active and COL_ACCENT or COL_FRAME_A
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), btn_col)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), btn_h)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), btn_a)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), active and 0xFFFFFFFF or COL_TEXT_DIM)
        if reaper.ImGui_Button(ctx, label .. "##nav", btn_w, 40) then current_mode = idx end
        reaper.ImGui_PopStyleColor(ctx, 4); reaper.ImGui_SameLine(ctx)
    end
    reaper.ImGui_PopFont(ctx)
end

function DrawManager()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_TEXT)
    reaper.ImGui_PushFont(ctx, nil, 15)
    if reaper.ImGui_BeginChild(ctx, "left", 240, 0, 1) then
        reaper.ImGui_Text(ctx, "SET LISTS")
        reaper.ImGui_Separator(ctx)
        for i, group in ipairs(data.groups) do
            if editing_group_idx == i then
                reaper.ImGui_SetKeyboardFocusHere(ctx)
                local rv, new_text = reaper.ImGui_InputText(ctx, "##rename"..i, rename_buf, 32)
                if rv then rename_buf = new_text end
                if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then
                    if rename_buf ~= "" then data.groups[i].name = rename_buf end
                    editing_group_idx = nil; SaveConfig()
                end
            else
                if reaper.ImGui_Selectable(ctx, group.name .. "##" .. i, data.selected_group == i) then data.selected_group = i end
                if reaper.ImGui_BeginPopupContextItem(ctx) then
                    if reaper.ImGui_MenuItem(ctx, "Rename setlist") then editing_group_idx = i; rename_buf = group.name end
                    if reaper.ImGui_MenuItem(ctx, "Delete setlist") then table.remove(data.groups, i); SaveConfig() end
                    reaper.ImGui_EndPopup(ctx)
                end
            end
        end
        reaper.ImGui_Spacing(ctx)
        if reaper.ImGui_Button(ctx, "+ Add Setlist", -1) then
            local idx = #data.groups + 1
            table.insert(data.groups, {name = "Setlist " .. idx, songs = {}})
            data.selected_group = idx
            SaveConfig()
        end
        reaper.ImGui_EndChild(ctx)
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_BeginGroup(ctx)
        local current = data.groups[data.selected_group]
        reaper.ImGui_Text(ctx, "SONGS: " .. (current and current.name:upper() or ""))
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_BeginChild(ctx, "list", 0, -50, 1) then
            if current then
                for j, song in ipairs(current.songs) do
                    reaper.ImGui_Selectable(ctx, j .. ". " .. song.title .. "##" .. j)
                    if reaper.ImGui_BeginDragDropSource(ctx) then
                        reaper.ImGui_SetDragDropPayload(ctx, "REORDER", tostring(j))
                        reaper.ImGui_Text(ctx, "Moving: " .. song.title); reaper.ImGui_EndDragDropSource(ctx)
                    end
                    if reaper.ImGui_BeginDragDropTarget(ctx) then
                        local rv, payload = reaper.ImGui_AcceptDragDropPayload(ctx, "REORDER")
                        if rv then local moved = table.remove(current.songs, tonumber(payload)); table.insert(current.songs, j, moved); SaveConfig() end
                        reaper.ImGui_EndDragDropTarget(ctx)
                    end
                    if reaper.ImGui_BeginPopupContextItem(ctx) then
                        if reaper.ImGui_MenuItem(ctx, "Delete Song") then table.remove(current.songs, j); SaveConfig() end
                        reaper.ImGui_EndPopup(ctx)
                    end
                end
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_FRAME)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_TEXT_DIM)
                reaper.ImGui_Button(ctx, "--- DROP .RPP FILES HERE ---", -1, 40)
                reaper.ImGui_PopStyleColor(ctx, 2)
            end
            reaper.ImGui_EndChild(ctx)
        end
        if current then
            if reaper.ImGui_BeginDragDropTarget(ctx) then
                local rv, count = reaper.ImGui_AcceptDragDropPayloadFiles(ctx)
                if rv then
                    for f = 0, count - 1 do
                        local ok, filepath = reaper.ImGui_GetDragDropPayloadFile(ctx, f)
                        if ok then
                            local name = filepath:match("([^/\\]+)%.[rR][pP][pP]$")
                            if name then table.insert(current.songs, {title = name, path = filepath}) end
                        end
                    end
                    SaveConfig()
                end
                reaper.ImGui_EndDragDropTarget(ctx)
            end
        end
        if deploy_state > 0 then
            reaper.ImGui_Button(ctx, "DEPLOYING... PLEASE WAIT", -1, 35)
        else
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_GREEN)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFFFF)
            if reaper.ImGui_Button(ctx, "DEPLOY SETLIST", -1, 35) then
                deploy_group = data.groups[data.selected_group]
                if deploy_group and #deploy_group.songs > 0 then deploy_state = 1; deploy_last_count = -1; deploy_frame_wait = 0 end
            end
            reaper.ImGui_PopStyleColor(ctx, 2)
        end
    reaper.ImGui_EndGroup(ctx)
    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_PopStyleColor(ctx)
end

function DrawHelp()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_TEXT)
    if reaper.ImGui_BeginChild(ctx, "help", 0, 0, 1) then
        reaper.ImGui_PushFont(ctx, nil, 15)
        if reaper.ImGui_BeginTabBar(ctx, "help_tabs") then
            if reaper.ImGui_BeginTabItem(ctx, "EN") then
                reaper.ImGui_TextWrapped(ctx, [[
# TLC SETLIST MANAGER HELP

1. ORGANIZING BANDS
Use the left column to manage your bands. Right-click to Rename or Delete.

2. CREATING SETLISTS
Select a band and drag .RPP files onto the central area to add songs.

3. DEPLOYING
Click "DEPLOY SETLIST" to load projects into project tabs automatically.

Developed by Jordi Molas - The Little Cavern 03-2026
]])
                reaper.ImGui_EndTabItem(ctx)
            end
            if reaper.ImGui_BeginTabItem(ctx, "ES") then
                reaper.ImGui_TextWrapped(ctx, [[
# AYUDA TLC SETLIST MANAGER

1. ORGANIZAR BANDAS
Usa la columna izquierda para gestionar tus bandas. Clic derecho para Renombrar o Eliminar.

2. CREAR SETLISTS
Selecciona una banda y arrastra archivos .RPP a la zona central para anadir canciones.

3. DESPLEGAR
Haz clic en "DEPLOY SETLIST" para cargar los proyectos en pestanas automaticamente.

Desarrollado por Jordi Molas - The Little Cavern 03-2026
]])
                reaper.ImGui_EndTabItem(ctx)
            end
            reaper.ImGui_EndTabBar(ctx)
        end
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_EndChild(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx)
end

-- =================================================================
--  MAIN LOOP
-- =================================================================
function Main()
    HandleAsyncDeploy()
    local color_count = PushTheme()
    local style_count = 0
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 20, 20); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 4); style_count = style_count + 1
    reaper.ImGui_SetNextWindowSize(ctx, 720, 650, reaper.ImGui_Cond_Always())
    local visible, open = reaper.ImGui_Begin(ctx, 'TLC SETLIST MANAGER', true, 64)
    if visible then
        local img_ok = logo_img and (not reaper.ImGui_ValidatePtr or reaper.ImGui_ValidatePtr(logo_img, 'ImGui_Image*'))
        if not img_ok and logo_img then logo_img = reaper.ImGui_CreateImage(logo_path) end
        DrawLogo()
        reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) - 200)
        DrawSupportLink()
        reaper.ImGui_Spacing(ctx); reaper.ImGui_Separator(ctx); reaper.ImGui_Spacing(ctx)
        DrawNavBar()
        reaper.ImGui_Spacing(ctx); reaper.ImGui_Separator(ctx); reaper.ImGui_Spacing(ctx)
        if current_mode == 0 then DrawManager() else DrawHelp() end
        reaper.ImGui_End(ctx)
    end
    reaper.ImGui_PopStyleVar(ctx, style_count); PopTheme(color_count)
    if open then reaper.defer(Main) end
end

LoadConfig(); Main()
