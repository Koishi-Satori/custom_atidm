untyped
global function custom_ui_init

const array<string> AdminUIDs = []
const array<string> ShitPlayerNames = []

// first key: [loudout_type], second key: UID, final value: index
table players_loadout = {}

array<string> TitanLoadouts_Ordnance = []
var TitanLoadouts_Ordnance_Mods = []
array<string> TitanLoadouts_Center = []
var TitanLoadouts_Center_Mods = []
array<string> TitanLoadouts_Special = []
var TitanLoadouts_Special_Mods = []
array<string> TitanLoadouts_MainWpn = []
var TitanLoadouts_MainWpn_Mods = []

const string HTTP_IO_URL = "[api_url]"

const array<string> TOP_LEVEL_UI_OPTIONS = ["主武器", "特殊技能", "辅助技能", "防御技能"]
const array<array<string> > LOADOUT_LEVEL_UI_OPTIONS = [
    ["电弧机炮", "XO-16", "40mm机炮", "龙息弹", "分裂枪", "四段火箭", "短点射配置XO-16", "返回"],
    ["涡旋防护罩", "被动式涡旋防护罩", "蓄力剑封", "粒子墙", "穹顶护盾", "牵引护盾", "返回"],
    ["重力节点", "相位冲刺", "泰坦激素", "强化电烟", "毒蛇推进器", "电磁陷阱", "返回"],
    ["集束飞弹", "电弧波", "火箭弹群", "镭射炮", "同步飞弹", "标记射线", "返回"]
]
const array<array<string> > LOADOUT_LEVEL_UI_OPTIONS_DESC = [
    ["可以连锁落点附近的敌人, 并且对敌人造成干扰", "经过伤害平衡的xo16", "经过强化的40mm机炮", "发射后会分裂出多股小型铝热剂, 在密闭空间反铁驭非常强大", "经过伤害加强和能量消耗减少的分裂枪", "瞄准时发射速度和装弹速度得到提升的四段火箭", "40发短点射XO16, 每次扣动扳机将会发射八连发"],
    ["离子涡旋防护罩, 经典款", "防护罩接到子弹后会立刻反弹，在未收到攻击时会缓慢恢复（包括开启时），但每收到一次攻击都会降低剩余时间", "剑封时消耗充能, 停止剑封可以恢复充能, 同时剑封时大幅增加移速(225%), 充能不足时减速70%", "正常的强力粒子护盾, 可以阻挡正面的攻击", "跟随并全方位保护使用者，使用者冲刺或受到近战攻击都会立刻摧毁护盾", "会往前推进直到碰到墙壁, 会推开途中的敌人, 并且对其造成干扰和微小伤害"],
    ["发射一个节点，会将周围的敌人吸过去并且造成干扰", "浪人相位冲刺冲刺冲刺, 但是强化了冲刺距离", "大幅度提升泰坦的移动速度, 泥头车!", "略微强化过的电烟", "携带毒蛇推进器的悬浮, 再按一次可以主动降落", "快速布置一排电弧场，瘫痪贸然穿越的敌方泰坦"],
    ["未改动的北极星集束飞弹", "正常的浪人电弧波", "可锁定重甲目标的多目标飞弹", "离子的镭射炮, 经典款", "锁定后多轮次连续发射三发锁定飞弹, 命中后产生很恶心的干扰效果", "击中敌人后会短时间标记敌人，被标记的实体会受到的伤害+65%"]
]

//	entity qWeapon = player.GetOffhandWeapon(OFFHAND_ORDNANCE)
//	entity gWeapon = player.GetOffhandWeapon(OFFHAND_TITAN_CENTER)
//	entity midWeapon = player.GetOffhandWeapon(OFFHAND_SPECIAL)
//	string coreWeapon = player.GetOffhandWeapon(OFFHAND_EQUIPMENT).GetWeaponClassName();
//	entity meleeWeapon = player.GetOffhandWeapon(OFFHAND_MELEE)
//	entity mainWeapon = player.GetMainWeapons()[0]
const int LEVEL_TOP = 0
const int LEVEL_WPN = 1
const int LEVEL_ORDNANCE = 4
const int LEVEL_CENTER = 3
const int LEVEL_SPECIAL = 2

const int CORE_SHIELD = 0
const int CORE_DAMAGE = 1
const int CORE_RUSH = 2

void function custom_ui_init() {
    InitTitanLoadouts()
    AddCallback_OnClientConnected(OnClientConnected)
    AddCallback_OnPlayerRespawned(RespawnMessage_CallBack)
    AddCallback_OnPlayerGetsNewPilotLoadout(OnPlayerGetsNewPilotLoadout)
    AddSpawnCallback( "npc_titan", OnTitanFall )

    #if SERVER
    AddClientCommandCallback( "ac", AdminCommand );
    AddClientCommandCallback("!switch", SwitchCommand);
    #endif
}

void function RespawnMessage_CallBack(entity player) {
    thread DisplayHealth(player)
	thread RespawnMessage_CallBackImpl(player);
}

