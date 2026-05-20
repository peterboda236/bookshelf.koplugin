-- bookshelf_folder_stack.lua
-- Renders a folder slot: the first book inside the folder fills the slot
-- like a regular spine; a compact cardboard "folder card" (tab + body)
-- sits on top of the book's bottom portion, label centred on the body.
-- The book's top peeks above the folder body and to the right of the
-- tab as visual evidence of the folder's contents.
--
-- Composition: see folder_card.lua for the cardboard primitive. This
-- module just adds the SpineWidget for the first book and the tap/hold
-- input handling.

local InputContainer = require("ui/widget/container/inputcontainer")
local OverlapGroup   = require("ui/widget/overlapgroup")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local SpineWidget    = require("lib/bookshelf_spine_widget")
local FolderCard     = require("lib/bookshelf_folder_card")
local CountBadge     = require("lib/bookshelf_count_badge")

local FolderStack = InputContainer:extend{
    folder      = nil,    -- { path, label, first_book }
    width       = nil,
    height      = nil,
    on_tap      = nil,
    on_hold     = nil,
    is_selected      = false,
    is_bulk_selected = false,
    -- book_count: total recursive books under this folder. nil
    -- suppresses the badge entirely. shelf_row supplies it (or not)
    -- based on the stack_count_badge_mode setting.
    book_count       = nil,
    -- selected_count: K when 0 < K < book_count → renders "K/book_count"
    -- instead of "×book_count" (Venn-diagram partial-selection state).
    selected_count   = nil,
    -- finished_count: out-of-selection format. Renders "F/N" when set
    -- and selected_count is nil. Driven by
    -- stack_count_badge_format = "finished_total".
    finished_count   = nil,
    -- finished_total: unfiltered total for the F/N denominator. Falls
    -- back to book_count when omitted. Separate field so F/N stays
    -- stack-wide even when book_count reflects a filtered count.
    finished_total   = nil,
}

function FolderStack:init()
    self.dimen = Geom:new{ w = self.width, h = self.height }

    -- Book layer: full-slot SpineWidget. Its internal drop shadow paints
    -- the slot's right+bottom L-strip; because the folder card shares
    -- the book card's right and bottom edges, that shadow doubles as
    -- the folder's drop shadow (no separate folder-shaped shadow layer).
    local book_widget
    if self.folder and self.folder.first_book then
        book_widget = SpineWidget:new{
            book             = self.folder.first_book,
            width            = self.width,
            height           = self.height,
            cover_fill       = true,
            is_selected      = self.is_selected,
            is_bulk_selected = self.is_bulk_selected,
        }
    else
        -- Empty folder: SpineWidget's fallback path with the folder's
        -- label as the title so the "?" placeholder reads correctly.
        book_widget = SpineWidget:new{
            book             = { title = self.folder and self.folder.label or "" },
            width            = self.width,
            height           = self.height,
            is_selected      = self.is_selected,
            is_bulk_selected = self.is_bulk_selected,
        }
    end

    local folder_widget, label_widget = FolderCard.build{
        width  = self.width,
        height = self.height,
        label  = self.folder and self.folder.label or "",
    }

    local children = {
        book_widget,           -- 0: book card + book's own drop shadow
        folder_widget,         -- 1: cardboard front (covers book bottom)
        label_widget,          -- 2: folder name on body
    }
    -- Count badge: same anchor as SeriesStack so a row mixing folders
    -- and group stacks reads with a consistent visual rhythm.
    if self.book_count and self.book_count > 0 then
        local badge = CountBadge.render(self.book_count, self.selected_count, self.finished_count, self.finished_total)
        if badge then
            local badge_w = badge:getSize().w
            local cover_right_x = self.width - FolderCard.SHADOW_OFFSET
            local badge_x = math.max(0, math.min(self.width - badge_w,
                                                 cover_right_x - math.floor(badge_w / 2)))
            badge.overlap_offset = { badge_x, -FolderCard.SHADOW_OFFSET }
            children[#children + 1] = badge
        end
    end
    children.dimen = self.dimen
    self[1] = OverlapGroup:new(children)
    self.ges_events = {
        Tap  = { GestureRange:new{ ges = "tap",  range = self.dimen } },
        Hold = { GestureRange:new{ ges = "hold", range = self.dimen } },
    }
end

function FolderStack:onTap()
    if self.on_tap then self.on_tap(self.folder) end
    return true
end
function FolderStack:onHold()
    if self.on_hold then self.on_hold(self.folder) end
    return true
end

return FolderStack
