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
    local visibleRows = 3 -- Adjust based on the desired number of rows visible at once
    local lineHeight = area:height() / visibleRows
    -- Adjust startY based on scrollOffset
    local startY = area.y1 - ScrollOffset

    -- Loop through the leaderboard entries and draw them if they are within the visible area
    for i, user in ipairs(self.rows) do
        -- Calculate the Y position of the current line
        local lineY = startY + (i - 1) * lineHeight

        -- Check if the current line is within the visible area
        if lineY + lineHeight > area.y1 and lineY < area.y1 + area:height() then
            if ui.isImageReady(user[1]) then
                ui.drawImageQuad(user[1], vec2(area.x1, lineY), vec2(area.x1 + lineHeight * 9/10, lineY), vec2(area.x1 + lineHeight * 9/10, lineY + lineHeight * 9/10), vec2(area.x1, lineY + lineHeight * 9/10))
            else
                LogDebugPeriodically("du_wi", 3, "Waiting for avatar image...")
            end

            -- Draw the user's name, date, and lap time within the specified columns
            local nameX = area.x1 + (area:width()) / 3
            local dateX = area.x1 + 2 * (area:width()) / 4
            local lapTimeX = area.x1 + 3 * (area:width()) / 4

            ui.drawText(user[2], vec2(nameX, lineY), self.textColor)
            ui.drawText(user[3], vec2(dateX, lineY), self.textColor)
            ui.drawText(user[4], vec2(lapTimeX, lineY), self.textColor)
        end
    end
end

