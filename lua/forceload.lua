local forceloading_happening = false


local function forceload_operate(pos1, pos2, handler, transient)
    local i,j,k

    for i=pos1.x,pos2.x,16 do
        for j=pos1.y,pos2.y,16 do
            for k=pos1.z,pos2.z,16 do
                handler({x=i,y=j,z=k}, transient)
            end
        end
    end
end

function rspawn:forceload_blocks_in(pos1, pos2)
    if forceloading_happening then
        rspawn:debug("Forceload operation already underway - abort")
        return false
    end

    rspawn:debug("Forceloading blocks -----------¬", {pos1=minetest.pos_to_string(pos1),pos2=minetest.pos_to_string(pos2)})
    forceloading_happening = true
    minetest.emerge_area(pos1, pos2)
    forceload_operate(pos1, pos2, minetest.forceload_block, true)

    return true
end

function rspawn:forceload_free_blocks_in(pos1, pos2)
    rspawn:debug("Freeing forceloaded blocks ____/", {pos1=minetest.pos_to_string(pos1),pos2=minetest.pos_to_string(pos2)})
    -- free both cases - take no chances
    forceload_operate(pos1, pos2, minetest.forceload_free_block) -- free if persistent
    forceload_operate(pos1, pos2, minetest.forceload_free_block, true) -- free if transient
    forceloading_happening = false
end

