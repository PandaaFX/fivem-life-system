fx_version 'cerulean'
game 'gta5'
version '1.0.0'
author 'PandaaFX'
description 'Lebenssystem'

shared_script '@es_extended/imports.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@es_extended/imports.lua',
    'config/config.lua',
    'server/db.lua',
    'server/main.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}