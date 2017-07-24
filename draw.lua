local love = _G.love
require 'utilities'
local anims = require 'anims'
local image = require 'image'
local stage = game.stage
local animations = require 'animations'
local UI = require 'uielements'

local draw = {}

-- camera manipulations
draw.camera = {
	x = 0,
	y = 0,
	scaleX = 1,
	scaleY = 1,
	rotation = 0
}

function draw.camera:set(parallax_x, parallax_y)
	love.graphics.push()
	love.graphics.rotate(-self.rotation)
	love.graphics.scale(1 / self.scaleX, 1 / self.scaleY)
	love.graphics.translate(-self.x * parallax_x, -self.y * parallax_y)
end

function draw.camera:unset()
	love.graphics.pop()
end

function draw.camera:move(dx, dy)
	self.x = self.x + (dx or 0)
	self.y = self.y + (dy or 0)
end

function draw.camera:rotate(dr)
	self.rotation = self.rotation + dr
end

function draw.camera:scale(sx, sy)
	sx = sx or 1
	self.scaleX = self.scaleX * sx
	self.scaleY = self.scaleY * (sy or sx)
end

function draw.camera:setPosition(x, y)
	self.x = x or self.x
	self.y = y or self.y
end

function draw.camera:setScale(sx, sy)
	self.scaleX = sx or self.scaleX
	self.scaleY = sy or self.scaleY
end

-- screenshake effect
function draw.screenshake(shake)
	shake = shake or 6
	local h_displacement = shake * (frame % 7 / 2 + frame % 13 / 4 + frame % 23 / 6 - 5)
	local v_displacement = shake * (frame % 5 * 2/3 + frame % 11 / 4 + frame % 17 / 6 - 5)
	draw.camera:setPosition(h_displacement, v_displacement)
end

-- TODO: De-globalize Background
-- background and background effects
function draw.drawBackground()
	love.graphics.clear()
	Background.current.drawImages()
end

local function numberToImage(num, color) -- color is char, white, red, timer
	return image.number[color][num]
end

-- draw all the non-gem screen elements: super bar, sprite
function draw.drawScreenElements()
	love.graphics.clear()

	-- under-platform trails
	for _, v in pairs(AllParticles.PlatformTinyStar) do v:draw() end
	for _, v in pairs(AllParticles.PlatformStar) do v:draw() end

	UI.tub_img:draw() -- tub
	UI.timer:draw()	-- timer bar

	for player in game:players() do
		anims.drawBurst(player) -- burst meter
		anims.drawSuper(player) -- super meter
		player.animation:draw(flip) -- sprite
	end

end

local function blockBottomGemRow()
-- stencil function to hide gems in bottom row
-- makes it look nicer when gems are generated and push up from the bottom
	local x = (stage.grid.x[0] + stage.grid.x[1]) / 2
	local y = (stage.grid.y[stage.grid.rows] + stage.grid.y[stage.grid.rows + 1]) / 2
	local width = stage.grid.x[stage.grid.columns] - stage.grid.x[0]
	local height = stage.gem_width
	love.graphics.rectangle("fill", x, y, width, height)
end

