require "class"
require "globals"
require "common"
require "logs"
require "sounds"
require "leaderboard"


function Now()
    return os.time()
end

function FutureTime(seconds)
    return Now() + seconds
end

function HasReachedTime(timeToReach)
    return Now() >= timeToReach
end


local _timeSinceFetch = 0 
local _fetchDelay = 15
local _maxScroll = 0

local ZOOM_MIN_VALUE = 0.5
local ZOOM_MAX_VALUE = 3.0

local _loadedCalled = false
local _readyCalled = false
local _showMainWindow = false
local _localWindowDrawn = false
local _leaderboardFetched = false

local _gotImage = false
local _live = false

local _showUI = true
local _lastShowUiKeyDown = false

local _uiWinAtLeft = true
local _uiWinAtTop = true
local _uiWinDistsToEdge = nil
local _uiWinPos = vec2(0, 0)
local _uiWinSize = vec2(0, 0)
local _uiZoomAdjust = 1.0
local _mainWinPos = vec2(0, 0)

local _textLogoPos = nil
local _textLogoTC = nil
local _winBgPos = nil ---@type Area
local _winBgTC = nil
local _titleLinePos = nil
local _winBgCol = nil
local _titleLineCol = nil
local _textLogoCol = nil
local _lineTC = nil
local _mainArea = nil ---@type Area
local _winArea = nil ---@type Area
local _winInnerArea = nil ---@type Area
local _leaderboard = nil ---@type Leaderboard




ui.setAsynchronousImagesLoading(true)

function script.prepare(dt)

    -- Note: script.prepare() is apparently called if ac.setStartMessage() is used during initialisation,
    --       and the message is shown until this function returns true. However this does not seem to work.

    LogError("prepare() should not be called.")
    return true

end

function script.loaded()

    if _loadedCalled then
        return
    end
    _loadedCalled = true

    math.randomseed(os.time())

    LogDebug("Loaded (" .. tostring(RunningLocally) .. ").")

    --- DEBUG_CODE_START
    local acCarName = ac.getCarID(0)
    local acCarSkin = ac.getCarSkinID(0)
    LogDebug("Car Name: " .. tostring(acCarName))
    LogDebug("Car Skin: " .. tostring(acCarSkin))
    --- DEBUG_CODE_END

    ac.onClientConnected(script.clientConnected)
    ac.onClientDisconnected(script.clientDisconnected)
    LogDebug("Loaded complete. Fetching real-time leaderboards...")
    

end

function script.update(dt)

    --- DEBUG_CODE_START
    -- Note: this can slow things down - for testing only.
    -- local callStatus, callErr = pcall(function()  
    --- DEBUG_CODE_END

    -- if we are running locally, don't do anything until the window gets drawn
    -- otherwise will run alongside any server version that is running.
    if not _localWindowDrawn then
        LogDebugPeriodically("du_wi", 30.0, "Waiting for window to be drawn...")
        return
    end

    if not _loadedCalled then
        script.loaded()
        return
    end

    if not _showMainWindow then
        _showMainWindow = true
    end

    if not _readyCalled then
        return
    end

    local sim = ac.getSim()

    --- DEBUG_CODE_START
    if false and LogDebugPeriodically("SXX", 10.0, "Checking...") then
        LogDebug("isLive: " .. tostring(sim.isLive))
        LogDebug("isReplayActive: " .. tostring(sim.isReplayActive))
        LogDebug("isSessionStarted: " .. tostring(sim.isSessionStarted))
        LogDebug("raceSessionType: " .. tostring(sim.raceSessionType))
        LogDebug("sessionTimeLeft: " .. tostring(sim.sessionTimeLeft))
        LogDebug("fixedSetup: " .. tostring(sim.fixedSetup))
    end
    --- DEBUG_CODE_END

    if sim.isLive and not sim.isInMainMenu then

        if not _live then
            LogDebug("Live.")
            _live = true
            script.updateDrawingVars()
        end

    else

        if _live then
            LogDebug("Not live.")
            _live = false
        end

    end

    script.handleUiInteraction()

    --- DEBUG_CODE_START
    -- end); if not callStatus then LogError("update> ex: " .. tostring(callErr)) end
    --- DEBUG_CODE_END
    if not _leaderboardFetched then --initial leaderboard fetch
        _leaderboard = Leaderboard(rgbm(1.0, 1.0, 0.0, 1.0))
        _leaderboard:fetch()
         _leaderboardFetched = true 
         _timeSinceFetch = 0

    end
     _timeSinceFetch = _timeSinceFetch + dt ---timer for fetching leaderboard data
    if _timeSinceFetch >= _fetchDelay then --fetch leaderboard data every 15 seconds and reset timer
        _leaderboard:fetch()
        _timeSinceFetch = 0
    end
 
