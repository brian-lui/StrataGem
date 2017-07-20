local image = {
	lookup = {},
	dummy = love.graphics.newImage('images/dummy.png'),

	-- backgrounds
	seasons_background = love.graphics.newImage('images/backgrounds/seasons/background.png'),
	seasons_background2 = love.graphics.newImage('images/backgrounds/seasons/background2.png'),
	seasons_background_thumbnail = love.graphics.newImage('images/charselect/seasonthumbnail.png'),
	seasons_greenleaf = love.graphics.newImage('images/backgrounds/seasons/greenleaf.png'),
	seasons_orangeleaf = love.graphics.newImage('images/backgrounds/seasons/orangeleaf.png'),
	seasons_redleaf = love.graphics.newImage('images/backgrounds/seasons/redleaf.png'),
	seasons_yellowleaf = love.graphics.newImage('images/backgrounds/seasons/yellowleaf.png'),
	seasons_sakura = love.graphics.newImage('images/backgrounds/seasons/sakura.png'),
	seasons_tinysakura = love.graphics.newImage('images/backgrounds/seasons/tinysakura.png'),
	seasons_snow1 = love.graphics.newImage('images/backgrounds/seasons/snow1.png'),
	seasons_snow2 = love.graphics.newImage('images/backgrounds/seasons/snow2.png'),
	seasons_snow3 = love.graphics.newImage('images/backgrounds/seasons/snow3.png'),
	seasons_snow4 = love.graphics.newImage('images/backgrounds/seasons/snow4.png'),

	-- Gems
	red_gem = love.graphics.newImage('images/gems/redgem.png'),
	blue_gem = love.graphics.newImage('images/gems/bluegem.png'),
	green_gem = love.graphics.newImage('images/gems/greengem.png'),
	yellow_gem = love.graphics.newImage('images/gems/yellowgem.png'),

	red_explode = love.graphics.newImage('images/gems/redgemexplode.png'),
	blue_explode = love.graphics.newImage('images/gems/bluegemexplode.png'),
	green_explode = love.graphics.newImage('images/gems/greengemexplode.png'),
	yellow_explode = love.graphics.newImage('images/gems/yellowgemexplode.png'),

	red_grey = love.graphics.newImage('images/gems/redgrey.png'),
	blue_grey = love.graphics.newImage('images/gems/bluegrey.png'),
	green_grey = love.graphics.newImage('images/gems/greengrey.png'),
	yellow_grey = love.graphics.newImage('images/gems/yellowgrey.png'),

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

	super_particle_red = love.graphics.newImage('images/particles/superparticlered.png'),
	super_particle_blue = love.graphics.newImage('images/particles/superparticleblue.png'),
	super_particle_green = love.graphics.newImage('images/particles/superparticlegreen.png'),
	super_particle_yellow = love.graphics.newImage('images/particles/superparticleyellow.png'),

	trail_particle_red = love.graphics.newImage('images/particles/trailred.png'),
	trail_particle_blue = love.graphics.newImage('images/particles/trailblue.png'),
	trail_particle_green = love.graphics.newImage('images/particles/trailgreen.png'),
	trail_particle_yellow = love.graphics.newImage('images/particles/trailyellow.png'),

	pop_particle_red = love.graphics.newImage('images/gems/popred.png'),
	pop_particle_blue = love.graphics.newImage('images/gems/popblue.png'),
	pop_particle_green = love.graphics.newImage('images/gems/popgreen.png'),
	pop_particle_yellow = love.graphics.newImage('images/gems/popyellow.png'),

	star_particle_silver1 = love.graphics.newImage('images/particles/star1silver.png'),
	star_particle_silver2 = love.graphics.newImage('images/particles/star2silver.png'),
	star_particle_silver3 = love.graphics.newImage('images/particles/star3silver.png'),
	star_particle_gold1 = love.graphics.newImage('images/particles/star1gold.png'),
	star_particle_gold2 = love.graphics.newImage('images/particles/star2gold.png'),
	star_particle_gold3 = love.graphics.newImage('images/particles/star3gold.png'),
	tinystar_particle_silver1 = love.graphics.newImage('images/particles/tinystar1silver.png'),
	tinystar_particle_silver2 = love.graphics.newImage('images/particles/tinystar2silver.png'),
	tinystar_particle_silver3 = love.graphics.newImage('images/particles/tinystar3silver.png'),
	tinystar_particle_gold1 = love.graphics.newImage('images/particles/tinystar1gold.png'),
	tinystar_particle_gold2 = love.graphics.newImage('images/particles/tinystar2gold.png'),
	tinystar_particle_gold3 = love.graphics.newImage('images/particles/tinystar3gold.png'),
}
image.GEM_WIDTH = image.red_gem:getWidth()
image.GEM_HEIGHT = image.red_gem:getHeight()

