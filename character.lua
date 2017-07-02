require 'inits'
local image = require 'image'
local stage = require 'stage'
local Piece = require 'piece'
local Pie = require 'pie'
local pic = require 'pic'
local hand = require 'hand'

local character = {}
character.defaults = require 'characters/default' -- called from charselect
character.heath = require 'characters/heath'
character.walter = require 'characters/walter'
character.gail = require 'characters/gail'

-- initialize super meter graphics
local function setupSuperMeter(player)
	local super_frame = player == p1 and image.UI.gauge_gold or image.UI.gauge_silver
	player.super_frame = pic:new{x = stage.super[player].frame.x,
		y = stage.super[player].frame.y, image = super_frame}
	player.super_word = pic:new{x = stage.super[player].frame.x,
		y = stage.super[player].frame.y, image = player.super_images.word}
	player.super_block = {}
	player.super_partial = {}
	player.super_glow = {}
	for i = 1, 4 do 
		player.super_block[i] = pic:new{x = stage.super[player][i].x,
			y = stage.super[player][i].y, image = player.super_images.full}
		player.super_partial[i] = pic:new{x = stage.super[player][i].x,
			y = stage.super[player][i].y, image = player.super_images.partial}
		player.super_glow[i] = pic:new{x = stage.super[player][i].glow_x,
			y = stage.super[player][i].glow_y, image = player.super_images.glow[i]}

	end
	player.super_glow.full = pic:new{x = stage.super[player][4].glow_x,
		y = stage.super[player][4].glow_y, image = player.super_images.glow[4]}
	player.super_glow.full.scaling = 0
end

-- placeholder, waiting for animations
local function createCharacterAnimation(player)
	player.animation = pic:new{x = stage.character[player.ID].x,
	y = stage.character[player.ID].y, image = player.small_image}
end


local function setupPieces(player)
	player.pieces_per_turn_init = player.pieces_per_turn_init or 1
	player.pieces_per_turn = player.pieces_per_turn_init
	player.pieces_to_get = 1
end

local function setupPies(player)
	player.pie = {}
	for i = 0, 6 do -- 0 and 6 are just sentinels
		player.pie[i] = Pie:new(player, i)
	end
	player.pie[1].damage = 4
end

-- do those things to set up the character. Called at start of match
function character.setup()
	for player in players() do
		player.hand = hand:new(player)
		player.hand:makeInitialPieces()
		setupSuperMeter(player)
		createCharacterAnimation(player)
		setupPieces(player)
		setupPies(player)
	end
end

return character