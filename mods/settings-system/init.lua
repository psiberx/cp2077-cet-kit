registerHotkey('SwitchFOV', 'Switch FOV', function()
	local fov = Game.GetSettingsSystem():GetVar('/graphics/basic', 'FieldOfView')

	local value = fov:GetValue() + fov:GetStepValue()

	if value > fov:GetMaxValue() then
		value = fov:GetMinValue()
	end

	fov:SetValue(value)

	print(('Current FOV: %.1f'):format(fov:GetValue()))
end)

registerHotkey('SwitchResolution', 'Switch resolution', function()
	local resolution = Game.GetSettingsSystem():GetVar('/video/display', 'Resolution')

	local options = resolution:GetValues()
	local current = resolution:GetIndex() + 1 -- lua tables start at 1
	local next = current + 1

	if next > #options then
		next = 1
	end

	resolution:SetIndex(next - 1)

	Game.GetSettingsSystem():ConfirmChanges()

	print(('Switched resolution from %s to %s'):format(options[current], options[next]))
end)

registerHotkey('ToggleHUD', 'Toggle HUD', function()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'action_buttons'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'activity_log'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'ammo_counter'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'chatters'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'healthbar'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'input_hints'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'johnny_hud'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'minimap'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'npc_healthbar'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'quest_tracker'):Toggle()
	Game.GetSettingsSystem():GetVar('/interface/hud', 'stamina_oxygen'):Toggle()
end)
