Config = {}

Config.ResourceName = 'mdt-sas'
Config.Command = 'sentinel'
Config.DefaultKey = 'F6'
Config.OpenToEveryone = false

-- ACE : les contrôles d'accès sont effectués côté serveur.
Config.Ace = {
    use = 'mdt.sas.use',
    dispatch = 'mdt.sas.dispatch',
    supervisor = 'mdt.sas.supervisor',
    admin = 'mdt.sas.admin'
}

-- Suivi GPS. UnOneSync est recommandé pour lire les positions côté serveur.
Config.PositionUpdateSeconds = 10
Config.MaxPositionDistance = 5000.0
Config.MaxDispatchTitleLength = 90
Config.MaxReportLength = 4000
Config.MaxEvidenceLength = 500
Config.DailyPassageTarget = 4

-- Heure de référence : heure locale du processus serveur.
-- Pour une remise à zéro à minuit en France, configure le fuseau horaire de l'hôte correctement.
Config.ResetDailyPassages = true

-- Remplace les exemples par les véritables entreprises partenaires.
Config.Partners = {
    {
        id = 'dynastie',
        name = 'Dynastie',
        address = 'Adresse à renseigner en jeu',
        target = 4,
        notes = 'Consignes de sécurité à renseigner.'
    }
}

-- Option de filtrage par métier. La base initiale utilise les permissions ACE ;
-- branche ici un adaptateur ESX/QBCore/Qbox si tu veux vérifier le métier automatiquement.
Config.Job = {
    enabled = false,
    name = 'sentinel'
}

Config.Statuses = {
    available = 'Disponible',
    enroute = 'En route',
    onsite = 'Sur place',
    securing = 'Sécurisation',
    unavailable = 'Indisponible'
}
