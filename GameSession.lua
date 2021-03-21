--[[
GameSession.lua
Reactive Session Observer
Persistent Session Manager

Copyright (c) 2021 psiberx
]]

local GameSession = { version = '1.0.0' }

GameSession.Event = {
	Start = 'Start',
	End = 'End',
	Pause = 'Pause',
	Blur = 'Blur',
	Resume = 'Resume',
	Death = 'Death',
	Update = 'Update',
	Load = 'Load',
	Save = 'Save',
	List = 'List',
	LoadData = 'LoadData',
	SaveData = 'SaveData',
}

GameSession.Scope = {
	Session = 'Session',
	Pause = 'Pause',
	Blur = 'Blur',
	Death = 'Death',
	Saves = 'Saves',
	Persistence = 'Persistence',
}

local initialized = {}
local listeners = {}
local previousState = {}

local isLoaded = false
local isPaused = true
local isBlurred = false
local isDead = false

local stateProps = {
	{ current = 'isLoaded', previous = 'wasLoaded', event = { on = GameSession.Event.Start, off = GameSession.Event.End, scope = GameSession.Scope.Session } },
	{ current = 'isPaused', previous = 'wasPaused', event = { on = GameSession.Event.Pause, off = GameSession.Event.Resume, scope = GameSession.Scope.Pause } },
	{ current = 'isBlurred', previous = 'wasBlurred', event = { on = GameSession.Event.Blur, off = GameSession.Event.Resume, scope = GameSession.Scope.Blur } },
	{ current = 'isDead', previous = 'wasWheel', event = { on = GameSession.Event.Death, scope = GameSession.Scope.Death } },
	{ current = 'timestamp' },
	{ current = 'timestamps' },
}

local eventScopes = {
	[GameSession.Event.Update] = {},
	[GameSession.Event.Load] = { [GameSession.Scope.Saves] = true },
	[GameSession.Event.Save] = { [GameSession.Scope.Saves] = true },
	[GameSession.Event.List] = { [GameSession.Scope.Saves] = true },
	[GameSession.Event.LoadData] = { [GameSession.Scope.Persistence] = true },
	[GameSession.Event.SaveData] = { [GameSession.Scope.Persistence] = true },
}

local function updateLoaded(loaded)
	isLoaded = loaded
end

local function updatePaused(isMenuActive)
	isPaused = isMenuActive
end

local function updateBlurred(isBlurActive)
	isBlurred = isBlurActive
end

local function updateDead(isPlayerDead)
	isDead = isPlayerDead
end

local function refreshCurrentState()
	local player = Game.GetPlayer()
	local blackboardDefs = Game.GetAllBlackboardDefs()
	local blackboardUI = Game.GetBlackboardSystem():Get(blackboardDefs.UI_System)

	updatePaused(blackboardUI:GetBool(blackboardDefs.UI_System.IsInMenu))
	updateBlurred(blackboardUI:GetBool(blackboardDefs.UI_System.CircularBlurEnabled))
	updateDead(player:IsDeadNoStatPool())

	if not isLoaded then
		updateLoaded(player:IsAttached() and not GetSingleton('inkMenuScenario'):GetSystemRequestsHandler():IsPreGame())
	end
end

local function determineEvents(currentState)
	local events = { GameSession.Event.Update }
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
						table.insert(events, 1, stateProp.event.off)
						firing[stateProp.event.off] = true
					end
				end
			end
		end
	end

	return events
end

local function notifyObservers()
	local currentState = GameSession.GetState()
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
				if event ~= GameSession.Event.Update then
					currentState.event = event
				end

				for _, callback in ipairs(listeners[event]) do
					callback(currentState)
				end

				currentState.event = nil
			end
		end

		previousState = currentState
	end
end

local function dispatchEvent(event, state)
	if listeners[event] then
		state.event = event

		for _, callback in ipairs(listeners[event]) do
			callback(state)
		end

		state.event = nil
	end
end

local function pushCurrentState()
	previousState = GameSession.GetState()
end

