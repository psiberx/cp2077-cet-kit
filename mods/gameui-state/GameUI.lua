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

local GameUI = { version = '0.9.5' }

GameUI.Event = {
	Braindance = 'Braindance',
	BraindanceEnter = 'BraindanceEnter',
	BraindanceExit = 'BraindanceExit',
	Camera = 'Camera',
	Context = 'Context',
	Device = 'Device',
	DeviceEnter = 'DeviceEnter',
	DeviceExit = 'DeviceExit',
	FastTravel = 'FastTravel',
	FastTravelFinish = 'FastTravelFinish',
	FastTravelStart = 'FastTravelStart',
	Loading = 'Loading',
	LoadingFinish = 'LoadingFinish',
	LoadingStart = 'LoadingStart',
	Menu = 'Menu',
	MenuClose = 'MenuClose',
	MenuNav = 'MenuNav',
	MenuOpen = 'MenuOpen',
	PhotoMode = 'PhotoMode',
	PhotoModeClose = 'PhotoModeClose',
	PhotoModeOpen = 'PhotoModeOpen',
	Popup = 'Popup',
	PopupClose = 'PopupClose',
	PopupOpen = 'PopupOpen',
	QuickHack = 'QuickHack',
	QuickHackClose = 'QuickHackClose',
	QuickHackOpen = 'QuickHackOpen',
	Scanner = 'Scanner',
	ScannerClose = 'ScannerClose',
	ScannerOpen = 'ScannerOpen',
	Scene = 'Scene',
	SceneEnter = 'SceneEnter',
	SceneExit = 'SceneExit',
	Session = 'Session',
	SessionEnd = 'SessionEnd',
	SessionStart = 'SessionStart',
	Update = 'Update',
	Vehicle = 'Vehicle',
	VehicleEnter = 'VehicleEnter',
	VehicleExit = 'VehicleExit',
	Wheel = 'Wheel',
	WheelClose = 'WheelClose',
	WheelOpen = 'WheelOpen',
}

GameUI.StateEvent = {
	[GameUI.Event.Braindance] = GameUI.Event.Braindance,
	[GameUI.Event.Context] = GameUI.Event.Context,
	[GameUI.Event.Device] = GameUI.Event.Device,
	[GameUI.Event.FastTravel] = GameUI.Event.FastTravel,
	[GameUI.Event.Loading] = GameUI.Event.Loading,
	[GameUI.Event.Menu] = GameUI.Event.Menu,
	[GameUI.Event.PhotoMode] = GameUI.Event.PhotoMode,
	[GameUI.Event.Popup] = GameUI.Event.Popup,
	[GameUI.Event.QuickHack] = GameUI.Event.QuickHack,
	[GameUI.Event.Scanner] = GameUI.Event.Scanner,
	[GameUI.Event.Scene] = GameUI.Event.Scene,
	[GameUI.Event.Session] = GameUI.Event.Session,
	[GameUI.Event.Update] = GameUI.Event.Update,
	[GameUI.Event.Vehicle] = GameUI.Event.Vehicle,
	[GameUI.Event.Wheel] = GameUI.Event.Wheel,
}

GameUI.Camera = {
	FirstPerson = 'FirstPerson',
	ThirdPerson = 'ThirdPerson',
}

