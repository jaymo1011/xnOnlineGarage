Citizen.CreateThread(function()
while not xnGarageConfig do Citizen.Wait(0) end

AddTextEntry("XNOV_ENTER", "Press ~INPUT_CONTEXT~ to enter your garage.")

xnGarage_default = {
    vehicleTaken = false,
    vehicleTakenPos = false,
    curGarage = false,
    curGarageName = false,
    vehicles = {},
} xnGarage = xnGarage or xnGarage_default

local vehicleTable

function GetVehicle(ply,doesNotNeedToBeDriver)
	local found = false
	local ped = GetPlayerPed((ply and ply or -1))
	local veh = 0
	if IsPedInAnyVehicle(ped) then
		 veh = GetVehiclePedIsIn(ped, false)
	end
	if veh ~= 0 then
		if GetPedInVehicleSeat(veh, -1) == ped or doesNotNeedToBeDriver then
			found = true
		end
	end
	return found, veh, (veh ~= 0 and GetEntityModel(veh) or 0)
end

local lock_fancyteleport = false
local function FancyTeleport(ent,x,y,z,h,fOut,hold,fIn,resetCam)
    if not lock_fancyteleport then
        lock_fancyteleport = true
        Citizen.CreateThread(function() Citizen.Wait(15000) DoScreenFadeIn(500) end)
        Citizen.CreateThread(function()
            FreezeEntityPosition(ent, true)

            DoScreenFadeOut(fOut or 500)
            while IsScreenFadingOut() do Citizen.Wait(0) end

            SetEntityCoords(ent, x, y, z)
            if h then SetEntityHeading(ent, h) SetGameplayCamRelativeHeading(0) end
            if GetVehicle() then SetVehicleOnGroundProperly(ent) end
            FreezeEntityPosition(ent, false)

            Citizen.Wait(hold or 5000)

            DoScreenFadeIn(fIn or 500)
            while IsScreenFadingIn() do Citizen.Wait(0) end

            lock_fancyteleport = false
        end)
    end
end

local function ToCoord(t,withHeading)
    if withHeading == true then
        local h = (t[4]+0.0) or 0.0
        return (t[1]+0.0),(t[2]+0.0),(t[3]+0.0),h
    elseif withHeading == "only" then
        local h = (t[4]+0.0) or 0.0
        return h
    else
        return (t[1]+0.0),(t[2]+0.0),(t[3]+0.0)
    end
end

-- These vehicle functions are not /fully/ mine.
-- I forgot where I took the originals from but I *did* modify them for my own use.
-- Credit to whoever actually made the original functions.
local function DoesVehicleHaveExtras( veh )
    for i = 1, 30 do
        if ( DoesExtraExist( veh, i ) ) then
            return true
        end
    end

    return false
end

local function VehicleToData(veh)
	local vehicleTableData = {}

	local model = GetEntityModel( veh )
	local primaryColour, secondaryColour = GetVehicleColours( veh )
	local pearlColour, wheelColour = GetVehicleExtraColours( veh )
	local mod1a, mod1b, mod1c = GetVehicleModColor_1( veh )
	local mod2a, mod2b = GetVehicleModColor_2( veh )
	local custR1, custG2, custB3, custR2, custG2, custB2

	if ( GetIsVehiclePrimaryColourCustom( veh ) ) then
		custR1, custG1, custB1 = GetVehicleCustomPrimaryColour( veh )
	end

	if ( GetIsVehicleSecondaryColourCustom( veh ) ) then
		custR2, custG2, custB2 = GetVehicleCustomSecondaryColour( veh )
	end

	vehicleTableData[ "model" ] = tostring( model )
	vehicleTableData[ "primaryColour" ] = primaryColour
	vehicleTableData[ "secondaryColour" ] = secondaryColour
	vehicleTableData[ "pearlColour" ] = pearlColour
	vehicleTableData[ "wheelColour" ] = wheelColour
	vehicleTableData[ "mod1Colour" ] = { mod1a, mod1b, mod1c }
	vehicleTableData[ "mod2Colour" ] = { mod2a, mod2b }
	vehicleTableData[ "custPrimaryColour" ] =  { custR1, custG1, custB1 }
	vehicleTableData[ "custSecondaryColour" ] = { custR2, custG2, custB2 }

	local livery = GetVehicleLivery( veh )
	local plateText = GetVehicleNumberPlateText( veh )
	local plateType = GetVehicleNumberPlateTextIndex( veh )
	local wheelType = GetVehicleWheelType( veh )
	local windowTint = GetVehicleWindowTint( veh )
	local burstableTyres = GetVehicleTyresCanBurst( veh )
	local customTyres = GetVehicleModVariation( veh, 23 )

	vehicleTableData[ "livery" ] = livery
	vehicleTableData[ "plateText" ] = plateText
	vehicleTableData[ "plateType" ] = plateType
	vehicleTableData[ "wheelType" ] = wheelType
	vehicleTableData[ "windowTint" ] = windowTint
	vehicleTableData[ "burstableTyres" ] = burstableTyres
	vehicleTableData[ "customTyres" ] = customTyres

	local neonR, neonG, neonB = GetVehicleNeonLightsColour( veh )
	local smokeR, smokeG, smokeB = GetVehicleTyreSmokeColor( veh )

	local neonToggles = {}

	for i = 0, 3 do
		if ( IsVehicleNeonLightEnabled( veh, i ) ) then
			table.insert( neonToggles, i )
		end
	end

	vehicleTableData[ "neonColour" ] = { neonR, neonG, neonB }
	vehicleTableData[ "smokeColour" ] = { smokeR, smokeG, smokeB }
	vehicleTableData[ "neonToggles" ] = neonToggles

	local extras = {}


	if ( DoesVehicleHaveExtras( veh ) ) then
		for i = 1, 30 do
			if ( DoesExtraExist( veh, i ) ) then
				if ( IsVehicleExtraTurnedOn( veh, i ) ) then
					table.insert( extras, i )
				end
			end
		end
	end

	vehicleTableData[ "extras" ] = extras

	local mods = {}

	for i = 0, 49 do
		local isToggle = ( i >= 17 ) and ( i <= 22 )

		if ( isToggle ) then
			mods[i] = IsToggleModOn( veh, i )
		else
			mods[i] = GetVehicleMod( veh, i )
		end
	end

	vehicleTableData[ "mods" ] = mods

	local ret = vehicleTableData

	return ret
end

local function CreateVehicleFromData(data, x,y,z,h, dontnetwork)

	local model = data[ "model" ]
	local primaryColour = data[ "primaryColour" ]
	local secondaryColour = data[ "secondaryColour" ]
	local pearlColour = data[ "pearlColour" ]
	local wheelColour = data[ "wheelColour" ]
	local mod1Colour = data[ "mod1Colour" ]
	local mod2Colour = data[ "mod2Colour" ]
	local custPrimaryColour = data[ "custPrimaryColour" ]
	local custSecondaryColour = data[ "custSecondaryColour" ]
	local livery = data[ "livery" ]
	local plateText = data[ "plateText" ]
	local plateType = data[ "plateType" ]
	local wheelType = data[ "wheelType" ]
	local windowTint = data[ "windowTint" ]
	local burstableTyres = data[ "burstableTyres" ]
	local customTyres = data[ "customTyres" ]
	local neonColour = data[ "neonColour" ]
	local smokeColour = data[ "smokeColour" ]
	local neonToggles = data[ "neonToggles" ]
	local extras = data[ "extras" ]
	local mods = data[ "mods" ]

	local veh = CreateVehicle(tonumber(model), x,y,z,h,not dontnetwork)

	-- Set the mod kit to 0, this is so we can do shit to the car
	SetVehicleModKit( veh, 0 )

	SetVehicleTyresCanBurst( veh, burstableTyres )
	SetVehicleNumberPlateTextIndex( veh,  plateType )
	SetVehicleNumberPlateText( veh, plateText )
	SetVehicleWindowTint( veh, windowTint )
	SetVehicleWheelType( veh, wheelType )

	for i = 1, 30 do
		if ( DoesExtraExist( veh, i ) ) then
			SetVehicleExtra( veh, i, true )
		end
	end

	for k, v in pairs( extras ) do
		local extra = tonumber( v )
		SetVehicleExtra( veh, extra, false )
	end

	for k, v in pairs( mods ) do
		local k = tonumber( k )
		local isToggle = ( k >= 17 ) and ( k <= 22 )

		if ( isToggle ) then
			ToggleVehicleMod( veh, k, v )
		else
			SetVehicleMod( veh, k, v, 0 )
		end
	end

	local currentMod = GetVehicleMod( veh, 23 )
	SetVehicleMod( veh, 23, currentMod, customTyres )
	SetVehicleMod( veh, 24, currentMod, customTyres )

	if ( livery ~= -1 ) then
		SetVehicleLivery( veh, livery )
	end

	SetVehicleExtraColours( veh, pearlColour, wheelColour )
	SetVehicleModColor_1( veh, mod1Colour[1], mod1Colour[2], mod1Colour[3] )
	SetVehicleModColor_2( veh, mod2Colour[1], mod2Colour[2] )

	SetVehicleColours( veh, primaryColour, secondaryColour )

	if ( custPrimaryColour[1] ~= nil and custPrimaryColour[2] ~= nil and custPrimaryColour[3] ~= nil ) then
		SetVehicleCustomPrimaryColour( veh, custPrimaryColour[1], custPrimaryColour[2], custPrimaryColour[3] )
	end

	if ( custSecondaryColour[1] ~= nil and custSecondaryColour[2] ~= nil and custSecondaryColour[3] ~= nil ) then
		SetVehicleCustomPrimaryColour( veh, custSecondaryColour[1], custSecondaryColour[2], custSecondaryColour[3] )
	end

	SetVehicleNeonLightsColour( veh, neonColour[1], neonColour[2], neonColour[3] )

	for i = 0, 3 do
		SetVehicleNeonLightEnabled( veh, i, false )
	end

	for k, v in pairs( neonToggles ) do
		local index = tonumber( v )
		SetVehicleNeonLightEnabled( veh, index, true )
	end

	SetVehicleDirtLevel(veh, 0.0)

	return veh
end

--Map Blips
Citizen.CreateThread(function()
    local blips = {}
    for ln,loc in pairs(xnGarageConfig.locations) do
        local x,y,z = ToCoord(loc.inLocation[1],false) -- Get coords
        local blip = AddBlipForCoord(x,y,z) -- Create blip

        -- Set blip option
        SetBlipSprite(blip, 357)
        SetBlipColour(blip, 0)
        SetBlipAsShortRange(blip, true)
        SetBlipCategory(blip, 9)
        BeginTextCommandSetBlipName("STRING")
    	      AddTextComponentString(xnGarageConfig.GroupMapBlips and "Garage" or ln)
    	EndTextCommandSetBlipName(blip)

        -- Save handle to blip table
        blips[#blips+1] = blip
    end
end)

local vehicleTable = {}
RegisterNetEvent("xnov:recVehicles")
AddEventHandler("xnov:recVehicles", function(data)
    vehicleTable = data
end)

RegisterNetEvent("xnov:message")
AddEventHandler("xnov:message", function(content,time)
    SetNotificationTextEntry("STRING")
        SetNotificationColorNext(0)
        AddTextComponentSubstringPlayerName(content)
    DrawNotification(0,1)
end)

RegisterCommand("testnot", function(_,args)


end, false)

local saveCallbackResponse = false
RegisterNetEvent("xnov:savecallback")
AddEventHandler("xnov:savecallback", function(response) saveCallbackResponse = response end)

-- Load Garage
function LoadGarage(wait)
    Citizen.CreateThread(function()
        local x,y,z = ToCoord(xnGarage.curGarage.inLocation[1], false)
        local int = GetInteriorAtCoords(x, y, z)
        if int then RefreshInterior(int) end

        if wait then
            BeginTextCommandBusyString("STRING")
                AddTextComponentSubstringPlayerName("Loading Garage")
            EndTextCommandBusyString(4)
            Citizen.Wait(wait)
            RemoveLoadingPrompt()
        end

        vehicleTable = false
        TriggerServerEvent("xnov:reqVehicles")
        while not vehicleTable do Citizen.Wait(0) end
        local vt = vehicleTable

        for _,oldVeh in pairs(xnGarage.vehicles) do
            SetEntityAsMissionEntity(oldVeh)
            DeleteVehicle(oldVeh)
        end
        xnGarage.vehicles = {}

        if vehicleTable and vehicleTable[xnGarage.curGarageName] then
            for pos=1,#xnGarageConfig.locations[xnGarage.curGarageName].carLocations do -- Something weird with JSON causes something to be stupid with null keys
                local vehData = vehicleTable[xnGarage.curGarageName][pos]
                if vehData and vehData ~= "none" then
                    Citizen.CreateThread(function()
                        local isInVehicle, veh, vehModel = GetVehicle()
                        local x,y,z,h = ToCoord(xnGarage.curGarage.carLocations[pos], true)
                        local model = tonumber(vehData["model"])
                        if xnGarage.vehicleTakenLoc == xnGarage.curGarageName and xnGarage.vehicleTaken and pos == xnGarage.vehicleTakenPos and not IsEntityDead(xnGarage.vehicleTaken) then
                        else
                            -- Load
                            RequestModel(model)
                            while not HasModelLoaded(model) do Citizen.Wait(0) end

                            -- Create
                            xnGarage.vehicles[pos] = CreateVehicleFromData(vehData, x,y,z+1.0,h,true)

                            -- Godmode
                            SetEntityInvincible(xnGarage.vehicles[pos], true)
            				SetEntityProofs(xnGarage.vehicles[pos], true, true, true, true, true, true, 1, true)
            				SetVehicleTyresCanBurst(xnGarage.vehicles[pos], false)
            				SetVehicleCanBreak(xnGarage.vehicles[pos], false)
            				SetVehicleCanBeVisiblyDamaged(xnGarage.vehicles[pos], false)
            				SetEntityCanBeDamaged(xnGarage.vehicles[pos], false)
            				SetVehicleExplodesOnHighExplosionDamage(xnGarage.vehicles[pos], false)
                        end
                        Citizen.CreateThread(function()
                            while true do
                                Citizen.Wait(0)
                                local isInVehicle, veh = GetVehicle()
                                if isInVehicle and veh == xnGarage.vehicles[pos] then
                                    local x,y,z = table.unpack(GetEntityVelocity(veh))
                                    if (x > 0.5 or y > 0.5 or z > 0.5) or (x < -0.5 or y < -0.5 or z < -0.5) then
                                        Citizen.CreateThread(function()
                                            xnGarage.vehicleTakenPos = pos
                                            xnGarage.vehicleTakenLoc = xnGarage.curGarageName

                                            local ent = GetPlayerPed(-1)
                                            local x,y,z,h = ToCoord(xnGarage.curGarage.spawnOutLocation, true)

                                            DoScreenFadeOut(500)
                                            while IsScreenFadingOut() do Citizen.Wait(0) end
                                            FreezeEntityPosition(ent, true)
                                            SetEntityCoords(ent, x, y, z)

                                            -- Delete All Prev Vehicles
                                            for i,veh in ipairs(xnGarage.vehicles) do
                                                SetEntityAsMissionEntity(veh)
                                                DeleteVehicle(veh)
                                                Citizen.Wait(10)
                                            end
                                            if xnGarage.vehicleTaken then DeleteVehicle(xnGarage.vehicleTaken) end -- Delete the last vehicle taken out if there is one

                                            -- Create new vehicle
                                            xnGarage.vehicleTaken = CreateVehicleFromData(vehData, x,y,z+1.0,h)
                                            FreezeEntityPosition(xnGarage.vehicleTaken, true)
                                            Citizen.Wait(1000)
                                            SetEntityAsMissionEntity(xnGarage.vehicleTaken)

                                            SetPedIntoVehicle(ent, xnGarage.vehicleTaken, -1) -- Put the ped into the new vehicle
                                            Citizen.Wait(1000)

                                            FreezeEntityPosition(ent, false)
                                            FreezeEntityPosition(xnGarage.vehicleTaken, false)
                                            Citizen.Wait(1000)

                                            DoScreenFadeIn(500)
                                            while IsScreenFadingIn() do Citizen.Wait(0) end

                                            xnGarage.curGarage = false
                                            xnGarage.curGarageName = false
                                        end)
                                        break
                                    end
                                end
                            end
                        end)
                    end)
                end
            end
        end
    end)
end

-- Management Menu
Citizen.CreateThread(function()
    local managecam = 999
    local camsettings = {
        zoomlevel = 1,
        heading = 360,
    }
    local context = {
        operation = false,
        entity = false,
        position = false,
        name = false,
    }

    local function SetupCam()
        if xnGarage and xnGarage.curGarage then
            camsettings = {
                zoomlevel = GetFollowPedCamZoomLevel(),
                heading = GetGameplayCamRelativeHeading(),
            }
            managecam = CreateCam("DEFAULT_SCRIPTED_CAMERA",true)
            local x,y,z = ToCoord(xnGarage.curGarage.modifyCam[1])
            local rx,ry,rz = ToCoord(xnGarage.curGarage.modifyCam[2])

            SetCamCoord(managecam,x,y,z)
            SetCamRot(managecam, rx,ry,rz, 1)
            SetCamActive(managecam, true)
        end
    end

	WarMenu.CreateMenu('vmm', 'Vehicle Management')
        WarMenu.CreateSubMenu('vmm:veh', 'vmm', 'Manage Vehicle')
            WarMenu.CreateSubMenu('vmm:move', 'vmm:veh', 'Where?')
            WarMenu.CreateSubMenu('vmm:delete', 'vmm:veh', 'Are You Sure?')

	WarMenu.SetSubTitle('vmm', "main menu")

    local menus = {"vmm","vmm:veh","vmm:move","vmm:delete"}

	while true do
        if WarMenu.IsMenuAboutToBeClosed() then
            for _,m in ipairs(menus) do
                if WarMenu.IsMenuOpened(m) then
                    SetCamActive(managecam, false)
                    SetCamActive(-1, true)
                    EnableGameplayCam(true)
                    RenderScriptCams(0,1,1000,0)
                    SetGameplayCamRelativeHeading(camsettings.heading)
                    SetFollowPedCamViewMode(camsettings.zoomlevel)

                    context = {}
                    managecam = 999
                    camsettings = {}
                    WarMenu.CloseMenu()
                    Citizen.Wait(1000)
                end
            end
        elseif WarMenu.IsMenuOpened('vmm') and xnGarage and xnGarage.curGarage then
            if managecam == 999 then SetupCam() elseif not IsCamRendering(managecam) and not IsCamInterpolating(managecam) then RenderScriptCams(1, 1, 1000, 0) end

            local hasAny = false
            for i=1,#xnGarage.curGarage.carLocations do
                if xnGarage.vehicles[i] then
                    hasAny = true
                    local n = GetDisplayNameFromVehicleModel(GetEntityModel(xnGarage.vehicles[i])) ~= "CARNOTFOUND" and GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(xnGarage.vehicles[i]))) or "NULL" -- woah
                    if WarMenu.MenuButton("Vehicle "..i,"vmm:veh",n) then
                        context = {
                            operation = "manage",
                            entity = xnGarage.vehicles[i],
                            position = i,
                            name = n,
                        }
                    end
                end
            end
            if not hasAny then WarMenu.Button("You have no vehicles in this garage!") end
        WarMenu.Display()

        elseif WarMenu.IsMenuOpened('vmm:veh') then
            local x,y,z = ToCoord(xnGarage.curGarage.carLocations[context.position] or {0,0,0,0}, false)
            DrawMarker(20, x,y,z+2.0, 0.0, 0.0, 0.0, 180.0, 0.0, 180.0, 1.5, 1.5, 1.0, 240, 200, 80, 180, false, true, 2, false, false, false, false)
            if WarMenu.MenuButton("Move "..context.name,"vmm:move") then context.operation = "move" end
            if WarMenu.MenuButton("~r~Delete "..context.name.."?","vmm:delete") then context.operation = "delete" end
        WarMenu.Display()

        elseif WarMenu.IsMenuOpened('vmm:move') then
            for i=1,#xnGarage.curGarage.carLocations do
                if i ~= context.position then
                    local clicked,hovered = WarMenu.Button("Position "..i)
                    if clicked then
                        Citizen.CreateThread(function()
                            TriggerServerEvent("xnov:moveVehicle",xnGarage.curGarageName,context.position,i)
                            LoadGarage(1000)
                            WarMenu.CloseMenu()
                        end)
                    elseif hovered then
                        local x,y,z = ToCoord(xnGarage.curGarage.carLocations[i] or {0,0,0,0}, false)
                        DrawMarker(20, x,y,z+2.0, 0.0, 0.0, 0.0, 180.0, 0.0, 180.0, 1.5, 1.5, 1.0, 0, 128, 255, 100, false, true, 2, false, false, false, false)
                    end
                else
                    WarMenu.Button("~HUD_COLOR_GREY~Position "..i)
                end
            end
            local x,y,z = ToCoord(xnGarage.curGarage.carLocations[context.position] or {0,0,0,0}, false)
            DrawMarker(20, x,y,z+2.0, 0.0, 0.0, 0.0, 180.0, 0.0, 180.0, 1.5, 1.5, 1.0, 240, 200, 80, 180, false, true, 2, false, false, false, false)
        WarMenu.Display()

        elseif WarMenu.IsMenuOpened('vmm:delete') then
            local x,y,z = ToCoord(xnGarage.curGarage.carLocations[context.position] or {0,0,0,0}, false)
            DrawMarker(20, x,y,z+2.0, 0.0, 0.0, 0.0, 180.0, 0.0, 180.0, 1.5, 1.5, 1.0, 255, 128, 128, 100, false, true, 2, false, false, false, false)
            WarMenu.MenuButton("No",'vmm:veh')
            if WarMenu.Button("Yes") and context.operation == "delete" then
                Citizen.CreateThread(function()
                    TriggerServerEvent("xnov:deleteVehicle",xnGarage.curGarageName,context.position)
                    LoadGarage()
                    WarMenu.CloseMenu()
                end)
            end
        WarMenu.Display()

        end

        Citizen.Wait(0)
	end
end)


