#include "../snippets.lua"


function generationInit()
    tiles = {}
    tilesCoordToIndex = {}
    islands = {}
    maxIslandSize = 40
    islandTileSize = 5
    islandTileHeight = 3

    enemyCount = 0
    maxEnemyCount = 4

    renderDist = 3.2
    renderedCount = 0
    renderedLimit = 3

    daytime = {
        value = 150,
        max = 300
    }

    debug = {
        noSpawn = false,  -- disable enemy and island spawning
        noEnemy = true,  -- disable enemy spawning
        noIsland = false,  -- disable island spawning
        noDaytime = true,  -- disable daytime cycle
        islandsCount = nil  -- fix the count of islands spawned to this value. No count if nil.
    }

    local debugConfigStr = ""
    for k, v in pairs(debug) do
        if v then
            debugConfigStr = debugConfigStr .. k .. " ; "
        end
    end
    if debugConfigStr ~= "" then
        DebugWatch("Debug Config", debugConfigStr)
    end
    
    skipRendering = false

    treasures = {}

    maxRenderIncrement = 1

    bottom = -2
    transitionHeight = 3

    tileSize = 200

    neighborhood = 3

    previousPlayerCoord = Vec(-1000, -1000, -1000)

    biomeType = {
        desertic = 1,
        village = 2,
        harbour = 3,
        spawn = 4
    }

    propList = {}
    propList[#propList + 1] = {
        name = "tree",
        count = 2,
        probability = 70,
        condition = {
            heightMin = 1
        }
    }
    propList[#propList + 1] = {
        name = "bush",
        count = 4,
        probability = 40,
        condition = {
            heightMin = transitionHeight
        }
    }
    propList[#propList + 1] = {
        name = "house",
        count = 1,
        probability = 25,
        condition = {
            floor = {"flat", "carpet"},
            biome = {biomeType.village, biomeType.harbour},
            jump = true
        }
    }
    propList[#propList + 1] = {
        name = "barrel",
        count = 2,
        probability = 5,
        condition = {
            floor = {"flat", "carpet"}
        }
    }
    propList[#propList + 1] = {
        name = "bridge",
        count = 1,
        probability = 10,
        condition = {
            limit = 2,
            heightMin = 0,
            heightMax = 0
        }
    }

    markerPropList = {}
    markerPropList[#markerPropList + 1] = {
        name = "cross",
        count = 1
    }

    displayMap = false

    mapSprite = {
        tree = "MOD/img/tree.png",
        treasureOn = "MOD/img/treasureOn.png",
        treasureOff = "MOD/img/treasureOff.png",
        house = "MOD/img/house.png",
        bush = "MOD/img/bush.png",
        bridge = "MOD/img/bridge.png",
        barrel = "MOD/img/barrel.png"
    }

    names = {
        part1 = {
            "Banana",
            "Roja",
            "Green",
            "Skull",
            "Wreck",
            "Shark",
            "Captain's",
            "Mermaids'",
            "Mysterious",
            "Forgotten",
            "Hurricane",
            "Corsair's",
            "Sunny",
            "Salt",
            "Smugglers'",
            "Shadow"
        },
        part2 = {
            "Island",
            "Bay",
            "Cove",
            "Beach",
            "Cliff",
            "Lagoon",
            "Atoll",
            "Shelter",
            "Lair",
            "Reef",
            "Sanctuary",
            "Grotto",
            "Haven",
            "Bight"
        }
    }

    waveCooldown = {
        value = 0,
        default = 1
    }

    wavesData = {
        cooldown = {
            value = 0,
            default = 0.8
        },
        density = 1.8,
        speed = 6,
        length = 10,
        toProcess = {},
        snd = {
            LoadSound("MOD/snd/wave_1.ogg"),
            LoadSound("MOD/snd/wave_2.ogg"),
            LoadSound("MOD/snd/wave_3.ogg")
        }
    }
end

