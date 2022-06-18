local _, Namespace = ...

Namespace.Utils = {}

local floor = math.floor
local format = string.format

function Namespace.Utils.TimeDiff(high, low)
    local secondsDiff = floor(high) - floor(low)
    local fullSeconds = secondsDiff
    local minutesDiff = floor(secondsDiff / 60)
    local hoursDiff = floor(minutesDiff / 60)

    secondsDiff = secondsDiff - (minutesDiff * 60 + hoursDiff * 60 * 60)

    return {
        fullSeconds = fullSeconds,
        seconds = secondsDiff,
        minutes = minutesDiff,
        hours = hoursDiff,
        format = function()
            if hoursDiff > 0 then
                return format('%dh %dm %ds', hoursDiff, minutesDiff, secondsDiff)
            end

            if minutesDiff > 0 then
                return format('%dm %ds', minutesDiff, secondsDiff)
            end

            return format('%ds', secondsDiff)
        end,
    }
end
