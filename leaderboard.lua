require "class"
require "common"
require "logs"



function ConvertToLuaTable(jsonString) --converts JSON object to lua table
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

function Leaderboard:fetch() --fetches the data from the API
    self.rows = {}
    web.get('https://iconx.world/events/get_lap_times.php?event_id=685&num_to_show=5'
    , function(err, response)
        if err then
            LogError("Error fetching data: " .. err)
            return
        else
            local parsedData = ConvertToLuaTable(response.body)
            for i, item in ipairs(parsedData) do
                -- Assuming item has 'name', 'date', 'lapTime' fields
                self:addRow(item.name, item.date, item.lap_time)
            end
        end
    end)
end

function Leaderboard:render(area)   --rendering function w Area instance of overlay parameter
    local startX = area.x1 
    local startY = area.y1 
    local lineHeight = (area:height())/#self.rows -- The height of each line in the leaderboard

    -- Loop through the leaderboard entries and draw them
    for i, user in ipairs(self.rows) do
        -- Calculate the Y position of the current line
        local lineY = startY + (i - 1) * lineHeight

        -- Draw the user's name
        ui.drawText(user[1], vec2(startX, lineY), self.textColor)

        -- Draw the user's date
        ui.drawText(user[2], vec2(startX + (area:width())/3, lineY), self.textColor)

        -- Draw the user's lap time
        ui.drawText( FormatLapTime(user[3]),vec2(startX + 2*(area:width())/3, lineY),self.textColor)
    end
end
