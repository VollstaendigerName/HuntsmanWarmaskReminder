-- =============================================================================
-- === HuntsmanWarmaskReminder Line Drawing (HWRLine.lua) ====================
-- =============================================================================
--[[
    Purpose: Draws a line to the last bashed target (PvE only)
    Based on WarMask Line.lua by @brainsnorkel
    Adapted from BetterGuard by TheMrPancake, CrutchAlerts by Kyzeragon,
    and OdySupportIcons by Lamierina7
--]]

local HWR = HuntsmanWarmaskReminder
local NAME = HWR.name
local EM = EVENT_MANAGER

local line = nil
local backdrop = nil
local renderCtrl = nil
local lineWindow = nil

-- Arrow controls
local arrowLeft = nil
local arrowLeftBackdrop = nil
local arrowRight = nil
local arrowRightBackdrop = nil

-- Use shared constant from main module (avoids duplication)
local MARK_OF_HIRCINE_ID = HWR.MARK_OF_HIRCINE_ID or 252048
local LINE_THICKNESS = 6  -- 50% thicker than original 4
local ARROW_SIZE = 16  -- Arrow wing length
local ARROW_ANGLE = 0.5  -- Arrow wing angle in radians (~30 degrees)

-- =============================================================================
-- STATE-BASED COLOR
-- =============================================================================
-- Get current color based on debuff state (matches icon colors)
local function GetStateColor()
    local isInCooldown = HWR.IsInCooldownPeriod and HWR.IsInCooldownPeriod()

    if isInCooldown then
        -- Cooldown period (first 10s) - use cooldown color (default red)
        local c = HWR.settings.cooldownColor or {r=1, g=0.2, b=0.2, a=1}
        return c.r, c.g, c.b, c.a
    elseif HWR.bashedTargetUnitId then
        -- Can bash period (after 10s cooldown) - use timer color (default green)
        local c = HWR.settings.timerColor or {r=0, g=1, b=0, a=1}
        return c.r, c.g, c.b, c.a
    else
        -- Bash state (no debuff active) - use bash color (default white)
        local c = HWR.settings.bashColor or {r=1, g=1, b=1, a=1}
        return c.r, c.g, c.b, c.a
    end
end

-- =============================================================================
-- COORDINATE CONVERSION
-- =============================================================================
-- Convert in-world coordinates to view via linear algebra
local function GetViewCoordinates(wX, wY, wZ)
    if not renderCtrl then return 0, 0, false end

    -- Prepare render space
    Set3DRenderSpaceToCurrentCamera(renderCtrl:GetName())

    -- Retrieve camera world position and orientation vectors
    local cX, cY, cZ = GuiRender3DPositionToWorldPosition(renderCtrl:Get3DRenderSpaceOrigin())
    local fX, fY, fZ = renderCtrl:Get3DRenderSpaceForward()
    local rX, rY, rZ = renderCtrl:Get3DRenderSpaceRight()
    local uX, uY, uZ = renderCtrl:Get3DRenderSpaceUp()

    -- Calculate inverse camera matrix
    local i11 = -(uY * fZ - uZ * fY)
    local i12 = -(rZ * fY - rY * fZ)
    local i13 = -(rY * uZ - rZ * uY)
    local i21 = -(uZ * fX - uX * fZ)
    local i22 = -(rX * fZ - rZ * fX)
    local i23 = -(rZ * uX - rX * uZ)
    local i31 = -(uX * fY - uY * fX)
    local i32 = -(rY * fX - rX * fY)
    local i33 = -(rX * uY - rY * uX)
    local i41 = -(uZ * fY * cX + uY * fX * cZ + uX * fZ * cY - uX * fY * cZ - uY * fZ * cX - uZ * fX * cY)
    local i42 = -(rX * fY * cZ + rY * fZ * cX + rZ * fX * cY - rZ * fY * cX - rY * fX * cZ - rX * fZ * cY)
    local i43 = -(rZ * uY * cX + rY * uX * cZ + rX * uZ * cY - rX * uY * cZ - rY * uZ * cX - rZ * uX * cY)

    -- Screen dimensions
    local uiW, uiH = GuiRoot:GetDimensions()

    -- Calculate unit view position
    local pX = wX * i11 + wY * i21 + wZ * i31 + i41
    local pY = wX * i12 + wY * i22 + wZ * i32 + i42
    local pZ = wX * i13 + wY * i23 + wZ * i33 + i43

    -- Calculate unit screen position
    local w, h = GetWorldDimensionsOfViewFrustumAtDepth(math.abs(pZ))

    return pX * uiW / w, -pY * uiH / h, pZ > 0
