local spawnsfile = minetest.get_worldpath().."/dynamicspawns.lua.ser"

--[[ Reconcile functions

reconcile_original_spawns : convert from base implementation to invites with original spawns

reconcile_guestlist_spawns : convert from "original spawns" implementation to "guest lists"

--]]

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

local function reconcile_guest(guestname, guestspawn)
    for hostname,hostspawn in pairs(rspawn.playerspawns) do
        if hostname ~= "guest lists" and hostname ~= guestname and hostspawn == guestspawn then
            local hostlist = rspawn.playerspawns["guest lists"][hostname] or {}
            hostlist[guestname] = 1
            rspawn.playerspawns["guest lists"][hostname] = hostlist
        end
    end
end

local function reconcile_guestlist_spawns()
    if not rspawn.playerspawns["guest lists"] then rspawn.playerspawns["guest lists"] = {} end

    for guestname,spawnpos in pairs(rspawn.playerspawns) do
        reconcile_guest(guestname, spawnpos)

        if rspawn.playerspawns["original spawns"][guestname] then
            rspawn.playerspawns[guestname] = rspawn.playerspawns["original spawns"][guestname]
            rspawn.playerspawns["original spawns"][guestname] = nil
        else
            minetest.debug("Could not return "..guestname)
        end
    end

    if #rspawn.playerspawns["original spawns"] == 0 then
        rspawn.playerspawns["original spawns"] = nil
    else
        minetest.log("error", "Failed to reconcile all spawns")
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
    reconcile_guestlist_spawns()

    minetest.debug("Loaded rspawn data with "..tostring(#pregens).." pregen nodes")
end