-- Mechanic Menu
Citizen.CreateThread(function()
    local context = {
        location = false,
    }

    WarMenu.CreateMenu('mech', 'Mechanic')
        WarMenu.CreateSubMenu('mech:location', 'mech', 'Vehicles')

	WarMenu.SetSubTitle('mech', "main menu")

    local menus = {"mech","mech:location"}


	while true do
		if WarMenu.IsMenuOpened('mech') then
            if json.encode(vehicleTable) == json.encode({}) then
                WarMenu.Button("You have no vehicles saved in any garage!")
            else
                for ln,location in pairs(vehicleTable) do
                    if WarMenu.MenuButton(ln,"mech:location") then context.location = ln end
                end
            end
        WarMenu.Display()

        elseif WarMenu.IsMenuOpened('mech:location') then
            for pos,vehData in ipairs(vehicleTable[context.location]) do
                if vehData ~= "none" then
                    local model = tonumber(vehData["model"])

                    if GetEntityModel(xnGarage.vehicleTaken) ~= model then -- Don't display the vehicle we currently have out
                        local name = GetDisplayNameFromVehicleModel(model) ~= "CARNOTFOUND" and GetLabelText(GetDisplayNameFromVehicleModel(model)) or ("Name not given for hash: "..model) -- more of this shit
                        if WarMenu.Button(name) then
                            RequestModel(model)
                            while not HasModelLoaded(model) do Citizen.Wait(0) end
                            xnGarage.vehicleTakenPos = pos
                            xnGarage.vehicleTakenLoc = context.location

                            if xnGarage.vehicleTaken then DeleteVehicle(xnGarage.vehicleTaken) end

                            local x,y,z = table.unpack(GetEntityCoords(GetPlayerPed(-1)))
                            local h = GetEntityHeading(GetPlayerPed(-1))
                            xnGarage.vehicleTaken = CreateVehicleFromData(vehData, x,y,z,h)
                            SetEntityAsMissionEntity(xnGarage.vehicleTaken)
                            SetPedIntoVehicle(GetPlayerPed(-1), xnGarage.vehicleTaken, -1)
                            WarMenu.CloseMenu()
                        end
                    end
                end
            end
        WarMenu.Display()

        elseif WarMenu.IsMenuAboutToBeClosed() then
            for _,m in ipairs(menus) do
                if WarMenu.IsMenuOpened(m) then context = {} end
            end

        elseif IsControlJustReleased(0, 167) then
            vehicleTable = false
            TriggerServerEvent("xnov:reqVehicles")
            while not vehicleTable do Citizen.Wait(0) end

            WarMenu.OpenMenu("mech")
        end

		Citizen.Wait(0)
	end
end)