local function initialize(event)
	if not initialized.data then
		for _, stateProp in ipairs(stateProps) do
			if stateProp.event then
				local eventScope = stateProp.event.scope or stateProp.event.change or stateProp.current

				for _, eventKey in ipairs({ 'change', 'on', 'off' }) do
					local eventName = stateProp.event[eventKey]

					if eventName then
						eventScopes[eventName] = {}
						eventScopes[eventName][eventScope] = true
					end
				end

				eventScopes[GameSession.Event.Update][eventScope] = true
			end
		end

		initialized.data = true
	end

	local required = eventScopes[event] or eventScopes[GameSession.Event.Update]

	-- Session State Listeners

	if required[GameSession.Scope.Session] and not initialized[GameSession.Scope.Session] then
		Observe('RadialWheelController', 'RegisterBlackboards', function(_, loaded)
			--spdlog.error(('RadialWheelController::RegisterBlackboards(%s)'):format(tostring(loaded)))

			updateLoaded(loaded)
			updatePaused(false)
			updateBlurred(false)
			updateDead(false)
			notifyObservers()
		end)

		initialized[GameSession.Scope.Session] = true
	end

	-- Pause State Listeners

	if required[GameSession.Scope.Pause] and not initialized[GameSession.Scope.Pause] then
		Observe('RadialWheelController', 'OnIsInMenuChanged', function(isInMenu)
			--spdlog.error(('RadialWheelController::OnIsInMenuChanged(%s)'):format(tostring(isInMenu)))

			updatePaused(isInMenu)
			notifyObservers()
		end)

		initialized[GameSession.Scope.Pause] = true
	end

	-- Blur State Listeners

	if required[GameSession.Scope.Blur] and not initialized[GameSession.Scope.Blur] then
		local popupControllers = {
			['PhoneDialerGameController'] = {
				['Show'] = true,
				['Hide'] = false,
			},
			['RadialWheelController'] = {
				['RefreshSlots'] = { initialized = true },
				['Shutdown'] = false,
			},
			['VehicleRadioPopupGameController'] = {
				['OnInitialize'] = true,
				['OnClose'] = false,
			},
			['VehiclesManagerPopupGameController'] = {
				['OnInitialize'] = true,
				['OnClose'] = false,
			},
		}

		for popupController, popupEvents in pairs(popupControllers) do
			for popupEvent, popupState in pairs(popupEvents) do
				Observe(popupController, popupEvent, function(self)
					--spdlog.error(('%s::%s()'):format(popupController, popupEvent))

					if isLoaded then
						if type(popupState) == 'table' then
							local popupActive = true
							for prop, value in pairs(popupState) do
								if self[prop] ~= value then
									popupActive = false
									break
								end
							end
							updateBlurred(popupActive)
						else
							updateBlurred(popupState)
						end

						notifyObservers()
					end
				end)
			end
		end

		initialized[GameSession.Scope.Blur] = true
	end

	-- Death State Listeners

	Observe('PlayerPuppet', 'OnDeath', function()
		updateDead(true)
		notifyObservers()
	end)

	-- Saving and Loading Listeners

	if required[GameSession.Scope.Saves] and not initialized[GameSession.Scope.Saves] then
		local saveList

		Observe('LoadGameMenuGameController', 'OnSavesReady', function()
			saveList = {}
		end)

		Observe('LoadGameMenuGameController', 'OnSaveMetadataReady', function(saveInfo)
			saveList[saveInfo.saveIndex] = saveInfo
		end)

		Observe('LoadGameMenuGameController', 'LoadSaveInGame', function(_, saveIndex)
			local timestamp = saveList[saveIndex].timestamp

			dispatchEvent(GameSession.Event.Load, { timestamp = timestamp })

			local timestamps = {}

			for _, saveInfo in pairs(saveList) do
				table.insert(timestamps, saveInfo.timestamp)
			end

			dispatchEvent(GameSession.Event.List, { timestamps = timestamps })

			saveList = nil
		end)

		Observe('gameuiInGameMenuGameController', 'OnSavingComplete', function(success)
			if success then
				local timestamp = os.time()

				dispatchEvent(GameSession.Event.Save, { timestamp = timestamp })
			end
		end)

		initialized[GameSession.Scope.Saves] = true
	end

	-- Initial state

	if not initialized.state then
		refreshCurrentState()
		pushCurrentState()

		initialized.state = true
	end
end

function GameSession.Observe(event, callback)
	if type(event) == 'string' then
		initialize(event)
	elseif type(event) == 'function' then
		callback, event = event, GameSession.Event.Update
		initialize(event)
	else
		if not event then
			initialize(GameSession.Event.Update)
		elseif type(event) == 'table' then
			for _, evt in ipairs(event) do
				GameSession.Observe(evt, callback)
			end
		end
		return
	end

	if type(callback) == 'function' then
		if not listeners[event] then
			listeners[event] = {}
		end

		table.insert(listeners[event], callback)
	end
end

function GameSession.Listen(event, callback)
	if type(event) == 'function' then
		callback = event
		for _, evt in pairs(GameSession.Event) do
			if evt ~= GameSession.Event.Update and not eventScopes[evt][GameSession.Scope.Persistence] then
				GameSession.Observe(evt, callback)
			end
		end
	else
		GameSession.Observe(event, callback)
	end
end

function GameSession.IsLoaded()
	return isLoaded
end

function GameSession.IsPaused()
	return isPaused
end

function GameSession.IsBlurred()
	return isBlurred
end

function GameSession.IsDead()
	return isDead
end

function GameSession.GetState()
	local currentState = {}

	currentState.isLoaded = GameSession.IsLoaded()
	currentState.isPaused = GameSession.IsPaused()
	currentState.isBlurred = GameSession.IsBlurred()
	currentState.isDead = GameSession.IsDead()

	for _, stateProp in ipairs(stateProps) do
		if stateProp.previous then
			currentState[stateProp.previous] = previousState[stateProp.current]
		end
	end

	return currentState
end

