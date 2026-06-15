-- =============================================================================
-- === HuntsmanWarmaskReminder Core Logic (HuntsmanWarmaskReminder.lua)     ===
-- =============================================================================
--[[
    AddOn Name:         Huntsman Warmask Reminder
    Description:        Warns when Huntsman Warmask is equipped but buff is missing in combat
    Version:            2.0.5
    Author:             VollständigerName & Orollas & brainsnorkel
    Dependencies:       LibAddonMenu-2.0
--]]


-- =============================================================================
-- == GLOBAL ADDON DEFINITION & VERSION CONTROL ================================
-- =============================================================================
local HuntsmanWarmaskReminder = {
    name = "HuntsmanWarmaskReminder",
    version = "2.0.5",
    settings = {
        enabled = true,  -- Default: reminder enabled
        debugMode = false,  -- Default: debug disabled
        showOutsideCombat = false,
        toggleTimer = true,
        toggleWarning = false,
        LockPosition = true,
        showTargetName = false;
        timerFontSize = 32,  -- Timer font size (default 32px)
        targetFontSize = 15,
        warningFontSize = 50, -- Warning font size (default 50px)
        iconSize = 100, -- 100% 
        timerColor = { r = 0, g = 1, b = 0, a = 1 },      -- Green timer
        bashColor = { r = 1, g = 1, b = 1, a = 1 },       -- White bash
        cooldownColor = { r = 1, g = 0.2, b = 0.2, a = 1 }, -- Red cooldown
        position = {
            point = CENTER,
            relativeTo = GuiRoot,
            relativePoint = CENTER,
            x = 128, y = 128 
        },
        colorForFirst10sCooldown = true,
        enableCanBash = false,
        textFont = "Univers67",
        textRight = false, -- Use horizontal layout (icon left, text right)
        },
}

-- =============================================================================
-- == LOCALIZED ALIASES & RUNTIME REFERENCES ===================================
-- =============================================================================
local HWR = HuntsmanWarmaskReminder or {}
local NAME = HWR.name
local EM = EVENT_MANAGER
local HWRSV -- SavedVariables reference

-- Constants
local HUNTSMAN_WARMASK_ITEM_ID = 223189
local HUNTSMAN_WARMASK_BUFF_ID = 252050
local REMINDER_COOLDOWN = 1000 -- 1 second in milliseconds

-- =============================================================================
-- == RUNTIME VARIABLE DECLARATIONS ============================================
-- =============================================================================
local lastReminderTime = 0
local cdTimer = 0
local remainingTime = 0
local isInCombat = false
local reminderControl = nil
local reminderControlWarning = nil
local hasWarmaskEquipped = false
local lastBashedTargetName = nil

local warningIcon
local warningTimer
local warningText 
local targetNameLabel
-- =============================================================================
-- == DEBUG UTILITY FUNCTIONS ==================================================
-- =============================================================================
--[[
    Purpose: Conditional debug output based on settings
--]]
local function Debug(message)
    if HWRSV.debugMode then
        d("[" .. NAME .. "] " .. message)
    end
end

-- =============================================================================
-- == FONT HELPER FUNCTIONS ====================================================
-- =============================================================================
--[[
    Purpose: Returns formatted font string for timer text
--]]
local fontPaths = {
    ["Univers67"] = "EsoUI/Common/Fonts/univers67.otf",
    ["ProseAntiquePSMT"] = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf",
    ["esocartographer-bold"] = "EsoUI/Common/Fonts/esocartographer-bold.otf",
    ["fontin_sans_b"] = "EsoUI/Common/Fonts/fontin_sans_b.otf",
    ["fontin_sans_i"] = "EsoUI/Common/Fonts/fontin_sans_i.otf",
    ["fontin_sans_r"] = "EsoUI/Common/Fonts/fontin_sans_r.otf",
    ["arialn"] = "EsoUI/Common/Fonts/arialn.ttf",
    ["consola"] = "EsoUI/Common/Fonts/consola.ttf",
    ["fontin_sans_sc"] = "EsoUI/Common/Fonts/fontin_sans_sc.otf",
    ["Handwritten_Bold"] = "EsoUI/Common/Fonts/Handwritten_Bold.otf",
    ["trajanpro-regular"] = "EsoUI/Common/Fonts/trajanpro-regular.otf",
    ["univers55"] = "EsoUI/Common/Fonts/univers55.otf",
    ["univers57"] = "EsoUI/Common/Fonts/univers57.otf",
}

local function GetTimerFont()
    local fontSize = tonumber(HWRSV.timerFontSize) or 32
    local fontPath = fontPaths[HWRSV.textFont or "Univers67"]
    local outline = "soft-shadow-thin"
    return string.format("%s|%d|%s", fontPath, fontSize, outline)
