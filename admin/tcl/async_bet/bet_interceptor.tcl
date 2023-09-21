# $Id: bet_interceptor.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Admin
# Asynchronous Betting Bet Interceptor - Allows an admin user with
# appropriate permissions to view and process pending bets via the
# new Bet Interceptor Admin Screens Interface.
#
# Configuration:
#   ASYNC_BET_REASON_CODE_GROUP      reason XLate group (Async.Bet)
#
# Procedures:
#   ::ADMIN::ASYNC_BET::GoBetInterceptor     play bet interceptor page
#   ::ADMIN::ASYNC_BET::DoPendingBetSearch   perform a search on pending bets
#

# Namespace
#
namespace eval ::ADMIN::ASYNC_BET {

	asSetAct ADMIN::ASYNC_BET::GoBetInterceptor   \
									::ADMIN::ASYNC_BET::H_bet_interceptor
	asSetAct ADMIN::ASYNC_BET::DoPendingBetSearch \
									::ADMIN::ASYNC_BET::H_do_pending_bet_search

	variable BET_COL_DATA
	variable VIEW_PREF_COOKIE_NAME
	variable FILTER_OPTIONS_COOKIE_NAME
	variable DEFAULT_REFRESH_RATE
	variable MIN_REFRESH_RATE
	variable VIEW_PREF_COLS
	variable LIAB_GROUP

	variable cookie_expires

	set cookie_expires "expires=Sat, 01 Jan 3000 00:00:00"

	# Store what how each column will be displayed, what it's data field
	# is and whether it's a M(andatory)/D(efault) to on/off (Y/N) column
	# respectively
	#
	set BET_COL_DATA [list \
					"Time"                  cr_date          "M"\
					"Selection"             seln_name        "Y"\
					"Price"                 price_type       "Y"\
					"Cust SF"               max_stake_scale  "Y"\
					"Client Name"           cust_name        "Y"\
					"Account No."           acct_no          "Y"\
					"Stake"                 sys_stake        "Y"\
					"Max bet"               max_bet          "Y"\
					"Bet type"              bet_type         "N"\
					"Start Time"            start_time       "N"\
					"Legs"                  num_legs         "N"\
					"No. Selns"             num_selns        "N"\
					"Perms"                 num_lines        "N"\
					"Payout"                sys_pot_payout   "Y"\
					"Event Category"        ev_category      "N"\
					"Event Class"           ev_class_name    "N"\
					"Event Type"            ev_type_name     "N"\
					"Event"                 ev_name          "N"\
					"Handicap"              hcap_value       "N"\
					"Channel"               source_desc      "N"\
					"Liability Group"       liab_desc        "N"\
					"Freebet"               token_value      "N"\
					"Currency"              ccy_code         "Y"\
					"Telephonist"           tele_user        "Y"\
					"Locked By"             admin_username   "Y"\
					"Reason"                park_reason      "Y"\
					"Customer Group"        cust_group       "N"]

	# Initialise View Preferences Cookie Name
	set VIEW_PREF_COOKIE_NAME \
		[OT_CfgGet ASYNC_BET_VIEW_PREF_COOKIE_NAME "AsyncBetViewPref"]

	# Initialise View Preferences Cookie Name
	set FILTER_OPTIONS_COOKIE_NAME \
		[OT_CfgGet ASYNC_BET_FILTER_COOKIE_NAME "AsyncBetFilterOptions"]

	set DEFAULT_REFRESH_RATE [OT_CfgGet ASYNC_BET_DETAILS_REFRESH_RATE 15]
	set MIN_REFRESH_RATE     [OT_CfgGet ASYNC_BET_DETAILS_MIN_REFRESH_RATE 5]

	array set VIEW_PREF_COLS [list]
	array set LIAB_GROUP     [list]

}



#--------------------------------------------------------------------------
# Action Handlers
#--------------------------------------------------------------------------

# Play the Async Details Betting Interceptor Page
#
proc ::ADMIN::ASYNC_BET::H_bet_interceptor args {

	variable VIEW_PREF_COOKIE_NAME
	variable FILTER_OPTIONS_COOKIE_NAME

	if {![op_allowed ViewAsyncBets]} {
		_err_bind "You do not have permission to view Auto-referral Bets"
		asPlayFile -nocache async_bet/bet_interceptor.html
		return
	}

	# Bind up the currenct time & refresh rate information
	_bind_time

	# Bind up list of Event Categories
	_bind_ev_categories

	# Bind up list of Event Classes
	_bind_ev_classes

	# Bind up list of Event Channels
	_bind_ev_channels

	# Bind up list of Event Types
	_bind_ev_types

	# Bind up list of Events
	_bind_events

	# Bind up list of account owners
	_bind_account_owners

	# Get/Setup the stored filter options from a cookie
	_prep_filter_options_cookie

	# Get/Setup the viewing preferences from a cookie (stored in a cookie)
	_prep_view_pref_cookie

	# Binding decline reason codes
	_bind_decline_reason_codes

	tpBindString view_pref_cookie      $VIEW_PREF_COOKIE_NAME
	tpBindString filter_options_cookie $FILTER_OPTIONS_COOKIE_NAME

	asPlayFile -nocache async_bet/bet_interceptor.html
}



# Perform an Async' Betting Search. This is initiated via an Ajax
# call so any response given should be sent back in HTML.
#
proc ::ADMIN::ASYNC_BET::H_do_pending_bet_search args {

	global ASYNC

	# Do login check here since 'login' check is not
	# performed for this action (as it'll play the main
	# login page in a div which isn't a good idea).
	if {![ADMIN::LOGIN::check_login]} {
		_err_send "You are not logged in , please login again."
		return
	}

	# Get/Setup the stored filter options from a cookie
	_prep_view_pref_cookie

	# Get the pending bets into the 'ASYNC' global array. If any
	# errors occur, write them back to the Ajax code can dump
	# the error information onto the page.
	if {[catch {_get_pending_bets} msg]} {
		_err_send $msg
		return
	}

	# Get/Setup the viewing preferences options from a cookie
	_prep_filter_options_cookie


	# Send back the outcome of the pending bets search
	_send_pending_bets

}


