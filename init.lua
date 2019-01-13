rspawn = {}
rspawn.playerspawns = {}

local mpath = minetest.get_modpath("rspawn")

local function notnil_or(d, v)
    if v == nil then
        return d
    else
        return v
    end
end

-- Water level, plus one to ensure we are above the sea.
local water_level = tonumber(minetest.settings:get("water_level", "0") )
local radial_step = 16

-- Setting with no namespace for interoperability
local static_spawnpoint = minetest.setting_get_pos("static_spawnpoint") or {x=0, y=0, z=0}
rspawn.admin = minetest.settings:get("name") or "" -- For messaging only

-- Setting from beds mod
rspawn.bedspawn = minetest.setting_getbool("enable_bed_respawn", true) -- from beds mod

-- rSpawn specific settings
rspawn.debug_on = minetest.settings:get_bool("rspawn.debug")
rspawn.spawnanywhere = notnil_or(true, minetest.settings:get_bool("rspawn.spawn_anywhere") )
rspawn.kick_on_fail = notnil_or(false, minetest.settings:get_bool("rspawn.kick_on_fail"))
rspawn.max_pregen_spawns = tonumber(minetest.settings:get("rspawn.max_pregen") or 5)
rspawn.search_radius = tonumber(minetest.settings:get("rspawn.search_radius") or 32)
rspawn.gen_frequency = tonumber(minetest.settings:get("rspawn.gen_frequency") or 30)
rspawn.spawn_block = minetest.settings:get("rspawn.spawn_block")

rspawn.min_x = tonumber(minetest.settings:get("rspawn.min_x") or -31000)
rspawn.max_x = tonumber(minetest.settings:get("rspawn.max_x") or 31000)
rspawn.min_z = tonumber(minetest.settings:get("rspawn.min_z") or -31000)
rspawn.max_z = tonumber(minetest.settings:get("rspawn.max_z") or 31000)
    
dofile(mpath.."/src/data.lua")
dofile(mpath.."/src/invites.lua")
dofile(mpath.."/src/commands.lua")
dofile(mpath.."/src/forceload.lua")
dofile(mpath.."/src/debugging.lua")




rspawn:spawnload()

local function set_default_node(pos)
    if rspawn.spawn_block then
        minetest.set_node(pos, {name=rspawn.spawn_block})
    end
end

local function daylight_above(min_daylight, pos)
    local level = minetest.get_node_light(pos, 0.5)
    return min_daylight <= level
end

function rspawn:get_positions_for(pos, radius)
    local breadth = radius
    local altitude = radius*2

    local pos1 = {x=pos.x-breadth, y=pos.y, z=pos.z-breadth}
    local pos2 = {x=pos.x+breadth, y=pos.y+altitude, z=pos.z+breadth}

    return pos1,pos2
end

function rspawn:newspawn(pos, radius)
    -- Given a seed position and a radius, find an exact spawn location
    --   that is an air node, walkable under it, non-walkable over it
    --   bright during the day, and not leaves

    rspawn:debug("Trying somewhere around "..minetest.pos_to_string(pos))

    local pos1,pos2 = rspawn:get_positions_for(pos, radius)

    rspawn:debug("Searching "..minetest.pos_to_string(pos1).." to "..minetest.pos_to_string(pos2))

    local airnodes = minetest.find_nodes_in_area(pos1, pos2, {"air"})
    local validnodes = {}

    rspawn:debug("Found "..tostring(#airnodes).." air nodes within "..tostring(radius))
    for _,anode in pairs(airnodes) do
        local under = minetest.get_node( {x=anode.x, y=anode.y-1, z=anode.z} ).name
        local over = minetest.get_node( {x=anode.x, y=anode.y+1, z=anode.z} ).name
        under = minetest.registered_nodes[under]
        over = minetest.registered_nodes[over]

        if under.walkable
         and not over.walkable
         and not minetest.is_protected(anode, "")
         and not (under.groups and under.groups.leaves ) -- no spawning on treetops!
         and daylight_above(7, anode) then
            validnodes[#validnodes+1] = anode
        end
    end

    if #validnodes > 0 then
        rspawn:debug("Valid spawn points found with radius "..tostring(radius))
        local newpos = validnodes[math.random(1,#validnodes)]

        return newpos
    else
        rspawn:debug("No valid air nodes")
    end
end

function rspawn:genpos()
    -- Generate a random position, and derive a new spawn position
    local pos = static_spawnpoint

    if rspawn.spawnanywhere then
        pos = {
            x = math.random(rspawn.min_x,rspawn.max_x),
            y = water_level, -- always start at waterlevel
            z = math.random(rspawn.min_z,rspawn.max_z),
        }
    end

    return pos
end

function rspawn:set_player_spawn(name, newpos)
    local tplayer = minetest.get_player_by_name(name)
    if not tplayer then
        return false
    end

    local spos = minetest.pos_to_string(newpos)

    rspawn.debug("Saving spawn for "..name, spos)
    rspawn.playerspawns[name] = newpos
    rspawn:spawnsave()

    minetest.chat_send_player(name, "New spawn set at "..spos)

    tplayer:setpos(rspawn.playerspawns[name])
    minetest.after(0.5,function()
        set_default_node({x=newpos.x,y=newpos.y-1,z=newpos.z})
    end)

    return true
end

local function register_original_spawn(playername, pos)
    if not rspawn.playerspawns["original spawns"] then
        rspawn.playerspawns["original spawns"] = {}
    end
    rspawn.playerspawns["original spawns"][playername] = pos
end

function rspawn:set_newplayer_spawn(player)
    -- only use for new players / players who have never had a randomized spawn
    if not player then return end

    local playername = player:get_player_name()

    if playername == "" then return end

    if not rspawn.playerspawns[playername] then
        local newpos = rspawn:get_next_spawn()

        if newpos then
            register_original_spawn(playername, newpos)
            rspawn:set_player_spawn(playername, newpos)

        else
            -- We did not get a new position
            
            if rspawn.kick_on_fail then
                minetest.kick_player(playername, "No personalized spawn points available - please try again later.")

            else
                minetest.chat_send_player(playername, "Could not get custom spawn! Retrying in "..rspawn.gen_frequency.." seconds")
                minetest.chat_send_player(rspawn.admin, "Exhausted spawns! Could not spawn "..playername)
                minetest.log("warning", "rspawn -- Exhausted spawns! Could not spawn "..playername)

                minetest.after(rspawn.gen_frequency, function()
                    rspawn:set_newplayer_spawn(player)
                end)
            end
        end
    end
end

function rspawn:renew_player_spawn(playername)
    local player = minetest.get_player_by_name(playername)
    if not player then
        return false
    end

    local newpos = rspawn:get_next_spawn()

    if newpos then
        return rspawn:set_player_spawn(playername, newpos)

    else
        minetest.chat_send_player(playername, "Could not get custom spawn!")
        return false
    end
end

minetest.register_on_joinplayer(function(player)
    rspawn:set_newplayer_spawn(player)
end)

minetest.register_on_respawnplayer(function(player)
    local name = player:get_player_name()
    if rspawn.bedspawn == true then
        local pos = beds.spawn[name]
        if pos then
            player:setpos(pos)
            return true
        end
    end

    minetest.debug("Respawning "..name)
    local pos = rspawn.playerspawns[name]

    -- And if no bed, nor bed spwawning not active:
    if pos then
        player:setpos(pos)
    else
        minetest.chat_send_player(name, "Failed to find your spawn point!")
        minetest.log("warning", "rspawn --Could not find spawn point for "..name)
    end
    return true
end)

dofile(mpath.."/src/pregeneration.lua")
