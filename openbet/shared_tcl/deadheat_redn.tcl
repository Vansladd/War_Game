# =====================================================================
# $Id: deadheat_redn.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Handle dead heat reductions for a market or selection
#
# Procedures:
#    ob_dh_redn::init         one time initialisation
#    ob_dh_redn::clear        clear reductions for a market
#    ob_dh_redn::get          get specific reduction
#    ob_dh_redn::get_all      get all reductions
#    ob_dh_redn::load         load reduction information
#    ob_dh_redn::update       update a specific reduction
#    ob_dh_redn::insert       insert a manual reduction
#    ob_dh_redn::insert_auto  insert automatic reductions
#    ob_dh_redn::get_err      get error list
#
# Information:
#    Deadheat reductions are calculated as follows and apply
#    only to the runners actually involved in the deadheat:
#
#     (ew places available + 1) - contended place number
#     --------------------------------------------------
#          num runners placed at contended place
#
#    Examples:
#
#    1) Market Terms: 3 places @ 1/3
#
#               Place   Win   Place
#    Runner 1:  1       1/4    3/4
#    Runner 2:  1       1/4    3/4
#    Runner 3:  1       1/4    3/4
#    Runner 4:  1       1/4    3/4
#
#    2) Market Terms: 3 places @ 1/3
#
#               Place   Win   Place
#    Runner 1:  1       -     -
#    Runner 2:  2       -     2/3
#    Runner 3:  2       -     2/3
#    Runner 4:  2       -     2/3
#
#    3) Market Terms: 3 places @ 1/3
#
#               Place   Win   Place
#    Runner 1:  1       1/2    -
#    Runner 2:  1       1/2    -
#    Runner 3:  3       -      1/2
#    Runner 4:  3       -      1/2
#
#    Note that if above formula returns a value >= 1 no reduction
#    applies and the result can be discarded.
#
# Usage:
#    Use the load function to retrieve all deadheat reductions
#    for a given result, selection or market while specifying
#    whether to use automatically generated reductions, manual
#    reductions and/or confirmed results. Use above described
#    interface functions to manipulate the reductions. Please
#    note that when both manual and automatic reductions are
#    loaded the manual reduction will always override an auto
#    generated reduction when retrieving the value using get.
#    Specific reductions are referenced using a key of format
#
#             dh_type,ev_oc_id,user_id,ew_terms_id
#
#       dh_type    : W|P (Win|Place)
#       ev_oc_id   : tEvOc.ev_oc_id
#       user_id    : tDeadHtRdDblRes.user_id (0 for final dead heat reduction)
#       ew_terms_id: tEachWayTerms.ew_terms_id
#                    (0 for no terms)
#
# =====================================================================


namespace eval ob_dh_redn {

	variable AUTO_DH
	variable MANUAL_DH

	variable EW
	variable MKT
	variable SELN

	variable CFG
	variable INIT

	# current request number
	set CFG(req_no) ""
	set CFG(error)  ""

	# init flag
	set INIT 0

}



#
# One-time initialisation
#
proc ob_dh_redn::init args {

	variable INIT

	if {$INIT} {return}

	ob_log::write INFO {==> ob_dh_redn::init}

	_prep_qrys

	set INIT 1

	return

}



#
# Return all currently loaded dead heat reductions
#
#   returns - array indexed by a dh_key where
#
#      dh_key: reduction key in format
#              dh_type,ev_oc_id,user_id,ew_terms_id
#
#       dh_type    : W|P (Win|Place)
#       ev_oc_id   : tEvOc.ev_oc_id
#       user_id    : tDeadHtRdDblRes.user_id
#                    (0 for final dead heat reduction)
#       ew_terms_id: tEachWayTerms.ew_terms_id
#                    (0 for no terms)
#
#             including fields
#
#       dh_num: reduction numerator
#       dh_den: reduction denominator
#       dh_mod: flag indicating manual
#               generation (taken from DB)
#
#             Manually set reductions will never be
#             overwritten by automatically generated
#             dead heat redcutions
#
proc ob_dh_redn::get_all args {

	variable AUTO_DH
	variable MANUAL_DH

	ob_log::write DEBUG {=>ob_dh_redn::get_all}

	_auto_reset

	# get all manual reductions
	array set DH [array get MANUAL_DH]

	# set all automatic reductions while
	# not overwriting manual reductions
	foreach key [array names AUTO_DH] {
		if {![info exists DH($key)]} {
			set DH($key) $AUTO_DH($key)
		}
	}
	
	return [array get DH]

}



