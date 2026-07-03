fx_version 'cerulean'
game 'gta5'

author 'HidmomTv (fork of qb-inventory by QBCore Framework)'
description 'qb-inventory rework — fork of https://github.com/qbcore-framework/qb-inventory'
version '2.0.0'
provide 'qb-inventory'
repository 'https://github.com/HidmomTv/qb-inventory'

export 'HasItem'
export 'OpenTrunk'
export 'OpenGlovebox'
export 'OpenStash'
export 'OpenShop'
export 'CreateShop'
export 'SyncPlayerUI'

shared_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/es.lua',
    'config/config.lua',
    'config/backpacks.lua',
    'config/vehicles.lua'
}

client_scripts {
    'client/main.lua',
    'client/drops.lua',
    'client/vehicles.lua',
    'client/clothing.lua',
    'client/loot.lua',
    'client/rob.lua',
    'client/crafting.lua',
    'client/weapons.lua',
    'client/hotbar.lua'
}

server_scripts {
    'server/main.lua',
    'server/items.lua',
    'server/commands.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/*.png',
    'html/images/*.PNG',
    'html/images/*.jpg',
    'html/images/*.webp'
}

lua54 'yes'
