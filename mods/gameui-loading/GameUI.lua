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

local GameUI = { version = '0.9.1' }

GameUI.Event = {
	Braindance = 'Braindance',
	Camera = 'Camera',
	Context = 'Context',
	FastTravel = 'FastTravel',
	FastTraveled = 'FastTraveled',
	Loaded = 'Loaded',
	Loading = 'Loading',
	Menu = 'Menu',
	Photo = 'Photo',
	Unloaded = 'Unloaded',
	Update = 'Update',
	Vehicle = 'Vehicle',
}

GameUI.Menu = {
	Attributes = 'Attributes',
	BodyType = 'BodyType',
	Brightness = 'Brightness',
	Controller = 'Controller',
	Credits = 'Credits',
	Customization = 'Customization',
	DeathMenu = 'DeathMenu',
	Difficulty = 'Difficulty',
	FastTravel = 'FastTravel',
	HDR = 'HDR',
	Hub = 'Hub',
	LifePath = 'LifePath',
	LoadGame = 'LoadGame',
	MainMenu = 'MainMenu',
	Map = 'Map',
	NetworkBreach = 'NetworkBreach',
	NewGame = 'NewGame',
	PauseMenu = 'PauseMenu',
	RipperDoc = 'RipperDoc',
	SaveGame = 'SaveGame',
	Settings = 'Settings',
	Stash = 'Stash',
	Summary = 'Summary',
	Trade = 'Trade',
	Vendor = 'Vendor',
}

GameUI.Camera = {
	FirstPerson = 'FirstPerson',
	ThirdPerson = 'ThirdPerson',
}

local initialized = {}
local listeners = {}
local previousState = { isDetached = true, menu = false }

local isDetached = true
local isLoaded = false
local isLoading = false
local isMenu = true
local isVehicle = false
local isBraindance = false
local isFastTravel = false
local isPhotoMode = false
local sceneTier = 4
local currentMenu = false
local currentSubmenu = false
local currentCamera = GameUI.Camera.FirstPerson
local contextStack = {}

local stateProps = {
	{ current = 'isLoaded', previous = nil, event = { on = GameUI.Event.Loaded } },
	{ current = 'isDetached', previous = nil, event = { on = GameUI.Event.Unloaded } },
	{ current = 'isLoading', previous = 'wasLoading', event = { change = GameUI.Event.Loading } },
	{ current = 'isMenu', previous = 'wasMenu' },
	{ current = 'isScene', previous = 'wasScene' },
	{ current = 'isVehicle', previous = 'wasVehicle', event = { change = GameUI.Event.Vehicle } },
	{ current = 'isBraindance', previous = 'wasBraindance', event = { change = GameUI.Event.Braindance } },
	{ current = 'isFastTravel', previous = 'wasFastTravel', event = { on = GameUI.Event.FastTravel, off = GameUI.Event.FastTraveled } },
	{ current = 'isDefault', previous = 'wasDefault' },
	{ current = 'isScanner', previous = 'wasScanner' },
	{ current = 'isPopup', previous = 'wasPopup' },
	{ current = 'isDevice', previous = 'wasDevice' },
	{ current = 'isPhoto', previous = 'wasPhoto', event = { change = GameUI.Event.Photo } },
	{ current = 'camera', previous = 'lastCamera', event = { change = GameUI.Event.Camera }, parent = 'isVehicle' },
	{ current = 'menu', previous = 'lastMenu', event = { change = GameUI.Event.Menu } },
	{ current = 'submenu', previous = 'lastSubmenu', event = { change = GameUI.Event.Menu } },
	{ current = 'context', previous = 'lastContext', event = { change = GameUI.Event.Context } },
}

local eventListens = {
	[GameUI.Event.Braindance] = { braindance = true },
	[GameUI.Event.Camera] = { vehicle = true },
	[GameUI.Event.Context] = { context = true },
	[GameUI.Event.FastTravel] = { fastTravel = true },
	[GameUI.Event.FastTraveled] = { fastTravel = true },
	[GameUI.Event.Loaded] = { loaded = true },
	[GameUI.Event.Loading] = { loading = true },
	[GameUI.Event.Menu] = { menu = true },
	[GameUI.Event.Photo] = { photoMode = true },
	[GameUI.Event.Unloaded] = { loaded = true },
	[GameUI.Event.Update] = { loaded = true, loading = true, menu = true, vehicle = true, braindance = true, sceneTier = true, photoMode = true, fastTravel = true, context = true },
	[GameUI.Event.Vehicle] = { vehicle = true },
}

