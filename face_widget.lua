-- face_widget.lua — draws the faces (plain rectangles and circles, no
-- images or fonts but the names) and the gallery of face cards.

local Blitbuffer     = require("ffi/blitbuffer")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local UIManager      = require("ui/uimanager")

local BLACK = Blitbuffer.COLOR_BLACK
local WHITE = Blitbuffer.COLOR_WHITE
local SKIN_EDGE = BLACK
local BODY  = Blitbuffer.COLOR_GRAY_B

local HAIR_COLOR = {
    dark  = Blitbuffer.COLOR_GRAY_2,
    grey  = Blitbuffer.COLOR_GRAY_8 or Blitbuffer.COLOR_GRAY_7,
    light = Blitbuffer.COLOR_GRAY_D,
    none  = Blitbuffer.COLOR_GRAY_2,
}

local Face = {}

-- Fills the rows of a disc (cx, cy, r) between y0 and y1.
local function discRows(bb, cx, cy, r, y0, y1, color)
    y0, y1 = math.max(math.floor(y0), cy - r), math.min(math.floor(y1), cy + r)
    for yy = y0, y1 do
        local dy = yy - cy
        local hw = math.floor(math.sqrt(math.max(0, r * r - dy * dy)) + 0.5)
        if hw > 0 then bb:paintRect(cx - hw, yy, 2 * hw, 1, color) end
    end
end

