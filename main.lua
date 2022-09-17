#include "snippets.lua"
#include "scripts/generation.lua"
#include "sword_fight/main_fight.lua"



function init()
    totalTime = 0
	generationInit()
	fightInit()
end

function tick(dt)
    totalTime = totalTime + dt
	SetFloat("level.pirate.time", totalTime)
	generationTick(dt)
	fightTick(dt)
end

function update(dt)
	generationUpdate(dt)
	fightUpdate(dt)
end

function draw() 
	generationDraw(dt)
	fightDraw(dt)
end