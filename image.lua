local love = _G.love

local gem_colors = {"red", "blue", "green", "yellow"}

-- A table {name, file location} of all the images to be gradually loaded
local image_data = {}

local buttons = {
	"vscpu", "vscpupush", "netplay", "netplaypush", "back", "backpush",
	"details", "detailspush", "start", "startpush", "backgroundleft", "backgroundright",
	"lobbycreatenew", "lobbyqueueranked", "lobbycancelsearch", "pause", "stop",
	"settings", "settingspush", "yes", "yespush", "no", "nopush", "quit", "quitpush"
}

local unclickables = {
	"titlelogo", "lobbygamebackground", "lobbysearchingnone", "lobbysearchingranked",
	"selectstageborder", "settingsframe", "suretoquit", "pausetext"
}

local gem = {
	"red", "blue", "green", "yellow",
	"explode_red", "explode_blue", "explode_green", "explode_yellow",
	"grey_red", "grey_blue", "grey_green", "grey_yellow",
	"pop_red", "pop_blue", "pop_green", "pop_yellow",
}
local words = {
	"doublecast", "rush", "ready", "go", "gameoverthanks", "norushonecolumn",
	"norushfull", "doublecastcloudh", "doublecastcloudv", "rushcloudh",
	"rushcloudv", "rushparticle", "gostar",
}

local ui = {
	"basin", "platform_gold", "platform_silver", "platform_red", "redx",
	"timer_gauge", "timer_bar", "timer_1", "timer_2", "timer_3",
	"super_text_red", "super_text_blue", "super_text_green", "super_text_yellow",
	"super_empty_red", "super_empty_blue", "super_empty_green", "super_empty_yellow",
	"super_full_red", "super_full_blue", "super_full_green", "super_full_yellow",
	"super_glow_red", "super_glow_blue", "super_glow_green", "super_glow_yellow",
	"burst_gauge_silver", "burst_gauge_gold",
	"burst_part_red", "burst_part_blue", "burst_part_green", "burst_part_yellow",
	"burst_full_red", "burst_full_blue", "burst_full_green", "burst_full_yellow",
	"burst_partglow_red", "burst_partglow_blue", "burst_partglow_green", "burst_partglow_yellow",
	"burst_fullglow_red", "burst_fullglow_blue", "burst_fullglow_green", "burst_fullglow_yellow",
	"starpiece1", "starpiece2", "starpiece3", "starpiece4",
}

local particles = {
	"star_normal_silver1", "star_normal_silver2", "star_normal_silver3",
	"star_normal_gold1", "star_normal_gold2", "star_normal_gold3",
	"star_tiny_silver1", "star_tiny_silver2", "star_tiny_silver3",
	"star_tiny_gold1", "star_tiny_gold2", "star_tiny_gold3",
	"particle_red_1", "particle_red_2", "particle_red_3",
	"particle_blue_1", "particle_blue_2", "particle_blue_3",
	"particle_green_1", "particle_green_2", "particle_green_3",
	"particle_yellow_1", "particle_yellow_2", "particle_yellow_3",
	"particle_healing_1", "particle_healing_2", "particle_healing_3",
	"particle_super_red", "particle_super_blue", "particle_super_green", "particle_super_yellow",
	"trail_red", "trail_blue", "trail_green", "trail_yellow", "trail_healing",
}
for _, item in pairs(particles) do
	image_data[item] = "images/particles/" .. item .. ".png"
end

local selectablechars = {
	"heath", "walter", "gail", "holly", "wolfgang",	"hailey", "diggory",
	"buzz", "ivy", "joy", "mort", "damon"
}
for _, item in pairs(selectablechars) do
	image_data["charselect_"..item.."char"] = "images/portraits/"..item.."action.png"
	image_data["charselect_"..item.."shadow"] = "images/portraits/"..item.."shadow.png"
	image_data["charselect_"..item.."name"] = "images/charselect/"..item.."name.png"
	image_data["charselect_"..item.."ring"] = "images/charselect/"..item.."ring.png"
end

-- categories to create, in the form [key] = {category}
-- assumes that key is the same as pathname
-- e.g. buttons = buttons will create
-- image_data["buttons_" .. item] = "images/buttons/" .. item .. ".png"
local categories = {
	buttons = buttons,
	unclickables = unclickables,
	words = words,
	ui = ui,
	gem = gem,
}

