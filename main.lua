-- Simple platformer demo for LÖVE
local Player = require("src.player")
local Level = require("src.level")

local player
local level
local gameState = "menu" -- or "playing"
local runHasDied = false -- track whether the player has died during the current run
local runStartTime = 0
local runKills = 0
local levelCompleteMode = false
local levelCompleteTimer = 0
local levelsList = {
    { id = 1, name = "Level 1", module = "levels.level1" },
    { id = 2, name = "Level 2", module = "levels.level2" },
}
local currentLevelIndex = nil

function love.load()
    love.window.setTitle("Simple Platformer")
    love.window.setMode(800, 600)
    level = Level.new()
    player = Player.new(100, 100, level)
    -- load persisted player info (money etc.)
    if type(player.loadFromDisk) == "function" then pcall(function() player:loadFromDisk() end) end
    -- let level know about player to avoid spawning on top of them
    level.player = player
    -- wait in menu until user selects level
end

-- helper to start a run at the given level index (defaults to 1)
local function startRun(idx)
    idx = idx or 1
    local info = levelsList[idx]
    if not info then return false end
    pcall(print, string.format("startRun: attempting to start level %s (module=%s)", tostring(idx), tostring(info.module)))
    local ok, script = pcall(require, info.module)
    if not ok or not script then return false end
    pcall(print, string.format("startRun: loaded module %s", tostring(info.module)))
    currentLevelIndex = idx
    level:loadScript(script)
    level.player = player
    -- reset transient run state but keep persistent money
    player.x = 100; player.y = 100; player.vx = 0; player.vy = 0; player.bullets = {}
    player.halfHearts = player.maxHalfHearts
    player.invulnTime = 0
    player.dead = false
    runHasDied = false
    runStartTime = love.timer.getTime()
    runKills = 0
    level.onKill = function(_, enemy, byPlayer)
        if byPlayer then runKills = runKills + 1 end
    end
    level.onComplete = function()
        levelCompleteMode = true
        levelCompleteTimer = 10
    end
    gameState = "playing"
    return true
end

function love.update(dt)
    if gameState == "playing" then
        player:update(dt)
        if level and level.update then
            level:update(dt)
        end
        -- if we're in the level-complete waiting window, count down
        if levelCompleteMode then
            levelCompleteTimer = levelCompleteTimer - dt
            if levelCompleteTimer <= 0 then
                -- time expired: try to advance to next level if available
                levelCompleteMode = false
                local nextIdx = currentLevelIndex and (currentLevelIndex + 1) or nil
                local nextInfo = nextIdx and levelsList[nextIdx] or nil
                if nextInfo then
                    local ok2, script2 = pcall(require, nextInfo.module)
                    if ok2 and script2 then
                        level:loadScript(script2)
                        level.player = player
                        player.x = 100; player.y = 100; player.vx = 0; player.vy = 0; player.bullets = {}
                        level.onKill = function(_, enemy, byPlayer)
                            if byPlayer then runKills = runKills + 1 end
                        end
                        currentLevelIndex = nextIdx
                    else
                        if not runHasDied then
                            gameState = "finished"
                        else
                            gameState = "menu"
                        end
                    end
                else
                    if not runHasDied then
                        gameState = "finished"
                    else
                        gameState = "menu"
                    end
                end
            end
        end
        -- switch to game over when player dies
        if player and player.dead then
            runHasDied = true
            gameState = "gameover"
        end
    end
end

