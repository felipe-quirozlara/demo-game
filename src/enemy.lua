local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(x, y, w, h, hits)
    local self = setmetatable({}, Enemy)
    self.x = x
    self.y = y
    self.w = w or 32
    self.h = h or 32
    self.hitsRemaining = hits or 2
    self.maxHits = hits or 2
    self.type = "grunt"
    return self
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
