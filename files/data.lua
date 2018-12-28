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
end

function rspawn:spawnload()
	local file, err = io.open(spawnsfile, "r")
	if err then
		minetest.log("error", "[spawn] Data read failed")
		return
	end
	rspawn.playerspawns = minetest.deserialize(file:read("*a"))
	file:close()
end

