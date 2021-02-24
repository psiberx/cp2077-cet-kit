--[[
GameUI State Observer

How to use:
```
local GameUI = require('GameUI')

registerForEvent('onInit', function()
	GameUI.Observe(function(state)
		GameUI.PrintState(state)
	end)
end)
```

See `GameUI.PrintState()` for all state properties
]]

local GameUI = {}

local isInitialized = false
local isLoading = false
local isLoaded = false
local isMenu = true
local isBraindance = false
local isPhotoMode = false
local sceneTier = 4
local contextStack = {}
local notifiedState = { isInitialized = false }
local observers = {}

local function updateLoading(loading)
	isLoading = loading
	isLoaded = false
end

local function updateMenu(menuActive)
	isMenu = menuActive or GameUI.IsMainMenu()

	if isLoading then
		if not isMenu then
			isLoading = false
			isLoaded = true
		end
	end
end

local function updateBraindance(braindanceActive)
	isBraindance = braindanceActive
end

local function updatePhotoMode(photoModeActive)
	isPhotoMode = photoModeActive
end

local function updateSceneTier(sceneTierValue)
	sceneTier = sceneTierValue -- gamePSMHighLevel?
end

local function updateContex(oldContext, newContext)
	if oldContext == nil and newContext == nil then
		contextStack = {}
	else
		local position = #contextStack + 1

		if oldContext ~= nil then
			for i = #contextStack, 1, -1 do
				if contextStack[i].value == oldContext.value then
					table.remove(contextStack, i)
					position = i
					break
				end
			end
		end

		if newContext ~= nil then
			table.insert(contextStack, position, newContext)
		end
	end
end

local function refreshCurrentState()
	local playerId = Game.GetPlayer():GetEntityID()
	local blackboardDefs = Game.GetAllBlackboardDefs()
	local blackboardUI = Game.GetBlackboardSystem():Get(blackboardDefs.UI_System)
	local blackboardBD = Game.GetBlackboardSystem():Get(blackboardDefs.Braindance)
	local blackboardPM = Game.GetBlackboardSystem():Get(blackboardDefs.PhotoMode)
	local blackboardPSM = Game.GetBlackboardSystem():GetLocalInstanced(playerId, blackboardDefs.PlayerStateMachine)

	updateMenu(blackboardUI:GetBool(blackboardDefs.UI_System.IsInMenu))
	updateBraindance(blackboardBD:GetBool(blackboardDefs.Braindance.IsActive))
	updatePhotoMode(blackboardPM:GetBool(blackboardDefs.PhotoMode.IsActive))
	updateSceneTier(blackboardPSM:GetInt(blackboardDefs.PlayerStateMachine.SceneTier))
end

local function notifyObservers()
	local currentState = GameUI.GetState()
	local stateChanged = false

	for stateProp, notifiedValue in pairs(notifiedState) do
		local currentValue = currentState[stateProp]

		if tostring(notifiedValue) ~= tostring(currentValue) then
			stateChanged = true
			break
		end
	end

	if stateChanged then
		for _, callback in ipairs(observers) do
			callback(currentState)
		end

		if isLoaded then
			isLoaded = false
		end

		notifiedState = currentState
	end
end

