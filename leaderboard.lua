require "class"
require "common"
require "logs"
require "globals"

function ConvertToLuaTable(jsonString) -- converts JSON object to lua table
    -- Remove the brackets at the start and end of the JSON string
    jsonString = jsonString:sub(2, -2)

    -- Split the string into individual user entries
    local entries = {}
    local pattern = '{(.-)}'
    for entry in jsonString:gmatch(pattern) do
        table.insert(entries, entry)
    end

    -- Parse each entry
    local users = {}
    for _, entry in ipairs(entries) do
        local user = {}

        -- Extract and assign each field to the user table
        for key, value in entry:gmatch('"([^"]+)":"?([^",}]+)"?') do
            if key and value then
                -- Convert JSON keys to Lua table fields
                key = key:gsub('avatar_url', 'avatar_url')
                value = value:gsub('\\/', '/')

                -- Attempt to convert numeric values
                if tonumber(value) then
                    user[key] = tonumber(value)
                else
                    user[key] = value
                end
            end
        end

        -- Add the parsed user to the users table
        table.insert(users, user)
    end

    return users
end

function FormatLapTime(milliseconds) ---formatting the lap time to a string
    local minutes = math.floor(milliseconds / 60000)
    local seconds = math.floor((milliseconds % 60000) / 1000)
    local millis = milliseconds % 1000
    return string.format("%02d:%02d.%03d", minutes, seconds, millis)
end

Leaderboard = class()
---@class Leaderboard
---@field rows table
---@field textColor table
---@field leaderboardAuxArea Area
---@field fontSize number
function Leaderboard:init()
    self.textColor = rgbm(1.0, 1.0, 0.0, 1.0) -- Default neon yellow
    self.rows = {}
    self.leaderboardAuxArea = nil
    self.fontSize = 14
end
function Leaderboard:calculateFontSize()

    self.fontSize = math.max(7, math.min(20, self.leaderboardAuxArea:width() / 20)) -- Just an example calculation
end
function Leaderboard:addRow(...)
    table.insert(self.rows, {...})
end

function Leaderboard:fetch() -- fetches the data from the API
    self.rows = {}
    web.get(LeaderboardUrl, function(err, response)
        if err then
            LogError("Error fetching data: " .. err)
            return
        else
            local parsedData = ConvertToLuaTable(response.body)
            for i, item in ipairs(parsedData) do
                -- Assuming item has 'name', 'date', 'lapTime' fields
                self:addRow(item.avatar_url, item.name, item.date, FormatLapTime(item.lap_time))
            end
        end
    end)
end

