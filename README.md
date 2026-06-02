# Denabled

A lightweight system loader for Roblox. Point it at one or more folders, and it requires every ModuleScript inside, then runs each system through a lifecycle in the correct order.

## Dependencies

None. Denabled has no external dependencies.

## Setup

Place Denabled in ReplicatedStorage or wherever you keep packages. Create a Script (server) or LocalScript (client) to start it.

```lua
local Denabled = require(game.ReplicatedStorage.Packages.Denabled)

Denabled:Start(
    game.ServerScriptService.Systems
)
```

You can pass multiple folders:

```lua
Denabled:Start(
    game.ServerScriptService.Systems,
    game.ServerScriptService.Services
)
```

## Lifecycle

Each system can implement any combination of these methods:

| Method | Phase | Timeout |
|---|---|---|
| `Init` or `Initialize` | First | 1 second per system |
| `PostInit` | Second | 1 second per system |
| `Start` | Third | None |

Denabled waits for all systems to finish each phase before moving to the next. If a system does not finish `Init` or `PostInit` within 1 second, a warning is printed and the framework moves on.

`Start` has no timeout and will wait indefinitely.

## Writing a System

A system is a ModuleScript that returns a table. Any methods you define on it will be called by Denabled at the right time.

```lua
-- ServerScriptService.Systems.MySystem

local MySystem = {}

function MySystem:Init()
    -- runs first, safe to set up state here
end

function MySystem:PostInit()
    -- runs after all systems have finished Init
    -- safe to call self:Get() here
end

function MySystem:Start()
    -- runs last, no timeout
end

function MySystem:PlayerAdded(player: Player)
    -- called automatically when a player joins
end

function MySystem:PlayerRemoving(player: Player)
    -- called automatically when a player leaves
end

return MySystem
```

On the client, `Init`, `PostInit`, and `Start` also receive `player` and `playerGui` as arguments.

## Getting Other Systems

Every system gets a `Get` method injected automatically:

```lua
function MySystem:Init()
    local OtherSystem = self:Get("OtherSystem")
end
```

Call this in `PostInit` or later to be sure the system you are asking for has already run its own `Init`.

## Skipping a ModuleScript

Add a `skip` attribute (boolean, true) to any ModuleScript and Denabled will not load it.

## Notes

- System names must be unique. If two ModuleScripts share a name, the second one is skipped and a warning is printed.
- Denabled can only be started once. Calling `Start` a second time does nothing.
