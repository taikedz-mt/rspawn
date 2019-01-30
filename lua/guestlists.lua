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
        minetest.log("error", "[rspawn] Levvy : Tried to access undefined player")
        return false
    end

    local pname = player:get_player_name()
    local player_inv = minetest.get_inventory({type='player', name = pname})
    local total_count = 0

    if not player_inv then
        minetest.log("error", "[rspawn] Levvy : Could not access inventory for "..pname)
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
        minetest.log("error", "[rspawn] Levvy : Tried to access undefined player")
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

    local explicitly_banned = host_glist[guestname] == GUEST_BAN

    local explicitly_banned_from_town = town_lists[hostname] and
        town_lists[hostname][guestname] == GUEST_BAN

    local open_town = town_lists[hostname] and town_lists[hostname]["town status"] == "on"

    if explicitly_banned or explicitly_banned_from_town then
        return false
    elseif open_town then
        return true
    end
    return false
end

-- Operational functions (to be invoked by /command)

function rspawn.guestlists:addplayer(hostname, guestname)
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    if guestlist[guestname] ~= nil then
        if guestlist[guestname] == GUEST_BAN then
            minetest.chat_send_player(guestname, hostname.." let you back into their spawn.")
            minetest.log("action", "[rspawn] "..hostname.." lifted exile on "..guestname)
        end
        guestlist[guestname] = GUEST_ALLOW

    elseif rspawn:consume_levvy(minetest.get_player_by_name(hostname) ) then -- Automatically notifies host if they don't have enough
        guestlist[guestname] = GUEST_ALLOW
        minetest.chat_send_player(guestname, hostname.." added you to their spawn! You can now visit them with /spawn visit "..hostname)
        minetest.log("action", "[rspawn] "..hostname.." added "..guestname.." to their spawn")
    else
        return
    end
    
    minetest.chat_send_player(hostname, guestname.." is allowed to visit your spawn.")
    rspawn.playerspawns["guest lists"][hostname] = guestlist
    rspawn:spawnsave()
end

function rspawn.guestlists:exileplayer(hostname, guestname)
    if hostname == guestname then
        minetest.chat_send_player(hostname, "Cannot ban yourself!")
        return false
    end
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    if guestlist[guestname] == GUEST_ALLOW then
        guestlist[guestname] = GUEST_BAN
        rspawn.playerspawns["guest lists"][hostname] = guestlist

    else
        minetest.chat_send_player(hostname, guestname.." is not in accepted guests list for "..hostname)
        return false
    end

    minetest.chat_send_player(guestname, "You may no longer visit "..hostname)
    minetest.log("action", "rspawn - "..hostname.." exiles "..guestname)
    rspawn:spawnsave()
    return true
end

function rspawn.guestlists:kickplayer(hostname, guestname)
    if rspawn.guestlists:exileplayer(hostname, guestname) then
        minetest.chat_send_player(hostname, "Evicted "..guestname.." from your spawn")
        minetest.log("action", "rspawn - "..hostname.." evicts "..guestname)
    end
end

function rspawn.guestlists:listguests(hostname)
    local guests = ""
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    local global_hosts = rspawn.playerspawns["town lists"] or {}
    if global_hosts[hostname] then
        guests = ", You are an active town host."
    end

    -- Explicit guests
    for guestname,status in pairs(guestlist) do
        if status == GUEST_ALLOW then status = "" else status = " (exiled guest)" end

        guests = guests..", "..guestname..status
    end

    -- Town bans - always list so this can be maanged even when town is closed
    for guestname,status in pairs(global_hosts[hostname] or {}) do
        if guestname ~= "town status" then
            if status == GUEST_ALLOW then status = "" else status = " (banned from town)" end

            guests = guests..", "..guestname..status
        end
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
    if not (hostname and guestname) then return end

    local guest = minetest.get_player_by_name(guestname)
    local hostpos = rspawn.playerspawns[hostname]

    if not hostpos then
        minetest.log("error", "[rspawn] Missing spawn position data for "..hostname)
        minetest.chat_send_player(guestname, "Could not find spawn position for "..hostname)
    end

    if guest and canvisit(hostname, guestname) then
        minetest.log("action", "[rspawn] "..guestname.." visits "..hostname.." (/spawn visit)")
        guest:setpos(hostpos)
    else
        minetest.chat_send_player(guestname, "Could not visit "..hostname)
    end
end

local function act_on_behalf(hostname, callername)
    return hostname == callername or -- caller is the town owner, always allow
        ( -- caller can act on behalf of town owner
            rspawn.playerspawns["guest lists"][hostname] and
            rspawn.playerspawns["guest lists"][hostname][callername] == GUEST_ALLOW
        )
end