local initialized = {}
local listeners = {}
local previousState = {
	isDetached = true,
	isMenu = false,
	menu = false,
}

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
	{ current = 'isLoaded', previous = nil, event = { change = GameUI.Event.Session, on = GameUI.Event.SessionStart } },
	{ current = 'isDetached', previous = nil, event = { change = GameUI.Event.Session, on = GameUI.Event.SessionEnd } },
	{ current = 'isLoading', previous = 'wasLoading', event = { change = GameUI.Event.Loading, on = GameUI.Event.LoadingStart, off = GameUI.Event.LoadingFinish } },
	{ current = 'isMenu', previous = 'wasMenu', event = { change = GameUI.Event.Menu, on = GameUI.Event.MenuOpen, off = GameUI.Event.MenuClose } },
	{ current = 'isScene', previous = 'wasScene', event = { change = GameUI.Event.Scene, on = GameUI.Event.SceneEnter, off = GameUI.Event.SceneExit } },
	{ current = 'isVehicle', previous = 'wasVehicle', event = { change = GameUI.Event.Vehicle, on = GameUI.Event.VehicleEnter, off = GameUI.Event.VehicleExit } },
	{ current = 'isBraindance', previous = 'wasBraindance', event = { change = GameUI.Event.Braindance, on = GameUI.Event.BraindanceEnter, off = GameUI.Event.BraindanceExit } },
	{ current = 'isFastTravel', previous = 'wasFastTravel', event = { change = GameUI.Event.FastTravel, on = GameUI.Event.FastTravelStart, off = GameUI.Event.FastTravelFinish } },
	{ current = 'isDefault', previous = 'wasDefault' },
	{ current = 'isScanner', previous = 'wasScanner', event = { change = GameUI.Event.Scanner, on = GameUI.Event.ScannerOpen, off = GameUI.Event.ScannerClose, scope = GameUI.Event.Context } },
	{ current = 'isQuickHack', previous = 'wasQuickHack', event = { change = GameUI.Event.QuickHack, on = GameUI.Event.QuickHackOpen, off = GameUI.Event.QuickHackClose, scope = GameUI.Event.Context } },
	{ current = 'isPopup', previous = 'wasPopup', event = { change = GameUI.Event.Popup, on = GameUI.Event.PopupOpen, off = GameUI.Event.PopupClose, scope = GameUI.Event.Context } },
	{ current = 'isWheel', previous = 'wasWheel', event = { change = GameUI.Event.Wheel, on = GameUI.Event.WheelOpen, off = GameUI.Event.WheelClose, scope = GameUI.Event.Context } },
	{ current = 'isDevice', previous = 'wasDevice', event = { change = GameUI.Event.Device, on = GameUI.Event.DeviceEnter, off = GameUI.Event.DeviceExit, scope = GameUI.Event.Context } },
	{ current = 'isPhoto', previous = 'wasPhoto', event = { change = GameUI.Event.PhotoMode, on = GameUI.Event.PhotoModeOpen, off = GameUI.Event.PhotoModeClose } },
	{ current = 'menu', previous = 'lastMenu', event = { change = GameUI.Event.MenuNav, reqs = { isMenu = true, wasMenu = true }, scope = GameUI.Event.Menu } },
	{ current = 'submenu', previous = 'lastSubmenu', event = { change = GameUI.Event.MenuNav, reqs = { isMenu = true, wasMenu = true }, scope = GameUI.Event.Menu } },
	{ current = 'camera', previous = 'lastCamera', event = { change = GameUI.Event.Camera, scope = GameUI.Event.Vehicle }, parent = 'isVehicle' },
	{ current = 'context', previous = 'lastContext', event = { change = GameUI.Event.Context } },
}

local menuScenarios = {
	['MenuScenario_BodyTypeSelection'] = { menu = 'NewGame', submenu = 'BodyType' },
	['MenuScenario_BoothMode'] = { menu = 'BoothMode', submenu = false },
	['MenuScenario_CharacterCustomization'] = { menu = 'NewGame', submenu = 'Customization' },
	['MenuScenario_ClippedMenu'] = { menu = 'ClippedMenu', submenu = false },
	['MenuScenario_Credits'] = { menu = 'MainMenu', submenu = 'Credits' },
	['MenuScenario_DeathMenu'] = { menu = 'DeathMenu', submenu = false },
	['MenuScenario_Difficulty'] = { menu = 'NewGame', submenu = 'Difficulty' },
	['MenuScenario_E3EndMenu'] = { menu = 'E3EndMenu', submenu = false },
	['MenuScenario_FastTravel'] = { menu = 'FastTravel', submenu = 'Map' },
	['MenuScenario_FinalBoards'] = { menu = 'FinalBoards', submenu = false },
	['MenuScenario_FindServers'] = { menu = 'FindServers', submenu = false },
	['MenuScenario_HubMenu'] = { menu = 'Hub', submenu = false },
	['MenuScenario_Idle'] = { menu = false, submenu = false },
	['MenuScenario_LifePathSelection'] = { menu = 'NewGame', submenu = 'LifePath' },
	['MenuScenario_LoadGame'] = { menu = 'MainMenu', submenu = 'LoadGame' },
	['MenuScenario_MultiplayerMenu'] = { menu = 'Multiplayer', submenu = false },
	['MenuScenario_NetworkBreach'] = { menu = 'NetworkBreach', submenu = false },
	['MenuScenario_NewGame'] = { menu = 'NewGame', submenu = false },
	['MenuScenario_PauseMenu'] = { menu = 'PauseMenu', submenu = false },
	['MenuScenario_PlayRecordedSession'] = { menu = 'PlayRecordedSession', submenu = false },
	['MenuScenario_PreGameSubMenu'] = { menu = 'PreGameSubMenu', submenu = false },
	['MenuScenario_Settings'] = { menu = 'MainMenu', submenu = 'Settings' },
	['MenuScenario_SingleplayerMenu'] = { menu = 'MainMenu', submenu = false },
	['MenuScenario_StatsAdjustment'] = { menu = 'NewGame', submenu = 'Attributes' },
	['MenuScenario_Storage'] = { menu = 'Stash', submenu = false },
	['MenuScenario_Summary'] = { menu = 'NewGame', submenu = 'Summary' },
	['MenuScenario_Vendor'] = { menu = 'Vendor', submenu = false },
}