-- draw gems and related objects (platforms, particles)
function draw.drawGems()
	love.graphics.clear()

	-- gem platforms
	for player in game:players() do
		for i = 0, #player.hand do
			if player.hand[i].platform then
				player.hand[i].platform:draw()
			end
		end
	end

	-- under-gem particles
	for _, instance in pairs(AllParticles.WordEffects) do instance:draw() end
	for _, instance in pairs(AllParticles.Dust) do instance:draw() end
	for _, instance in pairs(AllParticles.Pop) do instance:draw() end


	-- hand gems and pending-garbage gems
	for player in game:players() do
		for i = 1, player.hand_size do
			if player.hand[i].piece and player.hand[i].piece ~= game.active_piece then
				for j = 1, player.hand[i].piece.size do
						player.hand[i].piece:draw()
				end
			end
		end
		for i = 1, #player.hand.garbage do player.hand.garbage[i]:draw() end
	end

	-- grid gems
	love.graphics.push("all")
		love.graphics.stencil(blockBottomGemRow, "replace", 1)
		love.graphics.setStencilTest("equal", 0)
		for gem, r, c in stage.grid:gems() do
			if game.phase == "Action" and r <= 6 then
				gem:draw(nil, nil, {255, 255, 255, 192})
			else
				gem:draw()
			end
		end
		love.graphics.setStencilTest()
	love.graphics.pop()

	-- over-gem particles
	for _, v in pairs(AllParticles.SuperParticles) do v:draw() end
	for _, v in pairs(AllParticles.DamageTrail) do v:draw() end
	for _, v in pairs(AllParticles.Damage) do v:draw() end
	for _, v in pairs(AllParticles.ExplodingGem) do v:draw() end
	for _, v in pairs(AllParticles.PieEffects) do v:draw() end
	for _, v in pairs(AllParticles.CharEffects) do v:draw() end
	for i = 1, 3 do
		for _, v in pairs(AllParticles.SuperFreezeEffects) do
			if v.draw_order == i then v:draw() end
		end
	end

	-- draw the gem when it's been grabbed by the player
	if game.active_piece then
		anims.showShadows(game.active_piece)
		game.active_piece:draw()
		anims.showX(game.active_piece)
	end

	-- over-dust
	for _, v in pairs(AllParticles.OverDust) do v:draw() end

	-- exploded platform pieces
	for _, v in pairs(AllParticles.ExplodingPlatform) do v:draw() end
	
	-- uptween gems
	for _, v in pairs(AllParticles.UpGem) do v:draw() end

end

-- draw text items
function draw.drawText()
	love.graphics.clear()

	-- words
	for _, v in pairs(AllParticles.Words) do v:draw() end

	-- debug row/column display
	love.graphics.push("all")
		love.graphics.setColor(0, 255, 0)
		for r = 0, stage.grid.rows + 1 do
			love.graphics.print(r, 200, stage.grid.y[r])
		end
		for c = 0, stage.grid.columns + 1 do
			love.graphics.print(c, stage.grid.x[c], 200)
		end
	love.graphics.pop()

	-- debug: top right HUD
	if debugTool.overlay then
		love.graphics.push("all")
			love.graphics.setColor(255, 255, 255)
			local toprint = debugTool.overlay()
			love.graphics.printf(toprint, 0, 40, 1000, "right")
		love.graphics.pop()
	end

	-- debug: gem owner overlays
	if debugTool.drawGemOwners then
		love.graphics.push("all")
			love.graphics.setColor(0, 0, 0)
			love.graphics.setFont(FONT.REGULAR)
			for gem in stage.grid:gems() do
				love.graphics.print(gem.owner, gem.x, gem.y)
			end
		love.graphics.pop()
	end

	-- debug: particle destination overlays
	if debugTool.drawParticleDestinations then
		love.graphics.push("all")
			love.graphics.setColor(0, 0, 0)
			love.graphics.setFont(FONT.REGULAR)
			for _, p in pairs(AllParticles.Damage) do
				love.graphics.print(p.final_loc_idx, p.x, p.y)
			end
		love.graphics.pop()
	end

	-- debug: grid gamestate
	if debugTool.drawGamestate then
		local toprint = debugTool.drawGamestateFunc(stage.grid)
		love.graphics.push("all")
			love.graphics.setColor(0, 0, 0)
			love.graphics.setFont(FONT.REGULAR)
			love.graphics.print(toprint, 50, 400)
		love.graphics.pop()
	end
end

function draw.drawAnimations()
	love.graphics.clear(255, 255, 255)
	animations:drawAll()
end

function draw.drawAnimationTracers()
	animations:drawTracers()
end

return draw
