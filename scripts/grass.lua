#include "../snippets.lua"

function init()
    count = 45
    sprite = LoadSprite("MOD/img/grass.png")
    shape = FindShape("")
    shapeT = GetShapeWorldTransform(shape)
    maxDist = 30

    spriteHeight = 0.8

    tileSize = 5
    tileHeight = 3

    tileHeight = tileHeight - 0.1

    positions = {}
    for i=1, count do
        positions[#positions + 1] = TransformToParentPoint(shapeT, Vec(math.random() * tileSize, math.random() * tileSize, tileHeight))
        local offset = VecAdd(positions[#positions], Vec(0, -tileHeight, 0))
        local hit, dist = abRaycast(positions[#positions], offset)
        if hit then
            positions[#positions] = VecLerp(positions[#positions], offset, dist / tileHeight)
        end
    end
end

function tick(dt)
    local dist = VecLength(VecSub(GetCameraTransform().pos, shapeT.pos))
    local alpha = math.min((maxDist - dist) / 5, 1)
    if dist <= maxDist then
        local newPositions = {}

        local brigtness = GetEnvironmentProperty("sunBrightness")
        local ratio = 0.5 + 0.5 * (brigtness / 6)

        for i=1, #positions do
            local offset = VecAdd(positions[i], Vec(0, spriteHeight, 0))
            local sm, sr, sg, sb = GetShapeMaterialAtPosition(shape, positions[i])
            local svm = GetShapeMaterialAtPosition(shape, offset)
            if sm ~= "" and svm == "" and sg > sr and sg > sb then
                drawSpriteLine(positions[i], offset, sprite, 2.5, sr * ratio, sg * ratio, sb * ratio, alpha, true)
                newPositions[#newPositions + 1] = positions[i]
            end
        end
        positions = newPositions
    end
end