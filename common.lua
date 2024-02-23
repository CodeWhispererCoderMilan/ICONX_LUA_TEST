Area = class()
---@class Area
---@field x1 number
---@field y1 number
---@field x2 number
---@field y2 number

function Area:init(x1, y1, w, h)
	self.x1 = x1
	self.y1 = y1
	self.x2 = x1 + w
	self.y2 = y1 + h
	self:update()
end

function Area:update()
	self.p1 = vec2(self.x1, self.y1)
	self.p2 = vec2(self.x2, self.y1)
	self.p3 = vec2(self.x2, self.y2)
	self.p4 = vec2(self.x1, self.y2)
end

function Area:width()       return self.x2 - self.x1 end
function Area:height()      return self.y2 - self.y1 end
function Area:xCenter()     return self.x1 + ((self.x2 - self.x1) / 2) end
function Area:yCenter()     return self.y1 + ((self.y2 - self.y1) / 2) end
function Area:ratio()       return self:width() / self:height() end
function Area:topLeft()     return self.p1 end
function Area:topRight()    return self.p2 end
function Area:bottomLeft()  return self.p4 end
function Area:bottomRight() return self.p3 end
function Area:center()      return vec2(self:xCenter(), self:yCenter()) end

function Area:setX1(x1)
	local w = self:width()
	self.x1 = x1;
	self.x2 = x1 + w
	self:update()
end

function Area:setX2(x2)
	local w = self:width()
	self.x1 = x2 - w;
	self.x2 = x2
	self:update()
end

function Area:setY1(y1)
	local h = self:height()
	self.y1 = y1;
	self.y2 = y1 + h
	self:update()
end

function Area:setY2(y2)
	local h = self:height()
	self.y1 = y2 - h;
	self.y2 = y2
	self:update()
end

function Area:setHeight(h)
	self.y2 = self.y1 + h
	self:update()
end

function Area:addToPos(d)
	self.x1 = self.x1 + d.x
	self.y1 = self.y1 + d.y
	self.x2 = self.x2 + d.x
	self.y2 = self.y2 + d.y
	self:update()
end

function Area:setRatio(r)
	local w = self:width()
	local h = self:height()
	if w <= 0 or h <= 0 then return end
	local curR = w / h
	if curR == r then return end
	-- LogDebug("C: " .. curR .. ", W: " .. r)
	if r > curR then
		-- not wide enough => reduce height
		local yCen = self:yCenter()
		local newH = w / r
		self.y1 = yCen - (newH / 2)
		self.y2 = self.y1 + newH
		self:update()
	else
		-- too wide => reduce width
		local xCen = self:xCenter()
		local newW = h * r
		self.x1 = xCen - (newW / 2)
		self.x2 = self.x1 + newW
		self:update()
	end
end

function Area:growXY(x,y)
	self.x1 = self.x1 - x
	self.y1 = self.y1 - y
	self.x2 = self.x2 + x
	self.y2 = self.y2 + y
	self:update()
end

function Area:grow(size)
	self:growXY(size, size)
end

function Area:shrinkXY(x, y)
	self:growXY(-x, -y)
end

function Area:shrink(size)
	self:growXY(-size, -size)
end

function Area:copy()
	return Area(self.x1, self.y1, self:width(), self:height())
end

function Area:containsPoint(p)
	return p.x >= self.x1 and p.x <= self.x2 and p.y >= self.y1 and p.y <= self.y2
end

function Area:toRoundedString()
	return string.format("%d, %d, %d, %d", math.round(self.x1), math.round(self.y1), math.round(self:width()), math.round(self:height()))
end


TexCoords = class()
---@class TexCoords
---@field uv1 vec2
---@field uv2 vec2
---@field uv3 vec2
---@field uv4 vec2
function TexCoords:init(u1, v1, u2, v2)
	self.uv1 = vec2(u1, v1)
	self.uv2 = vec2(u2, v1)
	self.uv3 = vec2(u2, v2)
	self.uv4 = vec2(u1, v2)
end

TexCoords2 = { uv1 = vec2(0, 0), uv2 = vec2(1, 1), uv3 = vec2(1, 0), uv4 = vec2(0, 1) }
---@class TexCoords2
---@field uv1 vec2
---@field uv2 vec2
---@field uv3 vec2
---@field uv4 vec2
function TexCoords2:new(o, u1, v1, u2, v2)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	self.uv1 = vec2(u1, v1)
	self.uv2 = vec2(u2, v1)
	self.uv3 = vec2(u2, v2)
	self.uv4 = vec2(u1, v2)
	return o
end


ThrobColor = class()

