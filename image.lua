local love = _G.love

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

local gems = {
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
	"starpiece1", "starpiece2", "starpiece3", "starpiece4",

	"super_text_red", "super_text_blue", "super_text_green", "super_text_yellow",
	"super_empty_red", "super_empty_blue", "super_empty_green", "super_empty_yellow",
	"super_full_red", "super_full_blue", "super_full_green", "super_full_yellow",
	"super_glow_red", "super_glow_blue", "super_glow_green", "super_glow_yellow",

	"burst_gauge_silver", "burst_gauge_gold",
	"burst_part_red", "burst_part_blue", "burst_part_green", "burst_part_yellow",
	"burst_full_red", "burst_full_blue", "burst_full_green", "burst_full_yellow",
	"burst_partglow_red", "burst_partglow_blue", "burst_partglow_green", "burst_partglow_yellow",
	"burst_fullglow_red", "burst_fullglow_blue", "burst_fullglow_green", "burst_fullglow_yellow",
}

local particles = {
	"star_normal_silver1", "star_normal_silver2", "star_normal_silver3",
	"star_normal_gold1", "star_normal_gold2", "star_normal_gold3",
	"star_tiny_silver1", "star_tiny_silver2", "star_tiny_silver3",
	"star_tiny_gold1", "star_tiny_gold2", "star_tiny_gold3",

	"large_red1", "large_red2", "large_red3",
	"large_blue1", "large_blue2", "large_blue3",
	"large_green1", "large_green2", "large_green3",
	"large_yellow1", "large_yellow2", "large_yellow3",
	"large_healing1", "large_healing2", "large_healing3",

	"dust_red1", "dust_red2", "dust_red3",
	"dust_blue1", "dust_blue2", "dust_blue3",
	"dust_green1", "dust_green2", "dust_green3",
	"dust_yellow1", "dust_yellow2", "dust_yellow3",

	"super_red", "super_blue", "super_green", "super_yellow",

	"trail_red", "trail_blue", "trail_green", "trail_yellow", "trail_healing",
}

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

local background_thumbnails = {
	"thumbnail_colors", "thumbnail_starfall", "thumbnail_cloud",
	"thumbnail_rabbitsnowstorm", "thumbnail_checkmate",
}

for _, item in pairs(background_thumbnails) do
	image_data[item] = "images/charselect/" .. item .. ".png"
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
	gems = gems,
	particles = particles,
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
		local img
		local success = pcall(function() img = love.graphics.newImage(image_data[k]) end)
		assert(success, image_data[k])
		t[k] = img
		return img
	end
}
setmetatable(image, fallback)

image.GEM_WIDTH = image.gems_red:getWidth()
image.GEM_HEIGHT = image.gems_red:getHeight()

function image.lookup.words_ready(size)
	assert(size == "small" or size == "large", "invalid size")
	local ret
	if size == "small" then
		local choice = {
			image.particles_star_tiny_silver1,
			image.particles_star_tiny_silver2,
			image.particles_star_tiny_silver3,
		}
		ret = choice[math.random(#choice)]
	else
		local choice = {
			image.particles_star_normal_silver1,
			image.particles_star_normal_silver2,
			image.particles_star_normal_silver3,
		}
		ret = choice[math.random(#choice)]
	end
	return ret
end

local gem_colors = {"red", "blue", "green", "yellow"}
function image.lookup.particle_freq(color)
	local image_num_freq = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 3}
	local image_num = image_num_freq[math.random(#image_num_freq)]
	local image_color = color
	if color == "wild" then image_color = gem_colors[math.random(#gem_colors)] end
	local image_name = "particles_large_" .. image_color .. image_num
	if color == "none" then image_name = "dummy" end
	return image[image_name]
end

function image.lookup.platform_star(player_num, is_tiny)
	assert(player_num == 1 or player_num == 2, "invalid player_num provided")
	local image_name
	local image_num = math.random(3)
	if player_num == 1 then
		image_name = is_tiny and "particles_star_tiny_gold" or "particles_star_normal_gold"
	else
		image_name = is_tiny and "particles_star_tiny_silver" or "particles_star_normal_silver"
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
			local tbl = {image.particles_dust_red1, image.particles_dust_red2, image.particles_dust_red3}
			return tbl[math.random(#tbl)]
		elseif color == "blue" then
			local tbl = {image.particles_dust_blue1, image.particles_dust_blue2, image.particles_dust_blue3}
			return tbl[math.random(#tbl)]
		elseif color == "green" then
			local tbl = {image.particles_dust_green1, image.particles_dust_green2, image.particles_dust_green3}
			return tbl[math.random(#tbl)]
		elseif color == "yellow" then
			local tbl = {image.particles_dust_yellow1, image.particles_dust_yellow2, image.particles_dust_yellow3}
			return tbl[math.random(#tbl)]
		elseif color == "none" then
			return image.dummy
		elseif color == "wild" then
			local tbl = {
				image.particles_dust_red1, image.particles_dust_red2, image.particles_dust_red3,
				image.particles_dust_blue1, image.particles_dust_blue2, image.particles_dust_blue3,
				image.particles_dust_green1, image.particles_dust_green2, image.particles_dust_green3,
				image.particles_dust_yellow1, image.particles_dust_yellow2, image.particles_dust_yellow3,
			}
			return tbl[math.random(#tbl)]
		else
			print("image.lookup.smalldust Sucka MC")
			return image.particles_dust_red1
		end
	end
end

function image.lookup.stardust(color)
	if color == "red" then return image.particles_large_red1
	elseif color == "blue" then return image.particles_large_blue1
	elseif color == "green" then return image.particles_large_green1
	elseif color == "yellow" then return image.particles_large_yellow1
	elseif color == "none" then return image.dummy
	elseif color == "wild" then
		local tbl = {
			image.particles_large_red1,
			image.particles_large_blue1,
			image.particles_large_green1,
			image.particles_large_yellow1,
		}
		return tbl[math.random(#tbl)]
	else
		print("image.lookup.stardust Sucka MC")
		return image.particles_large_red1
	end
end

return image
