local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(x, y, w, h, hits)
    local self = setmetatable({}, Enemy)
    self.x = x
    self.y = y
    self.w = w or 32
    self.h = h or 32
    self.hitsRemaining = hits or 2
    return self
end

function Enemy:draw()
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setColor(1,1,1)
    love.graphics.print(tostring(self.hitsRemaining), self.x + self.w/2 - 4, self.y - 12)
end

return Enemy