local function exportValue(value)
	if type(value) == 'userdata' then
		value = string.format('%q', value.value)
	elseif type(value) == 'string' then
		value = string.format('%q', value)
	elseif type(value) == 'table' then
		value = '{ ' .. table.concat(value, ', ') .. ' }'
	else
		value = tostring(value)
	end

	return value
end

function GameSession.ExportState(state)
	local export = {}

	if state.event then
		table.insert(export, 'event = ' .. string.format('%q', state.event))
	end

	for _, stateProp in ipairs(stateProps) do
		local value = state[stateProp.current]

		if value and (not stateProp.parent or state[stateProp.parent]) then
			table.insert(export, stateProp.current .. ' = ' .. exportValue(value))
		end
	end

	for _, stateProp in ipairs(stateProps) do
		if stateProp.previous then
			local currentValue = state[stateProp.current]
			local previousValue = state[stateProp.previous]

			if previousValue and previousValue ~= currentValue then
				table.insert(export, stateProp.previous .. ' = ' .. exportValue(previousValue))
			end
		end
	end

	return '{ ' .. table.concat(export, ', ') .. ' }'
end

function GameSession.PrintState(state)
	print('[GameSession] ' .. GameSession.ExportState(state))
end

GameSession.On = GameSession.Listen

setmetatable(GameSession, {
	__index = function(_, key)
		local event = string.match(key, '^On(%w+)$')

		if event and GameSession.Event[event] then
			rawset(GameSession, key, function(callback)
				GameSession.Observe(event, callback)
			end)

			return rawget(GameSession, key)
		end
	end
})

-- Persistent Session

local sessionDataDir = ''
local sessionDataRef

local function exportSession(t, max, depth)
	if type(t) ~= 'table' then
		return ''
	end

	max = max or 63
	depth = depth or 0

	local dumpStr = '{\n'
	local indent = string.rep('\t', depth)

	for k, v in pairs(t) do
		local kstr = ''
		if type(k) == 'string' then
			kstr = string.format('[\'%s\'] = ', k)
		end

		local vstr = tostring(v)
		if type(v) == 'string' then
			vstr = string.format('\'%s\'', tostring(v))
		elseif type(v) == 'table' then
			if depth < max then
				vstr = exportSession(v, max, depth + 1)
			else
				vstr = '...'
			end
		end

		dumpStr = string.format('%s\t%s%s%s,\n', dumpStr, indent, kstr, vstr)
	end

	return string.format('%s%s}', dumpStr, indent)
end

local function writeSession(sessionName, sessionData)
	local sessionPath = sessionDataDir .. '/' .. sessionName .. '.lua'
	local sessionFile = io.open(sessionPath, 'w')

	if not sessionFile then
		error(('GameSession.Persist(): Cannot write session file %q.'):format(sessionPath))
	end

	sessionFile:write('return ')
	sessionFile:write(exportSession(sessionData))
	sessionFile:close()
end

local function readSession(sessionName)
	local sessionPath = sessionDataDir .. '/' .. sessionName .. '.lua'
	local sessionChunk = loadfile(sessionPath)

	if type(sessionChunk) ~= 'function' then
		error(('GameSession.Persist(): Cannot read session file %q.'):format(sessionPath))
	end

	return sessionChunk()
end

local function removeSession(sessionName)
	local sessionPath = sessionDataDir .. '/' .. sessionName .. '.lua'

	os.remove(sessionPath)
end

local function cleanUpSessions(sessionNames)
	local validNames = {}

	for _, sessionName in ipairs(sessionNames) do
		validNames[tostring(sessionName)] = true
		validNames[tostring(sessionName + 1)] = true
	end

	for _, sessionFile in pairs(dir(sessionDataDir)) do
		local sessionName = sessionFile.name:gsub('%.lua$', '')

		if not validNames[sessionName] then
			removeSession(sessionName)
		end
	end
end

local function setupPersistance()
	if not initialized[GameSession.Scope.Persistence] then

		GameSession.Observe(GameSession.Event.Save, function(state)
			local sessionName = state.timestamp
			local sessionData = sessionDataRef or {}

			dispatchEvent(GameSession.Event.SaveData, sessionData)

			writeSession(sessionName, sessionData)
		end)

		GameSession.Observe(GameSession.Event.Load, function(state)
			local sessionName = state.timestamp
			local sessionData = readSession(sessionName)

			dispatchEvent(GameSession.Event.LoadData, sessionData)

			if sessionDataRef then
				for prop, value in pairs(sessionData) do
					sessionDataRef[prop] = value
				end
			end
		end)

		GameSession.Observe(GameSession.Event.List, function(state)
			cleanUpSessions(state.timestamps)
		end)

		initialized[GameSession.Scope.Persistence] = true
	end
end

function GameSession.StoreInDir(sessionDir)
	sessionDataDir = sessionDir

	setupPersistance()
end

function GameSession.Persist(sessionData)
	if type(sessionData) ~= 'table' then
		error(('GameSession.Persist(): Session data must be a table, received %q.'):format(type(table)))
	end

	sessionDataRef = sessionData

	setupPersistance()
end

return GameSession