local menuScenarios = {
	['MenuScenario_BodyTypeSelection'] = { menu = GameUI.Menu.NewGame, submenu = GameUI.Menu.BodyType },
	['MenuScenario_BoothMode'] = { menu = 'BoothMode', submenu = false },
	['MenuScenario_CharacterCustomization'] = { menu = GameUI.Menu.NewGame, submenu = GameUI.Menu.Customization },
	['MenuScenario_ClippedMenu'] = { menu = 'ClippedMenu', submenu = false },
	['MenuScenario_Credits'] = { menu = GameUI.Menu.MainMenu, submenu = GameUI.Menu.Credits },
	['MenuScenario_DeathMenu'] = { menu = GameUI.Menu.DeathMenu, submenu = false },
	['MenuScenario_Difficulty'] = { menu = GameUI.Menu.NewGame, submenu = GameUI.Menu.Difficulty },
	['MenuScenario_E3EndMenu'] = { menu = 'E3EndMenu', submenu = false },
	['MenuScenario_FastTravel'] = { menu = GameUI.Menu.FastTravel, submenu = GameUI.Menu.Map },
	['MenuScenario_FinalBoards'] = { menu = 'FinalBoards', submenu = false },
	['MenuScenario_FindServers'] = { menu = 'FindServers', submenu = false },
	['MenuScenario_HubMenu'] = { menu = GameUI.Menu.Hub, submenu = false },
	['MenuScenario_Idle'] = { menu = false, submenu = false },
	['MenuScenario_LifePathSelection'] = { menu = GameUI.Menu.NewGame, submenu = GameUI.Menu.LifePath },
	['MenuScenario_LoadGame'] = { menu = GameUI.Menu.MainMenu, submenu = GameUI.Menu.LoadGame },
	['MenuScenario_MultiplayerMenu'] = { menu = 'Multiplayer', submenu = false },
	['MenuScenario_NetworkBreach'] = { menu = 'NetworkBreach', submenu = false },
	['MenuScenario_NewGame'] = { menu = GameUI.Menu.NewGame, submenu = false },
	['MenuScenario_PauseMenu'] = { menu = GameUI.Menu.PauseMenu, submenu = false },
	['MenuScenario_PlayRecordedSession'] = { menu = 'PlayRecordedSession', submenu = false },
	['MenuScenario_PreGameSubMenu'] = { menu = 'PreGameSubMenu', submenu = false },
	['MenuScenario_Settings'] = { menu = GameUI.Menu.MainMenu, submenu = GameUI.Menu.Settings },
	['MenuScenario_SingleplayerMenu'] = { menu = GameUI.Menu.MainMenu, submenu = false },
	['MenuScenario_StatsAdjustment'] = { menu = GameUI.Menu.NewGame, submenu = GameUI.Menu.Attributes },
	['MenuScenario_Storage'] = { menu = GameUI.Menu.Stash, submenu = false },
	['MenuScenario_Summary'] = { menu = GameUI.Menu.NewGame, submenu = GameUI.Menu.Summary },
	['MenuScenario_Vendor'] = { menu = GameUI.Menu.Vendor, submenu = false },
}

local function toStudlyCase(s)
	return (s:lower():gsub('_*(%l)(%w*)', function(first, rest)
		return string.upper(first) .. rest
	end))
end

local function updateDetached(detached)
	isDetached = detached
	isLoaded = false
end

local function updateLoaded(loaded)
	isDetached = not loaded
	isLoaded = loaded
end

local function updateLoading(loading)
	isLoading = loading
end

local function updateMenu(menuActive)
	isMenu = menuActive or GameUI.IsMainMenu()
end

local function updateMenuScenario(scenarioName)
	local scenario = menuScenarios[scenarioName] or menuScenarios['MenuScenario_Idle']

	isMenu = scenario.menu ~= false
	currentMenu = scenario.menu
	currentSubmenu = scenario.submenu
