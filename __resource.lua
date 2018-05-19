resource_manifest_version '05cfa83c-a124-4cfa-a768-c24a5811d8f9'
description "GTA:O Vehicle Garages"

files {"garages/paleto_bay_warehouse.xml"}

client_scripts {
    "sh_config.lua",
    "cl_interior.lua",
    "@xnWarMenu/warmenu.lua",
}

server_scripts {
    "sh_config.lua",
    "sv_saving.lua",
}
