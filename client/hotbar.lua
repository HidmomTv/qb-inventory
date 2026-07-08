-- client/hotbar.lua
local QBCore = exports['qb-core']:GetCoreObject()
local isHotbarVisible = false

-- Función para usar objeto asignado al slot rápido 1..6
local function UseQuickbarSlot(slotNum)
    if slotNum == 6 then
        TriggerEvent('qb-inventory:client:giveQuickSlot')
        return
    end

    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.items then return end

    for k, item in pairs(PlayerData.items) do
        if item and (tonumber(item.slot) == slotNum or tonumber(k) == slotNum or (item.info and tonumber(item.info.hotbarSlot) == slotNum)) then
            TriggerServerEvent('qb-inventory:server:UseItem', tonumber(item.slot) or tonumber(k) or slotNum)
            break
        end
    end
end

-- Keymappings nativos para atajos 1 al 6
for i = 1, 5 do
    RegisterCommand('quickslot_' .. i, function()
        UseQuickbarSlot(i)
    end, false)
    RegisterKeyMapping('quickslot_' .. i, 'Usar Slot Rápido ' .. i, 'keyboard', tostring(i))
end

RegisterCommand('givequick', function()
    TriggerEvent('qb-inventory:client:giveQuickSlot')
end, false)
RegisterKeyMapping('givequick', 'Entregar ítem rápido (Slot 6)', 'keyboard', '6')

CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, 37, true) -- Desactivar rueda de armas GTA V
        for i = 157, 165 do
            DisableControlAction(0, i, true) -- Desactivar selección nativa de armas GTA V (teclas 1-9)
        end

        if IsDisabledControlJustPressed(0, 20) or IsControlJustPressed(0, 20) then
            if not isHotbarVisible then
                isHotbarVisible = true
                local PlayerData = QBCore.Functions.GetPlayerData()
                SendNUIMessage({ action = "showHotbar", items = PlayerData and PlayerData.items or {} })
            end
        elseif IsDisabledControlJustReleased(0, 20) or IsControlJustReleased(0, 20) then
            if isHotbarVisible then
                isHotbarVisible = false
                SendNUIMessage({ action = "hideHotbar" })
            end
        end
    end
end)