#
# Clear all dead heat reductions for a market
#
#    mkt_id  - like tEvMkt.ev_mkt_id
#
#    returns - 1 on success
#              0 on failure
#
proc ob_dh_redn::clear {mkt_id} {

	ob_log::write DEV {==>ob_dh_redn::clear: $mkt_id}

	_auto_reset

	ob_db::begin_tran

	if {[catch {

		# delete reductions
		ob_db::exec_qry ob_dh_redn::delete $mkt_id $mkt_id

	} msg]} {

		ob_db::rollback_tran

		_set_err "ob_dh_redn::clear: $msg"
		return 0
	}

	ob_db::commit_tran

	return 1

}



#
# Retrieve dead heat reduction for a selection and a specific set of each way
# terms
#
#   dh_key  - reduction key in format
#             dh_type,ev_oc_id,user_id,ew_terms_id
#
#       dh_type    : W|P (Win|Place)
#       ev_oc_id   : tEvOc.ev_oc_id
#       user_id    : tDeadHtRdDblRes.user_id (0 for final dead heat reduction)
#       ew_terms_id: tEachWayTerms.ew_terms_id
#                    (0 for no terms)
#
#   auto    - flag determining whether to override
#             automatic reductions with manually
#             entered reductions
#
#   returns - list of dh_num
#                     dh_den
#                     dh_mod
#
#        dh_num: reduction numerator
#        dh_den: reduction denominator
#        dh_mod: flag indicating manual
#                generation (taken from DB)
#
proc ob_dh_redn::get {dh_key {auto 0}} {

	variable AUTO_DH
	variable MANUAL_DH

	ob_log::write DEBUG {=>ob_dh_redn::get: $dh_key}

	_auto_reset

	if {[info exists MANUAL_DH($dh_key,dh_num)] && !$auto} {

		return [list $MANUAL_DH($dh_key,dh_num)\
		             $MANUAL_DH($dh_key,dh_den)\
		             $MANUAL_DH($dh_key,dh_mod)]

	} elseif {[info exists AUTO_DH($dh_key,dh_num)]} {

		return [list $AUTO_DH($dh_key,dh_num)\
		             $AUTO_DH($dh_key,dh_den)\
		             $AUTO_DH($dh_key,dh_mod)]

	}
	return [list "" "" 0]

}



#
# Load all redcutions for a given market, selection
#
#    level  - M|S|R (Market|Selection)
#    obj_id - depending on the level either
#             ev_mkt_id, ev_oc_id or result_id
#    auto   - Flag specifying whether to include
#             automatically generated reductions
#    manual - Flag specifying whether to include
#             manually set reductions
#    conf   - Flag specifying whether to use only
#             confirmed results when generating
#             automatic reductions
#    force  - Flag specifying whether to force a
#             reload of all reductions
#
#    returns - 1 on success
#              0 on failure
#
proc ob_dh_redn::load {level obj_id auto manual conf {force 0}} {

	variable CFG
	variable DH

	set log_prefix "ob_dh_redn::load"

	ob_log::write INFO {=>$log_prefix}

	# skip if information is already loaded
	if {!$force && [_loaded $level $obj_id $auto $manual $conf]} {
		return 1
	}

	# force reset of all info
	set CFG(req_no) ""
	_auto_reset

	# set configuration
	if {![_set_cfg $level $obj_id \
	               $auto  $manual \
	               $conf]} {
		return 0
	}

	# load reduction information based
	# on configuration for this request
	if {![_load_manual]} {return 0}
	if {![_load_auto]} {return 0}

	return 1

}



