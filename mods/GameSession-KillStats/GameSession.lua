--[[
GameSession.lua
Reactive Session Observer
Persistent Session Manager

Copyright (c) 2021 psiberx
]]

local GameSession = {
	version = '1.4.0',
	framework = '1.19.0'
}

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
	Clean = 'Clean',
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

local eventScopes = {
	[GameSession.Event.Update] = {},
	[GameSession.Event.Load] = { [GameSession.Scope.Saves] = true },
	[GameSession.Event.Save] = { [GameSession.Scope.Saves] = true },
	[GameSession.Event.Clean] = { [GameSession.Scope.Saves] = true },
	[GameSession.Event.LoadData] = { [GameSession.Scope.Saves] = true, [GameSession.Scope.Persistence] = true },
	[GameSession.Event.SaveData] = { [GameSession.Scope.Saves] = true, [GameSession.Scope.Persistence] = true },
}

local isLoaded = false
local isPaused = true
local isBlurred = false
local isDead = false

local sessionDataDir
local sessionDataRef
local sessionDataTmpl
local sessionDataRelaxed = false

local sessionKeyValue = 0
local sessionKeyFactName = '_psxgs_session_key'

-- Error Handling --

local function raiseError(msg)
	print('[GameSession] ' .. msg)
	error(msg, 2)
end

-- Event Dispatching --

local function addEventListener(event, callback)
	if not listeners[event] then
		listeners[event] = {}
	end

	table.insert(listeners[event], callback)
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

-- State Observing --

local stateProps = {
	{ current = 'isLoaded', previous = 'wasLoaded', event = { on = GameSession.Event.Start, off = GameSession.Event.End, scope = GameSession.Scope.Session } },
	{ current = 'isPaused', previous = 'wasPaused', event = { on = GameSession.Event.Pause, off = GameSession.Event.Resume, scope = GameSession.Scope.Pause } },
	{ current = 'isBlurred', previous = 'wasBlurred', event = { on = GameSession.Event.Blur, off = GameSession.Event.Resume, scope = GameSession.Scope.Blur } },
	{ current = 'isDead', previous = 'wasWheel', event = { on = GameSession.Event.Death, scope = GameSession.Scope.Death } },
	{ current = 'timestamp' },
	{ current = 'timestamps' },
	{ current = 'sessionKey' },
}

local previousState = {}

local function updateLoaded(loaded)
	local changed = isLoaded ~= loaded

	isLoaded = loaded

	return changed
end

local function updatePaused(isMenuActive)
	isPaused = not isLoaded or isMenuActive
end

local function updateBlurred(isBlurActive)
	isBlurred = isBlurActive
end

local function updateDead(isPlayerDead)
	isDead = isPlayerDead
end

local function isPreGame()
	return GetSingleton('inkMenuScenario'):GetSystemRequestsHandler():IsPreGame()
end

local function refreshCurrentState()
	local player = Game.GetPlayer()
	local blackboardDefs = Game.GetAllBlackboardDefs()
	local blackboardUI = Game.GetBlackboardSystem():Get(blackboardDefs.UI_System)
	local blackboardPM = Game.GetBlackboardSystem():Get(blackboardDefs.PhotoMode)

	local menuActive = blackboardUI:GetBool(blackboardDefs.UI_System.IsInMenu)
	local blurActive = blackboardUI:GetBool(blackboardDefs.UI_System.CircularBlurEnabled)
	local photoModeActive = blackboardPM:GetBool(blackboardDefs.PhotoMode.IsActive)
	local tutorialActive = Game.GetTimeSystem():IsTimeDilationActive('UI_TutorialPopup')

	if not isLoaded then
		updateLoaded(player:IsAttached() and not isPreGame())
	end

	updatePaused(menuActive or photoModeActive or tutorialActive)
	updateBlurred(blurActive)
	updateDead(player:IsDeadNoStatPool())
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
		local events = determineEvents(currentState)

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

local function pushCurrentState()
	previousState = GameSession.GetState()
end

-- Session Key --

local function generateSessionKey()
	return os.time()
end

local function getSessionKey()
	return sessionKeyValue
end

local function setSessionKey(sessionKey)
	sessionKeyValue = sessionKey
end

local function isEmptySessionKey(sessionKey)
	if not sessionKey then
		sessionKey = getSessionKey()
	end

	return not sessionKey or sessionKey == 0
end

