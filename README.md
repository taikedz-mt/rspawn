# r-Spawn for Minetest

A spawn command for Minetest without needing a fixed point -- singpleayer rejoice!

Players are each given their own randomized spawn point on first joining. If no `static_spawnpoint` is defined in `minetest.conf`, the origin is 0,0,0. If static spawn point is defined, that point is used as origin instead.

Considerations:

* Players will not spawn in spaces that are protected by any other player than the Server Admin.
* Player will respawn at their spawnpoint if they die.
	* Players will respawn at their bed if this option is active
	* Their `/spawn` location will still be the randomized location.
* Players can request a new spawn point by typing `/newspawn` if they have the `newspawn` privilege.

## License

(C) 2017 Tai "DuCake" Kedzierski
based originally on the mod uploaded by everamzah

Provided under the terms of the LGPL v3.0
