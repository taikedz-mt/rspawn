local stepcount = 0
local newspawn_cooldown = {}

-- Command privileges

minetest.register_privilege("spawn", "Can teleport to spawn position.")
minetest.register_privilege("setspawn", "Can manually set a spawn point")
minetest.register_privilege("newspawn", "Can get a new randomized spawn position.")
minetest.register_privilege("spawnadmin", "Can clean up timers and set new spawns for players.")

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
        if not newspawn_cooldown[name] then
            rspawn:double_set_new_playerspawn(minetest.get_player_by_name(name), 2)
            newspawn_cooldown[name] = 300
        else
            minetest.chat_send_player(name, tostring(math.ceil(newspawn_cooldown[name])).."sec until you can randomize a new spawn.")
        end
	end
})

minetest.register_chatcommand("playerspawn", {
	description = "Randomly select a new spawn position for a player.",
	params = "playername",
	privs = "spawnadmin",
	func = function(adminname, playername)
        local jointname = adminname.."--"..playername
        if not newspawn_cooldown[jointname] then
            rspawn:double_set_new_playerspawn(minetest.get_player_by_name(playername), 2)
            newspawn_cooldown[jointname] = 60
        else
            minetest.chat_send_player(adminname, tostring(math.ceil(newspawn_cooldown[jointname])).."sec until you can randomize a new spawn for "..playername)
        end
	end
})

-- Prevent players from spamming newspawn
minetest.register_globalstep(function(dtime)
    local playername, playertime, shavetime
    stepcount = stepcount + dtime
    shavetime = stepcount
    if stepcount > 0.5 then
        stepcount = 0
    else
        return
    end

    for playername,playertime in pairs(newspawn_cooldown) do
        playertime = playertime - shavetime
        if playertime <= 0 then
            newspawn_cooldown[playername] = nil
            minetest.chat_send_player(playername, "/newspawn available")
        else
            newspawn_cooldown[playername] = playertime
        end
    end
end)
