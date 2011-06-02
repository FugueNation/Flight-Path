module(..., package.seeall)

require "ui"

local assetPath = "assets/"

local mainGroup = display.newGroup()

function new()
	
	local water = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
	water:setFillColor(173, 216, 230, 255 * .5)
	mainGroup:insert(water)

	local titleScreen = display.newImageRect(assetPath .. "title.png", display.contentWidth, display.contentHeight)
	titleScreen.x = display.contentWidth / 2
	titleScreen.y = display.contentHeight / 2
	mainGroup:insert(titleScreen)
	director:changeScene("titleScreen")
	
	local playButton = ui.newButton{ default = assetPath .. "playButton.png", onRelease = function(event)  director:changeScene("gameScreen") end,}
	playButton.x = display.contentWidth / 2
	playButton.y = display.contentHeight / 2
	mainGroup:insert(playButton)
	
	return mainGroup
end