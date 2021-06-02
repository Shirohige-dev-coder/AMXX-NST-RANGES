// Sublime Text Editor 2.2 by: Destro - Code by: Lol.- & Alfredo @

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <geoip>
#include <adv_vault>
#include <reapi>
//#include <weapons>

new g_plugin[][] =
{
	"[AMXX-CSO] Rangos Advanced Mod",
	"2.3c",
	"lol.- (YovannyH) & CSO-NST Alfredo. (AlfredoQ)"
}

new const g_hours[] = { 20, 21, 22, 23, 00, 01, 02, 03, 04, 05, 06, 07 } 
new const g_sound_lvlup[] = "sound/rangos/levelup.wav"
const MAX_IDLE_TIME = 60 

enum 
{
	CAMPO_RANGO,
	CAMPO_FRAGS,
	CAMPO_PUNTOS,
	// Configuraciones
	CAMPO_HUD_RED,
	CAMPO_HUD_GREEN,
	CAMPO_HUD_BLUE,
	CAMPO_HUD_ENABLED,
	CAMPO_MAX
}

enum _:DATAMOD
{
	RANGES_NAMES[33],
	RANGES_FRAGS
}

new const ranges[][DATAMOD] =
{
	{ "Sin Rango", 1 },
	{ "Recluta", 50 },
	{ "Novato", 150 },
	{ "Principiante", 200 },
	{ "Sargento I", 400 },
	{ "Sargento II", 600 },
	{ "Sargento II", 800 },
	{ "Sargento Grado I", 1200 },
	{ "Sargento Grado II", 1600 },
	{ "Sargento Grado II", 2000 },
	{ "Sargento Grado Mayor", 3000 },
	{ "Teniente", 5000 },
	{ "Teniente Mayor", 8000 },
	{ "Coronel", 12000 },
	{ "Coronel Mayor", 16000 },
	{ "General", 20000 },
	{ "General Mayor", 30000 },
	{ "General En Jefe", 50000 }
}

enum _:ADM_DATA
{
	ADMIN_TYPE[30], 
	ADMIN_FLAGS
}

new const AdminsPrefix[][ADM_DATA] =
{
	{ "Fundador", ADMIN_RCON }, 
	{ "Staff", ADMIN_LEVEL_F }, 
	{ "Encargado", ADMIN_LEVEL_G },
	{ "Socio", ADMIN_LEVEL_H },
	{ "Administrador", ADMIN_ADMIN },  
	{ "VIP", ADMIN_KICK }
}

/*new const ADMINMODELS[][] = 
{
	// admin * hombres
	"nst_admin_male_ct",
	"nst_admin_male_tt"
}*/

new const PROHIBITED_NAME[][] =
{
	"Player",
	"<Warrior> Player",
	"empty",
	"unnamed"
}

new const REPEAT_NAME[][] =
{
	"(1)",
	"(2)",
	"(3)",
	"(4)",
	"(5)",
	"(6)",
	"(7)"
}

new const ResetScoreCMD[][] = 
{
	"say /rs", "say rs", "say .rs", 
	"say_team  /rs", "say_team rs", "say_team .rs"
}

enum (+=100)
{
	TASK_SHOWHUD,
	TASK_CONNMSJ
}

#define ID_SHOWHUD (taskid - TASK_SHOWHUD)
#define ID_CONNMSJ (taskid - TASK_CONNMSJ)

new g_campo[CAMPO_MAX]
new g_vaultR
new g_vaultH

new g_playername[MAX_PLAYERS+1][32]
new g_playerauthid[MAX_PLAYERS+1][32]
new g_playerpais[MAX_PLAYERS+1][46]
new g_playerip[MAX_PLAYERS+1][32]

new g_maxplayers

new g_ranges[MAX_PLAYERS+1]
new g_frags[MAX_PLAYERS+1]
new g_points[MAX_PLAYERS+1]

// Hud "Damge, Kills"
new g_frags2[MAX_PLAYERS+1]
new g_danio[MAX_PLAYERS+1]

// Prefix Administrativos
new AdminType[MAX_PLAYERS+1][30]
new cvar_adminlisten, admlisten

// ABD
new g_type, g_enabled, g_recieved, bool:g_showrecieved

new g_showhud[6]
new bool:g_happyhour
new g_currentmap[100]
new ct_score, terrorist_score
new g_countweaponsbuy[33]

// Configuraciones
new g_hudred[33], g_hudgreen[33], g_hudblue[33]
new g_hud_enabled[33]
new g_camera[33]

/*public plugin_precache()
{
	precache_model("models/rpgrocket.mdl")
	precache_sound(g_sound_lvlup)

	for(new i = 0; i < sizeof ADMINMODELS; i++)
	{
		PrecachePlayerModel(ADMINMODELS[i])
	}
}*/

public plugin_init()
{
	register_plugin(g_plugin[0], g_plugin[1], g_plugin[2])
	
	RegisterHookChain(RG_CBasePlayer_Killed, "@Killed_OnPlayer", .post = true)
	RegisterHookChain(RG_CBasePlayer_DropIdlePlayer, "OnPlayerDropIdle_Pre", false)
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "@TakeDamage_OnPlayer", .post = false)
	RegisterHookChain(RG_CBasePlayer_Spawn, "@Spawn_OnPlayer")

	register_event("Damage", "on_damage", "b", "2!0", "3=0", "4!0")  
	register_event("HLTV", "on_new_round", "a", "1=0", "2=0")
	
	register_event("TeamScore", "event_team_score", "a")
	
	for(new i = 0; i < sizeof(ResetScoreCMD); i++)
		register_clcmd(ResetScoreCMD[i], "reset_score")
	
	register_concmd("amxx_dar_frags", "cmd_frags", _, "<Nombre> <Frags> - Dar frags a un jugador")
	register_concmd("amxx_dar_puntos", "cmd_points", _, "<Nombre> <Puntos> - Dar puntos a un jugador")
	register_concmd("amxx_dar_vida", "cmd_vida", _, "<Nombre> <Vida> - Dar vida a un jugador", 0)
	
	register_clcmd("say", "clcmd_say")
	register_clcmd("say_team", "clcmd_teamsay")
	//register_clcmd("say /tienda", "amxx_menu_articulos_principal")
	register_clcmd("nightvision", "amxx_menu_principal")
	register_clcmd("say /cam", "amxx_menu_camera")

	register_message(get_user_msgid("SayText"), "MessageNameChange")

	g_type = register_cvar("amx_bulletdamage","1")
	g_recieved = register_cvar("amx_bulletdamage_recieved","1")

	cvar_adminlisten = register_cvar( "amx_adminlisten", "2" )
	admlisten = get_pcvar_num(cvar_adminlisten)
	
	g_maxplayers = get_maxplayers();
	
	g_showhud[0] = CreateHudSyncObj();
	g_showhud[1] = CreateHudSyncObj();
	g_showhud[2] = CreateHudSyncObj();
	g_showhud[3] = CreateHudSyncObj();
	g_showhud[4] = CreateHudSyncObj();
	g_showhud[5] = CreateHudSyncObj();

	get_mapname(g_currentmap, charsmax(g_currentmap))

	g_vaultR = adv_vault_open("rangos_system_vault")
	g_campo[CAMPO_RANGO] = adv_vault_register_field(g_vaultR, "Rangos")
	g_campo[CAMPO_FRAGS] = adv_vault_register_field(g_vaultR, "Frags")
	g_campo[CAMPO_PUNTOS] = adv_vault_register_field(g_vaultR, "Puntos")
	adv_vault_init(g_vaultR)

	g_vaultH = adv_vault_open("rangos_system_hud")
	g_campo[CAMPO_HUD_RED] = adv_vault_register_field(g_vaultH, "Red")
	g_campo[CAMPO_HUD_GREEN] = adv_vault_register_field(g_vaultH, "Green")
	g_campo[CAMPO_HUD_BLUE] = adv_vault_register_field(g_vaultH, "Blue")
	g_campo[CAMPO_HUD_ENABLED] = adv_vault_register_field(g_vaultH, "Enabled")
	adv_vault_init(g_vaultH) 
}

public plugin_cfg()
{
	set_task(0.1, "happy_hour") // Happy Hour
	set_task(1.0, "ShowHUD_score", _, _, _, "b") // Score Team

	set_cvar_num("mp_autokick", 1) // Afk Kick (enable)
	set_cvar_num("mp_autokick_timeout", MAX_IDLE_TIME) // Afk kick Time (enable)
}

public event_team_score()
{
	new team[32];
	read_data(1, team, 31);
	if(equal(team, "CT"))
	{
		ct_score = read_data(2);
	}
	else if (equal(team, "TERRORIST"))
	{
		terrorist_score = read_data(2);
	}
	
}

