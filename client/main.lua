-- client/main.lua
local QBCore = exports['qb-core']:GetCoreObject()
local isOpen = false
DropProps = {}

local function GetTrunkOffset(veh)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.5, 0.0)
end

local function OpenPlayerInventory()
    if isOpen then
        ToggleInventory(false)
        return
    end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    -- 1. ¿Está sentado en un vehículo? (Abrir Guantera)
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local plate = QBCore.Functions.GetPlate(veh)
        if plate then
            local gbId = "glovebox-" .. plate
            QBCore.Functions.TriggerCallback('qb-inventory:server:GetGloveboxItems', function(gbItems)
                ToggleInventory(true, true, { title = "Guantera - " .. plate, maxWeight = 10.0, id = gbId, items = gbItems, invType = "glovebox" })
            end, gbId)
            return
        end
    end

    -- 2. ¿Está detrás del maletero de un vehículo exterior?
    local veh = GetClosestVehicle(pos.x, pos.y, pos.z, 6.0, 0, 71)
    if veh and veh ~= 0 then
        local lockStatus = GetVehicleDoorLockStatus(veh)
        if lockStatus < 2 then
            local trunkPos = GetTrunkOffset(veh)
            if #(pos - trunkPos) < 2.5 then
                local plate = QBCore.Functions.GetPlate(veh)
                local class = GetVehicleClass(veh)
                local maxW = 60.0
                if class == 0 or class == 1 or class == 3 or class == 4 or class == 5 or class == 6 or class == 7 then maxW = 60.0
                elseif class == 2 or class == 8 then maxW = 80.0
                elseif class == 9 or class == 10 or class == 11 or class == 12 then maxW = 120.0
                end

                local trunkId = "trunk-" .. plate
                QBCore.Functions.TriggerCallback('qb-inventory:server:GetTrunkItems', function(trunkItems)
                    ToggleInventory(true, true, { title = "Maletero - " .. plate, maxWeight = maxW, id = trunkId, items = trunkItems, invType = "trunk" })
                end, trunkId)
                return
            end
        end
    end

    -- 3. ¿Está cerca de una bolsa en el suelo (drop)?
    local closestDrop = nil
    local minDist = 2.0
    for dId, prop in pairs(DropProps) do
        if DoesEntityExist(prop) then
            local dPos = GetEntityCoords(prop)
            local d = #(pos - dPos)
            if d < minDist then
                minDist = d
                closestDrop = dId
            end
        end
    end

    if closestDrop then
        TriggerServerEvent('qb-inventory:server:openDrop', closestDrop)
        return
    end

    -- 4. Apertura personal normal
    ToggleInventory(true)
end

RegisterCommand('openinventory', function() OpenPlayerInventory() end, false)
RegisterKeyMapping('openinventory', 'Abrir Inventario', 'keyboard', 'TAB')

function ToggleInventory(state, isSecondary, secData)
    if state == isOpen and not isSecondary then return end
    isOpen = state
    SetNuiFocus(state, state)

    if state then
        QBCore.Functions.TriggerCallback('qb-inventory:server:getPlayerInventory', function(items, isAdmin, equippedBackpack)
            local rawWeight = type(Config.MaxWeight) == 'table' and (Config.MaxWeight.player or 120000) or Config.MaxWeight
            local playerMaxWeight = (tonumber(rawWeight) or 120000) > 1000 and ((tonumber(rawWeight) or 120000) / 1000.0) or (tonumber(rawWeight) or 120.0)
            SendNUIMessage({ action = 'setItems', payload = items, maxWeight = playerMaxWeight, isAdmin = isAdmin, equippedBackpack = equippedBackpack })

            if isSecondary and secData then
                SendNUIMessage({
                    action = 'openContainer',
                    title = secData.title,
                    maxWeight = secData.maxWeight,
                    containerId = secData.id,
                    items = secData.items,
                    invType = secData.invType,
                    slots = secData.slots,
                    isBackpack = secData.isBackpack
                })
            else
                SendNUIMessage({ action = 'openInventory', maxWeight = playerMaxWeight, equippedBackpack = equippedBackpack })
            end

        end)
    else
        SendNUIMessage({ action = 'closeInventory' })
        TriggerServerEvent('qb-inventory:server:closeInventory')
    end
