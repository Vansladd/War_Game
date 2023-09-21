# ==============================================================
# $Id: xgame_init.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2003 Orbis Technology Ltd. All rights reserved.
# ==============================================================

if {[OT_CfgGet FUNC_XGAME 0]} {

	global xtn
	global tcl_dir

	set source_files {
		xgame_admin_qrys
		xgame_admin
		settle
		settle-new
		import
		export
		report
		email
		topspot
		manual_authorize
		gamedef
		default_times
		round_ccy
		change_selections
		prices
	}

	if {[OT_CfgGet FUNC_XGAME_CHARITY 0]} {
		lappend source_files charity
	}


	foreach script $source_files  {
		if {[catch {
			OT_LogWrite 2 "TCL sourcing $tcl_dir/xgame/${script}.$xtn"
			source "$tcl_dir/xgame/${script}.$xtn"
		} msg]} {
			OT_LogWrite 2 "** Failed to source $tcl_dir/xgame/${script}.$xtn:$msg **"
		}
	}

	set bookmaker [OT_CfgGet OPENBET_CUST]
	set bm_source_files {}
	lappend bm_source_files export_${bookmaker}.$xtn
	lappend bm_source_files import_${bookmaker}.$xtn

	foreach script $bm_source_files  {
		if {[catch {
			OT_LogWrite 2 "TCL sourcing $tcl_dir/xgame/${script}"
			source "$tcl_dir/xgame/${script}"
		} msg]} {
			OT_LogWrite 10 "Did not source $tcl_dir/xgame/${script}: $msg"
		}
	}
}

proc xgame_init args {
	install_xgame_handlers
	bind_xgame_global_strings
	populate_xgame_admin_queries

	# This bookmaker may not have import export file functionality
	if [catch {
	populate_xgame_export_queries
	} msg] {
	OT_LogWrite 2 "Failed to populate xgame export queries"
	}
}

proc install_xgame_handlers args {

	asSetAct GoXGameFind		H_GoXGameFind
	asSetAct DoXGameFind		H_DoXGameFind
	asSetAct GoEditGame		    H_GoEditGame
	asSetAct GoEditGameStatus   H_GoEditGameStatus
	asSetAct DoEditGame		    H_DoEditGame
	asSetAct GoEditBalls		H_GoEditBalls
	asSetAct DoEditBalls		H_DoEditBalls
	asSetAct GoEditResults		H_GoEditResults
	asSetAct DoEditResults		H_DoEditResults

	asSetAct GoCreateExportFile	create_export_file
	asSetAct GoCreateCustomersExportFile   create_customers_export_file
	asSetAct GoExportFile		export_file
	asSetAct GoCustomerExportFile   export_cust_file

	asSetAct GoImportFile		import_file

	asSetAct GoReports		H_GoReport
	asSetAct DoReport		H_DoReport

	asSetAct GoPriceHistory		H_GoPriceHistory
	asSetAct DoPriceHistory		H_DoPriceHistory

	asSetAct GoEditDividend		H_GoEditDividend
	asSetAct DoAddDividend		H_DoAddDividend
	asSetAct DoRemoveDividend	H_DoRemoveDividend

	asSetAct GoManualAuthorize	H_GoManualAuthorize
	asSetAct GoManualAuthorizeForm  H_GoManualAuthorizeForm

	# TopSpot
	asSetAct GoTopSpotAssignArea	H_GoTopSpotAssignArea

	asSetAct GoTopSpotChoosePics	H_GoTopSpotChoosePics
	asSetAct GoTopSpotChoosePicLeft H_GoTopSpotChoosePicLeft
	asSetAct GoTopSpotChoosePicRight H_GoTopSpotChoosePicRight
	asSetAct DoTopSpotChoosePics	H_DoTopSpotChoosePics
	asSetAct DoTopSpotAssignArea	H_DoTopSpotAssignArea

	asSetAct GoPlaceBalls		H_GoPlaceBalls
	asSetAct DoPlaceBalls		H_DoPlaceBalls

	asSetAct GoTopSpotMark		H_GoTopSpotMark
	asSetAct DoTopSpotMark		H_DoTopSpotMark


	# Edit Game Definitions
	asSetAct show_gamedef_stake	show_gamedef_stake
	asSetAct delete_gamedef_stake	delete_gamedef_stake
	asSetAct add_gamedef_stake	add_gamedef_stake
	asSetAct modify_gamedef_stake	modify_gamedef_stake
	asSetAct modify_xgdef_chans modify_xgdef_chans

	asSetAct modify_gamedef_sub_limits modify_gamedef_sub_limits
	asSetAct add_game_price		add_game_price
	asSetAct modify_gamedef_max_card_payout modify_gamedef_max_card_payout
	asSetAct modify_gamedef_max_payout modify_gamedef_max_payout
	asSetAct modify_gamedef_default_draw_time modify_gamedef_default_draw_time

	asSetAct add_default_time       add_default_time
	asSetAct modify_game_price	modify_game_price
	asSetAct delete_game_price	delete_game_price
	asSetAct modify_game_options	modify_game_options

	asSetAct show_round_ccy		show_round_ccy
	asSetAct delete_round_ccy	delete_round_ccy
	asSetAct add_round_ccy		add_round_ccy

	asSetAct do_sub_change_selections do_sub_change_selections
	asSetAct UnparkXGBet unpark_xgamebet

	# Charity
	if {[OT_CfgGet FUNC_XGAME_CHARITY 0]} {
		asSetAct GoXGameCharityLst  ADMIN::XGAME::CHARITY::go_list_charities
		asSetAct GoXGameCharityDsp  ADMIN::XGAME::CHARITY::go_display_charity
		asSetAct GoXGameCharityAdd  ADMIN::XGAME::CHARITY::go_add_charity
		asSetAct GoXGameCharityMod  ADMIN::XGAME::CHARITY::go_modify_charity
		asSetAct GoXGameCharityDel  ADMIN::XGAME::CHARITY::go_delete_charity
	}


	asSetAct global_insert_outstanding_subs global_insert_outstanding_subs

}

#
# Register global string sites
#
proc bind_xgame_global_strings args {
	tpBindString APPLET_URL -global [OT_CfgGet APPLET_URL]
}


#
# Utility procedure to bind up a result set
#
proc xg_bind_rs {rs {key ""} {cols ""}} {

	global XG_RS

	# Prevent playing old data in case of failure.
	tpSetVar ${key}nrows 0

	set nrows [db_get_nrows $rs]

	if {$key!=""} {set key "${key}_"}

	tpSetVar ${key}nrows $nrows

	if {$cols==""} {set cols [db_get_colnames $rs]}

	for {set r 0} {$r<$nrows} {incr r} {
	foreach col $cols {
		set XG_RS($r,${key}${col}) [db_get_col $rs $r $col]
		OT_LogWrite 10 "XG_RS($r,${key}${col} = [db_get_col $rs $r $col]"
		tpBindVar ${key}${col} XG_RS ${key}${col} idx
	}
	}
}

