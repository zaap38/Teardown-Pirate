#include "snippets.lua"
#include "registry_snippets.lua"

function KeyInit()
	setKey("savegame.mod.weapon", 1, false)
end

function setKey(key, default, boolean, infinite)

	boolean = boolean or false
	infinite = infinite or false
	
	if not HasKey(key) then
		if boolean then
			SetBool(key, default)
		else
			SetInt(key, default)
		end
	end
	if infinite then
		if not HasKey(key .. "_infinite") then
			SetBool(key .. "_infinite", false)
		end
	end
end


function fightInit()

    KeyInit()

    toolname = "medieval_kit"
    toolnameStr = "Sword"
    local weaponId = GetInt("savegame.mod.weapon")
    if weaponId == 1 then
        toolname = "sword_mf"
        toolnameStr = "Sword"
    elseif weaponId == 2 then
        toolname = "axe_mf"
        toolnameStr = "Axe"
    elseif weaponId == 3 then
        toolname = "spear_mf"
        toolnameStr = "Spear"
    elseif weaponId == 4 then
        toolname = "hammer_mf"
        toolnameStr = "Hammer"
    end

    shieldToggled = false

    RegisterTool(toolname, toolnameStr, "MOD/sword_fight/vox/" .. toolname .. ".vox")
	SetBool("game.tool." .. toolname .. ".enabled", true)

    local hardcore = GetBool("savegame.mod.hardcore")
    local difficulty = "normal"
    if hardcore then
        difficulty = "hardcore"
    end
    setDifficultyInRegistry(difficulty)

    survival = false


    overlay = "" -- overlay image path

    weapon = nil
    weapons = {}
    SWORD = 1
    AXE = 2
    SPEAR = 3
    HAMMER = 4
    weapons[SWORD] = initSword()
    weapons[AXE] = initAxe()
    weapons[SPEAR] = initSpear()
    weapons[HAMMER] = initHammer()
    weapon = deepcopy(weapons[weaponId])

    setDamageAmountInRegistry(weapon.damage)

    stun = {
        value = 0,
        default = 1.0
    }

    incapacity = {
        value = 0,
        default = 1.0
    }

    slow = {
        ratio = 0.75,
        cooldown = {
            value = 0,
            default = 0.6
        }
    }


    identifierCount = 1
    enemies = {}

    animations = {}

    parryCooldown = {
        value = 0,
        default = 0.9
    }

    if shieldToggled then
        parryCooldown.default = 1.3
    end
    stamina = {
        value = 100,
        default = 100,
        regen = 7,
        damage = 20
    }

    oldHealth = 1

    --[[
        animations
            [i]
                state
                [j]
                    {time, pos, rot}
    ]]

    -- default pos = Vec(0.4, -0.8, -0.35), QuatEuler(-30, 0, 10)
    animations[#animations + 1] = {
        state = 1,
        timeLeft = nil,
        name = "vslice",
        effect = {false, false, true, true},
        pos = {makeAnimation(0.15, Vec(0.0, 1.1, -0.25), Vec(100, 0, -15)),
               makeAnimation(0.05, Vec(0, 0, 0), Vec(0, 0, 0)),
               makeAnimation(0.1, Vec(-0.225, -0.5, -0.4), Vec(-85, 0, 0)),
               makeAnimation(0.1, Vec(-0.225, -0.5, 0.0), Vec(-85, 0, 0)),
               makeAnimation(0.1, Vec(0, 0, 0), Vec(0, 0, 0)),
               makeAnimation(0.07, Vec(0.05, 0, 0.3), Vec(0, 0, 0)),
               makeAnimation(0.07, Vec(0.4, 0.0, 0.35), Vec(70, 0, 15))}
    }

    animations[#animations + 1] = {
        state = 1,
        timeLeft = nil,
        name = "lslice",
        effect = {false, false, true, true},
        pos = {makeAnimation(0.15, Vec(-0.45, 0.3, -0.25), Vec(40, 30, 75)),
               makeAnimation(0.05, Vec(0, 0, 0), Vec(0, 0, 0)),
               makeAnimation(0.25, Vec(0.75, 0.0, -0.05), Vec(-150, -45, -65)),
               makeAnimation(0.05, Vec(0, 0, 0), Vec(0, 0, 0)),
               makeAnimation(0.15, Vec(-0.3, -0.3, 0.3), Vec(0, 80, 0)),
               makeAnimation(0.08, Vec(-0.0, -0.0, 0.0), Vec(-70, -65, -10))}
    }

    animations[#animations + 1] = {
        state = 1,
        timeLeft = nil,
        name = "rslice",
        effect = {false, false, true, true},
        pos = {makeAnimation(0.15, Vec(0.15, 0.9, -0.25), Vec(100, 0, -55)),
               makeAnimation(0.05, Vec(0, 0, 0), Vec(0, 0, 0)),
               makeAnimation(0.1, Vec(-0.45, -0.25, -0.1), Vec(-95, -10, -15)),
               makeAnimation(0.1, Vec(-0.50, -0.35, 0.0), Vec(-95, -10, -15)),
               makeAnimation(0.15, Vec(0, 0, 0), Vec(0, 0, 0)),
               makeAnimation(0.1, Vec(0.8, -0.3, 0.35), Vec(90, 20, 85))}
    }

    animations[#animations + 1] = {
        state = 1,
        timeLeft = nil,
        name = "thrust",
        effect = {false, false, true, true, true},
        pos = {makeAnimation(0.25, Vec(-0.6, 1.2, -0.1), Vec(65, 180, -110)),
               makeAnimation(0.05, Vec(0, 0, 0), Vec(0, 0, 0)),
               makeAnimation(0.1, Vec(0.1, -0.125, -0.35), Vec(0, 0, 0)),
               makeAnimation(0.1, Vec(0.1, -0.125, -0.35), Vec(0, 0, 0)),
               makeAnimation(0.05, Vec(0, 0, 0), Vec(0, 0, 0)),
               makeAnimation(0.1, Vec(-0.1, 0.125, 0.35), Vec(0, 0, 0)),
               makeAnimation(0.1, Vec(-0.1, 0.125, 0.35), Vec(0, 0, 0)),
               makeAnimation(0.075, Vec(0.05, 0, 0.3), Vec(0, 0, 0)),
               makeAnimation(0.075, Vec(0.4, 0.0, 0.35), Vec(70, 0, 15)),
               makeAnimation(0.075, Vec(-0.25, -1.2, -0.9), Vec(155, -180, 80)),
               makeAnimation(0.075, Vec(0.4, 0, 0.35), Vec(70, 0, 15))}
    }

    animations[#animations + 1] = {
        state = 1,
        timeLeft = nil,
        name = "guardbreak",
        effect = {false, false, true, false},
        pos = {makeAnimation(0.15, Vec(0.0, 1.1, -0.25), Vec(100, 0, -15)),
               makeAnimation(0.05, Vec(0, 0, 0), Vec(0, 0, 0)),
               makeAnimation(0.1, Vec(-0.2, -0.2, -0.4), Vec(0, 0, 0)),
               makeAnimation(0.3, Vec(0.1, 0.1, 0.2), Vec(0, 0, 0)),
               makeAnimation(0.3, Vec(0.1, -1, 0.45), Vec(-100, 0, 15))}
    }

    animation = nil

    tt = defaultTransform() -- tool transform

    sndDing = {}
    sndDing[#sndDing + 1] = LoadSound("MOD/sword_fight/snd/ding1.ogg")
    sndDing[#sndDing + 1] = LoadSound("MOD/sword_fight/snd/ding2.ogg")
    sndDing[#sndDing + 1] = LoadSound("MOD/sword_fight/snd/ding3.ogg")

    sndHit = {}
    sndHit[#sndHit + 1] = LoadSound("MOD/sword_fight/snd/flesh1.ogg")
    sndHit[#sndHit + 1] = LoadSound("MOD/sword_fight/snd/flesh2.ogg")
    sndHit[#sndHit + 1] = LoadSound("MOD/sword_fight/snd/flesh3.ogg")

    sndMetal = {}
    sndMetal[#sndMetal + 1] = LoadSound("MOD/sword_fight/snd/metal1.ogg")
    sndMetal[#sndMetal + 1] = LoadSound("MOD/sword_fight/snd/metal2.ogg")
    sndMetal[#sndMetal + 1] = LoadSound("MOD/sword_fight/snd/metal3.ogg")
    sndMetal[#sndMetal + 1] = LoadSound("MOD/sword_fight/snd/metal4.ogg")

    sndSwing = {}
    sndSwing[#sndSwing + 1] = LoadSound("MOD/sword_fight/snd/swing1.ogg")
    sndSwing[#sndSwing + 1] = LoadSound("MOD/sword_fight/snd/swing2.ogg")
    
    sndWood = {}
    sndWood[#sndWood + 1] = LoadSound("MOD/sword_fight/snd/wood1.ogg")
    sndWood[#sndWood + 1] = LoadSound("MOD/sword_fight/snd/wood2.ogg")

    sndDie = {}
    sndDie[#sndDie + 1] = LoadSound("MOD/sword_fight/snd/die1.ogg")
    sndDie[#sndDie + 1] = LoadSound("MOD/sword_fight/snd/die2.ogg")
    sndDie[#sndDie + 1] = LoadSound("MOD/sword_fight/snd/die3.ogg")
    sndDie[#sndDie + 1] = LoadSound("MOD/sword_fight/snd/die4.ogg")

    
    sndLaugth = {}
    sndLaugth[#sndLaugth + 1] = LoadSound("MOD/sword_fight/snd/laugth1.ogg")

    sndGb = {}
    --sndGb[#sndGb + 1] = LoadSound("MOD/sword_fight/snd/hit1.ogg")
    sndGb[#sndGb + 1] = LoadSound("MOD/sword_fight/snd/hit2.ogg")

    lastSpawn = 0
    first = true

    st = defaultShieldTransform() -- shield transform
    sbody = nil -- shield body
end

function fightTick(dt)

    if first then
        first = false
        if survival then
            SetString("game.player.tool", toolname)
        end
        if shieldToggled then
            st = defaultShieldTransform()
            local ent = Spawn("spawn/shield_mf.xml", st)
            for i=1, #ent do
                if GetEntityType(ent[i]) == "body" then
                    sbody = ent[i]
                    break
                end
            end
        end
        stamina.value = stamina.default
        setStaminaDamageInRegistry(stamina.damage)
        setStaminaValueInRegistry(stamina.value)
        setShieldToggle(shieldToggled)
    end
    
    
    stamina.value = getStaminaValueInRegistry()
    if shieldToggled and stamina.value > 0 then
        setGuardBreak(false)
    end
    stamina.value = math.max(math.min(stamina.value + stamina.regen * dt, stamina.default), 0) -- stamina regen
    setStaminaValueInRegistry(stamina.value)

    if getGuardBreak() and shieldToggled and stamina.value > 0 then
        setGuardBreak(false)
    end

    setPlayerAttack(false)
    setPlayerHitting(isSlicing())
    
    if animation == nil then
        tt = defaultTransform()
    end

    identifierCount = getIdentifierCount()

    stun.value = stun.value - dt
    slow.cooldown.value = slow.cooldown.value - dt
    incapacity.value = incapacity.value - dt
    parryCooldown.value = parryCooldown.value - dt

    if oldHealth > 0 and GetPlayerHealth() <= 0 and survival then
        PlaySound(sndLaugth[rand(1, #sndLaugth)], TransformToParentPoint(GetPlayerCameraTransform(), Vec(0, 0, -1)), 0.9)
    end
    oldHealth = GetPlayerHealth()

    if getHasToSpawn() then
        setHasToSpawn(false)
        spawnEnemy(makeOffset(GetPlayerCameraTransform().pos), rand(1, 13))
    end

    if getEnemyDeath() then
        setEnemyDeath(false)
        PlaySound(sndDie[rand(1, #sndDie)], TransformToParentPoint(GetPlayerCameraTransform(), Vec(0, 0, -1)), 0.8)
    end

    if getSpawnSparks() then
        setSpawnSparks(false)
        makeSparks()
    end

    
    SetBodyTransform(sbody, Transform(Vec(0, -500, 0)))

    if isToolInHand() then
        ReleasePlayerGrab()
        
        SetBodyTransform(sbody, defaultShieldTransform())

        if slow.cooldown.value > 0 or stun.value > 0 then
            SetPlayerVelocity(VecScale(GetPlayerVelocity(), slow.ratio))
        end

        if stun.value > 0 or incapacity.value > 0 then
            SetToolTransform(stunTransform(), 0.3)
            animation = nil
            setIdentifierCount(identifierCount)
            return
        end

        if getDamageDone() then
            setDamageDone(false)
            PlaySound(sndHit[rand(1, #sndHit)], TransformToParentPoint(GetPlayerCameraTransform(), Vec(0, 0, -1)), 0.8)
            if weapon.id == HAMMER then
                PlaySound(sndMetal[rand(1, #sndMetal)], TransformToParentPoint(GetPlayerCameraTransform(), Vec(0, 0, -1)), 0.8)
            end
        end

        if getPlayerHurt() or (getGuardBreak() and not shieldToggled) then
            if not getGuardBreak() then
                slow.cooldown.value = slow.cooldown.default
                setPlayerHurt(false)
                PlaySound(sndHit[rand(1, #sndHit)], TransformToParentPoint(GetPlayerCameraTransform(), Vec(0, 0, -1)), 0.8)
            end
        end

        if InputPressed("usetool") and not InputDown("grab") then
            if animation == nil then
                animation = deepcopy(animations[rand(1, #animations - 2)])
                setPlayerHitting(true)
                setPlayerAttack(true)
                --animation = deepcopy(animations[3])
                PlaySound(sndSwing[rand(1, #sndSwing)], TransformToParentPoint(GetPlayerCameraTransform(), Vec(0, 0, -1)), 0.8)
                --debugTotalAnimationOffset(animation)
            end
        end

        if InputPressed("usetool") and InputDown("grab") then
            if animation == nil and not shieldToggled then
                parryCooldown.value = parryCooldown.default
                tt = defaultTransform()
                animation = deepcopy(animations[#animations - 1])
                setPlayerHitting(true)
                setPlayerAttack(true)
                --animation = deepcopy(animations[3])
                PlaySound(sndSwing[rand(1, #sndSwing)], TransformToParentPoint(GetPlayerCameraTransform(), Vec(0, 0, -1)), 0.8)
                --debugTotalAnimationOffset(animation)
                setPlayerThrust(true)
            end
        end

        if InputPressed("mmb") then
            if animation == nil then
                animation = deepcopy(animations[#animations])
                PlaySound(sndGb[rand(1, #sndGb)], TransformToParentPoint(GetPlayerCameraTransform(), Vec(0, 0, -1)), 0.8)
                --debugTotalAnimationOffset(animation)
            end
        end

        if parryCooldown.value <= 0 and (animation == nil or animation.timeLeft == nil or animation.state <= 2) and InputDown("grab") then
            animation = nil
            if getGuardBreak() then
                SetToolTransform(defaultTransform())
                setPlayerBlocking(false)
            else
                if shieldToggled then
                    SetBodyTransform(sbody, parryShieldTransform())
                    SetToolTransform(defaultTransform())
                else
                    SetToolTransform(parryTransform())
                end
                setPlayerBlocking(true)
            end
        else
            setPlayerBlocking(false)
            if animation ~= nil then
                handleAnimation(dt)
            else
                tt = defaultTransform()
            end
            SetToolTransform(tt, 0.3)
        end
        
        if (parryCooldown.value <= 0 and InputReleased("grab")) or getGuardBreak() then
            if getGuardBreak() and (not shieldToggled or stamina.value <= 0) then
                setGuardBreak(false)
                stun.value = stun.default
                PlaySound(sndGb[rand(1, #sndGb)], TransformToParentPoint(GetPlayerCameraTransform(), Vec(0, 0, -1)), 0.8)
                parryCooldown.value = parryCooldown.default
            elseif parryCooldown.value <= 0 and InputReleased("grab") then
                parryCooldown.value = parryCooldown.default
            end
        end

        if getStunInRegistry() then
            setStunInRegistry(false)
            incapacity.value = incapacity.default
            if animation ~= nil and animation.name == "thrust" then
                incapacity.value = incapacity.default --* 2
            end
        end

        local spawnTransform = TransformToParentTransform(GetPlayerCameraTransform(), Transform(Vec(0, 0, -3)))
        if InputPressed("c") then
            --spawnEnemy(spawnTransform.pos, 6)
        end
        
        if isSlicing(animation) then
            makeSlice()
        end
    end
    setIdentifierCount(identifierCount)
end

function fightUpdate(dt)
    --SetString("game.player.tool", toolname)

    if survival then
        updateSpawning(dt)
    end

    local newLastSpawn = getLastSpawn()
    if newLastSpawn ~= nil then
        if newLastSpawn ~= lastSpawn then
            --DebugPrint(newLastSpawn)
            enemies[newLastSpawn] = {
                id = newLastSpawn,
                alive = true,
                bodies = {},
                shapes = {}
            }
        end
        lastSpawn = newLastSpawn
    end
    if isToolInHand() then
        
    end
end

function fightDraw(dt)
    if isToolInHand() then
        if stun.value > 0 then
            local ratio = (stun.value / stun.default) * 0.6
            UiPush()
                UiColor(0, 0, 0, ratio)
                UiRect(UiWidth(), UiHeight())
            UiPop()
        end
        if shieldToggled and stamina.value < stamina.default then
            UiTranslate(UiCenter(), UiMiddle() * 1.5)
            local barSize = 400
            UiTranslate(-barSize / 2, 0)
            UiPush()
                UiColor(0, 0, 0, 0.8)
                UiRect(barSize, 2)
            UiPop()
            UiPush()
                UiColor(0.8, 0.6, 0.2, 0.8)
                if stamina.value <= stamina.damage then
                    UiColor(0.9, 0.25, 0.2, 0.8)
                end
                UiRect(barSize * (stamina.value / stamina.default), 2)
            UiPop()
        end
    end
end

function initSword()
    local w = {
        hands = 1,
        name = "Sword",
        id = SWORD,
        size = 2.0,
        damage = 40,
        width = 0.2
    }

    return w
end

function initAxe()
    local w = {
        hands = 1,
        name = "Axe",
        id = AXE,
        size = 1.6,
        damage = 70,
        width = 0.3
    }

    return w
end

function initSpear()
    local w = {
        hands = 1,
        name = "Spear",
        id = SPEAR,
        size = 2.5,
        damage = 30,
        width = 0.2
    }

    return w
end

function initHammer()
    local w = {
        hands = 1,
        name = "Hammer",
        id = HAMMER,
        size = 2.0,
        damage = 50,
        width = 0.3
    }

    return w
end

function isSlicing(a)
    if a ~= nil then
        return (animation.effect[animation.state] ~= nil and animation.effect[animation.state] == true)
    end
end

function isToolInHand()
    return GetString("game.player.tool") == toolname
end

function defaultShieldTransform()
    return TransformToParentTransform(GetPlayerCameraTransform(), Transform(Vec(-0.4, -1.25, -0.75), QuatEuler(0, 20, 0)))
end

function defaultTransform()
    return Transform(Vec(0.4, -0.8, -0.35), QuatEuler(-30, 0, 10))
end

function parryShieldTransform()
    return TransformToParentTransform(GetPlayerCameraTransform(), Transform(Vec(-0.2, -1.15, -0.9), QuatEuler(0, 5, 0)))
end

function parryTransform()
    return Transform(Vec(0.6, 0.1, -0.55), QuatEuler(0, 0, 85))
end

function stunTransform()
    return Transform(Vec(0.4, -0.8, -0.35), QuatEuler(-65, 0, -30))
end

function debugTotalAnimationOffset(a)
    --local t = defaultTransform()
    local pos = Vec()
    --local rx, ry, rz = GetQuatEuler(t.rot)
    local rot = Vec()

    for i=1, #a.pos do
        pos = VecAdd(pos, a.pos[i].pos)
        rot = VecAdd(rot, a.pos[i].rot)
    end
    DebugPrint(vecToString(pos) .. " " .. vecToString(rot))
end

function makeAnimation(time, v, q)
	local t = {
        time = 0,
        pos = Vec(),
        rot = Vec()
    }
	t.time = time
	t.pos = deepcopy(v)--VecScale(v, 1 / time)
	for i=1, 3 do
		t.rot[i] = q[i]--q[i] * (1 / time)
	end
	return deepcopy(t)
end

function getAnimation(a)
    return a.pos[a.state]
end

function spawnEnemy(pos, type)
    local dir = QuatLookAt(pos, GetPlayerCameraTransform().pos)
    type = type or 1
    local xml = "spawn/combine.xml"
    if type == 1 then
        xml = "spawn/combine.xml"
    elseif type == 2 then
        xml = "spawn/skeleton_short.xml"
    elseif type == 3 then
        xml = "spawn/skeleton_axe.xml"
    elseif type == 4 then
        xml = "spawn/skeleton_armor.xml"
    elseif type == 5 then
        xml = "spawn/skeleton_helmet.xml"
    elseif type == 6 then
        xml = "spawn/giant.xml"
    elseif type == 7 then
        xml = "spawn/giant_2.xml"
    elseif type == 8 then
        xml = "spawn/giant_axe.xml"
    elseif type == 9 then
        xml = "spawn/giant_2_axe.xml"
    elseif type == 10 then
        xml = "spawn/skeleton_armor2.xml"
    elseif type == 11 then
        xml = "spawn/skeleton_spear.xml"
    elseif type == 12 then
        xml = "spawn/skeleton_spear2.xml"
    elseif type == 13 then
        xml = "spawn/skeleton_spear3.xml"
    end
    local entities = Spawn(xml, Transform(pos, dir))
    local bodies = {}
    local shapes = {}
    for i=1, #entities do
        local e = entities[i]
        if GetEntityType(e) == "body" then
            bodies[#bodies + 1] = e
            SetTag(e, "identifier", tostring(identifierCount))
        elseif GetEntityType(e) == "shape" then
            shapes[#shapes + 1] = e
            SetTag(e, "identifier", tostring(identifierCount))
        end
    end

    local enemy = {
        alive = true,
        bodies = bodies,
        shapes = shapes,
        id = identifierCount
    }
    identifierCount = identifierCount + 1

    enemies[#enemies + 1] = enemy
end

function makeOffset(orig)
    orig = orig or Vec()
    local dist = 30
    local pos = Vec(0, 0, 0)
    pos[1] = math.random(1, 10) - 5
    pos[3] = math.random(1, 10) - 5
    pos = VecScale(VecNormalize(pos), dist)
    pos[2] = 1
    return VecAdd(pos, orig)
end

function handleAnimation(dt)

    local a = getAnimation(animation)
    local pos = tt.pos
    local rot = tt.rot
    local ratio = dt / a.time

    if animation.timeLeft == nil then
        animation.timeLeft = a.time
    end

    local posAdd = VecScale(a.pos, ratio)
    local rawRot = VecScale(a.rot, ratio)
    local rotAdd = QuatEuler(rawRot[1], rawRot[2], rawRot[3])

    tt = Transform(VecAdd(pos, posAdd), QuatRotateQuat(rot, rotAdd))

    animation.timeLeft = animation.timeLeft - dt
    if animation.timeLeft <= 0 then
        animation.state = animation.state + 1
        if animation.state > #animation.pos then
            animation = nil
        else
            local a2 = getAnimation(animation)
            animation.timeLeft = a2.time
        end
    end
end

function makeSlice()
    local count = 12
    local wSize = weapon.size
    if animation.name == "thrust" then  -- better range for thrust attack
        wSize = wSize * 1.5
    end
    local step = wSize / count
    local pos = {}
    local ct = GetPlayerCameraTransform()
    local finalTransform = TransformToParentTransform(ct, tt)
    local size = weapon.width
    local strength = 25

    local shapes = FindShapes("identifier", true)

    local weaponShapes = FindBodies("aim", true)
    local lHandShapes = FindBodies("lefthand", true)
    local rHandShapes = FindBodies("righthand", true)
    --DebugPrint(#weaponShapes .. " " .. #lHandShapes .. " " .. #rHandShapes)

    for i=1, count do
        local point = TransformToParentPoint(finalTransform, Vec(0, i * step, 0))
        if animation.name == "guardbreak" then
            point = TransformToParentPoint(finalTransform, Vec(0, -i * step, 0))
        end
        --MakeHole(point, size, 0, 0, false)
        for j=1, #weaponShapes do
            QueryRejectBody(weaponShapes[j])
        end
        for j=1, #lHandShapes do
            QueryRejectBody(lHandShapes[j])
        end
        for j=1, #rHandShapes do
            QueryRejectBody(rHandShapes[j])
        end
        local hitting, hitPos, normal, shape = QueryClosestPoint(point, size)
        for j=1, #shapes do
            if shape == shapes[j] then
                local identifier = GetTagValue(shape, "identifier")
                if not getHitInRegistry(identifier) and not getInvulnerabilityStatus(identifier) then
                    local vel = TransformToParentVec(ct, VecScale(VecNormalize(Vec(0, 1, -1)), strength))
                    setBumpDir(identifier, vel)
                    setBumpStatus(identifier, true)
                end
                if animation.name == "guardbreak" then
                    setGuardBreakOnEnemy(identifier, true)
                else
                    setHitInRegistry(identifier, true)
                    setShapeHit(identifier, shape)
                end
            end
        end
    end
end

function makeSparks()
    local ct = GetPlayerCameraTransform()
    if isToolInHand() then
        local count = 12
        local step = weapon.size / count
        local finalTransform = TransformToParentTransform(ct, tt)

        for i=1, count do
            local point = TransformToParentPoint(finalTransform, Vec(0, i * step, 0))
            if i >= count * 0.5 then
                if getPlayerBlocking() and shieldToggled then
                    PlaySound(sndWood[rand(1, #sndWood)], point, 0.8)
                    --stamina.value = stamina.value - stamina.damage
                else
                    sparks(point)
                    PointLight(point, 1, 0.99, 0.96, 0.4)
                    PlaySound(sndDing[rand(1, #sndDing)], point, 0.8)
                end
                break
            end
        end
    else
        PlaySound(sndDing[rand(1, #sndDing)], TransformToParentPoint(ct, Vec(0, 0, -5)), 0.8)
    end
end

function sparks(pos)
	local radius = 0.005
	local life = 0.45
	local count = 30
	local drag = 0.2
	local gravity = -2.5
	local alpha = 0.9
	
	--Set up the particle state
	ParticleReset()
	ParticleType("plain")
	ParticleRadius(radius)
	ParticleAlpha(alpha, alpha, "constant", 0.1 / life, 0.5)	-- Ramp up fast, ramp down after 50%
	ParticleGravity(gravity * randFloat(0.7, 1.3))				-- Slightly randomized gravity looks better
	ParticleDrag(drag)
	ParticleTile(4)
	ParticleCollide(1)
    ParticleEmissive(0.8, 0.2)
	
	--Emit particles
	for i=1, count do
        local red = 0.96 + randFloat(-0.04, 0.04)
        local green = 0.91 + randFloat(-0.04, 0.04)
        local blue = 0.50 + randFloat(-0.4, 0.4)
        ParticleColor(red, green, blue, 0.9, 0.9, 0.9)			-- Animating color towards white
		p = VecAdd(pos, randVec(2 * radius))
		local v = randVec(randFloat(1.5, 2.5))
        if v[2] < 0 then
            v[2] = -v[2]
        end
	
		--Randomize lifetime
		local l = randFloat(life * 0.8, life * 1.2)

		SpawnParticle(p, v, l)
	end
end



















