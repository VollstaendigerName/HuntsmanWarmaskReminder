-- =============================================================================
-- === HuntsmanWarmaskReminder Core Logic (HuntsmanWarmaskReminder.lua)     ===
-- =============================================================================
--[[
    AddOn Name:         HuntsmanWarmaskReminder
    Description:        Warns when Huntsman Warmask is equipped but buff is missing in combat
    Version:            1.2.1
    Author:             VollständigerName
    Dependencies:       LibAddonMenu-2.0
--]]
-- =============================================================================
--[[
    SYSTEM ARCHITECTURE:
    - Combat State Monitoring
    - Equipment Change Detection  
    - Buff Status Tracking
    - Visual Warning System
    - Settings Persistence
--]]
-- =============================================================================

-- =============================================================================
-- == GLOBAL ADDON DEFINITION & VERSION CONTROL ================================
-- =============================================================================
--[[
    Purpose: Establishes fundamental addon identity and configuration
    Contains:
    - Addon metadata for ESO client recognition
    - Default settings configuration
--]]
HuntsmanWarmaskReminder = {
    name = "HuntsmanWarmaskReminder",
    version = "1.2.1",
    settings = {
        enabled = true,  -- Default: reminder enabled
        debugMode = false,  -- Default: debug disabled
        showOutsideCombat = false,
        toggleTimer = true,
        toggleWarning = false,
        LockPosition = true,
        timerFontSize = 32,  -- Timer font size (default 32px)
        warningFontSize = 50, -- Warning font size (default 50px)
        bashedTargetFontSize = 20, -- Bashed target name font size (default 20px)
        iconSize = 100, -- 100% 
        timerColor = { r = 0, g = 1, b = 0, a = 1 },      -- Green timer
        bashColor = { r = 1, g = 1, b = 1, a = 1 },       -- White bash
        cooldownColor = { r = 1, g = 0.2, b = 0.2, a = 1 }, -- Red cooldown
        enableLine = false, -- Draw line to debuffed target (PvE only)
        enableCanBash = true, -- Show "can bash" text when debuff is active (after 10s)
        showBashedTarget = false, -- Show bashed target name under the timer/bash indicator
        horizontalLayout = false, -- Use horizontal layout (icon left, text right)
        fontFamily = "Univers67", -- Font family for text display
        position = {
            point = CENTER,
            relativeTo = GuiRoot,
            relativePoint = CENTER,
            x = 128, y = 128 },
    }
}

-- Track last bashed target (initialize after HWR is defined as local)
HuntsmanWarmaskReminder.bashedTargetName = nil

-- =============================================================================
-- == LOCALIZED ALIASES & RUNTIME REFERENCES ===================================
-- =============================================================================
--[[
    Purpose: Optimizes frequent access patterns and reduces overhead
    Contains:
    - Localized addon namespace reference
    - Cached event manager reference
    - Constant definitions
--]]
local HWR = HuntsmanWarmaskReminder
local NAME = HWR.name
local EM = EVENT_MANAGER
local HWRSV -- SavedVariables reference

-- Constants
local HUNTSMAN_WARMASK_ITEM_ID = 223189
local HUNTSMAN_WARMASK_BUFF_ID = 252050
local MARK_OF_HIRCINE_ID = 252048 -- Mark of Hircine debuff ID
local REMINDER_COOLDOWN = 1000 -- 1 second in milliseconds
local BASH_ABILITY_ID = 21970 -- Bash ability ID
local DEBUFF_DURATION = 60 -- 60 seconds debuff duration
local DEBUFF_COOLDOWN = 10 -- 10 seconds internal cooldown (first 10s of debuff)

-- Expose constants for other modules (e.g., HWRLine.lua)
HWR.MARK_OF_HIRCINE_ID = MARK_OF_HIRCINE_ID

-- =============================================================================
-- == RUNTIME VARIABLE DECLARATIONS ============================================
-- =============================================================================
local lastReminderTime = 0
local cdTimer = 0
local remainingTime = 0
local isInCombat = false
local reminderControl = nil
local reminderControlWarning = nil
local warningBashedTarget = nil -- Bashed target name label
local hasWarmaskEquipped = false

-- UI control references (declared here to avoid implicit globals)
local warningIcon = nil
local warningTimer = nil
local warningBashLabel = nil
local warningCanBash = nil
local warningText = nil

-- Bash tracking variables (similar to WarMask)
local debuffEndTime = 0 -- When the 60s debuff expires
local isDebuffActive = false -- Whether we're tracking an active debuff
local bashedTargetUnitId = nil -- Unit ID of the bashed target
local bashedTargetUnitName = nil -- Unit name of the bashed target

-- Expose bashed target unit ID for line drawing
HWR.bashedTargetUnitId = nil

-- Function to check if we're in the cooldown period (first 10 seconds after bash)
local function IsInCooldownPeriod()
    if not isDebuffActive then
        return false
    end
    local debuffRemaining = debuffEndTime - GetGameTimeSeconds()
    -- Cooldown period is when debuffRemaining > 50 (first 10s of 60s debuff)
    return debuffRemaining > 50
end

-- Expose cooldown check function for line drawing
HWR.IsInCooldownPeriod = IsInCooldownPeriod

-- =============================================================================
-- == DEBUG UTILITY FUNCTIONS ==================================================
-- =============================================================================
--[[
    Function: Debug
    Purpose: Conditional debug output based on settings
    Process Flow:
      1. Checks debug mode setting
      2. Outputs formatted debug message if enabled
--]]
local function Debug(message)
    if HWR.settings.debugMode then
        d("[" .. NAME .. "] " .. message)
    end
end

-- =============================================================================
-- == FONT HELPER FUNCTIONS ====================================================
-- =============================================================================