#
# Update a dead heat reduction
#
# The procedure will only update reductions if they
# have actually changed. Should automatically generated
# reductions be available a placeholder of 1/1 will be
# inserted if the automatic reduction was manually
# removed, otherwise only manually changed reductions
# will be entered/updated in the DB.
#
#   dh_key   - reduction key in format
#              dh_type,ev_oc_id,ew_terms_id
#
#       dh_type    : W|P (Win|Place)
#       ev_oc_id   : tEvOc.ev_oc_id
#       user_id    : tDeadHtRdDblRes.user_id (0 for final dead heat reduction)
#       ew_terms_id: tEachWayTerms.ew_terms_id
#                    (0 for no terms)
#
#   input_dh - updated dead heat reduction given as
#              list of
#
#       dh_num: reduction numerator
#       dh_den: reduction denominator
#
#    dbl_res - is double resulting functionality active
#
#    force_dbl_res - force dead heat reduction entries into main table (as long
#                    as 2 sets of reduction)
#
#    result - the result of the selection (optional - otherwise
#             use the result in the database)
#
#    do_tran - whether to make the updates in a transaction
#
#    returns - 1 on success
#              0 on failure
#
proc ob_dh_redn::update {
	dh_key
	input_dh
	{dbl_res "N"}
	{force_dbl_res "Y"}
	{result ""}
	{do_tran "Y"}
} {

	variable CFG

	variable AUTO_DH

	set log_prefix "ob_dh_redn::update"

	_auto_reset

	ob_log::write INFO {$log_prefix: $dh_key $input_dh}

	set input_dh_num [lindex $input_dh 0]
	set input_dh_den [lindex $input_dh 1]

	if {[string length $input_dh_num] &&\
	    [string length $input_dh_den]} {

		# get highest common factor
		set hcf [hcf $input_dh_num $input_dh_den]
	
		# adjust numerator/denominator
		set input_dh_num [expr {$input_dh_num / $hcf}]
		set input_dh_den [expr {$input_dh_den / $hcf}]
	}

	# retrieve current reduction
	set dh [get $dh_key]

	set dh_num [lindex $dh 0]
	set dh_den [lindex $dh 1]
	set dh_mod [lindex $dh 2]

	set write_dh 0

	if {($input_dh_num == $dh_num) &&
		($input_dh_den == $dh_den)} {
		ob_log::write DEV {$log_prefix: no udate to $dh_key}
		return 1
	}

	# input reduction is different

	if {$CFG(auto) && ($input_dh_num == "")} {
		# insert a special placeholder for an
		# empty reduction if automatic dead heat
		# reductions are enabled
		set input_dh_num 1
		set input_dh_den 1
	}

	# if the previous reductionn was a manual
	# one check that the update doesn't turn
	# it into the automatically generated value
	if {$dh_mod == 1} {

		set auto_dh [get $dh_key 1]

		if {$input_dh_num == [lindex $auto_dh 0] &&
		    $input_dh_den == [lindex $auto_dh 1]} {

			# clear previously manually modified reductions
			# if it is equal to the automatically generated
			# reduction
			ob_log::write DEBUG {$log_prefix: clearing manual reduction}

			## clear previous dead heat
			set input_dh_num ""
			set input_dh_den ""

		}
	}

	ob_log::write DEBUG {$log_prefix: updating reduction $dh_key}
	ob_log::write DEBUG {$log_prefix: from $dh_num/$dh_den}
	ob_log::write DEBUG {$log_prefix: to   $input_dh_num/$input_dh_den}

	# update/insert the reduction
	if {![insert $dh_key $input_dh_num $input_dh_den $dbl_res $force_dbl_res $result $do_tran]} {
		return 0
	}

	# store the new reduction value, only if we are
	# not clearing out the manually set reduction value
	_set $dh_key $input_dh_num $input_dh_den

	return 1

}