end

local function GetTargetNameFont()
    local fontSize = tonumber(HWRSV.targetFontSize) or 15
    local fontPath = fontPaths[HWRSV.textFont or "Univers67"]
    local outline = "soft-shadow-thin"
    return string.format("%s|%d|%s", fontPath, fontSize, outline)
end

--[[
    Purpose: Returns formatted font string for warning text
--]]
local function GetWarningFont()
    local fontSize = tonumber(HWRSV.warningFontSize) or 50
    local fontPath = fontPaths[HWRSV.textFont or "Univers67"]
    local outline = "soft-shadow-thick"
    return string.format("%s|%d|%s", fontPath, fontSize, outline)
end

-- =============================================================================
-- == WARNING UI SUBSYSTEM =====================================================
-- =============================================================================
--[[
    Purpose: Creates the visual warning display
--]]

local function UpdateIconSize()
    if reminderControl and warningIcon then
        local iconSize = HWRSV.iconSize or 100
        local iconDimensions = (iconSize / 100) * 80
        
        reminderControl:SetDimensions(iconDimensions + 40, iconDimensions + 40)
        
        warningIcon:SetDimensions(iconDimensions, iconDimensions)
        
        warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, iconDimensions/2 + 10)
        warningTimer:ClearAnchors()
        if HWRSV.textRight then
                warningTimer:SetAnchor(LEFT, warningIcon, RIGHT, 10, 0)
            else 
                warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, iconDimensions/2 + 10)
            end
            
            Debug("Icon size updated to: " .. iconSize .. "% (" .. iconDimensions .. "px)")
        end
    end
HWR.UpdateIconSize = UpdateIconSize

local function CreateWarningUI()
    Debug("Creating warning UI...")
    
    local iconSize = HWRSV.iconSize or 100
    local iconDimensions = (iconSize / 100) * 80
    
    reminderControl = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "Warning")
    reminderControl:SetDimensions(120, 120)
    reminderControl:SetDrawTier(DT_HIGH)
    reminderControl:SetClampedToScreen(true)
    reminderControl:SetMouseEnabled(true)
    reminderControl:SetMovable(true)
    reminderControl:SetHidden(false)
    
    reminderControl:ClearAnchors()
    reminderControl:SetAnchor(HWRSV.position.point, HWRSV.position.relativeTo, HWRSV.position.relativePoint, HWRSV.position.x, HWRSV.position.y)

    reminderControlWarning = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "WarningMiddle")
    reminderControlWarning:SetDimensions(600, 80)
    reminderControlWarning:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reminderControlWarning:SetDrawTier(DT_HIGH)
    reminderControlWarning:SetHidden(true)

    -- Icon
    warningIcon = WINDOW_MANAGER:CreateControl("$(parent)Icon", reminderControl, CT_TEXTURE)
    warningIcon:SetAnchor(CENTER, reminderControl, CENTER, 0, 0)
    warningIcon:SetDimensions(iconDimensions, iconDimensions)
    --warningIcon:SetDimensions(80, 80)
    warningIcon:SetTexture("/esoui/art/icons/gear_hircinessnarlmask_head_a.dds")
    warningIcon:SetHidden(false)

    -- Timer text
    warningTimer = WINDOW_MANAGER:CreateControl("$(parent)Text", reminderControl, CT_LABEL)
    --warningTimer:SetFont("ZoFontWinH1")
    warningTimer:SetFont(GetTimerFont()) 
    warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, iconDimensions/2 + 10)
    --warningTimer:SetAnchor(CENTER, reminderControl, CENTER, 0, 30)
    warningTimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warningTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    warningTimer:SetColor(1, 1, 1, 1)
    warningTimer:SetText("")

    -- Warning text label
    warningText = WINDOW_MANAGER:CreateControl("$(parent)Text", reminderControlWarning, CT_LABEL)
    warningText:SetFont(GetWarningFont())
    --warningText:SetFont("ZoFontWinH1")
    warningText:SetColor(1, 0.2, 0.2, 1) -- Red color for urgency
    --warningText:SetText(">>> HUNTSMAN WARMASK MISSING! <<<")
    warningText:SetText(">>> BASH <<<")
    warningText:SetDimensions(580, 60)
    warningText:SetAnchor(CENTER, reminderControlWarning, CENTER, 0, 0)
    warningText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warningText:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- Target name label
    targetNameLabel = WINDOW_MANAGER:CreateControl("$(parent)TargetName", reminderControl, CT_LABEL)
    targetNameLabel:SetFont(GetTargetNameFont())
    targetNameLabel:SetAnchor(TOP, warningTimer, BOTTOM, 0, 6)
    targetNameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    targetNameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    targetNameLabel:SetColor(1, 1, 1, 1)
    targetNameLabel:SetText("")
    targetNameLabel:SetHidden(true)

    HWR.UpdateIconSize()
    Debug("Warning UI created.")
