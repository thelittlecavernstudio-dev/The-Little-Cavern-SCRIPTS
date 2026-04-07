-- @description TLC Dashboard
-- @version 4.0.1
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about
--   # TLC Dashboard
--   Central hub for session templates, recent projects and studio tools.
--   Includes quick actions, color‑coded sessions and auto-start options.
-- @website https://ko-fi.com/thelittlecavern
-- @provides
--   [main] .
--   [nomain] TLC Dashboard Instructions_EN.txt
--   [nomain] TLC Dashboard Instructions_ES.txt
--   [nomain] TLC_logo_transparent_white.png > TLC Dashboard_logo.png
-- @changelog
--   # v4.0.1
--   * Added Auto-Start toggle with clear user confirmation.
--   # v4.0.0
--   * Unified dark UI theme and sizing consistency.
--   * Switched logo to white variant and preserved aspect ratio.
--   # v3.9.2
--   * Fixed missing Help tab and description logic.
--   * Restored full ReaImGui interface.

if not reaper.ImGui_CreateContext then
  reaper.MB("Este script requiere ReaImGui.", "Error", 0)
  return
end

local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local db_path = script_path .. "TLC Dashboard Database.txt"
local help_path_en = script_path .. "TLC Dashboard Instructions_EN.txt"
local help_path_es = script_path .. "TLC Dashboard Instructions_ES.txt"
local logo_path = script_path .. "TLC Dashboard_logo.png"
local ini_path = reaper.GetResourcePath() .. "/reaper.ini"
local ruta_templates = reaper.GetResourcePath() .. "/ProjectTemplates/"

local function EnsureFile(path)
    local f = io.open(path, "r")
    if f then f:close(); return end
    f = io.open(path, "w")
    if f then f:write(""); f:close() end
end

EnsureFile(db_path)

local ctx = reaper.ImGui_CreateContext('TLC Dashboard')
local sessions = {}
local recent_projects = {}
local current_mode = 0 
local current_lang = "EN"
local in_color_vec = {150, 150, 150}
local in_btn, in_temp, in_sc, in_act = "", "", "", ""
local editing_session_idx = -1
local studio_name = reaper.GetExtState("SessionBuilder", "StudioName")
if studio_name == "" then studio_name = "LITTLE CAVERN" end

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
local COL_TEXT_DARK = GetColor(20, 20, 20)
local COL_WHITE = GetColor(255, 255, 255)
local COL_TEXT_DIM = GetColor(160, 160, 160)
local COL_LINK = COL_ACCENT

local FONT_SMALL = 13
local FONT_BASE = 14
local FONT_HEADER = 16

local BTN_H_SM = 28
local BTN_H = 36
local BTN_H_LG = 44
local NAV_H = 38

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

local function PushCol(name, val)
    local key = "Col_" .. name; local id = reaper["ImGui_" .. key]
    if id then if type(id) == "function" then id = id() end reaper.ImGui_PushStyleColor(ctx, id, val) return true end
    return false
end

local function PushVar(name, v1, v2)
    local key = "StyleVar_" .. name; local id = reaper["ImGui_" .. key]
    if id then if type(id) == "function" then id = id() end if v2 then reaper.ImGui_PushStyleVar(ctx, id, v1, v2) else reaper.ImGui_PushStyleVar(ctx, id, v1) end return true end
    return false
end

local logo_img = nil
if reaper.ImGui_CreateImage then
    local f = io.open(logo_path, "r"); if f then f:close() logo_img = reaper.ImGui_CreateImage(logo_path) end
end

local function DrawLogo()
    if not logo_img or (reaper.ImGui_ValidatePtr and not reaper.ImGui_ValidatePtr(logo_img, 'ImGui_Image*')) then
        if reaper.ImGui_CreateImage then
            local f = io.open(logo_path, "r")
            if f then f:close(); logo_img = reaper.ImGui_CreateImage(logo_path) end
        end
    end
    if not logo_img or (reaper.ImGui_ValidatePtr and not reaper.ImGui_ValidatePtr(logo_img, 'ImGui_Image*')) then
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

