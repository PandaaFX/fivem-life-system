---@param identifier string
---@return number|nil
function GetPlayersLifes(identifier)
    local playerLifes = MySQL.scalar.await('SELECT COALESCE(lifes, -1) FROM `users` WHERE `identifier` = ? LIMIT 1', {
        identifier
    })

    return playerLifes and tonumber(playerLifes) or nil
end

---@param identifier string
---@return integer|nil
function ResetPlayersLife(identifier)
    local affectedRows = MySQL.update.await('UPDATE `users` SET `lifes` = ? WHERE `identifier` = ?', {
        PFX.Lifes,
        identifier
    })

    return affectedRows
end

--- Sets the `lifes` column of every player that has either less than 'PFX.Lifes' or their `lifes` is NULL to 'PFX.Lifes'
---@return integer|nil
function ResetAllLifes()
    local affectedRows = MySQL.update.await('UPDATE `users` SET `lifes` = ? WHERE `lifes` < ? OR `lifes` IS NULL', {
        PFX.Lifes,
        PFX.Lifes
    })

    return affectedRows
end

---@param identifier string
---@return integer|nil
function DecrementPlayersLife(identifier)
    local affectedRows = MySQL.update.await('UPDATE `users` SET `lifes` = GREATEST(`lifes` - 1, 0) WHERE `identifier` = ? AND `lifes` > 0', {
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
            WHERE `identifier` = ? AND `lifes` = 0
    ]], {
        dead,
        identifier
    })

    return affectedRows
end