void function DisplayHealth(entity player) {
    player.EndSignal("OnDestroy");
    player.EndSignal("OnDeath");

    string id_hp = UniqueString("kk_health#")
    string id_shp = UniqueString("kk_shield_health#")
    string id_vel = UniqueString("kk_velocity#")
    NSCreateStatusMessageOnPlayer(player, "", "当前血量: 0/0", id_hp)
    NSCreateStatusMessageOnPlayer(player, "", "当前护盾: 0/0", id_shp)
    NSCreateStatusMessageOnPlayer(player, "", "当前速度: unknown", id_vel)

    OnThreadEnd(
        function() : (player, id_hp, id_shp, id_vel) {
            NSDeleteStatusMessageOnPlayer(player, id_hp)
            NSDeleteStatusMessageOnPlayer(player, id_shp)
            NSDeleteStatusMessageOnPlayer(player, id_vel)
        }
    )

    while (true) {
        if (!IsValid(player) || !IsAlive(player))
            break
        int hp = player.GetHealth()
        int shp = player.GetShieldHealth()
        vector vel = player.GetVelocity()
        float vel_x = vel.x
        float vel_y = vel.y
//        float vel_z = vel.z
        float playerVelKph = sqrt(vel_x * vel_x + vel_y * vel_y) * 0.091392 * 0.621371
//        if (vel_z < 0)
//            vel_z *= -1
//        vel_z *= (0.091392 * 0.621371)

        NSEditStatusMessageOnPlayer(player, "", "当前血量: " + hp + "/" + player.GetMaxHealth(), id_hp)
        NSEditStatusMessageOnPlayer(player, "", "当前盾量: " + shp + "/" + player.GetShieldHealthMax(), id_shp)
        NSEditStatusMessageOnPlayer(player, "", "当前速度: " + format("%3i", playerVelKph) + "kph", id_vel)
        WaitFrame()
    }
}

void function RespawnMessage_CallBackImpl(entity player) {
    if (!("KC_HasShownTips" in player.s)) {
		Chat_ServerPrivateMessage(player, "队伍不平衡时可以在控制台用!switch更换队伍", false);
		Chat_ServerPrivateMessage(player, "已启用: 泰坦落地护盾/我自己的net io", false);
		player.s.KC_HasShownTips <- true;
	} else if (!TeamBalanceCheck())
		Chat_ServerPrivateMessage(player, "检测到当前队伍不平衡, 可以在控制台用!switch更换队伍", false);
    Chat_ServerPrivateMessage(player,"欢迎来到Kkoishi的服务器, 服主是[特莉波卡]Satori_KKoishi, 服务器群号: 753171184", false)
	Chat_ServerPrivateMessage(player, "在铁驭状态下您可以长按使用键(默认为E)来打开泰坦装备选择菜单, 未选择的装备将会随机选择一件使用, 可选择的为主武器和技能", false);
	Chat_ServerPrivateMessage(player, "您选择的装备将会被保存, 用于之后的对局. 服务器群号: 753171184", false);
    Chat_ServerPrivateMessage(player, "消音器莫桑比克将会被替换为双管霰弹, 弹射克莱伯将被替换为和平克莱伯", false)
	player.EndSignal( "OnDestroy" );
	player.EndSignal( "OnDeath" );
	WaitFrame();
	if (IsValid(player)) {
        // 直接重生为泰坦, 则生成泡泡护盾
        // 直接重生为玩家, 则检测是否需要携带双管喷/和平克莱伯
        if (player.IsTitan()) {
            CreateBubbleShield(player, player.GetOrigin(), player.GetAngles());
        } else {
            ReplacePilotWeapon(player)
        }

    thread KickPlayer()
	}
}

void function KickPlayer() {
    if (player.GetPlayerName() in ShitPlayerNames) {
    foreach (entity ent in GetPlayerArray()) {
        Chat_ServerPrivateMessage(entity, player.GetPlayerName() + " is fucking kicked, lmfao", false)
    }
    wait 0.5
    ServerCommand("kickid " + player.GetUID())
    }
}

void function OnPlayerGetsNewPilotLoadout(entity player, PilotLoadoutDef p) {
    thread ReplacePilotWeapon(player)
}

void function ReplacePilotWeapon(entity player) {
    array<entity> mainWpn = player.GetMainWeapons()
    if (mainWpn.len() != 3)
        return

    foreach (entity wpn in mainWpn) {
        string wpnName = wpn.GetWeaponClassName()
        array<string> wpnMods = wpn.GetMods()

        if (wpnName == "mp_weapon_shotgun_pistol" && wpnMods.contains("silencer")) {
            printt("find mp_weapon_shotgun_pistol")
            // gift mp_weapon_shotgun_doublebarrel_tfo kk  pas_run_and_gun  pas_fast_swap  pas_fast_ads
            player.TakeWeaponNow(wpnName)
            player.GiveWeapon("mp_weapon_shotgun_doublebarrel_tfo",["pas_fast_ads","pas_fast_swap","pas_run_and_gun"])
        } else if (wpnName == "mp_weapon_sniper" && wpnMods.contains("ricochet")) {
            printt("find mp_weapon_sniper")
            player.TakeWeaponNow(wpnName)
            player.GiveWeapon("mp_weapon_peacekraber", [])
        }
    }
}

