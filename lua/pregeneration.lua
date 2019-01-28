local steptime = 0

-- Ensure pregen data is stored and saved properly

local function len_pgen()
    return #rspawn.playerspawns["pre gen"]
end

local function set_pgen(idx, v)
    rspawn.playerspawns["pre gen"][idx] = v
    rspawn:spawnsave()
end

local function get_pgen(idx)
    return rspawn.playerspawns["pre gen"][idx]
end

-- Spawn generation

local function push_new_spawn()
    if len_pgen() >= rspawn.max_pregen_spawns then
        rspawn:debug("Max pregenerated spawns ("..rspawn.max_pregen_spawns..") reached : "..len_pgen())
        return
    end

    local random_pos = rspawn:genpos()
    local pos1,pos2 = rspawn:get_positions_for(random_pos, rspawn.search_radius)

    if rspawn:forceload_blocks_in(pos1, pos2) then
        minetest.after(rspawn.gen_frequency*0.8, function()
            -- Let the forceload do its thing, then act

            local newpos = rspawn:newspawn(random_pos, rspawn.search_radius)
            if newpos then
                rspawn:debug("Generated "..minetest.pos_to_string(newpos))
                set_pgen(len_pgen()+1, newpos )
            else
                rspawn:debug("Failed to generate new spawn point to push")
                minetest.chat_send_player(rspawn.admin, "Failed to generate new spawn")
            end

            rspawn:forceload_free_blocks_in(pos1, pos2)
        end)
    else
        rspawn:debug("Failed to push new spawn point - preexisting operation took precedence.")
    end
end

minetest.register_globalstep(function(dtime)
    steptime = steptime + dtime
    if steptime > rspawn.gen_frequency then
        steptime = 0
    else
        return
    end

    push_new_spawn()
end)

-- Access pregenrated spawns

function rspawn:get_next_spawn()
    local nspawn

    if len_pgen() > 0 then
        nspawn = get_pgen(len_pgen() )
        set_pgen(len_pgen(), nil)

        -- Someone might have claimed the area since.
        if minetest.is_protected(nspawn, "") then
            return rspawn:get_next_spawn()
        else
            rspawn:debug("Returning pregenerated spawn",nspawn)
        end
    end

    return nspawn
end

-- On load...

push_new_spawn()

