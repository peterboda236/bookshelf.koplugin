-- bookshelf_stale_sweep.lua
-- One-shot scan of CoverBrowser's bookinfo_cache for rows whose on-disk
-- file no longer matches the cached (filesize, filemtime). Reasons a
-- mismatch shows up:
--   * Syncthing pushed a replacement EPUB after enricher rewrote it
--   * User overwrote a file on the laptop and re-synced
--   * Calibre re-exported a book at a new path-collision-prone name
-- BIM has NO automatic invalidation -- once a row is written, the cover
-- bytes + metadata it holds are frozen until something explicitly deletes
-- the row. This sweep is that "something" for the cross-device sync case.
--
-- Stale criterion: size mismatch OR mtime mismatch. Size catches enricher
-- rewrites that preserve mtime (see ebook-enricher epub_meta.write_meta,
-- which os.utime's mtime back to the original to keep Recently-Added
-- ordering stable). Mtime catches plain in-place edits the user does
-- through other tools.
--
-- For each stale row we run the SAME purge as the user-initiated Refresh
-- metadata path: BIM:deleteBookInfo (drops the persistent row) plus
-- ScaledCoverCache:drop (kicks the in-memory copy that would otherwise
-- shadow the freshly re-extracted bytes). The next shelf render of the
-- book finds getBookInfo() returning nil and the existing
-- _kickOffMissingMetaExtraction path takes over -- text-only for off-
-- screen books, full cover_specs for visible ones.
--
-- Cost on a 200-book library: one SQLite SELECT (~5ms) + 200 lfs.attributes
-- calls (~50ms total). Well under a second on a Kindle. The actual
-- re-extraction is throttled by the existing visible-first kickoff and
-- doesn't add to startup latency.

local logger      = require("logger")
local DataStorage = require("datastorage")
local lfs         = require("libs/libkoreader-lfs")

local _gettime
do
    local ok, s = pcall(require, "socket")
    _gettime = (ok and s and type(s.gettime) == "function")
        and function() return s.gettime() end
        or  os.clock
end

local StaleSweep = {}

-- Module-level "already ran this process" flag. Bookshelf:init fires
-- twice per KOReader session (once in FM, once in Reader); we only want
-- to sweep once. The flag survives both inits because the module table
-- is package.loaded'd across requires.
StaleSweep._ran = false

local function _openBimDb()
    local db_path = DataStorage:getSettingsDir() .. "/bookinfo_cache.sqlite3"
    if not lfs.attributes(db_path, "mode") then
        return nil   -- no cache yet (first run / CoverBrowser disabled)
    end
    local ok, SQ3 = pcall(require, "lua-ljsqlite3/init")
    if not ok then return nil end
    local ok2, conn = pcall(SQ3.open, db_path)
    if not ok2 then return nil end
    return conn
end

-- run(opts) -- opts.force=true to bypass the once-per-session guard.
-- Returns a small stats table for logging/tests:
--   { scanned=N, stale=N, missing=N }   (missing = row exists but file gone)
function StaleSweep:run(opts)
    opts = opts or {}
    if self._ran and not opts.force then
        return { scanned = 0, stale = 0, missing = 0, skipped = true }
    end
    self._ran = true

    local t0 = _gettime()
    local stats = { scanned = 0, stale = 0, missing = 0 }

    local ok_bim, BIM = pcall(require, "bookinfomanager")
    if not (ok_bim and BIM and BIM.deleteBookInfo) then
        logger.dbg("[bookshelf stale-sweep] BIM unavailable, skipping")
        return stats
    end

    local db = _openBimDb()
    if not db then
        logger.dbg("[bookshelf stale-sweep] no bookinfo_cache.sqlite3 yet")
        return stats
    end

    -- Collect everything first, then close the connection BEFORE we call
    -- back into BIM (which opens its OWN connection). SQLite on Kindle
    -- doesn't always tolerate two writers to the same WAL file at once,
    -- and we want BIM's row deletes to commit cleanly.
    local rows = {}
    local ok_select = pcall(function()
        for r in db:rows("SELECT directory, filename, filemtime, filesize FROM bookinfo WHERE in_progress = 0;") do
            rows[#rows + 1] = {
                directory = r[1],
                filename  = r[2],
                filemtime = tonumber(r[3]) or 0,
                filesize  = tonumber(r[4]) or 0,
            }
        end
    end)
    pcall(function() db:close() end)
    if not ok_select then
        logger.warn("[bookshelf stale-sweep] SELECT failed; skipping")
        return stats
    end

    local stale_paths = {}
    for _i, r in ipairs(rows) do
        stats.scanned = stats.scanned + 1
        local fp   = r.directory .. r.filename
        local attr = lfs.attributes(fp)
        if not attr then
            stats.missing = stats.missing + 1
            -- File gone. Leave the row -- next shelf render won't surface
            -- it (the path isn't in the visible book list) and a future
            -- pass could pick it up if the user wants. Aggressive cleanup
            -- here risks deleting rows for files on temporarily-unmounted
            -- removable media.
        elseif attr.mode == "file" then
            if attr.size ~= r.filesize or attr.modification ~= r.filemtime then
                stale_paths[#stale_paths + 1] = fp
            end
        end
    end

    if #stale_paths == 0 then
        logger.dbg(string.format(
            "[bookshelf stale-sweep] scanned=%d stale=0 missing=%d in %.0fms",
            stats.scanned, stats.missing, (_gettime() - t0) * 1000))
        return stats
    end

    -- Purge stale entries via the same two-layer drop that Refresh
    -- metadata performs (commit f804285). BIM:deleteBookInfo drops the
    -- persistent row; ScaledCoverCache:drop drops the in-memory scaled
    -- bb. Together they ensure the next render misses both caches and
    -- triggers the existing kickoff extraction.
    local ScaledCoverCache = require("lib/bookshelf_scaled_cover_cache")
    for _i, fp in ipairs(stale_paths) do
        pcall(function() BIM:deleteBookInfo(fp) end)
        pcall(function() ScaledCoverCache:drop(fp) end)
        stats.stale = stats.stale + 1
    end

    logger.info(string.format(
        "[bookshelf stale-sweep] purged %d stale (scanned=%d, missing=%d) in %.0fms",
        stats.stale, stats.scanned, stats.missing, (_gettime() - t0) * 1000))
    return stats
end

return StaleSweep
