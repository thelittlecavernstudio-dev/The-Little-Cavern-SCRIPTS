-- @description TLC Analog Matrix
-- @version 1.6
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @website https://ko-fi.com/thelittlecavern
-- @provides
--   [main] .
--   [nomain] TLC_logo_transparent_white.png > TLC Analog Molecule_logo.png
-- @about
--   # Analog Matrix Control Suite (GFX Edition)
--   * High-visibility interface for Analog Molecule plugin parameters.
--   # Manual Line-Break Help & Settings
--   * Refined UI labels and a robust multiline help system with manual formatting.
-- @changelog
--   # v1.6 (2026-04-06)
--     + Mixed state detection: flavor selector and sliders show "MIXED" when
--       instances within a topology have divergent DSP values.
--     + Help overlay redesigned with two tabs (SETUP & USAGE / CONSOLE FLAVORS)
--       and full bilingual content (EN / ES) with scroll support.
--     + Text input fields support drag selection, double-click word selection,
--       and selection highlight.
--     + DetectFlavor(): flavor label inferred from DSP values each frame;
--       no longer read directly from JSFX parameter.
--     * Removed gmem/LINK flavor-push system (EnsureGmem, PushFlavorToNetwork,
--       SetLinkBroadcastForTopo). TAM always shows Custom — documented in Help.
--     * Removed debug logging, IPC command system, and param normalisation helpers.
--     * Removed debounce/timing machinery (pending_flavor, link_pulse, write
--       debounce, EnforceTopologyByConfig, EnforceLinkOnAll, ApplyAll).
--     * Removed SaveMatrixState/LoadMatrixState: JSFX project state is now the
--       single source of truth on startup.
--     * Preset table restructured from [topo][flavor] to [flavor][topo].
--     * mixed flag moved into state[topo].mixed; separate mixed table removed.
--     * AutoConfig now disables JSFX internal LINK on all instances.
--     * UpdatePlugins and PushChange simplified; ApplyPresetDSP writes DSP
--       values directly without gmem.
--   # v1.5
--   * Unified dark UI theme and improved legibility.
--   * Switched logo to white variant.
--   # v1.4
--   * FULL RESTORATION of logic.
--   * Renamed window to TLC Analog Molecule Matrix.
--   * Moved Support link to header (#0000EE).

local plugin_name = "Analog Molecule"
local ext_section = "JORDAN_AM_MATRIX"

-- Parameter IDs
local p_id, p_topo, p_flux, p_therm, p_text, p_drive, p_link, p_flavor = 0, 1, 3, 4, 5, 6, 11, 12

-- State Matrix  (mixed=true when instances within a topology have divergent DSP values)
local state = {
    [0] = { flavor=0, flux=20, therm=20, text=12, mixed=false },
    [1] = { flavor=0, flux=20, therm=20, text=12, mixed=false },
    [2] = { flavor=0, flux=20, therm=20, text=12, mixed=false }
}

-- Hardcoded Presets (topology-specific, matching JSFX load_flavor exactly)
-- Keys: [flavor_id][topo_idx]  topo 0=Channel, 1=Bus, 2=Master
local flavor_presets = {
    [1] = {  -- British Class A
        [0] = {flux=35, therm=40, text=25},
        [1] = {flux=25, therm=50, text=30},
        [2] = {flux=15, therm=30, text=20},
    },
    [2] = {  -- Solid State E
        [0] = {flux=20, therm=20, text=15},
        [1] = {flux=15, therm=35, text=20},
        [2] = {flux=10, therm=20, text=12},
    },
    [3] = {  -- US Discrete
        [0] = {flux=10, therm=10, text=10},
        [1] = {flux=10, therm=15, text=12},
        [2] = {flux=5,  therm=10, text=8},
    },
    [4] = {  -- Modern Mastering
        [0] = {flux=5,  therm=5,  text=5},
        [1] = {flux=5,  therm=5,  text=5},
        [2] = {flux=2,  therm=5,  text=2},
    },
}

-- UI Variables
local bg_r, bg_g, bg_b = 27/255, 27/255, 27/255
local col_panel = {35/255, 35/255, 35/255}
local col_frame = {52/255, 52/255, 52/255}
local col_text = {230/255, 230/255, 230/255}
local col_text_dim = {160/255, 160/255, 160/255}
local col_accent = {51/255, 204/255, 255/255}
local col_accent_d = {30/255, 111/255, 210/255}
local col_red = {120/255, 35/255, 35/255}
local col_green = {44/255, 138/255, 75/255}
local col_warn = {200/255, 120/255, 20/255}  -- orange for mixed state
local link_M_to_B, link_M_to_C, link_B_to_C = false, false, false
local excluded_tracks = {}   -- populated by AutoConfig; checked in UpdatePlugins/ReadBack
local mouse_down, active_slider = false, ""
local last_mouse_cap, last_click_time = 0, 0

-- Text input key codes (REAPER GFX encodes special keys as 4-char ASCII packed as int32)
local KEY_LEFT  = 1818584692  -- "left"
local KEY_RIGHT = 1919379572  -- "rght"
local KEY_HOME  = 1752132965  -- "home"
local KEY_END   = 6647396     -- "\x00end"
local KEY_DEL   = 6579564     -- "\x00del"

-- Text input drag/selection state
local input_drag_active = false
local input_drag_key    = nil
local input_drag_anchor = 0
local input_last_click  = { key=nil, time=0, pos=0 }

-- Paths
local script_path = debug.getinfo(1, "S").source:match("@?(.*[\\/])")
local logo_path = script_path .. "TLC Analog Molecule_logo.png"

-- Overlays
local show_config = false
local show_help = false
local help_lang = "EN"
local help_tab = "SETUP"   -- "SETUP" | "FLAVORS"
local help_scroll = 0
local cfg_w, cfg_h = 660, 540
local cfg_x, cfg_y = 0, 0
local is_dragging_cfg = false
local drag_dx, drag_dy = 0, 0
local cfg_temp = {}
local active_input_key = nil

local logo_loaded = false

--------------------------------------------------------------------------------
-- 1. DATABASE ENGINE
--------------------------------------------------------------------------------
function GetThesaurus()
    local exc = reaper.GetExtState(ext_section, "exclusions")
    if exc == "0" then exc = "" end
    local bk = reaper.GetExtState(ext_section, "bus_keywords")
    if bk == "0" or bk == "" then bk = "BUS, GRP" end

    return {
        master_name = reaper.GetExtState(ext_section, "master_name") ~= "" and reaper.GetExtState(ext_section, "master_name") or "MIXBUS",
        use_reaper_master = reaper.GetExtState(ext_section, "use_reaper_master") ~= "0",
        bus_keywords = bk,
        bus_parents = reaper.GetExtState(ext_section, "bus_parents") ~= "0",
        exclusions = exc
    }
end

function SaveThesaurus(cfg)
    reaper.SetExtState(ext_section, "master_name", cfg.master_name.val:upper(), true)
    reaper.SetExtState(ext_section, "use_reaper_master", cfg.use_reaper_master and "1" or "0", true)
    reaper.SetExtState(ext_section, "bus_keywords", cfg.bus_keywords.val:upper(), true)
    reaper.SetExtState(ext_section, "bus_parents", cfg.bus_parents and "1" or "0", true)
    reaper.SetExtState(ext_section, "exclusions", cfg.exclusions.val:upper(), true)
end

function MatchCSV(text, csv)
    if not csv or csv == "" then return false end
    for word in csv:gmatch('([^,]+)') do
        local clean_word = word:gsub("^%s*(.-)%s*$", "%1"):upper()
        if text:upper():find(clean_word, 1, true) then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- 2. PROCESSING ENGINE
--------------------------------------------------------------------------------

-- Returns the flavor id (1-4) if the current DSP values match a known preset for
-- the given topology, or 0 (Custom) if they don't. Tolerance of 0.5 to handle
-- float rounding from TrackFX_GetParam.
local function DetectFlavor(topo)
    for fid = 1, 4 do
        local p = flavor_presets[fid] and flavor_presets[fid][topo]
        if p and math.abs(state[topo].flux  - p.flux)  < 0.5
             and math.abs(state[topo].therm - p.therm) < 0.5
             and math.abs(state[topo].text  - p.text)  < 0.5 then
            return fid
        end
    end
    return 0
end

function ReadBackFromPlugins()
    if mouse_down then return end
    -- Collect DSP values from ALL instances per topology
    local instances = { [0]={}, [1]={}, [2]={} }
    for t = -1, reaper.CountTracks(0) - 1 do
        local track = (t == -1) and reaper.GetMasterTrack(0) or reaper.GetTrack(0, t)
        if not excluded_tracks[track] then
            for i = 0, reaper.TrackFX_GetCount(track) - 1 do
                local _, fx_name = reaper.TrackFX_GetFXName(track, i, "")
                if fx_name:match(plugin_name) then
                    local topo = math.floor(reaper.TrackFX_GetParam(track, i, p_topo) + 0.5)
                    if topo >= 0 and topo <= 2 then
                        table.insert(instances[topo], {
                            flux  = reaper.TrackFX_GetParam(track, i, p_flux),
                            therm = reaper.TrackFX_GetParam(track, i, p_therm),
                            text  = reaper.TrackFX_GetParam(track, i, p_text),
                        })
                    end
                end
            end
        end
    end
    -- Evaluate each topology
    for topo = 0, 2 do
        local list = instances[topo]
        if #list == 0 then
            -- no instances: leave state unchanged
        else
            local ref = list[1]
            local is_mixed = false
            for j = 2, #list do
                if math.abs(list[j].flux  - ref.flux)  > 0.05 or
                   math.abs(list[j].therm - ref.therm) > 0.05 or
                   math.abs(list[j].text  - ref.text)  > 0.05 then
                    is_mixed = true
                    break
                end
            end
            -- Use first instance as reference values for display
            state[topo].flux  = ref.flux
            state[topo].therm = ref.therm
            state[topo].text  = ref.text
            state[topo].mixed = is_mixed
            -- flavor: -1 signals mixed (no button highlighted, shows warning)
            state[topo].flavor = is_mixed and -1 or DetectFlavor(topo)
        end
    end
end

function UpdatePlugins(target_topo, param_idx, value)
    for t = -1, reaper.CountTracks(0) - 1 do
        local track = (t == -1) and reaper.GetMasterTrack(0) or reaper.GetTrack(0, t)
        if not excluded_tracks[track] then
            for i = 0, reaper.TrackFX_GetCount(track) - 1 do
                local _, fx_name = reaper.TrackFX_GetFXName(track, i, "")
                if fx_name:match(plugin_name) then
                    local current_topo = math.floor(reaper.TrackFX_GetParam(track, i, p_topo) + 0.5)
                    if current_topo == target_topo then
                        reaper.TrackFX_SetParam(track, i, param_idx, value)
                    end
                end
            end
        end
    end
end

function PushChange(source_topo, param_idx, value, key_name)
    state[source_topo][key_name] = value
    UpdatePlugins(source_topo, param_idx, value)
    if source_topo == 2 then 
        if link_M_to_B then state[1][key_name] = value; UpdatePlugins(1, param_idx, value) end
        if link_M_to_C then state[0][key_name] = value; UpdatePlugins(0, param_idx, value) end
    elseif source_topo == 1 then 
        if link_B_to_C and not link_M_to_C then state[0][key_name] = value; UpdatePlugins(0, param_idx, value) end
    end
end

local function CheckSliderChange(topo_idx, param, val, key)
    if val ~= state[topo_idx][key] then
        PushChange(topo_idx, param, val, key)
        -- Reset flavor to Custom in Lua state when user manually drags a slider.
        -- We do NOT write p_flavor to JSFX (it always stays at 0 there).
        if state[topo_idx].flavor ~= 0 then state[topo_idx].flavor = 0 end
    end
end

function AutoConfig()
    local cfg = GetThesaurus()
    excluded_tracks = {}   -- reset on each scan
    reaper.Undo_BeginBlock()
    local current_id = 1
    for t = -1, reaper.CountTracks(0) - 1 do
        local track = (t == -1) and reaper.GetMasterTrack(0) or reaper.GetTrack(0, t)
        local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local is_folder = (t ~= -1) and (reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1) or false
        local is_native_master = (t == -1)
        local target_topo = 0
        local skip = false
        if (cfg.use_reaper_master and is_native_master) or (not cfg.use_reaper_master and track_name:upper() == cfg.master_name:upper()) then
            target_topo = 2
        elseif MatchCSV(track_name, cfg.exclusions) then
            skip = true
            excluded_tracks[track] = true
        elseif (cfg.bus_parents and is_folder) or MatchCSV(track_name, cfg.bus_keywords) then
            target_topo = 1
        end
        if not skip then
            for i = 0, reaper.TrackFX_GetCount(track) - 1 do
                local _, fx_name = reaper.TrackFX_GetFXName(track, i, "")
                if fx_name:match(plugin_name) then
                    reaper.TrackFX_SetParam(track, i, p_topo, target_topo)
                    reaper.TrackFX_SetParam(track, i, p_id, current_id)
                    reaper.TrackFX_SetParam(track, i, p_link, 0)  -- disable JSFX internal link: Lua handles all propagation via UpdatePlugins/PushChange
                    current_id = (current_id % 180) + 1
                end
            end
        end
    end
    reaper.Undo_EndBlock("AM Matrix: Scan", -1)
    ReadBackFromPlugins()
end

--------------------------------------------------------------------------------
-- 3. DRAWING & UI COMPONENTS
--------------------------------------------------------------------------------
function DrawCheckbox(x, y, label, checked, disabled)
    local alpha = disabled and 0.4 or 1.0
    gfx.set(col_text_dim[1], col_text_dim[2], col_text_dim[3], alpha)
    gfx.rect(x, y, 16, 16, false)
    if checked then
        gfx.line(x+3, y+8, x+7, y+12); gfx.line(x+7, y+12, x+13, y+4)
        gfx.line(x+3, y+7, x+7, y+11); gfx.line(x+7, y+11, x+13, y+3)
    end
    gfx.setfont(1, "Arial", 16); gfx.set(col_text[1], col_text[2], col_text[3], alpha); gfx.x, gfx.y = x + 24, y; gfx.drawstr(label)
    if not disabled and gfx.mouse_cap & 1 == 1 and not mouse_down then
        if gfx.mouse_x >= x and gfx.mouse_x <= x + 300 and gfx.mouse_y >= y and gfx.mouse_y <= y + 16 then
            mouse_down = true; return not checked
        end
    end
    return checked
end

-- Helper: apply DSP preset values to a topo and its JSFX instances, update state.
local function ApplyPresetDSP(topo, flavor_id)
    local p = flavor_presets[flavor_id] and flavor_presets[flavor_id][topo] or nil
    if not p then return end
    UpdatePlugins(topo, p_flux,  p.flux)
    UpdatePlugins(topo, p_therm, p.therm)
    UpdatePlugins(topo, p_text,  p.text)
    state[topo].flux  = p.flux
    state[topo].therm = p.therm
    state[topo].text  = p.text
end

function DrawFlavorSelector(topo_idx, x, y, w)
    local flavors = {"Custom", "British A", "Solid State E", "US Discr.", "Modern"}
    local is_mixed = state[topo_idx].mixed
    local current  = is_mixed and -1 or math.floor(state[topo_idx].flavor + 0.5)
    local btn_w, btn_h = w - 4, 28
    local top_pad = 6

    -- Mixed state indicator: shown above the buttons when instances diverge
    if is_mixed then
        local bar_h = 22
        gfx.set(col_warn[1], col_warn[2], col_warn[3], 0.25)
        gfx.rect(x, y, btn_w, bar_h, true)
        gfx.set(col_warn[1], col_warn[2], col_warn[3], 1)
        gfx.setfont(1, "Arial", 13, 98)
        local lbl = "-- MIXED --"
        local tw, _ = gfx.measurestr(lbl)
        gfx.x, gfx.y = x + (btn_w - tw)/2, y + 5; gfx.drawstr(lbl)
        top_pad = top_pad + bar_h + 4
    end

    for i = 0, 4 do
        local bx = x
        local by = y + top_pad + (i * (btn_h + 4))
        local is_on = (current == i)
        gfx.set(is_on and col_accent_d[1] or col_panel[1], is_on and col_accent_d[2] or col_panel[2], is_on and col_accent_d[3] or col_panel[3], 1)
        gfx.rect(bx, by, btn_w, btn_h, true)
        gfx.set(is_on and 1 or col_text[1], is_on and 1 or col_text[2], is_on and 1 or col_text[3], 1)
        gfx.setfont(1, "Arial", 16, 98)
        local tw, _ = gfx.measurestr(flavors[i+1])
        gfx.x, gfx.y = bx + (btn_w - tw)/2, by + 7; gfx.drawstr(flavors[i+1])
        if gfx.mouse_cap & 1 == 1 and not mouse_down then
            if gfx.mouse_x >= bx and gfx.mouse_x <= bx + btn_w and gfx.mouse_y >= by and gfx.mouse_y <= by + btn_h then
                mouse_down = true
                -- Clicking any button unifies ALL instances of this topology.
                -- When mixed, this is an explicit bulk-override action.
                state[topo_idx].flavor = i
                state[topo_idx].mixed  = false
                if i > 0 then
                    ApplyPresetDSP(topo_idx, i)
                    if topo_idx == 2 then
                        if link_M_to_B then state[1].flavor=i; state[1].mixed=false; ApplyPresetDSP(1, i) end
                        if link_M_to_C then state[0].flavor=i; state[0].mixed=false; ApplyPresetDSP(0, i) end
                    elseif topo_idx == 1 then
                        if link_B_to_C and not link_M_to_C then state[0].flavor=i; state[0].mixed=false; ApplyPresetDSP(0, i) end
                    end
                else
                    if topo_idx == 2 then
                        if link_M_to_B then state[1].flavor=0; state[1].mixed=false end
                        if link_M_to_C then state[0].flavor=0; state[0].mixed=false end
                    elseif topo_idx == 1 then
                        if link_B_to_C and not link_M_to_C then state[0].flavor=0; state[0].mixed=false end
                    end
                end
            end
        end
    end
    return y + top_pad + (5 * (btn_h + 4)) + 10
end

function DrawSlider(slider_id, x, y, w, h, val, min_val, max_val, title, unit, color_idx, disabled)
    local alpha = disabled and 0.35 or 1.0
    gfx.set(col_panel[1], col_panel[2], col_panel[3], alpha); gfx.rect(x, y, w, h, true)
    gfx.set(col_frame[1], col_frame[2], col_frame[3], alpha); gfx.rect(x, y, w, h, false)
    if not disabled then
        local percent = (val - min_val) / (max_val - min_val)
        if color_idx == 1 then gfx.set(col_accent_d[1], col_accent_d[2], col_accent_d[3], 0.6)
        elseif color_idx == 2 then gfx.set(col_red[1], col_red[2], col_red[3], 0.6)
        elseif color_idx == 3 then gfx.set(col_green[1], col_green[2], col_green[3], 0.6)
        end
        gfx.rect(x+1, y+1, (w-2) * percent, h-2, true)
        if gfx.mouse_cap & 1 == 1 then
            if not mouse_down and gfx.mouse_x >= x and gfx.mouse_x <= x + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h then
                mouse_down = true; active_slider = slider_id
            end
            if mouse_down and active_slider == slider_id then
                local mouse_pos = math.max(0, math.min(w, gfx.mouse_x - x))
                val = min_val + ((mouse_pos / w) * (max_val - min_val))
                val = math.floor(val * 10 + 0.5) / 10
            end
        end
    end
    gfx.set(col_text[1], col_text[2], col_text[3], alpha); gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = x + 8, y + 6; gfx.drawstr(title)
    local val_str = disabled and "---" or (string.format("%.1f", val) .. unit)
    local tw, _ = gfx.measurestr(val_str); gfx.x = x + w - tw - 8; gfx.drawstr(val_str)
    return val
end

function DrawButton(x, y, w, h, label, bg_color, text_color)
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    local mul = hover and 1.1 or 1.0
    gfx.set(math.min(bg_color[1] * mul, 1), math.min(bg_color[2] * mul, 1), math.min(bg_color[3] * mul, 1), 1)
    gfx.rect(x, y, w, h, true)
    gfx.set(text_color[1], text_color[2], text_color[3], 1)
    gfx.setfont(1, "Arial", 15, 98)
    local tw, th = gfx.measurestr(label)
    gfx.x, gfx.y = x + (w-tw)/2, y + (h-th)/2; gfx.drawstr(label)
    if hover and gfx.mouse_cap & 1 == 1 and not mouse_down then
        mouse_down = true; return true
    end
    return false
end

-- Returns the character index (0-based) closest to pixel offset px inside text.
-- Must be called with the correct font already set.
local function pixel_to_cursor(text, px)
    if px <= 0 then return 0 end
    for i = 1, #text do
        local w = gfx.measurestr(text:sub(1, i))
        if w >= px then
            local wp = gfx.measurestr(text:sub(1, i - 1))
            return (px - wp < w - px) and (i - 1) or i
        end
    end
    return #text
end

-- Selects the word surrounding position pos in text.
-- Returns sel_anchor, new_cursor (word start, word end).
local function select_word(text, pos)
    local s, e = pos, pos
    while s > 0 and text:sub(s, s):match("%S") do s = s - 1 end
    while e < #text and text:sub(e + 1, e + 1):match("%S") do e = e + 1 end
    return s, e
end

function DrawTextInputAdvanced(key, inp_obj, x, y, w, h, disabled)
    local is_active = (active_input_key == key) and not disabled
    local pad = 4
    local tx = x + 8  -- text origin x
    local hover = gfx.mouse_x >= x - pad and gfx.mouse_x <= x + w + pad
               and gfx.mouse_y >= y - pad and gfx.mouse_y <= y + h + pad

    -- Background & border
    gfx.set(col_panel[1], col_panel[2], col_panel[3], 1)
    gfx.rect(x, y, w, h, true)
    gfx.set(is_active and col_accent[1] or col_frame[1],
            is_active and col_accent[2] or col_frame[2],
            is_active and col_accent[3] or col_frame[3], 1)
    gfx.rect(x, y, w, h, false)
    if is_active then gfx.rect(x-1, y-1, w+2, h+2, false) end

    gfx.setfont(1, "Arial", 16)
    local text = inp_obj.val
    local _, th = gfx.measurestr(text)

    -- Selection highlight
    if is_active and inp_obj.sel ~= nil then
        local s = math.min(inp_obj.cursor, inp_obj.sel)
        local e = math.max(inp_obj.cursor, inp_obj.sel)
        local sx = tx + gfx.measurestr(text:sub(1, s))
        local ex = tx + gfx.measurestr(text:sub(1, e))
        gfx.set(col_accent[1], col_accent[2], col_accent[3], 0.3)
        gfx.rect(sx, y + 3, math.max(ex - sx, 2), h - 6, true)
    end

    -- Text
    gfx.set(col_text[1], col_text[2], col_text[3], disabled and 0.4 or 1)
    gfx.x, gfx.y = tx, y + (h - th) / 2; gfx.drawstr(text)

    -- Cursor blink (shown when active, regardless of selection)
    if is_active and math.floor(reaper.time_precise() * 2) % 2 == 0 then
        local cur_x = tx + gfx.measurestr(text:sub(1, inp_obj.cursor))
        gfx.set(col_text[1], col_text[2], col_text[3], 1)
        gfx.line(cur_x, y + 4, cur_x, y + h - 4)
    end

    -- Mouse handling
    if not disabled then
        local mouse_px = gfx.mouse_x - tx

        if gfx.mouse_cap & 1 == 1 then
            if not mouse_down and hover then
                -- New click
                mouse_down = true
                active_input_key = key
                local now = reaper.time_precise()
                local clicked = pixel_to_cursor(text, mouse_px)

                if key == input_last_click.key and (now - input_last_click.time) < 0.35 then
                    -- Double-click: select word
                    local s, e = select_word(text, clicked)
                    inp_obj.sel    = s
                    inp_obj.cursor = e
                    input_drag_active = false
                else
                    -- Single click: position cursor, start drag
                    inp_obj.cursor    = clicked
                    inp_obj.sel       = nil
                    input_drag_active = true
                    input_drag_key    = key
                    input_drag_anchor = clicked
                end

                input_last_click = { key=key, time=now, pos=clicked }

            elseif input_drag_active and input_drag_key == key and is_active then
                -- Drag: move cursor, keep anchor
                local new_cur = pixel_to_cursor(text, mouse_px)
                inp_obj.cursor = new_cur
                inp_obj.sel    = (new_cur ~= input_drag_anchor) and input_drag_anchor or nil
            end
        else
            input_drag_active = false
            input_drag_key    = nil
        end
    end
end

--------------------------------------------------------------------------------
-- 4. OVERLAYS (CONFIG & HELP)
--------------------------------------------------------------------------------
function OpenConfig()
    local raw = GetThesaurus()
    cfg_temp = {
        use_reaper_master = raw.use_reaper_master,
        bus_parents = raw.bus_parents,
        master_name  = { val = raw.master_name,  cursor = #raw.master_name,  sel = nil },
        bus_keywords = { val = raw.bus_keywords, cursor = #raw.bus_keywords, sel = nil },
        exclusions   = { val = raw.exclusions,   cursor = #raw.exclusions,   sel = nil }
    }
    cfg_x, cfg_y = (gfx.w - cfg_w)/2, (gfx.h - cfg_h)/2
    show_config = true
    active_input_key = nil
end

function DrawConfigOverlay()
    gfx.set(bg_r, bg_g, bg_b, 0.85); gfx.rect(0, 0, gfx.w, gfx.h, true)
    if not mouse_down and gfx.mouse_cap & 1 == 1 and gfx.mouse_x >= cfg_x and gfx.mouse_x <= cfg_x + cfg_w and gfx.mouse_y >= cfg_y and gfx.mouse_y <= cfg_y + 45 then
        is_dragging_cfg = true; drag_dx, drag_dy = gfx.mouse_x - cfg_x, gfx.mouse_y - cfg_y; mouse_down = true
    elseif gfx.mouse_cap & 1 == 0 then is_dragging_cfg = false end
    if is_dragging_cfg then cfg_x, cfg_y = gfx.mouse_x - drag_dx, gfx.mouse_y - drag_dy end

    gfx.set(col_panel[1], col_panel[2], col_panel[3], 1); gfx.rect(cfg_x, cfg_y, cfg_w, cfg_h, true)
    gfx.set(col_frame[1], col_frame[2], col_frame[3], 1); gfx.rect(cfg_x, cfg_y, cfg_w, cfg_h, false)
    gfx.set(col_frame[1], col_frame[2], col_frame[3], 1); gfx.rect(cfg_x+1, cfg_y+1, cfg_w-2, 45, true)
    gfx.set(col_text[1], col_text[2], col_text[3], 1); gfx.setfont(1, "Arial", 19, 98); gfx.x, gfx.y = cfg_x + 35, cfg_y + 13; gfx.drawstr("MATRIX SETTINGS")
    
    local cy = cfg_y + 70
    local px = cfg_x + 35
    gfx.set(col_text[1], col_text[2], col_text[3], 1); gfx.setfont(1, "Arial", 17, 98); gfx.x, gfx.y = px, cy; gfx.drawstr("1. MASTER TRACK IDENTIFICATION")
    cfg_temp.use_reaper_master = DrawCheckbox(px, cy+30, "Use REAPER Native Master Track", cfg_temp.use_reaper_master, false)
    gfx.set(col_text_dim[1], col_text_dim[2], col_text_dim[3], 1); gfx.setfont(1, "Arial", 15); gfx.x, gfx.y = px, cy + 60; gfx.drawstr("Or custom Master name:")
    DrawTextInputAdvanced("master_name", cfg_temp.master_name, px, cy + 80, cfg_w - 70, 30, cfg_temp.use_reaper_master)
    
    cy = cy + 130
    gfx.set(col_text[1], col_text[2], col_text[3], 1); gfx.setfont(1, "Arial", 17, 98); gfx.x, gfx.y = px, cy; gfx.drawstr("2. BUS & GROUP IDENTIFICATION")
    cfg_temp.bus_parents = DrawCheckbox(px, cy+30, "Identify Parent Folders as Buses", cfg_temp.bus_parents, false)
    gfx.set(col_text_dim[1], col_text_dim[2], col_text_dim[3], 1); gfx.setfont(1, "Arial", 15); gfx.x, gfx.y = px, cy + 60; gfx.drawstr("Define additional keywords to identify Bus tracks. Separate words with commas:")
    DrawTextInputAdvanced("bus_keywords", cfg_temp.bus_keywords, px, cy + 80, cfg_w - 70, 30, false)

    cy = cy + 130
    gfx.set(col_text[1], col_text[2], col_text[3], 1); gfx.setfont(1, "Arial", 17, 98); gfx.x, gfx.y = px, cy; gfx.drawstr("3. EXCEPTIONS")
    gfx.set(col_text_dim[1], col_text_dim[2], col_text_dim[3], 1); gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = px, cy + 30; gfx.drawstr("Tracks with these keywords are excluded from AutoConfig. Applies to Channels and Buses.")
    gfx.x, gfx.y = px, cy + 48; gfx.drawstr("Separate with commas:")
    DrawTextInputAdvanced("exclusions", cfg_temp.exclusions, px, cy + 68, cfg_w - 70, 30, false)

    if DrawButton(px, cfg_y + cfg_h - 55, 130, 35, "CANCEL", col_frame, col_text) then show_config = false end
    if DrawButton(cfg_x + cfg_w - 185, cfg_y + cfg_h - 55, 150, 35, "SAVE SETTINGS", col_accent_d, {1,1,1}) then
        SaveThesaurus(cfg_temp); AutoConfig(); show_config = false
    end
end

function DrawHelpOverlay()
    gfx.set(bg_r, bg_g, bg_b, 0.95); gfx.rect(0, 0, gfx.w, gfx.h, true)
    local hw, hh = 800, 580
    local hx, hy = (gfx.w - hw)/2, (gfx.h - hh)/2
    gfx.set(col_panel[1], col_panel[2], col_panel[3], 1); gfx.rect(hx, hy, hw, hh, true)
    gfx.set(col_frame[1], col_frame[2], col_frame[3], 1); gfx.rect(hx, hy, hw, hh, false)

    -- Title & language buttons
    gfx.set(col_text[1], col_text[2], col_text[3], 1); gfx.setfont(1, "Arial", 20, 98)
    gfx.x, gfx.y = hx + 30, hy + 16; gfx.drawstr("ANALOG MATRIX HELP")
    if DrawButton(hx + hw - 215, hy + 12, 85, 26, "ENGLISH", help_lang == "EN" and col_accent_d or col_frame, {1,1,1}) then
        help_lang = "EN"; help_scroll = 0
    end
    if DrawButton(hx + hw - 120, hy + 12, 85, 26, "ESPAÑOL", help_lang == "ES" and col_accent_d or col_frame, {1,1,1}) then
        help_lang = "ES"; help_scroll = 0
    end

    -- Tab buttons
    if DrawButton(hx + 30, hy + 50, 190, 26, "SETUP & USAGE", help_tab == "SETUP" and col_accent_d or col_frame, {1,1,1}) then
        help_tab = "SETUP"; help_scroll = 0
    end
    if DrawButton(hx + 228, hy + 50, 195, 26, "CONSOLE FLAVORS", help_tab == "FLAVORS" and col_accent_d or col_frame, {1,1,1}) then
        help_tab = "FLAVORS"; help_scroll = 0
    end
    gfx.set(col_frame[1], col_frame[2], col_frame[3], 1)
    gfx.line(hx + 20, hy + 84, hx + hw - 20, hy + 84)

    -- Content strings
    local manual
    if help_lang == "EN" then
        if help_tab == "SETUP" then
            manual = [[
1. HOW IT WORKS

The script scans your project on launch and assigns a topology (Channel, Bus, Master)
to each TAM instance based on track names. Open Settings to configure the rules.

a) MASTER: REAPER's native Master Track, or a custom track name set in Config.
b) BUS / GROUP: Parent folder tracks (if enabled) or tracks matching Config keywords.
c) CHANNEL: All remaining tracks with a TAM instance.
d) EXCEPTIONS: Tracks with these keywords are fully ignored (Channels and Buses).

Topologies are reassigned every time the script starts. Any topology configured
manually inside TAM will be overwritten unless your Settings keywords match.

2. PARAMETER LINKING

Use the checkboxes in the main UI to propagate changes hierarchically:
  Master to Buses and/or Channels.  Bus to Channels.

Keep LINK set to OFF inside each TAM instance. The script handles all propagation.
Having TAM's own link active at the same time can cause conflicts and value resets.

3. TROUBLESHOOTING: UI CHANGES BUT TAM IS NOT AFFECTED

- Check Settings: track names must match the configured keywords for their topology.
  If no match is found, all instances are assigned Channel. Bus and Master instances
  will not update until their tracks are correctly identified.
- Disable LINK inside each TAM instance (see above).
- Confirm the FX chain name contains the text "Analog Molecule".

Developed by Jordi Molas - The Little Cavern 2026]]
        else
            manual = [[
WHY TAM ALWAYS SHOWS "CUSTOM"

When you select a console preset in the Matrix UI, TAM always displays Custom in its
own interface. This is expected behaviour, not a bug.

HOW PRESET SELECTION WORKS

The script does not write the console label to TAM. It writes the three underlying DSP
values — 3D Flux, Thermal Bloom, Analog Texture — matching the preset for each topology.
The audio processing is correct regardless of what TAM's label shows.

WHY THE LABEL CANNOT BE WRITTEN FROM SCRIPT TO TAM

Console flavors inside TAM are applied by an internal function triggered only through
a shared memory channel between TAM instances. This channel is inaccessible to Lua.
REAPER's scripting API provides no way to write to it.

A second obstacle: TAM resets its flavor display to Custom whenever DSP values change
while a flavor is active — even if the new values match a known preset exactly.
This dirty check cannot be bypassed from outside the plugin.

HOW THE SCRIPT COMPENSATES

The Matrix Console manages flavor state in Lua only. On every frame it reads DSP
values from each TAM instance and compares them against preset tables to infer which
console is active. Changes made inside TAM are detected and reflected in the script.
The reverse — script label to TAM label — is not possible by design.

Developed by Jordi Molas - The Little Cavern 2026]]
        end
    else
        if help_tab == "SETUP" then
            manual = [[
1. CÓMO FUNCIONA

El script analiza el proyecto al iniciarse y asigna una topología (Canal, Bus, Master)
a cada instancia de TAM según el nombre de las pistas. Configura las reglas en Settings.

a) MASTER: El Master nativo de REAPER, o un nombre de pista personalizado en Config.
b) BUS / GRUPO: Carpetas padre (si está activado) o pistas que contengan palabras clave.
c) CANAL: El resto de pistas con una instancia de TAM.
d) EXCEPCIONES: Pistas con estas palabras clave son ignoradas completamente.

