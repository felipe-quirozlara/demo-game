local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(x, y, w, h, hits, jumpVel)
    local self = setmetatable({}, Enemy)
    self.x = x
    self.y = y
    self.w = w or 32
    self.h = h or 32
    self.hitsRemaining = hits or 2
    self.maxHits = hits or 2
    -- derive type from hits if not explicitly set later
    if self.maxHits == 2 then
        self.type = "grunt"
    elseif self.maxHits == 3 then
        self.type = "soldier"
    elseif self.maxHits == 5 then
        self.type = "heavy"
    elseif self.maxHits == 10 then
        self.type = "boss"
    else
        self.type = "grunt"
    end
    self.group = nil

    -- movement state
    self.vx = 0
    self.vy = 0
    -- vertical physics
    self.gravity = 600
    -- default speeds (can be tuned)
    self.speed = 80
    self.chaseSpeed = 70
    if self.type == "boss" then self.chaseSpeed = 110 end
    -- direction for patrolling grunts: 1 = right, -1 = left
    -- default direction; for grunts choose randomly
    if self.type == "grunt" then
        if math.random(0,1) == 0 then
            self.direction = -1
        else
            self.direction = 1
        end
    else
        self.direction = 1
    end
    -- mark for removal when fallen off platform
    self.remove = false
    -- per-enemy jump velocity (negative value). If provided, use it; otherwise choose sensible defaults by type
    if jumpVel then
        self.jumpVelocity = jumpVel
    else
        if self.type == "soldier" then
            self.jumpVelocity = -440
        elseif self.type == "heavy" then
            self.jumpVelocity = -440
        elseif self.type == "boss" then
            self.jumpVelocity = -440
        else
            self.jumpVelocity = -440
        end
    end
    return self
end

-- Helper: simple AABB overlap
local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- Find the platform directly under the enemy (if any)
local function platformUnder(self, platforms)
    for _, p in ipairs(platforms) do
        local rx, ry, rw, rh = p[1], p[2], p[3], p[4]
        -- consider platform if enemy's bottom is at or slightly above the platform y
        if self.x + self.w > rx and self.x < rx + rw then
            if math.abs((self.y + self.h) - ry) <= 4 or (self.y + self.h) <= ry then
                return p
            end
        end
    end
    return nil
end

function Enemy:update(dt, level)
    -- Do not perform physics if flagged for removal
    if self.remove then return end

    -- default behavior by type
    -- Horizontal movement based on type
    if self.type == "grunt" then
        -- patrol horizontally in a straight line
        self.vx = self.direction * self.speed
    elseif self.type == "soldier" or self.type == "boss" or self.type == "heavy" then
        -- chaser behavior: move horizontally toward player; no jumping
        if level and level.player then
            local px = level.player.x + level.player.w/2
            local ex = self.x + self.w/2
            local dir = 0
            if math.abs(px - ex) > 6 then
                if px > ex then dir = 1 else dir = -1 end
            end
            local s = self.chaseSpeed
            if self.type == "heavy" then s = self.chaseSpeed * 0.85 end
            self.vx = dir * s
        else
            self.vx = 0
        end
        -- Jumping behavior for chasers: if player is above and nearby, try a jump (only from ground)
        if level and level.player then
            local onPlat = platformUnder(self, level.platforms)
            local isOnGround = onPlat and math.abs((self.y + self.h) - onPlat[2]) <= 4 and self.vy == 0
            if isOnGround then
                local px = level.player.x + level.player.w/2
                local ex = self.x + self.w/2
                local dx = math.abs(px - ex)
                local playerAbove = (level.player.y + level.player.h) < (self.y - 6)
                -- if player is above (platform above) and not too far horizontally, perform a jump
                if playerAbove and dx < 220 then
                    -- apply per-enemy jump velocity scaled by level multiplier (if present)
                    local multiplier = 1
                    if level and level.enemyJumpMultiplier then multiplier = level.enemyJumpMultiplier end
                    local baseJump = self.jumpVelocity or -300
                    self.vy = baseJump * multiplier
                end
            end
        end
    end

    -- Apply horizontal movement
    self.x = self.x + self.vx * dt

    -- Apply gravity
    self.vy = self.vy + self.gravity * dt
    local nextY = self.y + self.vy * dt

    -- Landing detection: if the enemy would land on a platform, snap to it and zero vy
    local landed = false
    for _, p in ipairs(level.platforms) do
        local rx, ry, rw, rh = p[1], p[2], p[3], p[4]
        -- horizontal overlap
        if self.x + self.w > rx and self.x < rx + rw then
            -- if moving downward and crossing the platform top
            if self.y + self.h <= ry and nextY + self.h >= ry then
                -- land on platform
                nextY = ry - self.h
                self.vy = 0
                landed = true
                break
            end
        end
    end

    self.y = nextY

    -- If enemy falls below the bottom of the screen, remove it
    local screenH = love.graphics.getHeight()
    if self.y > screenH + 200 then
        self.remove = true
        return
    end
end

function Enemy:draw()
    -- color based on original hit requirement
    if self.maxHits == 2 then
        love.graphics.setColor(1, 0.2, 0.2) -- red
    elseif self.maxHits == 3 then
        love.graphics.setColor(0.2, 1, 0.2) -- green
    elseif self.maxHits == 5 then
        love.graphics.setColor(0.2, 0.4, 1) -- blue
    elseif self.maxHits == 10 then
        love.graphics.setColor(0.9, 0.4, 0.8) -- boss: purple
    else
        love.graphics.setColor(1, 0.2, 0.2)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setColor(1,1,1)
    love.graphics.print(tostring(self.hitsRemaining), self.x + self.w/2 - 4, self.y - 12)
end

return Enemy
