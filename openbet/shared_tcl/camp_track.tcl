# $Id: camp_track.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Allows tracking of arbitary campaign actions, such as the placement of bets,
# depositing of funds. It attempts to be self-suffcient as much as possible,
# but any appserver using it should make sure that they call the req_init
# procedure during request initialisation.
#
# Configuration:
#   CAMPAIGN_TRACKING      - whether or not to track campaigns (0)
#   CAMPAIGN_COOKIE_NAME   - name of the cookie used (ob_camp_track)
#   CAMPAIGN_COOKIE_EXPIRY - expiry of cookie, blank means this session ("")
#   CAMPAIGN_REQ_ARG_NAME  - argument which overrides cookie (ext_camp_id)
#
# Procedures:
#   ob_camp_track::init               - initialisation
#   ob_camp_track::req_init           - must be called during request
#                                       initialisation
#   ob_camp_track::record_camp_action - records a customer action
#

package provide camp_track 4.5



# Dependencies
#
package require util_log 4.5
package require util_db  4.5



# Variables
#
namespace eval ob_camp_track {

	variable INIT 0
	variable CFG

	# The internal campaign id of the current request.
	#
	variable int_camp_id ""

	# The last request id, if the current request id is different, then we
	# know that we need to look up the campaign that the request has come from.
	#
	variable last_req_id -1
}



# One time initialisation
#
proc ob_camp_track::init {} {

	variable INIT
	variable CFG

	if {$INIT} {
		return
	}

	_prepare_qrys

	# get and check configuration options
	set CFG(camp_track)    [OT_CfgGetTrue CAMPAIGN_TRACKING]
	set CFG(cookie_name)   [OT_CfgGet     CAMPAIGN_COOKIE_NAME   ob_camp_track]
	set CFG(cookie_expiry) [OT_CfgGet     CAMPAIGN_COOKIE_EXPIRY            ""]
	set CFG(reg_arg_name)  [OT_CfgGet     CAMPAIGN_REQ_ARG_NAME    ext_camp_id]

	if {$CFG(camp_track)} {
		if {$CFG(cookie_name) == ""} {
			error "Config item CAMPAIGN_COOKIE_NAME blank"
		}
		# note: empty string will scan
		if {[catch {clock scan $CFG(cookie_expiry)} msg]} {
			error "Config item CAMPAIGN_COOKIE_EXPIRY unscannable: $msg"
		}
		if {$CFG(reg_arg_name) == ""} {
			error "Config item CAMPAIGN_REQ_ARG_NAME is blank"
		}
		if {[info command reqGetId] == ""} {
			error "System does not support reqGetId"
		}
	} else {
		ob_log::write INFO {ob_camp_track: Configured off}
	}

	set INIT 1
}



# Prepare queries
#
proc ob_camp_track::_prepare_qrys {} {

	# select by the external campaign id
	ob_db::store_qry ob_camp_track::sel_int_camp_id_from_ext {
		execute procedure pGetCMIntCamp(
			p_ext_camp_id = ?
		)
	}

	# select by the camp action id
	ob_db::store_qry ob_camp_track::sel_cm_ext_camp_by_camp_action_id {
		select
			int_camp_id
		from
			tCMExtCamp
		where
			camp_action_id = ?
	}

	# record campaign activity
	ob_db::store_qry ob_camp_track::ins_cm_activity {
		execute procedure pInsCMActivity (
			p_int_camp_id  = ?,
			p_cust_id      = ?,
			p_act_type_tag = ?,
			p_activity_tag = ?,
			p_tracked_id   = ?
		)
	}
}



# This must be called during request initialisation to pick up on campaign
# ids. This is especially important during the first (referring) request,
# otherwise the cookie will not get stored.
#
proc ob_camp_track::req_init {} {

	variable CFG

	_auto_reset
}



