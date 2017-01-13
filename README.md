# r-Spawn for Minetest

A spawn command for Minetest without needing a fixed point

## Normal mode

If `static_spawnpoint` is set in `minetest.conf`, this mod will simply provide a `/spawn` command that takes players to that point.

## Randomized mode

If no static spawning point is defined, each player is given a spawn location somewhere near 0,0,0.

Players will not spawn in spaces that are protected by any other player than the Server Admin.

Players can request a new spawn point by typing `/newspawn` if they have the `newspawn` privilege.

## License

(C) 2017 Tai "DuCake" Kedzierski
based originally on the mod by everamzah

Provided under the terms of the LGPL v3.0