end

function script.clientConnected(connectedCarIndex, connectedSessionID)
    LogDebug("Client connected: " .. tostring(connectedCarIndex) .. ", " .. tostring(connectedSessionID))
end

function script.clientDisconnected(connectedCarIndex, connectedSessionID)
    LogDebug("Client disconnected: " .. tostring(connectedCarIndex) .. ", " .. tostring(connectedSessionID))
end

function script.ready()

    if _readyCalled then
        return
    end
    _readyCalled = true

    script.initVars()

    LogDebug("Ready complete.")

end

function script.initVars()

    SetupImages()
    LoadFonts()

    script.setupWindow()

    LogDebug("Init complete.")

end

function script.setupWindow()

    _mainWinPos = vec2(0, 6)

    _uiWinSize = vec2(350, 320)

    if _uiZoomAdjust > 0 and _uiZoomAdjust ~= 1.0 then
        _uiWinSize = _uiWinSize * _uiZoomAdjust
    end
    local minW, minH, maxW, maxH = 10, 10, 2000, 2000
    if _uiWinSize.x < minW then
        _uiWinSize.x = minW
    end
    if _uiWinSize.y < minH then
        _uiWinSize.y = minH
    end
    if _uiWinSize.x > maxW then
        _uiWinSize.x = maxW
    end
    if _uiWinSize.y > maxH then
        _uiWinSize.y = maxH
    end

    if _uiWinDistsToEdge and #_uiWinDistsToEdge == 4 then
        -- LogDebugFormat("Dists: [ %s, %s, %s, %s ]", _uiWinDistsToEdge[1], _uiWinDistsToEdge[2], _uiWinDistsToEdge[3], _uiWinDistsToEdge[4])
        local uiState = ac.getUI()
        local minDX, minDY, maxDX, maxDY = -50, -50, uiState.windowSize.x - 50, uiState.windowSize.y - 50
        if _uiWinDistsToEdge[1] < minDX then
            _uiWinDistsToEdge[1] = minDX
        end
        if _uiWinDistsToEdge[2] < minDY then
            _uiWinDistsToEdge[2] = minDY
        end
        if _uiWinDistsToEdge[3] < minDX then
            _uiWinDistsToEdge[3] = minDX
        end
        if _uiWinDistsToEdge[4] < minDY then
            _uiWinDistsToEdge[4] = minDY
        end
        if _uiWinDistsToEdge[1] > maxDX then
            _uiWinDistsToEdge[1] = maxDX
        end
        if _uiWinDistsToEdge[2] > maxDY then
            _uiWinDistsToEdge[2] = maxDY
        end
        if _uiWinDistsToEdge[3] > maxDX then
            _uiWinDistsToEdge[3] = maxDX
        end
        if _uiWinDistsToEdge[4] > maxDY then
            _uiWinDistsToEdge[4] = maxDY
        end
        -- LogDebugFormat("Dists: [ %s, %s, %s, %s ]", _uiWinDistsToEdge[1], _uiWinDistsToEdge[2], _uiWinDistsToEdge[3], _uiWinDistsToEdge[4])
        _uiWinAtLeft = _uiWinDistsToEdge[1] < _uiWinDistsToEdge[3]
        _uiWinAtTop = _uiWinDistsToEdge[2] < _uiWinDistsToEdge[4]
        _uiWinPos = vec2(_uiWinDistsToEdge[1], _uiWinDistsToEdge[2])
        if not _uiWinAtLeft then
            _uiWinPos.x = uiState.windowSize.x - _uiWinSize.x - _uiWinDistsToEdge[3]
        end
        if not _uiWinAtTop then
            _uiWinPos.y = uiState.windowSize.y - _uiWinSize.y - _uiWinDistsToEdge[4]
        end
        -- _uiWinDistsToEdge = {  _uiWinPos.x, _uiWinPos.y,  uiState.windowSize.x - (_uiWinPos.x + _winBgPos:width()), uiState.windowSize.y - (_uiWinPos.y + _winBgPos:height()) }
    else
        _uiWinPos = _mainWinPos
        _uiWinAtLeft = true
        _uiWinAtTop = true
    end

    -- LogDebug("_uiWinPos: " .. tostring(_uiWinPos))

    script.updateWindowVars()
    script.updateDrawingVars()
    script.ensureWindowOnScreen()
    script.updateWindowVars()
    script.updateDrawingVars()