-- Draws face f in the square box (x, y, s).
function Face.paint(bb, f, x, y, s)
    local cx = x + math.floor(s / 2)
    local r  = math.floor(s * 0.27)
    local cy = y + math.floor(s * 0.47)
    local t  = math.max(2, math.floor(s / 40))
    local hair = HAIR_COLOR[f.color] or HAIR_COLOR.dark

    -- Shoulders and neck.
    local top = cy + math.floor(r * 0.9)
    local h = y + s - top
    for i = 0, h - 1 do
        local hw = math.floor(r * 0.45 + r * 1.0 * math.min(1, i / (h * 0.45)))
        bb:paintRect(cx - hw, top + i, 2 * hw, 1, BODY)
    end
    bb:paintRect(cx - math.floor(r * 0.28), cy + math.floor(r * 0.7), math.floor(r * 0.56), math.floor(r * 0.5), WHITE)

    -- Hair behind the head.
    if f.hair == "long" then
        bb:paintRect(cx - r - 2 * t, cy - math.floor(r * 0.2), 2 * r + 4 * t, math.floor(r * 1.35), hair)
        bb:paintCircle(cx, cy - math.floor(r * 0.1), r + 2 * t, hair)
    elseif f.hair == "short" then
        bb:paintCircle(cx, cy - math.floor(r * 0.12), r + t, hair)
    elseif f.hair == "curly" then
        local cr = math.floor(r * 0.36)
        for k = 0, 6 do
            local a = math.pi * (1.05 + 0.9 * k / 6)
            bb:paintCircle(cx + math.floor(math.cos(a) * r * 0.95), cy + math.floor(math.sin(a) * r * 0.9), cr, hair)
        end
    end

    -- Ears, then the face over them.
    local er = math.max(3, math.floor(r * 0.17))
    for _, sx in ipairs({ -1, 1 }) do
        bb:paintCircle(cx + sx * r, cy + math.floor(r * 0.05), er, WHITE)
        bb:paintCircle(cx + sx * r, cy + math.floor(r * 0.05), er, SKIN_EDGE, t)
    end
    bb:paintCircle(cx, cy, r, WHITE)
    bb:paintCircle(cx, cy, r, SKIN_EDGE, t)

    -- Fringe over the forehead.
    if f.hair ~= "bald" then
        discRows(bb, cx, cy, r, cy - r, cy - r * 0.5, hair)
        if f.color == "light" then
            -- A light fringe needs its lower edge drawn on a white face.
            local dy = math.floor(r * 0.5)
            local hw = math.floor(math.sqrt(r * r - dy * dy))
            bb:paintRect(cx - hw, cy - dy, 2 * hw, math.max(1, math.floor(t / 2)), BLACK)
        end
    end

    -- Beard (behind the mouth) or moustache.
    local beard_color = f.hair == "bald" and HAIR_COLOR.dark or hair
    if f.beard == "beard" then
        discRows(bb, cx, cy, r, cy + r * 0.3, cy + r, beard_color)
    end

    -- Eyes, nose, mouth.
    local ey = cy - math.floor(r * 0.08)
    local ex = math.floor(r * 0.38)
    local eye = math.max(2, math.floor(r * 0.09))
    bb:paintCircle(cx - ex, ey, eye, BLACK)
    bb:paintCircle(cx + ex, ey, eye, BLACK)
    bb:paintRect(cx - math.floor(t / 2), cy + math.floor(r * 0.02), t, math.floor(r * 0.22), BLACK)
    if f.beard == "moustache" then
        local mw, mh = math.floor(r * 0.36), math.max(3, math.floor(r * 0.13))
        bb:paintRect(cx - mw, cy + math.floor(r * 0.3), 2 * mw, mh, beard_color)
    end
    local mouth_color = (f.beard == "beard" and f.color ~= "light") and WHITE or BLACK
    local my = cy + math.floor(r * 0.5)
    local mw = math.floor(r * 0.32)
    if f.smile then
        for i = -mw, mw do
            local d = i / mw
            local yy = my + math.floor(r * 0.14 * (1 - d * d))
            bb:paintRect(cx + i, yy, 1, t, mouth_color)
        end
    else
        bb:paintRect(cx - mw, my + math.floor(r * 0.07), 2 * mw, t, mouth_color)
    end

    if f.glasses then
        local gr = math.floor(r * 0.25)
        bb:paintCircle(cx - ex, ey, gr, BLACK, t)
        bb:paintCircle(cx + ex, ey, gr, BLACK, t)
        bb:paintRect(cx - ex + gr, ey - math.floor(t / 2), 2 * (ex - gr), t, BLACK)
    end

    if f.earrings then
        for _, sx in ipairs({ -1, 1 }) do
            bb:paintCircle(cx + sx * r, cy + math.floor(r * 0.32), math.max(2, math.floor(r * 0.1)), BLACK)
        end
    end

    if f.hat == "cap" then
        -- A dome over the whole head (hair included), and a peak to one side.
        local dome = r + 3 * t
        discRows(bb, cx, cy - math.floor(r * 0.12), dome, cy - r * 0.12 - dome, cy - r * 0.42, BLACK)
        bb:paintRect(cx, cy - math.floor(r * 0.56), math.floor(r * 1.5), math.max(3, math.floor(r * 0.17)), BLACK)
    elseif f.hat == "hat" then
        local bw, bh = math.floor(r * 1.25), math.max(3, math.floor(r * 0.16))
        local hw, hh = math.floor(r * 0.72), math.floor(r * 0.85)
        local brim_y = cy - math.floor(r * 0.62)
        bb:paintRect(cx - hw, brim_y - hh, 2 * hw, hh, BLACK)
        bb:paintRect(cx - hw, brim_y - math.floor(hh * 0.35), 2 * hw, math.max(2, math.floor(hh * 0.12)), Blitbuffer.COLOR_GRAY_9)
        bb:paintRect(cx - bw, brim_y, 2 * bw, bh, BLACK)
    end
end

-- ---------------------------------------------------------------------------
-- FaceCard — one face with its name under it (the player's own character).
-- ---------------------------------------------------------------------------

local function centeredText(bb, text, face, cx, top, h)
    local m = RenderText:sizeUtf8Text(0, math.huge, face, text, true, false)
    local base = top + math.floor((h + m.y_top - m.y_bottom) / 2)
    RenderText:renderUtf8Text(bb, cx - math.floor(m.x / 2), base, face, text, true, false, BLACK)
end

local FaceCard = InputContainer:extend{
    face = nil,
    size = 200,
}

function FaceCard:init()
    self.name_h = math.floor(self.size * 0.2)
    self.name_face = Font:getFace("cfont", math.max(12, math.floor(self.size * 0.075)))
    self.dimen = Geom:new{ w = self.size, h = self.size + self.name_h }
end

function FaceCard:paintTo(bb, x, y)
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, WHITE)
    Face.paint(bb, self.face, x, y, self.size)
    centeredText(bb, self.face.name, self.name_face, x + math.floor(self.size / 2), y + self.size, self.name_h)
