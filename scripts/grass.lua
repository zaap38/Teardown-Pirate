#include "../snippets.lua"

function init()
    count = 45--90
    sprite = LoadSprite("MOD/img/grass.png")
    shape = FindShape("")
    shapeT = GetShapeWorldTransform(shape)

    maxDist = 30
    fov = math.rad(GetInt("options.gfx.fov"))
    maxFov = math.deg(2 * math.atan(math.tan(fov / 2) * (16 / 9))) + 20

    maxFov = maxFov / 2
    useFov = true

    spriteHeight = 1.2

    tileSize = 5
    tileHeight = 3

    tileHeight = tileHeight - 0.1
    local stepValue = tileSize * tileSize / count
    local randOffset = 0.25

    randPositions = {}
    for i=1, count do
        local value = i * stepValue + randFloat(-0.5, 0.5) * stepValue

        local col = (value % tileSize)
        local row = (value - col) / tileSize + 0.5 * stepValue + randFloat(-randOffset, randOffset)
        col = col + randFloat(-randOffset, randOffset)

        randPositions[#randPositions + 1] = {
            pos = Vec(col, row, tileHeight),
            truePos = Vec(),
            shadow = 0
        }
        local rPos = randPositions[#randPositions]

        rPos.truePos = TransformToParentPoint(shapeT, rPos.pos)
        local offset = VecAdd(rPos.truePos, Vec(0, -tileHeight, 0))
        local hit, dist = abRaycast(rPos.truePos, offset)
        if hit then
            rPos.pos = TransformToLocalPoint(shapeT, VecLerp(rPos.truePos, offset, dist / tileHeight))
        end
        rPos.truePos = TransformToParentPoint(shapeT, rPos.pos)
    end

    toggleOption = false

    playerTile = Vec()
    shadowBoxSize = 200

    grassToUpdateIndex = 0

    rndVectors = {}
    local raycastCount = 20
    local raycastLength = 15
    for i=1, raycastCount do
        rndVectors[#rndVectors + 1] = VecScale(VecNormalize(Vec(rand(20) - 10, rand(40), rand(20) - 10)), raycastLength)
    end

end

function tick(dt)

    shapeT = GetShapeWorldTransform(shape)

    local dist = VecLength(VecSub(GetCameraTransform().pos, shapeT.pos))
    local alpha = math.min((maxDist - dist) / 5, 1)

    local angle = 0
    local ct = GetCameraTransform()

    if useFov then
        local playerDir = TransformToParentVec(ct, fwd())
        playerDir[2] = 0
        toGrass = VecSub(shapeT.pos, ct.pos)
        toGrass[2] = 0
        angle = vecAngle(playerDir, toGrass)
    end

    if dist <= maxDist and (angle <= maxFov or dist <= 10) then

        
        grassToUpdateIndex = grassToUpdateIndex + 1
        if grassToUpdateIndex > #randPositions then
            grassToUpdateIndex = 1
        end
        if #randPositions > 0 then
            updateThisGrass(randPositions[grassToUpdateIndex])
        else
            return
        end

        local brigtness = GetEnvironmentProperty("sunBrightness")
        local maxRatio = 1.0
        local ratioDefault = maxRatio * 0.5 + maxRatio * 0.5 * (brigtness / 6)

        local rx, ry, rz = GetQuatEuler(ct.rot)
        local camRot = QuatEuler(rx, ry, 0)
        local vertex = QuatRotateVec(camRot, Vec(0, spriteHeight, 0))

        local playTime = GetFloat("level.pirate.time")

        for i=1, #randPositions do
            local ratio = ratioDefault
            local rPos = randPositions[i]
            local pos = rPos.truePos
            local value = math.cos(math.rad(playTime * 200 + pos[1] * 100)) / 100
            local vertexWave = VecScale(vertex, 1 + value)

            local offset = VecAdd(pos, vertexWave)

            local sm, sr, sg, sb = GetShapeMaterialAtPosition(shape, pos)
            
            if sm ~= "" and sg > sr and sg > sb then
                ratio = ratio * (1 - rPos.shadow)
                drawSpriteLine(pos, offset, sprite, 2.5, sr * ratio, sg * ratio, sb * ratio, alpha, true)
            end
        end
    end
end

function getPlayerTileInRegistry()
    local x = GetInt("level.pirate.playerTile.x")
    local z = GetInt("level.pirate.playerTile.z")
    playerTile = Vec(x, 0, z)
end

function updateThisGrass(grass)
    grass.truePos = TransformToParentPoint(shapeT, grass.pos)
    local success = 0
    for i=1, #rndVectors do
        local hit = QueryRaycast(VecAdd(grass.truePos, Vec(0, 0.5, 0)), VecNormalize(rndVectors[i]), VecLength(rndVectors[i]))
        if hit then
            success = success + 1
        end
    end
    grass.shadow = (success / #rndVectors) * 0.7
end
















