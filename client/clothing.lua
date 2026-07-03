local QBCore = exports['qb-core']:GetCoreObject()

local function ApplyBackpackModel(itemData, notify)
    if not itemData then return end
    local ped = PlayerPedId()
    local cfg = Config.Backpacks and Config.Backpacks[itemData.name]
    if not cfg then return end

    local gender = "male"
    if GetEntityModel(ped) == `mp_f_freemode_01` then gender = "female" end
    local cloth = cfg.clothing and cfg.clothing[gender] or { drawable = 40, texture = 0 }

    SetPedComponentVariation(ped, 5, cloth.drawable, cloth.texture, 0)
    if notify then
        QBCore.Functions.Notify("Mochila equipada: " .. cfg.label, "success")
    end
end

RegisterNetEvent('qb-inventory:client:onEquipBackpack', function(itemData)
    ApplyBackpackModel(itemData, true)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.metadata and PlayerData.metadata['equipped_backpack'] then
        ApplyBackpackModel(PlayerData.metadata['equipped_backpack'], false)
    end
end)


RegisterNetEvent('qb-inventory:client:onUnequipBackpack', function()
    local ped = PlayerPedId()
    SetPedComponentVariation(ped, 5, 0, 0, 0)
    QBCore.Functions.Notify("Te has quitado la mochila", "primary")
end)

RegisterNUICallback('equipBackpack', function(data, cb)
    if data and data.slot then
        TriggerServerEvent('qb-inventory:server:equipBackpack', data.slot)
    end
    cb({})
end)

RegisterNUICallback('unequipBackpack', function(data, cb)
    TriggerServerEvent('qb-inventory:server:unequipBackpack')
    cb({})
end)

RegisterNUICallback('openEquippedBackpack', function(data, cb)
    TriggerServerEvent('qb-inventory:server:openEquippedBackpack')
    cb({})
end)

RegisterNUICallback('toggleClothing', function(data, cb)
    local type = data.type or data.slot
    if not type then cb({}) return end

    local capMap = {
        ['mask'] = 'Mask', ['neck'] = 'Neck', ['top'] = 'Top', ['shirt'] = 'Shirt',
        ['gloves'] = 'Gloves', ['pants'] = 'Pants', ['shoes'] = 'Shoes', ['vest'] = 'Vest',
        ['bag'] = 'Bag', ['hat'] = 'Hat', ['glasses'] = 'Glasses', ['visor'] = 'Visor',
        ['watch'] = 'Watch', ['bracelet'] = 'Bracelet'
    }

    local capName = capMap[type] or type
    local lowName = string.lower(type)

    TriggerEvent('qb-radialmenu:ToggleClothing', capName)
    TriggerEvent('qb-radialmenu:ToggleProps', capName)
    TriggerEvent('qb-radialmenu:client:ToggleClothing', capName)
    TriggerEvent('qb-radialmenu:client:ToggleProps', capName)
    TriggerEvent('illenium-appearance:client:toggleClothing', capName)
    TriggerEvent('illenium-appearance:client:toggleProps', capName)
    TriggerEvent('qb-clothing:client:toggleClothing', capName)

    ExecuteCommand(lowName)

    cb({})
end)
