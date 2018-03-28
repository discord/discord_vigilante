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

local PARTYINFO_SIG = "74..F680........0174..8B88........3B"

local g_ffxiv_begin_addr = nil
local g_ffxiv_end_addr = nil

local g_party_asm_addr = nil
local g_party_arr_addr = nil
local g_party_PartySlot_size = nil
local g_party_SlotStatus_off = nil
local g_party_CharacterName_off = nil
local g_party_CharacterServerId_off = nil
local g_entity_arr_addr = nil

function get_party_ptr()
    if g_party_asm_addr == nil then
        
        g_party_asm_addr = Find(PARTYINFO_SIG, g_ffxiv_begin_addr, g_ffxiv_end_addr)
        if g_party_asm_addr == nil then
            return nil
        end
        
        local partyslot_size_call_addr = calc_near_call_addr(g_party_asm_addr - 0x07)
        if partyslot_size_call_addr > g_ffxiv_end_addr or partyslot_size_call_addr < g_ffxiv_begin_addr then
            return nil
        end
        
        g_party_PartySlot_size = read_dword(partyslot_size_call_addr + 0x17)
        g_party_SlotStatus_off = read_dword(g_party_asm_addr + 0x04)
        g_party_CharacterName_off = read_dword(g_party_asm_addr + 0x32)
        g_party_CharacterServerId_off = read_dword(g_party_asm_addr + 0x2D)
        g_party_arr_addr = read_dword(g_party_asm_addr - 0x0B)
        
        g_entity_arr_addr = read_dword(g_party_asm_addr - 0x25)
        g_entity_arr_addr = read_dword(g_entity_arr_addr)
    end
    return g_party_arr_addr
end

function get_party_members(party_arr_addr)
    local party = {}
    local count = 0;
    for i=1,7 do
        local addr = party_arr_addr + (g_party_PartySlot_size*i)
        if read_byte(addr + g_party_SlotStatus_off) == 5 then
            party[count+1] = {}
            party[count+1].name = read_string(addr + g_party_CharacterName_off, 32)
            count = count + 1
        end
    end
    return party
end

function get_player_name(party_arr_addr)
    local name = read_string(party_arr_addr + g_party_CharacterName_off, 32)
    if name ~= "" then
        return name
    end
    if g_entity_arr_addr == nil then
        return nil
    end
    return read_string(g_entity_arr_addr + 0x30, 32)
end

function get_presence()

    local ffxiv_begin_addr, ffxiv_size = GetModuleInfo("ffxiv.exe")

    if ffxiv_begin_addr == nil then
        return nil
    end

    -- Highly unlikely unless something rebases the main module
    if ffxiv_begin_addr ~= g_ffxiv_begin_addr then
        g_ffxiv_begin_addr = ffxiv_begin_addr
        g_ffxiv_end_addr = ffxiv_begin_addr + ffxiv_size
    end

    local party_arr_addr = get_party_ptr()
    if party_arr_addr == nil then
        return nil
    end
    
    local name = get_player_name(party_arr_addr)
    if name == nil then
        return nil
    end
    
    local party = get_party_members(party_arr_addr)
    
    return {
        state="Playing as " .. name,
        details="Party Members: " .. party[1].name,
        largeImageKey="foo",
        largeImageText="foo",
        smallImageKey="bar",
        smallImageText="bar"
    }
end