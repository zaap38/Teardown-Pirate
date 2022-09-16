

function setHitInRegistry(identifier, value)
    SetBool("level.medieval_fight.hit." .. identifier, value)
end

function getHitInRegistry(identifier)
    return GetBool("level.medieval_fight.hit." .. identifier)
end

function setInvulnerabilityStatus(identifier, value)
    SetBool("level.medieval_fight.invu." .. identifier, value)
end

function getInvulnerabilityStatus(identifier)
    return GetBool("level.medieval_fight.invu." .. identifier)
end

function setBumpStatus(identifier, value)
    SetBool("level.medieval_fight.bump.status." .. identifier, value)
end

function getBumpStatus(identifier)
    return GetBool("level.medieval_fight.bump.status." .. identifier)
end

function setBumpDir(identifier, value)
    for i=1, 3 do
        SetFloat("level.medieval_fight.bump.dir." .. identifier .. "." .. i, value[i])
    end
end

function getBumpDir(identifier)
    local val = Vec()
    for i=1, 3 do
        val[i] = GetFloat("level.medieval_fight.bump.dir." .. identifier .. "." .. i)
    end
    return val
end

function setPlayerBlocking(value)
    SetBool("level.medieval_fight.player.block", value)
end

function getPlayerBlocking()
    return GetBool("level.medieval_fight.player.block")
end

function setGuardBreak(value)
    SetBool("level.medieval_fight.player.gb", value)
end

function getGuardBreak()
    return GetBool("level.medieval_fight.player.gb")
end

function setStunInRegistry(value)
    SetBool("level.medieval_fight.player.stun", value)
end

function getStunInRegistry()
    return GetBool("level.medieval_fight.player.stun")
end

function setPlayerHurt(value)
    SetBool("level.medieval_fight.player.hurt", value)
end

function getPlayerHurt()
    return GetBool("level.medieval_fight.player.hurt")
end

function setGuardBreakOnEnemy(identifier, value)
    SetBool("level.medieval_fight.gb." .. identifier, value)
end

function getGuardBreakOnEnemy(identifier)
    return GetBool("level.medieval_fight.gb." .. identifier)
end

function setSpawnSparks(value)
    SetBool("level.medieval_fight.player.sparks", value)
end

function getSpawnSparks()
    return GetBool("level.medieval_fight.player.sparks")
end

function setDamageDone(value)
    SetBool("level.medieval_fight.player.damage", value)
end

function getDamageDone()
    return GetBool("level.medieval_fight.player.damage")
end

function getPlayerHitting()
    return GetBool("level.medieval_fight.player.hitting")
end

function setPlayerHitting(value)
    SetBool("level.medieval_fight.player.hitting", value)
end

function setHasToSpawn(value)
    SetBool("level.medieval_fight.player.spawn", value)
end

function getHasToSpawn()
    return GetBool("level.medieval_fight.player.spawn")
end

function setSpawnInRegistry(value)
    SetBool("level.medieval_fight.player.spawned", value)
end

function getSpawnInRegistry()
    return GetBool("level.medieval_fight.player.spawned")
end

function setLastSpawn(value)
    SetInt("level.medieval_fight.player.lastspawn", value)
end

function getLastSpawn()
    return GetInt("level.medieval_fight.player.lastspawn")
end

function setIdentifierCount(value)
    SetInt("level.medieval_fight.player.identifiercount", value)
end

function getIdentifierCount()
    return GetInt("level.medieval_fight.player.identifiercount")
end

function setDifficultyInRegistry(value)
    SetString("level.medieval_fight.player.difficulty", value)
end

function getDifficultyInRegistry()
    return GetString("level.medieval_fight.player.difficulty")
end

function setEnemyDeath(value)
    SetBool("level.medieval_fight.player.enemydeath", value)
end

function getEnemyDeath()
    return GetBool("level.medieval_fight.player.enemydeath")
end

function setPlayerDeath(value)
    SetBool("level.medieval_fight.player.death", value)
end

function getPlayerDeath()
    return GetBool("level.medieval_fight.player.death")
end

function setShapeHit(identifier, value)
    SetInt("level.medieval_fight.shapehit." .. identifier, value)
end

function getShapeHit(identifier)
    return GetInt("level.medieval_fight.shapehit." .. identifier)
end

function setPlayerAttack(value)
    SetBool("level.medieval_fight.attack", value)
end

function getPlayerAttack()
    return GetBool("level.medieval_fight.attack")
end

function setPlayerThrust(value)
    SetBool("level.medieval_fight.thrust", value)
end

function getPlayerThrust()
    return GetBool("level.medieval_fight.thrust")
end

function setDamageAmountInRegistry(value)
    SetInt("level.medieval_fight.player.damageamount", value)
end

function getDamageAmountInRegistry()
    return GetInt("level.medieval_fight.player.damageamount")
end

function setStaminaValueInRegistry(value)
    SetFloat("level.medieval_fight.player.stamina.value", value)
end

function getStaminaValueInRegistry()
    return GetFloat("level.medieval_fight.player.stamina.value")
end

function setStaminaDamageInRegistry(value)
    SetInt("level.medieval_fight.player.stamina.damage", value)
end

function getStaminaDamageInRegistry()
    return GetInt("level.medieval_fight.player.stamina.damage")
end

function setShieldToggle(value)
    SetBool("level.medieval_fight.player.shield", value)
end

function getShieldToggle()
    return GetBool("level.medieval_fight.player.shield")
end



















