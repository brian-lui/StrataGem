# StrataGem

Hey everyone! This is the current project for Hardly Working Games.

Eventually this will become private when it gets closer to release, but in the meantime please enjoy playing this game for free!

Debug mode is enabled by default. If you're coming from elsewhere and want to turn it off, press **"z"** in the game screen to toggle it.

Anyway this is in Love2D 11.1.

## How to run the game

Windows:
1. Download the binary [here](https://github.com/brian-lui/StrataGem/BINARIES/StrataGem!%20v0.7%20Windows.zip)
2. Unzip the file
3. Run StrataGem.exe

Other:
1. Download and install Love2D 11.1, available for download [here](https://love2d.org)
2. Create a shortcut/link to the executable
3. Download the master zip file [here](https://github.com/brian-lui/StrataGem/archive/master.zip)
4. Unzip the file, it will be unzipped to the folder StrataGem-master
5. Drag the folder to the Love2D executable


## How to play
(labelled diagram of the playing field)

### Basic game concept
The basin is divided into two halves. Each half belongs to a player. Players simultaneously take their turn, dragging any piece from the River into the basin. Players can also rotate gems at any time prior to dropping them in the basin. At the end of each turn, the River moves. It normally advances one space.

When three or more gems of the same color are connected vertically or horizontally, they explode and deal damage to the first non-red Star in the opponent's River. When a Star turns red (normally 4 gems' worth of damage), it breaks at the end of the turn. Excess damage will be transferred to the next Star down the River.

If a gem is on a star when it breaks, a row of gems will be added to the bottom of the basin of the person who received the damage.

When a player's half of the basin fills beyond the top, they lose.

### Advanced tactics: Rush and Double Cast
The energy bar is 6 units long, and starts with 3 units filled. At the start of each turn, each player gains 1 unit of energy. Energy can be used for two purposes:

**Rush** (3 units). Place a piece in the opponent's half of the basin. It will appear slightly below the opponent's piece, so it can be used to interfere with the oppponent's strategy.

**Double Cast** (3 units). Drop a second piece in your basin! The newer piece will appear above the first piece.
(diagram to explain rush and double cast interaction)

### Character Supers
Each character has their own super ability. The super bar starts out empty, and is filled from creating matches through regular play. Matches from gems that are the same color as the character's primary color (represented by the color of their bars) will give double the amount of super meter.

When the super bar is full, the player may click on the "Super" icon instead of playing a piece that turn. This will activate the character's super ability.


### Character Passives
Each character has their own unique abilities, which are described by clicking on the "Details" button in the character select screen. (The "Details" button is not implemented yet.)

For example, Heath creates fire by making horizontal matches, Walter creates rain by making vertical matches, Wolfgang lights up his BARK meter by making matches of the appropriate color.
