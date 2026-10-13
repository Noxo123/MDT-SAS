local agents = {}
local dispatches = {}
local passages = {}
local reports = {}
local nextDispatchId = 1
local nextReportId = 1

local function notify(src, message, kind)
    TriggerClientEvent('mdt-sas:client:toast', src, message, kind or 'info')
end

local function hasAce(src, ace)
    if src == 0 then return true end
    if Config.OpenToEveryone and ace == Config.Ace.use then return true end
    return IsPlayerAceAllowed(src, ace)
end

local function canUse(src)
    return hasAce(src, Config.Ace.use) or hasAce(src, Config.Ace.dispatch)
        or hasAce(src, Config.Ace.supervisor) or hasAce(src, Config.Ace.admin)
end

local function canDispatch(src)
    return hasAce(src, Config.Ace.dispatch) or hasAce(src, Config.Ace.supervisor)
        or hasAce(src, Config.Ace.admin)
end

local function canSupervise(src)
    return hasAce(src, Config.Ace.supervisor) or hasAce(src, Config.Ace.admin)
end

local function safeString(value, maxLength)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[%z\1-\8\11\12\14-\31]', '')
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function getIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _, identifier in ipairs(identifiers) do
        if identifier:sub(1, 8) == 'license:' then return identifier end
    end
    return ('source:%s'):format(src)
end

local function getName(src)
    return GetPlayerName(src) or ('Agent %s'):format(src)
end

local function getPartner(partnerId)
    for _, partner in ipairs(Config.Partners) do
        if partner.id == partnerId then return partner end
    end
    return nil
end

local function dayKey()
    return os.date('%Y-%m-%d')
end

local function getPassageCount(partnerId)
    local count = 0
    for _, passage in ipairs(passages) do
        if passage.partnerId == partnerId and passage.day == dayKey() and passage.status == 'validated' then
            count = count + 1
        end
    end
    return count
end

local function getPublicAgents()
    local result = {}
    for src, agent in pairs(agents) do
        if GetPlayerName(src) and agent.onDuty then
            local ped = GetPlayerPed(src)
            local coords = ped and ped ~= 0 and GetEntityCoords(ped) or nil
            result[#result + 1] = {
                source = src,
                name = agent.name,
                status = agent.status,
                onDuty = agent.onDuty,
                x = coords and coords.x or nil,
                y = coords and coords.y or nil,
                z = coords and coords.z or nil,
                updatedAt = agent.updatedAt
            }
        end
    end
    return result
end

