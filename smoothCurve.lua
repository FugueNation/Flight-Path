module(..., package.seeall)


function getSmoothCurvePoints(points)

	-- Number of points must be at least 3
	if(#points < 3) then return nil end

	local smoothPoints = {}

    -- Steps Per Segment - The Higher The Number - The Smoother The Curve - The Longer It Takes To Calculate
    local curveSteps = 30
    
    -- First Segment
    local firstSegement = drawCatmullSpline( points[1] , points[1] , points[2] , points[3] , curveSteps )
    
    for i = 1 , #firstSegement , 1 do
		 table.insert(smoothPoints, {x = firstSegement[i].x, y = firstSegement[i].y})
    end
    
    -- Segments Inbetween
    for i = 2 , #points - 2 , 1 do
            local middleSegment = drawCatmullSpline( points[i-1] , points[i] , points[i+1] , points[i+2] , curveSteps )
            for i = 2 , #middleSegment , 1 do
					 table.insert(smoothPoints, {x = middleSegment[i].x, y = middleSegment[i].y})
            end
    end
    
    -- Last Segment
    local lastSegment = drawCatmullSpline( points[#points-2] , points[#points-1] , points[#points] , points[#points] , curveSteps )
    for i = 2 , #lastSegment , 1 do
			table.insert(smoothPoints, {x = lastSegment[i].x, y = lastSegment[i].y})
    end

	return smoothPoints
end

function drawCatmullSpline( p0 , p1 , p2 , p3 , steps )
 
    local points = {}

    for t = 0 , 1 , 1 / steps do

            local xPoint = 0.5 * ( ( 2 * p1.x ) + ( p2.x - p0.x ) * t + ( 2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x ) * t * t + ( 3 * p1.x - p0.x - 3 * p2.x + p3.x ) * t * t * t )
            local yPoint = 0.5 * ( ( 2 * p1.y ) + ( p2.y - p0.y ) * t + ( 2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y ) * t * t + ( 3 * p1.y - p0.y - 3 * p2.y + p3.y ) * t * t * t )
            
			
            table.insert( points , { x = xPoint , y = yPoint } )
            -- local dot = display.newCircle( xPoint , yPoint , 2 )
            -- dot:setFillColor( 255 , 0 , 0 )
    end
    
    return points
 
end