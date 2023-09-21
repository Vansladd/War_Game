# $Id: verification.tcl,v 1.1 2011/10/04 12:41:15 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# --------------------------------------------------------------
#
# Handles Openbet Verification Server configuration and reporting
#
# Provides facilities to create and update profile definitions. Each profile
# definition is a template for a verification profile which can be run on
# customers' details. A profile definition consists of a group of associated
# check definitions. Each check definition corresponds to a possible check
# that can be run on a system, for example a passport number check with
# ProveURU or a IP check with Geopoint.
#
# Synopsis:
#	before using any of the other procedures you will need to add this file
#	to the list of namespaces in config file
#
# Configuration:
#
#	OVS_TITLES_LIST - mandatory list of acceptable titles
#



# Dependencies
#
package require ovs_ovs
package require ovs_accounts



# Variables
#
namespace eval ADMIN::VERIFICATION {

	foreach {
		action code
	} {
		GoProfileDefList { go_profile_def_list 0 }
		GoProfileDef       go_profile_def
		NewProfileDef      new_profile_def
		DoProfileDef       do_profile_def
		GoCheckDef         go_check_def
		DoCheckDef         do_check_def
		GoSearch           go_search
		DoSearch           do_search
		GoProfile          go_profile
		DoProfile          do_profile
		GoCheck            go_check
		GoManualList     { go_profile_def_list 1 }
		GoManual           go_manual
		DoManual           do_manual
		GoCheckLog         go_check_log
		DoCountry          do_country
		DoPaymentMap       do_pmt_map
		DoProfileModel     do_prfl_model
		DoCust             do_cust
		GoReasonList       go_reason_list
		DoReason           do_reason
	} {
		asSetAct ADMIN::VERIFICATION::$action [namespace code $code]
	}

}

# --------------------------------------------------------------------------
# Option used by OB4.5 customer screens whereby left hand menu bar is created
# dynamically: offering functionality to expand/collapse sub menu option.
# Note: it is the responsibility of the customer screens to call this.
# --------------------------------------------------------------------------
#

proc ADMIN::VERIFICATION::get_menus {} {
    set menus {
		{"Verification" ovs} {
		    {1 "Profile Definitions" "$CGI_URL?action=ADMIN::VERIFICATION::GoProfileDefList" "" "" {op_allowed VrfProfileDef}}
		    {2 "Search Checks" "$CGI_URL?action=ADMIN::VERIFICATION::GoSearch" "" "" {op_allowed VrfSearch}}
		    {3 "Manual Check" "$CGI_URL?action=ADMIN::VERIFICATION::GoManualList" "" "" {op_allowed VrfManCheck}}
		    {4 "External Providers" "$CGI_URL?action=ADMIN::VERIFICATION::PROVIDER::GoProviderList" "" "" {op_allowed VrfProvider}}
		}
    }
    return $menus
}

# Displays a list of available profile definitions, either so that they can
# updated or as a selection for a manual check on a customer account.
#
#	manual  - Specifies whether the list is being loaded for a manual check
#	          or to list all profile definitions
#	cust_id - Customer ID passed through for manual checks
#
proc ADMIN::VERIFICATION::go_profile_def_list {{manual 0} {cust_id ""}} {

	global DB
	global PROFILE

	catch {unset PROFILE}

	if {$manual} {
		set where "where status = 'A'"
	} else {
		set where ""
	}

	set stmt [inf_prep_sql $DB [subst {
		select
			vrf_prfl_def_id as profile_def_id,
			decode(status, "A", "Active", "S", "Suspended") as status,
			channels,
			desc
		from
			tVrfPrflDef
		$where
		order by
			status,
			profile_def_id
	}]]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set PROFILE(count) [db_get_nrows $res]

	set fields [db_get_colnames $res]


	foreach field $fields {
		for {set r 0} {$r < $PROFILE(count)} {incr r} {
			set PROFILE($r,$field) [db_get_col $res $r $field]
		}

		tpBindVar $field PROFILE $field idx
	}

	db_close $res

	tpSetVar count $PROFILE(count)
	tpSetVar manual $manual
	tpBindString cust_id $cust_id

	asPlayFile -nocache ovs/profile_def_list.html
}



