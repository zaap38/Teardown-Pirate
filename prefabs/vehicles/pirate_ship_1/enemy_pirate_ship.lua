#include "../../../snippets.lua"

function init()

    sail = {
        value = 0,
        max = 2
    }
    vehicleHandle = FindVehicle("")
    vehicleBody = GetVehicleBody(vehicleHandle)

    engageDist = 300
    huntDist = 4 * engageDist
    canonBallVelocity = 80

    snd = {}
    snd.shoot = LoadSound("MOD/snd/boom.ogg")

    gravity = 9.82

    canons = {
        all = {},
        right = {},
        left = {},
        yvel = {
            base = 5,
            increment = 3,
            state = {
                value = 0,
                max = 2
            }
        }
    }

    inactivityCooldown = {
        value = 300,
        default = 300
    }

    emerging = 30

    timeToDie = 120
    sinkVelocity = 0
    sinkForce = -2

    selfRotSpeed = 0
    selfRotForce = 45

    exploded = false
    
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

    firstEmerge = true

    addSelfVelocity = true
end

function tick(dt)

    if exploded then
        timeToDie = timeToDie - dt
    end
    if timeToDie <= 0 or inactivityCooldown.value <= 0 then
        Delete(vehicleHandle)
    else
        emerging = emerging - dt
        if emerging <= 0 and firstEmerge then
            firstEmerge = false
            local t = GetVehicleTransform(vehicleHandle)
            local x, y, z = GetQuatEuler(t.rot)
            SetBodyTransform(vehicleBody, Transform(t.pos, QuatEuler(0, y, 0)))
        end
        if timeToDie <= 15 then
            sinkVelocity = sinkVelocity * 0.97
            sinkVelocity = sinkVelocity + dt * sinkForce
            SetBodyVelocity(GetVehicleBody(vehicleHandle), Vec(0, sinkVelocity, 0))
        end
        if GetVehicleHealth(vehicleHandle) > 0.5 then
            shoot()
            drive(dt)
        elseif not exploded then
            exploded = true
            local spawnPos = TransformToParentPoint(GetVehicleTransform(vehicleHandle), Vec(0, 3, 7))
            Spawn("MOD/sword_fight/spawn/combine.xml", Transform(spawnPos))
        end
    end
end

function update(dt)
    updateCanonsCooldown(dt)
    stabilize(dt)
end

function draw(dt)

end

function stabilize(dt)
    selfRotSpeed = rebound(selfRotSpeed * 0.97, -90, 90)
    if exploded or emerging >= 0 or not IsPointInWater(GetVehicleTransform(vehicleHandle).pos) then
        return
    end
    ConstrainOrientation(vehicleBody, 0, QuatEuler(0, selfRotSpeed * dt, 0), Quat())
end

function isPlayerInVehicle()
    return vehicleHandle == GetPlayerVehicle()
end

function updateSail()
    if InputPressed("up") then
        sail.value = math.min(sail.value + 1, sail.max)
    end
    if InputPressed("down") then
        sail.value = math.max(sail.value - 1, 0)
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

function obstacle()
    local dist = 80
    local t = GetVehicleTransform(vehicleHandle)
    QueryRejectVehicle(vehicleHandle)
    QueryRejectVehicle(GetPlayerVehicle())
    local dir = TransformToParentVec(t, fwd())
    return QueryRaycast(t.pos, dir, dist)
end

