-- Simple platformer demo for LÖVE
local Player = require("src.player")
local Level = require("src.level")

local player
local level
local gameState = "menu" -- or "playing"
local levelsList = {
    { id = 1, name = "Level 1", module = "levels.level1" },
    { id = 2, name = "Level 2", module = "levels.level2" },
}

function love.load()
    love.window.setTitle("Simple Platformer")
    love.window.setMode(800, 600)
    level = Level.new()
    player = Player.new(100, 100, level)
    -- let level know about player to avoid spawning on top of them
    level.player = player
    -- wait in menu until user selects level
end

function love.update(dt)
    if gameState == "playing" then
        player:update(dt)
        if level and level.update then
            level:update(dt)
        end
    end
end

function love.draw()
    if gameState == "menu" then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Select level:", 0, 80, love.graphics.getWidth(), "center")
        for i, v in ipairs(levelsList) do
            love.graphics.printf(string.format("%d) %s", v.id, v.name), 0, 100 + i*20, love.graphics.getWidth(), "center")
        end
        love.graphics.printf("Press number to start", 0, 180, love.graphics.getWidth(), "center")
    else
        level:draw()
        player:draw()

        love.graphics.setColor(1,1,1)
        love.graphics.print("Use A/D or Left/Right to move, Space to jump", 10, 10)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    if gameState == "menu" then
        -- number keys to select level
        if key == "1" or key == "2" then
            local idx = tonumber(key)
            local info = levelsList[idx]
            if info then
                -- load script module
                local ok, script = pcall(require, info.module)
                if ok and script then
                    level:loadScript(script)
                    -- ensure level knows player
                    level.player = player
                    -- reset player
                    player.x = 100; player.y = 100; player.vx = 0; player.vy = 0; player.bullets = {}
                    gameState = "playing"
                else
                    print("Failed to load level script:", info.module)
                end
            end
        end
        return
    end
    -- allow multiple keys for jump: Space, Up arrow, and W
    if key == "space" or key == "up" or key == "w" then
        player:jump()
    end
    if key == "r" then
        if level and level.reset then
            level:reset()
        end
        -- clear player bullets and reset position
        if player then
            player.bullets = {}
            player.x = 100
            player.y = 100
            player.vx = 0
            player.vy = 0
        end
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
            player.fireTimer = player.fireInterval or (1 / (player.fireRate or 8))
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
