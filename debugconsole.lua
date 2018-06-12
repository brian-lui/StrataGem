local love = _G.love
local FONT = _G.FONT
local common = require "class.commons" -- class support
local pointIsInRect = require "utilities".pointIsInRect
local image = require "image"
local Gem = require "gem"
local DebugConsole = {}

function DebugConsole:init(game)
	assert(game, "Game object not received!")
	self.game = game
	self.grid = game.grid
	self.stage = game.stage
	self.phase = game.phase
	self.screencap_number = 0
	self.prints = {}
	self.PRINT_DURATION = 240 -- frames to display prints
end

-- makes the print also wrie to debug.txt and display
function DebugConsole:replacePrint()
	love.filesystem.remove("debug.txt")
	local reallyprint = print
	function print(...)
		reallyprint(self.game.frame or "", ...)
		local args = {...}
		for i = 1, #args do
			if type(args[i]) == "table" then args[i] = "table"
			elseif args[i] == true then args[i] = "true"
			elseif args[i] == false then args[i] = "false"
			elseif args[i] == nil then args[i] = "nil"
			elseif type(args[i]) == "userdata" then args[i] = "userdata"
			elseif type(args[i]) == "function" then args[i] = "function"
			elseif type(args[i]) == "thread" then args[i] = "thread"
			end
		end
		local write = table.concat(args, ", ")
		love.filesystem.append("debug.txt", write .. "\n")
		self.prints[#self.prints+1] = {self.game.frame, write}
	end
end

function DebugConsole:setDisplay(params)
	for k, v in pairs(params) do self[k] = v end
end

function DebugConsole:setDefaultDisplayParams()
	local game = self.game
	local phase = self.phase
	local params = {
		display_all = true,
		display_prints = true,
		display_gem_info = false,
		display_gem_owners = true,
		display_particle_destinations = true,
		display_gamestate = true,
		display_damage = true,
		display_grid = true,
		display_turn_number = true,
		display_game_frame = true,
		display_overlays = true,
		overlay_middle_function = function()
			if game.current_phase == "Pause" then
				return "Pausing at " .. phase.current_phase_for_debug_purposes_only .. ", " ..
				phase.frames_until_next_phase .. "\nGarbage this round: " .. phase.garbage_this_round
			else
				return game.current_phase
			end
		end,
		overlay_right_function = function()
			return "Garbage this round: " .. phase.garbage_this_round
		end,
		overlay_left_function = function()
			return "Damage particles: " .. game.particles:getNumber("Damage")
		end,
		save_screencaps = true,
		is_pause_mode_on = false,
	}
	self:setDisplay(params)
end

function DebugConsole:_drawGrid()
	local grid = self.grid
	love.graphics.push("all")
		love.graphics.setFont(FONT.MEDIUM)
		love.graphics.setColor(0, 255, 0)
		for r = 1, grid.ROWS + 1 do
			love.graphics.print(r, 200, grid.y[r])
		end
		for c = 0, grid.COLUMNS + 1 do
			love.graphics.print(c, grid.x[c], 200)
		end
	love.graphics.pop()
end

function DebugConsole:_drawGemInfo()
	local grid = self.grid
	for gem in grid:gems() do
		love.graphics.print("ROW:" .. gem.row, gem.x - gem.width * 0.4, gem.y - gem.height * 0.2)
		love.graphics.print("COL:" .. gem.column, gem.x - gem.width * 0.4, gem.y)
		if gem.is_in_a_horizontal_match then
			love.graphics.print("H", gem.x - gem.width * 0.2, gem.y + gem.height * 0.2)
		end
		if gem.is_in_a_vertical_match then
			love.graphics.print("V", gem.x + gem.width * 0.2, gem.y + gem.height * 0.2)
		end
	end
end

function DebugConsole:_drawGemOwners()
	local grid = self.grid
	for gem in grid:gems() do
		love.graphics.push("all")
			local y_start, height = gem.y - gem.height * 0.5, gem.height
			if gem.owner == 1 then
				love.graphics.setColor(100, 0, 200, 160)
				love.graphics.rectangle("fill", gem.x - gem.width * 0.5, y_start, gem.width * 0.5, height)
			elseif gem.owner == 2 then
				love.graphics.setColor(255, 153, 51, 230)
				love.graphics.rectangle("fill", gem.x, y_start, gem.width * 0.5, height)
			elseif gem.owner == 3 then
				love.graphics.setColor(160, 160, 160, 255)
				love.graphics.rectangle("fill", gem.x - gem.width * 0.5, y_start, gem.width, height * 0.5)
			end
			if gem.flag_match_originator then
				if gem.owner == 1 then
					love.graphics.setColor(255, 0, 255, 255)
				elseif gem.owner == 2 then
					love.graphics.setColor(255, 255, 0, 255)
				end
				love.graphics.circle("fill", gem.x, gem.y, 10)
			end
		love.graphics.pop()
	end
end

function DebugConsole:_drawParticleDestinations()
	local particles = self.game.particles
	for _, p in pairs(particles.allParticles.Damage) do
		love.graphics.print(p.final_loc_idx, p.x, p.y)
	end
end

function DebugConsole:_drawGamestate()
	local grid = self.grid
	love.graphics.push("all")
		love.graphics.setFont(FONT.MEDIUM)
		local toprint = {}
		local i = 1
		local colors = {red = "R", blue = "B", green = "G", yellow = "Y"}
		for row = grid.PENDING_START_ROW, grid.BASIN_END_ROW do
			for col = 1, 8 do
				toprint[i] = grid[row][col].gem and colors[grid[row][col].gem.color] or " "
				i = i + 1
			end
			toprint[i] = "\n"
			i = i + 1
		end
		love.graphics.print(table.concat(toprint), 50, 400)
	love.graphics.pop()
end

function DebugConsole:_drawDamage()
	local game = self.game
	local particles = game.particles
	love.graphics.push("all")
		local p1hand, p2hand = game.p1.hand, game.p2.hand

		local p1_destroyed_damage_particles = particles:getCount("destroyed", "Damage", 2)
		local p1_destroyed_healing_particles = particles:getCount("destroyed", "Healing", 1)
		local p1_displayed_damage = (game.p1.hand.turn_start_damage + p1_destroyed_damage_particles/3 - p1_destroyed_healing_particles/5)

		local p2_destroyed_damage_particles = particles:getCount("destroyed", "Damage", 1)
		local p2_destroyed_healing_particles = particles:getCount("destroyed", "Healing", 2)
		local p2_displayed_damage = (game.p2.hand.turn_start_damage + p2_destroyed_damage_particles/3 - p2_destroyed_healing_particles/5)

		local p1print = "Actual damage " .. p1hand.damage .. "\nShown damage " .. p1_displayed_damage
		local p2print = "Actual damage " .. p2hand.damage .. "\nShown damage " .. p2_displayed_damage

		love.graphics.setFont(FONT.SLIGHTLY_BIGGER)
		love.graphics.print(p1print, p1hand[2].x - 200, 900)
		love.graphics.print(p2print, p2hand[2].x - 100, 900)
	love.graphics.pop()
end

function DebugConsole:_drawTurnNumber()
	local toprint = "Turn: " .. self.game.turn
	local stage = self.stage
	love.graphics.push("all")
		love.graphics.setFont(FONT.SLIGHTLY_BIGGER)
		love.graphics.printf(toprint, stage.width * 0.01, stage.height * 0.965, stage.width, "left")
	love.graphics.pop()
end

function DebugConsole:_drawGameFrame()
	local toprint = "Frame: " .. self.game.frame
	local stage = self.stage
	love.graphics.push("all")
		love.graphics.setFont(FONT.SLIGHTLY_BIGGER)
		love.graphics.printf(toprint, 0, stage.height * 0.965, stage.width * 0.99, "right")
	love.graphics.pop()
end

function DebugConsole:_drawOverlays()
	local stage = self.stage
	love.graphics.push("all")
		love.graphics.setFont(FONT.SLIGHTLY_BIGGER)
		love.graphics.printf(self.overlay_left_function(), stage.width * 0.01, stage.height * 0.93, stage.width, "left")
		love.graphics.printf(self.overlay_middle_function(), 0, stage.height * 0.965, stage.width, "center")
		love.graphics.printf(self.overlay_right_function(), 0, stage.height * 0.93, stage.width * 0.99, "right")
	love.graphics.pop()
end

function DebugConsole:_drawPrints()
	local game = self.game
	local y = 30
	local Y_STEP = 30
	love.graphics.push("all")
		love.graphics.setFont(FONT.MEDIUM)
		for i = #self.prints, 1, -1 do
			local frame_diff = game.frame - self.prints[i][1]
			local frame_percentage = frame_diff / self.PRINT_DURATION
			if frame_percentage > 1 then
				table.remove(self.prints, i)
			else
				local toprint = self.prints[i][1] .. ":" .. self.prints[i][2]
				local x = 400 + frame_diff * 2
				love.graphics.print(toprint, x, y)
				y = y + Y_STEP
			end
		end
	love.graphics.pop()
end

function DebugConsole:draw()
	if self.display_all then
		love.graphics.push("all")
			love.graphics.setColor(0, 0, 0)
			love.graphics.setFont(FONT.REGULAR)
			if self.display_grid then self:_drawGrid() end
			if self.display_overlays then self:_drawOverlays() end
			if self.display_gem_info then self:_drawGemInfo() end
			if self.display_gem_owners then self:_drawGemOwners() end
			if self.display_particle_destinations then self:_drawParticleDestinations() end
			if self.display_gamestate then self:_drawGamestate() end
			if self.display_damage then self:_drawDamage() end
			if self.display_turn_number then self:_drawTurnNumber() end
			if self.display_game_frame then self:_drawGameFrame() end
			if self.display_prints then self:_drawPrints() end
		love.graphics.pop()
	end
end

-- save screenshot to disk
function DebugConsole:saveScreencap()
	if self.save_screencaps then
		self.screencap_number = self.screencap_number + 1
		local screenshot = love.graphics.newScreenshot()
		local filename = "turn" .. self.game.turn .. "cap" .. self.screencap_number .. ".png"
		screenshot:encode("png", filename)
		print("Saved file: " .. filename)
	end
end

function DebugConsole:resetScreencapNum()
	self.screencap_number = 0
end

-- TODO: able to destroy and create gems
function DebugConsole:swapGridGem(x, y)
	local grid = self.grid
	for col in grid:cols() do
		for row = grid.BASIN_START_ROW, grid.BASIN_END_ROW do
			local gem = grid[row][col].gem
			if gem then
				if pointIsInRect(x, y, gem:getRect()) then
					if gem.color == "red" then
						gem:setColor("blue")
					elseif gem.color == "blue" then
						gem:setColor("green")
					elseif gem.color == "green" then
						gem:setColor("yellow")
					else
						grid[row][col].gem = false
					end
					return
				end
			else
				local start_x = grid.x[col] - 0.5 * image.GEM_WIDTH
				local start_y = grid.y[row] - 0.5 * image.GEM_HEIGHT
				local w = image.GEM_WIDTH
				local h = image.GEM_HEIGHT
				if pointIsInRect(x, y, start_x, start_y, w, h) then
					grid[row][col].gem = Gem:create{
						game = self.game,
						x = grid.x[col],
						y = grid.y[row],
						color = "red",
					}
					grid[row][col].gem:updateGrid(row, col)
					return
				end
			end
		end
	end
end


return common.class("DebugConsole", DebugConsole)
