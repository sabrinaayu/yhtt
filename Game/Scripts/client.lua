require("util/strict")
require("constants")
require("util/util")
require("util/vector2")
require("util/mathutil")
require("ship")
require("physics")
require("payload")
require("obstacle")
require("render")
require("network")
require("input")
TUNING = require("tuning")

gClient = nil

local gRemoteView = nil
local gRemoteID = "0"

gRenderDt = 0
explosions = {}

local lastMouse = Vector2(0,0)

function love.keypressed(key)
end

function sendinput(client)
	local input = defaultinput()
	local pkg = beginpack()
	for k,v in pairs(input) do
		if love.keyboard.isDown(k) then
			pkg = pack(pkg, k, 1)
		end
	end
	
	local mouse = Vector2(love.mouse.getX(), love.mouse.getY())
	if (lastMouse - mouse):Length() > 2.0 then
		pkg = pack(pkg, 'm_x', love.mouse.getX() - Renderer.offset_x)
		pkg = pack(pkg, 'm_y', love.mouse.getY() - Renderer.offset_y)
	end
	lastMouse = mouse

	if love.mouse.isDown("r") then
		pkg = pack(pkg, 'm_r', 1)
	end
	if love.mouse.isDown("l") then
		pkg = pack(pkg, 'm_l', 1)
	end

	pkg = endpack(pkg)
	send(client, pkg, 'input')
end