local function readSessionKey()
	return Game.GetQuestsSystem():GetFactStr(sessionKeyFactName)
end

local function writeSessionKey(sessionKey)
	Game.GetQuestsSystem():SetFactStr(sessionKeyFactName, sessionKey)
end

local function initSessionKey()
	local sessionKey = readSessionKey()

	if isEmptySessionKey(sessionKey) then
		sessionKey = generateSessionKey()
		writeSessionKey(sessionKey)
	end

	setSessionKey(sessionKey)
end

local function renewSessionKey()
	local sessionKey = getSessionKey()
	local savedKey = readSessionKey()
	local nextKey = generateSessionKey()

	if sessionKey == savedKey or savedKey < nextKey - 1 then
		sessionKey = generateSessionKey()
		writeSessionKey(sessionKey)
	else
		sessionKey = savedKey
	end

	setSessionKey(sessionKey)
end

local function setSessionKeyName(sessionKeyName)
	sessionKeyFactName = sessionKeyName
end

-- Session Data --

local function exportSessionData(t, max, depth, result)
	if type(t) ~= 'table' then
		return '{}'
	end

	max = max or 63
	depth = depth or 0

	local indent = string.rep('\t', depth)
	local output = result or {}

	table.insert(output, '{\n')

	for k, v in pairs(t) do
		local ktype = type(k)
		local vtype = type(v)

		local kstr = ''
		if ktype == 'string' then
			kstr = string.format('[%q] = ', k)
		end

		local vstr = ''
		if vtype == 'string' then
			vstr = string.format('%q', v)
		elseif vtype == 'table' then
			if depth < max then
				table.insert(output, string.format('\t%s%s', indent, kstr))
				exportSessionData(v, max, depth + 1, output)
				table.insert(output, ',\n')
			end
		elseif vtype == 'userdata' then
			vstr = tostring(v)
			if vstr:find('^userdata:') or vstr:find('^sol%.') then
				if not sessionDataRelaxed then
					--vtype = vstr:match('^sol%.(.+):')
					if ktype == 'string' then
						raiseError(('Cannot store userdata in the %q field.'):format(k))
						--raiseError(('Cannot store userdata of type %q in the %q field.'):format(vtype, k))
					else
						raiseError(('Cannot store userdata in the list.'))
						--raiseError(('Cannot store userdata of type %q.'):format(vtype))
					end
				else
					vstr = ''
				end
			end
		elseif vtype == 'function' or vtype == 'thread' then
			if not sessionDataRelaxed then
				if ktype == 'string' then
					raiseError(('Cannot store %s in the %q field.'):format(vtype, k))
				else
					raiseError(('Cannot store %s.'):format(vtype))
				end
			end
		else
			vstr = tostring(v)
		end

		if vstr ~= '' then
			table.insert(output, string.format('\t%s%s%s,\n', indent, kstr, vstr))
		end
	end

	if not result and #output == 1 then
		return '{}'
	end

	table.insert(output, indent .. '}')

	if not result then
		return table.concat(output)
	end
end

local function importSessionData(s)
	local chunk = loadstring('return ' .. s, '')

	return chunk and chunk() or {}
end

-- Session File IO --

local function irpairs(tbl)
	local function iter(t, i)
		i = i - 1
		if i ~= 0 then
			return i, t[i]
		end
	end

    return iter, tbl, #tbl + 1
end

local function findSessionTimestampByKey(targetKey, isTemporary)
	if sessionDataDir and not isEmptySessionKey(targetKey) then
		local pattern = '^' .. (isTemporary and '!' or '') .. '(%d+)%.lua$'

		for _, sessionFile in irpairs(dir(sessionDataDir)) do
			if sessionFile.name:find(pattern) then
				local sessionReader = io.open(sessionDataDir .. '/' .. sessionFile.name, 'r')
				local sessionHeader = sessionReader:read('l')
				sessionReader:close()

				local sessionKeyStr = sessionHeader:match('^-- (%d+)$')
				if sessionKeyStr then
					local sessionKey = tonumber(sessionKeyStr)
					if sessionKey == targetKey then
						return tonumber((sessionFile.name:match(pattern)))
					end
				end
			end
		end
	end

	return nil
end

