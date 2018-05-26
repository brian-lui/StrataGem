local love = _G.love

local image = {
	lookup = {},
	dummy = love.graphics.newImage('images/dummy.png'),

	-- Gems
	red_gem = love.graphics.newImage('images/gems/redgem.png'),
	blue_gem = love.graphics.newImage('images/gems/bluegem.png'),
	green_gem = love.graphics.newImage('images/gems/greengem.png'),
	yellow_gem = love.graphics.newImage('images/gems/yellowgem.png'),

	red_particle1 = love.graphics.newImage('images/particles/redparticle1.png'),
	red_particle2 = love.graphics.newImage('images/particles/redparticle2.png'),
	red_particle3 = love.graphics.newImage('images/particles/redparticle3.png'),
	blue_particle1 = love.graphics.newImage('images/particles/blueparticle1.png'),
	blue_particle2 = love.graphics.newImage('images/particles/blueparticle2.png'),
	blue_particle3 = love.graphics.newImage('images/particles/blueparticle3.png'),
	green_particle1 = love.graphics.newImage('images/particles/greenparticle1.png'),
	green_particle2 = love.graphics.newImage('images/particles/greenparticle2.png'),
	green_particle3 = love.graphics.newImage('images/particles/greenparticle3.png'),
	yellow_particle1 = love.graphics.newImage('images/particles/yellowparticle1.png'),
	yellow_particle2 = love.graphics.newImage('images/particles/yellowparticle2.png'),
	yellow_particle3 = love.graphics.newImage('images/particles/yellowparticle3.png'),

	healing_particle1 = love.graphics.newImage('images/particles/healingparticle1.png'),
	healing_particle2 = love.graphics.newImage('images/particles/healingparticle2.png'),
	healing_particle3 = love.graphics.newImage('images/particles/healingparticle3.png'),

	star_particle_silver1 = love.graphics.newImage('images/particles/silverstar1.png'),
	star_particle_silver2 = love.graphics.newImage('images/particles/silverstar2.png'),
	star_particle_silver3 = love.graphics.newImage('images/particles/silverstar3.png'),
	star_particle_gold1 = love.graphics.newImage('images/particles/goldstar1.png'),
	star_particle_gold2 = love.graphics.newImage('images/particles/goldstar2.png'),
	star_particle_gold3 = love.graphics.newImage('images/particles/goldstar3.png'),
	tinystar_particle_silver1 = love.graphics.newImage('images/particles/tinystarsilver1.png'),
	tinystar_particle_silver2 = love.graphics.newImage('images/particles/tinystarsilver2.png'),
	tinystar_particle_silver3 = love.graphics.newImage('images/particles/tinystarsilver3.png'),
	tinystar_particle_gold1 = love.graphics.newImage('images/particles/tinystargold1.png'),
	tinystar_particle_gold2 = love.graphics.newImage('images/particles/tinystargold2.png'),
	tinystar_particle_gold3 = love.graphics.newImage('images/particles/tinystargold3.png'),
}

image.GEM_WIDTH = image.red_gem:getWidth()
image.GEM_HEIGHT = image.red_gem:getHeight()

local gem_colors = {"red", "blue", "green", "yellow"}
local super_colors = {"red", "blue", "green", "yellow"}
local burst_colors = {"red", "blue", "green", "yellow"}

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
for _, c in pairs(super_colors) do
	image.UI.super[c.."_word"] = love.graphics.newImage('images/words/supertext'..c..'.png')
	image.UI.super[c.."_empty"] = love.graphics.newImage('images/ui/'..c..'superempty.png')
	image.UI.super[c.."_full"] = love.graphics.newImage('images/ui/'..c..'superfull.png')
	image.UI.super[c.."_glow"] = love.graphics.newImage('images/ui/'..c..'superglow.png')
end

image.UI.burst = {}
for _, c in pairs(burst_colors) do
	image.UI.burst[c .. "_partial"] = love.graphics.newImage('images/ui/' .. c .. 'segmentpartial.png')
	image.UI.burst[c .. "_full"] = love.graphics.newImage('images/ui/' .. c .. 'segmentfull.png')
	for i = 1, 2 do
		image.UI.burst[c .. "_glow" .. i] = love.graphics.newImage('images/ui/' .. c .. 'barglow' .. i .. '.png')
	end
end

assert(image.UI.burst.red_partial)

local buttons = {"vscpu", "vscpupush", "netplay", "netplaypush", "back", "backpush",
	"details", "detailspush", "start", "startpush", "backgroundleft", "backgroundright",
	"lobbycreatenew", "lobbyqueueranked", "lobbycancelsearch", "pause", "stop",
	"settings", "settingspush", "yes", "yespush", "no", "nopush", "quit", "quitpush"}
image.button = {}
for _, v in pairs(buttons) do
	image.button[v] = love.graphics.newImage('images/buttons/' .. v .. '.png')
end

