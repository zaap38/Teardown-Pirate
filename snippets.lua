--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

---------------------------------

function clearConsole()
	for i=1, 25 do
		DebugPrint("")
	end
end

function rand(minv, maxv)
	minv = minv or nil
	maxv = maxv or nil
	if minv == nil then
		return math.random()
	end
	if maxv == nil then
		return math.random(minv)
	end
	return math.random(minv, maxv)
end

--Helper to return a random number in range mi to ma
function randFloat(mi, ma)
	return math.random(1000)/1000*(ma-mi) + mi
end

--Return a random vector of desired length
function randVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


function floorVec(v)
	return Vec(math.floor(v[1]), math.floor(v[2]), math.floor(v[3]))
end

function debugWatchTable(t)
	for k, v in pairs(t) do
		if type(v) ~= "boolean" then
			DebugWatch(k, string.format("%.1f", v))
		end
	end
end

function vecToString(v)
	return "Vec(" .. v[1] .. ", " .. v[2] .. ", " .. v[3] .. ")"
end


function getSpawnedEntities(ent, type, debug)
	debug = debug or false
	goodType = {}
	for i=1, #ent do
		if debug then
			DebugPrint(GetEntityType(ent[i]))
		end
		if GetEntityType(ent[i]) == type then
			goodType[#goodType + 1] = ent[i]
		end
	end
	return goodType
end

function fwd()
	return Vec(0, 0, -1)
end

function bwd()
	return Vec(0, 0, 1)
end

function drawAaBbBox(aa, bb, useDrawLine, r, g, b, a)
	useDrawLine = useDrawLine or false
	r = r or 1
	g = g or 1
	b = b or 1
	a = a or 1

	local f = DebugLine
	if useDrawLine then
		f = DrawLine
	end

	local start = aa
	local target = Vec(aa[1], aa[2], bb[3])
	f(start, target, r, g, b, a)
	start = aa
	target = Vec(bb[1], aa[2], aa[3])
	f(start, target, r, g, b, a)
	start = Vec(bb[1], aa[2], bb[3])
	target = Vec(aa[1], aa[2], bb[3])
	f(start, target, r, g, b, a)
	start = Vec(bb[1], aa[2], bb[3])
	target = Vec(bb[1], aa[2], aa[3])
	f(start, target, r, g, b, a)

	start = Vec(aa[1], bb[2], aa[3])
	target = Vec(aa[1], bb[2], bb[3])
	f(start, target, r, g, b, a)
	start = Vec(aa[1], bb[2], aa[3])
	target = Vec(bb[1], bb[2], aa[3])
	f(start, target, r, g, b, a)
	start = bb
	target = Vec(aa[1], bb[2], bb[3])
	f(start, target, r, g, b, a)
	start = bb
	target = Vec(bb[1], bb[2], aa[3])
	f(start, target, r, g, b, a)

	start = aa
	target = Vec(aa[1], bb[2], aa[3])
	f(start, target, r, g, b, a)
	start = Vec(bb[1], aa[2], aa[3])
	target = Vec(bb[1], bb[2], aa[3])
	f(start, target, r, g, b, a)
	start = Vec(aa[1], aa[2], bb[3])
	target = Vec(aa[1], bb[2], bb[3])
	f(start, target, r, g, b, a)
	start = Vec(bb[1], aa[2], bb[3])
	target = bb
	f(start, target, r, g, b, a)
end

function abRaycast(a, b, ignoreVehicles, radius)
	ignoreVehicles = ignoreVehicles or false
	radius = radius or 0
	
	local diff = VecSub(b, a)
	local dir = VecNormalize(diff)

	if ignoreVehicles then
		local v = FindVehicles("", true)
		for i=1, #v do
			QueryRejectVehicle(v[i])
		end
	end
	
	local hit, dist, normal, shape = QueryRaycast(a, dir, VecLength(diff), radius, false)
	if not hit then
		dist = VecLength(diff)
	end
	
	return hit, dist, normal, shape
end

function exist(element, tab)
	for i=1, #tab do
		if tab[i] == element then
			return true, i
		end
	end
	return false, 0
end

function defaultGeq(a, b)
	return a <= b
end

function partition(array, left, right, pivotIndex, fun)
	local pivotValue = array[pivotIndex]
	array[pivotIndex], array[right] = array[right], array[pivotIndex]
	
	local storeIndex = left
	
	for i =  left, right-1 do
    	if fun(array[i], pivotValue) then --array[i] <= pivotValue then
	        array[i], array[storeIndex] = array[storeIndex], array[i]
	        storeIndex = storeIndex + 1
		end
		array[storeIndex], array[right] = array[right], array[storeIndex]
	end
	
   return storeIndex
end

function quicksort(array, left, right, fun)
	fun = fun or defaultGeq()
	if right > left then
	    local pivotNewIndex = partition(array, left, right, left, fun)
	    quicksort(array, left, pivotNewIndex - 1, fun)
	    quicksort(array, pivotNewIndex + 1, right, fun)
	end
end

function rebound(value, minV, maxV)
	return math.min(math.max(value, minV), maxV)
end

function vecResize(v, s)
	return VecScale(VecNormalize(v), s)
end

function tableEq(a, b)
	if #a ~= #b then
		return false
	else
		for i=1, #a do
			if a[i] ~= b[i] then
				return false
			end
		end
		return true
	end
end

function tableToStr(t)
	local str = "{"
	for i=1, #t do
		str =  str .. tostring(t[i]) .. ", "
	end
	str = str .. "}"
	return str
end

function round(value, decimals)
	decimals = decimals or 0
	local mult = math.pow(10, decimals)
	return math.floor(value * mult) / mult
end

function vecAngle(u, v, signed)
	signed = signed or false
	local dot = VecDot(Vec(0, 1, 0), VecCross(u, v))
	local sign = 1
	if signed and dot < 0 then
		sign = -1
	end

	return sign * math.deg(math.acos(VecDot(u, v) / (VecLength(u) * VecLength(v))))
end

function drawPos(pos, r, g, b, a)
    r, g, b, a = rgbaInit(r, g, b, a)
    DrawLine(pos, VecAdd(pos, Vec(0, 5)), r, g, b, a)
end

function drawPath(path, r, g, b, a, decay)
	decay = decay or false
	r, g, b, a = rgbaInit(r, g, b, a)

    for i=1, #path - 1 do
		local ratio = 1
		if decay then
			ratio = 1 - (i + 1) / (#path)
		end
        DrawLine(path[i], path[i + 1], r, g, b, a * ratio)
    end
end

function drawSpriteLine(p1, p2, sprite, width, r, g, b, a, depthTest, additive)
	r, g, b, a = rgbaInit(r, g, b, a)
	depthTest = depthTest or false
	additive = additive or false

	local aToB = VecSub(p1, p2)
    local length = VecLength(aToB)
    local t = Transform(VecLerp(p1, p2, 0.5), QuatAlignXZ(VecNormalize(aToB), VecNormalize(VecSub(p1, GetCameraTransform().pos))))
    DrawSprite(sprite, t, length, width, r, g, b, a, depthTest, additive)
end

function rgbaInit(r, g, b, a)
	local tmp_r = 1
	local tmp_g = 1
	local tmp_b = 1
	local tmp_a = 1
	if r ~= nil or g ~= nil or b ~= nil then
		tmp_r = r or 0
		tmp_g = g or 0
        tmp_b = b or 0
        tmp_a = a or 1
	end
	return tmp_r, tmp_g, tmp_b, tmp_a
end






































