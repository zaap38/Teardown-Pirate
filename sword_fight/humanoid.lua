#include "script/common.lua"
#include "registry_snippets.lua"

function VecDist(a, b)
	return VecLength(VecSub(a, b))
end


function getTagParameter(entity, name, default)
	local v = tonumber(GetTagValue(entity, name))
	if v then
		return v
	else
		return default
	end
end

function getTagParameter2(entity, name, default)
	local s = splitString(GetTagValue(entity, name), ",")
	if #s == 1 then
		local v = tonumber(s[1])
		if v then
			return v, v
		else
			return default, default
		end
	elseif #s == 2 then
		local v1 = tonumber(s[1])
		local v2 = tonumber(s[2])
		if v1 and v2 then
			return v1, v2
		else
			return default, default
		end
	else
		return default, default
	end
end

pType = GetStringParam("type", "")
pSpeed = GetFloatParam("speed", 3.5)
pTurnSpeed = GetFloatParam("turnspeed", pSpeed)

config = {}
config.hasVision = false
config.viewDistance = 175
config.viewFov = 350
config.canHearPlayer = false
config.canSeePlayer = false
config.patrol = false
config.sensorDist = 5.0
config.speed = pSpeed
config.turnSpeed = pTurnSpeed
config.huntPlayer = false
config.huntSpeedScale = 1.6
config.avoidPlayer = false
config.triggerAlarmWhenSeen = false
config.visibilityTimer = 0.3 --Time player must be seen to be identified as enemy (ideal condition)
config.lostVisibilityTimer = 5.0 --Time player is seen after losing visibility
config.outline = 13
config.aimTime = 5.0
config.maxSoundDist = 100.0
config.aggressive = false
config.stepSound = "m"
config.practice = false
config.maxHealth = 100.0

PATH_NODE_TOLERANCE = 0.8

function configInit()
	local eye = FindLight("eye")
	local head = FindBody("head")
	config.patrol = FindLocation("patrol") ~= 0
	config.hasVision = true --eye ~= 0
	config.viewDistance = getTagParameter(eye, "viewdist", config.viewDistance)
	config.viewFov = getTagParameter(eye, "viewfov", config.viewFov)
	config.maxSoundDist = getTagParameter(head, "heardist", config.maxSoundDist)
	if hasWord(pType, "investigate") then
		config.canHearPlayer = true
		config.canSeePlayer = true
	end
	if hasWord(pType, "chase") then
		config.canHearPlayer = true
		config.canSeePlayer = true
		config.huntPlayer = true
	end
	if hasWord(pType, "avoid") and config.patrol then
		config.avoidPlayer = true
		config.canSeePlayer = true
	end
	if hasWord(pType, "alarm") then
		config.triggerAlarmWhenSeen = true
	end
	if hasWord(pType, "nooutline") then
		config.outline = 0
	end
	if hasWord(pType, "aggressive") then
		config.aggressive = true
	end
	if hasWord(pType, "practice") then
		config.canSeePlayer = true
		config.practice = true
	end
	local body = FindBody("body")
	if HasTag(body, "stepsound") then
		config.stepSound = GetTagValue(body, "stepsound")
	end
end

-----------------------------------------------------------------------

function rndVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end

function rnd(mi, ma)
	local v = math.random(0,1000) / 1000
	return mi + (ma-mi)*v
end

function rejectAllBodies(bodies)
	for i=1, #bodies do
		QueryRejectBody(bodies[i])
	end
end

-----------------------------------------------------------------------


humanoid = {}
humanoid.body = 0
humanoid.allBodies = {}
humanoid.allShapes = {}
humanoid.allJoints = {}
humanoid.transform = Transform()
humanoid.dir = Vec(0, 0, -1)
humanoid.axes = {}
humanoid.bodyCenter = Vec()
humanoid.navigationCenter = Vec()
humanoid.massCenter = Vec()
humanoid.speed = 0
humanoid.speedScale = 1
humanoid.blocked = 0
humanoid.mass = 0
humanoid.initialBodyTransforms = {}
humanoid.enabled = true
humanoid.deleted = false
humanoid.breakAll = false
humanoid.breakAllTimer = 0
humanoid.distToPlayer = 100
humanoid.dirToPlayer = 0
humanoid.roamTrigger = 0
humanoid.limitTrigger = 0
humanoid.investigateTrigger = 0
humanoid.activateTrigger = 0
humanoid.stunned = 0
humanoid.outlineAlpha = 0
humanoid.canSensePlayer = false
humanoid.playerPos = Vec()
humanoid.health = 100.0
humanoid.headDamageScale = 3.0
humanoid.torsoDamageScale = 1.4
humanoid.torso = 0
humanoid.head = 0
humanoid.rightHand = 0
humanoid.leftHand = 0
humanoid.rightFoot = 0
humanoid.leftFoot = 0

function humanoidSetAxes()
	humanoid.transform = GetBodyTransform(humanoid.body)
	humanoid.axes[1] = TransformToParentVec(humanoid.transform, Vec(1, 0, 0))
	humanoid.axes[2] = TransformToParentVec(humanoid.transform, Vec(0, 1, 0))
	humanoid.axes[3] = TransformToParentVec(humanoid.transform, Vec(0, 0, 1))
end

function humanoidInit()
	humanoid.body = FindBody("lowertorso")
	humanoid.torso = FindBody("uppertorso")
	humanoid.head = FindBody("head")
	humanoid.rightHand = FindBody("righthand")
	humanoid.leftHand = FindBody("lefthand")
	humanoid.rightFoot = FindBody("rightfoot")
	humanoid.leftFoot = FindBody("leftfoot")
	humanoid.weapon = FindBody("aim")
	humanoid.allBodies = FindBodies()
	humanoid.allShapes = FindShapes()
	humanoid.allJoints = FindJoints()

	humanoid.health = config.maxHealth

	humanoidSetAxes()
	humanoidCollide(true)
end

function humanoidCollide(enabled)
	local mask = 254
	if enabled then
		mask = 255
	end
	for i = 1, #humanoid.allShapes do
		local shape = humanoid.allShapes[i]
		if GetShapeBody(shape) ~= humanoid.body and GetShapeBody(shape) ~= humanoid.torso then
			SetShapeCollisionFilter(shape, 1, mask)
		end
	end
end

function humanoidTurnTowards(pos)
	humanoid.dir = VecNormalize(VecSub(pos, humanoid.transform.pos))
end


function humanoidSetDirAngle(angle)
	humanoid.dir[1] = math.cos(angle)
	humanoid.dir[3] = math.sin(angle)
end


function humanoidGetDirAngle()
	return math.atan2(humanoid.dir[3], humanoid.dir[1])
end

function humanoidUpdate()
	humanoidSetAxes()

	humanoid.playerPos = GetPlayerCameraTransform().pos

	local vel = GetBodyVelocity(humanoid.body)
	local fwdSpeed = VecDot(vel, humanoid.dir)
	local blocked = 0
	if humanoid.speed > 0 and fwdSpeed > -0.1 then
		blocked = 1.0 - clamp(fwdSpeed/0.5, 0.0, 1.0)
	end
	humanoid.blocked = humanoid.blocked * 0.95 + blocked * 0.05

	-- --Always blocked if fall is detected
	-- if sensor.detectFall > 0 then
	-- 	humanoid.blocked = 1.0
	-- end
	
	humanoid.mass = 0
	humanoid.massCenter = Vec()
	for i = 1, #humanoid.allBodies do
		local mass = GetBodyMass(humanoid.allBodies[i])
		humanoid.mass = humanoid.mass + mass
		humanoid.massCenter = VecAdd(humanoid.massCenter, VecScale(GetBodyCenterOfMass(humanoid.allBodies[i]), mass))
	end
	
	humanoid.bodyCenter = TransformToParentPoint(humanoid.transform, GetBodyCenterOfMass(humanoid.body))
	humanoid.navigationCenter = TransformToParentPoint(humanoid.transform, Vec(0, -hover.distTarget, 0))
	humanoid.massCenter = TransformToParentPoint(humanoid.transform, VecScale(humanoid.massCenter, 1 / humanoid.mass))
	
	--Distance and direction to player
	local pp = VecAdd(GetPlayerTransform().pos, Vec(0, 1, 0))
	local d = VecSub(pp, humanoid.bodyCenter)
	humanoid.distToPlayer = VecLength(d)
	humanoid.dirToPlayer = VecScale(d, 1.0/humanoid.distToPlayer)
	
	--Sense player if player is close and there is nothing in between
	humanoid.canSensePlayer = false
	if humanoid.distToPlayer < 3.0 then
		rejectAllBodies(humanoid.allBodies)
		if not QueryRaycast(humanoid.bodyCenter, humanoid.dirToPlayer, humanoid.distToPlayer) then
			humanoid.canSensePlayer = true
		end
	end
	humanoid.canSensePlayer = true
end

-----------------------------------------------------------------------

hover = {}
hover.hitBody = 0
hover.contact = 0.0
hover.currentDist = 0.8
hover.distTarget = 0.8
hover.distPadding = 0.3
hover.timeSinceContact = 0.0

function hoverInit()

end

function hoverFloat()
	if hover.contact > 0 then
		local d = clamp(hover.distTarget - hover.currentDist, -0.2, 0.2)
		local v = d * 10
		local f = math.max(0, d * humanoid.mass * 5) + humanoid.mass * 2
		ConstrainVelocity(humanoid.body, hover.hitBody, humanoid.massCenter, Vec(0, 1, 0), v, 0, f)
	end
end

function hoverUpright()
	local up = VecCross(humanoid.axes[2], Vec(0, 1, 0))
	local axes = {}
	axes[1] = Vec(1, 0, 0)
	axes[2] = Vec(0, 1, 0)
	axes[3] = Vec(0, 0, 1)
	for a = 1, 3 do
		local d = VecDot(up, axes[a])
		local v = clamp(d * 15, -5, 5)
		local f = clamp(math.abs(d), -0.5, 0.5)
		f = f + 0.05
		f = f * humanoid.mass * 5
		ConstrainAngularVelocity(humanoid.body, hover.hitBody, axes[a], v, -f, f)
	end
end

function hoverTurn()
	local fwd = VecScale(humanoid.axes[3], -1)
	local c = VecCross(fwd, humanoid.dir)
	local d = VecDot(c, humanoid.axes[2])
	local angVel = clamp(d*10, -config.turnSpeed * humanoid.speedScale, config.turnSpeed * humanoid.speedScale)

	local curr = VecDot(humanoid.axes[2], GetBodyAngularVelocity(humanoid.body))
	angVel = curr + clamp(angVel - curr, -humanoid.speedScale, humanoid.speedScale)

	local f = humanoid.mass*0.5 * hover.contact
	ConstrainAngularVelocity(humanoid.body, hover.hitBody, humanoid.axes[2], angVel, -f , f)
end