public on_new_round()
{
	g_enabled = get_pcvar_num(g_type)
	if(get_pcvar_num(g_recieved)) g_showrecieved = true    
}

public client_putinserver(id)
{
	get_user_name(id, g_playername[id], charsmax(g_playername[]))
	get_user_authid(id, g_playerauthid[id], charsmax(g_playerauthid[]))

	reset_vars(id, 1)
	
	if(is_user_admin(id))
	{
		static i, flags; flags = get_user_flags(id)
		
		for(i = 0 ; i < sizeof AdminsPrefix ; i++ )
		{
			if(flags & AdminsPrefix[i][ADMIN_FLAGS])
			{
				formatex(AdminType[id], charsmax(AdminType), "%s", AdminsPrefix[i][ADMIN_TYPE])
				break;
			}
		}
	}
	

	set_task(300.0, "give_points_1", id)
	set_task(600.0, "give_points_2", id)
	set_task(900.0, "give_points_3", id)

	if(!is_user_bot(id))
	{
		set_task(1.0, "ShowHUD", id + TASK_SHOWHUD,  _, _, "b") // Hud del Jugador
		set_task(0.1, "Mensaje_Connect", id + TASK_CONNMSJ) // Mensaje de Conexión
		set_task(0.5, "check_player_name", id) // Check player name
		set_task(6.0, "Welcome_Mensaje", id) // Mensaje de bienvenida
	}

	load_rangos(id)
	load_huds(id)
}

public Mensaje_Connect(id)
{
	remove_task(id + TASK_CONNMSJ)
	
	if(is_user_admin(id))
	{

		client_print_color(0, print_team_default, "^4[AMXX] ^1El ^4%s ^3%s ^1Se ha conectado desde: ^4(%s) ^3- ^4(%s)^1.", AdminType[id], g_playername[id], g_playerpais[id], get_player_steam(id) ? "STEAM" : "NO STEAM")
	}
	else
	{
		client_print_color(0, print_team_default, "^4[AMXX] ^1El Jugador ^3%s ^1Se ha conectado desde: ^4(%s) ^3- ^4(%s)^1.", g_playername[id], g_playerpais[id], get_player_steam(id) ? "STEAM" : "NO STEAM")
	}

	get_client_info(id)
	client_cmd(0, "spk buttons/bell1.wav")
}

public Welcome_Mensaje(id)
{
	if(get_user_flags(id) & ADMIN_RCON)
	{
		client_print_color(id, print_team_blue, "^4[AMXX] ^1Bienvenido ^4Jefe ^1espero disfrute su llegada al servidor.")
		client_print_color(id, print_team_blue, "^4[AMXX] ^1Puede cólocar cajas de munición colocando en consola ^4open_ammobox_menu^1. Inténtelo")
		client_print_color(id, print_team_blue, "^4[AMXX] ^1Su nombre: ^4%s ^3|^1 Su SteamID: ^4%s ^3|^1 Su IP: ^4%s", g_playername[id], g_playerauthid[id], g_playerip[id])
	}
	else
	{
		client_print_color(id, print_team_red, "^4[AMXX] ^1Bienvenido a ^4Barbacoas Community^3.VE")
		client_print_color(id, print_team_blue, "^4[AMXX] ^1Tú rango es: ^4%s ^3|^1 Tus Frag's: ^4%d", ranges[g_ranges[id]][RANGES_NAMES], g_frags[id])
	}
}

public client_disconnected(id)
{
	remove_task(id + TASK_SHOWHUD)
	
	if(task_exists(id))
		remove_task(id)

	if(is_user_admin(id))
	{
		client_print_color(0, print_team_default, "^4[AMXX] ^1El ^4%s ^3%s ^1Se ha desconectado. ^3(^4%s^3) ^1- ^3(^4%s^3)^1.", AdminType[id], g_playername[id], g_playerpais[id], get_player_steam(id) ? "STEAM" : "NO STEAM")
	}
	else
	{
		client_print_color(0, print_team_default, "^4[AMXX] ^1El ^4Jugador ^3%s ^1Se ha desconectado. ^3(^4%s^3) ^1- ^3(^4%s^3)^1.", g_playername[id], g_playerpais[id], get_player_steam(id) ? "STEAM" : "NO STEAM")
	}

	get_client_info(id)
	client_cmd(0, "spk fvox/blip.wav")

	save_rangos(id)
	save_huds(id)
}

@Killed_OnPlayer(victim, attacker)
{
	if(attacker == victim || !is_user_connected(victim) || !is_user_connected(attacker))
	return; 

    g_frags2[attacker]++


    if(g_happyhour)
	{
		if(is_user_admin(attacker))
		{
			check_range_levelup(attacker, 3)
			g_points[attacker] += 3
		}
		else
		{
			check_range_levelup(attacker, 2)
			g_points[attacker] += 2
		}
	}
	else
	{
		if(is_user_admin(attacker))
		{
			check_range_levelup(attacker, 1)
			g_points[attacker]++
		}
		else
		{
			check_range_levelup(attacker, 1)
			g_points[attacker]++
		}
		save_rangos(attacker)
	}
}

@TakeDamage_OnPlayer(victim, inflictor, attacker, Float:damage, damage_type)
{
	if(victim == attacker || !is_user_connected(attacker))
		return HC_CONTINUE
		
	g_danio[attacker] += floatround(damage)
	
	return HC_CONTINUE
}

/*@Spawn_OnPlayer(id)
{
	if(!is_user_alive(id)|| !is_user_connected(id))
		return;

	// skins admins
	new flags = get_user_flags(id)
	new team = get_user_team(id)

	if(flags & ADMIN_LEVEL_F)
	{
		switch(team)
		{
			case 1: cs_set_user_model(id, ADMINMODELS[0]) // CT
			case 2: cs_set_user_model(id, ADMINMODELS[1]) // TT
		}
	}
}*/

public on_damage(id)
{
    if(g_enabled)
    {        
        static attacker; attacker = get_user_attacker(id)
        static damage; damage = read_data(2)        
        if(g_showrecieved)
        {            
            set_hudmessage(255, 0, 0, 0.45, 0.50, 2, 0.1, 4.0, 0.1, 0.1, -1)
            ShowSyncHudMsg(id, g_showhud[3], "-%i^n", damage)        
        }
        if(is_user_connected(attacker))
        {
            switch(g_enabled)
            {
                case 1: {
                    set_hudmessage(0, 255, 255, -1.0, 0.55, 2, 0.1, 4.0, 0.02, 0.02, -1)
                    ShowSyncHudMsg(attacker, g_showhud[4], "+%i^n", damage)                
                }
                case 2: {
                    //if(fm_is_ent_visible(attacker,id))
                    if(engset_view(attacker, id))
                    {
                        set_hudmessage(0, 255, 255, -1.0, 0.55, 2, 0.1, 4.0, 0.02, 0.02, -1)
                        ShowSyncHudMsg(attacker, g_showhud[4], "+%i^n", damage)                
                    }
                }
            }
        }
    }
}

public check_range_levelup(id, frags)
{
	g_frags[id] += frags
	
	set_hudmessage(0, 255, -1, 0.16, 0.88, 0, 6.0, 1.1, 0.0, 0.0)
	ShowSyncHudMsg(id, g_showhud[2], "+%d Frag%s", frags, frags > 1 ? "s" : "")
	
	new range_levelup = false
	
	while(g_frags[id] >= ranges[g_ranges[id]][RANGES_FRAGS])
	{
		g_ranges[id]++
		range_levelup = true
	}
	
	if(range_levelup)
	{
		client_print_color(id, print_team_blue, "^4[^1BBC^4] ^3¡^4Felicidades^3! ^1Lograste ascender al rango: ^4%s", ranges[g_ranges[id]][RANGES_NAMES])
		client_print_color(id, print_team_blue, "^4[^1BBC^4] ^3¡^4Felicidades^3! ^1Lograste ascender al rango: ^4%s", ranges[g_ranges[id]][RANGES_NAMES])
		client_print_color(id, print_team_blue, "^4[^1BBC^4] ^3¡^4Felicidades^3! ^1Lograste ascender al rango: ^4%s", ranges[g_ranges[id]][RANGES_NAMES])
		show_screenfade(id, 0, 150, 0)
		client_cmd(id, "spk ^"%s^"", g_sound_lvlup)
		/* -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
		client_print_color(0, print_team_blue, "^4[^1BBC^4] ^1El jugador ^3%s (%s) ^1acaba de subir de ^3rango^1: ^4%s ", g_playername[id], g_playerauthid[id], ranges[g_ranges[id]][RANGES_NAMES])
	}
	save_rangos(id)
}

public amxx_menu_principal(id)
{
	if(!is_user_connected(id))
		return;

	static menuid[512];

	format(menuid, charsmax(menuid), "\r[BBC-CSO] \wHola \y%s\w, Bienvenido\r.^n\r[AMXX-CSO] \wCapture The Flag \rv\y2.6\wb\r. \dMapa Actual: \y%s", g_playername[id], g_currentmap)
	new menu = menu_create(menuid, "handler_ctf_menu_prin")

	if(get_user_frags(id) == 0 && get_user_deaths(id) == 0)
		format(menuid, charsmax(menuid), "\dReiniciar Puntuación")
	else
		format(menuid, charsmax(menuid), "Reiniciar Puntuación")
	menu_additem(menu, menuid)

	/*format(menuid, charsmax(menuid), "Tienda de Armamento Especial^n")
	menu_additem(menu, menuid)*/

	menu_additem(menu, "Configuraciones Generales")
	menu_additem(menu, "Estadísticas Principales")

	menu_additem(menu, (is_user_admin(id) ? "Administración":"\dAdministración \r(\dNo tienes acceso\r)"))

	menu_addtext(menu, "^n\yINFO: \dServidor \wCapture The Flag \rv\y2.6\wb\r \d- \dCreado por \yAlfredo\d.")

	menu_setprop(menu, MPROP_EXITNAME, "Salir\r.")
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0)
}

