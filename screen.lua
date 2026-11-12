local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ButtonDialog    = require("ui/widget/buttondialog")
local ConfirmBox      = require("ui/widget/confirmbox")
local Device          = require("device")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font            = require("ui/font")
local Geom            = require("ui/geometry")
local GestureRange    = require("ui/gesturerange")
local InputContainer  = require("ui/widget/container/inputcontainer")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local Duo        = require("duo")
local ScreenBase = require("screen_base")

local Board      = lrequire("board")
local Faces      = lrequire("face_widget")

local RULES_EN = [[
Mystery Face — two readers, two secret characters

Each player has a reader. Both readers show the same gallery of faces, and each one gives its player a secret character, hidden from the other. Be the first to find out who the other player is!

Starting
• One player taps New game → Start a game and reads the code aloud. The other taps New game → Join a game and types it. One is player 1, the other player 2.
• The player who starts chooses the gallery (menu): 16 or 24 faces.
• My character shows yours, with its looks spelled out, to answer without mistakes.

Playing — take turns
• Ask one question about looks that is answered yes or no: "Does your character wear glasses?", "Is the hair dark?", "Is there a hat?"
• Tap the faces your opponent's answer rules out: they turn grey. Tap again to bring one back.
• When you think you know, tap Guess, then the face. Your reader checks it: right, you win; wrong, you lose!
]]

local RULES_FR = [[
Devine le personnage — deux liseuses, deux personnages secrets

Chaque joueur a une liseuse. Les deux affichent la même galerie de visages, et chacune donne à son joueur un personnage secret, caché à l'autre. Soyez le premier à découvrir qui est le personnage de l'autre !

Pour commencer
• Un joueur touche Nouvelle partie → Lancer une partie et lit le code à voix haute. L'autre touche Nouvelle partie → Rejoindre une partie et le saisit. L'un est le joueur 1, l'autre le joueur 2.
• Celui qui lance choisit la galerie (menu) : 16 ou 24 visages.
• Mon personnage montre le vôtre, avec son apparence détaillée, pour répondre sans erreur.

Déroulement — chacun son tour
• Posez une question sur l'apparence, à laquelle on répond par oui ou non : « Ton personnage porte-t-il des lunettes ? », « A-t-il les cheveux foncés ? », « A-t-il un chapeau ? »
• Touchez les visages que la réponse élimine : ils deviennent gris. Touchez de nouveau pour en remettre un.
• Quand vous pensez savoir, touchez Deviner, puis le visage. Votre liseuse vérifie : juste, vous gagnez ; faux, vous perdez !
]]

local VARIANT_NAMES = { "16 faces", "24 faces" }

-- What a face looks like, in words, for the player who answers questions.
-- Whole phrases, so each language words them its own way.
local HAIR_LINES = {
    short = { dark = _("Hair: short and dark"), grey = _("Hair: short and grey"), light = _("Hair: short and light") },
    long  = { dark = _("Hair: long and dark"),  grey = _("Hair: long and grey"),  light = _("Hair: long and light") },
    curly = { dark = _("Hair: curly and dark"), grey = _("Hair: curly and grey"), light = _("Hair: curly and light") },
}

