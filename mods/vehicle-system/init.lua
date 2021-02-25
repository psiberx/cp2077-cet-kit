-- With instant summon mode enabled you can control the position of the spawn (it spawns in front of the player)
-- Otherwise the game can spawn a vehicle right in the spot of another one (collision fun yee)
-- You cannot spawn the same vehicle twice (same TweakDBID) with Vehicle System

-- The list of the summonable vehicles 
local targetVehicles = {
	'Vehicle.v_standard2_archer_hella_police',
	'Vehicle.v_standard2_villefort_cortes_police',
	'Vehicle.v_standard3_chevalier_emperor_police',
	'Vehicle.v_standard2_archer_hella_player',
	'Vehicle.v_sport2_quadra_type66_nomad',
}

local function summonVehicle(targetVehicle)
	local vehicleSystem = Game.GetVehicleSystem()

	local vehicleGarageId = GetSingleton('vehicleGarageVehicleID'):Resolve(targetVehicle)
	vehicleSystem:TogglePlayerActiveVehicle(vehicleGarageId, 'Car', true)
	vehicleSystem:SpawnPlayerVehicle('Car')
end

registerForEvent('onInit', function()
	local unlockableVehicles = TweakDB:GetFlat(TweakDBID.new('Vehicle.vehicle_list.list'))

	for _, targetVehicle in ipairs(targetVehicles) do
		local targetVehicleTweakDbId = TweakDBID.new(targetVehicle)
		local isVehicleUnlockable = false
		
		for _, unlockableVehicleTweakDbId in ipairs(unlockableVehicles) do
			if tostring(unlockableVehicleTweakDbId) == tostring(targetVehicleTweakDbId) then
				isVehicleUnlockable = true
				break
			end
		end
		
		if not isVehicleUnlockable then
			table.insert(unlockableVehicles, targetVehicleTweakDbId)
		end
	end
	
	TweakDB:SetFlat(TweakDBID.new('Vehicle.vehicle_list.list'), unlockableVehicles)
end)

registerHotkey('SpawnRandomVehicle', 'Spawn a random vehicle', function()
	summonVehicle(targetVehicles[math.random(#targetVehicles)])
end)

registerHotkey('ToggleSpawnMode', 'Toggle instant spawn mode', function()
	Game.GetVehicleSystem():ToggleSummonMode()
end)

registerHotkey('EnableAllVehicles', 'Add vehicles to the call list', function()
	for _, targetVehicle in ipairs(targetVehicles) do
		Game.GetVehicleSystem():EnablePlayerVehicle(targetVehicle, true, false)
	end
end)
