fx_version 'adamant'

game 'gta5'
lua54 'yes'
author "Voidline Interactive"

ui_page 'files/index.html'

client_scripts {
    'client/core.lua',
    'client/animations.lua',
    'client/enemyai.lua',
    'client/audio.lua',
    'client/blips.lua',
    'client/distance.lua',
    'client/peds.lua',
    'client/props.lua',
    'client/ipl.lua',
    'client/sequences.lua',
    'client/stealth.lua',
    'client/vehicles.lua',
    'client/vfx.lua',
    'client/vidialogue.lua',
    'client/viinteract.lua',
    'client/vilink.lua',
    'client/vinotifications.lua',
    'client/viobjectives.lua',
    'client/visubtitles.lua',
    'client/vicall.lua',
}

files {
    'files/*.html',
    'files/*.js',
    'files/*.css',
    'files/sounds/*.ogg',
    'files/sounds/*.mp3',
    'files/sounds/*.wav',
}