local function writeSessionFile(sessionTimestamp, sessionKey, isTemporary, sessionData)
	if not sessionDataDir then
		return
	end

	local sessionPath = sessionDataDir .. '/' .. (isTemporary and '!' or '') .. sessionTimestamp .. '.lua'
	local sessionFile = io.open(sessionPath, 'w')

	if not sessionFile then
		raiseError(('Cannot write session file %q.'):format(sessionPath))
	end

	sessionFile:write('-- ')
	sessionFile:write(sessionKey)
	sessionFile:write('\n')
	sessionFile:write('return ')
	sessionFile:write(exportSessionData(sessionData))
	sessionFile:close()
end

local function readSessionFile(sessionTimestamp, sessionKey, isTemporary)
	if not sessionDataDir then
		return nil
	end

	if not sessionTimestamp then
		sessionTimestamp = findSessionTimestampByKey(sessionKey, isTemporary)

		if not sessionTimestamp then
			return nil
		end
	end

	local sessionPath = sessionDataDir .. '/' .. (isTemporary and '!' or '') .. sessionTimestamp .. '.lua'
	local sessionChunk = loadfile(sessionPath)

	if type(sessionChunk) ~= 'function' then
		sessionPath = sessionDataDir .. '/' .. (sessionTimestamp + 1) .. '.lua'
		sessionChunk = loadfile(sessionPath)

		if type(sessionChunk) ~= 'function' then
			return nil
		end
	end

	return sessionChunk()
end

local function removeSessionFile(sessionTimestamp, isTemporary)
	if not sessionDataDir then
		return
	end

	local sessionPath = sessionDataDir .. '/' .. (isTemporary and '!' or '') .. sessionTimestamp .. '.lua'

	os.remove(sessionPath)
end

local function cleanUpSessionFiles(sessionTimestamps)
	if not sessionDataDir then
		return
	end

	local validNames = {}

	for _, sessionTimestamp in ipairs(sessionTimestamps) do
		validNames[tostring(sessionTimestamp)] = true
		validNames[tostring(sessionTimestamp + 1)] = true
	end

	for _, sessionFile in pairs(dir(sessionDataDir)) do
		local sessionTimestamp = sessionFile.name:match('^!?(%d+)%.lua$')

		if sessionTimestamp and not validNames[sessionTimestamp] then
			os.remove(sessionDataDir .. '/' .. sessionFile.name)
		end
	end
end

-- Session Meta --

local function getSessionMetaForSaving(isTemporary)
	return {
		sessionKey = getSessionKey(),
		timestamp = os.time(),
		isTemporary = isTemporary,
	}
end

local function getSessionMetaForLoading(isTemporary)
	return {
		sessionKey = getSessionKey(),
		timestamp = findSessionTimestampByKey(getSessionKey(), isTemporary) or 0,
		isTemporary = isTemporary,
	}
end

local function extractSessionMetaForLoading(saveInfo)
	return {
		sessionKey = 0, -- Cannot be retrieved from save metadata
		timestamp = tonumber(saveInfo.timestamp),
		isTemporary = false,
	}
end

-- Initialization --

