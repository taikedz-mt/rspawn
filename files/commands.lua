-- Command privileges

minetest.register_privilege("spawn", "Can teleport to spawn position.")
minetest.register_privilege("setspawn", "Can manually set a spawn point")
minetest.register_privilege("newspawn", "Can get a new randomized spawn position.")

-- Commands

minetest.register_chatcommand("spawn", {
	description = "Teleport to spawn position.",
	params = "",
	privs = "spawn",
	func = function(name)
		local target = rspawn.playerspawns[name]
        if target then
		    minetest.get_player_by_name(name):setpos(target)
        else
            minetest.chat_send_player(name, "You have no spawn position!")
        end
	end
})

minetest.register_chatcommand("setspawn", {
	description = "Assign current position as spawn position.",
	params = "",
	privs = "setspawn",
	func = function(name)
		rspawn.playerspawns[name] = minetest.get_player_by_name(name):getpos()
		rspawn:spawnsave()
		minetest.chat_send_player(name, "New spawn set !")
	end
})

minetest.register_chatcommand("newspawn", {
	description = "Randomly select a new spawn position.",
	params = "",
	privs = "newspawn",
	func = function(name, args)
        rspawn:double_set_new_playerspawn(minetest.get_player_by_name(name), 2)
	end
})
