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

    spriteHeight = 1.2--0.8

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

        randPositions[#randPositions + 1] = Vec(col, row, tileHeight)
    end

    toggleOption = false

    playerTile = Vec()
    shadowBoxSize = 200

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
        positions = {}
        for i=1, #randPositions do
            positions[#positions + 1] = TransformToParentPoint(shapeT, randPositions[i])
    
            local offset = VecAdd(positions[#positions], Vec(0, -tileHeight, 0))
            local hit, dist = abRaycast(positions[#positions], offset)
            if hit then
                positions[#positions] = VecLerp(positions[#positions], offset, dist / tileHeight)
            end
        end

        local brigtness = GetEnvironmentProperty("sunBrightness")
        local maxRatio = 0.6
        local ratio = maxRatio * 0.5 + maxRatio * 0.5 * (brigtness / 6)

        local rx, ry, rz = GetQuatEuler(ct.rot)
        local camRot = QuatEuler(rx, ry, 0)
        local vertex = QuatRotateVec(camRot, Vec(0, spriteHeight, 0))

        local playTime = GetFloat("level.pirate.time")

        local newPositions = {}
        for i=1, #positions do
            local pos = VecCopy(positions[i])
            local value = math.cos(math.rad(playTime * 200 + pos[1] * 100)) / 100
            local vertexWave = VecScale(vertex, 1 + value)

            local offset = VecAdd(pos, vertexWave)

            local sm, sr, sg, sb = GetShapeMaterialAtPosition(shape, pos)
            
            if sm ~= "" and sg > sr and sg > sb then
                drawSpriteLine(pos, offset, sprite, 2.5, sr * ratio, sg * ratio, sb * ratio, alpha, true)

                newPositions[#newPositions + 1] = randPositions[i]
            end
        end
        randPositions = newPositions
    end
end

function getPlayerTileInRegistry()
    local x = GetInt("level.pirate.playerTile.x")
    local z = GetInt("level.pirate.playerTile.z")
    playerTile = Vec(x, 0, z)
end
