end

local function updateMenuItem(itemName)
	currentSubmenu = itemName or nil
end

local function updateVehicle(vehicleActive, cameraMode)
	isVehicle = vehicleActive
	currentCamera = cameraMode and GameUI.Camera.ThirdPerson or GameUI.Camera.FirstPerson
end

local function updateBraindance(braindanceActive)
	isBraindance = braindanceActive
end

local function updateFastTravel(fastTravelActive)
	isFastTravel = fastTravelActive
end

local function updatePhotoMode(photoModeActive)
	isPhotoMode = photoModeActive
end

local function updateSceneTier(sceneTierValue)
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
	local blackboardVH = Game.GetBlackboardSystem():Get(blackboardDefs.UI_ActiveVehicleData)
	local blackboardBD = Game.GetBlackboardSystem():Get(blackboardDefs.Braindance)
	local blackboardPM = Game.GetBlackboardSystem():Get(blackboardDefs.PhotoMode)
	local blackboardPSM = Game.GetBlackboardSystem():GetLocalInstanced(playerId, blackboardDefs.PlayerStateMachine)

	updateMenu(blackboardUI:GetBool(blackboardDefs.UI_System.IsInMenu))
	updateVehicle(blackboardVH:GetBool(blackboardDefs.UI_ActiveVehicleData.IsPlayerMounted, blackboardDefs.UI_ActiveVehicleData.IsTPPCameraOn))
	updateBraindance(blackboardBD:GetBool(blackboardDefs.Braindance.IsActive))
	updatePhotoMode(blackboardPM:GetBool(blackboardDefs.PhotoMode.IsActive))
	updateSceneTier(blackboardPSM:GetInt(blackboardDefs.PlayerStateMachine.SceneTier))

	if not isLoaded then
		updateDetached(GetSingleton('inkMenuScenario'):GetSystemRequestsHandler():IsPreGame())

		if isDetached then
			currentMenu = GameUI.Menu.MainMenu
		end
	end
end

local function notifyObservers()
	local currentState = GameUI.GetState()
	local stateChanged = false

	for _, stateProp in ipairs(stateProps) do
		local currentValue = currentState[stateProp.current]
		local previousValue = previousState[stateProp.current]

		if tostring(currentValue) ~= tostring(previousValue) then
			stateChanged = true
			break
		end
	end

	if stateChanged then
		for _, listener in ipairs(listeners) do
			if listener.event == GameUI.Event.Update or listener.event == currentState.event then
				listener.callback(currentState)
			end
		end

		if isLoaded then
			isLoaded = false
		end

		previousState = currentState
	end
end

local function pushCurrentState()
	previousState = GameUI.GetState()
end