local function initialize(event)
	if not initialized.data then
		for _, stateProp in ipairs(stateProps) do
			if stateProp.event then
				local eventScope = stateProp.event.scope or stateProp.event.change

				if eventScope then
					for _, eventKey in ipairs({ 'change', 'on', 'off' }) do
						local eventName = stateProp.event[eventKey]

						if eventName then
							if not eventScopes[eventName] then
								eventScopes[eventName] = {}
							end

							eventScopes[eventName][eventScope] = true
						end
					end

					if eventScope ~= GameSession.Scope.Persistence then
						eventScopes[GameSession.Event.Update][eventScope] = true
					end
				end
			end
		end

		initialized.data = true
	end

	local required = eventScopes[event] or eventScopes[GameSession.Event.Update]

	-- Session State

	if required[GameSession.Scope.Session] and not initialized[GameSession.Scope.Session] then
		Observe('QuestTrackerGameController', 'OnInitialize', function()
			--spdlog.error(('QuestTrackerGameController::OnInitialize()'))

			if updateLoaded(true) then
				updatePaused(false)
				updateBlurred(false)
				updateDead(false)
				notifyObservers()
			end
		end)

		Observe('QuestTrackerGameController', 'OnUninitialize', function()
			--spdlog.error(('QuestTrackerGameController::OnUninitialize()'))

			if Game.GetPlayer() == nil then
				if updateLoaded(false) then
					updatePaused(true)
					updateBlurred(false)
					updateDead(false)
					notifyObservers()
				end
			end
		end)

		initialized[GameSession.Scope.Session] = true
	end

	-- Pause State

	if required[GameSession.Scope.Pause] and not initialized[GameSession.Scope.Pause] then
		local fastTravelActive, fastTravelStart

		Observe('gameuiPopupsManager', 'OnMenuUpdate', function(_, isInMenu)
			if isInMenu == nil then
				isInMenu = _
			end

			--spdlog.error(('gameuiPopupsManager::OnMenuUpdate(%s)'):format(tostring(isInMenu)))

			if not fastTravelActive then
				updatePaused(isInMenu)
				notifyObservers()
			end
		end)

		Observe('gameuiPhotoModeMenuController', 'OnShow', function()
			--spdlog.error(('PhotoModeMenuController::OnShow()'))

			updatePaused(true)
			notifyObservers()
		end)

		Observe('gameuiPhotoModeMenuController', 'OnHide', function()
			--spdlog.error(('PhotoModeMenuController::OnHide()'))

			updatePaused(false)
			notifyObservers()
		end)

		Observe('gameuiTutorialPopupGameController', 'PauseGame', function(_, tutorialActive)
			--spdlog.error(('gameuiTutorialPopupGameController::PauseGame(%s)'):format(tostring(tutorialActive)))

			updatePaused(tutorialActive)
			notifyObservers()
		end)

		Observe('FastTravelSystem', 'OnUpdateFastTravelPointRecordRequest', function(_, request)
			if request == nil then
				request = _
			end

			--spdlog.error(('FastTravelSystem::OnUpdateFastTravelPointRecordRequest()'))

			if request.isEnabled then
				fastTravelStart = request.pointRecord
			end
		end)

		Observe('FastTravelSystem', 'OnPerformFastTravelRequest', function(_, request)
			if request == nil then
				request = _
			end

			--spdlog.error(('FastTravelSystem::OnPerformFastTravelRequest()'))

			local fastTravelDestination = request.pointData.pointRecord

			if tostring(fastTravelStart) ~= tostring(fastTravelDestination) then
				fastTravelActive = true
			else
				fastTravelStart = nil
			end
		end)

		Observe('FastTravelSystem', 'OnLoadingScreenFinished', function(_, finished)
			if finished == nil then
				finished = _
			end

			--spdlog.error(('FastTravelSystem::OnLoadingScreenFinished(%s)'):format(tostring(finished)))

			if finished then
				fastTravelActive = false
				fastTravelStart = nil
				updatePaused(false)
				notifyObservers()
			end
		end)

		initialized[GameSession.Scope.Pause] = true
	end

	-- Blur State

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

		Observe('PhoneMessagePopupGameController', 'SetTimeDilatation', function(_, popupActive)
			--spdlog.error(('PhoneMessagePopupGameController::SetTimeDilatation()'))

			updateBlurred(popupActive)
			notifyObservers()
		end)

		initialized[GameSession.Scope.Blur] = true
	end

	-- Death State

	if required[GameSession.Scope.Death] and not initialized[GameSession.Scope.Death] then
		Observe('PlayerPuppet', 'OnDeath', function()
			--spdlog.error(('PlayerPuppet::OnDeath()'))

			updateDead(true)
			notifyObservers()
		end)

		initialized[GameSession.Scope.Death] = true
	end

	-- Saving and Loading

	if required[GameSession.Scope.Saves] and not initialized[GameSession.Scope.Saves] then
		local sessionLoadList = {}
		local sessionLoadRequest = {}

		if not isPreGame() then
			initSessionKey()
		end

		---@param self PlayerPuppet
		Observe('PlayerPuppet', 'OnTakeControl', function(self)
			--spdlog.error(('PlayerPuppet::OnTakeControl()'))

			if self:GetEntityID().hash ~= 1ULL then
				return
			end

			if not isPreGame() then
				-- Expand load request with session key from facts
				sessionLoadRequest.sessionKey = readSessionKey()

				-- Try to resolve timestamp from session key
				if not sessionLoadRequest.timestamp then
					sessionLoadRequest.timestamp = findSessionTimestampByKey(
						sessionLoadRequest.sessionKey,
						sessionLoadRequest.isTemporary
					)
				end

				-- Dispatch load event
				dispatchEvent(GameSession.Event.Load, sessionLoadRequest)
			end

			-- Reset session load request
			sessionLoadRequest = {}
		end)

		---@param self PlayerPuppet
		Observe('PlayerPuppet', 'OnGameAttached', function(self)
			--spdlog.error(('PlayerPuppet::OnGameAttached()'))

			if self:IsReplacer() then
				return
			end

			if not isPreGame() then
				-- Store new session key in facts
				renewSessionKey()
			end
		end)

		Observe('LoadListItem', 'SetMetadata', function(_, saveInfo)
			if saveInfo == nil then
				saveInfo = _
			end

			--spdlog.error(('LoadListItem::SetMetadata()'))

			-- Fill the session list from saves metadata
			sessionLoadList[saveInfo.saveIndex] = extractSessionMetaForLoading(saveInfo)
		end)

		Observe('LoadGameMenuGameController', 'LoadSaveInGame', function(_, saveIndex)
			--spdlog.error(('LoadGameMenuGameController::LoadSaveInGame(%d)'):format(saveIndex))

			if #sessionLoadList == 0 then
				return
			end

			-- Make a load request from selected save
			sessionLoadRequest = sessionLoadList[saveIndex]

			-- Collect timestamps for existing saves
			local existingTimestamps = {}
			for _, sessionMeta in pairs(sessionLoadList) do
				table.insert(existingTimestamps, sessionMeta.timestamp)
			end

			-- Dispatch clean event
			dispatchEvent(GameSession.Event.Clean, { timestamps = existingTimestamps })
		end)

		Observe('gameuiInGameMenuGameController', 'OnSavingComplete', function(_, success)
			if type(success) ~= 'boolean' then
				success = _
			end

			--spdlog.error(('gameuiInGameMenuGameController::OnSavingComplete(%s)'):format(tostring(success)))

			if success then
				-- Dispatch
				dispatchEvent(GameSession.Event.Save, getSessionMetaForSaving())

				-- Store new session key in facts
				renewSessionKey()
			end
		end)

		initialized[GameSession.Scope.Saves] = true
	end

	-- Persistence

	if required[GameSession.Scope.Persistence] and not initialized[GameSession.Scope.Persistence] then
		addEventListener(GameSession.Event.Save, function(sessionMeta)
			local sessionData = sessionDataRef or {}

			dispatchEvent(GameSession.Event.SaveData, sessionData)

			writeSessionFile(sessionMeta.timestamp, sessionMeta.sessionKey, sessionMeta.isTemporary, sessionData)
		end)

		addEventListener(GameSession.Event.Load, function(sessionMeta)
			local sessionData = readSessionFile(sessionMeta.timestamp, sessionMeta.sessionKey, sessionMeta.isTemporary)

			if not sessionData then
				if sessionDataTmpl then
					sessionData = importSessionData(sessionDataTmpl)
				else
					sessionData = {}
				end
			end

			dispatchEvent(GameSession.Event.LoadData, sessionData)

			if sessionDataRef then
				for prop, value in pairs(sessionData) do
					sessionDataRef[prop] = value
				end
			end

			if sessionMeta.isTemporary then
				removeSessionFile(sessionMeta.timestamp, true)
			end
		end)

		addEventListener(GameSession.Event.Clean, function(sessionMeta)
			cleanUpSessionFiles(sessionMeta.timestamps)
		end)

		initialized[GameSession.Scope.Persistence] = true
	end

	-- Initial state

	if not initialized.state then
		refreshCurrentState()
		pushCurrentState()

		initialized.state = true
	end
end

-- Public Interface --

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
		addEventListener(event, callback)
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

function GameSession.GetKey()
	return getSessionKey()
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

function GameSession.IdentifyAs(sessionName)
	setSessionKeyName(sessionName)
end

function GameSession.StoreInDir(sessionDir)
	sessionDataDir = sessionDir

	initialize(GameSession.Event.SaveData)
end

function GameSession.Persist(sessionData, relaxedMode)
	if type(sessionData) ~= 'table' then
		raiseError(('Session data must be a table, received %s.'):format(type(sessionData)))
	end

	sessionDataRef = sessionData
	sessionDataRelaxed = relaxedMode and true or false
	sessionDataTmpl = exportSessionData(sessionData)

	initialize(GameSession.Event.SaveData)
end

function GameSession.TrySave()
	if Game.GetSettingsSystem() then
		dispatchEvent(GameSession.Event.Save, getSessionMetaForSaving(true))
	end
end

function GameSession.TryLoad()
	if not isPreGame() and not isEmptySessionKey() then
		dispatchEvent(GameSession.Event.Load, getSessionMetaForLoading(true))
	end
end

return GameSession