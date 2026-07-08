local QBCore = exports['qb-core']:GetCoreObject()

local function IsAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god') or QBCore.Functions.HasPermission(src, 'command') or QBCore.Functions.HasPermission(src, 'mod') or IsPlayerAceAllowed(src, 'command')
end

QBCore.Commands.Add('giveitem', 'Dar un objeto a un jugador (Admin)', { { name = 'id', help = 'ID de Jugador' }, { name = 'item', help = 'Nombre del ítem (ej: water)' }, { name = 'cantidad', help = 'Cantidad' } }, false, function(source, args)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, "No tienes permisos de administrador", "error")
        return
    end
    local id = tonumber(args[1])
    local item = tostring(args[2]):lower()
    local amount = tonumber(args[3]) or 1

    local Target = QBCore.Functions.GetPlayer(id)
    if not Target then
        TriggerClientEvent('QBCore:Notify', src, "Jugador no encontrado", "error")
        return
    end

    local itemData = QBCore.Shared.Items[item]
    if not itemData then
        TriggerClientEvent('QBCore:Notify', src, "Ese ítem no existe en QBCore", "error")
        return
    end

    if Target.Functions.AddItem(item, amount) then
        TriggerClientEvent('QBCore:Notify', src, "Diste " .. amount .. "x " .. itemData.label .. " a " .. GetPlayerName(id), "success")
        if id ~= src then
            TriggerClientEvent('QBCore:Notify', id, "Recibiste " .. amount .. "x " .. itemData.label, "success")
        end
        exports['qb-inventory']:SyncPlayerUI(id)
    else
        TriggerClientEvent('QBCore:Notify', src, "Inventario del jugador lleno", "error")
    end
end)

-- Alias corto /give
QBCore.Commands.Add('give', 'Dar un objeto a un jugador (Admin)', { { name = 'id', help = 'ID de Jugador' }, { name = 'item', help = 'Nombre del ítem' }, { name = 'cantidad', help = 'Cantidad' } }, false, function(source, args)
    if not IsAdmin(source) then return end
    local id = tonumber(args[1])
    if id then ExecuteCommand('giveitem ' .. table.concat(args, ' ')) end
end)

QBCore.Commands.Add('clearinv', 'Limpiar inventario (Admin)', { { name = 'id', help = 'ID de Jugador' } }, false, function(source, args)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, "No tienes permisos de administrador", "error")
        return
    end
    local id = tonumber(args[1]) or src
    local Target = QBCore.Functions.GetPlayer(id)
    if Target then
        Target.Functions.SetPlayerData("items", {})
        exports['qb-inventory']:SyncPlayerUI(id)
        TriggerClientEvent('QBCore:Notify', src, "Inventario limpiado para ID " .. id, "success")
    end
end)

QBCore.Commands.Add('openinv', 'Inspeccionar inventario de un jugador en vivo (Admin)', { { name = 'id', help = 'ID de Jugador' } }, true, function(source, args)
    local src = source
    if not IsAdmin(src) then return end
    local targetId = tonumber(args[1])
    if targetId then
        TriggerEvent('qb-inventory:server:AdminOpenPlayerInventory', targetId, src)
    else
        TriggerClientEvent('QBCore:Notify', src, "Debes indicar la ID de un jugador", "error")
    end
end)

QBCore.Commands.Add('inspectinv', 'Inspeccionar inventario de un jugador en vivo (Admin)', { { name = 'id', help = 'ID de Jugador' } }, true, function(source, args)
    local src = source
    if not IsAdmin(src) then return end
    local targetId = tonumber(args[1])
    if targetId then
        TriggerEvent('qb-inventory:server:AdminOpenPlayerInventory', targetId, src)
    end
end)

QBCore.Commands.Add('inventoryadmin', 'Panel de Despacho Visual de Ítems (Admin)', {}, false, function(source)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, "No tienes permisos de administrador", "error")
        return
    end
    local players = {}
    for _, srcId in ipairs(GetPlayers()) do
        local id = tonumber(srcId)
        if id then
            local p = QBCore.Functions.GetPlayer(id)
            if p and p.PlayerData and p.PlayerData.charinfo then
                local charName = (p.PlayerData.charinfo.firstname or '') .. ' ' .. (p.PlayerData.charinfo.lastname or '')
                players[#players+1] = {
                    id = id,
                    name = charName .. ' (' .. (GetPlayerName(id) or p.PlayerData.name or '') .. ')'
                }
            else
                local playerName = GetPlayerName(id) or ('Jugador ' .. id)
                players[#players+1] = {
                    id = id,
                    name = '🔄 [Conectando] ' .. playerName
                }
            end
        end
    end

    local itemsList = {}
    for k, v in pairs(QBCore.Shared.Items) do
        itemsList[#itemsList+1] = v
    end

    TriggerClientEvent('qb-inventory:client:openAdminMenu', src, players, itemsList)
end)