#
# Insert a dead heat reduction into the DB
#
#   dh_key - reduction key in format
#            dh_type,ev_oc_id,ew_terms_id
#
#       dh_type    : W|P (Win|Place)
#       ev_oc_id   : tEvOc.ev_oc_id
#       ew_terms_id: tEachWayTerms.ew_terms_id
#                    (0 for no terms)
#
#   dh_num - reduction numerator
#   dh_den - reduction denominator
#
#   dbl_res - is double resulting functionality active
#
#   force_dbl_res - force dead heat reduction entries into main table (as long
#                   as 2 sets of reduction)
#
#   result - the result of the selection (optional - otherwise
#             uses the result in the database
#
#   do_tran - whether to make the updates in a transaction
#
#    returns - 1 on success
#              0 on failure
#
# TODO
proc ob_dh_redn::insert {
	dh_key
	dh_num
	dh_den
	{dbl_res "N"}
	{force_dbl_res "Y"}
	{result ""}
	{do_tran "Y"}
} {

	global USERNAME

	set log_prefix "ob_dh_redn::insert"

	ob_log::write INFO {=>$log_prefix: $dh_key $dh_num/$dh_den}

	_auto_reset

	set dh_key_list [split $dh_key ","]

	set type  [lindex $dh_key_list 0]
	set oc_id [lindex $dh_key_list 1]
	set ew_id [lindex $dh_key_list 2]

	ob_log::write DEBUG {$log_prefix: writing reduction}
	ob_log::write DEBUG {$log_prefix: type         = $type}
	ob_log::write ERROR {$log_prefix: oc_id        = $oc_id}
	ob_log::write DEBUG {$log_prefix: ew_id        = $ew_id}
	ob_log::write DEBUG {$log_prefix: dh           = $dh_num/$dh_den}
	ob_log::write DEBUG {$log_prefix: result        = $result}
	ob_log::write DEBUG {$log_prefix: dbl_res       = $dbl_res}
	ob_log::write DEBUG {$log_prefix: force_dbl_res = $force_dbl_res}

	if {[catch {
		ob_db::exec_qry ob_dh_redn::insert \
		                        $USERNAME \
		                        $oc_id \
		                        $ew_id \
		                        $dh_num \
		                        $dh_den \
		                        $type \
		                        $result \
		                        $dbl_res \
		                        $force_dbl_res \
		                        $do_tran
	} msg]} {
		_set_err "$log_prefix: $msg"
		return 0
	}

	return 1

}


#
# Load and insert all automatically generated
# dead heat reductions into the DB
#
#    level  - M|S (Market|Selection)
#    obj_id - depending on the level either
#             ev_mkt_id, ev_oc_id or result_id
#
#    returns - 1 on success
#              0 on failure
#
proc ob_dh_redn::insert_auto {level obj_id} {

	variable CFG

	variable AUTO_DH
	variable MANUAL_DH

	set log_prefix "ob_dh_redn::insert_auto"

	ob::log::write INFO {=>$log_prefix: $level $obj_id}

	# load data if not already loaded
	if {![load $level $obj_id 1 1 1]} {
		return 0
	}

	# check whether we can actually insert reductions
	if {!$CFG(result_conf)} {
		_set_err "Unconfirmed results - can not insert reductions for $level $obj_id"
		return 0
	}

	# begin transaction
	ob_db::begin_tran

	# insert all automatically generated reductions
	foreach dh_key [array names AUTO_DH *,dh_num] {

		# skip manually modified reductions
		# they are already stored in the DB
		if {[info exists MANUAL_DH($dh_key)]} {
			continue
		}

		regsub -- {,[^,]*$} $dh_key {} dh_key

		if {![insert $dh_key\
					 $AUTO_DH($dh_key,dh_num)\
					 $AUTO_DH($dh_key,dh_den)\
					 "N"\
					 "Y"\
					 ""\
					 "N"]} {
			# error - rollback transaction
			ob_db::rollback_tran
			return 0
		}

	}

	# commit transaction
	ob_db::commit_tran

	return 1

}

#
# Retrieve error
#
proc ob_dh_redn::get_err args {

	variable CFG
	_auto_reset

	return $CFG(error)

}



#
# Retrieve highest common factor of two integers
#
proc ob_dh_redn::hcf {a b} {

	if {$b == 0} {
		return $a
	}

	return [hcf $b [expr {$a % $b}]]
}