local function initialize(event)
	if not initialized.data then
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

		initialized.data = true
	end

	local listen = eventListens[event] or eventListens[GameUI.Event.Update]

	-- Loaded State Listeners

	if listen.loaded and not initialized.loaded then
		Observe('PlayerPuppet', 'OnDetach', function()
			--spdlog.info(('PlayerPuppet::OnDetach()'))

			if isMenu then
				updateDetached(true)
				updateBraindance(false)
				updatePhotoMode(false)
				updateContext()

				if currentMenu ~= GameUI.Menu.MainMenu then
					notifyObservers()
				else
					pushCurrentState()
				end
			end
		end)

		Observe('RadialWheelController', 'OnIsInMenuChanged', function(menuActive)
			--spdlog.info(('RadialWheelController::OnIsInMenuChanged(%s)'):format(tostring(menuActive)))

			if isDetached then
				if not menuActive then
					updateLoaded(true)
					updateMenuScenario()
					refreshCurrentState()
					notifyObservers()
				end
			else
				updateMenu(menuActive)
			end
		end)

		initialized.loaded = true
	end

	-- Loading State Listeners

	if listen.loading and not initialized.loading then
		Observe('LoadingScreenProgressBarController', 'OnInitialize', function()
			--spdlog.info(('LoadingScreenProgressBarController::OnInitialize()'))

			updateLoading(true)
			notifyObservers()
		end)

		Observe('LoadingScreenProgressBarController', 'SetProgress', function(_, progress)
			--spdlog.info(('LoadingScreenProgressBarController::SetProgress(%.3f)'):format(progress))

			if progress == 1.0 then
				updateLoading(false)
				notifyObservers()
			end
		end)

		initialized.loading = true
	end

	-- Menu State Listeners

	if listen.menu and not initialized.menu then
		Observe('inkMenuScenario', 'SwitchToScenario', function(_, menuName)
			--spdlog.info(('inkMenuScenario::SwitchToScenario(%q)'):format(Game.NameToString(menuName)))
			Game.GetPlayer() -- env fix

			updateMenuScenario(Game.NameToString(menuName))
			notifyObservers()
		end)

		--Observe('MenuScenario_BaseMenu', 'SwitchMenu', function(self, menuName)
		--	print('SwitchMenu', Game.NameToString(menuName))
		--end)

		Observe('MenuScenario_HubMenu', 'OnSelectMenuItem', function(menuItemData)
			--spdlog.info(('MenuScenario_HubMenu::OnSelectMenuItem(%q)'):format(menuItemData.menuData.label))
			Game.GetPlayer() -- env fix

			updateMenuItem(toStudlyCase(menuItemData.menuData.label))
			notifyObservers()
		end)

		Observe('MenuScenario_HubMenu', 'OnCloseHubMenu', function(_)
			--spdlog.info(('MenuScenario_HubMenu::OnCloseHubMenu()'))

			updateMenuItem(false)
			notifyObservers()
		end)

		local menuItemListeners = {
			['MenuScenario_SingleplayerMenu'] = {
				['OnLoadGame'] = GameUI.Menu.LoadGame,
			},
			['MenuScenario_PauseMenu'] = {
				['OnSwitchToBrightnessSettings'] = GameUI.Menu.Brightness,
				['OnSwitchToControllerPanel'] = GameUI.Menu.Controller,
				['OnSwitchToCredits'] = GameUI.Menu.Credits,
				['OnSwitchToHDRSettings'] = GameUI.Menu.HDR,
				['OnSwitchToLoadGame'] = GameUI.Menu.LoadGame,
				['OnSwitchToSaveGame'] = GameUI.Menu.SaveGame,
				['OnSwitchToSettings'] = GameUI.Menu.Settings,
			},
			['MenuScenario_DeathMenu'] = {
				['OnSwitchToBrightnessSettings'] = GameUI.Menu.Brightness,
				['OnSwitchToControllerPanel'] = GameUI.Menu.Controller,
				['OnSwitchToHDRSettings'] = GameUI.Menu.HDR,
				['OnSwitchToLoadGame'] = GameUI.Menu.LoadGame,
				['OnSwitchToSettings'] = GameUI.Menu.Settings,
			},
			['MenuScenario_Vendor'] = {
				['OnSwitchToVendor'] = GameUI.Menu.Trade,
				['OnSwitchToRipperDoc'] = GameUI.Menu.RipperDoc,
				['OnSwitchToCrafting'] = 'Crafting',
			},
		}

		for menuScenario, menuItemEvents in pairs(menuItemListeners) do
			for menuEvent, menuItem in pairs(menuItemEvents) do
				Observe(menuScenario, menuEvent, function()
					--spdlog.info(('%s::%s()'):format(menuScenario, menuEvent))

					updateMenuScenario(menuScenario)
					updateMenuItem(menuItem)
					notifyObservers()
				end)
			end
		end

		local menuBackListeners = {
			['MenuScenario_PauseMenu'] = 'GoBack',
			['MenuScenario_DeathMenu'] = 'GoBack',
		}

		for menuScenario, menuBackEvent in pairs(menuBackListeners) do
			Observe(menuScenario, menuBackEvent, function(self)
				--spdlog.info(('%s::%s()'):format(menuScenario, menuBackEvent))

				if Game.NameToString(self.prevMenuName) == 'settings_main' then
					updateMenuItem(GameUI.Menu.Settings)
				else
					updateMenuItem(false)
				end

				notifyObservers()
			end)
		end

		Observe('SingleplayerMenuGameController', 'OnSavesReady', function()
			--spdlog.info(('SingleplayerMenuGameController::OnSavesReady()'))

			--updateDetached(false)
			updateMenuScenario('MenuScenario_SingleplayerMenu')
			updateBraindance(false)
			updatePhotoMode(false)
			updateSceneTier(4)
			notifyObservers()
		end)

		initialized.menu = true
	end

	-- Vehicle State Listeners

	if listen.vehicle and not initialized.vehicle then
		Observe('hudCarController', 'OnCameraModeChanged', function(mode)
			--spdlog.info(('hudCarController::OnCameraModeChanged(%s)'):format(tostring(mode)))

			updateVehicle(true, mode)
			notifyObservers()
		end)

		Observe('hudCarController', 'OnUnmountingEvent', function()
			--spdlog.info(('hudCarController::OnUnmountingEvent()'))

			updateVehicle(false)
			notifyObservers()
		end)

		initialized.vehicle = true
	end

	-- Braindance State Listeners

	if listen.braindance and not initialized.braindance then
		Observe('BraindanceGameController', 'OnIsActiveUpdated', function(braindanceActive)
			--spdlog.info(('BraindanceGameController::OnIsActiveUpdated(%s)'):format(tostring(braindanceActive)))

			updateBraindance(braindanceActive)
			notifyObservers()
		end)

		initialized.braindance = true
	end

	-- Scene State Listeners

	if listen.sceneTier and not initialized.sceneTier then
		Observe('CrosshairGameController_NoWeapon', 'OnPSMSceneTierChanged', function(sceneTierValue)
			--spdlog.info(('CrosshairGameController_NoWeapon::OnPSMSceneTierChanged(%d)'):format(sceneTierValue))

			updateSceneTier(sceneTierValue)
			notifyObservers()
		end)

		initialized.sceneTier = true
	end

	-- Photo Mode Listeners

	if listen.photoMode and not initialized.photoMode then
		Observe('gameuiPhotoModeMenuController', 'OnShow', function()
			--spdlog.info(('PhotoModeMenuController::OnShow()'))

			updatePhotoMode(true)
			notifyObservers()
		end)

		Observe('gameuiPhotoModeMenuController', 'OnHide', function()
			--spdlog.info(('PhotoModeMenuController::OnHide()'))

			updatePhotoMode(false)
			notifyObservers()
		end)

		initialized.photoMode = true
	end

	-- Fast Travel Listeners

	if listen.fastTravel and not initialized.fastTravel then
		local fastTravelStart

		Observe('FastTravelSystem', 'OnToggleFastTravelAvailabilityOnMapRequest', function(request)
			--spdlog.info(('FastTravelSystem::OnToggleFastTravelAvailabilityOnMapRequest()'))

			if request.isEnabled then
				fastTravelStart = request.pointRecord
			end
		end)

		Observe('FastTravelSystem', 'OnPerformFastTravelRequest', function(request)
			--spdlog.info(('FastTravelSystem::OnPerformFastTravelRequest()'))

			local fastTravelDestination = request.pointData.pointRecord

			if tostring(fastTravelStart) ~= tostring(fastTravelDestination) then
				updateFastTravel(true)
				notifyObservers()
			end
		end)

		Observe('FastTravelSystem', 'OnLoadingScreenFinished', function(finished)
			--spdlog.info(('FastTravelSystem::OnLoadingScreenFinished(%s)'):format(tostring(finished)))

			if isFastTravel and finished then
				updateFastTravel(false)
				refreshCurrentState()
				notifyObservers()
			end
		end)

		initialized.fastTravel = true
	end

	-- UI Context Listeners

	if listen.context and not initialized.context then
		Observe('gameuiGameSystemUI', 'PushGameContext', function(_, newContext)
			--spdlog.info(('GameSystemUI::PushGameContext(%q)'):format(tostring(newContext)))

			if isBraindance and newContext.value == GameUI.Context.Scanning.value then
				return
			end

			updateContext(nil, newContext)
			notifyObservers()
		end)

		Observe('gameuiGameSystemUI', 'PopGameContext', function(_, oldContext)
			--spdlog.info(('GameSystemUI::PopGameContext(%q)'):format(tostring(oldContext)))

			if isBraindance and oldContext.value == GameUI.Context.Scanning.value then
				return
			end

			updateContext(oldContext, nil)
			notifyObservers()
		end)

		Observe('HUDManager', 'OnQuickHackUIVisibleChanged', function(quickhacking)
			--spdlog.info(('HUDManager::OnQuickHackUIVisibleChanged(%s)'):format(tostring(quickhacking)))

			if quickhacking then
				updateContext(nil, GameUI.Context.QuickHack)
			else
				updateContext(GameUI.Context.QuickHack, nil)
			end

			notifyObservers()
		end)

		--[[ This can cause crashes for some users ]]
		--Observe('gameuiGameSystemUI', 'SwapGameContext', function(_, oldContext, newContext)
		--	--spdlog.info(('GameSystemUI::SwapGameContext(%q, %q)'):format(tostring(oldContext), tostring(newContext)))
		--
		--	-- bugfix: new context is broken
		--	if oldContext.value == GameUI.Context.Scanning.value then
		--		newContext = GameUI.Context.QuickHack
		--	elseif oldContext.value == GameUI.Context.QuickHack.value then
		--		newContext = GameUI.Context.Scanning
		--	end
		--
		--	updateContext(oldContext, newContext)
		--	notifyObservers()
		--end)

		Observe('gameuiGameSystemUI', 'ResetGameContext', function()
			--spdlog.info(('GameSystemUI::ResetGameContext()'))

			updateContext()
			notifyObservers()
		end)

		initialized.context = true
	end

	-- Initial state

	if not initialized.state then
		refreshCurrentState()

		initialized.state = true
	end