function love.draw()
    if gameState == "menu" then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Demo Rogue-lite", 0, 60, love.graphics.getWidth(), "center")
        love.graphics.printf(string.format("Money: %d", player.money or 0), 0, 120, love.graphics.getWidth(), "center")
        -- Draw Start Run button
        local bw, bh = 240, 48
        local cx = love.graphics.getWidth() / 2
        local bx = cx - bw/2
        local by = 200
        local mx, my = love.mouse.getPosition()
        local hover = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
        love.graphics.setColor(hover and {0.2,0.7,0.2} or {0.1,0.5,0.1})
        love.graphics.rectangle("fill", bx, by, bw, bh)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Start Run", bx, by + 14, bw, "center")
    -- Upgrades screen button (next to Start)
    local ubw, ubh = 120, 36
    local ubx = bx + bw + 12
    local uby = by + (bh - ubh) / 2
    local upHover = mx >= ubx and mx <= ubx + ubw and my >= uby and my <= uby + ubh
    love.graphics.setColor(upHover and {0.2,0.6,0.8} or {0.1,0.4,0.6})
    love.graphics.rectangle("fill", ubx, uby, ubw, ubh)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Upgrades", ubx, uby + 8, ubw, "center")
    -- Shop: Red Burst weapon button
        local shopY = by + bh + 18
        local sbw, sbh = 220, 40
        local sbx = cx - sbw/2
        local sby = shopY
        local owned = player:hasUpgrade("red_burst")
        local price = 50
        local shopHover = mx >= sbx and mx <= sbx + sbw and my >= sby and my <= sby + sbh
        love.graphics.setColor(shopHover and {0.6,0.1,0.1} or {0.4,0.1,0.1})
        love.graphics.rectangle("fill", sbx, sby, sbw, sbh)
        love.graphics.setColor(1,1,1)
        if owned then
            love.graphics.printf("Owned: Red Burst", sbx, sby + 12, sbw, "center")
        else
            love.graphics.printf(string.format("Buy Red Burst (%d)", price), sbx, sby + 12, sbw, "center")
        end
        -- Debug overlay
        love.graphics.setColor(1,1,1)
        love.graphics.print(string.format("Mouse: %d, %d", mx, my), 10, love.graphics.getHeight() - 40)
        love.graphics.print(string.format("Hovering Start: %s", tostring(hover)), 10, love.graphics.getHeight() - 24)
        love.graphics.print(string.format("Hovering Upgrades: %s", tostring(upHover)), 10, love.graphics.getHeight() - 56)
    elseif gameState == "upgrades" then
        drawUpgrades()
        return
    else
        level:draw()
        player:draw()

        love.graphics.setColor(1,1,1)
        love.graphics.print("Use A/D or Left/Right to move, Space to jump", 10, 10)
        if gameState == "gameover" then
            love.graphics.setColor(0,0,0,0.6)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            love.graphics.setColor(1,1,1)
            love.graphics.printf("GAME OVER", 0, 200, love.graphics.getWidth(), "center")
            love.graphics.printf("Press R to restart level, M to return to menu", 0, 240, love.graphics.getWidth(), "center")
        end
        if levelCompleteMode then
            love.graphics.setColor(0,0,0,0.6)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            love.graphics.setColor(1,1,1)
            love.graphics.printf("LEVEL COMPLETE! Press 'C' to continue to the next level.", 0, 200, love.graphics.getWidth(), "center")
            love.graphics.printf(string.format("Time left: %.1fs — Hurry and collect dropped money!", math.max(0, levelCompleteTimer)), 0, 240, love.graphics.getWidth(), "center")
        end
        if gameState == "finished" then
            love.graphics.setColor(0,0,0,0.6)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            love.graphics.setColor(1,1,1)
            love.graphics.printf("CONGRATULATIONS! All levels cleared without dying.", 0, 200, love.graphics.getWidth(), "center")
            love.graphics.printf("Press R to replay or M to return to menu", 0, 240, love.graphics.getWidth(), "center")
            -- summary
            local elapsed = 0
            if runStartTime and runStartTime > 0 then elapsed = love.timer.getTime() - runStartTime end
            love.graphics.printf(string.format("Time: %.1fs    Kills: %d", elapsed, runKills), 0, 280, love.graphics.getWidth(), "center")
            -- Buttons
            local bw, bh = 180, 36
            local cx = love.graphics.getWidth() / 2
            local bx1 = cx - bw - 10
            local bx2 = cx + 10
            local by = 330
            -- New Game button
            local mx, my = love.mouse.getPosition()
            local hover1 = mx >= bx1 and mx <= bx1 + bw and my >= by and my <= by + bh
            local hover2 = mx >= bx2 and mx <= bx2 + bw and my >= by and my <= by + bh
            love.graphics.setColor(hover1 and {0.2,0.7,0.2} or {0.1,0.5,0.1})
            love.graphics.rectangle("fill", bx1, by, bw, bh)
            love.graphics.setColor(1,1,1)
            love.graphics.printf("New Game", bx1, by + 8, bw, "center")
            -- Back to Menu button
            love.graphics.setColor(hover2 and {0.7,0.2,0.2} or {0.5,0.1,0.1})
            love.graphics.rectangle("fill", bx2, by, bw, bh)
            love.graphics.setColor(1,1,1)
            love.graphics.printf("Back to Menu", bx2, by + 8, bw, "center")
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    -- allow 'M' to return from upgrades screen
    if key == "m" and gameState == "upgrades" then
        gameState = "menu"
        return
    end
    if gameState == "menu" then
        -- allow Enter to start the run
        if key == "return" or key == "enter" then
            startRun(1)
        end
        return
    end
    -- allow multiple keys for jump: Space, Up arrow, and W
    if key == "space" or key == "up" or key == "w" then
        player:jump()
    end
    if key == "c" and levelCompleteMode then
        -- try to advance immediately to next level
        levelCompleteMode = false
        local nextIdx = currentLevelIndex and (currentLevelIndex + 1) or nil
        local nextInfo = nextIdx and levelsList[nextIdx] or nil
        if nextInfo then
            local ok2, script2 = pcall(require, nextInfo.module)
            if ok2 and script2 then
                level:loadScript(script2)
                level.player = player
                player.x = 100; player.y = 100; player.vx = 0; player.vy = 0; player.bullets = {}
                -- keep run stats and attach onKill for the new level
                level.onKill = function(_, enemy, byPlayer)
                    if byPlayer then runKills = runKills + 1 end
                end
                currentLevelIndex = nextIdx
                return
            else
                gameState = "menu"
                return
            end
        else
            -- no next level
            if not runHasDied then
                gameState = "finished"
            else
                gameState = "menu"
            end
            return
        end
    end
    if key == "r" then
        -- if game over, restart current level; if finished, restart campaign; otherwise reset level in-play
        if gameState == "gameover" then
            -- restart level: reload the current script
            local info = levelsList[currentLevelIndex]
            if info then
                local ok, script = pcall(require, info.module)
                if ok and script then
                    level:loadScript(script)
                    level.player = player
                    player = Player.new(100, 100, level)
                    level.player = player
                    runHasDied = false
                    runStartTime = love.timer.getTime()
                    runKills = 0
                    level.onKill = function(_, enemy, byPlayer)
                        if byPlayer then runKills = runKills + 1 end
                    end
                    gameState = "playing"
                else
                    gameState = "menu"
                end
            else
                gameState = "menu"
            end
        elseif gameState == "finished" then
            -- replay campaign from first level
            local info = levelsList[1]
            if info then
                local ok, script = pcall(require, info.module)
                if ok and script then
                    currentLevelIndex = 1
                    level:loadScript(script)
                    player = Player.new(100, 100, level)
                    level.player = player
                    runHasDied = false
                    runStartTime = love.timer.getTime()
                    runKills = 0
                    level.onKill = function(_, enemy, byPlayer)
                        if byPlayer then runKills = runKills + 1 end
                    end
                    gameState = "playing"
                else
                    gameState = "menu"
                end
            else
                gameState = "menu"
            end
        else
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
    if key == "m" and (gameState == "gameover" or gameState == "finished") then
        gameState = "menu"
    end
