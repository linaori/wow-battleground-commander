local Private, _, Namespace = {}, ...

Namespace.Debug = {}

local type, pairs, tostring, print, concat, select, date = type, pairs, tostring, print, table.concat, select, date

--@debug@
Namespace.Debug.enabled = true
Namespace.Meta.version = '11.0.5-dev'
Namespace.Meta.date = date('!%Y-%m-%dT%TZ')
_G.BattlegroundCommander = Namespace
--@end-debug@

function Private.ToString(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if k == nil then k = 'nil' end
            if type(k) ~= 'number' then k = '\''..k..'\'' end
            s = s .. '['..k..'] = ' .. Private.ToString(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function Private.TablePack(...)
    return { n = select("#", ...), ... }
end

function Namespace.Debug.Print(...)
    if not Namespace.Debug.enabled then return end
    local args = Private.TablePack(...)
    local t = {}
    for i = 1, args.n do
        if args[i] == nil then
            t[i] = 'nil'
        else
            t[i] = args[i]
        end
    end

    print(Private.ToString(t))
end

function Namespace.Debug.Log(...)
    if not Namespace.Debug.enabled then return end

    print(concat({...}, ' '))
end