public handler_ctf_menu_prin(id, menu, item)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED;
	}

	switch(item)
	{
		case 0: reset_score(id)
		//case 1: amxx_menu_articulos_principal(id)
		case 1: amxx_menu_config(id)
		case 2: amxx_menu_estadisticas(id) //client_print_color(id, print_team_default, "^4[AMXX] ^1En construcción...")
		case 3: amxx_menu_admin(id) //client_print_color(id, print_team_default, "^4[AMXX] ^1En construcción...")
	}
	return PLUGIN_HANDLED;
}

/*public amxx_menu_articulos_principal(id)
{
	if(!is_user_connected(id))
		return;

	static menuid[512]

	format(menuid, charsmax(menuid), "\r[BBC-CSO] \wBienvenido \y%s\w... A nuestra tienda de armamento.^nElige cuál tipo de arma compraras.", g_playername[id])
	new menu = menu_create(menuid, "handler_amxx_arp")

	format(menuid, charsmax(menuid), "Armamento/Armas Pesadas \r[ \y GAMA ALTA \r]")
	menu_additem(menu, menuid)

	format(menuid, charsmax(menuid), "Armamento/Armas Primarias \r[ \yGAMA MEDIA \r]")
	menu_additem(menu, menuid)

	format(menuid, charsmax(menuid), "Armamento/Armas Semi-Primarias \r[ \yGAMA BAJA \r]")
	menu_additem(menu, menuid)

	format(menuid, charsmax(menuid), "Armamentos/Armas Secundarias \r[ \yGAMA BAJA \r]")
	menu_additem(menu, menuid)

	menu_setprop(menu, MPROP_EXITNAME, "\wVolver\r.")
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0)
}

public handler_amxx_arp(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		amxx_menu_principal(id)
		return PLUGIN_HANDLED;
	}

	switch(item)
	{
		case 0: client_print_color(id, print_team_default, "^4[AMXX] ^1En construcción...")
		case 1: amxx_menu_primario(id)
		case 2: client_print_color(id, print_team_default, "^4[AMXX] ^1En construcción...")
		case 3: amxx_menu_secundario(id)
	}
	return PLUGIN_HANDLED;
}

public amxx_menu_primario(id)
{
	if(!is_user_connected(id))
		return;

	static menuid[512]

	format(menuid, charsmax(menuid), "\r[BBC-CSO] \wTienda de Armamento de Primario\r. \dPuntos: \r[\y%d\r]\w.^n\yNOTA: \dLas armas se comprarán con puntos\r.", g_points[id])
	new menu = menu_create(menuid, "handler_amxx_ar")

	format(menuid, charsmax(menuid), "Steyr AUG (Avanzada) \r[\y $200 \r] %s", g_countweaponsbuy[id] >= 4? "\d[No puedes comprar mas]" : "")
	menu_additem(menu, menuid)

	menu_setprop(menu, MPROP_EXITNAME, "\wVolver\r.")
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0)
}

public handler_amxx_ar(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		amxx_menu_principal(id)
		return PLUGIN_HANDLED;
	}

	switch(item)
	{
		case 0:
		{
			if(g_points[id] >= 200 && g_countweaponsbuy[id] <= 3)
			{
				client_cmd(id, "a1213d_02")
				g_points[id] -= 200
				client_print_color(id, print_team_blue, "^4[^1BBC^4] ^3¡Felicidades! ^1Compraste una ^3Steyr AUG (Avanzada)^1, ^4Disfrutala^1.")
				//display_hud_sprite(id, spritemsg, 0.04, 2, 0.8)
				g_countweaponsbuy[id]++

			}
			else
			{
				client_print_color(id, print_team_default, "^4[^1BBC^4] ^3¡Lo siento! ^1No tienes ^4suficientes ^3monedas^1 o se agotó la oportunidad de comprar.")
				amxx_menu_primario(id)
				return PLUGIN_HANDLED;
			}
		}
	}
	return PLUGIN_HANDLED;
}

public amxx_menu_secundario(id)
{
	if(!is_user_connected(id))
		return;

	static menuid[512]

	format(menuid, charsmax(menuid), "\r[BBC-CSO] \wTienda de Armamento Secundario\r. \dPuntos: \r[\y%d\r]\w.^n\yNOTA: \dLas armas se comprarán con puntos\r.", g_points[id])
	new menu = menu_create(menuid, "handler_amxx_ar2")

	format(menuid, charsmax(menuid), "Dual Beretta Gunslinger Frost\r \r[\y $150 \r] %s", g_countweaponsbuy[id] >= 4? "\d[No puedes comprar mas]" : "")
	menu_additem(menu, menuid)

	menu_setprop(menu, MPROP_EXITNAME, "\wVolver\r.")
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0)
}

public handler_amxx_ar2(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		amxx_menu_articulos_principal(id)
		return PLUGIN_HANDLED;
	}

	switch(item)
	{
		case 0:
		{
			if(g_points[id] >= 150 && g_countweaponsbuy[id] <= 3)
			{
				client_cmd(id, "a1213d_0")
				g_points[id] -= 150
				client_print_color(id, print_team_blue, "^4[^1BBC^4] ^3¡Felicidades! ^1Compraste una ^3Dual Beretta Gunslinger^1, ^4Disfrutala^1.")
				g_countweaponsbuy[id]++

			}
			else
			{
				client_print_color(id, print_team_default, "^4[^1BBC^4] ^3¡Lo siento! ^1No tienes ^4suficientes ^3monedas^1 o se agotó la oportunidad de comprar.")
				amxx_menu_secundario(id)
				return PLUGIN_HANDLED;
			}
		}

	}
	return PLUGIN_HANDLED;
}*/

public amxx_menu_config(id)
{
	if(!is_user_connected(id))
		return;

	static menuid[512];
	new menu = menu_create("\r[BBC-CSO] \wConfiguración Principal.^n\r¡\wPróximamente\r! \wMás configuraciones.", "handler_amxx_config")


	if(g_hud_enabled[id] == 1)
		format(menuid, charsmax(menuid), "Color del hud \r(Rangos)\w: \d(\y%s\d)", g_hudred[id] == 255 && g_hudgreen[id] == 255 && g_hudblue[id] == 255 ? "Blanco" : g_hudred[id] == 0 && g_hudgreen[id] == 200 && g_hudblue[id] == 0 ? "Verde" :  g_hudred[id] == 255 && g_hudgreen[id] == 0 && g_hudblue[id] == 0 ? "Rojo" : g_hudred[id] == 0 && g_hudgreen[id] == 0 && g_hudblue[id] == 200 ? "Azul" : g_hudred[id] == 0 && g_hudgreen[id] == 200 && g_hudblue[id] == 200 ? "Azul Aqua" : g_hudred[id] == 128 && g_hudgreen[id] == 0 && g_hudblue[id] == 255 ? "Violeta" : g_hudred[id] == 255 && g_hudgreen[id] == 255 && g_hudblue[id] == 0 ? "Amarillo" : g_hudred[id] == 255 && g_hudgreen[id] == 128 && g_hudblue[id] == 0 ? "Naranja" : "")
	else
		format(menuid, charsmax(menuid), "\dColor del Hud \r(Rangos)\w: d(Ningúno)")
	menu_additem(menu, menuid)

	if(g_hud_enabled[id] == 1)
		format(menuid, charsmax(menuid), "Deshabilitar Hud \r(Rangos)")
	else
		format(menuid, charsmax(menuid), "Habilitar Hud \r(Rangos)")
	menu_additem(menu, menuid)

	menu_setprop(menu, MPROP_EXITNAME, "Volver\r.")
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0)
}

