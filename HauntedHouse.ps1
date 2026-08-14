<#
Haunted House - a text adventure in PowerShell

Files:
  HauntedHouse.ps1  - engine, game state, and main loop (this file)
  AsciiArt.ps1      - all room/treasure ASCII art
  Rooms.ps1         - room definitions and layout
#>

$Host.UI.RawUI.WindowTitle = "The Haunted House"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

#region ---------- Utility ----------

function Write-Slow {
    param([string]$Text, [int]$DelayMs = 8, [string]$Color = "Gray")
    foreach ($ch in $Text.ToCharArray()) {
        Write-Host -NoNewline $ch -ForegroundColor $Color
        Start-Sleep -Milliseconds $DelayMs
    }
    Write-Host ""
}

function Write-Art {
    param([string]$Art, [string]$Color = "DarkGray")
    Write-Host $Art -ForegroundColor $Color
}

function Suspend-Key {
    Write-Host ""
    Write-Host "[press any key to continue]" -ForegroundColor DarkCyan
    [void][System.Console]::ReadKey($true)
}

function Read-Cmd {
    param([string]$Prompt = "> ")
    Write-Host ""
    Write-Host -NoNewline $Prompt -ForegroundColor Yellow
    return (Read-Host).Trim().ToLower()
}

function Start-Spooky-Sound {
    $sounds = @(
        "You hear a faint creaaeaak from somewhere above...",
        "Something skitters across the floor in the dark.",
        "A cold draft blows past your neck.",
        "Far away, a door slams shut on its own.",
        "You swear you just heard your name whispered.",
        "The floorboards groan under a weight that isn't yours.",
        "A window rattles even though it's shut tight.",
        "You hear tiny claws scratching inside the walls."
    )
    Write-Slow ($sounds | Get-Random) 6 "DarkMagenta"
}

#endregion

#region ---------- Game State ----------

$global:HasFlashlight = $true
$global:FlashlightOn = $false
$global:HasBlackSkeleton = $true
$global:HasBlueSkeleton = $true
$global:HasAtticKey = $false
$global:HasCellarKey = $false
$global:CluesFound = @()
$global:Visited = @{}
$global:GameOver = $false
$global:TreasureRoom = $null
$global:ArmorMoved = $false
$global:GhostBefriended = $false
$global:DumbwaiterUnlocked = $false
$global:CurrentRoom = $null
$global:PendingLockedRoom = $null

# Rooms that are lit well enough to see/search without the flashlight
$global:LitRooms = @("foyer","livingroom","dining","kitchen","hallway")

#endregion

#region ---------- Room Model ----------

function New-Room {
    param($Id,$Name,$Floor,$Desc,$Art,$Exits,$Clue=$null,$Locked=$false,$KeyNeeded=$null,$Npc=$null,$Item=$null)
    $global:Rooms[$Id] = [ordered]@{
        Id = $Id
        Name = $Name
        Floor = $Floor
        Desc = $Desc
        Art = $Art
        Exits = $Exits
        Clue = $Clue
        Locked = $Locked
        KeyNeeded = $KeyNeeded
        Npc = $Npc
        Item = $Item
        Searched = $false
        Dug = $false
    }
}

# Load ASCII art and room layout (depends on New-Room being defined above)
. (Join-Path $ScriptDir "AsciiArt.ps1")
. (Join-Path $ScriptDir "Rooms.ps1")

#endregion

#region ---------- Display Helpers ----------

function Show-Intro {
    Clear-Host
    Write-Art $HouseArt "DarkGray"
    Write-Host ""
    Write-Slow "THE HAUNTED HOUSE" 20 "Red"
    Write-Host ""
    Write-Slow "Your flashlight flickers as you step through the front door of the old Clownyface house." 10 "White"
    Write-Slow "Legend says a treasure lies buried somewhere within its twelve rooms..." 10 "White"
    Write-Slow "You've brought two stuffed skeletons for courage: a black one and a blue one." 10 "White"
    Write-Host ""
    Write-Slow "Type 'help' at any time to see your options." 10 "Cyan"
    Show-Help
    Suspend-Key
}

