local stepcount = 0
local newspawn_cooldown = {}

-- Command privileges

minetest.register_privilege("spawn", "Can teleport to spawn position.")
minetest.register_privilege("setspawn", "Can manually set a spawn point")
minetest.register_privilege("newspawn", "Can get a new randomized spawn position.")
minetest.register_privilege("spawnadmin", "Can clean up timers and set new spawns for players.")

-- Support functions

local function splitstring(sdata, sep)
    local idx
    local tdata = {}

    while sdata ~= "" do
        idx = sdata:find(sep)
        
        if idx then
            tdata[#tdata+1] = sdata:sub(1,idx-1)
            sdata = sdata:sub(idx+1, sdata:len() )

        else -- last element
            tdata[#tdata+1] = sdata
            break
        end
    end

    return tdata
end

local function set_original_spawn(tname)
    local tpos = rspawn.playerspawns["original spawns"][tname]

    if not tpos then
        minetest.chat_send_player(tname, "Could not find your original spawn!")

    elseif rspawn:consume_levvy(minetest.get_player_by_name(tname)) then
        rspawn:set_player_spawn(tname, tpos)
    else
        minetest.chat_send_player(tname, "You do not have enough to pay the levvy. Aborting.")
    end
end

local function request_new_spawn(username, targetname)
    local timername = username
    if targetname ~= username then
        timername = username.." "..targetname
    end

    if not newspawn_cooldown[timername] then
        rspawn:renew_player_spawn(targetname)
        newspawn_cooldown[timername] = 300
    else
        minetest.chat_send_player(username, tostring(math.ceil(newspawn_cooldown[timername])).."sec until you can randomize a new spawn for "..targetname)
    end
end

-- Commands

minetest.register_chatcommand("spawn", {
	description = "Teleport to spawn position, or manage invitations. See you current invitation with '/spawn invite'. If you are a guest at a spawn, return to your orgiinal spawn with '/spawn original'",
	params = "[ invite [<player>] | accept | decline | original ]",
	privs = "spawn",
	func = function(name, args)
		local target = rspawn.playerspawns[name]
        local args = splitstring(args, " ")

        if #args == 0 then
            if target then
                minetest.get_player_by_name(name):setpos(target)
                return

            else
                minetest.chat_send_player(name, "You have no spawn position!")
                return
            end

        elseif args[1] == "accept" then
            rspawn.invites:accept(name)
            return

        elseif args[1] == "decline" then
            rspawn.invites:decline(name)
            return

        elseif args[1] == "original" then
            set_original_spawn(name)

        elseif args[1] == "invite" then
            if #args == 2 then
                rspawn.invites:invite_player_fromto(name, args[2])
                return

            elseif #args == 1 then
                rspawn.invites:show_invite_for(name)
                return
            end

        end
        
        minetest.chat_send_player(name, "Please check '/help spawn'")
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
	description = "Randomly select a new spawn position for a player, or use specified position, 'original' for their original spawn.",
	params = "<playername> [<pos> | original]",
	privs = "spawnadmin",
	func = function(name, args)
        if args ~= "" then
            args = splitstring(args, " ")

            if #args == 2 then
                local tname = args[1]
                local tpos

                if args[2] == "original" then
                    tpos = rspawn.playerspawns["original spawns"][tname]
                    if not tpos then
                        minetest.chat_send_player( name, "Could not find original spawn for "..tname)
                        minetest.chat_send_player(tname, "Could not find original spawn for "..tname)
                        return
                    end
                else
                    tpos = minetest.string_to_pos(args[2])
                end

                if tpos then
                    rspawn:set_player_spawn(tname, tpos)
                    return
                end
            elseif #args == 1 then
                request_new_spawn(name, args[1])
                return
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