# Displays a profile definition, either specified through a parameter to the
# procedure or in the HTTP request
#
#	profile_def_id - ID of profile definition to be displayed
#
proc ADMIN::VERIFICATION::go_profile_def {{profile_def_id ""}} {

	global DB
	global ACTION
	global EXT_ACTION
	global CHECK

	catch {
		unset CHECK
		unset ACTION
	}
	if {$profile_def_id == ""} {
		set profile_def_id [reqGetArg profile_def_id]
	}

	tpSetVar new 0

	# Retrieve Profile Definition

	set stmt [inf_prep_sql $DB {
		select
			vrf_prfl_def_id as profile_def_id,
			decode(status, "A", "Active", "S", "Suspended") as status,
			cr_date,
			channels,
			desc,
			vrf_prfl_code as code,
			blurb
		from
			tVrfPrflDef
		where
			vrf_prfl_def_id = ?
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set fields [db_get_colnames $res]

	foreach col $fields {
		tpBindString $col [db_get_col $res 0 $col]
	}

	set status [expr {[db_get_col $res 0 status] == "Active"}]

	make_channel_binds [db_get_col $res 0 channels] - 0

	db_close $res

	tpSetVar status $status

	# Retrieve Countries

	set stmt [inf_prep_sql $DB {
		select
			country_code
		from
			tVrfPrflCty
		where
			vrf_prfl_def_id = ?
		and status = "A"
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set countries [list]
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		lappend countries [db_get_col $res $i "country_code"]
	}

	if {[llength $countries] == 0} {
		tpBindString countries "No countries assigned!"
	} else {
		tpBindString countries [join $countries ", "]
	}

	# Retrieve Check Definitions

	set stmt [inf_prep_sql $DB {
		select
			c.vrf_chk_def_id as check_def_id,
			c.channels as check_channels,
			c.check_no,
			t.name as check_name,
			c.status as check_status
		from
			tVrfChkDef c,
			tVrfChkType t
		where
			c.vrf_prfl_def_id = ?
		and c.vrf_chk_type = t.vrf_chk_type
		order by
			check_status,
			check_no
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set fields     [db_get_colnames $res]
	set chk_count  [db_get_nrows $res]
	set num_active $chk_count

	for {set r 0} {$r < $chk_count} {incr r} {
		foreach col $fields {
			set CHECK($r,$col) [db_get_col $res $r $col]
		}
		if {$r < $num_active && $CHECK($r,check_status) == "S"} {
			set num_active $r
		}
	}

	db_close $res

	tpSetVar chk_count  $chk_count
	tpSetVar num_active $num_active

	tpBindString num_active $num_active

	foreach field $fields {
		tpBindVar $field CHECK $field idx
	}

	# Retrieve Profile Actions

	set stmt [inf_prep_sql $DB {
		select
			vrf_prfl_act_id as action_id,
			action,
			high_score as action_score
		from
			tVrfPrflAct
		where
			vrf_prfl_def_id = ?
		order by
			3
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set act_count [db_get_nrows $res]
	set fields    [db_get_colnames $res]

	for {set r 0} {$r < $act_count} {incr r} {
		foreach field $fields {
			set ACTION($r,$field) [db_get_col $res $r $field]
		}
	}

	db_close $res

	foreach field $fields {
		tpBindVar $field ACTION $field idx
	}
	tpSetVar act_count $act_count


	# Retrieve Profile Actions Exceptions
	set stmt [inf_prep_sql $DB {
		select
			vrf_prfl_ex_id as ex_action_id,
			action as ex_action,
			score as ex_action_score
		from
			tVrfPrflEx
		where
			vrf_prfl_def_id = ?
		order by
			3
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set ex_act_count [db_get_nrows $res]
	set fields       [db_get_colnames $res]

	for {set r 0} {$r < $ex_act_count} {incr r} {
		foreach field $fields {
			set EXT_ACTION($r,$field) [db_get_col $res $r $field]
		}
	}

	db_close $res

	foreach field $fields {
		tpBindVar $field EXT_ACTION $field ex_idx
	}
	tpSetVar ex_act_count $ex_act_count

	asPlayFile -nocache ovs/profile_def.html
}



# Displays an empty profile definition
#
proc ADMIN::VERIFICATION::new_profile_def {} {

	tpSetVar new 1

	make_channel_binds "" -

	asPlayFile -nocache ovs/profile_def.html
}



#
# params : pmt_mthd (opt)  - CC, NTLR, MB, etc...
#          type     (opt)  - type associated with the payment method
#                            for CC this is (D)ebit or (C)redit.
# desc   : display the country payment mapping page to enable/disable
#          ovs checks on payment methods.
#
proc ADMIN::VERIFICATION::go_pmt_cty_map {{pmt_mthd "CC"} {type ""}} {
	# Get country codes.
	global DB
	global COUNTRY
	global PAY_MTHD

	catch {unset COUNTRY}

	set profile_def_id [reqGetArg profile_def_id]

	# If CC and type is blank default it.
	if {$pmt_mthd == "CC" && $type == ""} {
		set type "D"
	}

	# Get payment methods.
	set sql {
		select
			pay_mthd,
			desc
		from
			tPayMthd pm
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set idx 0
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		if {[db_get_col $res $i pay_mthd] != "CC"} {
			set PAY_MTHD($idx,pay_mthd) [db_get_col $res $i pay_mthd]
			set PAY_MTHD($idx,desc)     [db_get_col $res $i desc]
			incr idx
		}
	}

	set extras [list \
		"ADJ" "Manual Adjustments" \
		"CC_C" "Credit Card" \
		"CC_D" "Debit Card" \
	]

	# Add the extra ones.
	foreach {mthd desc} $extras {
		set PAY_MTHD($idx,pay_mthd) $mthd
		set PAY_MTHD($idx,desc)     $desc
		incr idx
	}

	set pay_count $idx



	db_close $res

	tpSetVar     pay_count      $pay_count
	tpBindString profile_def_id $profile_def_id

	# Bind the current payment method.
	if {[string length $type]} {
		tpBindString cur_pay_mthd ${pmt_mthd}_${type}
	} else {
		tpBindString cur_pay_mthd $pmt_mthd
	}

	# Bind
	tpBindVar pay_mthd PAY_MTHD pay_mthd    idx
	tpBindVar desc     PAY_MTHD desc        idx

	# Build where clause.
	set where {}
	if {[string length $type]} {
		append where "and p.type = '$type'"
	}

	# Get payment info for desired country.
	if {[lsearch {ADJ} $pmt_mthd] > -1} {
		# Not actually a payment method.
		set sql [subst {
			select
				c.country_name as cty_name,
				c.country_code as cty_code,
				c.status as cty_status,
				c.disporder,
				p.pay_mthd as map_pay_mthd,
				CASE
					WHEN NVL(p.pay_mthd,'') != '' THEN 'A'
					ELSE 'S'
				END as pmt_status
			from
				tCountry c,
				outer (	tVrfPmtCtyMap p )
			where
					p.country_code = c.country_code
				and p.pay_mthd    = '$pmt_mthd'
				and c.status       = 'A'
			order by
				c.disporder,
				c.country_name
		}]

	} else {
		set sql [subst {
			select
				c.country_name as cty_name,
				c.country_code as cty_code,
				c.status as cty_status,
				c.disporder,
				p.pay_mthd as map_pay_mthd,
				CASE
					WHEN NVL(p.pay_mthd,'') != '' THEN 'A'
					ELSE 'S'
				END as pmt_status
			from
				tCountry c,
				tPayMthd pm,
				outer (	tVrfPmtCtyMap p )
			where
					p.country_code = c.country_code
				and pm.pay_mthd    = '$pmt_mthd'
				and pm.pay_mthd    = p.pay_mthd
				and c.status       = 'A'
				$where
			order by
				pm.desc,
				c.disporder,
				c.country_name
		}]
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set cty_count [db_get_nrows $res]
	set fields    [db_get_colnames $res]

	# Bind all feilds.
	for {set i 0} {$i < $cty_count} {incr i} {
		foreach field $fields {
			set COUNTRY($i,$field) [db_get_col $res $i $field]
		}
	}

	db_close $res

	tpBindVar code   COUNTRY cty_code    idx
	tpBindVar name   COUNTRY cty_name    idx
	tpBindVar status COUNTRY pmt_status  idx

	tpSetVar cty_count $cty_count

	asPlayFile -nocache ovs/pmt_country_map.html
}



# Handles alterations to profile definitions, calling procedures according to
# required change
#
proc ADMIN::VERIFICATION::do_profile_def {} {

	switch [reqGetArg SubmitName] {
		"UpdProfile" {
			upd_profile_def
		}
		"AddProfile" {
			add_profile_def
		}
		"SusProfile" {
			toggle_profile_def S
		}
		"ActProfile" {
			toggle_profile_def A
		}
		"CtyProfile" {
			go_country
		}
		"UpdOrder"   {
			upd_order
		}
		"AddAction"  {
			add_action
		}
		"UpdAction"  {
			upd_action
		}
		"AddExAction"  {
			add_ex_action
		}
		"UpdExAction"  {
			upd_ex_action
		}
		"AddCheck"   {
			add_check_def
		}
		"AddBinRange"   {
			add_check_def
		}
		"PmtCtyMap"   {
			go_pmt_cty_map
		}
		"PrflModel" {
			go_prfl_model
		}
		"Back"       {
			go_profile_def_list
		}
		default {
			err_bind "Unknown request: $[reqGetArg SubmitName]"
			go_profile_def_list
		}
	}
}



# Updates profile definition
#
proc ADMIN::VERIFICATION::upd_profile_def {} {

	global DB

	tpSetVar new 0

	set sql {
		update
			tVrfPrflDef
		set
			desc = ?,
			vrf_prfl_code = ?,
			blurb = ?,
			channels = ?
		where
			vrf_prfl_def_id = ?
	}

	set channels [make_channel_str]

	foreach field [list \
		desc \
		code \
		blurb \
		profile_def_id] {
		set $field [reqGetArg $field]
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]

		inf_exec_stmt $stmt \
			$desc \
			$code \
			$blurb \
			$channels \
			$profile_def_id

		inf_close_stmt $stmt

	} msg]} {
		set text "Could not update verification profile definition"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"
	} else {
		msg_bind "Verification profile definition updated"
	}
	go_profile_def $profile_def_id
}



# Add a new profile definition
#
proc ADMIN::VERIFICATION::add_profile_def {} {

	global DB

	if {![op_allowed VrfUpdProfileDef]} {
		err_bind "Insufficient permissions"
		go_profile_def [reqGetArg profile_def_id]
		return
	}

	tpSetVar new 0

	set sql {
		insert into
			tVrfPrflDef
		(
			channels,
			desc,
			vrf_prfl_code,
			blurb
		)
		values (?, ?, ?, ?)
	}

	set channels [make_channel_str]
	set desc     [reqGetArg desc]
	set code     [reqGetArg code]
	set blurb    [reqGetArg blurb]

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]

		inf_exec_stmt $stmt \
			$channels \
			$desc \
			$code \
			$blurb

		set profile_def_id [inf_get_serial $stmt]

		inf_close_stmt $stmt

	} msg]} {
		set text "Could not create verification profile definition"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"
		new_profile_def
	} else {
		msg_bind "Verification profile definition created"
		go_profile_def $profile_def_id
	}
}



# Displays a list of available countries for a profile definition
#
#	profile_def_id - ID of profile definition
#
proc ADMIN::VERIFICATION::go_country {{profile_def_id ""}} {

	global DB
	global COUNTRY

	catch {unset COUNTRY}

	if {$profile_def_id == ""} {
		set profile_def_id [reqGetArg profile_def_id]
	}

	set sql {
		select
			c.country_name as cty_name,
			c.country_code as cty_code,
			p.country_code as prfl_code,
			decode(c.status, 'A', 1, 'S', 0) as cty_bin,
			p.status as prfl_status,
			c.disporder,
			p.grace_days
		from
			tCountry c,
			outer tVrfPrflCty p
		where
			p.country_code = c.country_code
		and p.vrf_prfl_def_id = ?
		order by
			c.disporder,
			c.country_name
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $profile_def_id]

	inf_close_stmt $stmt

	set cty_count [db_get_nrows $res]
	set fields    [db_get_colnames $res]

	for {set i 0} {$i < $cty_count} {incr i} {
		foreach field $fields {
			set COUNTRY($i,$field) [db_get_col $res $i $field]
		}
		set COUNTRY($i,prfl_check) \
			[expr {$COUNTRY($i,prfl_code) == $COUNTRY($i,cty_code)}]
	}

	db_close $res

	tpBindVar code       COUNTRY cty_code    idx
	tpBindVar name       COUNTRY cty_name    idx
	tpBindVar status     COUNTRY prfl_status idx
	tpBindVar grace_days COUNTRY grace_days  idx

	tpBindString profile_def_id $profile_def_id

	tpSetVar cty_count $cty_count

	asPlayFile -nocache ovs/country_list.html
}



# Handles alterations to countries selected for a profile definition
#
proc ADMIN::VERIFICATION::do_country {} {

	switch [reqGetArg SubmitName] {
		"UpdCountry" {
			upd_country
		}
		"Back"       {
			go_profile_def
		}
		default {
			err_bind "Unknown request: $[reqGetArg SubmitName]"
			go_profile_def
		}
	}
}



# Updates countries selected for a profile definition
# NB. This is not done in a transaction. The update is not critical and can
# affect a _lot_ of rows.
#
proc ADMIN::VERIFICATION::upd_country {} {

	global DB

	set profile_def_id [reqGetArg profile_def_id]

	set sql {
		select
			c.country_code as cty_code,
			c.country_name as cty_name,
			p.country_code as prfl_code,
			p.status as status,
			p.grace_days
		from
			tCountry c,
			outer tVrfPrflCty p
		where
			p.country_code = c.country_code
		and p.vrf_prfl_def_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $profile_def_id]

	inf_close_stmt $stmt

	set cty_count [db_get_nrows $res]

	for {set i 0} {$i < $cty_count} {incr i} {
		set code           [db_get_col $res $i cty_code]
		set name           [db_get_col $res $i cty_name]
		set old_code       [db_get_col $res $i prfl_code]
		set old_status     [db_get_col $res $i status]
		set old_grace_days [db_get_col $res $i grace_days]
		set new_code       [reqGetArg check_$code]
		set new_status     [reqGetArg status_$code]
		set new_grace_days [reqGetArg grace_$code]

		# Check if country code has been added or removed
		if {$old_code != $new_code} {
			# Old code is empty, insert new country
			if {$old_code == ""} {
				set sql {
					insert into
						tVrfPrflCty
					(
						vrf_prfl_def_id,
						country_code,
						status,
						grace_days
					)
					values (?, ?, ?, ?)
				}
				if {[catch {
					set stmt [inf_prep_sql $DB $sql]

					inf_exec_stmt $stmt \
						$profile_def_id \
						$code \
						$new_status \
						$new_grace_days

					inf_close_stmt $stmt

				} msg]} {
					OT_LogWrite 1 "ERROR - Could not add country $name: $msg"
					err_bind "Could not add country $name: $msg"
				} else {
					msg_bind "Country $name added"
				}
			# Otherwise, otherwise delete country
			} else {
				set sql {
					delete from
						tVrfPrflCty
					where
						vrf_prfl_def_id = ?
					and country_code = ?
				}

				if {[catch {
					set stmt [inf_prep_sql $DB $sql]

					inf_exec_stmt $stmt \
						$profile_def_id \
						$code

					inf_close_stmt $stmt

				} msg]} {
					set text "Could not remove country $name"
					OT_LogWrite 1 "ERROR - $text: $msg"
					err_bind "$text: $msg"
				} else {
					msg_bind "Country $code removed"
				}
			}
		# Otherwise, check the status has been changed
		} elseif {$old_status != $new_status || $new_grace_days != $old_grace_days} {
			set sql {
				update
					tVrfPrflCty
				set
					status = ?,
					grace_days = ?
				where
					vrf_prfl_def_id = ?
				and country_code = ?
			}
			if {[catch {
				set stmt [inf_prep_sql $DB $sql]

				inf_exec_stmt $stmt \
					$new_status \
					$new_grace_days \
					$profile_def_id \
					$new_code

				inf_close_stmt $stmt

			} msg]} {
				OT_LogWrite 1 "ERROR - Could not update country $name: $msg"
				err_bind "Could not update country $name: $msg"
			} else {
				msg_bind "Country $name updated"
			}
		}
	}

	db_close $res

	go_country $profile_def_id
}



#
# Handles alterations to the payment/country mapping to enable/diable
# payment method through admin.
#
proc ADMIN::VERIFICATION::do_pmt_map {} {

	switch [reqGetArg SubmitName] {
		"UpdPmtType" {
			upd_pmt_type
		}
		"UpdPmtMap" {
			upd_pmt_map
		}
		"Back"       {
			go_profile_def
		}
		default {
			err_bind "Unknown request: $[reqGetArg SubmitName]"
			go_profile_def
		}
	}
}



#
# Update the current payment type being displayed in 'go_pmt_cty_map'
#
proc ADMIN::VERIFICATION::upd_pmt_type args {
	set pay_mthd [reqGetArg payMthd]

	# Either CC_C (credit card) or CC_D (debit card) is split into:
	#   pay_method: CC
	#   type      : (C)redit or (D)ebit
	set type {}
	if {[string range $pay_mthd 0 1] == "CC"} {
		set type     [string range $pay_mthd 3 3]
		set pay_mthd [string range $pay_mthd 0 1]
	}

	go_pmt_cty_map $pay_mthd $type
}



#
# Update payment map definitions.
#
proc ADMIN::VERIFICATION::upd_pmt_map args {

	global DB

	#
	# Get all the current payment statuses.
	#
	set pay_mthd       [reqGetArg pay_mthd]
	set profile_def_id [reqGetArg profile_def_id]

	# Either CC_C (credit card) or CC_D (debit card) is split into:
	#   pay_method: CC
	#   type      : (C)redit or (D)ebit
	set type {}
	if {[string range $pay_mthd 0 1] == "CC"} {
		set type     [string range $pay_mthd 3 3]
		set pay_mthd [string range $pay_mthd 0 1]

		# Build where clause.
		append where {and type = "$type"}
	}

	# Rebind
	tpBindString profile_def_id profile_def_id

	set where {}
	if {[string length $type]} {
		set where "and p.type = '$type'"
	}

	set sql [subst {
		select
			c.country_code as cty_code,
			c.country_name as cty_name,
			p.country_code as prfl_code,
   			CASE
      			WHEN NVL(p.pay_mthd,'') != '' THEN 'A'
				ELSE "S"
			END as status
		from
			tCountry c,
			outer tVrfPmtCtyMap p
		where
			p.country_code = c.country_code
		and p.pay_mthd     = ?
		and c.status       = "A"
		$where
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pay_mthd $type]
	inf_close_stmt $stmt

	set cty_count [db_get_nrows $res]

	set is_err 0

	for {set i 0} {$i < $cty_count} {incr i} {
		set code       [db_get_col $res $i cty_code]
		set name       [db_get_col $res $i cty_name]
		set old_code   [db_get_col $res $i prfl_code]
		set old_status [db_get_col $res $i status]

		set new_code   [reqGetArg check_$code]
		set new_status [reqGetArg status_$code]

		if {$old_status != $new_status} {
			if {$new_status == "A"} {
				# If type exists insert it else don't.
				if {[string length $type]} {
					set sql {
						insert into
							tVrfPmtCtyMap
							(
								vrf_prfl_def_id,
								pay_mthd,
								country_code,
								type
							)
						values (?, ?, ?, ?)
					}
				} else {
					set sql {
						insert into
							tVrfPmtCtyMap
							(
								vrf_prfl_def_id,
								pay_mthd,
								country_code
							)
						values (?, ?, ?)
					}
				}

				if {[catch {
					set stmt [inf_prep_sql $DB $sql]

					inf_exec_stmt $stmt \
						$profile_def_id \
						$pay_mthd \
						$code \
						$type

					inf_close_stmt $stmt

				} msg]} {
					OT_LogWrite 1 "ERROR - Could not add country $name: $msg"
					err_bind "Could not add country $name: $msg"
					set is_err 1
				} else {
					msg_bind "Country $name added"
				}
			} else {

				# Filter on type only if it exists.
				set where {}
				if {[string length $type]} {
					set where "and type = '$type'"
				}

				set sql [subst {
					delete from
						tVrfPmtCtyMap
					where
						    vrf_prfl_def_id = ?
						and pay_mthd        = ?
						and country_code    = ?
						$where
				}]

				if {[catch {
					set stmt [inf_prep_sql $DB $sql]

					inf_exec_stmt $stmt \
						$profile_def_id \
						$pay_mthd \
						$code

					inf_close_stmt $stmt

				} msg]} {
					set text "Could not remove country $name"
					OT_LogWrite 1 "ERROR - $text: $msg"
					err_bind "$text: $msg"
					set is_err 1
				} else {
					msg_bind "Country $code removed"
				}
			}
		}
	}

	# Bind success if no error.
	if {!$is_err} {
		msg_bind "Updated successfully"
	}

	db_close $res

	go_pmt_cty_map $pay_mthd $type
}




# Changes state of profile definition to either active or suspended
#
#	status - Status to switch profile to ('S'uspended or 'A'ctive)
#
proc ADMIN::VERIFICATION::toggle_profile_def {status} {

	global DB

	tpSetVar new 0

	set sql {
		update
			tVrfPrflDef
		set
			status = ?
		where
			vrf_prfl_def_id = ?
	}

	set profile_def_id [reqGetArg profile_def_id]

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]

		inf_exec_stmt $stmt $status $profile_def_id

		inf_close_stmt $stmt

	} msg]} {
		set text "Could not toggle verification profile definition"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"

	} else {
		if {$status == "S"} {
			msg_bind "Verification profile definition suspended"
		} else {
			msg_bind "Verification profile definition activated"
		}
	}

	go_profile_def $profile_def_id

	return
}