local gem_colors = {"red", "blue", "green", "yellow"}
local super_colors = {"red", "blue", "green", "yellow", "purple", "parch"}
local char_list = {"heath", "walter", "gail"}

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
for i = 1, 6 do
	image.background.cloud["bigcloud"..i] =	love.graphics.newImage('images/backgrounds/cloud/bigcloud'..i..'.png')
	image.background.cloud["medcloud"..i] =	love.graphics.newImage('images/backgrounds/cloud/medcloud'..i..'.png')
	image.background.cloud["smallcloud"..i] =	love.graphics.newImage('images/backgrounds/cloud/smallcloud'..i..'.png')
end

image.UI = {
	tub = love.graphics.newImage('images/ui/tub.png'),
	platform_gold = love.graphics.newImage('images/ui/platgold.png'),
	platform_silver = love.graphics.newImage('images/ui/platsilver.png'),
	platform_red = love.graphics.newImage('images/ui/platred.png'),
	platform_red_glow = love.graphics.newImage('images/ui/platredglow.png'),
	redX = love.graphics.newImage('images/ui/redx.png'),
	timer_bar = love.graphics.newImage('images/ui/timerbar.png'),
	timer_bar_full = love.graphics.newImage('images/ui/timerbarfull.png'),
	gauge_silver = love.graphics.newImage('images/ui/gaugesilver.png'),
	gauge_gold = love.graphics.newImage('images/ui/gaugegold.png'),
	starpiece = {
		love.graphics.newImage('images/ui/starpiece1.png'),
		love.graphics.newImage('images/ui/starpiece2.png'),
		love.graphics.newImage('images/ui/starpiece3.png'),
		love.graphics.newImage('images/ui/starpiece4.png'),
	}
}

image.UI.timer = {}
for i = 0, 9 do
	image.UI.timer[i] = love.graphics.newImage('images/numbers/timer '..i..'.png')
end

image.UI.super = {}
for _, c in pairs(super_colors) do
	image.UI.super[c.."_word"] = love.graphics.newImage('images/ui/'..c..'super.png')
	image.UI.super[c.."_partial"] = love.graphics.newImage('images/ui/'..c..'segmentpartial.png')
	image.UI.super[c.."_full"] = love.graphics.newImage('images/ui/'..c..'segmentfull.png')
	for i = 1, 4 do
		image.UI.super[c.."_glow"..i] = love.graphics.newImage('images/ui/'..c..'glow'..i..'.png')
	end
end

image.title = {
	logo = love.graphics.newImage('images/title/logo.png'),
	online = love.graphics.newImage('images/title/online.png'),
	onlinepush = love.graphics.newImage('images/title/onlinepush.png'),
	vscpu = love.graphics.newImage('images/title/vscpu.png'),
	vscpupush = love.graphics.newImage('images/title/vscpupush.png'),
}

image.lobby = {
	create = love.graphics.newImage('images/lobby/createlobbybutton.png'),
	ranked_match = love.graphics.newImage('images/lobby/rankedmatchbutton.png'),
	game_background = love.graphics.newImage('images/lobby/lobbygamebackground.png'),
	search_ranked = love.graphics.newImage('images/lobby/searchingranked.png'),
	search_none = love.graphics.newImage('images/lobby/searchingnone.png'),
	cancel_search = love.graphics.newImage('images/lobby/cancelsearchbutton.png'),
	back = love.graphics.newImage('images/lobby/backbutton.png'),
}

image.charselect = {
	-- UI elements
	bk_frame = love.graphics.newImage('images/charselect/stageborder.png'), -- placeholder image
	left_arrow = love.graphics.newImage('images/charselect/leftarrow.png'), -- placeholder image
	left_arrow_push = love.graphics.newImage('images/charselect/leftarrow.png'), -- no image yet
	right_arrow = love.graphics.newImage('images/charselect/rightarrow.png'), -- placeholder image
	right_arrow_push = love.graphics.newImage('images/charselect/rightarrow.png'), -- no image yet
	start = love.graphics.newImage('images/charselect/start.png'),
	startpush = love.graphics.newImage('images/charselect/startpush.png'),
	back = love.graphics.newImage('images/charselect/back.png'),
	backpush = love.graphics.newImage('images/charselect/backpush.png'),
}
	-- characters