function hoverMove()
	local desiredSpeed = humanoid.speed * humanoid.speedScale
	local fwd = VecScale(humanoid.axes[3], -1)
	fwd[2] = 0
	fwd = VecNormalize(fwd)
	local side = VecCross(Vec(0,1,0), fwd)
	local currSpeed = VecDot(fwd, GetBodyVelocityAtPos(humanoid.body, humanoid.bodyCenter))
	local speed = currSpeed + clamp(desiredSpeed - currSpeed, -0.2*humanoid.speedScale, 0.2*humanoid.speedScale)
	local f = humanoid.mass*0.2 * hover.contact

	ConstrainVelocity(humanoid.body, hover.hitBody, humanoid.bodyCenter, fwd, speed, -f , f)
	ConstrainVelocity(humanoid.body, hover.hitBody, humanoid.bodyCenter, humanoid.axes[1], 0, -f , f)
end

BALANCE_RADIUS = 0.4
function hoverUpdate()
	local dir = VecScale(humanoid.axes[2], -1)

	--Shoot rays from four locations downwards
	local hit = false
	local dist = 0
	local normal = Vec(0,0,0)
	local shape = 0
	local samples = {}
	samples[#samples+1] = Vec(-BALANCE_RADIUS,0,0)
	samples[#samples+1] = Vec(BALANCE_RADIUS,0,0)
	samples[#samples+1] = Vec(0,0,BALANCE_RADIUS)
	samples[#samples+1] = Vec(0,0,-BALANCE_RADIUS)
	local maxDist = hover.distTarget + hover.distPadding
	local castRadius = 0.1
	for i=1, #samples do
		QueryRequire("physical large")
		rejectAllBodies(humanoid.allBodies)
		local origin = TransformToParentPoint(humanoid.transform, samples[i])
		local rhit, rdist, rnormal, rshape = QueryRaycast(origin, dir, maxDist, castRadius)
		if rhit then
			hit = true
			dist = dist + rdist + castRadius
			if rdist == 0 then
				--Raycast origin in geometry, normal unsafe. Assume upright
				rnormal = Vec(0,1,0)
			end
			if shape == 0 then
				shape = rshape
			else
				local b = GetShapeBody(rshape)
				local bb = GetShapeBody(shape)
				--Prefer new hit if it's static or has more mass than old one
				if not IsBodyDynamic(b) or (IsBodyDynamic(bb) and GetBodyMass(b) > GetBodyMass(bb)) then
					shape = rshape
				end
			end
			normal = VecAdd(normal, rnormal)
		else
			dist = dist + maxDist
		end
	end

	--Use average of rays to determine contact and height
	if hit then
		dist = dist / #samples
		normal = VecNormalize(normal)
		hover.hitBody = GetShapeBody(shape)
		if IsBodyDynamic(hover.hitBody) and GetBodyMass(hover.hitBody) < 300 then
			--Hack alert! Treat small bodies as static to avoid sliding and glitching around on debris
			hover.hitBody = 0
		end
		hover.currentDist = dist
		hover.contact = clamp(1.0 - (dist - hover.distTarget) / hover.distPadding, 0.0, 1.0)
		hover.contact = hover.contact * math.max(0, normal[2])
	else
		hover.hitBody = 0
		hover.currentDist = maxDist
		hover.contact = 0
	end

	hoverFloat()
	hoverUpright()
	hoverTurn()
	hoverMove()
end

------------------------------------------------------------------------

head = {}
head.body = 0
head.eye = 0
head.dir = Vec(0,0,-1)
head.lookOffset = 0
head.lookOffsetTimer = 0
head.canSeePlayer = true
head.lastSeenPos = Vec(0,0,0)
head.timeSinceLastSeen = 999
head.seenTimer = 0
head.alarmTimer = 0
head.alarmTime = 2.0
head.aim = 0	-- 1.0 = perfect aim, 0.0 = will always miss player. This increases when robot sees player based on config.aimTime


function headInit()
	head.body = FindBody("head")
	head.eye = FindLight("eye")
	head.joint = FindJoint("head")
	head.alarmTime = getTagParameter(head.eye, "alarm", 2.0)
end


function headTurnTowards(pos)
	head.dir = VecNormalize(VecSub(pos, GetBodyTransform(head.body).pos))
end

function headUpdate(dt)
	local t = GetBodyTransform(head.body)
	local fwd = TransformToParentVec(t, Vec(0, 0, -1))

	--Check if head can see player
	local et = GetBodyTransform(head.body) --GetLightTransform(head.eye)
	local pp = VecCopy(humanoid.playerPos)
	local toPlayer = VecSub(pp, et.pos)
	local distToPlayer = VecLength(toPlayer)
	toPlayer = VecNormalize(toPlayer)

	--Determine player visibility
	local playerVisible = false
	if config.hasVision and config.canSeePlayer then
		if distToPlayer < config.viewDistance then	--Within view distance
			local limit = math.cos(config.viewFov * 0.5 * math.pi / 180)
			if VecDot(toPlayer, fwd) > limit then --In view frustum
				rejectAllBodies(humanoid.allBodies)
				QueryRejectVehicle(GetPlayerVehicle())
				if not QueryRaycast(et.pos, toPlayer, distToPlayer, 0, true) then --Not blocked
					playerVisible = true
				end
			end
		end
	end
	playerVisible = true

	if config.aggressive then
		playerVisible = true
	end
	
	--If player is visible it takes some time before registered as seen
	--If player goes out of sight, head can still see for some time second (approximation of motion estimation)
	if playerVisible then
		local distanceScale = clamp(1.0 - distToPlayer/config.viewDistance, 0.5, 1.0)
		local angleScale = clamp(VecDot(toPlayer, fwd), 0.5, 1.0)
		local delta = (dt * distanceScale * angleScale) / (config.visibilityTimer / 0.5)
		head.seenTimer = math.min(1.0, head.seenTimer + delta)
	else
		head.seenTimer = math.max(0.0, head.seenTimer - dt / config.lostVisibilityTimer)
	end
	head.canSeePlayer = (head.seenTimer > 0.5)
	
	if head.canSeePlayer then
		head.lastSeenPos = pp
		head.timeSinceLastSeen = 0
	else
		head.timeSinceLastSeen = head.timeSinceLastSeen + dt
	end

	if playerVisible and head.canSeePlayer then
		head.aim = math.min(1.0, head.aim + dt / config.aimTime)
	else
		head.aim = math.max(0.0, head.aim - dt / config.aimTime)
	end
	
	if config.triggerAlarmWhenSeen then
		local red = false
		if GetBool("level.alarm") then
			red = math.mod(GetTime(), 0.5) > 0.25
		else
			if playerVisible and IsPointAffectedByLight(head.eye, pp) then
				red = true
				head.alarmTimer = head.alarmTimer + dt
				PlayLoop(chargeLoop, humanoid.transform.pos)
				if head.alarmTimer > head.alarmTime and playerVisible then
					SetString("hud.notification", "Detected by robot. Alarm triggered.")
					SetBool("level.alarm", true)
				end
			else
				head.alarmTimer = math.max(0.0, head.alarmTimer - dt)
			end
		end
		if red then
			SetLightColor(head.eye, 1, 0, 0)
		else
			SetLightColor(head.eye, 1, 1, 1)
		end
	end
	
	--Rotate head to head.dir
	local fwd = TransformToParentVec(t, Vec(0, 0, -1))
	-- if playerVisible then
	-- 	headTurnTowards(pp)
	-- end
	head.dir = VecNormalize(head.dir)
	--end
	local c = VecCross(fwd, head.dir)
	local d = VecDot(c, humanoid.axes[2])
	local angVel = clamp(d*10, -3, 3)
	local f = 100
	-- mi, ma = GetJointLimits(head.joint)
	-- local ang = GetJointMovement(head.joint)
	-- if ang < mi+1 and angVel < 0 then
	-- 	angVel = 0
	-- end
	-- if ang > ma-1 and angVel > 0 then
	-- 	angVel = 0
	-- end

	ConstrainAngularVelocity(head.body, humanoid.body, humanoid.axes[2], angVel, -f , f)

	local vol = clamp(math.abs(angVel)*0.3, 0.0, 1.0)
	if vol > 0 then
		--PlayLoop(headLoop, humanoid.transform.pos, vol)
	end
end

------------------------------------------------------------------------

aims = {}

function aimsInit()
	local bodies = FindBodies("aim")
	for i=1, #bodies do
		local aim = {}
		aim.body = bodies[i]
		aims[i] = aim
	end
end


function aimsUpdate(dt)
	local state = stackTop()
	for i=1, #aims do
		local aim = aims[i]
		local playerPos = VecCopy(humanoid.playerPos)
		playerPos = VecAdd(playerPos, Vec(0, -0.75, 0))
		local toPlayer = VecNormalize(VecSub(playerPos, GetBodyTransform(aim.body).pos))
		local fwd = TransformToParentVec(GetBodyTransform(humanoid.body), Vec(0, 0, -1))
		if (state.id == "hunt" and VecDot(fwd, toPlayer) > 0.5) or humanoid.distToPlayer < 4.0 then
			--Should aim
			local v = 20
			local f = 200
			local wt = GetBodyTransform(aim.body)
			local toPlayerOrientation = QuatLookAt(wt.pos, playerPos)
			--ConstrainOrientation(aim.body, humanoid.body, wt.rot, toPlayerOrientation, v, f)
		else
			--Should not aim
			local rd = TransformToParentVec(GetBodyTransform(humanoid.body), Vec(0, 0, -1))
			local wd = TransformToParentVec(GetBodyTransform(aim.body), Vec(0, 0, -1))
			local angle = clamp(math.acos(VecDot(rd, wd)), 0, 1)
			local v = 2
			local f = math.abs(angle) * 100 + 3
			local orientation = QuatRotateQuat(GetBodyTransform(humanoid.rightHand).rot, QuatEuler(0, -90, 90))
			--ConstrainOrientation(humanoid.body, aim.body, orientation, GetBodyTransform(aim.body).rot, v, f)
		end
		--ConstrainVelocity(humanoid.body, aim.body, GetBodyTransform(humanoid.body).pos, VecNormalize(GetBodyVelocity(aim.body)), 0, 1)
	end
end

------------------------------------------------------------------------

weapons = {}

function weaponsInit()
	local locs = FindLocations("weapon")
	for i=1, #locs do
		local loc = locs[i]
		local t = GetLocationTransform(loc)
		QueryRequire("dynamic large")
		local hit, point, normal, shape = QueryClosestPoint(t.pos, 0.15)
		if hit then
			local weapon = {}
			weapon.type = GetTagValue(loc, "weapon")
			weapon.timeBetweenRounds = tonumber(GetTagValue(loc, "idle"))
			weapon.chargeTime = tonumber(GetTagValue(loc, "charge"))
			weapon.fireCooldown = tonumber(GetTagValue(loc, "cooldown"))
			weapon.shotsPerRound = tonumber(GetTagValue(loc, "count"))
			weapon.spread = tonumber(GetTagValue(loc, "spread"))
			weapon.strength = tonumber(GetTagValue(loc, "strength"))
			weapon.maxDist = tonumber(GetTagValue(loc, "maxdist"))
			if weapon.type == "" then weapon.type = "gun" end
			if not weapon.timeBetweenRounds then weapon.timeBetweenRounds = 1.0 end
			if not weapon.chargeTime then weapon.chargeTime = 1.2 end
			if not weapon.fireCooldown then weapon.fireCooldown = 0.08 end
			if not weapon.shotsPerRound then weapon.shotsPerRound = 6 end
			if not weapon.spread then weapon.spread = 0.01 end
			if not weapon.strength then weapon.strength = 1.0 end
			if not weapon.maxDist then weapon.maxDist = 100.0 end
			local b = GetShapeBody(shape)
			local bt = GetBodyTransform(b)
			weapon.localTransform = TransformToLocalTransform(bt, t)
			weapon.body = b
			weapon.state = "idle"
			weapon.idleTimer = 0
			weapon.chargeTimer = 0
			weapon.fireTimer = 0
			weapon.fireCount = 0
			weapons[i] = weapon
		end
	end
end


function getPerpendicular(dir)
	local perp = VecNormalize(Vec(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)))
	perp = VecNormalize(VecSub(perp, VecScale(dir, VecDot(dir, perp))))
	return perp
end


function weaponFire(weapon, pos, dir)
	local perp = getPerpendicular(dir)
	
	-- This is the default bullet spread
	local spread = weapon.spread * rnd(0.0, 1.0)

	-- Add more spread up based on aim, so that the first bullets never (well, rarely) hit player
	local extraSpread = math.min(0.5, 2.0 / humanoid.distToPlayer)
	spread = spread	+ (1.0-head.aim) * extraSpread

	dir = VecNormalize(VecAdd(dir, VecScale(perp, spread)))

	--Start one voxel ahead to not hit robot itself
	pos = VecAdd(pos, VecScale(dir, 0.1))
	
	if weapon.type == "gun" then
		PlaySound(shootSound, pos, 1.0, false)
		PointLight(pos, 1, 0.8, 0.6, 1.5)
		Shoot(pos, dir, 0, weapon.strength)
	elseif weapon.type == "rocket" then
		PlaySound(rocketSound, pos, 1.0, false)
		Shoot(pos, dir, 1, weapon.strength)
	end
end


function weaponsReset()
	for i=1, #weapons do
		weapons[i].state = "idle"
		weapons[i].idleTimer = weapons[i].timeBetweenRounds
		weapons[i].fire = 0
	end
end


function weaponEmitFire(weapon, t, amount)
	if humanoid.stunned > 0 then
		return
	end
	local p = TransformToParentPoint(t, Vec(0, 0, -0.1))
	local d = TransformToParentVec(t, Vec(0, 0, -1))
	ParticleReset()
	ParticleTile(5)
	ParticleColor(1, 1, 0.5, 1, 0.5, 0.2)
	ParticleRadius(0.1*amount, 0.8*amount)
	ParticleEmissive(6, 0)
	ParticleDrag(0.1)
	ParticleGravity(math.random()*20)
	PointLight(p, 1, 0.8, 0.2, 2*amount)
	PlayLoop(fireLoop, t.pos, amount)
	SpawnParticle(p, VecScale(d, 12), 0.5 * amount)

	if amount > 0.5 then
		--Spawn fire
		if not spawnFireTimer then
			spawnFireTimer = 0
		end
		if spawnFireTimer > 0 then
			spawnFireTimer = math.max(spawnFireTimer-0.01667, 0)
		else
			rejectAllBodies(humanoid.allBodies)
			local hit, dist = QueryRaycast(p, d, 3)
			if hit then
				local wp = VecAdd(p, VecScale(d, dist))
				SpawnFire(wp)
				spawnFireTimer = 1
			end
		end
		
		--Hurt player
		local toPlayer = VecSub(GetPlayerCameraTransform().pos, t.pos)
		local distToPlayer = VecLength(toPlayer)
		local distScale = clamp(1.0 - distToPlayer / 6.0, 0.0, 1.0)
		if distScale > 0 then
			toPlayer = VecNormalize(toPlayer)
			if VecDot(d, toPlayer) > 0.8 or distToPlayer < 0.5 then
				rejectAllBodies(humanoid.allBodies)
				local hit = QueryRaycast(p, toPlayer, distToPlayer)
				if not hit or distToPlayer < 0.5 then
					SetPlayerHealth(GetPlayerHealth() - 0.02 * weapon.strength * amount * distScale)
				end
			end	
		end
	end
end


function weaponsUpdate(dt)
	for i=1, #weapons do
		local weapon = weapons[i]
		local bt = GetBodyTransform(weapon.body)
		local t = TransformToParentTransform(bt, weapon.localTransform)
		local fwd = TransformToParentVec(t, Vec(0, 0, -1))
		t.pos = VecAdd(t.pos, VecScale(fwd, 0.15))
		local playerPos = VecCopy(humanoid.playerPos)
		local toPlayer = VecSub(playerPos, t.pos)
		local distToPlayer = VecLength(toPlayer)
		toPlayer = VecNormalize(toPlayer)
		local clearShot = false
		
		if weapon.type == "fire" then
			if not weapon.fire then
				weapon.fire = 0
			end
			if head.canSeePlayer and humanoid.distToPlayer < 8.0 then
				weapon.fire = math.min(weapon.fire + 0.1, 1.0)
			else
				weapon.fire = math.max(weapon.fire - dt*0.5, 0.0)
			end
			if weapon.fire > 0 then
				weaponEmitFire(weapon, t, weapon.fire)
			else
				weaponEmitFire(weapon, t, math.max(weapon.fire, 0.1))
			end
		else
			--Need to point towards player and have clear line of sight to have clear shot
			local towardsPlayer = VecDot(fwd, toPlayer)
			local gotAim = towardsPlayer > 0.9
			if distToPlayer < 1.0 and towardsPlayer > 0.0 then
				gotAim = true
			end
			if head.canSeePlayer and gotAim and humanoid.distToPlayer < weapon.maxDist then
				QueryRequire("physical large")
				rejectAllBodies(humanoid.allBodies)
				local hit = QueryRaycast(t.pos, fwd, distToPlayer, 0, true)
				if not hit then
					clearShot =  true
				end
			end

			--Handle states
			if weapon.state == "idle" then
				weapon.idleTimer = weapon.idleTimer - dt
				if weapon.idleTimer <= 0 and clearShot then
					weapon.state = "charge"
					weapon.fireDir = fwd
					weapon.chargeTimer = weapon.chargeTime
				end
			elseif weapon.state == "charge" or weapon.state == "chargesilent" then
				weapon.chargeTimer = weapon.chargeTimer - dt
				if weapon.state ~= "chargesilent" then
					--PlayLoop(chargeLoop, t.pos)
				end
				if weapon.chargeTimer <= 0 then
					weapon.state = "fire"
					weapon.fireTimer = 0
					weapon.fireCount = weapon.shotsPerRound
				end
			elseif weapon.state == "fire" then	
				weapon.fireTimer = weapon.fireTimer - dt
				if towardsPlayer > 0.3 or distToPlayer < 1.0 then
					if weapon.fireTimer <= 0 then
						weaponFire(weapon, t.pos, fwd)
						weapon.fireCount = weapon.fireCount - 1
						if weapon.fireCount <= 0 then
							if clearShot then
								weapon.state = "chargesilent"
								weapon.chargeTimer = weapon.chargeTime
							else
								weapon.state = "idle"
								weapon.idleTimer = weapon.timeBetweenRounds
							end
						else
							weapon.fireTimer = weapon.fireCooldown
						end
					end			
				else
					--We are no longer pointing towards player, abort round
					weapon.state = "idle"
					weapon.idleTimer = weapon.timeBetweenRounds
				end
			end
		end
	end
end	

-----------------------------------------------------------------------

function animatorPoses(actionValue)
	actionValue = actionValue or NOTHING

	a = {}
	a.poses = {}
	a.pose = {}
	a.frame = 1
	a.nextFrame = 1
	a.time = 0.0
	a.stepDist = 0.0
	a.stepLength = 0.5
	a.failed = false

	a.success = {}
	a.fail = {}
	a.duration = 0.5

	if actionValue == STUN then
		a.duration = 1.25
		a.success = {NOTHING}
		--actionValue = NOTHING
	elseif actionValue == NOTHING then
		a.duration = 0.75
	elseif actionValue == BLOCK then
		a.duration = 0.7
		a.success = {LOAD_VSLICE, FEINT}
		a.fail = {NOTHING}
		actionValue = PARRYING
	elseif actionValue == PARRYING then
		a.duration = 1.0 + math.random(0.5, 1.5)
		a.fail = {LOAD_VSLICE, LOAD_LSLICE}
	elseif actionValue == FEINT then
		a.duration = 0.5
		a.success = {FEINT2}
		actionValue = LOAD_VSLICE
	elseif actionValue == FEINT2 then
		a.duration = 0.5
		a.success = {LOAD_VSLICE, LOAD_LSLICE}
		actionValue = NOTHING
	elseif actionValue == LOAD_GB then
		a.duration = 0.3
		a.success = {GUARDBREAK}
		actionValue = NOTHING
	elseif actionValue == GUARDBREAK then
		a.duration = 0.4
		a.success = {LOAD_VSLICE, LOAD_LSLICE}
	elseif actionValue == LOAD_VSLICE then
		a.duration = 0.45
		a.success = {VSLICE}--, COMBO}
	elseif actionValue == LOAD_LSLICE then
		a.duration = 0.45
		a.success = {LSLICE}--, COMBO}
	elseif actionValue == COMBO then
		a.duration = 0.5
		a.success = {LOAD_VSLICE}
		a.fail = {NOTHING, LOAD_VSLICE}
		actionValue = VSLICE
	elseif actionValue == VSLICE then
		a.duration = 0.5
		a.success = {LOAD_LSLICE, LOAD_VSLICE, NOTHING}
		a.fail = {NOTHING, BLOCK}
	elseif actionValue == LSLICE then
		a.duration = 0.5
		a.success = {LOAD_LSLICE, LOAD_VSLICE, NOTHING}
		a.fail = {NOTHING, BLOCK}
	end

	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( 0.0,  0.0,  0.0),	vel = 0.0}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2,  -0.95,  0.0),	rot = QuatEuler( 0.0,  0.0,  0.0),	vel = 0.0}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2,  -0.95,  0.0),	rot = QuatEuler( 0.0,  0.0,  0.0),	vel = 0.0}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.2,  -0.4),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.1, -0.2),	rot = QuatEuler( 90.0,  90.0, -90.0),	vel = 0.8}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  1.0,  -0.35),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-10.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2,  -0.8,   0.6),	rot = QuatEuler(-45.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2,  -0.9,  -0.3),	rot = QuatEuler(15.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.6}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.2,  -0.4),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.1, -0.2),	rot = QuatEuler( 90.0,  90.0, -90.0),	vel = 0.8}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-10.0, 0.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2,  -0.55,  0.5),	rot = QuatEuler(-80.0, 0.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2,  -0.95,  0.0),	rot = QuatEuler( 0.0,  0.0,  0.0),	vel = 0.8}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.8}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.2,  -0.4),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.1, -0.2),	rot = QuatEuler( 90.0,  90.0, -90.0),	vel = 0.8}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-10.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2,  -0.9,  -0.3),	rot = QuatEuler(15.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2,  -0.8,   0.6),	rot = QuatEuler(-45.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.6}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.3,  -0.4),	rot = QuatEuler(0, 0, 0.0),	vel = 0.3}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.1, -0.2),	rot = QuatEuler( 90.0,  90.0, -90.0),	vel = 0.8}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,  0.0,   0.0),	rot = QuatEuler(-10.0, 0.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2, -0.95,  0.0),	rot = QuatEuler( 0.0,  0.0,  0.0),	vel = 0.8}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2, -0.55,  0.5),	rot = QuatEuler(-80.0, 0.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.8}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.2,  -0.4),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.1, -0.2),	rot = QuatEuler( 90.0,  90.0, -90.0),	vel = 0.8}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,  0.0,   0.0),	rot = QuatEuler(0.0, 0.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	----[[
	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -40.0,  0.0),	vel = 0.0}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2,  -0.8,   0.0),	rot = QuatEuler( 0.0, -45.0,  0.0),	vel = 0.0}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2,  -0.8,   0.0),	rot = QuatEuler( 0.0,  0.0,  0.0),	vel = 0.0}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  0.35, -0.2),	rot = QuatEuler( 0.0,  0.0, -90.0),	vel = 0.0}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec( 0.3,   0.35, -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.2,  -0.4),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.1, -0.2),	rot = QuatEuler( 90.0,  90.0, -90.0),	vel = 0.8}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,  0.0,   0.0),	rot = QuatEuler(0.0, 0.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-15.0, -55.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2,  -0.8,   0.6),	rot = QuatEuler(-45.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2,  -0.9,  -0.3),	rot = QuatEuler(15.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,  0.35, -0.1),	rot = QuatEuler(90.0, 90.0, -90.0),	vel = 0.6}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec( 0.35, 0.35, -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.2,  -0.4),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.1, -0.2),	rot = QuatEuler( 90.0,  90.0, -90.0),	vel = 0.8}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,  0.0,   0.0),	rot = QuatEuler(0.0, 0.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-15.0, -40.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2,  -0.55,  0.5),	rot = QuatEuler(-80.0, 0.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2,  -0.95,  0.0),	rot = QuatEuler( 0.0,  0.0,  0.0),	vel = 0.8}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  0.35, -0.1),	rot = QuatEuler(90.0, 90.0, -90.0),	vel = 0.8}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec( 0.3,   0.35, -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.2,  -0.4),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.35, -0.2),	rot = QuatEuler( 0.0,  90.0, -90.0),	vel = 0.5}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,  0.0,   0.0),	rot = QuatEuler(0.0, 0.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-15.0, -25.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2,  -0.9,  -0.3),	rot = QuatEuler(15.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2,  -0.8,   0.6),	rot = QuatEuler(-45.0, 0.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.3,   0.35, -0.1),	rot = QuatEuler(90.0, 90.0, -90.0),	vel = 0.6}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec( 0.25,  0.35, -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.6}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.2,  -0.4),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.35, -0.2),	rot = QuatEuler( 0.0,  90.0, -90.0),	vel = 0.5}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,  0.0,   0.0),	rot = QuatEuler(0.0, 0.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	a.poses[#a.poses + 1] = {}
	a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,  0.0,   0.0),	rot = QuatEuler(-15.0, -40.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["rightFoot"] = 	{pos = Vec( 0.2, -0.95,  0.0),	rot = QuatEuler( 0.0,  0.0,  0.0),	vel = 0.8}
	a.poses[#a.poses]["leftFoot"] = 	{pos = Vec(-0.2, -0.55,  0.5),	rot = QuatEuler(-80.0, 0.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  0.35, -0.1),	rot = QuatEuler(90.0, 90.0, -90.0),	vel = 0.8}
	a.poses[#a.poses]["leftHand"] = 	{pos = Vec( 0.3,   0.35, -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
	a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.3,  0.2,  -0.4),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	if actionValue == VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.2,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.2,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.05,  -0.05,  -0.5),	rot = QuatEuler(-80, 15, 0.0),	vel = 0.1}
	end
	if actionValue == LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.3,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.35,  0.25,  -0.3),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.4,  0.3,  -0.3),	rot = QuatEuler(-70, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, 20.0,  0.0),	vel = 0.0}
	end
	if actionValue == PARRYING then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.35,  1.35, -0.2),	rot = QuatEuler( 0.0,  90.0, -90.0),	vel = 0.5}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.65,  1.1,  -0.5),	rot = QuatEuler(0, 0, 82.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_VSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   1.1,  -0.25),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.5,  1.0,  -0.4),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.35,  1.1,  -0.35),	rot = QuatEuler(0, 0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler(-5.0, -60.0,  0.0),	vel = 0.0}
	end
	if actionValue == LOAD_LSLICE then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.4,   0.35,  -0.3),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.15,  0.35,  -0.25),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(-0.4,  0.35,  -0.3),	rot = QuatEuler(50, 0, 70.0),	vel = 0.0}
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,   0.0,   0.0),	rot = QuatEuler( -5.0,  45.0,  0.0),	vel = 0.0}
	end
	if actionValue == GUARDBREAK then
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.2,   0.8,  -0.45),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(0.15,  0.7,  -0.55),	rot = QuatEuler(90.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.15,  0.8,  -0.55),	rot = QuatEuler(30, 0, 0.0),	vel = 0.8}
	end
	if actionValue == STUN then
		a.poses[#a.poses]["torso"] = 		{pos = Vec( 0.0,  0.0,   0.0),	rot = QuatEuler(0.0, 0.0, 0.0),	vel = 0.8}
		a.poses[#a.poses]["rightHand"] = 	{pos = Vec( 0.65,   0.3,  -0.15),rot = QuatEuler(30.0, 150.0, -10.0),vel = 0.0}
		a.poses[#a.poses]["leftHand"] = 	{pos = Vec(-0.4,  0.3,  -0.2),	rot = QuatEuler(40.0, -160.0, 0.0),	vel = 0.0}
		a.poses[#a.poses]["weapon"] = 	{pos = Vec(0.55,  0.3,  -0.3),	rot = QuatEuler(-10, 0, 0.0),	vel = 0.0}
	end

	return a
end

animator = {}

function animatorInit()
	animator[STUN] = animatorPoses(STUN)
	animator[NOTHING] = animatorPoses(NOTHING)
	animator[LOAD_LSLICE] = animatorPoses(LOAD_LSLICE)
	animator[LSLICE] = animatorPoses(LSLICE)
	animator[PARRYING] = animatorPoses(PARRYING)
	animator[BLOCK] = animatorPoses(BLOCK)
	animator[VSLICE] = animatorPoses(VSLICE)
	animator[LOAD_VSLICE] = animatorPoses(LOAD_VSLICE)
	animator[FEINT] = animatorPoses(FEINT)
	animator[FEINT2] = animatorPoses(FEINT2)
	animator[COMBO] = animatorPoses(COMBO)
	animator[LOAD_GB] = animatorPoses(LOAD_GB)
	animator[GUARDBREAK] = animatorPoses(GUARDBREAK)
end

function vecToString(v)
	return "Vec(" .. v[1] .. ", " .. v[2] .. ", " .. v[3] .. ")"
end

function animatorUpdate(dt)
	local fwd = VecScale(humanoid.axes[3], -1)
	fwd[2] = 0
	fwd = VecNormalize(fwd)
	local currSpeed = VecDot(fwd, GetBodyVelocityAtPos(humanoid.body, humanoid.bodyCenter))

	if fight.anim == nil then
		fight.anim = deepcopy(animator[NOTHING])
	end

	local anim = fight.anim

	anim.stepDist = anim.stepDist + currSpeed * dt
	if anim.stepDist > anim.stepLength then
		anim.stepDist = anim.stepDist - anim.stepLength
		anim.frame = anim.nextFrame
		anim.nextFrame = anim.nextFrame + 1
		if anim.nextFrame > 5 then
			anim.nextFrame = 2
		end
		if anim.frame % 2 == 0 then
			PlaySound(stepSound, humanoid.transform.pos, 0.5, false)
		end
	end
	if anim.stepDist < 0.0 then
		anim.stepDist = anim.stepDist + anim.stepLength
		anim.nextFrame = anim.frame
		anim.frame = anim.frame - 1
		if anim.frame < 2 then
			anim.frame = 5
		end
		if anim.frame % 2 == 0 then
			PlaySound(stepSound, humanoid.transform.pos, 0.5, false)
		end
	end

	local idleFrame = 1
	local frame = anim.frame
	local nextFrame = anim.nextFrame

	local state = stackTop()

	--state.id = "hunt" -- force hunt
	if state.id == "hunt" then
		idleFrame = 6
		frame = frame + 5
		nextFrame = nextFrame + 5
	end

	local pose = anim.poses[frame]
	local nextPose = anim.poses[nextFrame]
	
	for n, b in pairs(pose) do
		--DebugWatch(n, vecToString(nextPose[n].pos))
		local t = anim.stepDist / anim.stepLength

		local vel0 = b.vel
		local vel1 = nextPose[n].vel
		local v = (-2 + vel0 + vel1) * t * t * t + (3 - 2*vel0 - vel1) * t * t + vel0 * t

		local body
		body = humanoid[n]

		local p = VecLerp(b.pos, nextPose[n].pos, v)
		local q = QuatSlerp(b.rot, nextPose[n].rot, v)

		local tt = clamp(currSpeed / (config.speed), 0.0, 1.0)
		p = VecLerp(anim.poses[idleFrame][n].pos, p, tt)
		q = QuatSlerp(anim.poses[idleFrame][n].rot, q, tt)

		anim.pose[n] = Transform(p, q)
	end

	if VecDot(fwd, humanoid.dirToPlayer) > 0.5 then
		anim.pose["head"] = TransformToLocalTransform(humanoid.transform, Transform(humanoid.transform.pos, QuatLookAt(Vec(), head.dir)))
	end

	for n, b in pairs(anim.pose) do
		local body = humanoid[n]
		local pos = TransformToParentPoint(humanoid.transform, b.pos)
		local rot = QuatRotateQuat(humanoid.transform.rot, b.rot)
	
		if n ~= "torso" and n ~= "head" then
			ConstrainPosition(body, humanoid.body, GetBodyTransform(body).pos, pos, 8, 20 * GetBodyMass(body))
		end
		ConstrainOrientation(body, humanoid.body, GetBodyTransform(body).rot, rot, 8, 20 * GetBodyMass(body))
	end
end

-----------------------------------------------------------------------

hearing = {}
hearing.lastSoundPos = Vec(0, -100, 0)
hearing.lastSoundVolume = 0
hearing.timeSinceLastSound = 0
hearing.hasNewSound = false

function hearingInit()
end

function hearingUpdate(dt)
	hearing.timeSinceLastSound = hearing.timeSinceLastSound + dt
	if config.canHearPlayer then
		local vol, pos = GetLastSound()
		local dist = VecDist(humanoid.transform.pos, pos)
		if vol > 0.1 and dist > 4.0 and dist < config.maxSoundDist then
			local valid = true
			--If there is an investigation trigger, the robot is in it and the sound is not, ignore sound
			if humanoid.investigateTrigger ~= 0 and IsPointInTrigger(humanoid.investigateTrigger, humanoid.bodyCenter) and not IsPointInTrigger(humanoid.investigateTrigger, pos) then
				valid = false
			end
			--React if time has passed since last sound or if it's substantially stronger
			if valid and (hearing.timeSinceLastSound > 2.0 or vol > hearing.lastSoundVolume*2.0) then
				local attenuation = 5.0 / math.max(5.0, dist)
				attenuation = attenuation * attenuation
				local heardVolume = vol * attenuation
				if heardVolume > 0.05 then
					hearing.lastSoundVolume = vol
					hearing.lastSoundPos = pos
					hearing.timeSinceLastSound = 0
					hearing.hasNewSound = true
				end
			end
		end
	end
end

function hearingConsumeSound()
	hearing.hasNewSound = false
end

-----------------------------------------------------------------------

navigation = {}
navigation.state = "done"
navigation.path = {}
navigation.target = Vec()
navigation.hasNewTarget = false
navigation.resultRetrieved = true
navigation.deviation = 0		-- Distance to path
navigation.blocked = 0
navigation.unblockTimer = 0		-- Timer that ticks up when blocked. If reaching limit, unblock kicks in and timer resets
navigation.unblock = 0			-- If more than zero, navigation is in unblock mode (reverse direction)
navigation.vertical = 0
navigation.thinkTime = 0
navigation.timeout = 1
navigation.lastQueryTime = 0
navigation.timeSinceProgress = 0

function navigationInit()
	-- if #wheels.bodies > 0 then
	-- 	navigation.pathType = "low"
	-- else
	-- 	navigation.pathType = "standard"
	-- end
	navigation.pathType = "standard"
end

--Prune path backwards so robot don't need to go backwards
function navigationPrunePath()
	if #navigation.path > 0 then
		for i=#navigation.path, 1, -1 do
			local p = navigation.path[i]
			local dv = VecSub(p, humanoid.transform.pos)
			local d = VecLength(dv)
			if d < PATH_NODE_TOLERANCE then
				--Keep everything after this node and throw out the rest
				local newPath = {}
				for j=i, #navigation.path do
					newPath[#newPath+1] = navigation.path[j]
				end
				navigation.path = newPath
				return
			end
		end
	end
end

function navigationClear()
	AbortPath()
	navigation.state = "done"
	navigation.path = {}
	navigation.hasNewTarget = false
	navigation.resultRetrieved = true
	navigation.deviation = 0
	navigation.blocked = 0
	navigation.unblock = 0
	navigation.vertical = 0
	navigation.target = Vec(0, -100, 0)
	navigation.thinkTime = 0
	navigation.lastQueryTime = 0
	navigation.unblockTimer = 0
	navigation.timeSinceProgress = 0
end

function navigationSetTarget(pos, timeout)
	pos = truncateToGround(pos)
	if VecDist(navigation.target, pos) > 1.5 then
		navigation.target = VecCopy(pos)
		navigation.hasNewTarget = true
		navigation.state = "move"
	end
	navigation.timeout = timeout
	navigation.timeSinceProgress = 0
end

function navigationUpdate(dt)
	if GetPathState() == "busy" then
		navigation.timeSinceProgress = 0
		navigation.thinkTime = navigation.thinkTime + dt
		if navigation.thinkTime > navigation.timeout then
			AbortPath()
		end
	end

	if GetPathState() ~= "busy" then
		if GetPathState() == "done" or GetPathState() == "fail" then
			if not navigation.resultRetrieved then
				if GetPathLength() > 0.5 then
					for l=0.2, GetPathLength(), 0.2 do
						navigation.path[#navigation.path+1] = GetPathPoint(l)
					end
				end			
				navigation.lastQueryTime = navigation.thinkTime
				navigation.resultRetrieved = true
				navigation.state = "move"
				navigationPrunePath()
			end
		end
		navigation.thinkTime = 0
	end

	if navigation.thinkTime == 0 and navigation.hasNewTarget then
		local startPos
		
		if #navigation.path > 0 and VecDist(navigation.path[1], humanoid.navigationCenter) < 2.0 then
			--Keep a little bit of the old path and use last point of that as start position
			--Use previous query's time as an estimate for the next
			local distToKeep = VecLength(GetBodyVelocity(humanoid.body))*navigation.lastQueryTime
			local nodesToKeep = math.clamp(math.ceil(distToKeep / 0.2), 1, 15)			
			local newPath = {}
			for i=1, math.min(nodesToKeep, #navigation.path) do
				newPath[i] = navigation.path[i]
			end
			navigation.path = newPath
			startPos = navigation.path[#navigation.path]
		else
			startPos = truncateToGround(humanoid.transform.pos)
			navigation.path = {}
		end

		local targetRadius = 1.0
		if GetPlayerVehicle()~=0 then
			targetRadius = 4.0
		end
	
		local target = navigation.target
		if humanoid.limitTrigger ~= 0 then
			target = GetTriggerClosestPoint(humanoid.limitTrigger, target)
			target = truncateToGround(target)
		end

		QueryRequire("physical large")
		rejectAllBodies(humanoid.allBodies)
		QueryPath(startPos, target, 100, targetRadius, navigation.pathType)

		navigation.timeSinceProgress = 0
		navigation.hasNewTarget = false
		navigation.resultRetrieved = false
		navigation.state = "move"
	end
		
	navigationMove(dt)
	
	if GetPathState() ~= "busy" and #navigation.path == 0 and not navigation.hasNewTarget then
		if GetPathState() == "done" or GetPathState() == "idle" then
			navigation.state = "done"
		else
			navigation.state = "fail"
		end
	end
end


function navigationMove(dt)
	if #navigation.path > 0 then
		if navigation.resultRetrieved then
			--If we have a finished path and didn't progress along it for five seconds, recompute
			--Should probably only do this for a limited time until giving up
			navigation.timeSinceProgress = navigation.timeSinceProgress + dt
			if navigation.timeSinceProgress > 5.0 then
				navigation.hasNewTarget = true
				navigation.path = {}
			end
		end
		if navigation.unblock > 0 then
			humanoid.speed = -2
			navigation.unblock = navigation.unblock - dt
		else
			local target = navigation.path[1]
			local dv = VecSub(target, humanoid.navigationCenter)
			local distToFirstPathPoint = VecLength(dv)
			dv[2] = 0
			local d = VecLength(dv)
			if distToFirstPathPoint < 2.5 then
				if d < PATH_NODE_TOLERANCE then
					if #navigation.path > 1 then
						--Measure verticality which should decrease speed
						local diff = VecSub(navigation.path[2], navigation.path[1])
						navigation.vertical = diff[2] / (VecLength(diff)+0.001)
						--Remove the first one
						local newPath = {}
						for i=2, #navigation.path do
							newPath[#newPath+1] = navigation.path[i]
						end
						navigation.path = newPath
						navigation.timeSinceProgress = 0
					else
						--We're done
						navigation.path = {}
						humanoid.speed = 0
						return
					end
				else
					--Walk towards first point on path
					humanoid.dir = VecCopy(VecNormalize(VecSub(target, humanoid.transform.pos)))
					humanoid.dir = VecNormalize(Vec(humanoid.dir[1], 0, humanoid.dir[3]))

					local dirDiff = VecDot(VecScale(humanoid.axes[3], -1), humanoid.dir)
					local speedScale = math.max(0.25, dirDiff)
					speedScale = speedScale * clamp(1.0 - navigation.vertical, 0.3, 1.0)
					humanoid.speed = config.speed * speedScale
				end
			else
				--Went off path, scrap everything and recompute
				navigation.hasNewTarget = true
				navigation.path = {}
			end

			--Check if stuck
			if humanoid.blocked > 0.2 then
				navigation.blocked = navigation.blocked + dt
				if navigation.blocked > 0.2 then
					humanoid.breakAllTimer = 0.1
					navigation.blocked = 0.0
				end
				navigation.unblockTimer = navigation.unblockTimer + dt
				if navigation.unblockTimer > 2.0 and navigation.unblock <= 0.0 then
					navigation.unblock = 1.0
					navigation.unblockTimer = 0
				end
			else
				navigation.blocked = 0
				navigation.unblockTimer = 0
			end
		end
	end
end

------------------------------------------------------------------------


stack = {}
stack.list = {}

function stackTop()
	return stack.list[#stack.list]
end

function stackPush(id)
	local index = #stack.list+1
	stack.list[index] = {}
	stack.list[index].id = id
	stack.list[index].totalTime = 0
	stack.list[index].activeTime = 0
	return stack.list[index]
end

function stackPop(id)
	if id then
		while stackHas(id) do
			stackPop()
		end
	else
		if #stack.list > 1 then
			stack.list[#stack.list] = nil
		end
	end
end

function stackHas(s)
	return stackGet(s) ~= nil
end

function stackGet(id)
	for i=1,#stack.list do
		if stack.list[i].id == id then
			return stack.list[i]
		end
	end
	return nil
end

function stackClear(s)
	stack.list = {}
	stackPush("none")
end

function stackInit()
	stackClear()
end

function stackUpdate(dt)
	if #stack.list > 0 then
		for i=1, #stack.list do
			stack.list[i].totalTime = stack.list[i].totalTime + dt
		end

		--Tick total time
		stack.list[#stack.list].activeTime = stack.list[#stack.list].activeTime + dt
	end
end



function getClosestPatrolIndex()
	local bestIndex = 1
	local bestDistance = 999
	for i=1, #patrolLocations do
		local pt = GetLocationTransform(patrolLocations[i]).pos
		local d = VecLength(VecSub(pt, humanoid.transform.pos))
		if d < bestDistance then
			bestDistance = d
			bestIndex = i
		end
	end
	return bestIndex
end


function getDistantPatrolIndex(currentPos)
	local bestIndex = 1
	local bestDistance = 0
	for i=1, #patrolLocations do
		local pt = GetLocationTransform(patrolLocations[i]).pos
		local d = VecLength(VecSub(pt, currentPos))
		if d > bestDistance then
			bestDistance = d
			bestIndex = i
		end
	end
	return bestIndex
end


function getNextPatrolIndex(current)
	local i = current + 1
	if i > #patrolLocations then
		i = 1	
	end
	return i
end


function markPatrolLocationAsActive(index)
	for i=1, #patrolLocations do
		if i==index then
			SetTag(patrolLocations[i], "active")
		else
			RemoveTag(patrolLocations[i], "active")
		end
	end
end

function debugState()
	local state = stackTop()
	DebugWatch("state", state.id)
	DebugWatch("activeTime", state.activeTime)
	DebugWatch("totalTime", state.totalTime)
	DebugWatch("navigation.state", navigation.state)
	DebugWatch("#navigation.path", #navigation.path)
	DebugWatch("navigation.hasNewTarget", navigation.hasNewTarget)
	DebugWatch("humanoid.blocked", humanoid.blocked)
	DebugWatch("humanoid.speed", humanoid.speed)
	DebugWatch("navigation.blocked", navigation.blocked)
	DebugWatch("navigation.unblock", navigation.unblock)
	DebugWatch("navigation.unblockTimer", navigation.unblockTimer)
	DebugWatch("navigation.thinkTime", navigation.thinkTime)
	DebugWatch("GetPathState()", GetPathState())
end

function init()

	STUN = "stun"
	NOTHING = "nothing"
	PARRYING = "parrying"
	BLOCK = "block"
	VSLICE = "vslice"
	LOAD_VSLICE = "load_vslice"
	LSLICE = "lslice"
	LOAD_LSLICE = "load_lslice"
	FEINT = "feint"
	FEINT2 = "feint2"
	COMBO = "combo"
	LOAD_GB = "load_gb"
	GUARDBREAK = "gb"

	bulletBlock = {
		value = 0,
		default = 2
	}

	invulnerability = {
		value = 0,
		default = 0.5
	}
	first = true

	setSpawnInRegistry(true)

	configInit()
	humanoidInit()
	hoverInit()
	headInit()
	aimsInit()
	weaponsInit()
	animatorInit()
	navigationInit()
	hearingInit()
	stackInit()

	fight = {
		action = NOTHING,
		anim = deepcopy(animator[NOTHING]),
		cooldown = {
			value = 3,
			default = 3
		},
		dmg = {
			value = 30
		}
	}

	patrolLocations = FindLocations("patrol")
	shootSound = LoadSound("tools/gun0.ogg", 8.0)
	rocketSound = LoadSound("tools/launcher0.ogg", 7.0)
	local nomDist = 7.0
	if config.stepSound == "s" then nomDist = 5.0 end
	if config.stepSound == "l" then nomDist = 9.0 end
	stepSound = LoadSound("robot/step-" .. config.stepSound .. "0.ogg", nomDist)
	headLoop = LoadLoop("robot/head-loop.ogg", 7.0)
	turnLoop = LoadLoop("robot/turn-loop.ogg", 7.0)
	walkLoop = LoadLoop("robot/walk-loop.ogg", 7.0)
	rollLoop = LoadLoop("robot/roll-loop.ogg", 7.0)
	chargeLoop = LoadLoop("robot/charge-loop.ogg", 8.0)
	alertSound = {LoadSound("MOD/sword_fight/snd/contactconfirmed.ogg", 9.0), LoadSound("MOD/sword_fight/snd/targetcontactat.ogg", 9.0), LoadSound("MOD/sword_fight/snd/goactiveintercept.ogg", 9.0)}
	huntSound = {LoadSound("MOD/sword_fight/snd/contactconfirmed.ogg", 9.0), LoadSound("MOD/sword_fight/snd/callcontactsuspecttarget1.ogg", 9.0)}
	lostSound = {LoadSound("MOD/sword_fight/snd/teamisdeployedandscanning.ogg", 9.0), LoadSound("MOD/sword_fight/snd/engagedincleanup.ogg", 9.0)}
	idleSound = {LoadSound("MOD/sword_fight/snd/reportallradialsfree.ogg", 9.0), LoadSound("MOD/sword_fight/snd/reportallpositionsclear.ogg", 9.0), LoadSound("MOD/sword_fight/snd/hasnegativemovement.ogg", 9.0), LoadSound("MOD/sword_fight/snd/sightlineisclear.ogg", 9.0)}
	hurtSound = {LoadSound("MOD/sword_fight/snd/pain1.ogg", 9.0), LoadSound("MOD/sword_fight/snd/pain2.ogg", 9.0), LoadSound("MOD/sword_fight/snd/pain3.ogg", 9.0)}
	dieSound = LoadSound("MOD/sword_fight/snd/die1.ogg", 9.0)
	fireLoop = LoadLoop("tools/blowtorch-loop.ogg")
	disableSound = LoadSound("robot/disable0.ogg")
end

function update(dt)
	if humanoid.deleted then 
		return
	else 
		if not IsHandleValid(humanoid.body) or IsPointInWater(GetBodyTransform(humanoid.head).pos) then
			for i=1, #humanoid.allBodies do
				Delete(humanoid.allBodies[i])
			end
			for i=1, #humanoid.allJoints do
				Delete(humanoid.allJoints[i])
			end
			humanoid.deleted = true
		end
	end

	local balls = FindBodies("bombardball", true)
	local exitLoop = false
	for i=1, #balls do
		local shapeBall = GetBodyShapes(balls[i])[1]
		local bodyShapes = humanoid.allShapes
		for k=1, #bodyShapes do
			if IsShapeTouching(shapeBall, bodyShapes[k]) and VecLength(GetBodyVelocity(balls[i])) > 30 then
				humanoid.health = 0
				local joints = humanoid.allJoints
				for l=1, #joints do
					DetachJointFromShape(joints[l], bodyShapes[k])
				end
				exitLoop = true
			end
		end
		if exitLoop then
			break
		end
	end

	if humanoid.activateTrigger ~= 0 then 
		if IsPointInTrigger(humanoid.activateTrigger, GetPlayerCameraTransform().pos) then
			RemoveTag(humanoid.body, "inactive")
			humanoid.activateTrigger = 0
		end
	end

	if humanoid.inactive or HasTag(humanoid.body, "sleeping") or not humanoid.enabled or humanoid.stunned > 0 then
		humanoidCollide(true)
	else
		humanoidCollide(false)
	end
	
	if HasTag(humanoid.body, "inactive") then
		humanoid.inactive = true
		return
	else
		if humanoid.inactive then
			humanoid.inactive = false
			--Reset robot pose
			local sleep = HasTag(humanoid.body, "sleeping")
			for i=1, #humanoid.allBodies do
				SetBodyTransform(humanoid.allBodies[i], humanoid.initialBodyTransforms[i])
				SetBodyVelocity(humanoid.allBodies[i], Vec(0,0,0))
				SetBodyAngularVelocity(humanoid.allBodies[i], Vec(0,0,0))
				if sleep then
					--If robot is sleeping make sure to not wake it up
					SetBodyActive(humanoid.allBodies[i], false)
				end
			end
		end
	end

	if HasTag(humanoid.body, "sleeping") then
		if IsBodyActive(humanoid.body) then
			wakeUp = true
		end
		local vol, pos = GetLastSound()
		if vol > 0.2 then
			if humanoid.investigateTrigger == 0 or IsPointInTrigger(humanoid.investigateTrigger, pos) then
				wakeUp = true
			end
		end	
		if wakeUp then
			RemoveTag(humanoid.body, "sleeping")
		end
		return
	end

	humanoidUpdate()

	if not humanoid.enabled then
		return
	end

	if humanoid.health <= 0.0 then
		for i = 1, #humanoid.allShapes do
			SetShapeEmissiveScale(humanoid.allShapes[i], 0)
		end
		SetTag(humanoid.body, "disabled")
		humanoid.enabled = false
		playVoice(dieSound, humanoid.bodyCenter, 1.0, false)
	end
	
	-- if IsPointInWater(humanoid.bodyCenter) then
	-- 	PlaySound(disableSound, humanoid.bodyCenter, 1.0, false)
	-- 	for i=1, #humanoid.allShapes do
	-- 		SetShapeEmissiveScale(humanoid.allShapes[i], 0)
	-- 	end
	-- 	SetTag(humanoid.body, "disabled")
	-- 	humanoid.enabled = false
	-- end
	
	humanoid.stunned = clamp(humanoid.stunned - dt, 0.0, 6.0)
	if humanoid.stunned > 0 then
		head.seenTimer = 0
		weaponsReset()
		return
	end
	
	hoverUpdate(dt)
	headUpdate(dt)
	aimsUpdate(dt)
	weaponsUpdate(dt)
	animatorUpdate(dt)
	hearingUpdate(dt)
	stackUpdate(dt)
	humanoid.speedScale = 1
	humanoid.speed = 0
	local state = stackTop()
	
	if state.id == "none" then
		if config.patrol then
			stackPush("patrol")
		else
			stackPush("roam")
		end
	end

	if state.id == "roam" then
		if not state.nextAction then
			state.nextAction = "move"
		elseif state.nextAction == "move" then
			local randomPos
			if humanoid.roamTrigger ~= 0 then
				randomPos = getRandomPosInTrigger(humanoid.roamTrigger)
				randomPos = truncateToGround(randomPos)
			else
				local rndAng = rnd(0, 2*math.pi)
				randomPos = VecAdd(humanoid.transform.pos, Vec(math.cos(rndAng)*6.0, 0, math.sin(rndAng)*6.0))
			end
			local s = stackPush("navigate")
			s.timeout = 1
			s.pos = randomPos
			state.nextAction = "search"
		elseif state.nextAction == "search" then
			stackPush("search")
			state.nextAction = "move"
		end
	end

	
	if state.id == "patrol" then
		if not state.nextAction then
			state.index = getClosestPatrolIndex()
			state.nextAction = "move"
		elseif state.nextAction == "move" then
			markPatrolLocationAsActive(state.index)
			local nav = stackPush("navigate")
			nav.pos = GetLocationTransform(patrolLocations[state.index]).pos
			state.nextAction = "search"
		elseif state.nextAction == "search" then
			stackPush("search")
			state.index = getNextPatrolIndex(state.index)
			state.nextAction = "move"
		end
	end

	
	if state.id == "search" then
		if state.activeTime > 2.5 then
			if not state.turn then
				humanoidSetDirAngle(humanoidGetDirAngle() + math.random(2, 4))
				state.turn = true
			end
			if state.activeTime > 6.0 then
				stackPop()
			end
		end
		if state.activeTime < 1.5 or state.activeTime > 3 and state.activeTime < 4.5 then
			head.dir = TransformToParentVec(humanoid.transform, Vec(-5, 0, -1))
		else
			head.dir = TransformToParentVec(humanoid.transform, Vec(5, 0, -1))
		end
	end

	
	if state.id == "investigate" then
		if not state.nextAction then
			local pos = state.pos
			humanoidTurnTowards(state.pos)
			headTurnTowards(state.pos)
			local nav = stackPush("navigate")
			nav.pos = state.pos
			nav.timeout = 5.0
			state.nextAction = "search"
		elseif state.nextAction == "search" then
			stackPush("search")
			state.nextAction = "done"
		elseif state.nextAction == "done" then
			playVoice(idleSound, humanoid.bodyCenter, 1.0, false)
			stackPop()
		end	
	end
	
	if state.id == "move" then
		humanoidTurnTowards(state.pos)
		humanoid.speed = config.speed
		head.dir = VecCopy(humanoid.dir)
		local d = VecLength(VecSub(state.pos, humanoid.transform.pos))
		if d < 2 then
			humanoid.speed = 0
			stackPop()
		else
			if humanoid.blocked > 0.5 then
				stackPush("unblock")
			end
		end
	end
	
	if state.id == "unblock" then
		if not state.dir then
			if math.random(0, 10) < 5 then
				state.dir = TransformToParentVec(humanoid.transform, Vec(-1, 0, -1))
			else
				state.dir = TransformToParentVec(humanoid.transform, Vec(1, 0, -1))
			end
			state.dir = VecNormalize(state.dir)
		else
			humanoid.dir = state.dir
			humanoid.speed = -math.min(config.speed, 2.0)
			if state.activeTime > 1 then
				stackPop()
			end
		end
	end

	--Hunt player
	if state.id == "hunt" then
		if not state.init then
			navigationClear()
			state.init = true
			state.headAngle = 0
			state.headAngleTimer = 0
		end
		if humanoid.distToPlayer < 4.0 then
			humanoid.dir = VecCopy(humanoid.dirToPlayer)
			head.dir = VecCopy(humanoid.dirToPlayer)
			humanoid.speed = 0
			navigationClear()
		else
			navigationSetTarget(head.lastSeenPos, 1.0 + clamp(head.timeSinceLastSeen, 0.0, 4.0))
			humanoid.speedScale = config.huntSpeedScale
			navigationUpdate(dt)
			if head.canSeePlayer then
				head.dir = VecCopy(humanoid.dirToPlayer)
				state.headAngle = 0
				state.headAngleTimer = 0
			else
				state.headAngleTimer = state.headAngleTimer + dt
				if state.headAngleTimer > 1.0 then
					if state.headAngle > 0.0 then
						state.headAngle = rnd(-1.0, -0.5)
					elseif state.headAngle < 0 then
						state.headAngle = rnd(0.5, 1.0)
					else
						state.headAngle = rnd(-1.0, 1.0)
					end
					state.headAngleTimer = 0
				end
				head.dir = QuatRotateVec(QuatEuler(0, state.headAngle, 0), humanoid.dir)
			end
		end
		if navigation.state ~= "move" and head.timeSinceLastSeen < 2 then
			--Turn towards player if not moving
			humanoid.dir = VecCopy(humanoid.dirToPlayer)
		end
		if navigation.state ~= "move" and head.timeSinceLastSeen > 2 and state.activeTime > 3.0 and VecLength(GetBodyVelocity(humanoid.body)) < 1 then
			if VecDist(head.lastSeenPos, humanoid.bodyCenter) > 3.0 then
				stackClear()
				local s = stackPush("investigate")
				s.pos = VecCopy(head.lastSeenPos)		
			else
				stackClear()
				stackPush("huntlost")
			end
		end
	end

	if state.id == "huntlost" then
		if not state.timer then
			state.timer = 6
			state.turnTimer = 1
		end
		state.timer = state.timer - dt
		head.dir = VecCopy(humanoid.dir)
		if state.timer < 0 then
			playVoice(lostSound, humanoid.bodyCenter, 1.0, false)
			stackPop()
		else
			state.turnTimer = state.turnTimer - dt
			if state.turnTimer < 0 then
				humanoidSetDirAngle(humanoidGetDirAngle() + math.random(2, 4))
				state.turnTimer = rnd(0.5, 1.5)
			end
		end
	end
	
	--Avoid player
	if state.id == "avoid" then
		if not state.init then
			navigationClear()
			state.init = true
			state.headAngle = 0
			state.headAngleTimer = 0
		end
		
		local distantPatrolIndex = getDistantPatrolIndex(GetPlayerTransform().pos)
		local avoidTarget = GetLocationTransform(patrolLocations[distantPatrolIndex]).pos
		navigationSetTarget(avoidTarget, 1.0)
		humanoid.speedScale = config.huntSpeedScale
		navigationUpdate(dt)
		if head.canSeePlayer then
			head.dir = VecNormalize(VecSub(head.lastSeenPos, humanoid.transform.pos))
			state.headAngle = 0
			state.headAngleTimer = 0
		else
			state.headAngleTimer = state.headAngleTimer + dt
			if state.headAngleTimer > 1.0 then
				if state.headAngle > 0.0 then
					state.headAngle = rnd(-1.0, -0.5)
				elseif state.headAngle < 0 then
					state.headAngle = rnd(0.5, 1.0)
				else
					state.headAngle = rnd(-1.0, 1.0)
				end
				state.headAngleTimer = 0
			end
			head.dir = QuatRotateVec(QuatEuler(0, state.headAngle, 0), humanoid.dir)
		end
		
		if navigation.state ~= "move" and head.timeSinceLastSeen > 2 and state.activeTime > 3.0 then
			stackClear()
		end
	end
	
	--Get up player
	if state.id == "getup" then
		if not state.time then 
			state.time = 0 
		end
		state.time = state.time + dt
		hover.timeSinceContact = 0
		if state.time > 2.0 then
			stackPop()
		else
			hoverGetUp()
		end
	end

	if state.id == "navigate" then
		if not state.initialized then
			if not state.timeout then state.timeout = 30 end
			navigationClear()
			navigationSetTarget(state.pos, state.timeout)
			state.initialized = true
		else
			head.dir = VecCopy(humanoid.dir)
			navigationUpdate(dt)
			if navigation.state == "done" or navigation.state == "fail" then
				stackPop()
			end
		end
	end

	--React to sound
	if not stackHas("hunt") then
		if hearing.hasNewSound and hearing.timeSinceLastSound < 1.0 then
			stackClear()
			playVoice(alertSound, humanoid.bodyCenter, 1.0, false)
			local s = stackPush("investigate")
			s.pos = hearing.lastSoundPos	
			hearingConsumeSound()
		end
	end
	
	--Seen player
	if config.huntPlayer and not stackHas("hunt") then
		if config.canSeePlayer and head.canSeePlayer or humanoid.canSensePlayer then
			stackClear()
			playVoice(huntSound, humanoid.bodyCenter, 1.0, false)
			stackPush("hunt")
		end
	end
	
	--Seen player
	if config.avoidPlayer and not stackHas("avoid") then
		if config.canSeePlayer and head.canSeePlayer or humanoid.distToPlayer < 2.0 then
			stackClear()
			stackPush("avoid")
		end
	end
	
	--Get up
	if hover.timeSinceContact > 3.0 and not stackHas("getup") then
		stackPush("getup")
	end
	
	if IsShapeBroken(GetLightShape(head.eye)) then
		config.hasVision = false
		config.canSeePlayer = false
	end
end

function canBeSeenByPlayer()
	for i=1, #humanoid.allShapes do
		if IsShapeVisible(humanoid.allShapes[i], config.outline, true) then
			return true
		end
	end
	return false
end

function playVoice(snd, pos, volume, bool)
	if type(snd) == "table" then
		PlaySound(snd[math.random(#snd)], pos, volume, bool)
	else
		PlaySound(snd, pos, volume, bool)
	end
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

function tick(dt)
	if not humanoid.enabled then
		return
	end
	
	if HasTag(humanoid.body, "turnhostile") then
		RemoveTag(humanoid.body, "turnhostile")
		config.canHearPlayer = true
		config.canSeePlayer = true
		config.huntPlayer = true
		config.aggressive = true
		config.practice = false
	end
	if first then
		identifier = getIdentifierCount() + 1
		--DebugPrint(identifier)
		setIdentifierCount(identifier)
		setLastSpawn(identifier)
		MakeHole(humanoid.bodyCenter, 6, 6, 6, true)
		first = false
		for i=1, #humanoid.allBodies do
			SetTag(humanoid.allBodies[i], "identifier", tostring(identifier))
			--DebugPrint(humanoid.allBodies[i])
			local shapes = GetBodyShapes(humanoid.allBodies[i])
			for j=1, #shapes do
				SetTag(shapes[j], "identifier", tostring(identifier))
			end
		end
	end

	bulletBlock.value = bulletBlock.value - dt
	identifier = GetTagValue(humanoid.body, "identifier")

	local difficulty = getDifficultyInRegistry()
	local playerHitting = getPlayerHitting()
	local dontDamage = false
	local counterAttack = false
	local shieldToggled = getShieldToggle()
	local staminaDamage = getStaminaDamageInRegistry()
	local staminaValue = getStaminaValueInRegistry()

	invulnerability.value = invulnerability.value - dt
	if getHitInRegistry(identifier) and invulnerability.value <= 0 then
		invulnerability.value = invulnerability.default
		if fight.action ~= PARRYING then
			if fight.action ~= BLOCK then
				if fight.action ~= LSLICE and fight.action ~= VSLICE then -- hit at the same time -> block
					if getBumpStatus(identifier) then
						setBumpStatus(identifier, false)
						SetBodyVelocity(humanoid.body, VecAdd(GetBodyVelocity(humanoid.body), getBumpDir(identifier)))
					end
					local dmg = getDamageAmountInRegistry()
					if difficulty == "hardcore" then
						dmg = dmg * 3
					end
					humanoid.health = humanoid.health - dmg
					--DebugPrint(humanoid.health)
					if humanoid.health <= 0 then
						setEnemyDeath(true)
						local shape = getShapeHit(identifier)
						local joints = GetShapeJoints(shape)
						for i=1, #joints do
							DetachJointFromShape(joints[i], shape)
						end
					end
					setDamageDone(true)
					if fight.action ~= LSLICE and fight.action ~= VSLIC then
						humanoid.stunned = humanoid.stunned + 0.1
						fight.action = NOTHING
						fight.anim = deepcopy(animator[fight.action])
					end
				else
					setSpawnSparks(true)
					fight.anim.duration = 0
					dontDamage = true
				end
			else
				fight.anim.duration = 0
				setStunInRegistry(true)
				setSpawnSparks(true)
			end
		else
			fight.anim.duration = 0
			fight.anim.failed = true
			--counterAttack = true
			--setStunInRegistry(true)
			setSpawnSparks(true)
		end
	elseif getGuardBreakOnEnemy(identifier) and invulnerability.value <= 0 then
		invulnerability.value = invulnerability.default
		setGuardBreakOnEnemy(identifier, false)
		if fight.action == PARRYING or fight.action == BLOCK then
			fight.action = STUN
			--DebugPrint("stun")
			fight.anim = deepcopy(animator[fight.action])
			--fight.anim.duration = 0
			if getBumpStatus(identifier) then -- is bumped by the hit
				setBumpStatus(identifier, false)
				SetBodyVelocity(humanoid.body, VecAdd(GetBodyVelocity(humanoid.body), getBumpDir(identifier)))
			end
		end
	else
		if fight.action == BLOCK and fight.anim.duration - dt <= 0 then -- block nothing
			fight.anim.failed = true
		end
	end
	setInvulnerabilityStatus(identifier, not (invulnerability.value <= 0))
	setHitInRegistry(identifier, false)


	local range = 9.5
	local damageRange = 4.5
	local st = GetBodyTransform(humanoid.body)
	local angleToPlayer = math.acos(VecDot(TransformToParentVec(st, Vec(0, 0, -1)), VecNormalize(VecSub(humanoid.playerPos, st.pos))))
	local maxAngle = 85 * math.pi / 180
	--DebugWatch(identifier, angleToPlayer .. " / " .. maxAngle)

	fight.anim.duration = fight.anim.duration - dt

	if VecDist(humanoid.playerPos, humanoid.bodyCenter) <= damageRange and angleToPlayer <= maxAngle then
		if fight.action == VSLICE or fight.action == LSLICE then
			if fight.anim.duration <= animator[fight.action].duration / 2 then
				if getPlayerBlocking() then
					if shieldToggled then
						local updatedStamina = staminaValue - staminaDamage
						--DebugPrint(updatedStamina)
						setStaminaValueInRegistry(updatedStamina)
						fight.anim.failed = true
						setSpawnSparks(true)
						if updatedStamina <= 0 then
							setGuardBreak(true)
							SetPlayerHealth(GetPlayerHealth() - (fight.dmg.value / 100))
							if difficulty == "hardcore" then
								SetPlayerHealth(0)
							end
							fight.anim.duration = 0
							setPlayerHurt(true)
							fight.anim.failed = false
						end
					else
						setSpawnSparks(true)
						fight.anim.failed = true
					end
				else
					if playerHitting or dontDamage then
						setSpawnSparks(true)
						counterAttack = true
						fight.anim.duration = 0
					else
						SetPlayerHealth(GetPlayerHealth() - (fight.dmg.value / 100))
						if difficulty == "hardcore" then
							SetPlayerHealth(0)
						end
						fight.anim.duration = 0
						setPlayerHurt(true)
					end
				end
			end
		elseif fight.action == GUARDBREAK then
			if fight.anim.duration <= animator[fight.action].duration / 2 then
				if getPlayerBlocking() then
					fight.anim.duration = 0
					if not shieldToggled then
						setGuardBreak(true)
					else
						local updatedStamina = staminaValue - staminaDamage
						--DebugPrint(updatedStamina)
						setStaminaValueInRegistry(updatedStamina)
						fight.anim.failed = true
						setSpawnSparks(true)
						if updatedStamina <= 0 then
							fight.anim.failed = false
							setGuardBreak(true)
						end
					end
				else
					fight.anim.failed = true
				end
			end
		end
	end

	local actionList = {NOTHING, LOAD_VSLICE, LOAD_LSLICE, PARRYING, FEINT, LOAD_GB} -- actions available by default
	local actionAttackList = {LOAD_VSLICE, LOAD_LSLICE}

	local threshold = 6
	local valueRandom = math.random(1, 10)
	if getPlayerThrust() then
		threshold = 8
		range = range * 1.5
		setPlayerThrust(false)
		--DebugPrint(valueRandom)
	end

	-- reflex parry
	local shouldBlock = ((getPlayerAttack() or counterAttack) and 
						valueRandom <= threshold and
						VecDist(humanoid.playerPos, humanoid.bodyCenter) <= range and
						angleToPlayer <= maxAngle and
						(fight.action == NOTHING or fight.action == LOAD_VSLICE or fight.action == LOAD_GB or fight.action == LOAD_LSLICE))

	local abortParry = (InputPressed("mmb") and 
					   math.random(1, 10) <= 6 and
					   fight.action == PARRYING)

	-- select next action
	if abortParry or shouldBlock or fight.anim.failed or fight.anim.duration <= 0 then
		if (VecDist(humanoid.playerPos, humanoid.bodyCenter) <= range and angleToPlayer <= maxAngle) or
				shouldBlock or fight.action == LOAD_VSLICE or fight.action == LOAD_LSLICE then
			if shouldBlock then
				fight.action = BLOCK
			elseif abortParry then
				fight.action = actionAttackList[math.random(1, #actionAttackList)]
			elseif getPlayerBlocking() and math.random(1, 10) <= 3 and not shieldToggled then
				fight.action = LOAD_GB
			else
				if fight.anim.failed and #fight.anim.fail > 0 then
					actionList = fight.anim.fail
				elseif not fight.anim.failed and #fight.anim.success > 0 then
					actionList = fight.anim.success
				end
				fight.action = actionList[math.random(1, #actionList)]
			end
		else
			fight.action = NOTHING
		end
		fight.anim = deepcopy(animator[fight.action])
		fight.anim.failed = false
		--DebugPrint(fight.action)
	end
	
	--Outline
	local dist = VecDist(humanoid.bodyCenter, GetPlayerCameraTransform().pos)
	if dist < config.outline then
		local a = clamp((config.outline - dist) / 5.0, 0.0, 1.0)
		if canBeSeenByPlayer() then
			a = 0
		end
		humanoid.outlineAlpha = humanoid.outlineAlpha + clamp(a - humanoid.outlineAlpha, -0.1, 0.1)
		for i=1, #humanoid.allBodies do
			--DrawBodyOutline(humanoid.allBodies[i], 1, 1, 1, humanoid.outlineAlpha*0.5)
		end
	end
	
	--Remove planks and wires after some time
	local tags = {"plank", "wire"}
	local removeTimeOut = 10
	for i=1, #humanoid.allShapes do
		local shape = humanoid.allShapes[i]
		local joints = GetShapeJoints(shape)
		for j=1, #joints do
			local joint = joints[j]
			for t=1, #tags do
				local tag = tags[t]
				if HasTag(joint, tag) then
					local t = tonumber(GetTagValue(joint, tag)) or 0
					t = t + dt
					if t > removeTimeOut then
						if GetJointType(joint) == "rope" then
							DetachJointFromShape(joint, shape)
						else
							Delete(joint)
						end
						break
					else
						SetTag(joint, tag, t)
					end
				end
			end
		end
	end

	-- debugState()
end


function hitByExplosion(strength, pos)
	if not humanoid.enabled then
		return
	end
	--Explosions smaller than 1.0 are ignored (with a bit of room for rounding errors)
	if strength > 0.99 then
		local d = VecDist(pos, humanoid.bodyCenter)	
		local f = clamp((1.0 - (d-2.0)/6.0), 0.0, 1.0) * strength
		if f > 0.2 then
			humanoid.stunned = math.max(humanoid.stunned, f * 4.0)
		end

		local damage = f * 20.0
		humanoid.health = humanoid.health - f * 20.0
		playVoice(hurtSound, humanoid.bodyCenter, 1.0, false)
		
		--Give robots an extra push if they are not already moving that much
		--Unphysical but more fun
		local maxVel = 7.0
		local strength = 3.0
		local dir = VecNormalize(VecSub(humanoid.bodyCenter, pos))
		--Tilt direction upwards to make them fly more
		dir[2] = dir[2] + 1.0
		dir = VecNormalize(dir)
		for i=1, #humanoid.allBodies do
			local b = humanoid.allBodies[i]
			local v = GetBodyVelocity(b)
			local scale = clamp(1.0-VecLength(v)/maxVel, 0.0, 1.0)
			local velAdd = math.min(maxVel, f*scale*strength)
			if velAdd > 0 then
				v = VecAdd(v, VecScale(dir, velAdd))
				SetBodyVelocity(b, v)
			end
		end
	end
end


function hitByShot(strength, pos, dir)
	if not humanoid.enabled then
		return
	end
	if VecDist(pos, humanoid.bodyCenter) < 3 then
		local hit, point, n, shape = QueryClosestPoint(pos, 0.1)
		if hit then
			for i=1, #humanoid.allShapes do
				if humanoid.allShapes[i] == shape then
					--Take damage
					local damage = strength * 20.0
					if GetShapeBody(shape) == humanoid.torso then
						damage = damage * humanoid.torsoDamageScale
					elseif GetShapeBody(shape) == head.body then
						damage = damage * humanoid.headDamageScale
					end
					humanoid.health = humanoid.health - damage
					humanoid.stunned = humanoid.stunned + 0.2
					playVoice(hurtSound, humanoid.bodyCenter, 1.0, false)
					return
				end
			end
		end
	end
end

-----------------------------------------------------------------------

function truncateToGround(pos)
	rejectAllBodies(humanoid.allBodies)
	QueryRejectVehicle(GetPlayerVehicle())
	hit, dist = QueryRaycast(pos, Vec(0, -1, 0), 5, 0.2)
	if hit then
		pos = VecAdd(pos, Vec(0, -dist, 0))
	end
	return pos
end


function getRandomPosInTrigger(trigger)
	local mi, ma = GetTriggerBounds(trigger)
	local minDist = math.max(ma[1]-mi[1], ma[3]-mi[3])*0.25
	minDist = math.min(minDist, 5.0)

	for i=1, 100 do
		local probe = Vec()
		for j=1, 3 do
			probe[j] = mi[j] + (ma[j]-mi[j])*rnd(0,1)
		end
		if IsPointInTrigger(trigger, probe) then
			return probe
		end
	end
	return VecLerp(mi, ma, 0.5)
end



function handleCommand(cmd)
	words = splitString(cmd, " ")
	if #words == 5 then
		if words[1] == "explosion" then
			local strength = tonumber(words[2])
			local x = tonumber(words[3])
			local y = tonumber(words[4])
			local z = tonumber(words[5])
			hitByExplosion(strength, Vec(x,y,z))
		end
	end
	if #words == 8 then
		if words[1] == "shot" then
			local strength = tonumber(words[2])
			local x = tonumber(words[3])
			local y = tonumber(words[4])
			local z = tonumber(words[5])
			local dx = tonumber(words[6])
			local dy = tonumber(words[7])
			local dz = tonumber(words[8])
			local randValue = math.random(1, 10)


			hitByShot(strength, Vec(x,y,z), Vec(dx,dy,dz))
			--DebugPrint(humanoid.health)
		end
	end
end