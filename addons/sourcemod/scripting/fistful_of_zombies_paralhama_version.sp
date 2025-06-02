/**
 * vim: set ts=4 :
 * =============================================================================
 * Fistful Of Zombies
 * Zombie survival for Fistful of Frags
 * New features added by Paralhama + Map Lighting Changer by Nocky
 * Copyright 2016 CrimsonTautology
 * =============================================================================
 *
 */
#pragma semicolon 1
#pragma newdecls optional
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib/clients>
#include <smlib/teams>
#include <smlib/entities>
#include <smlib/weapons>
#include <entitylump>
#include <morecolors>
#undef REQUIRE_EXTENSIONS
#tryinclude <steamworks>

#define MAX_MAPS 64

char Path[PLATFORM_MAX_PATH], MapName[MAX_MAPS][128], LightValue[MAX_MAPS][128];

Handle g_hHudSync;

int loadedMaps;

#define PLUGIN_VERSION "2.0"
#define PLUGIN_NAME "[FoF] Fistful Of Zombies - Paralhama version"

#define DMG_FALL (1 << 5)

#define MAX_KEY_LENGTH 128
#define MAX_TABLE 128
#define INFECTION_LIMIT 100.0
#define VOICE_SCALE 12.0

#define GAME_DESCRIPTION "Fistful Of Zombies"
#define SOUND_ROUNDSTART "music/standoff1.mp3"
#define SOUND_STINGER "music/course_stinger1.wav"
#define SOUND_NOPE "player/voice/no_no1.wav"
#define SOUND_BREATH "player/breath1.wav"

#define TEAM_HUMAN 2  // Vigilantes
#define TEAM_HUMAN_STR "2"
#define INFO_PLAYER_HUMAN "info_player_vigilante"
#define ON_NO_HUMAN_ALIVE "OnNoVigAlive"
#define INPUT_HUMAN_VICTORY "InputVigVictory"

#define COOLDOWN_TIME 0.6 // cooldown attack infected
#define TEAM_ZOMBIE 3  // Desperados
#define TEAM_ZOMBIE_STR "3"
#define INFO_PLAYER_ZOMBIE "info_player_desperado"
#define ON_NO_ZOMBIE_ALIVE "OnNoDespAlive"
#define INPUT_ZOMBIE_VICTORY "InputDespVictory"

ConVar g_EnabledCvar;
ConVar g_ConfigWeaponsCvar;
ConVar g_RoundTimeCvar;
ConVar g_RespawnTimeCvar;
ConVar g_RatioCvar;
ConVar g_InfectionCvar;
ConVar g_Infected_Speed;
ConVar g_Infected_Slow;
ConVar g_Infected_Slow_Time;
ConVar g_Infected_Damage;
ConVar g_Human_Damage;

ConVar g_TeambalanceAllowedCvar;
ConVar g_TeamsUnbalanceLimitCvar;
ConVar g_AutoteambalanceCvar;

KeyValues g_GearPrimaryTable;
int g_GearPrimaryTotalWeight;
bool g_GivenPrimary[MAXPLAYERS+1] = {false, ...};

bool g_human_transformation_message[MAXPLAYERS+1] = {false, ...};

KeyValues g_GearSecondaryTable;
int g_GearSecondaryTotalWeight;
bool g_GivenSecondary[MAXPLAYERS+1] = {false, ...};

KeyValues g_LootTable;
int g_LootTotalWeight;

int g_TeamplayEntity = INVALID_ENT_REFERENCE;
bool g_AutoSetGameDescription = false;

int g_VigilanteModelIndex;
int g_DesperadoModelIndex;
int g_BandidoModelIndex;
int g_RangerModelIndex;
int g_ZombieModelIndex;

float g_flLastAttack[MAXPLAYERS+1]; // Armazena o tempo do último ataque primário
float g_flLastAttack2[MAXPLAYERS+1]; // Armazena o tempo do último ataque secundário
bool g_SoundAttack[MAXPLAYERS+1] = {false, ...}; // Usando a nova sintaxe para booleanos
float currentTime; // Declarando uma variável de ponto flutuante corretamente

int g_PVMid[MAXPLAYERS+1]; // Predicted ViewModel ID's
int g_iClawModel;    // Custom ViewModel index

int LastPlayerToThrowObject[2049] = {-1, ...};
int oldButtons[MAXPLAYERS+1] = {0, ...};

// ######### GLOW WEAPONS ##########
Handle AddGlowServerSDKCall;
// ######### GLOW WEAPONS ##########

// a priority scaling for assigning to the human team;  a higher value has a
// higher priority for joining humans.
int g_HumanPriority[MAXPLAYERS+1] = {0, ...};

enum FoZRoundState
{
    RoundPre,
    RoundGrace,
    RoundActive,
    RoundEnd
}
FoZRoundState g_RoundState = RoundPre;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology, Paralhama and Nocky",
    description = "Zombie Survival for Fistful of Frags. New features added by Paralhama: Map Lighting Changer by Nocky + Glow enable on weapons by Backwards and other cool things :)",
    version = PLUGIN_VERSION,
    url = "https://github.com/paralhama/sm-fistful-of-zombies"
};

public void OnPluginStart()
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamagePlayer);

	g_hHudSync = CreateHudSynchronizer();
	if (g_hHudSync == INVALID_HANDLE)
	{
		SetFailState("Failed to create HUD synchronizer");
	}

	AutoExecConfig(true, "fof_zombies_config");
	LoadTranslations("fistful_of_zombies.phrases");

	CreateConVar("foz_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_EnabledCvar = CreateConVar("foz_enabled", "1", "Whether or not Fistful of Zombies is enabled", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_ConfigWeaponsCvar = CreateConVar("foz_config_weapons", "configs/fistful_of_zombies_weapons.txt", "Weapon loot configuration file location", 0);

	g_RoundTimeCvar = CreateConVar("foz_round_time", "120", "How long survivors have to survive in seconds to win a round in Fistful of Zombies", FCVAR_NOTIFY, true, 0.0);

	g_RespawnTimeCvar = CreateConVar("foz_respawn_time", "15", "How long zombies have to wait before respawning in Fistful of Zombies", FCVAR_NOTIFY, true, 0.0);

	g_RatioCvar = CreateConVar("foz_ratio", "0.65", "Percentage of players that start as human.", FCVAR_NOTIFY, true, 0.01, true, 1.0);

	g_InfectionCvar = CreateConVar("foz_infection", "0.50", "Chance that a human will be infected when punched by a zombie. Value is scaled such that more human players increase the chance", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_Infected_Speed = CreateConVar("foz_infected_speed", "280.0", "Change the max speed for a infected player", FCVAR_NOTIFY, true, 255.0, true, 320.0);

	g_Infected_Slow = CreateConVar("foz_infected_slow", "100.0", "Change the max speed for an infected player when receive damage", FCVAR_NOTIFY, true, 0.0, true, 320.0);

	g_Infected_Slow_Time = CreateConVar("foz_infected_slow_time", "1.0", "Seconds that the infected player will be slowed when taking damage", FCVAR_NOTIFY, true, 0.5, true, 2.0);

	g_Infected_Damage = CreateConVar("foz_infected_damage", "0.50", "Set the damage multiplier that human players deal to infected, lower values than 1.0 reduce damage (example, 0.50 means half damage). HEAD DAMAGE ON INFECTED PLAYERS IS ALWAYS 1.0, AS PER GAME STANDARD.", FCVAR_NOTIFY, true, 0.10, true, 1.0);

	g_Human_Damage = CreateConVar("foz_human_damage", "1.5", "Set the damage multiplier that infected players deal to humans. (1.0 is the game standart and 2.0 means double damage)", FCVAR_NOTIFY, true, 1.0, true, 2.0);

	g_TeambalanceAllowedCvar = FindConVar("fof_sv_teambalance_allowed");
	g_TeamsUnbalanceLimitCvar = FindConVar("mp_teams_unbalance_limit");
	g_AutoteambalanceCvar = FindConVar("mp_autoteambalance");

	HookEvent("hatshot", OnHatShot, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);

	RegAdminCmd("foz_reload", Command_Reload, ADMFLAG_CONFIG, "Force a reload of the configuration file");

	RegAdminCmd("foz_dump", Command_Dump, ADMFLAG_ROOT, "Debug: Output information about the current game to console");

	AddCommandListener(Command_JoinTeam, "jointeam");

	AddNormalSoundHook(SoundCallback);

	SetDefaultConVars();
	InitializeFistfulOfZombies();

// ######### GLOW WEAPONS ##########
	Handle hConf = LoadGameConfigFile("gamedata_fistful_of_zombies");

	if (hConf == null)
		SetFailState("hConf == null");

	StartPrepSDKCall(SDKCall_Entity); //SDKCall_Raw
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "Glow");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	AddGlowServerSDKCall = EndPrepSDKCall();

	if (AddGlowServerSDKCall == INVALID_HANDLE)
		SetFailState("Failed to create Call for AddGlowServer");

	CreateTimer(0.5, EnableWeaponsGlowOnMap, _, TIMER_REPEAT);
// ######### GLOW WEAPONS ##########
}

