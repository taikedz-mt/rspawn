local stepcount = 0
local newspawn_cooldown = {}

-- Command privileges

minetest.register_privilege("spawn", "Can teleport to spawn position.")
minetest.register_privilege("setspawn", "Can manually set a spawn point")
minetest.register_privilege("newspawn", "Can get a new randomized spawn position.")
minetest.register_privilege("spawnadmin", "Can clean up timers and set new spawns for players.")

-- Splitter

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

-- Commands

minetest.register_chatcommand("spawn", {
	description = "Teleport to spawn position, or manage invitations. See you current invitation with '/spawn invite'",
	params = "[ invite [<player>] | accept | decline ]",
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
                -- TODO, only one at a time, must be accepted or declined, and DO move player - not to be used lightly
            return

        elseif args[1] == "decline" then
            rspawn.invites:decline(name) -- TODO, free up invitation slot
            return

        elseif args[1] == "invite" then
            if #args == 2 then
                rspawn.invites:invite_player_fromto(name, args[2]) -- TODO
                return

            elseif #args == 1 then
                rspawn.invites:show_invite_for(name) -- TODO
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

minetest.register_chatcommand("newspawn", {
	description = "Randomly select a new spawn position.",
	params = "",
	privs = "newspawn",
	func = function(name, args)
        request_new_spawn(name, name)
    end
})

minetest.register_chatcommand("playerspawn", {
	description = "Randomly select a new spawn position for a player.",
	params = "playername",
	privs = "spawnadmin",
	func = function(adminname, playername)
        request_new_spawn(adminname, playername)
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
