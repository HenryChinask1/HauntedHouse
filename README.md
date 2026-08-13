# The Haunted House

A text adventure game for PowerShell. Explore a dozen rooms across two floors of a haunted house, armed with a flashlight and two stuffed skeletons, to find a treasure hidden in a random room each playthrough. ~5-10 minutes per run.

## How to run

Open powershell and navgate to the directory

```powershell
cd path/to/HauntedHouse
```

Or, if you're already in a PowerShell prompt with a permissive execution policy:

```powershell
.\HauntedHouse.ps1
```

## Commands

- `go <direction>` / `north`, `south`, `east`, `west`, `up`, `down` — move between rooms
- `look` — re-read the current room
- `search` — search the room for clues and items
- `talk` — talk to a character in the room, if any
- `use <item>` — use an item (e.g. `use flashlight`, `use black skeleton`, `use dumbwaiter`)
- `flashlight` — toggle your flashlight on/off
- `inventory` / `i` — show what you're carrying
- `clues` — review clues you've collected
- `map` — show rooms you've visited and their exits
- `help` — list commands
- `quit` — leave the house

## Files

- `HauntedHouse.ps1` — game engine, state, and main loop
- `AsciiArt.ps1` — ASCII art for each room and the treasure
- `Rooms.ps1` — room definitions, layout, and treasure placement
