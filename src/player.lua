local Player = {}
Player.__index = Player

local GRAVITY = 1500
local MOVE_SPEED = 200
local JUMP_VELOCITY = -650
local SHOOT_VELOCITY = 600

function Player.new(x, y, level)
    local self = setmetatable({}, Player)
    self.x = x
    self.y = y
    self.w = 32
    self.h = 48
    self.vx = 0
    self.vy = 0
    self.onGround = false
    self.bullets = {} -- active bullets
    self.firing = false
    self.fireRate = 4 -- bullets per second (kept for backward compatibility)
    self.fireInterval = 1 / self.fireRate -- seconds between shots
    self.fireTimer = 0
    self.lastMouseX = 0
    self.lastMouseY = 0
    -- per-player bullet speed (can be changed externally)
    self.bulletSpeed = SHOOT_VELOCITY
    self.level = level
    -- health: 5 hearts represented as 10 half-hearts
    self.maxHalfHearts = 10
    self.halfHearts = self.maxHalfHearts
    -- money
    self.money = 0
    -- invulnerability after taking damage (seconds)
    self.invulnTime = 0
    self.invulnDuration = 0.8
    -- alive state
    self.dead = false
    return self
end

function Player:update(dt)
    -- Horizontal movement
    local left = love.keyboard.isDown("a") or love.keyboard.isDown("left")
    local right = love.keyboard.isDown("d") or love.keyboard.isDown("right")

    if left then
        self.vx = -MOVE_SPEED
    elseif right then
        self.vx = MOVE_SPEED
    else
        self.vx = 0
    end

    -- Apply gravity
    self.vy = self.vy + GRAVITY * dt

    -- Integrate position
    local nextX = self.x + self.vx * dt
    local nextY = self.y + self.vy * dt

    -- Simple AABB collision with level platforms
    self.onGround = false
    -- Check vertical collisions
    local collidedY, correctedY, vy, landed = self.level:checkVerticalCollision(self, nextY)
    if collidedY then
        nextY = correctedY
        self.vy = vy
        -- if we landed on a platform, mark onGround true
        if landed then
            self.onGround = true
        end
    end

    -- Check horizontal collisions
    local collidedX, correctedX = self.level:checkHorizontalCollision(self, nextX)
    if collidedX then
        nextX = correctedX
        self.vx = 0
    end

    self.x = nextX
    self.y = nextY

    -- update bullets
    for i = #self.bullets, 1, -1 do
        local b = self.bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        local removed = false
        -- check collision with enemies
        if self.level and self.level.enemies then
            for ei = #self.level.enemies, 1, -1 do
                local e = self.level.enemies[ei]
                if b.x + b.r > e.x and b.x - b.r < e.x + e.w and b.y + b.r > e.y and b.y - b.r < e.y + e.h then
                    -- hit
                    e.hitsRemaining = e.hitsRemaining - 1
                    table.remove(self.bullets, i)
                    removed = true
                    if e.hitsRemaining <= 0 then
                        self.level:removeEnemy(ei, true)
                    end
                    break
                end
            end
        end
        if removed then goto continue_bullet_loop end

        -- remove if off-screen or life expired
        if b.x < -50 or b.x > love.graphics.getWidth() + 50 or b.y < -50 or b.y > love.graphics.getHeight() + 50 or b.life <= 0 then
            table.remove(self.bullets, i)
        end
        ::continue_bullet_loop::
    end

    -- firing logic: if firing, spawn bullets at fireRate toward last mouse pos
    if self.firing then
        self.fireTimer = self.fireTimer - dt
        local interval = self.fireInterval or (1 / self.fireRate)
        while self.fireTimer <= 0 do
            -- spawn
            self:shoot(self.lastMouseX, self.lastMouseY)
            self.fireTimer = self.fireTimer + interval
        end
    else
        -- reset timer so we fire immediately when starting again
        self.fireTimer = 0
    end

    -- decrement invulnerability timer
    if self.invulnTime and self.invulnTime > 0 then
        self.invulnTime = math.max(0, self.invulnTime - dt)
    end
end

function Player:takeDamage(halfUnits)
    if self.invulnTime > 0 then return end
    self.halfHearts = math.max(0, self.halfHearts - (halfUnits or 1))
    self.invulnTime = self.invulnDuration
    -- death handling
    if self.halfHearts <= 0 then
        -- mark player as dead; main game loop will handle game over
        self.dead = true
    end
end

function Player:jump()
    if self.onGround then
        self.vy = JUMP_VELOCITY
        self.onGround = false
    end
end

function Player:draw()
    love.graphics.setColor(0.2, 0.6, 1)
    love.graphics.rectangle("fill", math.floor(self.x), math.floor(self.y), self.w, self.h)

    -- draw bullets
    love.graphics.setColor(1, 0.6, 0.2)
    for _, b in ipairs(self.bullets) do
        love.graphics.circle("fill", b.x, b.y, b.r)
    end

    -- draw hearts UI (half hearts)
    local startX = 12
    local startY = 12
    local hh = self.halfHearts
    for i = 1, self.maxHalfHearts do
        local x = startX + (i-1) * 14
        if hh >= i then
            love.graphics.setColor(1, 0.1, 0.1)
            love.graphics.rectangle("fill", x, startY, 12, 12)
        else
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.rectangle("line", x, startY, 12, 12)
        end
    end
    love.graphics.setColor(1,1,1)
    -- draw money
    love.graphics.print(string.format("Money: %d", self.money), 10, 32)
end

function Player:shoot(tx, ty)
    -- spawn a bullet from the player's center toward target (tx, ty)
    local sx = self.x + self.w / 2
    local sy = self.y + self.h / 2
    local dx = tx - sx
    local dy = ty - sy
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then len = 1 end
    local vx = (dx / len) * self.bulletSpeed
    local vy = (dy / len) * self.bulletSpeed
    local bullet = { x = sx, y = sy, vx = vx, vy = vy, r = 4, life = 2 }
    table.insert(self.bullets, bullet)
end

return Player
