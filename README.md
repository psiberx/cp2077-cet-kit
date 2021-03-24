# Lua Kit for Cyber Engine Tweaks

Set of independent modules and examples to help develop mods for Cyber Engine Tweaks. 

## Modules

### `Cron.lua`

Run one-off and repeating tasks.

Right now only two type of tasks available: to run *after X secs* and to run *every X secs*.  

I plan to implement support of cron expressions and tie them to the time system of the game.

### `GameUI.lua` 

Track game UI state reactively. Doesn't use recurrent `onUpdate` checks. 
 
Current detections:
 
- Game Session (New Game, Load Game, Exit to Main Menu)
- Menus
  * Main Menu (Load Game, Settings, Credits)
  * New Game (Difficulty, Life Path, Body Type, Customization, Attributes, Summary)
  * Pause Menu (Save Game, Load Game, Settings, Credits) 
  * Death Menu (Load Game, Settings)
  * Hub (Inventory, Backpack, Cyberware, Character, Stats, Crafting, Journal, Messages, Shards, Tarot, Database)
  * Vendor (Trade, RipperDoc, Drop Point)
  * Network Breach
  * Fast Travel
  * Stash
- Loading Screen
- Scenes (Cutscenes, Dialogs, Mirrors)
- Scanning with Kiroshi Optics
- Quickhacking with Cyberdeck
- Devices (Computers, Terminals)
- Popups (Phone, Call Vehicle)
- Weapon Wheel
- Braindance (Playback, Editing)
- Vehicle (First Person, Third Person)
- Fast Travel
- Photo Mode

Todo:

- Virtual Reality
- Johnny's memories and takeovers 
- Visibility of individual HUD elements 

You can display own HUD elements and apply contextual logic depending on the current UI.

If you don't need UI, this module can be used to efficiently detect
when a player is loading into the game or exiting the current game session. 
You can initialize mod state when the actual gameplay starts, 
and reset mod state and free resources when the game session ends.

### `GameSession.lua` 

Track game session reactively and store data linked to a save file. 
 
Current detections:
 
- Session Start (New Game, Load Game)
- Session End (Load Game, Exit to Main Menu)
- Saving and Loading (Manual Save, Quick Save, Auto Save)
- Pause State (All Menus)
- Blur State (Weapon Wheel, Phone, Call Vehicle)
- Death State

Data persistence particularly useful for gameplay mods for storing internal state. 

### `GameSettings.lua` 

Manage game settings. 
You can get and set current values, get option lists, 
and export all settings as a table or to a file.

## How to use

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
    -- Listen for every UI state change
    GameUI.Observe(function(state)
        GameUI.PrintState(state)
    end)
end)
```

### Track UI Events

```lua
local GameUI = require('GameUI')

registerForEvent('onInit', function()
    -- Listen for every UI event
    GameUI.Listen(function(state)
        GameUI.PrintState(state)
    end)
end)
```

### Track Fast Traveling

```lua
local GameUI = require('GameUI')

registerForEvent('onInit', function()
    GameUI.OnFastTravelStart(function()
        print('Fast Travel Started')
    end)

    GameUI.OnFastTravelFinish(function()
        print('Fast Travel Finished')
    end)
end)
```

### Track Session Events

```lua
local GameSession = require('GameSession')

registerForEvent('onInit', function()
    -- Listen for every session event
    GameSession.Listen(function(state)
        GameSession.PrintState(state)
    end)
end)
```

### Track Session Lifecycle

```lua
local GameSession = require('GameSession')

registerForEvent('onInit', function()
    GameSession.OnStart(function()
        -- Triggered once the load is complete and the player is in the game
        -- (after the loading screen for "Load Game" or "New Game")
        print('Game Session Started')
    end)

    GameSession.OnEnd(function()
        -- Triggered once the current game session has ended
        -- (when "Load Game" or "Exit to Main Menu" selected)
        print('Game Session Ended')
    end)
end)
```

### Persist Session Data

```lua
local GameSession = require('GameSession')

local userState = { 
    consoleUses = 0 -- Initial state
}

