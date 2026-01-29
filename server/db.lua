---@param identifier string
---@return number|nil
function GetPlayersLives(identifier)
    local playerLives = MySQL.scalar.await('SELECT COALESCE(lives, -1) FROM `users` WHERE `identifier` = ? LIMIT 1', {
        identifier
    })

    return playerLives and tonumber(playerLives) or nil
end

---@param identifier string
---@return integer|nil
function ResetPlayersLives(identifier)
    local affectedRows = MySQL.update.await('UPDATE `users` SET `lives` = ? WHERE `identifier` = ?', {
        PFX.Lives,
        identifier
    })

    return affectedRows
end

--- Sets the `lives` column of every player that has either less than 'PFX.Lives' or their `lives` is NULL to 'PFX.Lives'
---@return integer|nil
function ResetAllLives()
    local affectedRows = MySQL.update.await('UPDATE `users` SET `lives` = ? WHERE `lives` < ? OR `lives` IS NULL', {
        PFX.Lives,
        PFX.Lives
    })

    return affectedRows
end

---@param identifier string
---@return integer|nil
function DecrementPlayersLives(identifier)
    local affectedRows = MySQL.update.await('UPDATE `users` SET `lives` = `lives` - 1 WHERE `identifier` = ? AND `lives` > 0', {
        identifier
    })

    return affectedRows
end

---@param identifier string
---@param isDead boolean
---@return integer|nil
function SetPlayerIsDead(identifier, isDead)
    local dead = isDead and 1 or 0
    local affectedRows = MySQL.update.await([[
        UPDATE `users`
            SET `is_dead` = ?
            WHERE `identifier` = ? AND `lives` = 0
    ]], {
        dead,
        identifier
    })

    return affectedRows
end