# Displays a check definition specified either as a parameter to the
# procedure or the HTTP request
#
#	check_def_id - ID of check definition
#
proc ADMIN::VERIFICATION::go_check_def {{check_def_id ""}} {

	global DB
	global PROFILE

	catch {unset PROFILE}

	tpSetVar new 0

	set profile_def_id  [reqGetArg profile_def_id]

	if {$check_def_id == ""} {set check_def_id [reqGetArg check_def_id]}

	set stmt [inf_prep_sql $DB {
		select
			c.vrf_chk_def_id as check_def_id,
			decode(c.status, "A", "Active", "S", "Suspended") as status,
			c.channels as channels,
			p.channels as channel_mask,
			c.check_no,
			c.cr_date,
			t.name,
			t.vrf_chk_class as check_class,
			t.vrf_chk_type as check_type,
			t.description
		from
			tVrfChkDef c,
			tVrfPrflDef p,
			tVrfChkType t
		where
			c.vrf_chk_def_id = ?
		and c.vrf_prfl_def_id = p.vrf_prfl_def_id
		and c.vrf_chk_type = t.vrf_chk_type
		order by
			check_def_id
	}]

	set res [inf_exec_stmt $stmt $check_def_id]
	inf_close_stmt $stmt

	foreach field [db_get_colnames $res] {
		set PROFILE($field) [db_get_col $res 0 $field]
		tpBindString $field $PROFILE($field)
	}

	tpBindString profile_def_id $profile_def_id
	tpBindString check_def_id   $check_def_id

	set status [expr {[db_get_col $res 0 status] == "Active"}]

	db_close $res

	tpSetVar status      $status
	tpSetVar check_class $PROFILE(check_class)
	tpSetVar check_type  $PROFILE(check_type)

	make_channel_binds $PROFILE(channels) $PROFILE(channel_mask) 0

	switch $PROFILE(check_class) {
		URU {
			set query {
				select
					u.vrf_uru_def_id as uru_id,
					u.response_no,
					decode(u.response_type,
						"C", "Comment",
						"W", "Warning",
						"M", "Match",
						"N", "Mismatch") as response_type,
					u.score,
					u.description
				from
					tVrfURUDef u,
					tVrfChkDef c
				where
					u.vrf_chk_def_id = ?
				and u.vrf_chk_def_id = c.vrf_chk_def_id
				order by
					response_type,
					response_no
			}
		}
		IP  {
			set query {
				select
					i.vrf_ip_def_id as ip_id,
					i.country_code as country,
					i.score,
					decode(i.response_type,
						"U", "Unknown",
						"M", "Match",
						"N", "No Match") as response_type
				from
					tVrfIPDef i,
					tVrfChkDef c
				where
					i.vrf_chk_def_id = ?
				and i.vrf_chk_def_id = c.vrf_chk_def_id
				order by
					country_code,
					response_type
			}
		}
		CARD  {
			if { $PROFILE(check_type) == "OB_CARD_BIN" } {
				#Card Bin
				set query {
					select
						b.vrf_cbin_def_id as card_bin_id,
						b.vrf_chk_def_id,
						b.bin_lo          as binlo,
						b.bin_hi          as binhi,
						b.score,
						b.status          as bin_status
					from
						tVrfCardBinDef b,
						tVrfChkDef c
					where
						b.vrf_chk_def_id = ? and
						b.vrf_chk_def_id = c.vrf_chk_def_id
					order by
						status,
						bin_lo
				}
			} else {
				#Card Scheme
				set query {
					select
						i.vrf_card_def_id as card_id,
						i.scheme,
						i.score
					from
						tVrfCardDef i,
						tVrfChkDef c
					where
						i.vrf_chk_def_id = ?
					and i.vrf_chk_def_id = c.vrf_chk_def_id
					order by
						scheme
				}
			}
		}
		GEN   {
			set query {
				select
					g.vrf_gen_def_id as gen_id,
					g.response_no,
					decode(g.response_type,
						"W", "Warning",
						"M", "Match",
						"N", "Mismatch") as response_type,
					g.score,
					g.description
				from
					tVrfGenDef g,
					tVrfChkDef c
				where
					g.vrf_chk_def_id = ?
				and g.vrf_chk_def_id = c.vrf_chk_def_id
				order by
					response_type,
					response_no
			}
		}
		AUTH_PRO {
			set query {
				select
					u.vrf_auth_pro_def_id as auth_pro_id,
					u.response_no,
					decode(u.response_type,
						"C", "Comment",
						"W", "Warning",
						"M", "Match",
						"N", "Mismatch") as response_type,
					u.score,
					u.description
				from
					tVrfAUthProDef u,
					tVrfChkDef c
				where
					u.vrf_chk_def_id = ?
				and u.vrf_chk_def_id = c.vrf_chk_def_id
				order by
					response_type,
					response_no
			}
		}
		default {
			set text "Unrecognised Check Class: $PROFILE(check_class)"
			OT_LogWrite 1 "ERROR - $text"
			err_bind $text

			go_profile_def $profile_def_id

			return
		}
	}

	set stmt [inf_prep_sql $DB $query]
	set res  [inf_exec_stmt $stmt $check_def_id]
	inf_close_stmt $stmt

	set PROFILE(count) [db_get_nrows $res]
	set fields         [db_get_colnames $res]

	foreach field $fields {
		for {set r 0} {$r < $PROFILE(count)} {incr r} {
			set PROFILE($r,$field) [db_get_col $res $r $field]
		}
		tpBindVar $field PROFILE $field idx
	}

	db_close $res

	tpSetVar count $PROFILE(count)

	asPlayFile -nocache ovs/check_def.html
}



# Handles alterations to check definitions by calling the function
# corresponding to the task
#
proc ADMIN::VERIFICATION::do_check_def {} {

	switch [reqGetArg SubmitName] {
		"Back"        {go_profile_def}
		"UpdCheck"    {upd_check_def}
		"NewCheck"    {new_check_def}
		"AddBinRange" {new_bin_chk_def}
		"SusCheck"    {toggle_check_def S}
		"ActCheck"    {toggle_check_def A}
		default {
			err_bind "Unknown request: $[reqGetArg SubmitName]"
			go_profile_def
		}
	}
}



