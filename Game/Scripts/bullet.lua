require("util/vector2")
require("util/class")

class("Bullet")

function Bullet:init(ship)
	self.ship = ship or nil
	self.position = Vector2(ship.position.x or 0, ship.position.y or 0)
	self.angle = ship.angle or 0 --rads
	
	self.speed = TUNING.BULLET.SPEED
	self.velocity = Vector2(0,0)
	self.size = deepcopy(BULLET_SIZE)
end

function Bullet:Update(dt)
	local directionVector = Vector2(math.cos(self.angle), math.sin(self.angle))
	local dir = directionVector * self.speed
	dir = dir * dt
	self.velocity = self.velocity + dir
	self.position = self.position + (self.velocity * dt)
end

function Bullet:Draw()
	love.graphics.setColor(255,255,255,255)
	love.graphics.rectangle("fill", self.position.x - (self.size.x * .5), self.position.y- (self.size.y * .5), BULLET_SIZE.x, BULLET_SIZE.y )
end