end

function script.applyZoom(v)
    if _uiZoomAdjust > 0 and _uiZoomAdjust ~= 1.0 then
        return v * _uiZoomAdjust
    end
    return v
end

function script.updateWindowVars()

    local ta = 0.001
    _winBgTC = TexCoords(0.25 + ta, 0.5 + ta, 0.5 - ta, 0.75 - ta)
    _winBgPos = Area(0, 0, _uiWinSize.x, _uiWinSize.y)

    -- winArea is the visual area of the background image, without the border
    _winArea = _winBgPos:copy()
    _winArea:shrinkXY(_winBgPos:width() * 0.061, _winBgPos:height() * 0.061)

    -- _winInnerArea is the area inside the border
    _winInnerArea = _winBgPos:copy()
    _winInnerArea:shrinkXY(_winBgPos:width() * 0.077, _winBgPos:height() * 0.078)

    local titleH = script.applyZoom(45.0)
    local logoH = titleH * 0.6
    local logoYGap = (titleH - logoH) / 2.0
    local logoY = _winInnerArea.y1 + logoYGap
    local logoBorderW = script.applyZoom(5.0)
    local titleLineH = script.applyZoom(3.0)

    _textLogoPos = Area(logoBorderW, logoY, _uiWinSize.x - logoBorderW, logoH)
    _textLogoTC = TexCoords(0, 0, 1, 88.0 / 512.0)
    _textLogoPos:setRatio(512.0 / 88.0)
    -- _textLogoPos:setX1(4)

    -- _logoTC        = TexCoords(0, 0.25, 0.25, 0.5)

    _winBgCol = rgbm(1.0, 1.0, 1.0, 1)
    _titleLineCol = rgbm(1.0, 1.0, 1.0, 1)
    _textLogoCol = rgbm(1.0, 1.0, 1.0, 0.8)

    _lineTC = TexCoords(0.75 + ta, 0.757, 1.0 - ta, 0.76)
    _titleLinePos = Area(0, _winInnerArea.y1 + titleH, _uiWinSize.x, titleLineH)

    local uiXBorder = script.applyZoom(10.0)
    local x1, y1 = _winInnerArea.x1 + uiXBorder, _titleLinePos.y2 + (logoYGap * 1.3)
    _mainArea = Area(x1, y1, _winInnerArea:width() - uiXBorder - uiXBorder,
        _winInnerArea:height() - titleH - (logoYGap * 2.9))

    _winBgPos:addToPos(_uiWinPos)
    _textLogoPos:addToPos(_uiWinPos)
    _titleLinePos:addToPos(_uiWinPos)
    _winArea:addToPos(_uiWinPos)
    _winInnerArea:addToPos(_uiWinPos)
    _mainArea:addToPos(_uiWinPos)

end

function script.updateDrawingVars()
end

function script.draw3D()
end