end


-- =============================================================================
-- == UpdateTargetName =========================================================
-- =============================================================================
--[[
    Purpose: Sets the target name below the icon to true or false
--]]
local function UpdateTargetName()
    if not targetNameLabel then return end

    if HWRSV.showTargetName and isInCombat then
        targetNameLabel:SetText(lastBashedTargetName)
        targetNameLabel:SetHidden(false)
    else
        lastBashedTargetName = ""
        targetNameLabel:SetHidden(true)
    end
end

local function UpdateTargetNameVisibility()
    UpdateTargetName()
end

HWR.UpdateTargetNameVisibility = UpdateTargetNameVisibility



-- =============================================================================
-- == FONT SIZE UPDATE FUNCTION ================================================
-- =============================================================================
--[[
    Purpose: Updates font sizes for timer and warning text
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

    if targetNameLabel then
        targetNameLabel:SetFont(GetTargetNameFont())
        targetNameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        targetNameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    Debug("Font sizes updated. Timer: " .. (HWRSV.timerFontSize or 32) .. "px, Warning: " .. (HWRSV.warningFontSize or 50) .. "px")
end

HWR.UpdateFontSizes = UpdateFontSizes

-- =============================================================================
-- == WARNING VISIBILITY CONTROL ===============================================
-- =============================================================================
--[[
    Purpose: Displays the warning UI
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
    Purpose: Hides the warning UI
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
    end
end
-- =============================================================================
-- == EQUIPMENT CHECK SUBSYSTEM ================================================
-- =============================================================================
--[[
    Purpose: Checks if Huntsman Warmask is currently equipped
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
    Purpose: Checks if Huntsman Warmask buff is active
--]]
local function HasBuff()
    for i = 1, GetNumBuffs("player") do
        local buffName, _, timeEnding, _, _, _, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        
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
    Purpose: Evaluates all conditions for showing reminder
--]]
local function CheckConditions()
    Debug("Checking conditions...")
    local _, point, relativeTo, relativePoint, UserX, UserY = reminderControl:GetAnchor()
    if not HWRSV.LockPosition and (UserX ~= HWRSV.position.x or UserY ~= HWRSV.position.y) then
        HWRSV.position.point = point
        HWRSV.position.relativeTo = relativeTo
        HWRSV.position.relativePoint = relativePoint
        HWRSV.position.x = UserX
        HWRSV.position.y = UserY
    end 

    -- d(tostring(HWRSV.position.x))
    -- d(tostring(HWRSV.position.y))
    -- Check if addon is enabled
    if not HWRSV.enabled then
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
    if (HWRSV.LockPosition and inMouseMode) or not isInCombat and not HWRSV.showOutsideCombat then
        lastBashedTargetName = ""
        HideWarning()
        HideIconAndTimer()
        return false
    end
    
    -- Check buff status
    local hasBuff,remaining = HasBuff()
    Debug("Buff active: " .. tostring(hasBuff))

    if HWRSV.toggleWarning then
        reminderControl:SetHidden(true)
        if hasBuff then
            HideWarning()
            return false
        else
            reminderControl:SetHidden(true)
        end
    else
        if hasBuff then
            remainingTime = remaining
            reminderControl:SetHidden(false)

            if HWRSV.toggleTimer then
                --warningTimer:SetColor(0, 1, 0, 1) 
                if HWRSV.colorForFirst10sCooldown  and remainingTime >50 then
                    warningTimer:SetColor(
                        HWRSV.cooldownColor.r,
                        HWRSV.cooldownColor.g,
                        HWRSV.cooldownColor.b,
                        HWRSV.cooldownColor.a
                    )
                else
                    warningTimer:SetColor(
                    HWRSV.timerColor.r,
                    HWRSV.timerColor.g,
                    HWRSV.timerColor.b,
                    HWRSV.timerColor.a
                    )
                end    
                if HWRSV.enableCanBash and remainingTime <=50 then warningTimer:SetText(string.format("%d |cAAAAFF CAN BASH|r", remaining))
                else warningTimer:SetText(string.format("%d", remaining)) end
            else
                warningTimer:SetText("")
                remainingTime = 0
                cdTimer = 0
            end
        elseif (isInCombat or HWRSV.showOutsideCombat) and remainingTime <=49 then
            remainingTime = 0
            cdTimer = 0
            reminderControl:SetHidden(false)
            -- warningTimer:SetColor(1, 1, 1, 1) 
            warningTimer:SetColor(
                HWRSV.bashColor.r,
                HWRSV.bashColor.g,
                HWRSV.bashColor.b,
                HWRSV.bashColor.a
            )
            warningTimer:SetText("Bash")
            
        elseif remainingTime > 50 and cdTimer <=10 then
            lastBashedTargetName = ""
            cdTimer = 10-(60-remainingTime)
            remainingTime = remainingTime-0.2
            reminderControl:SetHidden(false)
            --warningTimer:SetColor(1, 0.2, 0.2, 1) 
            warningTimer:SetColor(
                HWRSV.cooldownColor.r,
                HWRSV.cooldownColor.g,
                HWRSV.cooldownColor.b,
                HWRSV.cooldownColor.a
            )
            warningTimer:SetText(string.format("%d", cdTimer-0.2))
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
    if HWRSV.toggleWarning then
        ShowWarning()
    end
    return true
end

-- =============================================================================
-- == CONTINUOUS MONITORING SUBSYSTEM ==========================================
-- =============================================================================
--[[
    Purpose: Periodically checks conditions to ensure state consistency
--]]
local function ContinuousUpdate()
    if HWRSV.showOutsideCombat or (HWRSV.enabled and isInCombat and hasWarmaskEquipped) then
        CheckConditions()
        if reminderControl and not reminderControl:IsHidden() then
            UpdateTargetName()
        end
    end
end

-- =============================================================================
-- == EVENT HANDLER SUBSYSTEM ==================================================
-- =============================================================================
--[[
    Purpose: Handles combat state changes
--]]
local function OnCombatState(eventCode, inCombat)
    isInCombat = inCombat
    Debug("Combat status: " .. (inCombat and "In combat" or "Not in combat"))
    local inMouseMode = IsGameCameraUIModeActive()
    if (HWRSV.LockPosition and inMouseMode) or not inCombat and not HWRSV.showOutsideCombat then
        lastBashedTargetName = ""
        HideWarning()
        HideIconAndTimer()
    else
        CheckConditions()
    end
end

--[[
    Purpose: Handles equipment changes
--]]
local function OnEquipmentChanged(_, _, slotId, _, _, _, _)
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
    Purpose: Handles buff/debuff changes
--]]
local function OnEffectChanged(_, changeType, _, effectName, unitTag, _, _, _, _, _, _, _, _, _, abilityId, _)
    if unitTag == "player" then
        Debug("Effect event: " .. (effectName or "Unknown") .. " (ID: " .. (abilityId or "nil") .. ") Change: " .. changeType)
        if abilityId == HUNTSMAN_WARMASK_BUFF_ID then
            if changeType == EFFECT_RESULT_GAINED then
                Debug("Huntsman Warmask buff activated - hiding warning.")
                HideWarning()
            elseif changeType == EFFECT_RESULT_FADED then
                Debug("Huntsman Warmask buff faded - checking conditions.")
                zo_callLater(CheckConditions, 100)
            end
        end
    end
