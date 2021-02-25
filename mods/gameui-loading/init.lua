local GameUI = require('GameUI')

registerForEvent('onInit', function()
    GameUI.Observe(function(state)
        if state.isLoading then
            -- Triggered once when the load is started
            -- (including when the player selects "Exit to Main Menu")
            print('Loading')
        elseif state.isLoaded then
            -- Triggered once when the load is complete
            -- and the player is in the game
            -- (i.e. after the loading screen)
            print('Loaded')
        end
    end)
end)
