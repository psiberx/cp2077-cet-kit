--[[
EventProxy.lua
Event Handler Manager

Copyright (c) 2021 psiberx
]]

local Cron = require('Cron')
local Ref = require('Ref')

---@class EventHandler
---@field catcher IScriptable
---@field method string
---@field target IScriptable
---@field event any
---@field callback function

---@type table<string, EventHandler[]>
local observers = {}

local cleanUpInterval = 30.0

local knownTypes = {
    ['inkPointerEvent'] = 'sampleStyleManagerGameController::OnState3',
    ['inkWidget'] = 'sampleUISoundsLogicController::OnPress',
}

local knownEvents = {
    ['OnPress'] = 'inkPointerEvent',
    ['OnRelease'] = 'inkPointerEvent',
    ['OnHold'] = 'inkPointerEvent',
    ['OnRepeat'] = 'inkPointerEvent',
    ['OnRelative'] = 'inkPointerEvent',
    ['OnAxis'] = 'inkPointerEvent',
    ['OnEnter'] = 'inkPointerEvent',
    ['OnLeave'] = 'inkPointerEvent',
    ['OnHoverOver'] = 'inkPointerEvent',
    ['OnHoverOut'] = 'inkPointerEvent',
    ['OnPreOnPress'] = 'inkPointerEvent',
    ['OnPreOnRelease'] = 'inkPointerEvent',
    ['OnPreOnHold'] = 'inkPointerEvent',
    ['OnPreOnRepeat'] = 'inkPointerEvent',
    ['OnPreOnRelative'] = 'inkPointerEvent',
    ['OnPreOnAxis'] = 'inkPointerEvent',
    ['OnPostOnPress'] = 'inkPointerEvent',
    ['OnPostOnRelease'] = 'inkPointerEvent',
    ['OnPostOnHold'] = 'inkPointerEvent',
    ['OnPostOnRepeat'] = 'inkPointerEvent',
    ['OnPostOnRelative'] = 'inkPointerEvent',
    ['OnPostOnAxis'] = 'inkPointerEvent',
    ['OnLinkPressed'] = 'inkWidget',
}

---@param message string
local function warn(message)
    spdlog.warning(message)
    print(message)
end

---@param signature string
---@return string, string
local function parseSignature(signature)
    return signature:match('^(.+)::(.+)$')
end

---@param event string
---@return string, string|nil
local function parseProxyEvent(event)
    return event:match('^(.+)@(.+)$') or event, nil
end

---@param proxy string
---@return string
local function resolveProxyByType(proxy)
    return knownTypes[proxy] or proxy
end

---@param proxy string
---@return string, string
local function resolveProxyByEvent(proxy)
    local event, type = parseProxyEvent(proxy)

    if not type then
        type = knownEvents[event]

        if not type then
            type = 'inkWidget' -- Fallback to custom callback
        end
    end

    return resolveProxyByType(type), event
end

---@param target IScriptable
---@return boolean
local function isGlobalInput(target)
    return target:IsA('gameuiWidgetGameController') or target:IsA('inkWidgetLogicController')
end

---@param handler EventHandler
local function registerCallback(handler)
    if isGlobalInput(handler.target) then
        handler.target:RegisterToGlobalInputCallback(handler.event, handler.catcher, handler.method)
    else
        handler.target:RegisterToCallback(handler.event, handler.catcher, handler.method)
    end
end

---@param handler EventHandler
local function unregisterCallback(handler)
    if isGlobalInput(handler.target) then
        handler.target:UnregisterFromGlobalInputCallback(handler.event, handler.catcher, handler.method)
    else
        handler.target:UnregisterFromCallback(handler.event, handler.catcher, handler.method)
    end
end

---@param proxy string
---@param target IScriptable
---@param event string
---@param callback function
local function addEventHandler(proxy, target, event, callback)
    local class, method = parseSignature(proxy)

    if not class then
        return
    end

    local handlers = observers[proxy]

    if not handlers then
        handlers = {}

        local observer = function(self, ...)
            local hash = Ref.Hash(self)

            if handlers[hash] then
                handlers[hash].callback(handlers[hash].target, select(1, ...))
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

        observers[proxy] = handlers
    end

    local catcher = NewObject(class)
    local hash = Ref.Hash(catcher)

    if handlers[hash] then
        warn(('[EventProxy] %s: Hash conflict %08X '):format(proxy, hash))
    end

    local handler = {
        catcher = catcher,
        method = method,
        target = Ref.Weak(target),
        event = event,
        callback = callback,
    }

    registerCallback(handler)

    handlers[hash] = handler
end

---@param proxy string
---@param target IScriptable
---@param event string
---@param callback function
local function removeEventHandler(proxy, target, event, callback)
    local handlers = observers[proxy]

    if not handlers then
        return
    end

    for hash, handler in pairs(handlers) do
        if Ref.IsExpired(handler.catcher) or Ref.IsExpired(handler.target) then
            handlers[hash] = nil
        elseif handler.event == event and handler.callback == callback and Ref.Equals(handler.target, target) then
            unregisterCallback(handler)
            handlers[hash] = nil
            break
        end
    end
end

local function removeAllEventHandlers()
    for signature, handlers in pairs(observers) do
        for hash, handler in pairs(handlers) do
            if Ref.IsDefined(handler.target) and Ref.IsDefined(handler.catcher) then
                unregisterCallback(handler)
            end
            handlers[hash] = nil
        end
        observers[signature] = nil
    end
end

local EventProxy = { version = '1.0.2' }

---@type table<string, string>
EventProxy.Type = knownTypes

---@type table<string, string>
EventProxy.Event = knownEvents

---@param type string
---@param proxy string
function EventProxy.RegisterProxy(type, proxy)
    knownTypes[type] = proxy
end

---@param event string
---@param type string
function EventProxy.RegisterEvent(event, type)
    knownEvents[event] = type
end

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.RegisterCallback(target, event, callback)
    local _proxy, _event = resolveProxyByEvent(event)

    addEventHandler(_proxy, target, _event, callback)
end

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.UnregisteCallback(target, event, callback)
    local _proxy, _event = resolveProxyByEvent(event)

    removeEventHandler(_proxy, target, _event, callback)
end

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.RegisterPointerCallback(target, event, callback)
    addEventHandler(knownTypes.inkPointerEvent, target, event, callback)
end

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.UnregisterPointerCallback(target, event, callback)
    removeEventHandler(knownTypes.inkPointerEvent, target, event, callback)
end

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.RegisterCustomCallback(target, event, callback)
    addEventHandler(knownTypes.inkWidget, target, event, callback)
end

---@param target IScriptable
---@param event string
---@param callback function
function EventProxy.UnregisterCustomCallback(target, event, callback)
    removeEventHandler(knownTypes.inkWidget, target, event, callback)
end

function EventProxy.UnregisterAllCallbacks()
    removeAllEventHandlers()
end

return EventProxy