end

function GameUI.Observe(callback)
	if type(callback) == 'function' then
		table.insert(listeners, { event = GameUI.Event.Update, callback = callback })
	end

	initialize()
end

function GameUI.Listen(event, callback)
	if type(callback) == 'function' then
		table.insert(listeners, { event = event, callback = callback })

		initialize(event)
	end
end

function GameUI.OnLoaded(callback)
	if type(callback) == 'function' then
		table.insert(listeners, { event = GameUI.Event.Loaded, callback = callback })

		initialize(GameUI.Event.Loaded)
	end
end

function GameUI.OnUnloaded(callback)
	if type(callback) == 'function' then
		table.insert(listeners, { event = GameUI.Event.Unloaded, callback = callback })

		initialize(GameUI.Event.Unloaded)
	end
end

function GameUI.OnFastTravel(callback)
	if type(callback) == 'function' then
		table.insert(listeners, { event = GameUI.Event.FastTravel, callback = callback })

		initialize(GameUI.Event.FastTravel)
	end
end

function GameUI.OnFastTraveled(callback)
	if type(callback) == 'function' then
		table.insert(listeners, { event = GameUI.Event.FastTraveled, callback = callback })

		initialize(GameUI.Event.FastTraveled)
	end
end

function GameUI.IsDetached()
	return isDetached