# Attempt to reset and synchronise the system with the current request. It will
# first attempt to find out if there is an argument in the request, and use
# that, otherwise look for a cookie.
#
# Firstly, it will look for int_camp_id, secondly for ext_camp_id and
# finally for camp_action_id. Note that ext_camp_id may have another name.
# If it is unable to find any of these, it will look for a cookie.
#
proc ob_camp_track::_auto_reset {} {

	variable CFG
	variable last_req_id
	variable int_camp_id

	# no need to do anything if config'd off
	if {!$CFG(camp_track)} {
		return
	}

	# same request, we don't need to do the look up again
	if {$last_req_id == [reqGetId]} {
		return
	}

	# clear the session value
	set last_req_id [reqGetId]

	# Attempt to locate the campaign from the request's arguments,
	# if we can locate it, store it as a cookie which is persistent longer
	# than the browser session. We would expect to have to do this once
	# per customer referred from a campaign, and then in the future look up
	# the cookie. However this will allow us to override a previous campaign
	# with a newer one.

	# we don't check against the DB to see if this is valid, it may not be
	set int_camp_id [reqGetArg int_camp_id]

	# normally expected to be named ext_camp_id, but you may decide that
	# ExtCampID or EXT_CAMP_ID is more to your taste
	set ext_camp_id    [reqGetArg $CFG(reg_arg_name)]
	set camp_action_id [reqGetArg camp_action_id]

	# if int_camp_id is there, just use that...
	if {$int_camp_id == "" && $ext_camp_id != ""} {

		ob_log::write DEBUG {ob_camp_track: Found ext_camp_id in req args}
		set int_camp_id [_get_int_camp_id_by_ext_camp_id $ext_camp_id]

	}

	# if can't set an int_camp_id from ext_camp_id, then check action id...
	if {$int_camp_id == "" && $camp_action_id != ""} {

		ob_log::write DEBUG \
			{ob_camp_track: Found camp_action_id in req args}
		set int_camp_id [_get_int_camp_id_by_camp_action_id $camp_action_id]
	}

	# we've found a campaign id from request arguments
	# set the cookie for a short while
	if {$int_camp_id != ""} {
		ob_log::write DEBUG \
			{ob_camp_track: Storing int_camp_id from req args in cookie}

		if {$CFG(cookie_expiry) != ""} {
			set expires [clock format [clock scan $CFG(cookie_expiry)] \
				-format {%c}]
			set_cookie $CFG(cookie_name)=$int_camp_id / $expires
		} else {
			set_cookie $CFG(cookie_name)=$int_camp_id
		}
	}


	# we've failed to find the cookie in the request, or the arguments are bad
	# so we look in the cookie, it may still be blank
	if {$int_camp_id == ""} {
		set int_camp_id [get_cookie $CFG(cookie_name)]

		if {$int_camp_id != ""} {
			ob_log::write DEBUG {ob_camp_track: Found int_camp_id in cookie}
		}
	}

	if {$int_camp_id == ""} {
		ob_log::write DEBUG {ob_camp_track: No match found for campaign id}
	}
}



# Get the internal campaign id for an external campaign.
#
#   ext_camp_id - the external campaign id
#   return      - the internal campaign id, or empty string
#
proc ob_camp_track::_get_int_camp_id_by_ext_camp_id { ext_camp_id } {

	if {$ext_camp_id == ""} {
		return ""
	}

	if {[catch {
		set rs [ob_db::exec_qry \
			ob_camp_track::sel_int_camp_id_from_ext $ext_camp_id]
	} msg]} {
		ob_log::write ERROR {ob_camp_track: Failed to get internal id: $msg}
		return ""
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set int_camp_id [db_get_coln $rs 0 0]
	}

	ob_db::rs_close $rs

	if {$nrows == 1 && $int_camp_id != 0} {
		return $int_camp_id
	} else {
		return ""
	}
}



# Get the internal id from the action id
#
#   camp_action_id - campaign action id
#   returns        - the internal campaign id, or empty string
#
proc ob_camp_track::_get_int_camp_id_by_camp_action_id { camp_action_id } {

	if {$camp_action_id == ""} {
		return ""
	}

	if {[catch {
		set rs [ob_db::exec_qry \
			ob_camp_track::sel_cm_ext_camp_by_camp_action_id $camp_action_id]
	} msg]} {
		ob_log::write ERROR {ob_camp_track: Failed to get internal id: $msg}
		return ""
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set int_camp_id [db_get_coln $rs 0 0]
	}

	ob_db::rs_close $rs

	if {$nrows == 1} {
		return $int_camp_id
	} else {
		return ""
	}
}



# Called with an action and internal campaign id and recorded it in the DB.
#
#   cust_id      - customer id
#   ext_camp_id  - the external campaign id
#   act_type_tag - action type
#   act_type_id  - action id
#   tracked_id   - id of the entity actioned, e.g. bet_id
#
proc ob_camp_track::record_camp_action {  cust_id
										  act_type_tag
										  act_type_id
										{ tracked_id "" } } {

	variable CFG
	variable int_camp_id

	_auto_reset

	# no need to do anything if config'd off
	if {!$CFG(camp_track)} {
		return
	}

	if {$int_camp_id == ""} {
		# since this may be expected in the majority of cases
		# don't want to log this at a high level
		ob_log::write DEBUG {ob_camp_track: int_camp_id blank}
		return
	}

	ob_log::write INFO {ob_camp_track: $int_camp_id $cust_id $act_type_tag \
		$act_type_id $cust_id}

	if {[catch {
		set rs [ob_db::exec_qry ob_camp_track::ins_cm_activity \
			$int_camp_id $cust_id $act_type_tag $act_type_id $tracked_id]
	} msg]} {
		ob_log::write ERROR {ob_camp_track: Failed to record action: $msg}
		return
	}

	set camp_tracking_id [db_get_coln $rs 0 0]

	ob_db::rs_close $rs

	ob_log::write INFO {ob_camp_track: Campaign activity recorded: \
		$camp_tracking_id}
}
