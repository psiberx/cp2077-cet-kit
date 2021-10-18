--[[
EventProxy.lua
Event Handler Manager

Copyright (c) 2021 psiberx
]]

local Cron = require('Cron')
local Ref = require('Ref')

local observers = {}
local cleanUpInterval = 30

---@param message string
local function warn(message)
	spdlog.warning(message)
	print(message)
end

---@param signature string
---@param target IScriptable
---@param event string
---@param callback function
local function addEventHandler(signature, target, event, callback)
	local class, method = signature:match('^(.+)::(.+)$')
	local handlers = observers[signature]

	if not handlers then
		handlers = {}

		local observer = function(self, ...)
			local hash = Ref.Hash(self)

			if handlers[hash] then
				handlers[hash].callback(self, select(1, ...))
			end
		end

		Cron.NextTick(function()
			Observe(class, method, observer)
		end)

		Cron.Every(cleanUpInterval, function()
			local counter = 0
			for hash, handler in pairs(handlers) do
				if Ref.IsExpired(handler.catcher) or Ref.IsExpired(handler.target) then
					handlers[hash] = nil
				else
					counter = counter + 1
				end
			end
		end)

		observers[signature] = handlers
	end

	local catcher = NewObject(class)
	local hash = Ref.Hash(catcher)

	if handlers[hash] then
		warn(('[EventProxy] %s: Hash conflict %08X '):format(signature, hash))
	end

	target:RegisterToCallback(event, catcher, method)

	handlers[hash] = {
		catcher = catcher,
		method = method,
		target = Ref.Weak(target),
		event = event,
		callback = callback,
	}
end

---@param signature string
---@param target IScriptable
---@param event string
---@param callback function
local function removeEventHandler(signature, target, event, callback)
	local handlers = observers[signature]

	if not handlers then
		return
	end

	for hash, handler in pairs(handlers) do
		if Ref.IsExpired(handler.catcher) or Ref.IsExpired(handler.target) then
			handlers[hash] = nil
		elseif handler.event == event and handler.callback == callback and Ref.Equals(handler.target, target) then
			handler.target:UnregisterFromCallback(handler.event, handler.catcher, handler.method)
			handlers[hash] = nil
			break
		end
	end
end

local function removeAllEventHandlers()
	for signature, handlers in pairs(observers) do
		for hash, handler in pairs(handlers) do
			if Ref.IsDefined(handler.target) and Ref.IsDefined(handler.catcher) then
				handler.target:UnregisterFromCallback(handler.event, handler.catcher, handler.method)
			end
			handlers[hash] = nil
		end
		observers[signature] = nil
	end
end

local EventProxy = {}

EventProxy.Type = {
	['inkPointerEvent'] = 'sampleStyleManagerGameController::OnState3',
	['inkWidget'] = 'sampleUISoundsLogicController::OnPress',
}

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.RegisterPointerCallback(target, event, callback)
	addEventHandler(EventProxy.Type.inkPointerEvent, target, event, callback)
end

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.UnregisterPointerCallback(target, event, callback)
	removeEventHandler(EventProxy.Type.inkPointerEvent, target, event, callback)
end

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.RegisterWidgetCallback(target, event, callback)
	addEventHandler(EventProxy.Type.inkWidget, target, event, callback)
end

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.UnregisterWidgetCallback(target, event, callback)
	removeEventHandler(EventProxy.Type.inkWidget, target, event, callback)
end

---@param target IScriptable
---@param event string
---@param proxy string
---@param callback function
function EventProxy.RegisterCallback(target, event, proxy, callback)
	addEventHandler(EventProxy.Type[proxy] or proxy, target, event, callback)
end

---@param target IScriptable
---@param event string
---@param proxy string
---@param callback function
function EventProxy.UnregisteCallback(target, event, proxy, callback)
	removeEventHandler(EventProxy.Type[proxy] or proxy, target, event, callback)
end

function EventProxy.UnregisterAllCallbacks()
	removeAllEventHandlers()
end

return EventProxy