void function OnTitanFall(entity titan) {
	entity player = titan
	entity soul = titan.GetTitanSoul()
	if (!IsValid(player))
		return
	if (!titan.IsPlayer())
		player = GetPetTitanOwner(titan)
    if (player == null)
        return
	if (!IsValid(soul))
		return
	array<entity> weapons = titan.GetMainWeapons()
	foreach (entity weapon in weapons) {
        titan.TakeWeaponNow(weapon.GetWeaponClassName())
	}
	titan.TakeOffhandWeapon(OFFHAND_ORDNANCE)
	titan.TakeOffhandWeapon(OFFHAND_TITAN_CENTER)
	titan.TakeOffhandWeapon(OFFHAND_SPECIAL)
	titan.TakeOffhandWeapon(OFFHAND_EQUIPMENT)
    array<int> passives = [ePassives.PAS_NORTHSTAR_WEAPON,
							ePassives.PAS_NORTHSTAR_CLUSTER,
							ePassives.PAS_NORTHSTAR_TRAP,
							ePassives.PAS_NORTHSTAR_FLIGHTCORE,
							ePassives.PAS_NORTHSTAR_OPTICS,
							ePassives.PAS_VANGUARD_COREMETER,
							ePassives.PAS_VANGUARD_SHIELD,
							ePassives.PAS_VANGUARD_REARM,
							ePassives.PAS_VANGUARD_DOOM,
							ePassives.PAS_VANGUARD_CORE1,
							ePassives.PAS_VANGUARD_CORE2,
							ePassives.PAS_VANGUARD_CORE3,
							ePassives.PAS_VANGUARD_CORE4,
							ePassives.PAS_VANGUARD_CORE5,
							ePassives.PAS_VANGUARD_CORE6,
							ePassives.PAS_VANGUARD_CORE7,
							ePassives.PAS_VANGUARD_CORE8,
							ePassives.PAS_VANGUARD_CORE9,
							ePassives.PAS_SCORCH_WEAPON,
							ePassives.PAS_SCORCH_FIREWALL,
							ePassives.PAS_SCORCH_SHIELD,
							ePassives.PAS_SCORCH_SELFDMG,
							ePassives.PAS_SCORCH_FLAMECORE,
							ePassives.PAS_ION_WEAPON,
							ePassives.PAS_ION_TRIPWIRE,
							ePassives.PAS_ION_VORTEX,
							ePassives.PAS_ION_LASERCANNON,
							ePassives.PAS_ION_WEAPON_ADS,
							ePassives.PAS_RONIN_WEAPON,
							ePassives.PAS_RONIN_ARCWAVE,
							ePassives.PAS_RONIN_PHASE,
							ePassives.PAS_RONIN_SWORDCORE,
							ePassives.PAS_RONIN_AUTOSHIFT,
							ePassives.PAS_TONE_WEAPON,
							ePassives.PAS_TONE_ROCKETS,
							ePassives.PAS_TONE_SONAR,
							ePassives.PAS_TONE_WALL,
							ePassives.PAS_TONE_BURST,
							ePassives.PAS_LEGION_CHARGESHOT,
							ePassives.PAS_LEGION_GUNSHIELD,
							ePassives.PAS_LEGION_SMARTCORE,
							ePassives.PAS_LEGION_SPINUP,
							ePassives.PAS_LEGION_WEAPON]
	foreach (passive in passives) {
		TakePassive(soul, passive)
	}

	if (titan.GetMaxHealth() == 12500) {
        titan.SetMaxHealth(15000)
		titan.SetHealth(15000)
		titan.GiveOffhandWeapon("mp_titancore_upgrade", OFFHAND_EQUIPMENT, ["shield_core"])
		soul.SetTitanSoulNetInt("upgradeCount", 4)
        Chat_ServerPrivateMessage(player, "您的核心被替换为: 护盾核心-生效期间快速回复泰坦护盾", false)
	}
	if (titan.GetMaxHealth() == 10000)
	{
        titan.SetMaxHealth(12500)
		titan.SetHealth(12500)
		titan.GiveOffhandWeapon("mp_titancore_amp_core", OFFHAND_EQUIPMENT, ["damage_core"])
        Chat_ServerPrivateMessage(player, "您的核心被替换为: 破坏核心-提升全伤害40%", false)
	}
	if (titan.GetMaxHealth() == 7500) {
        titan.SetMaxHealth(9000)
        titan.SetHealth(9000)
		titan.TakeOffhandWeapon(OFFHAND_MELEE)
		titan.GiveOffhandWeapon("melee_titan_punch_northstar", OFFHAND_MELEE)
		titan.GiveOffhandWeapon("mp_titancore_shift_core", OFFHAND_EQUIPMENT, ["tcp_dash_core"])
        Chat_ServerPrivateMessage(player, "您的核心被替换为: 冲刺核心-无限冲刺", false)
	}

	titan.TakeOffhandWeapon(OFFHAND_ORDNANCE)
	titan.TakeOffhandWeapon(OFFHAND_TITAN_CENTER)
	titan.TakeOffhandWeapon(OFFHAND_SPECIAL)

    // give weapons
    string uid = player.GetUID()
    GiveOrdnance(uid, titan)
    GiveCenter(uid, titan)
    GiveSpecial(uid, titan)
    GiveMainWeapon(uid, titan)
}