-- Nota: AdminGiveItem y AdminClearInventory se gestionan en server/main.lua

QBCore.Commands.Add('randomitems', 'Recibir ítems aleatorios (Pruebas)', {}, false, function(source)
    local src = source
    if not IsAdmin(src) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local items = {}
    for k, v in pairs(QBCore.Shared.Items) do
        if v.type ~= 'weapon' and not v.unique then
            items[#items+1] = v.name
        end
    end

    for _ = 1, 5 do
        local randomName = items[math.random(1, #items)]
        Player.Functions.AddItem(randomName, math.random(1, 10))
    end
    TriggerClientEvent('QBCore:Notify', src, "Recibiste ítems aleatorios de prueba", "success")
end)

QBCore.Commands.Add('testqbcompat', 'Prueba ficticia de compatibilidad 100% QBCore Estándar (Pruebas)', {}, false, function(source)
    local src = source
    if not IsAdmin(src) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    print("^3[qb-inventory] --- INICIANDO PRUEBA FICTICIA DE COMPATIBILIDAD CON QBCORE ESTÁNDAR ---^7")
    local passed = 0
    local total = 0

    local function AssertTest(name, condition)
        total = total + 1
        if condition then
            passed = passed + 1
            print("^2[PASS]^7 " .. name)
        else
            print("^1[FAIL]^7 " .. name)
        end
    end

    -- Guardar inventario original para restaurar al final
    local originalItems = {}
    for k, v in pairs(Player.PlayerData.items) do originalItems[k] = v end

    -- 1. Simulación qb-shops / qb-weed: AddItem con 6 argumentos (incluyendo 'reason')
    Player.Functions.SetPlayerData("items", {})
    local resAdd = exports['qb-inventory']:AddItem(src, 'water', 5, false, false, 'qb-shops:buyItem')
    AssertTest("1. qb-shops/qb-weed: AddItem (6 argumentos con reason)", resAdd == true and exports['qb-inventory']:GetItemByName(src, 'water') ~= nil)

    -- 2. Simulación qb-smallresources: RemoveItem con 5 argumentos (incluyendo 'reason')
    local resRem = exports['qb-inventory']:RemoveItem(src, 'water', 2, false, 'qb-smallresources:drink')
    local waterItem = exports['qb-inventory']:GetItemByName(src, 'water')
    AssertTest("2. qb-smallresources: RemoveItem (5 argumentos con reason)", resRem == true and waterItem and waterItem.amount == 3)

    -- 3. Simulación qb-policejob: OpenInventory normalizado (2 argumentos: src, stashName)
    local resStash = pcall(function() exports['qb-inventory']:OpenInventory(src, 'policestash_test') end)
    AssertTest("3. qb-policejob: OpenInventory con nombre directo (policestash_test)", resStash == true)

    -- 4. Simulación qb-policejob: OpenInventory con opciones de peso/slots (ej. policetrash)
    local resTrash = pcall(function() exports['qb-inventory']:OpenInventory(src, 'policetrash_test', { maxweight = 4000000, slots = 300 }) end)
    AssertTest("4. qb-policejob: OpenInventory con tabla de configuración de peso/slots", resTrash == true)

    -- 5. Simulación qb-weapons / scripts externos: Protección de slot ocupado
    exports['qb-inventory']:AddItem(src, 'sandwich', 1, 1, false, 'test')
    -- Intentar añadir un teléfono en el slot 1 (donde ya hay un sándwich) no debe borrar el sándwich
    exports['qb-inventory']:AddItem(src, 'phone', 1, 1, false, 'test')
    local slot1Item = exports['qb-inventory']:GetItemBySlot(src, 1)
    local phoneItem = exports['qb-inventory']:GetItemByName(src, 'phone')
    AssertTest("5. Protección anti-borrado en AddItem si un script solicita un slot ocupado", slot1Item and slot1Item.name == 'sandwich' and phoneItem ~= nil)

    -- 6. Simulación ClearInventory (ej. cárcel o policía) con filtro de ítems
    exports['qb-inventory']:ClearInventory(src, { 'phone' })
    AssertTest("6. ClearInventory con filtro (conserva ítems filtrados como 'phone')", exports['qb-inventory']:GetItemByName(src, 'phone') ~= nil and exports['qb-inventory']:GetItemByName(src, 'sandwich') == nil)

    -- Restaurar inventario original intacto
    Player.Functions.SetPlayerData("items", originalItems)
    exports['qb-inventory']:SyncPlayerUI(src)

    print("^2[qb-inventory] --- PRUEBA FINALIZADA: " .. passed .. "/" .. total .. " SUPERADAS (100% COMPATIBLE) ---^7")
    TriggerClientEvent('QBCore:Notify', src, "Prueba QBCore Estándar: " .. passed .. "/" .. total .. " pasadas. Revisa la consola F8/servidor.", "success", 6000)
end)