function generationTick(dt)

    if enteringChunk() then
        addMissingTiles()
    end
    --DebugWatch("#tiles", #tiles)
    DebugWatch("#islands", #islands)
    renderedCount = 0
    local bodyCount = 0
    for i=1, #islands do
        if #islands[i].bodies > 0 then
            bodyCount = bodyCount + #islands[i].bodies
            renderedCount = renderedCount + 1
        end
    end
    DebugWatch("Body count", bodyCount)
    DebugWatch("Rendered", renderedCount .. "/" .. renderedLimit)

    enemyCount = 0
    local enemies = FindVehicles("enemy", true)
    for i=1, #enemies do
        if GetVehicleHealth(enemies[i]) > 0.5 then
            enemyCount = enemyCount + 1
        end
    end

    DebugWatch("#Enemies", enemyCount)
    local x, z = getTileCoord(GetPlayerTransform().pos)
    local tile = tilesCoordToIndex[x][z]
    if tile.island ~= nil then
        DebugWatch("Island name", tile.island.name)
    end
    DebugWatch("Player Tile", x .. " " .. z)
    --DebugWatch("Map", displayMap)
    for i=1, #tiles do
        local c = 0
        local wp = toWorldPos(tiles[i].pos)
        local top = deepcopy(wp)
        top = VecAdd(top, Vec(tileSize, 5, tileSize))
        if x == tiles[i].pos[1] and z == tiles[i].pos[3] then
            c = 1
        end
        --drawAaBbBox(wp, top, true, c, 1 - c)
    end
    updateIslands()
    if InputPressed("c") then
        displayMap = not displayMap
    end
end

function generationUpdate(dt)
    updateDaytime(dt)
    updateSpawnCooldown(dt)
    updateWaves(dt)
    processWaves(dt)
end

function generationDraw(dt)
    if displayMap then
        local x, z = getPlayerTile()
        local island = tilesCoordToIndex[x][z].island
        if island ~= nil then
            drawIslandMap(island)
            drawCompass()
        end
    end
end

function updateWaves(dt)
    wavesData.cooldown.value = wavesData.cooldown.value - dt
    if wavesData.cooldown.value <= 0 then
        wavesData.cooldown.value = wavesData.cooldown.default
        waves()
    end
end

function updateDaytime(dt)
    daytime.value = daytime.value + dt
    if daytime.value > daytime.max then
        daytime.value = 0
    end
    if not debug.noDaytime then
        dynamicTemplate(daytime.value / daytime.max)
    end
end

function dayTemplate()
    SetEnvironmentProperty("skybox", "day.dds")
    SetEnvironmentProperty("sunBrightness", "6")
    SetEnvironmentProperty("sunColorTint", "1", "0.8", "0.6")
    SetEnvironmentProperty("fogColor", "0.9", "0.9", "0.9")
    SetEnvironmentProperty("skyboxtint", "1", "1", "1")
end

function nightTemplate()
    SetEnvironmentProperty("skybox", "night_clear.dds")
    SetEnvironmentProperty("sunBrightness", "0")
    SetEnvironmentProperty("sunColorTint", "0", "0", "0")
    SetEnvironmentProperty("fogColor", "0.2", "0.2", "0.2")
    SetEnvironmentProperty("skyboxtint", "0.2", "0.2", "0.2")
end

function dynamicTemplate(ratio)

    ratio = 1 - math.abs(0.5 - ratio) * 2

    ratio = ratio * ratio

    local tint = {
        r = 0.9 * ratio,
        g = 0.9 * ratio,
        b = 0.9 * ratio,
    }

    local sunTint = {
        r = 1 * ratio,
        g = 0.8 * ratio,
        b = 0.6 * ratio,
    }

    SetEnvironmentProperty("sunBrightness", tostring(6 * ratio))
    SetEnvironmentProperty("skyboxbrightness", tostring(ratio))
    SetEnvironmentProperty("sunColorTint", tostring(sunTint.r), tostring(sunTint.g), tostring(sunTint.b))
    SetEnvironmentProperty("fogColor", tostring(tint.r), tostring(tint.g), tostring(tint.b))
    SetEnvironmentProperty("skyboxtint", tostring(tint.r), tostring(tint.g), tostring(tint.b))
end

function getNeighbors(origin, radius, selfTile)
    selfTile = selfTile or false
    local n = {}

    local half = math.floor(radius / 2) + 1

    for i=-half, half do
        for j=-half, half do
            local offset = Vec(i, 0, j)
            if selfTile or i ~= origin[1] or j ~= origin[3] then
                n[#n + 1] = offset
            end
        end
    end

    return n
end

function enteringChunk()
    local pos = coord(getTileCoord(GetPlayerTransform().pos))
    if VecLength(VecSub(pos, previousPlayerCoord)) ~= 0 then
        previousPlayerCoord = pos
        return true
    end
    return false
end

function addMissingTiles()
    if playerInBorderTile() then
        local pos = GetPlayerTransform().pos
        local x, z = getTileCoord(pos)
        spawnAdjacent(coord(x, z))
    end
end

function toWorldPos(pos)
    return VecScale(pos, tileSize)
end

function spawnAdjacent(pos)
    local n = getNeighbors(pos, neighborhood, true)
    for i=1, #n do
        local offset = VecAdd(pos, n[i])
        if not tileExist(offset) then
            local b = 0
            local randVal = rand(1, 100)
            local spawnIsland = (rand(1, 100) <= 7) -- probability to spawn an island or a spawn

            if debug.islandsCount ~= nil then
                if #islands < debug.islandsCount then
                    spawnIsland = true
                else
                    spawnIsland = false
                end
            end

            if spawnIsland then
                if randVal <= 50 then
                    b = biomeType.desertic
                elseif randVal <= 100 then
                    b = biomeType.village
                end
            elseif rand(1, 100) <= 10 then
                b = biomeType.spawn
            end
            addTile(offset, b, spawnIsland)
        end
    end
end

function drawIslandMap(island)
    local top = island.topology

    local width = UiWidth()
    local height = UiHeight()

    local islandWidth = island.bounds.bb[1] - island.bounds.aa[1]
    local islandHeight = island.bounds.bb[3] - island.bounds.aa[3]
    local islandAlt = island.maxHeight

    size = 15

    local base = 0.3

    UiPush()
        UiImageBox("MOD/img/background_map.png", 1920, 1080, 0, 0)
        local offset = {
            x = 570,
            y = 285
        }
        UiTranslate(offset.x, offset.y)
        UiColor(0.5, 0.5, 0.8)

        for i=1, #island.tiles do
            UiPush()
                local tile = island.tiles[i]
                local x = tile.coord[1]
                local y = tile.coord[3]
                UiTranslate(x * size, y * size)
                local celHeight = tile.height
                if celHeight >= 0 then
                    local ratio = celHeight / island.maxHeight
                    if tile.material == "sand" then
                        UiColor(base + 0.2 + ratio * 0.5, base + 0.2 + ratio * 0.5, base * ratio)
                    elseif tile.material == "transition" or tile.material == "transition2" then
                        UiColor(base * ratio * 0.5 + (base + 0.2 + ratio * 0.5) * 0.5,
                                (base + 0.5 * ratio) * 0.5 + (base + 0.2 + ratio * 0.5) * 0.5,
                                base * ratio * 0.5 + (base * ratio) * 0.5)
                    else
                        UiColor(base * ratio, base + 0.5 * ratio, base * ratio)
                    end
                    UiRect(size, size)
                end
            UiPop()
        end

        for line=0, maxIslandSize do
            for i=1, #island.tiles do
                if island.tiles[i].coord[3] == line then
                    UiPush()
                        local tile = island.tiles[i]
                        local x = tile.coord[1]
                        local y = tile.coord[3]
                        local image = ""
                        UiTranslate(x * size, y * size)
                        if tile.height >= 0 then
                            if tile.treasure == 2 then
                                image = mapSprite.treasureOn
                            elseif tile.treasure == 1 then
                                image = mapSprite.treasureOff
                            elseif tile.prop then
                                image = mapSprite[tile.propType]
                            end
                            if image ~= "" then
                                UiPush()
                                    UiColor(1, 1, 1, 1)
                                    --local propPos = VecCopy(tile.propLocalTransform.pos)
                                    --propPos = QuatRotateVec(tile.transform.rot, propPos)
                                    --UiTranslate(propPos[1] * size, propPos[3] * size)
                                    UiImageBox(image, size, size, 0, 0)
                                UiPop()
                            end
                        end
                    UiPop()
                end
            end
        end
        
        UiPush()
            UiTranslate(20, 50)
            UiTranslate(-100, -100)
            UiFont("font/skulls-and-crossbones-font/Skullsandcrossbones-RppKM.ttf", 48)
            UiPush()
                UiColor(0, 0, 0, 1)
                UiTranslate(-2, 2)
                UiText(island.name)
            UiPop()
            UiColor(1, 1, 1, 1)
            UiText(island.name)
        UiPop()
    UiPop()
end

function updateSpawnCooldown(dt)
    for i=1, #tiles do
        local tile = tiles[i]
        if tile.biome == biomeType.spawn then
            tile.spawnCooldown.value = tile.spawnCooldown.value - dt
            if tile.spawnCooldown.value <= 0 and VecLength(VecSub(toWorldPos(tile.pos), GetPlayerTransform().pos)) <= 4 * tileSize and enemyCount < maxEnemyCount then
                tile.spawnCooldown.value = tile.spawnCooldown.default
                if not (debug.noSpawn or debug.noEnemy) then
                    spawnEnemyBoat(tile)
                end
            end
        end
    end
end

function processWaves(dt)
    local waves = wavesData.toProcess
    local toKeep = {}
    for i=1, #waves do
        local w = waves[i]
        w.timeToDie = w.timeToDie - dt
        if w.timeToDie <= 0 then
            PlaySound(wavesData.snd[rand(1, #wavesData.snd)], w.hitPos, 0.6)
            makeWave(w.hitPos, VecScale(w.dir, -1), true)
        else
            toKeep[#toKeep + 1] = w
        end
    end
    wavesData.toProcess = toKeep
end

function waves()
    local x, y = getPlayerTile()

    local island = tilesCoordToIndex[x][y].island
    
    if island ~= nil then
        local vertexTarget = island.vertex[rand(1, #island.vertex)]
        local waveTarget = VecAdd(toWorldPos(coord(x, y)), VecScale(coord(vertexTarget.x, vertexTarget.y), islandTileSize))
        local offset = randVec(1)
        offset[2] = 0
        offset = vecResize(offset, vertexTarget.height * 0.5 * islandTileSize + 8)
        local offsetPos = VecAdd(waveTarget, offset)
        local dir = VecNormalize(VecSub(waveTarget, offsetPos))
        makeWave(offsetPos, dir)
    end
end

function makeWave(pos, dir, reflux)
    reflux = reflux or false
    local waveLine = QuatRotateVec(QuatEuler(0, 90, 0), dir)
    local waveSpeed = wavesData.speed
    local radius = 0.35
	local life = 20
    local waveLength = wavesData.length
	local count = waveLength * wavesData.density / radius
	local alpha = 0.3
	
	--Set up the particle state
	ParticleReset()
	ParticleType("plain")
	ParticleRadius(radius)
	ParticleAlpha(0, alpha)
	ParticleGravity(0)
    local drag = 0.01
    if reflux then
        drag = 0.1
        waveSpeed = waveSpeed / 2
        ParticleAlpha(alpha, 0)
        life = 5
    end
	ParticleDrag(drag)
	ParticleTile(0)
    ParticleEmissive(0.8, 0.8)

    if not reflux then
        local maxDist = tileSize
        local hit, dist = QueryRaycast(pos, dir, maxDist)
        if hit then
            life = dist / waveSpeed
        else
            return
        end

        local hitPos = VecAdd(pos, VecScale(dir, dist))
        wavesData.toProcess[#wavesData.toProcess + 1] = {
            hitPos = hitPos,
            timeToDie = life,
            dir = dir
        }
    end
	
	--Emit particles
	for i=1, count do
        local red = 0.8
        local green = 0.8
        local blue = 0.85
        ParticleColor(red, green, blue, 0.6, 0.6, 0.75)
		local p = VecAdd(pos, VecScale(waveLine, waveLength * i / count - waveLength / 2))
        p = VecAdd(p, VecScale(dir, math.cos(i * 0.2) * 0.2))

        local vel = VecScale(dir, waveSpeed)

		SpawnParticle(p, vel, life)
	end
end

function drawCompass()
    UiPush()
        UiTranslate(1350, 650)
        local length = 150
        local _, angle = GetQuatEuler(GetCameraTransform().rot)
        angle = math.rad(angle + -90)
        local x = math.cos(angle) * length
        local y = math.sin(angle) * length
        drawUiLine(0, 0, x, y, 5, 0.7, 0.2, 0.2)
        UiTranslate(-2, -2)
        UiColor(0.5, 0.2, 0.2)
        UiRect(9, 9)
    UiPop()
end

function drawUiLine(x1, y1, x2, y2, width, r, g, b, a)
    width = width or 1
    r = r or 1
    g = g or 1
    b = b or 1
    a = a or 1
    
    local dist = math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2))
    local points = math.floor(dist / width)
    for i=1, points do
        UiPush()
            UiColor(r, g, b, a)
            local ratio = i / points
            UiTranslate(x1 * (1 - ratio) + x2 * ratio, y1 * (1 - ratio) + y2 * ratio)
            UiRect(width, width)
        UiPop()
    end
end

function addTile(pos, biome, spawnIsland)
    spawnIsland = spawnIsland or false
    biome = biome or 0
    local flatPos = deepcopy(pos)
    flatPos[2] = 0
    tiles[#tiles + 1] = {
        biome = biome,
        handle = 0,
        pos = flatPos,
        island = nil,
        spawnCooldown = {
            value = 0,
            default = 300
        }
    }

    local tile = tiles[#tiles]
    if tilesCoordToIndex[tile.pos[1]] == nil then
        tilesCoordToIndex[tile.pos[1]] = {}
    end
    tilesCoordToIndex[tile.pos[1]][tile.pos[3]] = tile

    local spawnPos = VecAdd(VecScale(tile.pos, tileSize), Vec(tileSize / 2, 0, tileSize / 2))
    local entities = Spawn("<water pos='0 0 0' color='0 0.31 0.4 0.3' size='" .. tileSize .. " " .. tileSize  .. " " .. tileSize  .. "'/>", Transform(spawnPos))
    tile.handle = getSpawnedEntities(entities, "water")[1]

    if spawnIsland and not (debug.noSpawn or debug.noIsland) then
        tile.island = makeIsland(tile)
    end
end

function getIslandTile(island, x, y)
    if island.coordToTiles[x] ~= nil and island.coordToTiles[x][y] ~= nil then
        return island.coordToTiles[x][y]
    end
    return nil
end

function spawnEnemyBoat(tile)
    local spawnPos = toWorldPos(tile.pos)
    local pt = GetPlayerTransform()
    pt.pos[2] = 0
    spawnPos[2] = 0
    local rotQuat = QuatLookAt(spawnPos, pt.pos)
    spawnPos[2] = -10
    Spawn("MOD/prefabs/vehicles/pirate_ship_1/shipwreck.xml", Transform(spawnPos, rotQuat))
end

function pickProp(floorType, height, counts, biome, pos)
    local choices = {}
    for i=1, #propList do
        local p = propList[i]
        if p.condition.limit ~= nil and counts[p.name] >= p.condition.limit then

        elseif p.condition.heightMin ~= nil and height < p.condition.heightMin then

        elseif p.condition.heightMax ~= nil and height > p.condition.heightMax then

        elseif p.condition.floor ~= nil and not exist(floorType, p.condition.floor) then

        elseif p.condition.biome ~= nil and not exist(biome, p.condition.biome) then

        elseif p.condition.jump ~= nil and not ((pos[1] % 2) == 0 and (pos[3] % 2) == 0) then

        else
            choices[#choices + 1] = deepcopy(p)
        end
    end

    if #choices == 0 then
        return propList[1]
    elseif #choices == 1 then
        choices[#choices + 1] = {
            name = "nothing",
            probability = 100 - choices[1].probability
        }
    end

    local sum = 0
    for i=1, #choices do
        sum = sum + choices[i].probability
    end

    local randValue = rand(0, sum)
    for i=1, #choices do
        randValue = randValue - choices[i].probability
        if randValue <= 0 then
            return choices[i]
        end
    end
end

function makeIsland(tile)
    local island = {
        biome = tile.biome,
        name = "island_name",
        topology = {},
        xml = "",
        vertex = {},
        bodies = {},
        maxHeight = 0,
        pos = tile.pos,
        renderIndex = 1,
        tiles = {},
        coordToTiles = {},
        treasure = {
            exist = false,
            x = 0,
            y = 0
        },
        bounds = {
            aa = Vec(10000, 0, 10000),
            bb = Vec(-10000, 0, -10000)
        },
        renderState = 0--0 -- 0: no render, 1: sprite, 2: -, 3: detailed tiles
    }
    local pos = Vec()
    local x, z = getPlayerTile()
    pos[1] = x
    pos[3] = z
    local dist = VecLength(VecSub(pos, island.pos))
    if dist <= renderDist then
        island.renderState = 3
    end

    island.name = names.part1[rand(1, #names.part1)] .. " " .. names.part2[rand(1, #names.part2)]

    local propDensity = randFloat(0.5, 1)

    island.topology, island.maxHeight, island.vertex = makeLinearTopology()

    local top = island.topology

    local counts = {}
    for i=1, #propList do
        counts[propList[i].name] = 0
    end

    for i=1, maxIslandSize do
        for j=1, maxIslandSize do
            local celHeight = top[i][j]
            for k=math.max(celHeight, bottom), celHeight do

                local spawnPos = VecScale(Vec(i, k, j), islandTileSize)
                spawnPos[2] = k * islandTileHeight
                spawnPos = VecAdd(spawnPos, toWorldPos(tile.pos))

                local blockname = "flat"
                local rot = 0
                local size = islandTileHeight
                local material = "sand"
                local center = Vec(rand(1, maxIslandSize), 0, rand(1, maxIslandSize))

                blockname, rot, material = selectBlockType(top, i, j)

                if k == celHeight and (celHeight > bottom or celHeight == bottom and blockname ~= "flat") then
                    
                    island.bounds.aa[1] = math.min(island.bounds.aa[1], i)
                    island.bounds.aa[3] = math.min(island.bounds.aa[3], j)
                    island.bounds.bb[1] = math.max(island.bounds.bb[1], i)
                    island.bounds.bb[3] = math.max(island.bounds.bb[3], j)

                    island.tiles[#island.tiles + 1] = {
                        transform = Transform(spawnPos, QuatEuler(0, rot, 0)),
                        blockname = blockname,
                        material = material,
                        height = celHeight,
                        prop = (rand(1, 100) <= propDensity * 100),
                        propName = "",
                        propType = "",
                        propLocalTransform = Transform(),
                        treasure = 0,
                        coord = Vec(i, 0, j)
                    }
                    local tile = island.tiles[#island.tiles]

                    if island.coordToTiles[i] == nil then
                        island.coordToTiles[i] = {} 
                    end
                    island.coordToTiles[i][j] = tile

                    if blockname == "" or blockname == "carpet" or celHeight <= -1 then
                        tile.prop = false

                    elseif tile.prop then
                        --[[local rnd = rand(1, #propList)
                        local propType = propList[rnd]

                        local propName = deepcopy(propType.name)

                        if (propType.name == "house" and (not (blockname == "flat" or blockname == "carpet") or not ((i % 2) == 0 and (j % 2) == 0))) or island.biome ~= biomeType.village then
                            propName = "tree"
                        end

                        if tile.height == 0 then
                            propName = "bridge"
                        end]]

                        local propType = pickProp(blockname, tile.height, counts, island.biome, Vec(i, 0, j))
                        propName = propType.name

                        if propName == "nothing" then
                            tile.prop = false
                        end

                        if tile.prop then
                            counts[propName] = counts[propName] + 1

                            local rot
                            local offset = Vec()
                            if propName == "tree" then
                                rot = QuatEuler(0, rand(0, 360), 0)
                                offset = Vec(randFloat(-1, 1), randFloat(-4.5, -1.5), randFloat(-1, 1))

                            elseif propName == "bush" then
                                rot = QuatEuler(0, rand(0, 360), 0)
                                offset = Vec(randFloat(-0.5, 0.5), randFloat(0, 0.5), randFloat(-0.5, 0.5))

                            elseif propName == "barrel" then
                                rot = QuatEuler(0, rand(0, 360), 0)
                                offset = Vec(randFloat(-0.5, 0.5), islandTileHeight, randFloat(-0.5, 0.5))

                            elseif propName == "house" then
                                local tilePos = Vec(i, 0, j)
                                local closestVertexPos = Vec(island.vertex[1].x, 0, island.vertex[1].y)
                                for i=1, #island.vertex do
                                    local vPos = Vec(island.vertex[i].x, 0, island.vertex[i].y)
                                    if VecLength(VecSub(tilePos, vPos)) < VecLength(VecSub(tilePos, closestVertexPos)) then
                                        closestVertexPos = vPos
                                    end
                                end
                                rot = QuatRotateQuat(QuatLookAt(tilePos, closestVertexPos), QuatEuler(0, 180, 0))

                            elseif propName == "bridge" then
                                if blockname == "corner_concav_1" or blockname == "corner_concav_2" then
                                    rot = QuatEuler(0, -45, 0)
                                end
                            end

                            tile.propName = propName .. "_" .. rand(1, propType.count)
                            tile.propType = propName
                            local half = (0.75 * islandTileSize) / 2
                            tile.propLocalTransform = Transform(offset, rot)
                            tile.prop = true
                        end

                    elseif not island.treasure.exist and rand(1, 1000) <= 13 and tile.height > 0 then
                        island.treasure.x = i
                        island.treasure.y = j
                        tile.treasure = 2
                    end
                end
            end
        end
    end

    islands[#islands + 1] = island

    return island
end

function playerInBorderTile()
    local pos = GetPlayerTransform().pos
    local x, z = getTileCoord(pos)
    
    local origin = coord(x, z)

    if not tileExist(origin) then
        return true
    end

    local n = getNeighbors(origin, neighborhood)

    for i=1, #n do
        local offset = VecAdd(n[i], origin)
        if not tileExist(offset) then
            return true
        end
    end
    
    return false
end

function getPlayerTile()
    return getTileCoord(GetPlayerTransform().pos)
end

function coord(x, z)
    return Vec(x, 0, z)
end

function tileExist(x, z)
    if z == nil then
        local v = deepcopy(x)
        x = v[1]
        z = v[3]
    end
    return tilesCoordToIndex[x] ~= nil and tilesCoordToIndex[x][z] ~= nil
end

function getTileCoord(pos)
    local x, z
    x = math.floor(pos[1] / tileSize)
    z = math.floor(pos[3] / tileSize)
    return x, z
end

function makeLinearTopology()
    local top = {}

    for i=1, maxIslandSize do
        top[i] = {}
        for j=1, maxIslandSize do
            top[i][j] = bottom
        end
    end

    local bestHeight = bottom

    local penalty = 1
    local maxHeight = rand(3, 15)

    local vertex = {}
    for k=1, 1 + rand(0, 2) * 2 do
        local halved = rand(1, 2) == 1
        vertex[#vertex + 1] = {
            x = rand(math.floor(maxIslandSize * 0.2), math.floor(maxIslandSize * 0.8)),
            y = rand(math.floor(maxIslandSize * 0.2), math.floor(maxIslandSize * 0.8)),
            height = math.floor(rand(4 - bottom, 8 - bottom)),
            halved = halved
        }
    end

    for i=1, maxIslandSize do
        for j=1, maxIslandSize do
            local sum = 0
            for k=1, #vertex do
                local v = vertex[k]
                local value = math.floor(v.height - (math.abs(i - v.x) + math.abs(j - v.y)))
                if v.halved then
                    value = math.min(value, math.floor(v.height / 2))
                end
                sum = sum + math.max(0, value)
            end
            sum = math.min(math.max(sum, bottom), maxHeight)
            top[i][j] = sum + bottom
            if sum > bestHeight then
                bestHeight = sum
            end
        end
    end

    return top, bestHeight, vertex
end


function selectBlockType(top, i, j)
    local block = "flat"
    local rot = 0
    local n = {0, 0, 0, 0}
    local m = {0, 0, 0, 0}

    local height = top[i][j]

    if i - 1 > 0 then
        if top[i - 1][j] > height then
            n[1] = 1
        elseif top[i - 1][j] < height then
            m[1] = 1
        end
    else
        m[1] = 1
    end
    if j - 1 > 0 then
        if top[i][j - 1] > height then
            n[2] = 1
        elseif top[i][j - 1] < height then
            m[2] = 1
        end
    else
        m[2] = 1
    end
    if i + 1 < maxIslandSize then
        if top[i + 1][j] > height then
            n[3] = 1
        elseif top[i + 1][j] < height then
            m[3] = 1
        end
    else
        m[3] = 1
    end
    if j + 1 < maxIslandSize then
        if top[i][j + 1] > height then
            n[4] = 1
        elseif top[i][j + 1] < height then
            m[4] = 1
        end
    else
        m[4] = 1
    end

    local n1, i1 = match(n, {1, 1, 1, 1})
    local n2, i2 = match(n, {1, 1, 1, 0})
    local n3, i3 = match(n, {1, 1, 0, 0})
    local n4, i4 = match(n, {1, 0, 1, 0})
    local n5, i5 = match(n, {1, 0, 0, 0})
    local n6, i6 = match(n, {0, 0, 0, 0})

    local m1, j1 = match(m, {1, 1, 1, 1})
    local m2, j2 = match(m, {1, 1, 1, 0})
    local m3, j3 = match(m, {1, 1, 0, 0})
    local m4, j4 = match(m, {1, 0, 1, 0})
    local m5, j5 = match(m, {1, 0, 0, 0})
    local m6, j6 = match(m, {0, 0, 0, 0}) 

    if n1 then
        block = "flat"
        rot = 0
    elseif n2 then
        block = "climb"
        rot = i2 * 90 - 90
        if m6 then
            block = "flat"
        end
    elseif n3 then
        block = "corner_concav_1"
        rot = i3 * 90
        if m6 then
            block = "flat_2"
        end
    elseif n4 then
        block = "climb"
        rot = i4 * 90
    elseif n5 then
        block = "climb"
        rot = i5 * 90
        if m3 then
            block = "climb"
            rot = i5 * 90
        elseif m4 then
            block = "flat"
        elseif m5 and math.abs(i5 - j5) ~= 2 then
            block = "flat"
        elseif m6 then
            block = "flat"
        end
    elseif n6 then
        block = "flat"
        rot = 0
        if m1 then
            block = "carpet"
        elseif m2 then
            block = "climb"
            rot = j2 * 90 + 90
        elseif m3 then
            block = "corner_concav_2"
            rot = j3 * 90 + 180
        elseif m5 then
            block = "flat"
            rot = j5 * 90 + 180
        end
    end

    local material = "sand"

    local sandHeight = transitionHeight - 1
    local grassHeight = 100

    if height <= sandHeight then
        material = "sand"
        if (block == "corner_concav_1" or block == "flat_2") and height == sandHeight then
            material = "transition2"
        end
    elseif height <= transitionHeight then
        material = "transition"
    else
        material = "grass"
    end

    return block, rot, material
end

function match(array, shape)
    for i=1, #array do
        if tableEq(array, shape) then
            return true, i
        end
        shape = shift(shape)
    end
    return false, -1
end

function shift(array)
    local first = deepcopy(array[1])
    local newArray = {}
    for i=2, #array do
        newArray[#newArray + 1] = deepcopy(array[i])
    end
    newArray[#newArray + 1] = first
    return newArray
end

function isIslandCloserToPlayer(a, b)
    local playerPos = GetPlayerTransform().pos
    local da = VecLength(VecSub(toWorldPos(a.pos), playerPos))
    local db = VecLength(VecSub(toWorldPos(b.pos), playerPos))
    local sa = a.renderState
    local sb = b.renderState
    return da < db
    --[[if renderedCount >= renderedLimit then
        if sa == 3 then
            if sb == 3 then
                return da < db
            else
                return false
            end
        else
            if sb == 3 then
                return true
            else
                return da >= db
            end
        end
    end
    if sa == 3 then
        if sb ~= 3 then
            return true
        else
            return da < db
        end
    else
        if sb == 3 then
            return false
        else
            return da >= db
        end
    end]]
end

function updateIslands()
    skipRendering = not skipRendering
    if skipRendering then
        --return
    end

    if #islands > 1 then
        --table.sort(islands, isIslandCloserToPlayer)
    end

    --[[DebugPrint("vvvvvvvvvvvvvv")
    for i=1, #islands do
        local dist = VecLength(VecSub(toWorldPos(islands[i].pos), GetPlayerTransform().pos))
        DebugPrint(islands[i].name .. " " .. islands[i].renderState .. " " .. dist)
    end]]

    DebugWatch("Rendering", false)
    for i=1, #islands do
        local dist = VecLength(VecSub(toWorldPos(islands[i].pos), GetPlayerTransform().pos))
        if updateIslandRenderState(islands[i]) then
            break
        end
    end
end

function updateIslandRenderState(island)
    local old = island.renderState

    local pos = Vec()
    local x, z = getPlayerTile()
    pos[1] = x
    pos[3] = z
    local dist = VecLength(VecSub(pos, island.pos))

    if dist <= renderDist then
        island.renderState = 3
    else
        island.renderState = 0
    end

    return renderXml(island, old) ~= nil
end

function renderXml(island, previousState)
    if previousState ~= island.renderState then
        if previousState <= 1 then
            for i=1, #island.bodies do
                Delete(island.bodies[i])
            end
            island.bodies = {}
            island.xml = ""
        end
        island.renderIndex = 1
    else
        if island.renderIndex >= #island.tiles and island.renderState == 3 then
            return
        elseif island.renderIndex >= #island.bodies and island.renderState == 0 then
            island.bodies = {}
            island.xml = ""
            return
        elseif island.renderState == 1 then
            return
        end
    end

    if island.renderState == 0 then
        DebugWatch("Rendering", "Deleting")
        local sup = math.min(#island.bodies, island.renderIndex + #island.bodies)
        for i=island.renderIndex, sup - 1 do
            Delete(island.bodies[i])
        end
        island.xml = ""
        island.renderIndex = sup

        return false
        
    elseif island.renderState == 1 then

    elseif island.renderState == 2 then

    elseif island.renderState == 3 then
        local sup = math.min(#island.tiles, island.renderIndex + maxRenderIncrement)
        local entities
        local b
        local treasure = false
        local dynamicProp = false
        for i=island.renderIndex, sup - 1 do
            local spawnTransform
            local tile = island.tiles[i]
            local tilePath = "MOD/prefabs/tiles/" .. tile.material .. "/"
            if tile.blockname == "corner_concav_1" then

                local blockname = "corner_concav"
                local blockname_2 = "corner_concav_2"
                if tile.material == "transition2" then
                    blockname = "corner_concav_t"
                    blockname_2 = "corner_concav_t_2"
                    tilePath = "MOD/prefabs/tiles/transition/"
                end
                
                island.xml = island.xml .. "<instance pos=\"" .. vecToStr(tile.transform.pos, false) .. "\" \
                    rot=\"" .. quatToStr(tile.transform.rot, false) .. "\" \
                    file=\"" .. tilePath .. blockname_2 ..".xml\" />\n"

                spawnTransform = TransformCopy(tile.transform)
                spawnTransform.pos[2] = spawnTransform.pos[2] + islandTileHeight
                island.xml = island.xml .. "<instance pos=\"" .. vecToStr(spawnTransform.pos, false) .. "\" \
                    rot=\"" .. quatToStr(spawnTransform.rot, false) .. "\" \
                    file=\"" .. tilePath .. blockname ..".xml\" />\n"

            elseif tile.blockname == "flat_2" then

                local path2 = deepcopy(tilePath)
                local blockname_2 = "corner_concav"
                if tile.material == "transition2" then
                    blockname_2 = "corner_concav_t"
                    tilePath = "MOD/prefabs/tiles/transition/"
                    path2 = "MOD/prefabs/tiles/sand/"
                end

                island.xml = island.xml .. "<instance pos=\"" .. vecToStr(tile.transform.pos, false) .. "\" \
                    rot=\"" .. quatToStr(tile.transform.rot, false) .. "\" \
                    file=\"" .. path2 .."flat.xml\" />\n"

                spawnTransform = TransformCopy(tile.transform)
                spawnTransform.pos[2] = spawnTransform.pos[2] + islandTileHeight
                island.xml = island.xml .. "<instance pos=\"" .. vecToStr(spawnTransform.pos, false) .. "\" \
                    rot=\"" .. quatToStr(spawnTransform.rot, false) .. "\" \
                    file=\"" .. tilePath .. blockname_2 ..".xml\" />\n"

            else
                island.xml = island.xml .. "<instance pos=\"" .. vecToStr(tile.transform.pos, false) .. "\" \
                    rot=\"" .. quatToStr(tile.transform.rot, false) .. "\" \
                    file=\"" .. tilePath .. tile.blockname ..".xml\" />\n"
            end

            local size = islandTileHeight * (tile.height - bottom - 1)
            spawnTransform = TransformCopy(tile.transform)
            spawnTransform.pos[2] = bottom * islandTileHeight
            spawnTransform.pos = VecAdd(spawnTransform.pos, Vec(-0.5 * islandTileSize, 0.5 * islandTileHeight, -0.5 * islandTileSize))
            spawnTransform.rot = Quat()

            island.xml = island.xml .. "<voxbox texture='4' pos='" .. vecToStr(spawnTransform.pos, false) .. "' \
                rot='" .. quatToStr(spawnTransform.rot, false) .. "' \
                size='" .. islandTileSize * 10 .." ".. size * 10 .." " .. islandTileSize * 10 .. "' color='0.3 0.3 0.3' />\n"
            

            if tile.prop then
                if tile.propType == "barrel" then
                    dynamicProp = true
                end
                local propTransform = TransformToParentTransform(tile.transform, tile.propLocalTransform)
                island.xml = island.xml .. "<instance pos=\"" .. vecToStr(propTransform.pos, false) .. "\" \
                    rot=\"" .. quatToStr(propTransform.rot, false) .. "\" \
                    file='MOD/prefabs/prop/" .. tile.propType .. "s/" .. tile.propName .. ".xml' />\n"

            elseif tile.treasure == 2 then
                treasure = true
                spawnTransform = TransformCopy(tile.transform)
                spawnTransform.pos = VecAdd(spawnTransform.pos, Vec(0, -1, 0))
                island.xml = island.xml .. "<instance pos=\"" .. vecToStr(spawnTransform.pos, false) .. "\" \
                    rot=\"" .. quatToStr(spawnTransform.rot, false) .. "\" \
                    file='MOD/prefabs/prop/treasure_1.xml' />\n"
            end
        end
        DebugWatch("Rendering", "Spawning")
        island.renderIndex = sup
        local xml = xmlWrap(island.xml)
        local entities = Spawn(xml, Transform())
        b = getSpawnedEntities(entities, "body")
        local range = #b
        if treasure then
            range = range - 1
        end
        if dynamicProp then
            range = range - 1
        end
        for j=1, #b do
            if j <= range then
                SetBodyDynamic(b[j], false)
            end
            island.bodies[#island.bodies + 1] = b[j]
        end
        island.xml = ""
    end

    return true
end

function xmlWrap(text)
    return "<prefab version=\"1.1.0\"><group name=\"test_island\">" .. text .. "</group></prefab>"
end