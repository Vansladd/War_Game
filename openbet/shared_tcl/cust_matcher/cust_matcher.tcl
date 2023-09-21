# $Id: cust_matcher.tcl,v 1.1 2011/10/04 12:27:41 xbourgui Exp $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/cust_matcher/cust_matcher.tcl,v 1.1 2011/10/04 12:27:41 xbourgui Exp $
# $Name:  $
# (C) 2007 Orbis Technology Ltd. All rights reserved.
#
# The customer matcher matches customers to one another using a thing called a
#  URN (Unique Reference Number?)
#
# The most recent customer account will be held as the master record
# and this URN will be assigned to all the other accounts.
#


package require    monitor_compat 1.0


namespace eval cust_matcher {
	# Have we been initialised.
	variable INIT 0
	# An array to store the details of the customer we are currently trying
	# to match.
	variable CUST

}


#----------------------------------
# Initialise.
#
#----------------------------------
proc cust_matcher::init {} {
	variable INIT

	if {$INIT} {
		return
	}

	set INIT 1

	_prep_queries

	get_urn_match_control

	OT_LogWrite 4 "CM: initialised"
}


#----------------------------------
# Prepare the queries.
#
#----------------------------------
proc cust_matcher::_prep_queries {} {

	# Used to check we're able to match.
	OB_db::db_store_qry cust_matcher::get_urn_match_control {
		select
			last_proc_date,
			curr_version,
			allow_processing,
			load_status,
			extend(CURRENT,year to second) as db_start_time
		from
			tURNMatchControl
	}

	# Set the URN.
	OB_db::db_store_qry cust_matcher::upd_ext_cust {
		execute procedure pUpdExtCust(
			p_cust_id = ?,
			p_ext_cust_id = ?,
			p_version = ?,
			p_master = ?,
			p_code = 1,
			p_transactional = ?
		)
	}

	# Some stats to keep in mind (from stage 13th Nov 07).
	#
	# type             (count(*))
	#
	# addr_postc          3126372
	# address             3340113
	# alias                 54852
	# email               2856663
	# ipaddr              2971642
	# lname               3442476
	# mobile              1005921
	# telephone           2830350

	OB_db::db_store_qry cust_matcher::get_cust_matches8 {
		select {+ORDERED}
			r.cust_id,
			c.username,
			c.status,
			l.limit_type
		from
			tCustIndexedId addr_postc,
			tCustIndexedId lname ,
			tCustomerReg r,
			tCustomer c,
		outer   tCustLimits l
		where
			r.cust_id = addr_postc.cust_id
		and r.cust_id = lname.cust_id
		and addr_postc.type = 'addr_postc'
		and addr_postc.identifier = ?
		and lname.type = 'lname'
		and lname.identifier = ?
		and upper(r.fname) like ?
		and c.country_code = 'UK'
		and r.cust_id = c.cust_id
		and r.cust_id = l.cust_id
		and l.limit_type         = 'self_excl'
		and l.from_date          <= CURRENT
		and l.to_date            >= CURRENT
		and l.tm_date            is null
	}

	OB_db::db_store_qry cust_matcher::get_cust_matches9 {
		select {+ORDERED}
			r.cust_id,
			c.username,
			c.status,
			l.limit_type
		from
			tCustomerReg r,
			tCustIndexedId addr_postc,
			tCustIndexedId lname,
			tCustomer c,
		outer   tCustLimits l
		where
			r.cust_id = lname.cust_id
		-- needs index on tCustomerReg.dob
		and r.dob = ?
		and r.cust_id = addr_postc.cust_id
		and addr_postc.type = 'addr_postc'
		and addr_postc.identifier = ?
		and lname.type = 'lname'
		and lname.identifier = ?
		-- maybe ineffcient
		and upper(r.fname) like ?
		and c.country_code <> 'UK'
		and r.cust_id = c.cust_id
		and r.cust_id = l.cust_id
		and l.limit_type         = 'self_excl'
		and l.from_date          <= CURRENT
		and l.to_date            >= CURRENT
		and l.tm_date            is null

	}

	OB_db::db_store_qry cust_matcher::get_cust_matches10_one {
		select {+ORDERED}
			r.cust_id,
			c.username,
			c.status,
			l.limit_type
		from
			tCustomerReg r,
			tCustIndexedId telephone,
			tCustIndexedId lname,
			tCustomer c,
		outer   tCustLimits l
		where
			 r.cust_id = telephone.cust_id
		-- needs index on tCustomerReg.dob
		and r.dob = ?
		and r.cust_id = lname.cust_id
		and (
			(telephone.type = 'telephone' and telephone.identifier = ?)
			or
			(telephone.type = 'mobile' and telephone.identifier = ?)
		)
		and lname.type = 'lname'
		and lname.identifier = ?
		and upper(r.fname) like ?
		and c.country_code <> 'UK'
		and r.cust_id = c.cust_id
		and r.cust_id = l.cust_id
		and l.limit_type         = 'self_excl'
		and l.from_date          <= CURRENT
		and l.to_date            >= CURRENT
		and l.tm_date            is null
	}

	# note that because of the structure of tCustindexedId, 
	# this query could return multiple lines refering to the same match
	# i.e. if the mobile and telephone numbers both match to one user, 
	# you will get two rows for the same user.
	OB_db::db_store_qry cust_matcher::get_cust_matches10_both {
		select {+ORDERED}
			r.cust_id,
			c.username,
			c.status,
			l.limit_type
		from
			tCustomerReg r,
			tCustIndexedId telephone,
			tCustIndexedId lname,
			tCustomer c,
		outer   tCustLimits l
		where
			 r.cust_id = telephone.cust_id
		and r.dob = ?
		and r.cust_id = lname.cust_id
		and (
			(telephone.type = 'telephone' and telephone.identifier in (?, ?))
			or
			(telephone.type = 'mobile' and telephone.identifier in (?, ?))
		)
		and lname.type = 'lname'
		and lname.identifier = ?
		and upper(r.fname) like ?
		and c.country_code <> 'UK'
		and r.cust_id = c.cust_id
		and r.cust_id = l.cust_id
		and l.limit_type         = 'self_excl'
		and l.from_date          <= CURRENT
		and l.to_date            >= CURRENT
		and l.tm_date            is null
	}


	# Storing query cust_matcher::get_cust_matches11
	# This query is very long, with much repeated, so I'm assembling it like this:
	# Matching to Self-Excluded by any 3 of Title, Lname, dob, Postcode
	# format requires entering the same data multiple times
	# Argument order is: lname, dob, title,
	#                    lname, postcode, title,
	#                    dob, postcode, title,
	#                    lname, dob, postcode
	# Need to add an index on DOB for tCustomerReg
	# Shouldn't need one on title, because it should only be examining 
	#  title for a small subset of values
	# Using 'or' operators got too slow, so I went with unions
	set matches11_select {
		select 
			DISTINCT
			r.cust_id,
			c.username,
			c.status,
			r.lname,
			r.dob,
			r.addr_postcode,
			r.title,
			tCustLimits.limit_id
		from
			tCustomerReg r,
			tCustLimits,
			tCustIndexedId lname,
			tCustIndexedId postcode,
			tCustomer c
		where
			r.cust_id = tCustLimits.cust_id
			and limit_type         = 'self_excl'
			and from_date          <= CURRENT
			and to_date            >= CURRENT
			and tm_date            is null
			and
	}
	set matches11_1 {
			(
				(
					lname.type = 'lname'
					and lname.identifier = ?
					and r.cust_id = lname.cust_id
				)
				and     r.dob           = ?
				and     r.title         = ?
			)
			and r.cust_id = c.cust_id
	}
	set matches11_2 {
			(
				(
					lname.type = 'lname'
					and lname.identifier = ?
					and r.cust_id = lname.cust_id
				) 
				and
				(
					postcode.type = 'addr_postc'
					and postcode.identifier = ?
					and r.cust_id = postcode.cust_id
				)
				and     r.title         = ?
			)
			and r.cust_id = c.cust_id
	}
	set matches11_3 {
			(
				r.dob           = ?
				and	
				(
					postcode.type = 'addr_postc'
					and postcode.identifier = ?
					and r.cust_id = postcode.cust_id
				)
				and     r.title         = ?
			)
			and r.cust_id = c.cust_id
	}
	set matches11_4 {
			(
				(
					lname.type = 'lname'
					and lname.identifier = ?
					and r.cust_id = lname.cust_id
				)
				and     r.dob           = ?
				and
				(
					postcode.type = 'addr_postc'
					and postcode.identifier = ?
					and r.cust_id = postcode.cust_id
				)
			)
			and r.cust_id = c.cust_id
	}
	set query_11 ""
	OB_db::db_store_qry cust_matcher::get_cust_matches11 [append query_11 $matches11_select $matches11_1 \
	                                                             union    $matches11_select $matches11_2 \
	                                                             union    $matches11_select $matches11_3 \
	                                                             union    $matches11_select $matches11_4 ]


	# Defining cust_matcher::get_cust_matches12
	# This query is very long, with much repeated, so I'm assembling it like this:
	# Matching to on any 3 of Title, Lname, dob, Postcode
	#  format requires entering the same data multiple times
	#  Argument order is: lname, dob, title,
	#                     lname, postcode, title,
	#                     dob, postcode, title,
	#                     lname, dob, postcode
	#  Need to add an index on DOB for tCustomerReg
	#  Shouldn't need one on title, because it should only be examining 
	#   title for a small subset of values
	#   Using 'or' operators got too slow, so I went with unions

	set matches12_select {
		select 
			DISTINCT
			r.cust_id,
			c.username,
			c.status,
			r.lname,
			r.dob,
			r.addr_postcode,
			r.title,
			tCustLimits.limit_id
		from
			tCustomerReg r,
			outer tCustLimits,
			tCustIndexedId lname,
			tCustIndexedId postcode,
			tCustomer c
		where
	}
	set matches12_footer {
			and r.cust_id = c.cust_id
			and r.cust_id = tCustLimits.cust_id
			and limit_type         = 'self_excl'
			and from_date          <= CURRENT
			and to_date            >= CURRENT
			and tm_date            is null
	}
	set matches12_1 {
			(
				(
					lname.type = 'lname'
					and lname.identifier = ?
					and r.cust_id = lname.cust_id
				)
				and     r.dob           = ?
				and     upper(r.title)  = ?
			)
	}
	set matches12_2 {
			(
				(
					lname.type = 'lname'
					and lname.identifier = ?
					and r.cust_id = lname.cust_id
				) 
				and
				(
					postcode.type = 'addr_postc'
					and postcode.identifier = ?
					and r.cust_id = postcode.cust_id
				)
				and     upper(r.title)      = ?
			)
	}
	set matches12_3 {
			(
				r.dob           = ?
				and	
				(
					postcode.type = 'addr_postc'
					and postcode.identifier = ?
					and r.cust_id = postcode.cust_id
				)
				and     upper(r.title)      = ?
			)
	}
	set matches12_4 {
			(
				(
					lname.type = 'lname'
					and lname.identifier = ?
					and r.cust_id = lname.cust_id
				)
				and     r.dob           = ?
				and
				(
					postcode.type = 'addr_postc'
					and postcode.identifier = ?
					and r.cust_id = postcode.cust_id
				)
			)
	}
	set query_12 ""
	OB_db::db_store_qry cust_matcher::get_cust_matches12 [append query_12 $matches12_select $matches12_1 $matches12_footer \
	                                                             union    $matches12_select $matches12_2 $matches12_footer \
	                                                             union    $matches12_select $matches12_3 $matches12_footer \
	                                                             union    $matches12_select $matches12_4 $matches12_footer ]


	OB_db::db_store_qry cust_matcher::upd_cust_status {
		EXECUTE PROCEDURE pUpdCustStatus (
			p_cust_id = ?,
			p_status = ?,
			p_status_reason = ?
		)
	}


	# >  select ext_cust_id,count(*) from tExtCust group by ext_cust_id
	# having count(*) > 250;
	#
	# ext_cust_id                                                (count(*))
	#
	# 00524747                                                        351
	# 00683725                                                        417
	# 00787320                                                        267
	# 00801432                                                        412
	# 01665397                                                        319
	# 02362380                                                       1338
	#
	OB_db::db_store_qry cust_matcher::get_cust {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.status,
			c.cr_date,
			r.title,
			r.fname,
			r.lname,
			r.addr_street_1,
			r.addr_postcode,
			c.country_code,
			r.dob,
			r.telephone,
			r.mobile,
			e.ext_cust_id,
			e.version
		from
			tCustomer c,
			tCustomerReg r,
			tURNMatchControl u,
		outer
			tExtCust e
		where
			c.cust_id = r.cust_id
		and c.cust_id = e.cust_id
		and nvl(e.version, -1) = ?
		and c.cust_id = ?
		and e.code = 1
	}

	# If the customer is incomplete, we need to queue them.
	OB_db::db_store_qry cust_matcher::ins_cust_queue {
		execute procedure pInsCustQueue(
			p_cust_id = ?,
			p_type = 'M'
		)
	}

	OB_db::db_store_qry cust_matcher::del_cust_queue {
		delete from tCustQueue
		where
			cust_id = ?
		and type = 'M'
	}
}