function LeerBaseDatos()
    local f = io.open(db_path, "r"); if not f then return end
    sessions = {}
    for line in f:lines() do
        if line ~= "" then
            local label, template, screenset, action, color_str = line:match("([^|]+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
            if label then
                local r, g, b = (color_str or "150,150,150"):match("(%d+),(%d+),(%d+)")
                table.insert(sessions, {label = label, template = template, screenset = tonumber(screenset) or 0, action = action, color = {tonumber(r) or 150, tonumber(g) or 150, tonumber(b) or 150}})
            end
        end
    end
    f:close()
end

function GuardarBaseDatos()
    local f = io.open(db_path, "w")
    if f then
        for _, s in ipairs(sessions) do f:write(string.format("%s|%s|%s|%s|%d,%d,%d\n", s.label, s.template or "", s.screenset or "0", s.action or "", s.color[1], s.color[2], s.color[3])) end
        f:close()
    end
end

function LeerProyectosRecientes()
    recent_projects = {}
    local f = io.open(ini_path, "r"); if not f then return end
    local temp_raw = {}
    for line in f:lines() do
        local path = line:match("^recent%d*=(.+)")
        if path then table.insert(temp_raw, (path:gsub('"', ''))) end
    end
    f:close()
    for i = #temp_raw, 1, -1 do
        local p = temp_raw[i]; local is_dup = false
        for _, a in ipairs(recent_projects) do if a.path == p then is_dup = true break end end
        if not is_dup and #recent_projects < 10 and p:lower():match("%.rpp$") then
            local name = p:match("([^/\\]+)%.rpp$") or "Project"
            table.insert(recent_projects, {name = name, path = p})
        end
    end
end

local function ReadStartupFile()
    local path = reaper.GetResourcePath() .. "/Scripts/__startup.lua"
    local f = io.open(path, "r")
    if not f then return path, "" end
    local c = f:read("*all") or ""
    f:close()
    if c:match("^%s*[01]+%s*$") then c = "" end
    return path, c
end

local function WriteStartupFile(path, content)
    local f = io.open(path, "w")
    if f then f:write(content or ""); f:close() end
end

local function IsAutoStartEnabled()
    local _, c = ReadStartupFile()
    return c:find("TLC Dashboard Auto%-Start %(BEGIN%)", 1) ~= nil or c:find("TLC Dashboard.lua", 1, true) ~= nil
end

function ToggleAutoStart(skip_prompt)
    local path, c = ReadStartupFile()
    local full_path = debug.getinfo(1, "S").source:match("@?(.*)")
    local block = "\n-- TLC Dashboard Auto-Start (BEGIN)\nreaper.Main_OnCommand(reaper.AddRemoveReaScript(true, 0, [[" .. full_path .. "]], true), 0)\n-- TLC Dashboard Auto-Start (END)\n"
    local enabled = IsAutoStartEnabled()
    if not enabled then
        if skip_prompt or reaper.ShowMessageBox("Enable Auto-Start?", "Auto-Start", 1) == 1 then
            if not c:find("TLC Dashboard Auto%-Start %(BEGIN%)", 1) then
                c = (c == "" and "" or c) .. block
            end
            WriteStartupFile(path, c)
            reaper.MB("Enabled!", "Success", 0)
        end
    else
        if skip_prompt or reaper.ShowMessageBox("Remove Auto-Start?", "Auto-Start", 1) == 1 then
            local pattern = "%-%- TLC Dashboard Auto%-Start %(BEGIN%)[%s%S]-TLC Dashboard Auto%-Start %(END%)\n?"
            c = c:gsub(pattern, "")
            WriteStartupFile(path, c)
            reaper.MB("Removed.", "Success", 0)
        end
    end
end

local function DrawAutoStartToggle(toggle_w, toggle_h)
    local enabled = IsAutoStartEnabled()
    local id = "autostart_toggle"
    reaper.ImGui_InvisibleButton(ctx, id, toggle_w, toggle_h)
    local clicked = reaper.ImGui_IsItemClicked(ctx)

    local dl = reaper.ImGui_GetWindowDrawList(ctx)
    local x, y = reaper.ImGui_GetItemRectMin(ctx)
    local x2, y2 = reaper.ImGui_GetItemRectMax(ctx)
    local radius = toggle_h / 2
    local bg_col = enabled and COL_GREEN or COL_FRAME_H
    local knob_col = COL_WHITE
    reaper.ImGui_DrawList_AddRectFilled(dl, x, y, x2, y2, bg_col, radius)
    local knob_x = enabled and (x2 - radius) or (x + radius)
    reaper.ImGui_DrawList_AddCircleFilled(dl, knob_x, y + radius, radius - 2, knob_col)

    if clicked then
        local msg = enabled
            and "This will remove TLC Dashboard from __startup.lua.\nThe dashboard will NOT open automatically when REAPER starts.\n\nContinue?"
            or  "This will add TLC Dashboard to __startup.lua.\nThe dashboard will open automatically when REAPER starts.\n\nContinue?"
        if reaper.ShowMessageBox(msg, "Auto-Start", 1) == 1 then
            ToggleAutoStart(true)
        end
    end

end

function DrawSupportLink()
    reaper.ImGui_PushFont(ctx, nil, FONT_SMALL); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_LINK)
    reaper.ImGui_Text(ctx, "Support the TLC Team")
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
        if reaper.ImGui_IsMouseClicked(ctx, 0) then
            local url = "https://ko-fi.com/thelittlecavern"
            local os = reaper.GetOS(); if os:match("Win") then reaper.ExecProcess('cmd.exe /C start "" "' .. url .. '"', 0) else reaper.ExecProcess('/usr/bin/open "' .. url .. '"', 0) end
        end
    end
    reaper.ImGui_PopStyleColor(ctx); reaper.ImGui_PopFont(ctx)
