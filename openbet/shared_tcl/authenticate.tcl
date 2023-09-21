# ==============================================================
# $Id: authenticate.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

namespace eval OB::AUTHENTICATE {

	## the cust status flags

	set AV_FLAG [OT_CfgGet FUNC_OVS_AGE_VRF_PRFL_CODE ""]

	variable FLAGS
	array set FLAGS [list \
		BET                        [list STOP LOCK PWORD FRAUD PEND DORMANT          \
		                            DEBTST5 DEBTSTPP OVS_${AV_FLAG}_S]        \
		DEPOSIT                    [list LOCK PWORD FRAUD DEP PEND DORMANT FRAUDRISK \
		                            OVS_${AV_FLAG}_S]                                \
		WITHDRAW                   [list LOCK PWORD FRAUD WTD PEND DORMANT FRAUDRISK \
		                            OVS_${AV_FLAG}_S OVS_${AV_FLAG}_P]               \
		TRANSFER                   [list STOP LOCK PWORD FRAUD WTD DEP PEND          \
		                            OVS_${AV_FLAG}_S]                                \
		LOGIN                      [list LOCK PWORD FRAUD PEND DORMANT               \
		                            DEBTST5 OVS_${AV_FLAG}_S]        \
		BET_TBS                    [list SUPERVISOR MONITOR DORMANT                  \
		                            DEBTST3 DEBTST4 DEBTST5 DEBTSTPP OVS_${AV_FLAG}_S]       \
		LOGIN_TBS                  [list LOCK FRAUD ASK PEND STOP LOOK               \
		                            DEBTST2 DEBTST3 DEBTST4 DEBTST5 OVS_${AV_FLAG}_S]        \
		WITHDRAW_TBS               [list WTD OVS_${AV_FLAG}_S]                       \
		DEPOSIT_TBS                [list DEP OVS_${AV_FLAG}_S]                       \
		RETAIL                     [list LOCK PWORD FRAUD ASK PEND STOP LOOK         \
		                            SUPERVISOR MONITOR DEBTST2 DEBTST3 DEBTST4 DEBTST5 \
		                            OVS_${AV_FLAG}_S]                                \
	]

	# Check overrides in the config files
	set FLAGS(BET) [concat $FLAGS(BET) [OT_CfgGet AUTH_FLAGS_BET ""]]

	set FLAGS(LOGIN) [concat $FLAGS(LOGIN) [OT_CfgGet AUTH_FLAGS_LOGIN ""]]

	variable REGION_COOKIE
	set REGION_COOKIE(req_no) ""

	## customer status flag action mappings
	variable ACTION_MAPPINGS
	set ACTION_MAPPINGS(x_bet,cs)       BET
	set ACTION_MAPPINGS(bet,cs)         BET
	set ACTION_MAPPINGS(bet_simple,cs)  BET
	set ACTION_MAPPINGS(launch_game,cs) BET
	set ACTION_MAPPINGS(deposit,cs)     DEPOSIT
	set ACTION_MAPPINGS(withdraw,cs)    WITHDRAW
	set ACTION_MAPPINGS(external_transfer,cs)  TRANSFER
	set ACTION_MAPPINGS(mcs_casino,cs)         TRANSFER
	set ACTION_MAPPINGS(mcs_poker,cs)          TRANSFER
	set ACTION_MAPPINGS(poker_chip,cs)         TRANSFER
	set ACTION_MAPPINGS(casino_chip,cs)        TRANSFER
	set ACTION_MAPPINGS(login,cs)       LOGIN
	set ACTION_MAPPINGS(launch_game,cs) BET
	set ACTION_MAPPINGS(netballs_pg,cs) BET
	set ACTION_MAPPINGS(netballs_fo,cs) BET

	## country check action mappings
	set ACTION_MAPPINGS(x_bet,cc)             BET
	set ACTION_MAPPINGS(login,cc)             LOGIN
	set ACTION_MAPPINGS(registration,cc)      REG
	set ACTION_MAPPINGS(card_registration,cc) NEWCRD
	set ACTION_MAPPINGS(deposit,cc)           DEP
	set ACTION_MAPPINGS(withdraw,cc)          WTD
	set ACTION_MAPPINGS(external_transfer,cc) EXT
	set ACTION_MAPPINGS(mcs_casino,cc)        CASINO
	set ACTION_MAPPINGS(casino_chip,cc)       CASINO
	set ACTION_MAPPINGS(mcs_poker,cc)         POKER
	set ACTION_MAPPINGS(poker_chip,cc)        POKER
	set ACTION_MAPPINGS(launch_game,cc)       GAMES
	set ACTION_MAPPINGS(netballs_pg,cc)       NBPG
	set ACTION_MAPPINGS(netballs_fo,cc)       NBFO

	variable AUTH_CACHE_TIME [OT_CfgGet AUTH_CACHE_TIME 120]

	variable INITIALIZED 0

	variable COOKIE_REQ_ID -1

}


##
## Initializes sql for this library
##
proc OB::AUTHENTICATE::_init args {

	variable AUTH_CACHE_TIME
	variable INITIALIZED

	if {$INITIALIZED} {
		return
	}

	ob_db::store_qry OB::AUTHENTICATE::get_banned_ev_cats_for_ev_oc {
		select first 1
			b.category
		from
			tevclass c,
			tev e,
			tevoc o,
			tcntrybancat b,
			tAuthServerApp a
		where
			o.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) and
			o.ev_id = e.ev_id and
			b.country_code = ? and
			b.category = c.category and
			e.ev_class_id = c.ev_class_id and
			b.app_id = a.app_id and
			a.code = ?
	} $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::get_banned_ev_cats_for_ev {
		select first 1
			b.category
		from
			tevclass c,
			tev e,
			tcntrybancat b,
			tAuthServerApp a
		where
			e.ev_id = ? and
			e.ev_class_id = c.ev_class_id and
			b.category = c.category and
			b.country_code = ? and
			b.app_id = a.app_id and
			a.code = ?
	} $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::get_banned_lot_games {
		select first 1
			g.name
		from
			tXGameDef g,
			tAuthServerApp a,
			tCntryBanLot l
		where
			a.app_id = l.app_id
			and g.sort = l.sort
			and l.sort = ?
			and l.country_code = ?
			and a.code = ?
	} $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::get_banned_channels {
		select first 1
			c.desc
		from
			tChannel c,
			tCntryBanChan l
		where
			c.channel_id = l.channel_id
			and l.channel_id = ?
			and l.country_code = ?
	} $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::get_banned_systems {
		select first 1
			g.desc
		from
			tXSysHostGrp g,
			tCntryBanSys l
		where
			g.group_id = l.group_id
			and l.group_id = ?
			and l.country_code = ?
	} $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::get_additional_banned_items {
		select first 1
			a.name,
			ch.desc
		from
			tCntryBanAdd a,
			tChannel ch
		where
			a.country_code = ?
			and a.name = ?
			and a.channel_id = ?
			and ch.channel_id = a.channel_id
	} $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::get_telebet_channels {
		select
			channel_id
		from
			tChanGrpLink
		where
			channel_grp = 'TEL'
	} $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::get_sysgrp_from_sys_id {
		select first 1
			group_id
		from
			txsyshostgrplk
		where
			system_id = ?
	} $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::check_ip_allow {
                select
                        1
                from
                        tIPAllow
                where
                        ip_address = ? and
                        status = 'A'
        } $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::check_country_ban_op {
		select
			1
		from
			tAuthServerApp a,
			tCntryBanOp    b
		where a.app_id       = b.app_id
		  and a.code         = ?
		  and b.op_code      = ?
		  and b.country_code = ?
	} $AUTH_CACHE_TIME

	ob_db::store_qry OB::AUTHENTICATE::get_cust_country_code {
		select
			country_code
		from
			tCustomer
		where
			cust_id = ?
	} 0

	if [OT_CfgGet FUNC_AUTH_CHECK_GAMES 0] {
		ob_db::store_qry OB::AUTHENTICATE::get_banned_games {
			select
				1
			from
				tcgBannedGame bg
			where
				bg.cg_id = ?
			and
				bg.country_code = ?
		} $AUTH_CACHE_TIME

		ob_db::store_qry OB::AUTHENTICATE::get_banned_game_classes {
			select
				1
			from
				tcgBannedClass bc,
				tcgGame g
			where
				g.cg_id = ?
			and
				g.cg_class = bc.cg_class
			and
				bc.country_code = ?
		} $AUTH_CACHE_TIME
	}

	set INITIALIZED 1
}

#
# Public wrapper for _check_cust_status_flags. This is needed for OXi which needs all the
# status flags / stop codes like telebetting. This is unavailable from the main authenticate call
#
proc OB::AUTHENTICATE::check_cust_status_flags {action cust_id {channel "I"} {full_check 0}} {
		return [_check_cust_status_flags $action $cust_id $channel $full_check]
}


