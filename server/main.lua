local agents, dispatches, passages, reports, partners = {}, {}, {}, {}, {}
local nextDispatchId, nextReportId, nextPassageId = 1, 1, 1
local dbEnabled = false

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
    value = value:gsub('[%z\\1-\\8\\11\\12\\14-\\31]', '')
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function getIdentifier(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' then return identifier end
    end
    return ('source:%s'):format(src)
end

local function getName(src)
    return GetPlayerName(src) or ('Agent %s'):format(src)
end

local function sql(query, params, mode)
    if not dbEnabled or not MySQL then return nil end
    local ok, result = pcall(function()
        if mode == 'insert' then return MySQL.insert.await(query, params or {}) end
        if mode == 'update' then return MySQL.update.await(query, params or {}) end
        return MySQL.query.await(query, params or {})
    end)
    if not ok then
        print(('[mdt-sas] SQL error: %s'):format(tostring(result)))
        return nil
    end
    return result
end

local function getPartner(partnerId)
    return partners[partnerId]
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
                source = src, name = agent.name, status = agent.status, onDuty = true,
                x = coords and coords.x or nil, y = coords and coords.y or nil,
                z = coords and coords.z or nil, updatedAt = agent.updatedAt
            }
        end
    end
    return result
end

local function buildState(src)
    local agent = agents[src] or { name = getName(src), onDuty = false, status = 'unavailable' }
    local partnerList = {}
    for _, partner in pairs(partners) do
        partnerList[#partnerList + 1] = {
            id = partner.id, name = partner.name, address = partner.address,
            notes = partner.notes, x = partner.x, y = partner.y, z = partner.z,
            target = partner.target or Config.DailyPassageTarget, count = getPassageCount(partner.id)
        }
    end
    table.sort(partnerList, function(a, b) return a.name < b.name end)

    local dispatchList = {}
    for _, dispatch in pairs(dispatches) do dispatchList[#dispatchList + 1] = dispatch end
    table.sort(dispatchList, function(a, b) return a.createdAt > b.createdAt end)

    local passageList = {}
    for i = #passages, math.max(1, #passages - 99), -1 do
        if passages[i] then passageList[#passageList + 1] = passages[i] end
    end
    local reportList = {}
    for i = #reports, math.max(1, #reports - 99), -1 do
        if reports[i] then reportList[#reportList + 1] = reports[i] end
    end

    return {
        me = {
            name = agent.name or getName(src), onDuty = agent.onDuty == true,
            status = agent.status or 'unavailable',
            permissions = { dispatch = canDispatch(src), supervisor = canSupervise(src), admin = hasAce(src, Config.Ace.admin) }
        },
        partners = partnerList, dispatches = dispatchList, passages = passageList,
        reports = reportList, agents = getPublicAgents(), serverTime = os.date('%Y-%m-%d %H:%M:%S'),
        today = dayKey(), persistent = dbEnabled
    }
end

local function sendState(src)
    if GetPlayerName(src) then TriggerClientEvent('mdt-sas:client:state', src, buildState(src)) end
end

local function broadcastState()
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and canUse(src) then sendState(src) end
    end
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

local function persistAgent(src, agent)
    if not dbEnabled then return end
    sql([[
        INSERT INTO mdt_sas_agents (identifier, display_name, grade, on_duty, status)
        VALUES (?, ?, 'agent', ?, ?)
        ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), on_duty = VALUES(on_duty), status = VALUES(status)
    ]], { getIdentifier(src), agent.name, agent.onDuty and 1 or 0, agent.status }, 'insert')
end

local function loadDatabase()
    local deadline = GetGameTimer() + 30000
    while GetResourceState('oxmysql') == 'starting' and GetGameTimer() < deadline do Wait(250) end
    if GetResourceState('oxmysql') ~= 'started' or not MySQL or not MySQL.query then
        print('[mdt-sas] oxmysql absent : mode mémoire (données perdues au redémarrage).')
    else
        local ok = pcall(function() MySQL.query.await('SELECT id FROM mdt_sas_partners LIMIT 1') end)
        if ok then
            dbEnabled = true
            print('[mdt-sas] Connexion oxmysql active.')
            for _, configured in ipairs(Config.Partners) do
                sql([[
                    INSERT INTO mdt_sas_partners (id, name, address, x, y, z, daily_target, notes, active)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
                    ON DUPLICATE KEY UPDATE name = VALUES(name), address = VALUES(address),
                    x = VALUES(x), y = VALUES(y), z = VALUES(z), daily_target = VALUES(daily_target),
                    notes = VALUES(notes), active = 1
                ]], { configured.id, configured.name, configured.address or '', configured.x, configured.y, configured.z,
                    configured.target or Config.DailyPassageTarget, configured.notes or '' }, 'insert')
            end
            local partnerRows = sql('SELECT * FROM mdt_sas_partners WHERE active = 1', {}, 'query') or {}
            for _, p in ipairs(partnerRows) do
                partners[p.id] = { id = p.id, name = p.name, address = p.address, x = p.x, y = p.y, z = p.z,
                    target = tonumber(p.daily_target) or Config.DailyPassageTarget, notes = p.notes or '' }
            end
            local agentRows = sql('SELECT a.identifier, a.display_name, a.grade, a.on_duty, a.status FROM mdt_sas_agents a', {}, 'query') or {}
            -- Stored agents are historical profiles only; no player is automatically marked on duty after a restart.
            for _, a in ipairs(agentRows) do
                sql('UPDATE mdt_sas_agents SET on_duty = 0, status = \'unavailable\' WHERE identifier = ?', { a.identifier }, 'update')
            end
            local dispatchRows = sql('SELECT * FROM mdt_sas_dispatches ORDER BY id DESC LIMIT 500', {}, 'query') or {}
            for _, d in ipairs(dispatchRows) do
                local status = d.status
                if status ~= 'completed' and status ~= 'cancelled' then status = 'open' end
                dispatches[tostring(d.id)] = { id = tostring(d.id), title = d.title, description = d.description or '',
                    partnerId = d.partner_id or '', createdBy = d.created_by, createdAt = d.created_at and os.time() or 0,
                    status = status, assignedTo = nil, assignedIdentifier = d.assigned_identifier }
                nextDispatchId = math.max(nextDispatchId, (tonumber(d.id) or 0) + 1)
            end
            local passageRows = sql([[
                SELECT p.*, DATE_FORMAT(p.passage_day, '%Y-%m-%d') AS day_string,
                       DATE_FORMAT(p.created_at, '%H:%i:%s') AS time_string, b.name AS partner_name
                FROM mdt_sas_passages p LEFT JOIN mdt_sas_partners b ON b.id = p.partner_id
                ORDER BY p.id DESC LIMIT 5000
            ]], {}, 'query') or {}
            for _, p in ipairs(passageRows) do
                passages[#passages + 1] = { id = tostring(p.id), partnerId = p.partner_id,
                    partnerName = p.partner_name or p.partner_id, agent = p.agent_name, identifier = p.agent_identifier,
                    status = p.status, evidence = p.evidence_reference or '', day = p.day_string or tostring(p.passage_day),
                    time = p.time_string or '', timestamp = 0, x = p.x, y = p.y, z = p.z }
                nextPassageId = math.max(nextPassageId, (tonumber(p.id) or 0) + 1)
            end
            local reportRows = sql('SELECT * FROM mdt_sas_reports ORDER BY id DESC LIMIT 500', {}, 'query') or {}
            for _, r in ipairs(reportRows) do
                reports[#reports + 1] = { id = tostring(r.id), title = r.title, body = r.body,
                    author = r.author_name, identifier = r.author_identifier, createdAt = tostring(r.created_at or ''),
                    timestamp = 0 }
                nextReportId = math.max(nextReportId, (tonumber(r.id) or 0) + 1)
            end
        else
            print('[mdt-sas] Tables SQL introuvables. Importe sql/install.sql ; mode mémoire activé.')
        end
    end
    if not next(partners) then
        for _, p in ipairs(Config.Partners) do partners[p.id] = p end
    end
    print(('[%s] MDT prêt (%s).'):format(GetCurrentResourceName(), dbEnabled and 'SQL persistant' or 'mémoire temporaire'))
end

CreateThread(loadDatabase)

RegisterNetEvent('mdt-sas:server:requestState', function()
    local src = source
    if not canUse(src) then notify(src, 'Accès refusé à Sentinel MDT.', 'error'); return end
    sendState(src)
end)

RegisterNetEvent('mdt-sas:server:setDuty', function(enabled)
    local src = source
    if not canUse(src) or type(enabled) ~= 'boolean' then return end
    agents[src] = agents[src] or { name = getName(src), status = 'available' }
    agents[src].name, agents[src].onDuty = getName(src), enabled
    agents[src].status = enabled and 'available' or 'unavailable'
    agents[src].updatedAt = os.time()
    persistAgent(src, agents[src])
    notify(src, enabled and 'Prise de service enregistrée.' or 'Fin de service enregistrée.', 'success')
    broadcastState()
    broadcastPositions()
end)

RegisterNetEvent('mdt-sas:server:setStatus', function(status)
    local src = source
    if not canUse(src) or not agents[src] or not agents[src].onDuty then return end
    if not ({ available = true, enroute = true, onsite = true, securing = true, unavailable = true })[status] then return end
    agents[src].status, agents[src].updatedAt = status, os.time()
    persistAgent(src, agents[src])
    broadcastState()
    broadcastPositions()
end)

RegisterNetEvent('mdt-sas:server:heartbeat', function()
    local src = source
    if not canUse(src) or not agents[src] or not agents[src].onDuty then return end
    agents[src].updatedAt = os.time()
    broadcastPositions()
end)

RegisterNetEvent('mdt-sas:server:createDispatch', function(data)
    local src = source
    if not canDispatch(src) then notify(src, 'Droit de dispatch requis.', 'error'); return end
    if type(data) ~= 'table' then return end
    local title = safeString(data.title, Config.MaxDispatchTitleLength)
    local description = safeString(data.description, 1000)
    local partnerId = safeString(data.partnerId, 80)
    if title == '' then notify(src, 'Le titre est obligatoire.', 'error'); return end
    if partnerId ~= '' and not getPartner(partnerId) then notify(src, 'Partenaire inconnu.', 'error'); return end

    local id
    if dbEnabled then
        id = sql('INSERT INTO mdt_sas_dispatches (title, description, partner_id, status, created_by) VALUES (?, ?, ?, \'open\', ?)',
            { title, description, partnerId ~= '' and partnerId or nil, getName(src) }, 'insert')
    end
    id = tostring(id or nextDispatchId)
    nextDispatchId = math.max(nextDispatchId, (tonumber(id) or 0) + 1)
    dispatches[id] = { id = id, title = title, description = description, partnerId = partnerId,
        createdBy = getName(src), createdAt = os.time(), status = 'open' }
    notify(src, 'Dispatch créé.', 'success')
    broadcastState()
end)

RegisterNetEvent('mdt-sas:server:takeDispatch', function(dispatchId)
    local src = source
    if not canUse(src) or type(dispatchId) ~= 'string' then return end
    local dispatch = dispatches[dispatchId]
    if not dispatch or dispatch.status ~= 'open' then notify(src, 'Dispatch indisponible.', 'error'); return end
    if not agents[src] or not agents[src].onDuty then notify(src, 'Tu dois être en service.', 'error'); return end
    dispatch.status, dispatch.assignedTo, dispatch.assignedSource = 'enroute', getName(src), src
    dispatch.assignedIdentifier, dispatch.takenAt = getIdentifier(src), os.time()
    agents[src].status, agents[src].dispatchId = 'enroute', dispatchId
    if dbEnabled then
        sql('UPDATE mdt_sas_dispatches SET status = \'enroute\', assigned_identifier = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
            { getIdentifier(src), tonumber(dispatchId) }, 'update')
    end
    persistAgent(src, agents[src])
    notify(src, 'Dispatch pris en charge. Ta position GPS est suivie.', 'success')
    broadcastState()
    broadcastPositions()
end)

RegisterNetEvent('mdt-sas:server:updateDispatchStatus', function(data)
    local src = source
    if not canUse(src) or type(data) ~= 'table' then return end
    local dispatch = dispatches[tostring(data.id or '')]
    if not dispatch then return end
    if dispatch.assignedSource ~= src and dispatch.assignedIdentifier ~= getIdentifier(src) and not canSupervise(src) then
        notify(src, 'Tu ne peux pas modifier ce dispatch.', 'error'); return
    end
    local allowed = { enroute = true, onsite = true, securing = true, completed = true, cancelled = true }
    if not allowed[data.status] then return end
    dispatch.status, dispatch.updatedAt = data.status, os.time()
    if dbEnabled then
        sql('UPDATE mdt_sas_dispatches SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
            { data.status, tonumber(dispatch.id) }, 'update')
    end
    if data.status == 'completed' or data.status == 'cancelled' then
        local agent = dispatch.assignedSource and agents[dispatch.assignedSource]
        if agent then agent.status, agent.dispatchId = 'available', nil; persistAgent(dispatch.assignedSource, agent) end
        dispatch.assignedSource = nil
    elseif agents[src] then
        agents[src].status = data.status
        persistAgent(src, agents[src])
    end
    notify(src, 'Statut du dispatch mis à jour.', 'success')
    broadcastState()
    broadcastPositions()
end)

RegisterNetEvent('mdt-sas:server:validatePassage', function(data)
    local src = source
    if not canUse(src) or type(data) ~= 'table' then return end
    if not agents[src] or not agents[src].onDuty then notify(src, 'Tu dois être en service.', 'error'); return end
    local partnerId = safeString(data.partnerId, 80)
    local partner = getPartner(partnerId)
    if not partner then notify(src, 'Partenaire inconnu.', 'error'); return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then notify(src, 'Position indisponible.', 'error'); return end
    local coords = GetEntityCoords(ped)
    local px, py, pz = tonumber(partner.x), tonumber(partner.y), tonumber(partner.z)
    if not px or not py or not pz then
        notify(src, 'Coordonnées du partenaire manquantes : renseigne x, y, z dans config.lua.', 'error'); return
    end
    if #(coords - vector3(px, py, pz)) > 100.0 then
        notify(src, 'Tu dois être à moins de 100 mètres du partenaire.', 'error'); return
    end
    local evidence = safeString(data.evidence, Config.MaxEvidenceLength)
    if evidence == '' then notify(src, 'Une référence de preuve photo est obligatoire.', 'error'); return end

    -- Une URL saisie ne suffit pas à garantir une photo authentique : toute preuve passe en revue superviseur.
    local passageId = nil
    if dbEnabled then
        passageId = sql([[
            INSERT INTO mdt_sas_passages
              (partner_id, agent_identifier, agent_name, status, evidence_reference, x, y, z, passage_day)
            VALUES (?, ?, ?, 'pending_review', ?, ?, ?, ?, ?)
        ]], { partnerId, getIdentifier(src), getName(src), evidence, coords.x, coords.y, coords.z, dayKey() }, 'insert')
    end
    passageId = tostring(passageId or nextPassageId)
    nextPassageId = math.max(nextPassageId, (tonumber(passageId) or 0) + 1)
    passages[#passages + 1] = { id = passageId, partnerId = partnerId, partnerName = partner.name,
        agent = getName(src), identifier = getIdentifier(src), time = os.date('%H:%M:%S'),
        timestamp = os.time(), day = dayKey(), status = 'pending_review', evidence = evidence,
        x = coords.x, y = coords.y, z = coords.z }
    notify(src, 'Passage transmis pour validation par un superviseur.', 'success')
    broadcastState()
end)

RegisterNetEvent('mdt-sas:server:reviewPassage', function(data)
    local src = source
    if not canSupervise(src) or type(data) ~= 'table' then notify(src, 'Droits superviseur requis.', 'error'); return end
    local passage = nil
    for _, item in ipairs(passages) do
        if tostring(item.id) == tostring(data.id) then passage = item; break end
    end
    if not passage or passage.status ~= 'pending_review' then notify(src, 'Ce passage est déjà traité ou introuvable.', 'error'); return end
    local decision = data.decision
    if decision ~= 'validated' and decision ~= 'rejected' then return end
    passage.status = decision
    passage.reviewedBy = getName(src)
    passage.reviewedAt = os.time()
    if dbEnabled then
        sql('UPDATE mdt_sas_passages SET status = ? WHERE id = ?', { decision, tonumber(passage.id) }, 'update')
        sql('INSERT INTO mdt_sas_audit (actor_identifier, actor_name, action, details) VALUES (?, ?, ?, ?)',
            { getIdentifier(src), getName(src), 'passage.' .. decision,
              json.encode({ passageId = passage.id, partnerId = passage.partnerId, agent = passage.agent }) }, 'insert')
    end
    notify(src, decision == 'validated' and 'Passage validé : quota mis à jour.' or 'Passage refusé.', 'success')
    broadcastState()
end)

RegisterNetEvent('mdt-sas:server:createReport', function(data)
    local src = source
    if not canUse(src) or type(data) ~= 'table' then return end
    local title, body = safeString(data.title, 120), safeString(data.body, Config.MaxReportLength)
    if title == '' or body == '' then notify(src, 'Titre et contenu obligatoires.', 'error'); return end
    local id
    if dbEnabled then
        id = sql('INSERT INTO mdt_sas_reports (title, body, author_identifier, author_name) VALUES (?, ?, ?, ?)',
            { title, body, getIdentifier(src), getName(src) }, 'insert')
    end
    id = tostring(id or nextReportId)
    nextReportId = math.max(nextReportId, (tonumber(id) or 0) + 1)
    reports[#reports + 1] = { id = id, title = title, body = body, author = getName(src),
        identifier = getIdentifier(src), timestamp = os.time(), createdAt = os.date('%Y-%m-%d %H:%M:%S') }
    if dbEnabled then
        sql('INSERT INTO mdt_sas_audit (actor_identifier, actor_name, action, details) VALUES (?, ?, ?, ?)',
            { getIdentifier(src), getName(src), 'report.created', json.encode({ reportId = id, title = title }) }, 'insert')
    end
    notify(src, 'Rapport enregistré.', 'success')
    broadcastState()
end)

AddEventHandler('playerDropped', function()
    local src = source
    local agent = agents[src]
    if agent then
        agent.onDuty, agent.status = false, 'unavailable'
        persistAgent(src, agent)
    end
    agents[src] = nil
    for _, dispatch in pairs(dispatches) do
        if dispatch.assignedSource == src and dispatch.status ~= 'completed' and dispatch.status ~= 'cancelled' then
            dispatch.status, dispatch.assignedTo, dispatch.assignedSource = 'open', nil, nil
            if dbEnabled then
                sql('UPDATE mdt_sas_dispatches SET status = \'open\', assigned_identifier = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                    { tonumber(dispatch.id) }, 'update')
            end
        end
    end
    broadcastState()
    broadcastPositions()
end)

CreateThread(function()
    while true do
        Wait(math.max(5, Config.PositionUpdateSeconds) * 1000)
        broadcastPositions()
    end
end)
