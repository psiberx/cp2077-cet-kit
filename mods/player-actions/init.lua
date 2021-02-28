--[[
An example of reading player actions / inputs
]]

registerForEvent('onInit', function()
	local ListenerAction = GetSingleton('gameinputScriptListenerAction')

	Observe('PlayerPuppet', 'OnAction', function(action)
		local actionName = Game.NameToString(ListenerAction:GetName(action))
		local actionType = ListenerAction:GetType(action).value -- gameinputActionType
		local actionValue = ListenerAction:GetValue(action)

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
			elseif actionType == 'BUTTON_HOLD_COMPLETE' then
				print('[Action] Jump Charged')
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
	local ListenerAction = GetSingleton('gameinputScriptListenerAction')

	Observe('PlayerPuppet', 'OnAction', function(action)
		print('[Action]', Game.NameToString(ListenerAction:GetName(action)), ListenerAction:GetType(action).value, ListenerAction:GetValue(action))
	end)
end)
]]
