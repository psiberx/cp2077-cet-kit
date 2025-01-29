---------------------------------------------------------------------------------
-- Cron.lua (UPDATED)
-- Timed Tasks Manager
-- Copyright (c) 2025 psiberx

-- Update by DeVaughnDawn

-- Explanation of Changes (Short Version):
-- 1. Switched from forward iteration (for i, timer in ipairs(timers)) to a
--    reverse loop (for i = #timers, 1, -1) in Cron.Update(). 
--    This prevents potential skipping or index confusion when removing timers.
-- 2. Added robust in-line comments to ensure all changes are clear for future updating.
---------------------------------------------------------------------------------

-- Import external and internal modules
local Cron = { version = '1.0.3' }

local timers = {}
local counter = 0

---@param timeout number
---@param recurring boolean
---@param callback function
---@param args
---@return any
local function addTimer(timeout, recurring, callback, args)
    if type(timeout) ~= 'number' then
        return
    end

    if timeout < 0 then
        return
    end

    if type(recurring) ~= 'boolean' then
        return
    end

    if type(callback) ~= 'function' then
        if type(args) == 'function' then
            callback, args = args, callback
        else
            return
        end
    end

    if type(args) ~= 'table' then
        args = { arg = args }
    end

    counter = counter + 1

    local timer = {
        id = counter,
        callback = callback,
        recurring = recurring,
        timeout = timeout,
        active = true,
        delay = timeout,
        args = args,
    }

    if args.id == nil then
        args.id = timer.id
    end

    if args.interval == nil then
        args.interval = timer.timeout
    end

    if args.Halt == nil then
        args.Halt = Cron.Halt
    end

    if args.Pause == nil then
        args.Pause = Cron.Pause
    end

    if args.Resume == nil then
        args.Resume = Cron.Resume
    end

    table.insert(timers, timer)

    return timer.id
end

---@param timeout number
---@param callback function
---@param data
---@return any
function Cron.After(timeout, callback, data)
    return addTimer(timeout, false, callback, data)
end

---@param timeout number
---@param callback function
---@param data
---@return any
function Cron.Every(timeout, callback, data)
    return addTimer(timeout, true, callback, data)
end

---@param callback function
---@param data
---@return any
function Cron.NextTick(callback, data)
    return addTimer(0, false, callback, data)
end

---@param timerId any
---@return void
function Cron.Halt(timerId)
    if type(timerId) == 'table' then
        timerId = timerId.id
    end

    for i, timer in ipairs(timers) do
        if timer.id == timerId then
            table.remove(timers, i)
            break
        end
    end
end

---@param timerId any
---@return void
function Cron.Pause(timerId)
    if type(timerId) == 'table' then
        timerId = timerId.id
    end

    for _, timer in ipairs(timers) do
        if timer.id == timerId then
            timer.active = false
            break
        end
    end
end

---@param timerId any
---@return void
function Cron.Resume(timerId)
    if type(timerId) == 'table' then
        timerId = timerId.id
    end

    for _, timer in ipairs(timers) do
        if timer.id == timerId then
            timer.active = true
            break
        end
    end
end

---@param delta number
---@return void
function Cron.Update(delta)
    -- Optimization/bugfix: reverse iteration prevents skipping timers when removing them.
    for i = #timers, 1, -1 do
        local timer = timers[i]

        -- Only process active timers
        if timer and timer.active then
            timer.delay = timer.delay - delta

            if timer.delay <= 0 then
                -- If it's recurring, reset delay by adding the timeout again
                if timer.recurring then
                    timer.delay = timer.delay + timer.timeout
                else
                    -- Remove one-shot timer so we don't process it again
                    table.remove(timers, i)
                end

                -- Execute the timer callback
                timer.callback(timer.args)
            end
        end
    end
end

return Cron
