local resourceName = tostring(GetCurrentResourceName())
local function savePlayerFile(player, data)
    local fileName = GetPlayerIdentifiers(player)[2]
    local ret = SaveResourceFile(resourceName, "saves/"..fileName..".json", data, -1)
    return ret
end
local function loadPlayerFile(player)
    local fileName = GetPlayerIdentifiers(player)[2]
    local ret = LoadResourceFile(resourceName, "saves/"..fileName..".json")
    if ret then return ret else return "[]" end -- return empty table if theres no file
end

RegisterServerEvent("xnov:reqVehicles")
AddEventHandler("xnov:reqVehicles", function(player)
    local ply = player or source -- Sometimes this helps, dunno why
    local data = json.decode(loadPlayerFile(ply))
    TriggerClientEvent("xnov:recVehicles",source,data)
end)

RegisterServerEvent("xnov:saveVehicle")
AddEventHandler("xnov:saveVehicle", function(vehicleData, location, position,callback)
    local player = source -- Sometimes this helps, dunno why
    local data = json.decode(loadPlayerFile(player))
    if not data[location] then data[location] = {} end

    if not position then
        local found = false
        for i=1,#xnGarageConfig.locations[location].carLocations do
            if data[location][i] == nil or data[location][i] == "none" then
                data[location][i] = vehicleData
                found = true
                break
            end
        end
        if not found then TriggerClientEvent("xnov:savecallback", source, "no_slot") return end
    else
        data[location][position] = vehicleData
    end
    savePlayerFile(player, json.encode(data))

    TriggerClientEvent("xnov:savecallback", source, "success")
end)

RegisterServerEvent("xnov:deleteVehicle")
AddEventHandler("xnov:deleteVehicle", function(location, position)
    local player = source -- Sometimes this helps, dunno why
    local data = json.decode(loadPlayerFile(player))
    if data[location] and data[location][position] then data[location][position] = "none" end

    savePlayerFile(player, json.encode(data))

    TriggerClientEvent("xnov:message", source, "Vehicle Deleted")
end)

RegisterServerEvent("xnov:moveVehicle")
AddEventHandler("xnov:moveVehicle", function(location, oldPosition, newPosition)
    local player = source -- Sometimes this helps, dunno why
    local data = json.decode(loadPlayerFile(player))
    if data[location] then
        local oldVehicleData
        if data[location][newPosition] then
            oldVehicleData = data[location][newPosition]
        else
            oldVehicleData = "none"
        end
        print(newPosition,oldPosition,oldVehicleData)
        data[location][newPosition] = data[location][oldPosition]
        data[location][oldPosition] = oldVehicleData
    end

    savePlayerFile(player, json.encode(data))

    TriggerClientEvent("xnov:message", source, "Vehicle Moved")
end)
