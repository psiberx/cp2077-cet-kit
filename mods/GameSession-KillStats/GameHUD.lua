--[[
GameHUD.lua

Copyright (c) 2021 psiberx
]]

local GameHUD = { version = '0.4.1' }

function GameHUD.Initialize()
	-- Fix warning message for patch 1.3
	local gameVersionNum = EnumValueFromString('gameGameVersion', 'Current')
	if gameVersionNum >= 1300 and gameVersionNum <= 1301 then
		Override('WarningMessageGameController', 'UpdateWidgets', function(self)
			if self.simpleMessage.isShown and self.simpleMessage.message ~= '' then
				self.root:StopAllAnimations()

				inkTextRef.SetLetterCase(self.mainTextWidget, textLetterCase.UpperCase)
				inkTextRef.SetText(self.mainTextWidget, self.simpleMessage.message)

				Game.GetAudioSystem():Play('ui_jingle_chip_malfunction')

				self.animProxyShow = self:PlayLibraryAnimation('warning')

				local fakeAnim = inkAnimTransparency.new()
				fakeAnim:SetStartTransparency(1.00)
				fakeAnim:SetEndTransparency(1.00)
				fakeAnim:SetDuration(3.1)

				local fakeAnimDef = inkAnimDef.new()
				fakeAnimDef:AddInterpolator(fakeAnim)

				self.animProxyTimeout = self.root:PlayAnimation(fakeAnimDef)
				self.animProxyTimeout:RegisterToCallback(inkanimEventType.OnFinish, self, 'OnShown')

				self.root:SetVisible(true)
			elseif self.animProxyShow then
				self.animProxyShow:RegisterToCallback(inkanimEventType.OnFinish, self, 'OnHidden')
				self.animProxyShow:Resume()
			end
		end)

		Override('WarningMessageGameController', 'OnShown', function(self)
			self.animProxyShow:Pause()
			self:SetTimeout(self.simpleMessage.duration)
		end)
	end
end

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

	local message = SimpleScreenMessage.new()
	message.message = text
	message.duration = duration
	message.isShown = true

	local blackboardDefs = Game.GetAllBlackboardDefs()
	local blackboardUI = Game.GetBlackboardSystem():Get(blackboardDefs.UI_Notifications)

	blackboardUI:SetVariant(
		blackboardDefs.UI_Notifications.WarningMessage,
		ToVariant(message),
		true
	)
end

return GameHUD