local function describe(f)
    local lines = {}
    lines[#lines + 1] = f.hair == "bald" and _("Hair: none (bald)") or HAIR_LINES[f.hair][f.color]
    lines[#lines + 1] = f.glasses and _("Glasses: yes") or _("Glasses: no")
    lines[#lines + 1] = f.hat == "cap" and _("Hat: a cap") or f.hat == "hat" and _("Hat: a top hat") or _("Hat: no")
    lines[#lines + 1] = f.beard == "beard" and _("Beard: yes") or f.beard == "moustache" and _("Moustache: yes")
        or _("Beard or moustache: no")
    lines[#lines + 1] = f.earrings and _("Earrings: yes") or _("Earrings: no")
    lines[#lines + 1] = f.smile and _("Smiling: yes") or _("Smiling: no")
    return table.concat(lines, "\n")
end

-- A card shown on top of the screen; any tap closes it.
local CardPopup = InputContainer:extend{ content = nil }

function CardPopup:init()
    local screen = Device.screen
    self.dimen = Geom:new{ x = 0, y = 0, w = screen:getWidth(), h = screen:getHeight() }
    self[1] = CenterContainer:new{
        dimen = self.dimen,
        FrameContainer:new{
            background = require("ffi/blitbuffer").COLOR_WHITE,
            bordersize = Size.border.window,
            radius = Size.radius.window,
            padding = Size.padding.large,
            self.content,
        },
    }
    self.ges_events = {
        TapClose = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
end

function CardPopup:onTapClose()
    UIManager:close(self)
    UIManager:setDirty(nil, "ui")
    return true
end

local FaceScreen = ScreenBase:extend{}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function FaceScreen:init()
    self.board = Board.load(self.plugin:loadState())
    ScreenBase.init(self)
end

function FaceScreen:serializeState()
    return self.board and self.board:serialize() or nil
end

function FaceScreen:save()
    self.plugin:saveState(self:serializeState())
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function FaceScreen:isRoundOver()
    return not self.board or self.board:isOver()
end

function FaceScreen:buildLayout()
    local title_bar = self:buildTitleBar(_("Mystery Face"), function()
        local items = {
            { text = _("New game"), callback = function() self:onNewGame() end },
            { text = T(_("Gallery: %1"), _(VARIANT_NAMES[self.plugin:getSetting("variant", 2)])),
              callback = function() self:openVariantMenu() end },
        }
        if self.board then
            items[#items + 1] = { text = _("Show the game code"), callback = function() self:showCode() end }
        end
        items[#items + 1] = self:makeRulesButtonConfig(RULES_EN, RULES_FR)
        return items
    end)

    self.status_text:setMaxWidth(self:getControlsWidth())
    local rows = {}
    if self.board then
        rows = { {
            { text = _("My character"), callback = function() self:showMine() end },
            { text = _("Guess"), callback = function() self:onGuess() end },
        } }
    end
    local controls = VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self:buildActionBar(rows),
    }

    local budget_w, budget_h = self:getBoardBudget(title_bar, controls)
    local content
    if self.board then
        self.gallery = Faces.Gallery:new{
            board = self.board, max_width = budget_w, max_height = budget_h,
            getSelected  = function()
                local b = self.board
                if b:isOver() then return b.theirs end
                return nil
            end,
            onFaceTapped = function(i) self:onFaceTapped(i) end,
        }
        self.board_widget = self.gallery
        content = self.gallery
    else
        self.gallery, self.board_widget = nil, nil
        content = TextBoxWidget:new{
            text = _("Each player needs a reader with this game. One starts a game and reads the code aloud; the other joins with that code."),
            face = Font:getFace("infofont"),
            width = math.min(budget_w, Device.screen:scaleBySize(500)),
            alignment = "center",
        }
    end
    local frame = FrameContainer:new{ padding = 0, margin = 0, bordersize = 0, content }

    if self:isLandscape() then
        self:buildLandscapeLayout(title_bar, HorizontalGroup:new{
            align = "center", frame, HorizontalSpan:new{ width = self:getGutter() }, controls,
        })
    else
        self:buildPortraitLayout(title_bar, frame,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
    self:updateStatus()
end

function FaceScreen:rebuild()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function FaceScreen:updateStatus(message)
    local b = self.board
    local status = message
    if not status then
        if not b then
            status = _("Start or join a game.")
        elseif b.result == "won" then
            status = T(_("Right, it was %1. You win!"), b.faces[b.theirs].name)
        elseif b.result == "lost" then
            status = T(_("Wrong: it was %1. You lose."), b.faces[b.theirs].name)
        elseif self.guessing then
            status = _("Tap the face you think is the other player's.")
        else
            status = self:joinStatus(
                T(_("Player %1"), b.role),
                T(_("Faces still up: %1"), b:upCount()))
        end
    end
    ScreenBase.updateStatus(self, status)
end

-- ---------------------------------------------------------------------------
-- Play
-- ---------------------------------------------------------------------------

function FaceScreen:onFaceTapped(i)
    local b = self.board
    if b:isOver() then return end
    if self.guessing then
        self.guessing = false
        UIManager:show(ConfirmBox:new{
            text = T(_("Final guess: %1?\nA wrong guess loses the game."), b.faces[i].name),
            ok_text = _("Guess"),
            ok_callback = function()
                local right = b:makeGuess(i)
                self:save()
                self.gallery:refresh()
                self:updateStatus()
                self:refreshActionBar()
                self:showMessage(right and T(_("Right, it was %1. You win!"), b.faces[b.theirs].name)
                    or T(_("Wrong: it was %1. You lose."), b.faces[b.theirs].name), 5)
            end,
            cancel_callback = function() self:updateStatus() end,
        })
        return
    end
    b:toggle(i)
    self:save()
    self.gallery:refresh()
    self:updateStatus()
end

function FaceScreen:onGuess()
    if self.board:isOver() then return end
    self.guessing = not self.guessing
    self:updateStatus()
end

function FaceScreen:showMine()
    local f = self.board.faces[self.board.mine]
    local w = math.floor(math.min(Device.screen:getWidth(), Device.screen:getHeight()) * 0.55)
    UIManager:show(CardPopup:new{
        content = VerticalGroup:new{
            align = "center",
            TextBoxWidget:new{
                text = _("My character"),
                face = Font:getFace("tfont"),
                width = w,
                alignment = "center",
            },
            VerticalSpan:new{ width = Size.span.vertical_large },
            Faces.FaceCard:new{ face = f, size = w },
            TextBoxWidget:new{
                text = describe(f),
                face = Font:getFace("infofont"),
                width = w,
            },
        },
    })
end

-- ---------------------------------------------------------------------------
-- New game
-- ---------------------------------------------------------------------------

function FaceScreen:onNewGame()
    Duo.newGameDialog{
        title     = _("Mystery Face"),
        nvariants = #Board.VARIANTS,
        variant   = self.plugin:getSetting("variant", 2),
        variant_text = function(v) return T(_("Gallery: %1"), _(VARIANT_NAMES[v])) end,
        roles = {
            { id = 1, text = T(_("Player %1"), 1) },
            { id = 2, text = T(_("Player %1"), 2) },
        },
        on_start = function(game)
            self.guessing = false
            self.board = Board.new{ seed = game.seed, variant = game.variant, role = game.role, code = game.code }
            self:save()
            self:rebuild()
        end,
    }
end

function FaceScreen:showCode()
    local b = self.board
    self:showMessage(T(_("Game code: %1"), Duo.format(b.code)) .. "\n"
        .. T(_("Gallery: %1"), _(VARIANT_NAMES[b.variant])), 6)
end

function FaceScreen:openVariantMenu()
    local dlg
    local buttons = {}
    for i, name in ipairs(VARIANT_NAMES) do
        buttons[#buttons + 1] = { {
            text = _(name),
            callback = function()
                UIManager:close(dlg)
                self.plugin:saveSetting("variant", i)
            end,
        } }
    end
    dlg = ButtonDialog:new{ title = _("Gallery of the games you start"), buttons = buttons }
    UIManager:show(dlg)
end

return FaceScreen