Las topologías se reasignan cada vez que el script arranca. Cualquier topología
configurada manualmente en TAM será sobrescrita si las palabras clave no coinciden.

2. ENLACE DE PARÁMETROS

Usa los checkboxes de la UI principal para propagar cambios jerárquicamente:
  Master a Buses y/o Canales.  Bus a Canales.

Mantén LINK a OFF dentro de cada instancia de TAM. El script gestiona todo.
Tener el link interno de TAM activo al mismo tiempo puede causar conflictos.

3. SOLUCIÓN DE PROBLEMAS: LA UI CAMBIA PERO TAM NO SE ACTUALIZA

- Revisa Settings: los nombres de pista deben coincidir con las palabras clave.
  Si no hay coincidencia, todas las instancias son asignadas como Canal. Las
  instancias de Bus y Master no recibirán cambios hasta que sean identificadas.
- Desactiva LINK dentro de cada instancia de TAM (ver arriba).
- Confirma que el nombre del FX en la cadena contiene el texto "Analog Molecule".

Developed by Jordi Molas - The Little Cavern 2026]]
        else
            manual = [[
POR QUÉ TAM SIEMPRE MUESTRA "CUSTOM"

Cuando seleccionas una consola en la Matrix UI, TAM siempre mostrará Custom en su
propia interfaz. Este es el comportamiento esperado, no un error.

CÓMO FUNCIONA LA SELECCIÓN DE CONSOLA

El script no escribe la etiqueta de consola en TAM. Escribe directamente los tres
valores DSP — 3D Flux, Thermal Bloom, Analog Texture — correspondientes al preset
para cada topología. El procesado de audio es correcto independientemente de lo que
muestre la etiqueta de TAM.

POR QUÉ LA ETIQUETA NO PUEDE ESCRIBIRSE DESDE EL SCRIPT

Las consolas en TAM se aplican mediante una función interna que solo se activa a través
de un canal de memoria compartida (gmem) entre instancias de TAM. Este canal no es
accesible desde scripts Lua externos ni desde la API de REAPER.

Además, TAM restablece su visualización a Custom cuando los valores DSP cambian
mientras hay una consola activa, aunque los nuevos valores coincidan con un preset
conocido. Esta comprobación interna no puede evitarse desde fuera del plugin.

CÓMO LO RESUELVE EL SCRIPT

El Matrix Console gestiona el estado de consola solo en Lua. En cada frame lee los
valores DSP de cada instancia de TAM y los compara con tablas de presets para deducir
qué consola está activa. Los cambios hechos dentro de TAM sí se detectan y reflejan
en el script. Lo contrario — etiqueta del script a TAM — no es posible por diseño.

Developed by Jordi Molas - The Little Cavern 2026]]
        end
    end

    -- Scroll logic
    local line_h = 17
    local content_y = hy + 92
    local content_h = hh - 92 - 48
    local visible_lines = math.floor(content_h / line_h)
    local total_lines = 1
    for _ in manual:gmatch("\n") do total_lines = total_lines + 1 end
    local max_scroll = math.max(0, total_lines - visible_lines)
    help_scroll = math.max(0, math.min(help_scroll, max_scroll))
    if gfx.mouse_wheel ~= 0 then
        help_scroll = math.max(0, math.min(max_scroll, help_scroll - math.floor(gfx.mouse_wheel / 60)))
        gfx.mouse_wheel = 0
    end

    -- Draw lines
    local line_y = content_y
    local line_idx = 0
    for line in manual:gmatch("([^\n]*)\n?") do
        if line_idx >= help_scroll and line_idx < help_scroll + visible_lines then
            local is_header = line:match("^%d+%.%s") or
                (line:match("^[A-ZÁÉÍÓÚÑ]") and line == line:upper() and #line > 4)
            if is_header then
                gfx.set(col_text[1], col_text[2], col_text[3], 1)
                gfx.setfont(1, "Arial", 15, 98)
            else
                gfx.set(col_text[1], col_text[2], col_text[3], 0.72)
                gfx.setfont(1, "Arial", 15)
            end
            gfx.x, gfx.y = hx + 30, line_y; gfx.drawstr(line)
            line_y = line_y + line_h
        end
        line_idx = line_idx + 1
    end

    -- Scrollbar
    if max_scroll > 0 then
        local sb_x = hx + hw - 14
        gfx.set(col_frame[1], col_frame[2], col_frame[3], 0.4)
        gfx.rect(sb_x, content_y, 5, content_h, true)
        local thumb_h = math.max(18, content_h * visible_lines / total_lines)
        local thumb_y = content_y + (content_h - thumb_h) * (help_scroll / max_scroll)
        gfx.set(col_accent[1], col_accent[2], col_accent[3], 0.6)
        gfx.rect(sb_x, thumb_y, 5, thumb_h, true)
    end

    if DrawButton(hx + hw - 110, hy + hh - 40, 95, 32, "CLOSE", col_red, {1,1,1}) then show_help = false end
end

--------------------------------------------------------------------------------
-- 5. MAIN EVENT LOOP
--------------------------------------------------------------------------------
function Main()
    local char = gfx.getchar()
    if char == -1 or char == 27 then gfx.quit(); return end

    -- Sync DSP values from JSFX every frame (flavor is NOT read from JSFX, lives only in Lua)
    ReadBackFromPlugins()

    if show_config and char ~= 0 and active_input_key and cfg_temp[active_input_key] then
        local obj = cfg_temp[active_input_key]
        local shift = gfx.mouse_cap & 8 ~= 0

        -- Helpers (inline to access obj)
        local function has_sel() return obj.sel ~= nil and obj.sel ~= obj.cursor end
        local function sel_range()
            return math.min(obj.cursor, obj.sel), math.max(obj.cursor, obj.sel)
        end
        local function delete_sel()
            local s, e = sel_range()
            obj.val = obj.val:sub(1, s) .. obj.val:sub(e + 1)
            obj.cursor = s; obj.sel = nil
        end
        local function move(new_pos)
            if shift then
                if obj.sel == nil then obj.sel = obj.cursor end
                obj.cursor = math.max(0, math.min(#obj.val, new_pos))
                if obj.cursor == obj.sel then obj.sel = nil end
            else
                if has_sel() then
                    obj.cursor = (new_pos < obj.cursor) and math.min(obj.cursor, obj.sel)
                                                        or  math.max(obj.cursor, obj.sel)
                else
                    obj.cursor = math.max(0, math.min(#obj.val, new_pos))
                end
                obj.sel = nil
            end
        end

        if char == 1 then                          -- Ctrl+A: select all
            obj.sel = 0; obj.cursor = #obj.val
        elseif char == 22 then                     -- Ctrl+V: paste from clipboard (requires SWS)
            if reaper.CF_GetClipboard then
                local clip = reaper.CF_GetClipboard()
                if clip and #clip > 0 then
                    clip = clip:gsub("%c", "")     -- strip control/newline chars
                    if has_sel() then delete_sel() end
                    obj.val = obj.val:sub(1, obj.cursor) .. clip .. obj.val:sub(obj.cursor + 1)
                    obj.cursor = obj.cursor + #clip; obj.sel = nil
                end
            end
        elseif char == 8 then                      -- Backspace
            if has_sel() then delete_sel()
            elseif obj.cursor > 0 then
                obj.val = obj.val:sub(1, obj.cursor-1) .. obj.val:sub(obj.cursor+1)
                obj.cursor = obj.cursor - 1; obj.sel = nil
            end
        elseif char == KEY_DEL then                -- Delete forward
            if has_sel() then delete_sel()
            elseif obj.cursor < #obj.val then
                obj.val = obj.val:sub(1, obj.cursor) .. obj.val:sub(obj.cursor+2)
                obj.sel = nil
            end
        elseif char == KEY_LEFT  then move(obj.cursor - 1)
        elseif char == KEY_RIGHT then move(obj.cursor + 1)
        elseif char == KEY_HOME  then move(0)
        elseif char == KEY_END   then move(#obj.val)
        elseif char == 13 then                     -- Enter: confirm & deactivate
            active_input_key = nil
        elseif char >= 32 and char < 127 then      -- Printable character
            if has_sel() then delete_sel() end
            obj.val = obj.val:sub(1, obj.cursor) .. string.char(char) .. obj.val:sub(obj.cursor+1)
            obj.cursor = obj.cursor + 1; obj.sel = nil
        end
    end
    gfx.set(bg_r, bg_g, bg_b, 1); gfx.rect(0, 0, gfx.w, gfx.h, true)
    
    -- Logo XL & Header
    if not logo_loaded then local ok = gfx.loadimg(1, logo_path); if ok ~= -1 then logo_loaded = true end end
    if logo_loaded then
        local iw, ih = gfx.getimgdim(1)
        if iw > 0 and ih > 0 then
            local max_w, max_h = 300, 75
            local scale = math.min(max_w / iw, max_h / ih)
            gfx.blit(1, 1, 0, 0, 0, iw, ih, 25, 10, iw * scale, ih * scale)
        end
    end
    
    -- Support Link
    local s_text = "Support the TLC Team"
    gfx.set(col_accent[1], col_accent[2], col_accent[3], 1); gfx.setfont(1, "Arial", 13)
    local sw, sh = gfx.measurestr(s_text); local sx, sy = gfx.w - sw - 25, 8; gfx.x, gfx.y = sx, sy
    local btn_help_x, btn_help_y, btn_w, btn_h = gfx.w - 230, 25, 100, 35
    local btn_set_x, btn_set_y = gfx.w - 120, 25
    local over_btn = (gfx.mouse_x >= btn_help_x and gfx.mouse_x <= btn_help_x + btn_w and gfx.mouse_y >= btn_help_y and gfx.mouse_y <= btn_help_y + btn_h) or
                     (gfx.mouse_x >= btn_set_x and gfx.mouse_x <= btn_set_x + btn_w and gfx.mouse_y >= btn_set_y and gfx.mouse_y <= btn_set_y + btn_h)
    if not over_btn and gfx.mouse_x >= sx and gfx.mouse_x <= sx + sw and gfx.mouse_y >= sy and gfx.mouse_y <= sy + sh then
        gfx.set(col_accent_d[1], col_accent_d[2], col_accent_d[3], 1)
        if gfx.mouse_cap & 1 == 1 and not mouse_down then
            mouse_down = true; local url = "https://ko-fi.com/thelittlecavern"
            local os = reaper.GetOS(); if os:match("Win") then reaper.ExecProcess('cmd.exe /C start "" "' .. url .. '"', 0) else reaper.ExecProcess('/usr/bin/open "' .. url .. '"', 0) end
        end
    end
    gfx.drawstr(s_text)
    
    if not (show_config or show_help) then
        if DrawButton(gfx.w - 120, 35, 100, 35, "SETTINGS", col_frame, {1,1,1}) then OpenConfig() end
        if DrawButton(gfx.w - 230, 35, 100, 35, "HELP", col_accent_d, {1,1,1}) then show_help = true end

        local startY = 110
        local col_w = (gfx.w - 80) / 3
        local pos_C, pos_B, pos_M = 25, 25 + col_w + 15, 25 + (col_w * 2) + 30

        -- Column panels
        local panel_h = gfx.h - startY - 25
        gfx.set(col_panel[1]*1.05, col_panel[2]*1.05, col_panel[3]*1.05, 1)
        gfx.rect(pos_C-5, startY-10, col_w+10, panel_h+10, true)
        gfx.rect(pos_B-5, startY-10, col_w+10, panel_h+10, true)
        gfx.rect(pos_M-5, startY-10, col_w+10, panel_h+10, true)
        gfx.set(col_frame[1], col_frame[2], col_frame[3], 1)
        gfx.rect(pos_C-5, startY-10, col_w+10, panel_h+10, false)
        gfx.rect(pos_B-5, startY-10, col_w+10, panel_h+10, false)
        gfx.rect(pos_M-5, startY-10, col_w+10, panel_h+10, false)

        gfx.set(col_text[1], col_text[2], col_text[3], 1); gfx.setfont(1, "Arial", 18, 98); gfx.x, gfx.y = pos_C+5, startY; gfx.drawstr("CHANNELS"); gfx.x = pos_B+5; gfx.drawstr("BUSES"); gfx.x = pos_M+5; gfx.drawstr("MASTER TRACK")
        gfx.set(col_frame[1], col_frame[2], col_frame[3], 1); gfx.line(pos_C, startY+25, pos_C+col_w, startY+25); gfx.line(pos_B, startY+25, pos_B+col_w, startY+25); gfx.line(pos_M, startY+25, pos_M+col_w, startY+25)
        link_M_to_B = DrawCheckbox(pos_M, startY+35, "Link to BUSES", link_M_to_B, false)
        link_M_to_C = DrawCheckbox(pos_M, startY+60, "Link to CHANNELS", link_M_to_C, false)
        link_B_to_C = DrawCheckbox(pos_B, startY+35, "Link to CHANNELS", link_B_to_C, link_M_to_B)

        local fY = startY + 100
        local nC = DrawFlavorSelector(0, pos_C, fY, col_w)
        local cMix = state[0].mixed
        local vC_fl = DrawSlider("c1", pos_C, nC,    col_w, 26, state[0].flux,  0, 100, "3D Flux %",        "%", 1, cMix); CheckSliderChange(0, p_flux,  vC_fl, "flux")
        local vC_th = DrawSlider("c2", pos_C, nC+32, col_w, 26, state[0].therm, 0, 100, "Thermal Bloom %",  "%", 2, cMix); CheckSliderChange(0, p_therm, vC_th, "therm")
        local vC_te = DrawSlider("c3", pos_C, nC+64, col_w, 26, state[0].text,  0, 100, "Analog Texture %", "%", 3, cMix); CheckSliderChange(0, p_text,  vC_te, "text")
        local nB = DrawFlavorSelector(1, pos_B, fY, col_w)
        local bMix = state[1].mixed
        local vB_fl = DrawSlider("b1", pos_B, nB,    col_w, 26, state[1].flux,  0, 100, "3D Flux %",        "%", 1, bMix); CheckSliderChange(1, p_flux,  vB_fl, "flux")
        local vB_th = DrawSlider("b2", pos_B, nB+32, col_w, 26, state[1].therm, 0, 100, "Thermal Bloom %",  "%", 2, bMix); CheckSliderChange(1, p_therm, vB_th, "therm")
        local vB_te = DrawSlider("b3", pos_B, nB+64, col_w, 26, state[1].text,  0, 100, "Analog Texture %", "%", 3, bMix); CheckSliderChange(1, p_text,  vB_te, "text")
        local nM = DrawFlavorSelector(2, pos_M, fY, col_w)
        local mMix = state[2].mixed
        local vM_fl = DrawSlider("m1", pos_M, nM,    col_w, 26, state[2].flux,  0, 100, "3D Flux %",        "%", 1, mMix); CheckSliderChange(2, p_flux,  vM_fl, "flux")
        local vM_th = DrawSlider("m2", pos_M, nM+32, col_w, 26, state[2].therm, 0, 100, "Thermal Bloom %",  "%", 2, mMix); CheckSliderChange(2, p_therm, vM_th, "therm")
        local vM_te = DrawSlider("m3", pos_M, nM+64, col_w, 26, state[2].text,  0, 100, "Analog Texture %", "%", 3, mMix); CheckSliderChange(2, p_text,  vM_te, "text")
    end

    if show_config then DrawConfigOverlay() elseif show_help then DrawHelpOverlay() end
    if gfx.mouse_cap & 1 == 0 then mouse_down = false; active_slider = "" end
    last_mouse_cap = gfx.mouse_cap; reaper.defer(Main)
end

-- AutoConfig sets topology/ID/link and calls ReadBackFromPlugins at the end.
-- ReadBackFromPlugins reads current DSP values from JSFX (which the project persists),
-- and DetectFlavor infers the correct flavor label from those values.
-- No ExtState restore needed: the JSFX project state is the single source of truth.
AutoConfig()

gfx.init("TLC Analog Molecule Matrix", 900, 620, 0, 150, 150)
Main()
