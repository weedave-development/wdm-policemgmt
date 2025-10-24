fx_version 'cerulean'
game 'gta5'

name 'wdm_policemgmt'
description 'Police Management System for QBOX - Manage officers, callsigns, and ranks'
author 'WeeDave'
version '1.0.0'
repository 'https://github.com/weedave-development/wdm-policemgmt'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config/shared.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/nui.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/database.lua',
    'server/events.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*',
    'config/client.lua',
    'locales/*.json'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
