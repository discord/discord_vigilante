# Overview

`DiscordSidekick` is a process that executes a Lua script to provide rich presence data for a target process.

The sidekick process will attach to the target process ID and execute the script at `scripts/<game_id>.lua`. The target process ID and `game_id` are specified on the command line:
`DiscordSidekick_x86.exe <pid> <game_id>`. (The `x86` in `DiscordSidekick_x86.exe` refers to the architecture of the target process -- the x86 executable cannot target 64-bit processes and vice versa.)

Any `game_id` can be used for testing (`1` is perfectly fine). For the Discord client to automatically launch a sidekick process in production, a script for the game ID from Discord's game database entry must be present at `scripts/<game_id>.lua`.

# Lua

## Standard Library
The basic (with the exception of `dofile`, `loadfile`, and `load`), `coroutine`, `table`, `string`, `math`, and `utf8`Lua standard libraries are available (notably absent are the `package`, `io`, and `os` libraries).

## Sidekick API

### `Architecture`

The `Architecture` global variable is set to either `x86` or `x64` depending on the architecture of the target process.

### `Read(address, length)`

Returns `length` bytes of data at `address` as a string (or nil on failure).

### `Find(pattern, [begin_address[, [end_address, [executable_only]]])`

Returns the address of the first occurence of `pattern` within the specified range (the entire process if unspecified), or `nil` on failure. If `exutable_only` is `true` (the default behavior), only executable pages will be searched.

`pattern` is a `string` with the `format` `11223344......AABBCC`, where `NN` is a hexadecimal byte and `..` represents a wildcard.

### `GetModuleInfo(name)`

Returns a (base address, size) tuple for the specified module `name`, or `nil` on failure.


## Sidekick Interface

### `get_presence()`

The game script must define a global function named `get_presence`. It should return `nil` if presence data is unavailable (for example, because a signature failed to resolve), or a table with the following optional fields:

* `state`
* `details`
* `largeImageKey`
* `largeImageText`
* `smallImageKey`
* `smallImageText`
* `partyId`
* `matchSecret`
* `joinSecret`
* `spectateSecret`


For information on these fields, see [Update Presence Payload Fields](https://discordapp.com/developers/docs/rich-presence/how-to#updating-presence-update-presence-payload-fields).

# Guidelines

* If your script targets a game that can run as either a 32-bit or 64-bit process, make sure it checks `Architecture`.
* If your script makes use of `GetModuleInfo` for a module besides the main executable, make sure it handles the case where the module has not been loaded yet.
* Try not to include absolute addresses or relative offsets in your script. Instead, make use of `Find`.
* If possible, cache the result of `Find` instead of calling it every time `get_presence` is called.
* If possible, implement a sanity check that prevents any work from being done in `get_presence` once it fails.

# Example

```lua
function read_dword(addr)
    local data = Read(addr, 4)
    if data == nil then
        return nil
    end

    local result = string.byte(data, 1);
    result |= string.byte(data, 2) << 8;
    result |= string.byte(data, 3) << 16;
    result |= string.byte(data, 4) << 24;

    return result;
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

local prev_client_addr = nil
local str_addr = nil

function get_presence()
    local client_addr, client_size = GetModuleInfo("client.dll")

    if client_addr ~= prev_client_addr then
        str_adder = nil
    end

    if client_addr == nil then
        return nil
    end

    local client_end_addr = client_addr + client_size

    if str_addr == nil
        local addr = Find("8D8F........8BD0680401", client_addr, client_end_addr)
        if addr == nil then
            return nil
        end

        str_addr = read_dword(addr + 2)
    end

    local name = read_string(str_addr, 256)

    return {
        state="Playing as " .. name,
        details="hello",
        largeImageKey="foo",
        largeImageText="foo",
        smallImageKey="bar",
        smallImageText="bar"
    }
end
```
