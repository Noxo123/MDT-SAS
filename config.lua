Config = {}

Config.ResourceName = 'mdt-sas'
Config.Command = 'sentinel'
Config.DefaultKey = 'F6'
Config.OpenToEveryone = false

-- Permissions ACE : configure les groupes dans server.cfg.
Config.Ace = {
    use = 'mdt.sas.use',
    dispatch = 'mdt.sas.dispatch',
    supervisor = 'mdt.sas.supervisor',
    admin = 'mdt.sas.admin'
}

Config.PositionUpdateSeconds = 10
Config.MaxDispatchTitleLength = 90
Config.MaxReportLength = 4000
Config.MaxEvidenceLength = 500
Config.DailyPassageTarget = 4
Config.PassageValidationDistance = 100.0
Config.PassageCooldownSeconds = 300

-- Les quotas sont calculés sur la date locale du serveur FXServer.
-- Configure le fuseau horaire de la machine si tu veux minuit heure française.

-- Les coordonnées sont celles du monde GTA (vector3). Renseigne x, y et z
-- pour CHAQUE partenaire ; sinon les validations sont bloquées par sécurité.
Config.Partners = {
    {
        id = 'dynastie',
        name = 'Dynastie',
        address = 'Adresse RP à renseigner',
        x = nil, y = nil, z = nil,
        target = 4,
        notes = 'Consignes de sécurité à renseigner.'
    }
}

-- Base indépendante de framework. Les droits sont vérifiés via ACE.
-- Une intégration métier ESX/QBCore/Qbox pourra compléter les permissions ACE.
Config.Job = { enabled = false, name = 'sentinel' }