#
# Store a dead heat reduction. Any reduction stored
# in this way is a manually modified reduction
#
#   dh_key - reduction key in format
#            dh_type,ev_oc_id,result_id,ew_terms_id
#
#       dh_type    : W|P (Win|Place)
#       ev_oc_id   : tEvOc.ev_oc_id
#       ew_terms_id: tEachWayTerms.ew_terms_id
#                    (0 for no terms)
#
#   dh_num - reduction numerator
#   dh_den - reduction denominator
#
proc ob_dh_redn::_set {dh_key dh_num dh_den} {

	variable MANUAL_DH

	set log_prefix "ob_dh_redn::_set"

	# clear out the manual reduction
	if {$dh_num == ""} {

		ob_log::write DEV {$log_prefix: clearing $dh_key}

		unset MANUAL_DH($dh_key,dh_num)
		unset MANUAL_DH($dh_key,dh_den)
		unset MANUAL_DH($dh_key,dh_mod)

	} else {

		ob_log::write DEV {$log_prefix: $dh_key: $dh_num/$dh_den}

		set MANUAL_DH($dh_key,dh_num) $dh_num
		set MANUAL_DH($dh_key,dh_den) $dh_den
		set MANUAL_DH($dh_key,dh_mod) 1
	}

	return

}



#
# Set the configuration for loading reductions per request
#
#    level  - M|S (Market|Selection)
#    obj_id - depending on the level either
#             ev_mkt_id, ev_oc_id or result_id
#    auto   - Flag specifying whether to include
#             automatically generated reductions
#    manual - Flag specifying whether to include
#             manually set reductions
#    conf   - Flag specifying whether to use only
#             confirmed results when generating
#             automatic reductions
#
#    returns - 1 on success
#              0 on failure
#
proc ob_dh_redn::_set_cfg {level obj_id auto manual conf} {

	variable CFG

	set log_prefix "ob_dh_redn::set_cfg"

	set CFG(level)  $level
	set CFG(obj_id) $obj_id
	set CFG(auto)   $auto
	set CFG(manual) $manual
	set CFG(conf)   $conf

	# default configuration
	set CFG(mkt_id)       ""
	set CFG(auto_dh_redn) ""

	# retrieve basic market information
	if {[catch {
		set rs [ob_db::exec_qry ob_dh_redn::obj_info_${level} $obj_id]
	} msg]} {
		_set_err "$log_prefix: $msg"
		return 0
	}

	set nrows [db_get_nrows $rs]

	if {$nrows} {
		set CFG(mkt_id)       [db_get_col $rs 0 ev_mkt_id]
		set CFG(max_place)    [db_get_col $rs 0 max_place]
		set CFG(result_conf)  [db_get_col $rs 0 result_conf]
		set CFG(auto_dh_redn) [db_get_col $rs 0 auto_dh_redn]
	}

	ob_db::rs_close $rs

	# failed to find market, selection or result
	if {!$nrows} {
		_set_err "$log_prefix: Failed to find $level $obj_id"
		return 0
	}

	# automatic reductions not allowed
	if {$CFG(auto) && ($CFG(auto_dh_redn) != "Y")} {
		_set_err "$log_prefix: Automatic reductions not allowed for market $CFG(mkt_id)"
		return 0
	}

	# Check that this selection/result/market has relevant places
	if {!$CFG(max_place)} {
		set log_msg "No reductions apply as place is $CFG(max_place)"
		ob_log::write INFO {$log_prefix: $log_msg}
		return 1
	}

	_log_cfg

	return 1

}



#
# Retrieve the dead heat reductions currently in the DB
#
proc ob_dh_redn::_load_manual args {

	variable MANUAL_DH
	variable CFG

	set log_prefix "ob_dh_redn::_load_manual"

	ob_log::write INFO {==>$log_prefix}

	# no need to get the manually set reductions
	# if we don't wish to retrieve them and are
	# not going to be inserting any reductions
	if {!$CFG(manual)} {return 1}

	set MANUAL_DH(num_redns) 0

	# retrieve reduction information from DB
	if {[catch {
		set rs [ob_db::exec_qry ob_dh_redn::manual_${CFG(level)} $CFG(obj_id)]
	} msg]} {
		_set_err "$log_prefix: $msg"
		return 0
	}

	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {

		foreach n [db_get_colnames $rs] v [db_get_row $rs $r] {
			set $n $v
		}

		set dh_key "$dh_type,$ev_oc_id,$user_id,$ew_terms_id"

		set MANUAL_DH($dh_key,dh_num) $dh_num
		set MANUAL_DH($dh_key,dh_den) $dh_den
		set MANUAL_DH($dh_key,dh_mod) 1

		incr MANUAL_DH(num_redns)

	}

	ob_db::rs_close $rs

	return 1

}



