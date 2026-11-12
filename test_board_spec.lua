package.path = "./?.lua;./common/?.lua;" .. package.path
local Board = dofile("board.lua")

describe("gallery", function()
    it("has distinct faces with unique names, the same on both readers", function()
        for variant, v in ipairs(Board.VARIANTS) do
            for seed = 0, 60 do
                local p1 = Board.new{ seed = seed, variant = variant, role = 1 }
                local p2 = Board.new{ seed = seed, variant = variant, role = 2 }
                assert.equals(v.faces, #p1.faces)
                local names = {}
                for i, f in ipairs(p1.faces) do
                    assert.is_nil(names[f.name])
                    names[f.name] = true
                    assert.same(f, p2.faces[i])
                    if i > 1 then assert.is_true(p1.faces[i - 1].name < f.name) end
                end
                assert.equals(p1.mine, p2.theirs)
                assert.equals(p1.theirs, p2.mine)
                assert.are_not.equal(p1.mine, p1.theirs)
            end
        end
    end)

    it("gives every face a beard only from the first name list", function()
        local in_a = {}
        for _, n in ipairs(Board.NAMES_A) do in_a[n] = true end
        for seed = 0, 30 do
            for _, f in ipairs(Board.new{ seed = seed, variant = 2 }.faces) do
                if f.beard ~= "none" then assert.is_true(in_a[f.name], f.name) end
                if f.hair == "bald" then assert.equals("none", f.color) end
            end
        end
    end)

    it("varies its traits enough to ask questions", function()
        local glasses, hats, smiles, total = 0, 0, 0, 0
        for seed = 0, 40 do
            for _, f in ipairs(Board.new{ seed = seed, variant = 2 }.faces) do
                total = total + 1
                if f.glasses then glasses = glasses + 1 end
                if f.hat ~= "none" then hats = hats + 1 end
                if f.smile then smiles = smiles + 1 end
            end
        end
        assert.is_true(glasses / total > 0.15 and glasses / total < 0.45)
        assert.is_true(hats / total > 0.12 and hats / total < 0.4)
        assert.is_true(smiles / total > 0.35 and smiles / total < 0.65)
    end)
end)

describe("play", function()
    it("flips faces down and up", function()
        local b = Board.new{ seed = 3, variant = 1 }
        b:toggle(1)
        b:toggle(2)
        assert.equals(14, b:upCount())
        b:toggle(1)
        assert.equals(15, b:upCount())
    end)

    it("checks the final guess against the other secret", function()
        local b = Board.new{ seed = 4, variant = 2, role = 1 }
        assert.is_true(b:makeGuess(b.theirs))
        assert.equals("won", b.result)
        local c = Board.new{ seed = 4, variant = 2, role = 2 }
        assert.is_false(c:makeGuess(c.mine))
        assert.equals("lost", c.result)
        assert.is_nil(c:makeGuess(1))
    end)

    it("saves and restores", function()
        local b = Board.new{ seed = 5, variant = 2, role = 2, code = "11111" }
        b:toggle(3)
        local b2 = Board.load(b:serialize())
        assert.same(b:serialize(), b2:serialize())
        assert.equals(b.mine, b2.mine)
        assert.is_nil(Board.load({ seed = 1, variant = 7 }))
    end)
end)
