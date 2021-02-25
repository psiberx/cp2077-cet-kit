--[[
An example of reading player actions / inputs
]]

registerForEvent('onInit', function()
	Observe('PlayerPuppet', 'OnAction', function(action)
		local actionName = Game.NameToString(action:GetName(action))
		local actionType = action:GetType(action).value -- gameinputActionType
		local actionValue = action:GetValue(action)

		if actionName == 'Forward' or actionName == 'Back' then
			if actionType == 'BUTTON_PRESSED' then
				print('[Action]', actionName, 'Pressed')
			elseif actionType == 'BUTTON_RELEASED' then
				print('[Action]', actionName, 'Released')
			end
		elseif actionName == 'MoveY' then
			if actionValue ~= 0 then
				print('[Action]', (actionValue > 0 and 'Forward' or 'Back'), Game.GetPlayer():GetWorldForward())
			end
		elseif actionName == 'Jump' then
			if actionType == 'BUTTON_PRESSED' then
				print('[Action] Jump Pressed')
			elseif actionType == 'BUTTON_RELEASED' then
				print('[Action] Jump Released')
			end
		elseif actionName == 'WeaponSlot1' then
			if actionType == 'BUTTON_PRESSED' then
				print('[Action] Select Weapon 1')
			end
		end		
	end)
end)

--[[
Simple observer to see all player actions (including mouse and camera moves)

registerForEvent('onInit', function()
	Observe('PlayerPuppet', 'OnAction', function(action)
		print('[Action]', Game.NameToString(action:GetName(action)), action:GetType(action).value, action:GetValue(action))
	end)
end)
]]