gQueuedFrames = 0
function client_draw()
	local start_time = socket.gettime()

	local id_message = nextmessage(gClient, 'ID')
	if id_message and gRemoteID == "0" then
		gRemoteID = id_message
	end
	
	updateclient(gClient)		
	
	local message_count = messagecount(gClient, 'view')
	local message = nextmessage(gClient, 'view')
	gQueuedFrames = message_count - 1
	if message == nil then
		print('FPS: Running ahead!')
		while message_count < 2 do
			updateclient(gClient)
			message_count = messagecount(gClient, 'view')
		end
		message = nextmessage(gClient, 'view')
	end

	if message_count > 4 then
		print('FPS: Lagging behind!')
		while message_count > 3 do		
			message = nextmessage(gClient, 'view')
			message_count = messagecount(gClient, 'view')
		end
	end

	if message then
		gRemoteView = unpack(1, message)
	end


	
	if gRemoteView then
		Renderer:Draw(function()		

			local arena = gRemoteView.arena
			love.graphics.setColor(125,55,55,255)
			local thickness = 5
			love.graphics.rectangle("fill", -thickness, -thickness, thickness, arena.h + thickness*2)
			love.graphics.rectangle("fill", -thickness, -thickness, arena.w + thickness*2, thickness)
			love.graphics.rectangle("fill", -thickness, arena.h, arena.w + thickness*2, thickness)
			love.graphics.rectangle("fill", arena.w, -thickness, thickness, arena.h + thickness*2)

			for k,goal in pairs(gRemoteView.goals) do
				if goal.t == 0 then
					love.graphics.setColor(5,55,15,255)
					love.graphics.rectangle("fill",
										goal.x-goal.w/2,
										goal.y-goal.h/2,
										goal.w,
										goal.h)
					love.graphics.setColor(55,255,155,255)
					love.graphics.rectangle("line",
										goal.x-goal.w/2,
										goal.y-goal.h/2,
										goal.w,
										goal.h)
				else
					love.graphics.setColor(15,5,55,255)
					love.graphics.rectangle("fill",
										goal.x-goal.w/2,
										goal.y-goal.h/2,
										goal.w,
										goal.h)
					love.graphics.setColor(155,55,255,255)
					love.graphics.rectangle("line",
										goal.x-goal.w/2,
										goal.y-goal.h/2,
										goal.w,
										goal.h)
				end
			end

			for k,payload in pairs(gRemoteView.plds) do
				if payload.t == 0 then
					love.graphics.setColor(95,255,195,255)
				elseif payload.t == 1 then
					love.graphics.setColor(195,95,255,255)
				else
					love.graphics.setColor(255,255,255,255)
				end
				love.graphics.circle("fill", payload.x, payload.y, PAYLOAD_SIZE.rad, PAYLOAD_SIZE.segs )
				
				-- attachments
				local prevWidth = love.graphics.getLineWidth()
				love.graphics.setLineWidth(2)
				for k,v in pairs(payload.l) do
					love.graphics.line(payload.x, payload.y, v.x, v.y)
				end
				love.graphics.setLineWidth(prevWidth)
			end

			for k,ship in pairs(gRemoteView.ships) do

				--team color
				if ship.t == 0 then
					love.graphics.setColor(55,255,155,255)
				else
					love.graphics.setColor(155,55,255,255)
				end

				--if ship.p == 1 then
					--love.graphics.setColor(55,255,155,255)
				--end
				
				-- the ship
				DrawTriangle(10, 6, ship.x, ship.y, ship.a)

				-- attachments
				local prevWidth = love.graphics.getLineWidth()
				love.graphics.setLineWidth(2)
				for k,v in pairs(ship.l) do
					love.graphics.line(ship.x, ship.y, v.x, v.y)
				end
				love.graphics.setLineWidth(prevWidth)

				-- shield
				if ship.h > 0 then
					love.graphics.setColor(ship.h*255,ship.h*255,255,255)
				else
					love.graphics.setColor(255,0,0,255)
				end

				if k == gRemoteID then
					love.graphics.setLineWidth(2)
				end
				love.graphics.circle("line", ship.x, ship.y, ship.r)
				love.graphics.setLineWidth(prevWidth)
				
				-- thrusters
				if ship.it == 1 then -- TODO: detect whether or not a ship is thrusting!
					local flameLen = math.random()*0.8+0.2
					love.graphics.setColor(255,190,100,255)
					DrawTriangle(30*flameLen, 6, ship.x, ship.y, ship.a-math.pi, 15*flameLen+5, 0)
					love.graphics.setColor(255,255,255,255)
					DrawTriangle(20*flameLen, 4, ship.x, ship.y, ship.a-math.pi, 10*flameLen+5, 0)
				end

				if k == gRemoteID then
					Renderer:SetCameraPos(ship.x, ship.y)
				end
			end

			for k,bullet in pairs(gRemoteView.blts) do
				if bullet.t == 0 then
					love.graphics.setColor(55,255,155,255)
				else
					love.graphics.setColor(155,55,255,255)
				end
				DrawRectangle(5,2,bullet.x, bullet.y, bullet.a)
				local flameLen = math.random()*0.7+0.2
				love.graphics.setColor(255,190,100,255)
				DrawTriangle(15*flameLen, 3, bullet.x, bullet.y, bullet.a-math.pi, 7.2*flameLen+5, 0)
				love.graphics.setColor(255,255,255,255)
				DrawTriangle(10*flameLen, 2, bullet.x, bullet.y, bullet.a-math.pi, 5*flameLen+5, 0)				
			end

			for k,expl in pairs(explosions) do
				if expl.team == 0 then
					love.graphics.setColor(55,255,155,expl.alpha)
				else
					love.graphics.setColor(155,55,255,expl.alpha)
				end

				for k,v in pairs(expl.particles) do
					love.graphics.rectangle("fill", v.pos.x, v.pos.y, expl.size, expl.size)
				end
			end

			for k,obstacle in pairs(gRemoteView.obs) do
				love.graphics.setColor(155,155,155,255)
				love.graphics.circle("fill", obstacle.x, obstacle.y, obstacle.r)				
			end




		end)
	end

	gRenderDt = socket.gettime() - start_time

	
	local remote_frame_id = 0
	if gRemoteView then
		remote_frame_id = gRemoteView.frame_id
	end
end

function client_load()
	gClient = startclient(getip(), getport())
	Renderer:Load()	
end

function client_update(dt)
	sendinput(gClient)
	updateclient(gClient)	
	for k,expl in pairs(explosions) do
		expl:Update(dt)
	end
end


