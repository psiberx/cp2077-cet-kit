# Lua Kit for Cyber Engine Tweaks

## Components

### `Cron.lua`

Helper to run one-off and repeating tasks.

Right now there is only two type of tasks: to run *after X secs* and to run *every X secs*.  

I plan to implement support of cron expressions and tie them to the game time system.

### `GameUI.lua` 

Helper to track Game UI state reactively. 
Doesn't use recurrent `onUpdate` checks. 

Current detections:
 
- Menus (Main Menu, Pause Menu, Hub, Fast Travel, Drop Point, Vendor, Stash)
- Loading / Loaded State (New Game and Load Game)
- Special Scenes (Cutscenes, Dialogs, Mirrors)
- Scanning with Kiroshi Optics
- Quickhacking with Cyberdeck
- Devices (Computers, Terminals)
- Popups (Weapon Wheel, Phone, Call Vehicle)
- Braindance (Playback, Editing)
- Photo Mode

If you don't need UI state this helper can be effectively used to detect game loads / exit to main menu.
You can initialize mod state when the actual gameplay is started, and reset mod state, free resources when game session is ended.

## Samples

### Cron + GameUI Demo

```lua
local Cron = require('Cron')
local GameUI = require('GameUI')

local function time()
	return os.date('%H:%M:%S')
end

registerForEvent('onInit', function()
	-- Listen for state changes
	-- See GameUI.PrintState() for all state props
	GameUI.Observe(function(state)
		GameUI.PrintState(state)
	end)

	print(('[%s] Cron demo started'):format(time()))

	-- One-off timer
	Cron.After(5.0, function()
		print(('[%s] After 5.00 secs'):format(time()))
	end)

	-- Repeating self-halting timer with context
	Cron.Every(2.0, { tick = 1 }, function(timer)
		print(('[%s] Every %.2f secs #%d'):format(time(), timer.interval, timer.tick))

		if timer.tick < 5 then
			timer.tick = timer.tick + 1
		else
			timer:Halt() -- or Cron.Halt(timer)

			print(('[%s] Stopped after %.2f secs / %d ticks'):format(time(), timer.interval * timer.tick, timer.tick))
		end
	end)
end)

registerForEvent('onUpdate', function(delta)
	-- This is required for Cron to function
	Cron.Update(delta)
end)
```

### HUD Extension Demo

Gist: https://gist.github.com/psiberx/6a04862a17b35745dd4602f826b45245

Adds new HUD element near the Mini Map with the info about current player location.

Uses `GameUI` to determine when to show and hide the widget.
The widget is visible only on the default in-game HUD.

![WhereAmI](https://siberx.dev/cp2077-cet-demos/whereami-210223.jpg)

### Loading State Demo

The simple demo to see exactly when events are fired.

```lua
local GameUI = require('GameUI')

registerForEvent('onInit', function()
    GameUI.Observe(function(state)
        if state.isLoading then
            print('Loading')
        elseif state.isLoaded then
            print('Loaded')
        elseif state.isMainMenu then
            print('MainMenu')
        end
    end)
end)
```