function drive(dt)

    if exploded or emerging >= 0 then
        if not exploded then
            DriveVehicle(vehicleHandle, 1, 0, false)
        end
        return
    end

    local pt = GetPlayerTransform()
    local t = GetVehicleTransform(vehicleHandle)

    local playerPos, ptime = getPredictionPos()
    playerPos[2] = 0
    local shipPos = TransformToParentPoint(t, Vec(0, 0, -ptime * VecLength(GetBodyVelocity(vehicleBody))))--deepcopy(t.pos)--TransformToParentPoint(t, Vec(0, 0, -ptime * VecLength(GetBodyVelocity(vehicleBody))))
    if not addSelfVelocity then
        shipPos = deepcopy(t.pos)
    end
    shipPos[2] = 0

    local toPlayer = VecSub(playerPos, shipPos)

    local dist = VecLength(toPlayer)

    if dist > huntDist then
        inactivityCooldown.value = inactivityCooldown.value - dt
        return
    end
    inactivityCooldown.value = inactivityCooldown.default

    local steering = 0
    local playerDir = VecNormalize(toPlayer)
    local shipDir = TransformToParentVec(t, fwd())

    local angle = vecAngle(shipDir, playerDir, true)
    local absAngle = math.abs(angle)
    
    if dist <= engageDist then
        if angle < 0 then
            local a = angle + 90
            if a > 0 then
                steering = 1
            else
                steering = -1
            end
        else
            local a = angle - 90
            if a > 0 then
                steering = -1
            else
                steering = 1
            end
        end
    else
        steering = math.max(math.min(angle / 15, 1), -1)
    end

    if obstacle() then
        steering = 1
    end

    selfRotSpeed = selfRotSpeed - steering * GetTimeStep() * selfRotForce

    DriveVehicle(vehicleHandle, 1, steering, false)
end

function updateCanonsCooldown(dt)
    for i=1, #canons.all do
        canons.all[i].cooldown.value = canons.all[i].cooldown.value - dt
    end
end

function getPredictionPos()
    local shipT = GetVehicleTransform(vehicleHandle)
    local playerT = GetPlayerTransform()
    local pvehicle = GetPlayerVehicle()
    if pvehicle ~= 0 then
        playerT = GetVehicleTransform(pvehicle)
    end

    shipT.pos[2] = 0
    playerT.pos[2] = 0
    local toPlayer = VecSub(playerT.pos, shipT.pos)
    local angle = vecAngle(toPlayer, TransformToParentVec(shipT, Vec(1, 0, 0)))
    if angle > 90 then
        angle = math.abs(angle - 180)
    end
    local dist = VecLength(toPlayer) * math.cos(math.rad(angle))

    local playerVel = VecSub(GetPlayerVelocity(), GetBodyVelocity(vehicleBody))--GetPlayerVelocity()--VecSub(GetPlayerVelocity(), GetBodyVelocity(vehicleBody))
    if not addSelfVelocity then
        playerVel = GetPlayerVelocity()
    end
    playerVel[2] = 0

    local A = shipT.pos -- ship (self) pos
    local B = playerT.pos -- player pos
    local u = playerVel -- player velocity vector
    local cv = canonBallVelocity -- canon ball speed
    local O -- predicted pos given time
    local I = Vec() -- intersection pos
    local h = TransformToParentVec(shipT, Vec(1, 0, 0))

    local a, b, c, d, e, f
    a = u[3]
    b = -u[1]
    c = -B[1] * a - B[3] * b

    d = h[3]
    e = -h[1]
    f = -A[1] * d - A[3] * e

    --[[(x, y) € vel & h
    ax + by + c = 0
    dx + ey + f = 0

    x = -(by + c) / a
    dx + ey + f = 0

    d * (-(by + c) / a) + ey + f = 0
    ]]

    I[3] = ((d * c) / a - f) / (e - (d * b) / a)
    I[1] = -(b * I[3] + c) / a
    --drawPos(I, 0, 1, 1)
    --local up = Vec(0, 1, 0)
    --DrawLine(VecAdd(A, up), VecAdd(VecAdd(VecScale(h, 1000), up), A))
    --DrawLine(VecAdd(B, up), VecAdd(VecAdd(VecScale(u, 100), up), B))

    local distAI = VecLength(VecSub(I, A))
    local t = distAI / cv
    
    O = VecAdd(B, VecScale(u, t))
    --drawPos(O, 0, 1, 0)

    return O, t
end

