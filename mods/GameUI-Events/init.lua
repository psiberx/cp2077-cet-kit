local GameUI = require('GameUI')

registerForEvent('onInit', function()
	-- Listen for all event
	GameUI.Listen(function(state)
		GameUI.PrintState(state)
	end)
end)
