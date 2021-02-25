# Lua Kit for Cyber Engine Tweaks

Set of independent modules and examples to help develop mods for Cyber Engine Tweaks. 

## Modules

### `Cron.lua`

Run one-off and repeating tasks.

Right now only two type of tasks available: to run *after X secs* and to run *every X secs*.  

I plan to implement support of cron expressions and tie them to the time system of the game.

### `GameUI.lua` 

Track Game UI state reactively. Doesn't use recurrent `onUpdate` checks. 
 
Current detections:
 
- Menus (Main Menu, Pause Menu, Hub, Fast Travel, Drop Point, Vendor, Stash)
- Loading / Loaded State (New Game and Load Game)
- Special Scenes (Cutscenes, Dialogs, Mirrors)
- Scanning with Kiroshi Optics
- Quickhacking with Cyberdeck
- Devices (Computers, Terminals)
- Popups (Weapon Wheel, Phone, Call Vehicle)
- Braindance (Playback, Editing)
- Fast Travel
- Photo Mode

Todo:

- Vehicle FPP and TPP
- Johnny's memories and takeovers 
- Visibility of individual HUD elements 
- Identify each menu screen

You can display own HUD elements and apply contextual logic depending on the current UI.

If you don't need UI this module also can be used effectively to detect game loads.
You can initialize mod state when the actual gameplay starts, and reset mod state, free resources when the game session ends.

## How To Use

### Cron Tasks

```lua
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
```

### Track UI Changes

```lua
local GameUI = require('GameUI')

registerForEvent('onInit', function()
    -- Listen for state changes
    -- See GameUI.PrintState() for all state props
    GameUI.Observe(function(state)
        GameUI.PrintState(state)
    end)
end)
```

### Track Loading State

```lua
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
```

## Examples

- [Minimap HUD extension with current player location](https://gist.github.com/psiberx/6a04862a17b35745dd4602f826b45245)  
  Uses `GameUI` to determine when to show or hide the widget.  
  The widget is visible only on the default in-game HUD.  
  ![WhereAmI](https://siberx.dev/cp2077-cet-demos/whereami-210223.jpg)
- [Read player actions / inputs](https://gist.github.com/psiberx/0e94bc93ed40a70a93a410734a5f5ade)
- [Create custom map pins](https://gist.github.com/psiberx/50bcf9368cfeff5937de1a1ed815bdb1)
- [Call any vehicle with Vehicle System](https://gist.github.com/psiberx/01c656eae15d84c78d3e097caf22e808)  
- [Fix Dead-Eye with TweakDB](https://gist.github.com/psiberx/e434c2d03bec65780e524d691afe5c81)
