# r-Spawn for Minetest

Causes players to receive a spawn point anywhere on the map. Players will likely spawn veeery far from eachother into prisitine areas.

## Features

* Player is assigned randomized spawnpoint on joining
* Player will respawn at their spawnpoint if they die.
    * If `beds` spawning is active, then beds can be used to reset the players' spawn point.
* Players will not spawn in spaces that are protected by any other player than the Server Admin.
* Commands
    * Players can return to their spawn point with the `/spawn` command if they have `spawn` privilege.
	* Players can request a new spawn point by typing `/newspawn` if they have the `newspawn` privilege.
	* Players can set their spawn point by typing `/setspawn` if they have the `setspawn` privelege.
    * Players can assign a new random spawn for another player using `/playerspawn` if they have the `spawnadmin` privilege.

KNOWN ISSUE - Any player not yet registered with a spawn point will be given a spawn point anywhere in the world. If applying retroactively to a server, this will cause existing players to be re-spawned once.

## Settings

Note that the spawn generation is performed in the background on a timer, allowing storing a collection of random spawn points to be generated ahead of time.

*Generic settings used*

* `name` - on servers, sets the name of the admin, players can spawn in areas protected by the admin.
* `water_level` - Spawns are always set above water level, default `1`
* `static_spawnpoint` - main plce the player will start at, default `{0,0,0}`
* `enable_bed_respawn` - from `beds` mod - if active, then respawning will happen at beds, instead of randomized spawnpoint

*rSpawn-specific settings*

* Settings related to spawn generation
    * `rspawn.max_pregen` - maximum number of spawn points to pre-generate, default `5`
    * `rspawn.search_radius` - lateral radius around random point, within which a spawn poitn will be sought, default `32`
    * `rspawn.gen_frequency` - how frequently (in seconds) to generate a new spawn point, default `30`
* `rspawn.spawn_anywhere` - whether to spawn anywhere in the world at sea level
    * default `true`
    * if `false`, will randomize around the static spawn point
* `rspawn.kick_on_fail` - whether to kick the player if a randomized spawn cannot be set, default `false`
* `rspawn.spawn_block` - place this custom block under the user's spawn point
* `rspawn.debug` - whether to print debugging messages, default `false`

## License

(C) 2017 Tai "DuCake" Kedzierski

Provided under the terms of the LGPL v3.0