function shoot()
    local shipT = GetVehicleTransform(vehicleHandle)
    local playerT = GetPlayerTransform()
    local pvehicle = GetPlayerVehicle()
    if pvehicle ~= 0 then
        playerT = GetVehicleTransform(pvehicle)
    end

    local dist = VecLength(VecSub(playerT.pos, TransformToParentPoint(shipT, Vec(0, 0, 0))))

    if dist <= engageDist * 2 then
        local playerPos, ptime = getPredictionPos()
        playerPos[2] = 0

        local middlePos = TransformToParentPoint(shipT, Vec(0, 0, 0))
        middlePos[2] = 0
        local toPlayer = VecSub(playerPos, middlePos)

        local x, y, z = GetQuatEuler(shipT.rot)
        shipT.rot = QuatEuler(0, y, 0)

        local angleLeft = vecAngle(TransformToParentVec(shipT, Vec(-1, 0, 0)), toPlayer)
        local angleRight = vecAngle(TransformToParentVec(shipT, Vec(1, 0, 0)), toPlayer)

        local boardWidth = 2.5
        local maxAngle = math.deg(math.asin(boardWidth / VecLength(VecSub(playerPos, shipT.pos))))
        local rl = nil
        local rr = nil

        local yvel = (gravity / 2) * ptime
        --[[local traj = {}
        local basePos = VecAdd(shipT.pos, Vec(0, 3, 0))
        for i=1, 20 do
            local ratioIndex = i / 20
            local ratio = ptime * ratioIndex
            traj[#traj + 1] = VecAdd(basePos, Vec(toPlayer[1] * ratioIndex, -0.5 * gravity * ratio * ratio + yvel * ratio, toPlayer[3] * ratioIndex))
        end]]

        if angleRight <= maxAngle then
            shootBoard("right", yvel)
            rr = 1
        end
        if angleLeft <= maxAngle then
            shootBoard("left", yvel)
            rl = 1
        end
        --drawPath(traj, rr or rl)
    end
end

function shootBoard(side, yvel) -- left, right, all
    yvel = yvel or 4
    for i=1, #canons[side] do
        local canon = canons[side][i]
        local t = GetShapeWorldTransform(canon.handle)
        --DrawLine(t.pos, TransformToParentPoint(t, Vec(0, 0, -5)))
        if canon.cooldown.value <= 0 and canon.enabled then
            shootCanon(canon, yvel)
        end
    end
end

function shootCanon(canon, yvel)
    if GetShapeBody(canon.handle) ~= vehicleBody then
        canon.enabled = false
        return
    end
    canon.cooldown.value = canon.cooldown.default
    local canonTransform = GetShapeWorldTransform(canon.handle)
    local spawnPos = TransformToParentPoint(canonTransform, Vec(0, 0, -0.5))
    local entities = Spawn("MOD/prefabs/canonball/canonball.xml", Transform(spawnPos))
    local b = getSpawnedEntities(entities, "body")
    local velBall = Vec(0, yvel * randFloat(0.95, 1.05), -80)
    local baseVel = GetBodyVelocity(vehicleBody)
    local vel = VecAdd(TransformToParentVec(canonTransform, velBall), baseVel)
    if not addSelfVelocity then
        vel = TransformToParentVec(canonTransform, velBall)
    end
    for i=1, #b do
        SetBodyVelocity(b[i], vel)
    end
    PlaySound(snd.shoot, spawnPos, 1)
    smoke(spawnPos, baseVel)
end

function smoke(pos, baseVel)
    local radius = 0.3
	local life = 4
	local count = 200
	local drag = 0.2
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
		p = VecAdd(pos, randVec(2 * radius))
		local v = VecAdd(randVec(randFloat(0.5, 7)), baseVel)

        if v[2] < 0 then
            v[2] = v[2] * 0.5
        end
	
		--Randomize lifetime
		local l = randFloat(life * 0.8, life * 1.2)

		SpawnParticle(p, v, l)
	end
end