end

local function OnBashEvent(_, result, _, abilityName, _, _, _, sourceType, targetName, _, _, _, _, _, _, _, abilityId)
    if remainingTime > 51 then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if abilityId == 0 or abilityId == nil then return end
    local formattedTarget = GetUnitName('reticleover') or ((targetName ~= "" and zo_strformat("<<1>>", targetName))) and not (GetUnitName('player'))
    -- d(GetUnitName('reticleover'))
    -- d(((targetName ~= "" and zo_strformat("<<1>>", targetName))))
    local formattedAbility = abilityName ~= "" and zo_strformat("<<1>>", abilityName) or ""
    lastBashedTargetName = formattedTarget
    Debug(string.format(
        "|cAAAAFF[HWR COMBAT]|r result=%d | abilityId=%d | ability=%s | target=%s",
        result,
        abilityId,
        formattedAbility,
        formattedTarget
    ))
end



-- =============================================================================
-- == SLASH COMMAND IMPLEMENTATION =============================================
-- =============================================================================
--[[
    Purpose: Provides user interaction via chat commands
--]]
SLASH_COMMANDS["/huntsmanwarmaskreminder"] = function()
    HWRSV.enabled = not HWRSV.enabled
    d("Huntsman Warmask Reminder: " .. (HWRSV.enabled and "|c00FF00enabled|r" or "|cFF0000disabled|r"))
    
    if not HWRSV.enabled then
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
    HWRSV.timerColor = {r=0, g=1, b=0, a=1}
    d("|cFFFFFF |cFF0000HWR|r Timer Color:|r |c00FF00RESET to green|r")
    if HWRSV.enabled then
        CheckConditions()
    end