for str, tbl in pairs(categories) do
	for _, item in pairs(tbl) do
		image_data[str .. "_" .. item] = "images/" .. str .. "/" .. item .. ".png"
	end
end

-- coroutine that yields a single image each time it's called
local function loadImage()
	for k, v in pairs(image_data) do
		coroutine.yield(k, love.graphics.newImage(v))
	end
end
local coroLoadImage = coroutine.create(loadImage)

local load_dt = 0
local load_step = 0.02
local already_loaded = false
-- every load_step seconds it loads a new image and writes it
local LOAD_DT_LIMIT = 500000 -- bytes to load per load_dt
local bytes_used = 0
local function updateLoader(_self, dt)
	load_dt = load_dt + dt
	local proceed = false

	if already_loaded == true then
		proceed = true
	elseif load_dt > load_step then
		proceed = true
		load_dt = load_dt - load_step
	end

	if proceed then
		if coroutine.status(coroLoadImage) == "dead" then
			local count = 0
			for _ in pairs(image_data) do count = count + 1 end
			return count -- stop calling when all loaded
		else
			local _, key, img = coroutine.resume(coroLoadImage)
			if key ~= nil and img ~= nil then
				if rawget(_self, key) then
					already_loaded = true
					updateLoader(_self, 0)
				else
					_self[key] = img
					already_loaded = false
					local w, h = img:getDimensions()
					bytes_used = bytes_used + 4 * w * h + LOAD_DT_LIMIT * 0.3
					if bytes_used < LOAD_DT_LIMIT then
						updateLoader(_self, 0)
					else
						bytes_used = 0
					end
				end
			end
		end
	end
end


local image = {
	updateLoader = updateLoader,
	lookup = {},
	dummy = love.graphics.newImage('images/dummy.png'),
}

-- If an image isn't loaded yet but is called, immediately load it
local fallback = {
	__index = function(t, k)
		print("using fallback for " .. k .. " at:")
		print(image_data[k])
		local img = love.graphics.newImage(image_data[k])
		t[k] = img
		return img
	end
}
setmetatable(image, fallback)

image.GEM_WIDTH = image.gem_red:getWidth()
image.GEM_HEIGHT = image.gem_red:getHeight()

image.dust = {}
for _, c in pairs(gem_colors) do
	for i = 1, 3 do
		-- e.g. image.dust.red1 = love.graphics.newImage('images/particles/reddust1.png')
		image.dust[c..i] = love.graphics.newImage('images/particles/dust_'..c..i..'.png')
	end
end


image.background = {}
image.background.colors = {
	thumbnail = love.graphics.newImage('images/charselect/colorsthumbnail.png'),
	white = love.graphics.newImage('images/backgrounds/colors/white.png'),
	blue = love.graphics.newImage('images/backgrounds/colors/blue.png'),
	red = love.graphics.newImage('images/backgrounds/colors/red.png'),
	green = love.graphics.newImage('images/backgrounds/colors/green.png'),
	yellow = love.graphics.newImage('images/backgrounds/colors/yellow.png'),
}
image.background.starfall = {
	background = love.graphics.newImage('images/backgrounds/starfall/starfall.png'),
	thumbnail = love.graphics.newImage('images/charselect/starfallthumbnail.png'),
	star1 = love.graphics.newImage('images/backgrounds/starfall/star1.png'),
	star2 = love.graphics.newImage('images/backgrounds/starfall/star2.png'),
	star3 = love.graphics.newImage('images/backgrounds/starfall/star3.png'),
	star4 = love.graphics.newImage('images/backgrounds/starfall/star4.png'),
}
image.background.cloud = {
	background = love.graphics.newImage('images/backgrounds/cloud/sky.png'),
	thumbnail = love.graphics.newImage('images/charselect/skythumbnail.png'),
}
image.background.rabbitsnowstorm = {
	background = love.graphics.newImage('images/backgrounds/rabbitsnowstorm/rabbitsnowstorm.png'),
	thumbnail = love.graphics.newImage('images/charselect/rabbitthumbnail.png'),
}
image.background.checkmate = {
	background = love.graphics.newImage('images/backgrounds/rabbitsnowstorm/rabbitsnowstorm.png'),
	thumbnail = love.graphics.newImage('images/charselect/rabbitthumbnail.png'),
}
for i = 0, 9 do
	image.background.checkmate[i] = love.graphics.newImage('images/backgrounds/checkmate/checkmate'..i..'.png')