end

function DrawNavBar()
    reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    local labels = {"HOME", "ADD SESSION", "MANAGE SESSIONS", "HELP"}
    for i, label in ipairs(labels) do
        local idx = i - 1; local active = current_mode == idx
        local btn_w = reaper.ImGui_CalcTextSize(ctx, label) + 40
        local cur_pos_x, cur_pos_y = reaper.ImGui_GetCursorScreenPos(ctx)
        local btn_col = active and COL_ACCENT_D or COL_FRAME
        local btn_h = active and COL_ACCENT_H or COL_FRAME_H
        local btn_a = active and COL_ACCENT or COL_FRAME_A
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), btn_col)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), btn_h)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), btn_a)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), active and COL_WHITE or COL_TEXT_DIM)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)
        if reaper.ImGui_Button(ctx, label .. "##nav", btn_w, NAV_H) then current_mode = idx end
        if active then reaper.ImGui_DrawList_AddRectFilled(reaper.ImGui_GetWindowDrawList(ctx), cur_pos_x, cur_pos_y + (NAV_H - 3), cur_pos_x + btn_w, cur_pos_y + NAV_H, COL_ACCENT_D) end
        reaper.ImGui_PopStyleVar(ctx); reaper.ImGui_PopStyleColor(ctx, 4); reaper.ImGui_SameLine(ctx, nil, 5)
    end
    reaper.ImGui_PopFont(ctx)
end

function DrawDashboard()
    local win_w = reaper.ImGui_GetWindowWidth(ctx); VSpace(6)
    reaper.ImGui_BeginChild(ctx, 'c_sessions', (win_w - 80) * 0.40, 0, 0)
    for i, s in ipairs(sessions) do
        reaper.ImGui_PushID(ctx, i); local r, g, b = s.color[1]/255, s.color[2]/255, s.color[3]/255
        local lum = (r * 0.299 + g * 0.587 + b * 0.114)
        local hr, hg, hb = r, g, b
        if lum > 0.6 then
            hr = math.max(r - 0.12, 0); hg = math.max(g - 0.12, 0); hb = math.max(b - 0.12, 0)
        else
            hr = math.min(r + 0.12, 1); hg = math.min(g + 0.12, 1); hb = math.min(b + 0.12, 1)
        end
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, 1))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), reaper.ImGui_ColorConvertDouble4ToU32(hr, hg, hb, 1))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), reaper.ImGui_ColorConvertDouble4ToU32(hr, hg, hb, 1))
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), lum > 0.6 and COL_TEXT_DARK or COL_WHITE)
        reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
        if reaper.ImGui_Button(ctx, s.label:upper() .. "##btn", -1, BTN_H_LG) then
            if not s.template or s.template == "" then reaper.Main_OnCommand(40001, 0) else reaper.Main_openProject("template:" .. ruta_templates .. s.template) end
        end
        reaper.ImGui_PopFont(ctx); reaper.ImGui_PopStyleColor(ctx, 4); reaper.ImGui_PopID(ctx); VSpace(6)
    end
    reaper.ImGui_EndChild(ctx); reaper.ImGui_SameLine(ctx, nil, 40); reaper.ImGui_BeginGroup(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK); reaper.ImGui_PushFont(ctx, nil, FONT_HEADER); reaper.ImGui_Text(ctx, "YOUR LAST 10 PROJECTS"); reaper.ImGui_PopFont(ctx)
    reaper.ImGui_PushFont(ctx, nil, FONT_BASE); for i, proj in ipairs(recent_projects) do if reaper.ImGui_Selectable(ctx, i .. ". " .. proj.name, false, 0, 0, BTN_H_SM) then reaper.Main_openProject(proj.path) end end; reaper.ImGui_PopFont(ctx)
    VSpace(6); if reaper.ImGui_Selectable(ctx, "[ OPEN PROJECT EXPLORER ]") then reaper.Main_OnCommand(40025, 0) end
    reaper.ImGui_PopStyleColor(ctx); reaper.ImGui_EndGroup(ctx)
