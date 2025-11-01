--------------------------------------------------------------------------------
-- HuntsmanWarmaskReminder HWRmenu.lua 
-- =============================================================================
-- AddOn Name:        HuntsmanWarmaskReminder
-- Description:       configuration menu system
-- Authors:           Orollas & VollständigerName
-- Version:           1.1.0
-- Dependencies:      LibAddonMenu-2.0
-- =============================================================================
-- =============================================================================
-- === HuntsmanWarmaskReminder CONFIGURATION MENU (HWRmenu.lua) =============================
-- =============================================================================

local HWR = HuntsmanWarmaskReminder
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
    ACCENT     = "|c948159",   -- Gold accent
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
local function CreateSectionHeader(text)
    return {
        type = "divider",
        alpha = 0.3
    }, 
    {
        type = "description",
        text = COLOR.ACCENT..text,
        fontSize = "medium"
    }
end

local MenuPanel = "|cFF0000HuntsmanWarmask|rReminder"
local MenuAuthors = "|cEE82EEO|r|cDD74ECr|r|cCD65EAo|r|cBC57E8l|r|cAB48E6l|r|c9B3AE4a|r|c8A2BE2s|r & |cFFD700Vo|r|cF7D418l|r|cF3D324l|r|cEFD130s|r|cEBD03Ctä|r|cE3CD54n|r|cE0CC60d|r|cDCCA6Ci|r|cD8C978g|r|cD4C784e|r|cD0C690r|r|cCCC49CNa|r|cC4C1B4me|r"
local MenuWebsite = "https://github.com/VollstaendigerName"
local MenuInfo = "HuntsmanWarmaskReminder alerts you when you're wearing the Huntsman War Mask in combat but missing its bonus buff."
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
        {
            type = "submenu",
            name = COLOR.ACCENT.."Settings",
            controls = {
                CreateCheckbox(
                                "Toggle timer on icon",
                                "When this feature is enabled, a timer is displayed. Otherwise, the timer disappears and you only receive a 'bash' reminder every 60 seconds.",
                                function() return HWR.settings.toggleTimer end,
                                function(value) 
                                    HWR.settings.toggleTimer = value
                                end
                ),
                CreateCheckbox(
                            "Show icon outside of combat",
                            "Enable this option if you want to see the reminder outside of combat.",
                            function() return HWR.settings.showOutsideCombat end,
                            function(value) 
                                HWR.settings.showOutsideCombat = value
                            end
                ),
                CreateCheckbox(
                            "Switch between symbol and red text in the middle",
                            "Enable this option to display large red text in the center of the screen, or disable it to display an icon instead.",
                            function() return HWR.settings.toggleWarning end,
                            function(value) 
                                HWR.settings.toggleWarning = value
                            end
                ),
                CreateCheckbox(
                    "Lock the position of the icon",
                    "If this option is enabled, the icon is locked in position.",
                    function() return HWR.settings.LockPosition end,
                    function(value) 
                        HWR.settings.LockPosition = value
                    end,
                    function() return HWR.settings.toggleWarning end
                )
            }        
        }
    }   

    LAM:RegisterOptionControls(HWR.name.."_LAM", optionsTable)
    LAM:RegisterOptionControls(HWR.name.."Menu", options)
end

-- =============================================================================
-- === END OF MENU SYSTEM ======================================================
-- =============================================================================        