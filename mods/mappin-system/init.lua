--[[
Place a map pin at the player's current position: [shared credits with @b0kkr]
]]

registerHotkey('PlaceCustomMapPin', 'Place a map pin at player\'s position', function()
	local mappinData = NewObject('gamemappinsMappinData')
	mappinData.mappinType = TweakDBID.new('Mappins.DefaultStaticMappin')
	mappinData.variant = Enum.new('gamedataMappinVariant', 'FastTravelVariant')
	mappinData.visibleThroughWalls = true
	
	local position = Game.GetPlayer():GetWorldPosition()
	
	Game.GetMappinSystem():RegisterMappin(mappinData, position)
end)

--[[
Place a map pin on an object under the crosshair (NPC, Car, Terminal, etc.):
]]

registerHotkey('PlaceObjectMapPin', 'Place a map pin on the target', function()
	local target = Game.GetTargetingSystem():GetLookAtObject(Game.GetPlayer(), false, false)
	
	if target then
		local mappinData = NewObject('gamemappinsMappinData')
		mappinData.mappinType = TweakDBID.new('Mappins.DefaultStaticMappin')
		mappinData.variant = Enum.new('gamedataMappinVariant', 'FastTravelVariant')
		mappinData.visibleThroughWalls = true
		
		local slot = CName.new('poi_mappin')
		local offset = ToVector3{ x = 0, y = 0, z = 2 } -- Move the pin a bit up relative to the target
		
		Game.GetMappinSystem():RegisterMappinWithObject(mappinData, target, slot, offset)
	end
end)

--[[
A map pin can be tracked (drawing path on the map and minimap) if the variant allowing it. 
A map pin placed on an object follows the object if it moves.

Custom map pins remain after fast traveling. But the "pinned" object can be disposed / teleported, 
in which case the pin will move to an unpredictable coordinate.

Change `mappinData.variant` to get a different appearance (and sometimes behavior) of the map pin.
https://github.com/WolvenKit/CyberCAT/blob/main/CyberCAT.Core/Enums/Dumped%20Enums/gamedataMappinVariant.cs
]]
