local stepcount = 0
local newspawn_cooldown = {}
local cooldown_time = tonumber(minetest.settings:get("rspawn.cooldown_time")) or 300

-- Command privileges

minetest.register_privilege("spawn", "Can teleport to a spawn position and manage shared spawns.")
minetest.register_privilege("setspawn", "Can manually set a spawn point.")
minetest.register_privilege("newspawn", "Can get a new randomized spawn position.")
minetest.register_privilege("spawnadmin", "Can clean up timers and set new spawns for players.")

-- Support functions

local function request_new_spawn(username, targetname)
    local timername = username
    if targetname ~= username then
        timername = username.." "..targetname
    end

    if not newspawn_cooldown[timername] then
        if not rspawn:renew_player_spawn(targetname) then
            minetest.chat_send_player(username, "Could not set new spawn for "..targetname)
            return false
        else
            newspawn_cooldown[timername] = cooldown_time
            return true
        end
    else
        minetest.chat_send_player(username, tostring(math.ceil(newspawn_cooldown[timername])).."sec until you can randomize a new spawn for "..targetname)
        return false
    end
end

-- Commands

minetest.register_chatcommand("spawn", {
	description = "Teleport to your spawn, or manage guests in your spawn.",
	params = "[ add <player> | visit <player> | kick <player> | guests | hosts ]",
	privs = "spawn",
	func = function(playername, args)
		local target = rspawn.playerspawns[playername]
        local args = args:split(" ")

        if #args == 0 then
            if target then
                minetest.get_player_by_name(playername):setpos(target)
                return

            else
                minetest.chat_send_player(playername, "You have no spawn position!")
                return
            end
        elseif #args < 3 then
            for command,action in pairs({
                ["guests"] = function() rspawn.guestlists:listguests(playername) end,
                ["hosts"] = function() rspawn.guestlists:listhosts(playername) end,
                ["add"] = function(commandername,targetname) rspawn.guestlists:addplayer(commandername,targetname) end,
                ["visit"] = function(commandername,targetname) rspawn.guestlists:visitplayer(targetname, commandername) end,
                ["kick"] = function(commandername,targetname) rspawn.guestlists:exileplayer(commandername, targetname) end,
                }) do

                if args[1] == command then
                    if #args == 2 then
                        action(playername, args[2])
                        return

                    elseif #args == 1 then
                        action()
                        return
                    end
                end
            end
        end
        
        minetest.chat_send_player(playername, "Please check '/help spawn'")
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
        request_new_spawn(name, name)
    end
})

minetest.register_chatcommand("playerspawn", {
	description = "Randomly select a new spawn position for a player, or use specified position, or go to their spawn.",
	params = "<playername> { new | <pos> | go }",
	privs = "spawnadmin",
	func = function(name, args)
        if args ~= "" then
            args = args:split(" ")

            if #args == 2 then
                local tname = args[1]
                local tpos

                if args[2] == "go" then
                    local user = minetest.get_player_by_name(name)
                    local dest = rspawn.playerspawns[args[1]]
                    if dest then
                        user:setpos(dest)
                        minetest.chat_send_player(name, "Moved to spawn point of "..args[1])
                    else
                        minetest.chat_send_player(name, "No rspawn coords for "..args[1])
                    end
                    return

                elseif args[2] == "new" then
                    request_new_spawn(name, args[1])
                    return

                else
                    tpos = minetest.string_to_pos(args[2])

                    if tpos then
                        rspawn.playerspawns[tname] = tpos
                        minetest.chat_send_player(name, tname.."'s spawn has been reset")
                        return
                    end
                end
            end
        end

        minetest.chat_send_player(name, "Error. See '/help playerspawn'")
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