local function buildState(src)
    local agent = agents[src] or {
        name = getName(src),
        onDuty = false,
        status = 'unavailable'
    }

    local partners = {}
    for _, partner in ipairs(Config.Partners) do
        partners[#partners + 1] = {
            id = partner.id,
            name = partner.name,
            address = partner.address,
            notes = partner.notes,
            target = partner.target or Config.DailyPassageTarget,
            count = getPassageCount(partner.id)
        }
    end

    local visibleDispatches = {}
    for _, dispatch in pairs(dispatches) do
        visibleDispatches[#visibleDispatches + 1] = dispatch
    end
    table.sort(visibleDispatches, function(a, b) return a.createdAt > b.createdAt end)

    local visiblePassages = {}
    for i = #passages, math.max(1, #passages - 49), -1 do
        local p = passages[i]
        if p then visiblePassages[#visiblePassages + 1] = p end
    end

    local visibleReports = {}
    for i = #reports, math.max(1, #reports - 49), -1 do
        local r = reports[i]
        if r then visibleReports[#visibleReports + 1] = r end
    end

    return {
        me = {
            name = agent.name or getName(src),
            onDuty = agent.onDuty == true,
            status = agent.status or 'unavailable',
            permissions = {
                dispatch = canDispatch(src),
                supervisor = canSupervise(src),
                admin = hasAce(src, Config.Ace.admin)
            }
        },
        partners = partners,
        dispatches = visibleDispatches,
        passages = visiblePassages,
        reports = visibleReports,
        agents = getPublicAgents(),
        serverTime = os.date('%Y-%m-%d %H:%M:%S')
    }
end

local function broadcastPositions()
    local positions = getPublicAgents()
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and canUse(src) then
            TriggerClientEvent('mdt-sas:client:positionUpdate', src, positions)
        end
    end
end

RegisterNetEvent('mdt-sas:server:requestState', function()
    local src = source
    if not canUse(src) then
        notify(src, 'Accès refusé à Sentinel MDT.', 'error')
        return
    end
    TriggerClientEvent('mdt-sas:client:state', src, buildState(src))
end)

RegisterNetEvent('mdt-sas:server:setDuty', function(enabled)
    local src = source
    if not canUse(src) then return end
    if type(enabled) ~= 'boolean' then return end

    agents[src] = agents[src] or { name = getName(src), status = 'available' }
    agents[src].name = getName(src)
    agents[src].onDuty = enabled
    agents[src].status = enabled and 'available' or 'unavailable'
    agents[src].updatedAt = os.time()
    notify(src, enabled and 'Prise de service enregistrée.' or 'Fin de service enregistrée.', 'success')
    TriggerClientEvent('mdt-sas:client:state', src, buildState(src))
    broadcastPositions()
end)

RegisterNetEvent('mdt-sas:server:setStatus', function(status)
    local src = source
    if not canUse(src) or not agents[src] or not agents[src].onDuty then return end
    local allowed = { available = true, enroute = true, onsite = true, securing = true, unavailable = true }
    if not allowed[status] then return end
    agents[src].status = status
    agents[src].updatedAt = os.time()
    broadcastPositions()
    TriggerClientEvent('mdt-sas:client:state', src, buildState(src))
end)

RegisterNetEvent('mdt-sas:server:heartbeat', function()
    local src = source
    if not canUse(src) or not agents[src] or not agents[src].onDuty then return end
    agents[src].updatedAt = os.time()
    broadcastPositions()
end)

RegisterNetEvent('mdt-sas:server:createDispatch', function(data)
    local src = source
    if not canDispatch(src) then
        notify(src, 'Tu ne disposes pas du droit de créer un dispatch.', 'error')
        return
    end
    if type(data) ~= 'table' then return end
    local title = safeString(data.title, Config.MaxDispatchTitleLength)
    local description = safeString(data.description, 1000)
    local partnerId = safeString(data.partnerId, 80)
    if title == '' then
        notify(src, 'Le titre du dispatch est obligatoire.', 'error')
        return
    end
    if partnerId ~= '' and not getPartner(partnerId) then
        notify(src, 'Partenaire inconnu.', 'error')
        return
    end

    local id = tostring(nextDispatchId)
    nextDispatchId = nextDispatchId + 1
    dispatches[id] = {
        id = id,
        title = title,
        description = description,
        partnerId = partnerId,
        createdBy = getName(src),
        createdAt = os.time(),
        status = 'open',
        assignedTo = nil
    }
    notify(src, 'Dispatch créé.', 'success')
    TriggerClientEvent('mdt-sas:client:state', src, buildState(src))
end)

RegisterNetEvent('mdt-sas:server:takeDispatch', function(dispatchId)
    local src = source
    if not canUse(src) or type(dispatchId) ~= 'string' then return end
    local dispatch = dispatches[dispatchId]
    if not dispatch or dispatch.status ~= 'open' then
        notify(src, 'Ce dispatch n’est plus disponible.', 'error')
        return
    end
    if not agents[src] or not agents[src].onDuty then
        notify(src, 'Tu dois être en service pour prendre un dispatch.', 'error')
        return
    end
    dispatch.status = 'enroute'
    dispatch.assignedTo = getName(src)
    dispatch.assignedSource = src
    dispatch.takenAt = os.time()
    agents[src].status = 'enroute'
    agents[src].dispatchId = dispatchId
    broadcastPositions()
    notify(src, 'Dispatch pris en charge. GPS actualisé.', 'success')
    TriggerClientEvent('mdt-sas:client:state', src, buildState(src))
end)

RegisterNetEvent('mdt-sas:server:updateDispatchStatus', function(data)
    local src = source
    if not canUse(src) or type(data) ~= 'table' then return end
    local dispatch = dispatches[tostring(data.id or '')]
    if not dispatch then return end
    if dispatch.assignedSource ~= src and not canSupervise(src) then
        notify(src, 'Tu ne peux pas modifier ce dispatch.', 'error')
        return
    end
    local allowed = { enroute = true, onsite = true, securing = true, completed = true, cancelled = true }
    if not allowed[data.status] then return end
    dispatch.status = data.status
    dispatch.updatedAt = os.time()
    if data.status == 'completed' or data.status == 'cancelled' then
        local agent = agents[dispatch.assignedSource]
        if agent then
            agent.status = 'available'
            agent.dispatchId = nil
        end
    elseif agents[src] then
        agents[src].status = data.status
    end
    notify(src, 'Statut du dispatch mis à jour.', 'success')
    TriggerClientEvent('mdt-sas:client:state', src, buildState(src))
    broadcastPositions()
end)

RegisterNetEvent('mdt-sas:server:validatePassage', function(data)
    local src = source
    if not canUse(src) or type(data) ~= 'table' then return end
    if not agents[src] or not agents[src].onDuty then
        notify(src, 'Tu dois être en service pour valider un passage.', 'error')
        return
    end
    local partnerId = safeString(data.partnerId, 80)
    local partner = getPartner(partnerId)
    if not partner then
        notify(src, 'Partenaire inconnu.', 'error')
        return
    end

    -- Vérification serveur de proximité : la position client n'est jamais acceptée comme preuve.
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        notify(src, 'Position du personnage indisponible.', 'error')
        return
    end
    local coords = GetEntityCoords(ped)
    local px, py, pz = tonumber(partner.x), tonumber(partner.y), tonumber(partner.z)
    if not px or not py or not pz then
        notify(src, 'Les coordonnées du partenaire doivent être configurées dans config.lua avant validation.', 'error')
        return
    end
    local distance = #(coords - vector3(px, py, pz))
    if distance > 100.0 then
        notify(src, 'Tu dois être à proximité du partenaire pour valider le passage.', 'error')
        return
    end

    local evidence = safeString(data.evidence, Config.MaxEvidenceLength)
    local passage = {
        id = ('P-%s-%s'):format(os.time(), #passages + 1),
        partnerId = partnerId,
        partnerName = partner.name,
        agent = getName(src),
        identifier = getIdentifier(src),
        time = os.date('%H:%M:%S'),
        timestamp = os.time(),
        day = dayKey(),
        status = evidence ~= '' and 'validated' or 'pending_evidence',
        evidence = evidence,
        x = coords.x, y = coords.y, z = coords.z
    }
    passages[#passages + 1] = passage
    notify(src, evidence ~= '' and 'Passage enregistré.' or 'Passage enregistré en attente de preuve photo.', 'success')
    TriggerClientEvent('mdt-sas:client:state', src, buildState(src))
end)

RegisterNetEvent('mdt-sas:server:createReport', function(data)
    local src = source
    if not canUse(src) or type(data) ~= 'table' then return end
    local title = safeString(data.title, 120)
    local body = safeString(data.body, Config.MaxReportLength)
    if title == '' or body == '' then
        notify(src, 'Le titre et le contenu du rapport sont obligatoires.', 'error')
        return
    end
    local report = {
        id = tostring(nextReportId),
        title = title,
        body = body,
        author = getName(src),
        identifier = getIdentifier(src),
        timestamp = os.time(),
        createdAt = os.date('%Y-%m-%d %H:%M:%S')
    }
    nextReportId = nextReportId + 1
    reports[#reports + 1] = report
    notify(src, 'Rapport enregistré.', 'success')
    TriggerClientEvent('mdt-sas:client:state', src, buildState(src))
end)

AddEventHandler('playerDropped', function()
    local src = source
    agents[src] = nil
    for _, dispatch in pairs(dispatches) do
        if dispatch.assignedSource == src and dispatch.status ~= 'completed' then
            dispatch.status = 'open'
            dispatch.assignedTo = nil
            dispatch.assignedSource = nil
        end
    end
    broadcastPositions()
end)

CreateThread(function()
    while true do
        Wait(math.max(5, Config.PositionUpdateSeconds) * 1000)
        broadcastPositions()
    end
end)

print(('[%s] MDT SAS initialisé. Framework indépendant, permissions ACE.'):format(GetCurrentResourceName()))