end

-- ---------------------------------------------------------------------------
-- Gallery — every face as a card; flipped ones are greyed and crossed.
-- ---------------------------------------------------------------------------

local Gallery = InputContainer:extend{
    board      = nil,
    max_width  = 0,
    max_height = 0,
    getSelected  = nil,   -- function() -> face index (a guess being made)
    onFaceTapped = nil,   -- function(i)
}

Gallery.CARD_RATIO = 1.22   -- card height / width (portrait + name)

function Gallery:init()
    local n = #self.board.faces
    -- The column count that gives the biggest cards in the room there is.
    local best_w, best_cols = 0, 4
    for cols = 3, 8 do
        local rows = math.ceil(n / cols)
        local w = math.floor(math.min(self.max_width / cols, self.max_height / (rows * Gallery.CARD_RATIO)))
        if w > best_w then best_w, best_cols = w, cols end
    end
    self.cols = best_cols
    self.rows = math.ceil(n / best_cols)
    self.card_w = best_w
    self.card_h = math.floor(best_w * Gallery.CARD_RATIO)
    self.dimen = Geom:new{ w = self.card_w * self.cols, h = self.card_h * self.rows }
    self.name_face = Font:getFace("cfont", math.max(10, math.floor(self.card_w * 0.13)))
    self.ges_events = {
        TapFace = { GestureRange:new{ ges = "tap", range = function() return self.paint_rect end } },
    }
end

function Gallery:onTapFace(_, ges)
    if not self.paint_rect then return false end
    local col = math.floor((ges.pos.x - self.paint_rect.x) / self.card_w)
    local row = math.floor((ges.pos.y - self.paint_rect.y) / self.card_h)
    local i = row * self.cols + col + 1
    if col >= 0 and col < self.cols and row >= 0 and self.board.faces[i] and self.onFaceTapped then
        self.onFaceTapped(i)
    end
    return true
end

function Gallery:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }
    local b = self.board
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, WHITE)
    local pad = math.max(2, math.floor(self.card_w * 0.04))
    local sel = self.getSelected and self.getSelected()
    for i, f in ipairs(b.faces) do
        local col, row = (i - 1) % self.cols, math.floor((i - 1) / self.cols)
        local cx, cy = x + col * self.card_w, y + row * self.card_h
        local s = self.card_w - 2 * pad
        Face.paint(bb, f, cx + pad, cy + pad, s)
        local name_top = cy + pad + s
        centeredText(bb, f.name, self.name_face, cx + math.floor(self.card_w / 2), name_top,
            self.card_h - s - 2 * pad)
        if b.down[i] then
            bb:lightenRect(cx + 1, cy + 1, self.card_w - 2, self.card_h - 2, 0.75)
            local t = math.max(2, math.floor(self.card_w / 30))
            for k = 0, s do
                bb:paintRect(cx + pad + k, cy + pad + k, t, t, Blitbuffer.COLOR_GRAY_7)
                bb:paintRect(cx + pad + s - k, cy + pad + k, t, t, Blitbuffer.COLOR_GRAY_7)
            end
        end
        if (b.guess == i) or sel == i then
            bb:paintBorder(cx + 1, cy + 1, self.card_w - 2, self.card_h - 2, math.max(3, math.floor(self.card_w / 25)), BLACK)
        else
            bb:paintBorder(cx + 1, cy + 1, self.card_w - 2, self.card_h - 2, 1, Blitbuffer.COLOR_GRAY_B)
        end
    end
end

function Gallery:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

return { Face = Face, FaceCard = FaceCard, Gallery = Gallery }
