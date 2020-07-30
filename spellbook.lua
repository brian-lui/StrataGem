local common = require "class.commons"
local images = require "images"

-------------------------------------------------------------------------------
------------------------------- SPELLBOOK CLASS -------------------------------
-------------------------------------------------------------------------------
local Spellbook = {}

function Spellbook:init(charselect)
	self.game = charselect.game
	self.stage = self.game.stage

	self.spellbook_data = {
		heath = {
			spellbook = {
				image = images.spellbook_heath_spellbook,
			},
			pic1 = {
				image = images.spellbook_heath1,
				scaling = 0.25,
				x = self.stage.width * 0.35,
				y = self.stage.height * 0.725,
			},
			pic2 = {
				image = images.spellbook_heath2,
				scaling = 0.25,
				x = self.stage.width * 0.6,
				y = self.stage.height * 0.725,
			},
			pic3 = {
				image = images.spellbook_heath3,
				scaling = 0.25,
				x = self.stage.width * 0.85,
				y = self.stage.height * 0.725,
			},
			spellbook_loc = {x = self.stage.x_mid, y = self.stage.y_mid},
		},
	}

	self.spellbooks = {
		heath = {},
	}

	self.main_images = {}
	self.sub_images = {}
	self.char_displayed = false

	for char_name, data in pairs(self.spellbook_data) do
		self.spellbooks[char_name].main = charselect:_createButton{
			name = "spellbook_" .. char_name .. "_main",
			image = data.spellbook.image,
			image_pushed = data.spellbook.image,
			end_x = self.stage.x_mid,
			end_y = self.stage.height * -0.5,
			container = self.main_images,
			action = function() self:hideCharacter(char_name) end,
		}

		local pic_num = 1
		local next_pic = "pic" .. pic_num

		while data[next_pic] do
			local current_pic = "pic" .. pic_num
			self.spellbooks[char_name][next_pic] = charselect:_createButton{
				name = "spellbook_" .. char_name .. "_" .. next_pic,
				image = data[current_pic].image,
				image_pushed = data[current_pic].image,
				end_x = self.stage.width * -0.5,
				end_y = data[current_pic].y,
				container = self.sub_images,
				action = function()
					if self.spellbooks[char_name][current_pic].being_displayed then
						self:shrinkSubImage(char_name, current_pic)
					else
						self:magnifySubImage(char_name, current_pic)
					end
				end,
			}
			self.spellbooks[char_name][current_pic]:change{
				duration = 0,
				x = self.stage.width * -0.5,
				scaling = self.spellbook_data[char_name][current_pic].scaling,
			}

			self.spellbooks[char_name][current_pic].being_displayed = false

			pic_num = pic_num + 1
			next_pic = "pic" .. pic_num
		end
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

	local pic_num = 1
	local next_pic = "pic" .. pic_num

	while self.spellbooks[char_name][next_pic] do
		local current_pic = "pic" .. pic_num
		self.spellbooks[char_name][current_pic]:change{
			duration = 20,
			x = self.spellbook_data[char_name][current_pic].x,
		}

		pic_num = pic_num + 1
		next_pic = "pic" .. pic_num
	end

	self.char_displayed = char_name
end

function Spellbook:hideCharacter()
	local char = self.char_displayed
	if not char then return end

	self.spellbooks[char].main:change{
		duration = 0,
		y = self.stage.height * -0.5,
	}

	local pic_num = 1
	local next_pic = "pic" .. pic_num

	while self.spellbooks[char][next_pic] do
		local current_pic = "pic" .. pic_num
		self.spellbooks[char][current_pic]:change{
			duration = 0,
			x = self.stage.width * -0.5,
			scaling = self.spellbook_data[char][current_pic].scaling,
		}

		pic_num = pic_num + 1
		next_pic = "pic" .. pic_num
	end

	self.char_displayed = false
end

function Spellbook:magnifySubImage(char_name, pic_name)
	local picture = self.spellbooks[char_name][pic_name]
	picture:change{
		duration = 15,
		x = self.stage.x_mid,
		y = self.stage.y_mid,
		scaling = 1,
		easing = "outCubic",
	}

	picture.being_displayed = true
end

function Spellbook:shrinkSubImage(char_name, pic_name)
	local picture = self.spellbooks[char_name][pic_name]
	picture:change{
		duration = 5,
		x = self.spellbook_data[char_name][pic_name].x,
		y = self.spellbook_data[char_name][pic_name].y,
		scaling = self.spellbook_data[char_name][pic_name].scaling,
	}

	picture.being_displayed = false
end

function Spellbook:update(dt)
	for _, v in pairs(self.main_images) do v:update(dt) end
	for _, v in pairs(self.sub_images) do v:update(dt) end
end

function Spellbook:draw()
	if self.char_displayed then
		local darkened = self.game:isScreenDark()

		for _, v in pairs(self.main_images) do
			v:draw{darkened = darkened}
		end

		for _, v in pairs(self.sub_images) do
			if not v.being_displayed then v:draw{darkened = darkened} end
		end

		for _, v in pairs(self.sub_images) do
			if v.being_displayed then v:draw{darkened = darkened} end
		end
	end
end

return common.class("Spellbook", Spellbook)