-- Font family path mapping
local FONT_PATHS = {
    ["Univers67"] = "EsoUI/Common/Fonts/univers67.otf",
    ["ProseAntiquePSMT"] = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf",
}

--[[
    Function: GetFontPath
    Purpose: Returns the font path for the selected font family
--]]
local function GetFontPath()
    local fontFamily = HWR.settings.fontFamily or "Univers67"
    return FONT_PATHS[fontFamily] or FONT_PATHS["Univers67"]
end

--[[
    Function: GetTimerFont
    Purpose: Returns formatted font string for timer text
--]]
local function GetTimerFont()
    local fontSize = tonumber(HWR.settings.timerFontSize) or 32
    local fontPath = GetFontPath()
    local outline = "soft-shadow-thin"
    return string.format("%s|%d|%s", fontPath, fontSize, outline)
end

--[[
    Function: GetWarningFont
    Purpose: Returns formatted font string for warning text
--]]
local function GetWarningFont()
    local fontSize = tonumber(HWR.settings.warningFontSize) or 50
    local fontPath = GetFontPath()
    local outline = "soft-shadow-thick"
    return string.format("%s|%d|%s", fontPath, fontSize, outline)
end

--[[
    Function: GetBashedTargetFont
    Purpose: Returns formatted font string for bashed target name text
--]]
local function GetBashedTargetFont()
    local fontSize = tonumber(HWR.settings.bashedTargetFontSize) or 20
    local fontPath = GetFontPath()
    local outline = "soft-shadow-thin"
    return string.format("%s|%d|%s", fontPath, fontSize, outline)
end

-- =============================================================================
-- == WARNING UI SUBSYSTEM =====================================================
-- =============================================================================
--[[
    Function: CreateWarningUI
    Purpose: Creates the visual warning display
    Process Flow:
      1. Creates top-level warning container
      2. Sets dimensions and positioning
      3. Creates warning text label
      4. Applies styling and formatting
--]]
local function CreateWarningUI()
    Debug("Creating warning UI...")

    local iconSize = HWR.settings.iconSize or 100
    local iconDimensions = (iconSize / 100) * 80
    local isHorizontal = HWR.settings.horizontalLayout

    reminderControl = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "Warning")
    -- Horizontal layout needs wider container
    if isHorizontal then
        reminderControl:SetDimensions(iconDimensions + 200, iconDimensions + 40)
    else
        reminderControl:SetDimensions(120, 120)
    end
    reminderControl:SetDrawTier(DT_HIGH)
    reminderControl:SetClampedToScreen(true)
    reminderControl:SetMouseEnabled(true)
    reminderControl:SetMovable(true)
    reminderControl:SetHidden(false)

    reminderControl:ClearAnchors()
    reminderControl:SetAnchor(HWR.settings.position.point, HWR.settings.position.relativeTo, HWR.settings.position.relativePoint, HWR.settings.position.x, HWR.settings.position.y)

    --
    reminderControlWarning = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "WarningMiddle")
    reminderControlWarning:SetDimensions(600, 80)
    reminderControlWarning:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reminderControlWarning:SetDrawTier(DT_HIGH)
    reminderControlWarning:SetHidden(true)

    -- Icon
    warningIcon = WINDOW_MANAGER:CreateControl("$(parent)Icon", reminderControl, CT_TEXTURE)
    if isHorizontal then
        -- Horizontal: icon on the left
        warningIcon:SetAnchor(LEFT, reminderControl, LEFT, 10, 0)
    else
        -- Vertical: icon centered
        warningIcon:SetAnchor(CENTER, reminderControl, CENTER, 0, 0)
    end
    warningIcon:SetDimensions(iconDimensions, iconDimensions)
    warningIcon:SetTexture("/esoui/art/icons/gear_hircinessnarlmask_head_a.dds")
    warningIcon:SetHidden(false)

    -- Timer text
    warningTimer = WINDOW_MANAGER:CreateControl("$(parent)Text", reminderControl, CT_LABEL)
    warningTimer:SetFont(GetTimerFont())
    if isHorizontal then
        -- Horizontal: timer to the right of icon
        warningTimer:SetAnchor(LEFT, warningIcon, RIGHT, 10, 0)
        warningTimer:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    else
        -- Vertical: timer below icon
        warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, iconDimensions/2 + 10)
        warningTimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    warningTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    warningTimer:SetColor(1, 1, 1, 1)
    warningTimer:SetText("")

    -- "Bash" label (next to timer when debuff is active)
    warningBashLabel = WINDOW_MANAGER:CreateControl("$(parent)BashLabel", reminderControl, CT_LABEL)
    warningBashLabel:SetFont(GetTimerFont())
    warningBashLabel:SetAnchor(LEFT, warningTimer, RIGHT, 5, 0)
    warningBashLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    warningBashLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    warningBashLabel:SetColor(1, 1, 1, 1) -- White color (uses bashColor setting)
    warningBashLabel:SetText("")
    warningBashLabel:SetHidden(true)

    -- "Can bash" label (green text next to timer, shows after 10s cooldown)
    warningCanBash = WINDOW_MANAGER:CreateControl("$(parent)CanBash", reminderControl, CT_LABEL)
    warningCanBash:SetFont(GetTimerFont())
    warningCanBash:SetAnchor(LEFT, warningBashLabel, RIGHT, 5, 0)
    warningCanBash:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    warningCanBash:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    warningCanBash:SetColor(0, 1, 0, 1) -- Green color
    warningCanBash:SetText("")
    warningCanBash:SetHidden(true)

    -- Bashed target name label (under the timer in both layouts)
    warningBashedTarget = WINDOW_MANAGER:CreateControl("$(parent)BashedTarget", reminderControl, CT_LABEL)
    warningBashedTarget:SetFont(GetBashedTargetFont())
    if isHorizontal then
        -- Horizontal: target name below the timer text (which is right of icon)
        warningBashedTarget:SetAnchor(TOPLEFT, warningTimer, BOTTOMLEFT, 0, 5)
        warningBashedTarget:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    else
        -- Vertical: target name below timer, centered
        local bashedTargetOffset = iconDimensions/2 + 10 + math.max(20, iconDimensions * 0.3)
        warningBashedTarget:SetAnchor(CENTER, reminderControl, CENTER, 0, bashedTargetOffset)
        warningBashedTarget:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    warningBashedTarget:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    warningBashedTarget:SetColor(1, 1, 1, 1) -- White color
    warningBashedTarget:SetText("")
    warningBashedTarget:SetHidden(true)

    -- Warning text label
    warningText = WINDOW_MANAGER:CreateControl("$(parent)Text", reminderControlWarning, CT_LABEL)
    warningText:SetFont(GetWarningFont())
    warningText:SetColor(1, 0.2, 0.2, 1) -- Red color for urgency
    warningText:SetText(">>> BASH <<<")
    warningText:SetDimensions(580, 60)
    warningText:SetAnchor(CENTER, reminderControlWarning, CENTER, 0, 0)
    warningText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warningText:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    Debug("Warning UI created.")
