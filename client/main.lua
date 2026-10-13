local tabletOpen = false
local onDuty = false
local lastPositionSent = 0

local function setTablet(state)
    tabletOpen = state == true
    SetNuiFocus(tabletOpen, tabletOpen)
    SendNUIMessage({ action = 'setVisible', visible = tabletOpen })
    if tabletOpen then
        TriggerServerEvent('mdt-sas:server:requestState')
    end
end

RegisterCommand(Config.Command, function()
    setTablet(not tabletOpen)
end, false)

RegisterKeyMapping(Config.Command, 'Ouvrir la tablette Sentinel MDT', 'keyboard', Config.DefaultKey)

RegisterNUICallback('close', function(_, cb)
    setTablet(false)
    cb({ ok = true })
end)

RegisterNUICallback('requestState', function(_, cb)
    TriggerServerEvent('mdt-sas:server:requestState')
    cb({ ok = true })
end)

RegisterNUICallback('setDuty', function(data, cb)
    onDuty = data and data.onDuty == true
    TriggerServerEvent('mdt-sas:server:setDuty', onDuty)
    cb({ ok = true })
end)

RegisterNUICallback('setStatus', function(data, cb)
    if type(data) ~= 'table' or type(data.status) ~= 'string' then
        cb({ ok = false, error = 'Données invalides.' })
        return
    end
    TriggerServerEvent('mdt-sas:server:setStatus', data.status)
    cb({ ok = true })
end)

RegisterNUICallback('createDispatch', function(data, cb)
    TriggerServerEvent('mdt-sas:server:createDispatch', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('takeDispatch', function(data, cb)
    TriggerServerEvent('mdt-sas:server:takeDispatch', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('updateDispatchStatus', function(data, cb)
    TriggerServerEvent('mdt-sas:server:updateDispatchStatus', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('validatePassage', function(data, cb)
    TriggerServerEvent('mdt-sas:server:validatePassage', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('createReport', function(data, cb)
    TriggerServerEvent('mdt-sas:server:createReport', data or {})
    cb({ ok = true })
end)

RegisterNetEvent('mdt-sas:client:state', function(state)
    SendNUIMessage({ action = 'state', state = state })
end)

RegisterNetEvent('mdt-sas:client:toast', function(message, kind)
    SendNUIMessage({ action = 'toast', message = tostring(message or ''), kind = kind or 'info' })
end)

RegisterNetEvent('mdt-sas:client:positionUpdate', function(positions)
    SendNUIMessage({ action = 'positions', positions = positions or {} })
end)

-- Position publiée par le serveur à partir des coordonnées OneSync.
-- L'événement sert uniquement à annoncer qu'un agent en service doit être suivi.
CreateThread(function()
    while true do
        Wait(math.max(5, Config.PositionUpdateSeconds) * 1000)
        if onDuty then
            TriggerServerEvent('mdt-sas:server:heartbeat')
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
