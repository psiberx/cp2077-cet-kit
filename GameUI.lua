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
local observers = {}

local function notifyObservers()
	for _, callback in ipairs(observers) do
		callback(GameUI.GetState())
	end

	if isLoaded then
		isLoaded = false
	end
end

local function updateLoadingState(loadingState)
	isLoading = loadingState
	isLoaded = false
end

local function updateMenuState(menuActive)
	isMenu = menuActive or GameUI.IsMainMenu()

	if isLoading then
		if not isMenu then
			isLoading = false
			isLoaded = true
		end
	end
end

local function updateBraindanceState(braindanceActive)
	isBraindance = braindanceActive
end

local function updatePhotoModeState(photoModeActive)
	isPhotoMode = photoModeActive
end

local function updateSceneTierState(sceneTierValue)
	sceneTier = sceneTierValue -- gamePSMHighLevel?
end

local function updateContext(oldContext, newContext)
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

	updateMenuState(blackboardUI:GetBool(blackboardDefs.UI_System.IsInMenu))
	updateBraindanceState(blackboardBD:GetBool(blackboardDefs.Braindance.IsActive))
	updatePhotoModeState(blackboardPM:GetBool(blackboardDefs.PhotoMode.IsActive))
	updateSceneTierState(blackboardPSM:GetInt(blackboardDefs.PlayerStateMachine.SceneTier))
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
			updateLoadingState(true)
			notifyObservers()
		end
	end)

	Observe('SingleplayerMenuGameController', 'OnSavesReady', function()
		updateLoadingState(false)
		updateMenuState(true)
		updateBraindanceState(false)
		updatePhotoModeState(false)
		updateSceneTierState(4)
		notifyObservers()
	end)

	Observe('RadialWheelController', 'OnIsInMenuChanged', function(menuActive)
		updateMenuState(menuActive)
		if isLoaded then
			refreshCurrentState()
		end
		notifyObservers()
	end)

	Observe('BraindanceGameController', 'OnIsActiveUpdated', function(braindanceActive)
		print('OnIsActiveUpdated', braindanceActive)
		updateBraindanceState(braindanceActive)
		notifyObservers()
	end)

	Observe('CrosshairGameController_NoWeapon', 'OnPSMSceneTierChanged', function(sceneTierValue)
		updateSceneTierState(sceneTierValue)
		notifyObservers()
	end)

	Observe('gameuiPhotoModeMenuController', 'OnShow', function()
		updatePhotoModeState(true)
		notifyObservers()
	end)

	Observe('gameuiPhotoModeMenuController', 'OnHide', function()
		updatePhotoModeState(false)
		notifyObservers()
	end)

	Observe('gameuiGameSystemUI', 'PushGameContext', function(self, newContext)
		updateContext(nil, newContext)
		notifyObservers()
	end)

	Observe('gameuiGameSystemUI', 'PopGameContext', function(self, oldContext)
		updateContext(oldContext, nil)
		notifyObservers()
	end)

	Observe('gameuiGameSystemUI', 'SwapGameContext', function(self, oldContext, newContext)
		-- bugfix: new context is broken
		if oldContext.value == GameUI.Context.Scanning.value then
			newContext = GameUI.Context.QuickHack
		elseif oldContext.value == GameUI.Context.QuickHack.value then
			newContext = GameUI.Context.Scanning
		end

		updateContext(oldContext, newContext)
		notifyObservers()
	end)

	Observe('gameuiGameSystemUI', 'ResetGameContext', function()
		updateContext()
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