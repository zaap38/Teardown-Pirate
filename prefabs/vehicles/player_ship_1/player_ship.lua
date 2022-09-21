#include "../../../snippets.lua"

function init()

    sail = {
        value = 0,
        speed = 0.6
    }
    vehicleHandle = FindVehicle("")
    vehicleBody = GetVehicleBody(vehicleHandle)

    snd = {}
    snd.shoot = LoadSound("MOD/snd/boom.ogg")

    local sailsHandle = FindShapes("sail")
    sails = {}
    sailsOffset = 0.6
    sailsZOffset = 0.1
    for i=1, #sailsHandle do
        local handle = sailsHandle[i]
        local s = {
            handle = handle,
            index = tonumber(GetTagValue(handle, "sail")) - 1,
            t = GetShapeLocalTransform(handle)
        }
        sails[#sails + 1] = s
    end

    canons = {
        all = {},
        right = {},
        left = {},
        yvel = {
            base = 6,
            increment = 3,
            state = {
                value = 0,
                max = 4
            }
        }
    }

    gravity = 9.82
    canonBallVelocity = 80

    selfRotSpeed = 0
    selfRotForce = 45

    staticRotForce = 0.5
    
    local canonShapes = FindShapes("canon")
    for i=1, #canonShapes do
        local canon = {
            cooldown = {
                value = 0,
                default = 5
            },
            handle = canonShapes[i],
            enabled = true
        }

        canons.all[#canons.all + 1] = canon
        if GetTagValue(canon.handle, "side") == "right" then
            canons.right[#canons.right + 1] = canon
        else
            canons.left[#canons.left + 1] = canon
        end
    end

    pitchTime = 0
    pitchSpeed = 0
    pitchAngle = 0
    turning = 0
end

function tick(dt)
    if isPlayerInVehicle() then
        shoot()
        updateSail(dt)
        updateSailPos()
        updateCanonYVel()
        drawCanonsAim()
    end
    drive()
    stabilize(dt)
end

function update(dt)
    updateCanonsCooldown(dt)
    updatePitch(dt)
end

function draw(dt)

end

function updatePitch(dt)
    pitchTime = pitchTime + dt * 0.5
    local pitchForce = 0.13
    if math.cos(math.rad(pitchTime * 100) + math.pi) < 0 then
        pitchForce = -pitchForce
    end
    pitchSpeed = pitchSpeed * 0.97 + pitchForce * dt
    pitchAngle = pitchAngle + dt * pitchSpeed
end

function updateSailPos()
    for i=1, #sails do
        local s = sails[i]
        local offset = sailsOffset * s.index * sail.value
        local zoffset = sailsZOffset * s.index * sail.value
        local t = deepcopy(s.t)
        t.pos[2] = t.pos[2] - offset
        t.pos[3] = t.pos[3] - zoffset
        SetShapeLocalTransform(s.handle, t)
    end
end

function stabilize(dt)
    if isPlayerInVehicle() then
        if InputDown("left") or InputDown("right") then
            turning = 0.5
        end
    end
    local vt = GetVehicleTransform(vehicleHandle)
    turning = turning - dt
    if turning > 0 and IsPointInWater(vt.pos) then
        --SetBodyAngularVelocity(vehicleBody, Vec(0, GetBodyAngularVelocity(vehicleBody)[2], 0))
    else
        local rx, ry, rz = GetQuatEuler(vt.rot)
        local correction = Vec()
        local correctionValue = 1 * dt
        if rx < -0.01 then
            correction[1] = -correctionValue
        elseif rx > 0.01 then
            correction[1] = correctionValue
        elseif rz < -0.01 then
            correction[3] = -correctionValue
        elseif rz > 0.01 then
            correction[3] = correctionValue
        end   
        --SetBodyAngularVelocity(vehicleBody, VecAdd(GetBodyAngularVelocity(vehicleBody), correction))
    end
end

function drawCanonsAim()
    for i=1, #canons.all do
        if canons.all[i].enabled then
            drawCanonAim(canons.all[i])
        end
    end
end

function drawCanonAim(canon)
    local t = GetShapeWorldTransform(canon.handle)
    t.pos = TransformToParentPoint(t, Vec(0.25, 0.25, 0))
    
    local traj = {}
    local basePos = t.pos
    local yvel = canons.yvel.state.value * canons.yvel.increment + canons.yvel.base
    local vel = GetPlayerVelocity()
    for i=0, 3, 0.2 do -- simulated time
        local pos = Vec(0, -0.5 * gravity * i * i + yvel * i, -canonBallVelocity * i)
        traj[#traj + 1] = VecAdd(TransformToParentPoint(t, pos), VecScale(vel, i))
    end
    drawPath(traj, 1, 1, 1, 0.7, true)
end

function isPlayerInVehicle()
    return vehicleHandle == GetPlayerVehicle()
end

function updateSail(dt)
    if InputDown("up") then
        sail.value = math.min(sail.value + dt * sail.speed, 1)
    end
    if InputDown("down") then
        sail.value = math.max(sail.value - dt * sail.speed / 2, 0)
    end
end

function updateCanonYVel()
    local c = canons.yvel
    if InputPressed("flashlight") then
        c.state.value = c.state.value + 1
        if c.state.value > c.state.max then
            c.state.value = 0
        end
    end
end

function drive()
    if sail.value > 0 or isPlayerInVehicle() then
        local value = sail.value
        if isPlayerInVehicle() then
            if InputDown("up") then
                value = value - 1
            end
            if InputDown("down") then
                value = value + 1
            end
        end
        DriveVehicle(vehicleHandle, value, 0, false)
    end
end

function updateCanonsCooldown(dt)
    for i=1, #canons.all do
        canons.all[i].cooldown.value = canons.all[i].cooldown.value - dt
    end
end

function shoot()
    if InputPressed("grab") then
        shootBoard("right")
    end
    if InputPressed("usetool") then
        shootBoard("left")
    end
end

function shootBoard(side) -- left, right, all
    for i=1, #canons[side] do
        local canon = canons[side][i]
        if canon.cooldown.value <= 0 and canon.enabled then
            shootCanon(canon)
        end
    end
end

function shootCanon(canon)
    if GetShapeBody(canon.handle) ~= vehicleBody then
        canon.enabled = false
        return
    end
    canon.cooldown.value = canon.cooldown.default
    local canonTransform = GetShapeWorldTransform(canon.handle)
    local spawnPos = TransformToParentPoint(canonTransform, Vec(0, 0, -0.5))
    local entities = Spawn("MOD/prefabs/canonball/canonball.xml", Transform(spawnPos))
    local b = getSpawnedEntities(entities, "body")
    local vel = Vec(0, canons.yvel.state.value * canons.yvel.increment + canons.yvel.base + (math.random() - 0.5), -canonBallVelocity)
    local baseVel = GetBodyVelocity(vehicleBody)
    vel = VecAdd(TransformToParentVec(canonTransform, vel), baseVel)
    for i=1, #b do
        SetBodyVelocity(b[i], vel)
        SetTag(b[i], "ally", "true")
    end
    PlaySound(snd.shoot, spawnPos, 1)
    smoke(spawnPos, baseVel)
end

function smoke(pos, baseVel)
    local radius = 0.6
	local life = 3
	local count = 200
	local drag = 0.05
	local gravity = 0
	local alpha = 0.9

    if big then
        radius = radius * 2
    elseif huge then
        radius = radius * 3
    end
	
	--Set up the particle state
	ParticleReset()
	ParticleType("plain")
	ParticleRadius(radius)
	ParticleAlpha(alpha, 0.1, "constant", 0.1 / life, 0.5)	-- Ramp up fast, ramp down after 50%
	ParticleGravity(gravity, 0.6 * randFloat(0.7, 1.3))				-- Slightly randomized gravity looks better
	ParticleDrag(drag)
	ParticleTile(0)
	ParticleCollide(0)
    ParticleEmissive(0.4, 0.2)
	
	--Emit particles
	for i=1, count do
        local modif = randFloat(-0.02, 0.15)
        local red = 0.05 + modif
        local green = 0.05 + modif
        local blue = 0.05 + modif
        ParticleColor(red, green, blue)			-- Animating color towards white
		p = VecAdd(pos, randVec(1 * radius))
		local v = VecAdd(randVec(randFloat(0.5, 3)), baseVel)

        if v[2] < 0 then
            v[2] = v[2] * 0.5
        end
	
		--Randomize lifetime
		local l = randFloat(life * 0.8, life * 1.2)

		SpawnParticle(p, v, l)
	end
end