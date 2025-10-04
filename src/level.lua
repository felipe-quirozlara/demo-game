local Enemy = require("src.enemy")

local Level = {}
Level.__index = Level

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

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
    -- spawn system: queued spawn events and spawn timer
    self.spawnQueue = {} -- { {time=seconds_from_now, spec={...}} }
    self.spawnTimer = 0
    -- public variable: seconds between each automatic enemy spawn
    self.enemySpawnInterval = 4 -- spawn one enemy every N seconds
    -- backward-compatible alias
    self.randomSpawnInterval = self.enemySpawnInterval
    -- script tracking
    self.scriptTotalSpawns = 0
    self.scriptActive = false
    self.completed = false
    self.groupsMode = false
    self.currentScript = nil
    -- global multiplier to scale enemy jump heights (1.0 = unchanged)
    self.enemyJumpMultiplier = 1.0
    -- kill counters
    self.kills = 0
    self.killsByPlayer = 0
    return self
end

function Level:setEnemyJumpMultiplier(m)
    self.enemyJumpMultiplier = m or 1.0
end

-- spawn N enemies at random horizontal positions on the ground/platforms
function Level:spawnRandomEnemies(n)
    n = n or 4
    if self.groupsMode then return end
    local w,h = love.graphics.getWidth(), love.graphics.getHeight()
    for i=1,n do
        -- choose a platform to place enemy on (include ground)
        local p = self.platforms[math.random(1, #self.platforms)]
        local ex, ey
        -- try a few times to avoid spawning on the player
        local attempts = 8
        for a = 1, attempts do
            ex = math.random(p[1], p[1] + p[3] - 32)
            ey = p[2] - 32
            if not self.player or not rectsOverlap(ex, ey, 32, 32, self.player.x, self.player.y, self.player.w, self.player.h) then
                break
            end
            -- if last attempt and still overlapping, accept it to avoid infinite loop
        end
        -- choose hits from allowed set {2,3,5}
        local choices = {2,3,5}
        local hits = choices[math.random(1, #choices)]
        table.insert(self.enemies, Enemy.new(ex, ey, 32, 32, hits))
    end
end

-- spawn N enemies, optionally all with a specific hits value
function Level:spawnRandomEnemiesWithHits(n, hits)
    n = n or 1
    if self.groupsMode then return end
    for i=1,n do
        -- choose a platform to place enemy on (include ground)
        local p = self.platforms[math.random(1, #self.platforms)]
        local ex, ey
        local attempts = 8
        for a = 1, attempts do
            ex = math.random(p[1], p[1] + p[3] - 32)
            ey = p[2] - 32
            if not self.player or not rectsOverlap(ex, ey, 32, 32, self.player.x, self.player.y, self.player.w, self.player.h) then
                break
            end
        end
        table.insert(self.enemies, Enemy.new(ex, ey, 32, 32, hits))
    end
end

local function typeToHits(t)
    if not t then return nil end
    if t == "grunt" then return 2 end
    if t == "soldier" then return 3 end
    if t == "heavy" then return 5 end
    if t == "boss" then return 10 end
    return tonumber(t) or nil
end

-- load a level script (table) with initial spawns and timed events
function Level:loadScript(script)
    -- clear existing
    self.enemies = {}
    self.spawnQueue = {}
    self.spawnTimer = 0
    -- if the script defines platforms, use them; otherwise keep current/default
    if script.platforms then
        self.platforms = script.platforms
    end
    -- coin values by enemy type (script may define)
    self.coinValues = script.coinValues or { grunt = 1, soldier = 2, heavy = 4, boss = 10 }
    -- reset script tracking
    self.scriptTotalSpawns = 0
    self.scriptActive = true
    self.completed = false
    self.groupsMode = false
    self.currentScript = script
    -- control random spawns
    if script.randomSpawns == false then
        self.randomSpawnsEnabled = false
    else
        self.randomSpawnsEnabled = true
    end
    -- process initial immediate spawns
    -- If groups are defined we treat the script as grouped-only and skip initial/events to avoid duplicates
    if not script.groups then
        -- process initial immediate spawns
        if script.initial then
            for _, entry in ipairs(script.initial) do
                local hits = entry.hits or typeToHits(entry.type) or 2
                local count = entry.count or 1
                for i=1,count do
                    self:scheduleSpawn(0, { type = entry.type, hits = hits })
                    self.scriptTotalSpawns = self.scriptTotalSpawns + 1
                end
            end
        end
        -- schedule events
        if script.events then
            for _, ev in ipairs(script.events) do
                local spec = { type = ev.type, hits = typeToHits(ev.type) }
                -- allow overriding via ev.hits
                if ev.hits then spec.hits = ev.hits end
                self:scheduleSpawn(ev.time, spec)
                self.scriptTotalSpawns = self.scriptTotalSpawns + 1
            end
        end
    end
    -- if script defines counts and order, schedule them in sequence
    if script.groups then
        -- groups: an ordered list where each group has { type, count, requiredPercent }
        self.groupsMode = true
        self.groups = {}
        self.currentGroupIndex = 1
        self.groupSpawnTimer = 0
        self.groupSpawnInterval = script.spawnInterval or self.enemySpawnInterval or 1
        for gi, g in ipairs(script.groups) do
            local hits = g.hits or typeToHits(g.type)
            local group = {
                type = g.type,
                hits = hits,
                count = g.count or 1,
                requiredPercent = g.requiredPercent or 1.0,
                coin = g.coin or nil,
                spawned = 0,
                deaths = 0,
            }
            table.insert(self.groups, group)
            self.scriptTotalSpawns = self.scriptTotalSpawns + group.count
        end
        -- schedule the first group's spawns over time
        if #self.groups > 0 then
            self.groupSpawnTimer = 0
        end
    elseif script.counts and script.order then
        local interval = script.spawnInterval or self.enemySpawnInterval or 1
        local ttime = 0
        for _, typ in ipairs(script.order) do
            local cnt = script.counts[typ] or 0
            for i=1,cnt do
                self:scheduleSpawn(ttime, { type = typ, hits = typeToHits(typ) })
                self.scriptTotalSpawns = self.scriptTotalSpawns + 1
                ttime = ttime + interval
            end
        end
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
            else
                -- ensure spec position doesn't overlap player; if it does, nudge up to attempts
                if self.player and rectsOverlap(ex, ey, s.w or 32, s.h or 32, self.player.x, self.player.y, self.player.w, self.player.h) then
                    -- try small nudge attempts to avoid player
                    local moved = false
                    for a=1,6 do
                        ex = ex + math.random(-40,40)
                        ey = ey + math.random(-40,40)
                        if not rectsOverlap(ex, ey, s.w or 32, s.h or 32, self.player.x, self.player.y, self.player.w, self.player.h) then
                            moved = true; break
                        end
                    end
                    if not moved then
                        -- give up and accept the original spot
                    end
                end
            end
            local en = Enemy.new(ex, ey, s.w or 32, s.h or 32, hits)
            if s.coin then en.coin = s.coin end
            -- if the scheduled spawn carried a group tag, assign it and increment group's spawned count
            if s.group and self.groups and self.groups[s.group] then
                en.group = s.group
                self.groups[s.group].spawned = (self.groups[s.group].spawned or 0) + 1
            end
            table.insert(self.enemies, en)
            table.remove(self.spawnQueue, i)
            if self.scriptActive and self.scriptTotalSpawns > 0 then
                self.scriptTotalSpawns = self.scriptTotalSpawns - 1
            end
        end
    end

    -- automatic spawner: spawn one enemy each interval (if enabled)
    if self.randomSpawnsEnabled ~= false then
        self.spawnTimer = self.spawnTimer - dt
        if self.spawnTimer <= 0 then
            self.spawnTimer = self.enemySpawnInterval or self.randomSpawnInterval
            -- spawn single enemy at random
            self:spawnRandomEnemies(1)
        end
    end

    -- process groups (scripted grouped spawns)
    if self.groups and #self.groups > 0 and self.currentGroupIndex and self.currentGroupIndex <= #self.groups then
        local g = self.groups[self.currentGroupIndex]
        -- determine completion percent of previous group
        if g.spawned < g.count then
            -- spawn next from this group based on groupSpawnInterval
            self.groupSpawnTimer = self.groupSpawnTimer - dt
            if self.groupSpawnTimer <= 0 then
                self.groupSpawnTimer = self.groupSpawnInterval
                -- schedule one from group and tag with group index; we increment spawned when processed
                    self:scheduleSpawn(0, { type = g.type, hits = g.hits, group = self.currentGroupIndex, coin = g.coin })
                -- note: scriptTotalSpawns was already counted when loading
            end
        else
            -- group fully spawned; check deaths to decide when to advance
            local percentDead = 0
            if g.count > 0 then percentDead = g.deaths / g.count end
            if percentDead >= (g.requiredPercent or 1.0) then
                -- advance to next group
                self.currentGroupIndex = self.currentGroupIndex + 1
                if self.currentGroupIndex > #self.groups then
                    -- no more groups
                    self.currentGroupIndex = nil
                end
            end
        end
    end

    -- check completion: if script was active and all scripted spawns have happened and no enemies left
    -- First, update enemies and remove those flagged for removal (fallen off platforms)
    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]
        if e and e.update then
            pcall(e.update, e, dt, self)
        end
        if e and e.remove then
            -- use removeEnemy so group death counters are maintained
            self:removeEnemy(i)
        end
    end

    -- enemy-player collision: check overlaps and apply damage
    if self.player then
        for i = #self.enemies, 1, -1 do
            local e = self.enemies[i]
            if e then
                if e.x < self.player.x + self.player.w and e.x + e.w > self.player.x and e.y < self.player.y + self.player.h and e.y + e.h > self.player.y then
                    -- collision: decide damage (half-hearts)
                    local damage = 1
                    if e.maxHits == 10 or e.type == "boss" then damage = 2 end
                    -- apply damage only if player not invulnerable
                    if self.player.invulnTime <= 0 then
                        self.player:takeDamage(damage)
                        -- give the player a small knockback away from the enemy so they separate
                        local px = self.player.x + self.player.w/2
                        local ex = e.x + e.w/2
                        local dir = 0
                        if px > ex then dir = 1 else dir = -1 end
                        self.player.vx = dir * 140
                        -- do NOT remove the enemy on touch; the enemy should survive collisions
                    end
                end
            end
        end
    end

    if self.scriptActive and self.scriptTotalSpawns <= 0 and #self.enemies == 0 then
        self.scriptActive = false
        self.completed = true
        if self.onComplete then pcall(self.onComplete, self) end
    end
    
    -- update coins physics and check pickups
    if self.coins then
        for i = #self.coins, 1, -1 do
            local c = self.coins[i]
            -- simple physics
            c.vy = c.vy + 600 * dt
            c.x = c.x + c.vx * dt
            c.y = c.y + c.vy * dt
            -- landing on platforms: if coin intersects platform from above, snap to top and zero vy
            for _, p in ipairs(self.platforms) do
                local rx, ry, rw, rh = p[1], p[2], p[3], p[4]
                if c.x > rx - 8 and c.x < rx + rw + 8 then
                    if c.y >= ry - 8 and c.y <= ry + 12 then
                        c.y = ry - 6
                        c.vy = 0
                    end
                end
            end
            -- pickup by player: simple overlap with player's rectangle (use coin as small box)
            if self.player then
                local px, py, pw, ph = self.player.x, self.player.y, self.player.w, self.player.h
                if c.x > px and c.x < px + pw and c.y > py and c.y < py + ph then
                    if self.player.money ~= nil then
                        self.player.money = self.player.money + (c.amount or 0)
                    end
                    table.remove(self.coins, i)
                end
            end
        end
    end
end

-- coins: simple pickup entities created when an enemy is killed by player
-- each coin: { x, y, vx, vy, w, h, amount }

function Level:_spawnCoin(x, y, amount)
    self.coins = self.coins or {}
    -- spawn slightly above death point and give small random impulse
    -- keep coins static on the x-axis (vx = 0)
    local c = { x = x, y = y - 6, vx = 0, vy = -120 + math.random(-20,20), w = 10, h = 10, amount = amount }
    table.insert(self.coins, c)
end


function Level:setEnemySpawnInterval(seconds)
    self.enemySpawnInterval = seconds
    self.randomSpawnInterval = seconds
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
    -- draw coins as small yellow triangles
    if self.coins then
        love.graphics.setColor(1, 0.9, 0.2)
        for _, c in ipairs(self.coins) do
            local cx = c.x
            local cy = c.y
            local size = 8
            -- draw an upward triangle centered at (cx,cy)
            love.graphics.polygon("fill", cx, cy - size/2, cx - size/2, cy + size/2, cx + size/2, cy + size/2)
        end
        love.graphics.setColor(1,1,1)
    end
end

function Level:removeEnemy(index, byPlayer)
    local e = self.enemies[index]
    if e and e.group and self.groups and self.groups[e.group] then
        self.groups[e.group].deaths = (self.groups[e.group].deaths or 0) + 1
    end
    if e then
        self.kills = (self.kills or 0) + 1
        if byPlayer then
            self.killsByPlayer = (self.killsByPlayer or 0) + 1
            -- award coins to player based on enemy type and level coinValues
            local amount = 0
            if e and e.coin then
                amount = e.coin
            elseif e and e.type and self.coinValues then
                amount = self.coinValues[e.type] or 0
            end
            -- spawn a coin pickup at enemy position (one per enemy)
            if amount and amount > 0 then
                -- spawn visual coin that the player must pick up
                self:_spawnCoin(e.x + (e.w or 16)/2, e.y + (e.h or 16)/2, amount)
            else
                -- still add zero if needed
            end
            -- do not immediately add to player.money; player must pick it up
        end
        if self.onKill then pcall(self.onKill, self, e, byPlayer) end
    end
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
