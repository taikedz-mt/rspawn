local spawnsfile = minetest.get_worldpath().."/dynamicspawns.lua.ser"

-- Comatibility with old behaviour - players whose original spawns had not been registered receive the one they are now using
local function reconcile_original_spawns()
    if not rspawn.playerspawns["original spawns"] then
        rspawn.playerspawns["original spawns"] = {}
    end

    for playername,spawnpos in pairs(rspawn.playerspawns) do
        if playername ~= "pre gen" and playername ~= "original spawns" then
            if not rspawn.playerspawns["original spawns"][playername] then
                rspawn.playerspawns["original spawns"][playername] = rspawn.playerspawns[playername]
            end
        end
    end

    rspawn:spawnsave()
end

function rspawn:spawnsave()
	local serdata = minetest.serialize(rspawn.playerspawns)
	if not serdata then
		minetest.log("error", "[spawn] Data serialization failed")
		return
	end
	local file, err = io.open(spawnsfile, "w")
	if err then
		return err
	end
	file:write(serdata)
	file:close()

    local pregens = rspawn.playerspawns["pre gen"] or {}
    minetest.debug("Wrote rspawn data with "..tostring(#pregens).." pregen nodes")
end

function rspawn:spawnload()
	local file, err = io.open(spawnsfile, "r")
	if not err then
        rspawn.playerspawns = minetest.deserialize(file:read("*a"))
        file:close()
	else
		minetest.log("error", "[spawn] Data read failed - initializing")
        rspawn.playerspawns = {}
    end

    local pregens = rspawn.playerspawns["pre gen"] or {}
    rspawn.playerspawns["pre gen"] = pregens

    reconcile_original_spawns()

    minetest.debug("Loaded rspawn data with "..tostring(#pregens).." pregen nodes")
end

