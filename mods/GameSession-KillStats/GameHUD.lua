--[[
GameHUD.lua

Copyright (c) 2021 psiberx
]]

local GameHUD = { version = '0.2.0' }

local messageController

local function isVehicle()
	return Game['GetMountedVehicle;GameObject'](Game.GetPlayer()) ~= nil
end

function GameHUD.Init()
	Observe('OnscreenMessageGameController', 'CreateAnimations', function(self)
		messageController = self
	end)
end

function GameHUD.ShowMessage(text)
	if messageController and not isVehicle() then
		local message = NewObject('gameSimpleScreenMessage')
		message.isShown = true
		message.duration = 5.0
		message.message = text

		messageController.screenMessage = message
		messageController:UpdateWidgets()
	end
end

function GameHUD.ShowWarning(text, duration)
	Game['PreventionSystem::ShowMessage;GameInstanceStringFloat'](text, duration or 5.0)
end

return GameHUD