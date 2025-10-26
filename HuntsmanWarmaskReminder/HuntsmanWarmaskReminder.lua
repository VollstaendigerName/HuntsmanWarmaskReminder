-- =============================================================================
-- === HuntsmanWarmaskReminder Core Logic (HuntsmanWarmaskReminder.lua)     ===
-- =============================================================================
--[[
    AddOn Name:         HuntsmanWarmaskReminder
    Description:        Warns when Huntsman Warmask is equipped but buff is missing in combat
    Version:            1.0.0
    Author:             VollständigerName
    Dependencies:       None
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
    version = "1.0.1",
    settings = {
        enabled = true,  -- Default: reminder enabled
        debugMode = false  -- Default: debug disabled
    }
}

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
local REMINDER_COOLDOWN = 1000 -- 1 second in milliseconds

-- =============================================================================
-- == RUNTIME VARIABLE DECLARATIONS ============================================
-- =============================================================================
local lastReminderTime = 0
local isInCombat = false
local reminderControl = nil
local hasWarmaskEquipped = false

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
    
    -- Main warning container
    reminderControl = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "Warning")
    reminderControl:SetDimensions(600, 80)
    reminderControl:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reminderControl:SetDrawTier(DT_HIGH)
    reminderControl:SetHidden(true)
    
    -- Warning text label
    local warningText = WINDOW_MANAGER:CreateControl("$(parent)Text", reminderControl, CT_LABEL)
    warningText:SetFont("ZoFontWinH1")
    warningText:SetColor(1, 0.2, 0.2, 1) -- Red color for urgency
    warningText:SetText(">>> HUNTSMAN WARMASK MISSING! <<<")
    warningText:SetDimensions(580, 60)
    warningText:SetAnchor(CENTER, reminderControl, CENTER, 0, 0)
    warningText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warningText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    
    Debug("Warning UI created.")
end

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
        reminderControl:SetHidden(false)
        reminderControl:SetAlpha(1)
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
    if reminderControl then
        Debug("Hiding warning.")
        reminderControl:SetHidden(true)
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
            return true
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
    
    -- Check if addon is enabled
    if not HWR.settings.enabled then
        HideWarning()
        return false
    end
    
    -- Check helmet equipment
    if not CheckWarmaskEquipped() then
        Debug("Wrong helmet or no helmet")
        HideWarning()
        return false
    end
    
    -- Check combat state
    Debug("In combat: " .. tostring(isInCombat))
    if not isInCombat then
        HideWarning()
        return false
    end
    
    -- Check buff status
    local hasBuff = HasBuff()
    Debug("Buff active: " .. tostring(hasBuff))
    if hasBuff then
        HideWarning()
        return false
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
    ShowWarning()
    return true
end

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
    if HWR.settings.enabled and isInCombat and hasWarmaskEquipped then
        CheckConditions()
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
    
    if not inCombat then
        HideWarning()
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
        end
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
    else
        CheckConditions()
    end
end

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