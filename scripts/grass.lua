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

    positions = {}
    local stepValue = tileSize * tileSize / count
    local randOffset = 0.25
    for i=1, count do
        --positions[#positions + 1] = TransformToParentPoint(shapeT, Vec(math.random() * tileSize, math.random() * tileSize, tileHeight))
        local value = i * stepValue + randFloat(-0.5, 0.5) * stepValue

        local col = (value % tileSize)
        local row = (value - col) / tileSize + 0.5 * stepValue + randFloat(-randOffset, randOffset)
        col = col + randFloat(-randOffset, randOffset)

        positions[#positions + 1] = TransformToParentPoint(shapeT, Vec(col, row, tileHeight))

        local offset = VecAdd(positions[#positions], Vec(0, -tileHeight, 0))
        local hit, dist = abRaycast(positions[#positions], offset)
        if hit then
            positions[#positions] = VecLerp(positions[#positions], offset, dist / tileHeight)
        end
    end

    toggleOption = false

end

function tick(dt)

    if InputPressed("v") then
        toggleOption = not toggleOption
    end

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
        local newPositions = {}

        local brigtness = GetEnvironmentProperty("sunBrightness")
        local ratio = 0.5 + 0.5 * (brigtness / 6)

        local rx, ry, rz = GetQuatEuler(ct.rot)
        local camRot = QuatEuler(rx, ry, 0)
        local vertex = QuatRotateVec(camRot, Vec(0, spriteHeight, 0))

        local playTime = GetFloat("level.pirate.time")

        for i=1, #positions do
            local pos = VecCopy(positions[i])
            local value = math.cos(math.rad(playTime * 200 + pos[1] * 100)) / 100
            local vertexWave = VecScale(vertex, 1 + value)

            local offset = VecAdd(pos, vertexWave)

            local sm, sr, sg, sb = GetShapeMaterialAtPosition(shape, pos)
            
            if sm ~= "" and sg > sr and sg > sb then
                drawSpriteLine(pos, offset, sprite, 2.5, sr * ratio, sg * ratio, sb * ratio, alpha, true)

                newPositions[#newPositions + 1] = pos
            end
        end
        positions = newPositions
    end
end