local selectable_chars = {"heath", "walter", "gail", "buzz", "hailey"}
for _, v in pairs(selectable_chars) do
	image.charselect[v.."char"] = love.graphics.newImage('images/characters/'..v.."action.png")
	image.charselect[v.."name"] = love.graphics.newImage('images/charselect/'..v.."name.png")
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

	doublecast_cloud = love.graphics.newImage('images/words/doublecastcloud.png'),
	rush_cloud_h = love.graphics.newImage('images/words/rushcloudhori.png'),
	rush_cloud_v = love.graphics.newImage('images/words/rushcloudvert.png'),
	rush_particle = love.graphics.newImage('images/words/rushparticle.png'),
	go_star = love.graphics.newImage('images/words/gostar.png'),
	ready_star1 = love.graphics.newImage('images/words/readystar1.png'),
	ready_star2 = love.graphics.newImage('images/words/readystar2.png'),
	ready_star3 = love.graphics.newImage('images/words/readystar3.png'),
	ready_tinystar1 = love.graphics.newImage('images/words/readytinystar1.png'),
	ready_tinystar2 = love.graphics.newImage('images/words/readytinystar2.png'),
	ready_tinystar3 = love.graphics.newImage('images/words/readytinystar3.png'),
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
	BLUE = image.blue_explode,
	RED = image.red_explode,
	GREEN = image.green_explode,
	YELLOW = image.yellow_explode,
	RED_GRAY = image.red_grey,
	BLUE_GRAY = image.blue_grey,
	GREEN_GRAY = image.green_grey,
	YELLOW_GRAY = image.yellow_grey
}

image.lookup.particle_freq = {
	BLUE = {[image.blue_particle1] = 12, [image.blue_particle2] = 7, [image.blue_particle3] = 1},
	GREEN = {[image.green_particle1] = 12, [image.green_particle2] = 7, [image.green_particle3] = 1},
	RED = {[image.red_particle1] = 12, [image.red_particle2] = 7, [image.red_particle3] = 1},
	YELLOW = {[image.yellow_particle1] = 12, [image.yellow_particle2] = 7, [image.yellow_particle3] = 1}
}
image.lookup.particle_freq.random = function(color)
	local rand_table = {}
	local num = 0
	for color, freq in pairs(image.lookup.particle_freq[color]) do
		for i = 1, freq do
			num = num + 1
			rand_table[num] = color
		end
	end
	local rand = math.random(num)
	return rand_table[rand]
end

image.lookup.super_particle = {
	RED = image.super_particle_red,
	BLUE = image.super_particle_blue,
	GREEN = image.super_particle_green,
	YELLOW = image.super_particle_yellow
}

image.lookup.pop_particle = {
	RED = image.pop_particle_red,
	BLUE = image.pop_particle_blue,
	GREEN = image.pop_particle_green,
	YELLOW = image.pop_particle_yellow
}

image.lookup.trail_particle = {
	RED = image.trail_particle_red,
	BLUE = image.trail_particle_blue,
	GREEN = image.trail_particle_green,
	YELLOW = image.trail_particle_yellow
}

image.lookup.platform_star = {
	StarP2 = {image.star_particle_silver1, image.star_particle_silver2, image.star_particle_silver3},
	StarP1 = {image.star_particle_gold1, image.star_particle_gold2, image.star_particle_gold3},
	TinyStarP2 = {image.tinystar_particle_silver1, image.tinystar_particle_silver2, image.tinystar_particle_silver3},
	TinyStarP1 = {image.tinystar_particle_gold1, image.tinystar_particle_gold2, image.tinystar_particle_gold3},
}

image.lookup.dust = {
	small = function(color, big_possible)
		if big_possible == nil then big_possible = true end
		local rand = math.random(1, 3)
		local star_instead = big_possible and (math.random() < 0.05)
		if star_instead then
			return image.lookup.dust.star(color)
		else
			if color == "RED" then
				local tbl = {image.dust.red1, image.dust.red2, image.dust.red3}
				return tbl[rand]
			elseif color == "BLUE" then
				local tbl = {image.dust.blue1, image.dust.blue2, image.dust.blue3}
				return tbl[rand]
			elseif color == "GREEN" then
				local tbl = {image.dust.green1, image.dust.green2, image.dust.green3}
				return tbl[rand]
			elseif color == "YELLOW" then
				local tbl = {image.dust.yellow1, image.dust.yellow2, image.dust.yellow3}
				return tbl[rand]
			else print("image.lookup.dust Sucka MC") return image.dust.red1
			end
		end
	end,

	star = function(color)
		if color == "RED" then return image.red_particle1
		elseif color == "BLUE" then return image.blue_particle1
		elseif color == "GREEN" then return image.green_particle1
		elseif color == "YELLOW" then return image.yellow_particle1
		else print("image.lookup.dust Sucka MC") return image.red_particle1 end
	end
}

return image