#----------------------------------
# Return a normalised identfier. Space are stripped and the identifier is
# converted into upper-case. Phone numbers have all but that last six
# digits removed, because the last six have more variation in them and
# therefore procedure a better index.
#
# identifier - The value of the identifier.
# type       - The type of the identifier.
# return     - Normalised form.
#
#----------------------------------
proc cust_matcher::normalise_identifier {identifier type} {
	# last six characters for phone
	switch $type {
		"telephone" -
		"mobile" {
			return [string range \
				[string map [list " " ""] [string toupper $identifier]] \
				end-5 \
				end \
			]
		}
		"title" {
			return [string map [list " " "" "." "" "," ""] [string toupper $identifier]]
		}
		"addr_postc" -
		"lname" {
			return [string range \
			        [string map [list " " ""] [string toupper $identifier]] \
				0 9]
		}
		default {
			return [string map [list " " ""] [string toupper $identifier]]
		}
	}
}


#----------------------------------
# Can we even match on this? Too short and the search becomes very ineffcient.
#
# identifier - The value of the identifier.
# type       - The type of the identifier.
# returns    - Boolean.
#----------------------------------
proc cust_matcher::is_good_identifier {identifier type} {

	# the minimum number of characters for an identifier to be an efficient
	# match
	switch $type {
		"addr_postcode" -
		"addr_postc" {
			set min_length [OT_CfgGet CUST_MATCHER_MIN_IDENTIFIER_LENGTH.addr_postc 2]
		}
		"dob" {
			set min_length [OT_CfgGet CUST_MATCHER_MIN_IDENTIFIER_LENGTH.dob 10]
		}
		"fname" {
			set min_length [OT_CfgGet CUST_MATCHER_MIN_IDENTIFIER_LENGTH.fname 1]
		}
		"lname" {
			set min_length [OT_CfgGet CUST_MATCHER_MIN_IDENTIFIER_LENGTH.lname 2]
		}
		default {
			set min_length [OT_CfgGet CUST_MATCHER_MIN_IDENTIFIER_LENGTH.$type 3]
		}
	}

	set is_good_identifier [expr {
		[string length [normalise_identifier $identifier $type]] >= $min_length}]

	if {$is_good_identifier} {
		OT_LogWrite 6 "CM: $type \"$identifier\" is good"
	} else {
		OT_LogWrite 4 "CM: $type \"$identifier\" is bad"
	}

	return $is_good_identifier
}


