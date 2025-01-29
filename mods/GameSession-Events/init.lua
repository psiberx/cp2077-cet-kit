local GameSession = require('GameSession')

registerForEvent('onInit', function()
    GameSession.Listen(function(state)
        GameSession.PrintState(state)
    end)
end)
