local kvpInt = GetCurrentResourceName() .. "_lives_reset_timer"

local livesReset = 0

local function errorPrint(msg, ...)
    if not PFX.ErrorPrints then return end
    local dateTimeString = os.date("%Y-%m-%d %H:%M:%S")
    print(("[%s] %s"):format(dateTimeString, msg:format(...)))
end

local function timeDiffHumanReadable()
    local currentTime = os.time()
    local endTime = livesReset
    local diff = os.difftime(endTime, currentTime)
    diff = math.max(0, diff)

    local days = math.floor(diff / 86400)
    local hours = math.floor((diff % 86400) / 3600)
    local minutes = math.floor((diff % 3600) / 60)

    return Translate("timestring", days, hours, minutes)
end

---@param playerId string
---@return string|nil
local function getPlayerIdentifier(playerId)
    if not playerId then return nil end
    local playerIdentifier = nil

    if PFX.UsingMulticharacter then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then
            errorPrint("xPlayer object for player %s (%s) not found. Try again!", GetPlayerName(playerId), playerId)
            return nil
        end

        playerIdentifier = xPlayer.getIdentifier()
    else
        playerIdentifier = GetPlayerIdentifierByType(playerId, PFX.IdentifierType)
        if not playerIdentifier then
            errorPrint("Identifier %s for player %s not found. Try again!", PFX.IdentifierType, GetPlayerName(playerId))
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
                    errorPrint("^2[Life Reset]^7 ResetAllLives updated ^5%d^7 rows to ^5%i^7", result, PFX.Lives)
                else
                    errorPrint("^3[Life Reset]^7 ResetAllLives matched no rows")
                end
            else
                errorPrint("^1[Life Reset]^7 ResetAllLives failed (nil result)")
            end

            local resetTime = os.time() + (PFX.CheckingDays * 24 * 60 * 60)
            SetResourceKvpInt(kvpInt, resetTime)
            livesReset = resetTime
            errorPrint("^2[Life Reset]^7 Next reset will be in ^5%s^7", timeDiffHumanReadable())
        end

        Citizen.Wait(PFX.CheckingInterval * 60 * 1000)
    end
end)

---@param playerId string
---@return boolean, string|nil
local function validatePlayerLives(playerId)
    local playerIdentifier = getPlayerIdentifier(playerId)
    if not playerIdentifier then
        return false, Translate("player_identifier_not_found")
    end

    local playerLives = GetPlayersLives(playerIdentifier)
    if playerLives and playerLives == 0 then
        return false, Translate("no_lives_remaining", timeDiffHumanReadable())
    elseif playerLives and playerLives > 0 then
        return true, nil
    elseif playerLives and playerLives == -1 then
        local result = ResetPlayersLives(playerIdentifier)
        if result then
            if result > 0 then
                return true, nil
            else
                return false, Translate("reset_lives_error_code1")
            end
        else
            return false, Translate("reset_lives_error_code2")
        end
    elseif playerLives == nil then
        return true, nil
    end

    errorPrint("^1[Life System]^7 ValidatePlayerLives unexpected state for player %s (^5%s^7)", GetPlayerName(playerId), playerIdentifier)
    return false, nil
end

if PFX.UsingMulticharacter then
    AddEventHandler('esx:playerLoaded', function (playerId, xPlayer, isNew)
        local allowed, message = validatePlayerLives(playerId)
        if not allowed then
            DropPlayer(playerId, message or Translate("no_reason_specified"))
            return
        end
    end)
else
    -- https://docs.fivem.net/docs/scripting-reference/events/list/playerConnecting/
    AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
        local playerId = source
        local elapsedTime = 0 -- seconds
        local stopTimer = false

        deferrals.update(Translate("checking_lives"))


        Citizen.CreateThreadNow(function()
            while not stopTimer do
                deferrals.update(Translate("checking_lives_elapsed", elapsedTime))
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
            deferrals.done(message or Translate("no_reason_specified"))
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
        errorPrint("Player %s (%s) IsDead not updated.", GetPlayerName(xPlayer.source), xPlayer.getIdentifier())
    end
end

RegisterNetEvent('esx:onPlayerDeath', function()
    local playerId = source

    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        errorPrint("Player %s has not been found by ESX", playerId)
        return
    end

    local playerIdentifier = getPlayerIdentifier(playerId)
    if not playerIdentifier then return end

    local result = DecrementPlayersLives(playerIdentifier)
    if result == nil then
        errorPrint("^1[Life System]^7 DecrementPlayersLives returned nil for player %s (^5%s^7)", GetPlayerName(playerId), playerIdentifier)
        return
    elseif result == 0 then
        errorPrint("^3[Life System]^7 No rows updated while decrementing lives for player %s (^5%s^7). Likely already at 0.", GetPlayerName(playerId), playerIdentifier)
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
            errorPrint("^3[Life System]^7 Player %s (^5%s^7) disconnected before resurrect confirmation.", GetPlayerName(playerId) or "unknown", playerIdentifier)
            return
        end

        if clientCbResult == nil then
            errorPrint("^3[Life System]^7 Resurrect callback timed out for player %s (^5%s^7).", GetPlayerName(playerId), playerIdentifier)
            return
        end

        if clientCbResult == false then
            errorPrint("^1[Life System]^7 Resurrect callback failed for player %s (^5%s^7).", GetPlayerName(playerId), playerIdentifier)
            return
        end

        DropPlayer(playerId, Translate("used_all_lives"))
        return
    end
end)

RegisterCommand("lives", function(source)
    local playerId = source
    if playerId == 0 then
        errorPrint("Command is only usable ingame!")
        return
    end

    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        errorPrint("Player %s has not been found by ESX", source)
        return
    end

    local playerIdentifier = getPlayerIdentifier(playerId)
    if not playerIdentifier then return end

    local playersLives = GetPlayersLives(playerIdentifier)

    if not playersLives then
        errorPrint("^1[Life System]^7 GetPlayersLives returned nil for player %s (^5%s^7)", GetPlayerName(playerId), playerIdentifier)
        return
    end

    Notify(playerId, Translate("lives_remaining", playersLives, PFX.Lives))
end, false)