// ######### GLOW WEAPONS ##########

public Action EnableWeaponsGlowOnMap(Handle timer, any iGrenade)
{
	int weapon = INVALID_ENT_REFERENCE;

	while((weapon = FindEntityByClassname(weapon, "weapon_*")) != INVALID_ENT_REFERENCE)
	{
        // Verifica se tem a propriedade de dono
        if(!HasEntProp(weapon, Prop_Send, "m_hOwnerEntity"))
            continue;
            
        // Se NÃO tem dono (owner == -1), então a arma está no chão
        if(GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") == -1)
        {
            AddGlowServer(weapon);
        }
	}
}

public void AddGlowServer(int entity)
{
    SDKCall(AddGlowServerSDKCall, entity);
}

// ######### GLOW WEAPONS ##########

public Action OnHatShot(Handle event, const char[] name, bool dontBroadcast)
{
	SetEventBroadcast(event, true);
	return Plugin_Changed;
}



public void OnClientPutInServer(int client)
{
	if (!IsEnabled()) return;

	SetDefaultConVars();
	SDKHook(client, SDKHook_WeaponCanUse, Hook_OnWeaponCanUse);
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	SDKHook(client, SDKHook_TraceAttack, Infected_Damage_Filter);

	g_HumanPriority[client] = 0;

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamagePlayer);
}

public void OnMapStart()
{
	RemoveCrates();
	CreateTimer(1.0, ChangeLight);
	if (!IsEnabled()) return;

	char tmp[PLATFORM_MAX_PATH];

	// cache materials
	PrecacheSound(SOUND_ROUNDSTART, true);
	PrecacheSound(SOUND_STINGER, true);
	PrecacheSound(SOUND_NOPE, true);

	// precache zombie sounds
	for (int i = 1; i <= 3; i++)
	{
		Format(tmp, sizeof(tmp), "npc/zombie/foot%d.wav", i);
		PrecacheSound(tmp, true);
	}

	for (int i = 1; i <= 14; i++)
	{
		Format(tmp, sizeof(tmp), "npc/zombie/moan-%02d.wav", i);
		PrecacheSound(tmp, true);
	}

	for (int i = 1; i <= 4; i++)
	{
		Format(tmp, sizeof(tmp), "npc/zombie/zombie_chase-%d.wav", i);
		PrecacheSound(tmp, true);
	}

	for (int i = 1; i <= 4; i++)
	{
		Format(tmp, sizeof(tmp), "npc/zombie/moan_loop%d.wav", i);
		PrecacheSound(tmp, true);
	}

	for (int i = 1; i <= 2; i++)
	{
		Format(tmp, sizeof(tmp), "npc/zombie/claw_miss%d.wav", i);
		PrecacheSound(tmp, true);
	}

	for (int i = 1; i <= 3; i++)
	{
		Format(tmp, sizeof(tmp), "npc/zombie/claw_strike%d.wav", i);
		PrecacheSound(tmp, true);
	}

	for (int i = 1; i <= 3; i++)
	{
		Format(tmp, sizeof(tmp), "npc/zombie/zombie_die%d.wav", i);
		PrecacheSound(tmp, true);
	}

	PrecacheSound("vehicles/train/whistle.wav", true);
	PrecacheSound("player/fallscream1.wav", true);
	PrecacheSound("player/breath1.wav", true);

	g_VigilanteModelIndex = PrecacheModel("models/playermodels/player1.mdl");
	g_DesperadoModelIndex = PrecacheModel("models/playermodels/player2.mdl");
	g_BandidoModelIndex = PrecacheModel("models/playermodels/bandito.mdl");
	g_RangerModelIndex = PrecacheModel("models/playermodels/frank.mdl");
	g_ZombieModelIndex = PrecacheModel("models/fof_skins_v3/players/infected/infected.mdl"); // Infected players model
	g_iClawModel = PrecacheModel("models/fof_skins_v3/players/infected/arms/infected_fists.mdl"); // infected claws view model

	// initial setup
	ConvertSpawns();
	KillWeaponSpawn();
	g_TeamplayEntity = SpawnZombieTeamplayEntity();
	g_AutoSetGameDescription = true;

	SetRoundState(RoundPre);

	CreateTimer(1.0, Timer_Repeat, .flags = TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.001, Timer_SetConvars, .flags = TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPostAdminCheck(int client){
    SDKHook(client, SDKHook_WeaponSwitchPost, OnClientWeaponSwitchPost);    
}

public void OnClientWeaponSwitchPost(int client, int wpnid)
{
    
    char szWpn[MAX_KEY_LENGTH];
    GetEntityClassname(wpnid,szWpn,sizeof(szWpn));
    
    if(StrEqual(szWpn, "weapon_fists")  && IsZombie(client) && IsClientInGame(client) && IsPlayerAlive(client))
	{
        SetEntProp(wpnid, Prop_Send, "m_nModelIndex", 0);
        // Somente modifica se a entidade for válida
        if(IsValidEntity(g_PVMid[client]))
        {
            SetEntProp(g_PVMid[client], Prop_Send, "m_nModelIndex", g_iClawModel);
        }
    }
}

public void OnConfigsExecuted()
{
	LoadConfig();

	if (!IsEnabled()) return;

	SetGameDescription(GAME_DESCRIPTION);
	SetDefaultConVars();
	InitializeFistfulOfZombies();
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsEnabled()) return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsZombie(client))
	{
		g_PVMid[client] = Weapon_GetViewModelIndex2(client, -1);
    }

	SetDefaultConVars();
	int userid = event.GetInt("userid");
	CreateTimer(0.5, RemoveHatTimer, _, TIMER_REPEAT);
	RequestFrame(PlayerSpawnDelay, userid);
}


stock int GetSO()
{
     Handle hConf = LoadGameConfigFile("gamedata_fistful_of_zombies");
     int WindowsOrLinux = GameConfGetOffset(hConf, "WindowsOrLinux");
     CloseHandle(hConf);
     return WindowsOrLinux; // 1 para Windows; 2 para Linux
}

public Action RemoveHatTimer(Handle timer, any iGrenade)
{
	for(int i = 0 + 1;i < MaxClients+1;i++)
	{
		if(IsValidEntity(i) && IsValidEdict(i))
		{
			if(IsPlayerAlive(i) && IsZombie(i))
				RemoveHat(i);
		}
	}
	
	return Plugin_Continue;
}

void RemoveHat(int client)
{
	int SO = GetSO();

	int hatlessOffset = 0;
	
	// Verifica se o sistema é Windows ou Linux
	if (SO == 1)
		hatlessOffset = 4980;
	else
		hatlessOffset = 5000;
		
	SetEntData(client, hatlessOffset, 0, 4, true);
	// SetEntProp(client, Prop_Data, "m_nBody", 1); //Set the BodyGroup player model
	SetEntProp(client, Prop_Send, "m_nHitboxSet", 1);
}