end

function DrawAddSession()
    local win_w, box_w = reaper.ImGui_GetWindowWidth(ctx), 600; reaper.ImGui_SetCursorPosX(ctx, (win_w - box_w) / 2); reaper.ImGui_BeginGroup(ctx); reaper.ImGui_PushFont(ctx, nil, FONT_BASE); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK)
    if editing_session_idx ~= -1 then
        reaper.ImGui_Text(ctx, "EDIT SESSION")
        VSpace(6)
    end
    reaper.ImGui_Text(ctx, "Studio Name:"); reaper.ImGui_SetNextItemWidth(ctx, box_w); _, studio_name = reaper.ImGui_InputText(ctx, "##studio", studio_name); if _ then reaper.SetExtState("SessionBuilder", "StudioName", studio_name, true) end
    reaper.ImGui_Text(ctx, "Button Name:"); reaper.ImGui_SetNextItemWidth(ctx, box_w); _, in_btn = reaper.ImGui_InputText(ctx, "##bn", in_btn or "")
    reaper.ImGui_Text(ctx, "Template (.rpp filename):"); reaper.ImGui_SetNextItemWidth(ctx, box_w); _, in_temp = reaper.ImGui_InputText(ctx, "##tm", in_temp or "")
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_TEXT_DIM)
    reaper.ImGui_Text(ctx, "Example: MyTemplate.rpp")
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_Text(ctx, "Screenset ID:"); reaper.ImGui_SetNextItemWidth(ctx, box_w); _, in_sc = reaper.ImGui_InputText(ctx, "##sc", in_sc or "")
    reaper.ImGui_Text(ctx, "Action ID:"); reaper.ImGui_SetNextItemWidth(ctx, box_w); _, in_act = reaper.ImGui_InputText(ctx, "##ac", in_act or "")
    reaper.ImGui_Text(ctx, "Button Color:"); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
    local rv, col = reaper.ImGui_ColorEdit3(ctx, "##ce", (in_color_vec[1] << 16) | (in_color_vec[2] << 8) | in_color_vec[3], 32)
    reaper.ImGui_PopStyleColor(ctx); if rv then in_color_vec[1] = (col >> 16) & 0xFF; in_color_vec[2] = (col >> 8) & 0xFF; in_color_vec[3] = col & 0xFF end
    VSpace(8); if (in_btn or "") ~= "" then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_GREEN)
        local btn_label = editing_session_idx ~= -1 and "SAVE CHANGES" or "SAVE AND ADD SESSION"
        if reaper.ImGui_Button(ctx, btn_label, 220, BTN_H) then
            if editing_session_idx ~= -1 and sessions[editing_session_idx] then
                sessions[editing_session_idx] = {label = in_btn, template = in_temp, screenset = tonumber(in_sc) or 0, action = in_act, color = {in_color_vec[1], in_color_vec[2], in_color_vec[3]}}
                GuardarBaseDatos(); reaper.MB("Session updated!", "TLC", 0)
                editing_session_idx = -1
            else
                table.insert(sessions, {label = in_btn, template = in_temp, screenset = tonumber(in_sc) or 0, action = in_act, color = {in_color_vec[1], in_color_vec[2], in_color_vec[3]}})
                GuardarBaseDatos(); reaper.MB("Session added!", "TLC", 0)
            end
            in_btn, in_temp, in_sc, in_act = "", "", "", ""
        end
        reaper.ImGui_PopStyleColor(ctx)
        if editing_session_idx ~= -1 then
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "CANCEL", 100, BTN_H) then
                editing_session_idx = -1
                in_btn, in_temp, in_sc, in_act = "", "", "", ""
            end
        end
    end; reaper.ImGui_PopStyleColor(ctx); reaper.ImGui_PopFont(ctx); reaper.ImGui_EndGroup(ctx)
end

