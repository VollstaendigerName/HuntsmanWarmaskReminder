--------------------------------------------------------------------------------
-- HuntsmanWarmaskReminder HWRmenu.lua 
-- =============================================================================
-- AddOn Name:        HuntsmanWarmaskReminder
-- Description:       configuration menu system
-- Authors:           Orollas & VollständigerName
-- Version:           1.2.1
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

        -- Visibility Settings Section
        {
            type = "divider",
            alpha = 0.3
        },
        {
            type = "description",
            text = COLOR.ACCENT.."Visibility Settings",
            fontSize = "medium"
        },
        CreateCheckbox(
            "Lock the position of the icon",
            "If this option is enabled, the icon is locked in position.",
            function() return HWR.settings.LockPosition end,
            function(value) 
                HWR.settings.LockPosition = value
            end,
            function() return HWR.settings.toggleWarning end
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
            "Toggle timer on icon",
            "When this feature is enabled, a timer is displayed. Otherwise, the timer disappears and you only receive a 'bash' reminder every 60 seconds.",
            function() return HWR.settings.toggleTimer end,
            function(value) 
                HWR.settings.toggleTimer = value
            end
        ),
        CreateCheckbox(
            "Show \"can bash\" text",
            "When enabled, shows 'can bash' in green text next to the debuff timer after the first 10 seconds (from 50s to 0s remaining).",
            function() return HWR.settings.enableCanBash end,
            function(value) 
                HWR.settings.enableCanBash = value
                if HWR.settings.enabled and HWR.CheckConditions then
                    HWR.CheckConditions()
                end
            end
        ),
        CreateCheckbox(
            "Show bashed target name",
            "When enabled, displays the name of the currently bashed/debuffed target under the countdown/bash indicator.",
            function() return HWR.settings.showBashedTarget end,
            function(value) 
                HWR.settings.showBashedTarget = value
                if HWR.settings.enabled and HWR.CheckConditions then
                    HWR.CheckConditions()
                end
            end
        ),
        CreateCheckbox(
            "Show \"BASH\" center-screen instead of icon",
            "Enable this option to display large red text in the center of the screen, or disable it to display an icon instead.",
            function() return HWR.settings.toggleWarning end,
            function(value)
                HWR.settings.toggleWarning = value
                if HWR.CheckConditions then
                    HWR.CheckConditions()
                end
            end
        ),
        CreateCheckbox(
            "Horizontal layout",
            "When enabled, displays the icon on the left with timer/bash/can bash text to the right, and bashed target name below the text.",
            function() return HWR.settings.horizontalLayout end,
            function(value)
                HWR.settings.horizontalLayout = value
                if HWR.UpdateIconSize then
                    HWR.UpdateIconSize()
                end
                if HWR.CheckConditions then
                    HWR.CheckConditions()
                end
            end,
            function() return HWR.settings.toggleWarning end
        ),

        -- Visual Aids Section
        {
            type = "divider",
            alpha = 0.3
        },
        {
            type = "description",
            text = COLOR.ACCENT.."Visual Aids (PvE Only)",
            fontSize = "medium"
        },
        CreateCheckbox(
            "Draw arrow to debuffed target",
            "When enabled, draws an arrow from you to the target with Mark of Hircine debuff when you look at them. Only works in PvE (disabled in PvP).",
            function() return HWR.settings.enableLine end,
            function(value)
                HWR.settings.enableLine = value
                if not value and HWR.RemoveLine then
                    HWR.RemoveLine()
                elseif value and HWR.DrawLineToTarget then
                    HWR.DrawLineToTarget()
                end
            end
        ),

        -- Display Settings Section (merged with Color Settings)
        {
            type = "divider",
            alpha = 0.3
        },
        {
            type = "description",
            text = COLOR.ACCENT.."Display Settings",
            fontSize = "medium"
        },
        {
            type = "slider",
            name = COLOR.PRIMARY.."Icon Size",
            tooltip = COLOR.SECONDARY.."Adjust the size of the warning icon (50-200%)",
            min = 50,
            max = 200,
            step = 5,
            getFunc = function() return HWR.settings.iconSize or 100 end,
            setFunc = function(value)
                HWR.settings.iconSize = value
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
        {
            type = "slider",
            name = COLOR.PRIMARY.."Timer Font Size",
            tooltip = COLOR.SECONDARY.."Adjust the font size of the timer text (16-128px)",
            min = 16,
            max = 128,
            step = 1,
            getFunc = function() return HWR.settings.timerFontSize or 32 end,
            setFunc = function(value)
                HWR.settings.timerFontSize = value
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
        {
            type = "slider",
            name = COLOR.PRIMARY.."Warning Font Size",
            tooltip = COLOR.SECONDARY.."Adjust the font size of the warning text (16-128px)",
            min = 16,
            max = 128,
            step = 1,
            getFunc = function() return HWR.settings.warningFontSize or 50 end,
            setFunc = function(value)
                HWR.settings.warningFontSize = value
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
        {
            type = "slider",
            name = COLOR.PRIMARY.."Bashed Target Font Size",
            tooltip = COLOR.SECONDARY.."Adjust the font size of the bashed target name text (12-64px)",
            min = 12,
            max = 64,
            step = 1,
            getFunc = function() return HWR.settings.bashedTargetFontSize or 20 end,
            setFunc = function(value)
                HWR.settings.bashedTargetFontSize = value
                if HWR.UpdateFontSizes then
                    HWR.UpdateFontSizes()
                end
                if HWR.settings.enabled and HWR.CheckConditions then
                    HWR.CheckConditions()
                end
            end,
            width = "full",
            style = {
                paddingTop = 8,
                paddingBottom = 8
            }
        },
        {
            type = "colorpicker",
            name = COLOR.PRIMARY.."Timer Color (Active Buff)",
            tooltip = COLOR.SECONDARY.."Set the color for the timer when buff is active",
            getFunc = function()
                local c = HWR.settings.timerColor or {r=0, g=1, b=0, a=1}
                return c.r, c.g, c.b, c.a
            end,
            setFunc = function(r, g, b, a)
                HWR.settings.timerColor = {r=r, g=g, b=b, a=a}
                if HWR.settings.enabled and HWR.CheckConditions then
                    HWR.CheckConditions()
                end
            end,
            width = "full",
            style = {
                paddingTop = 8,
                paddingBottom = 8
            }
        },
        {
            type = "colorpicker",
            name = COLOR.PRIMARY.."Bash Text Color",
            tooltip = COLOR.SECONDARY.."Set the color for the 'Bash' reminder text",
            getFunc = function()
                local c = HWR.settings.bashColor or {r=1, g=1, b=1, a=1}
                return c.r, c.g, c.b, c.a
            end,
            setFunc = function(r, g, b, a)
                HWR.settings.bashColor = {r=r, g=g, b=b, a=a}
                if HWR.settings.enabled and HWR.CheckConditions then
                    HWR.CheckConditions()
                end
            end,
            width = "full",
            style = {
                paddingTop = 8,
                paddingBottom = 8
            }
        },
        {
            type = "colorpicker",
            name = COLOR.PRIMARY.."Cooldown Timer Color",
            tooltip = COLOR.SECONDARY.."Set the color for the cooldown timer",
            getFunc = function()
                local c = HWR.settings.cooldownColor or {r=1, g=0.2, b=0.2, a=1}
                return c.r, c.g, c.b, c.a
            end,
            setFunc = function(r, g, b, a)
                HWR.settings.cooldownColor = {r=r, g=g, b=b, a=a}
                if HWR.settings.enabled and HWR.CheckConditions then
                    HWR.CheckConditions()
                end
            end,
            width = "full",
            style = {
                paddingTop = 8,
                paddingBottom = 8
            }
        },

        -- Font Settings Submenu (collapsed)
        {
            type = "submenu",
            name = COLOR.PRIMARY.."Font Settings",
            tooltip = COLOR.SECONDARY.."Configure font family for text display",
            controls = {
                {
                    type = "dropdown",
                    name = COLOR.PRIMARY.."Font Family",
                    tooltip = COLOR.SECONDARY.."Select the font family to use for the addon text",
                    choices = {"Univers67", "ProseAntiquePSMT"},
                    choicesValues = {"Univers67", "ProseAntiquePSMT"},
                    getFunc = function() return HWR.settings.fontFamily or "Univers67" end,
                    setFunc = function(value)
                        HWR.settings.fontFamily = value
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
                    name = COLOR.PRIMARY.."Target Name Font Size",
                    tooltip = COLOR.SECONDARY.."Adjust the font size of the target name text (15-30px)",
                    min = 15,
                    max = 30,
                    step = 1,
                    getFunc = function() return HWR.settings.targetFontSize or 15 end,
                    setFunc = function(value)
                        HWR.settings.targetFontSize = value
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
                    name = COLOR.PRIMARY.."Warning Font Size",
                    tooltip = COLOR.SECONDARY.."Adjust the font size of the warning text (16-128px)",
                    min = 16,
                    max = 128,
                    step = 1,
                    getFunc = function() return HWR.settings.warningFontSize or 50 end,
                    setFunc = function(value)
                        HWR.settings.warningFontSize = value
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

                -- Timer
                {
                    type = "colorpicker",
                    name = COLOR.PRIMARY.."Timer Color (Active Buff)",
                    tooltip = COLOR.SECONDARY.."Set the color for the timer when buff is active",
                    getFunc = function()
                        local c = HWR.settings.timerColor or {r=0, g=1, b=0, a=1}
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        HWR.settings.timerColor = {r=r, g=g, b=b, a=a}
                        if HWR.settings.enabled and reminderControl and warningTimer then
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
                    name = COLOR.PRIMARY.."Bash Text Color",
                    tooltip = COLOR.SECONDARY.."Set the color for the 'Bash' reminder text",
                    getFunc = function()
                        local c = HWR.settings.bashColor or {r=1, g=1, b=1, a=1}
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        HWR.settings.bashColor = {r=r, g=g, b=b, a=a}
                        if HWR.settings.enabled and reminderControl and warningTimer then
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
                    name = COLOR.PRIMARY.."Cooldown Timer Color",
                    tooltip = COLOR.SECONDARY.."Set the color for the cooldown timer",
                    getFunc = function()
                        local c = HWR.settings.cooldownColor or {r=1, g=0.2, b=0.2, a=1}
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        HWR.settings.cooldownColor = {r=r, g=g, b=b, a=a}
                        if HWR.settings.enabled and reminderControl and warningTimer then
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
                                "Show target name below icon",
                                "Displays the current target name below the warning icon.",
                                function() return HWR.settings.showTargetName end,
                                function(value)
                                    HWR.settings.showTargetName = value
                                    if HWR.UpdateTargetNameVisibility then
                                        HWR.UpdateTargetNameVisibility()
                                    end
                                end
                ),
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

    --LAM:RegisterOptionControls(HWR.name.."_LAM", optionsTable)
    LAM:RegisterOptionControls(HWR.name.."Menu", options)
end

-- =============================================================================
-- === END OF MENU SYSTEM ======================================================
-- =============================================================================        