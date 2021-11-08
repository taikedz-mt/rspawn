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

CHANGENOTES

Spawn owners can invite guests.

* `/spawn add <player>` - owner, moderator; invite to join, remove ban. Levy
* `/spawn kick <player>` - owner, moderator; ban player and prevent from approaching
* `/spawn visit <player>` - visitor - visit player's spawn. Levy
* `/spawn guests [<player>]` - owner, list guests. If playername specified, allows moderator to see.
* `/spawn banned [<player>]` - owner, list banned players. If playername specified, allows moderator to see.
* `/spawn hosts` - visitor, list hosts who have added the player
* `/spawn moderators <player>`, list the moderators set by the spawn owner
* `/spawn {promote|demote}` allow other guests to ban/unban players

Guests can help the spawn owner manage bans on their town.

### Town hosting

To prevent town moderators from being used as a taxi service, moderators cannot "bring" people. INstead, a spawn can be set as "open" or not.

* `/spawn { open | close }` - switch spawn to open (it is a "town")
* `/spawn towns` - list open spawns

## DEVNOTES

This mod need fundamental change:

* possible spawn locations are determined by a calculation based on a grid in the `62000*62000` lateral map extents.
    * `f(int) -> pos` to allow a lookup by int, and by this respect, simply storing a list of ints for marking off consumed spawns.
    * separation of points can be determined by a "spawn radius" which also determines the kick extents
* this allows registering and marking off explored locations predictably
* spawn point assignment can then simply select a new location through randomizing on the list of these, which can be indefinitely large
* the forceload can run in the background more continuously without taxing the server
    * it can also perform a narrower, vertical search of highest point before spawning the player.

Visitor management

* We need to implement a relational schema for use here. When there is a many-to-many relationship like `player<-guest->player` relations, an easy way of registering the relationship needs to be provided by API
    * This should sit in its own mod `mt-lua-relations`, and be `required` by this mod

## License

(C) 2017 Tai "DuCake" Kedzierski

Provided under the terms of the LGPL v3.0
