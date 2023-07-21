#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = 
{
	name = "[AeT] Plugin",
	author = "ELDment",
	description = "[AeT] Plugin",
	version = "Internal",
	url = "http://github.com/ELDment"
};

bool RoundReset = false, PlayerIgnore[MAXPLAYERS + 1];
int PTickcount[MAXPLAYERS + 1], PWarn[MAXPLAYERS + 1];
float PYawvalue[MAXPLAYERS + 1];

public void OnPluginStart()
{
	HookEvent("round_freeze_end", Event_FreezeEnd, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("bullet_impact", Event_OnBulletImpact, EventHookMode_Post);
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsValidClient(client))
		return;
	PTickcount[client] = GetSysTickCount();
	PYawvalue[client] = -114514.0;
	PWarn[client] = 0;
	PlayerIgnore[client] = false;
}

public void Event_FreezeEnd(Event event, const char[] name, bool dB)
{
	RoundReset = false;
}
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) 
{
	RoundReset = true;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client))
			PYawvalue[client] = -114514.0;
	}
}

public Action Event_OnBulletImpact(Event event, const char[] name, bool dontBroadcast) //解决因玩家高到离谱的shot fl引起的误判
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client))
		return Plugin_Continue;
	CheckDelay(client);
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (RoundReset)
		return Plugin_Continue;
	if (!IsValidClient(client))
		return Plugin_Continue;
	if (!IsPlayerAlive(client))
		return Plugin_Continue;

	float angRotation[3];
	GetClientEyeAngles(client, angRotation);
	if (PYawvalue[client] == -114514.0) //初始化
	{
		PYawvalue[client] = angRotation[0];
		PTickcount[client] = GetSysTickCount();
		return Plugin_Continue;
	}
	
	if (buttons & IN_USE) //防止因为开启Legit (E键) 造成的误判
		return Plugin_Continue;
		
	/*
	//空中不检测
	if (buttons & IN_JUMP)
		return Plugin_Continue;
	if (!(GetEntityFlags(client) & FL_ONGROUND))
		return Plugin_Continue;
	if (GetEntityFlags(client) & FL_FLY)
		return Plugin_Continue;
	*/
	
	if (PlayerIgnore[client])
		return Plugin_Continue;

	if (GetSysTickCount() - PTickcount[client] >= 40)
	{
		float icount;
		
		icount = FloatAbs(PYawvalue[client] - angRotation[0]); //尽可能的优化性能
		if (PYawvalue[client] < angRotation[0])
		{
			icount = FloatAbs(angRotation[0] - PYawvalue[client]);
		}

		if (icount >= 89.999999)
		{
			PWarn[client]++;
			PrintToChat(client, "\x01[\x0EAeT\x01] \x07请注意\x01，Pitch切换幅度(\x0E%.4f\x01)存疑 [#\x06%i\x01 次警告]", icount, PWarn[client]);
			if (PWarn[client] >= 50)
			{
				if (IsValidClient(client))
					KickClientEx(client, "[+] 来自: 服务器插件检测\n[+] 原因: DefensiveAA(针对X轴)检测\n[+] 说明: 警告大于50次且未作出整改\n___________________________\n如有疑问请联系服务器管理员");
			}
			CheckDelay(client);
		}
		PYawvalue[client] = angRotation[0];
		PTickcount[client] = GetSysTickCount();
	}
	
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname) //解决玩家反馈 - 丢道具误判
{
	if (entity < -1)
		return;
	if (entity > MaxClients && IsValidEdict(entity) && IsValidEntity(entity))
	{
		if (StrContains(classname, "_projectile", false) != -1)
		{
			int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			if (IsValidClient(client))
				CheckDelay(client);
		}
	}
}

public void CheckDelay(int client)
{
	if (!IsValidClient(client))
		return;
	PlayerIgnore[client] = true;
	CreateTimer(0.5, ResetPlayerFlag, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action ResetPlayerFlag(Handle Timer, int client)
{
	if (IsValidClient(client))
	{
		float angRotation[3];
		GetClientEyeAngles(client, angRotation);
		PYawvalue[client] = angRotation[0];
		PlayerIgnore[client] = false;
	}
	return Plugin_Stop;
}

public bool IsValidClient(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		return (IsClientInGame(client) && !IsFakeClient(client) && IsClientConnected(client) && !IsClientSourceTV(client));
	}else{
		return false;
	}
}