end

local function UpdateIconSize()
    if reminderControl and warningIcon then
        local iconSize = HWR.settings.iconSize or 100
        local iconDimensions = (iconSize / 100) * 80
        local isHorizontal = HWR.settings.horizontalLayout

        -- Update main window dimensions based on layout
        if isHorizontal then
            reminderControl:SetDimensions(iconDimensions + 200, iconDimensions + 40)
        else
            reminderControl:SetDimensions(iconDimensions + 40, iconDimensions + 40)
        end

        -- Update icon size
        warningIcon:SetDimensions(iconDimensions, iconDimensions)

        -- Update icon anchor based on layout
        warningIcon:ClearAnchors()
        if isHorizontal then
            warningIcon:SetAnchor(LEFT, reminderControl, LEFT, 10, 0)
        else
            warningIcon:SetAnchor(CENTER, reminderControl, CENTER, 0, 0)
        end

        -- Update timer position based on layout
        warningTimer:ClearAnchors()
        if isHorizontal then
            warningTimer:SetAnchor(LEFT, warningIcon, RIGHT, 10, 0)
            warningTimer:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        else
            warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, iconDimensions/2 + 10)
            warningTimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        end

        -- Update bashed target name position based on layout
        if warningBashedTarget then
            warningBashedTarget:ClearAnchors()
            if isHorizontal then
                warningBashedTarget:SetAnchor(TOPLEFT, warningTimer, BOTTOMLEFT, 0, 5)
                warningBashedTarget:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            else
                local bashedTargetOffset = iconDimensions/2 + 10 + math.max(20, iconDimensions * 0.3)
                warningBashedTarget:SetAnchor(CENTER, reminderControl, CENTER, 0, bashedTargetOffset)
                warningBashedTarget:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            end
        end

        Debug("Icon size updated to: " .. iconSize .. "% (" .. iconDimensions .. "px), layout: " .. (isHorizontal and "horizontal" or "vertical"))
    end
end

HWR.UpdateIconSize = UpdateIconSize -- Global

-- =============================================================================
-- == FONT SIZE UPDATE FUNCTION ================================================
-- =============================================================================
--[[
    Function: UpdateFontSizes
    Purpose: Updates font sizes for timer, warning text, and bashed target name
--]]
local function UpdateFontSizes()
    if warningTimer then
        warningTimer:SetFont(GetTimerFont())
        warningTimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        warningTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    
    if warningText then
        warningText:SetFont(GetWarningFont())
        warningText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        warningText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    
    if warningBashedTarget then
        warningBashedTarget:SetFont(GetBashedTargetFont())
        warningBashedTarget:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        warningBashedTarget:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    
    Debug("Font sizes updated. Timer: " .. (HWR.settings.timerFontSize or 32) .. "px, Warning: " .. (HWR.settings.warningFontSize or 50) .. "px, Bashed Target: " .. (HWR.settings.bashedTargetFontSize or 20) .. "px")
end

HWR.UpdateFontSizes = UpdateFontSizes -- Global 

-- =============================================================================
-- == WARNING VISIBILITY CONTROL ===============================================
-- =============================================================================
--[[
    Function: ShowWarning
    Purpose: Displays the warning UI
    Process Flow:
      1. Checks if control exists
      2. Makes control visible with full opacity
--]]
local function ShowWarning()
    if reminderControl then
        Debug("Showing warning.")
        reminderControlWarning:SetHidden(false)
        reminderControlWarning:SetAlpha(1)
    else
        Debug("ERROR: reminderControl is nil!")
    end
end

--[[
    Function: HideWarning
    Purpose: Hides the warning UI
    Process Flow:
      1. Checks if control exists
      2. Hides the control
--]]
local function HideWarning()
    if reminderControlWarning then
        Debug("Hiding warning.")
        reminderControlWarning:SetHidden(true)
    end
end

local function HideIconAndTimer()
    if reminderControl and warningTimer then
        reminderControl:SetHidden(true)
        warningTimer:SetText("")
        remainingTime = 0
        cdTimer = 0
        if warningBashedTarget then
            warningBashedTarget:SetText("")
            warningBashedTarget:SetHidden(true)
        end
    end
end
-- =============================================================================
-- == EQUIPMENT CHECK SUBSYSTEM ================================================
-- =============================================================================
--[[
    Function: CheckWarmaskEquipped
    Purpose: Checks if Huntsman Warmask is currently equipped
    Process Flow:
      1. Gets current helmet item ID
      2. Compares with target item ID
      3. Updates hasWarmaskEquipped variable
--]]
local function CheckWarmaskEquipped()
    local currentHelmId = GetItemId(BAG_WORN, EQUIP_SLOT_HEAD)
    hasWarmaskEquipped = (currentHelmId == HUNTSMAN_WARMASK_ITEM_ID)
    Debug("Warmask equipped: " .. tostring(hasWarmaskEquipped))
    return hasWarmaskEquipped
