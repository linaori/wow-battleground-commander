local Private, _, Namespace = {}, ...

Namespace.Debug = {}
--@debug@
Namespace.Debug.enabled = true
Namespace.Meta.version = '1.6.1-dev'
--@end-debug@

local type, pairs, tostring, print, concat, select = type, pairs, tostring, print, table.concat, select
function Private.toString(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if k == nil then k = 'nil' end
            if type(k) ~= 'number' then k = '\''..k..'\'' end
            s = s .. '['..k..'] = ' .. Private.toString(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function Private.table_pack(...)
    return { n = select("#", ...), ... }
end

function Namespace.Debug.print(...)
    if not Namespace.Debug.enabled then return end
    local args = Private.table_pack(...)
    local t = {}
    for i = 1, args.n do
        if args[i] == nil then
            t[i] = 'nil'
        else
            t[i] = args[i]
        end
    end

    print(Private.toString(t))
end

function Namespace.Debug.log(...)
    if not Namespace.Debug.enabled then return end

    print(concat({...}, ' '))
end