#
# Check whether ip-address is allowed by the admin user or country is banned
#
proc OB::AUTHENTICATE::check_country_and_ip {action ipaddr ip_country} {
	set block 0
	set ip_allowed 0

	if {[catch {
		set rs_ip [ob_db::exec_qry OB::AUTHENTICATE::check_ip_allow $ipaddr]
	} msg]} {
		ob::log::write ERROR {failed to get ip allowed for ip $ipaddr: $msg}
	} else {
		if {[db_get_nrows $rs_ip] > 0} {
			ob::log::write INFO {IP $ipaddr is allowed by the admin, skipping country ban check}
			set ip_allowed 1
		}
		db_close $rs_ip
	}

	# if ip is allowed, then we need not do the country ban check
	if {!$ip_allowed} {
		# Check for the country ban set by admin users
		if {[catch {
			set rs [ob_db::exec_qry OB::AUTHENTICATE::check_country_ban_op \
				"default"                                \
				$action                                  \
				$ip_country
			]
		} msg]} {
			ob::log::write ERROR {failed to get opcode country mapping\
				$action $ip_country: $msg}
		} else {
			set nrows [db_get_nrows $rs]

			# if the country is banned, then at least a row should
			# be entered in the tCntryBanOp table
			if {$nrows != 0} {
				set block 1
			}
			db_close $rs
		}
	}

	return $block
}


# Determine if a channel is a Telebet channel
#
#   channel_id - The channel ID.
#   returns    - If the channel is a Telebet channel.
#
proc OB::AUTHENTICATE::_is_telebet_channel {channel_id} {

	variable INITIALIZED

	if {!$INITIALIZED} {
		_init
		set INITIALIZED 1
	}

	# We can safely assume that if the channel is I, then
	# we know that it's not a Telebet channel and we don't
	# need to hit the database.
	#
	if {$channel_id == "I"} {
		return 0
	}

	# We can also assume that if the channel is P, then we know
	# it's Telebet channel.
	#
	if {$channel_id == "P"} {
		return 1
	}

	set is_telebet_channel 0

	set rs [ob_db::exec_qry OB::AUTHENTICATE::get_telebet_channels]

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		if {[db_get_col $rs $r channel_id] == $channel_id} {
			set is_telebet_channel 1
			break
		}
	}

	db_close $rs

	ob::log::write DEBUG {_is_telebet_channel: \
		channel_id=$channel_id, is_telebet_channel=$is_telebet_channel}

	return $is_telebet_channel
}


## returns OK if the action is okay
## or a list of
## the flag that caused the restriction,
## the overide permision for tbs
## and a suggestion for a customer message
##
## or if full check returns a list of overrides (for telebet)
##
## A full list of overrides will be returned if full_check is set.
##
proc _check_cust_status_flags {action cust_id {channel "I"} {full_check 0}} {
	variable OB::AUTHENTICATE::FLAGS

	if {![info exists FLAGS($action)]} {
		ob::log::write ERROR {authentication failed invalid action: $action}
		return [list "ERROR" "" "INVALID_ACTION"]
	}

	set status [OB::STATUS_FLAGS::get_status $cust_id]
	set flags  [OB::STATUS_FLAGS::get_names $cust_id]

	if {[lsearch $flags LOCK] != -1} {
		set flags {LOCK $flags}
	}

	if {$status=="S"} {
		return  [list "SUSPENDED" "" "CUST_SUSPENDED"]
	} elseif {$status=="C"} {
		return  [list "CLOSED" "" "CUST_CLOSED"]
	}

	set flags_length [llength $flags]

	if {[OB::AUTHENTICATE::_is_telebet_channel $channel]} {
		set action "${action}_TBS"
	}


	if {$full_check} {
		set overrides {}
		foreach flag $flags {
			set search [lsearch $FLAGS($action) $flag]

			OT_LogWrite 5 "this action = $FLAGS($action), flag = $flag"

			set override [OB::STATUS_FLAGS::get_override $flag $cust_id]

			if {$search > -1} {
				ob::log::write INFO {authentication failed for action: $action, due to flag: $flag, adding to list}
				lappend overrides $flag $override
			}
		}

		if {$overrides != {}} {
			return $overrides
		}
	} else {

		foreach flag $flags {
			set search [lsearch $FLAGS($action) $flag]
			set overide [OB::STATUS_FLAGS::get_override $flag $cust_id]


			if {$search > -1} {
				set msg "CUST_RESTRICTED_${action}"
				if {$flag == {PWORD}} {
					set msg LOGIN_TEMP_PWD
				}
				ob::log::write INFO {authentication failed for action: $action, due to flag: $flag}
				return [list $flag $overide $msg]
			}
		}
	}
	return "OK"
}

##
## based on a list of evoc ids or ev id checks if the event category is allowed betting
## for this region retruns a list of allow and the category of this event to be used in customer messages
proc _check_cat_allowed_by_ev_id {id_list cust_id application ip_addr} {

	global IP_COUNTRY

	set allow 1
	set category ""

	ob::log::write INFO {Check if betting on this category is allowed for ip country: $IP_COUNTRY}

	#run query
	set rs [eval [concat ob_db::exec_qry OB::AUTHENTICATE::get_banned_ev_cats_for_ev $id_list $IP_COUNTRY $application]]

	if {[db_get_nrows $rs] > 0} {
		set category [db_get_col $rs 0 category]

		if {[OB::country_check::check_block_override $cust_id]} {
			ob::log::write INFO {Overriding block for cust_id $cust_id}
		} else {
			ob::log::write INFO {Blocking category: $category for ip country: $IP_COUNTRY}
			set allow 0
		}
	}
	catch {db_close $rs}

	OB::country_check::log_checkpoint $cust_id $ip_addr "" $category "" "" "" "" $IP_COUNTRY $allow

	ob::log::write INFO {_check_cat_allowed: returning $allow $category}
	return [list $allow $category]
}

proc _check_cat_allowed_by_ev_oc_id {id_list cust_id application ip_addr} {

	global IP_COUNTRY

	set allow 1
	set category ""

	ob::log::write INFO {Check if betting on this category is allowed for ip country: $IP_COUNTRY}

	for {set i [llength $id_list]} {$i < 20} {incr i} {
		lappend id_list -1
	}

	#run query
	set rs [eval [concat ob_db::exec_qry OB::AUTHENTICATE::get_banned_ev_cats_for_ev_oc $id_list $IP_COUNTRY $application]]

	if {[db_get_nrows $rs] > 0} {
		set category [db_get_col $rs 0 category]

		if {[OB::country_check::check_block_override $cust_id]} {
			ob::log::write INFO {Overriding block for cust_id $cust_id}
		} else {
			ob::log::write INFO {Blocking category: $category for ip country: $IP_COUNTRY}
			set allow 0
		}
	}
	catch {db_close $rs}

	OB::country_check::log_checkpoint $cust_id $ip_addr "" $category "" "" "" "" $IP_COUNTRY $allow

	ob::log::write INFO {_check_cat_allowed: returning $allow $category}
	return [list $allow $category]
}

##
## based on a sort number checks if the lottery game is allowed for betting
## in this region
## returns a list of allow and the lottery name to be used in customer messages
##
proc _check_lot_allowed {xgame_sort cust_id application ip_addr} {

	global IP_COUNTRY_FOR_RESTRICTIONS

	set allow 1
	set lottery_xgame_name ""

	ob::log::write INFO {Check if betting on this lottery game is allowed for ip country: $IP_COUNTRY_FOR_RESTRICTIONS}

	set app_name "OXi"
	if {$application != $app_name} {
		set app_name "default"
	}

	#run query
	set rs [ob_db::exec_qry OB::AUTHENTICATE::get_banned_lot_games $xgame_sort $IP_COUNTRY_FOR_RESTRICTIONS $app_name]

	if {[db_get_nrows $rs] > 0} {
		set lottery_xgame_name [db_get_col $rs 0 name]

		if {[OB::country_check::check_block_override $cust_id]} {
			ob::log::write INFO {Overriding block for cust_id $cust_id}
		} else {
			ob::log::write INFO {Blocking lottery game: $lottery_xgame_name for ip country: $IP_COUNTRY_FOR_RESTRICTIONS}
			set allow 0
		}
	}
	catch {db_close $rs}

	OB::country_check::log_checkpoint $cust_id $ip_addr "" "" $xgame_sort "" "" "" $IP_COUNTRY_FOR_RESTRICTIONS $allow

	ob::log::write INFO {_check_lot_allowed: returning $allow $lottery_xgame_name}
	return [list $allow $lottery_xgame_name]
}

##
## Based on the channel id checks if this channel is allowed for betting
## in this region
##
## Returns a list of allow and the channel name to be used in customer messages
##
proc _check_chan_allowed {channel_id cust_id ip_addr} {

	global IP_COUNTRY_FOR_RESTRICTIONS

	set allow 1
	set channel_name ""

	ob::log::write INFO {Check if betting on this channel is allowed for ip country: $IP_COUNTRY_FOR_RESTRICTIONS}

	#run query
	set rs [ob_db::exec_qry OB::AUTHENTICATE::get_banned_channels $channel_id $IP_COUNTRY_FOR_RESTRICTIONS]

	if {[db_get_nrows $rs] > 0} {
		set channel_name [db_get_col $rs 0 desc]

		if {[OB::country_check::check_block_override $cust_id]} {
			ob::log::write INFO {Overriding block for cust_id $cust_id}
		} else {
			ob::log::write INFO {Blocking channel: $channel_name for ip country: $IP_COUNTRY_FOR_RESTRICTIONS}
			set allow 0
		}
	}
	catch {db_close $rs}

	OB::country_check::log_checkpoint $cust_id $ip_addr "" "" "" $channel_id "" "" $IP_COUNTRY_FOR_RESTRICTIONS $allow

	ob::log::write INFO {_check_chan_allowed: returning $allow $channel_name}
	return [list $allow $channel_name]
}