-- Main
Citizen.CreateThread(function()
    while true do
        local isInVehicle, veh, vehModel = GetVehicle()
        if not xnGarage.curGarage then
            for ln,location in pairs(xnGarageConfig.locations) do
                local ent = isInVehicle and veh or GetPlayerPed(-1)
                local ix,iy,iz = ToCoord(location.inLocation[1],false)

                if Vdist2(GetEntityCoords(ent),ix,iy,iz) < 500.0 then
                    DrawMarker(20, ix,iy,iz+1.0, 0.0, 0.0, 0.0, 180.0, 0.0, 180.0, 1.5, 1.5, 1.0, 0, 128, 255, 100, false, true, 2, false, false, false, false)
                end

                local allowed = true
                if IsThisModelABoat(vehModel) then allowed = false end
                if IsThisModelAPlane(vehModel) then allowed = false end
                if IsThisModelAHeli(vehModel) then allowed = false end
                for _,blockedModel in ipairs(xnGarageConfig.BlacklistedVehicles) do
                    if GetHashKey(blockedModel) == vehModel then allowed = false end
                end

                if Vdist2(GetEntityCoords(ent),ix,iy,iz) < location.inLocation[2]*2.5 and not IsPedSprinting(GetPlayerPed(-1)) then
                    if not allowed then
                        DisplayHelpTextThisFrame("WEB_VEH_INV", 1)
                    else
                        DisplayHelpTextThisFrame("XNOV_ENTER", 1)
                        if IsControlJustReleased(0, 51) then
                            if isInVehicle then SetVehicleHalt(veh,1.0,1) end -- Nice Native!
                            xnGarage.curGarage = location
                            xnGarage.curGarageName = ln
                            if xnGarageConfig.PrintGarageName then print("[DEBUG] Entered Garage: "..tostring(ln)) end
                            if not isInVehicle then
                                LoadGarage()
                                local x,y,z,h = ToCoord(xnGarage.curGarage.spawnInLocation, true)
                                FancyTeleport(ent, x,y,z,h)
                                Citizen.Wait(500)
                            else
                                saveCallbackResponse = false
                                if xnGarage.vehicleTaken ~= veh then
                                    TriggerServerEvent("xnov:saveVehicle",VehicleToData(veh),ln)
                                else
                                    TriggerServerEvent("xnov:saveVehicle",VehicleToData(veh),ln,xnGarage.vehicleTakenPos,xnGarage.vehicleTakenLoc)
                                end
                                while not saveCallbackResponse do Citizen.Wait(0) end

                                if saveCallbackResponse == "no_slot" then
                                    xnGarage.curGarage = false
                                    xnGarage.curGarageName = false
                                    while Vdist2(GetEntityCoords(ent),ix,iy,iz) < location.inLocation[2]*2.5 do
                                        Citizen.Wait(0)
                                        DisplayHelpTextThisFrame("WEB_VEH_FULL", 1)
                                    end
                                end

                                Citizen.Wait(1000)
                                if saveCallbackResponse == "success" then
                                    xnGarage.vehicleTaken = false
                                    xnGarage.vehicleTakenPos = false
                                    xnGarage.vehicleTakenLoc = false

                                    LoadGarage()

                                    SetEntityAsMissionEntity(veh)
                                    DeleteVehicle(veh)
                                    local x,y,z,h = ToCoord(xnGarage.curGarage.spawnInLocation, true)
                                    FancyTeleport(GetPlayerPed(-1), x,y,z,h)
                                    Citizen.Wait(2000)
                                end
                            end
                            saveCallbackResponse = false
                        end
                    end
                end
            end
        else
            local gr = xnGarage.curGarage
            local ent = isInVehicle and veh or GetPlayerPed(-1)
            -- Exit Marker
            local ox,oy,oz = ToCoord(gr.outMarker)
            DrawMarker(1, ox,oy,oz, 0.0, 0.0, 0.0, 180.0, 180.0, 180.0, 1.0, 1.0, 1.0, 0, 128, 255, 100, false, true, 2, false, false, false, false)
            if Vdist2(GetEntityCoords(ent),ToCoord(gr.outMarker)) <= 1.5 then
                local x,y,z,h = ToCoord(xnGarage.curGarage.spawnOutLocation,true)
                local ix,iy,iz = ToCoord(gr.inLocation[1],false)
                local rad = gr.inLocation[2]
                FancyTeleport(ent, x,y,z,h, 500,2000,500, true)
                Citizen.Wait(3000)
                xnGarage.curGarage = false
                xnGarage.curGarageName = false
                xnGarage = xnGarage or xnGarage_default
                Citizen.Wait(500)
                while Vdist2(GetEntityCoords(ent),ix,iy,iz) < rad*2.5 do Citizen.Wait(0) end
            end

            local mx,my,mz = ToCoord(gr.modifyMarker)
            DrawMarker(1, mx,my,mz, 0.0, 0.0, 0.0, 180.0, 180.0, 180.0, 1.0, 1.0, 1.0, 240, 200, 80, 180, false, true, 2, false, false, false, false)
            if Vdist2(GetEntityCoords(ent),ToCoord(gr.modifyMarker)) <= 1.5 then
                DisplayHelpTextThisFrame("MP_MAN_VEH", 0) -- native localisation is cool
                if IsControlJustPressed(1, 51) then
                    WarMenu.OpenMenu("vmm")
                    Citizen.Wait(500)
                end
            end
        end
        Citizen.Wait(0)
    end
end)