array<string> function CastWeaponMods(var arr) {
    array<string> nArray = []
    int arr_len = expect int(arr.len())
    for (int index = 0; index < arr_len; index++)
        nArray.append(expect string(arr[index]))
    return nArray
}

void function GiveOrdnance(string uid, entity titan) {
    printt(uid in players_loadout.TitanLoadouts_Ordnance)
    int index
    if (!(uid in players_loadout.TitanLoadouts_Ordnance)) {
        index = RandomInt(TitanLoadouts_Ordnance.len())
    } else
        index = expect int(players_loadout.TitanLoadouts_Ordnance[uid])
    titan.GiveOffhandWeapon(TitanLoadouts_Ordnance[index], OFFHAND_ORDNANCE, CastWeaponMods(TitanLoadouts_Ordnance_Mods[index]))
}

void function GiveCenter(string uid, entity titan) {
    int index
    if (!(uid in players_loadout.TitanLoadouts_Center)) {
        index = RandomInt(TitanLoadouts_Center.len())
    } else
        index = expect int(players_loadout.TitanLoadouts_Center[uid])
    titan.GiveOffhandWeapon(TitanLoadouts_Center[index], OFFHAND_TITAN_CENTER, CastWeaponMods(TitanLoadouts_Center_Mods[index]))
}

void function GiveSpecial(string uid, entity titan) {
    int index
    if (!(uid in players_loadout.TitanLoadouts_Special)) {
        index = RandomInt(TitanLoadouts_Special.len())
    } else
        index = expect int(players_loadout.TitanLoadouts_Special[uid])
    titan.GiveOffhandWeapon(TitanLoadouts_Special[index], OFFHAND_SPECIAL, CastWeaponMods(TitanLoadouts_Special_Mods[index]))
}

void function GiveMainWeapon(string uid, entity titan) {
    int index
    if (!(uid in players_loadout.TitanLoadouts_MainWpn)) {
        index = RandomInt(TitanLoadouts_MainWpn.len())
    } else
        index = expect int(players_loadout.TitanLoadouts_MainWpn[uid])
    titan.GiveWeapon(TitanLoadouts_MainWpn[index], CastWeaponMods(TitanLoadouts_MainWpn_Mods[index]))
}

void function OnClientConnected(entity player) {
    player.s.KC_Option <- 0
    player.s.KC_MenuLevel <- LEVEL_TOP
    player.s.KC_TitanCore <- CORE_DAMAGE
    player.s.KC_GUIActive <- true
    player.s.KC_GUIClose <- false
    player.s.KC_GUIDisable <- false
    AddPlayerHeldButtonEventCallback(player, IN_USE, TitanLoadoutGUI, 0)
}

void function TitanLoadoutGUI(entity player) {
    if (player.IsTitan())
        return
    table result = {}
    bool timeOut = false
//    player.s.KC_GUIClose = false
    OnThreadEnd(
        function(): (player, timeOut) {
            if (!IsValid(player) || timeOut || player.IsTitan())
                return
            if (player.s.KC_GUIDisable)
                return

            SwitchMenu(player)
        }
    )

    wait 0.3
//    if (!player.s.KC_GUIActive)
//        return
    timeOut = true
    SelectMenu(player)
}

