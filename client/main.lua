ESX.RegisterClientCallback("lifesystem:resurrectPlayer", function(cb, coords)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w, 1, false)
    SetPlayerInvincible(ped, false)
    ClearPedBloodDamage(ped)
    FreezeEntityPosition(ped, false)

    TriggerServerEvent('esx:onPlayerSpawn')
    TriggerEvent('esx:onPlayerSpawn')

    cb(true)
end)