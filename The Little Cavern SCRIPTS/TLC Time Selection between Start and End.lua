-- @description TLC Time Selection between Start and End
-- @version 1.0
-- @author Jordi Molas - The Little Cavern
-- @donation https://ko-fi.com/thelittlecavern
-- @about
--   # Time Range Creation
--   * Sets the project's time selection between two markers named "=START" and "=END".
--   # Marker Detection
--   * Scans project markers while ignoring regions for selection boundaries.
--   # Feedback
--   * Provides a message box if markers are missing.
--   # Marker Order
--   * Adjusts if markers are placed in reverse order.
-- @changelog
--   # Initial Release
--   * Creates a time selection between the markers named '=START' and '=END'.
--   * Handles marker order and provides feedback if markers are missing.

-- Script para Reaper: Crear selección de tiempo entre marcadores =START y =END
-- Autor: Gemini AI

function SetTimeSelectionBetweenMarkers()
    local _, num_markers = reaper.CountProjectMarkers(0)
    local posStart = nil
    local posEnd = nil

    -- 1. Iterar a través de todos los marcadores para encontrar los nombres
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, markidx = reaper.EnumProjectMarkers3(0, i)
        
        if not isrgn then -- Nos aseguramos de que sea un marcador y no una región
            if name == "=START" then
                posStart = pos
            elseif name == "=END" then
                posEnd = pos
            end
        end
    end

    -- 2. Verificar si encontramos ambos marcadores
    if posStart and posEnd then
        -- En Reaper, el orden no importa para la función, pero lo ideal es que START < END
        if posStart > posEnd then
            posStart, posEnd = posEnd, posStart -- Intercambiamos si están al revés
        end

        -- Establecer la selección de tiempo (isSet=true, isLoop=false)
        reaper.GetSet_LoopTimeRange(true, false, posStart, posEnd, false)
        
        -- Mover el cursor al inicio de la selección (opcional, pero útil)
        reaper.SetEditCurPos(posStart, true, false)
        
        -- Refrescar la vista del timeline
        reaper.UpdateTimeline()
    else
        -- 3. Mensaje de error amigable si falta alguno
        local missing = ""
        if not posStart then missing = "=START" end
        if not posEnd then 
            if missing ~= "" then missing = missing .. " y " end
            missing = missing .. "=END" 
        end
        reaper.ShowMessageBox("No se pudo crear la selección. Falta el marcador: " .. missing, "Aviso", 0)
    end
end

-- Ejecutar la función
reaper.Undo_BeginBlock()
SetTimeSelectionBetweenMarkers()
reaper.Undo_EndBlock("Selección entre marcadores =START y =END", -1)