# Adds a new check definition to a profile definition
#
proc ADMIN::VERIFICATION::add_check_def {} {

	global DB
	global PROFILE

	if {![op_allowed VrfUpdProfileDef]} {
		err_bind "Insufficient permissions"
		go_profile_def [reqGetArg profile_def_id]
		return
	}

	catch {unset PROFILE}

	set profile_def_id [reqGetArg profile_def_id]

	tpSetVar new 1

	set stmt [inf_prep_sql $DB {
		select
			vrf_chk_type as type,
			name
		from
			tVrfChkType
		where
			vrf_chk_type not in (
				select
					vrf_chk_type
				from
					tVrfChkDef
				where
					vrf_prfl_def_id = ?
			)
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set PROFILE(type_count) [db_get_nrows $res]

	if {$PROFILE(type_count) == 0} {

		err_bind "No more check types available"
		go_profile_def $profile_def_id
		return
	}

	for {set r 0} {$r < $PROFILE(type_count)} {incr r} {

		set PROFILE($r,type) [db_get_col $res $r type]
		set PROFILE($r,name) [db_get_col $res $r name]
	}

	db_close $res

	set stmt [inf_prep_sql $DB {
		select
			channels as channel_mask
		from
			tVrfPrflDef
		where
			vrf_prfl_def_id = ?
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set channel_mask [db_get_col $res 0 channel_mask]

	make_channel_binds "" $channel_mask 1

	tpSetVar type_count $PROFILE(type_count)
	tpBindVar type PROFILE type idx
	tpBindVar name PROFILE name idx

	tpBindString profile_def_id $profile_def_id
	tpBindString channel_mask   $channel_mask

	asPlayFile -nocache ovs/check_def.html
}



# Updates the actions specified for a profile definition
#
proc ADMIN::VERIFICATION::upd_action {} {

	global DB

	set profile_def_id [reqGetArg profile_def_id]

	# Retrieve Profile Actions

	set stmt [inf_prep_sql $DB {
		select
			vrf_prfl_act_id as action_id,
			action,
			high_score
		from
			tVrfPrflAct
		where
			vrf_prfl_def_id = ?
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set act_count [db_get_nrows $res]

	inf_begin_tran $DB

	set del_stmt [inf_prep_sql $DB {
		delete
		from
			tVrfPrflAct
		where
			vrf_prfl_act_id = ?
	}]

	set ins_stmt [inf_prep_sql $DB {
		update
			tVrfPrflAct
		set
			action = ?,
			high_score = ?
		where
			vrf_prfl_act_id = ?
	}]

	for {set r 0} {$r < $act_count} {incr r} {
		set action_id      [db_get_col $res $r "action_id"]
		set old_action     [db_get_col $res $r "action"]
		set old_high_score [db_get_col $res $r "high_score"]

		set new_action     [reqGetArg action_$action_id]
		set new_high_score [reqGetArg high_score_$action_id]
		set delete         [reqGetArg delete_$action_id]

		if {$delete != ""} {
			if {[catch {
				inf_exec_stmt $del_stmt $action_id
			} msg]} {
				inf_close_stmt $del_stmt

				set text "Could not delete action $action_id"
				OT_LogWrite 1 "ERROR - $text: $msg"
				err_bind "$text: $msg"

				inf_rollback_tran $DB

				go_profile_def $profile_def_id

				return
			}
			msg_bind "Profile action deleted"
		} elseif {$old_action != $new_action
			   || $old_high_score != $new_high_score
		} {
			if {[catch {
				inf_exec_stmt $ins_stmt $new_action $new_high_score $action_id
			} msg]} {
				inf_close_stmt $ins_stmt

				set text "Could not update profile action $action_id"
				OT_LogWrite 1 "ERROR - $text: $msg"
				err_bind "$text: $msg"

				inf_rollback_tran $DB

				go_profile_def $profile_def_id

				return
			}
			msg_bind "Profile action updated"
		}
	}

	inf_close_stmt $ins_stmt
	inf_close_stmt $del_stmt

	db_close $res

	inf_commit_tran $DB

	go_profile_def $profile_def_id
}



# Adds a new action to a profile definition
#
proc ADMIN::VERIFICATION::add_action {} {

	global DB

	set profile_def_id [reqGetArg profile_def_id]

	set stmt [inf_prep_sql $DB {
		insert into
			tVrfPrflAct
		(
			vrf_prfl_def_id,
			action
		)
		values (?, ?)
	}]

	inf_exec_stmt $stmt $profile_def_id "N"
	inf_close_stmt $stmt

	msg_bind "Profile action created"
	go_profile_def $profile_def_id
}


#
# Updates the exception action specified for a profile definition.
#
proc ADMIN::VERIFICATION::upd_ex_action {} {

	global DB

	set profile_def_id [reqGetArg profile_def_id]

	# Retrieve Profile Actions
	set stmt [inf_prep_sql $DB {
		select
			vrf_prfl_ex_id as action_id,
			action,
			score
		from
			tVrfPrflEx
		where
			vrf_prfl_def_id = ?
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set act_count [db_get_nrows $res]

	inf_begin_tran $DB

	for {set r 0} {$r < $act_count} {incr r} {
		set action_id      [db_get_col $res $r "action_id"]
		set old_action     [db_get_col $res $r "action"]
		set old_score      [db_get_col $res $r "score"]

		set new_action     [reqGetArg action_$action_id]
		set new_score      [reqGetArg score_$action_id]
		set delete         [reqGetArg delete_$action_id]

		# Either delete or update the action.
		if {$delete != ""} {
			# Update

			if {[catch {
				set stmt [inf_prep_sql $DB {
					delete
					from
						tVrfPrflEx
					where
						vrf_prfl_ex_id = ?
				}]

				inf_exec_stmt $stmt $action_id
				inf_close_stmt $stmt
			} msg]} {
				set text "Could not delete exception $action_id"
				OT_LogWrite 1 "ERROR - $text: $msg"
				err_bind "$text: $msg"

				inf_rollback_tran $DB

				go_profile_def $profile_def_id

				return
			}
			msg_bind "Profile exception deleted"
		} elseif {$old_action != $new_action
			   || $old_score != $new_score
		} {
			# Delete
			if {[catch {
				set stmt [inf_prep_sql $DB {
					update
						tVrfPrflEx
					set
						action = ?,
						score = ?
					where
						vrf_prfl_ex_id = ?
				}]

				inf_exec_stmt $stmt $new_action $new_score $action_id
				inf_close_stmt $stmt
			} msg]} {

				set text "Could not update profile exception $action_id"
				OT_LogWrite 1 "ERROR - $text: $msg"
				err_bind "$text: $msg"

				inf_rollback_tran $DB

				go_profile_def $profile_def_id

				return
			}
			msg_bind "Profile exception updated"
		}
	}

	db_close $res

	inf_commit_tran $DB

	go_profile_def $profile_def_id
}



#
# Adds an exception action specified for a profile definition.
#
proc ADMIN::VERIFICATION::add_ex_action {} {

	global DB

	set profile_def_id [reqGetArg profile_def_id]

	set stmt [inf_prep_sql $DB {
		insert into
			tVrfPrflEx
		(
			vrf_prfl_def_id,
			action
		)
		values (?, ?)
	}]

	inf_exec_stmt $stmt $profile_def_id "N"
	inf_close_stmt $stmt

	msg_bind "Profile exception created"
	go_profile_def $profile_def_id
}



# Updates the order check definitions are executed in a profile definition
#
proc ADMIN::VERIFICATION::upd_order {} {

	global DB

	set profile_def_id [reqGetArg profile_def_id]

	set stmt [inf_prep_sql $DB {
		select
			vrf_chk_def_id as check_def_id,
			check_no
		from
			tVrfChkDef
		where
			vrf_prfl_def_id = ?
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	inf_begin_tran $DB

	set stmt [inf_prep_sql $DB {
		execute procedure pUpdVrfChkOrder (
			p_check_no = ?,
			p_vrf_chk_def_id = ?
		)
	}]

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {

		set check_def_id [db_get_col $res $r check_def_id]
		set old_check_no [db_get_col $res $r check_no]
		set new_check_no [reqGetArg check_no_$check_def_id]

		if {$old_check_no != $new_check_no} {
			if {[catch {
				inf_exec_stmt $stmt $new_check_no $check_def_id
			} msg]} {

				set text "Could not update check"
				append text " definition order $check_def_id"

				OT_LogWrite 1 "ERROR - $text: $msg"
				err_bind "$text: $msg"

				inf_rollback_tran $DB

				go_profile_def $profile_def_id

				return
			}
		}
	}

	inf_close_stmt $stmt
	inf_commit_tran $DB

	msg_bind "Check definition order updated"
	go_profile_def $profile_def_id
}



# Adds a new check definition to a profile definition
#
proc ADMIN::VERIFICATION::upd_check_def {} {

	global DB

	set check_def_id [reqGetArg check_def_id]
	set channel_mask [reqGetArg channel_mask]
	set channels     [make_channel_str]

	tpSetVar new 0

	set in_trans 0

	set sql {
		select
			c.channels,
			t.vrf_chk_class as check_class,
			t.vrf_chk_type as check_type
		from
			tVrfChkDef c,
			tVrfChkType t
		where
			c.vrf_chk_def_id = ?
		and c.vrf_chk_type = t.vrf_chk_type
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $check_def_id]

	inf_close_stmt $stmt

	set old_channels [db_get_col $res 0 channels]
	set check_class  [db_get_col $res 0 check_class]
	set check_type   [db_get_col $res 0 check_type]

	db_close $res

	if {$old_channels != $channels} {

		set sql {
			update
				tVrfChkDef
			set
				channels = ?
			where
				vrf_chk_def_id = ?
		}

		inf_begin_tran $DB

		set in_trans 1

		if {[catch {
			set stmt [inf_prep_sql $DB $sql]

			set res [inf_exec_stmt $stmt \
				$channels \
				$check_def_id]

			inf_close_stmt $stmt

			db_close $res

		} msg]} {

			set text "Could not update verification profile definition"
			OT_LogWrite 1 "ERROR - $text: $msg"
			err_bind "$text: $msg"

			inf_rollback_tran $DB

			go_check_def $check_def_id

			return
		}
	}

	switch $check_class {
		URU {

			set sql {
				select
					vrf_uru_def_id as id,
					score
				from
					tVrfURUDef
				where
					vrf_chk_def_id = ?
			}

			set sql2 {
				update
					tVrfURUDef
				set
					score = ?
				where
					vrf_uru_def_id = ?
			}
		}
		IP {

			set sql {
				select
					vrf_ip_def_id as id,
					score
				from
					tVrfIPDef
				where
					vrf_chk_def_id = ?
			}

			set sql2 {
				update
					tVrfIPDef
				set
					score = ?
				where
					vrf_ip_def_id = ?
			}
		}
		CARD {

			if { $check_type == "OB_CARD_BIN" } {
				#Card Bin
				set sql {
					select
						vrf_cbin_def_id as id,
						score
					from
						tVrfCardBinDef
					where
						vrf_chk_def_id = ?
				}

				set sql2 {
					update
						tVrfCardBinDef
					set
						score = ?,
						status = ?
					where
						vrf_cbin_def_id = ?
				}
			} else {
				#Card scheme
				set sql {
					select
						vrf_card_def_id as id,
						score
					from
						tVrfCardDef
					where
						vrf_chk_def_id = ?
				}

				set sql2 {
					update
						tVrfCardDef
					set
						score = ?
					where
						vrf_card_def_id = ?
				}
			}
		}
		GEN {

			set sql {
				select
					vrf_gen_def_id as id,
					score
				from
					tVrfGenDef
				where
					vrf_chk_def_id = ?
			}

			set sql2 {
				update
					tVrfGenDef
				set
					score = ?
				where
					vrf_gen_def_id = ?
			}
		}
		AUTH_PRO {

			set sql {
				select
					vrf_auth_pro_def_id as id,
					score
				from
					tVrfAuthProDef
				where
					vrf_chk_def_id = ?
			}

			set sql2 {
				update
					tVrfAuthProDef
				set
					score = ?
				where
					vrf_auth_pro_def_id = ?
			}
		}
		default {

			OT_LogWrite 1 "ERROR - Unknown check class: $check_class"
			err_bind "ERROR - Unknown check class: $check_class"

			if {$in_trans} {
				inf_rollback_tran $DB
			}

			go_check_def $check_def_id

			return
		}
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $check_def_id]

	inf_close_stmt $stmt

	set stmt2 [inf_prep_sql $DB $sql2]

	for {set n 0} {$n < [db_get_nrows $res]} {incr n} {

		set id [db_get_col $res $n id]
		set old_score [db_get_col $res $n score]
		set new_score [reqGetArg score_$id]
		set status [reqGetArg status_$id]

		if { ($old_score != $new_score) || ($status != "") } {

			if {!$in_trans} {
				inf_begin_tran $DB
				set in_trans 1
			}

			if {[catch {
				        if { $check_type == "OB_CARD_BIN" } {
								inf_exec_stmt $stmt2 $new_score $status $id
				        } else {
								inf_exec_stmt $stmt2 $new_score $id
			           }
			} msg]} {

				inf_close_stmt $stmt2

				db_close $res

				inf_rollback_tran $DB

				OT_LogWrite 1 "ERROR - Could not update response $id: $msg"
				err_bind "Could not update response $id: $msg"

				go_check_def $check_def_id
				return

			}
		}
	}

	inf_close_stmt $stmt2

	db_close $res

	msg_bind "Verification profile definition updated"

	if {$in_trans} {
		inf_commit_tran $DB
	}

	go_check_def $check_def_id
}



# Adds a new check definition to a profile definition
#
proc ADMIN::VERIFICATION::new_bin_chk_def {} {

	global DB

	set check_def_id [reqGetArg check_def_id]
	set bin_lo [reqGetArg binlo_new]
	set bin_hi [reqGetArg binhi_new]
	set score [reqGetArg score_new]

	#Check the bin numbers to catch problems
	if { ! [regexp {^[0-9]{6}$} $bin_lo] } {
		OT_LogWrite 1 "ERROR - Could not validate submitted Bin Lo number."
		err_bind "One or more BIN range numbers are not valid numberic values."
		go_check_def $check_def_id
		return
	}

	if { ! [regexp {^[0-9]{6}$} $bin_hi] } {
		OT_LogWrite 1 "ERROR - Could not validate submitted Bin Hi number."
		err_bind "One or more BIN range numbers are not valid numberic values."
		go_check_def $check_def_id
		return
	}

	if { $bin_hi < $bin_lo } {
		OT_LogWrite 1 "ERROR - Upper BIN is less than Lower BIN number."
		err_bind "Upper BIN cannot be less than Lower BIN number."
		go_check_def $check_def_id
		return
	}

	#Check to see if there are any overlapping BIN ranges
	set stmt [inf_prep_sql $DB {
		select
			vrf_chk_def_id,
			bin_lo,
			bin_hi,
			score
		from
			tVrfCardBinDef
		where
			vrf_chk_def_id = ? AND
			status = 'A' AND
			(( bin_hi >= ? AND
			bin_lo <= ? ) OR
			( bin_hi >= ? AND
			bin_lo <= ? ))

	}]

	set stmt2 [inf_prep_sql $DB {
		insert into
			tVrfCardBinDef
		(
			vrf_chk_def_id,
			bin_lo,
			bin_hi,
			score
		)
		values (?, ?, ?, ?)
	}]

	set res [inf_exec_stmt $stmt $check_def_id $bin_lo $bin_lo $bin_hi $bin_hi]


	set temp [db_get_nrows $res]

	if {[db_get_nrows $res] > 0} {
		#Existing BIN Found
		OT_LogWrite 1 "ERROR - Existing Active BIN range already covers all or part of new range."
		err_bind "Existing Active BIN range already covers all or part of new range."
		inf_close_stmt $stmt
		go_check_def $check_def_id
		return
	}
	inf_close_stmt $stmt

	#Insert the new bin range
	inf_exec_stmt $stmt2 $check_def_id $bin_lo $bin_hi $score
	inf_close_stmt $stmt2

	msg_bind "Bin Range Added"

	go_check_def $check_def_id

}



# Adds a new check definition to a profile definition
#
proc ADMIN::VERIFICATION::new_check_def {} {

	global DB

	tpSetVar new 0

	foreach field {
		profile_def_id
		type
	} {
		set $field [reqGetArg $field]
	}

	# Retrieve the next available check number
	set stmt [inf_prep_sql $DB {
		select first 1
			check_no
		from
			tVrfChkDef
		where
			vrf_prfl_def_id = ?
		order by
			check_no desc
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 0} {
		ob::log::write DEV {No checks found}
		set check_no 1
	} else {
		ob::log::write DEV {Highest check found is [db_get_col $res 0 check_no]}
		set check_no [expr {[db_get_col $res 0 check_no] + 1}]
	}

	# Retrieve the check class
	set stmt [inf_prep_sql $DB {
		select
			vrf_chk_class
		from
			tVrfChkType
		where
			vrf_chk_type = ?
	}]

	set res [inf_exec_stmt $stmt $type]
	inf_close_stmt $stmt

	set class [db_get_col $res 0 vrf_chk_class]

	db_close $res

	set sql {
		execute procedure pInsVrfChkDef
			(
			p_vrf_prfl_def_id = ?,
			p_vrf_chk_type    = ?,
			p_channels        = ?,
			p_check_no        = ?
			)
	}

	set channels [make_channel_str]

	inf_begin_tran $DB

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]

		set res [inf_exec_stmt $stmt \
			$profile_def_id \
			$type \
			$channels \
			$check_no]

		set check_def_id [db_get_coln $res 0 0]

		inf_close_stmt $stmt

		db_close $res

	} msg]} {

		set text "Could not create verification profile definition"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"

		inf_rollback_tran $DB

		go_profile_def $profile_def_id

		return
	}

	# We need to insert the check responses for URU and generic class checks as
	# there are so many.

	if {$class == "URU" || $class == "GEN"} {

		if {$class == "URU"} {
			set sql {
				execute procedure pInsVrfURUDef
					(
					p_vrf_chk_def_id = ?,
					p_response_no    = ?,
					p_response_type  = ?,
					p_description    = ?
					)
			}

			set sql2 {
				select
					response_no,
					response_type,
					description
				from
					tVrfURUType
				where
					vrf_chk_type = ?
			}
		} else {
			set sql {
				execute procedure pInsVrfGenDef
					(
					p_vrf_chk_def_id = ?,
					p_response_no    = ?,
					p_response_type  = ?,
					p_description    = ?
					)
			}

			set sql2 {
				select
					response_no,
					response_type,
					description
				from
					tVrfGenType
				where
					vrf_chk_type = ?
			}
		}
		set stmt  [inf_prep_sql $DB $sql]
		set stmt2 [inf_prep_sql $DB $sql2]
		set res   [inf_exec_stmt $stmt2 $type]

		set fields [db_get_colnames $res]

		for {set row 0} {$row < [db_get_nrows $res]} {incr row} {

			foreach col $fields {
				set $col [db_get_col $res $row $col]
			}

			if {[catch {

				inf_exec_stmt $stmt \
					$check_def_id \
					$response_no \
					$response_type \
					$description

			} msg]} {
				set text "Could not create verification check definition"
				append text " response $response_no $response_type"
				OT_LogWrite 1 "ERROR - $text: $msg"
				err_bind "$text: $msg"

				inf_rollback_tran $DB

				go_profile_def $profile_id

				return
			}
		}
		db_close $res
		inf_close_stmt $stmt2
		inf_close_stmt $stmt
	}

	inf_commit_tran $DB

	msg_bind "Verification check definition created"

	go_check_def $check_def_id
}



# Changes state of check definition to either active or suspended
#
#	status - 'S'uspended or 'A'ctive
#
proc ADMIN::VERIFICATION::toggle_check_def {status} {

	global DB

	tpSetVar new 0

	set sql {
		update
			tVrfChkDef
		set
			status = ?
		where
			vrf_chk_def_id = ?
	}

	set check_def_id [reqGetArg check_def_id]

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]

		set res [inf_exec_stmt $stmt $status $check_def_id]

		inf_close_stmt $stmt

		db_close $res

	} msg]} {

		set text "Could not toggle verification check definition"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"

		go_check_def $check_def_id

		return
	} else {
		if {$status == "S"} {
			msg_bind "Verification check definition suspended"
		} else {
			msg_bind "Verification check definition activated"
		}
	}

	go_check_def $check_def_id
}



# Displays dialogue for searching through completed verification profiles
#
proc ADMIN::VERIFICATION::go_search {} {

	global DB
	global PROFILE

	catch {unset PROFILE}

	set stmt [inf_prep_sql $DB {
		select
			vrf_prfl_def_id as id,
			desc
		from
			tVrfPrflDef
		order by
			id
	}]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set PROFILE(count) [db_get_nrows $res]

	for {set r 0} {$r < $PROFILE(count)} {incr r} {

		set PROFILE($r,id)   [db_get_col $res $r id]
		set PROFILE($r,desc) [db_get_col $res $r desc]
	}

	db_close $res

	tpSetVar count $PROFILE(count)

	tpBindVar desc PROFILE desc idx
	tpBindVar id   PROFILE id   idx

	# If we have a cust_id the prepop the acct_no on the search screen.
	if {[reqGetArg CustId] != ""} {
		set stmt [inf_prep_sql $DB {
			select
				acct_no
			from
				tCustomer
			where
				cust_id = ?
		}]

		set res [inf_exec_stmt $stmt [reqGetArg CustId]]
		inf_close_stmt $stmt

		tpBindString acct_no [db_get_col $res 0 acct_no]

		db_close $res
	}

	asPlayFile -nocache ovs/search.html
}



# Returns a list of completed verification profiles matching the search
# criteria
#
#	status - 'S'uspended or 'A'ctive
#
proc ADMIN::VERIFICATION::do_search {} {

	global DB
	global PROFILE
	global CHARSET

	catch {unset PROFILE}

	foreach {Y M D} [split [clock format [clock seconds] -format %Y-%m-%d] -] {
		break
	}

	set from       ""
	set where      ""
	set date_range [reqGetArg date_range]

	# Either query based on the to/from date, or query based on the date_range (today, yesterday etc..)
	set from_date [string trim [reqGetArg from_date]]
	set to_date   [string trim [reqGetArg to_date]]
	if {$from_date != "" && $to_date != ""} {
		set date_lo "$from_date 00:00:00"
		set date_hi "$to_date 23:59:59"
		append where "and p.cr_date between '$date_lo' and '$date_hi'"
	} elseif {$date_range != ""} {

		set date_hi "$Y-$M-$D 23:59:59"
		switch $date_range {
			TD { # Today
				set date_lo "$Y-$M-$D 00:00:00"
			}
			YD { # Yesterday
				set date_lo "[date_days_ago $Y $M $D 1] 00:00:00"
				set date_hi "[date_days_ago $Y $M $D 1] 23:59:59"
			}
			L3 { # Last 3 days
				set date_lo "[date_days_ago $Y $M $D 3] 00:00:00"
			}
			L7 { # Last 7 days
				set date_lo "[date_days_ago $Y $M $D 7] 00:00:00"
			}
			CM { # Current Month
				set date_lo "$Y-$M-01 00:00:00"
			}
		}

		append where "and p.cr_date between '$date_lo' and '$date_hi'"
	}

	set status [reqGetArg status]

	switch $status {
		P { # Parked
			append from  "tVrfPrflPark pk,"
			append where " and p.vrf_prfl_id = pk.vrf_prfl_id"
		}
		C { # Confirmed
			append where " and p.vrf_prfl_id not in"
			append where " (select vrf_prfl_id from tVrfPrflPark)"
		}
	}

	set profile_def [reqGetArg profile_def_id]
	if {$profile_def != ""} {
		append where " and p.vrf_prfl_def_id = $profile_def"
	}

	set acct_no [reqGetArg acct_no]
	if {$acct_no != ""} {
		append where " and c.acct_no = '$acct_no'"
	}

	foreach field {date_range profile_def status} {
		tpBindString $field [set $field]
	}

	set sql [subst {
		select distinct
			p.vrf_prfl_id as profile_id,
			p.vrf_prfl_def_id profile_def_id,
			p.cr_date,
			d.desc,
			c.username,
			p.cust_id,
			decode(p.check_type,
				"A", "Automatic",
				"M", "Manual") as check_type,
			decode(p.action,
				"P", "Pending admin/customer user action",
				"S", "Suspended",
				"A", "Activated",
				"N", "Nothing") as action,
			p.user_id,
			u.uru_reference
		from
			tVrfPrfl p,
			tVrfPrflDef d,
			$from
			tCustomer c,
			tVrfChk v,
			outer tVrfURUChk u
		where
			p.cust_id = c.cust_id
			and v.vrf_prfl_id = p.vrf_prfl_id
			and u.vrf_check_id = v.vrf_check_id
			and p.vrf_prfl_def_id = d.vrf_prfl_def_id
			$where
		order by
			p.cr_date,
			p.vrf_prfl_id
	}]

	set stmt [inf_prep_sql $DB $sql]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set PROFILE(count) [db_get_nrows $res]

	tpSetVar count $PROFILE(count)

	foreach col [db_get_colnames $res] {

		for {set r 0} {$r < $PROFILE(count)} {incr r} {
			set PROFILE($r,$col) [db_get_col $res $r $col]
		}
		tpBindVar $col PROFILE $col idx
	}

	GC::mark PROFILE

	db_close $res

	if {[OT_CfgGet FUNC_OVS_AGE_VRF_CSV_RPT 0]} {

		tpBindString csv_date_range $date_range
		tpBindString csv_status $status
		tpBindString csv_profile_def $profile_def

		# these variables determine which columns to display in the report
		if {[reqGetArg col_1] == "Y"} {
			tpSetVar disp_profile 1
		}
		if {[reqGetArg col_2] == "Y"} {
			tpSetVar disp_profile_def 1
		}
		if {[reqGetArg col_3] == "Y"} {
			tpSetVar disp_date 1
		}
		if {[reqGetArg col_4] == "Y"} {
			tpSetVar disp_customer 1
		}
		if {[reqGetArg col_5] == "Y"} {
			tpSetVar disp_check 1
		}
		if {[reqGetArg col_6] == "Y"} {
			tpSetVar disp_action 1
		}
	}

	# Display prompt for CSV report
	if {[reqGetArg print_csv] == 1} {
		tpBufAddHdr "Content-Type"  "text/csv; charset=$::CHARSET"
		asPlayFile -nocache ovs/age_vrf_report.csv
	} else {
		asPlayFile -nocache ovs/profile_list.html
	}
}



# Displays completed verification profile showing results and scores if
# available
#
#	profile_id - ID of profile
#
proc ADMIN::VERIFICATION::go_profile {{profile_id ""}} {

	global DB
	global PROFILE

	catch {unset PROFILE}

	if {$profile_id == ""} {
		set profile_id [reqGetArg profile_id]
	}

	set sql {
		select
			p.vrf_prfl_def_id profile_def_id,
			p.cr_date,
			d.desc,
			c.username,
			p.cust_id,
			decode(p.check_type,
				"A", "Automatic",
				"M", "Manual") as check_type,
			decode(p.action,
				"S", "Suspended",
				"A", "Activated",
				"N", "Nothing") as action,
			p.action_desc,
			p.user_id,
			decode(nvl(pk.vrf_prfl_id, 0), 0, 'Confirmed', 'Parked') as status
		from
			tVrfPrfl p,
			tVrfPrflDef d,
			tCustomer c,
			outer tVrfPrflPark pk
		where
			p.vrf_prfl_id = ?
		and p.cust_id = c.cust_id
		and p.vrf_prfl_def_id = d.vrf_prfl_def_id
		and p.vrf_prfl_id = pk.vrf_prfl_id}

	set stmt [inf_prep_sql $DB $sql]

	set res [inf_exec_stmt $stmt $profile_id]
	inf_close_stmt $stmt

	foreach col [db_get_colnames $res] {

		set PROFILE($col) [db_get_col $res 0 $col]
		tpBindString $col $PROFILE($col)
	}

	db_close $res

	if {$PROFILE(check_type) == "Automatic"} {
		tpSetVar check_type A
	} else {
		tpSetVar check_type M
	}

	if {$PROFILE(status) == "Parked"} {
		tpSetVar status P
	} else {
		tpSetVar status C
	}

	set stmt [inf_prep_sql $DB {
		select
			c.vrf_check_id as check_id,
			c.vrf_chk_def_id as check_def_id,
			c.cr_date as check_cr_date,
			c.check_no,
			t.name as check_name
		from
			tVrfChk c,
			tVrfChkType t
		where
			c.vrf_prfl_id = ?
		and c.vrf_chk_type = t.vrf_chk_type
		order by
			check_no
	}]

	set res [inf_exec_stmt $stmt $profile_id]
	inf_close_stmt $stmt

	set PROFILE(count) [db_get_nrows $res]

	foreach field [db_get_colnames $res] {
		for {set r 0} {$r < $PROFILE(count)} {incr r} {
			set PROFILE($r,$field) [db_get_col $res $r $field]
		}
		tpBindVar $field PROFILE $field idx
	}

	db_close $res

	tpSetVar count $PROFILE(count)

	tpBindString profile_id $profile_id

	asPlayFile -nocache ovs/profile.html
}



# Alters profile buy calling procedures according to the request
#
proc ADMIN::VERIFICATION::do_profile {} {

	switch [reqGetArg SubmitName] {
		"UpdProfile" {
			upd_profile
			go_profile
		}
		"Back"       {
			do_search
		}
		default {
			err_bind "Unknown request: $[reqGetArg SubmitName]"
			go_search
		}
	}
}



# Allows the action taken for a completed profile to be confirmed or updated
#
proc ADMIN::VERIFICATION::upd_profile {} {

	global DB

	set upd_cust_sql {
		update
			tCustomer
		set
			status = ?
		where
			cust_id = ?
	}

	set upd_prfl_sql {
		update
			tVrfPrfl
		set
			action = ?,
			action_desc = ?
		where
			vrf_prfl_id = ?
	}

	set del_prfl_sql {
		delete from
			tVrfPrflPark
		where
			vrf_prfl_id = ?
	}

	foreach field [list \
		acct_action \
		action_desc \
		profile_id \
		cust_id] {
		set $field [reqGetArg $field]
	}

	inf_begin_tran $DB

	if {[catch {
		set stmt [inf_prep_sql $DB $upd_prfl_sql]

		inf_exec_stmt $stmt $acct_action $action_desc $profile_id

		inf_close_stmt $stmt

		if {$acct_action == "S" || $acct_action == "A"} {

			set stmt [inf_prep_sql $DB $upd_cust_sql]

			inf_exec_stmt $stmt $acct_action $cust_id

			inf_close_stmt $stmt
		}

		set stmt [inf_prep_sql $DB $del_prfl_sql]

		inf_exec_stmt $stmt $profile_id

		inf_close_stmt $stmt

	} msg]} {

		inf_rollback_tran $DB

		OT_LogWrite 1 "ERROR - Could not confirm verification profile: $msg"
		err_bind "Could not confirm verification profile: $msg"
		return
	}

	inf_commit_tran $DB
	msg_bind "Verification profile confirmed"
}



# Displays completed verification check showing results and scores if
# available
#
#	profile_id - ID of profile
#	check_id   - ID of check
#
proc ADMIN::VERIFICATION::go_check {{check_id ""} {profile_id ""}} {

	global DB
	global PROFILE

	catch {unset PROFILE}

	if {$check_id == ""} {
		set check_id [reqGetArg check_id]
	}

	if {$profile_id == ""} {
		set profile_id [reqGetArg profile_id]
	}

	set stmt [inf_prep_sql $DB {
		select
			c.vrf_chk_def_id as check_def_id,
			c.cr_date as cr_date,
			c.check_no,
			c.vrf_ext_cdef_id as ext_check_def_id,
			t.name as name,
			t.vrf_chk_class as class,
			t.vrf_chk_type as type,
			cst.cust_id,
			cst.username as username,
			p.action as status
		from
			tVrfPrfl p,
			tVrfChk c,
			tVrfChkType t,
			tCustomer cst
		where
		    c.vrf_check_id = ?
		and p.vrf_prfl_id  = c.vrf_prfl_id
		and p.cust_id      = cst.cust_id
		and c.vrf_chk_type = t.vrf_chk_type
		order by
			check_no
	}]

	set res [inf_exec_stmt $stmt $check_id]
	inf_close_stmt $stmt

	foreach col [db_get_colnames $res] {
		set PROFILE($col) [db_get_col $res 0 $col]
		tpBindString $col $PROFILE($col)
	}

	db_close $res

	switch $PROFILE(class) {
		URU {
			set sql {
				select
					c.score,
					c.uru_reference,
					d.response_no,
					decode(d.response_type,
						"C", "Comment",
						"M", "Match",
						"N", "No match",
						"W", "Warning") as response_type,
					d.description
				from
					tVrfURUChk c,
					tVrfURUDef d
				where
					c.vrf_check_id = ?
				and c.vrf_uru_def_id = d.vrf_uru_def_id
			}
		}
		IP {
			set sql {
				select
					c.score,
					c.expected_ctry,
					c.ip_ctry,
					decode(d.response_type,
						"U", "Unknown",
						"M", "Match",
						"N", "No match") as response_type
				from
					tVrfIPChk c,
					tVrfIPDef d
				where
					c.vrf_check_id = ?
				and c.vrf_ip_def_id = d.vrf_ip_def_id
			}
		}
		CARD {
			if {$PROFILE(type) == "OB_CARD_BIN"} {

				set sql {
					select
						c.score,
						c.card_bin  as bin,
						c.cr_date   as date,
						d.bin_lo,
						d.bin_hi
					from
						tVrfCardBinDef d,
						tVrfCardBinChk c
					where
						c.vrf_check_id = ?
					    and c.vrf_cbin_def_id = d.vrf_cbin_def_id
				}

			} else {

				set sql {
					select
						c.score,
						d.scheme
					from
						tVrfCardChk c,
						tVrfCardDef d
					where
						c.vrf_check_id = ?
					and c.vrf_card_def_id = d.vrf_card_def_id
				}
			}
		}
		GEN {
			set sql {
				select
					c.score,
					d.response_no,
					decode(d.response_type,
						"M", "Match",
						"N", "No match",
						"W", "Warning") as response_type,
					d.description
				from
					tVrfGenChk c,
					tVrfGenDef d
				where
					c.vrf_check_id = ?
				and c.vrf_gen_def_id = d.vrf_gen_def_id
			}
		}
		AUTH_PRO {
			set sql {
				select
					c.score,
					c.resp_value,
					d.response_no,
					decode(d.response_type,
						"C", "Comment",
						"M", "Match",
						"N", "No match",
						"W", "Warning") as response_type,
					d.description
				from
					tVrfAuthProChk c,
					tVrfAuthProDef d
				where
					c.vrf_check_id = ?
				and c.vrf_auth_pro_def_id = d.vrf_auth_pro_def_id
			}
		}
		default {

			OT_LogWrite 1 "ERROR - Unknown check class: $check_class"
			err_bind "ERROR - Unknown check class: $check_class"

			if {$in_trans} {
				inf_rollback_tran $DB
			}

			go_check_def $check_id

			return
		}
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $check_id]

	inf_close_stmt $stmt

	set PROFILE(count) [db_get_nrows $res]

	if {$PROFILE(count) > 0} {
		foreach col [db_get_colnames $res] {
			for {set r 0} {$r < $PROFILE(count)} {incr r} {
				set PROFILE($r,$col) [db_get_col $res $r $col]
			}
			tpBindVar $col PROFILE $col idx
		}

		if {$PROFILE(class) == "URU"} {
			tpBindString uru_reference [db_get_col $res 0 "uru_reference"]
			tpBindString profile_id    [reqGetArg profile_id]
			tpBindString check_id      [reqGetArg check_id]
		}

		if {$PROFILE(type) == "OB_CARD_BIN"} {
			tpSetVar bin [db_get_col $res 0 "bin"]
		}

		if {$PROFILE(type) == "AUTH_PRO"} {
			tpBindString resp_value [db_get_col $res 0 "resp_value"]
		}
	}

	db_close $res

	tpSetVar count $PROFILE(count)
	tpSetVar class $PROFILE(class)
	tpSetVar type  $PROFILE(type)

	tpBindString profile_id $profile_id

	asPlayFile -nocache ovs/check.html
}



# Displays form for running a manual verification. This can be on an existing
# customer, in which case the customer's details are pre-populated in the
# form. The fields displayed for entering customer details are dependant on
# the check definitions in the profile definition.
#
#	profile_def_id - ID of profile definition
#	bind_cust      - switch whether to bind customer details to manual
#	                 verification form
#	log            - whether this is displaying the logs for a previous
#	                 verification profile
#	data           - if present, use as customer data to bind
#
proc ADMIN::VERIFICATION::go_manual {
	{profile_def_id ""}
	{bind_cust 1}
	{log 0}
	{data ""}
} {

	global DB
	global PROFILE
	global INDEX

	catch {
		unset PROFILE
		unset INDEX
	}

	if {$profile_def_id == ""} {
		set profile_def_id [reqGetArg profile_def_id]
	}

	set cust_id  [reqGetArg cust_id]

	set username [reqGetArg username]
	tpBindString username $username

	if {$bind_cust} {

		if {$data != ""} {
			# Bind up customer's details from args
			bind_results $data

		} else {

			# Bind up customer's details from database

			if {$cust_id != ""} {

				global ADDRESS

				catch {
					unset ADDRESS
				}

				set stmt [inf_prep_sql $DB {
					select
						r.title,
						r.fname         as forename,
						r.lname         as surname,
						r.title,
						r.gender,
						r.dob,
						r.addr_street_1 as building_no,
						r.addr_street_2 as street,
						r.addr_street_3 as sub_street,
						r.addr_street_4 as town,
						r.addr_city     as district,
						r.addr_postcode as postcode,
						r.telephone     as telephone_number,
						c.country_code  as country,
						c.source        as channel,
						c.username
					from
						tCustomerReg r,
						tCustomer c
					where c.cust_id = ?
					and c.cust_id = r.cust_id
				}]
				set res [inf_exec_stmt $stmt $cust_id]
				inf_close_stmt $stmt

				foreach col [list \
					title \
					forename \
					surname \
					title \
					telephone_number \
					country \
					username \
					channel] {

					tpBindString $col [db_get_col $res 0 $col]
				}

				tpSetVar gender [db_get_col $res 0 gender]

				set dob [db_get_col $res 0 dob]
				if {$dob != ""} {
					set fields [list dob_year dob_month dob_day]
					foreach $fields [split $dob "-"] {
						break
					}
					foreach field $fields {
						tpBindString $field [set $field]
					}
				}

				foreach field [list \
					building_no \
					street \
					sub_street \
					town \
					district \
					postcode] {

					set ADDRESS(0,$field) [db_get_col $res 0 $field]
					tpBindVar address_$field ADDRESS $field idx2
				}

				db_close $res

				tpBindString electric_postcode $ADDRESS(0,postcode)
				tpBindString driver_postcode   $ADDRESS(0,postcode)
			}
		}
	}
	tpSetVar new 0

	set stmt [inf_prep_sql $DB {
		select
			d.check_no,
			d.vrf_chk_type as type,
			t.vrf_chk_class as class
		from
			tVrfChkDef d,
			tVrfChkType t
		where
			d.vrf_prfl_def_id = ?
		and d.status = 'A'
		and d.vrf_chk_type = t.vrf_chk_type
		order by
			check_no
	}]

	set res [inf_exec_stmt $stmt $profile_def_id]
	inf_close_stmt $stmt

	set PROFILE(check_count) [db_get_nrows $res]
	set PROFILE(checks)      [list]
	foreach default [list \
		ip \
		card \
		address \
		drivers \
		electricity \
		passport \
		phone \
		scheme \
		URU \
		GEN \
		IP \
		CARD \
		AUTH_PRO] {tpSetVar $default 0}

	set address 0

	for {set r 0} {$r < $PROFILE(check_count)} {incr r} {
		tpSetVar [db_get_col $res $r class] 1

		switch [db_get_col $res $r type] {
			"GEO_IP_LOCATION" {
				tpSetVar ip 1
			}
			"OB_CARD_SCHEME" {
				tpSetVar scheme 1
			}
			"OB_CARD_BIN" {
				tpSetVar card_bin 1
			}
			"GENERIC_ADDRESS" {
				if {!$address} {
					set address 1
				}
			}
			"URU_UK_MORTALITY" -
			"URU_UK_RESIDENCY" -
			"URU_UK_MAX_ADDRESS" -
			"URU_UK_MIN_ADDRESS" {
				set address 4
			}
			"URU_UK_DRIVERS" {
				if {!$address} {
					set address 1
				}
				tpSetVar drivers 1
			}
			"URU_UK_ELECTRICITY" {
				if {!$address} {
					set address 1
				}
				tpSetVar electricity 1
			}
			"URU_UK_PASSPORT" {
				if {!$address} {
					set address 1
				}
				tpSetVar passport 1
			}
			"GENERIC_PHONE" -
			"URU_UK_PHONE" {
				if {!$address} {
					set address 1
				}
				tpSetVar phone 1
			}
			"URU_UK_CREDIT_DEBIT" {
				if {!$address} {
					set address 1
				}
				tpSetVar card 1
			}
			"URU_UK_DOB" {
				set address 1
			}
			"AUTH_PRO_DOB" {
				set address 1
			}
		}

		lappend PROFILE(checks) [db_get_col $res $r type]
	}

	tpSetVar address $address
	if {[info exists DATA(telephone,exdirectory)]} {
		tpSetVar telephone_exdirectory $DATA(telephone,exdirectory)
	} else {
		tpSetVar telephone_exdirectory "No"
	}

	db_close $res

	set stmt [inf_prep_sql $DB {
		select
			scheme,
			scheme_name
		from
			tCardSchemeInfo
		order by
			2
	}]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set PROFILE(scheme_count) [db_get_nrows $res]

	for {set r 0} {$r < $PROFILE(scheme_count)} {incr r} {
		foreach col [db_get_colnames $res] {
			set PROFILE($r,$col) [db_get_col $res $r $col]
		}
	}

	db_close $res

	set channel_list [join [split [reqGetArg channels] ""] "','"]

	set sql [subst {
		select
			channel_id as channel,
			desc as channel_name
		from
			tChannel
		where
			channel_id in ('$channel_list')
		order by
			2
	}]

	set stmt [inf_prep_sql $DB $sql]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set PROFILE(channel_count) [db_get_nrows $res]

	for {set r 0} {$r < $PROFILE(channel_count)} {incr r} {
		foreach col [db_get_colnames $res] {
			set PROFILE($r,$col) [db_get_col $res $r $col]
		}
	}

	db_close $res

	set titles_list [list]
	set titles_list [OT_CfgGet OVS_TITLES_LIST [list Mr Mrs Miss Dr Other]]
	set title_count [llength $titles_list]

	set PROFILE(title_count) $title_count

	for {set i 0} {$i < $PROFILE(title_count)} {incr i} {
		set PROFILE($i,title)      [lindex $titles_list $i]
		set PROFILE($i,title_name) [lindex $titles_list $i]
	}

	set stmt [inf_prep_sql $DB {
		select
			country_code as country,
			country_name,
			disporder
		from
			tCountry
		where
			status = 'A'
		order by
			3, 2
	}]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set PROFILE(country_count) [db_get_nrows $res]

	for {set r 0} {$r < $PROFILE(country_count)} {incr r} {
		set PROFILE($r,country)      [db_get_col $res $r country]
		set PROFILE($r,country_name) [db_get_col $res $r country_name]
	}

	db_close $res

	array set INDEX {"0,index" 1 "1,index" 2 "2,index" 3 "3,index" 4}

	tpBindVar index INDEX index idx2

	tpSetVar check_count $PROFILE(check_count)
	tpSetVar log         $log

	foreach field [list scheme channel title country] {
		tpBindVar ${field}_val  PROFILE $field        idx2
		tpBindVar ${field}_name PROFILE ${field}_name idx2

		tpSetVar ${field}_count $PROFILE(${field}_count)
	}

	tpBindString checks         $PROFILE(checks)
	tpBindString profile_def_id $profile_def_id
	tpBindString cust_id        $cust_id
	tpBindString channels       [reqGetArg channels]

	asPlayFile -nocache ovs/manual_check.html
}



# Submits the customer details provided for verification
#
proc ADMIN::VERIFICATION::do_manual {} {

	global USERID

	# Get an empty array to populate
	array set DATA [ob_ovs::get_empty]

	foreach element [lsort [array names DATA]] {
		set field [join [split $element ","] "_"]
		set DATA($element) [reqGetArg $field]
		ob_log::write DEBUG {DATA($element) = $DATA($element)}
	}

	set dob_validation  [ob_chk::dob $DATA(dob_year) $DATA(dob_month) $DATA(dob_day)]

	if {$dob_validation != "OB_OK"} {
		err_bind "Invalid date of birth: $dob_validation"
		go_manual $DATA(profile_def_id) 1 0 [array get DATA]
		return
	}

	set DATA(address_count) 0
	for {set i 1} {$i <= 4} {incr i} {
		if {[reqGetArg address$i] != ""} {
			incr DATA(address_count)
		}
	}

	if {[reqGetArg address1_building_number] != ""} {
		set DATA(address1,addr_street_1) "[reqGetArg address1_building_number] [reqGetArg address1_street]"
	} else {
		set DATA(address1,addr_street_1) "[reqGetArg address1_building_name], [reqGetArg address1_street]"
	}
	set DATA(address1,addr_street_2) [reqGetArg address1_sub_street]

	if {[reqGetArg ip_address1] != ""} {
		set DATA(ip,address) [join [list \
			[reqGetArg ip_address1] \
			[reqGetArg ip_address2] \
			[reqGetArg ip_address3] \
			[reqGetArg ip_address4]] "."]
	}

	if {[reqGetArg driver_number1] != ""} {
		set DATA(driver,postcode) [reqGetArg address1_postcode]
	}

	if {[reqGetArg electric_number1] != ""} {
		set DATA(electric,postcode) [reqGetArg address1_postcode]
	}

	if {[reqGetArg title] != ""} {
		set DATA(title) [reqGetArg title]
	}

	#Openbet Checks
	if {[reqGetArg card_bin] != ""} {
		set DATA(card_bin,bin) [reqGetArg card_bin]
	}

	# Boiler-plate callback function
	set DATA(callback) [OT_CfgGet OVS_QUEUE_CALLBACK "ob_ovs_accounts::callback"]

	set DATA(user_id) $USERID

	set in_tran 0
	foreach {status data} [ob_ovs::run_profile [array get DATA] $in_tran OB_MANUAL_CHECK] {
		break
	}

	if {$status != "OB_OK"} {
		switch -- $status {
			OB_NO_CHK_REQ {
				err_bind "No check required for specified country."
			}
			default {
				err_bind "Unable to run verification: $status"
			}
		}
		go_manual $DATA(profile_def_id) 1 0 [array get DATA]
		return
	}

	array set DATA $data

	bind_results $data

	tpBindString final_score $DATA(score)
	tpBindString weight      $DATA(weight)

	go_manual $DATA(profile_def_id) 0 0
}



# Displays form for running a manual verification. This can be on an existing
# customer, in which case the customer's details are pre-populated in the
# form. The fields displayed for entering customer details depend on the check
# definitions in the profile definition.
#
#	profile_def_id - ID of profile definition
#	bind_cust      - switch whether to bind customer details to manual
#	                 verification form
#	log            - whether this is displaying the logs for a previous
#	                 verification profile
#
proc ADMIN::VERIFICATION::go_check_log {} {

	set uru_reference [reqGetArg uru_reference]
	set profile_id    [reqGetArg profile_id]

	foreach {code data} [ob_ovs::get_uru_log $profile_id $uru_reference] {
		break
	}

	if {$code != "OB_OK"} {
		err_bind "Unable to retrieve log $uru_reference - $code"
		go_check [reqGetArg check_id] [reqGetArg profile_id]
		return
	}

	array set DATA $data
	bind_results $data

	tpBindString final_score $DATA(URU,score)
	tpBindString weight      [OT_CfgGet OVS_SCORE_WEIGHT 0]

	go_manual $DATA(profile_def_id) 0 1
}



# Binds results for a profile, either from searching, a manual profile or
# retrieving logs.
#
#	data - An array returned from call to ovs_ovs package
#
proc ADMIN::VERIFICATION::bind_results data {

	global DB
	global RESULT
	global ADDRESS

	catch {
		unset RESULT
		unset ADDRESS
	}

	array set DATA $data

	set results [list]
	set or_count 0

	foreach type [list URU IP CARD GEN AUTH_PRO] {
		if {[info exists DATA(override,$type)]} {
			set RESULT($or_count,or_name)  $type
			set RESULT($or_count,or_score) $DATA(override,$type)
			incr or_count
		}

		if {[info exists DATA($type)] && $DATA($type)} {
			if {$type == "URU" || $type == "GEN"} {
				set sql [subst {
					select
						response_type as resp_type,
						description as resp_message
					from
						tVrf${type}Type
					where
						response_no = ?
						and vrf_chk_type = ?
				}]
				set stmt [inf_prep_sql $DB $sql]
			} elseif {$type == "AUTH_PRO"} {
				set sql [subst {
					select
						response_type as resp_type,
						description as resp_message
					from
						tVrfAuthProType
					where
						response_no = ?
						and vrf_chk_type = ?
				}]
				set stmt [inf_prep_sql $DB $sql]
			}

			foreach check $DATA($type,checks) {
				foreach response $DATA($check,responses) {
					if {$type == "URU" || $type == "GEN" || $type == "AUTH_PRO"} {
						set res [inf_exec_stmt $stmt $response $check]
						for {set row 0} {$row < [db_get_nrows $res]} {incr row} {
							foreach col [db_get_colnames $res] {
								set $col [db_get_col $res $row $col]
							}
						}
					} elseif {$check == "OB_CARD_BIN"} {
						if { $DATA($check,$response,result) == "PASSED"} {
							#Passed
							set response $DATA(card_bin,bin)
							set resp_type    "M"
							set resp_message "PASSED: BIN NOT PRESENT IN RESTRICTED LIST"
						} else {
							set resp_type    "N"
							set resp_message "FAILED: BIN FOUND IN RESTRICTRED LIST"
						}
					} else {
						set resp_type    ""
						set resp_message ""
					}

					# We only get one response from Authenticate Pro that tells
					# us if we have a sucessful match or not showing the
					# description is pointless, show value instead.
					if {$type == "AUTH_PRO"} {
						lappend results [list \
							$response \
							$DATA($check,$response,value) \
							$DATA($check,$response,score) \
							$resp_type]
					} else {
						lappend results [list \
							$response \
							$resp_message \
							$DATA($check,$response,score) \
							$resp_type]
					}
				}
			}
		}
	}

	set i 0
	foreach result $results {
		foreach [list \
			RESULT($i,resp_code) \
			RESULT($i,resp_message) \
			RESULT($i,resp_score) \
			RESULT($i,resp_type)] $result {
			break
		}
		switch $RESULT($i,resp_type) {
			"C" {set RESULT($i,resp_colour) "blue"}
			"W" {set RESULT($i,resp_colour) "yellow"}
			"M" {set RESULT($i,resp_colour) "green"}
			"N" {set RESULT($i,resp_colour) "red"}
			default {set RESULT($i,resp_colour) "grey"}
		}
		incr i
	}

	foreach element [lsort [array names RESULT]] {
		if {$element == "provider_uname" ||
			$element == "provider_passwd"} {
			set value "XXXX"
		} else {
			set value $RESULT($element)
		}

		ob_log::write DEBUG {RESULT($element) = $value}
	}

	foreach element [lsort [array names DATA {[a-z]*}]] {
		set field [join [split $element ","] "_"]

		if {$element == "provider_uname" ||
			$element == "provider_passwd"} {
			set value "XXXX"
		} else {
			set value $DATA($element)
		}

		tpBindString $field $value
		ob_log::write DEBUG {$field = $value}
	}

	if {[info exists DATA(card,card_expiry_date)]} {
		tpBindString card_expiry_date $DATA(card,card_expiry_date)
	}

	if {[info exists DATA(card,card_number)]} {
		set card_number $DATA(card,card_number)

		#replace midrange of card number
		set card_length [string length $card_number]
		set repl "XXXXXXXXXXXXXXXXXXXX"
		set disp_0 [string range $card_number 0 5]
		set disp_1 [string range $repl 6 [expr {$card_length-5}]]
		set disp_2 [string range $card_number [expr {$card_length-4}] end]
		set card_number $disp_0$disp_1$disp_2

		tpBindString card_number $card_number
	}

	if {[info exists DATA(card,cardtype)]} {
		tpBindString card_type $DATA(card,cardtype)
	}

	for {set i 1} {$i <= $DATA(address_count)} {incr i} {
		set j [expr {$i - 1}]
		foreach addr_path [array names DATA "address${i}*"] {
			set addr_element [lindex [split $addr_path ","] 1]
			set ADDRESS($j,$addr_element) $DATA($addr_path)
		}
	}

	foreach addr_path [array names DATA "address1*"] {
		set addr_element [lindex [split $addr_path ","] 1]
		tpBindVar address_$addr_element ADDRESS $addr_element idx2
	}

	tpSetVar gender     $DATA(gender)
	tpSetVar resp_count [llength $results]
	tpSetVar or_count   $or_count

	tpBindVar or_name      RESULT or_name      idx
	tpBindVar or_score     RESULT or_score     idx
	tpBindVar resp_code    RESULT resp_code    idx
	tpBindVar resp_message RESULT resp_message idx
	tpBindVar resp_score   RESULT resp_score   idx
	tpBindVar resp_colour  RESULT resp_colour  idx
}


# Gets status and reason for a given
#  Returns
#     list of status and reason code
#     "" if no record found for that customer
proc ADMIN::VERIFICATION::get_ovs_details {cust_id check_type} {

	global DB

	set prfl_name [OT_CfgGet FUNC_OVS_${check_type}_VRF_PRFL_CODE ""]

	set sql [subst {
		select
			s.status,
			s.notes,
			r.reason_code
		from
			tVrfCustStatus s,
			outer tVrfCustReason r
		where
			    s.cust_id     = ?
			and vrf_prfl_code = ?
			and r.reason_code = s.reason_code
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt $cust_id $prfl_name]
	inf_close_stmt $stmt

	set ret ""
	if {[db_get_nrows $rs]} {
 		set ret [list \
			[db_get_col $rs 0 status] \
			[db_get_col $rs 0 reason_code] \
			[db_get_col $rs 0 notes] \
		]
	}
	db_close $rs

	return $ret
}



# Bind Age Verification details for customer page
#
#    cust_id - customer identifier
#
proc ADMIN::VERIFICATION::bind_cust { cust_id } {

	global DB
	global AGE_VER_REASON

	GC::mark AGE_VER_REASON

	foreach {status reason notes} [ADMIN::VERIFICATION::get_ovs_details $cust_id "AGE"] {
		tpBindString CustAgeVerStatus $status
		tpBindString CustAgeVerReason $reason
		tpBindString CustAgeVerNotes  $notes
	}

	# bind up reason codes
	set sql {
		select
			status,
			reason_code,
			desc
		from
			tVrfCustReason
		order by status
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt



	set num_types -1
	set sub_type_num 0

	set status {}
	set nrows [db_get_nrows $res]
	for {set i 0} {$i < $nrows} {incr i} {

		set status_i [db_get_col $res $i status]
		if {$status_i != $status} {
			set status $status_i
			incr num_types
			set sub_type_num 0

			set AGE_VER_REASON($num_types,type_id) $num_types
			set AGE_VER_REASON($num_types,type)    $status
			set AGE_VER_REASON($num_types,desc)    $status
		}

		set AGE_VER_REASON($num_types,$sub_type_num,sub_type)   [db_get_col $res $i reason_code]
		set AGE_VER_REASON($num_types,$sub_type_num,desc)   [db_get_col $res $i desc]
		set AGE_VER_REASON($num_types,num_subtypes)         [incr sub_type_num]
	}

	tpSetVar NumCustAgeVerTypes [incr num_types]

	tpBindVar CustAgeVerType         AGE_VER_REASON  type      vrf_type_idx
	tpBindVar CustAgeVerDesc         AGE_VER_REASON  desc      vrf_type_idx
	tpBindVar CustAgeVerSelc         AGE_VER_REASON  selected  vrf_type_idx
	tpBindVar CustAgeVerSubType      AGE_VER_REASON  sub_type  vrf_type_idx   vrf_subtype_idx
	tpBindVar CustAgeVerSubTypeDesc  AGE_VER_REASON  desc      vrf_type_idx   vrf_subtype_idx
	tpBindVar CustAgeVerNumSubTypes  AGE_VER_REASON  num_subtypes      vrf_type_idx

}



#  Manually Update Age Verification Details for current customer
proc ADMIN::VERIFICATION::do_cust {} {

	global DB USERNAME

	set cust_id [reqGetArg CustId]

	if {![op_allowed VrfAgeManage]} {

		OT_LogWrite 1 "User does not have permission to update AV status"

		err_bind "You do not have permission to update AV status"
		ADMIN::CUST::go_cust cust_id $cust_id
		return
	}

	# does the customer already have a row
	set sql [subst {
		execute procedure pUpdVrfCustStatus (
			p_adminuser     = ?,
			p_status        = ?,
			p_reason_code   = ?,
			p_notes         = ?,
			p_cust_id       = ?,
			p_vrf_prfl_code = ?
		);
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt \
		$USERNAME \
		[reqGetArg av_status] \
		[reqGetArg av_reason_code] \
		[reqGetArg av_notes] \
		$cust_id\
		[OT_CfgGet FUNC_OVS_AGE_VRF_PRFL_CODE ""]]

	OT_LogWrite 5 "ADMIN::VERIFICATION::do_cust Successfully update Age Verification status"
	msg_bind "Successfully updated customer Age Verification status"

	inf_close_stmt $stmt
	db_close $res

	if {[OT_CfgGet ENABLE_STRALFORS 0]} {
		# Add Stralfors flag to account to signify welcome pack generation
		set sql {
			select
				exported
			from
				tCustStralfor
			where
				cust_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $cust_id]

		set exported "N"
		if {[db_get_nrows $rs] == 1} {
			set exported [db_get_col $rs exported]
		}

		if {$exported == "N"} {
			tb_register::tb_stralfor_code $cust_id
		}

		inf_close_stmt $stmt
		db_close $rs
	}

	ADMIN::CUST::go_cust cust_id $cust_id
}



#  Display Verification Status Reasons for manual update
proc ADMIN::VERIFICATION::go_reason_list {} {

	global DB
	global AGE_VER_REASON

	# bind up reason codes
	set sql {
		select
			reason_code,
			desc,
			status
		from
			tVrfCustReason
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	for {set i 0} {$i < $nrows} {incr i} {
		set AGE_VER_REASON($i,code)   [db_get_col $res $i reason_code]
		set AGE_VER_REASON($i,desc)   [db_get_col $res $i desc]
		set AGE_VER_REASON($i,status) [db_get_col $res $i status]
	}

	db_close $res

	tpBindVar  AgeVerReasonCode   AGE_VER_REASON  code     av_idx
	tpBindVar  AgeVerDesc         AGE_VER_REASON  desc     av_idx
	tpBindVar  AgeVerStatus       AGE_VER_REASON  status   av_idx

	tpSetVar NumAVReasonRows $nrows

	asPlayFile -nocache ovs/status_reasons.html

}



#
proc ADMIN::VERIFICATION::do_reason {} {

	global DB

	switch -- [reqGetArg SubmitName] {
		add_reason {

			set sql {
				execute procedure pInsVrfCustReason (
					p_adminuser   = ?,
					p_reason_code = ?,
					p_desc        = ?,
					p_status      = ?
				);
			}

			if {[catch {
				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt \
					$::USERNAME \
					[reqGetArg reason_code] \
					[reqGetArg reason_desc] \
					[reqGetArg reason_status]]
			} msg]} {
				err_bind "An error occured: $msg"
				ADMIN::VERIFICATION::go_reason_list
				return
			}

		}
		remove_reason {

			set sql {
				execute procedure pDelVrfCustReason (
					p_adminuser   = ?,
					p_reason_code = ?
				);
			}
			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt \
				$::USERNAME \
				[reqGetArg reason_code]]

		}
		default {

			err_bind "UnKnown SubmitName: [reqGetArg SubmitName]"
			ADMIN::VERIFICATION::go_reason_list
			return

		}
	}

	OT_LogWrite 5 "ADMIN::VERIFICATION::do_reason Successfully update Age Verification Reasons"
	msg_bind "Successfully updated customer Age Verification reasons"

	inf_close_stmt $stmt
	db_close $res

	ADMIN::VERIFICATION::go_reason_list
}


# Helper function for go_prfl_model
# bind up all the pay method data
proc ADMIN::VERIFICATION::bind_pmt_mthds {} {

	global DB
	global PAY_MTHD

	# safety first!
	catch {unset PAY_MTHD}

	# Get payment methods.
	set sql {
		select
			pay_mthd,
			desc
		from
			tPayMthd pm
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set idx 0
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		if {[db_get_col $res $i pay_mthd] != "CC"} {
			set PAY_MTHD($idx,pay_mthd) [db_get_col $res $i pay_mthd]
			set PAY_MTHD($idx,desc)     [db_get_col $res $i desc]
			incr idx
		}
	}

	set extras [list \
		"ADJ" "Manual Adjustments" \
		"CC_C" "Credit Card" \
		"CC_D" "Debit Card" \
	]

	# Add the extra ones.
	foreach {mthd desc} $extras {
		set PAY_MTHD($idx,pay_mthd) $mthd
		set PAY_MTHD($idx,desc)     $desc
		incr idx
	}

	set pay_count $idx

	db_close $res

	tpSetVar     pay_count      $pay_count

	# Bind
	tpBindVar pay_mthd PAY_MTHD pay_mthd    idx
	tpBindVar desc     PAY_MTHD desc        idx

}

# unlike go_prfl_model, we should always know which pay_mthd and type we want here
# so there's no need to deal with blank/default ones
proc ADMIN::VERIFICATION::load_prfl_model {prfl_def_id pmt_mthd type} {

	global DB
	global PRFL_MODEL

	# safety first!
	catch {unset PRFL_MODEL}

	ob_log::write DEBUG {load_prfl_model $prfl_def_id $pmt_mthd $type}

	# Build where clause.
	set where {}
	if {[string length $type]} {
		append where "and p.type = '$type'"
	}

	# Get payment info for desired country.
	if {[lsearch {ADJ} $pmt_mthd] > -1} {
		set where ""
	}

	set sql [subst {
		select
			c.country_name  as cty_name,
			c.country_code  as cty_code,
			c.status        as cty_status,
			c.disporder,
			CASE WHEN p.pay_mthd != '' THEN
			-- this tells us there is no current row
				1
			ELSE
				0
			END as cty_pm_exists,
			p.pay_mthd      as model_pay_mthd,
			p.type          as model_pm_type,
			p.grace_days    as model_grace_days,
			p.action        as model_action,
			p.status        as model_status,
			p.pmt_sort      as model_pmt_sort
		from
			tCountry c,
			tPayMthd pm,
			outer (	tVrfPrflModel p )
		where
			p.country_code = c.country_code
			and pm.pay_mthd    = '$pmt_mthd'
			and pm.pay_mthd    = p.pay_mthd
			and c.status       = 'A'
			and p.vrf_prfl_def_id = $prfl_def_id
			$where
		order by
			pm.desc,
			c.disporder,
			c.country_name
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	# bind the number of countries
	set PRFL_MODEL(cty_count)  [db_get_nrows $res]

	# get the list of columns
	set PRFL_MODEL(colnames) [db_get_colnames $res]

	# Bind all cols.
	# cty_name        (tCountry.country_name)
	# cty_code        (tCountry.country_code)
	# cty_status      (tCountry.status)
	# disporder       (tCountry.disporder)
	# model_pay_mthd  (tVrfPrflModel.pay_mthd)
	# model_pm_type   (tVrfPrflModel.type)
	# model_grace     (tVrfPrflModel.grace_days)
	# model_action    (tVrfPrflModel.action)
	# model_status    (tVrfPrflModel.status)
	# model_pmt_sort  (tVrfPrflModel.pmt_sort)
	#
	for {set i 0} {$i < $PRFL_MODEL(cty_count)} {incr i} {
		foreach col $PRFL_MODEL(colnames) {
			set PRFL_MODEL($i,$col) [db_get_col $res $i $col]
		}
	}

	db_close $res

}

# binds up whatever has been loaded into PRFL_MODEL
# PRE  : load_prfl_model has been run successfully
proc ADMIN::VERIFICATION::bind_prfl_model {} {

	global PRFL_MODEL

	if {![info exists PRFL_MODEL]} {
		error "No Profile Model loaded"
	}

	tpSetVar cty_count $PRFL_MODEL(cty_count)

	for {set c 0} {$c < $PRFL_MODEL(cty_count)} {incr c} {
		foreach col $PRFL_MODEL(colnames) {
			tpBindVar $col PRFL_MODEL $col idx
		}
	}
}
#
# params : pmt_mthd (opt)  - CC, NTLR, MB, etc...
#          type     (opt)  - type associated with the payment method
#                            for CC this is (D)ebit or (C)redit.
# desc   : display the country payment mapping page to enable/disable
#          ovs checks on payment methods.
#
proc ADMIN::VERIFICATION::go_prfl_model {{pmt_mthd "CC"} {type ""}} {

	global DB
	global PAY_MTHD

	# find out which profile we're in
	set profile_def_id [reqGetArg profile_def_id]

	# bind it up
	tpBindString profile_def_id $profile_def_id

	# bind up the pay method info
	bind_pmt_mthds

	# if CC and blank type, default to D
	if {$pmt_mthd == "CC" && $type == ""} {
		set type "D"
	}

	# bind up the current pay method
	tpBindString cur_pay_mthd $pmt_mthd
	tpBindString cur_type     $type

	if {$type != ""} {
		tpBindString PayMthd ${pmt_mthd}_${type}
	} else {
		tpBindString PayMthd $pmt_mthd
	}

	ob_log::write DEBUG {PayMthd: [tpBindGet PayMthd]}

	# load the correct profile model into PRFL_MODEL
	load_prfl_model $profile_def_id $pmt_mthd $type

	# attempt to bind up the variables
	# this will error if no Profile Model was loaded
	if {[catch {bind_prfl_model} msg]} {
		ob_log::write ERROR "Failed to bind Profile Model: $msg"
	}

	asPlayFile -nocache ovs/profile_models.html

}


# proc to update all the country rows for a given pay method in tVrfPrflModel
proc ADMIN::VERIFICATION::upd_prfl_model_pmt {} {

	global DB
	global PAY_MTHD
	global PRFL_MODEL

	# set up PAY_MTHD -- this may not be necessary -- let's find out!
	bind_pmt_mthds

	set profile_def_id [reqGetArg profile_def_id]
	set pay_mthd       [reqGetArg pay_mthd]
	set type           [reqGetArg type]

	ob_log::write DEBUG {upd_prfl_model_pmt: $pay_mthd $type}
	# we know that pay_mthd could actually contain the type as well
	# eg CC_D
	# but it might not
	# eg WU
# 	set re {([^_]+)(_([^_]))*}
# 	regexp $re $pay_mthd match pm foo type
	# this will give us:
	# for CC_D :
	#    pm = "CC"  foo = "_D"  type = "D"
	# for "WU" :
	#    pm = "WU"  foo = ""   type = ""

	load_prfl_model $profile_def_id $pay_mthd $type

	# so now we have the relevant profile model data set in PRFL_MODEL
	# we can compare what we've been given in the request to what was
	# in the DB, and update where necessary

	for {set c 0} {$c < $PRFL_MODEL(cty_count)} {incr c} {

		# init the vars we need for each row:
		set code          $PRFL_MODEL($c,cty_code)

		# insert :
		set insert_cols [list \
			vrf_prfl_def_id \
			country_code \
			pay_mthd \
			type \
		]
		set insert_vals [list \
			"'$profile_def_id'" \
			"'$code'" \
			"'$pay_mthd'" \
			"'$type'" \
		]

		# update :
		set set_clause   {}
		# both :
		set where_clause [list \
			"vrf_prfl_def_id = $profile_def_id" \
			"country_code = '$code'" \
			"pay_mthd = '$pay_mthd'" \
			"type = '$type'" \
		]

		if {[reqGetArg pmt_sort_${code}] == "N"} {

			if {$PRFL_MODEL($c,cty_pm_exists)} {
				set sql [subst {
					delete from
						tVrfPrflModel
					where
						[join $where_clause { and }]
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt]

				if {[catch {db_close $res} msg]} {
					ob_log::write DEBUG {Failed to close update res for $code: $msg}
					ob_log::write DEV   {SQL that failed was: $sql}
				} else {
					msg_bind "$PRFL_MODEL($c,cty_name),$pay_mthd,$type removed successfully"
				}
			}
		} else {
			foreach col {
				status
				pmt_sort
				action
				grace_days
			} {
				# get the value submitted from the form
				set $col [reqGetArg ${col}_${code}]

				# compare this to the value from the db
				if {[set $col] != $PRFL_MODEL($c,model_${col})} {
					# it's been altered - add it to the list
					if {$PRFL_MODEL($c,cty_pm_exists)} {
						# doing an update
						lappend set_clause "$col = '[set $col]'"
					} else {
						# doing an insert
						lappend insert_cols $col
						lappend insert_vals "'[set $col]'"
					}
				}
			}

			if {[llength $set_clause] || [llength $insert_cols] > 4} {
				if {$PRFL_MODEL($c,cty_pm_exists)} {
					set sql [subst {
						update
							tVrfPrflModel
						set
							[join $set_clause {,}]
						where
							[join $where_clause { and }]
					}]
				} else {
					set sql [subst {
						insert into
							tVrfPrflModel
						([join $insert_cols {,}])
						values
						([join $insert_vals {,}])
					}]
				}

				# now actually run the SQL
				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt]

				if {[catch {db_close $res} msg]} {
					ob_log::write DEBUG {Failed to close update res for $code: $msg}
					ob_log::write DEV   {SQL that failed was: $sql}
				} else {
					msg_bind "$PRFL_MODEL($c,cty_name),$pay_mthd,$type Updated successfully"
				}
			}
		}
	}

	# do we want to just get the list of countries from tCountry,
	# or should we really be paying attention to what was played onto the page?

	# how hard could that be?

	# once we've got the list of countries, we need to iterate through them
	# and grab the appropriate information from the request, and then update
	# tVrfPrflModel

	go_prfl_model $pay_mthd $type

}


#
# Update the current payment type being displayed in 'go_prfl_model'
#
proc ADMIN::VERIFICATION::upd_pmt_type args {
	set pay_mthd [reqGetArg payMthd]

	# Either CC_C (credit card) or CC_D (debit card) is split into:
	#   pay_method: CC
	#   type      : (C)redit or (D)ebit
	set type {}
	if {[string range $pay_mthd 0 1] == "CC"} {
		set type     [string range $pay_mthd 3 3]
		set pay_mthd [string range $pay_mthd 0 1]
	}

	go_prfl_model $pay_mthd $type
}

#
# Handles alterations to the payment/country mapping to enable/diable
# payment method through admin.
#
proc ADMIN::VERIFICATION::do_prfl_model {} {

	switch [reqGetArg SubmitName] {
		"UpdPmtType" {
			upd_pmt_type
		}
		"UpdPrflModel" {
			upd_prfl_model_pmt
		}
		"Back"       {
			go_profile_def
		}
		default {
			err_bind "Unknown request: $[reqGetArg SubmitName]"
			go_profile_def
		}
	}
}
