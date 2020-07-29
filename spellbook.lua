local common = require "class.commons"
local images = require "images"

-------------------------------------------------------------------------------
------------------------------- SPELLBOOK CLASS -------------------------------
-------------------------------------------------------------------------------
local Spellbook = {}

function Spellbook:init(charselect)
	self.game = charselect.game
	self.stage = self.game.stage
	self.charselect = charselect

	self.spellbook_data = {
		heath = {
			spellbook = {
				image = images.spellbook_heath_spellbook,
			},
			pic1 = {
				image = images.spellbook_heath1,
				scaling = 0.25,
				x = self.stage.width * 0.4,
				y = self.stage.height * 0.7,
			},
			pic2 = {
				image = images.spellbook_heath2,
				scaling = 0.25,
				x = self.stage.width * 0.6,
				y = self.stage.height * 0.7,
			},
			pic3 = {
				image = images.spellbook_heath3,
				scaling = 0.25,
				x = self.stage.width * 0.8,
				y = self.stage.height * 0.7,
			},
			spellbook_loc = {x = self.stage.x_mid, y = self.stage.y_mid},
		},
	}

	self.spellbooks = {
		heath = {},
	}

	for char_name, data in pairs(self.spellbook_data) do
		self.spellbooks[char_name].main = self.charselect:_createButton{
			name = "spellbook_" .. char_name .. "_main",
			image = data.spellbook.image,
			image_pushed = data.spellbook.image,
			end_x = self.stage.x_mid,
			end_y = self.stage.height * -0.5,
			container = self.charselect.gamestate.ui.spellbooks,
		}

	end
end

function Spellbook:displayCharacter(char_name)
	local char = self.spellbooks[char_name]
	assert(char.main, "No data for requested character " .. char_name)

	self.spellbooks[char_name].main:change{
		duration = 20,
		y = self.stage.y_mid,
		easing = "outCubic",
	}
end

function Spellbook:hideCharacter(char_name)
	local char = self.spellbooks[char_name]
	assert(char, "No character in spellbook " .. char_name)

	self.spellbooks[char_name].main: change{
		duration = 0,
		y = self.stage.height * -0.5,
	}
	-- TODO: hide the pics too
end

return common.class("Spellbook", Spellbook)