##
## Based on the group id checks if this system group is allowed for betting
## in this region
##
## Returns a list of allow and the system group name to be used in customer messages
##
proc _check_sys_allowed {system_group_id cust_id ip_addr} {

	global IP_COUNTRY_FOR_RESTRICTIONS

	set allow 1
	set system_group_name ""

	ob::log::write INFO {Check if betting on this system group is allowed for ip country: $IP_COUNTRY_FOR_RESTRICTIONS}

	#run query
	set rs [ob_db::exec_qry OB::AUTHENTICATE::get_banned_systems $system_group_id $IP_COUNTRY_FOR_RESTRICTIONS]

	if {[db_get_nrows $rs] > 0} {
		set system_group_name [db_get_col $rs 0 desc]

		if {[OB::country_check::check_block_override $cust_id]} {
			ob::log::write INFO {Overriding block for cust_id $cust_id}
		} else {
			ob::log::write INFO {Blocking system: $system_group_name for ip country: $IP_COUNTRY_FOR_RESTRICTIONS}
			set allow 0
		}
	}
	catch {db_close $rs}

	OB::country_check::log_checkpoint $cust_id $ip_addr "" "" "" "" $system_group_id "" $IP_COUNTRY_FOR_RESTRICTIONS $allow

	ob::log::write INFO {_check_sys_allowed: returning $allow $system_group_name}
	return [list $allow $system_group_name]
}

proc _check_add_allowed {name channel_id cust_id ip_addr} {

	global IP_COUNTRY_FOR_RESTRICTIONS

	set allow 1
	set add_name ""
	set ch_name ""

	ob::log::write INFO {Check if betting on this item is allowed for ip country: $IP_COUNTRY_FOR_RESTRICTIONS}

	#run query
	set rs [ob_db::exec_qry OB::AUTHENTICATE::get_additional_banned_items $IP_COUNTRY_FOR_RESTRICTIONS $name $channel_id]

	if {[db_get_nrows $rs] > 0} {
		set add_name [db_get_col $rs 0 name]
		set ch_name [db_get_col $rs 0 desc]

		if {[OB::country_check::check_block_override $cust_id]} {
			ob::log::write INFO {Overriding block for cust_id $cust_id}
		} else {
			ob::log::write INFO {Blocking item: $add_name on channel $ch_name for ip country: $IP_COUNTRY_FOR_RESTRICTIONS}
			set allow 0
		}
	}
	catch {db_close $rs}

	OB::country_check::log_checkpoint $cust_id $ip_addr "" "" "" "" "" $add_name $IP_COUNTRY_FOR_RESTRICTIONS $allow

	ob::log::write INFO {_check_add_allowed: returning $allow $add_name $ch_name}
	return [list $allow $add_name $ch_name]
}

## based on a customers id and a game id checks if the game is allowed for this region
proc _allow_game {game_id cust_id} {
	global IP_COUNTRY

	set rs [ob_db::exec_qry OB::AUTHENTICATE::get_banned_game_classes $game_id $IP_COUNTRY]
	set bans [db_get_nrows $rs]
	catch {db_close $rs}

	if {$bans > 0} {
		if {[OB::country_check::check_block_override $cust_id]} {
			ob::log::write INFO {Overriding block for game (at class level): $game_id for ip country: $IP_COUNTRY}
			return 1
		} else {
			ob::log::write INFO {Blocking games (at class level): $game_id for ip country: $IP_COUNTRY}
			return 0
		}
	}

	set rs [ob_db::exec_qry OB::AUTHENTICATE::get_banned_games $game_id $IP_COUNTRY]
	set bans [db_get_nrows $rs]
	catch {db_close $rs}

	if {$bans > 0} {
		if {[OB::country_check::check_block_override $cust_id]} {
			ob::log::write INFO {Overriding block for game (at game level): $game_id for ip country: $IP_COUNTRY}
			return 1
		} else {
			ob::log::write INFO {Blocking games (at game level): $game_id for ip country: $IP_COUNTRY}
			return 0
		}
	}

	return 1
}

#
# Lightweight check
# ie this proc doesn't generate a new region cookie if it's expired
# and only checks the cookie rather than looking up geopoint etc
#
proc _lightweight_cookie_check {} {
	set ip_country "??"

	# Retrieve region cookie
	set cookie [OB::country_check::retrieve_cc_cookie]

	# Check for expired cookie
	if {$cookie == {}} {
		ob::log::write ERROR {_lightweight_cookie_check: Region cookie has expired}
	}

	# Check for blocked ip
	if {[lindex $cookie [lsearch $OB::country_check::COOKIE_FMT ip_is_blocked]] == "Y"} {
		ob::log::write ERROR {_lightweight_cookie_check: User ip addr is blocked}
		return 1
	}

	# Check for disallowed country
	set ip_country [lindex $cookie [lsearch $OB::country_check::COOKIE_FMT ip_country]]
	if {[lsearch -exact [OT_CfgGet DISALLOWED_CTYS ""] $ip_country] != -1} {
		ob::log::write ERROR {_lightweight_cookie_check: User coming from a disallowed jurisdiction}
		return 1
	}

	# User is allowed to continue
	ob::log::write INFO {_lightweight_cookie_check: User is allowed to continue}
	return 0
}

#
# set up spoofed country check cookie: for use when not using IP checks,
# but doing checks on the customer's REGISTERED country code
#
# region_cookie: region_cookie name (as passed into AUTHENTICATE::authenticate)
# cust_id      : customer ID
# ip_address   : ip_address as passed into AUTHENTICATE::authenticate
#
# return: 1 for success, 0 for failure
proc _setup_spoof_cc_cookie {region_cookie cust_id ip_address} {

	ob::log::write DEV {_setup_spoof_cc_cookie $region_cookie $cust_id $ip_address}

	# if no ip_address, grab the req ip
	if {$ip_address == ""} {
		set ip_address [reqGetEnv REMOTE_ADDR]
	}

	# need the customer's country code
	set ret [_get_cust_reg_country_code $cust_id]
	if {[lindex $ret 0]} {
		set country_code [lindex $ret 1]
	} else {
		# fail!
		return [list 0 "no_cookie" $ip_address]
	}

	# spoof cc cookie contents
	# cust_id  flag  ip_country  ip_city  ip_routing  country_cf  ip_addr  ip_is_blocked
	OB::country_check::store_cc_cookie $cust_id 0 $country_code "" "" "" $ip_address N

	return [list 1 $region_cookie $ip_address]
}

#
# Get customer's country code from registration
# cust_id: customer ID
#
# returns: [list 0] - failure
#        : [list 1 $country_code] - success
proc _get_cust_reg_country_code {cust_id} {

	ob::log::write DEV {_get_cust_reg_country_code $cust_id}

	set rs [ob_db::exec_qry OB::AUTHENTICATE::get_cust_country_code $cust_id]

	if {![db_get_nrows $rs]} {
		catch {db_close $rs}
		return [list 0]
	} else {
		set country_code [db_get_col $rs 0 country_code]
		catch {db_close $rs}
		return [list 1 $country_code]
	}
	catch {db_close $rs}
	# safety first!
	return [list 0]

}

## authenticate returns a list of
##
## main_response - either S(uccess) or F(aliure)
##
## return_code - a list of containg 4 elements (or a list of these lists if full_check is on)
##
## 1st element is the system that found the block or problem, one of:
## COOKIE_CHECK
## CUST_STATUS_FLAGS
## GEOPOINT
## COUNTRY_CAT_ALLOWED
## COUNTRY_LOT_ALLOWED
## COUNTRY_CHAN_ALLOWED
## COUNTRY_SYS_ALLOWED
## COUNTRY_ADD_ALLOWED
## FOG_CHECK
##
## 2nd element of the return_code is the code
## COOKIE_CHECK one of
## 	IP_BLOCKED
## 	COOKIE_CHECK_FAILED
##
## CUST_STATUS_FLAGS one of
## 	LOCK
## 	PWORD
## 	FRAUD
## 	DEP
## 	WTD
## 	STOP
## 	ASK
## 	SUPERVISOR
## 	MONITOR
## 	LOOK
## 	PEND
##  FRAUDRISK
##  CHANNEL_LOCK
##
## GEOPOINT one of
## 	GEOPOINT_IP_BLOCKED or
## 	GEOPOINT_${gp_action}_BAN_${country} where gp_action is one of
## 		LOGIN
## 		REGISTRATION
## 		REG_CARD
## 		TXN
## 		EXT
## 		CASINO
## 		POKER
##      NBPG
##      NBFO
##
## COUNTRY_CAT_ALLOWED
## 	BET_ERROR_COUNTRY_CHECK_${banned_cat}_${country} where banned_cat is one of the event categories
## COUNTRY_LOT_ALLOWED
## 	BET_ERROR_COUNTRY_CHECK_${banned_lot}_${country} where banned_lot is one of the lottery games
## COUNTRY_CHAN_ALLOWED
## 	BET_ERROR_COUNTRY_CHECK_${banned_chan}_${country} where banned_chan is one of the channels
## COUNTRY_SYS_ALLOWED
## 	BET_ERROR_COUNTRY_CHECK_${banned_sys}_${country} where banned_sys is one of the system groups
## COUNTRY_ADD_ALLOWED
## 	BET_ERROR_COUNTRY_CHECK_${banned_add}_${country} where banned_add is one of the additional bannable items
##
## FOG_CHECK
## 	COUNTRY_BLOCKED_${country}
##
## 3rd element of the return_code is a customer message for translation
##
## 4th element of the return_code is operator message
##
## region_cookie - the region cokie generated by the cookie check code, to be re stored
##
## overrides - any overrides remaining to be overridden (telebet only)
proc OB::AUTHENTICATE::authenticate {application channel cust_id action full_check {ip_address ""} {region_cookie "no_cookie"} {ev_oc_ids ""} {ev_id ""} {game_id ""} {overrides ""} {flatten_return_codes "Y"} {xgame_sort ""} {system_id ""} {add_name ""}} {

	 if {[OT_CfgGet USE_AUTHENTICATE_SERVER 0]} {
		set xml_resp [post_auth_request $application $channel $cust_id $action $full_check $ip_address $region_cookie $ev_oc_ids $ev_id $game_id $overrides]
		return [parse_response $xml_resp $flatten_return_codes]
	 } else {
	 	return [authenticate_local $application $channel $cust_id $action $full_check $ip_address $region_cookie $ev_oc_ids $ev_id $game_id $overrides $flatten_return_codes $xgame_sort $system_id $add_name]
	 }
}