function Leaderboard:render(area)
    self.leaderboardAuxArea = Area(area.x1 + area:width() / 9, area.y1 + area:height() / 4, area:width() * 7 / 9,
        area:height() * 0.6) -- Adjust the leaderboard area as needed  
    self:calculateFontSize();
    ---ui.drawRectFilled(vec2(self.leaderboardAuxArea.x1,self.leaderboardAuxArea.y1), vec2(self.leaderboardAuxArea.x2,self.leaderboardAuxArea.y2),rgbm(1,0.5,1,0.5))
    local visibleRows = 3 -- Adjust based on the desired number of rows always visible at once
    local lineHeight = self.leaderboardAuxArea:height() / visibleRows
    local totalRows = #self.rows
    local startY = self.leaderboardAuxArea.y1 - ScrollOffset - lineHeight

    -- Calculate the scrollbar dimensions
    local scrollbarWidth = area:width() / 14 -- Width of the scrollbar, adjust as needed
    local scrollbarMargin = area:width() / 25 -- Space between the scrollbar and the leaderboard
    local scrollbarX1 = self.leaderboardAuxArea.x1 + self.leaderboardAuxArea:width() + scrollbarMargin
    local scrollbarY1 = self.leaderboardAuxArea.y1
    local scrollbarHeight = (visibleRows / totalRows) * self.leaderboardAuxArea:height()
    -- Ensure the scrollbar height does not exceed the leaderboard area's height
    scrollbarHeight = math.min(scrollbarHeight, self.leaderboardAuxArea:height())

    -- Adjust the scrollbar position based on the scroll offset

    local scrollRatio = ScrollOffset / ((totalRows - visibleRows) * lineHeight)
    local maxScrollRatio = (#self.rows - 4) * (self.leaderboardAuxArea:height() / 3) /
                               ((totalRows - visibleRows) * lineHeight)
    local scrollPosition = scrollbarY1 + (scrollRatio * (self.leaderboardAuxArea:height() - scrollbarHeight)) -
                               lineHeight * 1.1 -- Calculate the Y position of the scrollbar
    local scrollbarX2 = scrollbarX1 + scrollbarWidth
    local scrollbarY2 = scrollPosition + scrollbarHeight
    local scrollBackgroundX1 = scrollbarX1
    local scrollBackgroundY1 = self.leaderboardAuxArea.y1 - lineHeight * 1.1
    local scrollBackgroundX2 = scrollbarX2
    local scrollBackgroundY2 = self.leaderboardAuxArea.y1 +
                                   (maxScrollRatio * (self.leaderboardAuxArea:height() - scrollbarHeight)) - lineHeight *
                                   1.1 + scrollbarHeight

    -- Draw header text and background
    local headerNameX = self.leaderboardAuxArea.x1 + (self.leaderboardAuxArea:width()) / 5
    local headerLapTimeX = self.leaderboardAuxArea.x1 + 3 * (self.leaderboardAuxArea:width()) / 4
    local headerPlaceX = self.leaderboardAuxArea.x1 - self.leaderboardAuxArea:width() / 10
    local headerBackgroundX1 = self.leaderboardAuxArea.x1 - self.leaderboardAuxArea:width() / 8
    local headerBackgroundY1 = self.leaderboardAuxArea.y1 - lineHeight * 1.5
    local headerBackgroundX2 = scrollBackgroundX2
    local headerBackgroundY2 = headerBackgroundY1 + lineHeight * 0.434
    local headerTextY1 = self.leaderboardAuxArea.y1 - lineHeight * 1.46
    local LeaderboardBoxX1 = headerBackgroundX1
    local LeaderboardBoxY1 = headerBackgroundY1
    local LeaderboardBoxX2 = scrollBackgroundX2
    local LeaderboardBoxY2 = self.leaderboardAuxArea.y1 + self.leaderboardAuxArea:height()*1.01

    ui.drawRectFilled(vec2(LeaderboardBoxX1, LeaderboardBoxY1), vec2(LeaderboardBoxX2, LeaderboardBoxY2),
        rgbm(0.0, 0.0, 0.0, 0.35))
    ui.drawRectFilled(vec2(headerBackgroundX1, headerBackgroundY1), vec2(headerBackgroundX2, headerBackgroundY2),
        rgbm(0.0, 0.0, 0.0, 0.5))
    ui.dwriteDrawText("Place", self.fontSize, vec2(headerPlaceX, headerTextY1), rgbm(1, 1, 1, 1))
    ui.dwriteDrawText("Username", self.fontSize, vec2(headerNameX, headerTextY1), rgbm(1, 1, 1, 1))
    ui.dwriteDrawText("Lap Time", self.fontSize, vec2(headerLapTimeX, headerTextY1), rgbm(1, 1, 1, 1))
    -- Loop through the leaderboard entries and draw them if they are within the visible self.leaderboardAuxArea
    local switchcolor = false
    for i, user in ipairs(self.rows) do
        -- Calculate the Y position of the current line
        local lineY = startY + (i - 1) * lineHeight

        -- Check if the current line is within the visible self.leaderboardAuxArea
        if lineY + lineHeight * 1.01 > self.leaderboardAuxArea.y1 and lineY + lineHeight * 0.9 <
            self.leaderboardAuxArea.y1 + self.leaderboardAuxArea:height() then
            ui.drawRectFilled(vec2(LeaderboardBoxX1, lineY - lineHeight * 0.05),
                vec2(LeaderboardBoxX2, lineY + lineHeight * 0.95),
                switchcolor and rgbm(0.0, 0.0, 0.0, 0.35) or rgbm(1, 1, 0, 0.2))
            if (switchcolor) then
                self.textColor = rgbm(1, 1, 0, 1)
            else
                self.textColor = rgbm(1, 1, 1, 1)
            end
            if ui.isImageReady(user[1]) then
                ui.drawImageQuad(user[1], vec2(self.leaderboardAuxArea.x1, lineY),
                    vec2(self.leaderboardAuxArea.x1 + lineHeight * 9 / 10, lineY), vec2(
                        self.leaderboardAuxArea.x1 + lineHeight * 9 / 10, lineY + lineHeight * 9 / 10),
                    vec2(self.leaderboardAuxArea.x1, lineY + lineHeight * 9 / 10))
            else
                LogDebugPeriodically("du_wi", 3, "Waiting for avatar image...")
            end

            -- Draw the user's name, date, and lap time within the specified columns
            local nameX = self.leaderboardAuxArea.x1 + (self.leaderboardAuxArea:width()) / 5
            local lapTimeX = self.leaderboardAuxArea.x1 + 3 * (self.leaderboardAuxArea:width()) / 4
            ui.dwriteDrawText(i .. ".", self.fontSize, vec2(self.leaderboardAuxArea.x1 - self.leaderboardAuxArea:width() / 9,lineY + lineHeight * 0.5 - self.fontSize), self.textColor)
            ui.dwriteDrawText(user[2], self.fontSize, vec2(nameX, lineY + lineHeight * 0.5 - self.fontSize),self.textColor)
            ui.dwriteDrawText(user[4], self.fontSize, vec2(lapTimeX, lineY + lineHeight * 0.5 - self.fontSize),self.textColor)
        end
        switchcolor = not switchcolor
    end
    -- Draw the scrollbar
    -- Draw scroll bar
    ui.drawRectFilled(vec2(scrollBackgroundX1, scrollBackgroundY1), vec2(scrollBackgroundX2, scrollBackgroundY2),rgbm(0.0, 0.0, 0.0, 0.5))
    ui.drawRectFilled(vec2(scrollbarX1, scrollPosition), vec2(scrollbarX2, scrollbarY2), rgbm(0.0, 0.0, 0.0, 1.0))
end

