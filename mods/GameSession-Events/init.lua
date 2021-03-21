local GameSession = require('GameSession')

registerForEvent('onInit', function()
	GameSession.Listen(GameSession.PrintState)
end)