end


for i = 1, 6 do
	image.background.cloud["bigcloud"..i] =	love.graphics.newImage('images/backgrounds/cloud/bigcloud'..i..'.png')
	image.background.cloud["medcloud"..i] =	love.graphics.newImage('images/backgrounds/cloud/medcloud'..i..'.png')
	image.background.cloud["smallcloud"..i] =	love.graphics.newImage('images/backgrounds/cloud/smallcloud'..i..'.png')
end

function image.lookup.words_ready(size)
	assert(size == "small" or size == "large", "invalid size")
	local ret
	if size == "small" then
		local choice = {
			image.star_tiny_silver1,
			image.star_tiny_silver2,
			image.star_tiny_silver3,
		}
		ret = choice[math.random(#choice)]
	else
		local choice = {
			image.star_normal_silver1,
			image.star_normal_silver2,
			image.star_normal_silver3,
		}
		ret = choice[math.random(#choice)]
	end
	return ret
end

function image.lookup.particle_freq(color)
	local image_num_freq = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 3}
	local image_num = image_num_freq[math.random(#image_num_freq)]
	local image_color = color
	if color == "wild" then image_color = gem_colors[math.random(#gem_colors)] end
	local image_name = "particle_" .. image_color .. "_" .. image_num
	if color == "none" then image_name = "dummy" end
	return image[image_name]
end

function image.lookup.platform_star(player_num, is_tiny)
	assert(player_num == 1 or player_num == 2, "invalid player_num provided")
	local image_name
	local image_num = math.random(3)
	if player_num == 1 then
		image_name = is_tiny and "star_tiny_gold" or "star_normal_gold"
	else
		image_name = is_tiny and "star_tiny_silver" or "star_normal_silver"
	end

	return image[image_name .. image_num]
end

function image.lookup.smalldust(color, big_possible)
	if big_possible ~= false then big_possible = true end
	local star_instead = big_possible and math.random() < 0.05
	if star_instead then
		return image.lookup.stardust(color)
	else
		if color == "red" then
			local tbl = {image.dust.red1, image.dust.red2, image.dust.red3}
			return tbl[math.random(#tbl)]
		elseif color == "blue" then
			local tbl = {image.dust.blue1, image.dust.blue2, image.dust.blue3}
			return tbl[math.random(#tbl)]
		elseif color == "green" then
			local tbl = {image.dust.green1, image.dust.green2, image.dust.green3}
			return tbl[math.random(#tbl)]
		elseif color == "yellow" then
			local tbl = {image.dust.yellow1, image.dust.yellow2, image.dust.yellow3}
			return tbl[math.random(#tbl)]
		elseif color == "none" then
			return image.dummy
		elseif color == "wild" then
			local tbl = {
				image.dust.red1, image.dust.red2, image.dust.red3,
				image.dust.blue1, image.dust.blue2, image.dust.blue3,
				image.dust.green1, image.dust.green2, image.dust.green3,
				image.dust.yellow1, image.dust.yellow2, image.dust.yellow3,
			}
			return tbl[math.random(#tbl)]
		else
			print("image.lookup.smalldust Sucka MC")
			return image.dust.red1
		end
	end
end

function image.lookup.stardust(color)
	if color == "red" then return image.particle_red_1
	elseif color == "blue" then return image.particle_blue_1
	elseif color == "green" then return image.particle_green_1
	elseif color == "yellow" then return image.particle_yellow_1
	elseif color == "none" then return image.dummy
	elseif color == "wild" then
		local tbl = {
			image.particle_red_1,
			image.particle_blue_1,
			image.particle_green_1,
			image.particle_yellow_1,
		}
		return tbl[math.random(#tbl)]
	else
		print("image.lookup.stardust Sucka MC")
		return image.particle_red_1
	end
end

return image
