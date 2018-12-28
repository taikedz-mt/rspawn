rspawn = {}

--[[ FIXME - still not working
The mapgen cannot keep up with the attempts to query it.

Need to rework this so that emerging is done once per query, and only after some time passes do we attempt to query.

Don't recursively use newspawn() !
--]]

local mpath = minetest.get_modpath("rspawn")

local origin = minetest.setting_get_pos("static_spawnpoint") or {x=0, y=50, z=0}
local radial_step = 16
rspawn.adminname = minetest.setting_get("name") or "singleplayer"

rspawn.spawnanywhere = minetest.setting_get("spawn_anywhere") or false
rspawn.playerspawns = {}

rspawn.bedspawn = minetest.setting_getbool("enable_bed_respawn")
if rspawn.bedspawn ~= false then
    rspawn.bedspawn = true
end

dofile(mpath.."/files/data.lua")
dofile(mpath.."/files/commands.lua")

rspawn:spawnload()

local function forceload_operate(pos1, pos2, handler)
    local i,j,k

    for i=pos1.x,pos2.x,16 do
        for j=pos1.y,pos2.y,16 do
            for k=pos1.z,pos2.z,16 do
                handler({x=1,y=j,z=k})
            end
        end
    end
end

local function forceload_blocks_in(pos1, pos2)
    forceload_operate(pos1, pos2, minetest.forceload_block)
end

local function forceload_free_blocks_in(pos1, pos2)
    forceload_operate(pos1, pos2, minetest.forceload_free_block)
end

local function daylight_above(min_daylight, pos)
    minetest.get_node_light(pos, 0.5)
end

function rspawn:newspawn(pos, radius)
    -- Given a seed position and a radius, find an exact spawn location
    --   that is walkable and with 2 air nodes above it

    if not radius then
        radius = radial_step
    end

    if radius > 4*radial_step then
        minetest.debug("No valid spawnable location around "..minetest.pos_to_string(pos))
        return
    end

    minetest.debug("Trying somewhere around "..minetest.pos_to_string(pos))

    local breadth = radius/2
    local altitude = radius*2

    local pos1 = {x=pos.x-breadth, y=pos.y-altitude/2, z=pos.z-breadth}
    local pos2 = {x=pos.x+breadth, y=pos.y+altitude, z=pos.z+breadth}

    minetest.debug("Searching "..minetest.pos_to_string(pos1).." to "..minetest.pos_to_string(pos2))

    minetest.emerge_area(pos1, pos2)
    forceload_blocks_in(pos1, pos2)

    local airnodes = minetest.find_nodes_in_area(pos1, pos2, {"air"})
    local validnodes = {}

    minetest.debug("Found "..tostring(#airnodes).." air nodes within "..tostring(radius))
    for _,anode in pairs(airnodes) do
        local under = minetest.get_node( {x=anode.x, y=anode.y-1, z=anode.z} ).name
        local over = minetest.get_node( {x=anode.x, y=anode.y+1, z=anode.z} ).name
        under = minetest.registered_nodes[under]
        over = minetest.registered_nodes[over]

        if under.walkable
         and not over.walkable
         and not minetest.is_protected(anode, rspawn.adminname)
         and daylight_above(7, anode) then
            validnodes[#validnodes+1] = anode
        end
    end

    if #validnodes > 0 then
        minetest.log("info", "New spawn point found with radius "..tostring(radius))
        forceload_free_blocks_in(pos1, pos2)
        return validnodes[math.random(1,#validnodes)]
    end

    local pos = rspawn:newspawn(pos, radius+radial_step)
    if not pos then
        -- Nothing found, do cleanup with this largest forceloaded area
        forceload_free_blocks_in(pos1, pos2)
    end
    return pos
end

function rspawn:genpos()
    -- Generate a random position, and derive a new spawn position
    local pos = origin

    if rspawn.spawnanywhere then
        pos = {
            x = math.random(-30000,30000),
            y = math.random(0, 10),
            z = math.random(-30000,30000),
        }
    end

    return pos
end

function rspawn:set_new_playerspawn(player, args)
    local newpos
    if args == "here" then
        newpos = player:get_pos()
    elseif args then
        newpos = minetest.string_to_pos(args)
    end

    if not newpos then
        newpos = rspawn:genpos()
    end

    local spawnpos = rspawn:newspawn(newpos)
    local name = player:get_player_name()

    if spawnpos then
        rspawn.playerspawns[name] = spawnpos
        player:setpos(rspawn.playerspawns[name])
        rspawn:spawnsave()
        return spawnpos
    end
end

function rspawn:double_set_new_playerspawn(player, attempts)
    local cpos = minetest.pos_to_string(rspawn:genpos())
    local name = player:get_player_name()
    attempts = attempts or 1

    minetest.chat_send_player(name, tostring(attempts)..": Searching for a suitable spawn around "..cpos)

    local newpos = rspawn:set_new_playerspawn(player, cpos)
    if not newpos then
        minetest.after(4,function()
            newpos = rspawn:set_new_playerspawn(player, cpos)
            if not newpos then
                if attempts > 0 then
                    rspawn:double_set_new_playerspawn(player, attempts - 1)
                else
                    minetest.chat_send_player(name, "! Could not identify suitable spawn location (try again?)")
                end
            else
                minetest.chat_send_player(name, "New spawn set at "..minetest.pos_to_string(newpos))
            end
        end)
    end
end

minetest.register_on_joinplayer(function(player)
    -- Use the recursive mode - it is not acceptable for a player
    --   not to receive a randomized spawn
    if not rspawn.playerspawns[player:get_player_name()] then
        rspawn:double_set_new_playerspawn(player, 10)
    end
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

    -- And if no bed, nor bed spwawning not active:
    player:setpos(rspawn.playerspawns[name])
    return true
end)
