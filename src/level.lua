local Enemy = require("src.enemy")

local Level = {}
Level.__index = Level

function Level.new()
    local self = setmetatable({}, Level)
    -- Simple list of platforms: {x, y, w, h}
    self.platforms = {
        {0, 560, 800, 40}, -- ground
        {200, 450, 120, 20},
        {380, 360, 120, 20},
        {560, 280, 120, 20},
        {50, 320, 80, 20}
    }
    -- enemies list (initially empty)
    self.enemies = {}
    -- spawn system: queued spawn events and random spawn timer
    self.spawnQueue = {} -- { {time=seconds_from_now, spec={...}} }
    self.spawnTimer = 0
    self.randomSpawnInterval = 2 -- spawn every N seconds randomly
    -- optionally populate with a few initial enemies
    self:spawnRandomEnemies(2)
    return self
end

-- spawn N enemies at random horizontal positions on the ground/platforms
function Level:spawnRandomEnemies(n)
    n = n or 4
    local w,h = love.graphics.getWidth(), love.graphics.getHeight()
    for i=1,n do
        -- choose a platform to place enemy on (include ground)
        local p = self.platforms[math.random(1, #self.platforms)]
        local ex = math.random(p[1], p[1] + p[3] - 32)
        local ey = p[2] - 32
        -- choose hits from allowed set {2,3,5}
        local choices = {2,3,5}
        local hits = choices[math.random(1, #choices)]
        table.insert(self.enemies, Enemy.new(ex, ey, 32, 32, hits))
    end
end

-- schedule a specific spawn in seconds_from_now with a spec table
function Level:scheduleSpawn(seconds_from_now, spec)
    table.insert(self.spawnQueue, { time = seconds_from_now, spec = spec })
end

-- update the spawn system: call from main update loop
function Level:update(dt)
    -- process spawn queue
    for i = #self.spawnQueue, 1, -1 do
        local ev = self.spawnQueue[i]
        ev.time = ev.time - dt
        if ev.time <= 0 then
            -- spawn using spec or random
            local s = ev.spec or {}
            local hits = s.hits or ({2,3,5})[math.random(1,3)]
            local ex = s.x
            local ey = s.y
            if not ex or not ey then
                -- place on a random platform
                local p = self.platforms[math.random(1, #self.platforms)]
                ex = math.random(p[1], p[1] + p[3] - 32)
                ey = p[2] - 32
            end
            table.insert(self.enemies, Enemy.new(ex, ey, s.w or 32, s.h or 32, hits))
            table.remove(self.spawnQueue, i)
        end
    end

    -- random spawner
    self.spawnTimer = self.spawnTimer - dt
    if self.spawnTimer <= 0 then
        self.spawnTimer = self.randomSpawnInterval
        -- small chance to spawn 0..2 enemies
        local count = math.random(0,2)
        self:spawnRandomEnemies(count)
    end
end

function Level:reset()
    self.enemies = {}
    self:spawnRandomEnemies(4)
end

function Level:draw()
    love.graphics.setColor(0.4, 0.4, 0.4)
    for _, p in ipairs(self.platforms) do
        love.graphics.rectangle("fill", p[1], p[2], p[3], p[4])
    end
    -- draw enemies
    for _, e in ipairs(self.enemies) do
        e:draw()
    end
end

function Level:removeEnemy(index)
    table.remove(self.enemies, index)
end

-- Collision helpers
function Level:checkVerticalCollision(player, nextY)
    local px = player.x
    local py = nextY
    local pw = player.w
    local ph = player.h

    for _, p in ipairs(self.platforms) do
        local rx, ry, rw, rh = p[1], p[2], p[3], p[4]
        if px + pw > rx and px < rx + rw then
            -- overlapping in X
            if player.y + ph <= ry and py + ph > ry then
                -- falling onto platform
                return true, ry - ph, 0, true
            end
            if player.y >= ry + rh and py < ry + rh then
                -- hitting head on platform
                return true, ry + rh, 0, false
            end
        end
    end

    return false, nextY, player.vy, false
end

function Level:checkHorizontalCollision(player, nextX)
    local px = nextX
    local py = player.y
    local pw = player.w
    local ph = player.h

    for _, p in ipairs(self.platforms) do
        local rx, ry, rw, rh = p[1], p[2], p[3], p[4]
        if py + ph > ry and py < ry + rh then
            -- overlapping in Y
            if player.x + pw <= rx and px + pw > rx then
                -- moving right into platform
                return true, rx - pw
            end
            if player.x >= rx + rw and px < rx + rw then
                -- moving left into platform
                return true, rx + rw
            end
        end
    end

    return false, nextX
end

return Level