#----------------------------------
# Can we match the customer? Have they finished their registration?
#
# returns    - Boolean.
#----------------------------------
proc cust_matcher::is_incomplete_registration {} {
	variable CUST

	return [expr {$CUST(lname) == "" || $CUST(fname) == ""}]
}


#----------------------------------
# Populate the date from the control table
#
#----------------------------------
proc cust_matcher::get_urn_match_control {} {
	variable URN_MATCH_CONTROL

	array unset URN_MATCH_CONTROL

	set rs [OB_db::db_exec_qry cust_matcher::get_urn_match_control]

	set colnames [db_get_colnames $rs]

	foreach n $colnames {
		set URN_MATCH_CONTROL($n) [db_get_col $rs 0 $n]
	}

	OB_db::db_close $rs

	OT_LogWrite 4 "CM: [array get URN_MATCH_CONTROL]"

}


#----------------------------------
# Do the matching and linking for customer, cust_id
#  Behavior depends on config items:
#     CUST_MATCHER_LINK_OPT     = {A, B}
#        A - default (William Hill's preference)
#          links when self-excluded is active and any three are true:
#            lname matches,
#            post_code matches,
#            dob matches,
#            title matches
#        B - Ladbrokes preference (see comments of get_matches_B for details)
#        C - Currently un-used Option
#          links when any three are true:
#            lname matches,
#            post_code matches,
#            dob matches,
#            title matches
#
#     CUST_MATCHER_NOTIFY_OPT   = {A, B}
#         A - Default - (William Hill preference)
#           Send a monitor message when match is found to a Self-Excluded account.
#         B - Ladbrokes preference
#           Send a monitor message when match is found to a suspended account
#     CUST_MATCHER_SUSPEND_OPT  = {A, B}
#         A - (William Hill preference)
#           Immediately suspend new accounts if exact match is found to a Self-Excluded account.
#         B - Default
#           Take no action
#
# Throws errors on 
#    URN load in progress
#    URN matching has been disabled
# Returns:  a list containing return code, return message
#  return_code   return_msg
#   -1           Matching Unsuccessful (should never happen.  Should throw errors instead)
#    0           Matching success, but no matches.
#    1           Matched Customers:  cust_ids
#    2           Matched and Suspended cust_id $cust_id because _
#----------------------------------
proc cust_matcher::match { cust_id {transactional "Y"} } {
	set return_code [list -1 "Matching Unsuccessful"]
	OT_LogWrite DEBUG "CM:  Entering Matching"

	variable CUST
	variable CUSTS
	variable URN_MATCH_CONTROL
	global SHARED_SQL

	# Initialise things if not already done
	init

	array set URN_MATCH_CONTROL [array unset URN_MATCH_CONTROL]
	get_urn_match_control

	if {$URN_MATCH_CONTROL(load_status) == "L"} {
		error "URN load in progress"
	}

	if {$URN_MATCH_CONTROL(allow_processing) != "Y"} {
		error "URN matching has been disabled"
	}

	# If version is less than the current version we are performing a rematch
	# maintaining linking from a previous ruleset, ignoring current linking
	set match_version [OT_CfgGet MATCH_VERSION $URN_MATCH_CONTROL(curr_version)]
	if { $match_version < $URN_MATCH_CONTROL(curr_version) } {
		OT_LogWrite WARNING "CM: matching using version $match_version"
	} else {
		set match_version $URN_MATCH_CONTROL(curr_version)
	}

	# Populate the CUST array with current customers details
	get_cust $cust_id $match_version

	OT_LogWrite WARNING "CM: matching customer $CUST(cust_id)"
	OT_LogWrite WARNING "CM: customer currently linked to < $CUST(ext_cust_id) >"

	# Find any matching customers
	# and load them into $CUSTS
	set switch_arg [OT_CfgGet CUST_MATCHER_LINK_OPT ""]
	switch -- $switch_arg {
		A {get_matches_A}
		B {get_matches_B}
		C {get_matches_C}
		default {get_matches_A}
	}

	if {[llength $CUSTS(cust_ids)] == 0} {
		set return_code [list 0 "Matching Successful, No Matches."]
	} elseif {[llength $CUSTS(cust_ids)] > 0} {
		set return_code [list 1 "Matched Customers: $CUSTS(cust_ids)"]
	}

	# Link to the found customers
	link $CUSTS(cust_ids) $match_version $transactional

	# Remove the customer from the failure queue if they are there
	OB_db::db_exec_qry cust_matcher::del_cust_queue $CUST(cust_id)

	switch -- [OT_CfgGet CUST_MATCHER_NOTIFY_OPT ""] {
		B {
			# Send monitor message if they match to a suspended customer
			#-----------------------------------------------------------
			foreach cust_id $CUSTS(cust_ids) {
				if {$CUSTS($cust_id,status) == "S"} {
					OT_LogWrite 4 "CM: customer matched suspended customer $cust_id"
					if {[catch {
						send_monitor $CUSTS($cust_id,username)
					} msg]} {
						OT_LogWrite 4 "CM: sending of monitor message failed"
					}
				}
			}
		}
		A -
		default {
			# Send monitor message if they are self excluded
			#-----------------------------------------------------------
			foreach cust_id $CUSTS(cust_ids) {
				if {$CUSTS($cust_id,limit_id) != ""} {
					OT_LogWrite 4 "CM: customer matched self excluded customer $cust_id"
					if {[catch {
						send_monitor $CUSTS($cust_id,username)
					} msg]} {
						OT_LogWrite 4 "CM: sending of monitor message failed"
					}
				}
			}
		}
	}

	# Determine what customers get suspended here 
	switch -- [OT_CfgGet CUST_MATCHER_SUSPEND_OPT ""] {
		A {
			OT_LogWrite DEBUG "CM: Suspend option set: CUST_MATCHER_SUSPEND_OPT = |[OT_CfgGet CUST_MATCHER_SUSPEND_OPT " "]|"

			# Suspend customers that are exact matches to self excluded customers
			foreach cust_id $CUSTS(cust_ids) {
				set exactMatch 1
				if {$CUSTS($cust_id,limit_id) != ""} {
					if {$CUSTS($cust_id,exactMatch)} {

					# suspending customer
					OT_LogWrite INFO "CM: Customer $CUST(cust_id) matched self excluded $cust_id customer exactly."
					OT_LogWrite INFO "CM: Suspending customer $CUST(cust_id)"
					set suspendMessage "URN Match found with self-excluded customer"
					OT_LogWrite DEBUG "CM: Suspending OB_db::db_exec_qry cust_matcher::upd_cust_status $CUST(cust_id) S $suspendMessage"
					if {[catch {
						OB_db::db_exec_qry cust_matcher::upd_cust_status $CUST(cust_id) S $suspendMessage
					} msg] } {
						 OT_LogWrite ERROR "CM: Failed to set $CUST(cust_id) status to suspended $msg" 
					} 
					# sending monitor message about suspension
					send_suspended_monitor $CUSTS($cust_id,username)
					set return_code [list 2 "Matched and Suspended cust_id $cust_id because it matched a self-excluded customer."]

					} else {
						OT_LogWrite DEBUG "CM: Customer $CUST(cust_id) not exact match to $cust_id, so not suspended"
					}
				} else {
					OT_LogWrite DEBUG "CM: Customer $cust_id not self excluded, so $CUST(cust_id) not suspended"
				}
			}
		}
		B -
		default {
			#do nothing
			OT_LogWrite DEBUG "CM: No Suspend option set: CUST_MATCHER_SUSPEND_OPT = |[OT_CfgGet CUST_MATCHER_SUSPEND_OPT " "]|"
		}
	}
	OT_LogWrite 4 "CM: finished matching"
	return $return_code
}

