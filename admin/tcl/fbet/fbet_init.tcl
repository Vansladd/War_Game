# ==============================================================
# $Id: fbet_init.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval OB_fbet_init {


	# -------------------------------------------------------------
	# One off initialisation function
	# -------------------------------------------------------------
	
	proc fbet_init {} {
		install_fbet_handlers
	}


	# -------------------------------------------------------------
	# One of installation the handler functions
	# -------------------------------------------------------------
	
	proc install_fbet_handlers {} {

		asSetAct GoFBetGameSearch 			OB_fbet_data::go_fantasy_games_search
		asSetAct GoFBetGame 				OB_fbet_data::go_fantasy_games
		asSetAct GoFBetGameUpdate			OB_fbet_data::display_fantasy_game
		asSetAct DoInsertGame				OB_fbet_data::do_fantasy_game_insert
		asSetAct GoFBetViewPeriodStandings 	OB_fbet_data::go_period_standings
	}


	# -------------------------------------------------------------
	# Handler to simply play a template file
	# -------------------------------------------------------------

	proc play_file {file} {
		tpBufAddHdr "Content-Type" "text/html"					
		tpBufAddHdr "Cache-Control" no-cache					
		OT_LogWrite 6 "Playing File: $file"
		
		uplevel 1 asPlayFile $file
	}
}