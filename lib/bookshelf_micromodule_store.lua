-- bookshelf_micromodule_store.lua
--
-- A SEPARATE settings file for micro-module data, at
-- <datadir>/settings/bookshelf_micromodules.lua (LuaSettings format), kept apart
-- from the main bookshelf.lua. Why a second file:
--   * Isolation/hygiene -- a module's data (per-type prefs + caches) is no longer
--     interleaved with core bookshelf settings; the file can be inspected, reset
--     or removed on its own, and a misbehaving module can't bloat / clobber the
--     main settings.
--   * Perf -- writes flush this small file, not the 100KB+ bookshelf.lua.
--
-- Two ways data lands here:
--   * Transparently: bookshelf_settings_store routes any "micromodule_*" key
--     here (and relocates existing ones once), so the ~dozen modules already
--     using those keys keep working unchanged.
--   * The clean API: `lib/bookshelf_module_kit`.moduleStore(key) wraps this in a
--     per-module namespaced handle (the going-forward path for new modules).
--
-- Keys are stored verbatim (the "micromodule_<key>_<name>" shape), so both
-- entry points address the same keys.

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local SETTINGS_PATH = DataStorage:getSettingsDir() .. "/bookshelf_micromodules.lua"

local Store = {}
local _settings = nil

local function _open()
    if _settings then return _settings end
    _settings = LuaSettings:open(SETTINGS_PATH)
    return _settings
end

function Store.read(key, default)
    local v = _open():readSetting(key)
    if v == nil then return default end
    return v
end

function Store.save(key, value)
    local s = _open()
    s:saveSetting(key, value)
    s:flush()
end

-- In-memory write only (no flush); for the one-shot relocation that flushes
-- once at the end. Hot-path module caches should also use this + a lifecycle
-- flush if per-write flushing is too costly.
function Store.saveDeferred(key, value)
    _open():saveSetting(key, value)
end

function Store.delete(key)
    local s = _open()
    s:delSetting(key)
    s:flush()
end

function Store.flush()
    if _settings then _settings:flush() end
end

-- Path the file lives at -- exposed so a future "uninstall plugin" / "reset
-- modules" feature can find and remove it without re-deriving the convention.
function Store.path() return SETTINGS_PATH end

return Store
