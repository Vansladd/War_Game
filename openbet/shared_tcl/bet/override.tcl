################################################################################
# $Id: override.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Allows normally show stopper scenarios to be overriden;
# such as: the price changing.
#
# Configuration:
#    Does not read config file use ob_bet::init -[various options] to
#    customise
#
# Synopsis:
#    package require bet_bet ?4.5?
#
# Procedures:
#
#    ob_bet::add_override
#       Override a bet placement constraint
#    ob_bet::get_overrides
#       Get items that will need to be overridden in order to place the bet
#    ob_bet::clear_overrides
#       Clear all active overrides with a given code WITHOUT recording them.
#    ob_bet::need_override
#       Manually indicate that an override will be required
#    ob_bet::reg_override_code
#       Register a new override code
#
################################################################################

namespace eval ob_bet {
	namespace export add_override
	namespace export get_overrides
	namespace export clear_overrides

	variable OVERRIDE
	variable AVAILABLE_OVERRIDES

	array set AVAILABLE_OVERRIDES {
		PRC_CHG         PriceOverride
		SUSP            SelnSuspOverride
		START           EvStartOverride
		STK_HIGH        MaxBetOverride
		HCAP_CHG        HcapChangeOverride
		BIR_CHG         BIRChangeOverride
		CREDIT          CredLimOverride
		LOW_FUNDS       LowFundsOverride
		STK_LOW         MinBetOverride
		NO_BETTING      NoBettingOverride
		NO_LP           NoLPAvailOverride
		NO_SP           NoSPAvailOverride
		BAD_LEG_SORT    BadLegSortOverride
		EW_PLC_CHG      EWPlcChgOverride
		EW_PRC_CHG      EWPrcChgOverride
		SHOP_BET        ShopBetOverride
	}
}



