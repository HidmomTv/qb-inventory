local QBCore = exports['qb-core']:GetCoreObject()
HoldingDrop = false
local bagObject = nil
local heldDrop = nil
CurrentDrop = nil
DropBlips = {}

local function CreateOrUpdateDeathBlip(dropId, coords, dropData)
    if string.sub(dropId, 1, 6) ~= "death-" then return end
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData or not playerData.citizenid then return end

    if dropData and dropData.owner and dropData.owner ~= playerData.citizenid then
        return
    end

    if DropBlips[dropId] and DoesBlipExist(DropBlips[dropId]) then
        SetBlipCoords(DropBlips[dropId], coords.x, coords.y, coords.z)
        return
    end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 586)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Pertenencias (Muerte)")
    EndTextCommandSetBlipName(blip)
    DropBlips[dropId] = blip
end

local function RemoveDeathBlip(dropId)
    if DropBlips[dropId] then
        if DoesBlipExist(DropBlips[dropId]) then
            RemoveBlip(DropBlips[dropId])
        end
        DropBlips[dropId] = nil
    end
end

local function SetupDropTarget(bag, dropId)
    if not DoesEntityExist(bag) then return end
    exports['qb-target']:AddTargetEntity(bag, {
        options = {
            {
                icon = 'fas fa-backpack',
                label = 'Abrir Bolsa',
                action = function()
                    TriggerServerEvent('qb-inventory:server:openDrop', dropId)
                    CurrentDrop = dropId
                end
            },
            {
                icon = 'fas fa-hands',
                label = 'Recoger Todo',
                action = function()
                    TriggerServerEvent('qb-inventory:server:takeAllFromDrop', dropId)
                end
            },
            {
                icon = 'fas fa-hand-pointer',
                label = 'Agarrar Bolsa',
                action = function()
                    TriggerEvent('qb-inventory:client:pickupDrop', dropId)
                end
            }
        },
        distance = 2.0
    })
end

RegisterNetEvent('qb-inventory:client:createLocalDrop', function(dropId, coords, dropData)
    if DropProps[dropId] and DoesEntityExist(DropProps[dropId]) then
        DeleteEntity(DropProps[dropId])
    end
    local model = Config.ItemDropObject or `bkr_prop_duffel_bag_01a`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local bag = CreateObject(model, coords.x, coords.y, coords.z - 1.0, false, false, false)
    PlaceObjectOnGroundProperly(bag)
    FreezeEntityPosition(bag, true)
    DropProps[dropId] = bag

    CreateOrUpdateDeathBlip(dropId, coords, dropData)

    if dropData and dropData.heldBy then
        local holderPed = GetPlayerPed(GetPlayerFromServerId(dropData.heldBy))
        if holderPed ~= 0 and DoesEntityExist(holderPed) then
            AttachEntityToEntity(
                bag,
                holderPed,
                GetPedBoneIndex(holderPed, Config.ItemDropObjectBone or 28422),
                Config.ItemDropObjectOffset[1].x, Config.ItemDropObjectOffset[1].y, Config.ItemDropObjectOffset[1].z,
                Config.ItemDropObjectOffset[2].x, Config.ItemDropObjectOffset[2].y, Config.ItemDropObjectOffset[2].z,
                true, true, false, true, 1, true
            )
        end
    else
        SetupDropTarget(bag, dropId)
    end
end)

RegisterNetEvent('qb-inventory:client:removeDrop', function(dropId)
    RemoveDeathBlip(dropId)
    if DropProps[dropId] then
        if DoesEntityExist(DropProps[dropId]) then
            exports['qb-target']:RemoveTargetEntity(DropProps[dropId])
            DeleteEntity(DropProps[dropId])
        end
        DropProps[dropId] = nil
    end
    if heldDrop == dropId then
        HoldingDrop = false
        heldDrop = nil
        bagObject = nil
        exports['qb-core']:HideText()
    end
    SendNUIMessage({ action = 'closeSecondaryDrop', dropId = dropId })
end)

RegisterNetEvent('qb-inventory:client:pickupDrop', function(dropId)
    if IsPedArmed(PlayerPedId(), 4) then
        return QBCore.Functions.Notify("¡No puedes llevar un arma en la mano mientras agarras una bolsa!", "error", 5000)
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return QBCore.Functions.Notify("¡No puedes agarrar la bolsa estando en un vehículo!", "error", 5000)
    end
    if HoldingDrop then
        return QBCore.Functions.Notify("¡Ya tienes una bolsa en la mano! Suéltala primero con [G].", "error", 5000)
    end
    TriggerServerEvent('qb-inventory:server:pickupDropBag', dropId)
end)

