# `[rspawn]` Randomized Spawning for Minetest

Causes players to receive a spawn point anywhere on the map. Players will likely spawn veeery far from eachother into prisitine areas.

## Features

* Player is assigned randomized spawnpoint on joining
* Player will respawn at their spawnpoint if they die.
    * If `beds` spawning is active, then beds can be used to reset the players' spawn point.
* Players will not spawn in spaces that are protected by any other player than the Server Admin.
* Commands
    * Players can return to their spawn point with the `/spawn` command if they have `spawn` privilege.
        * Players can invite other players to join their spawn - see "Spawn invites" below
	* Players can request a new spawn point by typing `/newspawn` if they have the `newspawn` privilege.
	* Players can set their spawn point by typing `/setspawn` if they have the `setspawn` privelege.
    * Moderator players can assign a new random spawn for another player using `/playerspawn` if they have the `spawnadmin` privilege.

KNOWN ISSUE - Any player not yet registered with a spawn point will be given a spawn point anywhere in the world. If applying retroactively to a server, this will cause existing players to be re-spawned once.

### Spawn invites

Randomized spawning typically causes players to spawn far from eachother. If players wish to share a single spawn point, a player can invite another to join their spawn position.

The player issuing the invite (host) must typically pay a levvy when the other player (guest) accepts.

When the guest accepts:

* The host will pay the levvy from their inventory
* The guest's spawn will be set to the host's spawn position
* The guest will be transported to their new spawn immediately

The guest can return to their original spawn by running `/spawn original` ; they will themselves be charged the same levvy.

## Settings

Note that the spawn generation is performed in the background on a timer, allowing storing a collection of random spawn points to be generated ahead of time.

*Generic settings used*

* `name` - on servers, sets the name of the admin, players can spawn in areas protected by the admin.
* `water_level` - Spawns are always set above water level, default `1`
* `static_spawnpoint` - main position the player will start at, default `{0,0,0}`
* `enable_bed_respawn` - from `beds` mod - if active, then respawning will happen at beds, instead of randomized spawnpoint

*rspawn-specific settings*

* Settings related to spawn generation
    * `rspawn.max_pregen` - maximum number of spawn points to pre-generate, default `5`
    * `rspawn.search_radius` - lateral radius around random point, within which a spawn poitn will be sought, default `32`
    * `rspawn.gen_frequency` - how frequently (in seconds) to generate a new spawn point, default `30`
* `rspawn.spawn_anywhere` - whether to spawn anywhere in the world at sea level
    * default `true`
    * if `false`, will randomize around the static spawn point
* `rspawn.levvy_name` - name of the block to use as levvy charge on the player issuing an invitation, default `default:cobble`
* `rspawn.levvy_qtty` - number of blocks to levvy from the player who issued the invitation, default `99`
* `rspawn.kick_on_fail` - whether to kick the player if a randomized spawn cannot be set, default `false`
* `rspawn.spawn_block` - place this custom block under the user's spawn point
* `rspawn.debug` - whether to print debugging messages, default `false`

## Troubleshooting

You can turn on `rspawn.debug = true` to see debug in logs.

If the generation log shows `0 air nodes found within <x>` on more than 2-3 consecutive tries, you may want to check the max number of forceloaded blocks configured - see `max_forceloaded_blocks`.

This should be at least `2*(rspawn.search_radius^3) / (16^3)`, so with the default `rspawn.search_radius = 32`, you should have at least `max_forceloaded_blocks = 8`

Also check that another mod is not forceloading blocks and not clearing them.

You may also find some mods (rarely) do permanent forceloads. In your world folder `~/.minetest/worlds/<yourworld>` there should eb a `force_loaded.txt` - see that its contents are simply `return {}`; if there is data in the table, then something else is forceloading blocks.

Resolutions in order of best to worst:

* identify the mod and have it clear them properly (ideal)
* increase the max number of forceloaded blocks
    * (not great - you will effectively be simply mitigating a forceloaded-blocks-related memory leak)
* Stop minetest, delete the `force_loaded.txt` file, and start it again
    * (bad - some things in the mods using the forceload mechanism may break)

## License

(C) 2017 Tai "DuCake" Kedzierski

Provided under the terms of the LGPL v3.0
