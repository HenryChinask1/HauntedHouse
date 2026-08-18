<#
Room definitions for the Haunted House game.
Dot-sourced by HauntedHouse.ps1 - expects AsciiArt.ps1 to already be loaded (for the $XxxArt variables)
and the New-Room function to already be defined.

Builds $global:Rooms and picks $global:TreasureRoom.
#>

$global:Rooms = @{}

# --- Ground floor ---
New-Room -Id "foyer" -Name "Front Foyer" -Floor 1 -Desc "You stand in a grand, dusty foyer. A chandelier sways slightly even though there's no breeze. A staircase leads up. Doors lead to a Living Room and a Dining Room." -Art $FoyerArt -Exits @{ north="livingroom"; east="dining"; up="hallway" }

New-Room -Id "livingroom" -Name "Living Room" -Floor 1 -Desc "An old TV flickers above the fireplace, somehow still playing 'Gabby's Dollhouse' reruns to no one. Moth-eaten sofas line the walls." -Art $LivingRoomArt -Exits @{ south="foyer"; east="kitchen" } -Clue "The TV static briefly clears, showing a message: 'Under the stairs, cats don't dig, but treasure might.'"

New-Room -Id "dining" -Name "Dining Room" -Floor 1 -Desc "A long table is set for twelve, plates untouched for decades. A chandelier drips wax that never lands." -Art $DiningArt -Exits @{ west="foyer"; north="kitchen"; south="basement" } -Clue "Scratched into the table: 'The room with the coldest floor hides the warmest secret.'"

New-Room -Id "kitchen" -Name "Kitchen" -Floor 1 -Desc "Pots hang crookedly. A rusty dumbwaiter shaft leads up into darkness." -Art $KitchenArt -Exits @{ west="livingroom"; south="dining" } -Clue "A recipe card reads: 'Two eyes of glass watch the study from above the mantle.'"

New-Room -Id "basement" -Name "Basement" -Floor 1 -Desc "Thick spiderwebs coat every surface. Something with too many legs just scurried out of your flashlight beam." -Art $BasementArt -Exits @{ up="dining" } -Locked $true -KeyNeeded "cellarkey" -Clue "Carved into a support beam: 'What ticks but has no heart hides where letters are written.'"

# --- Hallway connects floors, has armor & stairs ---
New-Room -Id "hallway" -Name "Upstairs Hallway" -Floor 2 -Desc "A suit of armor stands motionless at the end of the hall... or does it? Doors branch off in every direction." -Art $HallwayArt -Exits @{ down="foyer"; north="master"; east="library"; west="kidsroom"; south="bath" } -Npc "armor"

New-Room -Id "master" -Name "Master Bedroom" -Floor 2 -Desc "A spider stuffed animal sits in the corner of the bedroom. A dumbwaiter door is set into the wall, its rope frayed but intact." -Art $MasterArt -Exits @{ south="hallway"; up="attic" } -Locked $true -KeyNeeded "atticaccess" -Clue "Under the pillow, a note: 'The globe in the study spins toward truth.'"

New-Room -Id "library" -Name "Library" -Floor 2 -Desc "Floor-to-ceiling bookshelves, most collapsed. Something rustles between the pages of a fallen book." -Art $LibraryArt -Exits @{ west="hallway"; north="study" } -Clue "A bookmark reads: 'The closet keeps what the coats forgot.'"

New-Room -Id "study" -Name "Study" -Floor 2 -Desc "A dusty globe sits on the desk, spun to a spot marked in red ink. An old rotary phone rings once, then stops." -Art $StudyArt -Exits @{ south="library" } -Clue "A journal page: 'Above the mantle in the dining room, glass eyes never blink.'" -Npc "ghostwriter"

New-Room -Id "kidsroom" -Name "Kid's Room" -Floor 2 -Desc "A single teddy bear sits abandoned on the floor. The bunkbed's top mattress has claw marks." -Art $KidsRoomArt -Exits @{ east="hallway"; north="closet" } -Clue "Crayon scrawl on the wall: 'The basement beam counts the ticks of a clock with no heart.'"

New-Room -Id "closet" -Name "Hidden Closet" -Floor 2 -Desc "A cramped closet stuffed with moth-eaten coats. Something metallic glints in a shoe box." -Art $ClosetArt -Exits @{ south="kidsroom" } -Clue "Inside a shoe: a small brass key labeled 'CELLAR'."

New-Room -Id "bath" -Name "Bathroom" -Floor 2 -Desc "A cracked mirror shows your reflection a half-second too late. The tub is bone dry, except it drips anyway." -Art $BathArt -Exits @{ north="hallway" } -Clue "Fogged into the mirror: 'Two skeletons together may calm what walks the attic stairs.'"

New-Room -Id "attic" -Name "Attic" -Floor 2 -Desc "Dust hangs thick in your flashlight beam. Trunks and boxes are piled everywhere. Something pale drifts between them." -Art $AtticArt -Exits @{ down="master" } -Npc "ghost"

# Randomize treasure room among rooms that are not foyer/hallway (entry points)
$possibleTreasureRooms = @("basement","master","library","study","kidsroom","closet","bath","attic")
$global:TreasureRoom = $possibleTreasureRooms | Get-Random

# --- Map data (used by the `map` command for a top-down view) ---

# Short labels for the grid cells (kept to ~9 chars so they fit the boxes)
$global:RoomLabels = @{
    foyer      = "Foyer"
    livingroom = "Living Rm"
    dining     = "Dining"
    kitchen    = "Kitchen"
    basement   = "Basement"
    hallway    = "Hallway"
    master     = "Master Bd"
    library    = "Library"
    study      = "Study"
    kidsroom   = "Kids Room"
    closet     = "Closet"
    bath       = "Bath"
    attic      = "Attic"
}

# Top-down grid layout per floor. $null = empty lot. Position reflects each
# room's Exits in the layout above (N/S/E/W), so the grid lines up with how
# you actually walk between rooms.
$global:FloorLayouts = @{
    1 = @(
        @("livingroom", "kitchen"),
        @("foyer",       "dining"),
        @($null,         "basement")
    )
    2 = @(
        @("closet",   "master",  "study"),
        @("kidsroom", "hallway", "library"),
        @($null,      "bath",    $null)
    )
}