end

-- =============================================================================
-- == BUFF DETECTION SUBSYSTEM =================================================
-- =============================================================================
--[[
    Function: HasBuff
    Purpose: Checks if Huntsman Warmask buff is active
    Process Flow:
      1. Iterates through all player buffs
      2. Compares ability IDs with target buff ID
      3. Returns true if buff is found
--]]
local function HasBuff()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo("player", i)
        
        if abilityId == HUNTSMAN_WARMASK_BUFF_ID then
            Debug("Buff found: " .. (buffName or "Unknown") .. " (ID: " .. abilityId .. ")")
            return true, timeEnding - GetFrameTimeSeconds()
        end
    end
    return false
end

-- =============================================================================
-- == CORE LOGIC: CONDITION CHECKING ===========================================
-- =============================================================================
--[[
    Function: CheckConditions
    Purpose: Evaluates all conditions for showing reminder
    Process Flow:
      1. Checks if addon is enabled
      2. Verifies correct helmet is equipped
      3. Confirms combat state
      4. Checks buff status
      5. Validates cooldown period
      6. Shows warning if all conditions met
--]]
local function CheckConditions()
    Debug("Checking conditions...")
    local _, point, relativeTo, relativePoint, UserX, UserY = reminderControl:GetAnchor()
    if UserX ~= HWR.settings.position.x or UserY ~= HWR.settings.position.y then
        HWR.settings.position.point = point
        HWR.settings.position.relativeTo = relativeTo
        HWR.settings.position.relativePoint = relativePoint
        HWR.settings.position.x = UserX
        HWR.settings.position.y = UserY
    end

    -- Check if addon is enabled
    if not HWR.settings.enabled then
        HideWarning()
        HideIconAndTimer()
        return false
    end
    
    -- Check helmet equipment
    if not CheckWarmaskEquipped() then
        Debug("Wrong helmet or no helmet")
        HideWarning()
        HideIconAndTimer()
        return false
    end
    
    -- Check combat state
    Debug("In combat: " .. tostring(isInCombat))
    local inMouseMode = IsGameCameraUIModeActive()
    if (HWR.settings.LockPosition and inMouseMode) or (not isInCombat and not HWR.settings.showOutsideCombat) then
        HideWarning()
        HideIconAndTimer()
        return false
    end
    
    -- Check buff status
    local hasBuff,remaining = HasBuff()
    Debug("Buff active: " .. tostring(hasBuff))

    -- Update debuff timer if active
    if isDebuffActive then
        local debuffRemaining = debuffEndTime - GetGameTimeSeconds()
        if debuffRemaining <= 0 then
            -- Debuff expired
            isDebuffActive = false
            debuffEndTime = 0
            bashedTargetUnitId = nil
            bashedTargetUnitName = nil
            HWR.bashedTargetName = nil -- Clear for line drawing
            HWR.bashedTargetUnitId = nil -- Clear unit ID for line drawing
            if warningCanBash then warningCanBash:SetHidden(true) end
            if warningBashLabel then warningBashLabel:SetHidden(true) end
            if HWR.RemoveLine then
                HWR.RemoveLine()
            end
        end
    end

    -- Hide labels by default
    if warningCanBash then warningCanBash:SetHidden(true) end
    if warningBashLabel then warningBashLabel:SetHidden(true) end
    
    -- Update bashed target name display
    if warningBashedTarget then
        if HWR.settings.showBashedTarget and HWR.bashedTargetName and not reminderControl:IsHidden() then
            warningBashedTarget:SetText(HWR.bashedTargetName)
            warningBashedTarget:SetHidden(false)
        else
            warningBashedTarget:SetText("")
            warningBashedTarget:SetHidden(true)
        end
    end

    if HWR.settings.toggleWarning then
        reminderControl:SetHidden(true)
        if hasBuff then
            -- Has buff - check debuff state for center warning
            if isDebuffActive then
                local debuffRemaining = debuffEndTime - GetGameTimeSeconds()
                if debuffRemaining > 50 then
                    -- Cooldown period (first 10s) - hide warning
                    HideWarning()
                elseif debuffRemaining > 0 then
                    -- Can bash period (50s to 0s) - show "CAN BASH" if enabled
                    if HWR.settings.enableCanBash then
                        ShowWarning()
                        if warningText then
                            warningText:SetText(">>> CAN BASH <<<")
                            warningText:SetColor(
                                HWR.settings.timerColor.r or 0,
                                HWR.settings.timerColor.g or 1,
                                HWR.settings.timerColor.b or 0,
                                HWR.settings.timerColor.a or 1
                            )
                        end
                    else
                        HideWarning()
                    end
                else
                    -- Debuff expired - show "BASH"
                    ShowWarning()
                    if warningText then
                        warningText:SetText(">>> BASH <<<")
                        warningText:SetColor(
                            HWR.settings.bashColor.r or 1,
                            HWR.settings.bashColor.g or 1,
                            HWR.settings.bashColor.b or 1,
                            HWR.settings.bashColor.a or 1
                        )
                    end
                end
            else
                -- No debuff active - bash state, show "BASH"
                ShowWarning()
                if warningText then
                    warningText:SetText(">>> BASH <<<")
                    warningText:SetColor(
                        HWR.settings.bashColor.r or 1,
                        HWR.settings.bashColor.g or 1,
                        HWR.settings.bashColor.b or 1,
                        HWR.settings.bashColor.a or 1
                    )
                end
            end
            return false
        else
            -- No buff - check debuff state for center warning
            if isDebuffActive then
                local debuffRemaining = debuffEndTime - GetGameTimeSeconds()
                if debuffRemaining > 50 then
                    -- Cooldown period (first 10s) - hide warning
                    HideWarning()
                elseif debuffRemaining > 0 then
                    -- Can bash period (50s to 0s) - show "CAN BASH" if enabled
                    if HWR.settings.enableCanBash then
                        ShowWarning()
                        if warningText then
                            warningText:SetText(">>> CAN BASH <<<")
                            warningText:SetColor(
                                HWR.settings.timerColor.r or 0,
                                HWR.settings.timerColor.g or 1,
                                HWR.settings.timerColor.b or 0,
                                HWR.settings.timerColor.a or 1
                            )
                        end
                    else
                        HideWarning()
                    end
                else
                    -- Debuff expired - show "BASH"
                    ShowWarning()
                    if warningText then
                        warningText:SetText(">>> BASH <<<")
                        warningText:SetColor(
                            HWR.settings.bashColor.r or 1,
                            HWR.settings.bashColor.g or 1,
                            HWR.settings.bashColor.b or 1,
                            HWR.settings.bashColor.a or 1
                        )
                    end
                end
            else
                -- No debuff active - bash state, show "BASH"
                ShowWarning()
                if warningText then
                    warningText:SetText(">>> BASH <<<")
                    warningText:SetColor(
                        HWR.settings.bashColor.r or 1,
                        HWR.settings.bashColor.g or 1,
                        HWR.settings.bashColor.b or 1,
                        HWR.settings.bashColor.a or 1
                    )
                end
            end
        end
    else
        -- When toggleWarning is off, hide the center-screen warning
        HideWarning()
        if hasBuff then
            remainingTime = remaining
            reminderControl:SetHidden(false)

            if HWR.settings.toggleTimer then
                -- If debuff is active, show debuff timer instead of buff timer
                if isDebuffActive then
                    local debuffRemaining = debuffEndTime - GetGameTimeSeconds()
                    if debuffRemaining > 0 then
                        -- Cooldown period: first 10s after bash applies debuff (60s to 50s remaining)
                        -- Use cooldown color during cooldown, timer color during "can bash" period
                        if debuffRemaining > 50 then
                            warningTimer:SetColor(
                                HWR.settings.cooldownColor.r or 1,
                                HWR.settings.cooldownColor.g or 0.2,
                                HWR.settings.cooldownColor.b or 0.2,
                                HWR.settings.cooldownColor.a or 1
                            )
                        else
                            warningTimer:SetColor(
                                HWR.settings.timerColor.r or 0,
                                HWR.settings.timerColor.g or 1,
                                HWR.settings.timerColor.b or 0,
                                HWR.settings.timerColor.a or 1
                            )
                        end
                        -- Build timer text - append "can bash" during can bash period (50s to 0s)
                        local timerText = string.format("%d", math.ceil(debuffRemaining))
                        if HWR.settings.enableCanBash and debuffRemaining <= 50 and debuffRemaining > 0 then
                            timerText = timerText .. " can bash"
                        end
                        warningTimer:SetText(timerText)
                        
                        -- Hide "bash" label when debuff is active (only show "can bash" during 50s-0s)
                        if warningBashLabel then
                            warningBashLabel:SetHidden(true)
                        end
                        
                        -- Hide "can bash" label since it's now in the timer text
                        if warningCanBash then
                            warningCanBash:SetHidden(true)
                        end
                    else
                        -- Debuff expired, show buff timer and "bash" state
                        warningTimer:SetColor(
                            HWR.settings.timerColor.r or 0,
                            HWR.settings.timerColor.g or 1,
                            HWR.settings.timerColor.b or 0,
                            HWR.settings.timerColor.a or 1
                        )
                        warningTimer:SetText(string.format("%d", remaining))
                        
                        -- Show "bash" label when debuff expired (bash state)
                        if warningBashLabel then
                            warningBashLabel:SetText("bash")
                            warningBashLabel:SetColor(
                                HWR.settings.bashColor.r or 1,
                                HWR.settings.bashColor.g or 1,
                                HWR.settings.bashColor.b or 1,
                                HWR.settings.bashColor.a or 1
                            )
                            warningBashLabel:SetHidden(false)
                        end
                    end
                else
                    -- No debuff active, show buff timer and "bash" state
                    warningTimer:SetColor(
                        HWR.settings.timerColor.r or 0,
                        HWR.settings.timerColor.g or 1,
                        HWR.settings.timerColor.b or 0,
                        HWR.settings.timerColor.a or 1
                    )
                    warningTimer:SetText(string.format("%d", remaining))
                    
                    -- Show "bash" label when no debuff active (bash state)
                    if warningBashLabel then
                        warningBashLabel:SetText("bash")
                        warningBashLabel:SetColor(
                            HWR.settings.bashColor.r or 1,
                            HWR.settings.bashColor.g or 1,
                            HWR.settings.bashColor.b or 1,
                            HWR.settings.bashColor.a or 1
                        )
                        warningBashLabel:SetHidden(false)
                    end
                end
            else
                warningTimer:SetText("")
                remainingTime = 0
                cdTimer = 0
            end
        elseif (isInCombat or HWR.settings.showOutsideCombat) then
            -- Show icon when debuff is active
            if isDebuffActive then
                local debuffRemaining = debuffEndTime - GetGameTimeSeconds()
                if debuffRemaining > 0 then
                    reminderControl:SetHidden(false)
                    
                    if HWR.settings.toggleTimer then
                        -- Cooldown period: first 10s after bash applies debuff (60s to 50s remaining)
                        -- Use cooldown color during cooldown, timer color during "can bash" period
                        if debuffRemaining > 50 then
                            warningTimer:SetColor(
                                HWR.settings.cooldownColor.r or 1,
                                HWR.settings.cooldownColor.g or 0.2,
                                HWR.settings.cooldownColor.b or 0.2,
                                HWR.settings.cooldownColor.a or 1
                            )
                        else
                            warningTimer:SetColor(
                                HWR.settings.timerColor.r or 0,
                                HWR.settings.timerColor.g or 1,
                                HWR.settings.timerColor.b or 0,
                                HWR.settings.timerColor.a or 1
                            )
                        end
                        -- Build timer text - append "can bash" during can bash period (50s to 0s)
                        local timerText = string.format("%d", math.ceil(debuffRemaining))
                        if HWR.settings.enableCanBash and debuffRemaining <= 50 and debuffRemaining > 0 then
                            timerText = timerText .. " can bash"
                        end
                        warningTimer:SetText(timerText)
                        
                        -- Hide "bash" label when debuff is active (only show "can bash" during 50s-0s)
                        if warningBashLabel then
                            warningBashLabel:SetHidden(true)
                        end
                        
                        -- Hide "can bash" label since it's now in the timer text
                        if warningCanBash then
                            warningCanBash:SetHidden(true)
                        end
                    else
                        warningTimer:SetText("")
                    end
                else
                    -- No debuff active - show "bash" state
                    reminderControl:SetHidden(false)
                    if HWR.settings.toggleTimer then
                        warningTimer:SetColor(
                            HWR.settings.bashColor.r or 1,
                            HWR.settings.bashColor.g or 1,
                            HWR.settings.bashColor.b or 1,
                            HWR.settings.bashColor.a or 1
                        )
                        warningTimer:SetText("Bash")
                    else
                        warningTimer:SetText("")
                    end
                    
                    -- Hide "bash" label when timer already shows "Bash"
                    if warningBashLabel then
                        warningBashLabel:SetHidden(true)
                    end
                end
            else
                -- No debuff active - show "bash" state
                reminderControl:SetHidden(false)
                if HWR.settings.toggleTimer then
                    warningTimer:SetColor(
                        HWR.settings.bashColor.r or 1,
                        HWR.settings.bashColor.g or 1,
                        HWR.settings.bashColor.b or 1,
                        HWR.settings.bashColor.a or 1
                    )
                    warningTimer:SetText("Bash")
                else
                    warningTimer:SetText("")
                end
                
                -- Hide "bash" label when timer already shows "Bash"
                if warningBashLabel then
                    warningBashLabel:SetHidden(true)
                end
            end
        else
            remainingTime = 0
            cdTimer = 0
            reminderControl:SetHidden(true)
        end
    end
    
    -- Check cooldown
    local currentTime = GetGameTimeMilliseconds()
    local timeSinceLastReminder = currentTime - lastReminderTime
    Debug("Time since last warning: " .. timeSinceLastReminder .. "ms")
    
    if timeSinceLastReminder < REMINDER_COOLDOWN then
        Debug("Cooldown active - no warning")
        return false
    end
    
    -- All conditions met - show warning
    Debug("All conditions met - showing warning")
    lastReminderTime = currentTime
    if HWR.settings.toggleWarning then
        ShowWarning()
    end
    return true
