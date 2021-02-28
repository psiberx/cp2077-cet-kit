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

local GameUI = { version = '0.8.1' }

local initialized = {}
local observers = {}
local listeners = {}
local previousState = { _ = false }

local isLoading = false
local isLoaded = false
local isMenu = true
local isBraindance = false
local isFastTravel = false
local isPhotoMode = false
local sceneTier = 4
local currentMenu
local currentSubmenu
local contextStack = {}

local menuScenarios = {
	['MenuScenario_BodyTypeSelection'] = { menu = 'NewGame', submenu = 'BodyType' },
	['MenuScenario_BoothMode'] = { menu = 'BoothMode', submenu = nil },
	['MenuScenario_CharacterCustomization'] = { menu = 'NewGame', submenu = 'Customization' },
	['MenuScenario_ClippedMenu'] = { menu = 'ClippedMenu', submenu = nil },
	['MenuScenario_Credits'] = { menu = 'Credits', submenu = nil },
	['MenuScenario_DeathMenu'] = { menu = 'DeathMenu', submenu = nil },
	['MenuScenario_Difficulty'] = { menu = 'NewGame', submenu = 'Difficulty' },
	['MenuScenario_E3EndMenu'] = { menu = 'E3EndMenu', submenu = nil },
	['MenuScenario_FastTravel'] = { menu = 'FastTravel', submenu = 'Map' },
	['MenuScenario_FinalBoards'] = { menu = 'FinalBoards', submenu = nil },
	['MenuScenario_FindServers'] = { menu = 'FindServers', submenu = nil },
	['MenuScenario_HubMenu'] = { menu = 'Hub', submenu = nil },
	['MenuScenario_Idle'] = { menu = nil, submenu = nil },
	['MenuScenario_LifePathSelection'] = { menu = 'NewGame', submenu = 'LifePath' },
	['MenuScenario_LoadGame'] = { menu = 'MainMenu', submenu = 'LoadGame' },
	['MenuScenario_MultiplayerMenu'] = { menu = 'Multiplayer', submenu = nil },
	['MenuScenario_NetworkBreach'] = { menu = 'NetworkBreach', submenu = nil },
	['MenuScenario_NewGame'] = { menu = 'NewGame', submenu = nil },
	['MenuScenario_PauseMenu'] = { menu = 'PauseMenu', submenu = nil },
	['MenuScenario_PlayRecordedSession'] = { menu = 'PlayRecordedSession', submenu = nil },
	['MenuScenario_PreGameSubMenu'] = { menu = 'PreGameSubMenu', submenu = nil },
	['MenuScenario_Settings'] = { menu = 'MainMenu', submenu = 'Settings' },
	['MenuScenario_SingleplayerMenu'] = { menu = 'MainMenu', submenu = nil },
	['MenuScenario_StatsAdjustment'] = { menu = 'NewGame', submenu = 'Attributes' },
	['MenuScenario_Storage'] = { menu = 'Stash', submenu = nil },
	['MenuScenario_Summary'] = { menu = 'NewGame', submenu = 'Summary' },
	['MenuScenario_Vendor'] = { menu = 'Vendor', submenu = nil },
}

local stateProps = {
	'isLoading',
	'isLoaded',
	'isMenu',
	'isScene',
	'isBraindance',
	'isFastTravel',
	'isDefault',
	'isScanner',
	'isPopup',
	'isDevice',
	'isPhoto',
	'menu',
	'submenu',
	'context',
}

local function toStudlyCase(s)
	return (s:lower():gsub('_*(%l)(%w*)', function(first, rest)
		return string.upper(first) .. rest
	end))
end

local function updateLoading(loading)
	isLoading = loading
	isLoaded = false
end

local function updateLoaded(loaded)
	isLoading = not loaded
	isLoaded = loaded
end

local function updateMenu(menuActive)
	isMenu = menuActive or GameUI.IsMainMenu()
end

local function updateMenuScenario(scenarioName)
	local scenario = menuScenarios[scenarioName] or menuScenarios['MenuScenario_Idle']

	isMenu = scenario.menu ~= nil
	currentMenu = scenario.menu
	currentSubmenu = scenario.submenu
end

local function updateMenuItem(itemName)
	currentSubmenu = itemName or nil
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

	for _, stateProp in ipairs(stateProps) do
		local currentValue = currentState[stateProp]
		local previousValue = previousState[stateProp]

		if tostring(currentValue) ~= tostring(previousValue) then
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

		previousState = currentState
	end
end

