# $Id: pools_setup_result.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
namespace eval ADMIN::POOLS::SETUP {

	asSetAct ADMIN::POOLS::SETUP::go_pools_result [namespace code show_poolresult]
	asSetAct ADMIN::POOLS::SETUP::eval_result [namespace code eval_result]

	# procedures for showing and setting the results of the pools.
	# This is essentially filling in the tDividend table.

	proc show_poolresult { args } {

		# setup the page for showing pools

		global DB PoolArray LegArray

		if { [info exists PoolArray] } { unset PoolArray }
		if { [info exists LegArray] } { unset LegArray }

		set source [ reqGetArg sid ]
		set type   [ reqGetArg Types ]
		set pool   [ reqGetArg Pool ]
		
		log 5 "source: $source"
		log 5 "type: $type"
		log 5 "pool: $pool"
		
		set detail 0

		if { $source != "" && $type != "" } {
			set detail 1
			get_pool_data $source $type
			if { $pool == "" } {
				set pool [get_pool_detail $source $type]
		} else {
			get_pool_detail $source $type
			}
		}

		if { $pool != "" } {
			set detail 2
			get_dividend_detail $pool
		}

		#tpBindString Message "" --> override this to have messages appear on the page
		set slen [ tpGetVar SourceLen ]
		set src -1
		for { set i 0 } { $i < $slen } { incr i } {
			if { $PoolArray($i,pool_source_id) == $source } {
				set src $i
			}
			if { $src != -1 } { break }
		}
		if { $src == -1 } {
			log 5 "Unknown source... src is $src"
			error "Unknown pool_source_id."
			return
		}

		tpBindString SourceCCY $PoolArray($src,ccy_code)
		tpBindString SourceDivU $PoolArray($src,dividend_unit)
		tpBindString Source $PoolArray($src,desc)
		tpBindString SourceType $PoolArray($src,pool_source_id)

		tpBindString Type $PoolArray($src,type,name)
		tpBindString TypeId $PoolArray($src,type,pool_type_id)
		tpBindString PoolId $pool
		tpBindString Reqlegs "unset"

		tpBindVar value PoolArray pool,pool_id   pool_idx
		tpBindVar name  PoolArray pool,name      pool_idx

		# dividends next: we assume exactly one dividend per pool
		if { $detail >= 2 } {
		tpSetVar numLegs $PoolArray($pool,0,num_legs) 
			tpBindVar LegVal LegArray  leg   legs
			tpBindVar Legs   LegArray  name  legs

			tpBindString Dividend $PoolArray($pool,0,dividend)
		tpBindString Reqlegs $PoolArray($pool,0,num_legs_req)

		}

		asPlayFile "pools_setup/pools_setup_resolve.html"

		return

	}

	proc get_pool_data { {source ""} {type ""} } {

		global DB PoolArray

		if { $source == "" || $type == "" } {
			log 5 "Cannot get pool data without knowing the source and type"
			error "No source or type available to obtain pool data by."
			return
		}

		set source_sql "select pool_source_id, desc, ccy_code,\
						dividend_unit from tPoolSource where pool_source_id = '$source'"
		set type_sql   "select pool_source_id, pool_type_id, name, \
							   num_legs, leg_type, all_up_avail, \
							   void_action \
						from tPoolType where pool_source_id='$source' and pool_type_id = '$type'"

		set stmt1    [ inf_prep_sql $DB $source_sql ]
		set stmt2    [ inf_prep_sql $DB $type_sql ]
		set src_res  [ inf_exec_stmt $stmt1 ]
		set type_res [ inf_exec_stmt $stmt2 ]
		inf_close_stmt $stmt1
		inf_close_stmt $stmt2
		set src_rc   [db_get_nrows $src_res]
		set type_rc  [db_get_nrows $type_res]
		set bad 0

		if { $src_rc < 1 } {
			log 3 "No pools sources available: cannot continue."
			error "No pools sources available: cannot continue."
			set bad 1
		}
		if { $type_rc < 1 } {
			log 5 "No pool types available: have any been set up?"
			error "No pool types available: have any been set up?"
			set bad 1
		}
		if { $bad == 1 } {
			tpSetVar SourceLen 0 
			tpSetVar TypeLen 0
			return
		}

		set j 0 
		for { set i 0 } { $i < $src_rc } { incr i } {
			foreach nm { pool_source_id desc ccy_code dividend_unit } {
				set PoolArray($i,$nm) [ db_get_col $src_res $i $nm ]
			}

			while { $j < $type_rc && \
			[db_get_col $type_res $j pool_source_id] == $PoolArray($i,pool_source_id) } {
				foreach nm { pool_type_id name num_legs leg_type all_up_avail void_action } {
					set PoolArray($i,type,$nm) [db_get_col $type_res $j $nm]
				}
				incr j
			}

			if { $j > $type_rc } {
				log 5 "More types than rows in result set: aborting type collation."
				break
			}
		}

		tpSetVar SourceLen $src_rc
		tpSetVar TypeLen   $type_rc

		return
	}