-- Slow walk loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if xnGarage.curGarage and xnGarageConfig.RestrictActions then
            DisableControlAction(0, 22, true)
            DisablePlayerFiring(PlayerId(), true)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        if xnGarageConfig.RestrictActions then
            local curGarage = xnGarage.curGarage
            while xnGarage.curGarage == curGarage do Citizen.Wait(0) end

            if xnGarage.curGarage then
                SetCanAttackFriendly(GetPlayerPed(-1), false, false)
                NetworkSetFriendlyFireOption(false)
            else
                SetCanAttackFriendly(GetPlayerPed(-1), true, false)
                NetworkSetFriendlyFireOption(true)
            end
        end
        Citizen.Wait(0)
    end
end)


-- Personal vehicle blip
Citizen.CreateThread(function()
    local blip = false
    while true do
        Citizen.Wait(0)
        local prevEntId = xnGarage.vehicleTaken
        while not xnGarage.vehicleTaken or prevEntId == xnGarage.vehicleTaken do Citizen.Wait(0) end

        blip = AddBlipForEntity(xnGarage.vehicleTaken)

        SetBlipSprite(blip, 225)

        BeginTextCommandSetBlipName("STRING")
		AddTextComponentSubstringTextLabel("PVEHICLE")
		EndTextCommandSetBlipName(blip)

        Citizen.CreateThread(function() -- I could probably make this better but eh
            local myBlip = blip
            while myBlip == blip do
                Citizen.Wait(0)
                local isInVehicle, veh = GetVehicle(_,true)
                if isInVehicle and veh == xnGarage.vehicleTaken then
                    if GetBlipInfoIdDisplay(myBlip) ~= 3 then
                        SetBlipDisplay(myBlip, 3)
                        BeginTextCommandSetBlipName("STRING")
                		AddTextComponentSubstringTextLabel("PVEHICLE")
                		EndTextCommandSetBlipName(myBlip)
                    end
                else
                    if GetBlipInfoIdDisplay(myBlip) ~= 2 then
                        SetBlipDisplay(myBlip, 2)
                        BeginTextCommandSetBlipName("STRING")
                		AddTextComponentSubstringTextLabel("PVEHICLE")
                		EndTextCommandSetBlipName(myBlip)
                    end
                end
                if IsEntityDead(xnGarage.vehicleTaken) then
                    RemoveBlip(myBlip)
                    break
                end
            end
        end)
    end
end)