end

function love.mousepressed(x, y, button)
    -- Accept numeric 1 or string variants for left button for compatibility
    local isLeft = false
    if button == 1 then isLeft = true end
    if type(button) == "string" then
        local bl = button:lower()
        if bl == "l" or bl == "left" or bl == "1" then isLeft = true end
    end
    if not isLeft then return end
    -- debug: helpful prints to console if the button seems unresponsive
    pcall(print, string.format("mousepressed: x=%s y=%s button=%s state=%s", tostring(x), tostring(y), tostring(button), tostring(gameState)))
    -- Finished screen buttons (New Game, Back to Menu)
    if gameState == "finished" then
        local bw, bh = 180, 36
        local cx = love.graphics.getWidth() / 2
        local bx1 = cx - bw - 10
        local bx2 = cx + 10
        local by = 330
        if x >= bx1 and x <= bx1 + bw and y >= by and y <= by + bh then
            -- New Game: replay campaign from level 1
            startRun(1)
            return
        end
        if x >= bx2 and x <= bx2 + bw and y >= by and y <= by + bh then
            gameState = "menu"
            return
        end
        return
    end

    -- Menu: Start Run button
    if gameState == "menu" then
        local bw, bh = 240, 48
        local cx = love.graphics.getWidth() / 2
        local bx = cx - bw/2
        local by = 200
        if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
            startRun(1)
            return
        end
        -- Upgrades button region
        local ubw, ubh = 120, 36
        local ubx = bx + bw + 12
        local uby = by + (bh - ubh) / 2
        if x >= ubx and x <= ubx + ubw and y >= uby and y <= uby + ubh then
            gameState = "upgrades"
            return
        end
        -- shop button region (Red Burst)
        local shopY = by + bh + 18
        local sbw, sbh = 220, 40
        local sbx = cx - sbw/2
        local sby = shopY
        if x >= sbx and x <= sbx + sbw and y >= sby and y <= sby + sbh then
            -- attempt purchase
            local price = 50
            if player:hasUpgrade("red_burst") then
                -- already owned: equip it
                player.weapon = "red_burst"
            else
                local ok, err = player:buyUpgrade("red_burst", price)
                if not ok then pcall(print, "buy failed:", err) end
            end
            return
        end
        return
    end

    -- Upgrades screen input
    if gameState == "upgrades" then
        -- coordinates must match drawUpgrades layout (single Red Burst entry)
        local bw, bh = 520, 56
        local cx = love.graphics.getWidth() / 2
        local bx = cx - bw/2
        local by = 140
        local btnW, btnH = 100, 36
        local btnX = bx + bw - btnW - 12
        local btnY = by + 10
        if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
            local id = "red_burst"
            local price = 50
            if player:hasUpgrade(id) then
                -- toggle equip/unequip
                if player.weapon == id then
                    player:unequip()
                else
                    player:equipUpgrade(id)
                end
            else
                local ok, err = player:buyUpgrade(id, price)
                if not ok then pcall(print, "buy failed:", err) end
            end
            return
        end
        return
    end

    -- In-game: firing
    if player then
        player.lastMouseX = x
        player.lastMouseY = y
        if player.weapon == "red_burst" and type(player.burstFire) == "function" then
            -- click-to-fire burst weapon
            pcall(function() player:burstFire(x, y) end)
            -- persist no auto-fire (do not set player.firing)
        else
            player.firing = true
            if player.shoot then player:shoot(x, y) end
            player.fireTimer = player.fireInterval or (1 / (player.fireRate or 8))
        end
    end
