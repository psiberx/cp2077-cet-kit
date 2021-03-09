local GameUI = require('GameUI')

registerForEvent('onInit', function()
	GameUI.OnSessionStart(function()
		-- Triggered once the load is complete and the player is in the game
		-- (after the loading screen for "Load Game" or "New Game")
		print('Game Session Started')
	end)

	GameUI.OnSessionEnd(function()
		-- Triggered once the current game session has ended
		-- (when "Load Game" or "Exit to Main Menu" selected)
		print('Game Session Ended')
	end)
end)