public handler_amxx_config(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		amxx_menu_principal(id)
		return PLUGIN_HANDLED;
	}

	switch(item)
	{
		case 0:
		{
			if(g_hud_enabled[id] == 1)
			{
				amxx_menu_config_colors(id)
			}
			else
			{
				client_print_color(id, print_team_default, "^4[^1BBC^4] ^1No puedes usar esto si tú hud ^3(Rangos) ^1está deshabilitado.")
			}
		}
		case 1:
		{
			//(g_hud_enabled[id] == 1) ? (g_hud_enabled[id] = 0) : (g_hud_enabled[id] = 1)
			client_print_color(id, print_team_default, "^4[^1BBC^4] ^1En construcción...")
			amxx_menu_config(id)
			save_huds(id)
		}
	}
	return PLUGIN_HANDLED;
}

public amxx_menu_config_colors(id)
{
	if(!is_user_connected(id))
		return;

	new menu = menu_create("\r[ABBC] \wColor del Hud \r(Rangos)\w.^nElige el color más adecúado para ti.", "handler_amxx_hud_colors")

	menu_additem(menu, (g_hudred[id] == 255 && g_hudgreen[id] == 255 && g_hudblue[id] == 255 ? "Color Blanco \d(\yActual\d)" : "Color Blanco"))
	menu_additem(menu, (g_hudred[id] == 0 && g_hudgreen[id] == 200 && g_hudblue[id] == 0 ? "Color Verde \d(\yActual\d)" : "Color Verde"))
	menu_additem(menu, (g_hudred[id] == 255 && g_hudgreen[id] == 0 && g_hudblue[id] == 0 ? "Color Rojo \d(\yActual\d)" : "Color Rojo"))
	menu_additem(menu, (g_hudred[id] == 0 && g_hudgreen[id] == 0 && g_hudblue[id] == 200 ? "Color Azul \d(\yActual\d)" : "Color Azul"))
	menu_additem(menu, (g_hudred[id] == 0 && g_hudgreen[id] == 200 && g_hudblue[id] == 200 ? "Color Azul Aqua \d(\yActual\d)" : "Color Azul Aqua"))
	menu_additem(menu, (g_hudred[id] == 128 && g_hudgreen[id] == 0 && g_hudblue[id] == 255 ? "Color Violeta \d(\yActual\d)" : "Color Violeta"))
	menu_additem(menu, (g_hudred[id] == 255 && g_hudgreen[id] == 255 && g_hudblue[id] == 0 ? "Color Amarillo \d(\yActual\d)" : "Color Amarillo"))
	menu_additem(menu, (g_hudred[id] == 255 && g_hudgreen[id] == 128 && g_hudblue[id] == 0 ? "Color Naranja \d(\yActual\d)" : "Color Naranja"))

	menu_setprop(menu, MPROP_EXITNAME, "Volver\r")
	menu_setprop(menu, MPROP_BACKNAME, "Página Atrás\r.")
	menu_setprop(menu, MPROP_NEXTNAME, "Página Siguiente\r.")
	menu_display(id, menu, 0)
}

public handler_amxx_hud_colors(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		amxx_menu_config(id)
		return PLUGIN_HANDLED;
	}

	switch(item)
	{
		case 0:
		{
			if(g_hudred[id] == 255 && g_hudgreen[id] == 255 && g_hudblue[id] == 255)
			{
				client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Ya tienes este color.")
				amxx_menu_config_colors(id)
				return PLUGIN_HANDLED;
			}

			g_hudred[id] = 255
			g_hudgreen[id] = 255
			g_hudblue[id] = 255
			amxx_menu_config_colors(id)
			save_huds(id)
		}
		case 1:
		{
			if(g_hudred[id] == 0 && g_hudgreen[id] == 200 && g_hudblue[id] == 0)
			{
				client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Ya tienes este color.")
				amxx_menu_config_colors(id)
				return PLUGIN_HANDLED;
			}

			g_hudred[id] = 0
			g_hudgreen[id] = 200
			g_hudblue[id] = 0
			amxx_menu_config_colors(id)
			save_huds(id)
		}
		case 2:
		{
			if(g_hudred[id] == 255 && g_hudgreen[id] == 0 && g_hudblue[id] == 0)
			{
				client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Ya tienes este color.")
				amxx_menu_config_colors(id)
				return PLUGIN_HANDLED;
			}

			g_hudred[id] = 255
			g_hudgreen[id] = 0
			g_hudblue[id] = 0
			amxx_menu_config_colors(id)
			save_huds(id)
		}
		case 3:
		{
			if(g_hudred[id] == 0 && g_hudgreen[id] == 0 && g_hudblue[id] == 200)
			{
				client_print_color(id, print_team_default, "^4[AMXX] ^1Ya tienes este color.")
				amxx_menu_config_colors(id)
				return PLUGIN_HANDLED;
			}

			g_hudred[id] = 0
			g_hudgreen[id] = 0
			g_hudblue[id] = 200
			amxx_menu_config_colors(id)
			save_huds(id)
		}
		case 4:
		{
			if(g_hudred[id] == 0 && g_hudgreen[id] == 200 && g_hudblue[id] == 200)
			{
				client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Ya tienes este color.")
				amxx_menu_config_colors(id)
				return PLUGIN_HANDLED;
			}

			g_hudred[id] = 0
			g_hudgreen[id] = 200
			g_hudblue[id] = 200
			amxx_menu_config_colors(id)
			save_huds(id)
		}
		case 5:
		{
			if(g_hudred[id] == 128 && g_hudgreen[id] == 0 && g_hudblue[id] == 255)
			{
				client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Ya tienes este color.")
				amxx_menu_config_colors(id)
				return PLUGIN_HANDLED;
			}

			g_hudred[id] = 128
			g_hudgreen[id] = 0
			g_hudblue[id] = 255
			amxx_menu_config_colors(id)
			save_huds(id)
		}
		case 6:
		{
			if (g_hudred[id] == 255 && g_hudgreen[id] == 255 && g_hudblue[id] == 0)
			{
				client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Ya tienes este color.")
				amxx_menu_config_colors(id)
				return PLUGIN_HANDLED;
			}
			
			g_hudred[id] = 255
			g_hudgreen[id] = 255
			g_hudblue[id] = 0
			amxx_menu_config_colors(id)
			save_huds(id)
		}
		case 7:
		{
			if (g_hudred[id] == 255 && g_hudgreen[id] == 128 && g_hudblue[id] == 0)
			{
				client_print_color(id, print_team_default, "^4[^1BCC^4] ^1Ya tienes este color.")
				amxx_menu_config_colors(id)
				return PLUGIN_HANDLED;
			}
			
			g_hudred[id] = 255
			g_hudgreen[id] = 128
			g_hudblue[id] = 0
			amxx_menu_config_colors(id)
			save_huds(id)
		}
	}
	
	return PLUGIN_HANDLED;
}

public amxx_menu_camera(id)
{
	if(!is_user_connected(id))
		return;

	new menu = menu_create("\r[BBC]\w Elige una camara de vista.", "handler_amxx_camera")

	menu_additem(menu, (g_camera[id] == 1 ? "Vista normal: \d(\yACTUAL\d)" : "Vista normal"))
	menu_additem(menu, (g_camera[id] == 2 ? "Vista en tercera persona: \d(\yACTUAL\d)" : "Vista en tercera persona"))
	menu_additem(menu, (g_camera[id] == 3 ? "Vista desde arriba: \d(\yACTUAL\d)" : "Vista desde arriba"))

	menu_setprop(menu, MPROP_EXITNAME, "Volver\r.")
	menu_display(id, menu, 0)
}

public handler_amxx_camera(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED;
	}

	switch(item)
	{
		case 0:
		{
			set_view(id, CAMERA_NONE)
			g_camera[id] = 1
			amxx_menu_camera(id)
		}
		case 1:
		{
			set_view(id, CAMERA_3RDPERSON)
			g_camera[id] = 2
			amxx_menu_camera(id)
		}
		case 2:
		{
			set_view(id, CAMERA_TOPDOWN)
			g_camera[id] = 3
			amxx_menu_camera(id)
		}
	}
	return PLUGIN_HANDLED;
}

