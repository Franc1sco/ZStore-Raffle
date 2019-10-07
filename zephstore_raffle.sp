#pragma semicolon 1

#define PLUGIN_VERSION "1.6"

#include <sourcemod>
#include <sdktools>
#include <store>
#include <multicolors>

#define CHAT_PREFIX "[Store-Raffle]"

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++)

bool g_bUsed[MAXPLAYERS + 1] = {false, ...};
int g_iSpend[MAXPLAYERS + 1] = {0, ...};

Handle g_hJackpot = null;

Handle cvar_min, cvar_max;


public Plugin myinfo = 
{
	name = "Zeph Store: Raffle",
	author = "Franc1sco franug, .#Zipcore & Simon",
	description = "Round based raffle system for store credits",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_raffle", Cmd_Raffle);
	RegConsoleCmd("sm_jackpot", Cmd_Raffle);
	
	cvar_min = CreateConVar("sm_raffle_min", "10", "min raffle value");
	cvar_max = CreateConVar("sm_raffle_max", "5000", "max raffle value");
	
	g_hJackpot = CreateArray(1);
	
	HookEvent("round_end", Event_OnRoundEnd);
}

public Action Event_OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	int jackpot = GetArraySize(g_hJackpot);
	
	if (jackpot <= 0)
		return Plugin_Continue;
		
	int winner_account = GetArrayCell(g_hJackpot, GetRandomInt(0, jackpot-1));
	int winner = winner_account;
	
	// Winner is not in game, try to find another winner
	if (winner <= 0 || !IsClientInGame(winner))
	{
		CPrintToChatAll("%s Winner is not in game anymore, trying to find a new winner.", CHAT_PREFIX);
		
		for (int i = 0; i < jackpot - 1; i++)
		{
			winner_account = GetArrayCell(g_hJackpot, GetRandomInt(0, jackpot-1));
			winner = winner_account;
			
			if(winner > 0 && IsClientInGame(winner))
				break;
		}
	}
	
	// All players disconnect, nobody get his credits back, lol
	if (winner <= 0 || !IsClientInGame(winner))
	{
		CPrintToChatAll("%s All players disconnect, nobody get his credits back, lol. Jackpot was %d credits!", CHAT_PREFIX, jackpot);
		return Plugin_Continue;
	}
	
	Store_SetClientCredits(winner_account, Store_GetClientCredits(winner_account)+jackpot);
	
	if(winner == -1 || !IsClientInGame(winner))
		CPrintToChatAll("%s Winner has left the game but won %d credits.", CHAT_PREFIX, jackpot);
	else CPrintToChatAll("%s %N has won %d credits.", CHAT_PREFIX, winner, jackpot);
	
	// Reset
	LoopClients(i)
	{
		g_bUsed[i] = false;
		g_iSpend[i] = 0;
	}
		
	ClearArray(g_hJackpot);
	
	return Plugin_Continue;
}

public Action Cmd_Raffle(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "%s This command is only for players", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	if(g_bUsed[client])
	{
		CPrintToChat(client, "%s You already spend %d credits this game. Current win chance: %.2f% Jackpot: %d credits", CHAT_PREFIX, g_iSpend[client], float(g_iSpend[client])/float(GetArraySize(g_hJackpot))*100.0, GetArraySize(g_hJackpot));
		return Plugin_Handled;
	}
	
	if(args == 0)
	{
		CPrintToChat(client, "%s Jackpot: %d credits", CHAT_PREFIX, GetArraySize(g_hJackpot));
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		CPrintToChat(client, "%s Usage: sm_raffle <credits> or Usage: sm_jackpot <credits>", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	char buffer[32];
	GetCmdArg(1, buffer, 32);
	
	int credits_spend = StringToInt(buffer);
	
	if(credits_spend < GetConVarInt(cvar_min))
	{
		CPrintToChat(client, "%s You have to spend at least %d credits.", CHAT_PREFIX, GetConVarInt(cvar_min));
		return Plugin_Handled;
	}
	else if(credits_spend > GetConVarInt(cvar_max))
	{
		CPrintToChat(client, "%s You can't spend that much credits (Max: %d).", CHAT_PREFIX, GetConVarInt(cvar_max));
		return Plugin_Handled;
	}
	
	int storeAccountID = client;
	int credits = Store_GetClientCredits(client);
	
	if(credits_spend > credits)
	{
		CPrintToChat(client, "%s You don't have enough credits. (Spend: %d Current: %d)", CHAT_PREFIX, credits_spend, credits);
		return Plugin_Handled;
	}
	
	g_bUsed[client] = true;
	g_iSpend[client] = credits_spend;
	
	// Remove credits
	Store_SetClientCredits(client, Store_GetClientCredits(client)-credits_spend);
	
	// Add his credits too the jackpot "pool"
	for (int i = 0; i < credits_spend; i++)
		PushArrayCell(g_hJackpot, storeAccountID); //Use store account id in case player left game or rejoined
	
	CPrintToChatAll("%s %N has spend %d credits, his current winning chance is: %.2f% (Jackpot: %d credits)", CHAT_PREFIX, client, credits_spend, float(credits_spend)/float(GetArraySize(g_hJackpot))*100.0, GetArraySize(g_hJackpot));
	
	return Plugin_Handled;
}