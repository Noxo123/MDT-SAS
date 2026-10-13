fx_version 'cerulean'
game 'gta5'

author 'Noxo123'
description 'Sentinel Security Agency — MDT portable'
version '0.1.0'

lua54 'yes'

ui_page 'web/index.html'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

-- Aucune dépendance de framework obligatoire.
-- oxmysql pourra être ajouté comme dépendance optionnelle lors de l'intégration SQL.
