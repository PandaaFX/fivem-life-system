fx_version 'cerulean'
game 'gta5'
version '1.0.0'
author 'PandaaFX'
description 'Lebenssystem'

shared_scripts {
    '@es_extended/imports.lua',
    'locale.lua',
    'locales/*.lua'
}

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