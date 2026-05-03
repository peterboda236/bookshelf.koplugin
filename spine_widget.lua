-- spine_widget.lua
-- One book's cover. Cover render path when book.cover_bb is present;
-- otherwise paper-tone fallback (Task 3.2 adds this).

local FrameContainer = require("ui/widget/container/framecontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local ImageWidget    = require("ui/widget/imagewidget")
local Geom           = require("ui/geometry")
local Size           = require("ui/size")
local InputContainer = require("ui/widget/container/inputcontainer")

local SpineWidget = InputContainer:extend{
    book      = nil,    -- Book record
    width     = nil,    -- pixels
    height    = nil,    -- pixels
    on_tap    = nil,    -- function(book) — opens reader
    on_hold   = nil,    -- function(book) — long-press menu
}

function SpineWidget:init()
    self.dimen = Geom:new{ w = self.width, h = self.height }
    if self.book and self.book.has_cover and self.book.cover_bb then
        self[1] = self:_renderCover()
    else
        self[1] = self:_renderFallback()
    end
    self.ges_events = {
        Tap  = { GestureRange = { ges = "tap",  range = self.dimen } },
        Hold = { GestureRange = { ges = "hold", range = self.dimen } },
    }
end

function SpineWidget:_renderCover()
    return FrameContainer:new{
        bordersize = Size.border.thin,
        padding    = 0,
        ImageWidget:new{
            image  = self.book.cover_bb,
            width  = self.width,
            height = self.height,
            scale_factor = 0,  -- fit (preserves aspect, no upscale)
        },
    }
end

function SpineWidget:_renderFallback()
    local TextBoxWidget = require("ui/widget/textboxwidget")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local Font = require("ui/font")
    local Blitbuffer = require("ffi/blitbuffer")
    local pad = Size.padding.small

    local title = TextBoxWidget:new{
        text = self.book and self.book.title or "?",
        face = Font:getFace("infofont", 12),
        width = self.width - pad * 2,
        alignment = "center",
        bold = true,
    }
    local rule = FrameContainer:new{
        bordersize = 0,
        background = Blitbuffer.COLOR_BLACK,
        Geom:new{ w = self.width / 4, h = Size.line.thin },
    }
    local author = TextBoxWidget:new{
        text = self.book and self.book.author or "",
        face = Font:getFace("infofont", 10),
        width = self.width - pad * 2,
        alignment = "center",
    }

    local stack = VerticalGroup:new{
        align = "center",
        title,
        rule,
        author,
    }

    -- Blitbuffer.gray(0.95): paper-tone (nearly white on greyscale e-ink,
    -- gives subtle paper feel). Falls back to COLOR_WHITE if gray() unavailable.
    local paper
    if type(Blitbuffer.gray) == "function" then
        paper = Blitbuffer.gray(0.95)
    else
        paper = Blitbuffer.COLOR_WHITE
    end

    return FrameContainer:new{
        bordersize    = Size.border.thin,
        padding_top    = pad * 2,
        padding_bottom = pad * 2,
        padding_left  = pad,
        padding_right = pad,
        background = paper,
        CenterContainer:new{
            dimen = Geom:new{ w = self.width, h = self.height },
            stack,
        },
    }
end

function SpineWidget:onTap()      if self.on_tap  then self.on_tap(self.book)  end; return true end
function SpineWidget:onHold()     if self.on_hold then self.on_hold(self.book) end; return true end

return SpineWidget