## where all the actual authentication work is done, wrapped up by OB::AUTHENTICATE::authenticate to allow
## this library to be run remotely via xml or normally
proc OB::AUTHENTICATE::authenticate_local {application channel cust_id action full_check {ip_address ""} {region_cookie "no_cookie"} {ev_oc_ids ""} {ev_id ""} {game_id ""} {overrides ""} {flatten_return_codes "Y"} {xgame_sort ""} {system_id ""} {add_name ""}} {

	ob::log::write INFO {OB::AUTHENTICATE::authenticate application = $application, \n channel = $channel, \n cust_id = $cust_id, \n action = $action, \n fullcheck = $full_check, \n ip = $ip_address, \n cookie = $region_cookie, \n ev_oc_id = $ev_oc_ids, \n ev_id = $ev_id, \n game id = $game_id, \n overrides = $overrides, \n flatten = $flatten_return_codes, \n  sort = $xgame_sort, \n add_name = $add_name, \n system_id = $system_id}

	global IP_COUNTRY
	global IP_COUNTRY_FOR_RESTRICTIONS
	global REG_CHANNEL
	global LOGIN_DETAILS
	variable ACTION_MAPPINGS
	variable INITIALIZED

	if {!$INITIALIZED} {
		_init
		set INITIALIZED 1
	}

	if {$region_cookie == "cc_spoof"} {

		# get the relevant information
		# note that this proc will on failure:
		#            reset region_cookie to 'no_cookie'
		#            return the ip_address as was passed
		# otherwise: returns the region_cookie as was passed
		#            returns [reqGetEnv REMOTE_ADDR] for ip_address
		foreach {result region_cookie ip_address} [_setup_spoof_cc_cookie $region_cookie $cust_id $ip_address] {}

	} elseif {$region_cookie != "no_cookie"} {
		set_region_cookie $region_cookie
	}

	# Check for customer exclusion by channel
	if {[OT_CfgGet FUNC_EXCLUSION_FLAGS 0]} {
		set channel_excl \
			[OB::EXCLUSIONS::check_channel_allowed $cust_id $channel]
		if {![lindex $channel_excl 1]} {
			set returnVal \
				{CUST_STATUS_FLAGS CHANNEL_BLOCK \
				"Customer is excluded from this channel" $region_cookie}
			return [list F $returnVal]
		}
	}

	set do_checkpoint_check   0
	set do_status_flags_check 0
	set do_cookie_check       0
	set do_cat_allowed_check  0
	set do_lot_allowed_check  0
	set do_chan_allowed_check 0
	set do_sys_allowed_check  0
	set do_add_allowed_check  0
	set do_games_check        0
	set do_lightweight_cookie_check 0

	set continue 1
	set failed 0

	set return_codes [list]
	set overrides_r [list]

	## work out what checks we need to do
	switch -- $action {
		"registration" {
			if {$application != "TBET" && $ip_address != ""} {
				set do_checkpoint_check 1
			}
			if {$application == "OXi" && $system_id != ""} {
				set do_sys_allowed_check  1
			}
			set do_chan_allowed_check 1
		}

		"login" {
			if {$application == "OXi" && $region_cookie == "cc_spoof" || $application != "TBET" && $ip_address != ""} {
				set do_checkpoint_check 1
			}
			if {($application == "PlaytechLogin" || $application == "OXi") && $system_id != ""} {
				set do_sys_allowed_check 1
			}
			set do_status_flags_check 1
			set do_chan_allowed_check 1
		}

		"deposit" {
			if {$application != "TBET" && $ip_address != ""} {
				set do_checkpoint_check 1

				if {$region_cookie != "no_cookie"} {
					set do_cookie_check   1
				}
			}
			if {$application == "OXi" && $system_id != ""} {
				set do_sys_allowed_check  1
			}
			set do_status_flags_check 1
			set do_chan_allowed_check 1
		}

		"withdraw" {
			if {$application != "TBET" && $ip_address != ""} {
				set do_checkpoint_check 1

				if {$region_cookie != "no_cookie"} {
					set do_cookie_check   1
				}
			}
			if {$application == "OXi" && $system_id != ""} {
				set do_sys_allowed_check  1
			}
			set do_status_flags_check 1
			set do_chan_allowed_check 1
		}

		"casino_chip"     -
		"mcs_casino" -
		"poker_chip"      -
		"mcs_poker" {
			if {$application != "TBET"} {
				set do_status_flags_check 1

				if {$application == "OXi" && $region_cookie == "cc_spoof" || $ip_address != ""} {

					set do_checkpoint_check     1
					if {$region_cookie != "no_cookie" && $ip_address != ""} {
						set do_cookie_check   1
					}
				}
			}
		}

		"bet" {
			if {$application != "TBET" && $ip_address != ""} {
				set do_cat_allowed_check  1

				if {$region_cookie != "no_cookie"} {
					set do_cookie_check   1
				}
			}
			if {$application == "OXi" && $system_id != ""} {
				set do_sys_allowed_check  1
			}
			if {$application != "OXi" && $add_name != ""} {
				set do_add_allowed_check  1
			}

			if {$application == "TBET" && $xgame_sort != ""} {
				set do_lot_allowed_check  1
			}

			set do_status_flags_check 1
			set do_chan_allowed_check 1
		}

		"bet_simple" {
			if {$application != "TBET" && $ip_address != "" && $region_cookie != "no_cookie"} {
				set do_cookie_check   1
			}
			set do_status_flags_check 1
		}

		"card_registration" {
			if {$application != "TBET" && $ip_address != ""} {
				set do_checkpoint_check     1
			}
		}

		"external_transfer" {
			if {$application != "TBET"} {

				set do_status_flags_check 1

				if {$region_cookie != "no_cookie" && $ip_address != ""} {
					set do_cookie_check   1
				}
			}

			if {$application == "OXi" && $region_cookie == "cc_spoof" || [OT_CfgGet XFER_FORCE_CNTRY_CHECK 0]} {
				set do_checkpoint_check 1
			}

			if {$application == "OXi"} {
				set do_sys_allowed_check  1
			}

			set do_chan_allowed_check 1
		}

		"launch_game" {
			if {$application != "FOGf"} {
				set do_games_check 1
				set do_status_flags_check 1

				if {$region_cookie != "no_cookie" && $ip_address != ""} {
					set do_cookie_check   1
				}
				set do_checkpoint_check 1
			}

			set do_add_allowed_check 0
			set do_chan_allowed_check 1
		}

		"update_cookie" {
			if {$region_cookie != "no_cookie" && $ip_address != ""} {
				set do_cookie_check   1
			}
		}

		"x_bet" {
			if {$application != "TBET" && $region_cookie != "no_cookie" && $ip_address != ""} {
				if {[OT_CfgGet FUNC_USE_LIGHT_COOKIE_CHECK 0]} {
					# Note:  Lightweight check doesn't actually check the DB
					# To determine which countries are blocked.  WTF?
					set do_lightweight_cookie_check       1
				} else {
					set do_checkpoint_check  1

					if {$region_cookie != "no_cookie"} {
						set do_cookie_check   1
					}
				}
			}
			if {$application == "OXi" && $system_id != ""} {
				set do_sys_allowed_check  1
			}
			set do_lot_allowed_check 1
			set do_status_flags_check 1
			set do_chan_allowed_check 1
		}

		"netballs_fo" {
			if {$application != "TBET" && $ip_address != ""} {
				set do_checkpoint_check  1

				if {$region_cookie != "no_cookie"} {
					set do_cookie_check   1
				}
			}
			set do_status_flags_check 1
		}

		"netballs_pg" {
			if {$application != "TBET" && $ip_address != ""} {
				set do_checkpoint_check  1

				if {$region_cookie != "no_cookie"} {
					set do_cookie_check   1
				}
			}
			set do_status_flags_check 1
		}

		default {
			set continue 0
			set failed 1
			lappend return_codes [list AUTHENTICATE INVALID_ACTION INVALID_ACTION "Invalid Action"]
		}
	}

	# if neither IP2Location nor GeoPoint are in use
	#  and checking country by customer address is not enabled
	#  then disable the checkpoint check and cookie check.
	if {!([OT_CfgGetTrue FUNC_IP2LOCATION_IP_CHECK] ||
	      [OT_CfgGetTrue FUNC_GEOPOINT_IP_CHECK] ||
	      [OT_CfgGetTrue CCHK_BY_CUST_ADDR])} {
		ob::log::write INFO {OB::AUTHENTICATE::authenticate switching off ip2location checking}
		set do_checkpoint_check 0
		set do_cookie_check 0
		set do_cat_allowed_check 0
		set do_lot_allowed_check 0
		set do_chan_allowed_check 0
		set do_sys_allowed_check 0
		set do_add_allowed_check 0
		set IP_COUNTRY "??"
	}



	if {![OT_CfgGet FUNC_AUTH_CHECK_GAMES 0]} {
		ob::log::write INFO {OB::AUTHENTICATE::authenticate switching off games checking}
		set do_games_check 0
	}

	ob::log::write INFO {OB::AUTHENTICATE::authenticate $application $channel $cust_id $action $full_check $ip_address $region_cookie $ev_oc_ids $game_id $overrides}

	ob::log::write DEV {OB::AUTHENTICATE::authenticate do_checkpoint_check   $do_checkpoint_check}
	ob::log::write DEV {OB::AUTHENTICATE::authenticate do_status_flags_check $do_status_flags_check}
	ob::log::write DEV {OB::AUTHENTICATE::authenticate do_cookie_check       $do_cookie_check}
	ob::log::write DEV {OB::AUTHENTICATE::authenticate do_cat_allowed_check  $do_cat_allowed_check}
	ob::log::write DEV {OB::AUTHENTICATE::authenticate do_lot_allowed_check  $do_lot_allowed_check}
	ob::log::write DEV {OB::AUTHENTICATE::authenticate do_chan_allowed_check $do_chan_allowed_check}
	ob::log::write DEV {OB::AUTHENTICATE::authenticate do_sys_allowed_check  $do_sys_allowed_check}
	ob::log::write DEV {OB::AUTHENTICATE::authenticate do_add_allowed_check  $do_add_allowed_check}
	ob::log::write DEV {OB::AUTHENTICATE::authenticate do_games_check        $do_games_check}


	# do the actual checks
	if {$do_cookie_check && $continue} {
		## do cookie check first
		set cc_res [OB::country_check::cookie_check $cust_id $ip_address "" "" outcome ]

		if {$cc_res} {
			set failed 1
			if {$outcome=="IP_BLOCKED"} {
				## this ip address is blocked
				lappend return_codes [list COOKIE_CHECK IP_BLOCKED IP_BLOCKED "IP2Location IP Blocked"]
			} else {
				## failed cookie check
				lappend return_codes [list COOKIE_CHECK COOKIE_CHECK_FAILED COOKIE_CHECK_FAILED "Cookie Check Failed"]
			}

			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate cookie_check failed}
		}

		## this check failed, were not doing a full check so dont continue with other checks
		if {!$full_check && $failed} {
			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking out of authentication at cookie_check}
			set continue 0
		}
	}

	# IP_COUNTRY needs to be set from the DB instead of the cookie for various country checks
	if { ($do_lot_allowed_check || $do_chan_allowed_check || $do_sys_allowed_check || $do_add_allowed_check) } {

		# get and set customer's registration info
		set IP_COUNTRY_FOR_RESTRICTIONS [ob_login::get cntry_code]
		set REG_CHANNEL                 [ob_login::get channel]

		if {($IP_COUNTRY_FOR_RESTRICTIONS == "" || $REG_CHANNEL == "") && $application == "OXi"} {
			# OXi uses old login style - need to get the details with an extra call
			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate getting login details for OXi}
			OB_login::get_user_info $cust_id PASSWD

			set IP_COUNTRY_FOR_RESTRICTIONS $LOGIN_DETAILS(CNTRY_CODE)
			set REG_CHANNEL                 $LOGIN_DETAILS(CHANNEL)
		}

		if {[string length $IP_COUNTRY_FOR_RESTRICTIONS]>0 && [string length $REG_CHANNEL]>0} {
			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate setting country: \
				 customer $cust_id country $IP_COUNTRY_FOR_RESTRICTIONS}
			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate setting registration channel: \
				 customer $cust_id reg channel $REG_CHANNEL}
		} else {
			ob::log::write ERROR {OB::AUTHENTICATE::authenticate could not get \
				country code or registration channel for customer $cust_id.  \
				Skipping the following checks: lotteries, channels, systems, add. items}
			set do_lot_allowed_check  0
			set do_chan_allowed_check 0
			set do_sys_allowed_check  0
			set do_add_allowed_check  0
		}
	}

	if {$do_status_flags_check && $continue} {
		if {$application == "TBET"} {

			set csf_res [_check_cust_status_flags $ACTION_MAPPINGS($action,cs) $cust_id "P" $full_check]

			if {[llength $csf_res] > 0 && $csf_res != "OK"} {

				set overrides_r $csf_res

				## remove any overrides we dont care about, ie. the ones passed in to the proc have presumably
				## already been overiridden and were only interested in any 'new' ones
				## this functionality is for telebet
				foreach {flag or} $overrides {

					set x [lsearch -exact $overrides_r $or]
					if {$x >= 0} {
						set overrides_r [lreplace $overrides_r $x $x]

						set flag [lsearch -exact $overrides_r $flag]
						if {$flag >= 0} {
							set overrides_r [lreplace $overrides_r $flag $flag]
							ob::log::write DEBUG {OB::AUTHENTICATE::authenticate this has already been overridden}
						} else {
							## put back in override rather than let it fail.
							## this is precaution only, shouldn't happen.
							##
							set overrides_r [linsert $overrides_r $x $or]
						}
					}
				}

				## check if there are any left!
				if {[llength $overrides_r] > 0} {
					## despite the overides we passed in this customer account still has some remain status flags to be overirdden
					## this emans the authentication failed pass back the return code and the overrides remaing to be overridden
					set failed 1
					lappend return_codes [list CUST_STATUS_FLAGS STATUS_FLAGS_CHECK_FAILED \
									STATUS_FLAGS_CHECK_FAILED "Cust status flags checked failed"]

					ob::log::write DEBUG {OB::AUTHENTICATE::authenticate status_flags check failed overrides $overrides_r}
				}
			}

		} else {

			set csf_res [_check_cust_status_flags $ACTION_MAPPINGS($action,cs) $cust_id]

			if {$csf_res != "OK" } {
				## this user has cust status flag restrictions for this acction
				set failed 1
				lappend return_codes [list "CUST_STATUS_FLAGS" [lindex $csf_res 0] [lindex $csf_res 2] [lindex $csf_res 2]]

				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate status_flags check failed}
			}
		}
		## this check failed, were not doing a full check so dont continue with other checks
		if {!$full_check && $failed} {
			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking out of authentication at status_flag check}
			set continue 0
		}
	}


	if {$do_checkpoint_check && $continue} {
		set action_list $action
		if {[lsearch {poker_chip casino_chip} $action] != -1} {
			lappend action_list external_transfer
		}
		foreach current_action $action_list {
			if {!$continue} {
				continue
			}
			set gp_action $ACTION_MAPPINGS($current_action,cc)

			set gp_rs [OB::country_check::do_checkpoint $gp_action $ip_address $application $cust_id $channel]

			ob::log::write DEBUG {checkpoint return $gp_rs}
			if {$gp_rs == "BLOCKED"} {
				## ip blocking encountered in checkpoint checking
				set failed 1
				lappend return_codes [list IP2LOCATION IP2LOCATION_IP_BLOCKED IP2LOCATION_IP_BLOCKED "IP2Location IP blocked"]

				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate checkpoint check failed ip blocked}
			} elseif {[lindex $gp_rs 0]==0} {
				## this ip country is banned from this action
				set failed 1
				set country [lindex $gp_rs 1]

				# switch here if we're doing the spoofed stuff, so we can return the correct error codes
				# i.e. we're not actually using IP2LOCATION, but checking tCtryBanOp for the customer's
				# registered country codes
				if {$region_cookie == "cc_spoof"} {
					lappend return_codes [list CCHK_REG_CTRY CCHK_${gp_action}_BAN_${country} CCHK_${gp_action}_BAN "CCHK Reg Country blocked $gp_action $country"]
					ob::log::write DEBUG {OB::AUTHENTICATE::authenticate checkpoint check failed REGISTRATION country/action blocked action $gp_action country $country}
				} else {
					lappend return_codes [list IP2LOCATION IP2LOCATION_${gp_action}_BAN_${country} IP2LOCATION_${gp_action}_BAN "IP2Location Country Check blocked $gp_action $country"]
					ob::log::write DEBUG {OB::AUTHENTICATE::authenticate checkpoint check failed country/action blocked action $gp_action country $country}
				}
			}
			## this check failed, were not doing a full check so dont continue with other checks
			if {!$full_check && $failed} {
				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking out of authentication at checkpoint check}
				set continue 0
			}
		}
	}


	if {$do_chan_allowed_check && $continue} {
		set force_channel_check 0
		if {[string length $REG_CHANNEL] < 1} {
			ob::log::write ERROR {OB::AUTHENTICATE::authenticate_local registration channel \
				is not populated. Skipping registration channel check for customer $cust_id. }
			set force_channel_check 1
		} else {
			if {$REG_CHANNEL != "I" && $REG_CHANNEL != "P" && $REG_CHANNEL != $channel } {
			# Non-standard registration channel, doing extra channel check
				ob::log::write INFO {OB::AUTHENTICATE::authenticate_local extra channel check for \
					customer $cust_id with registration channel $REG_CHANNEL. }
				set la_rs [_check_chan_allowed $REG_CHANNEL $cust_id $ip_address]
				if {[lindex $la_rs 0] == 0} {
					## channel banned for this ip country
					set failed 1
					set banned_chan [lindex $la_rs 1]
					lappend return_codes [list COUNTRY_CHAN_ALLOWED \
						BET_ERROR_COUNTRY_CHECK_${channel}_${IP_COUNTRY_FOR_RESTRICTIONS} \
						BET_ERROR_COUNTRY_CHECK_${channel}_${IP_COUNTRY_FOR_RESTRICTIONS} \
						"Channel Check Failed: $banned_chan $IP_COUNTRY_FOR_RESTRICTIONS"]

					ob::log::write DEBUG {OB::AUTHENTICATE::authenticate bet registration channel \
						extra check failed channel $banned_chan country $IP_COUNTRY_FOR_RESTRICTIONS}
				}

				## this check failed, we are not doing a full check so dont continue with other checks
				if {!$full_check && $failed} {
					ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking \
						out of authentication at registration channel country check}
					set continue 0
				}
			}
		}

		# if the previous check did not fail, and the registration channel does not override regular
		# or the check has been enforced, then perform regular channel check
		if {$continue} {
			if { (![OT_CfgGet REG_CH_OVERRIDE_CH 0] || $force_channel_check)} {

				if {$channel == ""} {
					ob::log::write ERROR {OB::AUTHENTICATE::authenticate_local channel_id \
						was not passed for the check. Skipping channel check. }
				} else {
					set la_rs [_check_chan_allowed $channel $cust_id $ip_address]
					if {[lindex $la_rs 0] == 0} {
						## channel banned for this ip country
						set failed 1
						set banned_chan [lindex $la_rs 1]
						lappend return_codes [list COUNTRY_CHAN_ALLOWED \
							BET_ERROR_COUNTRY_CHECK_${channel}_${IP_COUNTRY_FOR_RESTRICTIONS} \
							BET_ERROR_COUNTRY_CHECK_${channel}_${IP_COUNTRY_FOR_RESTRICTIONS} \
							"Channel Check Failed: $banned_chan $IP_COUNTRY_FOR_RESTRICTIONS"]

						ob::log::write DEBUG {OB::AUTHENTICATE::authenticate bet channel \
							allowed check failed channel $banned_chan country $IP_COUNTRY_FOR_RESTRICTIONS}
					}

					## this check failed, we are not doing a full check so dont continue with other checks
					if {!$full_check && $failed} {
						ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking \
							out of authentication at bet channel country check}
						set continue 0
					}
				}
			} else {
				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate regular channel check has been overriden}
			}
		}
	} else {
		ob::log::write DEV {OB::AUTHENTICATE::authenticate skipped channel check}
	}

	if {$do_sys_allowed_check && $continue && $system_id != ""} {
		set rs [ob_db::exec_qry OB::AUTHENTICATE::get_sysgrp_from_sys_id $system_id]
		set group_id ""

		if {[db_get_nrows $rs] < 1} {
			ob::log::write ERROR {OB::AUTHENTICATE::authenticate_local \
				system id $system_id cannot be linked to any group id. \
				Skipping system check. }
		} else {
			set group_id [db_get_col $rs 0 group_id]
			ob::log::write INFO {Linking system id $system_id to group id $group_id}

			# Check whether the customer is allowed to to use the system.
			foreach {res avail} [OB::EXCLUSIONS::check_system_allowed $cust_id $system_id] {}
			if {$res != {OK} || !$avail} {
				set failed 1
				lappend return_codes [list COUNTRY_SYS_ALLOWED \
					BET_ERROR_COUNTRY_CHECK_${group_id}_${IP_COUNTRY_FOR_RESTRICTIONS} \
					BET_ERROR_COUNTRY_CHECK_${group_id}_${IP_COUNTRY_FOR_RESTRICTIONS} \
					"System check failed: group_id:$group_id $IP_COUNTRY_FOR_RESTRICTIONS"]
			}


			set la_rs [_check_sys_allowed $group_id $cust_id $ip_address]

			if {[lindex $la_rs 0] == 0} {
				## system banned for this ip country
				set failed 1
				set banned_sys [lindex $la_rs 1]
				lappend return_codes [list COUNTRY_SYS_ALLOWED \
					BET_ERROR_COUNTRY_CHECK_${group_id}_${IP_COUNTRY_FOR_RESTRICTIONS} \
					BET_ERROR_COUNTRY_CHECK_${group_id}_${IP_COUNTRY_FOR_RESTRICTIONS} \
					"System check failed: $banned_sys $IP_COUNTRY_FOR_RESTRICTIONS"]

				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate bet system allowed \
					check failed $banned_sys country $IP_COUNTRY_FOR_RESTRICTIONS}
			}

			## this check failed, we are not doing a full check so dont continue with other checks
			if {!$full_check && $failed} {
				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking \
					out of authentication at bet system group
				country check}
				set continue 0
			}
		}
		catch {db_close $rs}
	} else {
		ob::log::write DEV {OB::AUTHENTICATE::authenticate skipped system check}
	}

	if {$do_add_allowed_check && $continue} {

		if {$channel == "" || $add_name == ""} {
			ob::log::write ERROR {OB::AUTHENTICATE::authenticate_local name \
				or channel_id were not passed in. Skipping additional item check. }
		} else {
			set la_rs [_check_add_allowed $add_name $channel $cust_id $ip_address]

			if {[lindex $la_rs 0] == 0} {
				## item banned for this ip country
				set failed 1
				set banned_add [lindex $la_rs 1]
				set banned_channel [lindex $la_rs 2]
				if {$add_name == "Minigames"} {
					lappend return_codes [list FOG_CHECK \
						COUNTRY_BLOCKED_${IP_COUNTRY_FOR_RESTRICTIONS} \
						FOG_COUNTRY_BLOCKED_${IP_COUNTRY_FOR_RESTRICTIONS} \
						"Country Blocked: $IP_COUNTRY_FOR_RESTRICTIONS"]
				} else {
					lappend return_codes [list COUNTRY_ADD_ALLOWED \
						BET_ERROR_COUNTRY_CHECK_${banned_add}_${banned_channel}_${IP_COUNTRY_FOR_RESTRICTIONS} \
						BET_ERROR_COUNTRY_CHECK_${banned_add}_${banned_channel}_${IP_COUNTRY_FOR_RESTRICTIONS} \
						"Additional Check Failed: $banned_add $banned_channel $IP_COUNTRY_FOR_RESTRICTIONS"]
				}
				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate additional bannable \
					item check failed item $banned_add channel $banned_channel country \
					$IP_COUNTRY_FOR_RESTRICTIONS}
			}

			## this check failed, we are not doing a full check so dont continue with other checks
			if {!$full_check && $failed} {
				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking out \
					of authentication at bet additional item country check}
				set continue 0
			}
		}
	} else {
		ob::log::write DEV {OB::AUTHENTICATE::authenticate skipped additional item check}
	}

	if {$do_cat_allowed_check && $continue} {

		if {$ev_id != ""} {
			set ca_rs [_check_cat_allowed_by_ev_id $ev_id $cust_id $application $ip_address]
		} else {
			set ca_rs [_check_cat_allowed_by_ev_oc_id $ev_oc_ids $cust_id $application $ip_address]
		}

		if {[lindex $ca_rs 0] == 0} {
			## category banned for this ip country
			set failed 1
			set banned_cat [lindex $ca_rs 1]
			lappend return_codes [list COUNTRY_CAT_ALLOWED BET_ERROR_COUNTRY_CHECK_${banned_cat}_${IP_COUNTRY} BET_ERROR_COUNTRY_CHECK_${banned_cat}_${IP_COUNTRY} "Category Check failed: $banned_cat $IP_COUNTRY"]

			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate bet category allowed check failed cat $banned_cat country $IP_COUNTRY}
		}

		## this check failed, were not doing a full check so dont continue with other checks
		if {!$full_check && $failed} {
			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking out of authentication at bet category country check}
			set continue 0
		}
	}

	if {$do_lot_allowed_check && $continue} {

		if {$xgame_sort == ""} {
			ob::log::write ERROR {OB::AUTHENTICATE::authenticate_local \
				xgame_sort was not passed for the check. Skipping lotteries check. }
		} else {
			set la_rs [_check_lot_allowed $xgame_sort $cust_id $application $ip_address]

			if {[lindex $la_rs 0] == 0} {
				## lottery banned for this ip country
				set failed 1
				set banned_lot [lindex $la_rs 1]
				lappend return_codes [list COUNTRY_LOT_ALLOWED \
				BET_ERROR_COUNTRY_CHECK_${xgame_sort}_${IP_COUNTRY_FOR_RESTRICTIONS} \
				BET_ERROR_COUNTRY_CHECK_${xgame_sort}_${IP_COUNTRY_FOR_RESTRICTIONS} \
				"Lottery Check Failed: $banned_lot $IP_COUNTRY_FOR_RESTRICTIONS"]

				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate bet lottery allowed \
					check failed lottery $banned_lot country $IP_COUNTRY_FOR_RESTRICTIONS}
			}

			## this check failed, we are not doing a full check so dont continue with other checks
			if {!$full_check && $failed} {
				ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking \
					out of authentication at bet lottery country check}
				set continue 0
			}
		}
	} else {
		ob::log::write DEV {OB::AUTHENTICATE::authenticate skipped lottery check}
	}

	if {$do_games_check && $continue} {
		set gc_rs [_allow_game $game_id $cust_id]

		if {$gc_rs == 0} {
			set failed 1
			lappend return_codes [list FOG_CHECK COUNTRY_BLOCKED_${IP_COUNTRY} FOG_COUNTRY_BLOCKED_${IP_COUNTRY} "Country Blocked: $IP_COUNTRY"]
		}

		## this check failed, were not doing a full check so dont continue with other checks
		if {!$full_check && $failed} {
			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate breaking out of authentication at games check check}
			set continue 0
		}
	}

	if {$do_lightweight_cookie_check && $continue} {
		set lw_cc [_lightweight_cookie_check]

		if {$lw_cc} {
			set failed 1
			lappend return_codes [list COOKIE_CHECK COOKIE_CHECK_FAILED COOKIE_CHECK_FAILED "Cookie Check Failed"]

			ob::log::write DEBUG {OB::AUTHENTICATE::authenticate lightweight_cookie_check failed}
		}
	}

	## build up return list
	if {$failed} {
		set main_response F
	} else {
		set main_response S
	}

	if {[llength $return_codes] == 1 && $flatten_return_codes == "Y"} {
		## flatten this list if only one item to make my life easier
		set return_codes [lindex $return_codes 0]
	}

	set region_cookie [get_region_cookie]

	ob::log::write INFO {OB::AUTHENTICATE::authenticate returning $main_response $return_codes $region_cookie $overrides_r}

	return [list $main_response $return_codes $region_cookie $overrides_r]
}

