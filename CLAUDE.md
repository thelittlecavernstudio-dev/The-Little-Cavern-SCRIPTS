I need to improve my english level. For that reason I'll try always to express in English but depending of how much complicated the tasks description is I Will express in Spanish.

Before Claude starts to respond me Will check if my prompt is in English or in Spanish. If is in English Claude Will show me two scales from 0 o 10. One of them Will be to evalute my English gramma and the other one Will be to evaluate how my mates of office theorically evaluate my English.

If I start in Spanish then Claude won't evaluate anything.

Before deploy to GitHub and update XML to ReaPack Claude will question me if I want to authorize that task. Claude will never update Git without my permission.

Claude will design a system to recover the last right code to assure recover it if any problem appears during the DEV process.


 # CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

Single Git repository for REAPER audio production tools distributed via ReaPack.

```
The Little Cavern/               ← repo root (git)
  The Little Cavern SCRIPTS/    ← Lua scripts for REAPER
  The Little Cavern JSFX/       ← JSFX audio effect plugins
  index.xml                     ← ReaPack manifest (auto-generated, do not edit)
```

## Dev → Test → Live Workflow

**Edit source files only inside `The Little Cavern SCRIPTS\` or `The Little Cavern JSFX\`. Never edit directly in REAPER.**

User database files, dumps, and configs do NOT go in the repo.

### 1. Deploy for quick local testing
```powershell
& "C:\Users\Jordi\TLC REAPER\DEV\deploy-to-reaper.ps1"
```
Copies scripts/JSFX to REAPER's AppData folders with a timestamped backup first.

### 2. Regenerate ReaPack index after any release change
```powershell
& "C:\Users\Jordi\TLC REAPER\DEV\build-reapack-index.ps1"
```
Reads ReaPack metadata headers from source files and rebuilds `index.xml`.

### 3. Commit and push via GitHub Desktop, then verify in REAPER
ReaPack → Synchronize packages → filter by "TLC"

### Restore last backup if needed
```powershell
& "C:\Users\Jordi\TLC REAPER\DEV\restore-last-backup.ps1"
```

## ReaPack Distribution

Single URL for REAPER's ReaPack repository list:
- `https://raw.githubusercontent.com/thelittlecavernstudio-dev/The-Little-Cavern-SCRIPTS/main/index.xml`

The `index.xml` is auto-generated — do not edit it by hand.

ReaPack installs files to:
- Scripts → `C:\Users\[USER]\AppData\Roaming\REAPER\Scripts\The Little Cavern SCRIPTS\`
- JSFX    → `C:\Users\[USER]\AppData\Roaming\REAPER\Effects\The Little Cavern JSFX\`

## Script Metadata Headers

Every `.lua` and `.jsfx` file must have a ReaPack header block at the top. The `build-reapack-index.ps1` script reads these to build `index.xml`. Required fields:

```lua
-- @description Short description
-- @version X.Y
-- @author Jordi Molas
-- @donation https://ko-fi.com/thelittlecavern
-- @about
--   Longer description here.
-- @changelog
--   vX.Y (YYYY-MM-DD)
--     + Added feature
--     * Fixed bug
-- @provides
--   [main] Script Name.lua
```

When bumping a version, update both the `@version` tag and add an entry to `@changelog`. The `build-reapack-index.ps1` must be re-run before committing to update `index.xml`.

## Logo Asset Rule

The shared logo PNG (`TLC_logo_transparent_white.png`) must be renamed per-script in `@provides` to avoid ReaPack conflicts. Each script that includes it declares it under a unique name in its `@provides` block.

## Complex Scripts (ImGui UI Pattern)

Scripts with GUIs (`TLC Dashboard.lua`, `TLC Analog Molecule Matrix Console.lua`, etc.) use the **ReaImGui** library. Shared conventions across these scripts:

- `GetColor(r, g, b, a)` — helper to pack RGBA into REAPER's integer format
- Color constants: `COL_BG`, `COL_ACCENT`, `COL_TEXT`, etc.
- Font size constants: `FONT_SMALL`, `FONT_BASE`, `FONT_HEADER`
- Button height constants: `BTN_H_SM`, `BTN_H`, `BTN_H_LG`
- Styling applied via `reaper.ImGui_PushStyleColor` / `PopStyleColor` and `PushStyleVar` / `PopStyleVar`
- Tab-based layout with mode state variable controlling which panel renders

## JSFX (TLC ABMetrix)

The single JSFX file (`TLC ABMetrix.jsfx`) is a 4-channel A/B comparison meter. It expects channels 1/2 = Mix, 3/4 = Reference on the Master Track. It uses JSFX slider parameters, memory buffers, and FFT analysis — no external dependencies beyond REAPER's built-in JSFX engine.

-----------------

To ensure that Claude has read all instructions, it will show me this message when a new chat starts: remaining balance, and also add "Puta Barça i Visca RCDE". This instruction applies only to the first message when a chat starts. After each subsequent message, Claude will show me only the remaining balance.

Claude will always speak to me in Spanish, using short and basic phrases as if talking to a beginner. Claude will never use expressions such as "Good idea" or "I love this kind of challenge" because Claude is software running on a machine and has no feelings about anything.
