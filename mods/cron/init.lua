local Cron = require('Cron')

registerForEvent('onInit', function()
	print(('[%s] Cron demo started'):format(os.date('%H:%M:%S')))

	-- One-off timer
	Cron.After(5.0, function()
		print(('[%s] After 5.00 secs'):format(os.date('%H:%M:%S')))
	end)

	-- Repeating self-halting timer with context
	Cron.Every(2.0, { tick = 1 }, function(timer)
		print(('[%s] Every %.2f secs #%d'):format(os.date('%H:%M:%S'), timer.interval, timer.tick))

		if timer.tick < 5 then
			timer.tick = timer.tick + 1
		else
			timer:Halt() -- or Cron.Halt(timer)

			print(('[%s] Stopped after %.2f secs / %d ticks'):format(os.date('%H:%M:%S'), timer.interval * timer.tick, timer.tick))
		end
	end)
end)

registerForEvent('onUpdate', function(delta)
	-- This is required for Cron to function
	Cron.Update(delta)
end)