	proc get_pool_detail { {source ""} {type ""} } {

		global DB PoolArray

		# given a type and source, obtain the pool information
		if { $source == "" || $type == "" } {
			log 8 "Empty arguments passed to get_pool_detail:\n \
			source = $source and type = $type.  Please correct."
			error "Cannot get pool detail"
			tpSetVar PoolLen 0
			return
		}

	set pool_sql "select pool_id, name, status, displayed, result_conf, \
	              settled, rec_dividend, is_void from tPool \
				  where pool_type_id = '$type' and pool_source_id = '$source' \
				  and settled ='N' and is_void = 'N' "
		set stmt     [ inf_prep_sql $DB $pool_sql ]
		set pool_res [ inf_exec_stmt $stmt ]
		inf_close_stmt $stmt
		set pool_rc  [db_get_nrows $pool_res]

		if { $pool_rc < 1 } {
			log 5 "No pools found for source $source and type $type"
			error "There are no pools of that type from that source."
			return
		}

		for { set i 0 } { $i < $pool_rc } { incr i } {
		foreach nm { pool_id status displayed result_conf settled rec_dividend } {
				set PoolArray($i,pool,$nm) [ db_get_col $pool_res $i $nm ]
			}
		# need to find a better way of identifying individual pools
		set PoolArray($i,pool,name) "[db_get_col $pool_res $i name]:[db_get_col $pool_res $i pool_id]"
		}

		tpSetVar PoolLen $pool_rc

		return $PoolArray(0,pool,pool_id)

	}

	proc get_dividend_detail { {pool "" } } {

		global DB PoolArray LegArray

		# given a pool_id, select from the dividend table
		if { $pool == "" } {
			log 8 "Empty pool_id passed to get_dividend_detail!"
			error "Cannot get dividend if the pool_id is not known!"
			tpSetVar DivLen 0
			return
		}

		set div_sql "select * from tPoolDividend where pool_id = $pool"
		set stmt    [ inf_prep_sql $DB $div_sql ]
		set div_res [ inf_exec_stmt $stmt ]
		inf_close_stmt $stmt
		set div_rc  [ db_get_nrows $div_res ]

	if { $div_rc < 1 } {
		tpBindString Message "No dividends set yet for this pool_id..."
		initialise_dividend $pool
	} else {

		for { set i 0 } { $i < $div_rc } { incr i } {
			foreach nm {pool_dividend_id num_legs num_legs_req dividend} {
				set PoolArray($pool,$i,$nm) [ db_get_col $div_res $i $nm ]
			}
			for { set j 1 } { $j < 10 } { incr j } {
				set k [ expr { $j - 1 } ]
				set LegArray($k,leg) [ db_get_col $div_res $i leg_$j ]
				set LegArray($k,name) "Leg $j"
			}
		}

		tpSetVar DivLen $div_rc
	}


	return

}

proc initialise_dividend { { pool "" } } {

	global DB PoolArray LegArray

	# find out how many empty rows and such to leave on the page
	set sql "select t.num_legs from tPoolType t, tPool p where \
			 p.pool_type_id = t.pool_type_id and t.pool_source_id \
			 = p.pool_source_id and p.pool_id = $pool"
	set stmt [ inf_prep_sql $DB $sql ]
	set res  [ inf_exec_stmt $stmt ]
	inf_close_stmt $stmt
	set rc [ db_get_nrows $res ]

	set PoolArray($pool,0,num_legs) [db_get_col $res 0 num_legs]
	set PoolArray($pool,0,dividend) 0
	set PoolArray($pool,0,num_legs_req) "?"

	for { set i 1 } { $i < 10 } { incr i } {
		set k [ expr { $i - 1 } ]
		set LegArray($k,leg) ""
		set LegArray($k,name) "Leg $i"
	}

	tpSetVar DivLen $rc

		return

	}

