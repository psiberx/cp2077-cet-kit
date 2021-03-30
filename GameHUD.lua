--[[
GameHUD.lua

Copyright (c) 2021 psiberx
]]

local GameHUD = { version = '0.1.1' }

local messageController

function GameHUD.Init()
	Observe('OnscreenMessageGameController', 'CreateAnimations', function(self)
		messageController = self
	end)
end

function GameHUD.ShowMessage(text)
	if messageController then
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