function script.drawUI()

    --- DEBUG_CODE_START
    -- Note: this can slow things down - for testing only.
    -- local callStatus, callErr = pcall(function()
    --- DEBUG_CODE_END
   

    if not _readyCalled then
        script.ready()
        return
    end
    
    local showUIKeyDown = ac.isKeyDown(ac.KeyIndex.Control) and ac.isKeyDown(ac.KeyIndex.D)
    if showUIKeyDown and _lastShowUiKeyDown ~= showUIKeyDown then
        _showUI = not _showUI
        _lastShowUiKeyDown = showUIKeyDown
    elseif not showUIKeyDown then
        _lastShowUiKeyDown = false
    end

    if not _showUI then
        ui.text('')
        return
    end

    script.beginDrawWindow()

    if ui.isImageReady(MainImagePath) then
        if not _gotImage then
            -- LogDebug("Got image.")
            _gotImage = true
        end
        if _showMainWindow then
            DrawImageQuad(MainImagePath, _winBgPos, _winBgTC, _winBgCol)
            DrawImageQuad(MainImagePath, _titleLinePos, _lineTC, _titleLineCol)
            DrawImageQuad(MainImagePath, _textLogoPos, _textLogoTC, _textLogoCol)

            -- DEBUG_CODE_START
            -- ui.drawRect(_winArea:topLeft(), _winArea:bottomRight(), rgbm.colors.cyan, 0, ui.CornerFlags.None, 3)
            -- ui.drawRectFilled(_winBgPos:topLeft(), _winBgPos:bottomRight(), rgbm(0,0,1,0.2))
            -- ui.drawRectFilled(_winArea:topLeft(), _winArea:bottomRight(), rgbm(1,0,0,0.2))
            -- ui.drawRectFilled(_winInnerArea:topLeft(), _winInnerArea:bottomRight(), rgbm(1,1,1,0.2))
            -- ui.drawRectFilled(_mainArea:topLeft(), _mainArea:bottomRight(), rgbm(1,0,1,0.2))
            -- ui.drawRectFilled(ui.mousePos() - 10, ui.mousePos() + 10, rgbm(0,1,0,0.2))
            --- DEBUG_CODE_END
        end
    else
        LogDebugPeriodically("du_wi", 0.5, "Waiting for image...")
        script.endDrawWindow()
        return
    end

    --- DEBUG_CODE_START
    if DebugShowWheelsOut then
        car = ac.getCar(0)
        local col = rgbm(0, 1, 0, 1);
        if car.wheelsOutside > 2 then
            col = rgbm(1, 0, 0, 1)
        elseif car.wheelsOutside >= 1 then
            col = rgbm.colors.orange
        end
        local ts = 50;
        if car.wheelsOutside > 2 then
            ts = 100
        elseif car.wheelsOutside >= 1 then
            ts = 60
        end
        ui.setCursor(vec2(25, 355))
        ui.dwriteTextAligned(string.format("WO: %d", car.wheelsOutside), ts, ui.Alignment.Start, ui.Alignment.Start,
            nil, false, rgbm.colors.black)
        ui.setCursor(vec2(20, 350))
        ui.dwriteTextAligned(string.format("WO: %d", car.wheelsOutside), ts, ui.Alignment.Start, ui.Alignment.Start,
            nil, false, col)
    end
    --- DEBUG_CODE_END
    if _leaderboardFetched then ---render leaderboard after data has been fetched from API
        _leaderboard:render(_mainArea)
    end
        script.endDrawWindow()
    
    --- DEBUG_CODE_START
    -- end); if not callStatus then LogError("drawUI> ex: " .. tostring(callErr)) end
    --- DEBUG_CODE_END

end

function script.beginDrawWindow()

    --	if _fadingInLevel < 1 then
    --		ui.pushStyleVar(ui.StyleVar.Alpha, _fadingInLevel)
    --	end

    -- if not _runningLocally then

    --
    -- ui.beginTransparentWindow('Icon.X', _windowDrawPos, _windowDrawSize, true)

    -- create the window to fill the full screen so we can draw anywhere
    local uiState = ac.getUI()
    -- LogDebugPeriodically("bdw", 1.0, "WS: " .. tostring(uiState.windowSize))
    ui.beginTransparentWindow('Icon.X', vec2(0, 0), uiState.windowSize, true)
  
    
    -- ui.drawRect(vec2(0,0), uiState.windowSize, rgbm(0,1,1,0.5), 0, ui.CornerFlags.None, 10)
    
    -- end

end

function script.endDrawWindow()

    -- if not _runningLocally then
    ui.endTransparentWindow()
    -- ui.endToolWindow()
    -- end

    --	if _fadingInLevel < 1 then
    --		ui.pushStyleVar(ui.StyleVar.Alpha, 1.0)
    --		_fadingInLevel = _fadingInLevel + (uiState.dt * 1.0)
    --		if _fadingInLevel > 1.0 then _fadingInLevel = 1.0 end
    --	end

end

local _dragState = 0
local _dragStartPos = vec2(0, 0)
local _dragWinStartPos = vec2(0, 0)
local _dragStartZoom = 0
local _dragZoomDir = false

