#pragma semicolon 1
#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>  

#define LoopAllClients(%1) for(int %1 = 1;%1 <= MaxClients;%1++)
#define LoopClients(%1) for(int %1 = 1;%1 <= MaxClients;%1++) if(IsValidClient(%1))
#define LoopAliveClients(%1) for(int %1 = 1;%1 <= MaxClients;%1++) if(IsValidClient(%1, true))

char g_sRadioCmds[][] = { "coverme", "takepoint", "holdpos", "regroup", "followme", "takingfire", "go", "fallback", "sticktog", "getinpos", "stormfront", "report", "roger", "enemyspot", "needbackup", "sectorclear",
"inposition", "reportingin", "getout", "negative","enemydown", "compliment", "thanks", "cheer" };
 
bool
        bg_ClientInv[MAXPLAYERS+1] = {false,...}; 

ConVar 
        cV_Gravity,
        cV_Speed;
float 
        cVf_Gravity,
        cVf_Speed;

int 
        cash;

public Plugin myinfo = {
  name = "Furien Mod",
  author = "Filiq_",
  version = "0.0.2a",
  description = "Furien cs 1.6 style for cs:go",
  url = "https://github.com/Diversity2251/Furien"
};

public void OnPluginStart() {

    RegConsoleCmd("sm_shop", CMD_SHOP, "Shop");

    HookEvent("player_spawn", Event_PlayerSpawn);

    cV_Gravity = CreateConVar("furien_gravity", "0.15", "Gravitatea * x la furien");
    cV_Speed = CreateConVar("furien_speed", "4.0", "Viteza * x la furien");

    cVf_Gravity = GetConVarFloat(cV_Gravity);
    cVf_Speed = GetConVarFloat(cV_Speed);

    HookConVarChange(cV_Gravity, OnConVarChanged);
    HookConVarChange(cV_Speed, OnConVarChanged);

    for(int i; i < sizeof(g_sRadioCmds); i++)
        AddCommandListener(Command_Block, g_sRadioCmds[i]); 

    AddCommandListener(Command_Block, "kill");

    cash = FindSendPropInfo("CCSPlayer", "m_iAccount");
}

public void OnMapStart() {
    SetConVarString(FindConVar("mp_teamname_1"), "ANTI-FURIENS", true);
    SetConVarString(FindConVar("mp_teamname_2"), "FURIENS", true);

    SetConVarInt(FindConVar("mp_startmoney"), 800, true);
    SetConVarInt(FindConVar("sv_deadtalk"), 1, true);
    SetConVarInt(FindConVar("sv_alltalk"), 1, true);
    SetConVarInt(FindConVar("mp_buytime"), 0, true);
    SetConVarInt(FindConVar("sv_ignoregrenaderadio"), 1, true);
    SetConVarInt(FindConVar("sv_disable_immunity_alpha"), 1, true);
    SetConVarInt(FindConVar("sv_airaccelerate"), 20, true);
    SetConVarInt(FindConVar("mp_maxrounds"), 30, true); 
     
    SetConVarFloat(FindConVar("mp_roundtime"), 2.5, true);
    SetConVarFloat(FindConVar("mp_roundtime_defuse"), 2.5, true);
} 

public Action CMD_SHOP(int client, int args) {
    if(!IsValidClient(client, true)) 
        return Plugin_Handled; 

    Menu shop = new Menu(MenuShop_Handler);

    switch(GetClientTeam(client)) {
        case CS_TEAM_T: {
            SetMenuTitle(shop, "Furien Shop: %d", GetClientMoney(client)); 
            shop.AddItem("SK", "SuperKnife | $10.000");
        }
        case CS_TEAM_CT: {
            SetMenuTitle(shop, "Anti-Furien Shop: %d", GetClientMoney(client)); 
            shop.AddItem("DEF", "Defuse Kit | $500");
        }
    } 
     
    shop.AddItem("HEG", "He Grenade | $3.000");
    shop.AddItem("HP", "50 HP | $3.000");
    shop.AddItem("AP", "50 AP + HELMET | $500");

    shop.Display(client, 0);

    return Plugin_Continue;
}

