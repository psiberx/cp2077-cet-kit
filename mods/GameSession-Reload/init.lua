local GameSession = require('GameSession')

local state = { runtime = 0 }

registerForEvent('onInit', function()
    GameSession.StoreInDir('sessions')
    GameSession.Persist(state)
    GameSession.OnLoad(function()
        -- This is not reset when the mod is reloaded
        print(('Runtime: %.2f s'):format(state.runtime))
    end)
    GameSession.TryLoad() -- Load temp session
end)

registerForEvent('onUpdate', function(delta)
    state.runtime = state.runtime + delta -- Some test data
end)

registerForEvent('onShutdown', function()
    GameSession.TrySave() -- Save temp session
end)