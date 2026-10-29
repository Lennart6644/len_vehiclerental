fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'len_vehiclerental'
author 'Lennart'
description 'len_vehiclerental - Vehicle rental with insurance, damage system, debts and multilingual UI'
version '1.0.0'

dependencies {
    'es_extended',
    'oxmysql'
}

shared_scripts {
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client/keys.lua',
    'client/preview.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/vehicles/*.webp',
    'html/img/vehicles/*.png'
}