local function townban(callername, guestname, hostname)
    if not (callername and guestname) then return end

    hostname = hostname or callername

    if act_on_behalf(hostname, callername) then
        if not rspawn.playerspawns["town lists"][hostname] then
            minetest.chat_send_player(callername, "No such town "..hostname)
            return
        end

        rspawn.playerspawns["town lists"][hostname][guestname] = GUEST_BAN

        minetest.chat_send_player(callername, "Evicted "..guestname.." from "..hostname.."'s spawn")
        minetest.log("action", "[rspawn] - "..callername.." evicts "..guestname.." on behalf of "..hostname)
    else
        minetest.chat_send_player(callername, "You are not permitted to act on behalf of "..hostname)
    end
    rspawn:spawnsave()
end

local function townunban(callername, guestname, hostname)
    if not (callername and guestname) then return end

    hostname = hostname or callername
    if act_on_behalf(hostname, callername) then
        if not rspawn.playerspawns["town lists"][hostname] then
            minetest.chat_send_player(callername, "No such town "..hostname)
            return
        end

        rspawn.playerspawns["town lists"][hostname][guestname] = nil

        minetest.chat_send_player(callername, "Allowed "..guestname.." back to town "..hostname)
        minetest.log("action", "[rspawn] - "..callername.." lifts eviction on "..guestname.." on behalf of "..hostname)
    else
        minetest.chat_send_player(callername, "You are not permitted to act on behalf of "..hostname)
    end
    rspawn:spawnsave()
end

local function listtowns()
    local town_lists = rspawn.playerspawns["town lists"] or {}
    local open_towns = ""

    for townname,banlist in pairs(town_lists) do
        if banlist["town status"] == "on" then
            open_towns = open_towns..", "..townname
        end
    end

    if open_towns ~= "" then
        return open_towns:sub(3)
    end
end

function rspawn.guestlists:townset(hostname, params)
    if not hostname then return end

    params = params or ""
    params = params:split(" ")

    local mode = params[1]
    local guestname = params[2]
    local town_lists = rspawn.playerspawns["town lists"] or {}
    local town_banlist = town_lists[hostname] or {}

    if mode == "open" then
        town_banlist["town status"] = "on"
        minetest.chat_send_all(hostname.." is opens access to all!")
        minetest.log("action", "[rspawn] town: "..hostname.." sets their spawn to open")

    elseif mode == "close" then
        town_banlist["town status"] = "off"
        minetest.chat_send_all(hostname.." closes town access - only guests may directly visit.")
        minetest.log("action", "[rspawn] town: "..hostname.." sets their spawn to closed")

    elseif mode == "status" then
        minetest.chat_send_player(hostname, "Town mode is: "..town_banlist["town status"])
        return

    elseif mode == "ban" and guestname and guestname ~= hostname then
        townban(hostname, guestname, params[3])

    elseif mode == "unban" and guestname then
        townunban(hostname, guestname, params[3])

    elseif mode == nil or mode == "" then
        local open_towns = listtowns()
        if not open_towns then
            open_towns = "(none yet)"
        end
        minetest.chat_send_player(hostname, open_towns)

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

    for _x,guest in ipairs(minetest.get_connected_players()) do
        local guestname = guest:get_player_name()
        local playerprivs = minetest.get_player_privs(guestname)

        if not (playerprivs.basic_privs or playerprivs.server) then
            local guestpos = guest:getpos()

            for _y,player_list_name in ipairs({"guest lists", "town lists"}) do
                for hostname,host_guestlist in pairs(rspawn.playerspawns[player_list_name] or {}) do

                    if host_guestlist[guestname] == GUEST_BAN then
                        -- Check distance of guest from banned pos
                        local vdist = vector.distance(guestpos, rspawn.playerspawns[hostname])

                        -- Check distance of guest from their own pos
                        -- If their spawn is very close to one they are banned from,
                        -- and they are close to their own, kick should not occur
                        local sdist = vector.distance(guestpos, rspawn.playerspawns[guestname])

                        if vdist < exile_distance and sdist > exile_distance then
                            guest:setpos(rspawn.playerspawns[guestname])
                            minetest.chat_send_player(guestname, "You got too close to "..hostname.."'s turf.")
                            minetest.log("action", "[rspawn] Auto-kicked "..guestname.." for being too close to "..hostname.."'s spawn")

                        elseif vdist < exile_distance*1.5 and sdist > exile_distance then
                            minetest.chat_send_player(guestname, "You are getting too close to "..hostname.."'s turf.")
                        end
                    end
                end
            end
        end

    end
end)

-- Announce towns!

minetest.register_on_joinplayer(function(player)
    local open_towns = listtowns()
    if open_towns then
        minetest.chat_send_player(player:get_player_name(), "Currently open towns: "..open_towns..". Visit with '/spawn visit <townname>' !")
    end
end)