end

HWR.CheckConditions = CheckConditions -- Global

-- =============================================================================
-- == CONTINUOUS MONITORING SUBSYSTEM ==========================================
-- =============================================================================
--[[
    Function: ContinuousUpdate
    Purpose: Periodically checks conditions to ensure state consistency
    Process Flow:
      1. Runs every 250ms when conditions might be active
      2. Only checks when addon is enabled and in combat
      3. Maintains consistent state monitoring
--]]
local function ContinuousUpdate()
    -- Update debuff timer if active
    if isDebuffActive then
        local debuffRemaining = debuffEndTime - GetGameTimeSeconds()
        if debuffRemaining <= 0 then
            isDebuffActive = false
            debuffEndTime = 0
            bashedTargetUnitId = nil
            bashedTargetUnitName = nil
            HWR.bashedTargetName = nil -- Clear for line drawing
            HWR.bashedTargetUnitId = nil -- Clear unit ID for line drawing
            if HWR.RemoveLine then
                HWR.RemoveLine()
            end
        end
    end
    
    if HWR.settings.showOutsideCombat or (HWR.settings.enabled and isInCombat and hasWarmaskEquipped) then
        CheckConditions()
    end
    
    -- Update line drawing if enabled
    if HWR.settings.enableLine and HWR.DrawLineToTarget then
        HWR.DrawLineToTarget()
    end