	proc eval_result { args } {

		# read the information submitted from the form, check its
		# validity, and update the database if everything's good

		global DB

		set source [ reqGetArg Source ]
		set type   [ reqGetArg Type ]
		set pool   [ reqGetArg Pool ]
		set div    [ reqGetArg Dividend ]
		set limit  [ reqGetArg limit ]
		set reqleg [ reqGetArg reqlegs ]
		for { set i 0 } { $i < $limit } { incr i } {
			set name "leg_$i"
			set leg($i) [ reqGetArg $name ]
		}

		# first do some validation of our data
		set sql "select pool_id from tPool where pool_id = $pool \
				 and pool_source_id = '$source' and pool_type_id='$type'"
		set stmt [ inf_prep_sql $DB $sql ]
		set res  [ inf_exec_stmt $stmt ]
		set rc   [ db_get_nrows $res ]
		inf_close_stmt $stmt

		if { $rc < 1 } {
			log 5 "Pool id $pool, source $source and type $type returned [expr {$rc -1}] rows instead of 1"
			error "Cannot update pool"
			return
		}

		# verify that the dividend is numeric
		if { [regexp {^[0-9]+\.?[0-9]*} $div dummy] == 0 } {
			log 5 "Non-numeric dividend $div passed through"
			error "Dividend must be of the form nnnn.nn where n is a positive integer"
			return
		}

	#verify that reqlegs is an integer less than or equal to legs
	if { [regexp {^[0-9]?[0-9]*$} $reqleg dummy] == 0 || $reqleg < 0 || $reqleg > $limit } {
		log 5 "number of required legs should be an integer, not $reqleg"
		error "Please enter an integer value for the number of required legs"
		return
	}
		set bad 0
		for { set i 0 } { $i < $reqleg } { incr i } {
			if {$leg($i) == "" } {
				log 5 "Missing results for leg $i"
				set bad 1
			} else {
				set j [ expr { $i + 1 } ]
				lappend leg_list " leg_$j = '$leg($i)' "
			}
		}
		if { $bad == 1 } {
			error "Cannot set dividend until all legs have been filled in."
			return
		}

		# if we get this far, we can update the database

		# is this a new dividend or does one already exist?
		set sql "select pool_dividend_id from tPoolDividend where pool_id = $pool"
		set stmt [ inf_prep_sql $DB $sql ]
		set res  [ inf_exec_stmt $stmt ]
		inf_close_stmt $stmt
		set rc   [ db_get_nrows $res ]

		if { $rc < 1 } {
			#insert
			set sql "insert into tPoolDividend ( pool_id, num_legs, num_legs_req, cr_date, \
					 dividend, "
			for { set i 0 } { $i < $reqleg } { incr i } {
				set j [ expr { $i + 1 } ]
				append sql "leg_$j, "
			}
			append sql " is_consolation, confirmed ) "
			append sql "values ( $pool, $limit, $reqleg, CURRENT, $div, "
			for { set i 0 } { $i < $reqleg } { incr i } {
			append sql "'$leg($i)', "
			}
			append sql " 'N', 'N' ) "


			set stmt [ inf_prep_sql $DB $sql ]
			set res  [ inf_exec_stmt $stmt ]
			set rc   [ inf_get_row_count $stmt ]
			inf_close_stmt $stmt

			tpBindString Message "Dividend successfully inserted."
		} else {
			#update
			set sql "update tPoolDividend set dividend = $div, "
			set legs [ join $leg_list , ]
			append sql $legs 
			append sql " where pool_id = $pool "


			set stmt [ inf_prep_sql $DB $sql ]
			set res  [ inf_exec_stmt $stmt ]
			set rc   [ inf_get_row_count $stmt ]
			inf_close_stmt $stmt

			tpBindString Message "Dividend successfully updated."
		}

		# need to set variables for the next proc
		reqSetArg sid $source
		reqSetArg Types $type
		reqSetArg SourceLen 1
		reqSetArg Pool $pool

		show_poolresult

		return
	}

# close namespace
} 
