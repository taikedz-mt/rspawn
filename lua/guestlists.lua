rspawn.guestlists = {}

-- invitations[guest] = host
rspawn.invitations = {}

local invite_charge = {}

levvy_name = minetest.settings:get("rspawn.levvy_name") or "default:cobble"
levvy_qtty = tonumber(minetest.settings:get("rspawn.levvy_qtty")) or 10
levvy_nicename = "cobblestone"

minetest.after(0,function()
    if minetest.registered_items[levvy_name] then
        levvy_nicename = minetest.registered_nodes[levvy_name].description
    else
        minetest.debug("No such item "..levvy_name.." -- reverting to defaults.")
        levvy_name = "default:cobble"
        levvy_qtty = 99
    end
end)

local function canvisit(hostname, guestname)
    minetest.debug(dump(rspawn.playerspawns["guest lists"]))

    local glist = rspawn.playerspawns["guest lists"][hostname] or {}
    return glist[guestname] == 1
end

local function find_levvy(player)
    -- return itemstack index, and stack itself, with qtty removed
    -- or none if not found/not enough found
    local i

    if not player then
        minetest.log("action", "Tried to access undefined player")
        return false
    end

    local pname = player:get_player_name()
    local player_inv = minetest.get_inventory({type='player', name = pname})
    local total_count = 0

    if not player_inv then
        minetest.log("action", "Could not access inventory for "..pname)
        return false
    end

    for i = 1,32 do
        local itemstack = player_inv:get_stack('main', i)
        local itemname = itemstack:get_name()
        if itemname == levvy_name then
            if itemstack:get_count() >= levvy_qtty then
                return true
            else
                total_count = total_count + itemstack:get_count()

                if total_count >= (levvy_qtty) then
                    return true
                end
            end
        end
    end

    minetest.chat_send_player(pname, "You do not have enough "..levvy_nicename.." to pay the spawn levvy for your invitation.")
    return false
end

function rspawn:consume_levvy(player)
    if not player then
        minetest.log("action", "Tried to access undefined player")
        return false
    end

    local i
    local pname = player:get_player_name()
    local player_inv = minetest.get_inventory({type='player', name = pname})
    local total_count = 0

    -- TODO combine find_levvy and consume_levvy so that we're
    --    not scouring the inventory twice...
    if find_levvy(player) then
        for i = 1,32 do
            local itemstack = player_inv:get_stack('main', i)
            local itemname = itemstack:get_name()
            if itemname == levvy_name then
                if itemstack:get_count() >= levvy_qtty then
                    itemstack:take_item(levvy_qtty)
                    player_inv:set_stack('main', i, itemstack)
                    return true
                else
                    total_count = total_count + itemstack:get_count()
                    itemstack:clear()
                    player_inv:set_stack('main', i, itemstack)

                    if total_count >= (levvy_qtty) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function rspawn.guestlists:addplayer(hostname, guestname)
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    if guestlist[guestname] ~= nil then
        if guestlist[guestname] == 0 then
            minetest.chat_send_player(guestname, hostname.." let you back into their spawn.")
        end
        guestlist[guestname] = 1

    elseif rspawn:consume_levvy(minetest.get_player_by_name(hostname) ) then -- Automatically notifies host if they don't have enough
        guestlist[guestname] = 1
        minetest.chat_send_player(guestname, hostname.." added you to their spawn! You can now visit them with /spawn visit "..hostname)
    else
        return
    end
    
    minetest.chat_send_player(hostname, guestname.." is allowed to visit your spawn.")
    rspawn.playerspawns["guest lists"][hostname] = guestlist
    rspawn:spawnsave()
end

function rspawn.guestlists:exileplayer(hostname, guestname)
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    if guestlist[guestname] == 1 then
        guestlist[guestname] = 0
        rspawn.playerspawns["guest lists"][hostname] = guestlist

    else
        minetest.chat_send_player(hostname, guestname.." is not in your accepted guests list.")
        return
    end

    minetest.chat_send_player(guestname, hostname.." banishes you!")
    rspawn.guestlists:kick(hostname, guestname)
    rspawn:spawnsave()
end

function rspawn.guestlists:kick(hostname, guestname)
    local guest = minetest.get_player_by_name(guestname)
    local guestpos = guest:getpos()
    local hostspawnpos = rspawn.playerspawns[hostname]
    local guestspawnpos = rspawn.playerspawns[guestname]

    if vector.distance(guestpos, hostspawnpos) < 32 then
        guest:setpos(guestspawnpos)
    end
end

function rspawn.guestlists:listguests(hostname)
    local guests = ""
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    for guestname,status in pairs(guestlist) do
        if status == 1 then status = "" else status = " (exiled)" end

        guests = guests..", "..guestname..status
    end

    minetest.chat_send_player(hostname, guests:sub(3))
end

function rspawn.guestlists:listhosts(guestname)
    local hosts = ""

    for hostname,hostguestlist in pairs(rspawn.playerspawns["guest lists"]) do
        for gname,status in pairs(hostguestlist) do
            if guestname == gname then
                if status == 1 then status = "" else status = " (exiled)" end

                hosts = hosts..", "..hostname..status
            end
        end
    end

    minetest.chat_send_player(guestname, hosts:sub(3))
end

function rspawn.guestlists:visitplayer(hostname, guestname)
    local guest = minetest.get_player_by_name(guestname)
    local hostpos = rspawn.playerspawns[hostname]

    if not hostpos then
        minetest.log("error", "[rspawn] Missing spawn position data for "..hostname)
        minetest.chat_send_player(guestname, "Could not find spawn position for "..hostname)
    end

    if guest and canvisit(hostname, guestname) then
        guest:setpos(hostpos)
    else
        minetest.chat_send_player(guestname, "Could not visit "..hostname)
    end
end