public int MenuShop_Handler(Menu menu, MenuAction action, int client, int item) {

}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(IsValidClient(client, true)) {    
        bg_ClientInv[client] = false;    
        
        SetEntityRenderColor(client, 255, 255, 255, 255); 
        SetEntityRenderMode(client, RENDER_NORMAL);
        StripWeapons(client);
        GivePlayerItem(client, "weapon_knife");

        if(GetClientTeam(client) == CS_TEAM_CT) {
            GivePlayerItem(client, "weapon_flashbang");
            SetEntityGravity(client, 1.0);
            SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0); 
        } 
    } 
}

public void OnClientPutInServer(int client) {
    if(IsValidClient(client)) {
        SDKHook(client, SDKHook_PreThink, ClientPreThink);
        SDKHook(client, SDKHook_PostThinkPost, ClientPostThink); 
    }
}

public void ClientPreThink(int client) {
	if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_T) {
        SetEntityGravity(client, cVf_Gravity);
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", cVf_Speed);
	}
}

public void ClientPostThink(int client) {
	if(IsValidClient(client, true)) {
		SetEntProp(client, Prop_Send, "m_bInBuyZone", 0); 

		if(GetClientTeam(client) == CS_TEAM_T)
            SetEntProp(client, Prop_Send, "m_iAddonBits", -1);
		else if(GetClientTeam(client) == CS_TEAM_CT)
            SetEntProp(client, Prop_Send, "m_iAddonBits", 1);
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2]) {
    if(IsValidClient(client, true)) { 
        char Weapon[32];
        int flag = GetEntityFlags(client);  
        GetClientWeapon(client, Weapon, 32);
        if(GetClientTeam(client) == CS_TEAM_T) {
            //PrintCenterText(client, "test 2"); 
            if(IsClientInAir(client, flag)) {
                float Vel[3];
                GetEntPropVector(client, Prop_Data, "m_vecVelocity", Vel);
                
                if(Vel[2] < -1.0) {
                    Vel[2] += 1.9;
                    SetEntPropVector(client, Prop_Data, "m_vecVelocity", Vel);
                    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Vel);
                }
                if(Vel[2] > 200.0) {
                    Vel[2] -=20.0;
                    SetEntPropVector(client, Prop_Data, "m_vecVelocity", Vel);
                    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Vel);
                }
            } 
            if(IsClientNotMoving(buttons) && !IsClientInAir(client, flag)) {
                // PrintCenterText(client, "test 4");
                if(bg_ClientInv[client] == false) {   
                    SetEntityRenderColor(client, 255, 255, 255, 0);
                    SetEntityRenderMode(client, RENDER_TRANSALPHA);
                    // SetEntityRenderFx(client, 7);

                    bg_ClientInv[client] = true;

                    PrintCenterText(client, "Now you are invisibile");
                }
            } else {
                if(bg_ClientInv[client] == true) {
                    SetEntityRenderColor(client, 255, 255, 255, 255); 
                    SetEntityRenderMode(client, RENDER_NORMAL);
                    // SetEntityRenderFx(client, 0);

                    bg_ClientInv[client] = false;

                    PrintCenterText(client, "Now you are visibile");
                }
            }
        }
    }
} 

public Action Command_Block(int client, const char[] command,int  args) {
	return Plugin_Handled;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) { 

    if(convar == cV_Gravity)
        cVf_Gravity = GetConVarFloat(cV_Gravity); 
    else if(convar == cV_Speed)
        cVf_Speed = GetConVarFloat(cV_Speed);  
}

stock bool IsClientInAir(int client, int flags)
{
    return !(flags & FL_ONGROUND);
}
stock bool IsClientNotMoving(int buttons)
{
	return !IsMoveButtonsPressed(buttons);
}
stock bool IsMoveButtonsPressed(int buttons)
{
	return buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT;
}

stock bool IsValidClient(int client, bool alive = false) {
    if(0 < client && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) == false && (alive == false || IsPlayerAlive(client)))
        return true; 
    return false;
}

stock void StripWeapons(int client)
{
	int wepIdx;
	for (int x = 0; x <= 5; x++)
	{
		if (x != 2 && (wepIdx = GetPlayerWeaponSlot(client, x)) != -1)
		{
			RemovePlayerItem(client, wepIdx);
			RemoveEdict(wepIdx);
		}
	}
}

stock void SetClientMoney(int client, int money) {
    SetEntData(client, cash, money); 
}
stock int GetClientMoney(int client) {
    return GetEntData(client, cash); 
}