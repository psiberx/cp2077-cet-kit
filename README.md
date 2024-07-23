# Lua Kit for Cyber Engine Tweaks

Set of independent modules and examples to help develop mods for Cyber Engine Tweaks. 

## Modules

### `Cron.lua`

Run one-off and repeating tasks.

Right now only two type of tasks available: to run *after X secs* and to run *every X secs*.  

I plan to implement support of cron expressions and tie them to the time system of the game.

### `GameHUD.lua` 

Show in-game messages.

### `GameUI.lua` 

Track game UI state reactively. Doesn't use recurrent `onUpdate` checks. 
 
Current detections:
 
- Menus
  * Main Menu (Load Game, Settings, Credits)
  * New Game (Difficulty, Life Path, Body Type, Customization, Attributes, Summary)
  * Pause Menu (Save Game, Load Game, Settings, Credits) 
  * Death Menu (Load Game, Settings)
  * Hub (Backpack, Inventory, Cyberware, Character, Stats, Map, Crafting, Journal, Messages, Shards, Tarot, Database)
  * Vendor (Trade, RipperDoc, Drop Point)
  * Network Breach
  * Fast Travel
  * Stash
- Tutorials
- Loading Screen
- Scenes (Cinematics, Limited Gameplay)
- Vehicles (First Person, Third Person)
- Scanning with Kiroshi Optics
- Quickhacking with Cyberdeck
- Devices (Computers, Terminals)
- Popups (Phone, Call Vehicle, Radio)
- Weapon Wheel
- Fast Travel
- Braindance (Playback, Editing)
- Cyberspace
- Johnny's Takeovers
- Johnny's Memories
- Photo Mode

You can display own HUD elements and apply contextual logic depending on the current UI.

### `GameSession.lua` 

Track game session reactively and store data linked to a save file. 
 
Current detections:
 
- Session Start (New Game, Load Game)
- Session End (Load Game, Exit to Main Menu)
- Saving and Loading (Manual Save, Quick Save, Auto Save)
- Pause State (All Menus, Fast Travel, Photo Mode, Tutorials)
- Blur State (Weapon Wheel, Phone, Call Vehicle, Radio)
- Death State

This module can be used to efficiently detect when a player 
is loading into the game or exiting the current game session. 
You can initialize mod state when the actual gameplay starts, 
and reset mod state and free resources when the game session ends.

Data persistence feature particularly useful for gameplay mods 
for storing its internal state.

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
    GameSession.OnLoad(function()
        print('Console was opened', userState.consoleUses, 'time(s)') -- Show the number on load 
    end)
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

    if GameSettings.NeedsConfirmation() then
        GameSettings.Confirm()
    end

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

Option 1 &ndash; Toggle all settings in the group:

```lua
local GameSettings = require('GameSettings')

registerHotkey('ToggleHUD', 'Toggle HUD', function()
    GameSettings.ToggleGroup('/interface/hud')
end)
```

Option 2 &ndash; Toggle specific settings:

```lua
local GameSettings = require('GameSettings')

registerHotkey('ToggleHUD', 'Toggle HUD', function()
    GameSettings.ToggleAll({
        '/interface/hud/action_buttons',
        '/interface/hud/activity_log',
        '/interface/hud/ammo_counter',
        '/interface/hud/healthbar',
        '/interface/hud/input_hints',
        '/interface/hud/johnny_hud',
        '/interface/hud/minimap',
        '/interface/hud/npc_healthbar',
        '/interface/hud/npc_names',
        '/interface/hud/object_markers',
        '/interface/hud/quest_tracker',
        '/interface/hud/stamina_oxygen',
    })
end)
```

### Switch Blur With Hotkey

```lua
registerHotkey('SwitchBlur', 'Switch blur', function()
    local options, current = GameSettings.Options('/graphics/basic/MotionBlur')
    local next = current + 1

    if next > #options then
        next = 1
    end

    GameSettings.Set('/graphics/basic/MotionBlur', options[next])
    GameSettings.Save() -- Required for most graphics settings

    print(('Switched blur from %s to %s'):format(options[current], options[next]))
end)
```

## Examples

- [Minimap HUD extension](https://github.com/psiberx/cp2077-cet-kit/blob/main/mods/GameUI-WhereAmI/init.lua)  
  Uses `GameUI` to determine when to show or hide the widget.  
  The widget is visible only on the default in-game HUD.  
  ![WhereAmI](https://siberx.dev/cp2077-cet-demos/whereami-210223.jpg)
- [Kill stats recorder](https://github.com/psiberx/cp2077-cet-kit/blob/main/mods/GameSession-KillStats/init.lua)  
  Uses `GameSession` to store kill stats for each save file.  
  Uses `GameHUD` to display on screen messages for kills.  
  ![KillStats](https://siberx.dev/cp2077-cet-demos/killstats-210326.jpg)
