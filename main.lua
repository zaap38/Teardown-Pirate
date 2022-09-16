#include "snippets.lua"
#include "scripts/generation.lua"
#include "sword_fight/main_fight.lua"



function init()
	generationInit()
	fightInit()
end

function tick(dt)
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