// Get model index and prevent server from crash
int Weapon_GetViewModelIndex2(int client, int sIndex)
{
	while ((sIndex = FindEntityByClassname2(sIndex, "predicted_viewmodel")) != -1)
	{
		int Owner = GetEntPropEnt(sIndex, Prop_Send, "m_hOwner");
		
		if (Owner != client)
			continue;
		
		return sIndex;
	}
	return -1;
}
// Get entity name
int FindEntityByClassname2(int sStartEnt, const char[] szClassname)
{
    while (sStartEnt > -1 && !IsValidEntity(sStartEnt)) sStartEnt--;
    return FindEntityByClassname(sStartEnt, szClassname);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsEnabled()) return;

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	// a dead human becomes a zombie
	if (IsHuman(client))
	{
		// announce the infection
		char PlayerName[256];
		GetClientName(client, PlayerName, sizeof(PlayerName));
		EmitSoundToAll(SOUND_STINGER, .flags = SND_CHANGEPITCH, .pitch = 80);

		RequestFrame(BecomeZombieDelay, userid);
	}
	RemoveCrates();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsEnabled()) return;

    SetRoundState(RoundGrace);
    CreateTimer(10.0, Timer_EndGrace, TIMER_FLAG_NO_MAPCHANGE);

    WeaponSpawn(g_LootTable, g_LootTotalWeight);
    RemoveCrates();
    RemoveTeamplayEntities();
    RandomizeTeams();
    SetDefaultConVars();
    // Criar um timer para mostrar as mensagens após um pequeno delay
    CreateTimer(0.5, Timer_ShowRoundStartMessages, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ShowRoundStartMessages(Handle timer)
{
	if (g_hHudSync == INVALID_HANDLE) return Plugin_Stop;

	// Loop através de todos os clientes
	for (int client = 1; client <= MaxClients; client++)
	{
		g_human_transformation_message[client] = false;

		if (!IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client))
			continue;

		// Configurar os parâmetros do HUD uma vez
		// SetHudTextParams(0.02, 0.4, 10.0, 255, 255, 255, 255, 0, 0.5, 0.5, 0.5);

		if (IsHuman(client))
		{
			SetHudTextParams(0.02, 0.4, 10.0, 60, 118, 226, 255, 0, 0.5, 0.5, 0.5);
			ShowSyncHudText(client, g_hHudSync, "%t", "Survive the Infected attack");
		}
		else if (IsZombie(client))
		{
			SetHudTextParams(0.02, 0.4, 10.0, 255, 61, 61, 255, 0, 0.5, 0.5, 0.5);
			ShowSyncHudText(client, g_hHudSync, "%t", "Find, attack, and infect the humans");
		}
	}

	return Plugin_Stop;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsEnabled()) return;

    SetRoundState(RoundEnd);
    RewardSurvivingHumans();
}

Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsEnabled()) return Plugin_Continue;

    int userid = event.GetInt("userid");
    int team = event.GetInt("team");

    event.BroadcastDisabled = true;

    // if A player joins in late as a human force them to be a zombie
    if (team == TEAM_HUMAN && GetRoundState() == RoundActive)
    {
        RequestFrame(BecomeZombieDelay, userid);
        return Plugin_Handled;
    }

    if (team == TEAM_ZOMBIE && GetRoundState() == RoundPre)
    {
        ChangeClientTeam(userid, TEAM_HUMAN);
    }

    return Plugin_Continue;
}

void PlayerSpawnDelay(int userid)
{
    int client = GetClientOfUserId(userid);

    if (!IsEnabled()) return;
    if (!IsClientIngame(client)) return;
    if (!IsPlayerAlive(client)) return;

    g_GivenPrimary[client] = false;
    g_GivenSecondary[client] = false;

    if (GetRoundState() == RoundPre)
    {
        ChangeClientTeam(client, TEAM_HUMAN);
        StripWeapons_RoundPre(client);
        KillWeaponSpawn();
    }

    if (IsHuman(client))
    {
        RandomizeModel(client);

        // if a player spawns as human give them their primary and secondary
        // gear
        CreateTimer(0.5, Timer_GiveSecondaryWeapon, userid, TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(0.9, Timer_GivePrimaryWeapon, userid, TIMER_FLAG_NO_MAPCHANGE);

        //PrintCenterText(client, "Survive the zombie plague!");
    }
	else if (IsZombie(client))
	{
		// force client model
		RandomizeModel(client);
		StripWeapons(client);
		FakeClientCommandEx(client, "use weapon_fists");
		EmitZombieYell(client);
		CreateTimer(0.1, SetMaxSpeedInfected, userid, TIMER_FLAG_NO_MAPCHANGE);
		//PrintCenterText(client, "Ughhhh..... BRAINNNSSSS");
	}
}

Action SetMaxSpeedInfected(Handle timer, int userid)
{
	float MaxSpeed = g_Infected_Speed.FloatValue;

	int client = GetClientOfUserId(userid);
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", MaxSpeed ); 
	ChangeEdictState(client, GetEntSendPropOffs(client, "m_flMaxspeed"));
	return Plugin_Handled;
}

void BecomeZombieDelay(int userid)
{
    int client = GetClientOfUserId(userid);

    if (!IsEnabled()) return;
    if (!IsClientIngame(client)) return;
    if (GetRoundState() == RoundPre) return;

    JoinZombieTeam(client);
}

Action Timer_GivePrimaryWeapon(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!IsEnabled()) return Plugin_Handled;
    if (!IsClientIngame(client)) return Plugin_Handled;
    if (IsZombie(client)) return Plugin_Handled;
    if (g_GivenPrimary[client]) return Plugin_Handled;
    char weapon[MAX_KEY_LENGTH];

    if (GetRoundState() != RoundPre)
    {
		GetRandomValueFromTable(g_GearPrimaryTable, g_GearPrimaryTotalWeight,
				weapon, sizeof(weapon));
		GivePlayerItem(client, weapon);
		UseWeapon(client, weapon);

		g_GivenPrimary[client] = true;
    }

    return Plugin_Handled;
}

Action Timer_GiveSecondaryWeapon(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!IsEnabled()) return Plugin_Handled;
    if (!IsClientIngame(client)) return Plugin_Handled;
    if (IsZombie(client)) return Plugin_Handled;
    if (g_GivenSecondary[client]) return Plugin_Handled;

    char weapon[MAX_KEY_LENGTH];


    if (GetRoundState() != RoundPre)
    {
		GetRandomValueFromTable(g_GearSecondaryTable, g_GearSecondaryTotalWeight,
				weapon, sizeof(weapon));
		GivePlayerItem(client, weapon);
		UseWeapon(client, weapon, true);

		g_GivenSecondary[client] = true;
	}

    return Plugin_Handled;
}

Action Timer_EndGrace(Handle timer)
{
    SetRoundState(RoundActive);
    return Plugin_Continue;
}


Action Timer_SetConvars(Handle timer)
{
    SetDefaultConVars();
    return Plugin_Continue;
}

Action Timer_Repeat(Handle timer)
{
	if (!IsEnabled())
		return Plugin_Continue;

	// NOTE: Spawning a teamplay entity seems to now change game description to
	// Teamplay. Need to re-set game description back to zombies next iteration.
	if (g_AutoSetGameDescription)
	{
		SetGameDescription(GAME_DESCRIPTION);
		g_AutoSetGameDescription = false;
	}

	SetDefaultConVars();
	RoundEndCheck();

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;

		if (IsHuman(client))
		{
		// no-op
		}
		else if (IsZombie(client))
		{
			StripWeapons(client);
			FakeClientCommandEx(client, "use weapon_fists");
		}
	}

	return Plugin_Handled;
}


Action Hook_OnWeaponCanUse(int client, int weapon)
{
	if (!IsEnabled()) return Plugin_Continue;

	char class[MAX_KEY_LENGTH];
	GetEntityClassname(weapon, class, sizeof(class));

	// block zombies from picking up guns
	if (IsZombie(client) && !StrEqual(class, "weapon_fists"))
	{
		EmitSoundToClient(client, SOUND_NOPE);
		CPrintToChat(client, "%t", "Zombies Can Not Use Guns");

		return Plugin_Handled;
	}

	return Plugin_Continue;
}


