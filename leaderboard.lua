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
function Leaderboard:init(textColor)
    self.textColor = textColor or rgbm(1.0, 1.0, 0.0, 1.0) -- Default neon yellow
    self.rows = {}

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
    local leaderboardArea = Area(area.x1 + area:width()/8 , area.y1 + area:height()/5,area:width() * 3/4, area:height() * 1.8/3)
    local visibleRows = 3-- Adjust based on the desired number of rows visible at once
    local lineHeight = leaderboardArea:height() / visibleRows 
    local totalRows = #self.rows
    local startY = leaderboardArea.y1 - ScrollOffset

    -- Calculate the scrollbar dimensions
    local scrollbarWidth = area:width()/14 -- Width of the scrollbar, adjust as needed
    local scrollbarMargin = area:width()/25 -- Space between the scrollbar and the leaderboard
    local scrollbarX1 = leaderboardArea.x1 + leaderboardArea:width() + scrollbarMargin
    local scrollbarY1 = leaderboardArea.y1
    local scrollbarHeight = (visibleRows / totalRows) * leaderboardArea:height()
    -- Ensure the scrollbar height does not exceed the leaderboard area's height
    scrollbarHeight = math.min(scrollbarHeight, leaderboardArea:height())

    -- Adjust the scrollbar position based on the scroll offset
    local scrollRatio = ScrollOffset / ((totalRows - visibleRows) * lineHeight)
    local scrollPosition = scrollbarY1 + (scrollRatio * (leaderboardArea:height() - scrollbarHeight)) - leaderboardArea:height()/3 -- Calculate the Y position of the scrollbar
    local scrollbarX2 = scrollbarX1 + scrollbarWidth
    local scrollbarY2 = scrollPosition + scrollbarHeight
    local scrollBackgroundX1 = scrollbarX1
    local scrollBackgroundY1 = leaderboardArea.y1 - lineHeight
    local scrollBackgroundX2 = scrollbarX2
    local scrollBackgroundY2 = leaderboardArea.y1 + leaderboardArea:height()*19/20- leaderboardArea:height()/3
    -- Draw scroll bar
    ui.drawRectFilled(vec2(scrollBackgroundX1,scrollBackgroundY1), vec2(scrollBackgroundX2,scrollBackgroundY2),rgbm(0.0, 0.0, 0.0, 0.5))
    ui.drawRectFilled(vec2(scrollbarX1,scrollPosition), vec2(scrollbarX2,scrollbarY2),rgbm(0.0, 0.0, 0.0, 1.0))
    -- Draw header text and background
    local headerY = leaderboardArea.y1 - lineHeight*1.3
    local headerNameX = leaderboardArea.x1 + (leaderboardArea:width()) / 5
    local headerLapTimeX = leaderboardArea.x1 + 3 * (leaderboardArea:width()) / 4
    local headerPlaceX = leaderboardArea.x1 - leaderboardArea:width()/9
    local headerBackgroundX1 = leaderboardArea.x1 - leaderboardArea:width()/8
    local headerBackgroundY1 = headerY
    local headerBackgroundX2 = scrollBackgroundX2
    local headerBackgroundY2 = headerY + lineHeight/3
    local LeaderboardBoxX1 = headerBackgroundX1
    local LeaderboardBoxY1 = headerBackgroundY1
    local LeaderboardBoxX2 = scrollBackgroundX2
    local LeaderboardBoxY2 = leaderboardArea.y1 + leaderboardArea:height()*1.3

    ui.drawRectFilled(vec2(LeaderboardBoxX1, LeaderboardBoxY1), vec2(LeaderboardBoxX2,LeaderboardBoxY2), rgbm(0.0, 0.0, 0.0, 0.35))
    ui.drawRectFilled(vec2(headerBackgroundX1, headerBackgroundY1), vec2(headerBackgroundX2,headerBackgroundY2), rgbm(0.0, 0.0, 0.0, 0.5))
    ui.drawText("Place", vec2(headerPlaceX, headerY), self.textColor)
    ui.drawText("Username", vec2(headerNameX,headerY), self.textColor)
    ui.drawText("Lap Time", vec2(headerLapTimeX,headerY), self.textColor)
    -- Loop through the leaderboard entries and draw them if they are within the visible leaderboardArea
    for i, user in ipairs(self.rows) do
        -- Calculate the Y position of the current line
        local lineY = startY + (i - 1) * lineHeight

        -- Check if the current line is within the visible leaderboardArea
        if lineY + lineHeight > leaderboardArea.y1 and lineY < leaderboardArea.y1 + leaderboardArea:height() then
            if ui.isImageReady(user[1]) then
                ui.drawImageQuad(user[1], vec2(leaderboardArea.x1, lineY), vec2(leaderboardArea.x1 + lineHeight * 9/10, lineY), vec2(leaderboardArea.x1 + lineHeight * 9/10, lineY + lineHeight * 9/10), vec2(leaderboardArea.x1, lineY + lineHeight * 9/10))
            else
                LogDebugPeriodically("du_wi", 3, "Waiting for avatar image...")
            end

            -- Draw the user's name, date, and lap time within the specified columns
            local nameX = leaderboardArea.x1 + (leaderboardArea:width()) / 5
            local lapTimeX = leaderboardArea.x1 + 3 * (leaderboardArea:width()) / 4
            ui.drawText(i ..".", vec2(leaderboardArea.x1 - leaderboardArea:width()/9, lineY), self.textColor)
            ui.drawText(user[2], vec2(nameX, lineY), self.textColor)
            ui.drawText(user[4], vec2(lapTimeX, lineY), self.textColor)
        end
    end
end