end

local function ResetBashColor()
    HWRSV.bashColor = {r=1, g=1, b=1, a=1}
    d("|cFFFFFF |cFF0000HWR|r Bash Color:|r |cFFFFFFRESET to white|r")
    if HWRSV.enabled then
        CheckConditions()
    end
end

local function ResetCooldownColor()
    HWRSV.cooldownColor = {r=1, g=0.2, b=0.2, a=1}
    d("|cFFFFFF |cFF0000HWR|r Cooldown Color:|r |cFF5555RESET to red|r")
    if HWRSV.enabled then
        CheckConditions()
    end
end

local function ToggleAddon()
    HWRSV.enabled = not HWRSV.enabled
    d("|cFFFFFF |cFF0000HWR|r:|r " .. (HWRSV.enabled and "|c00FF00enabled|r" or "|cFF0000disabled|r"))
end

local function ToggleShowOutside()
    HWRSV.showOutsideCombat = not HWRSV.showOutsideCombat
    d("|cFFFFFF|cFF0000HWR|r Show Outside Combat:|r " ..
        (HWRSV.showOutsideCombat and "|c00FF00ON|r" or "|cFF0000OFF|r"))
end

local function ToggleShowTimer()
    HWRSV.toggleTimer = not HWRSV.toggleTimer
    d("|cFFFFFF|cFF0000HWR|r Toggle Timer on Icon:|r " ..
        (HWRSV.toggleTimer and "|c00FF00ON|r" or "|cFF0000OFF|r"))
end

local function ToggleWarning()
    HWRSV.toggleWarning = not HWRSV.toggleWarning
    d("|cFFFFFF|cFF0000HWR|r Toggle Warning in the middle on the screen:|r " ..
        (HWRSV.toggleWarning and "|c00FF00ON|r" or "|cFF0000OFF|r"))
end
SLASH_COMMANDS["/hwr"] = ToggleAddon
SLASH_COMMANDS["/hwrshow"] = ToggleShowOutside
SLASH_COMMANDS["/hwrstoggletimer"] = ToggleShowTimer
SLASH_COMMANDS["/hwrstogglewarning"] = ToggleWarning
SLASH_COMMANDS["/hwrresettimercolor"] = ResetTimerColor
SLASH_COMMANDS["/hwrresetbashcolor"] = ResetBashColor
SLASH_COMMANDS["/hwrresetcooldowncolor"] = ResetCooldownColor

-- =============================================================================
-- === HuntsmanWarmaskReminder CONFIGURATION MENU (HWRmenu.lua) ================
-- =============================================================================

local LAM = LibAddonMenu2

-- =============================================================================
-- == COLOR SCHEMA DEFINITION ==================================================
-- =============================================================================
--[[
    Purpose: Centralized color management for UI consistency
    Color Codes:
    - PRIMARY: Main text (Light Gray |cD4D4D4)
    - SECONDARY: Secondary text (Medium Gray |cA6A6A6)
    - ACCENT: Gold accent (Gold |c948159)
    - WARNING: Error/alert text (Red |cFF5555)
    - DISABLED: Disabled state (Dark Gray |c666666)
    - BORDER: UI borders (Very Dark Gray |c3C3C3C)
--]]
local COLOR = {
    PRIMARY    = "|cD4D4D4",   -- Main text
    SECONDARY  = "|cA6A6A6",   -- Secondary text
    ACCENT     = "|cFF0000",   -- Red accent
    WARNING    = "|cFF5555",   -- Warnings
    DISABLED   = "|c666666",   -- Disabled
    BORDER     = "|c3C3C3C"    -- Borders
}

-- =============================================================================
-- == UI COMPONENT FACTORIES ===================================================
-- =============================================================================
--[[
    Purpose: Reusable component generators for menu consistency
    Features:
    - Standardized styling across all controls
    - Automatic color application
    - Localization integration
    - Dynamic enable/disable states
--]]

--------------------------------------------------------------------------------
-- Checkbox Control Factory
-- @param nameKey: Localization key for display name
-- @param tooltipKey: Localization key for tooltip text
-- @param OWgetFunc: Function to retrieve current value
-- @param OWsetFunc: Function to set new value
-- @param disabledFunc: Optional function to determine disabled state
-- @return: Fully configured checkbox table
--------------------------------------------------------------------------------
local function CreateCheckbox(nameKey, tooltipKey, HWRgetFunc, HWRsetFunc, disabledFunc)
    return {
        type = "checkbox",
        name = COLOR.PRIMARY..nameKey,
        tooltip = COLOR.SECONDARY..tooltipKey,
        getFunc = HWRgetFunc,
        setFunc = HWRsetFunc,
        width = "full",
        style = {
            paddingTop = 8,
            paddingBottom = 8,
            labelBeforeCheckbox = true
        },
        disabled = disabledFunc
    }
