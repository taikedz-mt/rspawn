# `[rspawn]` Randomized Spawning for Minetest

Causes players to receive a spawn point anywhere on the map. Players will likely spawn very far from eachother into prisitine areas.

## Features

* Player is assigned randomized spawnpoint on joining
    * New players will not spawn into protected areas
* Player will respawn at their spawnpoint if they die.
    * If `beds` spawning is active, then beds can be used to set players' re-spawn point (they still go to their main spawnpoint on invoking `/spawn`).
* Commands
    * Players can return to their spawn point with the `/spawn` command if they have `spawn` privilege.
        * Players can invite other players to join their spawn - see "Spawn guests" below
        * Players can allow any other player to visit their spawn - see "Town hosting" below
	* Players can request a new spawn point by typing `/newspawn` if they have the `newspawn` privilege.
	* Players can set their spawn point by typing `/setspawn` if they have the `setspawn` privelege.
    * Moderator players can assign a new random spawn for another player using `/playerspawn` if they have the `spawnadmin` privilege.

KNOWN ISSUE - Any player not yet registered with a spawn point will be given a spawn point anywhere in the world. If applying retroactively to a server, this will cause existing players to be re-spawned once.

### Spawn guests

Randomized spawning typically causes players to spawn far from eachother. If players wish to share a single spawn point, a player can add another to join their spawn position.

The player issuing the invite (host) must typically pay a levvy when adding another player.

* `/spawn add <player>` - allow another player to visit your spawn directly (levvy must be paid), or lift their exile (no levvy to pay)
* `/spawn kick <targetplayer>`
    * revoke rights to visit you
    * if the exiled player gets close to your spawn, they are kicked back to their own spawn
* `/spawn visit <player>` - visit a player's spawn
* `/spawn guests` - see who you have added to your spawn
* `/spawn hosts` - see whose spawns you may visit

Guests can help the spawn owner manage bans on their town.

### Town hosting

You can host a town from your spawn if you wish. Hosting a town means that any player who connects to the server will be able to visit your spawn. You can still `/spawn kick <playername>` individually in this mode. If you switch off town hosting, only allowed guests in your normal guestlist can visit.

There is no levvy on hosting a town.

* `/spawn town { open | close }` - switch town hosting on or off.
* `/spawn town { ban | unban } <playername> [<town>]` - ban or unban a player from a town
    * Town owners can use this, as well as unexiled guests of the town owner

Explicit guests can ban/unban other players from a town.

Town owner can forcibly ban a player by first adding the player to their guest list, and then exiling them. Guests cannot override this.

## Settings

Note that the spawn generation is performed in the background on a timer, allowing storing a collection of random spawn points to be generated ahead of time.

*Generic settings used*

* `name` - used for knowing the server admin's name
* `water_level` - Spawns are always set above water level, default `1`
* `static_spawnpoint` - main position the player will start at, default `{0,0,0}`
* `enable_bed_respawn` - from `beds` mod - if active, then respawning will happen at beds, instead of randomized spawnpoint

*rspawn-specific settings*

* Settings related to spawn generation
    * `rspawn.max_pregen` - maximum number of spawn points to pre-generate, default `20`
    * `rspawn.search_radius` - lateral radius around random point, within which a spawn point will be sought, default `32`
    * `rspawn.gen_frequency` - how frequently (in seconds) to generate a new spawn point, default `30`, increase this on slower servers
* `rspawn.spawn_anywhere` - whether to spawn anywhere in the world at sea level (limited by the bounds spawn limits, check below)
if false, only spawns at a fixed spawn locaiton, for every player.
    * if `true`, (default) spawns the player somewhere else on the map within valid air node and not inside solid block
    * if `false`, will randomize around the static spawn point using search radius as maximun area for.
* `rspawn.cooldown_time` - how many seconds between two uses of `/newspawn`, per player
* `rspawn.kick_on_fail` - whether to kick the player if a randomized spawn cannot be set, default `false`
* `rspawn.spawn_block` - place this custom block under the user's spawn point
* Guestlist and town related settings
    * `rspawn.levvy_name` - name of the block to use as levvy charge on the player issuing an invitation, default `default:cobble`
    * `rspawn.levvy_qtty` - number of blocks to levvy from the player who issued the invitation, default `10`
    * `rspawn.kick_period` - how frequently to check if exiled players are too near their locus of exile, default `3` (seconds)
    * `rspawn.exile_distance` - distance from exile locus at which player gets bounced back to their own spawn, default `64` (nodes)