-- timeToShow: how long to show the throb (in seconds, or nil to show forever)
-- col1:       color values to throb from (array of 4 numbers, or nil to use white)
-- col2:       color values to throb to (array of 4 numbers, or nil to just use col1)
-- intensity:  how much to throb (0.0 to 1.0)
-- speedMult:  hot fast to throb (1.0 is normal)
-- colorIfOff: color to use if throb is off (array of 4 numbers,  or nil)
function ThrobColor:init(timeToShow, col1, col2, intensity, speedMult, colorIfOff)
	self._timeToShow     = timeToShow
	self._color1         = col1
	self._color2         = col2
	self._intensity      = intensity
	self._speedMult      = speedMult
	self._colorIfOff     = colorIfOff
	self._time           = os.time()
	self._trav           = 0
	self._amount         = 0
	self._on             = true
	self._ending         = false
	self._colorForEnding = nil
	if not self._color1 then self._color1 = { 1,1,1,1 } end  -- if no color1, use white
end

function ThrobColor:update(dt) -- returns false if finished
	
	if not self._on then
		return false
	end
	
	if self._ending then
		self._amount = self._amount + (dt * self._speedMult * 3.145)
		local finalCol = self._colorIfOff
		if not finalCol then finalCol = self._color2 end
		if not finalCol then finalCol = self._color1 end
		if self._amount > 1 then self._amount = 1 end
		-- interpolate between current color and final color
		local r = self._colorForEnding[1] + (finalCol[1] - self._colorForEnding[1]) * self._amount
		local g = self._colorForEnding[2] + (finalCol[2] - self._colorForEnding[2]) * self._amount
		local b = self._colorForEnding[3] + (finalCol[3] - self._colorForEnding[3]) * self._amount
		local a = self._colorForEnding[4] + (finalCol[4] - self._colorForEnding[4]) * self._amount
		self._color = rgbm(r, g, b, a)
		if self._amount >= 1 then
			self._on = false
			if self._colorIfOff then
				self._color = rgbm(self._colorIfOff[1], self._colorIfOff[2], self._colorIfOff[3], self._colorIfOff[4])
			end
			return false
		end
		return true
	end

	self._trav   = self._trav + (dt * self._speedMult)
	self._amount = ((math.sin((self._trav % 1.0 + 1.0) * 3.1415 * 2) + 1.0) / 2.0) * self._intensity + (1.0 - self._intensity)
	
	local r,g,b,a
	if self._color2 then
		-- two colors specified so interpolate between them
		r = self._color1[1] + (self._color2[1] - self._color1[1]) * self._amount
		g = self._color1[2] + (self._color2[2] - self._color1[2]) * self._amount
		b = self._color1[3] + (self._color2[3] - self._color1[3]) * self._amount
		a = self._color1[4] + (self._color2[4] - self._color1[4]) * self._amount
	else
		-- one color specified so just use alpha
		r = self._color1[1]
		g = self._color1[2]
		b = self._color1[3]
		a = self._color1[4] * self._amount
	end
	self._color = rgbm(r, g, b, a)
	
	if self._timeToShow and os.time() - self._time > self._timeToShow then
		self._ending         = true
		self._colorForEnding = { r, g, b, a }
		self._amount         = 0
		return true
	end

	return true
end

function ThrobColor:getColor() -- returns a rgbm value
	return self._color
end







function LoadFonts()
	
	-- default fonts installed with AC:
	--     Segoe UI, Segoe UI Black, Segoe UI Light, ..., Consolas, Orbitron

	local fontToUse = "Orbitron"
	-- local fontToUse = "Segoe UI"
	
	NormFont       = ui.DWriteFont(fontToUse):weight(ui.DWriteFont.Weight.Regular):style(ui.DWriteFont.Style.Normal) -- :stretch(ui.DWriteFont.Stretch.Condensed)
	BoldFont       = ui.DWriteFont(fontToUse):weight(ui.DWriteFont.Weight.Bold):style(ui.DWriteFont.Style.Normal)
	ItalicFont     = ui.DWriteFont(fontToUse):weight(ui.DWriteFont.Weight.Regular):style(ui.DWriteFont.Style.Italic)
	BoldItalicFont = ui.DWriteFont(fontToUse):weight(ui.DWriteFont.Weight.Bold):style(ui.DWriteFont.Style.Italic)

end


function SetupImages()


	if not RunningLocally then
		-- _imagesBaseUrl = "http://" .. ac.getServerIP() .. ":" .. ac.getServerPortHTTP() .. "/images"
		ImagesBaseUrl       = "https://iconx.world/traffic/images"
	else
		ImagesBaseUrl       = "./images"
	end
	MainImagePath    = ImagesBaseUrl .. "/main.png"

end


function DrawImageQuad(name, pos, tc, col)
	ui.drawImageQuad(name, pos.p1, pos.p2, pos.p3, pos.p4, col, tc.uv1, tc.uv2, tc.uv3, tc.uv4)
end

function DrawImageQuadFullTC(name, pos, col)
	ui.drawImageQuad(name, pos.p1, pos.p2, pos.p3, pos.p4, col)
end

function DrawImageQuadWhiteFullTC(name, pos)
	ui.drawImageQuad(name, pos.p1, pos.p2, pos.p3, pos.p4)
end