local function initialize(listen)
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

	if not listen then
		listen = {
			loading = true,
			menu = true,
			braindance = true,
			sceneTier = true,
			photoMode = true,
			fastTravel = true,
			context = true,
		}
	end

	-- Loading State Listeners

	if listen.loading and not initialized.loading then
		Observe('PlayerPuppet', 'OnDetach', function()
			spdlog.info(('PlayerPuppet::OnDetach()'))

			if isMenu then
				updateLoading(true)
				updateBraindance(false)
				updatePhotoMode(false)
				updateContext()
				notifyObservers()
			end
		end)

		Observe('RadialWheelController', 'OnIsInMenuChanged', function(menuActive)
			spdlog.info(('RadialWheelController::OnIsInMenuChanged(%s)'):format(tostring(menuActive)))

			if isLoading and not menuActive then
				updateLoaded(true)
				updateMenuScenario()
				refreshCurrentState()
				notifyObservers()
			end
		end)

		initialized.loading = true
	end

	-- Menu State Listeners

	if listen.menu and not initialized.menu then
		Observe('inkMenuScenario', 'SwitchToScenario', function(_, menuName)
			spdlog.info(('inkMenuScenario::SwitchToScenario(%q)'):format(Game.NameToString(menuName)))

			updateMenuScenario(Game.NameToString(menuName))
			notifyObservers()
		end)

		--Observe('MenuScenario_BaseMenu', 'SwitchMenu', function(self, menuName)
		--	print('SwitchMenu', Game.NameToString(menuName))
		--end)

		Observe('MenuScenario_HubMenu', 'OnSelectMenuItem', function(menuItemData)
			spdlog.info(('MenuScenario_HubMenu::OnSelectMenuItem(%q)'):format(menuItemData.menuData.label))

			updateMenuItem(toStudlyCase(menuItemData.menuData.label))
			notifyObservers()
		end)

		Observe('MenuScenario_HubMenu', 'OnCloseHubMenu', function(_)
			spdlog.info(('MenuScenario_HubMenu::OnCloseHubMenu()'))

			updateMenuItem(false)
			notifyObservers()
		end)

		--Observe('DropPointControllerPS', 'OnOpenVendorUI', function()
		--	spdlog.info(('DropPointControllerPS::OnOpenVendorUI()'))
		--
		--	updateMenuScenario('MenuScenario_Vendor')
		--	updateMenuItem('DropPoint')
		--	notifyObservers()
		--end)

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
				['OnSwitchToPauseMenu'] = false,
				['OnSwitchToSaveGame'] = 'SaveGame',
				['OnSwitchToSettings'] = 'Settings',
			},
			['MenuScenario_DeathMenu'] = {
				--['OnCloseSettingsScreen'] = false,
				['OnSwitchToBrightnessSettings'] = 'Brightness',
				['OnSwitchToControllerPanel'] = 'Controller',
				['OnSwitchToHDRSettings'] = 'HDR',
				['OnSwitchToLoadGame'] = 'LoadGame',
				--['OnMainMenuBack'] = false,
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
					spdlog.info(('%s::%s()'):format(menuScenario, menuEvent))

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
				spdlog.info(('%s::%s()'):format(menuScenario, menuBackEvent))

				if Game.NameToString(self.prevMenuName) == 'settings_main' then
					updateMenuItem('Settings')
				else
					updateMenuItem(false)
				end

				notifyObservers()
			end)
		end

		Observe('SingleplayerMenuGameController', 'OnSavesReady', function()
			spdlog.info(('SingleplayerMenuGameController::OnSavesReady()'))

			updateLoading(false)
			updateMenuScenario('MenuScenario_SingleplayerMenu')
			updateBraindance(false)
			updatePhotoMode(false)
			updateSceneTier(4)
			notifyObservers()
		end)

		initialized.menu = true
	end

	-- Braindance State Listeners

	if listen.braindance and not initialized.braindance then
		Observe('BraindanceGameController', 'OnIsActiveUpdated', function(braindanceActive)
			spdlog.info(('BraindanceGameController::OnIsActiveUpdated(%s)'):format(tostring(braindanceActive)))

			updateBraindance(braindanceActive)
			notifyObservers()
		end)

		initialized.braindance = true
	end

	-- Scene Tier Listeners

	if listen.sceneTier and not initialized.sceneTier then
		Observe('CrosshairGameController_NoWeapon', 'OnPSMSceneTierChanged', function(sceneTierValue)
			spdlog.info(('CrosshairGameController_NoWeapon::OnPSMSceneTierChanged(%d)'):format(sceneTierValue))

			updateSceneTier(sceneTierValue)
			notifyObservers()
		end)

		initialized.sceneTier = true
	end

	-- Photo Mode Listeners

	if listen.photoMode and not initialized.photoMode then
		Observe('gameuiPhotoModeMenuController', 'OnShow', function()
			spdlog.info(('PhotoModeMenuController::OnShow()'))

			updatePhotoMode(true)
			notifyObservers()
		end)

		Observe('gameuiPhotoModeMenuController', 'OnHide', function()
			spdlog.info(('PhotoModeMenuController::OnHide()'))

			updatePhotoMode(false)
			notifyObservers()
		end)

		initialized.photoMode = true
	end

	-- Fast Travel Listeners

	if listen.fastTravel and not initialized.fastTravel then
		local fastTravelStart

		Observe('FastTravelSystem', 'OnToggleFastTravelAvailabilityOnMapRequest', function(request)
			spdlog.info(('FastTravelSystem::OnToggleFastTravelAvailabilityOnMapRequest()'))

			if request.isEnabled then
				fastTravelStart = request.pointRecord
			end
		end)

		Observe('FastTravelSystem', 'OnPerformFastTravelRequest', function(request)
			spdlog.info(('FastTravelSystem::OnPerformFastTravelRequest()'))

			local fastTravelDestination = request.pointData.pointRecord

			if tostring(fastTravelStart) ~= tostring(fastTravelDestination) then
				updateFastTravel(true)
				notifyObservers()
			end
		end)

		Observe('FastTravelSystem', 'OnLoadingScreenFinished', function(finished)
			spdlog.info(('FastTravelSystem::OnLoadingScreenFinished(%s)'):format(tostring(finished)))

			if finished then
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
			spdlog.info(('GameSystemUI::PushGameContext(%q)'):format(tostring(newContext)))

			if isBraindance and newContext.value == GameUI.Context.Scanning.value then
				return
			end

			updateContext(nil, newContext)
			notifyObservers()
		end)

		Observe('gameuiGameSystemUI', 'PopGameContext', function(_, oldContext)
			spdlog.info(('GameSystemUI::PopGameContext(%q)'):format(tostring(oldContext)))

			if isBraindance and oldContext.value == GameUI.Context.Scanning.value then
				return
			end

			updateContext(oldContext, nil)
			notifyObservers()
		end)

		Observe('gameuiGameSystemUI', 'SwapGameContext', function(_, oldContext, newContext)
			spdlog.info(('GameSystemUI::SwapGameContext(%q, %q)'):format(tostring(oldContext), tostring(newContext)))

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
			spdlog.info(('GameSystemUI::ResetGameContext()'))

			updateContext()
			notifyObservers()
		end)

		initialized.context = true
	end

	-- Initial state

	if not initialized.state then
		refreshCurrentState()
		--notifyObservers()

		initialized.state = true
	end