#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Private procedure to bind account owners
#
proc ::ADMIN::ASYNC_BET::_bind_account_owners args {
	global DB ACCT_OWNERS

	catch {array unset ACCT_OWNERS}

	set owners_cfg [OT_CfgGet ENUM_ACCT_OWNER {}]

	set i 0
	foreach owner $owners_cfg {
		set ACCT_OWNERS($i,name) [lindex $owner 0]
		set ACCT_OWNERS($i,desc) [lindex $owner 1]
		incr i
	}

	tpSetVar NumAcctOwners [llength $owners_cfg]

	tpBindVar OwnerName ACCT_OWNERS name owners_idx
	tpBindVar OwnerDesc ACCT_OWNERS desc owners_idx
}

# Private procedure to bind active Event Classes
#
proc ::ADMIN::ASYNC_BET::_bind_ev_categories args {

	global DB EV_CAT

	catch {array unset EV_CAT}

	array set EV_CAT [list]

	set sql {
		select
			ev_category_id,
			category
		from
			tEvCategory
		where
			displayed <> 'N'
		order by
			disporder
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set EV_CAT($i,id)     [db_get_col $rs $i ev_category_id]
		set EV_CAT($i,name)   [db_get_col $rs $i category]

		# provide a version of the category name without spaces
		# or '-' or '*' (for use in HTML element names)
		set EV_CAT($i,stripped_name) [string map {{ } {} {-} {} {*} {}} \
												[db_get_col $rs $i category]]
	}

	catch {db_close $rs}

	tpSetVar NumCategories $nrows

	tpBindVar CategoryId      EV_CAT id   cat_idx
	tpBindVar CategoryName    EV_CAT name cat_idx
	tpBindVar CatNameStripped EV_CAT stripped_name cat_idx

}



# Private procedure to bind active Event Classes
#
proc ::ADMIN::ASYNC_BET::_bind_ev_classes args {

	global DB EV_CLASS

	catch {array unset EV_CLASS}

	array set EV_CLASS [list]

	set sql {
		select
			ev_class_id,
			name cname,
			upper(name) upcname,
			category
		from
			tEvClass
		where
			status <> 'S'
		order by
			displayed desc,
			upcname asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set EV_CLASS($i,id)   [db_get_col $rs $i ev_class_id]
		set EV_CLASS($i,name) [db_get_col $rs $i cname]
		set EV_CLASS($i,category) [db_get_col $rs $i category]
	}

	catch {db_close $rs}

	tpSetVar NumClasses $nrows

	tpBindVar ClassId   EV_CLASS id       class_idx
	tpBindVar ClassName EV_CLASS name     class_idx
	tpBindVar ClassCategory  EV_CLASS category class_idx
}

# Private procedure to bind active Channels
#
proc ::ADMIN::ASYNC_BET::_bind_ev_channels args {

	global DB CHANNEL_MAP

	# initialise CHANNEL_MAP array if it hasn't been already
	read_channel_info

	set num_channels $CHANNEL_MAP(num_channels)

	tpSetVar     NumChannels $num_channels

	tpBindVar ChannelId    CHANNEL_MAP code chan_idx
	tpBindVar ChannelName  CHANNEL_MAP name chan_idx
}

# Private procedure to bind active Event Types
#
proc ::ADMIN::ASYNC_BET::_bind_ev_types args {

	global DB EV_TYPE

	catch {array unset EV_TYPE}

	array set EV_TYPE [list]

	set sql {
		select
			t.ev_type_id,
			t.name,
			t.ev_class_id,
			c.category
		from
			tEvType t,
			tEvClass c
		where
			c.ev_class_id = t.ev_class_id
			and t.status <> 'S'
		order by
			t.displayed desc,
			t.name asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set EV_TYPE($i,id)   [db_get_col $rs $i ev_type_id]
		set EV_TYPE($i,name) [db_get_col $rs $i name]
		set EV_TYPE($i,class_id) [db_get_col $rs $i ev_class_id]
		set EV_TYPE($i,category) [db_get_col $rs $i category]
	}

	catch {db_close $rs}

	tpSetVar NumEvTypes $nrows

	tpBindVar TypeId    EV_TYPE id       ev_type_idx
	tpBindVar TypeName  EV_TYPE name     ev_type_idx
	tpBindVar TypeClassId   EV_TYPE class_id ev_type_idx
	tpBindVar TypeCategory  EV_TYPE category ev_type_idx
}

# Private procedure to bind active Event Types
#
proc ::ADMIN::ASYNC_BET::_bind_events args {

	global DB EV

	catch {array unset EV}

	array set EV [list]

	set sql {
		select
			e.ev_id,
			e.desc as name,
			e.ev_class_id,
			e.ev_type_id,
			c.category
		from
			tEv e,
			tEvClass c
		where
			c.ev_class_id = e.ev_class_id and
			e.status <> 'S'
		order by
			e.displayed desc,
			e.desc asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set EV($i,id)   [db_get_col $rs $i ev_id]
		set EV($i,name) [db_get_col $rs $i name]
		set EV($i,class_id) [db_get_col $rs $i ev_class_id]
		set EV($i,type_id) [db_get_col $rs $i ev_type_id]
		set EV($i,category) [db_get_col $rs $i category]
	}

	catch {db_close $rs}

	tpSetVar NumEvents $nrows

	tpBindVar EvId      EV id       ev_idx
	tpBindVar EvName    EV name     ev_idx
	tpBindVar EvClassId EV class_id ev_idx
	tpBindVar EvTypeId  EV type_id  ev_idx
	tpBindVar EvCategory EV category  ev_idx
}