end

RegisterNUICallback('close', function(data, cb)
    ToggleInventory(false)
    cb({})
end)

CreateThread(function()
    while true do
        Wait(0)
        if isOpen then
            if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 289) then
                ToggleInventory(false)
            end
        else
            Wait(500)
        end
    end
end)

RegisterNUICallback('UseItem', function(data, cb)
    local slotOrItem = data.slot or (data.item and (data.item.slot or data.item.qbslot)) or data.item
    TriggerServerEvent('qb-inventory:server:UseItem', slotOrItem)
    cb({})
end)

RegisterNUICallback('DropItem', function(data, cb)
    TriggerServerEvent('qb-inventory:server:DropItem', data.item, data.amount)
    cb({})
end)

RegisterNUICallback('SetItemSlot', function(data, cb)
    TriggerServerEvent('qb-inventory:server:SetItemSlot', data)
    cb({})
end)

RegisterNUICallback('SetInventoryData', function(data, cb)
    TriggerServerEvent('qb-inventory:server:SetInventoryData', data.fromInventory, data.toInventory, data.fromSlot, data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)

RegisterNUICallback('TakeFromSecondary', function(data, cb)
    TriggerServerEvent('qb-inventory:server:TakeFromSecondary', data)
    cb({})
end)

RegisterNUICallback('takeAllFromDrop', function(data, cb)
    TriggerServerEvent('qb-inventory:server:takeAllFromDrop', data.containerId)
    cb({})
end)

RegisterNUICallback('PutInSecondary', function(data, cb)
    TriggerServerEvent('qb-inventory:server:PutInSecondary', data)
    cb({})
end)

RegisterNUICallback('SetQuickbarSlot', function(data, cb)
    TriggerServerEvent('qb-inventory:server:SetQuickbarSlot', data)
    cb({})
end)

RegisterNUICallback('GiveItem', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId and targetId > 0 then
        TriggerServerEvent('qb-inventory:server:GiveItem', data.item, data.amount, targetId)
    else
        QBCore.Functions.Notify("ID de jugador destino no válido", "error")
    end
    cb({})
end)

RegisterNUICallback('SplitItem', function(data, cb)
    TriggerServerEvent('qb-inventory:server:SplitItem', data.item, data.amount)
    cb({})
end)

RegisterNUICallback('MergeStack', function(data, cb)
    TriggerServerEvent('qb-inventory:server:MergeStack', data.source, data.target)
    cb({})
end)

-- EVENTOS DE APERTURA SECUNDARIA (STASH, TRUNK, GLOVEBOX, SHOP)
RegisterNetEvent('qb-inventory:client:openSecondary', function(title, maxWeight, containerId, type, itemsData, slots, isBackpack)
    -- Si el servidor ya mandó los items, abrimos directamente sin callback adicional
    if itemsData ~= nil then
        ToggleInventory(true, true, { title = title, maxWeight = maxWeight, id = containerId, items = itemsData, invType = type, slots = slots, isBackpack = isBackpack })
        return
    end

    -- Fallback: pedir items por callback (solo si el servidor no los incluyó)
    if type == "stash" then
        QBCore.Functions.TriggerCallback('qb-inventory:server:GetStashItems', function(stashItems)
            ToggleInventory(true, true, { title = title, maxWeight = maxWeight, id = containerId, items = stashItems or {}, invType = "stash" })
        end, containerId)
    elseif type == "trunk" then
        QBCore.Functions.TriggerCallback('qb-inventory:server:GetTrunkItems', function(trunkItems)
            ToggleInventory(true, true, { title = title, maxWeight = maxWeight, id = containerId, items = trunkItems or {}, invType = "trunk" })
        end, containerId)
    elseif type == "glovebox" then
        QBCore.Functions.TriggerCallback('qb-inventory:server:GetGloveboxItems', function(gbItems)
            ToggleInventory(true, true, { title = title, maxWeight = maxWeight, id = containerId, items = gbItems or {}, invType = "glovebox" })
        end, containerId)
    elseif type == "shop" then
        ToggleInventory(true, true, { title = title, maxWeight = 1000.0, id = containerId, items = {}, invType = "shop" })
    else
        ToggleInventory(true, true, { title = title, maxWeight = maxWeight, id = containerId, items = {}, invType = type })
    end
end)

-- EVENTOS Y EXPORTS DE DROPS GESTIONADOS EN client/drops.lua


RegisterNetEvent('qb-inventory:client:openLoot', function(dropId, items)
    if isOpen then
        SendNUIMessage({
            action = 'openContainer',
            containerId = dropId,
            items = items,
            title = "Bolsa en el suelo",
            maxWeight = 50.0,
            invType = "drop"
        })
    else
        ToggleInventory(true, true, { title = "Bolsa en el suelo", maxWeight = 50.0, id = dropId, items = items, invType = "drop" })
    end
end)

RegisterNetEvent('qb-inventory:client:updateSecondaryContainer', function(containerId, items, title, maxWeight, invType, slots)
    SendNUIMessage({
        action = 'openContainer',
        containerId = containerId,
        items = items,
        title = title or "Contenedor",
        maxWeight = maxWeight or 100.0,
        invType = invType or "container",
        slots = slots
    })
end)

-- HUD ITEMBOX (Notificación visual al ganar/perder ítems)
RegisterNetEvent('inventory:client:ItemBox', function(itemData, type)
    SendNUIMessage({ action = 'itemBox', item = itemData, type = type })
end)
RegisterNetEvent('qb-inventory:client:ItemBox', function(itemData, type) TriggerEvent('inventory:client:ItemBox', itemData, type) end)

RegisterNetEvent('qb-inventory:client:refreshUI', function(items, equippedBackpack)
    SendNUIMessage({ action = 'updateInventory', inventory = items, equippedBackpack = equippedBackpack })
end)

exports('HasItem', function(items, amount)
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.items then return false end
    local count = amount or 1

    if type(items) == "table" then
        for _, item in pairs(items) do
            for _, pItem in pairs(PlayerData.items) do
                if pItem and pItem.name and pItem.name:lower() == tostring(item):lower() and pItem.amount >= count then return true end
            end
        end
        return false
    else
        for _, pItem in pairs(PlayerData.items) do
            if pItem and pItem.name and pItem.name:lower() == tostring(items):lower() and pItem.amount >= count then return true end
        end
        return false
    end
end)

exports('GetSlotsByItem', function(itemName)
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.items then return {} end
    local slotsFound = {}
    for slot, item in pairs(PlayerData.items) do
        if item and item.name:lower() == itemName:lower() then
            table.insert(slotsFound, tonumber(slot))
        end
    end
    return slotsFound
end)

exports('GetFirstSlotByItem', function(itemName)
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.items then return nil end
    for slot, item in pairs(PlayerData.items) do
        if item and item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end)

RegisterNetEvent('qb-inventory:client:openAdminMenu', function(players, items)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAdminPanel', players = players, items = items })
end)

RegisterNUICallback('AdminGiveItem', function(data, cb)
    TriggerServerEvent('qb-inventory:server:AdminGiveItem', data.targetId, data.itemName, data.amount)
    cb({})
end)

RegisterNUICallback('BuyItem', function(data, cb)
    TriggerServerEvent('qb-inventory:server:BuyItem', data.shop, data.item.name, data.amount, data.item.slot)
    cb({})
end)

RegisterNUICallback('AdminClearInventory', function(data, cb)
    TriggerServerEvent('qb-inventory:server:AdminClearInventory', data.targetId or 0)
    cb({})
end)

RegisterNUICallback('AdminInspectPlayer', function(data, cb)
    if data.targetId and tonumber(data.targetId) > 0 then
        TriggerServerEvent('qb-inventory:server:AdminOpenPlayerInventory', data.targetId)
    else
        QBCore.Functions.Notify("Selecciona un jugador válido para inspeccionarlo", "error")
    end
    cb({})
end)

RegisterNUICallback('GetAdminData', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:GetAdminData', function(players, items)
        cb({ players = players, items = items })
    end)
end)

RegisterNUICallback('MoveInSecondary', function(data, cb)
    TriggerServerEvent('qb-inventory:server:MoveInSecondary', data)
    cb({})
end)