# store and retrieve the cookie in a var, use req_no is ensure we have right value
# shared tcl now use these functoions to store and retrieve the cookie
# and the actual applications deal with putting the cookie in the response etc.
# this allows non openbet apps to utilise cookie check as the cookie string is in the xml request and response :-)
proc OB::AUTHENTICATE::get_region_cookie args {
	variable REGION_COOKIE
	set id [reqGetId]

	ob::log::write INFO {REGION_COOKIE(req_no) $REGION_COOKIE(req_no) | request ID: $id}

	if {$REGION_COOKIE(req_no) != $id} {
		return ""
	} else {
		return $REGION_COOKIE(region_cookie)
	}
}
proc OB::AUTHENTICATE::set_region_cookie {region_cookie} {

	variable REGION_COOKIE
	set id [reqGetId]
	set REGION_COOKIE(req_no) $id
	set REGION_COOKIE(region_cookie) $region_cookie
}


##some helper functions to be used to store and retrive cookies by applications that care about them
proc OB::AUTHENTICATE::store_region_cookie {region_cookie} {

	variable COOKIE_REQ_ID
	set id [reqGetId]

	## COOKIE_REQ_ID stops us storing the cookie in the header multiple times in a request
	## doing so screws up the cookie as browsers get confused

	if {$region_cookie != "" && $COOKIE_REQ_ID != $id} {
		set cc_cookie_name [OT_CfgGet CC_COOKIE "cust_auth"]
		ob_util::set_cookie "$cc_cookie_name=$region_cookie"

		set COOKIE_REQ_ID $id

		ob::log::write INFO {Set encrypted cookie for country check $cc_cookie_name=$region_cookie}
	}
}
proc OB::AUTHENTICATE::retrieve_region_cookie args {
	set cc_cookie_name [OT_CfgGet CC_COOKIE "cust_auth"]

	set enc_flag [get_cookie $cc_cookie_name]

	set_region_cookie $enc_flag

	return $enc_flag
}

