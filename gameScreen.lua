module(..., package.seeall)

require( "physics" )
require( "smoothCurve")

physics.start()
physics.setDrawMode ( "normal" )	 -- Uncomment if you want to see all the physics bodies
physics.setGravity(0,0) 

local assetPath = "assets/"

local mainGroup = display.newGroup()

-- Plane properties
local planeSpeed = 50
local planeSpawnInterval = 4000
local minDistanceBetweenFlightPoint = 20
local planLandingTime = 2000 -- Amount of time the plane must stay in the landing strip in order for it to "land" 

local lineDrawInterval = 50

local planeImages -- Will contain a list of plane images

local yellowHighlight = display.newImage( assetPath .. "yellow.png");	yellowHighlight.alpha = .50; 	yellowHighlight.isVisible = false;
local blueHighlight = display.newImage( assetPath .. "blue.png")		blueHighlight.alpha = .50; 		blueHighlight.isVisible = false;
local redHighlight = display.newImage( assetPath .. "red.png")			redHighlight.alpha = .50; 		redHighlight.isVisible = false;

local backgroundGroup = display.newGroup(); mainGroup:insert(backgroundGroup)
local lineGroup = display.newGroup()		mainGroup:insert(lineGroup)
local planeGroup = display.newGroup()		mainGroup:insert(planeGroup)


function new()
	
	setUpBackgroundImages()
	initPlanes() 	 

	startGame()
	
	return mainGroup
end

function startGame()
	
	spawnRandomPlane()
	timer.performWithDelay(planeSpawnInterval,spawnRandomPlane, 0)
	
end

-- Will Spawn a random plane outside the screen, that will  be traveling towards the center of the screen
function spawnRandomPlane()
		
	local angle = math.random(1, 360)-- Generate a random angle for this plane to be positioned relative to the center of the screen
	local lengthFromCenter = display.contentHeight * (3/4) -- How far the planes will spawn from the center
	
	local plane = getRandomPlane(lengthFromCenter * math.cos(math.rad(angle))	+ display.contentWidth / 2, lengthFromCenter * math.sin(math.rad(angle)) * -1  + display.contentHeight / 2)

	plane.rotation = -90 - angle -- Calcualte the rotation of the plane (so it faces towards the center)

	plane.touch = onPlaneTouched
	plane:addEventListener("touch", plane)
	
	plane.collision = onPlaneCollision
	plane:addEventListener("collision", plane)

	-- Set the plane speed
	plane:setLinearVelocity( math.cos(math.rad(angle)) * planeSpeed * -1,  math.sin(math.rad(angle)) * planeSpeed )
end	