-- Hide players in garage
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if xnGarage.curGarage then
            for i=0,63 do
                if i ~= GetPlayerServerId(PlayerId()) then
                    SetPlayerInvisibleLocally(GetPlayerFromServerId(i))
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    if xnGarageConfig.EnableInteriors then
    	RequestIpl("bkr_bi_id1_23_door")
    	RequestIpl("bkr_bi_hw1_13_int")

        RequestIpl("bkr_biker_interior_placement_interior_0_biker_dlc_int_01_milo")
        RequestIpl("bkr_biker_interior_placement_interior_1_biker_dlc_int_02_milo")
    	EnableInteriorProp(246529, "mod_booth")
    	EnableInteriorProp(246529, "gun_locker")
    	EnableInteriorProp(246529, "lower_walls_default")
    	SetInteriorPropColor(246529, "lower_walls_default", 3)
    	EnableInteriorProp(246529, "walls_02")
    	SetInteriorPropColor(246529, "walls_02", 3)
    	EnableInteriorProp(246529, "mural_01")
    	EnableInteriorProp(246529, "furnishings_02")
        RefreshInterior(246529)

        RequestIpl("ex_exec_warehouse_placement_interior_0_int_warehouse_m_dlc_milo ")
        RequestIpl("ex_exec_warehouse_placement_interior_1_int_warehouse_s_dlc_milo ")
        RequestIpl("ex_exec_warehouse_placement_interior_2_int_warehouse_l_dlc_milo ")

        RequestIpl("imp_dt1_11_cargarage_a")
        EnableInteriorProp(256513, "Garage_Decor_01")
        EnableInteriorProp(256513, "Lighting_Option01")
        EnableInteriorProp(256513, "Numbering_Style01_N1")
        EnableInteriorProp(256513, "Floor_vinyl_01")
        RefreshInterior(256513)

        RequestIpl("imp_dt1_02_cargarage_a")
        EnableInteriorProp(253441, "Garage_Decor_02")
        EnableInteriorProp(253441, "Lighting_Option02")
        EnableInteriorProp(253441, "Numbering_Style02_N1")
        EnableInteriorProp(253441, "Floor_vinyl_02")
        RefreshInterior(253441)

        RequestIpl("imp_sm_13_cargarage_a")
        EnableInteriorProp(254465, "Garage_Decor_03")
        EnableInteriorProp(254465, "Lighting_Option03")
        EnableInteriorProp(254465, "Numbering_Style03_N1")
        EnableInteriorProp(254465, "Floor_vinyl_03")
        RefreshInterior(254465)

        RequestIpl("imp_sm_15_cargarage_a")
        EnableInteriorProp(255489, "Garage_Decor_04")
        EnableInteriorProp(255489, "Lighting_Option04")
        EnableInteriorProp(255489, "Numbering_Style04_N1")
        EnableInteriorProp(255489, "Floor_vinyl_04")
        RefreshInterior(255489)
    end
end)

end) -- no, this is not mismatched
