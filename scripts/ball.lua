
function init()
    body = FindBody("bombardball")
    radius = 1.0

    trigger1 = false
    trigger2 = false
    breaking = 500
    ratio = {
        soft = 0.15,
        medium = 0.1,
        hard = 3
    }
    timeToLive = 20
    disappear = false

    impact = false
    sndPoke = LoadSound("MOD/snd/poke.ogg")

    previousPos = GetBodyTransform(body).pos
    touchWater = false
end

function tick(dt)

    if IsPointInWater(GetBodyTransform(body).pos) and not touchWater then
        touchWater = true
        splash(GetBodyTransform(body).pos)
    end
    
    if timeToLive <= 0 then
        Delete(body)
    else
        local vel = GetBodyVelocity(body)
        local pos = GetBodyTransform(body).pos
        sparks(GetBodyTransform(body).pos)
        previousPos = pos

        if disappear then
            timeToLive = timeToLive - dt
        end

        if VecLength(vel) >= 30 then
            disappear = true
            local count = 0
            local pos = VecAdd(GetBodyTransform(body).pos, VecScale(vel, dt))
            local radius = 1
            local oldCount = count
            count = count + MakeHole(pos, radius, radius, radius / 2) * ratio.soft
            if oldCount ~= count and not impact and HasTag(body, "ally")  then
                impact = true
                PlaySound(sndPoke, GetCameraTransform().pos, 0.2)
            end
            breaking = breaking - count

            if breaking <= 0 then
                Delete(body)
                trigger1 = false
            end
        end
    end
end

function randVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end

function randFloat(mi, ma)
	return math.random(1000)/1000*(ma-mi) + mi
end

function splash(pos)
    local radius = 0.2
	local life = 3.0
	local count = 150
	local drag = 0
	local gravity = -9.82
	local alpha = 0.8
	
	--Set up the particle state
	ParticleReset()
	ParticleType("plain")
	ParticleRadius(radius)
	ParticleAlpha(alpha, 0.3)	-- Ramp up fast, ramp down after 50%
	ParticleGravity(gravity * randFloat(0.9, 1.1))				-- Slightly randomized gravity looks better
	ParticleDrag(drag)
	ParticleTile(0)
	ParticleCollide(0)
    ParticleEmissive(0.8, 0.8)

    local force = 7
    local baseVel = GetBodyVelocity(body)
    if VecLength(baseVel) < 30 then
        return
    end
    baseVel = VecScale(VecNormalize(baseVel), force)
	
	--Emit particles
	for i=1, count do
        local red = 0.8
        local green = 0.8
        local blue = 0.85
        ParticleColor(red, green, blue, 0.6, 0.6, 0.75)
		local p = pos
	
		--Randomize lifetime
		local l = randFloat(life * 0.8, life * 1.2)

        local vel = randVec(1.5)
        vel = VecAdd(vel, Vec(0, force, 0))
        vel = VecAdd(vel, baseVel)
        vel = VecScale(vel, randFloat(0.5, 1.5))

		SpawnParticle(p, vel, l)
	end
end

function sparks(pos)
	local radius = 0.25
	local life = 1.2
	local count = 8
	local drag = 0.2
	local gravity = 0.5
	local alpha = 0.5

    local chances = 0
    if VecLength(GetBodyVelocity(body)) > 30 then
        chances = 7
        life = life / 2
    elseif VecLength(GetBodyVelocity(body)) <= 31 then
        return
    end
    if math.random(1, 10) <= 8 - chances then
        return
    end
	
	--Set up the particle state
	ParticleReset()
	ParticleType("plain")
	ParticleRadius(radius)
	ParticleAlpha(alpha, 0.1)	-- Ramp up fast, ramp down after 50%
	ParticleGravity(gravity * randFloat(0.7, 1.3))				-- Slightly randomized gravity looks better
	ParticleDrag(drag)
	ParticleTile(5)
	ParticleCollide(0, 1, "easeout")
    ParticleEmissive(0.8, 0.8)
	
	--Emit particles
	for i=1, count do
        local red = 0.7
        local green = 0.7
        local blue = 0.7
        ParticleColor(red, green, blue, 0.4, 0.4, 0.4)			-- Animating color towards white
		local p = TransformToParentPoint(Transform(VecLerp(pos, previousPos, math.random()), GetBodyTransform(body).rot), Vec(0.05, 0, -0.1))
	
		--Randomize lifetime
		local l = randFloat(life * 0.8, life * 1.2)

		SpawnParticle(p, Vec(), l)
	end
end