end

function GameUI.Observe(callback)
	table.insert(observers, callback)

	initialize()
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
	return isMenu or isFastTravel
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

function GameUI.GetContext()
	return #contextStack > 0 and contextStack[#contextStack] or GameUI.Context.Default
end

function GameUI.GetState()
	local state = {}

	state.isLoading = GameUI.IsLoading()
	state.isLoaded = GameUI.IsLoaded()

	state.isMenu = GameUI.IsAnyMenu()
	state.isScene = GameUI.IsScene()
	state.isBraindance = GameUI.IsBraindance()
	state.isFastTravel = GameUI.IsFastTravel()
	state.isScanner = GameUI.IsScanner()
	state.isPopup = GameUI.IsPopup()
	state.isDevice = GameUI.IsDevice()
	state.isPhoto = GameUI.IsPhoto()

	state.isDefault = not state.isMenu and not state.isScene
		and not state.isBraindance and not state.isFastTravel and not state.isPhoto
		and not state.isScanner and not state.isPopup and not state.isDevice

	state.menu = GameUI.GetMenu()
	state.submenu = GameUI.GetSubmenu()
	state.context = GameUI.GetContext()

	return state
end

function GameUI.ExportState(state)
	local export = {}

	for _, prop in ipairs(stateProps) do
		local value = state[prop]

		if value then
			if type(value) == 'userdata' then
				value = 'GameUI.Context.' .. value.value
			elseif type(value) == 'string' then
				value = string.format('%q', value)
			else
				value = tostring(value)
			end

			table.insert(export, prop .. ' = ' .. value)
		end
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

	if state.isLoading then
		print('- Loading:', state.isLoading)
	elseif state.isLoaded then
		print('- Loaded:', state.isLoaded)
	end

	if state.isMenu or all then
		print('- Menu:', state.isMenu, state.menu and '(' .. state.menu .. (state.submenu and ' / ' .. state.submenu or '') .. ')' or '')
	end

	if state.isScene or all then
		print('- Scene:', state.isScene)
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