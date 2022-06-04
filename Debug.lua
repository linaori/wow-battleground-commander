local _, Namespace = ...

Namespace.Debug = {}

--@debug@
Namespace.Debug.enabled = true
--@end-debug@

local type, pairs, tostring, print, concat = type, pairs, tostring, print, table.concat
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

function Namespace.Debug.print(...)
    if not Namespace.Debug.enabled then return end

    print(Namespace.Debug.toString({...}))
end

function Namespace.Debug.log(...)
    if not Namespace.Debug.enabled then return end

    print(concat({...}, ' '))
end
