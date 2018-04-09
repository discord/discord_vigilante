--luacheck: globals Read Find GetModuleInfo
function read_num(addr, bsize)
    local data = Read(addr, bsize)
    if data == nil then
        return nil
    end
    local result = 0
    for i = 1,bsize do
        result = result | string.byte(data, i) << (i-1)*8
    end
    return result;
end
function read_byte(addr)
    return read_num(addr, 1)
end
function read_word(addr)
    return read_num(addr, 2)
end
function read_dword(addr)
    return read_num(addr, 4)
end
function read_string(addr, max_size)
    local data = Read(addr, max_size)
    if data == nil then
        return nil
    end
    for i = 1, max_size do
        if data:byte(i) == 0 then
            return data:sub(1, i)
        end
    end
    return data
end
function calc_near_call_addr(call_loc)
    local offset = read_dword(call_loc + 1)
    if offset == nil then
        return nil
    end
    return call_loc + 5 + offset
end


local __SIGS = {
    PARTYINFO = "74..F680........0174..8B88........3B",
    WORLDID = "0FB7..026689..........0FB7..046689..........0FB6"
}

local __module = {
    ffxiv = {
        begin = nil,
        end_ = nil
    }
}

local __party = {
    addr = {
        asm = nil,
        arr = nil
    },
    sz = {
        PartySlot = nil
    },
    off = {
        SlotStatus = nil,
        CharacterName = nil,
        CharacterServerId = nil
    }
}

local __entity = {
    addr = {
        asm = nil,
        arr = nil
    },
    off = {
        WorldId = nil
    }
}


function get_world_id()
    if __entity.addr.asm == nil then
        __entity.addr.asm = Find(__SIGS.WORLDID, __module.ffxiv.begin, __module.ffxiv.end_)
        if __entity.addr.asm == nil then
            return nil
        end
        __entity.off.WorldId = read_dword(__entity.addr.asm + 0x12)        
    end
    
    -- The party sig contains the pointer to the entity array.
    if __entity.addr.arr == nil then
        get_party_ptr();
        if __entity.addr.arr == nil then
            return nil
        end
    end
    
    return read_byte(__entity.addr.arr + __entity.off.WorldId)
end

function get_party_ptr()
    if __party.addr.asm == nil then
        __party.addr.asm = Find(__SIGS.PARTYINFO, __module.ffxiv.begin, __module.ffxiv.end_)
        if __party.addr.asm == nil then
            return nil
        end
        
        local partyslot_size_call_addr = calc_near_call_addr(__party.addr.asm - 0x07)
        if partyslot_size_call_addr > __module.ffxiv.end_ or partyslot_size_call_addr < __module.ffxiv.begin then
            return nil
        end
        
        __party.sz.PartySlot = read_dword(partyslot_size_call_addr + 0x17)
        __party.off.SlotStatus = read_dword(__party.addr.asm + 0x04)
        __party.off.CharacterName = read_dword(__party.addr.asm + 0x32)
        __party.off.CharacterServerId = read_dword(__party.addr.asm + 0x2D)
        __party.addr.arr = read_dword(__party.addr.asm - 0x0B)
        
        __entity.addr.arr = read_dword(__party.addr.asm - 0x21)
        __entity.addr.arr = read_dword(__entity.addr.arr)
    end
    return __party.addr.arr
end

function get_party_members(party_arr_addr)
    local party = {}
    local count = 0;
    for i=1,7 do
        local addr = party_arr_addr + (__party.sz.PartySlot*i)
        if read_byte(addr + __party.off.SlotStatus) == 5 then
            party[count+1] = {}
            party[count+1].name = read_string(addr + __party.off.CharacterName, 32)
            count = count + 1
        end
    end
    return party
end

function get_player_name(party_arr_addr)
    local name = read_string(party_arr_addr + __party.off.CharacterName, 32)
    if name ~= nil and #name > 1 then
        return name
    end
    -- Fallback to reading the entity array if no party has been formed yet
    if __entity.addr.arr == nil then
        return nil
    end
    return read_string(__entity.addr.arr + 0x30, 32)
end

function get_presence()

    local ffxiv_begin, ffxiv_size = GetModuleInfo("ffxiv.exe")

    if ffxiv_begin == nil then
        return nil
    end

    -- Highly unlikely unless something rebases the main module
    if ffxiv_begin ~= __module.ffxiv.begin then
        __module.ffxiv.begin = ffxiv_begin
        __module.ffxiv.end_ = ffxiv_begin + ffxiv_size
    end
    
    local party_arr_addr = get_party_ptr()
    
    if party_arr_addr == nil then
        return nil
    end
    
    local name = get_player_name(party_arr_addr)
    if name == nil then
        return nil
    end
    
    local worldid = get_world_id()
    
    return {
        state="Playing as " .. name,
        details="World ID: " .. worldid,
        largeImageKey="foo",
        largeImageText="foo",
        smallImageKey="bar",
        smallImageText="bar"
    }
end