end

-- Draw Upgrades screen
function drawUpgrades()
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Upgrades", 0, 40, love.graphics.getWidth(), "center")
    love.graphics.printf(string.format("Money: %d", player.money or 0), 0, 80, love.graphics.getWidth(), "center")
    -- list upgrades vertically
    local startY = 140
    local gap = 72
    local cx = love.graphics.getWidth() / 2
    -- Example: red_burst
    local name = "Red Burst"
    local id = "red_burst"
    local price = 50
    local owned = player:hasUpgrade(id)
    local equipped = (player.weapon == id)
    local boxW, boxH = 520, 56
    local bx = cx - boxW/2
    local by = startY
    love.graphics.setColor(0.15,0.15,0.15)
    love.graphics.rectangle("fill", bx, by, boxW, boxH)
    love.graphics.setColor(1,1,1)
    love.graphics.printf(name, bx + 12, by + 8, 300)
    if owned then
        love.graphics.printf("Owned", bx + 320, by + 8, 80)
    else
        love.graphics.printf(string.format("Price: %d", price), bx + 320, by + 8, 80)
    end
    if equipped then love.graphics.printf("Equipped", bx + 420, by + 8, 80) end
    -- buttons: Buy/Equip/Unequip
    -- Buy/Equip button box
    local bw = 100; local bh = 36
    local buyX = bx + boxW - bw - 12
    local buyY = by + 10
    love.graphics.setColor(owned and {0.2,0.6,0.2} or {0.4,0.1,0.1})
    love.graphics.rectangle("fill", buyX, buyY, bw, bh)
    love.graphics.setColor(1,1,1)
    love.graphics.printf(owned and (equipped and "Unequip" or "Equip") or "Buy", buyX, buyY + 8, bw, "center")

    love.graphics.setColor(1,1,1)
    love.graphics.printf("Press M to return to menu", 0, love.graphics.getHeight() - 40, love.graphics.getWidth(), "center")
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
