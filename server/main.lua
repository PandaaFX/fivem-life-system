local kvpInt = GetCurrentResourceName() .. "_life_reset_timer"

local lifeReset = 0

local function timeDiffHumanReadable()
    local currentTime = os.time()
    local endTime = lifeReset
    local diff = os.difftime(endTime, currentTime)
    diff = math.max(0, diff)

    local days = math.floor(diff / 86400)
    local hours = math.floor((diff % 86400) / 3600)
    local minutes = math.floor((diff % 3600) / 60)

    return ("%02d days %02d hours %02d minutes"):format(days, hours, minutes)
end

---@param playerId string
---@return string|nil
local function getPlayerIdentifier(playerId)
    local playerIdentifier = GetPlayerIdentifierByType(playerId, PFX.IdentifierType)
    if not playerIdentifier then
        print(("Identifier %s for player %s not found. Try again!"):format(PFX.IdentifierType, GetPlayerName(playerId)))
        return nil
    end

    if PFX.RemovePrefix then
        playerIdentifier = string.gsub(playerIdentifier, PFX.RemovePrefix, "")
    end

    return playerIdentifier
end

Citizen.CreateThread(function()
    lifeReset = GetResourceKvpInt(kvpInt)

    if lifeReset == 0 then
        local resetTime = os.time() + (PFX.CheckingDays * 24 * 60 * 60)
        SetResourceKvpInt(kvpInt, resetTime)
        lifeReset = resetTime
    end

    while true do
        local currentTime = os.time()
        if currentTime >= lifeReset then
            local result = ResetAllLifes()
            if type(result) == "number" then
                if result > 0 then
                    print(("^2[Life Reset]^7 ResetAllLifes updated ^5%d^7 rows to ^5%i^7"):format(result, PFX.Lifes))
                else
                    print("^3[Life Reset]^7 ResetAllLifes matched no rows")
                end
            else
                print("^1[Life Reset]^7 ResetAllLifes failed (nil result)")
            end

            local resetTime = os.time() + (PFX.CheckingDays * 24 * 60 * 60)
            SetResourceKvpInt(kvpInt, resetTime)
            lifeReset = resetTime
            print(("^2[Life Reset]^7 Next reset will be in ^5%s^7"):format(timeDiffHumanReadable()))
        end

        Citizen.Wait(PFX.CheckingInterval * 60 * 1000)
    end
end)

-- https://docs.fivem.net/docs/scripting-reference/events/list/playerConnecting/
AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    local playerId = source

    local playerIdentifier = getPlayerIdentifier(playerId)
    if not playerIdentifier then
        deferrals.done(("Identifier %s not found. Try again!"):format(PFX.IdentifierType))
        return
    end

    deferrals.update("Checking your players lifes...")

    local playerLifes = GetPlayersLifes(playerIdentifier)
    if playerLifes and playerLifes == 0 then
        deferrals.done(("You do not have any remaining lifes! Reset in: %s"):format(timeDiffHumanReadable()))
        return
    elseif playerLifes and playerLifes > 0 then
        deferrals.done()
        return
    elseif playerLifes and playerLifes == -1 then
        local result = ResetPlayersLife(playerIdentifier)
        if result then
            if result > 0 then
                deferrals.done()
                return
            else
                deferrals.done("Something went wrong when resetting your lifes. Contact server support. CODE 1")
                return
            end
        else
            deferrals.done("Something went wrong when resetting your lifes. Contact server support. CODE 2")
            return
        end
    elseif playerLifes == nil then
        deferrals.done()
        return
    end
end)

local function removeCurrencies(xPlayer)
    if not xPlayer then return end

    if PFX.OnZeroLifes.RemoveAllCurrencies then
		if xPlayer.getMoney() > 0 then
			xPlayer.removeMoney(xPlayer.getMoney(), "Death")
		end

		if xPlayer.getAccount('black_money').money > 0 then
			xPlayer.setAccountMoney('black_money', 0, "Death")
		end
	end