local eventScopes = {
	[GameUI.Event.Update] = {}
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
	currentSubmenu = itemName or false
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
			if contextStack[position] ~= newContext then
				table.insert(contextStack, position, newContext)
			end
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
			currentMenu = 'MainMenu'
		end
	end
end

local function determineEvents(currentState)
	local events = { GameUI.Event.Update }
	local firing = {}

	for _, stateProp in ipairs(stateProps) do
		local currentValue = currentState[stateProp.current]
		local previousValue = previousState[stateProp.current]

		if stateProp.event and (not stateProp.parent or currentState[stateProp.parent]) then
			local reqSatisfied = true

			if stateProp.event.reqs then
				for reqProp, reqValue in pairs(stateProp.event.reqs) do
					if tostring(currentState[reqProp]) ~= tostring(reqValue) then
						reqSatisfied = false
						break
					end
				end
			end

			if reqSatisfied then
				if stateProp.event.change and previousValue ~= nil then
					if tostring(currentValue) ~= tostring(previousValue) then
						if not firing[stateProp.event.change] then
							table.insert(events, stateProp.event.change)
							firing[stateProp.event.change] = true
						end
					end
				end

				if stateProp.event.on and currentValue and not previousValue then
					if not firing[stateProp.event.on] then
						table.insert(events, stateProp.event.on)
						firing[stateProp.event.on] = true
					end
				elseif stateProp.event.off and not currentValue and previousValue then
					if not firing[stateProp.event.off] then
						table.insert(events, stateProp.event.off)
						firing[stateProp.event.off] = true
					end
				end
			end
		end
	end

	return events
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
		local events =  determineEvents(currentState)

		for _, event in ipairs(events) do
			if listeners[event] then
				if event ~= GameUI.Event.Update then
					currentState.event = event
				end

				for _, callback in ipairs(listeners[event]) do
					callback(currentState)
				end

				currentState.event = nil
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

		for _, stateProp in ipairs(stateProps) do
			if stateProp.event then
				local eventScope = stateProp.event.scope or stateProp.event.change

				for _, eventKey in ipairs({ 'change', 'on', 'off' }) do
					local eventName = stateProp.event[eventKey]

					if eventName then
						eventScopes[eventName] = {}
						eventScopes[eventName][eventScope] = true
					end
				end

				eventScopes[GameUI.Event.Update][eventScope] = true
			end
		end

		initialized.data = true
	end

	local required = eventScopes[event] or eventScopes[GameUI.Event.Update]

	-- Game Session Listeners

	if required[GameUI.Event.Session] and not initialized[GameUI.Event.Session] then
		
		Observe('RadialWheelController', 'RegisterBlackboards', function(_, loaded)
			--spdlog.info(('RadialWheelController::RegisterBlackboards(%s)'):format(tostring(loaded)))

			if loaded then
				updateLoaded(true)
				updateMenuScenario()
				refreshCurrentState()
				notifyObservers()
			else
				updateDetached(true)
				updateBraindance(false)
				updatePhotoMode(false)
				updateContext()

				if currentMenu ~= 'MainMenu' then
					notifyObservers()
				else
					pushCurrentState()
				end
			end
		end)

		initialized[GameUI.Event.Session] = true
	end

	-- Loading State Listeners

	if required[GameUI.Event.Loading] and not initialized[GameUI.Event.Loading] then
		Observe('LoadingScreenProgressBarController', 'OnInitialize', function()
			--spdlog.info(('LoadingScreenProgressBarController::OnInitialize()'))

			updateMenuScenario()
			updateLoading(true)
			notifyObservers()
		end)

		Observe('LoadingScreenProgressBarController', 'SetProgress', function(_, progress)
			--spdlog.info(('LoadingScreenProgressBarController::SetProgress(%.3f)'):format(progress))

			if progress == 1.0 then
				updateMenuScenario()
				updateLoading(false)
				notifyObservers()
			end
		end)

		initialized[GameUI.Event.Loading] = true
	end

	-- Menu State Listeners

	if required[GameUI.Event.Menu] and not initialized[GameUI.Event.Menu] then
		Observe('inkMenuScenario', 'SwitchToScenario', function(_, menuName)
			--spdlog.info(('inkMenuScenario::SwitchToScenario(%q)'):format(Game.NameToString(menuName)))
			Game.GetPlayer() -- env fix

			updateMenuScenario(Game.NameToString(menuName))
			notifyObservers()
		end)

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
				['OnLoadGame'] = 'LoadGame',
			},
			['MenuScenario_PauseMenu'] = {
				['OnSwitchToBrightnessSettings'] = 'Brightness',
				['OnSwitchToControllerPanel'] = 'Controller',
				['OnSwitchToCredits'] = 'Credits',
				['OnSwitchToHDRSettings'] = 'HDR',
				['OnSwitchToLoadGame'] = 'LoadGame',
				['OnSwitchToSaveGame'] = 'SaveGame',
				['OnSwitchToSettings'] = 'Settings',
			},
			['MenuScenario_DeathMenu'] = {
				['OnSwitchToBrightnessSettings'] = 'Brightness',
				['OnSwitchToControllerPanel'] = 'Controller',
				['OnSwitchToHDRSettings'] = 'HDR',
				['OnSwitchToLoadGame'] = 'LoadGame',
				['OnSwitchToSettings'] = 'Settings',
			},
			['MenuScenario_Vendor'] = {
				['OnSwitchToVendor'] = 'Trade',
				['OnSwitchToRipperDoc'] = 'RipperDoc',
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
					updateMenuItem('Settings')
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

		initialized[GameUI.Event.Menu] = true
	end

	-- Vehicle State Listeners

	if required[GameUI.Event.Vehicle] and not initialized[GameUI.Event.Vehicle] then
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

		initialized[GameUI.Event.Vehicle] = true
	end

	-- Braindance State Listeners

	if required[GameUI.Event.Braindance] and not initialized[GameUI.Event.Braindance] then
		Observe('BraindanceGameController', 'OnIsActiveUpdated', function(braindanceActive)
			--spdlog.info(('BraindanceGameController::OnIsActiveUpdated(%s)'):format(tostring(braindanceActive)))

			updateBraindance(braindanceActive)
			notifyObservers()
		end)

		initialized[GameUI.Event.Braindance] = true
	end

	-- Scene State Listeners

	if required[GameUI.Event.Scene] and not initialized[GameUI.Event.Scene] then
		Observe('CrosshairGameController_NoWeapon', 'OnPSMSceneTierChanged', function(sceneTierValue)
			--spdlog.info(('CrosshairGameController_NoWeapon::OnPSMSceneTierChanged(%d)'):format(sceneTierValue))

			updateSceneTier(sceneTierValue)
			notifyObservers()
		end)

		initialized[GameUI.Event.Scene] = true
	end

	-- Photo Mode Listeners

	if required[GameUI.Event.PhotoMode] and not initialized[GameUI.Event.PhotoMode] then
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

		initialized[GameUI.Event.PhotoMode] = true
	end

	-- Fast Travel Listeners

	if required[GameUI.Event.FastTravel] and not initialized[GameUI.Event.FastTravel] then
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
				updateLoading(true)
				updateFastTravel(true)
				notifyObservers()
			end
		end)

		Observe('FastTravelSystem', 'OnLoadingScreenFinished', function(finished)
			--spdlog.info(('FastTravelSystem::OnLoadingScreenFinished(%s)'):format(tostring(finished)))

			if isFastTravel and finished then
				updateLoading(false)
				updateFastTravel(false)
				refreshCurrentState()
				notifyObservers()
			end
		end)

		initialized[GameUI.Event.FastTravel] = true
	end

	-- UI Context Listeners

	if required[GameUI.Event.Context] and not initialized[GameUI.Event.Context] then
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

			if oldContext.value == GameUI.Context.QuickHack.value then
				oldContext = GameUI.Context.Scanning
			end

			updateContext(oldContext, nil)
			notifyObservers()
		end)

		Observe('HUDManager', 'OnQuickHackUIVisibleChanged', function(quickhacking)
			--spdlog.info(('HUDManager::OnQuickHackUIVisibleChanged(%s)'):format(tostring(quickhacking)))

			if quickhacking then
				updateContext(GameUI.Context.Scanning, GameUI.Context.QuickHack)
			else
				updateContext(GameUI.Context.QuickHack, GameUI.Context.Scanning)
			end

			notifyObservers()
		end)

		Observe('gameuiGameSystemUI', 'ResetGameContext', function()
			--spdlog.info(('GameSystemUI::ResetGameContext()'))

			updateContext()
			notifyObservers()
		end)

		initialized[GameUI.Event.Context] = true
	end

	-- Initial state

	if not initialized.state then
		refreshCurrentState()

		initialized.state = true
	end
