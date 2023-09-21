##
# ~name OB_ccy
# ~type tcl file
# ~title multi-ccy.tcl
# ~summary Multi-currency functions
# ~version $Id: multi-ccy.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd.  All rights reserved.
#
# SYNOPSIS
#
# METHODS
#
##
namespace eval ::OB_ccy {

	namespace export rate

	if {[OT_CfgGet XG_MULTICURRENCY 0]==1} {
		namespace export round_rate
	}

	variable ccy_loaded 0
	variable RATE
	variable RND_RATE

	array set RATE     [list]
	array set RND_RATE [list]

}

##
# OB_ccy::load_rates - retrieves and stores rates
#
# SYNOPSIS
#
#	[OB_ccy::load_rates]
#
# SCOPE
#
#	private
#
# PARAMS
#
#	none
#
# RETURN
#
#	none
#
# DESCRIPTION
#
#	Retrieves and store rates from table tCCY for
#	active currencies.
#
#	If XG_MULTICURRENCY config value is set to 1, then
#	rounded rates are also retrieved.
#
##
proc ::OB_ccy::load_rates {} {

	global   DB
	variable ccy_loaded
	variable RATE
	variable RND_RATE

	catch {OB_db::db_unprep_qry OB_ccy::get_ccy_rates}
	OB_db::db_store_qry OB_ccy::get_ccy_rates {
		select
			ccy_code,
			exch_rate
		from
			tCCY
	}

	set res   [OB_db::db_exec_qry OB_ccy::get_ccy_rates]
	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		set ccy_code  [db_get_col $res $i ccy_code]
		set exch_rate [db_get_col $res $i exch_rate]
		set RATE($ccy_code) $exch_rate
	}

	db_close       $res

	if {[OT_CfgGet XG_MULTICURRENCY 0]==1} {
		catch {OB_db::db_unprep_qry OB_ccy::get_xgame_round_ccys}
		OB_db::db_store_qry OB_ccy::get_xgame_round_ccys {
			select
				ccy_code,
				round_exch_rate
			from
				tXGameRoundCCY
			where
				status = 'A'
		}

		set res   [OB_db::db_exec_qry OB_ccy::get_xgame_round_ccys]
		set nrows [db_get_nrows $res]

		for {set i 0} {$i < $nrows} {incr i} {
			set ccy_code        [db_get_col $res $i ccy_code]
			set round_exch_rate [db_get_col $res $i round_exch_rate]
			set RND_RATE($ccy_code) $round_exch_rate
		}

		db_close       $res
	}

	set ccy_loaded 1
}

##
# OB_ccy::rate - get the currency rate
#
# SYNOPSIS
#
#	[OB_ccy::rate <ccy>]
#
# SCOPE
#
#	public
#
# PARAMS
#
#	[ccy] - tCCY.ccy_code
#
# RETURN
#
#	The currency rate
#
# DESCRIPTION
#
#	Simple get currency rate method.
#
##
proc ::OB_ccy::rate {ccy} {

	variable ccy_loaded
	variable RATE

	if {!$ccy_loaded} {
		load_rates
	}

	return $RATE($ccy)
}

##
# OB_ccy::round_rate - get the rounded currency rate
#
# SYNOPSIS
#
#	[OB_ccy::round_rate <ccy>]
#
# SCOPE
#
#	public
#
# PARAMS
#
#	[ccy] - tXGameRoundCCY.ccy_code
#
# RETURN
#
#	The rounded currency rate
#
# DESCRIPTION
#
#	Simple get rounded currency rate method.
#
##
proc ::OB_ccy::round_rate {ccy} {

	variable ccy_loaded
	variable RND_RATE

	if {!$ccy_loaded} {
		load_rates
	}

	return $RND_RATE($ccy)
}