#
# Calculate win and place dead heat reductions for
# a given market
#
#   level   - hierarchy level of id passed in
#             S: Selection
#             M: Market
#
#   obj_id  - market, selection or result id
#
#   ins_db  - flag showing whether the calculated
#             reductions should be stored
#
#   manual_override - overwrite automatically calculated
#             values with manual changes taken from
#             tDeadHeatRedn
#
#   returns - dh_num, dh_den in an array indexed by
#       h_type:      W|P (win or place)
#       ev_oc_id:    selection id
#       ew_terms_id: each way terms id (0 if null)
#
# Please see the header comment for detailed description
# and examples of how the reductions are generated.
#
proc ob_dh_redn::_load_auto args {

	variable CFG

	variable AUTO_DH

	variable EW
	variable MKT
	variable SELN

	set log_prefix "ob_dh_redn::_load_auto"

	ob_log::write INFO {==>$log_prefix}

	# no need to automatically calculate reductions
	# if we don't wish to retrieve them
	if {!$CFG(auto)} {return 1}

	# retrieve market and selection information
	if {![_get_ew_terms] || ![_get_seln_info]} {
		return 0
	}

	ob_log::write_array DEV EW
	ob_log::write_array DEV MKT
	ob_log::write_array DEV SELN

	# for each place a horse has
	# placed on in the market
	foreach place $MKT(places) {

		set mkt_key "$place"

		# check for a dead heat
		set num_placed [llength $MKT($mkt_key,selns)]

		# skip places for which there is no deadheat
		if {$num_placed < 2} {continue}

		# loop through all each way terms for the market
		foreach ew_id [array names EW] {

			set ew_places $EW($ew_id)

			# check whether the place is relevant within
			# the context of the each way places available
			if {$place > $ew_places} {continue}

			# calculate the dead heat reduction
			set dh_num [expr {($ew_places + 1) - $place}]
			set dh_den $num_placed

			# dead heat - but the number of available
			# places exceeds the number of placed runners
			if {$dh_num >= $dh_den} {continue}

			# apply the dead heat reduction to all selections
			# which are contending for this place
			foreach ev_oc_id $MKT($mkt_key,selns) {

				if {$CFG(level) == "S" && $ev_oc_id != $CFG(obj_id)} {
					# not relevant, so continue
					continue
				}

				# avoid setting reductions multiple times
				if {![info exists SELN($ev_oc_id,result)]} {
					continue
				}

				# skip any settled results
				if {$SELN($ev_oc_id,settled) == "Y"} {
					continue
				}


				if {$ew_id == "W"} {
					# special character is only added as each way
					# term when looking at place 1 and so to include
					# win reductions
					set dh_type     "W"
					set ew_terms_id  0
				} else {
					set dh_type     "P"
					set ew_terms_id $ew_id
				}

				# log reduction
				set    log_txt "$ev_oc_id,$ew_terms_id: "
				append log_txt "$dh_type reduction: $dh_num/$dh_den"

				ob_log::write DEBUG {$log_prefix: $log_txt}

				set dh_key "$dh_type,$ev_oc_id,0,$ew_terms_id"

				# get highest common factor
				set hcf [hcf $dh_num $dh_den]

				# adjust numerator/denominator
				set dh_num [expr {$dh_num / $hcf}]
				set dh_den [expr {$dh_den / $hcf}]

				# set dead heat reduction
				set AUTO_DH($dh_key,dh_num) $dh_num
				set AUTO_DH($dh_key,dh_den) $dh_den
				set AUTO_DH($dh_key,dh_mod) 0

			}
		}
	}

	return 1

}