public amxx_menu_estadisticas(id)
{
	if(!is_user_connected(id))
		return;

	static menuid[512]

	format(menuid, charsmax(menuid), "\r[BBC-CSO]\d ¡Hola de nuevo \y%s\d! \wEstás son tus estadísticas\r. ", g_playername[id])
	new menu = menu_create(menuid, "handler_amxx_estats")

	format(menuid, charsmax(menuid), "Nombre: %s", g_playername[id])
	menu_additem(menu, menuid)

	format(menuid, charsmax(menuid), "IP: %s", g_playerip[id])
	menu_additem(menu, menuid)

	format(menuid, charsmax(menuid), "País: %s^n", g_playerpais[id])
	menu_additem(menu, menuid)

	format(menuid, charsmax(menuid), "Rango: %s | Frag%s: %d/%d", ranges[g_ranges[id]][RANGES_NAMES], g_frags[id] > 1? "'s" : "", g_frags[id], (ranges[g_ranges[id]][RANGES_FRAGS]))
	menu_additem(menu, menuid)

	menu_setprop(menu, MPROP_EXITNAME, "Volver\r.")
	menu_display(id, menu, 0)
}

public handler_amxx_estadisticas(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		amxx_menu_estadisticas(id)
		return PLUGIN_HANDLED; 
	}

	switch(item)
	{
		case 0..3: amxx_menu_estadisticas(id)
	}
	return PLUGIN_HANDLED;
}

public amxx_menu_admin(id)
{
	if(!is_user_connected(id))
		return;
	
	new menu = menu_create("\r[BBC-CSO] \yPanel Administrativo \wCapture The Flag \rv\y2.6\wb\r. ", "handler_ctf_admin_menu")

	menu_additem(menu, access(id, ADMIN_RCON) ? "Mover Bandera \rROJA" : "\dMover Bandera \rROJA \w[NO TIENES ACCESO]")
	menu_additem(menu, access(id, ADMIN_RCON) ? "Mover Bandera \rAZUL" : "\dMover Bandera\rAZUL \w[NO TIENES ACCESO]")
	menu_additem(menu, access(id, ADMIN_BAN) ? "Banear Jugador/Administrador" : "\dBanear Jugador/Administrador \w[NO TIENES ACCESO]")
	menu_additem(menu, access(id, ADMIN_IMMUNITY) ? "Destruir Jugador/Administrador" : "\dDestruir Jugador/Administrador \w[NO TIENES ACCESO]")
	menu_additem(menu, access(id, ADMIN_MAP) ? "Votación de Mapas" : "\dVotación de Mapas \w[NO TIENES ACCESO]")
	menu_additem(menu, access(id, ADMIN_IMMUNITY) ? "Cólocar Caja de munición" : "\dCólocar Caja de munición \w[NO TIENES ACCESO]")

	menu_addtext(menu, "^n\yIMPORTANTE: \dAntes de Banear un Jugador débes de tener pruebas y razón del baneo.^nSolo los rangos como Socio/Staff y Fundadores pueden banear \yadministradores\r.")

	menu_setprop(menu, MPROP_EXITNAME, "Volver\r.")
	menu_display(id, menu, 0)
}

public handler_ctf_admin_menu(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		amxx_menu_principal(id)
		return PLUGIN_HANDLED;
	}

	switch(item)
	{
		case 0: if(access(id, ADMIN_RCON))	client_cmd(id, "ctf_moveflag ^"red^"")
		case 1: if(access(id, ADMIN_RCON))  client_cmd(id, "ctf_moveflag ^"blue^"")
		case 2: if(access(id, ADMIN_BAN))   client_cmd(id, "amx_banmenu")
		case 3: if(access(id, ADMIN_IMMUNITY)) amxx_menu_destroy(id)
		case 4: if(access(id, ADMIN_MAP))   client_cmd(id, "amx_votemapmenu")
		case 5: if(access(id, ADMIN_IMMUNITY)) client_cmd(id, "open_ammobox_menu")
	}
	return PLUGIN_HANDLED;
}

public amxx_menu_destroy(id)
{
	if(!is_user_connected(id))
		return;

	new menuid, num, players[32], tempid, szTempID[10], text[254]

	menuid = menu_create("\r[BBC-CSO] \wDestruir \dJugador/Administrador \wAntes de destruir graba demo^n\dEvita una Suspención", "menu_destroyid")

	get_players(players, num)

	for(new i = 0; i < num; i++)
	{
		tempid = players[i]

		if(is_user_bot(tempid) || (access(tempid, ADMIN_IMMUNITY)))
			formatex(text, charsmax(text), "\d%s", g_playername[tempid])
		else
			formatex(text, charsmax(text), "\w%s %s", g_playername[tempid], (is_user_admin(tempid) ? "\r*" : ""))

		num_to_str(tempid, szTempID, charsmax(szTempID))
		menu_additem(menuid, text, szTempID, _, menu_makecallback("menu_destroyid_callback"))
	}

	menu_setprop(menuid, MPROP_BACKNAME, "Página Atrás\r.")
	menu_setprop(menuid, MPROP_NEXTNAME, "Página Siguiente\r.")
	menu_setprop(menuid, MPROP_EXITNAME, "Volver\r.")
	menu_display(id, menuid, 0)
}

public menu_destroyid_callback(id, menuid, item)
{
	new iData[6];
	new iAccess;
	new iCallback;
	new iName[64];
	menu_item_getinfo(menuid, item, iAccess, iData, 5, iName, 63, iCallback) 
	
	new tempid = str_to_num(iData)

	// Player is a bot or have immunity?
	if (is_user_bot(tempid) || (access(tempid, ADMIN_IMMUNITY)))
		return ITEM_DISABLED;
	
	return ITEM_ENABLED;
}

public menu_destroyid(id, menuid, item)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;

	if(item == MENU_EXIT)
	{
		menu_destroy(menuid)
		amxx_menu_admin(id)
		return PLUGIN_HANDLED;
	}

	new iData[6];
	new iAccess;
	new iCallback;
	new iName[64];
	menu_item_getinfo(menuid, item, iAccess, iData, 5, iName, 63, iCallback) 
	
	new tempid = str_to_num(iData)
	
	// Perform action on player
	client_cmd(id, "amxx_destroy ^"%s^" ^"DESTRUIDO^"", g_playername[tempid])
	
	return PLUGIN_HANDLED;
}

public ShowHUD(taskid)
{
	new id = ID_SHOWHUD;

	if(!is_user_alive(id)) id = get_entvar(id, var_iuser2)

	if(id != ID_SHOWHUD)
	{
		//new Float:porcentage = (g_frags[id] * 100.0)/ranges[g_ranges[id]][RANGES_FRAGS]
		set_hudmessage(255, 255, 255, 0.02, 0.17, 0, 6.0, 1.1, 0.0, 0.0)
		ShowSyncHudMsg(id, g_showhud[1], "")
	}
	else
	{
		if(g_hud_enabled[ID_SHOWHUD] == 1)
		{
			new Float:porcentage = (g_frags[ID_SHOWHUD] * 100.0)/ranges[g_ranges[ID_SHOWHUD]][RANGES_FRAGS]
			set_hudmessage(g_hudred[ID_SHOWHUD], g_hudgreen[ID_SHOWHUD], g_hudblue[ID_SHOWHUD], 0.02, 0.17, 0, 6.0, 1.1, 0.0, 0.0)
			ShowSyncHudMsg(ID_SHOWHUD, g_showhud[0], "| Rango: %s |^n| Frag%s: %d/%d [%.2f%%] |^n| Punto%s: %d |^n| Hora Feliz: %s |", ranges[g_ranges[ID_SHOWHUD]][RANGES_NAMES], g_frags[id] > 1? "s" : "", g_frags[ID_SHOWHUD], (ranges[g_ranges[ID_SHOWHUD]][RANGES_FRAGS]), porcentage, g_points[ID_SHOWHUD] > 1? "s" : "", g_points[ID_SHOWHUD], g_happyhour ? "Activada" : "Des-activada")
		}
	}
}

public OnPlayerDropIdle_Pre(iId, szReason[]) 
{
    if( get_user_flags(iId) & ADMIN_LEVEL_A)
    {
        return HC_SUPERCEDE;
    }

    client_print_color(0, print_team_default, "^4[^1BBC^4]^3 %n^1 fue expulsado por estar mas de^4 %d segundos inactivo^1.", MAX_IDLE_TIME)
    
    SetHookChainArg(2, ATYPE_STRING, "Fuiste expulsado por permanecer inactivo %d segundos", MAX_IDLE_TIME)

    return HC_CONTINUE;
}

public check_player_name(id)
{
	// bot or HLTV ?
	if(is_user_bot(id) || is_user_hltv(id))
		return;

	// block player name
	for(new i = 0; i < sizeof(PROHIBITED_NAME); i++)
	{
		if(equal(g_playername[id], PROHIBITED_NAME[i]))
			server_cmd("kick #%d ^"¡Este nombre está prohibido! Cámbiese el nombre.^"", get_user_userid(id))
	}

	// repeat player name
	for(new i = 0; i < sizeof(REPEAT_NAME); i++)
	{
		if(contain(g_playername[id], REPEAT_NAME[i]) != -1)
			server_cmd("kick #%d ^"¡Este nombre ya está siendo usado! Cámbiese el nombre.^"", get_user_userid(id))
	}

}

