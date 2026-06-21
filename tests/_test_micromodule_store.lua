-- Pure-Lua tests for the micro-module settings store + the routing/relocation
-- that bookshelf_settings_store does for "micromodule_*" keys: such keys read
-- and write the SEPARATE bookshelf_micromodules.lua file, and any that already
-- lived in bookshelf.lua are relocated once on first access.
package.path = "./?.lua;./?/init.lua;" .. package.path

-- Path-aware LuaSettings stub: one in-memory table per file path, exposing
-- `.data` so the relocation pass can enumerate keys (as real LuaSettings does).
local files = {}
local function fileData(path)
    files[path] = files[path] or {}
    return files[path]
end
package.loaded["luasettings"] = {
    open = function(_self, path)
        local data = fileData(path)
        local obj = { data = data }
        function obj:readSetting(k) return data[k] end
        function obj:saveSetting(k, v) data[k] = v end
        function obj:delSetting(k) data[k] = nil end
        function obj:flush() end
        function obj:isTrue(k) return data[k] == true end
        function obj:nilOrTrue(k) local v = data[k]; return v == nil or v == true end
        return obj
    end,
}
package.loaded["datastorage"] = { getSettingsDir = function() return "/x" end }
package.loaded["logger"] = { dbg = function() end, info = function() end,
                             warn = function() end, err = function() end }
package.loaded["libs/libkoreader-lfs"] = {
    attributes = function(_p, a) if a == "mode" then return nil end end,
}
_G.G_reader_settings = { readSetting = function() return nil end,
                         delSetting = function() end }

local MAIN = "/x/bookshelf.lua"
local MM   = "/x/bookshelf_micromodules.lua"

-- Seed: legacy migration already done (skip it), relocation NOT yet done, with
-- one micromodule_* key and one ordinary key already in the main file.
fileData(MAIN).migrated            = true
fileData(MAIN).micromodule_foo_bar = "hello"
fileData(MAIN).active_chip         = "recent"

local Store = dofile("lib/bookshelf_settings_store.lua")
local t = dofile("tests/_helpers.lua").runner()

t.test("first access relocates pre-existing micromodule_* keys to the MM file", function()
    -- Reading any key opens the store and runs the one-shot relocation.
    local v = Store.read("micromodule_foo_bar")
    assert(v == "hello", "routed read must return the relocated value")
    assert(fileData(MM).micromodule_foo_bar == "hello",
        "the key must now live in the MM file")
    assert(fileData(MAIN).micromodule_foo_bar == nil,
        "the key must be gone from the main file")
    assert(fileData(MAIN).micromodules_relocated == true,
        "relocation must set its one-shot flag")
    assert(fileData(MAIN).active_chip == "recent",
        "ordinary keys must be untouched by relocation")
end)

t.test("micromodule_* writes go to the MM file, not the main file", function()
    Store.save("micromodule_clock_format", "24")
    assert(fileData(MM).micromodule_clock_format == "24",
        "micromodule write must land in the MM file")
    assert(fileData(MAIN).micromodule_clock_format == nil,
        "micromodule write must NOT touch the main file")
end)

t.test("ordinary keys still read/write the main file", function()
    Store.save("font_scale", 120)
    assert(fileData(MAIN).font_scale == 120, "ordinary write stays in the main file")
    assert(fileData(MM).font_scale == nil, "ordinary write must not leak to MM file")
    assert(Store.read("font_scale") == 120)
end)

t.test("delete + nilOrTrue/isTrue route for micromodule_* keys", function()
    Store.save("micromodule_x_flag", true)
    assert(Store.isTrue("micromodule_x_flag") == true)
    assert(Store.nilOrTrue("micromodule_x_missing") == true) -- absent => true
    Store.delete("micromodule_x_flag")
    assert(fileData(MM).micromodule_x_flag == nil, "delete must clear it from the MM file")
end)

t.done()