#
# Retrieve all each way terms in tEachWayTerms and
# from tEvMkt for a given market.
#
# Sets the variable EW. EW is indexed by ew_places.
# Each entry holds a list of ew_term_ids. The
# placeholder ew_term_id for the value from tEvMkt
# is 0. The array also holds an entry max_places
# which is the maximum number of relevant places
# for the given market.
#
proc ob_dh_redn::_get_ew_terms args {

	variable CFG
	variable EW

	ob::log::write DEV {=>ob_dh_redn::_get_ew_terms}

	if {[catch {
		set rs [ob_db::exec_qry ob_dh_redn::ew_terms $CFG(mkt_id)\
		                                                $CFG(mkt_id)]
	} msg]} {
		_set_err "db_redn::_get_ew_terms: $msg"
		return 0
	}

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {

		set id     [db_get_col $rs $i ew_id]
		set places [db_get_col $rs $i ew_places]

		set EW($id) $places

	}

	ob_db::rs_close $rs

	# cheat for win reduction
	set EW(W) 1

	return 1

}



#
# Retrieve selection result information from tEvOc
# and tEvOcResult for a given market. Only consider
# selections which are not unnamed favourites and
# for which a result has been set.
#
# Modifies variables MKT and SELN. MKT is an array
# containing a list of selections for each place.
# SELN contains the result and result id for a
# selection per tag. The placeholder result id
# where the result is from tEvOc is 0.
#
proc ob_dh_redn::_get_seln_info args {

	variable CFG
	variable MKT
	variable SELN

	set log_prefix "ob_dh_redn::_get_seln_info"

	ob::log::write DEV {=>$log_prefix}

	set MKT(oc_ids) [list]
	set MKT(places) [list]

	if {$CFG(conf)} {
		set confirmed [list "Y"]
	} else {
		set confirmed [list "N"]
	}

	# retrieve selection details
	if {[catch {
		set rs [ob_db::exec_qry ob_dh_redn::seln_info $CFG(mkt_id)\
		                                                 $confirmed]
	} msg]} {
		_set_err "$log_prefix $msg"
		return 0
	}

	set nrows [db_get_nrows $rs]

	ob::log::write DEV {$log_prefix: $nrows results}

	for {set i 0} {$i < $nrows} {incr i} {

		set oc_id [db_get_col $rs $i ev_oc_id]
		set place [db_get_col $rs $i place]


		lappend MKT(oc_ids) $oc_id
		lappend MKT(places) $place

		set key "$oc_id"

		set SELN($key,place)     $place
		set SELN($key,result)    [db_get_col $rs $i result]
		set SELN($key,settled)   [db_get_col $rs $i settled]
	}

	ob_db::rs_close $rs

	foreach name {oc_ids places} {
		set MKT($name) [lsort -unique $MKT($name)]
	}

	foreach place $MKT(places) {
		set MKT($place,selns) [list]
	}

	foreach oc_id $MKT(oc_ids) {

		set place ""

		if {[info exists SELN($oc_id,place)]} {
			set place $SELN($oc_id,place)
		}

		if {$place != ""} {
			lappend MKT($place,selns) $oc_id
		}
	}

	return 1
}




#
# Log and set error
#
proc ob_dh_redn::_set_err {err_msg} {

	variable CFG

	ob_log::write ERROR {$err_msg}
	set CFG(error) $err_msg

	return
}



#
# Unset data if this is a different request
#
proc ob_dh_redn::_auto_reset args {

	variable CFG

	variable AUTO_DH
	variable MANUAL_DH

	variable EW
	variable MKT
	variable SELN

	set log_prefix "ob_dh_redn::_auto_reset"

	# get the request id
	set id [reqGetId]

	if {$CFG(req_no) == $id} {
		# already loaded
		return 0
	}

	# different request numbers, unset all data
	catch {unset CFG}

	catch {unset AUTO_DH}
	catch {unset MANUAL_DH}

	catch {unset EW}
	catch {unset MKT}
	catch {unset SELN}

	set CFG(req_no) $id
	set CFG(error)  ""

	# ensure queries are prepared
	init

	ob::log::write DEBUG {$log_prefix: reset}

	return 1

}



#
# check whether reduction information is already loaded
#
proc ob_dh_redn::_loaded {level obj_id auto manual conf} {

	variable CFG

	if {[_auto_reset]} {
		return 0
	}

	if {![info exists CFG(level)]} {
		return 0
	}

	set same_cfg 1

	# check for cfg changes
	foreach name {level obj_id auto manual conf} {
		if {$CFG($name) != [set $name]} {
			set same_cfg 0
			break
		}
	}

	return $same_cfg

}