registerForEvent('onInit', function()
    GameSession.StoreInDir('sessions') -- Set directory to store session data
    GameSession.Persist(userState) -- Link the data that should be watched and persisted 
end)

registerForEvent('onOverlayOpen', function()
    userState.consoleUses = userState.consoleUses + 1 -- Increase the number of console uses
end)
```

### Dump All Game Settings

```lua
local GameSettings = require('GameSettings')

registerHotkey('ExportSettings', 'Export all settings', function()
    GameSettings.ExportTo('settings.lua')
end)
```

### Switch FOV With Hotkey

```lua
local GameSettings = require('GameSettings')

registerHotkey('SwitchFOV', 'Switch FOV', function()
    local fov = GameSettings.Var('/graphics/basic/FieldOfView')

    fov.value = fov.value + fov.step

    if fov.value > fov.max then
        fov.value = fov.min
    end

    GameSettings.Set('/graphics/basic/FieldOfView', fov.value)

    print(('Current FOV: %.1f'):format(GameSettings.Get('/graphics/basic/FieldOfView')))
end)
```

### Cycle Resolutions With Hotkey

```lua
local GameSettings = require('GameSettings')

registerHotkey('SwitchResolution', 'Switch resolution', function()
    -- You can get available options and current selection for lists
    local options, current = GameSettings.Options('/video/display/Resolution')
    local next = current + 1

    if next > #options then
        next = 1
    end

    GameSettings.Set('/video/display/Resolution', options[next])

    if GameSettings.NeedsConfirmation() then
        GameSettings.Confirm()
    end

    print(('Switched resolution from %s to %s'):format(options[current], options[next]))
end)
```

### Toggle HUD With Hotkey

```lua
local GameSettings = require('GameSettings')

registerHotkey('ToggleHUD', 'Toggle HUD', function()
    GameSettings.Toggle('/interface/hud/action_buttons')
    GameSettings.Toggle('/interface/hud/activity_log')
    GameSettings.Toggle('/interface/hud/ammo_counter')
    GameSettings.Toggle('/interface/hud/chatters')
    GameSettings.Toggle('/interface/hud/healthbar')
    GameSettings.Toggle('/interface/hud/input_hints')
    GameSettings.Toggle('/interface/hud/johnny_hud')
    GameSettings.Toggle('/interface/hud/minimap')
    GameSettings.Toggle('/interface/hud/npc_healthbar')
    GameSettings.Toggle('/interface/hud/quest_tracker')
    GameSettings.Toggle('/interface/hud/stamina_oxygen')
end)
```

## Examples

- [Minimap HUD extension](https://github.com/psiberx/cp2077-cet-kit/blob/main/mods/GameUI-WhereAmI/init.lua)  
  Uses `GameUI` to determine when to show or hide the widget.  
  The widget is visible only on the default in-game HUD.  
  ![WhereAmI](https://siberx.dev/cp2077-cet-demos/whereami-210223.jpg)
- [Kill stats recorder](https://github.com/psiberx/cp2077-cet-kit/blob/main/mods/GameSession-KillStats/init.lua)  
  Uses `GameSession` to store kill stats for each save file.  
  Uses `GameHUD` to display on screen messages on kills.  
  ![KillStats](https://siberx.dev/cp2077-cet-demos/killstats-210324.jpg)
- [Read player actions / inputs](https://github.com/psiberx/cp2077-cet-kit/blob/main/mods/player-actions/init.lua)
- [Create custom map pins](https://github.com/psiberx/cp2077-cet-kit/blob/main/mods/mappin-system/init.lua)
- [Call any vehicle with Vehicle System](https://github.com/psiberx/cp2077-cet-kit/blob/main/mods/vehicle-system/init.lua)  
- [Fix Dead-Eye with TweakDB](https://github.com/psiberx/cp2077-cet-kit/blob/main/mods/dead-eye-fix/init.lua)
- [Manage game settings](https://github.com/psiberx/cp2077-cet-kit/blob/main/mods/settings-system/init.lua)