Action Hook_OnTakeDamage(int victim, int& attacker, int& inflictor,
                         float& damage, int& damagetype, int& weapon, 
                         float damageForce[3], float damagePosition[3])
{
	if (!IsEnabled())
		return Plugin_Continue;

	if (!IsClientIngame(victim))
		return Plugin_Continue;

	// For infected:
	if (IsZombie(victim))
	{
		// Cancel non-lethal fall damage
		if (damagetype & DMG_FALL)
		{
			float DamageSlow = g_Infected_Slow.FloatValue;
			float SlowTime = g_Infected_Slow_Time.FloatValue;
			if (damage <= 100.0)
			{
				// Se nenhuma dessas palavras estiver presente, altere a velocidade máxima do jogador para 100.0
				SetEntPropFloat(victim, Prop_Send, "m_flMaxspeed", DamageSlow);

				// Notificar o motor do jogo sobre a mudança de estado
				ChangeEdictState(victim, GetEntSendPropOffs(victim, "m_flMaxspeed"));

				// Iniciar um temporizador para restaurar a velocidade
				CreateTimer(SlowTime, ResetPlayerSpeed, victim);		
				return Plugin_Handled;
			}
		}

		return Plugin_Continue;
	}

	if (attacker == victim)
		return Plugin_Continue;

	if (!IsClientIngame(attacker))
		return Plugin_Continue;

	// For humans:
	if (IsZombie(attacker))
	{
		// Random chance to be infected when attacked by infected
		if (weapon <= 0)
			return Plugin_Continue;

		char classname[16];
		GetEntityClassname(weapon, classname, sizeof(classname));
		if (StrEqual(classname, "weapon_fists"))
		{
			if (InfectionChanceRoll())
			{
				BecomeInfected(victim);
			}
		}
	}
	else
	{
		// Reduce damage of friendly-fire
		damage = float(RoundToCeil(damage / 10.0));
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

// Função chamada quando o evento player_hurt é acionado
public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	char weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsHuman(victim))
	{
		if (StrEqual(weapon, "kick"))
		{
			if (InfectionChanceRoll())
			{
				BecomeInfected(victim);
			}
		}
	}


	if (IsZombie(victim))
	{
		// Verificar se a arma não contém as strings específicas
		if (StrContains(weapon, "x_arrow", false) == -1 &&
		StrContains(weapon, "physics", false) == -1 &&
		StrContains(weapon, "prop_dynamic", false) == -1 &&
		StrContains(weapon, "dynamite", false) == -1 &&
		StrContains(weapon, "kick", false) == -1 &&
		StrContains(weapon, "blast", false) == -1)
		{
			float DamageSlow = g_Infected_Slow.FloatValue;
			float SlowTime = g_Infected_Slow_Time.FloatValue;

			// Se nenhuma dessas palavras estiver presente, altere a velocidade máxima do jogador para 100.0
			SetEntPropFloat(victim, Prop_Send, "m_flMaxspeed", DamageSlow);

			// Notificar o motor do jogo sobre a mudança de estado
			ChangeEdictState(victim, GetEntSendPropOffs(victim, "m_flMaxspeed"));

			// Iniciar um temporizador para restaurar a velocidade
			CreateTimer(SlowTime, ResetPlayerSpeed, victim);		
		}
	}

	return Plugin_Continue;
}

