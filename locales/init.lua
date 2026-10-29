function GetLocaleTable()
    return Locales[Config.Locale] or Locales.de
end

function L(key, ...)
    local locale = GetLocaleTable()
    local text = locale[key] or key
    if select('#', ...) > 0 then
        return text:format(...)
    end
    return text
end

function LT(value)
    if type(value) == 'table' then
        return value[Config.Locale] or value.de
    end
    return value
end

function FormatMoney(amount)
    local digits = tostring(math.floor(amount))
    local grouped = digits:reverse():gsub('(%d%d%d)', '%1.'):reverse()
    grouped = grouped:gsub('^%.', '')
    return Config.Currency .. grouped
end
