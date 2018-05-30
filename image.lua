local love = _G.love

-- A table {name, file location} of all the images to be gradually loaded
local image_data = {}
local count = 1

local buttons = {"vscpu", "vscpupush", "netplay", "netplaypush", "back", "backpush",
	"details", "detailspush", "start", "startpush", "backgroundleft", "backgroundright",
	"lobbycreatenew", "lobbyqueueranked", "lobbycancelsearch", "pause", "stop",
	"settings", "settingspush", "yes", "yespush", "no", "nopush", "quit", "quitpush"}
for _, item in pairs(buttons) do
	image_data["buttons_" .. item] = "images/buttons/" .. item .. ".png"
	count = count + 1
end

local unclickables = {"titlelogo", "lobbygamebackground", "lobbysearchingnone",
	"lobbysearchingranked", "selectstageborder", "settingsframe", "suretoquit", "pausetext"}
for _, item in pairs(unclickables) do
	image_data["unclickables_" .. item] = "images/unclickables/" .. item .. ".png"
	count = count + 1
end

local gems = {"redgem", "bluegem", "greengem", "yellowgem"}
for _, item in pairs(gems) do
	image_data[item] = "images/gems/" .. item .. ".png"
	count = count + 1
end

local particles = {"redparticle1", "redparticle2", "redparticle3", "blueparticle1",
	"blueparticle2", "blueparticle3", "greenparticle1", "greenparticle2",
	"greenparticle3", "yellowparticle1", "yellowparticle2", "yellowparticle3",
	"healingparticle1", "healingparticle2", "healingparticle3", "starparticlesilver1",
	"starparticlesilver2", "starparticlesilver3", "starparticlegold1",
	"starparticlegold2", "starparticlegold3", "tinystarparticlesilver1",
	"tinystarparticlesilver2", "tinystarparticlesilver3", "tinystarparticlegold1",
	"tinystarparticlegold2", "tinystarparticlegold3"}
for _, item in pairs(particles) do
	image_data[item] = "images/particles/" .. item .. ".png"
	count = count + 1
end

local selectablechars = {"heath", "walter", "gail", "holly", "wolfgang",
	"hailey", "diggory", "buzz", "ivy", "joy", "mort", "damon"}
for _, item in pairs(selectablechars) do
	image_data["charselect_"..item.."char"] = "images/portraits/"..item.."action.png"
	image_data["charselect_"..item.."shadow"] = "images/portraits/"..item.."shadow.png"
	image_data["charselect_"..item.."name"] = "images/words/"..item.."name.png"
	image_data["charselect_"..item.."ring"] = "images/charselect/"..item.."ring.png"
end


-- coroutine that yields a single image each time it's called
local function loadImage()
	for k, v in pairs(image_data) do
		coroutine.yield(k, love.graphics.newImage(v))
	end
end
local coroLoadImage = coroutine.create(loadImage)

local load_dt = 0
local load_step = 0.05
local load_count = 1
local already_loaded = false
-- every load_step seconds it loads a new image and writes it
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
			return true -- stop calling when all loaded
		else
			local _, key, img = coroutine.resume(coroLoadImage)
			if key ~= nil and img ~= nil then
				if rawget(_self, key) then
					already_loaded = true
				else
					_self[key] = img
					already_loaded = false
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
		print("using fallback for " .. k)
		local img = love.graphics.newImage(image_data[k])
		t[k] = img
		return img
	end
}
setmetatable(image, fallback)

image.GEM_WIDTH = image.redgem:getWidth()
image.GEM_HEIGHT = image.redgem:getHeight()



image.dust = {}
local gem_colors = {"red", "blue", "green", "yellow"}
for _, c in pairs(gem_colors) do
	for i = 1, 3 do
		-- e.g. image.dust.red1 = love.graphics.newImage('images/particles/reddust1.png')
		image.dust[c..i] = love.graphics.newImage('images/particles/'..c..'dust'..i..'.png')
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