########################### server procedures used by authetication server ###################################


##
## procedure called in authenticate request.
## takes an xml message breaks it in to its parts and makes a call to authenticate_local
## the result is then packed up as an xml message returned to the caller
##
proc OB::AUTHENTICATE::do_remote_authenticate {xml_msg} {
	ob::log::write DEBUG {OB::AUTHENTICATE::do_remote_authenticate request xml $xml_msg}

	##REQUIRED nodes
	foreach required {application channel cust_id action} {
		if {[catch {
			set node [$xml_msg selectNode "${required}/text()"]
			set $required [$node nodeValue]

		} msg]} {
			destroyMessage $xml_msg
			error "required node not present: $required"
		}
	}

	##OPTIONAL nodes
	set full_check "N"
	set ip_address ""
	set region_cookie "no_cookie"
	set ev_oc_ids ""
	set ev_id ""
	set game_id ""
	set overrides [list]

	foreach optional {full_check ip_address region_cookie ev_oc_ids game_id} {
		catch {
			set node [$xml_msg selectNode "${optional}/text()"]

			## node may be empty
			if {[catch {
				set $optional [$node nodeValue]
			} msg]} {
				set $optional ""
			}
		}
	}



	# get overirdes
	catch {
		set orides [$xml_msg selectNode "overrides"]
		set override_nodes [$orides selectNode "override/text()"]

		foreach override_node $override_nodes {
			lappend overrides [$override_node nodeValue]
		}
	}

	## do authenticate
	set response [authenticate_local $application $channel $cust_id $action $full_check $ip_address $region_cookie $ev_oc_ids $ev_id $game_id $overrides N ]


	set main_response [lindex $response 0]
	set return_codes  [lindex $response 1]
	set region_cookie [lindex $response 2]
	set orides        [lindex $response 3]

	# build response xml

	dom setResultEncoding [OT_CfgGet XML_ENCODING "UTF-8"]

	set doc [dom createDocument "shared_server"]
	set sharedserver [$doc documentElement]

	set resp [$doc createElement "response"]
	set message [$sharedserver appendChild $resp]

	set elem		[$doc createElement "respAuthenticate"]
	set respAuth	[$message appendChild $elem]

	## main response elem
	set elem		[$doc createElement "main_response"]
	set main_resp_node	[$respAuth appendChild $elem]
	set main_resp_tnode  [$doc createTextNode $main_response]
	$main_resp_node appendChild $main_resp_tnode

	if {[llength $return_codes] > 0 } {
		set elem [$doc createElement "return_codes"]
		set return_codes_node [$respAuth appendChild $elem]
	}

	# add return codes
	for {set i 0} {$i < [llength $return_codes]} {incr i} {
		set return_code [lindex $return_codes $i]

		set elem [$doc createElement "return_code"]
		set return_code_node [$return_codes_node appendChild $elem]

		set elem [$doc createElement "check"]
		set check_node [$return_code_node appendChild $elem]
		set check_node_tnode  [$doc createTextNode [lindex $return_code 0]]
		$check_node appendChild $check_node_tnode

		set elem [$doc createElement "code"]
		set code_node [$return_code_node appendChild $elem]
		set code_node_tnode  [$doc createTextNode [lindex $return_code 1]]
		$code_node appendChild $code_node_tnode

		set elem [$doc createElement "cust_message"]
		set cust_message_node [$return_code_node appendChild $elem]
		set cust_message_tnode  [$doc createTextNode [lindex $return_code 2]]
		$cust_message_node appendChild $cust_message_tnode

		set elem [$doc createElement "op_message"]
		set op_message_node [$return_code_node appendChild $elem]
		set op_message_tnode  [$doc createTextNode [lindex $return_code 3]]
		$op_message_node appendChild $op_message_tnode
	}

	if {$region_cookie != ""} {
		# cookie element
		set elem [$doc createElement "cookie"]
		set cookie_node [$respAuth appendChild $elem]
		set cookie_text_node [$doc createTextNode $region_cookie]
		$cookie_node appendChild $cookie_text_node
	}

	if {[llength $orides] > 0 } {
		set elem [$doc createElement "overrides"]
		set orides_node [$respAuth appendChild $elem]
	}

	# add overrirdes elements
	for {set i 0} {$i < [llength $orides]} {incr i} {
		set elem [$doc createElement "override"]
		set oride_node [$orides_node appendChild $elem]
		set oride_text_node [$doc createTextNode [lindex $orides $i]]
		$oride_node appendChild $oride_text_node
	}

	return $resp
}



