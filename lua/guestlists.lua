-- API holder object
rspawn.guestlists = {}

local kick_step = 0

local kick_period = tonumber(minetest.settings:get("rspawn.kick_period")) or 3
local exile_distance = tonumber(minetest.settings:get("rspawn.exile_distance")) or 64

local GUEST_BAN = 0
local GUEST_ALLOW = 1

-- Levvy helpers
-- FIXME Minetest API might actually be able to do this cross-stacks with a single call at inventory level.

local levvy_name = minetest.settings:get("rspawn.levvy_name") or "default:cobble"
local levvy_qtty = tonumber(minetest.settings:get("rspawn.levvy_qtty")) or 10
local levvy_nicename = "cobblestone"

minetest.after(0,function()
    if minetest.registered_items[levvy_name] then
        levvy_nicename = minetest.registered_nodes[levvy_name].description
    else
        minetest.debug("No such item "..levvy_name.." -- reverting to defaults.")
        levvy_name = "default:cobble"
        levvy_qtty = 99
    end
end)

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

-- Visitation rights check

local function canvisit(hostname, guestname)
    local host_glist = rspawn.playerspawns["guest lists"][hostname] or {}
    local town_lists = rspawn.playerspawns["town lists"] or {}

    return (
        -- Guest not explicitly banned
        (
            not host_glist[guestname] or
            host_glist[guestname] ~= GUEST_BAN
        )
        and
        -- Host is open town, and guest is not banned
        (
            town_lists[hostname] and
            town_lists[hostname]["town status"] == "on" and
            town_lists[hostname][guestname] ~= GUEST_BAN
        )
    )
end

-- Operational functions (to be invoked by /command)

function rspawn.guestlists:addplayer(hostname, guestname)
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    if guestlist[guestname] ~= nil then
        if guestlist[guestname] == GUEST_BAN then
            minetest.chat_send_player(guestname, hostname.." let you back into their spawn.")
        end
        guestlist[guestname] = GUEST_ALLOW

    elseif rspawn:consume_levvy(minetest.get_player_by_name(hostname) ) then -- Automatically notifies host if they don't have enough
        guestlist[guestname] = GUEST_ALLOW
        minetest.chat_send_player(guestname, hostname.." added you to their spawn! You can now visit them with /spawn visit "..hostname)
    else
        return
    end
    
    minetest.chat_send_player(hostname, guestname.." is allowed to visit your spawn.")
    rspawn.playerspawns["guest lists"][hostname] = guestlist
    rspawn:spawnsave()
end

function rspawn.guestlists:exileplayer(hostname, guestname, callername)
    if hostname == guestname then
        minetest.chat_send_player(hostname, "Cannot ban yourself!")
        return
    end
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    if guestlist[guestname] == GUEST_ALLOW then
        guestlist[guestname] = GUEST_BAN
        rspawn.playerspawns["guest lists"][hostname] = guestlist

    else
        minetest.chat_send_player(callername or hostname, guestname.." is not in accepted guests list for "..hostname)
        return
    end

    minetest.chat_send_player(guestname, hostname.." banishes you!")
    rspawn:spawnsave()
end

function rspawn.guestlists:kickplayer(callername, params)
    params = params:split(" ")
    local hostname = params[2]
    local target = params[1]

    -- Caller is an explicit non-exiled guest
    if rspawn.playerspawns[hostname] and rspawn.playerspawns[hostname][callername] == GUEST_ALLOW then
        rspawb.guestlists:exileplayer(hostname, guestname)
    end
end

function rspawn.guestlists:listguests(hostname)
    local guests = ""
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    local global_hosts = rspawn.playerspawns["town lists"] or {}
    if global_hosts[hostname] then
        guests = ", You are an active town host."
    end

    for guestname,status in pairs(guestlist) do
        if status == GUEST_ALLOW then status = "" else status = " (exiled)" end

        guests = guests..", "..guestname..status
    end

    if guests == "" then
        guests = ", No guests, not hosting a town."
    end

    minetest.chat_send_player(hostname, guests:sub(3))
end

function rspawn.guestlists:listhosts(guestname)
    local hosts = ""

    for hostname,hostguestlist in pairs(rspawn.playerspawns["guest lists"]) do
        for gname,status in pairs(hostguestlist) do
            if guestname == gname then
                if status == GUEST_ALLOWED then
                    hosts = hosts..", "..hostname
                end
            end
        end
    end

    local global_hostlist = rspawn.playerspawns["town lists"] or {}
    for hostname,host_banlist in pairs(global_hostlist) do
        if host_banlist["town status"] == "on" and
          host_banlist[guestname] ~= GUEST_BAN
          then
            hosts = hosts..", "..hostname.." (town)"
        end
    end

    if hosts == "" then
        hosts = ", (no visitable hosts)"
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

function rspawn.guestlists:townset(hostname, params)
    params = params or ""
    params = params:split(" ")

    local mode = params[1]
    local guestname = params[2]
    local town_lists = rspawn.playerspawns["town lists"] or {}
    local town_banlist = town_lists[hostname] or {}

    if mode == "open" then
        town_banlist["town status"] = "on"
        minetest.chat_send_all(hostname.." is opens access to all!")

    elseif mode == "close" then
        town_banlist["town status"] = "off"
        minetest.chat_send_all(hostname.." closes town access - only guests may directly visit.")

    elseif mode == "status" then
        minetest.chat_send_player(hostname, "Town mode is: "..town_banlist["town status"])
        return

    elseif mode == "ban" and guestname and guestname ~= hostname then
        town_banlist[guestname] = GUEST_BAN
        minetest.chat_send_all(guestname.." is exiled from "..hostname.."'s town.")

    elseif mode == "unban" and guestname then
        town_banlist[guestname] = nil
        minetest.chat_send_all(guestname.." is no longer exiled from  "..hostname.."'s town.")

    else
        minetest.chat_send_player(hostname, "Unknown parameterless town operation: "..tostring(mode) )
        return
    end

    town_lists[hostname] = town_banlist
    rspawn.playerspawns["town lists"] = town_lists

    rspawn:spawnsave()
end

-- Exile check
minetest.register_globalstep(function(dtime)
    if kick_step < kick_period then
        kick_step = kick_step + dtime
        return
    else
        kick_step = 0
    end

    for _,guest in ipairs(minetest.get_connected_players()) do
        local guestname = guest:get_player_name()
        local playerprivs = minetest.get_player_privs(guestname)

        if not (playerprivs.basic_privs or playerprivs.server) then
            local guestpos = guest:getpos()

            for _,player_list_name in ipairs({"guest lists", "town lists"}) do
                for hostname,host_guestlist in pairs(rspawn.playerspawns[player_list_name] or {}) do

                    if host_guestlist[guestname] == GUEST_BAN then
                        local vdist = vector.distance(guestpos, rspawn.playerspawns[hostname])

                        if vdist < exile_distance then
                            guest:setpos(rspawn.playerspawns[guestname])
                            minetest.chat_send_player(guestname, "You got too close to "..hostname.."'s turf.")
                            return

                        elseif vdist < exile_distance*1.5 then
                            minetest.chat_send_player(guestname, "You are getting too close to "..hostname.."'s turf.")
                            return
                        end
                    end
                end
            end
        end

    end
end)
