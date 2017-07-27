local love = _G.love
require 'inits'
require 'lovedebug'
require 'utilities' -- helper functions

_G.game = require "game"()	-- TODO: de-globalize
local game = _G.game
local stage = game.stage
local particles = game.particles
local sound = require 'sound'
--local Gem = require "gem"
--local settings = require 'settings'
--local Character = require "character"
local draw = require 'draw'
local music = require 'music'
local title = require 'title'
local background = require 'background'
local charselect = require 'charselect'
local inputs = require 'inputs'
local phase = require 'phase'
local lobby = require 'lobby'
local client = require 'client'
local animations = require 'animations'
local UI = require 'uielements'
-- local sandbox = require 'animationsandbox'

-- build screen
love.window.setMode(window.width, window.height)
love.window.setTitle("StrataGem")

-- build canvas layers
local canvas = {}
for i = 1, 6 do
	canvas[i] = love.graphics.newCanvas(stage.width, stage.height)
end

queue = {}
function queue.add(frames, func, ...)
	assert(frames % 1 == 0 and frames >= 0, "non-integer or negative queue received")
	local a = frame + frames
	queue[a] = queue[a] or {}
	table.insert(queue[a], {func, {...}})
end

function queue.update()
	local do_today = queue[frame]
	if do_today then
		for i = 1, #do_today do
			local func, args = do_today[i][1], do_today[i][2]
			func(unpack(args))
		end
		queue[frame] = nil
	end
end

time = {step = 1/60, bucket = 0}
function time.dip(logic_function)
--[[ This is a wrapper to do stuff at 60hz. We want the logic stuff to be at
	60hz, but the drawing can be at whatever! So each love.update runs at
	unbounded speed, and then adds dt to bucket. When bucket is larger
	than 1/60, it runs the logic functions until bucket is less than 1/60,
	or we reached the maximum number of times to run the logic this cycle. --]]
	for i = 1, 4 do -- run a maximum of 4 logic cycles per love.update cycle
		if time.bucket >= time.step then
			logic_function()
			frame = frame + 1
			time.bucket = time.bucket - time.step
		end
	end
end

function love.load()
	love.audio.setPosition(0, 1, 0)
	music.setBGM("buzz.ogg", 1)
	frame = 0 -- framecount
end


function love.draw()
	if game.current_screen == "maingame" then
		if frame % 2 == 0 then
			canvas[1]:renderTo(draw.drawBackground)
		end
		canvas[2]:renderTo(draw.drawScreenElements)
		canvas[3]:renderTo(draw.drawGems)
		--canvas[4]:renderTo(draw.drawAnimations)
		canvas[5]:renderTo(draw.drawText)

		love.graphics.draw(canvas[1])
		for i = 2, 4 do
			draw.camera:set(1, 1)
			if game.screenshake_frames > 0 then
				draw.screenshake(game.screenshake_vel)
			else
				draw.camera:setPosition(0, 0)
			end
			love.graphics.draw(canvas[i])
			draw.camera:unset()
		end
		love.graphics.draw(canvas[5])

	elseif game.current_screen == "title" then
		canvas[1]:renderTo(title.drawBackground)
		canvas[2]:renderTo(title.drawScreenElements)
		love.graphics.draw(canvas[1])
		love.graphics.draw(canvas[2])

	elseif game.current_screen == "charselect" then
		canvas[1]:renderTo(charselect.drawBackground)
		canvas[2]:renderTo(charselect.drawScreenElements)
		love.graphics.draw(canvas[1])
		love.graphics.draw(canvas[2])

	elseif game.current_screen == "lobby" then
		canvas[1]:renderTo(lobby.drawBackground)
		canvas[2]:renderTo(lobby.drawScreenElements)
		love.graphics.draw(canvas[1])
		love.graphics.draw(canvas[2])

	elseif game.current_screen == "animation_testing" then
		canvas[1]:renderTo(draw.drawAnimations)
		canvas[6]:renderTo(draw.drawAnimationTracers)
		love.graphics.draw(canvas[1])
		love.graphics.draw(canvas[6])
	end