#----------------------------------
# Populates the array CUSTS with matching customers and their details.
#     used if CUST_MATCHER_LINK_OPT  = A
#     matches when Self-excluded is active and any three are true:
#            lname matches,
#            post_code matches,
#            dob matches,
#            title matches
proc cust_matcher::get_matches_A {} {
	OT_LogWrite DEBUG "CM:  Entering get_matches_A"

	variable CUSTS
	variable CUST

	array unset CUSTS

	OT_LogWrite 4 "CM: getting matches"
	OT_LogWrite 4 "CM: customer: [array get CUST]"

	# We can't match the customer if their registration has not
	# been completed.
	#
	if {[is_incomplete_registration]} {
		error "cannot match customer with incomplete registration"
	}

	set rs ""

	set lname_normalized   [normalise_identifier $CUST(lname) "lname"]
	set dob_normalized     [normalise_identifier $CUST(dob) "dob"]
	set title_normalized   [normalise_identifier $CUST(title) "title"]
	set postc_normalized   [normalise_identifier $CUST(addr_postcode) "addr_postc"]


	set rs [OB_db::db_exec_qry cust_matcher::get_cust_matches11 \
		$lname_normalized $dob_normalized $title_normalized \
		$lname_normalized $postc_normalized $title_normalized \
		$dob_normalized $postc_normalized $title_normalized \
		$lname_normalized $dob_normalized $postc_normalized\
	]

	if {$rs == ""} {
		error "no suitable matching criteria"
	}

	set CUSTS(cust_ids) [list]
	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]
	for {set r 0} {$r < $nrows} {incr r} {
		set cust_id [db_get_col $rs $r cust_id]
		lappend CUSTS(cust_ids) $cust_id
		foreach n $colnames {
			set CUSTS($cust_id,$n) [db_get_col $rs $r $n]
		}

		# Checking for an exact match
		if {[normalise_identifier $CUSTS($cust_id,lname) "lname"]              == $lname_normalized &&
		    [normalise_identifier $CUSTS($cust_id,dob) "dob"]                  == $dob_normalized   &&
		    [normalise_identifier $CUSTS($cust_id,title) "title"]              == $title_normalized &&
		    [normalise_identifier $CUSTS($cust_id,addr_postcode) "addr_postc"] == $postc_normalized
		} {
			set CUSTS($cust_id,exactMatch) 1
		} else {
			set CUSTS($cust_id,exactMatch) 0
		}
	}
	OB_db::db_close $rs

	set CUSTS(cust_ids) [lsort -decreasing -unique -integer $CUSTS(cust_ids)]


	# Remove the customer from the list of matched customers
	#-------------------------------------------------------
	set i [lsearch $CUSTS(cust_ids) $CUST(cust_id)]
	if {$i >= 0} {
		OT_LogWrite 4 "CM: customer matched themself"
		set CUSTS(cust_ids) [lreplace $CUSTS(cust_ids) $i $i]
	}
	OT_LogWrite 4 "CM: [llength $CUSTS(cust_ids)] match(es)"
	OT_LogWrite 5 "CM: matched:< $CUSTS(cust_ids) >"

} 