image.UI = {
	tub = love.graphics.newImage('images/ui/basin.png'),
	platform_gold = love.graphics.newImage('images/ui/platformstargold.png'),
	platform_silver = love.graphics.newImage('images/ui/platformstarsilver.png'),
	platform_red = love.graphics.newImage('images/ui/platformstarred.png'),
	redX = love.graphics.newImage('images/ui/redx.png'),
	timer_gauge = love.graphics.newImage('images/ui/timergauge.png'),
	timer_bar = love.graphics.newImage('images/ui/timerbar.png'),
	gauge_silver = love.graphics.newImage('images/ui/gaugesilver.png'),
	gauge_gold = love.graphics.newImage('images/ui/gaugegold.png'),
	starpiece = {
		love.graphics.newImage('images/ui/starbreak1.png'),
		love.graphics.newImage('images/ui/starbreak2.png'),
		love.graphics.newImage('images/ui/starbreak3.png'),
		love.graphics.newImage('images/ui/starbreak4.png'),
	}
}

image.UI.timer = {}
for i = 1, 3 do
	image.UI.timer[i] = love.graphics.newImage('images/numbers/' .. i .. '.png')
end

image.UI.super = {}
local super_colors = {"red", "blue", "green", "yellow"}
for _, c in pairs(super_colors) do
	image.UI.super[c.."_word"] = love.graphics.newImage('images/words/supertext'..c..'.png')
	image.UI.super[c.."_empty"] = love.graphics.newImage('images/ui/'..c..'superempty.png')
	image.UI.super[c.."_full"] = love.graphics.newImage('images/ui/'..c..'superfull.png')
	image.UI.super[c.."_glow"] = love.graphics.newImage('images/ui/'..c..'superglow.png')
end

image.UI.burst = {}
local burst_colors = {"red", "blue", "green", "yellow"}
for _, c in pairs(burst_colors) do
	image.UI.burst[c .. "_partial"] = love.graphics.newImage('images/ui/' .. c .. 'segmentpartial.png')
	image.UI.burst[c .. "_full"] = love.graphics.newImage('images/ui/' .. c .. 'segmentfull.png')
	for i = 1, 2 do
		image.UI.burst[c .. "_glow" .. i] = love.graphics.newImage('images/ui/' .. c .. 'barglow' .. i .. '.png')
	end
end

image.words = {
	doublecast = love.graphics.newImage('images/words/doublecast.png'),
	rush = love.graphics.newImage('images/words/rush.png'),
	ready = love.graphics.newImage('images/words/ready.png'),
	go = love.graphics.newImage('images/words/go.png'),
	gameoverthanks = love.graphics.newImage('images/words/gameoverthanks.png'),
	no_rush_one_column = love.graphics.newImage('images/words/norushonecolumn.png'),
	no_rush_full = love.graphics.newImage('images/words/norushfull.png'),

	doublecast_cloud_h = love.graphics.newImage('images/words/doublecasthori.png'),
	doublecast_cloud_v = love.graphics.newImage('images/words/doublecastvert.png'),
	rush_cloud_h = love.graphics.newImage('images/words/rushhori.png'),
	rush_cloud_v = love.graphics.newImage('images/words/rushvert.png'),
	rush_particle = love.graphics.newImage('images/words/rushparticle.png'),
	go_star = image.UI.platform_gold,
	ready_star1 = image.starparticlesilver1,
	ready_star2 = image.starparticlesilver2,
	ready_star3 = image.starparticlesilver3,
	ready_tinystar1 = image.tinystarparticlesilver1,
	ready_tinystar2 = image.tinystarparticlesilver2,
	ready_tinystar3 = image.tinystarparticlesilver3,
}

