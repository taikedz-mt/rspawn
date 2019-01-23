rspawn.invites = {}

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

local function get_players(p1name, p2name)
    -- Check both players are online.
    -- It is easier to implement agains online players than to manage offline interactions
    local err, p1, p2
    local errmsg_generic = " is not online."

    if not p1name then
        minetest.log("error", "Missing p1name")
        return nil,nil,"Internal error."

    elseif not p2name then
        minetest.log("error", "Missing p2name")
        return nil,nil,"Internal error."
    end

    p1 = minetest.get_player_by_name(p1name)
    p2 = minetest.get_player_by_name(p2name)

    if not p1 then err = p1name..errmsg_generic end
    if not p2 then err = p2name..errmsg_generic end

    return p1,p2,err
end

function rspawn.invites:invite_player_fromto(hostname, guestname)
    local host,guest = get_players(hostname, guestname)

    if not (host and guest) then
        minetest.chat_send_player(hostname, err or "player not online")
        return
    end

    if not rspawn.invitations[guestname] then
        rspawn.invitations[guestname] = hostname
    else
        minetest.chat_send_player(hostname, guestname.." already has a pending invitation, and cannot be invited.")
        return
    end

    local hostspawn_s = minetest.pos_to_string(rspawn.playerspawns[hostname])

    minetest.chat_send_player(guestname, hostname.." invited you to join their spawn point.\nIf you accept, your spawn point will be set to "..hostspawn_s.." and you will be taken there IMMEDIATELY.\nRun '/spawn accept' to accept, '/spawn decline' to decline and clear the invite.")

    minetest.chat_send_player(hostname,
        "You have invited "..guestname.." to join your spawn.\nIf they accept, you will be charged \n\n    "..levvy_qtty.." "..levvy_nicename.." \n\nwhich will be taken from your inventory."
    )
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

    minetest.chat_send_player(pname, "You do not have enough "..levvy_nicename.." to pay the spawn levvy for your invitaiton.")
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

function rspawn.invites:addplayer(hostname, guestname)
    local guestlist = rspawn.guestlists[hostname] or {}

    if guestlist[guestname] ~= nil then
        minetest.chat_send_player(hostname, guestname.." is already in your guest list.")

    elseif rspawn:consume_levvy(minetest.get_player_by_name(hostname) ) then -- Automatically notifies host if they don't have enough
        guestlist[guestname] = 1
        rspawn.questlists[hostname] = guestlist

        minetest.chat_send_player(guestname, hostname.." added you to their spawn! You can now visit them with /spawn visit "..hostname)
    end
end

function rspawn.invites:exileplayer(hostname, guestname)
    local guestlist = rspawn.guestlists[hostname] or {}

    if guestlist[guestname] == 1 then
        guestlist[guestname] = 0
        rspawn.questlists[hostname] = guestlist

        minetest.chat_send_player(guestname, hostname.." has exiled you!")
    else
        minetest.chat_send_player(hostname, guestname.." is not in your accepted guests list.")
    end
end

function rspawn.invites:liftexileplayer(hostname, guestname)
    local guestlist = rspawn.guestlists[hostname] or {}

    if guestlist[guestname] == 0 then
        guestlist[guestname] = 1
        rspawn.questlists[hostname] = guestlist

        rspawn.invites:kick(hostname, guestname)

        minetest.chat_send_player(guestname, hostname.." has exiled you!")
    else
        minetest.chat_send_player(hostname, guestname.." is not in your exiled guests list.")
    end
end

function rspawn.invites:kick(hostname, guestname)
    local guest = minetest.get_player_by_name(guestname)
    local guestpos = guest:getpos()
    local hostspawnpos = rspawn.playerspawns[hostname]
    local guestspawnpos = rspawn.playerspawns[guestname]

    if vector.distance(guestpos, hostspawnpos) then
        guest:setpos(guestspawnpos)
    end
end

function rspawn.invites:listguests(hostname)
    local guests = ""
    local guestlist = rspawn.guestlists[hostname] or {}

    for guestname,status in pairs(guestlist) do
        if status == 1 then status = "" else status = " (exiled)"

        guests = ", "..guestname..status
    end

    minetest.chat_send_player(hostname, guests)
end

function rspawn.invites:listhosts(guestname)
    local hosts = ""

    for _,hostname in ipairs(rspawn.guestlists) do
        for gname,status in pairs(rspawn.guestlists[hostname]) do
            if guestname == gname then
                if status == 1 then status = "" else status = " (exiled)"

                hosts = ", "..hostname..status
            end
        end
    end

    minetest.chat_send_player(guestname, hosts)
end

function rspawn.invites:accept(guestname)
    local hostname = rspawn.invitations[guestname]

    if not hostname then
        minetest.chat_send_player(guestname, "No invitation to accept.")
        return
    end

    local host,guest = get_players(hostname, guestname)

    if not (host and guest) then
        minetest.chat_send_player(guestname, err or "player not online")
        return
    end

    if rspawn:consume_levvy(minetest.get_player_by_name(hostname) ) then -- Systematically notifies host if they don't have enough
        local hostspawn = rspawn.playerspawns[hostname]
        rspawn:set_player_spawn(guestname, hostspawn) -- sets new spawn position, saves, teleports player
        local success_message = " has accepted the spawn invitation from "
        minetest.chat_send_player(guestname, guestname..success_message..hostname)
        minetest.chat_send_player(hostname, guestname..success_message..hostname)

        minetest.chat_send_player(guestname, "You can return to your original spawn using '/spawn original' for \n\n    "..levvy_qtty.." "..levvy_nicename.." \n\nwhich will be taken from your inventory.")

    else -- Host was notified, now notify guest
        minetest.chat_send_player(guestname, hostname.." was unable to pay the levvy. Invitation could not be accepted.")
    end
end


function rspawn.invites:decline(guestname)
    local hostname = rspawn.invitations[guestname]

    if hostname then
        rspawn.invitations[guestname] = nil
        -- Player not online, message simply ignored.
        minetest.chat_send_player(guestname, "Declined invitation to join "..hostname.."'s spawn for now.")
        minetest.chat_send_player(hostname, guestname.." declined to join your spawn point for now.")
    else
        minetest.chat_send_player(guestname, "No invitation to decline.")
    end
end

function rspawn.invites:show_invite_for(guestname)
    local hostname = rspawn.invitations[guestname]

    if hostname then
        minetest.chat_send_player(guestname, "You have been invited to join "..hostname.." at "..minetest.pos_to_string(rspawn.playerspawns[hostname]))
    else
        minetest.chat_send_player(guestname, "No pending invitation.")
    end
end
