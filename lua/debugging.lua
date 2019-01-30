function rspawn:d(stuff)
    -- Quick debugging
    minetest.debug(dump(stuff))
end

function rspawn:debug(message, data)
    -- Debugging from setting
    if not rspawn.debug_on then
        return
    end

    local debug_data = ""

    if data ~= nil then
        debug_data = " :: "..dump(data)
    end
    local debug_string = "[rspawn] DEBUG : "..message..debug_data

    minetest.debug(debug_string)
end
