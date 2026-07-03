-- server/main.lua
local QBCore = exports['qb-core']:GetCoreObject()
local Drops = {}
local Trunks = {}
local Gloveboxes = {}
local Stashes = {}
local Shops = {}
local OpenedContainers = {}
local SearchedProps = {}
local SyncPlayerUI

local function CopyTable(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = CopyTable(orig_value)
        end
    else
        copy = orig
    end
    return copy
end

local function CompareHashes(h1, h2)
    if not h1 or not h2 then return false end
    if h1 == h2 or tostring(h1) == tostring(h2) then return true end
    local n1 = tonumber(h1)
    local n2 = tonumber(h2)
    if not n1 and type(h1) == 'string' then n1 = GetHashKey(h1) end
    if not n2 and type(h2) == 'string' then n2 = GetHashKey(h2) end
    if n1 and n2 then
        if n1 == n2 then return true end
        if (n1 & 0xFFFFFFFF) == (n2 & 0xFFFFFFFF) then return true end
    end
    return false
end

local function ResolveAttachmentLabel(att)
    if not att then return att end
    if type(att) == 'table' and att.label and att.label ~= 'Accesorio Táctico' and att.label ~= 'Componente Táctico' then
        return att
    end
    local attComp = type(att) == 'table' and (att.component or att.id or att.hash) or att
    local itemName = type(att) == 'table' and (att.item or att.attachment) or nil

    if not itemName and attComp then
        local ok, allAtts = pcall(function()
            return exports['qb-weapons']:getConfigWeaponAttachments()
        end)
        if ok and allAtts then
            for category, weaponsMap in pairs(allAtts) do
                if type(weaponsMap) == 'table' then
                    for wName, hashVal in pairs(weaponsMap) do
                        if CompareHashes(hashVal, attComp) then
                            if QBCore.Shared.Items[category] then
                                itemName = category
                            elseif QBCore.Shared.Items[category .. "_attachment"] then
                                itemName = category .. "_attachment"
                            end
                            break
                        end
                    end
                end
                if itemName then break end
            end
        end
    end

    if not itemName and attComp then
        local numComp = tonumber(attComp) or 0
        local unsignedComp = numComp & 0xFFFFFFFF
        local knownMap = {
            [1709866683] = 'suppressor_attachment',
            [316253668] = 'flashlight_attachment',
            [899381934] = 'flashlight_attachment',
            [(0xFFFFFFFF & -2218447396)] = 'clip_attachment',
            [1593441988] = 'suppressor_attachment'
        }
        if knownMap[unsignedComp] and QBCore.Shared.Items[knownMap[unsignedComp]] then
            itemName = knownMap[unsignedComp]
        end
    end

    local label = nil
    if itemName and QBCore.Shared.Items[itemName] then
        label = QBCore.Shared.Items[itemName].label
    elseif itemName then
        if itemName:find('camo') then label = 'Camuflaje de Arma'
        elseif itemName:find('supp') then label = 'Silenciador Táctico'
        elseif itemName:find('flsh') then label = 'Linterna Táctica'
        elseif itemName:find('clip') or itemName:find('drum') then label = 'Cargador Ampliado'
        elseif itemName:find('scope') then label = 'Mira Telescópica'
        elseif itemName:find('grip') then label = 'Empuñadura Táctica'
        elseif itemName:find('muzzle') or itemName:find('comp') then label = 'Compensador Táctico'
        elseif itemName:find('barrel') then label = 'Cañón Pesado'
        elseif itemName:find('finish') or itemName:find('luxe') then label = 'Acabado de Lujo'
        end
    end

    label = label or 'Modificación de Arma'

    if type(att) == 'table' then
        att.label = label
        if itemName then att.item = itemName end
        return att
    else
        return { component = attComp, item = itemName, label = label }
    end
end

local function EnrichSingleItem(item)
    if not item or not item.name then return nil end
    local sItem = QBCore.Shared.Items[item.name:lower()]
    local cfgBp = Config.Backpacks and (Config.Backpacks[item.name] or Config.Backpacks[item.name:lower()])
    local w = tonumber(item.weight)
    if not w or w <= 0 then
        w = tonumber(sItem and sItem.weight) or 100
    end
    item.weight = w
    item.label = (cfgBp and cfgBp.label) or item.label or (sItem and sItem.label) or item.name
    item.image = (cfgBp and cfgBp.image) or (sItem and sItem.image) or item.image or (item.name .. '.png')
    item.description = item.description or (sItem and sItem.description) or ''
    if sItem and sItem.type == 'weapon' then
        item.info = item.info or {}
        if item.info.quality == nil then
            item.info.quality = 100
        end
    end
    if item.info and type(item.info) == 'table' and item.info.attachments and type(item.info.attachments) == 'table' then
        local newAtts = {}
        for idx, att in pairs(item.info.attachments) do
            newAtts[idx] = ResolveAttachmentLabel(att)
        end
        item.info.attachments = newAtts
    end
    return item
end

local function EnrichItems(items)
    if not items then return {} end
    local enriched = {}
    for k, item in pairs(items) do
        if item and item.name then
            enriched[k] = EnrichSingleItem(item)
        end
    end
    return enriched
end

-- FUNCIONES CORE DE INVENTARIO PARA JUGADORES QBCORE
local function GetItemBySlot(source, slot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not slot then return nil end
    slot = tonumber(slot)
    local items = Player.PlayerData.items
    if items[slot] and tonumber(items[slot].slot) == slot then
        return items[slot]
    end
    for k, v in pairs(items) do
        if v and tonumber(v.slot) == slot then
            return v
        end
    end
    return nil
end

local function GetItemByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not item then return nil end
    item = item:lower()
    for _, itemData in pairs(Player.PlayerData.items) do
        if itemData and itemData.name:lower() == item then
            return itemData
        end
    end
    return nil
end

local function GetItemTotalAmount(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not item then return 0 end
    item = item:lower()
    local total = 0
    for _, itemData in pairs(Player.PlayerData.items) do
        if itemData and itemData.name:lower() == item then
            total = total + (tonumber(itemData.amount) or 1)
        end
    end
    return total
end

local function GetItemsByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not item then return {} end
    item = item:lower()
    local found = {}
    for _, itemData in pairs(Player.PlayerData.items) do
        if itemData and itemData.name:lower() == item then
            found[#found+1] = itemData
        end
    end
    return found
end

local function GetFirstFreeSlot(items, maxSlots)
    maxSlots = maxSlots or 41
    for i = 1, maxSlots do
        local occupied = false
        if items[i] then occupied = true end
        if not occupied then
            for _, v in pairs(items) do
                if v and tonumber(v.slot) == i then
                    occupied = true
                    break
                end
            end
        end
        if not occupied then return i end
    end
    return nil
end

local function AddItem(source, item, amount, slot, info)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local sharedItem = QBCore.Shared.Items[item:lower()]
    if not sharedItem then
        print("^1[qb-inventory] Intento de añadir ítem inexistente: " .. tostring(item) .. "^7")
        return false
    end

    amount = tonumber(amount) or 1
    slot = tonumber(slot)
    info = info or {}

    local items = Player.PlayerData.items

    -- Si nos dan un slot que ya está ocupado por otro ítem o no es apilable, buscamos un slot libre o apilamos
    if slot and items[slot] then
        if items[slot].name:lower() == item:lower() and not sharedItem.unique and sharedItem.type ~= 'weapon' then
            items[slot].amount = items[slot].amount + amount
            Player.Functions.SetPlayerData("items", items)
            TriggerClientEvent('inventory:client:ItemBox', source, sharedItem, 'add')
            TriggerClientEvent('qb-inventory:client:refreshUI', source, items)
            return true
        else
            -- Slot ocupado por un objeto diferente, buscar slot libre para no borrar el ítem existente
            slot = GetFirstFreeSlot(items)
            if not slot then
                TriggerClientEvent('QBCore:Notify', source, "Inventario lleno", "error")
                return false
            end
        end
    elseif not slot then
        if not sharedItem.unique and sharedItem.type ~= 'weapon' then
            for s, itemData in pairs(items) do
                if itemData and itemData.name:lower() == item:lower() then
                    itemData.amount = itemData.amount + amount
                    Player.Functions.SetPlayerData("items", items)
                    TriggerClientEvent('inventory:client:ItemBox', source, sharedItem, 'add')
                    TriggerClientEvent('qb-inventory:client:refreshUI', source, items)
                    return true
                end
            end
        end

        slot = GetFirstFreeSlot(items)
        if not slot then
            TriggerClientEvent('QBCore:Notify', source, "Inventario lleno", "error")
            return false
        end
    end

    -- Si el slot pedido ya está ocupado y es el mismo objeto apilable (por si acaso)
    if items[slot] and items[slot].name:lower() == item:lower() and not sharedItem.unique and sharedItem.type ~= 'weapon' then
        items[slot].amount = items[slot].amount + amount
    else
        -- Nuevo objeto en el slot
        if sharedItem.type == 'weapon' then
            info = info or {}
            if info.quality == nil then
                info.quality = 100
            end
            info.attachments = info.attachments or {}
        end
        items[slot] = {
            name = sharedItem.name,
            amount = amount,
            info = info,
            label = sharedItem.label,
            description = sharedItem.description or '',
            weight = sharedItem.weight or 0,
            type = sharedItem.type or 'item',
            unique = sharedItem.unique or false,
            useable = sharedItem.useable or false,
            image = sharedItem.image or (sharedItem.name .. '.png'),
            slot = slot
        }
    end

    Player.Functions.SetPlayerData("items", items)
    TriggerClientEvent('inventory:client:ItemBox', source, sharedItem, 'add')
    TriggerClientEvent('qb-inventory:client:refreshUI', source, items)
    return true
end

local function RemoveItem(source, item, amount, slot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not item then return false end

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then return false end

    slot = tonumber(slot)
    local items = Player.PlayerData.items

    if slot then
        local itemData = items[slot]
        if not itemData then
            for k, v in pairs(items) do
                if v and tonumber(v.slot) == slot then
                    itemData = v
                    slot = k
                    break
                end
            end
        end
        if itemData and itemData.name:lower() == item:lower() then
            if tonumber(itemData.amount) >= amount then
                if tonumber(itemData.amount) > amount then
                    itemData.amount = tonumber(itemData.amount) - amount
                else
                    items[slot] = nil
                end
                Player.Functions.SetPlayerData("items", items)
                local sharedItem = QBCore.Shared.Items[item:lower()] or itemData
                TriggerClientEvent('inventory:client:ItemBox', source, sharedItem, 'remove')
                TriggerClientEvent('qb-inventory:client:refreshUI', source, items)
                return true
            end
        end
        return false
    else
        local totalAmount = 0
        for _, itemData in pairs(items) do
            if itemData and itemData.name:lower() == item:lower() then
                totalAmount = totalAmount + (tonumber(itemData.amount) or 0)
            end
        end
        if totalAmount < amount then return false end

        local toRemove = amount
        for s, itemData in pairs(items) do
            if itemData and itemData.name:lower() == item:lower() then
                if tonumber(itemData.amount) > toRemove then
                    itemData.amount = tonumber(itemData.amount) - toRemove
                    toRemove = 0
                    break
                else
                    toRemove = toRemove - tonumber(itemData.amount)
                    items[s] = nil
                    if toRemove <= 0 then break end
                end
            end
        end
        Player.Functions.SetPlayerData("items", items)
        local sharedItem = QBCore.Shared.Items[item:lower()] or { name = item }
        TriggerClientEvent('inventory:client:ItemBox', source, sharedItem, 'remove')
        TriggerClientEvent('qb-inventory:client:refreshUI', source, items)
        return true
    end
end

local function SetInventory(source, items)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    Player.Functions.SetPlayerData("items", items)
    return true
end

-- INYECCIÓN EN JUGADORES QBCORE
local function InyectarMetodosJugador(src)
    QBCore.Functions.AddPlayerMethod(src, "AddItem", function(...) return AddItem(src, ...) end)
    QBCore.Functions.AddPlayerMethod(src, "RemoveItem", function(...) return RemoveItem(src, ...) end)
    QBCore.Functions.AddPlayerMethod(src, "GetItemByName", function(...) return GetItemByName(src, ...) end)
    QBCore.Functions.AddPlayerMethod(src, "GetItemBySlot", function(...) return GetItemBySlot(src, ...) end)
    QBCore.Functions.AddPlayerMethod(src, "GetItemsByName", function(...) return GetItemsByName(src, ...) end)
    QBCore.Functions.AddPlayerMethod(src, "SetInventory", function(...) return SetInventory(src, ...) end)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData and Player.PlayerData.source then
        InyectarMetodosJugador(Player.PlayerData.source)
    end
end)

CreateThread(function()
    Wait(500)
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        if Player and Player.PlayerData and Player.PlayerData.source then
            InyectarMetodosJugador(Player.PlayerData.source)
        end
    end
end)

-- EXPORTS PUBLICOS
exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('GetItemByName', GetItemByName)
exports('GetItemBySlot', GetItemBySlot)
exports('GetItemsByName', GetItemsByName)
exports('SetInventory', SetInventory)

exports('GetSlotsByItem', function(source, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end
    local slotsFound = {}
    for slot, item in pairs(Player.PlayerData.items) do
        if item.name:lower() == itemName:lower() then
            table.insert(slotsFound, tonumber(slot))
        end
    end
    return slotsFound
end)

exports('GetFirstSlotByItem', function(source, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end
    for slot, item in pairs(Player.PlayerData.items) do
        if item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end)

exports('GetTotalWeight', function(items)
    if not items then return 0 end
    local weight = 0
    for _, item in pairs(items) do
        local w = item.weight
        if not w and item.name then
            local sItem = QBCore.Shared.Items[item.name:lower()]
            if sItem then w = sItem.weight end
        end
        weight = weight + ((tonumber(w) or 0) * (tonumber(item.amount) or 1))
    end
    return tonumber(weight)
end)

exports('GetSlots', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 0, Config.MaxSlots or 40 end
    local count = 0
    for _ in pairs(Player.PlayerData.items) do count = count + 1 end
    return count, (Config.MaxSlots or 40) - count
end)

exports('GetItemCount', function(source, items)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 0 end
    local isTable = type(items) == 'table'
    local itemsSet = isTable and {} or nil
    if isTable then
        for _, item in pairs(items) do itemsSet[item:lower()] = true end
    end
    local count = 0
    for _, item in pairs(Player.PlayerData.items) do
        if (isTable and itemsSet[item.name:lower()]) or (not isTable and items:lower() == item.name:lower()) then
            count = count + item.amount
        end
    end
    return count
end)

exports('CanAddItem', function(source, item, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    local itemData = QBCore.Shared.Items[item:lower()]
    if not itemData then return false end
    
    local rawWeight = type(Config.MaxWeight) == 'table' and (Config.MaxWeight.player or 120000) or Config.MaxWeight
    local maxWeight = tonumber(rawWeight) or 120000
    if maxWeight <= 1000 then maxWeight = maxWeight * 1000 end

    local totalWeight = 0
    local slotsUsed = 0
    for _, i in pairs(Player.PlayerData.items) do
        totalWeight = totalWeight + ((i.weight or 0) * (i.amount or 1))
        slotsUsed = slotsUsed + 1
    end

    if (totalWeight + (itemData.weight * amount)) > maxWeight then return false, 'weight' end
    if slotsUsed >= (Config.MaxSlots or 40) then
        for _, v in pairs(Player.PlayerData.items) do
            if v.name == itemData.name and not itemData.unique then return true end
        end
        return false, 'slots'
    end
    return true
end)

exports('GetFreeWeight', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 0 end
    local rawWeight = type(Config.MaxWeight) == 'table' and (Config.MaxWeight.player or 120000) or Config.MaxWeight
    local maxWeight = tonumber(rawWeight) or 120000
    if maxWeight <= 1000 then maxWeight = maxWeight * 1000 end
    local totalWeight = 0
    for _, i in pairs(Player.PlayerData.items) do
        totalWeight = totalWeight + ((i.weight or 0) * (i.amount or 1))
    end
    return maxWeight - totalWeight
end)

exports('ClearInventory', function(source, filterItems)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local savedItemData = {}
    if filterItems then
        if type(filterItems) == 'string' then
            for slot, item in pairs(Player.PlayerData.items) do
                if item and item.name:lower() == filterItems:lower() then savedItemData[slot] = item end
            end
        elseif type(filterItems) == 'table' then
            local filterSet = {}
            for k, v in pairs(filterItems) do
                if type(v) == 'string' then filterSet[v:lower()] = true
                elseif type(k) == 'string' and v then filterSet[k:lower()] = true end
            end
            for slot, item in pairs(Player.PlayerData.items) do
                if item and filterSet[item.name:lower()] then savedItemData[slot] = item end
            end
        end
    end
    Player.Functions.SetPlayerData('items', savedItemData)
    TriggerClientEvent('qb-inventory:client:refreshUI', source, savedItemData)
end)

exports('CloseInventory', function(source, invId)
    TriggerClientEvent('qb-inventory:client:closeInventory', source)
end)

RegisterNetEvent('qb-inventory:server:closeInventory', function()
    OpenedContainers[source] = nil
end)

exports('ClearStash', function(stashId)
    Stashes[stashId] = { items = {} }
    MySQL.update('UPDATE stashitems SET items = ? WHERE stash = ?', { '[]', stashId })
end)

exports('CreateShop', function(shopData)
    local shopId = shopData.name or ("shop_" .. math.random(1000,9999))
    local formattedItems = {}
    if shopData.items then
        for i, item in pairs(shopData.items) do
            local sItem = QBCore.Shared.Items[item.name:lower()]
            formattedItems[i] = {
                name = item.name,
                price = item.price or 0,
                amount = item.amount or 9999,
                slot = i,
                label = sItem and sItem.label or item.name,
                image = sItem and sItem.image or (item.name .. ".png"),
                weight = sItem and sItem.weight or 0,
                info = item.info or {}
            }
        end
    end
    Shops[shopId] = { name = shopData.label or shopId, items = formattedItems }
    return shopId
end)

exports('OpenShop', function(source, shopId)
    local shop = Shops[shopId] or (RegisteredShops and RegisteredShops[shopId])
    if not shop then return end
    OpenedContainers[source] = { type = "shop", id = shopId }
    TriggerClientEvent('qb-inventory:client:openSecondary', source, shop.name or shop.label or "Tienda", 1000.0, shopId, "shop", shop.items)
end)

local function OpenContainerNormalizedHelper(source, invType, invId, other)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    if invType == "stash" then
        local stashId = tostring(invId)
        local data = type(other) == "table" and other or {}
        local maxW = tonumber(data.maxweight or data.maxWeight) or 100000
        if maxW > 5000 then maxW = maxW / 1000.0 end
        if maxW < 10 then maxW = 100.0 end

        OpenedContainers[source] = { type = "stash", id = stashId }
        local items = LoadContainerItems("stash", stashId)
        TriggerClientEvent('qb-inventory:client:openSecondary', source, "Armario: " .. stashId, maxW, stashId, "stash", EnrichItems(items))
    elseif invType == "trunk" then
        OpenedContainers[source] = { type = "trunk", id = invId }
        local items = LoadContainerItems("trunk", invId)
        TriggerClientEvent('qb-inventory:client:openSecondary', source, "Maletero: " .. invId, 150.0, invId, "trunk", EnrichItems(items))
    elseif invType == "glovebox" then
        OpenedContainers[source] = { type = "glovebox", id = invId }
        local items = LoadContainerItems("glovebox", invId)
        TriggerClientEvent('qb-inventory:client:openSecondary', source, "Guantera: " .. invId, 15.0, invId, "glovebox", EnrichItems(items))
    elseif invType == "shop" then
        OpenedContainers[source] = { type = "shop", id = invId }
        local shopItems = Shops[invId] and Shops[invId].items or (RegisteredShops and RegisteredShops[invId] and RegisteredShops[invId].items) or (other and other.items or {})
        TriggerClientEvent('qb-inventory:client:openSecondary', source, Shops[invId] and Shops[invId].name or (RegisteredShops and RegisteredShops[invId] and RegisteredShops[invId].label) or "Tienda", 1000.0, invId, "shop", shopItems)
    else
        -- Llamada estándar QBCore con 2 o 3 argumentos: OpenInventory(src, 'nombre_contenedor', { maxweight = ..., slots = ... })
        local stashId = tostring(invType)
        local data = type(invId) == "table" and invId or (type(other) == "table" and other or {})
        local maxW = tonumber(data.maxweight or data.maxWeight) or 100000
        if maxW > 5000 then maxW = maxW / 1000.0 end
        if maxW < 10 then maxW = 100.0 end

        OpenedContainers[source] = { type = "stash", id = stashId }
        local items = LoadContainerItems("stash", stashId)
        TriggerClientEvent('qb-inventory:client:openSecondary', source, "Armario: " .. stashId, maxW, stashId, "stash", EnrichItems(items))
    end
end

exports('OpenInventory', function(source, invType, invId, other)
    OpenContainerNormalizedHelper(source, invType, invId, other)
end)
exports('OpenInventoryById', function(source, invId)
    local targetId = tonumber(invId)
    if not targetId then return end
    local Target = QBCore.Functions.GetPlayer(targetId)
    if Target then
        OpenedContainers[source] = { type = "otherplayer", id = targetId }
        TriggerClientEvent('qb-inventory:client:openSecondary', source, "Cacheo: " .. GetPlayerName(targetId), 120.0, targetId, "otherplayer", EnrichItems(Target.PlayerData.items))
    end
end)
exports('OpenStash', function(source, stashId)
    OpenedContainers[source] = { type = "stash", id = stashId }
    local items = LoadContainerItems("stash", stashId)
    TriggerClientEvent('qb-inventory:client:openSecondary', source, "Stash: " .. stashId, 100.0, stashId, "stash", EnrichItems(items))
end)
exports('OpenTrunk', function(source, plate)
    OpenedContainers[source] = { type = "trunk", id = plate }
    local items = LoadContainerItems("trunk", plate)
    TriggerClientEvent('qb-inventory:client:openSecondary', source, "Maletero: " .. plate, 150.0, plate, "trunk", EnrichItems(items))
end)
exports('OpenGlovebox', function(source, plate)
    OpenedContainers[source] = { type = "glovebox", id = plate }
    local items = LoadContainerItems("glovebox", plate)
    TriggerClientEvent('qb-inventory:client:openSecondary', source, "Guantera: " .. plate, 15.0, plate, "glovebox", EnrichItems(items))
end)

exports('HasItem', function(source, items, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    local count = amount or 1

    if type(items) == "table" then
        for _, item in pairs(items) do
            local itemData = GetItemByName(source, item)
            if itemData and itemData.amount >= count then return true end
        end
        return false
    else
        local itemData = GetItemByName(source, items)
        return (itemData and itemData.amount >= count)
    end
end)

local function UseItem(itemName, ...)
    local itemData = QBCore.Functions.CanUseItem(itemName)
    if type(itemData) == 'table' and itemData.func then
        itemData.func(...)
    end
end
exports('UseItem', UseItem)

exports('LoadInventory', function(source, citizenid)
    local inventory = MySQL.query.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    if inventory[1] and inventory[1].inventory then
        local items = json.decode(inventory[1].inventory)
        if type(items) == "table" then return items end
    end
    return {}
end)

exports('SaveInventory', function(source, offline)
    local items = nil
    local citizenid = nil

    if type(source) == "table" and offline then
        items = source.items
        citizenid = source.citizenid
    else
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            items = Player.PlayerData.items
            citizenid = Player.PlayerData.citizenid
        end
    end

    if citizenid and items then
        MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(items), citizenid })
    end
end)

local function IsAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god') or QBCore.Functions.HasPermission(src, 'command') or QBCore.Functions.HasPermission(src, 'mod') or IsPlayerAceAllowed(src, 'command')
end

-- CALLBACKS ESTÁNDAR DE QBCORE
QBCore.Functions.CreateCallback('qb-inventory:server:getPlayerInventory', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}, false, nil) return end
    local ok, enriched = pcall(EnrichItems, Player.PlayerData.items)
    if not ok then
        print("^1[qb-inventory] Error en EnrichItems: " .. tostring(enriched) .. "^7")
        enriched = Player.PlayerData.items or {}
    end
    local equippedBp = nil
    if Player.PlayerData.metadata['equipped_backpack'] then
        equippedBp = EnrichSingleItem(CopyTable(Player.PlayerData.metadata['equipped_backpack']))
    end
    cb(enriched, IsAdmin(source), equippedBp)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:GetAdminData', function(source, cb)
    local src = source
    if not IsAdmin(src) then
        cb({}, {})
        return
    end

    local players = {}
    for _, p in pairs(QBCore.Functions.GetQBPlayers()) do
        if p and p.PlayerData then
            players[#players+1] = {
                id = p.PlayerData.source,
                name = (p.PlayerData.charinfo.firstname or '') .. ' ' .. (p.PlayerData.charinfo.lastname or '') .. ' (' .. GetPlayerName(p.PlayerData.source) .. ')'
            }
        end
    end

    local itemsList = {}
    for k, v in pairs(QBCore.Shared.Items) do
        itemsList[#itemsList+1] = v
    end

    cb(players, itemsList)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:GetCurrentDrops', function(source, cb) cb(Drops) end)

-- HELPER: cargar items de contenedor desde memoria o DB
local function LoadContainerItems(cType, id)
    if cType == "stash" then
        if not Stashes[id] then
            local r = MySQL.query.await('SELECT items FROM stashitems WHERE stash = ?', { id })
            Stashes[id] = { items = (r and r[1] and r[1].items and json.decode(r[1].items)) or {} }
        end
        return Stashes[id].items
    elseif cType == "trunk" then
        if not Trunks[id] then
            local r = MySQL.query.await('SELECT items FROM trunkitems WHERE plate = ?', { id })
            Trunks[id] = { items = (r and r[1] and r[1].items and json.decode(r[1].items)) or {} }
        end
        return Trunks[id].items
    elseif cType == "glovebox" then
        if not Gloveboxes[id] then
            local r = MySQL.query.await('SELECT items FROM gloveboxitems WHERE plate = ?', { id })
            Gloveboxes[id] = { items = (r and r[1] and r[1].items and json.decode(r[1].items)) or {} }
        end
        return Gloveboxes[id].items
    end
    return {}
end

RegisterNetEvent('inventory:server:OpenInventory', function(type, id, other)
    OpenContainerNormalizedHelper(source, type, id, other)
end)

-- CALLBACKS PARA OBTENER ITEMS DE CONTENEDOR (solicitados por el cliente)
QBCore.Functions.CreateCallback('qb-inventory:server:GetStashItems', function(source, cb, stashId)
    local items = LoadContainerItems("stash", stashId)
    OpenedContainers[source] = { type = "stash", id = stashId }
    cb(EnrichItems(items))
end)

QBCore.Functions.CreateCallback('qb-inventory:server:GetTrunkItems', function(source, cb, plate)
    local items = LoadContainerItems("trunk", plate)
    OpenedContainers[source] = { type = "trunk", id = plate }
    cb(EnrichItems(items))
end)

QBCore.Functions.CreateCallback('qb-inventory:server:GetGloveboxItems', function(source, cb, plate)
    local items = LoadContainerItems("glovebox", plate)
    OpenedContainers[source] = { type = "glovebox", id = plate }
    cb(EnrichItems(items))
end)

-- GUARDADO DE CONTENEDORES (Bloqueado frente a clientes de red directos para evitar overwrites arbitrarios)
RegisterNetEvent('inventory:server:SaveStashItems', function(stashId, items)
    if source and source ~= "" and source ~= 0 then return end
    Stashes[stashId] = { items = items }
    MySQL.insert('INSERT INTO stashitems (stash, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { stashId, json.encode(items), json.encode(items) })
end)

RegisterNetEvent('inventory:server:SaveTrunkItems', function(plate, items)
    if source and source ~= "" and source ~= 0 then return end
    Trunks[plate] = { items = items }
    MySQL.insert('INSERT INTO trunkitems (plate, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { plate, json.encode(items), json.encode(items) })
end)

RegisterNetEvent('inventory:server:SaveGloveboxItems', function(plate, items)
    if source and source ~= "" and source ~= 0 then return end
    Gloveboxes[plate] = { items = items }
    MySQL.insert('INSERT INTO gloveboxitems (plate, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { plate, json.encode(items), json.encode(items) })
end)

-- EVENTOS DE USO DE ÍTEMS
local function HandleItemUse(src, itemSlot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local itemData = GetItemBySlot(src, itemSlot)
    if not itemData then return end

    if itemData.type == 'weapon' then
        local quality = tonumber(itemData.info and itemData.info.quality)
        if not quality then quality = 100 end
        TriggerClientEvent('qb-weapons:client:UseWeapon', src, itemData, quality > 0)
    elseif Config.Backpacks and Config.Backpacks[itemData.name] then
        TriggerEvent('qb-inventory:server:useBackpackItem', src, itemData)
    else
        UseItem(itemData.name, src, itemData)
    end
end

RegisterNetEvent('qb-inventory:server:UseItem', function(item)
    local slot = type(item) == "table" and (item.qbslot or item.slot) or tonumber(item)
    HandleItemUse(source, slot)
end)
RegisterNetEvent('inventory:server:UseItem', function(slot) HandleItemUse(source, tonumber(slot) or (type(slot)=="table" and slot.slot)) end)

-- ACTUAlIZAR COORDENADAS TETRIS Y ACCESO RÁPIDO (HOTBAR 1-6)
local function HandlePlayerSlotMove(src, fromSlot, toSlot, moveAmount)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    fromSlot = tonumber(fromSlot)
    toSlot = tonumber(toSlot)
    if not fromSlot or not toSlot or fromSlot == toSlot then return end

    local items = Player.PlayerData.items
    local fromKey, fromItem = nil, nil
    local toKey, toItem = nil, nil

    for k, v in pairs(items) do
        if v and (tonumber(v.slot) == fromSlot or tonumber(k) == fromSlot) then
            fromKey = k
            fromItem = v
        end
        if v and (tonumber(v.slot) == toSlot or tonumber(k) == toSlot) then
            toKey = k
            toItem = v
        end
    end

    if not fromItem then return end
    moveAmount = math.floor(tonumber(moveAmount) or tonumber(fromItem.amount) or 1)
    if moveAmount <= 0 then moveAmount = 1 end
    if moveAmount > tonumber(fromItem.amount) then moveAmount = tonumber(fromItem.amount) end

    local sharedItem = QBCore.Shared.Items[fromItem.name:lower()]
    local isStackable = not fromItem.unique and fromItem.type ~= 'weapon' and not (sharedItem and sharedItem.unique)

    if toItem and fromItem.name:lower() == toItem.name:lower() and isStackable then
        toItem.amount = tonumber(toItem.amount) + moveAmount
        if moveAmount >= tonumber(fromItem.amount) then
            items[fromKey] = nil
            if tonumber(fromKey) then items[tonumber(fromKey)] = nil end
        else
            fromItem.amount = tonumber(fromItem.amount) - moveAmount
        end
    elseif moveAmount < tonumber(fromItem.amount) and not toItem then
        fromItem.amount = tonumber(fromItem.amount) - moveAmount
        items[toSlot] = {
            name = fromItem.name,
            amount = moveAmount,
            info = CopyTable(fromItem.info or {}),
            label = fromItem.label,
            description = fromItem.description or '',
            weight = fromItem.weight or 0,
            type = fromItem.type or 'item',
            unique = fromItem.unique or false,
            useable = fromItem.useable or false,
            image = fromItem.image or (fromItem.name .. '.png'),
            slot = toSlot
        }
    else
        items[fromKey] = nil
        if tonumber(fromKey) then items[tonumber(fromKey)] = nil end
        if toKey then
            items[toKey] = nil
            if tonumber(toKey) then items[tonumber(toKey)] = nil end
        end

        fromItem.slot = toSlot
        items[toSlot] = fromItem

        if toItem then
            toItem.slot = fromSlot
            items[fromSlot] = toItem
        end
    end

    Player.Functions.SetPlayerData("items", items)
    if Player.Functions.SetInventory then
        Player.Functions.SetInventory(items)
    end
    SyncPlayerUI(src)
end

RegisterNetEvent('qb-inventory:server:SetItemSlot', function(data)
    if not data then return end
    local fromSlot = data.fromSlot or (data.item and (data.item.qbslot or data.item.slot))
    HandlePlayerSlotMove(source, fromSlot, data.toSlot, data.amount)
end)

RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInv, toInv, fromSlot, toSlot, fromAmount, toAmount)
    HandlePlayerSlotMove(source, fromSlot, toSlot, fromAmount)
end)

RegisterNetEvent('inventory:server:SetInventoryData', function(fromInv, toInv, fromSlot, toSlot, fromAmount, toAmount)
    HandlePlayerSlotMove(source, fromSlot, toSlot, fromAmount)
end)

RegisterNetEvent('qb-inventory:server:SetQuickbarSlot', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not data then return end

    local fromSlot = tonumber(data.slot or (data.item and (data.item.qbslot or data.item.slot)))
    local toSlot = tonumber(data.hotbarSlot)
    if not fromSlot or not toSlot or fromSlot == toSlot then return end

    local items = Player.PlayerData.items
    local fromKey, fromItem = nil, nil
    local toKey, toItem = nil, nil

    for k, v in pairs(items) do
        if v and (tonumber(v.slot) == fromSlot or tonumber(k) == fromSlot) then
            fromKey = k
            fromItem = v
        end
        if v and (tonumber(v.slot) == toSlot or tonumber(k) == toSlot) then
            toKey = k
            toItem = v
        end
    end

    if fromItem then
        fromItem.slot = toSlot
        items[toSlot] = fromItem
        if fromKey ~= toSlot then items[fromKey] = nil end

        if toItem then
            toItem.slot = fromSlot
            items[fromSlot] = toItem
            if toKey ~= fromSlot and toKey ~= toSlot then items[toKey] = nil end
        end

        Player.Functions.SetPlayerData("items", items)
        SyncPlayerUI(src)
    end
end)

SyncPlayerUI = function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData then
        TriggerClientEvent('qb-inventory:client:refreshUI', src, EnrichItems(Player.PlayerData.items), Player.PlayerData.metadata['equipped_backpack'])
    end
end
exports('SyncPlayerUI', SyncPlayerUI)

-- DROPS EN EL SUELO Y MUERTE
RegisterNetEvent('qb-inventory:server:DropItem', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not item then return end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local slot = item.qbslot or item.slot

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then return end
    if RemoveItem(src, item.name, amount, slot) then
        local dropId = "drop-" .. math.random(100000, 999999)
        local droppedItem = CopyTable(item)
        droppedItem.amount = amount
        droppedItem.slot = 1

        Drops[dropId] = { id = dropId, items = { [1] = droppedItem }, coords = playerCoords }
        TriggerClientEvent('qb-inventory:client:createLocalDrop', -1, dropId, playerCoords, Drops[dropId])
        SyncPlayerUI(src)
    end
end)

RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
    if not isDead then return end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local dropId = "death-" .. math.random(100000, 999999)
    local deathItems = {}
    local slot = 1

    for k, v in pairs(Player.PlayerData.items) do
        if v.name ~= 'id_card' and v.name ~= 'phone' then
            deathItems[slot] = CopyTable(v)
            deathItems[slot].slot = slot
            RemoveItem(src, v.name, v.amount, v.slot)
            slot = slot + 1
        end
    end

    if slot > 1 then
        Drops[dropId] = { id = dropId, items = deathItems, coords = playerCoords, owner = Player.PlayerData.citizenid }
        TriggerClientEvent('qb-inventory:client:createLocalDrop', -1, dropId, playerCoords, Drops[dropId])
        SyncPlayerUI(src)
    end
end)

RegisterNetEvent('qb-inventory:server:openDrop', function(dropId)
    local src = source
    if Drops[dropId] then
        if Drops[dropId].heldBy then
            TriggerClientEvent('QBCore:Notify', src, "Alguien tiene esta bolsa en las manos", "error")
            return
        end
        OpenedContainers[src] = { type = "drop", id = dropId }
        TriggerClientEvent('qb-inventory:client:openLoot', src, dropId, EnrichItems(Drops[dropId].items))
    end
end)

-- TRANSFERIR Y DIVIDIR ÍTEMS
RegisterNetEvent('qb-inventory:server:GiveItem', function(item, amount, targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)

    if not Player or not Target or src == targetId or not item then return end

    local pCoords = GetEntityCoords(GetPlayerPed(src))
    local tCoords = GetEntityCoords(GetPlayerPed(targetId))
    if #(pCoords - tCoords) > 5.0 then
        TriggerClientEvent('QBCore:Notify', src, "Jugador demasiado lejos", "error")
        return
    end

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then return end
    if RemoveItem(src, item.name, amount, item.qbslot or item.slot) then
        AddItem(targetId, item.name, amount, false, item.info)
        TriggerClientEvent('QBCore:Notify', src, "Has dado " .. amount .. "x " .. item.label, "success")
        TriggerClientEvent('QBCore:Notify', targetId, "Has recibido " .. amount .. "x " .. item.label, "success")
        SyncPlayerUI(src)
        SyncPlayerUI(targetId)
    end
end)

RegisterNetEvent('qb-inventory:server:SplitItem', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not item then return end

    amount = math.floor(tonumber(amount) or 1)
    local origSlot = tonumber(item.qbslot or item.slot)
    local items = Player.PlayerData.items
    local origItem = items[origSlot]

    if not origItem or amount <= 0 or origItem.amount <= amount then return end

    local freeSlot = GetFirstFreeSlot(items)
    if not freeSlot then
        TriggerClientEvent('QBCore:Notify', src, "Inventario lleno para dividir", "error")
        return
    end

    -- Restamos del original
    origItem.amount = origItem.amount - amount

    -- Insertamos como nuevo stack separado en el nuevo slot libre
    items[freeSlot] = {
        name = origItem.name,
        amount = amount,
        info = CopyTable(origItem.info or {}),
        label = origItem.label,
        description = origItem.description or '',
        weight = origItem.weight or 0,
        type = origItem.type or 'item',
        unique = origItem.unique or false,
        useable = origItem.useable or false,
        image = origItem.image or (origItem.name .. '.png'),
        slot = freeSlot
    }

    Player.Functions.SetPlayerData("items", items)
    SyncPlayerUI(src)
end)

RegisterNetEvent('qb-inventory:server:MergeStack', function(sourceItem, targetItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not sourceItem or not targetItem then return end
    local items = Player.PlayerData.items
    local srcSlot = tonumber(sourceItem.qbslot or sourceItem.slot)
    local tgtSlot = tonumber(targetItem.qbslot or targetItem.slot)
    if not srcSlot or not tgtSlot or not items[srcSlot] or not items[tgtSlot] then return end

    if items[srcSlot].name == items[tgtSlot].name and not items[srcSlot].unique and items[srcSlot].type ~= 'weapon' then
        items[tgtSlot].amount = items[tgtSlot].amount + items[srcSlot].amount
        items[srcSlot] = nil
        Player.Functions.SetPlayerData("items", items)
        SyncPlayerUI(src)
    end
end)


local function GetContainerData(src, containerId, cType)
    if not OpenedContainers[src] or tostring(OpenedContainers[src].id) ~= tostring(containerId) then
        return nil
    end
    cType = OpenedContainers[src].type

    if not cType then return nil end

    if cType == "stash" then
        if not Stashes[containerId] then
            local result = MySQL.query.await('SELECT items FROM stashitems WHERE stash = ?', { containerId })
            if result and result[1] and result[1].items then
                Stashes[containerId] = { items = json.decode(result[1].items) }
            else
                Stashes[containerId] = { items = {} }
            end
        end
        return Stashes[containerId], "stash", "Armario: " .. containerId, 100.0
    elseif cType == "trunk" then
        if not Trunks[containerId] then
            local result = MySQL.query.await('SELECT items FROM trunkitems WHERE plate = ?', { containerId })
            if result and result[1] and result[1].items then
                Trunks[containerId] = { items = json.decode(result[1].items) }
            else
                Trunks[containerId] = { items = {} }
            end
        end
        return Trunks[containerId], "trunk", "Maletero: " .. containerId, 150.0
    elseif cType == "glovebox" then
        if not Gloveboxes[containerId] then
            local result = MySQL.query.await('SELECT items FROM gloveboxitems WHERE plate = ?', { containerId })
            if result and result[1] and result[1].items then
                Gloveboxes[containerId] = { items = json.decode(result[1].items) }
            else
                Gloveboxes[containerId] = { items = {} }
            end
        end
        return Gloveboxes[containerId], "glovebox", "Guantera: " .. containerId, 15.0
    elseif cType == "drop" then
        if Drops[containerId] then
            local pCoords = GetEntityCoords(GetPlayerPed(src))
            if #(pCoords - Drops[containerId].coords) > 5.0 then return nil end
            return Drops[containerId], "drop", "Bolsa de Botín", 100.0
        end
    elseif cType == "shop" then
        local shopData = Shops[containerId] or (RegisteredShops and RegisteredShops[containerId])
        return shopData, "shop", shopData and (shopData.name or shopData.label) or "Tienda", 1000.0
    elseif cType == "otherplayer" then
        local targetSrc = tonumber(containerId)
        local TargetPlayer = QBCore.Functions.GetPlayer(targetSrc)
        if TargetPlayer then
            local pCoords = GetEntityCoords(GetPlayerPed(src))
            local tCoords = GetEntityCoords(GetPlayerPed(targetSrc))
            if #(pCoords - tCoords) > 5.0 then return nil end
            return { items = TargetPlayer.PlayerData.items }, "otherplayer", "Jugador [" .. targetSrc .. "]", Config.MaxWeight or 120000
        end
    end
    return nil
end

local function SaveContainerData(id, cType, container)
    if cType == "stash" then
        MySQL.insert('INSERT INTO stashitems (stash, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { id, json.encode(container.items), json.encode(container.items) })
    elseif cType == "trunk" then
        MySQL.insert('INSERT INTO trunkitems (plate, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { id, json.encode(container.items), json.encode(container.items) })
    elseif cType == "glovebox" then
        MySQL.insert('INSERT INTO gloveboxitems (plate, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { id, json.encode(container.items), json.encode(container.items) })
    elseif cType == "otherplayer" then
        local targetSrc = tonumber(id)
        local TargetPlayer = QBCore.Functions.GetPlayer(targetSrc)
        if TargetPlayer then
            TargetPlayer.Functions.SetPlayerData("items", container.items)
            SyncPlayerUI(targetSrc)
        end
    end
end

-- TRANSFERENCIA TRANSACCIONAL: RECOGER DE BOLSA / MALETERO / ARMARIO A MOCHILA
RegisterNetEvent('qb-inventory:server:TakeFromSecondary', function(data)
    local src = source
    local containerId = data.containerId
    local item = data.item
    if not containerId or not item then return end
    local amount = math.floor(tonumber(data.amount or item.count or item.amount or 1))
    if amount <= 0 then return end

    local container, cType, title, maxW = GetContainerData(src, containerId, data.invType)
    if not container or not container.items then return end

    local foundSlot = nil
    if item.slot and container.items[tonumber(item.slot)] then
        foundSlot = tonumber(item.slot)
    else
        for k, v in pairs(container.items) do
            if v and (tonumber(v.slot) == tonumber(item.slot) or v.name == item.name) then
                foundSlot = k
                break
            end
        end
    end

    if foundSlot then
        local v = container.items[foundSlot]
        if v.amount > amount then
            v.amount = v.amount - amount
        else
            amount = v.amount
            container.items[foundSlot] = nil
        end
        item.info = item.info or {}
        if item.info.tetris then item.info.tetris = nil end
        AddItem(src, item.name, amount, tonumber(data.toSlot), item.info)

        if cType == "drop" then
            local remainingCount = 0
            for _, _ in pairs(container.items) do remainingCount = remainingCount + 1 end
            if remainingCount == 0 then
                Drops[containerId] = nil
                TriggerClientEvent('qb-inventory:client:removeDrop', -1, containerId)
            else
                TriggerClientEvent('qb-inventory:client:openLoot', src, containerId, EnrichItems(container.items))
            end
        else
            SaveContainerData(containerId, cType, container)
            TriggerClientEvent('qb-inventory:client:updateSecondaryContainer', src, containerId, EnrichItems(container.items), title, maxW, cType, container.slots)
        end
        SyncPlayerUI(src)
    end
end)

-- TRANSFERENCIA TRANSACCIONAL: DEPOSITAR DE MOCHILA A BOLSA / MALETERO / ARMARIO
RegisterNetEvent('qb-inventory:server:PutInSecondary', function(data)
    local src = source
    local containerId = data.containerId
    local item = data.item
    if not containerId or not item then return end
    local amount = math.floor(tonumber(data.amount or item.count or item.amount or 1))
    if amount <= 0 then return end
    local origSlot = tonumber(item.qbslot or item.slot)

    local container, cType, title, maxW = GetContainerData(src, containerId, data.invType)
    if not container or not container.items then return end

    if (cType == "stash" and string.sub(tostring(containerId), 1, 3) == "bp_") or (cType == "backpack") then
        if Config.Backpacks and Config.Backpacks[item.name] then
            TriggerClientEvent('QBCore:Notify', src, "No puedes guardar una mochila dentro de otra mochila", "error")
            SyncPlayerUI(src)
            return
        end
    end

    if RemoveItem(src, item.name, amount, origSlot) then
        local nextSlot = tonumber(data.toSlot)
        local stacked = false

        if nextSlot and container.items[nextSlot] then
            local existing = container.items[nextSlot]
            local sharedItem = QBCore.Shared.Items[item.name:lower()]
            if existing.name:lower() == item.name:lower() and sharedItem and not sharedItem.unique and sharedItem.type ~= 'weapon' then
                existing.amount = tonumber(existing.amount) + amount
                stacked = true
            end
        end

        if not stacked then
            if not nextSlot or container.items[nextSlot] then
                nextSlot = 1
                while container.items[nextSlot] do nextSlot = nextSlot + 1 end
            end

            local newItem = CopyTable(item)
            newItem.amount = amount
            newItem.slot = nextSlot
            newItem.info = newItem.info or {}
            if newItem.info.tetris then newItem.info.tetris = nil end

            container.items[nextSlot] = newItem
        end

        if cType == "drop" then
            TriggerClientEvent('qb-inventory:client:openLoot', src, containerId, EnrichItems(container.items))
        else
            SaveContainerData(containerId, cType, container)
            TriggerClientEvent('qb-inventory:client:updateSecondaryContainer', src, containerId, EnrichItems(container.items), title, maxW, cType, container.slots)
        end
        SyncPlayerUI(src)
    end
end)

RegisterNetEvent('qb-inventory:server:MoveInSecondary', function(data)
    local src = source
    local containerId = data.containerId
    local fromSlot = tonumber(data.fromSlot)
    local toSlot = tonumber(data.toSlot)
    if not containerId or not fromSlot or not toSlot or fromSlot == toSlot then return end

    local container, cType, title, maxW = GetContainerData(src, containerId, data.invType)
    if not container or not container.items then return end

    local fromItem = container.items[fromSlot]
    if not fromItem then return end
    local toItem = container.items[toSlot]

    container.items[fromSlot] = nil
    fromItem.slot = toSlot
    container.items[toSlot] = fromItem

    if toItem then
        toItem.slot = fromSlot
        container.items[fromSlot] = toItem
    end

    if cType == "drop" then
        TriggerClientEvent('qb-inventory:client:openLoot', src, containerId, EnrichItems(container.items))
    else
        SaveContainerData(containerId, cType, container)
        TriggerClientEvent('qb-inventory:client:updateSecondaryContainer', src, containerId, EnrichItems(container.items), title, maxW, cType, container.slots)
    end

end)

RegisterNetEvent('qb-inventory:server:BuyItem', function(shopId, itemName, amount, slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local shop = Shops[shopId] or (RegisteredShops and RegisteredShops[shopId])
    if not shop and type(shopId) == "string" and string.sub(shopId, 1, 5) == "shop-" then
        local cleanId = string.sub(shopId, 6)
        shop = Shops[cleanId] or (RegisteredShops and RegisteredShops[cleanId])
    end
    if not shop then return end

    local shopItem = nil
    for _, si in pairs(shop.items) do
        if si.name and si.name:lower() == itemName:lower() then shopItem = si break end
    end
    if not shopItem then return end

    local buyQty = math.floor(tonumber(amount) or 1)
    if buyQty <= 0 then return end
    local price = (shopItem.price or 0) * buyQty

    if Player.Functions.RemoveMoney('cash', price, "shop-purchase") or Player.Functions.RemoveMoney('bank', price, "shop-purchase") then
        Player.Functions.AddItem(itemName, buyQty, false, shopItem.info)
        TriggerClientEvent('QBCore:Notify', src, "Comprado x" .. buyQty .. " " .. (shopItem.label or itemName) .. " por $" .. price, "success")
        SyncPlayerUI(src)
    else
        TriggerClientEvent('QBCore:Notify', src, "No tienes dinero suficiente ($" .. price .. ")", "error")
    end
end)

local CraftingRecipes = {
    ['bandage'] = { output = 'bandage', amount = 2, reqs = { { item = 'cloth', count = 2 } } },
    ['medkit'] = { output = 'medkit', amount = 1, reqs = { { item = 'bandage', count = 2 }, { item = 'alcohol', count = 1 } } },
    ['ammo-9'] = { output = 'pistol_ammo', amount = 1, reqs = { { item = 'metalscrap', count = 3 }, { item = 'gunpowder', count = 2 } } },
    ['repairkit'] = { output = 'repairkit', amount = 1, reqs = { { item = 'iron', count = 4 }, { item = 'steel', count = 2 } } },
    ['lockpick'] = { output = 'lockpick', amount = 1, reqs = { { item = 'metalscrap', count = 2 } } },
    ['armor'] = { output = 'armor', amount = 1, reqs = { { item = 'kevlar', count = 5 }, { item = 'steel', count = 3 } } }
}

RegisterNetEvent('qb-inventory:server:craftItem', function(recipeId, outputCount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local recipe = CraftingRecipes[recipeId]
    if not recipe then return end

    -- Verify player has all ingredients
    for _, req in pairs(recipe.reqs) do
        if GetItemTotalAmount(src, req.item) < req.count then
            TriggerClientEvent('QBCore:Notify', src, "No tienes suficientes materiales para fabricar esto", "error")
            return
        end
    end

    -- Remove ingredients
    for _, req in pairs(recipe.reqs) do
        RemoveItem(src, req.item, req.count)
    end

    -- Give output item
    local outputItem = recipe.output
    if outputItem == 'pistol_ammo' and not QBCore.Shared.Items['pistol_ammo'] and QBCore.Shared.Items['ammo-9'] then
        outputItem = 'ammo-9'
    end

    AddItem(src, outputItem, recipe.amount)
    TriggerClientEvent('QBCore:Notify', src, "Fabricado con éxito: " .. (QBCore.Shared.Items[outputItem] and QBCore.Shared.Items[outputItem].label or outputItem), "success")
    SyncPlayerUI(src)
end)

RegisterNetEvent('qb-inventory:server:modifyWeaponAttachment', function(slot, componentHash, install)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not slot then return end
    local items = Player.PlayerData.items
    local itemData = GetItemBySlot(src, slot)
    if not itemData then return end

    itemData.info = itemData.info or {}
    itemData.info.attachments = itemData.info.attachments or {}

    local giveBackItem = nil

    if install then
        local found = false
        for _, att in pairs(itemData.info.attachments) do
            local attComp = type(att) == 'table' and (att.component or att.id or att.hash) or att
            if CompareHashes(attComp, componentHash) then
                found = true
                break
            end
        end
        if not found then
            table.insert(itemData.info.attachments, { component = componentHash })
        end
    else
        local newAttachments = {}
        for _, att in pairs(itemData.info.attachments) do
            local attComp = type(att) == 'table' and (att.component or att.id or att.hash) or att
            if CompareHashes(attComp, componentHash) then
                if not giveBackItem then
                    local itemName = (type(att) == 'table' and (att.item or att.attachment))
                    if not itemName then
                        local ok, allAtts = pcall(function()
                            return exports['qb-weapons']:getConfigWeaponAttachments()
                        end)
                        if ok and allAtts then
                            for category, weaponsMap in pairs(allAtts) do
                                if type(weaponsMap) == 'table' then
                                    for wName, hashVal in pairs(weaponsMap) do
                                        if CompareHashes(hashVal, attComp) then
                                            if QBCore.Shared.Items[category] then
                                                itemName = category
                                            elseif QBCore.Shared.Items[category .. "_attachment"] then
                                                itemName = category .. "_attachment"
                                            end
                                            break
                                        end
                                    end
                                end
                                if itemName then break end
                            end
                        end
                    end

                    if not itemName then
                        local numComp = tonumber(attComp) or 0
                        local unsignedComp = numComp & 0xFFFFFFFF
                        local knownMap = {
                            [1709866683] = 'suppressor_attachment',
                            [316253668] = 'flashlight_attachment',
                            [899381934] = 'flashlight_attachment',
                            [(0xFFFFFFFF & -2218447396)] = 'clip_attachment',
                            [1593441988] = 'suppressor_attachment'
                        }
                        if knownMap[unsignedComp] and QBCore.Shared.Items[knownMap[unsignedComp]] then
                            itemName = knownMap[unsignedComp]
                        end
                    end

                    if not itemName then
                        itemName = 'suppressor_attachment'
                    end

                    giveBackItem = itemName
                end
            else
                table.insert(newAttachments, att)
            end
        end
        itemData.info.attachments = newAttachments
    end

    local slot = itemData.slot
    local weaponName = itemData.name
    local info = itemData.info

    Player.Functions.RemoveItem(weaponName, 1, slot)
    Player.Functions.AddItem(weaponName, 1, slot, info)

    if giveBackItem and QBCore.Shared.Items[giveBackItem] then
        Player.Functions.AddItem(giveBackItem, 1, false, false)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[giveBackItem], 'add')
    end

    if SyncPlayerUI then
        SyncPlayerUI(src)
    end

    local updatedWeapon = Player.PlayerData.items[slot]
    TriggerClientEvent('qb-weapons:client:SetCurrentWeapon', src, updatedWeapon or {}, true)
end)

RegisterNetEvent('qb-inventory:server:AdminGiveItem', function(targetId, itemName, amount)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, "No tienes permisos de administrador", "error")
        return
    end

    local target = tonumber(targetId)
    if not target or target == 0 then target = src end
    local Target = QBCore.Functions.GetPlayer(target)
    if not Target then
        TriggerClientEvent('QBCore:Notify', src, "El jugador seleccionado no se encuentra en línea", "error")
        return
    end

    local qty = math.floor(tonumber(amount) or 1)
    if qty <= 0 then return end
    if Target.Functions.AddItem(itemName, qty) then
        TriggerClientEvent('QBCore:Notify', src, "Despachado x" .. qty .. " " .. itemName .. " a " .. (Target.PlayerData.charinfo.firstname or "Jugador"), "success")
        if target ~= src then
            TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, "Recibido x" .. qty .. " " .. itemName .. " de un Administrador", "info")
        end
        SyncPlayerUI(target)
    else
        TriggerClientEvent('QBCore:Notify', src, "El inventario de destino está lleno", "error")
    end
end)

RegisterNetEvent('qb-inventory:server:AdminClearInventory', function(targetId)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, "No tienes permisos de administrador", "error")
        return
    end

    local target = tonumber(targetId)
    if not target or target == 0 then target = src end
    local TargetPlayer = QBCore.Functions.GetPlayer(target)
    if TargetPlayer then
        TargetPlayer.Functions.SetPlayerData("items", {})
        SyncPlayerUI(target)
        TriggerClientEvent('QBCore:Notify', src, "Inventario limpiado correctamente", "success")
    end
end)

-- SAQUEO DE CONTENEDORES (LOOT DE BASURAS)
RegisterNetEvent('qb-inventory:server:searchProp', function(lootType, coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not coords then return end

    local coordsKey = string.format("%.1f_%.1f_%.1f", coords.x, coords.y, coords.z)
    local now = GetGameTimer()
    if SearchedProps[coordsKey] and (now - SearchedProps[coordsKey]) < 300000 then
        TriggerClientEvent('QBCore:Notify', src, "Ya han rebuscado aquí recientemente...", "error")
        return
    end

    SearchedProps[coordsKey] = now

    local lootPool = {
        basura = { "metalscrap", "plastic", "glass", "empty_weed_bag" },
        papelera = { "plastic", "paper", "water_bottle" },
        caja = { "wood", "metalscrap", "lockpick" }
    }

    local possibleItems = lootPool[lootType] or { "metalscrap", "plastic" }
    if math.random(1, 100) <= 75 then
        local chosenItem = possibleItems[math.random(1, #possibleItems)]
        local amount = math.random(1, 3)
        if Player.Functions.AddItem(chosenItem, amount) then
            TriggerClientEvent('QBCore:Notify', src, "Encontraste algo en la basura", "success")
            SyncPlayerUI(src)
        else
            TriggerClientEvent('QBCore:Notify', src, "Encontraste algo pero no te cabe en el inventario", "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "No encontraste nada útil", "info")
    end
end)

-- ROBO ENTRE JUGADORES
RegisterNetEvent('qb-inventory:server:robPlayer', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not Player or not Target or src == tonumber(targetId) then return end

    local srcPed = GetPlayerPed(src)
    local tgtPed = GetPlayerPed(tonumber(targetId))
    if #(GetEntityCoords(srcPed) - GetEntityCoords(tgtPed)) > 5.0 then
        TriggerClientEvent('QBCore:Notify', src, "Estás muy lejos del objetivo", "error")
        return
    end

    OpenedContainers[src] = { type = "otherplayer", id = targetId }
    TriggerClientEvent('qb-inventory:client:openSecondary', src, "Cacheo: " .. GetPlayerName(targetId), 4.0, targetId, "otherplayer", EnrichItems(Target.PlayerData.items))
end)

-- GESTIÓN AVANZADA DE DROPS: RECOGER TODO Y AGARRAR CON LA MANO
RegisterNetEvent('qb-inventory:server:takeAllFromDrop', function(dropId)
    local src = source
    local dropData = Drops[dropId]
    if not dropData or not dropData.items then return end

    local pCoords = GetEntityCoords(GetPlayerPed(src))
    if #(pCoords - dropData.coords) > 5.0 then
        TriggerClientEvent('QBCore:Notify', src, "Estás demasiado lejos de la bolsa", "error")
        return
    end

    if dropData.heldBy then
        TriggerClientEvent('QBCore:Notify', src, "Alguien está sosteniendo esta bolsa, no puedes recoger ítems ahora", "error")
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local itemsTaken = 0
    for k, item in pairs(dropData.items) do
        if item and item.name and item.amount > 0 then
            if AddItem(src, item.name, item.amount, false, item.info) then
                dropData.items[k] = nil
                itemsTaken = itemsTaken + 1
            else
                TriggerClientEvent('QBCore:Notify', src, "No tienes suficiente espacio para recoger: " .. (item.label or item.name), "error")
            end
        end
    end

    local remainingCount = 0
    for _, _ in pairs(dropData.items) do
        remainingCount = remainingCount + 1
    end

    if remainingCount == 0 then
        Drops[dropId] = nil
        TriggerClientEvent('qb-inventory:client:removeDrop', -1, dropId)
    else
        for pSrc, container in pairs(OpenedContainers) do
            if container.type == "drop" and container.id == dropId then
                TriggerClientEvent('qb-inventory:client:openLoot', pSrc, dropId, EnrichItems(dropData.items))
            end
        end
    end

    if itemsTaken > 0 then
        SyncPlayerUI(src)
        TriggerClientEvent('QBCore:Notify', src, "Has recogido los ítems de la bolsa", "success")
    end
end)

RegisterNetEvent('qb-inventory:server:pickupDropBag', function(dropId)
    local src = source
    local dropData = Drops[dropId]
    if not dropData then return end

    local pCoords = GetEntityCoords(GetPlayerPed(src))
    if #(pCoords - dropData.coords) > 5.0 then
        TriggerClientEvent('QBCore:Notify', src, "Estás demasiado lejos para agarrar la bolsa", "error")
        return
    end

    if dropData.heldBy then
        TriggerClientEvent('QBCore:Notify', src, "Alguien ya está cargando esta bolsa", "error")
        return
    end
    dropData.heldBy = src
    TriggerClientEvent('qb-inventory:client:onPickupDropBag', -1, dropId, src)
end)

RegisterNetEvent('qb-inventory:server:dropHeldBag', function(dropId, newCoords)
    local src = source
    if not Drops[dropId] then return end
    if Drops[dropId].heldBy ~= src then return end
    Drops[dropId].heldBy = nil
    if newCoords then
        Drops[dropId].coords = newCoords
    end
    TriggerClientEvent('qb-inventory:client:onDropHeldBag', -1, dropId, Drops[dropId].coords)
end)
RegisterNetEvent('qb-inventory:server:updateDrop', function(dropId, newCoords)
    TriggerEvent('qb-inventory:server:dropHeldBag', dropId, newCoords)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for dropId, dData in pairs(Drops) do
        if dData.heldBy == src then
            dData.heldBy = nil
            TriggerClientEvent('qb-inventory:client:onDropHeldBag', -1, dropId, dData.coords)
        end
    end
    OpenedContainers[src] = nil
end)

-- SISTEMA INTEGRAL DE MOCHILAS (EQUIPAMIENTO + STASH PORTÁTIL + APARIENCIA)
local function EnsureBackpackStashId(Player, itemData)
    if not itemData.info then itemData.info = {} end
    if not itemData.info.stashId then
        itemData.info.stashId = "bp_" .. Player.PlayerData.citizenid .. "_" .. math.random(10000, 99999)
    end
    return itemData
end

local function EquipBackpack(src, slot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local slotNum = tonumber(slot)
    local itemData = slotNum and Player.PlayerData.items[slotNum]
    if not itemData then return end

    local cfg = Config.Backpacks and Config.Backpacks[itemData.name]
    if not cfg then return end

    itemData = EnsureBackpackStashId(Player, itemData)
    itemData = EnrichSingleItem(itemData)

    -- Si ya tenía una mochila equipada, desequipar e intercambiar en el mismo slot
    local currentEquipped = Player.PlayerData.metadata['equipped_backpack']
    if currentEquipped then
        Player.PlayerData.items[slotNum] = currentEquipped
        Player.PlayerData.items[slotNum].slot = slotNum
    else
        Player.PlayerData.items[slotNum] = nil
    end

    Player.Functions.SetMetaData('equipped_backpack', itemData)
    Player.Functions.SetPlayerData("items", Player.PlayerData.items)

    TriggerClientEvent('qb-inventory:client:onEquipBackpack', src, itemData)
    SyncPlayerUI(src)
end

RegisterNetEvent('qb-inventory:server:equipBackpack', function(slot)
    EquipBackpack(source, slot)
end)

RegisterNetEvent('qb-inventory:server:unequipBackpack', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local currentEquipped = Player.PlayerData.metadata['equipped_backpack']
    if not currentEquipped then return end

    if Player.Functions.AddItem(currentEquipped.name, 1, false, currentEquipped.info) then
        Player.Functions.SetMetaData('equipped_backpack', nil)
        TriggerClientEvent('qb-inventory:client:onUnequipBackpack', src)
        SyncPlayerUI(src)
    else
        TriggerClientEvent('QBCore:Notify', src, "No tienes espacio en el inventario para quitarte la mochila", "error")
    end
end)

RegisterNetEvent('qb-inventory:server:openEquippedBackpack', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local currentEquipped = Player.PlayerData.metadata['equipped_backpack']
    if not currentEquipped or not currentEquipped.info or not currentEquipped.info.stashId then
        TriggerClientEvent('QBCore:Notify', src, "No tienes ninguna mochila equipada", "error")
        return
    end

    local cfg = Config.Backpacks and Config.Backpacks[currentEquipped.name]
    local maxW = cfg and (cfg.maxWeight or 50000) / 1000.0 or 50.0
    local slots = cfg and cfg.slots or 25
    local label = cfg and cfg.label or currentEquipped.label or "Mochila"

    OpenedContainers[src] = { type = "stash", id = currentEquipped.info.stashId }
    local items = LoadContainerItems("stash", currentEquipped.info.stashId)
    TriggerClientEvent('qb-inventory:client:openSecondary', src, label, maxW, currentEquipped.info.stashId, "stash", EnrichItems(items), slots, true)
end)


RegisterNetEvent('qb-inventory:server:useBackpackItem', function(src, itemData)
    EquipBackpack(src, itemData.slot)
end)