end

-- =============================================================================
-- == EVENT HANDLER SUBSYSTEM ==================================================
-- =============================================================================
--[[
    Function: OnCombatState
    Purpose: Handles combat state changes
    Process Flow:
      1. Updates combat state variable
      2. Hides warning when leaving combat
      3. Checks conditions when entering combat
--]]
local function OnCombatState(eventCode, inCombat)
    isInCombat = inCombat
    Debug("Combat status: " .. (inCombat and "In combat" or "Not in combat"))
    
    -- Clear bashed target when leaving combat
    if not inCombat then
        HWR.bashedTargetName = nil
        bashedTargetUnitId = nil
        bashedTargetUnitName = nil
        isDebuffActive = false
        debuffEndTime = 0
        if HWR.RemoveLine then
            HWR.RemoveLine()
        end
        Debug("Left combat - cleared bashed target")
    end
    
    local inMouseMode = IsGameCameraUIModeActive()
    if (HWR.settings.LockPosition and inMouseMode) or (not inCombat and not HWR.settings.showOutsideCombat) then
        HideWarning()
        HideIconAndTimer()
    else
        CheckConditions()
    end
end

--[[
    Function: OnEquipmentChanged
    Purpose: Handles equipment changes
    Process Flow:
      1. Filters for head slot changes only
      2. Logs equipment changes for debugging
      3. Triggers immediate condition check
--]]
local function OnEquipmentChanged(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
    if slotId == EQUIP_SLOT_HEAD then
        local itemId = GetItemId(BAG_WORN, EQUIP_SLOT_HEAD)
        if itemId and itemId ~= 0 then
            local itemName = GetItemName(BAG_WORN, EQUIP_SLOT_HEAD)
            Debug("Helmet changed: " .. itemName .. " (ID: " .. itemId .. ")")
            CheckWarmaskEquipped()
            CheckConditions()
        else
            Debug("No helmet equipped!")
            hasWarmaskEquipped = false
            HideWarning()
            HideIconAndTimer()
        end
    end
end

--[[
    Function: OnCombatEvent
    Purpose: Detects bash/interrupt events to track the last bashed target
    Process Flow:
      1. Filters for bash ability from player
      2. Tracks the target name for line drawing
      3. Starts 60-second debuff timer
--]]
local function OnCombatEvent(eventCode, result, isError, _, _, _, sourceName, sourceType, targetName, targetType, _, _, _, _, sourceUnitId, targetUnitId, abilityId)
    -- Only track bashes from the player
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then
        return
    end
    
    -- Accept multiple result types for bashes
    local isAcceptedResult = (result == ACTION_RESULT_DAMAGE) or (result == ACTION_RESULT_BLOCKED_DAMAGE) or (result == 2)
    if not isAcceptedResult then
        return
    end
    
    -- Track the bashed target and start debuff timer
    if targetName then
        local formattedTargetName = zo_strformat("<<1>>", targetName)
        
        -- Only accept bashes during allowed periods:
        -- 1. Before bashing anything (no debuff active)
        -- 2. After 60s debuff is finished (no debuff active)
        -- 3. During "can bash" period (50s to 0s remaining on debuff)
        -- DO NOT accept during cooldown period (60s to 50s remaining)
        local canAcceptBash = false
        
        if not isDebuffActive then
            -- No debuff active - can bash (before first bash or after debuff expired)
            canAcceptBash = true
            Debug("Bash accepted - no debuff active (before first bash or after debuff expired)")
        else
            -- Debuff is active - check if we're in the "can bash" period
            local debuffRemaining = debuffEndTime - GetGameTimeSeconds()
            if debuffRemaining <= 50 and debuffRemaining > 0 then
                -- In "can bash" period (50s to 0s remaining)
                canAcceptBash = true
                Debug("Bash accepted - in 'can bash' period (" .. string.format("%.1f", debuffRemaining) .. "s remaining)")
            else
                -- In cooldown period (60s to 50s remaining) - ignore this bash
                Debug("Bash ignored - in cooldown period (" .. string.format("%.1f", debuffRemaining) .. "s remaining, need <= 50s)")
            end
        end
        
        if canAcceptBash then
            HWR.bashedTargetName = formattedTargetName
            bashedTargetUnitName = HWR.bashedTargetName
            bashedTargetUnitId = targetUnitId
            HWR.bashedTargetUnitId = targetUnitId -- Expose for line drawing
            
            -- Start 60-second debuff timer
            debuffEndTime = GetGameTimeSeconds() + DEBUFF_DURATION
            isDebuffActive = true
            
            Debug("Bash detected - tracking target: " .. HWR.bashedTargetName .. " (Unit ID: " .. tostring(targetUnitId) .. ", 60s debuff started)")
            
            -- Update display immediately
            if HWR.settings.enabled then
                CheckConditions()
            end
        end
    end
end

--[[
    Function: OnReticleTargetChanged
    Purpose: Updates line drawing when reticle target changes
    Process Flow:
      1. Checks if line is enabled
      2. Checks if in PvP (disables in PvP)
      3. Draws line if reticle target matches bashed target
--]]
local function OnReticleTargetChanged()
    if not HWR.settings.enableLine then
        if HWR.RemoveLine then
            HWR.RemoveLine()
        end
        return
    end
    
    -- Check if in PvP (disable in PvP)
    local inPvPWorld = IsPlayerInAvAWorld() or IsActiveWorldBattleground()
    if inPvPWorld then
        if HWR.RemoveLine then
            HWR.RemoveLine()
        end
        return
    end
    
    -- Update line drawing
    if HWR.DrawLineToTarget then
        HWR.DrawLineToTarget()
    end
end

--[[
    Function: OnEffectChanged
    Purpose: Handles buff/debuff changes
    Process Flow:
      1. Filters for player effects only
      2. Hides warning when target buff is gained
      3. Checks conditions when buff fades
--]]
local function OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, abilityId, combatUnitType)
    if unitTag == "player" then
        Debug("Effect event: " .. (effectName or "Unknown") .. " (ID: " .. (abilityId or "nil") .. ") Change: " .. changeType)
        
        -- Check if this is our target buff
        if abilityId == HUNTSMAN_WARMASK_BUFF_ID then
            if changeType == EFFECT_RESULT_GAINED then
                Debug("Huntsman Warmask buff activated - hiding warning.")
                HideWarning()
            elseif changeType == EFFECT_RESULT_FADED then
                Debug("Huntsman Warmask buff faded - checking conditions.")
                -- Small delay to ensure the buff is completely removed
                zo_callLater(CheckConditions, 100)
            end
        end
    end