#----------------------------------
# Populates the array CUSTS with matching customers and their details.
#       used if CUST_MATCHER_LINK_OPT = B
#          UK  (rule 8)
#          ----
#          Link all customers by URN that have the following common attributes.
#          - Post Code
#          - Surname
#          - First Initial
#
#          The most recent customer account will be held as the master record and this
#          URN will be assigned to all the other accounts.
#
#          International (rule 9 & 10)
#          ---------------
#          Link all customers that have the following common attributes
#          - Post Code
#          - Surname
#          - First Initial
#          - Date Of Birth
#
#          Where the customer attributes do not contain a Post Code, the following
#          linking will be applied
#
#          - Surname
#          - First Initial
#          - Date of Birth
#          - Telephone number or
#          - Mobile number
#----------------------------------
proc cust_matcher::get_matches_B {} {
	OT_LogWrite DEBUG "CM:  Entering get_matches_B"

	variable CUSTS
	variable CUST

	array unset CUSTS

	OT_LogWrite 4 "CM: getting matches"
	OT_LogWrite 4 "CM: customer: [array get CUST]"

	# We can't match the customer if their registration has not
	# been completed.
	#
	if {[is_incomplete_registration]} {
		error "cannot match customer with incomplete registration"
	}

	# If this is the empty string, then we've got no good way to match the
	# customer.
	set rs ""

	if {
		$CUST(country_code) == "UK" &&
		[is_good_identifier $CUST(addr_postcode) "addr_postc"] &&
		[is_good_identifier $CUST(lname) "lname"] &&
		[is_good_identifier $CUST(fname) "fname"]
	} {
		OT_LogWrite 4 "CM: rule 8: UK, first initial, surname, postcode"
		set rs [OB_db::db_exec_qry cust_matcher::get_cust_matches8 \
			[normalise_identifier $CUST(addr_postcode) "addr_postc"] \
			[normalise_identifier $CUST(lname) "lname"] \
			[string range [normalise_identifier $CUST(fname) "fname"] 0 1]% \
		]
	}

	if {$CUST(country_code) != "UK"} {
		if {
			[is_good_identifier $CUST(dob) "dob"] &&
			[is_good_identifier $CUST(addr_postcode) "addr_postc"] &&
			[is_good_identifier $CUST(lname) "lname"] &&
			[is_good_identifier $CUST(fname) "fname"]
		} {
			OT_LogWrite 4 "CM: rule 9: non-UK, first initial, surname, dob, postcode"
			set rs [OB_db::db_exec_qry cust_matcher::get_cust_matches9 \
				[normalise_identifier $CUST(dob) "dob"] \
				[normalise_identifier $CUST(addr_postcode) "addr_postc"] \
				[normalise_identifier $CUST(lname) "lname"] \
				[string range [normalise_identifier $CUST(fname) "fname"] 0 1]% \
			]
		} elseif {
			[is_good_identifier $CUST(dob) "dob"] &&
			[is_good_identifier $CUST(lname) "lname"] &&
			[is_good_identifier $CUST(fname) "fname"] &&
			(
				[is_good_identifier $CUST(telephone) "telephone"] ||
				[is_good_identifier $CUST(mobile) "mobile"]
			)
		} {
			OT_LogWrite 4 "CM: rule 10: non-UK, phone, first initial, surname"

			switch [is_good_identifier $CUST(telephone) "telephone"][is_good_identifier $CUST(mobile) "mobile"] {
				10 {
					set rs [OB_db::db_exec_qry cust_matcher::get_cust_matches10_one \
						[normalise_identifier $CUST(dob) "dob"] \
						[normalise_identifier $CUST(telephone) "telephone"] \
						[normalise_identifier $CUST(telephone) "telephone"] \
						[normalise_identifier $CUST(lname) "lname"] \
						[string range [normalise_identifier $CUST(fname) "fname"] 0 1]% \
					]
				}
				01 {
					set rs [OB_db::db_exec_qry cust_matcher::get_cust_matches10_one \
						[normalise_identifier $CUST(dob) "dob"] \
						[normalise_identifier $CUST(mobile) "mobile"] \
						[normalise_identifier $CUST(mobile) "mobile"] \
						[normalise_identifier $CUST(lname) "lname"] \
						[string range [normalise_identifier $CUST(fname) "fname"] 0 1]% \
					]
				}
				11 {
					set rs [OB_db::db_exec_qry cust_matcher::get_cust_matches10_both \
						[normalise_identifier $CUST(dob) "dob"] \
						[normalise_identifier $CUST(telephone) "telephone"] \
						[normalise_identifier $CUST(mobile) "mobile"] \
						[normalise_identifier $CUST(telephone) "telephone"] \
						[normalise_identifier $CUST(mobile) "mobile"] \
						[normalise_identifier $CUST(lname) "lname"] \
						[string range [normalise_identifier $CUST(fname) "fname"] 0 1]% \
					]
				}
				default {
					error "not valid combination of mobile and telephone"
				}
			}
		}
	}

	if {$rs == ""} {
		error "no suitable matching criteria"
	}

	set CUSTS(cust_ids) [list]
	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]
	for {set r 0} {$r < $nrows} {incr r} {
		set cust_id [db_get_col $rs $r cust_id]
		lappend CUSTS(cust_ids) $cust_id
		foreach n $colnames {
			set CUSTS($cust_id,$n) [db_get_col $rs $r $n]
		}
		set CUSTS($cust_id,exactMatch) 1
	}
	OB_db::db_close $rs

	set CUSTS(cust_ids) [lsort -decreasing -unique -integer $CUSTS(cust_ids)]


	# Remove the customer from the list of matched customers
	#-------------------------------------------------------
	set i [lsearch $CUSTS(cust_ids) $CUST(cust_id)]
	if {$i >= 0} {
		OT_LogWrite 4 "CM: customer matched themself"
		set CUSTS(cust_ids) [lreplace $CUSTS(cust_ids) $i $i]
	}
	OT_LogWrite 4 "CM: [llength $CUSTS(cust_ids)] match(es)"
	OT_LogWrite 5 "CM: matched:< $CUSTS(cust_ids) >"

}