function script.handleUiInteraction()

    local mousePos = ui.mousePos()
    if mousePos.x == -1 and mousePos.y == -1 then
        return
    end

    -- change cursor if over window
    if _dragState == 0 and _winArea:containsPoint(mousePos) then
        local innerArea = _winArea:copy();
        innerArea:shrink(20)
        if innerArea:containsPoint(mousePos) then
            -- ui.setMouseCursor(ui.MouseCursor.ResizeAll)
        else
            local xCen, yCen = _winBgPos:xCenter(), _winBgPos:yCenter()
            local inTopLeft = mousePos.x < xCen and mousePos.y < yCen
            local inBottomLeft = mousePos.x >= xCen and mousePos.y >= yCen
            if inTopLeft or inBottomLeft then
                ui.setMouseCursor(ui.MouseCursor.ResizeNWSE)
            else
                ui.setMouseCursor(ui.MouseCursor.ResizeNESW)
            end
        end
    elseif _dragState > 0 then
        ui.setMouseCursor(ui.MouseCursor.ResizeAll)
    end

    if ui.mouseClicked(ui.MouseButton.Left) then
        if _dragState == 0 then
            _dragStartPos = mousePos
            if _winArea:containsPoint(_dragStartPos) then
                local innerArea = _winArea:copy();
                innerArea:shrink(20)
                if innerArea:containsPoint(_dragStartPos) then
                    -- LogDebug("Drag Start")
                    _dragWinStartPos = _uiWinPos
                    _dragState = 1
                else
                    -- LogDebug("Drag Border Start")
                    _dragStartZoom = _uiZoomAdjust
                    _dragZoomDir = mousePos.x < _winArea:xCenter()
                    _dragWinStartPos = mousePos
                    _dragState = 2
                end
            end
        end
    end

    if not (ui.mouseWheel() == 0)and _mainArea:containsPoint(ui.mousePos()) and _leaderboardFetched then
        ScrollOffset = ScrollOffset - ui.mouseWheel() * 20 -- Adjust 20 to change scroll speed
        ScrollOffset = math.max(0, ScrollOffset) -- Prevent scrolling above the start
        ScrollOffset = math.min(ScrollOffset, (#_leaderboard.rows-4)*_mainArea:height()/3) -- Prevent scrolling below the end
    end
    if _dragState > 0 then
        if ui.isMouseReleased(ui.MouseButton.Left) then
            if _dragState == 2 and ui.keyboardButtonDown(ui.KeyIndex.Shift) then
                _uiZoomAdjust = 1.0
            end
            _dragState = 0
            script.ensureWindowOnScreen()
            local uiState = ac.getUI()
            _uiWinDistsToEdge = {_uiWinPos.x, _uiWinPos.y, uiState.windowSize.x - (_uiWinPos.x + _uiWinSize.x),
                                 uiState.windowSize.y - (_uiWinPos.y + _uiWinSize.y)}
            script.setupWindow()
            script.updateDrawingVars()
        else
            local delta = mousePos - _dragStartPos
            if _dragState == 1 then
                _uiWinPos = _dragWinStartPos + delta
                script.updateWindowVars()
                script.updateDrawingVars()
            elseif _dragState == 2 then
                local deltaToUse = delta.x
                if _dragZoomDir then
                    deltaToUse = -deltaToUse
                end
                _uiZoomAdjust = _dragStartZoom + (deltaToUse * 0.003)
                if _uiZoomAdjust < ZOOM_MIN_VALUE then
                    _uiZoomAdjust = ZOOM_MIN_VALUE
                end
                if _uiZoomAdjust > ZOOM_MAX_VALUE then
                    _uiZoomAdjust = ZOOM_MAX_VALUE
                end
                -- LogDebugPeriodically("uiza", 0.2, "Zoom: " .. tostring(_uiZoomAdjust))
                script.setupWindow()
            end
        end
    end

end

function script.ensureWindowOnScreen()
    local uiState = ac.getUI()
    local bX, bY = 20, 18
    bX, bY = bX * _uiZoomAdjust, bY * _uiZoomAdjust
    if _uiWinPos.x < -bX then
        _uiWinPos.x = -bX
    end
    if _uiWinPos.x + _winBgPos:width() > uiState.windowSize.x + bX then
        _uiWinPos.x = uiState.windowSize.x - _winBgPos:width() + bX
    end
    if _uiWinPos.y < -bY then
        _uiWinPos.y = -bY
    end
    if _uiWinPos.y + _winBgPos:height() > uiState.windowSize.y + bY then
        _uiWinPos.y = uiState.windowSize.y - _winBgPos:height() + bY
    end
    -- LogDebugFormat("Window: %s, %s", _uiWinPos, _uiWinSize)
end

--- DEBUG_CODE_START

local _tickCt = 0

function script.luaTestDraw()

    ui.text('TICK [' .. _tickCt .. ']')
    _tickCt = _tickCt + 1

    if not _localWindowDrawn then
        LogDebug("LocalWindowDrawn.")
        _localWindowDrawn = true
    end

    if not _readyCalled then
        RunningLocally = true
        script.ready()
        LogDebug("Starting...")
    end

    script.drawUI()

    LogsRender()

end


function script.luaTestRenderOpaque()
    -- LogDebugPeriodically("otro", 1.0, "opaque")
    script.draw3D()
end
function script.luaTestRenderTransparent()
    -- LogDebugPeriodically("otrt", 1.0, "transparent")
end
--- DEBUG_CODE_END
