local spawnsfile = minetest.get_worldpath().."/dynamicspawns.lua.ser"

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

    pregens = rspawn.playerspawns["pre gen"] or {}
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

    pregens = rspawn.playerspawns["pre gen"] or {}
    rspawn.playerspawns["pre gen"] = pregens

    minetest.debug("Loaded rspawn data with "..tostring(#pregens).." pregen nodes")
end