end

function love.update(dt)
	client.update()
	if game.current_screen == "maingame" then
		time.dip(function() phase:run(time.step) end)
		particles:update(dt) -- variable fps
		background.current.update() -- variable fps
		UI.timer:update()
		animations:updateAll(dt)
		game.screenshake_frames = math.max(0, game.screenshake_frames - 1)
		time.bucket = time.bucket + dt

		-- Testing trail stars
		-- TODO: put this in the right place
		if frame % 10 == 0 then
			particles.platformStar:generate(p1, "TinyStar", 0.05, 0.2, 0.29)
			particles.platformStar:generate(p2, "TinyStar", 0.95, 0.8, 0.71)
		end
		if frame % 42 == 0 then
			particles.platformStar:generate(p1, "Star", 0.05, 0.21, 0.28)
			particles.platformStar:generate(p2, "Star", 0.95, 0.79, 0.72)
		end

	elseif game.current_screen == "title" then
		title.drawBackground()
		title.update(dt)

	elseif game.current_screen == "charselect" then
		charselect.drawBackground()
		charselect.update(dt)

	elseif game.current_screen == "lobby" then
		lobby.drawBackground()
		lobby.update()

	elseif game.current_screen == "animation_testing" then
		animations:updateAll(dt)
		queue.update()
		time.bucket = time.bucket + dt
		time.dip(function() end)
	end
end

function startGame(gametype, char1, char2, bkground, seed, side)
	ID:reset()

	game:reset()
	sound:reset()
	stage.grid:reset()
	particles:reset()
	if seed then
		game.rng:setSeed(seed)
	end

	p1 = require("characters." .. char1):new(1, game.stage)
	p2 = require("characters." .. char2):new(2, game.stage)
	p1.enemy = p2
	p2.enemy = p1

	side = side or 1
	if side == 1 then
		game.me_player, game.them_player = p1, p2
		print("You are PLAYER 1. This will be graphicalized soon")
	elseif side == 2 then
		game.me_player, game.them_player = p2, p1
		print("You are PLAYER 2. This will be graphicalized soon")
	else
		print("Sh*t")
	end
	for player in game:players() do player:cleanup() end
	background.current = bkground
	background.current.reset()

	game.type = gametype
	game.current_screen = "maingame"
end

