-- ---------------------------------------------------------------------------
-- board.lua — Mystery Face: guess the other player's character. Pure Lua.
--
-- Both readers build the same gallery of faces from the game code (common/
-- duo.lua), and the same two secret characters: one per player. Each reader
-- shows its own player's character and hides the other one. The players
-- take turns asking yes/no questions about looks ("Does your character
-- wear glasses?") and tap the faces they rule out. A guess is checked by
-- the guesser's own reader, since it knows the other secret too.
--
-- Names are the same in every language (spoken aloud between two readers
-- that may not share a UI language).
-- ---------------------------------------------------------------------------

local Duo = require("duo")

local Board = {}
Board.__index = Board

-- Gallery sizes (the code's variant): faces, columns in portrait.
Board.VARIANTS = {
    { faces = 16, cols = 4 },
    { faces = 24, cols = 6 },
}

Board.NAMES_A = {
    "Adam", "Alex", "Arthur", "Ben", "Daniel", "David", "Felix", "Hugo", "Jules", "Leo",
    "Louis", "Lucas", "Max", "Noah", "Oscar", "Paul", "Sam", "Simon", "Theo", "Tom", "Victor",
}
Board.NAMES_B = {
    "Alice", "Anna", "Camille", "Charlie", "Chloe", "Clara", "Emma", "Eva", "Iris", "Jade",
    "Julia", "Lea", "Lily", "Lina", "Lucie", "Luna", "Maya", "Mia", "Nina", "Nora", "Rose",
    "Sarah", "Sofia", "Zoe",
}

-- Traits, with the values a face can take. `beard` only on NAMES_A faces.
Board.HAIR   = { "bald", "short", "long", "curly" }
Board.COLOR  = { "dark", "grey", "light" }
Board.HAT    = { "none", "cap", "hat" }
Board.BEARD  = { "none", "moustache", "beard" }

local function key(f)
    return table.concat({ f.hair, f.color, f.hat, f.beard, tostring(f.glasses),
        tostring(f.earrings), tostring(f.smile) }, "/")
end

-- The gallery and both secrets for (seed, variant).
function Board.generate(seed, variant)
    local v = Board.VARIANTS[variant] or Board.VARIANTS[2]
    local rng = Duo.rng(seed, "mysteryface")
    local names_a, names_b = {}, {}
    for i, n in ipairs(Board.NAMES_A) do names_a[i] = n end
    for i, n in ipairs(Board.NAMES_B) do names_b[i] = n end
    rng:shuffle(names_a)
    rng:shuffle(names_b)
    local faces, seen = {}, {}
    local ia, ib = 0, 0
    while #faces < v.faces do
        local group_a = rng:random(2) == 1
        if ia == #names_a then group_a = false elseif ib == #names_b then group_a = true end
        local f = {
            hair     = rng:pick(Board.HAIR),
            color    = rng:pick(Board.COLOR),
            hat      = rng:random() < 0.25 and (rng:random(2) == 1 and "cap" or "hat") or "none",
            glasses  = rng:random() < 0.3,
            earrings = rng:random() < 0.25,
            smile    = rng:random(2) == 1,
            beard    = "none",
        }
        if group_a and rng:random() < 0.45 then f.beard = rng:random(2) == 1 and "moustache" or "beard" end
        -- A bald head has no hair colour; a hat hides most of the hair.
        if f.hair == "bald" then f.color = "none" end
        local k = key(f)
        if not seen[k] then
            seen[k] = true
            if group_a then
                ia = ia + 1
                f.name = names_a[ia]
            else
                ib = ib + 1
                f.name = names_b[ib]
            end
            faces[#faces + 1] = f
        end
    end
    -- Sorted by name, so both players can find a face quickly. Byte order,
    -- not the locale's: both readers must agree (names are unique).
    table.sort(faces, function(x, y)
        local a, b = x.name, y.name
        for i = 1, math.min(#a, #b) do
            local ca, cb = a:byte(i), b:byte(i)
            if ca ~= cb then return ca < cb end
        end
        return #a < #b
    end)
    local s1 = rng:random(#faces)
    local s2 = rng:random(#faces - 1)
    if s2 >= s1 then s2 = s2 + 1 end
    return { faces = faces, cols = v.cols, secret = { s1, s2 } }
end

-- o: seed, variant, role (1 | 2), code, and saved progress.
function Board.new(o)
    local self = setmetatable({}, Board)
    self.seed    = o.seed or 0
    self.variant = Board.VARIANTS[o.variant] and o.variant or 2
    self.role    = o.role == 2 and 2 or 1
    self.code    = o.code
    local g = Board.generate(self.seed, self.variant)
    self.faces, self.cols = g.faces, g.cols
    self.mine   = g.secret[self.role]
    self.theirs = g.secret[3 - self.role]
    self.down   = o.down or {}
    self.result = o.result          -- nil | "won" | "lost"
    self.guess  = o.guess
    return self
end

function Board:serialize()
    return {
        seed = self.seed, variant = self.variant, role = self.role, code = self.code,
        down = self.down, result = self.result, guess = self.guess,
    }
end

function Board.load(t)
    if type(t) ~= "table" or type(t.seed) ~= "number" or not Board.VARIANTS[t.variant] then return nil end
    return Board.new(t)
end

function Board:isOver()
    return self.result ~= nil
end

function Board:toggle(i)
    if self:isOver() or not self.faces[i] then return end
    self.down[i] = not self.down[i] or nil
end

function Board:upCount()
    local k = 0
    for i = 1, #self.faces do
        if not self.down[i] then k = k + 1 end
    end
    return k
end

-- Final guess: true if face i is the other player's character. Classic
-- rule: a wrong guess loses the game.
function Board:makeGuess(i)
    if self:isOver() or not self.faces[i] then return nil end
    self.guess = i
    self.result = (i == self.theirs) and "won" or "lost"
    return self.result == "won"
end

return Board