void function RenderMenu(entity player) {
    //player.s.KC_GUIActive <- false
    int level = expect int(player.s.KC_MenuLevel)
    printt("Showing menu level " + level + " to player " + player.GetUID())
    int option = expect int(player.s.KC_Option)
    switch (level) {
        case LEVEL_TOP:
            string topMenu = "短按切换 == Main Menu == 长按选中\n\n"
            if (option < 0 || option > 3)
                option = 0
            for (int index = 0; index < TOP_LEVEL_UI_OPTIONS.len(); index++) {
                // -xxx- -xxx- -xxx-
                topMenu += "-"
                if (index == option) {
                    topMenu += "◆"
                    topMenu += TOP_LEVEL_UI_OPTIONS[index]
                    topMenu += "◆"
                }
                else {
                    topMenu += "◇"
                    topMenu += TOP_LEVEL_UI_OPTIONS[index]
                    topMenu += "◇"
                }
                topMenu += "-"
                if (index != TOP_LEVEL_UI_OPTIONS.len() - 1)
                    topMenu += " "
            }
            topMenu += "\n\n\n\n\n选择完毕后会在下一次泰坦重生时应用更改\n您目前的装备是: \n主武器: "
            string uid = player.GetUID()
            if (uid in players_loadout.TitanLoadouts_MainWpn)
                topMenu += expect string(LOADOUT_LEVEL_UI_OPTIONS[0][players_loadout.TitanLoadouts_MainWpn[uid]])
            else
                topMenu += "未选择:("
            topMenu += " 防御技能: "
            if (uid in players_loadout.TitanLoadouts_Special)
                topMenu += expect string(LOADOUT_LEVEL_UI_OPTIONS[1][players_loadout.TitanLoadouts_Special[uid]])
            else
                topMenu += "未选择:("
            topMenu += " 辅助技能: "
            if (uid in players_loadout.TitanLoadouts_Center)
                topMenu += expect string(LOADOUT_LEVEL_UI_OPTIONS[2][players_loadout.TitanLoadouts_Center[uid]])
            else
                topMenu += "未选择:("
            topMenu += " 特殊技能: "
            if (uid in players_loadout.TitanLoadouts_Ordnance)
                topMenu += expect string(LOADOUT_LEVEL_UI_OPTIONS[3][players_loadout.TitanLoadouts_Ordnance[uid]])
            else
                topMenu += "未选择:("
            topMenu += "\n\n未选择的将会随机一件装备awa"

            SendHudMessage(player, topMenu, -1, 0.3, 200, 200, 225, 0, 0.15, 6, 1);
            break;
        case LEVEL_WPN:
        case LEVEL_ORDNANCE:
        case LEVEL_CENTER:
        case LEVEL_SPECIAL:
            string menu = "短按切换 == Loadout Selection Menu == 长按选中\n\n"
            array<string> options = LOADOUT_LEVEL_UI_OPTIONS[level - 1]
            int options_len = options.len()
            if (option < 0 || option > options_len - 1)
                option = 0
            for (int index = 0; index < options_len; index++) {
                // -xxx- -xxx- -xxx-
                menu += "-"
                if (index == option) {
                    menu += "◆"
                    menu += options[index]
                    menu += "◆"
                }
                else {
                    menu += "◇"
                    menu += options[index]
                    menu += "◇"
                }
                menu += "-"
                if (index != options_len - 1)
                    menu += " "
            }
            menu += "\n\n\n\n\n选择完毕后会在下一次泰坦重生时应用更改"

            SendHudMessage(player, menu, -1, 0.4, 200, 200, 225, 0, 0.15, 6, 1);
            break;
    }
    //player.s.KC_GUIClose = true
}

void function SelectMenu(entity player) {
    //ReadDataFromHttpIO()
    //player.s.KC_GUIActive = false
    int level = expect int(player.s.KC_MenuLevel)
    int option = expect int(player.s.KC_Option)
    string uid = player.GetUID()
    //printt(uid + " select " + option)
    switch (level) {
        case LEVEL_TOP:
            if (option == 0)
                player.s.KC_MenuLevel = LEVEL_WPN
            else if (option == 1)
                player.s.KC_MenuLevel = LEVEL_ORDNANCE
            else if (option == 2)
                player.s.KC_MenuLevel = LEVEL_CENTER
            else if (option == 3)
                player.s.KC_MenuLevel = LEVEL_SPECIAL
            else {
                player.s.KC_MenuLevel = LEVEL_WPN
            }
            player.s.KC_Option = -1
            break;
        case LEVEL_WPN:
            array<string> options = LOADOUT_LEVEL_UI_OPTIONS[level - 1]
            int options_len = options.len()
            if (option == options_len - 1) {
                player.s.KC_Option = 0
                player.s.KC_MenuLevel = LEVEL_TOP
                return
            }
            if (option < 0 || option > options_len - 1)
                option = 0
            players_loadout.TitanLoadouts_MainWpn[player.GetUID()] <- option
            SaveDataToHttpIO()
            Chat_ServerPrivateMessage(player, "已更改装备为" + LOADOUT_LEVEL_UI_OPTIONS[0][option] + ": " + LOADOUT_LEVEL_UI_OPTIONS_DESC[0][option], false)
            player.s.KC_MenuLevel = LEVEL_TOP
            break;
        case LEVEL_ORDNANCE:
            array<string> options = LOADOUT_LEVEL_UI_OPTIONS[level - 1]
            int options_len = options.len()
            if (option == options_len - 1) {
                player.s.KC_Option = 0
                player.s.KC_MenuLevel = LEVEL_TOP
                return
            }
            if (option < 0 || option > options_len - 1)
                option = 0
            players_loadout.TitanLoadouts_Ordnance[player.GetUID()] <- option
            SaveDataToHttpIO()
            Chat_ServerPrivateMessage(player, "已更改装备为" + LOADOUT_LEVEL_UI_OPTIONS[3][option] + ": " + LOADOUT_LEVEL_UI_OPTIONS_DESC[3][option], false)
            player.s.KC_MenuLevel = LEVEL_TOP
            break;
        case LEVEL_CENTER:
            array<string> options = LOADOUT_LEVEL_UI_OPTIONS[level - 1]
            int options_len = options.len()
            if (option == options_len - 1) {
                player.s.KC_Option = 0
                player.s.KC_MenuLevel = LEVEL_TOP
                return
            }
            if (option < 0 || option > options_len - 1)
                option = 0
            players_loadout.TitanLoadouts_Center[player.GetUID()] <- option
            SaveDataToHttpIO()
            Chat_ServerPrivateMessage(player, "已更改装备为" + LOADOUT_LEVEL_UI_OPTIONS[2][option] + ": " + LOADOUT_LEVEL_UI_OPTIONS_DESC[2][option], false)
            player.s.KC_MenuLevel = LEVEL_TOP
            break;
        case LEVEL_SPECIAL:
            array<string> options = LOADOUT_LEVEL_UI_OPTIONS[level - 1]
            int options_len = options.len()
            if (option == options_len - 1) {
                player.s.KC_Option = 0
                player.s.KC_MenuLevel = LEVEL_TOP
                return
            }
            if (option < 0 || option > options_len - 1)
                option = 0
            players_loadout.TitanLoadouts_Special[player.GetUID()] <- option
            SaveDataToHttpIO()
            Chat_ServerPrivateMessage(player, "已更改装备为" + LOADOUT_LEVEL_UI_OPTIONS[1][option] + ": " + LOADOUT_LEVEL_UI_OPTIONS_DESC[1][option], false)
            player.s.KC_MenuLevel = LEVEL_TOP
            break;
    }
}

