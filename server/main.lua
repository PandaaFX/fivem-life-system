local kvpInt = GetCurrentResourceName() .. "_lives_reset_timer"

local livesReset = 0

local function timeDiffHumanReadable()
    local currentTime = os.time()
    local endTime = livesReset
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
    if not playerId then return nil end
    local playerIdentifier = nil

    if PFX.UsingMulticharacter then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then
            print(("xPlayer object for player %s (%s) not found. Try again!"):format(GetPlayerName(playerId), playerId))
            return nil
        end

        playerIdentifier = xPlayer.getIdentifier()
    else
        playerIdentifier = GetPlayerIdentifierByType(playerId, PFX.IdentifierType)
        if not playerIdentifier then
            print(("Identifier %s for player %s not found. Try again!"):format(PFX.IdentifierType, GetPlayerName(playerId)))
            return nil
        end

        if PFX.RemovePrefix then
            playerIdentifier = string.gsub(playerIdentifier, PFX.RemovePrefix, "")
        end
    end

    return playerIdentifier
end

Citizen.CreateThread(function()
    livesReset = GetResourceKvpInt(kvpInt)

    if livesReset == 0 then
        local resetTime = os.time() + (PFX.CheckingDays * 24 * 60 * 60)
        SetResourceKvpInt(kvpInt, resetTime)
        livesReset = resetTime
    end

    while true do
        local currentTime = os.time()
        if currentTime >= livesReset then
            local result = ResetAllLives()
            if type(result) == "number" then
                if result > 0 then
                    print(("^2[Life Reset]^7 ResetAllLives updated ^5%d^7 rows to ^5%i^7"):format(result, PFX.Lives))
                else
                    print("^3[Life Reset]^7 ResetAllLives matched no rows")
                end
            else
                print("^1[Life Reset]^7 ResetAllLives failed (nil result)")
            end

            local resetTime = os.time() + (PFX.CheckingDays * 24 * 60 * 60)
            SetResourceKvpInt(kvpInt, resetTime)
            livesReset = resetTime
            print(("^2[Life Reset]^7 Next reset will be in ^5%s^7"):format(timeDiffHumanReadable()))
        end

        Citizen.Wait(PFX.CheckingInterval * 60 * 1000)
    end
end)

---@param playerId string
---@return boolean, string|nil
local function validatePlayerLives(playerId)
    local playerIdentifier = getPlayerIdentifier(playerId)
    if not playerIdentifier then
        return false, "Player identifier not found. Try again!"
    end

    local playerLives = GetPlayersLives(playerIdentifier)
    if playerLives and playerLives == 0 then
        return false, ("You do not have any remaining lives! Reset in: %s"):format(timeDiffHumanReadable())
    elseif playerLives and playerLives > 0 then
        return true, nil
    elseif playerLives and playerLives == -1 then
        local result = ResetPlayersLives(playerIdentifier)
        if result then
            if result > 0 then
                return true, nil
            else
                return false, "Something went wrong when resetting your lives. Contact server support. CODE 1"
            end
        else
            return false, "Something went wrong when resetting your lives. Contact server support. CODE 2"
        end
    elseif playerLives == nil then
        return true, nil
    end

    print(("^1[Life System]^7 ValidatePlayerLives unexpected state for player %s (^5%s^7)"):format(GetPlayerName(playerId), playerIdentifier))
    return false, nil
end

if PFX.UsingMulticharacter then
    AddEventHandler('esx:playerLoaded', function (playerId, xPlayer, isNew)
        local allowed, message = validatePlayerLives(playerId)
        if not allowed then
            DropPlayer(playerId, message or "No reason specified")
            return
        end
    end)
else
    -- https://docs.fivem.net/docs/scripting-reference/events/list/playerConnecting/
    AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
        local playerId = source
        local elapsedTime = 0 -- seconds
        local stopTimer = false

        deferrals.update("Checking your player's lives...")


        Citizen.CreateThreadNow(function()
            while not stopTimer do
                deferrals.update(("Checking your player's lives... %i seconds elapsed"):format(elapsedTime))
                elapsedTime = elapsedTime + 1
                Citizen.Wait(1000)
            end
        end)

        local allowed, message = validatePlayerLives(playerId)
        stopTimer = true

        Citizen.Wait(0)
        if allowed then
            deferrals.done()
        else
            deferrals.done(message or "No reason specified")
        end
    end)
end

local function removeCurrencies(xPlayer)
    if not xPlayer then return end

    if PFX.OnZeroLives.RemoveAllCurrencies then
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

    if PFX.OnZeroLives.RemoveAllItems then
		for i=1, #xPlayer.inventory, 1 do
			if xPlayer.inventory[i].count > 0 then
				xPlayer.setInventoryItem(xPlayer.inventory[i].name, 0)
			end
		end
	end
end

local function removeWeapons(xPlayer)
    if not xPlayer then return end

	if PFX.OnZeroLives.RemoveAllWeapons then
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
    if affectedRows and affectedRows > 0 and xPlayer.setMeta then
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

    local result = DecrementPlayersLives(playerIdentifier)
    if result == nil then
        print(("^1[Life System]^7 DecrementPlayersLives returned nil for player %s (^5%s^7)"):format(GetPlayerName(playerId), playerIdentifier))
        return
    elseif result == 0 then
        print(("^3[Life System]^7 No rows updated while decrementing lives for player %s (^5%s^7). Likely already at 0."):format(GetPlayerName(playerId), playerIdentifier))
        return
    elseif result > 0 then
        local playersLives = GetPlayersLives(playerIdentifier)
        if playersLives > 0 then return end

        actionsBeforeKick(xPlayer)

        local clientCbResult = nil
        local timeout = 0

        ESX.TriggerClientCallback(xPlayer.source, "lifesystem:resurrectPlayer", function(success)
            clientCbResult = success
        end, PFX.OnZeroLives.ForceRespawnCoords)

        repeat
            Citizen.Wait(500) -- 500 ms
            timeout = timeout + 1
        until clientCbResult ~= nil or timeout >= 10 -- 5 seconds

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

        DropPlayer(playerId, "Used all remaining lives")
        return
    end
end)

RegisterCommand("lives", function(source)
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

    local playersLives = GetPlayersLives(playerIdentifier)

    if not playersLives then
        print(("^1[Life System]^7 GetPlayersLives returned nil for player %s (^5%s^7)"):format(GetPlayerName(playerId), playerIdentifier))
        return
    end

    Notify(playerId, ("You have %i/%i lives remaining"):format(playersLives, PFX.Lives))
end, false)