end

-- =============================================================================
-- LINE DRAWING
-- =============================================================================
local function DrawLineBetweenPoints(x1, y1, x2, y2)
    if not line then return end

    -- Get state-based color
    local r, g, b, a = GetStateColor()

    backdrop:SetCenterColor(r, g, b, a)
    backdrop:SetEdgeColor(r, g, b, a)

    -- Calculate direction and length
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx)

    -- Calculate midpoint
    local centerX = (x1 + x2) / 2
    local centerY = (y1 + y2) / 2
    line:ClearAnchors()
    line:SetAnchor(CENTER, GuiRoot, CENTER, centerX, centerY)

    -- Set length and rotation
    line:SetDimensions(length, LINE_THICKNESS)
    line:SetTransformRotationZ(-angle)

    -- Draw arrow at target end (x2, y2)
    if arrowLeft and arrowRight then
        arrowLeftBackdrop:SetCenterColor(r, g, b, a)
        arrowLeftBackdrop:SetEdgeColor(r, g, b, a)
        arrowRightBackdrop:SetCenterColor(r, g, b, a)
        arrowRightBackdrop:SetEdgeColor(r, g, b, a)

        -- Arrow wings point back toward the player
        -- Left wing
        local leftAngle = angle + math.pi - ARROW_ANGLE
        local leftEndX = x2 + ARROW_SIZE * math.cos(leftAngle)
        local leftEndY = y2 + ARROW_SIZE * math.sin(leftAngle)
        local leftCenterX = (x2 + leftEndX) / 2
        local leftCenterY = (y2 + leftEndY) / 2

        arrowLeft:ClearAnchors()
        arrowLeft:SetAnchor(CENTER, GuiRoot, CENTER, leftCenterX, leftCenterY)
        arrowLeft:SetDimensions(ARROW_SIZE, LINE_THICKNESS)
        arrowLeft:SetTransformRotationZ(-leftAngle)
        arrowLeft:SetHidden(false)

        -- Right wing
        local rightAngle = angle + math.pi + ARROW_ANGLE
        local rightEndX = x2 + ARROW_SIZE * math.cos(rightAngle)
        local rightEndY = y2 + ARROW_SIZE * math.sin(rightAngle)
        local rightCenterX = (x2 + rightEndX) / 2
        local rightCenterY = (y2 + rightEndY) / 2

        arrowRight:ClearAnchors()
        arrowRight:SetAnchor(CENTER, GuiRoot, CENTER, rightCenterX, rightCenterY)
        arrowRight:SetDimensions(ARROW_SIZE, LINE_THICKNESS)
        arrowRight:SetTransformRotationZ(-rightAngle)
        arrowRight:SetHidden(false)
    end
end