void function SwitchMenu(entity player) {
    if (player.s.KC_GUIActive) {
        int level = expect int(player.s.KC_MenuLevel)
        int option = expect int(player.s.KC_Option)
        option++
        switch (level) {
            case LEVEL_TOP:
                if (option < 0 || option > 3)
                    option = 0
                break;
            case LEVEL_WPN:
            case LEVEL_ORDNANCE:
            case LEVEL_CENTER:
            case LEVEL_SPECIAL:
                array<string> options = LOADOUT_LEVEL_UI_OPTIONS[level - 1]
                int options_len = options.len()
                if (option < 0 || option > options_len - 1)
                    option = 0
                break;
        }
        player.s.KC_Option = option
    }

    //player.s.KC_GUIActive <- true
    //player.s.KC_GUIClose <- false
    EmitSoundOnEntityOnlyToPlayer( player, player, "menu_click" )
    thread RenderMenu(player)
}

void function InitTitanLoadouts() {
    // get data from my net io~
    ReadDataFromHttpIO()

    // init loadouts
    // const array<array<string> > LOADOUT_LEVEL_UI_OPTIONS = [
    //    ["电弧机炮", "XO-16", "40mm机炮", "龙息弹", "分裂枪", "四段火箭", "返回"],
    //    ["涡旋防护罩", "被动式涡旋防护罩", "蓄力剑封", "粒子墙", "穹顶护盾", "返回"],
    //    ["重力节点", "相位冲刺", "野牛突刺", "强化电烟", "毒蛇推进器", "返回"],
    //    ["集束飞弹", "电弧波", "火箭弹群", "镭射炮", "同步飞弹", "返回"]
    //]
    //array<string> TitanLoadouts_Ordnance = []
    //var TitanLoadouts_Ordnance_Mods = []
    //array<string> TitanLoadouts_Center = []
    //var TitanLoadouts_Center_Mods = []
    //array<string> TitanLoadouts_Special = []
    //var TitanLoadouts_Special_Mods = []
    //array<string> TitanLoadouts_MainWpn = []
    //var TitanLoadouts_MainWpn_Mods = []
    TitanLoadouts_MainWpn.append("mp_titanweapon_arc_cannon")
    TitanLoadouts_MainWpn_Mods.append(["capacitor", "overcharge"])
    TitanLoadouts_MainWpn.append("mp_titanweapon_xo16_vanguard");
    TitanLoadouts_MainWpn_Mods.append(["fd_balance"]);
    TitanLoadouts_MainWpn.append("mp_titanweapon_sticky_40mm");
    TitanLoadouts_MainWpn_Mods.append(["burn_mod_titan_40mm", "extended_ammo"]);
    TitanLoadouts_MainWpn.append("mp_titanweapon_meteor");
    TitanLoadouts_MainWpn_Mods.append(["tcp_shotgun"]);
    TitanLoadouts_MainWpn.append("mp_titanweapon_particle_accelerator");
    TitanLoadouts_MainWpn_Mods.append(["burn_mod_titan_particle_accelerator", "fd_split_shot_cost"]);
    TitanLoadouts_MainWpn.append("mp_titanweapon_rocketeer_rocketstream");
    TitanLoadouts_MainWpn_Mods.append(["tcp_brute"]);
    TitanLoadouts_MainWpn.append("mp_titanweapon_xo16_shorty");
    TitanLoadouts_MainWpn_Mods.append(["tcp_kk_balance_extended_ammo", "burst"]);
//    TitanLoadouts_MainWpn.append("");
//    TitanLoadouts_MainWpn_Mods.append([""]);

    TitanLoadouts_Special.append("mp_titanweapon_vortex_shield")
    TitanLoadouts_Special_Mods.append(["slow_recovery_vortex"])
    TitanLoadouts_Special.append("mp_titanweapon_vortex_shield")
    TitanLoadouts_Special_Mods.append(["burn_mod_titan_vortex_shield", "slow_recovery_vortex"])
    TitanLoadouts_Special.append("mp_ability_swordblock")
    TitanLoadouts_Special_Mods.append([])
    TitanLoadouts_Special.append("mp_titanability_particle_wall")
    TitanLoadouts_Special_Mods.append([])
    TitanLoadouts_Special.append("mp_titanability_particle_wall")
    TitanLoadouts_Special_Mods.append(["brute4_bubble_shield"])
    TitanLoadouts_Special.append("mp_titanability_particle_wall")
    TitanLoadouts_Special_Mods.append(["tcp_dash_shield"])
//    TitanLoadouts_Ordnance.append("")
//    TitanLoadouts_Ordnance_Mods.append([])

    TitanLoadouts_Center.append("mp_titanability_sonar_pulse")
    TitanLoadouts_Center_Mods.append(["tcp_gravity"])
    TitanLoadouts_Center.append("mp_titanability_phase_dash")
    TitanLoadouts_Center_Mods.append(["fd_phase_distance"])
    TitanLoadouts_Center.append("mp_ability_heal")
    TitanLoadouts_Center_Mods.append(["bc_super_stim" ,"bc_long_stim2" ,"pas_power_cell" ,"burn_card_weapon_mod" ,"amped_tacticals" ,"spree_lvl3_heal"])
    TitanLoadouts_Center.append("mp_titanability_smoke")
    TitanLoadouts_Center_Mods.append(["pas_defensive_core", "fast_warmup"])
    TitanLoadouts_Center.append("mp_titanability_hover")
    TitanLoadouts_Center_Mods.append(["tcp_super_hover"])
    TitanLoadouts_Center.append("mp_titanability_laser_trip")
    TitanLoadouts_Center_Mods.append(["tcp_arc_trip"])
//    TitanLoadouts_Center.append("")
//    TitanLoadouts_Center_Mods.append([])

    TitanLoadouts_Ordnance.append("mp_titanweapon_dumbfire_rockets")
    TitanLoadouts_Ordnance_Mods.append([])
    TitanLoadouts_Ordnance.append("mp_titanweapon_arc_wave")
    TitanLoadouts_Ordnance_Mods.append([])
    TitanLoadouts_Ordnance.append("mp_titanweapon_shoulder_rockets")
    TitanLoadouts_Ordnance_Mods.append(["upgradeCore_MissileRack_Vanguard", "fd_balance"])
    TitanLoadouts_Ordnance.append("mp_titanweapon_laser_lite")
    TitanLoadouts_Ordnance_Mods.append([])
    TitanLoadouts_Ordnance.append("mp_titanweapon_homing_rockets")
    TitanLoadouts_Ordnance_Mods.append([])
    TitanLoadouts_Ordnance.append("mp_titanweapon_laser_lite")
    TitanLoadouts_Ordnance_Mods.append(["tcp_mark_laser"])
//    TitanLoadouts_Special.append("")
//    TitanLoadouts_Special_Mods.append([])
}