function Show-Help {
    Write-Host ""
    Write-Host "COMMANDS:" -ForegroundColor Cyan
    Write-Host "  go <direction>     - move (north, south, east, west, up, down)"
    Write-Host "  look               - re-read the room description"
    Write-Host "  search             - search the room for clues/items"
    Write-Host "  dig                - dig for buried treasure in this room"
    Write-Host "  inventory / i      - show what you're carrying"
    Write-Host "  flashlight         - toggle your flashlight on/off"
    Write-Host "  clues              - review clues you've collected"
    Write-Host "  talk               - talk to a character in the room, if any"
    Write-Host "  use <item>         - use an item (e.g. 'use black skeleton', 'use key')"
    Write-Host "  map                - show discovered rooms and exits"
    Write-Host "  quit               - leave the house (end game)"
}

function Show-Inventory {
    Write-Host ""
    Write-Host "You are carrying:" -ForegroundColor Cyan
    if ($global:HasFlashlight) { Write-Host "  - A flashlight $(if($global:FlashlightOn){'(ON)'}else{'(off)'})" }
    if ($global:HasBlackSkeleton) { Write-Host "  - A small black stuffed skeleton" }
    if ($global:HasBlueSkeleton) { Write-Host "  - A small blue stuffed skeleton" }
    if ($global:HasAtticKey) { Write-Host "  - A tarnished key labeled 'ATTIC'" }
    if ($global:HasCellarKey) { Write-Host "  - A small brass key labeled 'CELLAR'" }
}

function Show-Clues {
    Write-Host ""
    if ($global:CluesFound.Count -eq 0) {
        Write-Host "You haven't found any clues yet." -ForegroundColor DarkYellow
    } else {
        Write-Host "Clues collected:" -ForegroundColor Cyan
        foreach ($c in $global:CluesFound) { Write-Host "  * $c" }
    }
}

function Get-CellText {
    param([string]$RoomId, [int]$Width)

    if (-not $RoomId) { return (" " * $Width) }

    $label = $global:RoomLabels[$RoomId]
    if (-not $global:Visited.ContainsKey($RoomId)) {
        $label = "?" * [Math]::Min($label.Length, 7)
    }
    if ($RoomId -eq $global:CurrentRoom) {
        $label = "*$label*"
    }

    $pad = $Width - $label.Length
    $left = [Math]::Max([Math]::Floor($pad / 2), 0)
    $right = [Math]::Max($pad - $left, 0)
    return ((" " * $left) + $label + (" " * $right))
}

function Get-CellColor {
    param([string]$RoomId)
    if ($RoomId -and $RoomId -eq $global:CurrentRoom) { return "Yellow" }
    if ($RoomId -and $global:Visited.ContainsKey($RoomId)) { return "White" }
    return "DarkGray"
}