#----------------------------------
# Populates the array CUSTS with matching customers and their details.
#     used if CUST_MATCHER_LINK_OPT  = C
#     matches when any three are true:
#            lname matches,
#            post_code matches,
#            dob matches,
#            title matches
proc cust_matcher::get_matches_C {} {
	OT_LogWrite DEBUG "CM:  Entering get_matches_C"
	variable CUSTS
	variable CUST

	array unset CUSTS

	OT_LogWrite 4 "CM: getting matches"
	OT_LogWrite 4 "CM: customer: [array get CUST]"

	# We can't match the customer if their registration has not
	# been completed.
	#
	if {[is_incomplete_registration]} {
		error "cannot match customer with incomplete registration"
	}

	set lname_normalized   [normalise_identifier $CUST(lname) "lname"]
	set dob_normalized     [normalise_identifier $CUST(dob) "dob"]
	set title_normalized   [normalise_identifier $CUST(title) "title"]
	set postc_normalized   [normalise_identifier $CUST(addr_postcode) "addr_postc"]

	set rs [OB_db::db_exec_qry cust_matcher::get_cust_matches12 \
		$lname_normalized $dob_normalized $title_normalized \
		$lname_normalized $postc_normalized $title_normalized \
		$dob_normalized $postc_normalized $title_normalized \
		$lname_normalized $dob_normalized $postc_normalized\
	]
	if {$rs == ""} {
		error "no suitable matching criteria"
	}

	set CUSTS(cust_ids) [list]
	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]
	for {set r 0} {$r < $nrows} {incr r} {
		set cust_id [db_get_col $rs $r cust_id]
		lappend CUSTS(cust_ids) $cust_id
		foreach n $colnames {
			set CUSTS($cust_id,$n) [db_get_col $rs $r $n]
		}

		# Checking for an exact match
		if {[normalise_identifier $CUSTS($cust_id,lname) "lname"]              == $lname_normalized &&
		    [normalise_identifier $CUSTS($cust_id,dob) "dob"]                  == $dob_normalized   &&
		    [normalise_identifier $CUSTS($cust_id,title) "title"]              == $title_normalized &&
		    [normalise_identifier $CUSTS($cust_id,addr_postcode) "addr_postc"] == $postc_normalized
		} {
			set CUSTS($cust_id,exactMatch) 1
		} else {
			set CUSTS($cust_id,exactMatch) 0
		}
	}
	OB_db::db_close $rs

	set CUSTS(cust_ids) [lsort -decreasing -unique -integer $CUSTS(cust_ids)]


	# Remove the customer from the list of matched customers
	#-------------------------------------------------------
	set i [lsearch $CUSTS(cust_ids) $CUST(cust_id)]
	if {$i >= 0} {
		OT_LogWrite 4 "CM: customer matched themself"
		set CUSTS(cust_ids) [lreplace $CUSTS(cust_ids) $i $i]
	}
	OT_LogWrite 4 "CM: [llength $CUSTS(cust_ids)] match(es)"
	OT_LogWrite 5 "CM: matched:< $CUSTS(cust_ids) >"

} 


