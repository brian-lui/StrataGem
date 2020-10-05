--[[
	This is the class to show the "spellbook" character ability details on the
	select screen.
--]]

local common = require "class.commons"
local images = require "images"

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
				x = self.stage.width * 0.35,
				y = self.stage.height * 0.725,
			},
			pic2 = {
				image = images.spellbook_heath2,
				x = self.stage.width * 0.6,
				y = self.stage.height * 0.725,
			},
			pic3 = {
				image = images.spellbook_heath3,
				x = self.stage.width * 0.85,
				y = self.stage.height * 0.725,
			},
			spellbook_loc = {x = self.stage.x_mid, y = self.stage.y_mid},
		},

		walter = {
			spellbook = {
				image = images.spellbook_walter_spellbook,
			},
			pic1 = {
				image = images.spellbook_walter1,
				x = self.stage.width * 0.45,
				y = self.stage.height * 0.725,
			},
			pic2 = {
				image = images.spellbook_walter2,
				x = self.stage.width * 0.75,
				y = self.stage.height * 0.725,
			},
		},

		diggory = {
			spellbook = {
				image = images.spellbook_diggory_spellbook,
			},
		},

		holly = {
			spellbook = {
				image = images.spellbook_holly_spellbook,
			},
		},

		wolfgang = {
			spellbook = {
				image = images.spellbook_wolfgang_spellbook,
			},
			pic1 = {
				image = images.spellbook_wolfgang1,
				x = self.stage.width * 0.35,
				y = self.stage.height * 0.725,
			},
			pic2 = {
				image = images.spellbook_wolfgang2,
				x = self.stage.width * 0.6,
				y = self.stage.height * 0.725,
			},
			pic3 = {
				image = images.spellbook_wolfgang3,
				x = self.stage.width * 0.85,
				y = self.stage.height * 0.725,
			},
		},

		fuka = {
			spellbook = {
				image = images.spellbook_fuka_spellbook,
			},
		},

	}

	self.spellbooks = {
		heath = {},
		walter = {},
		diggory = {},
		holly = {},
		wolfgang = {},
		fuka = {},
	}

	self.main_images = {}
	self.sub_images = {}
	self.char_displayed = false

	self.THUMBNAIL_SCALING = 0.25

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
			local thumbnail = "pic" .. pic_num
			self.spellbooks[char_name][next_pic] = charselect:_createButton{
				name = "spellbook_" .. char_name .. "_" .. next_pic,
				image = data[thumbnail].image,
				image_pushed = data[thumbnail].image,
				end_x = data[thumbnail].x,
				end_y = self.stage.height * -0.5,
				container = self.sub_images,
				action = function()
					if self.spellbooks[char_name][thumbnail].being_displayed then
						self:shrinkSubImage(char_name, thumbnail)
					else
						self:magnifySubImage(char_name, thumbnail)
					end
				end,
			}
			self.spellbooks[char_name][thumbnail]:change{
				duration = 0,
				x = self.stage.width * -0.5,
				scaling = self.THUMBNAIL_SCALING,
			}

			self.spellbooks[char_name][thumbnail].being_displayed = false

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
		local thumbnail = "pic" .. pic_num
		self.spellbooks[char_name][thumbnail]:change{
			duration = 0,
			x = self.spellbook_data[char_name][thumbnail].x,
			y = self.spellbook_data[char_name][thumbnail].y - self.stage.height,
			scaling = self.THUMBNAIL_SCALING * 0.95
		}
		self.spellbooks[char_name][thumbnail]:change{
			duration = 20,
			y = self.spellbook_data[char_name][thumbnail].y,
			easing = "outCubic",
		}
		self.spellbooks[char_name][thumbnail]:change{
			duration = 5,
			scaling = self.THUMBNAIL_SCALING,
			easing = "outCubic",
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
		local thumbnail = "pic" .. pic_num
		self.spellbooks[char][thumbnail]:change{
			duration = 0,
			y = self.spellbook_data[char][thumbnail].y - self.stage.height,
			scaling = self.THUMBNAIL_SCALING,
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
		scaling = self.THUMBNAIL_SCALING,
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