##
## posts an auth request to a authentication server
## this procedure is used if the applicationsusinf the library wnat to use a remote authentication server rather than doing it locally
## build the request xml, posts request, parses response and build return list as if the call had been made locally
##
proc OB::AUTHENTICATE::post_auth_request {application channel cust_id action full_check {ip_address ""} {region_cookie "no_cookie"} {ev_oc_ids ""} {ev_id ""} {game_id ""} {overrides ""}} {
	package require http

	set xml_msg [generate_request_xml $application $channel $cust_id $action $full_check $ip_address $region_cookie $ev_oc_ids $ev_id $game_id $overrides]

	set get_url_fail 0

	if {[catch {
		#Send the request.
		set resp_token [http::geturl \
							[OT_CfgGet AUTH_SERVER_SERVER_URL]\
							-timeout [OT_CfgGet AUTH_SERVER_TIMEOUT] \
							-type "text/xml" \
							-query $xml_msg]
		upvar #0 $resp_token state

		ob::log::write INFO {OB::AUTHENTICATE::post_auth_request server response status: $state(http)}
	} msg]} {
		ob::log::write ERROR {OB::AUTHENTICATE::post_auth_request Failed to get a reponse from the server: $msg}
		set get_url_fail 1
	}

	#Get the http response code. For a successful request $state(http)
	#will be of the form:
	#
	# HTTP_VERSION HTTP_RESPONSE_CODE HTTP_RESPONSE_MESSAGE
	#
	#For a successful request:
	#
	# HTTP/1.1 200 OK
	set http_response_code [lindex [split $state(http) " "] 1]

	set success 1

	if {$get_url_fail || ($http_response_code != "200")} {
		set success 0
		#If the reqest failed then log the action.
		ob::log::write ERROR {OB::AUTHENTICATE::post_auth_request failed authenticate server request}
		set body ""
	} else {
		set body $state(body)
	}

	http::cleanup $resp_token

	return [list $success $http_response_code $body]
}


