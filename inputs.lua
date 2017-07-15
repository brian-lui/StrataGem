-- require backgrounds
local charselect = require 'charselect'
--local character = require 'character'
local stage = game.stage
local title = require 'title'

-------------------------------------------------------------------------------
-------------------------- MOUSE HANDLER / MAINGAME ---------------------------
-------------------------------------------------------------------------------
local mouseHandler = {}

function mouseHandler.maingameClick(x, y)
	local player = game.me_player
	mouse.down = true

	if game.phase == "Action" then
		mouse.last_clicked_frame = frame
		mouse.last_clicked_x = x
		mouse.last_clicked_y = y

		for i = 1, player.hand_size do
			if player.hand[i].piece and pointIsInRect(x, y, player.hand[i].piece:getRect()) then
				player.hand[i].piece:select()
			end
		end

		if pointIsInRect(x, y, unpack(stage.super_click[player.ID])) then
			player.super_clicked = true
		end
	end
end

function mouseHandler.maingameRelease(x, y)
	local player = game.me_player
	if mouse.down then
		mouse.down = false

		if game.active_piece then
			local quickclick = frame - mouse.last_clicked_frame < mouse.QUICKCLICK_FRAMES
			local nomove = math.abs(x - mouse.last_clicked_x) < stage.width * mouse.QUICKCLICK_MAX_MOVE and
				math.abs(y - mouse.last_clicked_y) < stage.height * mouse.QUICKCLICK_MAX_MOVE
			game.active_piece:deselect()
			if quickclick and nomove then game.active_piece:rotate() end

		elseif player.super_clicked and pointIsInRect(x, y, unpack(stage.super_click[player.ID])) then
			player:super()
		end
	end
	player.super_clicked = false
	game.active_piece = false
end

function mouseHandler.maingameMove(x, y)
	if mouse.down and game.active_piece and game.phase == "Action" then
		game.active_piece:moveTo{x = x, y = y}
	end
end

---------------------------- MOUSE HANDLER / TITLE ----------------------------
function mouseHandler.titleClick(x, y)
	if not mouse.down then title.handleClick(x, y) end
	mouse.down = true
end

function mouseHandler.titleRelease(x, y)
	if mouse.down then title.handleRelease(x, y) end
	mouse.down = false
end

function mouseHandler.titleMove(x, y)
	title.handleMove(x, y)
end

---------------------------- MOUSE HANDLER / LOBBY ----------------------------
function mouseHandler.lobbyClick(x, y)
	if not mouse.down then lobby.handleClick(x, y) end
	mouse.down = true
end

function mouseHandler.lobbyRelease(x, y)
	if mouse.down then lobby.handleRelease(x, y) end
	mouse.down = false
end

function mouseHandler.lobbyMove(x, y)
	lobby.handleMove(x, y)
end

---------------------- MOUSE HANDLER / CHARACTER SELECT -----------------------
function mouseHandler.charselectClick(x, y)
	if not mouse.down then charselect.handleClick(x, y) end
	mouse.down = true
end

function mouseHandler.charselectRelease(x, y)
	if mouse.down then charselect.handleRelease(x, y) end
	mouse.down = false
end

function mouseHandler.charselectMove(x, y)
	charselect.handleMove(x, y)
end

-- add a function to the mouse table in inits.lua
function mouse.isOnLeft()
	return mouse.x < stage.x_mid
end


---------------------- MOUSE HANDLER / ANIMATION TESTING -----------------------
function mouseHandler.animation_testingClick(x, y) end
function mouseHandler.animation_testingRelease(x, y) end
function mouseHandler.animation_testingMove(x, y) end


return mouseHandler