local function initialize()
	GameUI.Context = {
		Default = Enum.new('UIGameContext', 0),
		QuickHack = Enum.new('UIGameContext', 1),
		Scanning = Enum.new('UIGameContext', 2),
		DeviceZoom = Enum.new('UIGameContext', 3),
		BraindanceEditor = Enum.new('UIGameContext', 4),
		BraindancePlayback = Enum.new('UIGameContext', 5),
		VehicleMounted = Enum.new('UIGameContext', 6),
		ModalPopup = Enum.new('UIGameContext', 7),
		RadialWheel = Enum.new('UIGameContext', 8),
		VehicleRace = Enum.new('UIGameContext', 9),
	}

	Enum.__eq = function(a, b)
		return a.value == b.value
	end

	-- Game state observers

	Observe('PlayerPuppet', 'OnDetach', function()
		if isMenu then
			updateLoading(true)
			notifyObservers()
		end
	end)

	Observe('SingleplayerMenuGameController', 'OnSavesReady', function()
		updateLoading(false)
		updateMenu(true)
		updateBraindance(false)
		updatePhotoMode(false)
		updateSceneTier(4)
		notifyObservers()
	end)

	Observe('RadialWheelController', 'OnIsInMenuChanged', function(menuActive)
		updateMenu(menuActive)

		if isLoaded then
			refreshCurrentState()
		end

		notifyObservers()
	end)

	Observe('BraindanceGameController', 'OnIsActiveUpdated', function(braindanceActive)
		updateBraindance(braindanceActive)
		notifyObservers()
	end)

	Observe('CrosshairGameController_NoWeapon', 'OnPSMSceneTierChanged', function(sceneTierValue)
		updateSceneTier(sceneTierValue)
		notifyObservers()
	end)

	Observe('gameuiPhotoModeMenuController', 'OnShow', function()
		updatePhotoMode(true)
		notifyObservers()
	end)

	Observe('gameuiPhotoModeMenuController', 'OnHide', function()
		updatePhotoMode(false)
		notifyObservers()
	end)

	Observe('gameuiGameSystemUI', 'PushGameContext', function(self, newContext)
		updateContex(nil, newContext)
		notifyObservers()
	end)

	Observe('gameuiGameSystemUI', 'PopGameContext', function(self, oldContext)
		updateContex(oldContext, nil)
		notifyObservers()
	end)

	Observe('gameuiGameSystemUI', 'SwapGameContext', function(self, oldContext, newContext)
		-- bugfix: new context is broken
		if oldContext.value == GameUI.Context.Scanning.value then
			newContext = GameUI.Context.QuickHack
		elseif oldContext.value == GameUI.Context.QuickHack.value then
			newContext = GameUI.Context.Scanning
		end

		updateContex(oldContext, newContext)
		notifyObservers()
	end)

	Observe('gameuiGameSystemUI', 'ResetGameContext', function()
		updateContex()
		notifyObservers()
	end)

	-- Initial state

	refreshCurrentState()
	notifyObservers()
end

function GameUI.Observe(callback)
	table.insert(observers, callback)

	if not isInitialized then
		initialize()

		isInitialized = true
	end
end

function GameUI.IsReady()
	return isInitialized
end

function GameUI.IsLoading()
	return isLoading
end

function GameUI.IsLoaded()
	return isLoaded
end

function GameUI.IsMainMenu()
	return GetSingleton('inkMenuScenario'):GetSystemRequestsHandler():IsPreGame()
end

function GameUI.IsAnyMenu()
	return isMenu
end

function GameUI.IsScene()
	return sceneTier > 2
end

function GameUI.IsScanner()
	local context = GameUI.GetContext()

	return not isMenu and (context.value == GameUI.Context.Scanning.value or context.value == GameUI.Context.QuickHack.value)
end

function GameUI.IsPopup()
	local context = GameUI.GetContext()

	return not isMenu and (context.value == GameUI.Context.RadialWheel.value or context.value == GameUI.Context.ModalPopup.value)
end

function GameUI.IsDevice()
	local context = GameUI.GetContext()

	return not isMenu and (context.value == GameUI.Context.DeviceZoom.value)
end

function GameUI.IsBraindance()
	return isBraindance
end

function GameUI.IsPhoto()
	return isPhotoMode
end

function GameUI.GetContext()
	return #contextStack > 0 and contextStack[#contextStack] or GameUI.Context.Default
end

function GameUI.GetState()
	local state = {}

	state.isLoading = GameUI.IsLoading()
	state.isLoaded = GameUI.IsLoaded()

	state.isMenu = GameUI.IsAnyMenu()
	state.isMainMenu = GameUI.IsMainMenu()
	state.isScene = GameUI.IsScene()
	state.isScanner = GameUI.IsScanner()
	state.isPopup = GameUI.IsPopup()
	state.isDevice = GameUI.IsDevice()
	state.isBraindance = GameUI.IsBraindance()
	state.isPhoto = GameUI.IsPhoto()

	state.isDefault = not state.isMenu and not state.isScene and not state.isPhoto
		and not state.isScanner and not state.isPopup and not state.isDevice and not state.isBraindance

	state.context = GameUI.GetContext()

	return state
end

function GameUI.PrintState(state)
	print('[UI State]')

	if state.isLoading then
		print('- Loading:', state.isLoading)
	elseif state.isLoaded then
		print('- Loaded:', state.isLoaded)
	end

	if state.isMenu then
		print('- Menu:', state.isMenu, state.isMainMenu and '(Main Menu)' or '')
	end

	if state.isScene then
		print('- Scene:', state.isScene)
	end

	if state.isDefault then
		print('- Default:', state.isDefault)
	end

	if state.isScanner then
		print('- Scanner:', state.isScanner)
	end

	if state.isPopup then
		print('- Popup:', state.isPopup)
	end

	if state.isDevice then
		print('- Device:', state.isDevice)
	end

	if state.isBraindance then
		print('- Braindance:', state.isBraindance)
	end

	if state.isPhoto then
		print('- Photo:', state.isPhoto)
	end

	print('- Context:', state.context)
end

return GameUI