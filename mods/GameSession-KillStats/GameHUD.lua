--[[
GameHUD.lua

Copyright (c) 2021 psiberx
]]

local GameHUD = { version = '0.3.0' }

function GameHUD.ShowMessage(text)
	local message = SimpleScreenMessage.new({
		message = text,
		isShown = true
	})

	local blackboardDefs = Game.GetAllBlackboardDefs()
	local blackboardUI = Game.GetBlackboardSystem():Get(blackboardDefs.UI_Notifications)

	blackboardUI:SetVariant(
		blackboardDefs.UI_Notifications.OnscreenMessage,
		ToVariant(message),
		true
	)
end

function GameHUD.ShowWarning(text, duration)
	PreventionSystem.ShowMessage(text, duration or 5.0)
end

return GameHUD