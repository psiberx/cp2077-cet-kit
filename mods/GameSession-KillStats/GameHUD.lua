--[[
GameHUD.lua

Copyright (c) 2021 psiberx
]]

local GameHUD = { version = '0.3.1' }

function GameHUD.ShowMessage(text)
	if text == nil or text == "" then
		return
	end

	local message = SimpleScreenMessage.new()
	message.message = text
	message.isShown = true

	local blackboardDefs = Game.GetAllBlackboardDefs()
	local blackboardUI = Game.GetBlackboardSystem():Get(blackboardDefs.UI_Notifications)

	blackboardUI:SetVariant(
		blackboardDefs.UI_Notifications.OnscreenMessage,
		ToVariant(message),
		true
	)
end

function GameHUD.ShowWarning(text, duration)
	if text == nil or text == "" then
		return
	end

	PreventionSystem.ShowMessage(text, duration or 5.0)
end

return GameHUD