#----------------------------------
# Link the current customer to the customer IDs.
#
#----------------------------------
proc cust_matcher::link {cust_ids match_version {transactional "Y"} } {
	variable URN_MATCH_CONTROL
	variable CUST

	get_urn_match_control

	# Check we are ok to carry on
	#----------------------------
	if {$URN_MATCH_CONTROL(allow_processing) != "Y"} {
		error "matching has been disabled"
	}
	if {$URN_MATCH_CONTROL(load_status) == "L"} {
		error "URN load in progress"
	}


	# Get the URN for the last registered  customer we match to
	#--------------------------------------------------------------
	OT_LogWrite 4 "CM: linking to \"$cust_ids\""
	set ext_cust_id $CUST(ext_cust_id)
	if {[llength $cust_ids] > 0} {
		foreach cust_id $cust_ids {
			set rs [OB_db::db_exec_qry cust_matcher::get_cust $match_version $cust_id]
			set new_ext_cust_id [db_get_col $rs 0 ext_cust_id]
			OB_db::db_close $rs
			if { $new_ext_cust_id != "" } {
				set ext_cust_id $new_ext_cust_id
				break
			}
		}
	}
	OT_LogWrite 4 "CM: setting external ID to \"$ext_cust_id\""


	# If INSERT_VERSION is greater than the version in tUrnMatchControl we are
	# performing a rematch operation
	#-------------------------------------------------------------------------
	set insert_version [OT_CfgGet INSERT_VERSION $URN_MATCH_CONTROL(curr_version)]
	set rematch_op 0
	if {  $insert_version > $URN_MATCH_CONTROL(curr_version) } {
		set urn_version $insert_version
		set rematch_op 1
		OT_LogWrite 4 "CM: updating/inserting URN with version $urn_version"
	} else {
		set urn_version $URN_MATCH_CONTROL(curr_version)
	}


	# If the urn has changed, the customer doesn't match anyone
	# or we are moving to a new version then update/insert urn
	#------------------------------------------------------------
	if { $ext_cust_id == "" || $ext_cust_id != $CUST(ext_cust_id) || $rematch_op} {

		# The first customer on a URN should be the master
		if { $ext_cust_id == "" } {
			set master Y
		} else {
			set master N
		}

		set rs [OB_db::db_exec_qry cust_matcher::upd_ext_cust \
			$CUST(cust_id) \
			$ext_cust_id \
			$urn_version \
			$master \
			$transactional]
		set ext_cust_id [db_get_coln $rs 0 0]
		OB_db::db_close $rs
	}


	OT_LogWrite 4 "CM: set external ID to $ext_cust_id "
}