void function SaveDataToHttpIO() {
    table data = {
        KC_saved_loudouts = EncodeJSON(players_loadout)
    }
    thread NSHttpPostBody(HTTP_IO_URL + "/write_data", EncodeJSON(data))
}

void function ReadDataFromHttpIO() {
    HttpRequest request
    request.method = HttpRequestMethod.GET
    request.url = HTTP_IO_URL + "/read_data"
    NSHttpRequest( request, ReadResponse, debugFunc )
}

void function debugFunc( HttpRequestFailure response ) {
    printt( "faild to get request / error code:"+ response.errorCode )
    printt( "error message: "+ response.errorMessage )
}

void function ReadResponse(HttpRequestResponse response) {
    printt( "get request / status code:"+ response.statusCode )
    table body = DecodeJSON(response.body)
    if ("KC_saved_loudouts" in body)
        players_loadout = DecodeJSON(body.KC_saved_loudouts)
    else {
        players_loadout.TitanLoadouts_Ordnance <- {}
        players_loadout.TitanLoadouts_Center <- {}
        players_loadout.TitanLoadouts_Special <- {}
        players_loadout.TitanLoadouts_MainWpn <- {}
        SaveDataToHttpIO()
    }
    printt("data: "+EncodeJSON(players_loadout))
}

bool function TeamBalanceCheck() {
	int imcCount = GetPlayerArrayOfTeam( TEAM_IMC ).len();
	int militiaCount = GetPlayerArrayOfTeam(TEAM_MILITIA).len();
	int delta = imcCount - militiaCount;
	return delta < 2 && delta > -2;
}

bool function SwitchCommand(entity player, array<string> args) {
	thread SwitchCommand_Threaded(player, args);
	return true
}