#
# Log configuration (dev tool)
#
proc ob_dh_redn::_log_cfg args {
	variable CFG
	ob_log::write_array DEV CFG
}



#
# Prepare queries
#
proc ob_dh_redn::_prep_qrys args {

	ob_db::store_qry ob_dh_redn::manual_M {
		select
			d.dh_redn_id,
			d.ev_oc_id,
			d.dh_type,
			d.dh_num,
			d.dh_den,
			NVL(d.ew_terms_id,0) as ew_terms_id,
			0 as user_id
		from
			tDeadHeatRedn d,
			tEvOc         o
		where
			o.ev_mkt_id = ? and
			o.ev_oc_id  = d.ev_oc_id

		union

		select
			-1,
			d.ev_oc_id,
			d.dh_type,
			d.dh_num,
			d.dh_den,
			NVL(d.ew_terms_id,0) as ew_terms_id,
			d.user_id
		from
			tDeadHtRdDblRes d,
			tEvOc           o
		where
			o.ev_mkt_id = ? and
			o.ev_oc_id  = d.ev_oc_id
		order by
			d.dh_type desc,
			5,
			6
	}

	ob_db::store_qry ob_dh_redn::manual_S {
		select
			d.dh_redn_id,
			d.ev_oc_id,
			d.dh_type,
			d.dh_num,
			d.dh_den,
			NVL(d.ew_terms_id,0) as ew_terms_id,
			0 as user_id
		from
			tDeadHeatRedn d
		where
			d.ev_oc_id = ?

		union

		select
			-1,
			d.ev_oc_id,
			d.dh_type,
			d.dh_num,
			d.dh_den,
			NVL(d.ew_terms_id,0) as ew_terms_id,
			d.user_id
		from
			tDeadHtRdDblRes d
		where
			d.ev_oc_id = ?
		order by
			d.dh_type desc,
			5,
			6
	}

	ob_db::store_qry ob_dh_redn::insert {
		execute procedure pSetDeadHeatRedn (
			p_adminuser     = ?,
			p_ev_oc_id      = ?,
			p_ew_terms_id   = ?,
			p_dh_num        = ?,
			p_dh_den        = ?,
			p_dh_type       = ?,
			p_result        = ?,
			p_func_dbl_res  = ?,
			p_force_dbl_res = ?,
			p_do_tran       = ?
		)
	}
	
	ob_db::store_qry ob_dh_redn::ew_terms {
		select
			ew_terms_id as ew_id,
			ew_places
		from
			tEachWayTerms
		where
			ev_mkt_id = ?

		union

		select
			0 as ew_id,
			ew_places
		from
			tEvMkt
		where
			ev_mkt_id = ?   and
			ew_avail  = 'Y'

		order by
			1
	}
	
	ob_db::store_qry ob_dh_redn::seln_info {
		select
			ev_oc_id,
			result,
			NVL(place,999) as place,
			settled
		from
			tEvOc
		where
			ev_mkt_id       = ?        and
			fb_result not in ('1','2') and
			result         <> '-'      and
			result_conf in ('Y',?)
		order by
			3
	}

	ob_db::store_qry ob_dh_redn::obj_info_S {
		select
			m.ev_mkt_id,
			m.auto_dh_redn,
			NVL(o.place,0) as max_place,
			DECODE(o.result_conf,'Y',1,0) as result_conf
		from
			tEvOc  o,
			tEvMkt m
		where
			o.ev_oc_id  = ? and
			o.ev_mkt_id = m.ev_mkt_id
	}

	ob_db::store_qry ob_dh_redn::obj_info_M {
		select
			ev_mkt_id,
			auto_dh_redn,
			998 as max_place,
			DECODE(result_conf,'Y',1,0) as result_conf
		from
			tEvMkt
		where
			ev_mkt_id = ?
	}
	
	ob_db::store_qry ob_dh_redn::delete {
		delete from
			tDeadHeatRedn
		where
			ev_oc_id in (
				select
					ev_oc_id
				from
					tEvOc
				where
					ev_mkt_id = ?   and
					settled   = 'N'
			)
	}

}