RegisterNetEvent('qb-inventory:client:onPickupDropBag', function(dropId, holderSrc)
    local bag = DropProps[dropId]
    if not bag or not DoesEntityExist(bag) then return end

    exports['qb-target']:RemoveTargetEntity(bag)
    FreezeEntityPosition(bag, false)

    local playerPed = PlayerPedId()
    local myServerId = GetPlayerServerId(PlayerId())

    if holderSrc == myServerId then
        HoldingDrop = true
        heldDrop = dropId
        bagObject = bag
        exports['qb-core']:DrawText('[G] Soltar bolsa en el suelo')

        AttachEntityToEntity(
            bag,
            playerPed,
            GetPedBoneIndex(playerPed, Config.ItemDropObjectBone or 28422),
            Config.ItemDropObjectOffset[1].x, Config.ItemDropObjectOffset[1].y, Config.ItemDropObjectOffset[1].z,
            Config.ItemDropObjectOffset[2].x, Config.ItemDropObjectOffset[2].y, Config.ItemDropObjectOffset[2].z,
            true, true, false, true, 1, true
        )
    else
        local holderPlayer = GetPlayerFromServerId(holderSrc)
        if holderPlayer ~= -1 then
            local holderPed = GetPlayerPed(holderPlayer)
            if holderPed ~= 0 and DoesEntityExist(holderPed) then
                AttachEntityToEntity(
                    bag,
                    holderPed,
                    GetPedBoneIndex(holderPed, Config.ItemDropObjectBone or 28422),
                    Config.ItemDropObjectOffset[1].x, Config.ItemDropObjectOffset[1].y, Config.ItemDropObjectOffset[1].z,
                    Config.ItemDropObjectOffset[2].x, Config.ItemDropObjectOffset[2].y, Config.ItemDropObjectOffset[2].z,
                    true, true, false, true, 1, true
                )
            end
        end
    end
end)

RegisterNetEvent('qb-inventory:client:onDropHeldBag', function(dropId, newCoords)
    if heldDrop == dropId then
        HoldingDrop = false
        heldDrop = nil
        bagObject = nil
        exports['qb-core']:HideText()
    end

    local bag = DropProps[dropId]
    if bag and DoesEntityExist(bag) then
        DetachEntity(bag, true, true)
        SetEntityCoords(bag, newCoords.x, newCoords.y, newCoords.z, false, false, false, false)
        PlaceObjectOnGroundProperly(bag)
        FreezeEntityPosition(bag, true)
        SetupDropTarget(bag, dropId)
        CreateOrUpdateDeathBlip(dropId, newCoords, nil)
    end
end)

function GetDrops()
    QBCore.Functions.TriggerCallback('qb-inventory:server:GetCurrentDrops', function(drops)
        if not drops then return end
        for dropId, dropData in pairs(drops) do
            if not DropProps[dropId] or not DoesEntityExist(DropProps[dropId]) then
                TriggerEvent('qb-inventory:client:createLocalDrop', dropId, dropData.coords, dropData)
            else
                CreateOrUpdateDeathBlip(dropId, dropData.coords, dropData)
            end
        end
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    GetDrops()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        GetDrops()
    end
end)

CreateThread(function()
    while true do
        if HoldingDrop and heldDrop and bagObject then
            local ped = PlayerPedId()
            if IsControlJustPressed(0, 47) then -- [G]
                local coords = GetEntityCoords(ped)
                local forward = GetEntityForwardVector(ped)
                local newPos = vector3(coords.x + forward.x * 0.6, coords.y + forward.y * 0.6, coords.z - 0.9)
                TriggerServerEvent('qb-inventory:server:dropHeldBag', heldDrop, newPos)
            elseif IsPedArmed(ped, 4) then
                QBCore.Functions.Notify("¡Has soltado la bolsa al sacar un arma!", "error", 4000)
                local coords = GetEntityCoords(ped)
                TriggerServerEvent('qb-inventory:server:dropHeldBag', heldDrop, vector3(coords.x, coords.y, coords.z - 0.9))
            elseif IsPedInAnyVehicle(ped, false) then
                QBCore.Functions.Notify("¡Has soltado la bolsa al subir a un vehículo!", "error", 4000)
                local coords = GetEntityCoords(ped)
                TriggerServerEvent('qb-inventory:server:dropHeldBag', heldDrop, vector3(coords.x, coords.y, coords.z - 0.9))
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
