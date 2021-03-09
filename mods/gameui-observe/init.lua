local GameUI = require('GameUI')

registerForEvent('onInit', function()
	GameUI.Observe(function(state)
		GameUI.PrintState(state)
	end)
end)
