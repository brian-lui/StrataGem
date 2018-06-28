local love = _G.love

function love.conf(t)
	t.version = "11.1"
	t.modules.joystick = false
	t.modules.physics = false
	t.console = true
end