void function SwitchCommand_Threaded(entity player, array<string> args) {
	if (TeamBalanceCheck()) {
		if (!AdminUIDs.contains(player.GetUID())) {
				SendHudMessage( player, "当前队伍已经平衡!",  -1, 0.4, 200, 200, 225, 0, 0.15, 6, 1);
			return
		}
	}

	int imcCount = GetPlayerArrayOfTeam( TEAM_IMC ).len();
	int militiaCount = GetPlayerArrayOfTeam(TEAM_MILITIA).len();
	if (player.GetTeam() == TEAM_MILITIA) {
		if (militiaCount < imcCount && !AdminUIDs.contains(player.GetUID())){
			SendHudMessage( player, "你队友很少欸 不准换队", -1, 0.4, 200, 200, 225, 0, 0.15, 6, 1);
			return;
		} else
			SetTeam(player, TEAM_IMC);
	} else {
		if (imcCount < militiaCount && !AdminUIDs.contains(player.GetUID())){
			SendHudMessage( player, "你队友很少欸 不准换队", -1, 0.4, 200, 200, 225, 0, 0.15, 6, 1);
			return;
		} else
			SetTeam(player, TEAM_MILITIA);
	}
	SendHudMessage( player, "您已切换队伍",  -1, 0.4, 200, 200, 225, 0, 0.15, 6, 1);
}

bool function AdminCommand( entity player, array<string> args )
{
	thread AdminCommand_Threaded( player, args )
	return true
}
void function AdminCommand_Threaded( entity player, array<string> args )
{
	if( !IsValid( player ) )
		return
	if( !AdminUIDs.contains( player.GetUID() ) )
		return
	if( args.len() == 0 )
		return
	switch( args[0] )
	{
		case "dianchi":
		case "battery":
			for( int i = 100; i > 0; i -= 1)
			{
				PlayerInventory_PushInventoryItemByBurnRef( player, "burnmeter_instant_battery" )
			}
			break
		case "fly":
			if ( player.IsNoclipping() )
				player.SetPhysics( MOVETYPE_WALK )
			else
				player.SetPhysics( MOVETYPE_NOCLIP )
			break
		case "st":
			if (player.GetTeam() == TEAM_IMC)
				SetTeam( player, TEAM_MILITIA )
			else if (player.GetTeam() == TEAM_MILITIA)
				SetTeam( player, TEAM_IMC )
				break
		case "god":
			player.SetInvulnerable()
			break
		case "godoff":
			player.ClearInvulnerable()
			break
		case "both":
			if (player.GetTeam() == TEAM_UNASSIGNED )
				SetTeam( player, TEAM_MILITIA )
			else
				SetTeam( player, TEAM_UNASSIGNED )
			break
		case "recharge":
			PlayerEarnMeter_AddEarnedAndOwned( player, 0.0, 100.0 )
			break
		case "speed":
		case "vel":
			if( args.len() < 2 )
				return
			vector velocity = Vector(0,0,0)
			vector angles = player.EyeAngles()
			angles = AnglesToForward( angles )
			velocity += angles * args[1].tointeger()
			player.SetVelocity( velocity )
			break
		case "time":
			if( args.len() < 2 )
				return
			SetServerVar( "gameEndTime", Time() + args[1].tointeger() )
			break
		case "spawnbattery":
			if( args.len() < 3 )
				return
			for( int i = args[1].tointeger(); i > 0; i -= 1 )
			{
				Burnmeter_AmpedBattery( player )
				wait ( float( args[2].tointeger() ) / 10 )
			}
			break
		case "respawn":
			try
			{
				player.RespawnPlayer(FindSpawnPoint(player, false, false))
			} catch(e2) { printt(e2) }
			break
		case "sound":
			if( args.len() < 2 )
				return
			EmitSoundOnEntityOnlyToPlayer( player, player, args[1] )
			break
		case "score":
			if( args.len() < 3 )
				return
			if( args[1] == "1" )
			{
				AddTeamScore( TEAM_IMC, args[2].tointeger() )
			}
			else
			{
				AddTeamScore( TEAM_MILITIA, args[2].tointeger() )
			}
			break
		case "model":
			player.GetMainWeapons()[0].SetModel( $"models/weapons/titan_sniper_rifle/w_titan_sniper_rifle.mdl" )
			break
		case "hp":
			SendHudMessage( player, "maxhealth:"+ player.GetMaxHealth() + "curr:"+ player.GetHealth() , -1, 0.5, 200, 200, 225, 0, 0.15, 6, 1);
			break
		case "info":
			SendHudMessage( player, "angles:"+ player.EyeAngles() +"\norigin:"+ player.EyePosition() , -1, 0.5, 200, 200, 225, 0, 0.15, 6, 1);
			break
		case "rui":
			if( args.len() < 2 )
				return
			NSSendLargeMessageToPlayer(player,"I'm not a dummy >:(", "You are", 1, args[1])
			break
		case "health":
            if (args.len() < 2)
                return
            int hp = args[1].tointeger()
            player.SetMaxHealth( hp )
            player.SetHealth( hp )
			break
		case "slay":
			if (!IsAlive(player))
				return
			player.Die()
			break;
        case "notice":
			if (args.len() < 2)
				return
			foreach (e in GetPlayerArray()){
				SendHudMessage(e, "通知: " + args[1], -1, 0.4, 200, 200, 225, 0, 0.15, 6, 1);
				Chat_ServerPrivateMessage(e, "来自管理员的通知: " + args[1], false);
			}
			break;
		case "skip":
			SetGameState(eGameState.Postmatch);
			break;
	}
}