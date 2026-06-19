--[[
Persistent Bookshelf launcher button for the reader view.

Registered with ReaderView via view:registerViewModule (the Bookends overlay
mechanism), so its paintTo runs as part of every ReaderView paint pass -- drawn
INTO the reader frame, surviving page turns / refreshes rather than floating on
the window stack where an e-ink refresh would ghost it. main.lua registers a
touch zone over the button that opens the start menu.

Geometry is replicated from the bookshelf footer's start-menu button
(_buildStartMenuIcon + _wrapAsFooterButton + _buildFooterRow) so it's identical:
the same hamburger bars, centred in the same side strip, in the same bottom
footer band, on the side the start_menu_position setting picks. No background or
border -- the footer button has none either (those appear only on d-pad focus).
]]
local Blitbuffer = require("ffi/blitbuffer")
local Device     = require("device")
local Geom       = require("ui/geometry")
local Size       = require("ui/size")
local Widget     = require("ui/widget/widget")
local Screen     = Device.screen

local ReaderButtons = Widget:extend{
    side = "left",  -- "left" | "right" (from start_menu_position)
}

-- Footer geometry, matching bookshelf_widget's FOOTER_* constants and
-- _buildFooterRow's side-strip maths, so the launcher lines up with where the
-- home-screen hamburger sits.
local function consts()
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local art      = Screen:scaleBySize(32)                              -- art box
    local bar_t    = math.max(1, math.floor(Screen:scaleBySize(32) / 14)) -- FOOTER_STROKE_W
    local hit      = Screen:scaleBySize(12)                               -- FOOTER_HIT_EXTENSION
    local footer_h = Screen:scaleBySize(32) + 2 * Screen:scaleBySize(4)   -- FOOTER_H
    local pad      = math.min(math.floor(Size.padding.fullscreen * 2 * 0.8),
                              math.floor(sw * 0.03))
    local content_w   = sw - 2 * pad
    local nav_strip_w = math.floor(content_w * 0.75)
    local side_strip  = math.floor((sw - nav_strip_w) / 2)
    return sw, sh, art, bar_t, hit, footer_h, side_strip
end

-- X of the bars' centre: centred within the side strip, like the footer button.
local function barsCenterX(side, sw, side_strip)
    if side == "right" then return sw - math.floor(side_strip / 2) end
    return math.floor(side_strip / 2)
end

function ReaderButtons:paintTo(_bb, _x, _y)
    local sw, sh, art, bar_t, hit, footer_h, side_strip = consts()
    local cx = barsCenterX(self.side, sw, side_strip)
    -- Three centred horizontal bars, exactly as _buildStartMenuIcon.
    local bar_w = art
    local span0 = math.floor(art * 0.62)
    local gap   = math.max(1, math.floor((span0 - 3 * bar_t) / 2))
    local span  = 3 * bar_t + 2 * gap
    -- Vertical: the footer frame (art + hit) is centred in footer_h, the bars
    -- centred within the art box at the frame's top.
    local band_top  = sh - footer_h
    local frame_top = band_top + math.floor((footer_h - (art + hit)) / 2)
    local first_y   = frame_top + math.floor((art - span) / 2)
    local left      = cx - math.floor(bar_w / 2)
    for i = 0, 2 do
        _bb:paintRect(left, first_y + i * (bar_t + gap), bar_w, bar_t, Blitbuffer.COLOR_BLACK)
    end
    self.dimen = Geom:new{ x = left, y = first_y, w = bar_w, h = span }
end

-- Touch target: a comfortable box around the bars, centred on them in the
-- bottom footer band. Deliberately NOT the full side strip (the footer button's
-- width) -- in the reader that would swallow the bottom corner's page-turn taps.
function ReaderButtons.tapRect(side)
    local sw, sh, art, _bar_t, _hit, footer_h, side_strip = consts()
    local cx = barsCenterX(side, sw, side_strip)
    local w  = art + 2 * Screen:scaleBySize(10)
    return Geom:new{ x = math.max(0, cx - math.floor(w / 2)),
                     y = sh - footer_h, w = w, h = footer_h }
end

return ReaderButtons