end

function GameUI.IsLoading()
	return isLoading
end

function GameUI.IsAnyMenu()
	return isMenu or isLoading or isFastTravel
end

function GameUI.IsMainMenu()
	return currentMenu == GameUI.Menu.MainMenu
	--return GetSingleton('inkMenuScenario'):GetSystemRequestsHandler():IsPreGame()
end

function GameUI.IsScene()
	return sceneTier > 2 and not GameUI.IsMainMenu()
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

function GameUI.IsVehicle()
	return isVehicle
end

function GameUI.IsBraindance()
	return isBraindance
end

function GameUI.IsFastTravel()
	return isFastTravel
end

function GameUI.IsPhoto()
	return isPhotoMode
end

function GameUI.GetMenu()
	return currentMenu
end

function GameUI.GetSubmenu()
	return currentSubmenu
end

function GameUI.GetCamera()
	return currentCamera
end

function GameUI.GetContext()
	return #contextStack > 0 and contextStack[#contextStack] or GameUI.Context.Default
end

function GameUI.GetState()
	local currentState = {}

	currentState.isDetached = GameUI.IsDetached()
	currentState.isLoading = GameUI.IsLoading()
	currentState.isLoaded = isLoaded

	currentState.isMenu = GameUI.IsAnyMenu()
	currentState.isScene = GameUI.IsScene()
	currentState.isVehicle = GameUI.IsVehicle()
	currentState.isBraindance = GameUI.IsBraindance()
	currentState.isFastTravel = GameUI.IsFastTravel()
	currentState.isScanner = GameUI.IsScanner()
	currentState.isPopup = GameUI.IsPopup()
	currentState.isDevice = GameUI.IsDevice()
	currentState.isPhoto = GameUI.IsPhoto()

	currentState.isDefault = not currentState.isMenu and not currentState.isScene
		and not currentState.isBraindance and not currentState.isFastTravel and not currentState.isPhoto
		and not currentState.isScanner and not currentState.isPopup and not currentState.isDevice

	currentState.menu = GameUI.GetMenu()
	currentState.submenu = GameUI.GetSubmenu()
	currentState.camera = GameUI.GetCamera()
	currentState.context = GameUI.GetContext()

	for _, stateProp in ipairs(stateProps) do
		local currentValue = currentState[stateProp.current]
		local previousValue = previousState[stateProp.current]

		if stateProp.previous then
			currentState[stateProp.previous] = previousValue
		end

		if not currentState.event and stateProp.event then
			if stateProp.event.on and currentValue and not previousValue then
				currentState.event = stateProp.event.on
			elseif stateProp.event.off and not currentValue and previousValue then
				currentState.event = stateProp.event.off
			elseif stateProp.event.change then
				if previousValue ~= nil and tostring(currentValue) ~= tostring(previousValue) then
					currentState.event = stateProp.event.change
				end
			end
		end
	end

	return currentState
