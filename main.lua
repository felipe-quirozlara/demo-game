-- Simple platformer demo for LÖVE
local Player = require("src.player")
local Level = require("src.level")

local player
local level

function love.load()
    love.window.setTitle("Simple Platformer")
    love.window.setMode(800, 600)

    level = Level.new()
    player = Player.new(100, 100, level)
end

function love.update(dt)
    player:update(dt)
end

function love.draw()
    level:draw()
    player:draw()

    love.graphics.setColor(1,1,1)
    love.graphics.print("Use A/D or Left/Right to move, Space to jump", 10, 10)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    -- allow multiple keys for jump: Space, Up arrow, and W
    if key == "space" or key == "up" or key == "w" then
        player:jump()
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- left click
        if player then
            player.firing = true
            player.lastMouseX = x
            player.lastMouseY = y
            -- immediate shot
            if player.shoot then player:shoot(x, y) end
            -- start the timer so continuous fire waits full interval
            player.fireTimer = 1 / (player.fireRate or 8)
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and player then
        player.firing = false
    end
end

function love.mousemoved(x, y, dx, dy)
    if player then
        player.lastMouseX = x
        player.lastMouseY = y
    end
end
