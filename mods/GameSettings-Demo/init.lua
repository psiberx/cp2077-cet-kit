local GameSettings = require('GameSettings')

registerHotkey('ExportSettings', 'Export all settings', function()
	GameSettings.ExportTo('settings.lua')
end)

registerHotkey('SwitchFOV', 'Switch FOV', function()
	local fov = GameSettings.Var('/graphics/basic/FieldOfView')

	fov.value = fov.value + fov.step

	if fov.value > fov.max then
		fov.value = fov.min
	end

	GameSettings.Set('/graphics/basic/FieldOfView', fov.value)
		
	if GameSettings.NeedsConfirmation() then
		GameSettings.Confirm()
	end
	
	print(('Current FOV: %.1f'):format(GameSettings.Get('/graphics/basic/FieldOfView')))
end)

registerHotkey('SwitchResolution', 'Switch resolution', function()
	-- You can get available options and current selection for lists
	local options, current = GameSettings.Options('/video/display/Resolution')
	local next = current + 1

	if next > #options then
		next = 1
	end

	GameSettings.Set('/video/display/Resolution', options[next])

	if GameSettings.NeedsConfirmation() then
		GameSettings.Confirm()
	end

	print(('Switched resolution from %s to %s'):format(options[current], options[next]))
end)

registerHotkey('ToggleHUD', 'Toggle HUD', function()
	-- Option 1: Toggle all settings in the group
	GameSettings.ToggleGroup('/interface/hud')

	-- Option 2: Toggle specific settings
	--GameSettings.ToggleAll({
	--	'/interface/hud/action_buttons',
	--	'/interface/hud/activity_log',
	--	'/interface/hud/ammo_counter',
	--	'/interface/hud/healthbar',
	--	'/interface/hud/input_hints',
	--	'/interface/hud/johnny_hud',
	--	'/interface/hud/minimap',
	--	'/interface/hud/npc_healthbar',
	--	'/interface/hud/npc_names',
	--	'/interface/hud/object_markers',
	--	'/interface/hud/quest_tracker',
	--	'/interface/hud/stamina_oxygen',
	--})
end)

registerHotkey('SwitchBlur', 'Switch blur', function()
	local options, current = GameSettings.Options('/graphics/basic/MotionBlur')
	local next = current + 1

	if next > #options then
		next = 1
	end

	GameSettings.Set('/graphics/basic/MotionBlur', options[next])
	GameSettings.Save() -- Required for most graphics settings

	print(('Switched blur from %s to %s'):format(options[current], options[next]))
end)