* `rspawn.debug` - whether to print debugging messages, default `false`
* Bounds limiting - you can limit the random spawning search area to a given subsection of the global map if you wish:
    * `rspawn.min_x`, `rspawn.max_x`, `rspawn.min_z`, `rspawn.max_z` as expected

## Troubleshooting

As admin, you will receive notifications of inability to generate spawns when players join without being set a spawn. Those players will join but cannot play cos cannot spawn in a "valid spawn point".

If you only wants to solve it, just define a valid fixed spawn point with `static_spawnpoint` on your minetest.conf config file, then set `rspawn.gen_frequency` to a high number like 120 seconds or 300; warnings will continue but players will join and play (withou a spawn point set yet, take note).

If you are more hacker, you can turn on `rspawn.debug = true` to see debug in logs. Spawn generation uses a temporary forceload to read the blocks in the area ; it then releases the forceload after operating, so should not depend on the `max_forceloaded_blocks` setting.

If the generation log shows `0 air nodes found within <x>` on more than 2-3 consecutive tries, you may want to check that another mod is not forceloading blocks and then not subsequently clearing them, also try to reduce the bounds limits area of rspawn in settings, always around the fixed spawn point..

You may also find some mods do permanent forceloads by design (though this should be rare). In your world folder `~/.minetest/worlds/<yourworld>` there should eb a `force_loaded.txt` - see that its contents are simply `return {}`; if there is data in the table, then something else is forceloading blocks with permanence.

Resolutions in order of best to worst:

* Define a valid fixed spawn point with `static_spawnpoint` to be a valid air node and not a solid block
   * then set `rspawn.gen_frequency` to a high number like 120 seconds or 300, and reduce the bounds limits.
* identify the mod and have it clear them properly (ideal)
    * on UNIX/Linux you should be able to run `grep -rl forceload ~/.minetest/mods/` to see all mod files where forceloading is being done
* increase the max number of forceloaded blocks
    * (not great - you will effectively be simply mitigating a forceloaded-blocks-related memory leak)
* Stop minetest, delete the `force_loaded.txt` file, and start it again
    * (bad - some things in the mods using the forceload mechanism may break)

## Optimizations

It is also suitable for single player sessions too - if you want a new location to start a creative build, but don't need to go through creating another, separate world for it, just grab yourself a new spawnpoint!

On big multiplayers servers or small single players computers you may want to tune the mod.

#### For multiplayers big servers

* Define a valid fixed spawn point on your minetest.conf config file using the `static_spawnpoint` to a valid air node, not a solid block: it will be used if you do not want players to be kicked (by usage of `rspawn.kick_on_fail`) when there are no valid respawns points available.
* Bound limit must be little.. 400 nodes around is a number to play around. Do not set the `rspawn.search_radius` to a high number, 16 to 32 in big servers with big spawn random areas.
* Set `rspawn.gen_frequency` to a high number like 120 seconds or 300
* Change the Cooldown time - default is `300` seconds (5 minutes) between uses of `/newspawn`

#### Single Player Mode

* Add `rspawn` to your world
    * Go to the *Advanced Settings* area of Minetest, look for `mods > rspawn`
    * Change the frequency of pregeneration as required
        * Good CPUs, enough RAM and SSD hard drives might get away with a frequency of 20sec (!)
        * If you find your game immediately lagging due to excessive map generation, switch the frequency to say 120
    * Change the Cooldown time - default is `300` seconds (5 minutes) between uses of `/newspawn`
    * Optionally, change the maximum pregen to the desired number of spawnpoints to pregenerate and hold
* Start the game session; Wait around 1 minute or so as the initial spawn point gets generated and is assigned to you
* Jump around! (with `/newspawn`)
    * Until you exhaust pregens :-P

## License

(C) 2017 Tai "DuCake" Kedzierski

Provided under the terms of the LGPL v3.0