local unclickables = {"title_logo", "lobby_gamebackground", "lobby_searchingnone",
	"lobby_searchingranked", "select_stageborder", "settingsframe", "suretoquit", "pausetext"}
image.unclickable = {}
for _, v in pairs(unclickables) do
	image.unclickable[v] = love.graphics.newImage('images/unclickables/' .. v .. '.png')
end



-- characters
local selectable_chars = {"heath", "walter", "gail", "holly", "wolfgang",
	"hailey", "diggory", "buzz", "ivy", "joy", "mort", "damon"}
image.charselect = {}
for _, v in pairs(selectable_chars) do
	image.charselect[v.."char"] = love.graphics.newImage('images/portraits/'..v.."action.png")
	image.charselect[v.."name"] = love.graphics.newImage('images/words/'..v.."name.png")
	image.charselect[v.."ring"] = love.graphics.newImage('images/charselect/'..v.."ring.png")
end


image.dust = {}
for _, c in pairs(gem_colors) do
	for i = 1, 3 do
		-- e.g. image.dust.red1 = love.graphics.newImage('images/particles/reddust1.png')
		image.dust[c..i] = love.graphics.newImage('images/particles/'..c..'dust'..i..'.png')
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
	ready_star1 = image.star_particle_silver1,
	ready_star2 = image.star_particle_silver2,
	ready_star3 = image.star_particle_silver3,
	ready_tinystar1 = image.tinystar_particle_silver1,
	ready_tinystar2 = image.tinystar_particle_silver2,
	ready_tinystar3 = image.tinystar_particle_silver3,
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
	blue = love.graphics.newImage('images/gems/bluegemexplode.png'),
	red = love.graphics.newImage('images/gems/redgemexplode.png'),
	green = love.graphics.newImage('images/gems/greengemexplode.png'),
	yellow = love.graphics.newImage('images/gems/yellowgemexplode.png'),
}

image.lookup.grey_gem_crumble = {
	red = love.graphics.newImage('images/gems/redgemgrey.png'),
	blue = love.graphics.newImage('images/gems/bluegemgrey.png'),
	green = love.graphics.newImage('images/gems/greengemgrey.png'),
	yellow = love.graphics.newImage('images/gems/yellowgemgrey.png'),
}

image.lookup.particle_freq = {
	red = {[image.red_particle1] = 12, [image.red_particle2] = 7, [image.red_particle3] = 1},
	blue = {[image.blue_particle1] = 12, [image.blue_particle2] = 7, [image.blue_particle3] = 1},
	green = {[image.green_particle1] = 12, [image.green_particle2] = 7, [image.green_particle3] = 1},
	yellow = {[image.yellow_particle1] = 12, [image.yellow_particle2] = 7, [image.yellow_particle3] = 1},
	healing = {[image.healing_particle1] = 12, [image.healing_particle2] = 7, [image.healing_particle3] = 1},
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
}

image.lookup.pop_particle = {
	red = love.graphics.newImage('images/gems/popred.png'),
	blue = love.graphics.newImage('images/gems/popblue.png'),
	green = love.graphics.newImage('images/gems/popgreen.png'),
	yellow = love.graphics.newImage('images/gems/popyellow.png'),
}

image.lookup.trail_particle = {
	red = love.graphics.newImage('images/particles/redtrail.png'),
	blue = love.graphics.newImage('images/particles/bluetrail.png'),
	green = love.graphics.newImage('images/particles/greentrail.png'),
	yellow = love.graphics.newImage('images/particles/yellowtrail.png'),
	healing = love.graphics.newImage('images/particles/healingtrail.png'),
}

image.lookup.platform_star = {
	StarP2 = {image.star_particle_silver1, image.star_particle_silver2, image.star_particle_silver3},
	StarP1 = {image.star_particle_gold1, image.star_particle_gold2, image.star_particle_gold3},
	TinyStarP2 = {image.tinystar_particle_silver1, image.tinystar_particle_silver2, image.tinystar_particle_silver3},
	TinyStarP1 = {image.tinystar_particle_gold1, image.tinystar_particle_gold2, image.tinystar_particle_gold3},
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
		if color == "red" then return image.red_particle1
		elseif color == "blue" then return image.blue_particle1
		elseif color == "green" then return image.green_particle1
		elseif color == "yellow" then return image.yellow_particle1
		elseif color == "wild" then
			local tbl = {
				image.red_particle1,
				image.blue_particle1,
				image.green_particle1,
				image.yellow_particle1,
			}
			return tbl[math.random(#tbl)]
		else print("image.lookup.dust Sucka MC") return image.red_particle1 end
	end
}

image.lookup.colorline = {
	red = love.graphics.newImage('images/ui/blueline.png'),
	blue = love.graphics.newImage('images/ui/blueline.png'),
	green = love.graphics.newImage('images/ui/blueline.png'),
	yellow = love.graphics.newImage('images/ui/blueline.png'),
}
return image