function DrawManage()
    local box_w = 530; reaper.ImGui_SetCursorPosX(ctx, (reaper.ImGui_GetWindowWidth(ctx) - box_w) / 2); reaper.ImGui_BeginGroup(ctx); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK)
    reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    local move_from, move_to = -1, -1
    for i, s in ipairs(sessions) do
        reaper.ImGui_PushID(ctx, i); reaper.ImGui_Selectable(ctx, " [::] " .. s.label:upper(), false, 0, box_w - 210, BTN_H)
        if reaper.ImGui_BeginDragDropSource(ctx) then reaper.ImGui_SetDragDropPayload(ctx, 'DND', tostring(i)); reaper.ImGui_Text(ctx, "Moving: " .. s.label); reaper.ImGui_EndDragDropSource(ctx) end
        if reaper.ImGui_BeginDragDropTarget(ctx) then local r, p = reaper.ImGui_AcceptDragDropPayload(ctx, 'DND'); if r then move_from, move_to = tonumber(p), i end; reaper.ImGui_EndDragDropTarget(ctx) end
        reaper.ImGui_SameLine(ctx, box_w - 200); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_FRAME); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_TEXT_DIM)
        if reaper.ImGui_Button(ctx, "EDIT", 90, BTN_H) then
            editing_session_idx = i
            in_btn = s.label or ""
            in_temp = s.template or ""
            in_sc = tostring(s.screenset or "")
            in_act = s.action or ""
            in_color_vec = {s.color[1], s.color[2], s.color[3]}
            current_mode = 1
        end
        reaper.ImGui_PopStyleColor(ctx, 2)
        reaper.ImGui_SameLine(ctx, box_w - 100); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COL_MAROON); reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_WHITE)
        if reaper.ImGui_Button(ctx, "DELETE", 100, BTN_H) then if reaper.ShowMessageBox("Delete '" .. s.label .. "'?", "Confirm", 1) == 1 then table.remove(sessions, i); GuardarBaseDatos() end end
        reaper.ImGui_PopStyleColor(ctx, 2); reaper.ImGui_PopID(ctx); VSpace(6)
    end
    if move_from ~= -1 then local el = table.remove(sessions, move_from); table.insert(sessions, move_to, el); GuardarBaseDatos() end
    reaper.ImGui_PopFont(ctx); reaper.ImGui_PopStyleColor(ctx); reaper.ImGui_EndGroup(ctx)
end

function DrawHelp()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COL_BLACK); reaper.ImGui_PushFont(ctx, nil, FONT_BASE)
    if reaper.ImGui_Selectable(ctx, "[ ENGLISH ]", current_lang == "EN", 0, 120) then current_lang = "EN" end
    reaper.ImGui_SameLine(ctx); if reaper.ImGui_Selectable(ctx, "[ ESPAÃ‘OL ]", current_lang == "ES", 0, 120) then current_lang = "ES" end
    reaper.ImGui_Separator(ctx); VSpace(6)
    if reaper.ImGui_BeginChild(ctx, 'htxt', 0, 0, 1) then
        local f = io.open(current_lang == "EN" and help_path_en or help_path_es, "r")
        if f then reaper.ImGui_TextWrapped(ctx, f:read("*all")); f:close() end
        reaper.ImGui_EndChild(ctx)
    end
    reaper.ImGui_PopFont(ctx); reaper.ImGui_PopStyleColor(ctx)
end

function MainLoop()
    local color_count = PushTheme()
    local style_count = 0
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 20, 20); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 4); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 6); style_count = style_count + 1
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 8, 6); style_count = style_count + 1
    reaper.ImGui_SetNextWindowSize(ctx, 800, 680, reaper.ImGui_Cond_Always())
    local visible, open = reaper.ImGui_Begin(ctx, 'TLC DASHBOARD v4.0.1', true, 64)
    if visible then
        DrawLogo()
        reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) - 150); DrawSupportLink()
        VSpace(6); reaper.ImGui_Separator(ctx); VSpace(6)
        local nav_y = reaper.ImGui_GetCursorPosY(ctx)
        DrawNavBar()
        local toggle_w = 70
        local toggle_h = 22
        reaper.ImGui_SetCursorPosY(ctx, nav_y + (NAV_H - toggle_h) / 2)
        reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetWindowWidth(ctx) - toggle_w - 20)
        DrawAutoStartToggle(toggle_w, toggle_h)
        VSpace(6); reaper.ImGui_Separator(ctx); VSpace(6)
        if current_mode == 0 then DrawDashboard() elseif current_mode == 1 then DrawAddSession() elseif current_mode == 2 then DrawManage() elseif current_mode == 3 then DrawHelp() end
        reaper.ImGui_End(ctx)
    end
    reaper.ImGui_PopStyleVar(ctx, style_count); PopTheme(color_count)
    if open then reaper.defer(MainLoop) end
end

LeerBaseDatos(); LeerProyectosRecientes(); MainLoop()
