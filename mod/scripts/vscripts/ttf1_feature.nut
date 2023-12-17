untyped
global function ttf1_feature_init

void function ttf1_feature_init() {
    AddDamageCallback("player", ChangeShieldFunctionCallback)
}

void function ChangeShieldFunctionCallback(entity player, var damageInfo) {
    thread ChangeShieldFunction(player, damageInfo)
}

void function ChangeShieldFunction(entity player, var damageInfo) {
    if (!IsValid(player) || !IsAlive(player) || !player.IsTitan())
        return

    entity soul = player.GetTitanSoul()
    if (soul == null)
        return

    entity attacker = DamageInfo_GetAttacker(damageInfo)
    if(!attacker.IsPlayer())
        if (attacker.IsProjectile())
            attacker = attacker.GetOwner()
    else {
        if (!IsValid(attacker))
            return
    }
    entity inflictor = DamageInfo_GetInflictor(damageInfo)
    float damage = DamageInfo_GetDamage(damageInfo)
    int damageSourceId = DamageInfo_GetDamageSourceIdentifier(damageInfo)

    int shieldMax = soul.GetShieldHealthMax()
    int currentShield = soul.GetShieldHealth()
    if (int(damage) > currentShield)
        return

    float defenceRate = CalcShieldDefenceRate(damage, currentShield, shieldMax)
    int titanHp = player.GetHealth()
    int tDamage = int(defenceRate * damage)
    titanHp -= tDamage
    if (titanHp <= 0) {
        if (soul.IsDoomed())
            player.Die(attacker, attacker, { damageSourceId = damageSourceId })
        else {
            int newShield = currentShield - int(damage)
            soul.SetShieldHealth(0)
            player.TakeDamage(tDamage, attacker, attacker, { damageSourceId = damageSourceId })
            if (IsAlive(player) && newShield > 0)
                soul.SetShieldHealth(newShield)
            //TakeDamage(20, GetPlayerArray()[0], GetPlayerArray()[0], { damageSourceId = eDamageSourceId.mp_weapon_lmg })
        }
    } else {
        int newShield = currentShield - int(damage)
        soul.SetShieldHealth(0)
        player.TakeDamage(tDamage, attacker, attacker, { damageSourceId = damageSourceId })
        if (IsAlive(player) && newShield > 0)
            soul.SetShieldHealth(newShield)
    }
}

float function CalcShieldDefenceRate(float damage, int currentShield, int shieldMax) {
    return 1.0 - max(0.6, 0.9 * float(currentShield) / float(shieldMax))
}

//float function max(float a, float b) {
//    if (a > b)
//        return a
//    else
//        return b
//}