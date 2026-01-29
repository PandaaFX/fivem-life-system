Locales = {}

function Translate(key, ...)
    if not key then
        return "No translation key specified!"
    end

    local translations = Locales[PFX.Locale]
    if not translations then
        return ("Locale [%s] does not exist"):format(PFX.Locale)
    end

    if translations[key] then
        return translations[key]:format(...)
    end

    return ("Translation [%s][%s] does not exist"):format(PFX.Locale, key)
end