local AddonName, Namespace = ...

Namespace.Debug = {}

--@debug@
Namespace.Debug.enabled = true
--@end-debug@

local type, pairs, tostring, print = type, pairs, tostring, print
function Namespace.Debug.toString(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '\''..k..'\'' end
            s = s .. '['..k..'] = ' .. Namespace.Debug.toString(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local printId = 0
function Namespace.Debug.print(...)
    if not Namespace.Debug.enabled then return end

    for _, data in (...) do
        printId = printId + 1
        print(AddonName, printId, Namespace.Debug.toString(data))
    end
end