end

function GameUI.Observe(event, callback)
	if type(event) == 'function' then
		callback = event
		event = GameUI.Event.Update
	elseif type(callback) ~= 'function' then
		return
	end

	if not listeners[event] then
		listeners[event] = {}
	end

	table.insert(listeners[event], callback)

	initialize(event)
end

function GameUI.IsDetached()
	return isDetached
end

function GameUI.IsLoading()
	return isLoading
end

function GameUI.IsMenu()
	return isMenu
end

function GameUI.IsMainMenu()
	return isMenu and currentMenu == 'MainMenu'
end

function GameUI.IsScene()
	return sceneTier > 2 and not GameUI.IsMainMenu()
end

function GameUI.IsScanner()
	local context = GameUI.GetContext()

	return not isMenu and (context.value == GameUI.Context.Scanning.value)
end

function GameUI.IsQuickHack()
	local context = GameUI.GetContext()

	return not isMenu and (context.value == GameUI.Context.QuickHack.value)
end

function GameUI.IsPopup()
	local context = GameUI.GetContext()

	return not isMenu and (context.value == GameUI.Context.ModalPopup.value)
end

function GameUI.IsWheel()
	local context = GameUI.GetContext()

	return not isMenu and (context.value == GameUI.Context.RadialWheel.value)
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

	currentState.isMenu = GameUI.IsMenu()
	currentState.isScene = GameUI.IsScene()
	currentState.isVehicle = GameUI.IsVehicle()
	currentState.isBraindance = GameUI.IsBraindance()
	currentState.isFastTravel = GameUI.IsFastTravel()
	currentState.isScanner = GameUI.IsScanner()
	currentState.isQuickHack = GameUI.IsQuickHack()
	currentState.isPopup = GameUI.IsPopup()
	currentState.isWheel = GameUI.IsWheel()
	currentState.isDevice = GameUI.IsDevice()
	currentState.isPhoto = GameUI.IsPhoto()

	currentState.isDefault = not currentState.isMenu and not currentState.isScene
		and not currentState.isBraindance and not currentState.isFastTravel and not currentState.isPhoto
		and not currentState.isScanner and not currentState.isQuickHack
		and not currentState.isPopup and not currentState.isWheel
		and not currentState.isDevice

	currentState.menu = GameUI.GetMenu()
	currentState.submenu = GameUI.GetSubmenu()
	currentState.camera = GameUI.GetCamera()
	currentState.context = GameUI.GetContext()

	for _, stateProp in ipairs(stateProps) do
		if stateProp.previous then
			currentState[stateProp.previous] = previousState[stateProp.current]
		end
	end

	return currentState
