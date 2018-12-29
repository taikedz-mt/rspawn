local debug_on = minetest.settings:get_bool("rspawn.debug")

local function debug(message, data)
    if not debug_on then
        return
    end

    local debug_data = ""

    if data ~= nil then
        debug_data = " :: "..dump(data)
    end
    local debug_string = "rspawn : "..message..debug_data

    minetest.debug(debug_string)
end

return debug