##
## generates the request xml for the authentication server
##
proc OB::AUTHENTICATE::generate_request_xml {application channel cust_id action full_check {ip_address ""} {region_cookie "no_cookie"} {ev_oc_ids ""} {ev_id ""} {game_id ""} {orides ""}} {

	package require tdom

	dom setResultEncoding [OT_CfgGet XML_ENCODING "UTF-8"]

	set doc [dom createDocument "shared_server"]
	set sharedserver [$doc documentElement]

	set resp [$doc createElement "request"]
	set message [$sharedserver appendChild $resp]

	set elem		[$doc createElement "reqAuthenticate"]
	set reqAuth	    [$message appendChild $elem]

	## application node
	set elem		        [$doc createElement "application"]
	set application_node	[$reqAuth appendChild $elem]
	set application_tnode   [$doc createTextNode $application]
	$application_node appendChild $application_tnode

	## channel node
	set elem		        [$doc createElement "channel"]
	set channel_node	    [$reqAuth appendChild $elem]
	set channel_tnode       [$doc createTextNode $channel]
	$channel_node appendChild $channel_tnode

	## cust_id node
	set elem		        [$doc createElement "cust_id"]
	set cust_id_node	    [$reqAuth appendChild $elem]
	set cust_id_tnode       [$doc createTextNode $cust_id]
	$cust_id_node appendChild $cust_id_tnode

	## action node
	set elem		        [$doc createElement "action"]
	set action_node	        [$reqAuth appendChild $elem]
	set action_tnode       [$doc createTextNode $action]
	$action_node appendChild $action_tnode

	## full_check node
	set elem		        [$doc createElement "full_check"]
	set full_check_node	        [$reqAuth appendChild $elem]
	set full_check_tnode       [$doc createTextNode $full_check]
	$full_check_node appendChild $full_check_tnode


	if {$ip_address != ""} {
		## ip_address node
		set elem		        [$doc createElement "ip_address"]
		set ip_address_node	        [$reqAuth appendChild $elem]
		set ip_address_tnode       [$doc createTextNode $ip_address]
		$ip_address_node appendChild $ip_address_tnode
	}

	if {$region_cookie != "no_cookie"} {
		## region_cookie node
		set elem		        [$doc createElement "region_cookie"]
		set region_cookie_node	        [$reqAuth appendChild $elem]
		set region_cookie_tnode       [$doc createTextNode $region_cookie]
		$region_cookie_node appendChild $region_cookie_tnode
	}

	if {$ev_oc_ids != ""} {
		## ev_oc_ids node
		set elem		        [$doc createElement "ev_oc_ids"]
		set ev_oc_ids_node	        [$reqAuth appendChild $elem]
		set ev_oc_ids_tnode       [$doc createTextNode $ev_oc_ids]
		$ev_oc_ids_node appendChild $ev_oc_ids_tnode
	}

	if {$ev_id != ""} {
		## ev_id node
		set elem		        [$doc createElement "ev_id"]
		set ev_id_node	        [$reqAuth appendChild $elem]
		set ev_id_tnode       [$doc createTextNode $ev_id]
		$ev_id_node appendChild $ev_id_tnode
	}

	if {$game_id != ""} {
		$authenticate_node setAttribute "game_id" $game_id

		## game_id node
		set elem		        [$doc createElement "game_id"]
		set game_id_node	        [$reqAuth appendChild $elem]
		set game_id_tnode       [$doc createTextNode $game_id]
		$game_id_node appendChild $game_id_tnode
	}

	if {[llength $orides] > 0 } {
		set elem [$doc createElement "overrides"]
		set orides_node [$respAuth appendChild $elem]
	}

	# add overrirdes elements
	for {set i 0} {$i < [llength $orides]} {incr i} {
		set elem [$doc createElement "override"]
		set oride_node [$orides_node appendChild $elem]
		set oride_text_node [$doc createTextNode [lindex $orides $i]]
		$oride_node appendChild $oride_text_node
	}


	set xml_msg [printMessage $resp]

	destroyMessage $resp

	ob::log::write DEBUG {OB::AUTHENTICATE::generate_request_xml request XML: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n $xml_msg"}

	return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n$xml_msg"

}



## parses the resonse xml from an authtication server generating a return list as if the call to authenticate had been made locally
proc OB::AUTHENTICATE::parse_response {xml_resp {flatten_return_codes "Y"}} {
	package require tdom

	ob::log::write DEBUG {OB::AUTHENTICATE::parse_response response xml : $xml_resp}

	set err_return_code [list "AUTH_SERVER" "GARBLED_XML" "GARBLED_XML" "Garbled XML"]

	if {[catch { set doc [dom parse -simple $xml_resp]} msg]} {
		return [list E $err_return_code "" $msg]
	}

	set sharedserver [$doc documentElement]

	# Get the child nodes of the document element.
	if {[catch {set nodes [$sharedserver childNodes]} msg]} {
		destroyMessage $xml_resp
		return [list E $err_return_code "" $msg]
	}

	# We should have one child element.
	if {[llength $nodes] != 1} {
		destroyMessage $xml_resp
		return [list E $err_return_code "" $msg]
	}
	set node [lindex $nodes 0]
	set class [$node nodeName]

	# Check the element name is correct.
	if {![string equal $class "response"]} {
		destroyMessage $xml_resp
		return [list E $err_return_code "" $msg]
	}

	if {[catch {set nodes [$node childNodes]} msg]} {
		destroyMessage $xml_resp
		return [list E $err_return_code "" $msg]
	}

	set numNodes [llength $nodes]

	if {$numNodes == 1} {
		set respAuthenticate [lindex $nodes 0]
		if {[catch {set type [$respAuthenticate nodeName]} msg]} {
			destroyMessage $xml_resp
			return [list E $err_return_code "" $msg]
		}
	} else {
		destroyMessage $xml_resp
		return [list E $err_return_code "" "more than one respAuthenticate node"]
	}

	if {$type != "respAuthenticate"} {
		destroyMessage $xml_resp
		return [list E $err_return_code "" "request not of type respAuthenticate: $type"]
	}

	set return_codes [list]
	set overrides [list]
	set main_response F
	set region_cookie ""

	## main response is required
	if {[catch {
			set node [$respAuthenticate selectNode "main_response/text()"]
			set main_response [$node nodeValue]
	} msg]} {
		destroyMessage $xml_resp
		return [list F $err_return_code "" "$msg"]
	}

	## get the cookie value if its there
	catch {
		set node [$respAuthenticate selectNode "${cookie}/text()"]
		set region_cookie [$node nodeValue]
	}

	## get the return codes
	catch {
		set r_codes [$respAuthenticate selectNode "return_codes"]
		set return_code_nodes [$r_codes selectNode "return_code"]

		foreach return_code_node $return_code_nodes {
			set node [$return_code_node selectNode "check/text()"]
			set check [$node nodeValue]

			set node [$return_code_node selectNode "code/text()"]
			set code [$node nodeValue]

			set node [$return_code_node selectNode "cust_message/text()"]
			set cust_message [$node nodeValue]

			set node [$return_code_node selectNode "op_message/text()"]
			set op_message [$node nodeValue]

			lappend return_codes [list $check $code $cust_message $op_message]
		}
	}

	## get the overrides
	catch {
		set orides [$respAuthenticate selectNode "overrides"]
		set override_nodes [$orides selectNode "override/text()"]

		foreach override_node $override_nodes {
			lappend overrides [$override_node nodeValue]
		}
	}

	destroyMessage $xml_resp

	if {[llength $return_codes] == 1 && $flatten_return_codes == "Y"} {
		## flatten this list if only one item to make my life easier
		set return_codes [lindex $return_codes 0]
	}

	return [list $main_response $return_codes $region_cookie $overrides]
}


##
## destroys the xml. we nedd to make sure we always do this when we are done with the dom tree to sabe from memory leaks
##
proc OB::AUTHENTICATE::destroyMessage {node} {

	if {[catch {set doc [$node ownerDocument]}]} {
		set doc $node
	}
	catch {$doc delete}
}



##
## converts the xml structure in to text.
##
proc OB::AUTHENTICATE::printMessage {node} {
	set doc [$node ownerDocument]
	set doc_elem [$doc documentElement]
	set xml [$doc_elem asXML]

	return $xml
}


# Initialise
OB::AUTHENTICATE::_init