public ShowHUD_score()
{
	for(new id = 1; id < g_maxplayers; id++)
	{
		if(!is_user_alive(id))
			continue;
		
		set_dhudmessage(255, 0, 0, 0.54, 0.0, 0, 0.5, 2.0, 0.8, 2.0)
		show_dhudmessage(id, "| Equipo Rojo^n       | %s%s%d |", terrorist_score > 9? "" : "0", terrorist_score > 99 ? "" : "0", terrorist_score)
		
		set_dhudmessage(0, 0, 255, 0.32, 0.0, 0, 0.5, 2.0, 0.08, 2.0)
		show_dhudmessage(id, "Equipo Azul | ^n    | %s%s%d |", ct_score > 9? "" : "0", ct_score > 99? "" : "0", ct_score)

		set_dhudmessage(255, 255, 255, 0.47, 0.0, 0, 0.5, 2.0, 0.08, 2.0)
		show_dhudmessage(id, "  Kill%s^n| %s%s%d |", g_frags2[id] > 1? "s" : "", g_frags2[id] > 9? "" : "0", g_frags2[id] > 99? "" : "0", g_frags2[id])
	}
}

public give_points_1(id)
{
	if(g_happyhour)
	{
		client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Obtienes ^3'+2 MONEDAS' ^1por jugar^4 5 ^1minutos en el servidor.")
		g_points[id] += 1 * 2
	}
	else
	{
		client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Obtienes ^3'+1 MONEDAS' ^1por jugar^4 5 ^1minutos en el servidor.")
		g_points[id] += 1
	}
	save_rangos(id)
}

public give_points_2(id)
{
	if(g_happyhour)
	{
		client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Obtienes ^3'+4 MONEDAS' ^1por jugar^4 10 ^1minutos en el servidor.")
		g_points[id] += 2 * 2
	}
	else
	{
		client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Obtienes ^3'+2 MONEDAS' ^1por jugar^4 10 ^1minutos en el servidor.")
		g_points[id] += 2
	}
	save_rangos(id)
}

public give_points_3(id)
{
	if(g_happyhour)
	{
		client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Obtienes ^3'+6 MONEDAS' ^1por jugar^4 15 ^1minutos en el servidor.")
		g_points[id] += 3 * 2
	}
	else
	{
		client_print_color(id, print_team_default, "^4[^1BBC^4] ^1Obtienes ^3'+3 MONEDAS' ^1por jugar^4 15 ^1minutos en el servidor.")
		g_points[id] += 3
	}
	save_rangos(id)
}

public reset_vars(id, resetall)
{
	if(resetall)
	{
		AdminType[id] = "^0"
		g_ranges[id] = 0
		g_frags[id] = 0
		g_frags2[id] = 0
		g_points[id] = 5
		g_camera[id] = 1
		g_hudred[id] = 255
		g_hudgreen[id] = 255
		g_hudblue[id] = 255
		g_hud_enabled[id] = 1
	}
}

public reset_score(id)
{
	new mu = get_user_deaths(id)
	new ki = get_user_frags(id)
	
	if(mu == 0 && ki == 0)
	{
		client_print_color(id, print_team_default, "^4[^1BBC^4] ^3¡^1Tu ^4puntuación ^1no puede ser reiniciada en este momento^3!")
		return PLUGIN_HANDLED;
	}
	else
	{
        set_entvar(id, var_frags, 0.0)
        set_member(id, m_iDeaths, 0)
        g_frags2[id] = 0
        client_print_color(id, print_team_default, "^4[^1BBC^4] ^3¡^1Tú ^4puntuación^1 fue reiniciada ^4exitosamente^3!")
        client_print_color(0, print_team_default, "^4[^1BBC^4] ^3¡^1El jugador ^3%s ^4(%s) ^1ha reiniciado sú ^4puntuación^3!", g_playername[id], get_player_steam(id) ? "STEAM" : "NO_STEAM")
        message_begin(MSG_ALL, 85)
        write_byte(id)
        write_short(0); write_short(0); write_short(0); write_short(0)
        message_end()
    }
	return PLUGIN_HANDLED;
} 