end

function GameUI.ExportState(state)
	local export = {}

	for _, stateProp in ipairs(stateProps) do
		local value = state[stateProp.current]

		if value and (not stateProp.parent or state[stateProp.parent]) then
			if type(value) == 'userdata' then
				value = 'GameUI.Context.' .. value.value
			elseif type(value) == 'string' then
				value = string.format('%q', value)
			else
				value = tostring(value)
			end

			table.insert(export, stateProp.current .. ' = ' .. value)
		end
	end

	for _, stateProp in ipairs(stateProps) do
		if stateProp.previous then
			local currentValue = state[stateProp.current]
			local previousValue = state[stateProp.previous]

			if previousValue and previousValue ~= currentValue then
				if type(previousValue) == 'userdata' then
					previousValue = 'GameUI.Context.' .. previousValue.value
				elseif type(previousValue) == 'string' then
					previousValue = string.format('%q', previousValue)
				else
					previousValue = tostring(previousValue)
				end

				table.insert(export, stateProp.previous .. ' = ' .. previousValue)
			end
		end
	end

	if state.event then
		table.insert(export, 'event = ' .. string.format('%q', state.event))
	end

	return '{ ' .. table.concat(export, ', ') .. ' }'
end

function GameUI.PrintState(state, expanded, all)
	if not expanded then
		print('[UI State] ' .. GameUI.ExportState(state))
		return
	end

	print('[UI State]')

	if state.event then
		print('- Event:', state.event)
	end

	if state.isDetached then
		print('- Detached:', state.isDetached)
	elseif state.isLoaded then
		print('- Loaded:', state.isLoaded)
	end

	if state.isLoading then
		print('- Loading:', state.isLoading)
	end

	if state.isMenu or all then
		print('- Menu:', state.isMenu, state.menu and '(' .. state.menu .. (state.submenu and ' / ' .. state.submenu or '') .. ')' or '')
	end

	if state.isScene or all then
		print('- Scene:', state.isScene)
	end

	if state.isVehicle or all then
		print('- Vehicle:', state.isVehicle, state.camera and '(' .. state.camera .. ')' or '')
	end

	if state.isBraindance or all then
		print('- Braindance:', state.isBraindance)
	end

	if state.isFastTravel or all then
		print('- Fast Travel:', state.isFastTravel)
	end

	if state.isDefault or all then
		print('- Default:', state.isDefault)
	end

	if state.isScanner or all then
		print('- Scanner:', state.isScanner)
	end

	if state.isPopup or all then
		print('- Popup:', state.isPopup)
	end

	if state.isDevice or all then
		print('- Device:', state.isDevice)
	end

	if state.isPhoto or all then
		print('- Photo:', state.isPhoto)
	end

	print('- Context:', state.context)
end

return GameUI