end

-- =============================================================================
-- == SLASH COMMAND IMPLEMENTATION =============================================
-- =============================================================================
--[[
    Function: Slash Command Handler
    Purpose: Provides user interaction via chat commands
    Process Flow:
      1. Toggles enabled setting when /huntsmanwarmaskreminder is called
      2. Provides visual feedback in chat
--]]
SLASH_COMMANDS["/huntsmanwarmaskreminder"] = function()
    HWR.settings.enabled = not HWR.settings.enabled
    d("Huntsman Warmask Reminder: " .. (HWR.settings.enabled and "|c00FF00enabled|r" or "|cFF0000disabled|r"))
    
    if not HWR.settings.enabled then
        HideWarning()
        HideIconAndTimer()
    else
        CheckConditions()
    end
end

-- =======================================================================
-- == Slash Commands =====================================================
-- =======================================================================
local function ResetTimerColor()
    HWR.settings.timerColor = {r=0, g=1, b=0, a=1}
    d("|cFFFFFF |cFF0000HWR|r Timer Color:|r |c00FF00RESET to green|r")
    if HWR.settings.enabled then
        CheckConditions()
    end
end

local function ResetBashColor()
    HWR.settings.bashColor = {r=1, g=1, b=1, a=1}
    d("|cFFFFFF |cFF0000HWR|r Bash Color:|r |cFFFFFFRESET to white|r")
    if HWR.settings.enabled then
        CheckConditions()
    end