public Action OnTakeDamagePlayer(int entity, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    char entname[64], entname2[64], modelname[128];
    
    GetEntityClassname(attacker, entname, sizeof(entname));
    GetEntityClassname(inflictor, entname2, sizeof(entname2));
    
    if(strcmp(entname, "entityflame") == 0 && strcmp(entname2, "prop_physics_respawnable") == 0)
    {
        // Verifica o modelo do prop
        GetEntPropString(inflictor, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
        
        // Verifica se é o barril explosivo
        if(StrContains(modelname, "barrel2_explosive", false) != -1 || StrContains(modelname, "barrel1_explosive", false) != -1)
        {
            if(LastPlayerToThrowObject[inflictor] != -1 && IsClientInGame(LastPlayerToThrowObject[inflictor]))
            {
                attacker = LastPlayerToThrowObject[inflictor];
                // Mantem o inflictor como o barril
                damagetype |= DMG_BLAST; // Adiciona o tipo de dano de explosão
                return Plugin_Changed;
            }
        }
    }
    
    return Plugin_Continue;
}

// Função para restaurar a velocidade do jogador para 300.0
public Action ResetPlayerSpeed(Handle timer, any client)
{
	if (IsClientInGame(client) && IsZombie(client))
	{
		float MaxSpeed = g_Infected_Speed.FloatValue;

		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", MaxSpeed);
		ChangeEdictState(client, GetEntSendPropOffs(client, "m_flMaxspeed"));
	}
	return Plugin_Stop;
}

public Action Infected_Damage_Filter(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    // Primeiro, validamos se os índices são válidos
    if (!IsValidClient(attacker) || !IsValidClient(victim))
    {
        return Plugin_Continue; // Se não forem válidos, deixa o dano passar normalmente
    }
    
    // Agora podemos checar as condições com segurança
    if (IsHuman(attacker) && IsZombie(victim))
    {
        if (hitgroup != 1)
        {
            float InfecteDamage = g_Infected_Damage.FloatValue;
            damage *= InfecteDamage;
        }
    }
    
    if (IsZombie(attacker) && IsHuman(victim))
    {
        float HumanDamage = g_Human_Damage.FloatValue;
        if (damagetype & DMG_CLUB)
        {
            damage *= HumanDamage;
        }
    }
    
    return Plugin_Changed;
}


public void OnMapInit(const char[] mapName)
{
    // Itera sobre todas as entradas de entidades no mapa
    for (int i = 0; i < EntityLump.Length(); i++) 
    {
        EntityLumpEntry entry = EntityLump.Get(i);
        
        char classname[32];
        // Obtém o nome da classe da entidade
        if (entry.GetNextKey("classname", classname, sizeof(classname)) == -1) continue;

        // Verifica se a entidade é trigger_hurt, trigger_hurt_fof ou prop_physics_respawnable
        if (StrEqual(classname, "trigger_hurt") || StrEqual(classname, "trigger_hurt_fof"))
        {
            // Verifica se o tipo de dano é FALL antes de modificar
            char CurrentDamageType[32];
            if (entry.GetNextKey("damagetype", CurrentDamageType, sizeof(CurrentDamageType)) != -1 && (StrEqual(CurrentDamageType, "32")))
            {
				// Atualiza o tipo de dano para 0
				int damageTypeIndex = entry.FindKey("damagetype", -1);
				if (damageTypeIndex != -1)
				{
					entry.Update(damageTypeIndex, "damagetype", "0");
				}

				// Atualiza o dano para 999
				int damageIndex = entry.FindKey("damage", -1);
				if (damageIndex != -1)
				{
					entry.Update(damageIndex, "damage", "999");
				}
			}
        }
        else if (StrEqual(classname, "prop_physics_respawnable"))
		{
			// Verifica se a chave "model" contém "FurnitureDresser", "wood_crate"
			char modelValue[MAX_KEY_LENGTH];
			if (entry.GetNextKey("model", modelValue, sizeof(modelValue)) != -1 &&
				(StrContains(modelValue, "FurnitureDresser") != -1 || 
				 StrContains(modelValue, "wood_crate") != -1 ||
				 StrContains(modelValue, "barrel1_explosive") != -1))
			{
				// Atualiza o modelo para "models/elpaso/barrel2_explosive.mdl"
				int modelIndex = entry.FindKey("model", -1);
				if (modelIndex != -1)
				{
					entry.Update(modelIndex, "model", "models/elpaso/barrel2_explosive.mdl");
				}

				// Atualiza o tempo de respawn para 30
				int respawnTimeIndex = entry.FindKey("RespawnTime", -1);
				if (respawnTimeIndex != -1)
				{
					entry.Update(respawnTimeIndex, "RespawnTime", "30");
				}

				// Atualiza o spawnflags para 0
				int spawnflagsIndex = entry.FindKey("spawnflags", -1);
				if (spawnflagsIndex != -1)
				{
					entry.Update(spawnflagsIndex, "spawnflags", "0");
				}

				// Atualiza fademindist para -1
				int fademindistIndex = entry.FindKey("fademindist", -1);
				if (fademindistIndex != -1)
				{
					entry.Update(fademindistIndex, "fademindist", "-1");
				}

				// Atualiza fademaxdist para 0
				int fademaxdistIndex = entry.FindKey("fademaxdist", -1);
				if (fademaxdistIndex != -1)
				{
					entry.Update(fademaxdistIndex, "fademaxdist", "0");
				}

			}
		}

        else if (StrEqual(classname, "worldspawn"))
        {
            // Atualiza o skyname para "fof05"
            int skynameIndex = entry.FindKey("skyname", -1);
            if (skynameIndex != -1)
            {
                entry.Update(skynameIndex, "skyname", "fof05");
            }
		}
	}
}

Action Command_JoinTeam(int client, const char[] command, int argc)
{
    if (!IsEnabled()) return Plugin_Continue;
    if (!IsClientIngame(client)) return Plugin_Continue;

    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));

    if (GetRoundState() == RoundPre)
    {
        // block players switching to humans
        if (StrEqual(arg, TEAM_ZOMBIE_STR, false) ||
                StrEqual(arg, "auto", false))
        {
			ChangeClientTeam(client, TEAM_HUMAN);
        }
    }

    if (GetRoundState() == RoundGrace)
    {
        // block players switching to humans
        if (StrEqual(arg, TEAM_HUMAN_STR, false) ||
                StrEqual(arg, "auto", false))
        {
            EmitSoundToClient(client, SOUND_NOPE);
            CPrintToChat(client, "%t", "You cannot change teams");
            return Plugin_Handled;
        }
    }

    if (GetRoundState() == RoundActive)
    {
        // if attempting to join human team or random then join zombie team
        if (StrEqual(arg, TEAM_HUMAN_STR, false) ||
                StrEqual(arg, "auto", false))
        {
            return Plugin_Handled;
        }
        // if attempting to join zombie team or spectator, let them
        else if (StrEqual(arg, TEAM_ZOMBIE_STR, false) ||
                StrEqual(arg, "spectate", false))
        {
            return Plugin_Continue;
        }
        // prevent joining any other team
        else
        {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

Action SoundCallback(int clients[MAXPLAYERS], int &numClients,
        char sample[PLATFORM_MAX_PATH], int &entity, int &channel,
        float &volume, int &level, int &pitch, int &flags,
        char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (0 < entity <= MaxClients)
    {
        // change the voice of zombie players
        if (IsZombie(entity))
        {
            // change to zombie footsteps
            if (StrContains(sample, "player/footsteps") == 0)
            {
                Format(sample, sizeof(sample), "npc/zombie/foot%d.wav", GetRandomInt(1, 3));
                return Plugin_Changed;
            }

            // change zombie punching
            if (StrContains(sample, "weapons/fists/fists_punch") == 0)
            {
				g_SoundAttack[entity] = true;
				Format(sample, sizeof(sample), "npc/zombie/claw_strike%d.wav", GetRandomInt(1, 3));
				return Plugin_Changed;
            }
			else
			{
				g_SoundAttack[entity] = false;
			}

            // change zombie punch missing
            if (StrContains(sample, "weapons/fists/fists_miss") == 0)
            {
				g_SoundAttack[entity] = true;
				Format(sample, sizeof(sample), "npc/zombie/claw_miss%d.wav", GetRandomInt(1, 2));
				return Plugin_Changed;
            }
			else
			{
				g_SoundAttack[entity] = false;
			}

            // change zombie death sound
            if (StrContains(sample, "player/voice/pain/pl_death") == 0 ||
                    StrContains(sample, "player/voice2/pain/pl_death") == 0 ||
                    StrContains(sample, "player/voice4/pain/pl_death") == 0 ||
                    StrContains(sample, "npc/mexican/death") == 0)
            {
                Format(sample, sizeof(sample), "npc/zombie/zombie_die%d.wav", GetRandomInt(1, 3));
                return Plugin_Changed;
            }

            if (StrContains(sample, "player/voice") == 0 ||
                    StrContains(sample, "npc/mexican") == 0)
            {
                Format(sample, sizeof(sample), "npc/zombie/moan-%02d.wav", GetRandomInt(1, 14));
                return Plugin_Changed;
            }
        }
    }
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon)
{
    // Pega o tempo atual do jogo (Declara a variável Float no escopo correto)
    currentTime = GetGameTime();

    // Verifica o ataque primário (IN_ATTACK)
    if (buttons & IN_ATTACK && IsZombie(client) && IsClientInGame(client) && IsPlayerAlive(client))
    {
        // Se o tempo desde o último ataque for menor que o cooldown, cancela o ataque
        if (currentTime - g_flLastAttack[client] < COOLDOWN_TIME)
        {
			buttons &= ~IN_ATTACK; // Desativa o ataque
			g_flLastAttack2[client] = currentTime;
        }
        else
        {
			// Se já passou o tempo de cooldown, atualiza o tempo do último ataque
			g_flLastAttack[client] = currentTime;
			if (g_SoundAttack[client])
			{
				SetEntProp(g_PVMid[client], Prop_Send, "m_nSequence", 5); // linha 1102
			}
			else
			{
				SetEntProp(g_PVMid[client], Prop_Send, "m_nSequence", 0); // linha 1106
			}
        }
    }

    // Verifica o ataque secundário (IN_ATTACK2)
    if (buttons & IN_ATTACK2 && IsZombie(client) && IsClientInGame(client) && IsPlayerAlive(client))
    {
        // Se o tempo desde o último ataque secundário for menor que o cooldown, cancela o ataque
        if (currentTime - g_flLastAttack2[client] < COOLDOWN_TIME)
        {
			buttons &= ~IN_ATTACK2; // Desativa o ataque secundário
			g_flLastAttack[client] = currentTime;
        }
        else
        {
			// Se já passou o tempo de cooldown, atualiza o tempo do último ataque secundário
			g_flLastAttack2[client] = currentTime;
			if (g_SoundAttack[client])
			{
				SetEntProp(g_PVMid[client], Prop_Send, "m_nSequence", 4); // linhas 1126
			}
			else
			{
				SetEntProp(g_PVMid[client], Prop_Send, "m_nSequence", 0); //linha 1130
			}
        }
    }

	// Code for infected to throw flaming barrels
    if (buttons & IN_SPEED && !(oldButtons[client] & IN_SPEED) && IsZombie(client))
    {
        int item = GetEntPropEnt(client, Prop_Send, "m_hAttachedObject");    
        
        if(IsValidEntity(item))
        {
            char classname[64], modelname[128];
            GetEntityClassname(item, classname, sizeof(classname));
            
            // Verifica se é um prop_physics_respawnable
            if(strcmp(classname, "prop_physics_respawnable") == 0)
            {
                // Verifica o modelo
                GetEntPropString(item, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
                
                // Se for o barril explosivo
                if(StrContains(modelname, "barrel2_explosive", false) != -1 || StrContains(modelname, "barrel1_explosive", false) != -1)
                {
                    LastPlayerToThrowObject[item] = client;
                    AcceptEntityInput(item, "Ignite", client, client);
                }
            }
        }
    }

    oldButtons[client] = buttons;
    return Plugin_Continue;
}

Action Command_Dump(int caller, int args)
{
    char tmp[32];
    int team, health;
    PrintToConsole(caller, "---------------------------------");
    PrintToConsole(caller, "RoundState: %d", g_RoundState);
    PrintToConsole(caller, "TEAM_ZOMBIE: %d, TEAM_HUMAN: %d", TEAM_ZOMBIE, TEAM_HUMAN);
    PrintToConsole(caller, "---------------------------------");
    PrintToConsole(caller, "team          health pri user");
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client)) continue;

        team = GetClientTeam(client);
        health = Entity_GetHealth(client);
        Team_GetName(team, tmp, sizeof(tmp));

        PrintToConsole(caller, "%13s %6d %3d %L",
                tmp,
                health,
                g_HumanPriority[client],
                client
                );
    }
    PrintToConsole(caller, "---------------------------------");
    return Plugin_Handled;
}

Action Command_Reload(int caller, int args)
{
    InitializeFistfulOfZombies();
    return Plugin_Handled;
}

void InitializeFistfulOfZombies()
{
    // load configuration weapons
    char file[PLATFORM_MAX_PATH];
    g_ConfigWeaponsCvar.GetString(file, sizeof(file));

    KeyValues config = LoadFistfulOfZombiesFile(file);

    delete g_LootTable;
    g_LootTable = BuildWeightTable(
            config, "loot", g_LootTotalWeight);

    delete g_GearPrimaryTable;
    g_GearPrimaryTable = BuildWeightTable(
            config, "gear_primary", g_GearPrimaryTotalWeight);

    delete g_GearSecondaryTable;
    g_GearSecondaryTable = BuildWeightTable(
            config, "gear_secondary", g_GearSecondaryTotalWeight);

    delete config;
}

KeyValues LoadFistfulOfZombiesFile(const char[] file)
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), file);
    WriteLog("LoadFistfulOfZombiesFile %s", path);

    KeyValues config = new KeyValues("fistful_of_zombies_weapons");
    if (!config.ImportFromFile(path))
    {
        LogError("Could not read Fistful of Zombies config file \"%s\"", file);
        SetFailState("Could not read Fistful of Zombies config file \"%s\"", file);
        return null;
    }

    return config;
}

