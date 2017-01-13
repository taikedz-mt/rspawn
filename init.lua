local origin = minetest.setting_get_pos("static_spawnpoint") or {x=0, y=0, z=0}
local adminname = minetest.setting_get("name") or "singleplayer"

local playerspawns = {}
local spawnsfile = minetest.get_worldpath().."/dynamicspawns.lua.ser"

minetest.register_privilege("spawn", "Can teleport to spawn position.")


minetest.register_chatcommand("spawn", {
	description = "Teleport to spawn position.",
	params = "",
	privs = "spawn",
	func = function(name)
		local target = playerspawns[name]
		if not target then
			playerspawns[name] = newspawn()
			target = playerspawns[name]
			spawnsave()
		end
		minetest.get_player_by_name(name):setpos(target)
	end
})

local function newspawn(radius)
	if not radius then
		radius = 32
	end
	if radius > 256 then
		minetest.log("error", "No valid spawnable location")
		return
	end

	local pos1 = {x=origin.x-radius, y=origin.y, z=origin.z-radius}
	local pos2 = {x=origin.x+radius, y=origin.y+(radius/2), z=origin.z+radius}

	local airnodes = minetest.find_nodes_in_area(pos1, pos2, {"air"})
	local validnodes = {}

	for _,anode in pairs(airnodes) do
		local under = minetest.get_node( {x=anode.x, y=anode.y-1, z=anode.z} ).name
		local over = minetest.get_node( {x=anode.x, y=anode.y+1, z=anode.z} ).name
		under = minetest.registered_nodes[under]
		over = minetest.registered_nodes[over]

		
		if under.walkable and not over.walkable and not minetest.is_protected(anode, adminname) then
			validnodes[#validnodes+1] = anode
		end
	end

	if #validnodes > 0 then
		minetest.log("info", "New spawn point found with radius "..tostring(radius))
		return validnodes[math.random(1,#validnodes)]
	end

	return newspawn(radius+32)
end

minetest.register_privilege("newspawn", "Can get a new randomized spawn position.")

minetest.register_chatcommand("newspawn", {
	description = "Randomly select a new spawn position.",
	params = "",
	privs = "newspawn",
	func = function(name)
		playerspawns[name] = newspawn()
		minetest.get_player_by_name(name):setpos(playerspawns[name])
		spawnsave()
	end
})

function spawnsave()
	local serdata = minetest.serialize(playerspawns)
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

function spawnload()
	local file, err = io.open(spawnsfile, "r")
	if err then
		minetest.log("error", "[spawn] Data read failed")
		return
	end
	playerspawns = minetest.deserialize(file:read("*a"))
	file:close()
end

spawnload()

minetest.register_on_newplayer(function(player)
	minetest.after(1,function()
		local name = player:get_player_name()

		 -- Set immediately so that joinplayer does not get triggered whilst we're stil looking
		playerspawns[name] = player:getpos()

		playerspawns[name] = newspawn()
		player:setpos(playerspawns[name])
		spawnsave()
	end)
end)

minetest.register_on_joinplayer(function(player)
	minetest.after(1.1, function()
		local name = player:get_player_name()
		if not playerspawns[name] then
			playerspawns[name] = newspawn()
			player:setpos(playerspawns[name])
			spawnsave()
		end
	end)
end)

minetest.register_on_respawnplayer(function(player)
	local name = player:get_player_name()
	player:setpos(playerspawns[name])
	return true
end)