# Private procedure to get information the on pending bets and
# store the information in the 'ASYNC' array
#
proc ::ADMIN::ASYNC_BET::_get_pending_bets { {arg_grp_id ""} args } {

	global DB ASYNC USERNAME CHANNEL_MAP
	variable VIEW_PREF_COLS

	catch {array unset ASYNC}

	# Get filter parameters
	set class_ids    [reqGetArgs chosen_class_id]
	set category_ids [reqGetArgs chosen_category_id]
	set channel_ids  [reqGetArgs chosen_channel_id]
	set ev_type_ids  [reqGetArgs chosen_ev_type_id]
	set ev_ids       [reqGetArgs chosen_ev_id]
	set acct_owners  [reqGetArgs chosen_owner]

	set category_exc [reqGetArgs cat_exclude]
	set bir_flag     [reqGetArgs bir_flag]

	set category_filter {}
	set class_filter    {}
	set channel_filter  {}
	set ev_type_filter  {}
	set event_filter    {}
	set bir_filter      {}
	set grp_filter      {}
	set owner_filter    {}

	# initialise CHANNEL_MAP array if it hasn't been already
	read_channel_info

	if {$class_ids != ""} {
		set class_filter "ec.ev_class_id in ([join $class_ids {,}]) and"
	}

	if {$category_ids != "" && $category_exc == "N"}  {
		set category_filter "ecat.category in ('[join $category_ids {','}]') and"
	}
	if {$category_ids != "" && $category_exc == "Y"} {
		set category_filter "ecat.category not in ('[join $category_ids {','}]') and"
	}

	if {$channel_ids != ""} {
		set channel_filter "b.source in ('[join $channel_ids {','}]') and"
	}

	if {$ev_type_ids != ""}  {
		set ev_type_filter "et.ev_type_id in ([join $ev_type_ids {,}]) and"
	}

	if {$ev_ids != ""} {
		set event_filter "e.ev_id in ([join $ev_ids {,}]) and"
	}

	if {$bir_flag == "Y"} {
		set bir_filter "o.in_running = 'Y' and"
	}

	if {$acct_owners != ""} {
		set owner_filter "a.owner in ('[join $acct_owners {','}]') and"
	}

	# Setup the pending bets search query
	set sql [subst {
		select
			NVL(au.username,'-') admin_username,
			NVL(xv.xlation_1,NVL(y.park_reason,'-')) park_reason,
			NVL(c.liab_group,'-') liab_group,
			c.cust_id,
			c.acct_no,
			c.max_stake_scale,
			cr.fname,
			cr.lname,
			a.ccy_code,
			a.acct_id,
			b.bet_id,
			b.cr_date,
			b.bet_type,
			b.stake,
			b.token_value,
			b.stake_per_line,
			b.num_lines,
			b.num_legs,
			b.num_selns,
			sb.betslip_id as bet_group_id,
			bo.status as ref_status,
			case
				when b.status = 'X' then 'X'
				when b.status = 'S' then 'S'
				when y.expiry_date > CURRENT then 'A'
			else 'T'
			end as status,
			NVL(b.potential_payout,'0.00') potential_payout,
			NVL(b.max_bet,'-') max_bet,
			case when a.owner = 'Y' then
				'Y'
			else
				'N'
			end as hedged,
			b.leg_type,
			b.source,
			nvl(call_user.fname, "") || ' '
				|| nvl(call_user.lname, "") || '('
				|| call_user.username || ')' as tele_user,
			o.price_type,
			o.in_running,
			o.leg_no,
			o.part_no,
			o.o_num,
			o.o_den,
			o.hcap_value,
			o.leg_sort,
			ecat.category ev_category,
			ec.name ev_class_name,
			ec.ev_class_id,
			e.desc ev_name,
			e.start_time,
			e.is_off,
			et.name ev_type_name,
			et.ev_type_id,
			s.desc seln_name,
			s.ev_oc_id,
			s.fb_result,
			m.ev_oc_grp_id,
			m.type,
			m.ew_fac_num,
			m.ew_fac_den,
			m.bet_in_run,
			case
				when s.status = 'S' then 'S'
				when m.status = 'S' then 'S'
				when e.status = 'S' then 'S'
			else 'A'
			end as susp_status,
			bt.num_lines bet_type_lines,
			NVL(lg.liab_desc,'-') as liab_desc,
			NVL(lg.colour,'#000000') as liab_colour,
			NVL(lg.disp_order,'0') as liab_disp_order,
			case
				when e.start_time < current +
					[OT_CfgGet ASYNC_EV_NEAR_START_TIME_SECONDS 600] units second
			then
				1
			else
				0
			end as ev_near_start_time,
			g.group_name as cust_group,

			case
				when b.source = 'P' then 1
				when b.source = 'T' then 1
				else 2
			end as chan_priority,

			case
				when c.elite = 'Y' then 1
				else 2
			end as cust_priority
		from
			tBetAsync y,
			outer tAsyncBetOff bo,
			outer tAdminUser au,
			tBet b,
			outer (tCall ca, outer tAdminUser call_user),
			tOBet o,
			tEvOc s,
			tEv e,
			tEvMkt m,
			tEvType et,
			tEvClass ec,
			tEvCategory ecat,
			tAcct a,
			tCustomer c,
			tCustomerReg cr,
			outer (tCustGroup cg, tGroupValue g),
			tBetType bt,
			outer tbetslipbet sb,
			outer tLiabGroup lg,
			outer (tXLateCode xc, tXLateVal xv)
		where
			b.bet_id          = y.bet_id and
			y.bet_id          = bo.bet_id and
			au.user_id        = y.lock_user_id and
			b.bet_type        = bt.bet_type and
			b.bet_id          = o.bet_id and
			b.call_id         = ca.call_id and
			ca.oper_id        = call_user.user_id and
			o.ev_oc_id        = s.ev_oc_id and
			e.ev_id           = s.ev_id and
			m.ev_mkt_id       = s.ev_mkt_id and
			et.ev_type_id     = e.ev_type_id and
			ec.ev_class_id    = e.ev_class_id and
			ecat.category     = ec.category and
			b.bet_id          = sb.bet_id and
			$category_filter
			$class_filter
			$channel_filter
			$ev_type_filter
			$event_filter
			$bir_filter
			$grp_filter
			$owner_filter
			a.acct_id         = y.acct_id and
			c.cust_id         = a.cust_id and
			c.cust_id         = cr.cust_id and
			c.cust_id         = cg.cust_id and
			cg.group_value_id = g.group_value_id and
			y.park_reason     = xc.code and
			xc.code_id        = xv.code_id and
			xv.lang           = 'en' and
			lg.liab_group_id  = c.liab_group
		order by
			lg.disp_order,
			b.bet_id,
			o.leg_no,
			o.part_no
	}]

	ob_log::write DEV $sql

	# execute the query
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	# Initiate required variables
	set bet_id             -1
	set cur_bet_id         -1
	set prev_ev_start_secs -1
	array set seln [list]

	# Setup the data that will need to fetch for every leg in a bet
	set leg_cols [list \
					ev_name \
					ev_type_name \
					ev_category \
					ev_class_name \
					seln_name\
					susp_status]

	set ASYNC(nrows)   $nrows
	set ASYNC(bet_ids) [list]

	# If we have some data, populate the liability group
	# data array 'LIAB_GROUP'
	if {$nrows > 0} {
		_get_liab_priorities
	}

	set max_bet_id -1
	set unique_bet_group_ids [list]
	set unique_bet_ids [list]

	# Put any information obtained from the query into the 'ASYNC' array
	for {set i 0} {$i < $nrows} {incr i} {

		set bet_id         [db_get_col $rs $i bet_id]
		set bet_group_id   [db_get_col $rs $i bet_group_id]

		#Overridden bets must not be added to the list
		set ref_status   [db_get_col $rs $i ref_status]
		if {$ref_status == "O"} {
			continue
		}

		# Start of a new bet so attempt to get the info. on the bet itself
		if {$bet_id != $cur_bet_id} {

			#For group detail page remove the duplicate bet_ids returned by the query.
			if {$arg_grp_id != "" || 1} {
				if {[lsearch -exact $unique_bet_ids $bet_id] == -1 } {
					lappend unique_bet_ids $bet_id
					if {![info exists ASYNC($bet_group_id,count)]} {
						set ASYNC($bet_group_id,count) 1
					} else {
						incr ASYNC($bet_group_id,count)
					}
				} else {
					continue
				}
			}

			#Display only the first bet in a group. Skip this part for group detail page.
			if {$arg_grp_id == "" && $bet_group_id != ""} {
				if {[lsearch -exact $unique_bet_group_ids $bet_group_id] == -1 } {
					lappend unique_bet_group_ids $bet_group_id
				} else {
					continue
				}
			} else {
				set bet_group_id -1
			}

			if {$max_bet_id == -1} {
				set max_bet_id $bet_id
			}
			# Setup the max bet ID so the filter preference cookie will know
			# when a new bet has come in
			if {$bet_id > $max_bet_id} {
				set max_bet_id $bet_id
			}

			set cur_bet_id $bet_id

			lappend ASYNC(bet_ids) $bet_id

			# Get the core column data
			foreach bet_col [list \
						admin_username in_running ccy_code num_legs \
						num_selns num_lines bet_type park_reason liab_group \
						cust_id tele_user leg_type leg_sort source max_stake_scale \
						liab_desc liab_colour token_value acct_id \
						acct_no max_bet start_time is_off ev_near_start_time leg_no \
						part_no liab_disp_order bet_in_run susp_status \
						chan_priority cust_priority cust_group] {

				set ASYNC($bet_id,$bet_col) [escape_javascript \
												[db_get_col $rs $i $bet_col]]
			}

			set ASYNC($bet_id,bet_group_id) $bet_group_id
			set ASYNC($bet_id,source_desc) \
									$CHANNEL_MAP(code,$ASYNC($bet_id,source))



			#
			# Next, get the customised column data
			#

			# Customer name
			set ASYNC($bet_id,cust_name) {}
			set fname [db_get_col $rs $i fname]
			set lname [db_get_col $rs $i lname]

			if {$fname != {}} {
				set ASYNC($bet_id,cust_name) "$fname $lname"
			} else {
				set ASYNC($bet_id,cust_name) $lname
			}

			set ASYNC($bet_id,cust_name) \
								[escape_javascript $ASYNC($bet_id,cust_name)]
			set ASYNC($bet_id,cr_date) \
								[db_get_col $rs $i cr_date]

			# Get the bet stakes and potential payouts in the bookmakers
			# default currency
			set hedged   [db_get_col $rs $i hedged]
			set stake    [db_get_col $rs $i stake]
			if {$hedged == "Y"} {
				set stake [expr {0.0 - $stake}]
			}
			set ccy_code [db_get_col $rs $i ccy_code]
			set res_conv [ob_exchange::to_sys_amount $ccy_code $stake]
			if {[lindex $res_conv 0] == "OK"} {
				set ASYNC($bet_id,sys_stake) [lindex $res_conv 1]
			} else {
				set ASYNC($bet_id,sys_stake) $stake
			}
			set pot_payout [db_get_col $rs $i potential_payout]
			if {[string is double -strict $pot_payout]} {
				if {$hedged == "Y"} {
					set pot_payout [expr {0.0 - $pot_payout}]
				}
				set ccy_code [db_get_col $rs $i ccy_code]
				set res_conv [ob_exchange::to_sys_amount $ccy_code $pot_payout]
				if {[lindex $res_conv 0] == "OK"} {
					set ASYNC($bet_id,sys_pot_payout) [lindex $res_conv 1]
				} else {
					set ASYNC($bet_id,sys_pot_payout) $pot_payout
				}
			} else {
				set ASYNC($bet_id,sys_pot_payout)  "-"
			}

			# Initialise required variables for the leg level info. of a bet
			foreach leg_col $leg_cols {
				set ASYNC($bet_id,$leg_col) {}
			}

			set ASYNC($bet_id,hcap_value)    {}

			array set seln [list]

		}

		# Setup the start time of the earliest event

		set start_time [db_get_col $rs $i start_time]

		if {![info exists ASYNC($bet_id,first_event_time)]} {
            set ASYNC($bet_id,first_event_time) $start_time
		} else {
			set start_secs [clock scan $start_time]
			set curr_start_secs [clock scan $ASYNC($bet_id,first_event_time)]
			if {$start_secs < $curr_start_secs} {
				set ASYNC($bet_id,first_event_time) $start_time
			}
		}

		set price_type [db_get_col $rs $i price_type]
		set lp_num     [db_get_col $rs $i o_num]
		set lp_den     [db_get_col $rs $i o_den]
		set ew_fac_num [db_get_col $rs $i ew_fac_num]
		set ew_fac_den [db_get_col $rs $i ew_fac_den]

		set lp_price_str     [mk_price $lp_num $lp_den]

		if {![info exists ASYNC($bet_id,price_type)] \
										|| $ASYNC($bet_id,leg_sort) == "SC"} {

			if {$price_type != "L" && $price_type != "G"} {
				set ASYNC($bet_id,price_type) [get_price_type_desc $price_type]

				if {$ASYNC($bet_id,leg_type) == "E"} {
					append ASYNC($bet_id,price_type) \
											" @ $ew_fac_num/$ew_fac_den (E/W)"
				} elseif {$ASYNC($bet_id,leg_type) == "P"} {
					append ASYNC($bet_id,price_type) \
											" @ $ew_fac_num/$ew_fac_den"
				}
			} else {
				if {$ASYNC($bet_id,leg_type) == "E"} {
					set ASYNC($bet_id,price_type) \
								"$lp_price_str @ $ew_fac_num/$ew_fac_den (E/W)"
				} elseif {$ASYNC($bet_id,leg_type) == "P"} {
					set ASYNC($bet_id,price_type) \
								"$lp_price_str @ $ew_fac_num/$ew_fac_den"
				} else {
					set ASYNC($bet_id,price_type) "$lp_price_str"
				}
			}

		} else {
			set bet_type_lines [db_get_col $rs $i bet_type_lines]
			set num_lines      [db_get_col $rs $i num_lines]

			# For a straight accumulator, try and multiply the selection
			# odds together.
			#
			if {$bet_type_lines == 1 && $num_lines == 1} {
				if {[string is double -strict $lp_price_str] &&
					[string is double -strict $ASYNC($bet_id,price_type)]} {
					set ASYNC($bet_id,price_type) [expr {
						$ASYNC($bet_id,price_type) * $lp_price_str
					}]
				} else {
					set ASYNC($bet_id,price_type) "-"
				}
			} else {
				set ASYNC($bet_id,price_type) "-"
			}
		}

		foreach leg_col $leg_cols {
			# When a bet is not a Forecast, Reverse forecast, Combinational
			# forecast, Tricast or Combinational tricast. All the Category,
			# Class and Event names need to be included.
			if {$leg_col == "susp_status"} {

				if { [db_get_col $rs $i susp_status] == "S" || $ASYNC($bet_id,susp_status) == "S" } {
					set ASYNC($bet_id,susp_status) "S"
				} else {
					set ASYNC($bet_id,susp_status) "A"
				}
			} elseif {$leg_col == "seln_name" || \
				[lsearch [list SF RF CF TC CT] $ASYNC($bet_id,leg_sort)] == -1 } {
				if {$ASYNC($bet_id,$leg_col) == ""} {
					append ASYNC($bet_id,$leg_col) \
							[escape_javascript [db_get_col $rs $i $leg_col]]
				} else {
					append ASYNC($bet_id,$leg_col) \
							", [escape_javascript [db_get_col $rs $i $leg_col]]"
				}
			} else {
				set ASYNC($bet_id,$leg_col) \
							[escape_javascript [db_get_col $rs $i $leg_col]]
			}
		}

		if {[string equal $ASYNC($bet_id,bet_type) "SGL"]} {

			if {[set hcap_value [db_get_col $rs $i hcap_value]] != {}} {
				# Translate the selection's handicap value
				set hcap_str [ob_price::mk_hcap_str\
									[db_get_col $rs $i type]\
									[db_get_col $rs $i fb_result]\
									$hcap_value]

				append ASYNC($bet_id,hcap_value) $hcap_str
			} else {
				append ASYNC($bet_id,hcap_value) "-"
			}

		}

		#
		# Gather up data that we'll need for calculating the closest
		# risk limit for the bet
		#
		set ev_oc_id     [db_get_col $rs $i ev_oc_id]
		set ev_oc_grp_id [db_get_col $rs $i ev_oc_grp_id]
		set ev_type_id   [db_get_col $rs $i ev_type_id]
		set ev_class_id  [db_get_col $rs $i ev_class_id]

		lappend seln(ev_oc_id) $ev_oc_id

		set seln($ev_oc_id,EVOCGRP) $ev_oc_grp_id
		set seln($ev_oc_id,TYPE)    $ev_type_id
		set seln($ev_oc_id,CLASS)   $ev_class_id

		# If we've reached the end of a bet, attempt to get the customer risk
		# level that matches the bet the most.
		#
		# Also now's a good time to convert the earliest event start time to
		# the user local time
		#
		if {
			$i == [expr {$nrows - 1}] ||
			$bet_id != [db_get_col $rs [expr {$i+1}] bet_id]
		} {
			set cust_liab [_calc_cust_risk_limit\
								$ASYNC($bet_id,cust_id)\
								[array get seln]]

			if {[lindex $cust_liab 0] == 1} {
				set ASYNC($bet_id,liab_desc)       [lindex $cust_liab 1]
				set ASYNC($bet_id,liab_colour)     [lindex $cust_liab 2]
				set ASYNC($bet_id,liab_disp_order) [lindex $cust_liab 3]
				set ASYNC($bet_id,max_stake_scale) [lindex $cust_liab 4]
			}

			# If the event is about to start, this colour overwrites any other
			# liability colour
			if {$ASYNC($bet_id,ev_near_start_time)} {
				set ASYNC($bet_id,liab_colour) \
						[OT_CfgGet ASYNC_EV_NEAR_START_TIME_COLOUR #EEB422]
			}
		}
	}

	# if we have a new max bet id
	if {$max_bet_id > -1} {
		set ASYNC(max_bet_id) $max_bet_id
	}


	# Reordering array according to the specific liability groups for each
	# specific customer and selection.

	# This field defines the columns by which the array would be ordered.
	# It must content AT LEAST bet_id
	set ASYNC(ordering_cols) [list]

	# Order by channel
	if {$VIEW_PREF_COLS(source_desc) == "Y"} {
		lappend ASYNC(ordering_cols) "chan_priority"
	}

	# Order by customer group
	if {$VIEW_PREF_COLS(cust_group) == "Y"} {
		lappend ASYNC(ordering_cols) "cust_priority" "cust_group"
	}

	lappend ASYNC(ordering_cols) liab_disp_order bet_id leg_no part_no

	# Watch out, for this step to be carried out correctly, ASYNC(ordering_cols)
	# should contain the ordering columns.
	_order_bet_array

	db_close $rs

	return $ASYNC(nrows)

}



# Private procedure to send information on pending bets in a HTML
# table. What columns are sent back depends on the array that
# stores the viewing preference cookie data (VIEW_PREF_COLS)
#
proc ::ADMIN::ASYNC_BET::_send_pending_bets { {arg_grp_id ""} args } {

	global ASYNC
	variable BET_COL_DATA
	variable VIEW_PREF_COLS

	tpBufAddHdr "Content-Type" "text/html"

	if {$ASYNC(nrows) == 0} {
			tpBufWrite "<p class=\"info_no\">No bets found</p>"
	} else {

		tpBufWrite "<table><tr>"

		if {$arg_grp_id == ""} {
			tpBufWrite "<th></th>"
		}

		# If the column is mandatory/chosen to be view then
		# write out the column name
		foreach {col_name col_field col_default} $BET_COL_DATA {
			if {$VIEW_PREF_COLS($col_field) == "Y" || \
				$VIEW_PREF_COLS($col_field) == "M"} {
				tpBufWrite "<th>$col_name</th>"
			}
		}
		tpBufWrite "</tr>"

		# Write out a row for every pending bet stored in 'ASYNC'
		foreach bet_id $ASYNC(bet_ids) {
			if {$ASYNC($bet_id,susp_status) == "S" } {
				tpBufWrite "<tr style=\"color: #FFFFFF; background: #BB0000;\">"
			} elseif { ([clock scan $ASYNC($bet_id,start_time)] < [clock scan now] || \
					 $ASYNC($bet_id,is_off) == "Y") && $ASYNC($bet_id,bet_in_run) == "N" } {
				tpBufWrite "<tr style=\"color: $ASYNC($bet_id,liab_colour); background: #E9BE16;\">"
			} elseif {$ASYNC($bet_id,bet_in_run) == "Y" } {
				tpBufWrite "<tr style=\"color: #FFFFFF; background: #000055;\">"
			} else {
				tpBufWrite "<tr style=\"color: $ASYNC($bet_id,liab_colour);\">"
			}
			tpBufWrite "<td><input type=\"checkbox\" id=\"bet_$bet_id\" onclick=\"document.bet_list.toggle($bet_id);\"/></td>"

			foreach {col_name col_field col_default} $BET_COL_DATA {

				# Write out the column as long as the column is mandatory
				# or chosen to be selected.

				if {$VIEW_PREF_COLS($col_field) == "Y"} {

					set v $ASYNC($bet_id,$col_field)
					if {[string is double -strict $v]} {

						set value [comma_num_str $v]
						if {$value < 0.0} {
							tpBufWrite "<td class=negative>$value</td>"
						} else {
							tpBufWrite "<td>$value</td>"
						}

					} else {
						# Special cases
						if {$col_field == "cust_name"} {
							tpBufWrite "<td><a id=\"cust_name_$bet_id\" href='[OT_CfgGet CGI_URL]?action=ADMIN::CUST::GoCust&CustId=$ASYNC($bet_id,cust_id)'>"
							tpBufWrite $v
							tpBufWrite "</a></td>"
						} else {
							tpBufWrite "<td>$v</td>"
						}

					}
				} elseif {$VIEW_PREF_COLS($col_field) == "M"} {
					# TCL has no short circuit for the condition below,
					# so just add a 0 here for ASYNC(-1,count) which will
					# be checked below
					set ASYNC(-1,count) 1

					if { $ASYNC($bet_id,bet_group_id) == -1
						|| $ASYNC($ASYNC($bet_id,bet_group_id),count) < 2} {
						tpBufWrite "<td>"
					} else {
						tpBufWrite "<td bgcolor=\"#8AB800\">"
					}
					tpBufWrite "<a id=\"bet_time_$bet_id\" "
					tpBufWrite "href=\"javascript:popupAsyncBetDetails($bet_id, $ASYNC($bet_id,bet_group_id))\">"
					tpBufWrite "$ASYNC($bet_id,$col_field)</a></td>"
				}
			}
			tpBufWrite "<input type=\"hidden\" id=\"bet_${bet_id}_bet_group_id\" \
											value=\"$ASYNC($bet_id,bet_group_id)\">"
			tpBufWrite "<input type=\"hidden\" id=\"bet_${bet_id}_acct\" \
											value=\"$ASYNC($bet_id,acct_id)\">"
			tpBufWrite "<input type=\"hidden\" id=\"bet_${bet_id}_max_bet\" \
											value=\"$ASYNC($bet_id,max_bet)\">"
			tpBufWrite "<input type=\"hidden\" id=\"bet_${bet_id}_source\" \
											value=\"$ASYNC($bet_id,source)\">"
			tpBufWrite "</tr>"
		}

		tpBufWrite "</table>"
	}

}



# Private procedure to send an error back
#
# msg - the error message
#
proc ::ADMIN::ASYNC_BET::_err_send {msg} {

	variable VIEW_PREF_COLS

	# Filter out any "'" generated from TCL errors as that messes
	# up the HTML
	regsub -all {\'} $msg {} msg

	tpBufAddHdr "Content-Type" "text/html"
	tpBufWrite "<p class=\"info_no\">Error : $msg</p>"

}



# Private procedure to bind up time & refresh rate information
#
#
proc ::ADMIN::ASYNC_BET::_bind_time {} {

	global USERNAME
	variable DEFAULT_REFRESH_RATE
	variable MIN_REFRESH_RATE

	set date_list [split [get_current_db_time] " "]

	foreach {year mon date} [split [lindex $date_list 0] "-"] {}
	foreach {hour min sec} [split [lindex $date_list 1] ":"] {}

	foreach v {year mon date hour min sec} {
		set $v [string trimleft [set $v] "0"]
		if {[set $v] == ""} {
			set $v "0"
		}
		tpBindString curr_$v [set $v]
	}

	tpBindString refresh_rate     $DEFAULT_REFRESH_RATE
	tpBindString min_refresh_rate $MIN_REFRESH_RATE

}



#
# Retrieve data from the Bet Interceptor View Preferences
# cookie.Note that the order of the cookie parameters is important
# as it dictates which columns we will display for the given
# bet(s).
#
proc ::ADMIN::ASYNC_BET::_prep_view_pref_cookie {} {

	variable VIEW_PREF_COOKIE_NAME
	variable VIEW_PREF_COLS
	variable BET_COL_DATA
	variable cookie_expires

	set cookie [get_cookie $VIEW_PREF_COOKIE_NAME]
	set params [split $cookie "|"]
	set len    [llength $params]

	# Omit any mandatory values from the columns length
	set num_cols [expr {([llength $BET_COL_DATA] / 3) - 1}]

	if {$len != $num_cols && $len != "0"} {
		ob::log::write ERROR "Incorrect number of view preference cookie \
				parameters: $len, num_cols: $num_cols"
		set len 0
	}

	# Bet Interceptor View Preference Cookie exists?
	if {$len > 0} {
		set j 0

		# Set up 'VIEW_PREF_COLS' array from the values retrieved
		# from the cookie. Ignore however mandatory values since
		# the cookie has no control of the display on those column
		# types (e.g. bet creation date)
		foreach {col_name col_field col_default} $BET_COL_DATA {

			if {$col_default != "M"} {
				set VIEW_PREF_COLS($col_field) [lindex $params $j]
				incr j
			} else {
				set VIEW_PREF_COLS($col_field) $col_default
			}
		}
	} else {

		# Setup a View Preferences cookie by setting the
		# columns according to their default display
		set params [list]

		foreach {col_name col_field col_default} $BET_COL_DATA {

			set VIEW_PREF_COLS($col_field) $col_default

			# ignore mandatory values since those column types are
			# not dependant on cookies (i.e. they'll always be displayed)
			if {$col_default != "M"} {
				lappend params $col_default
			}

		}

		set_cookie "$VIEW_PREF_COOKIE_NAME=[join $params "|"]; $cookie_expires"
	}

	tpBindString view_pref_len $num_cols
}



#
# Retrieve data from the Bet Interceptor Filter Options cookie.
# Note that the order of the cookie parameters is important
# as it dictates which options are chosen for filtering pending bets
#
proc ::ADMIN::ASYNC_BET::_prep_filter_options_cookie {} {

	global ASYNC
	variable FILTER_OPTIONS_COOKIE_NAME
	variable DEFAULT_REFRESH_RATE
	variable cookie_expires

	set cookie [get_cookie $FILTER_OPTIONS_COOKIE_NAME]
	set len    [llength [split $cookie "|"]]

	if {$len != 11 && $len != "0"} {
		ob::log::write ERROR "Incorrect number of filter options cookie \
													parameters: $cookie, $len"
		# Support call 45778 : we do not want this to break everything : in case
		# the number of args in the cookie is incorrect, we set it to 0 so as to
		# behave as if there was no cookie, and set a default one
		set len 0
	}

	# Bet Interceptor Filter Options Cookie exists?
	if {$len > 0} {

		# Attempt to extract the last value of the cookie (max_bet_id)
		if {![regexp {^(.*\|)(.*)$} $cookie -> filter_options max_bet_id]} {
			ob::log::write ERROR "Incorrect filter options cookie format: $cookie"
			error "Incorrect filter options cookie format: $cookie"
		}

		# If the max bet ID has changed, update the cookie to reflect that
		# a new bet has been found. The front-end code will pick up this
		# change and will optionally play a sound.
		if {[info exists ASYNC(max_bet_id)]} {

			set new_cookie "${filter_options}${ASYNC(max_bet_id)}"

			if {![string equal $cookie $new_cookie]} {
				set_cookie "$FILTER_OPTIONS_COOKIE_NAME=${new_cookie}; \
																$cookie_expires"
			}
		}

	} else {

		# Set the cookie with filter option values
		set params [list "N"\
						$DEFAULT_REFRESH_RATE\
						"N"\
						0\
						0\
						0\
						0\
						0\
						0\
						"N"\
						-1]
		set_cookie "$FILTER_OPTIONS_COOKIE_NAME=[join $params "|"]; \
																$cookie_expires"

	}

}



#
# Calculates the customers risk limit. It will loop through
# all the selections in the bet and take the liability group
# that is closest to the bet (in order of EvOCGrp, EvType and
# EVClass). The highest risk out of all of them will be used,
# if none is defined, the customer liab group will be used.
#
proc ::ADMIN::ASYNC_BET::_calc_cust_risk_limit {cust_id seln} {

	global ASYNC
	variable LIAB_GROUP

	# Get all of the customer's risk limits
	array set cust_risk_limits [_get_cust_risk_limits $cust_id]

	# Get all the selection info on the bet (list of ev_oc_ids,
	# ev_grp_ids, ev_type_ids and ev_class_ids)
	array set seln_info $seln

	set priority        -1
	set max_stake_scale  1

	# Go through each selection in the bet
	foreach seln_id $seln_info(ev_oc_id) {
		set cur_priority        -1
		set cur_max_stake_scale  1

		# Check if a risk limit is defined for the customer, starting
		# in priority of EVOCGRP, TYPE and CLASS. Jump out on the first
		# limit that has been found
		foreach level {EVOCGRP TYPE CLASS} {

			set id $seln_info($seln_id,$level)
			if {[info exists cust_risk_limits($level,$id,liab_group_id)] && \
				[info exists cust_risk_limits($level,$id,max_stake_scale)]} {
				set cur_priority \
				$LIAB_GROUP($cust_risk_limits($level,$id,liab_group_id),priority)
				set cur_max_stake_scale \
				$cust_risk_limits($level,$id,max_stake_scale)
				break
			}
		}

		# Set the priority (i.e. display order) if it is the highest one there
		if {$cur_priority > $priority} {
			set priority        $cur_priority
			set max_stake_scale $cur_max_stake_scale
		}
	}

	# If a priority has found on a 'tCustLimit' level, set the risk
	# limit to it's matching liability group description
	if {$priority != -1} {
		return [list 1 $LIAB_GROUP($priority,liab_desc) \
				$LIAB_GROUP($priority,colour) $LIAB_GROUP($priority,disp_order)\
				$max_stake_scale]
	} else {
			return [list 0 {N/A} {#000000} {0} {1.00}]
	}
}



#
# Gather the cust risk limits for a customer into an array
#
proc ::ADMIN::ASYNC_BET::_get_cust_risk_limits {cust_id} {

	global DB

	array set cust_risk_limit [list]

	set sql {
		select
			level,
			id,
			max_stake_scale,
			liab_group_id
		from
			tCustLimit
		where
			cust_id = ?
	}

	# execute the query
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set level            [db_get_col $rs $r level]
		set id               [db_get_col $rs $r id]
		set liab_group_id    [db_get_col $rs $r liab_group_id]
		set max_stake_scale  [db_get_col $rs $r max_stake_scale]

		if {$liab_group_id != ""} {
			set cust_risk_limit($level,$id,liab_group_id)   $liab_group_id
			set cust_risk_limit($level,$id,max_stake_scale) $max_stake_scale
		}
	}

	db_close $rs

	return [array get cust_risk_limit]

}


#
# Gather the liability group settings into the array 'LIAB_GROUP'
# It will be used to deterimine what the customer risk limit
# should be for the bet.
#
proc ::ADMIN::ASYNC_BET::_get_liab_priorities {} {

	global DB
	variable LIAB_GROUP

	array unset LIAB_GROUP

	set sql {
		select
			disp_order,
			liab_group_id,
			liab_desc,
			colour
		from
			tLiabGroup
		order by 1
	}

	# execute the query
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	array set liab_group [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set liab_group_id                       [db_get_col $rs $i liab_group_id]

		set LIAB_GROUP($liab_group_id,priority) $i
		set LIAB_GROUP($i,liab_group_id)        $liab_group_id
		set LIAB_GROUP($i,liab_desc)            [db_get_col $rs $i liab_desc]
		set LIAB_GROUP($i,colour)               [db_get_col $rs $i colour]
		set LIAB_GROUP($i,disp_order)           [db_get_col $rs $i disp_order]
	}

	db_close $rs
}

#
# Order the ASYNC array according to the final liability groups obtained
# per level depending upon the actual selection. This fuction just reorders
# the bet_ids field of the ASYNC array accordingly to the ordering_cols field
#
proc ::ADMIN::ASYNC_BET::_order_bet_array {} {

	global ASYNC

	if {[info exists ASYNC(ordering_cols)] && $ASYNC(ordering_cols) != {}} {
		set to_order_list [list]

		foreach bet_id $ASYNC(bet_ids) {
			set ordering_token [list]
			foreach col $ASYNC(ordering_cols) {
				if {$col == "bet_id"} {
					lappend ordering_token $bet_id
				} else {
					lappend ordering_token $ASYNC($bet_id,$col)
				}
			}
			lappend to_order_list [join $ordering_token {,}]
		}
		set ordered_list [lsort -ascii $to_order_list]

		set bet_ids [list]
		foreach ordering_token $ordered_list {
			set tokens     [split $ordering_token {,}]
			set bet_id_idx [lsearch -exact $ASYNC(ordering_cols) {bet_id}]
			lappend bet_ids [lindex $tokens $bet_id_idx]
		}
		set ASYNC(bet_ids) $bet_ids
	}
}