// build a table for randomly selecting a weighted value
KeyValues BuildWeightTable(KeyValues config, const char[] name,
        int& total_weight)
{
    char key[MAX_KEY_LENGTH];
    int weight;
    KeyValues table = new KeyValues(name);

    total_weight = 0;

    config.Rewind();
    WriteLog("BuildWeightTable %s start", name);

    if (config.JumpToKey(name))
    {
        table.Import(config);

        config.GotoFirstSubKey();
        do
        {
            config.GetSectionName(key, sizeof(key));
            weight = config.GetNum("weight", 0);

            // ignore values that do not have a weight or 0 weight
            if (weight > 0)
            {
                total_weight += weight;
            }
            WriteLog("BuildWeightTable %s key: %s, weight: %d",
                    name, key, weight);
        }
        while(config.GotoNextKey());

    }
    else
    {
        LogError("A valid \"%s\" key was not defined", name);
        SetFailState("A valid \"%s\" key was not defined", name);
    }
    WriteLog("BuildWeightTable %s end total_weight: %d", name, total_weight);

    return table;
}

void SetDefaultConVars()
{
    g_TeambalanceAllowedCvar.SetInt(0, false, false);
    g_TeamsUnbalanceLimitCvar.SetInt(0, false, false);
    g_AutoteambalanceCvar.SetInt(0, false, false);
}

void RemoveCrates()
{
    Entity_KillAllByClassName("fof_crate*");
}

void RemoveTeamplayEntities()
{
    Entity_KillAllByClassName("fof_buyzone");
}

// change all info_player_fof spawn points to a round robin
// info_player_desperado and info_player_vigilante.
void ConvertSpawns()
{
    int count = GetRandomInt(0, 1);
    int spawn = INVALID_ENT_REFERENCE;
    int converted = INVALID_ENT_REFERENCE;
    float origin[3], angles[3];

    while((spawn = FindEntityByClassname(spawn, "info_player_fof")) != INVALID_ENT_REFERENCE)
    {
        // get original's position and remove it
        Entity_GetAbsOrigin(spawn, origin);
        Entity_GetAbsAngles(spawn, angles);
        Entity_Kill(spawn);

        // spawn a replacement at the same position
        converted = count % 2 == 0
            ? Entity_Create(INFO_PLAYER_HUMAN)
            : Entity_Create(INFO_PLAYER_ZOMBIE)
            ;
        if (IsValidEntity(converted))
        {
            Entity_SetAbsOrigin(converted, origin);
            Entity_SetAbsAngles(converted, angles);
            DispatchKeyValue(converted, "StartDisabled", "0");
            DispatchSpawn(converted);
            ActivateEntity(converted);
        }

        count++;
    }

}

void WeaponSpawn(KeyValues loot_table, int loot_total_weight)
{
	char loot[MAX_KEY_LENGTH];
	int count = 0;
	int entity = INVALID_ENT_REFERENCE;
	int converted = INVALID_ENT_REFERENCE;
	float origin[3], angles[3];

	// Process item_whiskey entities
	while((entity = FindEntityByClassname(entity, "item_whiskey")) != INVALID_ENT_REFERENCE)
	{
		// Get original's position and remove it
		Entity_GetAbsOrigin(entity, origin);
		Entity_GetAbsAngles(entity, angles);
		Entity_Kill(entity);

		// Spawn a replacement at the same position
		GetRandomValueFromTable(loot_table, loot_total_weight, loot, sizeof(loot));
		if (StrEqual(loot, "nothing", false)) continue;

		converted = Weapon_Create(loot, origin, angles);
		AddGlowServer(converted);
		Entity_AddEFlags(converted, EFL_NO_GAME_PHYSICS_SIMULATION | EFL_DONTBLOCKLOS);
		count++;
	}

	// Reset entity reference for processing fof_horse entities
	entity = INVALID_ENT_REFERENCE;
	// Process fof_horse entities
	while((entity = FindEntityByClassname(entity, "fof_horse")) != INVALID_ENT_REFERENCE)
	{
		// Get original's position and remove it
		Entity_GetAbsOrigin(entity, origin);
		Entity_GetAbsAngles(entity, angles);
		Entity_Kill(entity);

		// Spawn a replacement at the same position
		GetRandomValueFromTable(loot_table, loot_total_weight, loot, sizeof(loot));
		if (StrEqual(loot, "nothing", false)) continue;

		converted = Weapon_Create(loot, origin, angles);
		AddGlowServer(converted);
		Entity_AddEFlags(converted, EFL_NO_GAME_PHYSICS_SIMULATION | EFL_DONTBLOCKLOS);
		count++;
	}

	// Process npc_horse entities
	entity = INVALID_ENT_REFERENCE;
	while((entity = FindEntityByClassname(entity, "npc_horse")) != INVALID_ENT_REFERENCE)
	{
		// Get original's position and remove it
		Entity_GetAbsOrigin(entity, origin);
		Entity_GetAbsAngles(entity, angles);
		Entity_Kill(entity);

		// Spawn a replacement at the same position
		GetRandomValueFromTable(loot_table, loot_total_weight, loot, sizeof(loot));
		if (StrEqual(loot, "nothing", false)) continue;

		converted = Weapon_Create(loot, origin, angles);
		AddGlowServer(converted);
		Entity_AddEFlags(converted, EFL_NO_GAME_PHYSICS_SIMULATION | EFL_DONTBLOCKLOS);
		count++;
	}
}

void KillWeaponSpawn()
{
    int entity = INVALID_ENT_REFERENCE;
    int count = 0;

    // Remove item_whiskey entities
    while((entity = FindEntityByClassname(entity, "weapon_*")) != INVALID_ENT_REFERENCE)
    {
        if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == -1)
		{
			Entity_Kill(entity);
			count++;
        }
    }

    // Remove item_whiskey entities
    while((entity = FindEntityByClassname(entity, "item_whiskey")) != INVALID_ENT_REFERENCE)
    {
        Entity_Kill(entity);
        count++;
    }

    // Reset entity reference for processing fof_horse entities
    entity = INVALID_ENT_REFERENCE;

    // Remove fof_horse entities
    while((entity = FindEntityByClassname(entity, "fof_horse")) != INVALID_ENT_REFERENCE)
    {
        Entity_Kill(entity);
        count++;
    }

    // Reset entity reference for processing npc_horse entities
    entity = INVALID_ENT_REFERENCE;

    // Remove npc_horse entities
    while((entity = FindEntityByClassname(entity, "npc_horse")) != INVALID_ENT_REFERENCE)
    {
        Entity_Kill(entity);
        count++;
    }
}

// spawn the fof_teamplay entity that will control the game's logic.
int SpawnZombieTeamplayEntity()
{
    char tmp[512];

    // first check if an fof_teamplay already exists
    int ent = FindEntityByClassname(INVALID_ENT_REFERENCE, "fof_teamplay");
    if (IsValidEntity(ent))
    {
        DispatchKeyValue(ent, "RespawnSystem", "1");

        Format(tmp, sizeof(tmp),                 "!self,RoundTime,%d,0,-1", GetRoundTime());
        DispatchKeyValue(ent, "OnNewRound",      tmp);
        DispatchKeyValue(ent, "OnNewRound",      "!self,ExtraTime,15,0.1,-1");

        Format(tmp, sizeof(tmp),                 "!self,ExtraTime,%d,0,-1", GetRespawnTime());
        DispatchKeyValue(ent, "OnTimerEnd",      tmp);
        DispatchKeyValue(ent, "OnTimerEnd",      "!self,InputRespawnPlayers,-2,0,-1");

        Format(tmp, sizeof(tmp),                 "!self,%s,,0,-1", INPUT_HUMAN_VICTORY);
        DispatchKeyValue(ent, "OnRoundTimeEnd",  tmp);
        DispatchKeyValue(ent, ON_NO_ZOMBIE_ALIVE,   "!self,InputRespawnPlayers,-2,0,-1");
        Format(tmp, sizeof(tmp),                 "!self,%s,,0,-1", INPUT_ZOMBIE_VICTORY);
        DispatchKeyValue(ent, ON_NO_HUMAN_ALIVE, tmp);

    }

    // if not create one
    else if (!IsValidEntity(ent))
    {
        ent = CreateEntityByName("fof_teamplay");
        DispatchKeyValue(ent, "targetname", "tpzombie");

        DispatchKeyValue(ent, "RoundBased", "1");
        DispatchKeyValue(ent, "RespawnSystem", "1");

        Format(tmp, sizeof(tmp),                 "!self,RoundTime,%d,0,-1", GetRoundTime());
        DispatchKeyValue(ent, "OnNewRound",      tmp);
        DispatchKeyValue(ent, "OnNewRound",      "!self,ExtraTime,15,0.1,-1");

        Format(tmp, sizeof(tmp),                 "!self,ExtraTime,%d,0,-1", GetRespawnTime());
        DispatchKeyValue(ent, "OnTimerEnd",      tmp);
        DispatchKeyValue(ent, "OnTimerEnd",      "!self,InputRespawnPlayers,-2,0,-1");

        Format(tmp, sizeof(tmp),                 "!self,%s,,0,-1", INPUT_HUMAN_VICTORY);
        DispatchKeyValue(ent, "OnRoundTimeEnd",  tmp);
        DispatchKeyValue(ent, ON_NO_ZOMBIE_ALIVE,   "!self,InputRespawnPlayers,-2,0,-1");
        Format(tmp, sizeof(tmp),                 "!self,%s,,0,-1", INPUT_ZOMBIE_VICTORY);
        DispatchKeyValue(ent, ON_NO_HUMAN_ALIVE, tmp);

        DispatchSpawn(ent);
        ActivateEntity(ent);
    }

    return ent;
}

