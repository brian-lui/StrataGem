require 'inits'
require 'lovedebug'
require 'utilities' -- helper functions
stage = require 'stage'  -- playing field area and grid
Gem = require 'gem'
local settings = require 'settings'
local draw = require 'draw'
local music = require 'music'
local particles = require 'particles'
local title = require 'title'
local background = require 'background'
local charselect = require 'charselect'
local inputs = require 'inputs'
local character = require 'character'
local phase = require 'phase'
local lobby = require 'lobby'
local client = require 'client'
local animations = require 'animations'
local UI = require 'uielements'
local sandbox = require 'animationsandbox'

game.version = "64.0"

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
		rng.newSeed(os.time())
		music.setBGM("bgm.mp3", 1)
		frame = 0 -- framecount
		rng.orig_rng_seed = rng.seed -- for debugging
end


function love.draw()
	if game.current_screen == "maingame" then
		if frame % 2 == 0 then canvas[1]:renderTo(draw.drawBackground) end
		canvas[2]:renderTo(draw.drawScreenElements)
		canvas[3]:renderTo(draw.drawGems)
		--canvas[4]:renderTo(draw.drawAnimations)
		canvas[5]:renderTo(draw.drawText)

		love.graphics.draw(canvas[1])
		for i = 2, 4 do
			draw.camera:set(1, 1)
			if game.screenshake_frames > 0 then
				draw.screenshake(screenshake_vel)
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
		particles.update(dt) -- variable fps
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
	stage.grid:reset()
	particles.reset()
	AllGemPlatforms = {}
	if seed then rng.newSeed(seed) end
	side = side or 1
	local function setPlayerToCharacter(player, char)
		local temp_defaults = deepcpy(character.defaults)
		local temp_char = deepcpy(character[char])
		for k, v in pairs(temp_defaults) do player[k] = v end
		for k, v in pairs(temp_char) do player[k] = v end
	end
	setPlayerToCharacter(p1, char1)
	setPlayerToCharacter(p2, char2)

	if side == 1 then
		game.me_player, game.them_player = p1, p2
		print("You are PLAYER 1. This will be graphicalized soon")
	elseif side == 2 then
		game.me_player, game.them_player = p2, p1
		print("You are PLAYER 2. This will be graphicalized soon")
	else
		print("Sh*t")
	end

	background.current = bkground
	background.current.reset()

	game.type = gametype
	p1.cur_mp, p2.cur_mp = 0, 0
	character.setup()
	game.current_screen = "maingame"
end

function love.keypressed(key)
	if key == "escape" then love.event.quit() end
	if key == "t" then
		stage.grid:addBottomRow(p1)
		for gem in stage.grid:gems() do
			gem.x = gem.target_x
			gem.y = gem.target_y
		end
	end
	if key == "y" then
		stage.grid:addBottomRow(p2)
		for gem in stage.grid:gems() do
			gem.x = gem.target_x
			gem.y = gem.target_y
		end
	end
	if key == "q" then reallyprint(love.filesystem.getSaveDirectory()) end
	if key == "a" then game.time_to_next = 1 end
	if key == "s" then local hand = require 'hand' p1.hand:addDamage(1) end
	if key == "d" then local hand = require 'hand' p2.hand:addDamage(1) end
	if key == "f" then
		p1.cur_mp = math.min(p1.cur_mp + 20, p1.MAX_MP)
		p2.cur_mp = math.min(p2.cur_mp + 20, p2.MAX_MP)
	end
	--if key == "g" then sandbox.g() end
	--if key == "b" then sandbox.b() end
	--if key == "h" then sandbox.h() end
	--if key == "n" then sandbox.n() end
	--if key == "j" then sandbox.j() end
	--if key == "m" then sandbox.m() end
	if key == "k" then canvas[6]:renderTo(function() love.graphics.clear() end) end
	if key == "z" then startGame("1P", "heath", "walter", Background.Starfall, nil, 1) end
	if key == "x" then
		p1.cur_mp = 64
		--p2.cur_mp = 20
	end
	if key == "c" then
		local pic = require 'pic'
		local image = require 'image'
		local temp = pic:new{x = stage.width * 0.5, y = stage.height * 0.5, image = image.red_gem}
		AllParticles.PieEffects[ID.particle] = temp
		temp.update = temp.greatupdate
		local asdf = {{function(a) print(a) end, "a"}, {function(b) print(b) end, "b"}}
		local newbluegem = function()
			local x, y = temp.x, temp.y
			local blue = pic:new{x = x, y = y, image = image.blue_gem}
			blue.update = blue.greatupdate
			AllParticles.PieEffects[ID.particle] = blue
		end
		local during = {10, 5, newbluegem}
		temp:moveTo{x = 300, y = 200, duration = 120, exit = asdf, during = during}
		queue.add(10, temp.moveTo, temp, {x = 600, y = 450, duration = 60, easing = "outQuart"})
	end
	if key == "v" then
		debugTool.printSummaryState(stage.grid, p1, p2)
	end
	if key == "b" then
		n(8, 7, "G")
		n(8, 6, "G")
		n(7, 5, "G")
		n(8, 5)
		n(8, 4)
		n(7, 3)
		n(8, 3, "Y")
		n(8, 2, "Y")
	end
	if key == "n" then
		n(8, 2, "G")
		n(8, 4, "G")
		n(8, 5, "G")
		n(7, 5, "G")
		n(8, 6, "R")
	end
end

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
	stage.grid[row][column].gem:addOwner(1)
end

--game.current_screen = "animation_testing"
--sandbox.g()

--local background = require 'background'
--startGame("1P", character.heath, character.walter, background.list[1].background, nil, 1)