function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "t" then
		stage.grid:addBottomRow(p1)
		for gem in stage.grid:gems() do
			gem.x = gem.target_x
			gem.y = gem.target_y
		end
	elseif key == "y" then
		stage.grid:addBottomRow(p2)
		for gem in stage.grid:gems() do
			gem.x = gem.target_x
			gem.y = gem.target_y
		end
	elseif key == "q" then reallyprint(love.filesystem.getSaveDirectory())
	elseif key == "a" then game.time_to_next = 1
	elseif key == "s" then p1.hand:addDamage(1)
	elseif key == "d" then p2.hand:addDamage(1)
	elseif key == "f" then
		for player in game:players() do
			player.cur_burst = math.min(player.cur_burst + 1, player.MAX_BURST)
			player:addSuper(10000)
			player:resetMP()
		end
	elseif key == "k" then canvas[6]:renderTo(function() love.graphics.clear() end)
	elseif key == "z" then startGame("1P", "heath", "walter", Background.Starfall, nil, 1)
	elseif key == "x" then -- double match
		n(7,1,"R") n(7,2,"G") n(7,3,"B") n(7,4,"Y")
		n(8,1,"R") n(8,2,"G") n(8,3,"B") n(8,4,"Y")
	elseif key == "c" then -- heath big damage super with a R/Y piece
		n(1,1,"B")
		n(2,1,"B")
		n(3,1,"R") n(3,2,"G")
		n(4,1,"Y") n(4,2,"Y")
		n(5,1,"R") n(5,2,"R") n(5,3,"G")
		n(6,1,"B") n(6,2,"G") n(6,3,"B")
		n(7,1,"B") n(7,2,"R") n(7,3,"R")
		n(8,1,"R") n(8,2,"G") n(8,3,"G") n(8,4,"Y")

	elseif key == "v" then -- garbage move up match
		n(7,3,"B") n(7,4,"B") n(7,5,"R") n(7,6,"R") n(7,7,"G")
		n(8,3,"R") n(8,4,"R") n(8,5,"B") n(8,6,"B") n(8,7,"Y")
	elseif key == "b" then -- multimatch
		                                            n(4,6,"R")            n(4,8,"G")
		                                 n(5,5,"R") n(5,6,"B") n(5,7,"B") n(5,8,"R")
		           n(6,3,"G") n(6,4,"R") n(6,5,"B") n(6,6,"Y") n(6,7,"Y") n(6,8,"R")
		n(7,2,"R") n(7,3,"R") n(7,4,"G") n(7,5,"B") n(7,6,"G") n(7,7,"G") n(7,8,"Y")
		n(8,2,"Y") n(8,3,"Y") n(8,4,"R") n(8,5,"G") n(8,6,"B") n(8,7,"B") n(8,8,"R")
	elseif key == "n" then -- heath super test
		n(6,1,"B")
		n(7,1,"Y") n(7,2,"Y")
		n(8,1,"G") n(8,2,"R") n(8,3,"G")
	elseif key == "m" then
		debugTool.drawGemOwners = not debugTool.drawGemOwners
		debugTool.drawParticleDestinations = not debugTool.drawParticleDestinations
		debugTool.drawGamestate = not debugTool.drawGamestate
		debugTool.drawDamage = not debugTool.drawDamage
		debugTool.drawGrid = not debugTool.drawGrid
	elseif key == "," then
		debugTool.setOverlay(function() return p1.super_meter_image.transparency end)
	elseif key == "." then
		debugTool.toggleSlowdown()
	end

end

-- lol at this placement here
debugTool.setOverlay(function() return game.phase end)


function love.mousepressed(x, y, button, istouch)
	if button == 1 and not mouse.down then -- the primary button
		local click = game.current_screen .. "Click"
		inputs[click](x, y)
	end
end

function love.mousereleased(x, y, button, istouch)
	if button == 1 and mouse.down then -- the primary button
		local click = game.current_screen .. "Release"
		inputs[click](x, y)
	end
end

function love.mousemoved(x, y, dx, dy)
	mouse.x = x
	mouse.y = y
	local click = game.current_screen .. "Move"
	inputs[click](x, y)
end


-- testing!
local gem = require 'gem'

-- rows is from 8 at the top to 1 at the bottom
n = function(row, column, color, owner)
	owner = owner or 0
	if color == "R" or color == "red" then
		color = "Red"
	elseif color == "B" or color == "blue" then
		color = "Blue"
	elseif color == "G" or color == "green" then
		color = "Green"
	elseif color == "Y" or color == "yellow" then
		color = "Yellow"
	else
		color = "Red"
	end
	if type(row) ~= "number" or type(column) ~= "number" then
		print("row or column not a number!")
		return
	end
	if row % 1 ~= 0 or column % 1 ~= 0 then
		print("row or column not an integer!")
		return
	end
	if row < 1 or row > 8 then
		print("row out of bounds! 1 = bottom, 8 = top")
		return
	end
	if column < 1 or column > 8 then
		print("column out of bounds!")
		return
	end

	row = row + 6
	local x, y = stage.grid.x[column], stage.grid.y[row]
	local gem_color = gem[color.."Gem"]
	stage.grid[row][column].gem = gem_color:new(x, y)
	if owner > 0 then stage.grid[row][column].gem:addOwner(owner) end
end

-- TODO: Remove this bit and animationsandbox.lua
--game.current_screen = "animation_testing"
--sandbox.g()

--local background = require 'background'
--startGame("1P", character.heath, character.walter, background.list[1].background, nil, 1)