function getRandomPlane(posX, posY)
	
	local planeIndex = math.random(1, #planeImages)
	
	local planeImage = planeImages[planeIndex]
	local plane = display.newImage( planeImage.body)
	
	plane.x = posX
	plane.y = posY
	
	-- Special case for the helicopter
	if(planeImage.propeller ~= nil) then
		local physicsData = (require "helicopterShape").physicsData(1)
		physics.addBody(plane, "dynamic",  {density = 100, isSensor = true, radius = 40})
		
		plane.propeller = display.newImage(planeImage.propeller)
		physics.addBody(plane.propeller, "dynamic",  physicsData:get("propeller"))

		plane.propeller.x = plane.x 
		plane.propeller.y = plane.y - plane.height / 10

		plane.rotationJoint = physics.newJoint( "pivot", plane, plane.propeller, plane.propeller.x ,plane.propeller.y )
		
		plane.rotationJoint.isMotorEnabled = true
		plane.rotationJoint.motorSpeed = 1000
		plane.rotationJoint.maxMotorTorque = 10000

	else
		local physicsData = (require "planeShape").physicsData(1)
		physics.addBody(plane, "dynamic",  physicsData:get("plane"))
	end
		
	plane.type = planeIndex
	
	plane.highlight = planeIndex == 1 and blueHighlight or planeIndex == 2 and yellowHighlight or planeIndex == 3 and redHighlight
	
	return plane
end

function initPlanes()
	
	planeImages = {}
	table.insert(planeImages, {body = assetPath ..  "plane1.png"})
	table.insert(planeImages, {body = assetPath ..  "plane2.png"})
	table.insert(planeImages, {body = assetPath ..  "helicopter.png", propeller = assetPath .. "propeller.png"})
	
end

function onPlaneCollision(self, event)
	
	local otherObject = event.other
	
	-- If a plane has collided with another plane remove the colliding planes
	if(otherObject.type == 1 or otherObject.type == 2 or otherObject.type == 3) then
		
		self.angularVelocity = 500
		event.other.angularVelocity = 500
		
		removePlane(self)
		removePlane(event.other)	
	end	
end

function onPlaneTouched(self, event)

	if(event.phase == "began") then
		
		self.allowLineDraw = true
		self.lineType = "dotted"
		
		self.points = {}
		table.insert(self.points, {x = event.x, y = event.y})

		display.getCurrentStage():setFocus( self )
		self.isFocus = true
		
		self.highlight.isVisible = true
		
	elseif (event.phase == "moved" and self.isFocus == true ) then
		
		if(#self.points == 0) then
			self.points = {}
			table.insert(self.points, {x = self.x, y = self.y})
			table.insert(self.points, {x = event.x, y = event.y})
		end

		local distance = math.sqrt(math.pow(self.points[#self.points].x - event.x, 2) + math.pow(self.points[#self.points].y - event.y, 2))
		if(distance > minDistanceBetweenFlightPoint) then
			
			table.insert(self.points, {x = event.x, y = event.y})
		
			if(self.allowLineDraw == true) then 
				drawLine(self)		
				followPoints(self)		 
			
				self.allowLineDraw = false
				timer.performWithDelay(lineDrawInterval, function(new) self.allowLineDraw = true end)
			end
		end
	elseif(event.phase == "ended" and #self.points > 0) then
	
		local distance = math.sqrt(math.pow(self.points[#self.points].x - event.x, 2) + math.pow(self.points[#self.points].y - event.y, 2))
		if(self.isFocus == true and distance > minDistanceBetweenFlightPoint) then
			table.insert(self.points, {x = event.x, y = event.y})
		end

		display.getCurrentStage():setFocus(nil)
		self.isFocus = false
		
		followPoints(self)		
		
		self.lineType = "solid"
		drawLine(self)
		
		self.highlight.isVisible = false
		
	end
end


function drawLine(plane)

	if(plane.lineGroup ~= nil) then 
		plane.lineGroup:removeSelf()
		plane.lineGroup = nil 
	end

	local smoothPoints = smoothCurve.getSmoothCurvePoints(plane.points)	
	if(smoothPoints == nil) then return end
	
	plane.lineGroup = display.newGroup()
	lineGroup:insert(plane.lineGroup)

	local modNumber = plane.lineType == "dotted" and 2 or 1
	
	for i = 0 ,#smoothPoints do
		if(i % modNumber == 0 and smoothPoints[i] ~= nil and smoothPoints[i + 1] ~= nil) then 
			local line = display.newLine(smoothPoints[i].x, smoothPoints[i].y, smoothPoints[i + 1].x, smoothPoints[i + 1].y)
			
			line.width = modNumber == 1 and 1 or 3
			
			plane.lineGroup:insert(line)
		end
	end
	
	return smoothPoints
	
end	

function followPoints(plane)

	if(plane.points == nil or #plane.points == 0) then return end;

	point = plane.points[1]

	local flightAngel = math.atan2((plane.y - point.y) , (plane.x - point.x) ) * (180 / math.pi)
	
	local velocityX = math.cos(math.rad(flightAngel)) * planeSpeed * -1
 	local velocityY = math.sin(math.rad(flightAngel)) * planeSpeed * -1
	
	plane.rotation = flightAngel - 90

	plane:setLinearVelocity( velocityX, velocityY)
	
	local enterFrameFunction = nil
	local checkForNextPoint
	checkForNextPoint = function(plane)
	
		if(plane ~= nil) then
	
			local dest = plane.dest

			local velX, velY = plane:getLinearVelocity()
		
			if(	(velX < 0 and plane.x < dest.x and velY < 0 and plane.y < dest.y) or  (velX > 0 and plane.x > dest.x and velY < 0 and plane.y < dest.y) or
				(velX > 0 and plane.x > dest.x and velY > 0 and plane.y > dest.y) or  (velX < 0 and plane.x < dest.x and velY > 0 and plane.y > dest.y) or #plane.points == 0) then
			
				Runtime:removeEventListener("enterFrame", enterFrameFunction)
				table.remove(plane.points, 1)
			
				drawLine(plane)
				if(#plane.points > 0) then
					followPoints(plane)
				end

			end		
		else
			Runtime:removeEventListener("enterFrame", enterFrameFunction)
		end
	end
	
	plane.dest = point
	enterFrameFunction = function(event) checkForNextPoint(plane) end

	Runtime:addEventListener("enterFrame", enterFrameFunction)

end

function getRandomPlaneImage()
	
	return planeImages[math.random(1, #planeImages)]
end

function onHelicopterPadCollision(self, event)

	local plane = event.other	

	if(plane.type == 3) then
		plane.rotationJoint.motorSpeed = 250
		plane.points = {}
		table.insert(plane.points, {x = self.x, y = self.y})				
		
		local onTimerComplete = function(event)
			followPoints(plane) 		
			
			local velX, velY = plane:getLinearVelocity()

			plane:setLinearVelocity(velX * .5, velY * .5)
			
			removePlane(plane)
		end
		
		-- Need to put this in a timer since you can't rotate an object during a collision
		timer.performWithDelay(10, onTimerComplete)
	end

end

function onLandingStripCollision(self, event)

	local plane = event.other	
	local landingStrip = self

	if(plane.type == landingStrip.landingPlaneType and plane.x < landingStrip.leftMostCoord + 30 and plane.isLanding == nil) then 

		plane.isLanding = true

		local planeLandedTimer 
		local checkPlaneLanding 
 		checkPlaneLanding = function(event)		

			if(isPointInPoly(landingStrip.numOfVerts, landingStrip.verts, {x=plane.x , y=plane.y}) == false) then
				timer.cancel(planeLandedTimer) 	
				Runtime:removeEventListener("enterFrame", checkPlaneLanding)
				plane.isLanding = nil
				
				
			end
				
		end
		-- The plane's center must stay in the landing strip for 'planLandingTime' amount of millisecond
		planeLandedTimer = timer.performWithDelay(planLandingTime, function(event) Runtime:removeEventListener("enterFrame", checkPlaneLanding);  removePlane(plane); end)
		Runtime:addEventListener("enterFrame", checkPlaneLanding)		
	end	
end

function removePlane(plane)
	
	plane.points = {}
	plane.type = "dead" -- Set the type to something other then 1,2, or 3 so this plane does not cause other planes to crash
	plane:removeEventListener("touch", plane)
	plane:removeEventListener("collision", plane)
	
	local onPlaneTransitionComplete = function(obj)
		if(obj ~= nil and obj.removeSelf ~= nil) then 

			obj:removeSelf()
			obj = nil
		end
	end
	
	transition.to( plane, { time=2000, xScale = .25, yScale = .25, alpha=0, onComplete=onPlaneTransitionComplete} )	
	
	if(plane.propeller ~= nil) then
		transition.to( plane.propeller, { time=2000, xScale = .25, yScale = .25, alpha=0, onComplete=onPlaneTransitionComplete} )
	end
end

function setUpBackgroundImages()

	-- local water = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
	-- water:setFillColor(173, 216, 230, 255 * .5)
	-- backgroundGroup:insert(water)

	local water1 = display.newImageRect(assetPath .. "waterFrame1.png", 1024, 768)
	water1.x, water1.y = display.contentWidth / 2, display.contentHeight / 2
	backgroundGroup:insert(water1)
	
	local water2 = display.newImageRect(assetPath .. "waterFrame2.png", 1024, 768)
	water2.x, water2.y = display.contentWidth / 2, display.contentHeight / 2
	backgroundGroup:insert(water2)
	
	local fadeOut, fadeIn
	local fadeTime = 1500
	
	fadeOut = function() transition.to(water2, {time=fadeTime, alpha = .25, onComplete= function(event) fadeIn() end}) end
	fadeIn = function() transition.to(water2, {time=fadeTime, alpha = 1, onComplete= function(event) fadeOut() end}) end
	
	fadeOut()
	
	local ship = display.newImageRect(assetPath .. "ship.png", 1024, 768)
	ship.x, ship.y = display.contentWidth / 2, display.contentHeight / 2
	backgroundGroup:insert(ship)
	
	local yellowLandingStrip = display.newRect( 0, 0, display.contentWidth, display.contentHeight )	
	yellowLandingStrip:setFillColor(0, 255, 0, 255 * 0)
	backgroundGroup:insert(yellowLandingStrip)	
	physics.addBody(yellowLandingStrip, "static", {isSensor = true, shape = { -70, 55,  -232,-107,  -222,-153,  -14, 55 }})
	
	-- Info that will be used for checking if the plan is landing correctly
	yellowLandingStrip.verts = {}
	table.insert(yellowLandingStrip.verts, {x=-70 + display.contentWidth / 2, y=55 + display.contentHeight / 2})
	table.insert(yellowLandingStrip.verts, {x=-232 + display.contentWidth / 2, y=-107 + display.contentHeight / 2})
	table.insert(yellowLandingStrip.verts, {x=-222 + display.contentWidth / 2, y=-153 + display.contentHeight / 2})
	table.insert(yellowLandingStrip.verts, {x=-14 + display.contentWidth / 2, y=55 + display.contentHeight / 2})
	yellowLandingStrip.numOfVerts = 4
	yellowLandingStrip.leftMostCoord = yellowLandingStrip.verts[2].x -- Will be used so that plane can only land from the left side of the strip
	yellowLandingStrip.landingPlaneType = 2
	
	yellowLandingStrip.collision = onLandingStripCollision
	yellowLandingStrip:addEventListener("collision", yellowLandingStrip)
	
	
	
	local blueLandingStrip = display.newRect( 0, 0, 495, 40 )
	blueLandingStrip:setFillColor(0, 255, 0, 255 * 0)
	backgroundGroup:insert(blueLandingStrip)
	
	blueLandingStrip.x = display.contentWidth / 2   - 5
	blueLandingStrip.y = display.contentHeight / 2 + 90
	physics.addBody(blueLandingStrip, "static", {isSensor = true})
	
	-- Info that will be used for checking if the plan is landing correctly
	blueLandingStrip.verts = {}
	table.insert(blueLandingStrip.verts, {x=blueLandingStrip.contentBounds.xMin, y=blueLandingStrip.contentBounds.yMin})
	table.insert(blueLandingStrip.verts, {x=blueLandingStrip.contentBounds.xMax, y=blueLandingStrip.contentBounds.yMin})
	table.insert(blueLandingStrip.verts, {x=blueLandingStrip.contentBounds.xMax, y=blueLandingStrip.contentBounds.yMax})
	table.insert(blueLandingStrip.verts, {x=blueLandingStrip.contentBounds.xMin, y=blueLandingStrip.contentBounds.yMax})
	blueLandingStrip.numOfVerts = 4
	blueLandingStrip.leftMostCoord = yellowLandingStrip.verts[1].x -- Will be used so that plane can only land from the left side of the strip
	blueLandingStrip.landingPlaneType = 1
	
	blueLandingStrip.collision = onLandingStripCollision
	blueLandingStrip:addEventListener("collision", blueLandingStrip)
		
	local helicopterPad = display.newCircle( 0, 0, 15 )
	helicopterPad:setFillColor(0, 255, 0, 255 * 0)
	helicopterPad.x = 485
	helicopterPad.y = 230
	physics.addBody(helicopterPad, "static", {isSensor = true, radius = helicopterPad.width / 2})
	
	helicopterPad.collision = onHelicopterPadCollision
	helicopterPad:addEventListener("collision", helicopterPad)
	
end

-- Will use this to test if the plane is within the bounds of the landing strips
-- Taken from... http://stackoverflow.com/questions/217578/point-in-polygon-aka-hit-test/2922778#2922778
--
-- numOfVerts: Number of vertices in the polygon
-- polyVerts: An array containing the x and y coordinates of the polygon's vertices
-- point: The point to test against
function isPointInPoly(numOfVerts, polyVerts, point)
	
	local i, j
	local result = false
	
	j = numOfVerts
	i = 1
	while (i <= numOfVerts ) do 
		
		if ( ((polyVerts[i].y > point.y) ~= (polyVerts[j].y > point.y)) and 
			(point.x < (polyVerts[j].x - polyVerts[i].x) * (point.y - polyVerts[i].y) / (polyVerts[j].y - polyVerts[i].y) + polyVerts[i].x )) then
			
			if (result == false) then result = true else result = false end
		end
		
		j = i
		i = i + 1
	end

	return result
end