end

local function removeItems(xPlayer)
    if not xPlayer then return end

    if PFX.OnZeroLifes.RemoveAllItems then
		for i=1, #xPlayer.inventory, 1 do
			if xPlayer.inventory[i].count > 0 then
				xPlayer.setInventoryItem(xPlayer.inventory[i].name, 0)
			end
		end
	end
end

local function removeWeapons(xPlayer)
    if not xPlayer then return end

	if PFX.OnZeroLifes.RemoveAllWeapons then
		for i=1, #xPlayer.loadout, 1 do
			xPlayer.removeWeapon(xPlayer.loadout[i].name)
		end
	end
end

local function actionsBeforeKick(xPlayer)
    removeCurrencies(xPlayer)
    removeItems(xPlayer)
    removeWeapons(xPlayer)

    local playerIdentifier = getPlayerIdentifier(xPlayer.source)
    if not playerIdentifier then return end

    local affectedRows = SetPlayerIsDead(playerIdentifier, false)
    if affectedRows and affectedRows > 0 then
        xPlayer.setMeta("health", 200)
    else
        print(("Player %s (%s) IsDead not updated."):format(GetPlayerName(xPlayer.source), xPlayer.getIdentifier()))
    end
end

RegisterNetEvent('esx:onPlayerDeath', function()
    local playerId = source

    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        print(("Player %s has not been found by ESX"):format(playerId))
        return
    end

    local playerIdentifier = getPlayerIdentifier(playerId)
    if not playerIdentifier then return end

    local result = DecrementPlayersLife(playerIdentifier)
    if result == nil then
        print(("^1[Life System]^7 DecrementPlayersLife returned nil for player %s (^5%s^7)"):format(GetPlayerName(playerId), playerIdentifier))
        return
    elseif result == 0 then
        print(("^3[Life System]^7 No rows updated while decrementing lifes for player %s (^5%s^7). Likely already at 0."):format(GetPlayerName(playerId), playerIdentifier))
        return
    elseif result > 0 then
        local playersLifes = GetPlayersLifes(playerIdentifier)
        if playersLifes > 0 then return end

        actionsBeforeKick(xPlayer)

        local clientCbResult = nil
        local timeout = 0

        ESX.TriggerClientCallback(xPlayer.source, "lifesystem:resurrectPlayer", function(success)
            clientCbResult = success
        end, PFX.OnZeroLifes.ForceRespawnCoords)

        repeat
            Citizen.Wait(500) -- 500 ms
            timeout = timeout + 1
        until clientCbResult ~= nil or timeout >= 10 -- 5 seocnds

        if not DoesPlayerExist(playerId) then
            print(("^3[Life System]^7 Player %s (^5%s^7) disconnected before resurrect confirmation."):format(GetPlayerName(playerId) or "unknown", playerIdentifier))
            return
        end

        if clientCbResult == nil then
            print(("^3[Life System]^7 Resurrect callback timed out for player %s (^5%s^7)."):format(GetPlayerName(playerId), playerIdentifier))
            return
        end

        if clientCbResult == false then
            print(("^1[Life System]^7 Resurrect callback failed for player %s (^5%s^7)."):format(GetPlayerName(playerId), playerIdentifier))
            return
        end

        DropPlayer(playerId, "Used all remaining lifes")
        return
    end
end)

RegisterCommand("lifes", function(source)
    local playerId = source
    if playerId == 0 then
        print("Command is only usable ingame!")
        return
    end

    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        print(("Player %s has not been found by ESX"):format(source))
        return
    end

    local playerIdentifier = getPlayerIdentifier(playerId)
    if not playerIdentifier then return end

    local playersLifes = GetPlayersLifes(playerIdentifier)

    Notify(playerId, ("You have %i/%i lifes remaining"):format(playersLifes, PFX.Lifes))
end, false)