#----------------------------------
# Get a single customer into memory.
#
#----------------------------------
proc cust_matcher::get_cust {cust_id version} {
	variable CUST

	array unset CUST

	set rs [OB_db::db_exec_qry cust_matcher::get_cust $version $cust_id ]

	set colnames [db_get_colnames $rs]

	foreach n $colnames {
		set CUST($n) [db_get_col $rs 0 $n]
	}

	OB_db::db_close $rs
}


#----------------------------------
# Send a monitor message saying that we've matched a customer.
#
# username - The username of the matched customer.
#----------------------------------
proc cust_matcher::send_monitor {username} {
	variable CUST

	OT_LogWrite 4 "CM: sending monitor message for URN match"

	MONITOR::send_urn_match \
		$CUST(cr_date) \
		$CUST(username) \
		$CUST(acct_no) \
		[normalise_identifier $CUST(addr_street_1) "addr_street_1"] \
		[normalise_identifier $CUST(addr_postcode) "addr_postc"] \
		$username
}

proc cust_matcher::send_suspended_monitor {username} {
	variable CUST

	OT_LogWrite 4 "CM: sending suspended message via monitor"

	MONITOR::send_suspended \
		$CUST(cr_date) \
		$CUST(username) \
		$CUST(acct_no) \
		[normalise_identifier $CUST(addr_street_1) "addr_street_1"] \
		[normalise_identifier $CUST(addr_postcode) "addr_postc"] \
		$username \
		URNM

}

#----------------------------------
# Queue the customer for future processing.
#
# cust_id - The customer's ID.
#----------------------------------
proc cust_matcher::queue {cust_id} {

	OT_LogWrite 4 "CM: queuing customer $cust_id for future match"

	if {[catch {
		OB_db::db_exec_qry cust_matcher::ins_cust_queue $cust_id
	} msg]} {
		OT_LogWrite 2 "CM: failed to queue customer $cust_id: $msg"
	}
}




