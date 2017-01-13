local spawn_point = minetest.setting_get_pos("static_spawnpoint")

local playerspawns = {}
local spawnsfile = minetest.get_worldpath().."/dynamicspawns.lua.ser"

local function newspawn(radius)
	if not radius then
		radius = 32
	end
	if radius > 200 then
		minetest.debug("No valid spawnable location")
		return
	end
	minetest.debug("Re-spawn: Trying radius "..tostring(radius))

	local pos1 = {x=-radius, y=0, z=-radius}
	local pos2 = {x=radius, y=radius/2, z=radius}

	local airnodes = minetest.find_nodes_in_area(pos1, pos2, {"air"})
	local validnodes = {}

	for _,anode in pairs(airnodes) do
		local under = minetest.get_node( {x=anode.x, y=anode.y-1, z=anode.z} ).name
		local over = minetest.get_node( {x=anode.x, y=anode.y+1, z=anode.z} ).name
		under = minetest.registered_nodes[under]
		over = minetest.registered_nodes[over]

		
		if under.walkable and not over.walkable and not minetest.is_protected(anode, "") then
			validnodes[#validnodes+1] = anode
		end
	end

	if #validnodes > 0 then
		return validnodes[math.random(1,#validnodes)]
	end

	return newspawn(radius+32)
end

minetest.register_privilege("spawn", "Can teleport to spawn position.")

minetest.register_chatcommand("spawn", {
	description = "Teleport to spawn position.",
	params = "",
	privs = "spawn",
	func = function(name)
		local target = spawn_point
		if not target then
			target = playerspawns[name]
		end
		if not target then
			playerspawns[name] = newspawn()
			target = playerspawns[name]
			spawnsave()
		end
		minetest.get_player_by_name(name):setpos(target)
	end
})

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
		playerspawns[player:get_player_name()] = player:getpos()
	end)
end)

minetest.register_on_joinplayer(function(player)
	minetest.after(1, function()
		if not playerspawns[player:get_player_name()] then
			playerspawns[player:get_player_name()] = newspawn()
			spawnsave()
		end
	end)
end)

