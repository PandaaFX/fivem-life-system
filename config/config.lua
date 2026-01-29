---@class Config
PFX = {
    Lives = 7, -- used in SQL and Server checks
    CheckingDays = 9, -- change only applies after the server recaches the expiry date
    CheckingInterval = 1, -- checks the exiry time every X minutes

    -- not in use when `UsingMulticharacter` is enabled
    IdentifierType = "license", -- identifier type you need (e.g. license, steam, xbl, discord)
    RemovePrefix = "license:", -- prefix to remove from identifier or nil (for playerConnecting)
    -- not in use when `UsingMulticharacter` is enabled

    -- actions taken when a player reaches zero lives after dying.
    OnZeroLives = {
        RemoveAllCurrencies = true,
        RemoveAllItems = true,
        RemoveAllWeapons = true,
        ForceRespawnCoords = vector4(298.7658, -584.5848, 43.2608, 70.1004)
    },

    -- if this setting is enabled the script will listen for the `esx:onPlayerLoaded` event instead of relying on the `playerConnecting`
    -- for the identification between different characters
    UsingMulticharacter = false
}

function Notify(playerId, message)
    -- change for your needs
    TriggerClientEvent("ws_notify", playerId, "info", "Information", message, 5000)
end