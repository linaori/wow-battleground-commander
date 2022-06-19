local _, Namespace = ...

Namespace.Utils = {}

local floor = math.floor
local ceil = math.ceil
local format = string.format

function Namespace.Utils.TimeDiff(a, b)
    local secondsDiff = a - b
    local fullSeconds = secondsDiff

    local rounder = secondsDiff > 0 and floor or ceil
    local minutesDiff = rounder(secondsDiff / 60)
    local hoursDiff = rounder(minutesDiff / 60)

    local fullHours, fullMinutes = hoursDiff, minutesDiff
    minutesDiff = minutesDiff - hoursDiff * 60
    secondsDiff = secondsDiff - (minutesDiff * 60 + hoursDiff * 60 * 60)

    return {
        fullSeconds = fullSeconds,
        fullMinutes = fullMinutes,
        fullHours = fullHours,
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