bool IsEnabled()
{
    return g_EnabledCvar.BoolValue;
}

// Função auxiliar para verificar se o cliente é válido
bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

// Função para verificar se é zumbi
bool IsZombie(int client)
{
    if (!IsValidClient(client))
        return false;
    return GetClientTeam(client) == TEAM_ZOMBIE;
}

// Função para verificar se é humano
bool IsHuman(int client)
{
    if (!IsValidClient(client))
        return false;
    return GetClientTeam(client) == TEAM_HUMAN;
}

void JoinHumanTeam(int client)
{
    ChangeClientTeam(client, TEAM_HUMAN);
}

void JoinZombieTeam(int client)
{
    if (GetRoundState() != RoundPre)
    {
		ChangeClientTeam(client, TEAM_ZOMBIE);
    }
}

void RandomizeTeams()
{
    int clients[MAXPLAYERS+1];
    int client_count = 0, human_count, client;
    float ratio = g_RatioCvar.FloatValue;

    for (client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client)) continue;
        if (!(IsZombie(client) || IsHuman(client))) continue;

        clients[client_count] = client;
        client_count++;
    }

    SortCustom1D(clients, client_count, Sort_HumanPriority);

    // calculate number of humans;  need at least one
    human_count = RoundToFloor(client_count * ratio);
    if (human_count == 0 && client_count > 0) human_count = 1;

    // assign teams; modify priority for next round
    for (int i = 0; i < human_count; i++)
    {
        client = clients[i];
        JoinHumanTeam(client);
        g_HumanPriority[client]--;
    }
    for (int i = human_count; i < client_count; i++)
    {
        client = clients[i];
        JoinZombieTeam(clients[i]);
        g_HumanPriority[client]++;
    }
}

bool GetRandomValueFromTable(KeyValues table, int total_weight, char[] value,
        int length)
{
    int weight;
    int rand = GetRandomInt(0, total_weight - 1);

    table.Rewind();
    table.GotoFirstSubKey();
    WriteLog("GetRandomValueFromTable total_weight: %d, rand: %d",
            total_weight, rand);
    do
    {
        table.GetSectionName(value, length);
        weight = table.GetNum("weight", 0);
        WriteLog("GetRandomValueFromTable value: %s, weight: %d",
                value, weight);
        if (weight <= 0) continue;

        if (rand < weight)
        {
            return true;
        }
        rand -= weight;
    }
    while(table.GotoNextKey());

    return false;
}

void UseWeapon(int client, const char[] weapon, bool second=false)
{
    char tmp[MAX_KEY_LENGTH];
    Format(tmp, sizeof(tmp), "use %s%s", weapon, second ? "2" : "");
    ClientCommand(client, tmp);
}

void StripWeapons_RoundPre(int client)
{
	int weapon_ent;
	char class_name[MAX_KEY_LENGTH];
	int offs = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");

	for (int i = 0; i <= 47; i++)
	{
		weapon_ent = GetEntDataEnt2(client, offs + (i * 4));
		if (weapon_ent == -1) continue;

		GetEdictClassname(weapon_ent, class_name, sizeof(class_name));
		if (StrEqual(class_name, "weapon_fists")) continue;

		// Remover a arma do jogador
		RemovePlayerItem(client, weapon_ent);
		RemoveEdict(weapon_ent);
	}

	// Equipar o jogador com "weapon_fists"
	UseWeapon(client, "weapon_fists");
	FakeClientCommandEx(client, "use weapon_fists");
}

void StripWeapons(int client)
{
	int weapon_ent;
	char class_name[MAX_KEY_LENGTH];
	int offs = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");

	// Obter a posição do jogador para spawnar a arma
	float pos[3];
	GetClientAbsOrigin(client, pos);
	pos[2] += 50.0;
	for (int i = 0; i <= 47; i++)
	{
		weapon_ent = GetEntDataEnt2(client, offs + (i * 4));
		if (weapon_ent == -1) continue;

		GetEdictClassname(weapon_ent, class_name, sizeof(class_name));
		if (StrEqual(class_name, "weapon_fists")) continue;

		// Criar a entidade da arma dropada
		int dropped_weapon = CreateEntityByName(class_name);
		if (GetRoundState() != RoundPre)
		{
			if (dropped_weapon != -1)
			{
				CPrintToChat(client, "%t", "Zombies Can Not Use Guns");
				TeleportEntity(dropped_weapon, pos, NULL_VECTOR, NULL_VECTOR);
				DispatchSpawn(dropped_weapon);
				AddGlowServer(dropped_weapon);
			}
		}

		// Remover a arma do jogador
		RemovePlayerItem(client, weapon_ent);
		RemoveEdict(weapon_ent);
	}

	// Equipar o jogador com "weapon_fists"
	UseWeapon(client, "weapon_fists");
	FakeClientCommandEx(client, "use weapon_fists");
	CreateTimer(0.1, SetMaxSpeedInfectedStrip, client, TIMER_FLAG_NO_MAPCHANGE);
}

Action SetMaxSpeedInfectedStrip(Handle timer, int client)
{
    // Verifica se a entidade é válida, o cliente está conectado e está vivo
    if (IsValidEntity(client) && IsClientInGame(client) && IsPlayerAlive(client))
    {
        float MaxSpeed = g_Infected_Speed.FloatValue;

        SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", MaxSpeed);
        ChangeEdictState(client, GetEntSendPropOffs(client, "m_flMaxspeed"));
    }

    return Plugin_Handled;
}

void EmitZombieYell(int client)
{
    char tmp[PLATFORM_MAX_PATH];
    Format(tmp, sizeof(tmp), "npc/zombie/zombie_chase-%d.wav",
            GetRandomInt(1, 4));
    EmitSoundToAll(tmp, client, SNDCHAN_AUTO, SNDLEVEL_SCREAMING,
            SND_CHANGEPITCH, SNDVOL_NORMAL, GetRandomInt(85, 110));
}

void RandomizeModel(int client)
{
    int model;

    if (IsHuman(client))
    {
        model = GetRandomInt(0, 3);
        switch (model)
        {
            case 0: { Entity_SetModelIndex(client, g_VigilanteModelIndex); }
            case 1: { Entity_SetModelIndex(client, g_DesperadoModelIndex); }
            case 2: { Entity_SetModelIndex(client, g_BandidoModelIndex); }
            case 3: { Entity_SetModelIndex(client, g_RangerModelIndex); }
        }

    }
    else if (IsZombie(client))
    {
        model = GetRandomInt(0, 0);
        switch (model)
        {
            case 0: { Entity_SetModelIndex(client, g_ZombieModelIndex); }
        }
    }
}

int GetRoundTime()
{
    return g_RoundTimeCvar.IntValue;
}

int GetRespawnTime()
{
    return g_RespawnTimeCvar.IntValue;
}

void SetRoundState(FoZRoundState round_state)
{
    WriteLog("Set RoundState: %d", round_state);
    g_RoundState = round_state;
}

FoZRoundState GetRoundState()
{
    return g_RoundState;
}

bool InfectionChanceRoll()
{
    int humans = Team_GetClientCount(TEAM_HUMAN, CLIENTFILTER_ALIVE);
    // last human can't be infected
    if (humans <= 1) return false;

    float chance = g_InfectionCvar.FloatValue;

    return GetURandomFloat() < chance;
}

void BecomeInfected(int client)
{
    Entity_ChangeOverTime(client, 0.1, InfectionStep);
}