end

function GameUI.ExportState(state)
	local export = {}

	if state.event then
		table.insert(export, 'event = ' .. string.format('%q', state.event))
	end

	for _, stateProp in ipairs(stateProps) do
		local value = state[stateProp.current]

		if value and (not stateProp.parent or state[stateProp.parent]) then
			if type(value) == 'userdata' then
				value = string.format('%q', value.value) -- 'GameUI.Context.'
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
					previousValue = string.format('%q', previousValue.value) -- 'GameUI.Context.'
				elseif type(previousValue) == 'string' then
					previousValue = string.format('%q', previousValue)
				else
					previousValue = tostring(previousValue)
				end

				table.insert(export, stateProp.previous .. ' = ' .. previousValue)
			end
		end
	end

	return '{ ' .. table.concat(export, ', ') .. ' }'
end

function GameUI.PrintState(state)
	print('[UI State] ' .. GameUI.ExportState(state))
end

GameUI.On = GameUI.Observe
GameUI.Listen = GameUI.Observe

--for event, _ in pairs(GameUI.Event) do
--	GameUI['On' .. event] = function(callback)
--		GameUI.Listen(event, callback)
--	end
--end

setmetatable(GameUI, {
	__index = function(_, key)
		local event = string.match(key, '^On(%w+)$')

		if event and GameUI.Event[event] then
			return function(callback)
				GameUI.Observe(event, callback)
			end
		end
	end
})

return GameUI