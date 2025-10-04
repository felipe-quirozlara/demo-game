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
    return self
end

function Level:draw()
    love.graphics.setColor(0.4, 0.4, 0.4)
    for _, p in ipairs(self.platforms) do
        love.graphics.rectangle("fill", p[1], p[2], p[3], p[4])
    end
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
