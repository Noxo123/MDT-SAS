fx_version 'cerulean'
game 'gta5'

author 'Noxo123'
description 'Sentinel Security Agency — MDT portable'
version '0.2.0'

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

-- oxmysql est optionnel au démarrage mais requis pour conserver les données.
-- Si installé, démarre oxmysql avant cette ressource dans server.cfg.
