local GameUI = require('GameUI')

registerForEvent('onInit', function()
    -- Listen for state changes
    -- See GameUI.PrintState() for all state props
    GameUI.Observe(function(state)
        GameUI.PrintState(state)
    end)
end)