function Write-FloorGrid {
    param($Layout, [int]$Width = 13)

    $numCols = $Layout[0].Count
    $border = "+" + ((("-" * $Width) + "+") * $numCols)

    Write-Host $border -ForegroundColor DarkGray
    foreach ($row in $Layout) {
        Write-Host -NoNewline "|" -ForegroundColor DarkGray
        foreach ($cell in $row) {
            Write-Host -NoNewline (Get-CellText -RoomId $cell -Width $Width) -ForegroundColor (Get-CellColor $cell)
            Write-Host -NoNewline "|" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host $border -ForegroundColor DarkGray
    }
}

function Show-Map {
    Write-Host ""
    Write-Host "===== FLOOR 1 =====" -ForegroundColor Cyan
    Write-FloorGrid -Layout $global:FloorLayouts[1]
    Write-Host "  stairs (Foyer) <-> Hallway, Floor 2" -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "===== FLOOR 2 =====" -ForegroundColor Cyan
    Write-FloorGrid -Layout $global:FloorLayouts[2]

    $atticLabel = if ($global:CurrentRoom -eq "attic") { "*Attic*" } elseif ($global:Visited.ContainsKey("attic")) { "Attic" } else { "???" }
    Write-Host "  $atticLabel - up narrow stairs from Master Bedroom" -ForegroundColor (Get-CellColor "attic")
    Write-Host "  dumbwaiter: Master Bedroom <-> Kitchen" -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "You are in the $($global:Rooms[$global:CurrentRoom].Name)." -ForegroundColor Yellow
    Write-Host "(Yellow = you, White = visited, Grey = undiscovered)" -ForegroundColor DarkGray
}

function Show-Treasure {
    Clear-Host
    Write-Art $TreasureArt "Yellow"
    Write-Host ""
    Write-Slow "Your flashlight beam catches a glint of gold beneath a floorboard..." 8 "Yellow"
    Write-Slow "You pry it open and find an ancient chest, brimming with coins, jewels, and a faded photograph of the Clownyface family." 8 "Yellow"
    Write-Host ""
    if ($global:GhostBefriended) {
        Write-Slow "The child ghost from the attic appears beside you, smiling for the first time in a hundred years." 8 "Magenta"
        Write-Slow "'Thank you for finding it,' it whispers, then fades peacefully into light." 8 "Magenta"
    }
    Write-Host ""
    Write-Slow "*** YOU FOUND THE TREASURE! YOU WIN! ***" 15 "Green"
    Write-Host ""
    Write-Slow "Clues you used along the way:" 6 "Cyan"
    foreach ($c in $global:CluesFound) { Write-Host "  * $c" -ForegroundColor Gray }
    $global:GameOver = $true
}

#endregion

#region ---------- Room Interaction ----------

function Test-KeyHeld {
    param($KeyNeeded)
    switch ($KeyNeeded) {
        "cellarkey" { return $global:HasCellarKey }
        "atticaccess" { return $global:HasAtticKey }
        default { return $true }
    }
}

function Set-SpecialEntry {
    param($RoomId)
    switch ($RoomId) {
        "hallway" {
            if (-not $global:ArmorMoved -and (Get-Random -Minimum 1 -Maximum 3) -eq 1) {
                Write-Host ""
                Write-Slow "As you pass, the suit of armor's helmet creaks... and slowly turns to follow you." 8 "DarkRed"
            }
        }
        "attic" {
            if (-not $global:GhostBefriended) {
                Write-Host ""
                Write-Slow "A pale, translucent figure drifts from behind a trunk. A child ghost, staring at you with hollow eyes." 8 "Magenta"
                Write-Slow "It doesn't attack. It just... waits." 8 "Magenta"
            }
        }
        "kitchen" {
            if (-not $global:DumbwaiterUnlocked) {
                Write-Host ""
                Write-Slow "The dumbwaiter shaft rattles. Something up in the Master Bedroom must connect to it." 6 "DarkGray"
            }
        }
    }
}

function Enter-Room {
    param([string]$RoomId)

    $room = $global:Rooms[$RoomId]

    if ($room.Locked) {
        Write-Host ""
        Write-Slow "The door is locked tight. You'll need to find a way in." 8 "Red"
        $global:PendingLockedRoom = $RoomId
        return $false
    }

    $global:CurrentRoom = $RoomId
    $global:Visited[$RoomId] = $true

    Clear-Host
    Write-Art $room.Art "DarkGray"
    Write-Host ""
    Write-Host "== $($room.Name) ==" -ForegroundColor Green
    if ($global:FlashlightOn -or $room.Id -in $global:LitRooms) {
        Write-Slow $room.Desc 6 "White"
    } else {
        Write-Slow "It's too dark to see clearly. Maybe turn on your flashlight?" 6 "DarkGray"
    }

    if ((Get-Random -Minimum 1 -Maximum 4) -eq 1) { Start-Spooky-Sound }

    Set-SpecialEntry -RoomId $RoomId

    return $true
}

function Invoke-Search {
    $room = $global:Rooms[$global:CurrentRoom]

    if (-not $global:FlashlightOn -and $room.Id -notin $global:LitRooms) {
        Write-Slow "It's too dark to search properly. Turn on your flashlight first." 8 "Red"
        return
    }

    if ($room.Searched) {
        Write-Slow "You've already thoroughly searched this room." 6 "DarkYellow"
        return
    }
    $room.Searched = $true

    if ($room.Clue) {
        Write-Host ""
        Write-Slow "You search carefully and find something..." 6 "Cyan"
        Write-Slow $room.Clue 6 "Yellow"
        $global:CluesFound += $room.Clue
    } else {
        Write-Slow "You search but find nothing of note - just dust and cobwebs." 6 "DarkGray"
    }

    # special item pickups
    if ($room.Id -eq "closet" -and -not $global:HasCellarKey) {
        $global:HasCellarKey = $true
        Write-Slow "You pocket the small brass CELLAR key!" 6 "Green"
    }
    if ($room.Id -eq "study" -and -not $global:HasAtticKey) {
        $global:HasAtticKey = $true
        Write-Slow "Tucked behind the globe, you find a tarnished key labeled 'ATTIC'!" 6 "Green"
    }
}

function Invoke-Dig {
    $room = $global:Rooms[$global:CurrentRoom]

    if (-not $global:FlashlightOn -and $room.Id -notin $global:LitRooms) {
        Write-Slow "It's too dark to dig properly. Turn on your flashlight first." 8 "Red"
        return
    }

    if ($room.Id -eq $global:TreasureRoom) {
        Show-Treasure
        return
    }

    if ($room.Dug) {
        Write-Slow "You've already dug through this room. There's nothing more buried here." 6 "DarkYellow"
        return
    }
    $room.Dug = $true

    Write-Slow "You dig around the floorboards and corners, but there's no treasure buried here." 6 "DarkGray"
}

function Start-Talk {
    $room = $global:Rooms[$global:CurrentRoom]
    if (-not $room.Npc) {
        Write-Slow "There's no one here to talk to." 6 "DarkGray"
        return
    }
    switch ($room.Npc) {
        "armor" {
            Write-Slow "You address the suit of armor. It says nothing... but you notice its gauntlet points toward the Dining Room." 8 "Gray"
            $global:ArmorMoved = $true
        }
        "ghost" {
            if (-not $global:GhostBefriended) {
                if ($global:HasBlackSkeleton -or $global:HasBlueSkeleton) {
                    Write-Host ""
                    Write-Slow "You hold out one of your stuffed skeletons. The ghost's hollow eyes widen." 8 "Magenta"
                    Write-Slow "'You brought a friend for me?' it whispers, and gently takes the skeleton." 8 "Magenta"
                    Write-Slow "The ghost calms, and the attic grows warmer. It murmurs a final clue before fading:" 8 "Magenta"
                    $ghostClue = "The ghost whispers: 'What you seek is not in the rooms you've already searched twice - look where the coldest draft meets the warmest secret.'"
                    Write-Slow $ghostClue 8 "Yellow"
                    $global:CluesFound += $ghostClue
                    $global:GhostBefriended = $true
                } else {
                    Write-Slow "The ghost reaches toward you, but you have nothing to offer it. It recoils sadly." 8 "Magenta"
                }
            } else {
                Write-Slow "The ghost child hums softly, content, cradling the stuffed skeleton you gave it." 6 "Magenta"
            }
        }
        "ghostwriter" {
            Write-Slow "You hear scratching at the desk - an invisible hand finishing a sentence in the journal: 'Look up. The answer is never on the floor you're standing on.'" 8 "Magenta"
            $c = "The invisible writer's note: 'Look up. The answer is never on the floor you're standing on.'"
            if ($global:CluesFound -notcontains $c) { $global:CluesFound += $c }
        }
        default {
            Write-Slow "There's no response." 6 "DarkGray"
        }
    }
}

function Enable-Flashlight {
    $global:FlashlightOn = -not $global:FlashlightOn
    if ($global:FlashlightOn) {
        Write-Slow "Click. Your flashlight beam cuts through the darkness." 6 "Cyan"
    } else {
        Write-Slow "Click. Darkness creeps back in." 6 "DarkGray"
    }
}

function Use-Item {
    param([string]$ItemArg)

    if ($ItemArg -match "flashlight") {
        Enable-Flashlight
        return
    }

    if ($ItemArg -match "key") {
        if (-not $global:PendingLockedRoom) {
            Write-Slow "There's no locked door here to use a key on. Try walking toward one first." 6 "DarkGray"
            return
        }

        $lockedRoom = $global:Rooms[$global:PendingLockedRoom]
        if (Test-KeyHeld $lockedRoom.KeyNeeded) {
            Write-Slow "You slide the key into the lock. It turns with a rusty groan - the door swings open!" 8 "Green"
            $lockedRoom.Locked = $false
            $global:PendingLockedRoom = $null
            Enter-Room $lockedRoom.Id | Out-Null
        } else {
            Write-Slow "You try your key, but it doesn't fit this lock." 6 "Red"
        }
        return
    }

    if ($ItemArg -match "skeleton") {
        if ($global:CurrentRoom -eq "attic") {
            Start-Talk
        }
        elseif ($global:CurrentRoom -eq "hallway") {
            Write-Slow "You place a stuffed skeleton at the armor's feet. It seems... satisfied, and stops turning to watch you." 8 "Gray"
            $global:ArmorMoved = $true
        }
        else {
            Write-Slow "You hug your stuffed skeleton tightly. It doesn't do much here, but you feel a little braver." 6 "Cyan"
        }
        return
    }

    if ($ItemArg -match "dumbwaiter") {
        if ($global:CurrentRoom -eq "master" -or $global:CurrentRoom -eq "kitchen") {
            $dest = if ($global:CurrentRoom -eq "master") { "kitchen" } else { "master" }
            $destRoom = $global:Rooms[$dest]
            if ($destRoom.Locked) {
                Write-Slow "You climb in and pull the rope, but the dumbwaiter jams partway - the door on the other side is locked tight." 8 "Red"
                $global:PendingLockedRoom = $dest
                return
            }
            $global:DumbwaiterUnlocked = $true
            Write-Slow "You climb into the dusty dumbwaiter and pull the rope. With a groan, it carries you to the $($destRoom.Name)!" 8 "Cyan"
            Enter-Room $dest | Out-Null
        } else {
            Write-Slow "There's no dumbwaiter here. It only connects the Master Bedroom and the Kitchen." 6 "DarkGray"
        }
        return
    }

    Write-Slow "You're not sure how to use that here." 6 "DarkGray"
}

#endregion

#region ---------- Main Loop ----------

function Invoke-Command {
    param([string]$CommandLine)

    $parts = $CommandLine -split '\s+', 2
    $verb = $parts[0]
    $arg = if ($parts.Count -gt 1) { $parts[1] } else { "" }

    switch -Regex ($verb) {
        "^(help|\?)$" { Show-Help }
        "^(i|inventory)$" { Show-Inventory }
        "^clues$" { Show-Clues }
        "^map$" { Show-Map }
        "^look$" { Enter-Room $global:CurrentRoom | Out-Null }
        "^search$" { Invoke-Search }
        "^dig$" { Invoke-Dig }
        "^talk$" { Start-Talk }
        "^flashlight$" { Enable-Flashlight }
        "^use$" { Use-Item -ItemArg $arg }
        "^(go|move|walk)$" {
            $room = $global:Rooms[$global:CurrentRoom]
            if ($room.Exits.ContainsKey($arg)) {
                Enter-Room $room.Exits[$arg] | Out-Null
            } else {
                Write-Slow "You can't go that way." 6 "Red"
            }
        }
        "^(north|south|east|west|up|down)$" {
            $room = $global:Rooms[$global:CurrentRoom]
            if ($room.Exits.ContainsKey($verb)) {
                Enter-Room $room.Exits[$verb] | Out-Null
            } else {
                Write-Slow "You can't go that way." 6 "Red"
            }
        }
        "^(quit|exit)$" {
            Write-Slow "You decide the house has had enough of you for tonight. You step back out into the moonlight..." 8 "White"
            $global:GameOver = $true
        }
        default {
            Write-Slow "You're not sure how to do that. Type 'help' for a list of commands." 6 "DarkYellow"
        }
    }
}

function Start-Game {
    Show-Intro
    $global:CurrentRoom = "foyer"
    Enter-Room $global:CurrentRoom | Out-Null

    while (-not $global:GameOver) {
        $cmd = Read-Cmd
        Invoke-Command -CommandLine $cmd
    }

    Write-Host ""
    Write-Slow "Thanks for exploring the Clownyface house." 10 "DarkCyan"
}

#endregion

Start-Game