#API:add_override Override rule disallowing bet placement
#
#Usage:
#  ob_bet::add_override user_id override_user_id reason type id override
#
#  Override an operation that would normally not permit the bet to be placed
#  ie: if the price is different in the database or the event has already
#  started.  Usually used on a discretionary basis with telebet or when
#  placing retrospective bets.
#  Overrides can be added before or after the bet details.
#
# Parameters:
# user_id           FORMAT: INT
#                   DESC  : tAdminUser.user_id - Operator placing the bet
# override_user_id  FORMAT: INT
#                   DESC  : tAdminUser.user_id - User overriding bet
#                           Can be same as user_id but not necessarily so.
#                           This allows managers to override certain
#                           bet details.
# reason            FORMAT: VARCHAR
#                   DESC  : Reason for override
# type              FORMAT: BET|LEG|CUST
#                   DESC  : SELN for selection specific options ie  PRC_CHG
#                           CUST for cust specific options
#                           ie: customer suspended
#                           BET for bet specific options ie: low stake
# id                FORMAT: INT
#                   DESC  : bet_id, ev_oc_id or cust_id dep. on type
# override          FORMAT: PRC_CHG|SUSP|START|STK_HIGH|HCAP_CHG|
#                           CREDIT|LOW_FUNDS|STK_LOW|NO_BETTING|
#                           NO_LP|EW_PLC_CHG|EW_PRICE_CHG
#                   DESC  : PRC_CHG     - Price in DB different to entered
#                           SUSP        - Outcome suspended
#                           START       - Event started
#                           STK_HIGH    - Stake higher than allowed
#                           HCAP_CHG    - Hcap different to that entered
#                           CREDIT      - Credit customer would go over
#                                         credit limit
#                           LOW_FUNDS   - Customer has insufficient funds in
#                                         account to place bets
#                           STK_LOW     - Stake lower than allowed
#                           NO_BETTING  - No betting in permitted on system
#                                         as present
#                           NO_LP       - Live price not available in DB
#                           EW_PLC_CHG   - Each/Way place in DB different to entered
#                           EW_PRC_CHG  - Each/Way price in DB different to entered
#
proc ::ob_bet::add_override {
	user_id
	override_user_id
	reason
	type
	id
	override
} {

	# log input params
	set log_msg "API(add_override): $user_id,$override_user_id,$reason,"
	append log_msg "$type,$id,$override"
	_log INFO $log_msg

	# check input arguments
	#          name             value             type nullable min max
	_check_arg user_id          $user_id          INT       0   1
	_check_arg override_user_id $override_user_id INT       0   1
	_check_arg reason           $reason           CHAR      1
	_check_arg type             $type             CHAR      0   3   5
	_check_arg id               $id               INT       0   0
	_check_arg override         $override         CHAR      0

	if {[catch {
		set ret [eval _add_override\
		             {$user_id}\
		             {$override_user_id}\
		             {$reason}\
		             {$type}\
		             {$id}\
		             {$override}]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:get_overrides Retrieve active overrides.
#
#  Will return a list of reasons the bet cannot be placed.  The bet will
#  not be placed unless they are overriden by add_override see above.
#
# RETURNS: list of the form:
#          {{type1 id1 override1} {type2 id2 override2} ...}
#
# EXAMPLE: A price change and a low funds override are needed
#          would return {{SELN 123 PRC_CHG} {CUST 2 LOW_FUNDS}}
#
proc ::ob_bet::get_overrides {} {

	if {[catch {
		set ret [eval _get_overrides]
	} msg]} {
		_err $msg
	}
	return $ret
}

#API:need_override Manually indicate that some item will require an override.
#
# PARAMS:
#   type, id = the thing requiring an override; should be one of:
#     BET,  bet_num
#     LEG,  leg_num
#     CUST, cust_id
#   override = the reason an override is needed (e.g. PRC_CHG).
#   detail   = Optional extra detail to pass through to get_overrides.
#
# RETURNS:
#   Nothing. Throws an error if the type or override is obviously bogus.
#
# NOTES:
#   Only exposed as part of the public API for Telebet really.
#
proc ::ob_bet::need_override { type id override {detail ""} } {
	variable AVAILABLE_OVERRIDES
	if {[lsearch [list BET LEG CUST] $type] == -1} {
		error "Unknown override reference type \"$type\";\
			should be one of BET LEG CUST"
	}
	if {![info exists AVAILABLE_OVERRIDES($override)]} {
		error "Unknown override reason \"$override\";\
			should be one of [lsort [array names AVAILABLE_OVERRIDES]]"
	}
	return [_need_override $type $id $override]
}

#API:reg_override_code Register a new override code.
# PARAMS:
#   override_code - the code which will be passed to _need_override
#   permission    - admin permission needed to override it (or ""
#                   if no-one can override it).
#
# RETURNS:
#   Nothing
#
# NOTES:
#   Only exposed as part of the public API for Telebet really.
#
proc ob_bet::reg_override_code { override_code { permission ""} } {
	variable AVAILABLE_OVERRIDES
	set AVAILABLE_OVERRIDES($override_code) $permission
}

# Get permission associated to an override
#
proc ::ob_bet::get_override_permission {code} {

	variable AVAILABLE_OVERRIDES

	set permission {}

	if {[info exists AVAILABLE_OVERRIDES($code)]} {
		set permission $AVAILABLE_OVERRIDES($code)
	}

	return $permission
}

#API:clear_overrides Clear active overrides with a given code (dangerous!)
# PARAMS:
#   override_code - any active overrides with this code will be cleared
#                   (i.e. it will be as if they were never needed)
#
# RETURNS:
#   Nothing
#
# NOTES:
#   Implemented just for Telebet drawdown really. Not very useful.
#
proc ob_bet::clear_overrides {override_code} {

	variable OVERRIDE

	_log INFO "API(clear_overrides): $override_code"

	if {$override_code != "LOW_FUNDS"} {
		error "A \"$override_code\" override cannot be cleared."
	}

	if {[info exists OVERRIDE(active)]} {
		foreach override $OVERRIDE(active) {
			set o_type [lindex $override 0]
			set o_id   [lindex $override 1]
			set o_code [lindex $override 2]
			if {$o_code == $override_code} {
				_clear_override $o_type $o_id $o_code
			}
		}
	}

	return
}


#END OF API..... private procedures



#prepare override queries
proc ::ob_bet::_prepare_override_qrys {} {

	ob_db::store_qry ob_bet::ins_override {
		execute procedure pInsOverride(
			p_cust_id     = ?,
			p_oper_id     = ?,
			p_override_by = ?,
			p_action      = ?,
			p_call_id     = ?,
			p_ref_id      = ?,
			p_ref_key     = 'BET',
			p_leg_no      = ?,
			p_part_no     = ?,
			p_reason      = ?
		)
	}
}



# Get overrides needed to place this bet
#
proc ::ob_bet::_get_overrides {} {

	variable OVERRIDE

	_smart_reset OVERRIDE

	if {[info exists OVERRIDE(active)]} {
		return $OVERRIDE(active)
	} else {
		return [list]
	}


}


# Add an override to the bet
#
proc ::ob_bet::_add_override {
	user_id
	override_user_id
	reason
	type
	id
	override
} {
	variable OVERRIDE
	variable AVAILABLE_OVERRIDES


	# check valid override type
	if {$type != "LEG" && $type != "BET" && $type != "CUST"} {
		error\
			"Bad override type: $type should be LEG,BET or CUST"\
			""\
			"OVERRIDE_INVALID_TYPE"
	}

	# check override exists
	if {![info exists AVAILABLE_OVERRIDES($override)]} {
		error\
			"Invalid override: $override"\
			""\
			"OVERRIDE_INVALID_OVERRIDE"
	}
	set permission $AVAILABLE_OVERRIDES($override)

	_smart_reset OVERRIDE

	# TODO: check that this user has permission
	# shouldn't be done here as would duplicate
	# operator operations

	if {[info exists OVERRIDE($type,$id,$override)]} {
		# remove this item from the active index
		set idx [lindex $OVERRIDE($type,$id,$override) 0]

		if {$idx != -1} {
			# reindex
			foreach l [lrange $OVERRIDE(active) [expr {$idx+1}] end] {
				set OVERRIDE([join $l ","])\
					[expr {[set OVERRIDE([join $l ","])] -1}]
			}
			set OVERRIDE(active) [lreplace $OVERRIDE(active) $idx $idx]
		}
	}
	set OVERRIDE($type,$id,$override) [list\
	                                       -1\
	                                       $user_id\
	                                       $override_user_id\
	                                       $reason]
}



# Indicate that this action will require an override.
#
proc ::ob_bet::_need_override {type id override} {

	variable OVERRIDE

	_smart_reset OVERRIDE

	if { [info exists OVERRIDE(needed,$type,$id)] && \
	     [lsearch $OVERRIDE(needed,$type,$id) $override] != -1 } {
		# Already got this one.
		return
	}

	lappend OVERRIDE(needed,$type,$id) $override
	lappend OVERRIDE(needed) [list $type $id $override]

	# no need to add the override if not added
	if {![info exists OVERRIDE($type,$id,$override)]} {
		lappend OVERRIDE(active) [list $type $id $override]
		set OVERRIDE($type,$id,$override)\
			[expr {[llength $OVERRIDE(active)] - 1}]
		incr OVERRIDE(num)
	}
}

# Clear an override request WITHOUT recording it.
proc ob_bet::_clear_override {type id override} {

	variable OVERRIDE

	if {[info exists OVERRIDE(needed,$type,$id)]} {
		set needed $OVERRIDE(needed,$type,$id)
		set idx [lsearch $needed $override]
		if {$idx != -1} {
			set OVERRIDE(needed,$type,$id) [lreplace $needed $idx $idx]
		}
		set idx [lsearch $OVERRIDE(needed) [list $type $id $override]]
		set OVERRIDE(needed) [lreplace $OVERRIDE(needed) $idx $idx]
	}

	if {[info exists OVERRIDE($type,$id,$override)]} {
		set idx [lindex $OVERRIDE($type,$id,$override) 0]
		if {$idx != -1} {
			# reindex (expensive!)
			foreach l [lrange $OVERRIDE(active) [expr {$idx+1}] end] {
				# Unlike the keys in OVERRIDE, the overrides in the active
				# list can contain more info than just type, id and code.
				set l [lrange $l 0 2]
				set OVERRIDE([join $l ","])\
				  [expr {[set OVERRIDE([join $l ","])] -1}]
			}
			set OVERRIDE(active) [lreplace $OVERRIDE(active) $idx $idx]
		}
		unset OVERRIDE($type,$id,$override)
	}

	return
}



# Insert the override into the DB
#
proc ::ob_bet::_ins_override {
	call_id
	bet_id
	leg_no
	part_no
	type
	id
} {
	variable OVERRIDE
	variable AVAILABLE_OVERRIDES
	variable CUST

	_smart_reset OVERRIDE

	# check if we need to add an override
	if {![info exists OVERRIDE(needed,$type,$id)]} {
		_log DEBUG "No override needed for $type $id"
		return
	}

	foreach override $OVERRIDE(needed,$type,$id) {
		if {![info exists OVERRIDE($type,$id,$override)]} {
			error\
				"No override for $ref_key $ref_id $override"\
				""\
				"OVERRIDE_NOT_OVERRIDDEN"
		}

		foreach {
			ign
			user_id
			override_user_id
			reason
		} $OVERRIDE($type,$id,$override) {break}

		set permission $AVAILABLE_OVERRIDES($override)

		_log INFO "Adding override: $permission: $bet_id $leg_no $part_no"

		ob_db::exec_qry ob_bet::ins_override\
			$CUST(cust_id)\
			$user_id\
			$override_user_id\
			$permission\
			$call_id\
			$bet_id\
			$leg_no\
			$part_no\
			$reason
	}
}

::ob_bet::_log INFO "sourced override.tcl"