end

local function ResetCooldownColor()
    HWR.settings.cooldownColor = {r=1, g=0.2, b=0.2, a=1}
    d("|cFFFFFF |cFF0000HWR|r Cooldown Color:|r |cFF5555RESET to red|r")
    if HWR.settings.enabled then
        CheckConditions()
    end
end

local function ToggleAddon()
    HWR.settings.enabled = not HWR.settings.enabled
    d("|cFFFFFF |cFF0000HWR|r:|r " .. (HWR.settings.enabled and "|c00FF00enabled|r" or "|cFF0000disabled|r"))
end

local function ToggleShowOutside()
    HWR.settings.showOutsideCombat = not HWR.settings.showOutsideCombat
    d("|cFFFFFF|cFF0000HWR|r Show Outside Combat:|r " ..
        (HWR.settings.showOutsideCombat and "|c00FF00ON|r" or "|cFF0000OFF|r"))
end

local function ToggleShowTimer()
    HWR.settings.toggleTimer = not HWR.settings.toggleTimer
    d("|cFFFFFF|cFF0000HWR|r Toggle Timer on Icon:|r " ..
        (HWR.settings.toggleTimer and "|c00FF00ON|r" or "|cFF0000OFF|r"))
end

local function ToggleWarning()
    HWR.settings.toggleWarning = not HWR.settings.toggleWarning
    d("|cFFFFFF|cFF0000HWR|r Toggle Warning in the middle on the screen:|r " ..
        (HWR.settings.toggleWarning and "|c00FF00ON|r" or "|cFF0000OFF|r"))
end
SLASH_COMMANDS["/hwr"] = ToggleAddon
SLASH_COMMANDS["/hwrshow"] = ToggleShowOutside
SLASH_COMMANDS["/hwrstoggletimer"] = ToggleShowTimer
SLASH_COMMANDS["/hwrstogglewarning"] = ToggleWarning
SLASH_COMMANDS["/hwrresettimercolor"] = ResetTimerColor
SLASH_COMMANDS["/hwrresetbashcolor"] = ResetBashColor
SLASH_COMMANDS["/hwrresetcooldowncolor"] = ResetCooldownColor

-- =============================================================================
-- == ADDON INITIALIZATION =====================================================
-- =============================================================================
--[[
    Function: HWR.Initialize
    Purpose: Performs addon initialization routines
    Process Flow:
      1. Initializes SavedVariables
      2. Creates warning UI elements
      3. Registers event handlers with filters
      4. Sets up continuous monitoring
      5. Performs initial condition check
--]]
function HWR.Initialize()
    -- SavedVariables initialization
    HWRSV = ZO_SavedVars:NewAccountWide("HuntsmanWarmaskReminderSV", 1, nil, HWR.settings)
    HWR.settings = HWRSV
    
    -- Create warning UI
    CreateWarningUI()
    
    -- Create line UI (if line module is loaded)
    if HWR.CreateLineUI then
        HWR.CreateLineUI()
    end
    
    -- Register event handlers with appropriate filters
    EM:RegisterForEvent(NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    
    EM:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    
    EM:RegisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnEquipmentChanged)
    EM:AddFilterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_BAG_ID, BAG_WORN)
    
    -- Register bash detection
    EM:RegisterForEvent(NAME, EVENT_COMBAT_EVENT, OnCombatEvent)
    EM:AddFilterForEvent(NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, BASH_ABILITY_ID)
    
    -- Register reticle target change for line drawing
    EM:RegisterForEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)
    
    -- Set up continuous monitoring for state consistency
    EM:RegisterForUpdate(NAME .. "ContinuousUpdate", 250, ContinuousUpdate)

    -- Register scene callbacks (credit: Duesentrieb)
    SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange", ContinuousUpdate)
    SCENE_MANAGER:GetScene("hudui"):RegisterCallback("StateChange", function()
        reminderControl:SetHidden(true)
    end)

    -- Initial condition check
    CheckWarmaskEquipped()
    CheckConditions()

    HWR.BuildMenu(HWRSV)
    Debug("Addon initialized.")
end

-- =============================================================================
-- == EVENT HANDLER: ADDON LOADED ==============================================
-- =============================================================================
--[[
    Function: OnAddOnLoaded
    Purpose: Handles the EVENT_ADD_ON_LOADED event to initialize the addon
    Process Flow:
      1. Checks if the loaded addon is our own
      2. Unregisters event handler after successful initialization
      3. Performs addon initialization
--]]
local function OnAddOnLoaded(event, addonName)
    if addonName == NAME then
        EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
        HWR.Initialize()
    end
end

-- =============================================================================
-- == EVENT REGISTRATION =======================================================
-- =============================================================================
--[[
    Purpose: Registers necessary event handlers for addon operation
    Contains:
    - EVENT_ADD_ON_LOADED handler for delayed initialization
--]]
EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
