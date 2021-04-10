local GameUI = require('GameUI')

registerForEvent('onInit', function()
	GameUI.Listen(function(state)
		GameUI.PrintState(state)
	end)
end)