-- =============================================================================
-- PUBLIC FUNCTIONS
-- =============================================================================
function HWR.CreateLineUI()
    -- Create render space control
    renderCtrl = WINDOW_MANAGER:CreateControl(NAME .. "RenderCtrl", GuiRoot, CT_CONTROL)
    renderCtrl:SetAnchorFill(GuiRoot)
    renderCtrl:Create3DRenderSpace()
    renderCtrl:SetHidden(true)

    -- Create parent window for line
    lineWindow = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "LineWin")
    lineWindow:SetClampedToScreen(true)
    lineWindow:SetMouseEnabled(false)
    lineWindow:SetMovable(false)
    lineWindow:SetAnchorFill(GuiRoot)
    lineWindow:SetDrawLayer(DL_BACKGROUND)
    lineWindow:SetDrawTier(DT_LOW)
    lineWindow:SetDrawLevel(0)

    -- Create line control
    line = WINDOW_MANAGER:CreateControl(NAME .. "Line", lineWindow, CT_CONTROL)
    backdrop = WINDOW_MANAGER:CreateControl(NAME .. "LineBackdrop", line, CT_BACKDROP)
    backdrop:SetAnchorFill()
    backdrop:SetCenterColor(1, 1, 1, 1)
    backdrop:SetEdgeColor(1, 1, 1, 1)
    line:SetHidden(true)

    -- Create arrow left wing
    arrowLeft = WINDOW_MANAGER:CreateControl(NAME .. "ArrowLeft", lineWindow, CT_CONTROL)
    arrowLeftBackdrop = WINDOW_MANAGER:CreateControl(NAME .. "ArrowLeftBackdrop", arrowLeft, CT_BACKDROP)
    arrowLeftBackdrop:SetAnchorFill()
    arrowLeftBackdrop:SetCenterColor(1, 1, 1, 1)
    arrowLeftBackdrop:SetEdgeColor(1, 1, 1, 1)
    arrowLeft:SetHidden(true)

    -- Create arrow right wing
    arrowRight = WINDOW_MANAGER:CreateControl(NAME .. "ArrowRight", lineWindow, CT_CONTROL)
    arrowRightBackdrop = WINDOW_MANAGER:CreateControl(NAME .. "ArrowRightBackdrop", arrowRight, CT_BACKDROP)
    arrowRightBackdrop:SetAnchorFill()
    arrowRightBackdrop:SetCenterColor(1, 1, 1, 1)
    arrowRightBackdrop:SetEdgeColor(1, 1, 1, 1)
    arrowRight:SetHidden(true)

    -- Add to HUD fragments
    local frag = ZO_HUDFadeSceneFragment:New(lineWindow)
    HUD_UI_SCENE:AddFragment(frag)
    HUD_SCENE:AddFragment(frag)
end

-- Helper function to check if reticle target has Mark of Hircine debuff
local function TargetHasMarkDebuff()
    if not DoesUnitExist("reticleover") then
        return false
    end

    -- Check if target has the Mark of Hircine debuff
    for i = 1, GetNumBuffs("reticleover") do
        local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("reticleover", i)
        if abilityId == MARK_OF_HIRCINE_ID then
            return true
        end
    end

    return false
end

function HWR.DrawLineToTarget()
    -- Check if line is enabled
    if not HWR.settings.enableLine then
        HWR.RemoveLine()
        return
    end

    -- Check if in PvP (disable in PvP)
    local inPvPWorld = IsPlayerInAvAWorld() or IsActiveWorldBattleground()
    if inPvPWorld then
        HWR.RemoveLine()
        return
    end

    -- Check if reticle target exists
    if not DoesUnitExist("reticleover") then
        HWR.RemoveLine()
        return
    end

    -- Check if target has Mark of Hircine debuff
    if not TargetHasMarkDebuff() then
        HWR.RemoveLine()
        return
    end

    if not line then return end

    line:SetHidden(false)

    -- Get player position (at chest height)
    -- GetUnitRawWorldPosition returns: zoneId, worldX, worldY, worldZ
    local _, pX, pY, pZ = GetUnitRawWorldPosition("player")
    local playerX, playerY, playerInFront = GetViewCoordinates(pX, pY + 100, pZ)

    -- Get target position (at chest height)
    local _, tX, tY, tZ = GetUnitRawWorldPosition("reticleover")
    local targetX, targetY, targetInFront = GetViewCoordinates(tX, tY + 100, tZ)

    -- Only draw if at least one point is in front of camera
    if not playerInFront and not targetInFront then
        line:SetHidden(true)
        if arrowLeft then arrowLeft:SetHidden(true) end
        if arrowRight then arrowRight:SetHidden(true) end
        return
    end

    DrawLineBetweenPoints(playerX, playerY, targetX, targetY)
end

function HWR.RemoveLine()
    if line then
        line:SetHidden(true)
    end
    if arrowLeft then
        arrowLeft:SetHidden(true)
    end
    if arrowRight then
        arrowRight:SetHidden(true)
    end
end