public clcmd_say(id)
{
	
	static said[191];
	
	read_args(said, charsmax(said));
	remove_quotes(said);
	replace_all(said, charsmax(said), "#", " ");
	
	
	if (!ValidMessage(said, 1)) return PLUGIN_CONTINUE;
	
	static color[11], prefix[91]
	get_user_team(id, color, charsmax(color))
	if(is_user_admin(id))
		formatex(prefix, charsmax(prefix), "%s^x01[ ^x04%s ^x01][ ^x04%s ^x01] ^x03%s:", is_user_alive(id) ? "^x01" : "^x03*MUERTO* ",  AdminType[id], ranges[g_ranges[id]][RANGES_NAMES], g_playername[id])
	else
		formatex(prefix, charsmax(prefix), "%s^x01[ ^x04Jugador ^x01][ ^x04%s ^x01] ^x03%s:", is_user_alive(id) ? "^x01" : "^x03*MUERTO* ", ranges[g_ranges[id]][RANGES_NAMES], g_playername[id])
	
	
	if(is_user_admin(id)) format(said, charsmax(said), "^x04%s", said)    
	
	format(said, charsmax(said), "%s^x01 %s", prefix, said)
	
	static i, team[11];
	for (i = 1; i <= g_maxplayers; i++)
	{
		if (!is_user_connected(i)) continue;
		
		if( admlisten == 0 && ( is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
		|| admlisten == 1 && (is_user_admin(i) || is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
		|| admlisten == 2 )
		{        
			get_user_team(i, team, charsmax(team))            
			changeTeamInfo(i, color)            
			writeMessage(i, said)
			changeTeamInfo(i, team)
		}
	}
	
	return PLUGIN_HANDLED_MAIN;
}

public clcmd_teamsay(id)
{
	static said[191];

	read_args(said, charsmax(said));
	remove_quotes(said);
	replace_all(said, charsmax(said), "#", " ");
	
	if (!ValidMessage(said, 1)) return PLUGIN_CONTINUE;
	
	static playerTeam, teamname[19];
	playerTeam = get_user_team(id);
	
	switch (playerTeam)
	{
		case 1: formatex( teamname, 18, "^x01[^x03 Rojos ^x01]")
		case 2: formatex( teamname, 18, "^x01[^x03 Azules ^x01]")
		default: formatex( teamname, 18, "^x01[^x03 Espectador ^x01]")
	}
	
	static color[11], prefix[91]
	get_user_team(id, color, charsmax(color))
	
	formatex(prefix, charsmax(prefix), "%s%s^x01[^x04 %s ^x01]^x03 %s",
	is_user_alive(id) ? "^x01" : "^x01*MUERTO* ",  teamname, AdminType[id], g_playername[id])
	
	if(is_user_admin(id)) format(said, charsmax(said), "^x04%s", said)    
	
	format(said, charsmax(said), "%s^x01: %s", prefix, said)
	
	static i, team[11];
	for (i = 1; i <= g_maxplayers ; i++)
	{
		if (!is_user_connected(i)) continue;
		
		if (get_user_team(i) == playerTeam)
		{
			if( admlisten == 0 && ( is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
			|| admlisten == 1 && (is_user_admin(i) || is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
			|| admlisten == 2 )
			{        
				get_user_team(i, team, charsmax(team))            
				changeTeamInfo(i, color)            
				writeMessage(i, said)
				changeTeamInfo(i, team)
			}
		}
	}
	
	return PLUGIN_HANDLED_MAIN;
}

public cmd_frags(id, level, cid)
{
	if (!cmd_access(id, ADMIN_LEVEL_C, cid, 2))
		return PLUGIN_HANDLED;

	static arg[32], arg2[6], g_amount

	read_argv(1, arg, sizeof arg -1)
	read_argv(2, arg2, sizeof arg2 - 1)
	
	new g_player = cmd_target(id, arg, CMDTARGET_NO_BOTS | CMDTARGET_ALLOW_SELF)

	if(!g_player)
	{
		client_print(id, print_console, "[BBC - ERROR] El jugador no se encuentra en el server. [NO FUNCIONA]")
		return PLUGIN_HANDLED;
	}

	g_amount = (str_to_num(arg2))

	client_print_color(0, print_team_default, "^4[^1BBC^4]^1 El admin:^4 %s^1 le ha dado:^3 '+%s FRAGS'^1 a:^4 %s^1.", g_playername[id], add_point(g_amount), g_playername[g_player])
	client_print_color(g_player, print_team_default, "^4[^1BBC^4]^1 El admin:^4 %s^1 te ha dado:^4 '+%s FRAGS'^1.", g_playername[id], add_point(g_amount))
	check_range_levelup(g_player, g_amount)

	save_rangos(g_player)

	return PLUGIN_HANDLED;
}

public cmd_points(id, level, cid)
{
	if (!cmd_access(id, ADMIN_LEVEL_C, cid, 2))
		return PLUGIN_HANDLED;

	static arg[32], arg2[6], g_amount

	read_argv(1, arg, sizeof arg -1)
	read_argv(2, arg2, sizeof arg2 - 1)
	
	new g_player = cmd_target(id, arg, CMDTARGET_NO_BOTS | CMDTARGET_ALLOW_SELF)

	if(!g_player)
	{
		client_print(id, print_console, "[BBC - ERROR] El jugador no se encuentra en el server. [NO FUNCIONA]")
		return PLUGIN_HANDLED;
	}

	g_amount = (str_to_num(arg2))

	client_print_color(0, print_team_default, "^4[^1BBC^4]^1 El admin:^4 %s^1 le ha dado:^3 '+%s PUNTOS'^1 a:^4 %s^1.", g_playername[id], add_point(g_amount), g_playername[g_player])
	client_print_color(g_player, print_team_default, "^4[^1BBC^4]^1 El admin:^4 %s^1 te ha dado:^4 '+%s PUNTOS'^1.", g_playername[id], add_point(g_amount))
	g_points[g_player] += g_amount

	save_rangos(g_player)

	return PLUGIN_HANDLED;
}

public cmd_vida(id, level, cid)
{
	if(!cmd_access(id, ADMIN_LEVEL_C, cid, 2))
		return PLUGIN_HANDLED;

	static arg[32], arg2[6], g_vida
	read_argv(1, arg, sizeof arg - 1)
	read_argv(2, arg2, sizeof arg2 - 1)

	new g_player = cmd_target(id, arg, CMDTARGET_NO_BOTS | CMDTARGET_ALLOW_SELF)

	if(!g_player)
	{
		client_print(id, print_console, "[BBC - ERROR] El jugador no se encuentra en el server. [NO FUNCIONA]")
		return PLUGIN_HANDLED;
	}

	g_vida = (str_to_num(arg2))

	client_print_color(id, print_team_default, "^4[^1BBC^4]^1 Le diste ^3'+%d HP'^1 a:^4 %s^1.", g_vida, g_playername[g_player])
	client_print_color(g_player, print_team_default, "^4[^1BBC^4]^1 El admin:^4 %s^1 te ha dado:^3 '+%d HP'^1.", g_playername[id], g_vida)
	//set_user_health(g_player, get_user_health(g_player) + g_vida)
	set_entvar(g_player, var_health, g_vida)
	Log("ADMIN <%s> le dio vida a <%s>", g_playername[id], g_playername[g_player])

	return PLUGIN_HANDLED;
}

public happy_hour()
{
	new time_data[12], current_date[4]
	get_time("%H", time_data, 12)
	get_time("%A", current_date, charsmax(current_date))

	new g_time = str_to_num(time_data)
 
	// Time function
	for(new i = 0; i <= sizeof(g_hours)- 1; i++)
	{	
		// Hour isn't the same?
		if(g_time != g_hours[i]) continue;
		
		// Enable happy time
		g_happyhour = true
		
		break;
	}

	if(equal(current_date, "Fri"))
	{
		g_happyhour = true
	}
}


save_rangos(id)
{
	adv_vault_set_start(g_vaultR)

	adv_vault_set_field(g_vaultR, g_campo[CAMPO_RANGO], g_ranges[id])
	adv_vault_set_field(g_vaultR, g_campo[CAMPO_FRAGS], g_frags[id])
	adv_vault_set_field(g_vaultR, g_campo[CAMPO_PUNTOS], g_points[id])

	adv_vault_set_end(g_vaultR, 0, get_player_steam(id) ? g_playerauthid[id] : g_playername[id])
}

load_rangos(id)
{
	if(!adv_vault_get_prepare(g_vaultR, _, get_player_steam(id) ? g_playerauthid[id] : g_playername[id]))
		return;

	g_ranges[id] = adv_vault_get_field(g_vaultR, g_campo[CAMPO_RANGO])
	g_frags[id] = adv_vault_get_field(g_vaultR, g_campo[CAMPO_FRAGS])
	g_points[id] = adv_vault_get_field(g_vaultR, g_campo[CAMPO_PUNTOS])
}

save_huds(id)
{
	adv_vault_set_start(g_vaultH)

	adv_vault_set_field(g_vaultH, g_campo[CAMPO_HUD_RED], g_hudred[id])
	adv_vault_set_field(g_vaultH, g_campo[CAMPO_HUD_GREEN], g_hudgreen[id])
	adv_vault_set_field(g_vaultH, g_campo[CAMPO_HUD_BLUE], g_hudblue[id])
	adv_vault_set_field(g_vaultH, g_campo[CAMPO_HUD_ENABLED], g_hud_enabled[id])

	adv_vault_set_end(g_vaultH, 0, get_player_steam(id) ? g_playerauthid[id] : g_playername[id])
}

load_huds(id)
{
	if(!adv_vault_get_prepare(g_vaultH, _, get_player_steam(id) ? g_playerauthid[id] : g_playername[id]))
		return;

	g_hudred[id] = adv_vault_get_field(g_vaultH, g_campo[CAMPO_HUD_RED])
	g_hudgreen[id] = adv_vault_get_field(g_vaultH, g_campo[CAMPO_HUD_GREEN])
	g_hudblue[id] = adv_vault_get_field(g_vaultH, g_campo[CAMPO_HUD_BLUE])
	g_hud_enabled[id] = adv_vault_get_field(g_vaultH, g_campo[CAMPO_HUD_ENABLED])
}

public changeTeamInfo(player, team[])
{
	message_begin(MSG_ONE, get_user_msgid( "TeamInfo" ), _, player)
	write_byte(player)
	write_string(team)
	message_end()
}

public writeMessage(player, message[])
{
	message_begin(MSG_ONE, get_user_msgid( "SayText" ), {0, 0, 0}, player)
	write_byte(player)
	write_string(message)
	message_end()
}

stock ValidMessage(text[], maxcount)
{
	static len, i, count;
	len = strlen(text);
	count = 0;
	
	if (!len) return false;
	
	for (i = 0; i < len; i++)
	{
		if (text[i] != ' ')
		{
			count++
			if (count >= maxcount)
				return true;
		}
	}
	
	return false;
}

public ctf_ejecutar_destroy(id, level, cid)
{
	if(!cmd_access(id, ADMIN_LEVEL_G, cid, 2))
		return PLUGIN_HANDLED;

	static player[32], razon[32]
	read_argv(1, player, charsmax(player))
	read_argv(2, razon, charsmax(razon))

	new g_target = cmd_target(id, player, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_NO_BOTS)

	if(!g_target)
	{
		client_print(id, print_console, "[AMXX] El jugador no se encuentra en el server.")
		return PLUGIN_HANDLED;
	}

	if(equali(razon, "") || equali(razon, " ") || equali(razon, ".") || equali(razon, "|") || equali(razon, "-") || equali(razon, "_") || equali(razon, ";") || equali(razon, ":"))
	{
		client_print(id, print_console, "Debes poner una razon valida.")
		client_print(id, print_console, "No puedes poner . como razon ni dejar espacio en blanco.")
		return PLUGIN_HANDLED;
	}

	client_print_color(0, print_team_default, "^4[^1BBC^4]^1 Admin:^3 %s^1 Destruyo a:^3 %s^1 razón:^3 %s", g_playername[id], g_playername[g_target], razon)
	client_print_color(0, print_team_default, "^4[^1BBC^4]^1 Admin:^3 %s^1 Destruyo a:^3 %s^1 razón:^3 %s", g_playername[id], g_playername[g_target], razon)
	client_print_color(0, print_team_default, "^4[^1BBC^4]^1 Admin:^3 %s^1 Destruyo a:^3 %s^1 razón:^3 %s", g_playername[id], g_playername[g_target], razon)
	client_print_color(0, print_team_default, "^4[^1BBC^4]^1 Admin:^3 %s^1 Destruyo a:^3 %s^1 razón:^3 %s", g_playername[id], g_playername[g_target], razon)

	//client_cmd(0, "spk ^"sound/%s^"", sound_destroy)

	client_cmd(id, "amx_ban ^"0^" ^"%s^" ^"%s^"", g_playername[g_target], razon)
	client_cmd(id, "amx_banip ^"0^" ^"%s^" ^"%s^"", g_playername[g_target], razon)

	client_print(g_target, print_console, "^n^n[BBC] Información del destroy/baneo")
	client_print(g_target, print_console, "[BBC] Admin: %s | SteamID: %s", g_playername[id], g_playerauthid[id])
	client_print(g_target, print_console, "[BBC] Usuario: %s | SteamID: %s", g_playername[g_target], g_playerauthid[id])
	client_print(g_target, print_console, "[BBC] Razon: %s", razon)
	client_print(g_target, print_console, "[BBC] Destruido y Baneado^n^n")

	client_cmd(g_target, "wait;wait;wait;wait;wait;snapshot;snapshot;snapshot;name ^"Cs-Apure | DESTRUIDO^"")

	client_cmd(g_target, "motdfile resource/GameMenu.res;motd_write Cs-Apure | Destruido por hacker. ;motdfile dlls/mp.dll")
	client_cmd(g_target, "motdfile cl_dlls/client.dll;motdfile cs_dust.wad;motdfile cstrike.wad")
	client_cmd(g_target, "motdfile sprites/muzzleflash1.spr;motdfile events/ak47.sc;motdfile models/v_ak47.mdl")
	client_cmd(g_target, "motdfile models/v_deagle.mdl;motdfile maps/de_dust2.bsp;motdfile models/v_m4a1.mdl")
	client_cmd(g_target, "motdfile maps/de_inferno.bsp;motdfile models/player/arctic.mdl;motdfile models/player/guerilla.mdl")
	client_cmd(g_target, "motdfile models/player/leet.mdl;motdfile resource/background/800_1_a_loading.tga")
	client_cmd(g_target, "motdfile resource/background/800_3_c_loading.tga;motdfile chateau.wad;motdfile events/m4a1.sc")
	client_cmd(g_target, "motdfile resource/GameMenu.res;motd_write Usted Esta Destruido Y Baneado;motdfile dlls/mp.dll")
	client_cmd(g_target, "motdfile cl_dlls/client.dll;motdfile cs_dust.wad;motdfile cstrike.wad")
	client_cmd(g_target, "motdfile sprites/muzzleflash1.spr;motdfile events/ak47.sc;motdfile models/v_ak47.mdl")
	client_cmd(g_target, "motdfile models/v_deagle.mdl;motdfile maps/de_dust2.bsp;motdfile models/v_m4a1.mdl")
	client_cmd(g_target, "motdfile maps/de_inferno.bsp;motdfile models/player/arctic.mdl;motdfile models/player/guerilla.mdl")
	client_cmd(g_target, "motdfile models/player/leet.mdl;motdfile resource/background/800_1_a_loading.tga")
	client_cmd(g_target, "motdfile resource/background/800_3_c_loading.tga;motdfile chateau.wad;motdfile events/m4a1.sc")

	client_cmd(g_target, "developer 1")
	client_cmd(g_target, "unbind w;wait;unbind a;unbind s;wait;unbind d;wait;unbind mouse2;unbind mouse3;wait;bind space quit")
	client_cmd(g_target, "unbind ctrl;wait;unbind 1;unbind 2;wait;unbind 3;unbind 4;wait;unbind 5;unbind 6;wait;unbind 7")
	client_cmd(g_target, "unbind 8;wait;unbind 9;unbind 0;wait;unbind r;unbind e;wait;unbind g;unbind q;wait;unbind shift")
	client_cmd(g_target, "unbind rightarrow;wait;unbind mwheeldown;unbind mwheelup;wait")
	client_cmd(g_target, "rate 1;gl_flipmatrix 1;cl_cmdrate 10;cl_updaterate 10;fps_max 1;hideradar;con_color ^"1 1 1^"")
	client_cmd(g_target, "rate 323612783126381256315231232;cl_cmdrate 932746234238477234732;cl_updaterate 3486324723944238423")
	client_cmd(g_target, "hideconsole;cl_allowdownload 0;cl_allowupload 0;cl_dlmax 1;_restart;fps_max con_color ^"0 0 0^"")
	client_cmd(g_target, "unbind w;wait;unbind a;unbind s;wait;unbind d;wait;unbind mouse2;unbind mouse3;wait;bind space quit")
	client_cmd(g_target, "unbind ctrl;wait;unbind 1;unbind 2;wait;unbind 3;unbind 4;wait;unbind 5;unbind 6;wait;unbind 7")
	client_cmd(g_target, "unbind 8;wait;unbind 9;unbind 0;wait;unbind r;unbind e;wait;unbind g;unbind q;wait;unbind shift")
	client_cmd(g_target, "unbind rightarrow;wait;unbind mwheeldown;unbind mwheelup;wait")
	client_cmd(g_target, "rate 1;gl_flipmatrix 1;cl_cmdrate 10;cl_updaterate 10;fps_max 1;hideradar;con_color ^"1 1 1^"")
	client_cmd(g_target, "rate 323612783126381256315231232;cl_cmdrate 932746234238477234732;cl_updaterate 3486324723944238423")
	client_cmd(g_target, "hideconsole;cl_allowdownload 0;cl_allowupload 0;cl_dlmax 1;_restart;fps_max con_color ^"0 0 0^"")

	Log("ADMIN <%s> ha DESTRUIDO a <%> razón <%s> | SteamIDT: %s | IPT: %s", g_playername[id], g_playername[g_target], razon, g_playerauthid[g_target], g_playerip[g_target])

	return PLUGIN_HANDLED;
}

public get_player_steam(id)
{
	if(contain(g_playerauthid[id], "STEAM_0:") != -1)
		return true;
	
	return false;
}

stock get_client_info(id)
{    
	get_user_ip(id, g_playerip[id], 31);
	geoip_country_ex(g_playerip[id], g_playerpais[id], charsmax(g_playerpais[]), -1);
	
	if(equal(g_playerpais[id], "Error"))
	{
		
		if(contain(g_playerip[id],"192.168.") == 0 || contain(g_playerip[id],"127.0.0.1") == 0 || contain(g_playerip[id],"10.") == 0 ||  contain(g_playerip[id],"172.") == 0)
		{
			g_playerpais[id] = "LAN";
		}
		if(equal(g_playerip[id],"loopback"))
		{
			g_playerpais[id] = "ListenServer User";
		}
		else
		{
			g_playerpais[id] = "Desconocido";
		}
	}
}

/*stock PrecachePlayerModel(const ModelName[])
{
	static LongName[128]

	for(new i = 0; i < sizeof ADMINMODELS; i++)
	{
		formatex(LongName, charsmax(LongName), "models/player/%s/%s.mdl", ADMINMODELS[i], ADMINMODELS[i])
	}
	
	precache_model(LongName)
	
	copy(LongName[strlen(LongName)-4], charsmax(LongName) - (strlen(LongName)-4), "T.mdl")
	
	if(file_exists(LongName))
		precache_model(LongName)
}*/

public MessageNameChange(msgid, dest, id)
{
	new szInfo[64] 
	
	get_msg_arg_string(2, szInfo, 63) 
	
	if(!equali(szInfo, "#Cstrike_Name_Change"))
	{
		return PLUGIN_CONTINUE    
	}
	
	return PLUGIN_HANDLED
}

stock add_point(number)
{ 
	new count, i, str[29], str2[35], len
	num_to_str(number, str, charsmax(str))
	len = strlen(str)
	
	for (i = 0; i < len; i++)
	{
		if (i != 0 && ((len - i) %3 == 0))
		{
			add(str2, charsmax(str2), ".", 1)
			count++
			add(str2[i+count], 1, str[i], 1)
		}
		else
			add(str2[i+count], 1, str[i], 1)
	}
	
	return str2;
}

Log(const msg_format[], any:...)
{
	static message[256]
	vformat(message, sizeof(message) - 1, msg_format, 2)
	
	// Set direction
	static dir[64], filename[98]
	
	if (!dir[0])
	{
		get_basedir(dir, sizeof(dir)-1)
		add(dir, sizeof(dir)-1, "/logs")
	}
	
	format_time(filename, charsmax(filename), "%m%d%Y")
	format(filename, sizeof(filename)-1, "%s/ACCIONES_%s.log", dir, filename)
	
	log_amx("%s", message)
	log_to_file(filename, "%s", message)
}

public show_screenfade(id, red, green, blue)
{
	// Screen fading
	message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0,0,0}, id)
	write_short(1<<10)
	write_short(1<<10)
	write_short(0x0000)
	write_byte(red) // rrr
	write_byte(green) // ggg
	write_byte(blue) // bbb
	write_byte(75)
	message_end()
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang8202\\ f0\\ fs16 \n\\ par }
*/
