local love = _G.love

function love.conf(t)
	t.version = "0.10.0"
	t.modules.joystick = false
	t.modules.physics = false
end

print(love.filesystem.getSaveDirectory())