end

-- =============================================================================
-- == MENU STRUCTURE COMPONENTS ================================================
-- =============================================================================
--[[
    Purpose: Visual organization elements for menu layout
    Features:
    - Consistent section headers
    - Themed dividers
    - Proper spacing and alignment
--]]

--------------------------------------------------------------------------------
-- Section Header Generator
-- @param text: Display text for section header
-- @return: Divider and description control pair
--------------------------------------------------------------------------------
local MenuPanel = "|cFF0000Huntsman Warmask|r Reminder"
local MenuAuthors = "|cFFD700Vo|r|cF7D418l|r|cF3D324l|r|cEFD130s|r|cEBD03Ctä|r|cE3CD54n|r|cE0CC60d|r|cDCCA6Ci|r|cD8C978g|r|cD4C784e|r|cD0C690r|r|cCCC49CNa|r|cC4C1B4me|r & |cEE82EEO|r|cDD74ECr|r|cCD65EAo|r|cBC57E8l|r|cAB48E6l|r|c9B3AE4a|r|c8A2BE2s|r & brainsnorkel"
local MenuWebsite = "https://github.com/VollstaendigerName"
local MenuInfo = "Huntsman Warmask Reminder reminds you to bash when you wear huntsman's warmask"
-- =============================================================================
-- == MAIN MENU CONSTRUCTION ===================================================
-- =============================================================================
-- Main panel definition
function HWR.BuildMenu(HWRSV)
    local panel = {
        type = "panel",
        name = HWR.name,
        displayName = COLOR.ACCENT..MenuPanel,
        author = MenuAuthors,
        version = COLOR.PRIMARY..HWR.version,
        website = MenuWebsite,
        registerForRefresh = true,
        -- registerForDefaults = true
    }

    -- Register main panel with LibAddonMenu
    LAM:RegisterAddonPanel(HWR.name.."Menu", panel)

    local options = {
        {
            type = "description",
            text = COLOR.SECONDARY..MenuInfo,
            fontSize = "medium",
            width = "full"
        },

        -- Core Mechanics
        -- {
        --     type = "submenu",
        --     name = COLOR.ACCENT.."Settings",
        --     controls = {
        {
            type = "divider",
            alpha = 0.3
        },
        {
            type = "description",
            text = COLOR.ACCENT.."Visual settings",
            fontSize = "medium"
        },
        --{
                 {
                    type = "slider",
                    name = COLOR.PRIMARY.."Icon size",
                    tooltip = COLOR.SECONDARY.."Adjust the size of the warning icon (50-200%)",
                    min = 50,
                    max = 200,
                    step = 5,
                    getFunc = function() return HWRSV.iconSize or 100 end,
                    setFunc = function(value)
                        HWRSV.iconSize = value
                        if HWR.UpdateIconSize then
                            HWR.UpdateIconSize()
                        end
                    end,
                    width = "full",
                    style = {
                        paddingTop = 8,
                        paddingBottom = 8
                    }
                },

                -- Timer Font Size
                {
                    type = "slider",
                    name = COLOR.PRIMARY.."Timer font size",
                    tooltip = COLOR.SECONDARY.."Adjust the font size of the timer text (16-128px)",
                    min = 16,
                    max = 128,
                    step = 1,
                    getFunc = function() return HWRSV.timerFontSize or 32 end,
                    setFunc = function(value)
                        HWRSV.timerFontSize = value
                        if HWR.UpdateFontSizes then
                            HWR.UpdateFontSizes()
                        end
                    end,
                    width = "full",
                    style = {
                        paddingTop = 8,
                        paddingBottom = 8
                    }
                },
                
                -- Target Name Font Size
                {
                    type = "slider",
                    name = COLOR.PRIMARY.."Target name font size",
                    tooltip = COLOR.SECONDARY.."Adjust the font size of the target name text (15-30px)",
                    min = 15,
                    max = 30,
                    step = 1,
                    getFunc = function() return HWRSV.targetFontSize or 15 end,
                    setFunc = function(value)
                        HWRSV.targetFontSize = value
                        if HWR.UpdateFontSizes then
                            HWR.UpdateFontSizes()
                        end
                    end,
                    width = "full",
                    style = {
                        paddingTop = 8,
                        paddingBottom = 8
                    }
                },
                
                -- Warning Font Size
                {
                    type = "slider",
                    name = COLOR.PRIMARY.."Warning font size",
                    tooltip = COLOR.SECONDARY.."Adjust the font size of the warning text (16-128px)",
                    min = 16,
                    max = 128,
                    step = 1,
                    getFunc = function() return HWRSV.warningFontSize or 50 end,
                    setFunc = function(value)
                        HWRSV.warningFontSize = value
                        if HWR.UpdateFontSizes then
                            HWR.UpdateFontSizes()
                        end
                    end,
                    width = "full",
                    style = {
                        paddingTop = 8,
                        paddingBottom = 8
                    }
                },
                { type = "divider", alpha = 0.3 }, -- =============================================================================
                {
                type = "description",
                text = COLOR.ACCENT.."Color settings",
                fontSize = "medium"
                },
                -- Timer
                {
                    type = "colorpicker",
                    name = COLOR.PRIMARY.."Timer color",
                    tooltip = COLOR.SECONDARY.."Set the color for the timer when buff is active",
                    getFunc = function()
                        local c = HWRSV.timerColor or {r=0, g=1, b=0, a=1}
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        HWRSV.timerColor = {r=r, g=g, b=b, a=a}
                        if HWRSV.enabled and reminderControl and warningTimer then
                            CheckConditions()
                        end
                    end,
                    width = "full",
                    style = {
                        paddingTop = 8,
                        paddingBottom = 8
                    }
                },
                -- Bash
                {
                    type = "colorpicker",
                    name = COLOR.PRIMARY.."Bash text color",
                    tooltip = COLOR.SECONDARY.."Set the color for the 'Bash' reminder text",
                    getFunc = function()
                        local c = HWRSV.bashColor or {r=1, g=1, b=1, a=1}
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        HWRSV.bashColor = {r=r, g=g, b=b, a=a}
                        if HWRSV.enabled and reminderControl and warningTimer then
                            CheckConditions()
                        end
                    end,
                    width = "full",
                    style = {
                        paddingTop = 8,
                        paddingBottom = 8
                    }
                },
                -- Cooldown
                {
                    type = "colorpicker",
                    name = COLOR.PRIMARY.."Cooldown timer color",
                    tooltip = COLOR.SECONDARY.."Set the color for the internal cooldown timer of Huntsman's Warmask, which prevents you from applying the debuff if you applied a debuff 10 seconds earlier.",
                    getFunc = function()
                        local c = HWRSV.cooldownColor or {r=1, g=0.2, b=0.2, a=1}
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        HWRSV.cooldownColor = {r=r, g=g, b=b, a=a}
                        if HWRSV.enabled and reminderControl and warningTimer then
                            CheckConditions()
                        end
                    end,
                    width = "full",
                    style = {
                        paddingTop = 8,
                        paddingBottom = 8
                    }
                },
                CreateCheckbox(
                                "Cooldown color",
                                "Indicates the internal cooldown of Huntsman's Warmask, which prevents you from applying the debuff if you applied a debuff 10 seconds earlier.",
                                function() return HWRSV.colorForFirst10sCooldown  end,
                                function(value) 
                                    HWRSV.colorForFirst10sCooldown = value
                                    if HWRSV.enabled and HWR.colorForFirst10sCooldown then
                                        CheckConditions()
                                    end
                                end
                            ),

                { type = "divider", alpha = 0.3 }, -- =============================================================================
                {
                    type = "description",
                    text = COLOR.ACCENT.."Icon settings",
                    fontSize = "medium"
                },
                CreateCheckbox(
                                "Show target name below icon",
                                "Displays the current target name below the icon.",
                                function() return HWRSV.showTargetName end,
                                function(value)
                                    HWRSV.showTargetName = value
                                    if HWR.UpdateTargetNameVisibility then
                                        HWR.UpdateTargetNameVisibility()
                                    end
                                end
                            ),
                CreateCheckbox(--Still dunno who needs that
                                "Show 'can bash' always next to the timer",
                                "When enabled, shows 'can bash' next to the timer after the first 10 seconds.",
                                function() return HWRSV.enableCanBash end,
                                function(value) 
                                    HWRSV.enableCanBash = value
                                    if HWRSV.enabled and HWR.CheckConditions then
                                        CheckConditions()
                                    end
                                end
                            ),
                CreateCheckbox(
                                "Toggle timer on icon",
                                "When this feature is enabled, a timer is displayed. Otherwise, the timer disappears and you only receive a 'bash' reminder every 60 seconds.",
                                function() return HWRSV.toggleTimer end,
                                function(value) 
                                    HWRSV.toggleTimer = value
                                end
                            ),
                CreateCheckbox(
                                "Show icon outside of combat",
                                "Enable this option if you want to see the icon outside of combat.",
                                function() return HWRSV.showOutsideCombat end,
                                function(value) 
                                    HWRSV.showOutsideCombat = value
                                end
                            ),
                CreateCheckbox(
                            "Text on the right side of the icon",
                            "When enabled, shows every text right to the icon instead of below.",
                            function() return HWRSV.textRight end,
                            function(value)
                                HWRSV.textRight = value
                                if HWR.UpdateIconSize then
                                    HWR.UpdateIconSize()
                                end
                                if HWR.CheckConditions then
                                    CheckConditions()
                                end
                            end,
                            function() return HWRSV.toggleWarning end
                            ),

                CreateCheckbox(
                                "Switch between symbol and red text in the middle",
                                "Enable this option to display large red text in the center of the screen, or disable it to display an icon instead.",
                                function() return HWRSV.toggleWarning end,
                                function(value) 
                                    HWRSV.toggleWarning = value
                                end
                            ),
                CreateCheckbox(
                    "Lock the position of the icon",
                    "If this option is enabled, the icon is locked in position.",
                    function() return HWRSV.LockPosition end,
                    function(value) 
                        HWRSV.LockPosition = value
                    end,
                    function() return HWRSV.toggleWarning end
                            ),

                {
            type = "submenu",
            name = COLOR.PRIMARY.."Font settings",
            tooltip = COLOR.SECONDARY.."Configure font family for text display",
            controls = {
                {
                    type = "dropdown",
                    name = COLOR.PRIMARY.."Text Font",
                    tooltip = COLOR.SECONDARY.."Select the font to use for the addon text",
                    choices = {"Univers67", "ProseAntiquePSMT", "esocartographer-bold", "fontin_sans_b", "fontin_sans_i",  "fontin_sans_r", "arialn", "consola", "fontin_sans_sc", "Handwritten_Bold", "trajanpro-regular", "univers55", "univers57"},
                    choicesValues = {"Univers67", "ProseAntiquePSMT", "esocartographer-bold", "fontin_sans_b", "fontin_sans_i",  "fontin_sans_r", "arialn", "consola", "fontin_sans_sc", "Handwritten_Bold", "trajanpro-regular", "univers55", "univers57"},
                    getFunc = function() return HWRSV.textFont or "Univers67" end,
                    setFunc = function(value)
                        HWRSV.textFont = value
                        if HWR.UpdateFontSizes then
                            HWR.UpdateFontSizes()
                        end
                        if HWRSV.enabled and HWR.CheckConditions then
                            CheckConditions()
                        end
                    end,
                    width = "full",
                    style = {
                        paddingTop = 8,
                        paddingBottom = 8
                    }
                }
            }
        }
    }        
    
    LAM:RegisterOptionControls(HWR.name.."Menu", options)
end

-- =============================================================================
-- === END OF MENU SYSTEM ======================================================
-- =============================================================================        

local function sceneChange(_, scene) -- Thank you Duesentrieb <3
    if reminderControl then
        reminderControl:SetHidden(true)
    end
end
-- =============================================================================
-- == ADDON INITIALIZATION =====================================================
-- =============================================================================
--[[
    Purpose: Performs addon initialization routines
--]]
local function Initialize()
    -- SavedVariables initialization
    HWRSV = ZO_SavedVars:NewAccountWide("HuntsmanWarmaskReminderSV", 1, GetWorldName(), HWR.settings)
    --HWR.setting = HWRSV
    
    -- Create warning UI
    CreateWarningUI()
    SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange", ContinuousUpdate)
    SCENE_MANAGER:GetScene("hudui"):RegisterCallback("StateChange", sceneChange)
    EM:RegisterForEvent(NAME, EVENT_COMBAT_EVENT, OnBashEvent)
    EM:AddFilterForEvent(NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 21970)

    -- Register event handlers with appropriate filters
    EM:RegisterForEvent(NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    
    EM:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    
    EM:RegisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnEquipmentChanged)
    EM:AddFilterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_BAG_ID, BAG_WORN)
    
    -- Set up continuous monitoring for state consistency
    EM:RegisterForUpdate(NAME .. "ContinuousUpdate", 250, ContinuousUpdate)
    
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
    Purpose: Handles the EVENT_ADD_ON_LOADED event to initialize the addon
--]]
local function OnAddOnLoaded(event, addonName)
    if addonName == NAME then
        EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end



-- =============================================================================
-- == EVENT REGISTRATION =======================================================
-- =============================================================================
EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
-- SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange", ContinuousUpdate) 
-- SCENE_MANAGER:GetScene("hudui"):RegisterCallback("StateChange", sceneChange)-- Thank you Duesentrieb <3