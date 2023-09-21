# ==============================================================
# $Id: bf_mkt_grp.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETFAIR_MKTGRP {


#
#------------------------------------------------------------------
# To Bind all betfair related information in the go to type/group page
# with a market id
#------------------------------------------------------------------
#
proc bind_bf_mkt_grp {csort} {
	
	global DB
		
	set mkt_grp_id [reqGetArg MktGrpId]

	#
	# Get betfair related market information
	#
	set sql [subst {
		select
			o.bf_desc,
			o.bir_expand as bf_bir_expand,
			o.min_vwap_vol 
		from			
			tBFOcGrpMap o
		where
			o.ev_oc_grp_id = $mkt_grp_id 
	}]
	
	set stmt    [inf_prep_sql $DB $sql]
	set res     [inf_exec_stmt $stmt]
	
	inf_close_stmt $stmt
		
	set nrows [db_get_nrows $res] 
	
	if {$nrows == 0} { 
		db_close $res
		return
	} 
		
	tpBindString MktGrpBFDesc          [db_get_col $res 0 bf_desc]
	tpBindString MktGrpBFBIRExpand     [db_get_col $res 0 bf_bir_expand]

	# Minimum Back Liquidity per Selection
	tpBindString MktGrpMinBackLiqOC	   [db_get_col $res 0 min_vwap_vol]
	
	db_close $res
	
	if {$csort == "HR" || $csort == "GR"} {
		tpSetVar ShowDefMtchOpt 1
		set match [OT_CfgGet BF_MATCH_STRING_HR ""]				
		tpBindString BfDefMatchString $match
	}
}



#
#------------------------------------------------------------------
# To add betfair related information for adding the market
#------------------------------------------------------------------
#
proc do_bf_mkt_grp_add {mkt_grp_id} {
	
	global DB USERNAME
	
	set bad 0
	
	set bf_grp_desc 	""
	set min_vwap_vol	[reqGetArg MktGrpMinBackLiqOC]
	
	# if MktGrpMinBackLiqOC is empty then take the default value
	set min_vwap_vol       	[expr { $min_vwap_vol != "" ? $min_vwap_vol :\
					[OT_CfgGet BF_MIN_BACK_LIQUID 20]}]
	
	set sql [subst {
		execute procedure pBFUpdOcGrpMap(
					p_adminuser     = ?,
					p_ev_oc_grp_id  = ?,
					p_bf_desc       = ?,
					p_min_vwap_vol  = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt\
					$USERNAME\
					$mkt_grp_id\
					$bf_grp_desc\
					$min_vwap_vol} msg]} {
		ob::log::write ERROR {do_bf_mkt_grp_add - $msg}
		err_bind $msg
		set bad 1
		return $bad
	}

	inf_close_stmt $stmt
	return $bad
}


#
#------------------------------------------------------------------
# To update betfair related information
#------------------------------------------------------------------
#
proc do_bf_mkt_grp_upd args {
	
	global DB USERNAME
	
	set bad 0
	
	#
	# Update Betfair market matcher
	#
	if {[OT_CfgGet BF_ACTIVE 0] && [OT_CfgGet BF_AUTO_MATCH 0]} {
		set bf_grp_desc        [reqGetArg MktGrpBFDesc]
		set orig_bf_grp_desc   [reqGetArg hiddenMktGrpBFDesc]
		set bf_bir_expand      [reqGetArg MktGrpBFBIRExpand]
		set orig_bf_bir_expand [reqGetArg hiddenMktGrpBFBIRExpand]
	} else {
		set bf_grp_desc        ""
		set orig_bf_grp_desc   ""
		set bf_bir_expand      ""
		set orig_bf_bir_expand ""
	}
	
	set min_vwap_vol	   [reqGetArg MktGrpMinBackLiqOC]
	
	# if MktGrpMinBackLiqOC is empty then take the default value
	set min_vwap_vol       [expr { $min_vwap_vol != "" ? $min_vwap_vol : \
					[OT_CfgGet BF_MIN_BACK_LIQUID 20]}]
	
	set orig_min_vwap_vol  [reqGetArg hiddenMktGrpMinBackLiqOC]
	
	if {$bf_grp_desc != $orig_bf_grp_desc ||
		$bf_bir_expand != $orig_bf_bir_expand ||
		$min_vwap_vol != $orig_min_vwap_vol} {

		# Updating the tBFOcGrpMap

		set sql [subst {
			execute procedure pBFUpdOcGrpMap(
						p_adminuser     = ?,
						p_ev_oc_grp_id  = ?,
						p_bf_desc       = ?,
						p_bir_expand    = ?,
						p_min_vwap_vol  = ?
			)
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {inf_exec_stmt $stmt\
						$USERNAME\
						[reqGetArg MktGrpId]\
						$bf_grp_desc\
						$bf_bir_expand\
						$min_vwap_vol} msg]} {
			ob::log::write ERROR {do_bf_mkt_grp_upd - $msg}
			err_bind $msg
			set bad 1
			return $bad
		}

		inf_close_stmt $stmt
	}
	return $bad
}

}