image.lookup.words_ready = function(size)
	local choice
	if size == "small" then
		choice = {
			image.words.ready_tinystar1,
			image.words.ready_tinystar2,
			image.words.ready_tinystar3
		}
	elseif size == "large" then
		choice = {
			image.words.ready_star1,
			image.words.ready_star2,
			image.words.ready_star3,
		}
	else print ("lol dumb") end
	local rand = math.random(#choice)
	return choice[rand]
end

image.lookup.gem_explode = {
	red = love.graphics.newImage('images/gems/redgemexplode.png'),
	blue = love.graphics.newImage('images/gems/bluegemexplode.png'),
	green = love.graphics.newImage('images/gems/greengemexplode.png'),
	yellow = love.graphics.newImage('images/gems/yellowgemexplode.png'),
	none = image.dummy,
}

image.lookup.grey_gem_crumble = {
	red = love.graphics.newImage('images/gems/redgemgrey.png'),
	blue = love.graphics.newImage('images/gems/bluegemgrey.png'),
	green = love.graphics.newImage('images/gems/greengemgrey.png'),
	yellow = love.graphics.newImage('images/gems/yellowgemgrey.png'),
	none = image.dummy,
}

image.lookup.particle_freq = {
	red = {[image.redparticle1] = 12, [image.redparticle2] = 7, [image.redparticle3] = 1},
	blue = {[image.blueparticle1] = 12, [image.blueparticle2] = 7, [image.blueparticle3] = 1},
	green = {[image.greenparticle1] = 12, [image.greenparticle2] = 7, [image.greenparticle3] = 1},
	yellow = {[image.yellowparticle1] = 12, [image.yellowparticle2] = 7, [image.yellowparticle3] = 1},
	healing = {[image.healingparticle1] = 12, [image.healingparticle2] = 7, [image.healingparticle3] = 1},
	none = {[image.dummy] = 1},
	wild = {
		[image.redparticle1] = 12, [image.redparticle2] = 7, [image.redparticle3] = 1,
		[image.blueparticle1] = 12, [image.blueparticle2] = 7, [image.blueparticle3] = 1,
		[image.greenparticle1] = 12, [image.greenparticle2] = 7, [image.greenparticle3] = 1,
		[image.yellowparticle1] = 12, [image.yellowparticle2] = 7, [image.yellowparticle3] = 1,
	},
}
image.lookup.particle_freq.random = function(color)
	local rand_table = {}
	local num = 0
	for c, freq in pairs(image.lookup.particle_freq[color]) do
		for _ = 1, freq do
			num = num + 1
			rand_table[num] = c
		end
	end
	local rand = math.random(num)
	return rand_table[rand]
end

image.lookup.super_particle = {
	red = love.graphics.newImage('images/particles/redsuperparticle.png'),
	blue = love.graphics.newImage('images/particles/bluesuperparticle.png'),
	green = love.graphics.newImage('images/particles/greensuperparticle.png'),
	yellow = love.graphics.newImage('images/particles/yellowsuperparticle.png'),
	none = image.dummy,
}

image.lookup.pop_particle = {
	red = love.graphics.newImage('images/gems/popred.png'),
	blue = love.graphics.newImage('images/gems/popblue.png'),
	green = love.graphics.newImage('images/gems/popgreen.png'),
	yellow = love.graphics.newImage('images/gems/popyellow.png'),
	none = image.dummy,
}

image.lookup.trail_particle = {
	red = love.graphics.newImage('images/particles/redtrail.png'),
	blue = love.graphics.newImage('images/particles/bluetrail.png'),
	green = love.graphics.newImage('images/particles/greentrail.png'),
	yellow = love.graphics.newImage('images/particles/yellowtrail.png'),
	healing = love.graphics.newImage('images/particles/healingtrail.png'),
	none = image.dummy,
}

image.lookup.platform_star = {
	StarP2 = {image.starparticlesilver1, image.starparticlesilver2, image.starparticlesilver3},
	StarP1 = {image.starparticlegold1, image.starparticlegold2, image.starparticlegold3},
	TinyStarP2 = {image.tinystarparticlesilver1, image.tinystarparticlesilver2, image.tinystarparticlesilver3},
	TinyStarP1 = {image.tinystarparticlegold1, image.tinystarparticlegold2, image.tinystarparticlegold3},
}

image.lookup.dust = {
	small = function(color, big_possible)
		if big_possible ~= false then big_possible = true end
		local star_instead = big_possible and math.random() < 0.05
		if star_instead then
			return image.lookup.dust.star(color)
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
				print("image.lookup.dust Sucka MC")
				return image.dust.red1
			end
		end
	end,

	star = function(color)
		if color == "red" then return image.redparticle1
		elseif color == "blue" then return image.blueparticle1
		elseif color == "green" then return image.greenparticle1
		elseif color == "yellow" then return image.yellowparticle1
		elseif color == "none" then return image.dummy
		elseif color == "wild" then
			local tbl = {
				image.redparticle1,
				image.blueparticle1,
				image.greenparticle1,
				image.yellowparticle1,
			}
			return tbl[math.random(#tbl)]
		else print("image.lookup.dust Sucka MC") return image.redparticle1 end
	end
}


return image