void InfectedToZombie(int client)
{
	StripWeapons(client);
	UseWeapon(client, "weapon_fists");
	FakeClientCommandEx(client, "use weapon_fists");
	g_PVMid[client] = Weapon_GetViewModelIndex2(client, -1);

	JoinZombieTeam(client);
	Entity_SetModelIndex(client, g_ZombieModelIndex);
	Entity_SetModelIndex(g_PVMid[client], g_iClawModel);

	EmitZombieYell(client);
	SetEntPropFloat(client, Prop_Send, "m_flDrunkness", 0.0);

	char PlayerName[256];
	GetClientName(client, PlayerName, sizeof(PlayerName));
	WriteParticle(client, "bigboom_blood");
	CPrintToChatAll("%t", "Become Infected", PlayerName);

	new weapon_index;
	for (new x = 0; x <= 3; x++)
	{
		if (x != 2 && (weapon_index = GetPlayerWeaponSlot(client, x)) != -1)
		{  
			RemovePlayerItem(client, weapon_index);
			RemoveEdict(weapon_index);
			CreateTimer(0.5, usefists, client);
		}
	}

	EmitSoundToAll(SOUND_STINGER, .flags = SND_CHANGEPITCH, .pitch = 80);
}

public Action:usefists(Handle:timer, any:client)
{
	GivePlayerItem(client, "weapon_fists");
	FakeClientCommandEx(client, "use weapon_fists");
	ClientCommand(client, "use weapon_fists");
}

bool InfectionStep(int& client, float& interval, int& currentCall)
{
	// this steps through the process of an infected human to a zombie takes
	// 300 steps or 30 seconds
	if (!IsEnabled()) return false;
	if (!IsClientIngame(client)) return false;
	if (!IsPlayerAlive(client)) return false;
	if (!IsHuman(client)) return false;
	if (GetRoundState() != RoundActive) return false;
	if (Team_GetClientCount(TEAM_HUMAN, CLIENTFILTER_ALIVE) <= 1) return false;

	// become drunk 2/3 of the way through
	if (currentCall > 200)
	{
		char PlayerName[256];
		GetClientName(client, PlayerName, sizeof(PlayerName));
		float drunkness = GetEntPropFloat(client, Prop_Send, "m_flDrunkness");
		drunkness = currentCall * 1.0;

		// Verifica se a mensagem já foi mostrada
		if (!g_human_transformation_message[client])
		{
			SetEntPropFloat(client, Prop_Send, "m_flDrunkness", drunkness);
			EmitSoundToClient(client, SOUND_BREATH);
			CPrintToChatAll("%t", "has been infected and can transform at any moment", PlayerName);

			Client_ScreenFade(
			client,         // ID do jogador
			200,           // Duração do fade
			FFADE_IN,       // Modo de fade (fade entrando)
			4000,           // Holdtime (quanto tempo fica visível)
			0,              // Red (0 para verde puro)
			255,            // Green (255 para verde máximo)
			0,              // Blue (0 para verde puro)
			5,             // Alpha (Transparencia)
			true            // Reliable message
			);

			g_human_transformation_message[client] = true; // Marca como mostrada
			CreateTimer(8.0, stop_drunkness_effect, client);
		}
	}

	// all the way through, change client into a zombie
	if (currentCall > 300)
	{
		InfectedToZombie(client);
		return false;
	}

	if (currentCall > 250 && (2 * GetURandomFloat()) < (currentCall / 300.0))
	{
		FakeClientCommand(client, "vc 15");
	}

	return true;
}

public Action:stop_drunkness_effect(Handle:timer, any:client)
{
	SetEntPropFloat(client, Prop_Send, "m_flDrunkness", 0.0);
	StopSound(client, SNDCHAN_AUTO, SOUND_BREATH);

}

void RoundEndCheck()
{
    // check if any Humans are alive and if not force zombies to win
    // NOTE:  The fof_teamplay entity should be handling this but there are
    // some cases where it does not work.
    if (GetRoundState() == RoundActive
            && Team_GetClientCount(TEAM_HUMAN, CLIENTFILTER_ALIVE) <= 0)
    {
        AcceptEntityInput(g_TeamplayEntity, INPUT_ZOMBIE_VICTORY);
    }
}

int Sort_HumanPriority(int elem1, int elem2, const int[] array, Handle hndl)
{
    if (g_HumanPriority[elem1] < g_HumanPriority[elem2]) return 1;
    if (g_HumanPriority[elem1] > g_HumanPriority[elem2]) return -1;

    return GetURandomFloat() < 0.5 ? 1 : -1;
}

void RewardSurvivingHumans()
{
    // Called at round end to give rewards to surviving humans.  Currently used
    // to pump their priority by one so they have a better chance to be human
    // next round.

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientIngame(client)) continue;
        if (!IsPlayerAlive(client)) continue;
        if (!IsHuman(client)) continue;

        g_HumanPriority[client]++;
    }
}

bool SetGameDescription(const char[] description)
{
#if defined _SteamWorks_Included
    return SteamWorks_SetGameDescription(description);
#else
    return false;
#endif
}

stock bool IsClientIngame(int client)
{
	if (client > 4096) {
		client = EntRefToEntIndex(client);
	}

	if (client < 1 || client > MaxClients) {
		return false;
	}

	return IsClientInGame(client);
}

stock void WriteLog(const char[] format, any ...)
{
#if defined DEBUG
    char buf[2048];
    VFormat(buf, sizeof(buf), format, 2);
    PrintToServer("[FOZ - %.3f] %s", GetGameTime(), buf);
#endif
}

// ################################## Maps lighting changer ######################################################

void LoadConfig()
{
	BuildPath(Path_SM, Path, sizeof(Path), "configs/fistful_of_zombies_maps.cfg");
	
	KeyValues kv = new KeyValues("MapLightingChanger");
	kv.ImportFromFile(Path);
	
	if (!FileExists(Path))
	{
		SetFailState("Configuration file %s is not found", Path);
		return;
	}
	if (!kv.GotoFirstSubKey())
	{
		SetFailState("In configuration file %s is errors", Path);
		return;
	}
	
	int i = 0;
	
	do
	{
		kv.GetSectionName(MapName[i], sizeof(MapName[]));
		kv.GetString("light", LightValue[i], sizeof(LightValue[]));
		
		i++;
		
	} while (kv.GotoNextKey());
	
	loadedMaps = i;
	
	delete kv;
	return;
}

public Action ChangeLight(Handle timer)
{
	char CurrentMap[PLATFORM_MAX_PATH];
	
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	for (int i = 0; i <= loadedMaps; i++)
	{
		if (StrEqual(MapName[i], CurrentMap))
		{
			SetLightStyle(0, LightValue[i]);
			break; // Interrompe o loop após encontrar a correspondência
		}
	}

	return Plugin_Continue; // Retorna um valor explícito
}
// ################################################################################################################

WriteParticle(Ent, String:ParticleName[])
{
	decl Particle;
	decl String:tName[64];

	Particle = CreateEntityByName("info_particle_system");
    
	if(IsValidEdict(Particle))
	{
		float Position[3];
		GetClientAbsOrigin(Ent, Position);
		Position[2] += 50.0;

		GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", Position);
		Position[2] += GetRandomFloat(15.0, 35.0);

		TeleportEntity(Particle, Position, NULL_VECTOR, NULL_VECTOR);

		// Configura nome e propriedades da partícula
		Format(tName, sizeof(tName), "Entity%d", Ent);
		DispatchKeyValue(Ent, "targetname", tName);
		GetEntPropString(Ent, Prop_Data, "m_iName", tName, sizeof(tName));

		DispatchKeyValue(Particle, "targetname", "CSSParticle");
		DispatchKeyValue(Particle, "parentname", tName);
		DispatchKeyValue(Particle, "effect_name", ParticleName);

		DispatchSpawn(Particle);

		// Configura a partícula como "parented" ao jogador
		SetVariantString(tName);
		AcceptEntityInput(Particle, "SetParent", Particle, Particle, 0);

		ActivateEntity(Particle);
		AcceptEntityInput(Particle, "start");

		// Deleta a partícula após 3 segundos
		CreateTimer(1.0, DeleteParticle, Particle);
	}
}

// Função para deletar a partícula após o tempo determinado
public Action:DeleteParticle(Handle:timer, any:Particle)
{
    if (IsValidEdict(Particle))
    {
        AcceptEntityInput(Particle, "Kill");
    }
    return Plugin_Stop;
}
