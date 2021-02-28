local Cron = {}

local timers = { version = '1.0.0' }
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

	if timeout <= 0 then
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

---@param delta number
---@return void
function Cron.Update(delta)
	if #timers > 0 then
		for i, timer in ipairs(timers) do
			timer.delay = timer.delay - delta

			if timer.delay <= 0 then
				if timer.recurring then
					timer.delay = timer.delay + timer.timeout
				else
					table.remove(timers, i)
					i = i - 1
				end

				timer.callback(timer.args)
			end
		end
	end
end

return Cron