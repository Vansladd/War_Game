# $Id: country_check.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# Country checking
#
# The following configuration entries affect this module:
#
#   CCHK_LIBRARY           country checking shared library to load
#   CCHK_BLOCK_FLAGS       override default set of block flags
#   CCHK_BLOCK_CCS         list of ISO country codes to block
#

namespace eval OB::country_check {

	set COOKIE_FMT {
		expires
		cust_id
		flag
		ip_country
		ip_city
		ip_routing
		country_cf
		ip_addr
		ip_is_blocked
	}


	# Initialisation flag

	set CCHK_READY 0
	set KEEPALIVE [OT_CfgGet CCHK_COOKIE_KEEPALIVE -1]

	# Default set of flags to block

	set CCHK_BLOCK_FLAGS {
		YYY
		YYN
		YY-
		YNY
		Y-Y
		Y-N
		Y--
		NYY
		-YY
		-Y-
		-NY
		--Y
		---
	}

	# Default set of country codes to block (none)

	set CCHK_BLOCK_CCS [list]

	# Regular expression to match US-style zipcodes

	set CCHK_POSTCODE_RX {^\s*([A-Z]+\W*)?\d{5}(\W\d{4})?\D*$}

	# Array of long country names mapped to their ISO country codes
	# (actually set at the bottom of this file!)

	array set CC_EXPANSION [list]

	array set BLOCK_OR_REQ {req_id -1}

}

proc OB::country_check::init args {

	variable CCHK_READY
	variable CCHK_BLOCK_FLAGS
	variable CCHK_BLOCK_CCS

	global xtn

	if {$CCHK_READY} {
		return
	}

	ob_log::write DEV {OB::country_check::init}

	if { [OT_CfgGetTrue FUNC_GEOPOINT_IP_CHECK] } {

		ob_log::write DEV {OB::country_check::init: loading geopoint}

		set lib [string trim [OT_CfgGet CCHK_LIBRARY ""]]

		if {![string length $lib]} {
			ob::log::write CRITICAL \
				{OB::country_check::init - no CCHK_LIBRARY specified}
			set CCHK_READY -1
			return
		}

		global xtn

		if {[regexp -nocase ".$xtn\$" $lib]} {

			if {[catch {source $lib} msg]} {
				ob::log::write CRITICAL \
					{OB::country_check::init - failed to source $lib ($msg)}
				set CCHK_READY -1
				return
			}

		} else {

			if {[catch {load $lib} msg]} {
				ob::log::write CRITICAL \
					{OB::country_check::init - failed to load $lib ($msg)}
				set CCHK_READY -1
				return
			}

		}

	}

	if {[OT_CfgGet FUNC_IP2LOCATION_IP_CHECK 0]} {
		set lib [file join [OT_CfgGet TCL_SCRIPT_DIR tcl]/shared_tcl\
                           ip2location.$xtn]
		ob::log::write DEBUG {sourcing $lib}
		if {[catch {source $lib} msg]} {
			ob::log::write CRITICAL\
				{OB::country_check::init - failed to source $lib ($msg)}
			set CCHK_READY -1
			return
		}
	}


	ob_log::write DEV {OB::country_check::init: setting up SQL}

	global SHARED_SQL

	set SHARED_SQL(get_card_country) {
		select	country
		from	tCardInfo
		where	card_bin = ?
	}

	set SHARED_SQL(log_check) {
		insert into	tCustCheck
			(
			cust_id,
			ipaddr,
			card_bin,
			postcode,
			ip_country,
			cc_country,
			check_flags,
			result
			)
		values (?, ?, ?, ?, ?, ?, ?, ?)
	}

	set SHARED_SQL(get_cust_postcode) {
		select addr_postcode
		from   tcustomerreg
		where  cust_id = ?
	}

	set SHARED_SQL(get_cust_card_bin) {
		select
			cpm.card_bin
		from
			tCustPayMthd m,
			tCpmCC       cpm
		where
			cpm.cpm_id     = m.cpm_id
			and m.status   = 'A'
			and m.cust_id  = ?
	}

	set SHARED_SQL(get_skip_check_flag) {
		select flag_value
		from   tcustomerflag
		where  flag_name = 'SkipIPCheck'
		and    cust_id   = ?
	}

	set SHARED_SQL(get_keepalive) {
		select login_keepalive from tcontrol
	}

	set SHARED_SQL(get_block_list) {
		select * from tPmtCntryChk
	}

	set SHARED_SQL(get_ccy_country) {
		select country_code
		from   tcountry
		where  ccy_code=?
	}

	set SHARED_SQL(get_specific_ccy_country) {
		select country_code
		from   tcountry
		where  ccy_code=? and
			   country_code = ?
	}

	set SHARED_SQL(check_country_ban_op) {

		select
			1
		from
			tAuthServerApp a,
			tCntryBanOp    b
		where a.app_id       = b.app_id
		  and a.code         = ?
		  and b.op_code      = ?
		  and b.country_code = ?

	}

	# insert into tIPCheckFail
	set SHARED_SQL(ins_check_fail) {
		execute procedure
			pInsIPCheckFail(
				p_cust_id = ?,
				p_ip_addr = ?,
				p_channel = ?,
				p_action  = ?,
				p_country_code = ?
			)
	}

	set SHARED_SQL(check_ip_allow) {
		select
			1
		from
			tIPAllow
		where
			ip_address = ? and
			status = 'A'
	}

	set SHARED_SQL(insert_check_item) {
		insert into
		tCntryChk(
			cust_id,
			ip_address,
			op_code,
			category,
			xgame_sort,
			channel_id,
			sys_group_id,
			add_name,
			country_code,
			check_result,
			cr_date
		) values (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			current
		)
	}

	set SHARED_SQL(insert_check_item_no_cust_id) {
		insert into
		tCntryChk(
			ip_address,
			op_code,
			category,
			xgame_sort,
			channel_id,
			sys_group_id,
			add_name,
			check_result,
			cr_date
		) values (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			current
		)
	}

	set SHARED_SQL(get_ip_blocked) {
		select
			1
		from
			tIPBlock
		where
			? >= ip_addr_lo
		and
			? <= ip_addr_hi
		and (
			expires is null
		or
			expires > current
		)
	}

	set SHARED_SQL(insert_ip_block_log) {
		insert into
		tBlockedAccessLog(
			ip_address,
			date
		) values (
			?,
			current
		)
	}

	set SHARED_SQL(upd_cust_flag) {
		execute procedure
		pUpdCustFlag(
			p_cust_id = ?,
			p_flag_name = ?,
			p_flag_value = ?
		)
	}

	if { [OT_CfgGetTrue CCHK_USE_DATABASE] } {

		set result [get_block_list_from_database]

		if { ![lindex $result 0] } {
			ob::log::write INFO \
				{OB::country_check::init - [lindex $result 1]}
		} else {
			set CCHK_BLOCK_FLAGS [lindex $result 1]
		}

	}

	set block_list [OT_CfgGet CCHK_BLOCK_FLAGS ""]

	if { $block_list != "" } {

		set CCHK_BLOCK_FLAGS [string toupper $block_list]

	}

	set block_list [OT_CfgGet CCHK_BLOCK_CCS ""]

	if { $block_list != "" } {

		set CCHK_BLOCK_CCS [string toupper $block_list]

	}

	set CCHK_READY 1

}

proc OB::country_check::get_block_list_from_database {} {

	global DB SHARED_SQL

	set options [list Y N -]
	set block_list ""

	set rs [tb_db::tb_exec_qry get_block_list]

	if {[db_get_nrows $rs]!=9} {
		return [list 0 "Wrong number of rules in tPmtCntryChk"]
	}

	# convert data from matrix into list of block flags
	for {set row 0} {$row<9} {incr row} {
		for {set col 0} {$col<3} {incr col} {
			if {[db_get_coln $rs $row [expr $col+1]]=="B"} {
				set ip    [lindex $options [expr $row/3]]
				set bin   [lindex $options $col]
				set pc    [lindex $options [expr $row%3]]

				ob::log::write DEBUG \
					{row=$row, col=$col, ip = $ip, bin = $bin, pc = $pc}

				lappend block_list "${ip}${bin}${pc}"
			}
		}
	}

	db_close $rs

	ob::log::write INFO {BLOCK_LIST = $block_list}

	return [list 1 $block_list]
}


proc OB::country_check::card_to_cc {card_bin} {

	variable CCHK_READY
	variable CC_EXPANSION

	if {$CCHK_READY == -1} {
		return "??"
	}

	set card_cc "??"

	if {[catch {
		set rs_gcc [tb_db::tb_exec_qry get_card_country $card_bin]
		if {[db_get_nrows $rs_gcc] == 1} {
			set db_cntry [string toupper [db_get_col $rs_gcc 0 country]]
			foreach expand_cc [array names CC_EXPANSION] {
				if {[string first $expand_cc $db_cntry] == 0} {
					set card_cc $CC_EXPANSION($expand_cc)
					break
				}
			}
		}
		db_close $rs_gcc
	} msg]} {
		ob::log::write ERROR {OB::country_check::card_check -\
			failed to get card_bin: $msg}
	}

	if {$card_cc == "??" && [regexp {^6} $card_bin]} {
		set card_cc "UK"
	}

	return $card_cc
}


# Get ip country, currency country, address country and card country.
# Check if they match and award points for mismatches.
proc OB::country_check::fraud_check {cust_id ipaddr card_no country ccy} {

	variable CCHK_READY
	variable CCHK_POSTCODE_RX
	variable CCHK_BLOCK_FLAGS
	variable CCHK_BLOCK_CCS

	if {$CCHK_READY == -1} {
		# if we can't run the check due to a failed initialisation, allow
		# everything
		return 0
	}

	set cust_country 		[get_cust_country $ipaddr]
	# The realmapping server returns 'GB' while
	# currency and address return 'UK' so convert
	if {$cust_country == "GB"} {
		set cust_country "UK"
	}

	# remove non-digits
	regsub -all {\D} $card_no {} card_no

	# and pull out the bin
	if {![regexp {^\d\d\d\d\d\d} $card_no card_bin]} {
		set card_bin ""
	}

	set card_country 	[get_card_country $card_bin]
	# The array at the end of this file returns 'GB' for credit card while
	# currency and address return 'UK' so convert
	if {$card_country == "GB"} {
		set card_country "UK"
	}
	set ccy_country		[get_ccy_country $ccy]
	set addr_country 	$country

	ob::log::write INFO {cust country: $cust_country}
	ob::log::write INFO {card country: $card_country}
	ob::log::write INFO {ccy country : $ccy_country}
	ob::log::write INFO {addr country: $addr_country}

	#
	# Add points for countries that do not match
	#
	set matrix [OT_CfgGet FRAUD_CHECK_MATRIX "0,0,0,0,0,0"]
	set list [split $matrix ,]
	set points 0

	# compare ip country with card country
	if {![string equal $cust_country "A!"] &&
		![string equal $cust_country $card_country] &&
		![string equal $cust_country "??"] &&
		![string equal $card_country "??"]} {

		incr points [lindex $list 0]
	}
	# compare addr country with card country
	if {![string equal $addr_country $card_country] &&
		![string equal $addr_country "--"] &&
		![string equal $card_country "??"]} {

		incr points [lindex $list 1]
	}
	# compare ccy country with card country
	if {$ccy_country == "--" && ![string equal $card_country "??"]} {
		if {[catch {
			set rs [tb_db::tb_exec_qry \
				get_specific_ccy_country $ccy $card_country]
		} msg]} {
			ob::log::write ERROR {failed to get country for\
				ccy $ccy, card country $card_country: $msg}
		} elseif {[db_get_nrows $rs] == 0} {

			incr points [lindex $list 2]
		}

	} elseif {![string equal $ccy_country $card_country] &&
			  ![string equal $ccy_country "??"] &&
			  ![string equal $card_country "??"]} {

			incr points [lindex $list 2]
	}
	# compare ip country with addr country
	if {![string equal $cust_country "A!"] &&
		![string equal $cust_country $addr_country] &&
		![string equal $cust_country "??"] &&
		![string equal $addr_country "--"]} {

		incr points [lindex $list 3]
	}
	# compare addr country with ccy country
	if {$ccy_country == "--" && ![string equal $addr_country "--"]} {
		if {[catch {
			set rs [tb_db::tb_exec_qry \
				get_specific_ccy_country $ccy $addr_country]
		} msg]} {
			ob::log::write INFO {failed to get country for \
				ccy $ccy and addr country $addr_country: $msg}
		} elseif {[db_get_nrows $rs] == 0} {

			incr points [lindex $list 4]
		}
	} elseif {![string equal $addr_country $ccy_country] &&
			  ![string equal $addr_country "--"] &&
			  ![string equal $ccy_country "??"]} {

		incr points [lindex $list 4]
	}
	# compare ip country with ccy country
	if {
		$ccy_country == "--"
		&& ![string equal $cust_country "??"]
		&& ![string equal $cust_country "A!"]
	} {
		if {[catch {
			set rs [tb_db::tb_exec_qry \
				get_specific_ccy_country $ccy $cust_country]
		} msg]} {
			ob::log::write INFO {failed to get country for\
				ccy $ccy and ip country $cust_country: $msg}
		} elseif {[db_get_nrows $rs] == 0} {

			incr points [lindex $list 5]
		}
	} elseif {![string equal $cust_country "A!"] &&
			  ![string equal $cust_country $ccy_country] &&
			  ![string equal $cust_country "??"] &&
			  ![string equal $ccy_country "??"]} {

		incr points [lindex $list 5]
	}

	return $points
}

# local function.
# superseded by use get_cust_country instead
proc OB::country_check::get_ip_country {ipaddr } {

	#
	# Check IP address - this uses the country checking library to return a
	# two character country code
	#
	set ip_country "??"
	if {[regexp {^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$} $ipaddr]} {
		if {[catch {set ip_country [ip_to_cc $ipaddr ]} msg]} {
			ob_log::write ERROR {Unable to perform ip_to_cc on $ipaddr - $msg}
		}
	}

	return $ip_country
}


proc OB::country_check::get_card_country {card_bin} {

	#
	# Check card number - this checks against tCardInfo to establish the
	# country of origin which we then look up to find the two character
	# country code
	#
	set card_country [card_to_cc $card_bin]
	return $card_country
}


proc OB::country_check::get_ccy_country {ccy} {

	set ccy_country "??"
	if {[catch {set rs [tb_db::tb_exec_qry get_ccy_country $ccy]} msg]} {
		ob::log::write ERROR {failed to get country for currency $ccy: $msg}
	} else {
		set nrows [db_get_nrows $rs]

		if {$nrows == 1} {
			set ccy_country [db_get_col $rs country_code]
		} elseif {$nrows > 1} {
			set ccy_country "--"
		}
	}
	return $ccy_country
}

proc OB::country_check::check {cust_id ipaddr card_bin postcode } {
	variable CCHK_READY
	variable CCHK_POSTCODE_RX
	variable CCHK_BLOCK_FLAGS
	variable CCHK_BLOCK_CCS

	set ip_country "??"

	if {$CCHK_READY == -1} {
		ob::log::write ERROR {Can't run the check \
			due to failed initialisation, allow everything}
		return [list 0 $ip_country]
	}

	set cust_country [get_cust_country $ipaddr]

	set block 0

	if {[OT_CfgGet FUNC_OVS_CHECK_IPADDR 1]} {

		if {$card_bin == ""} {
			set card_country "??"
		} else {
			set card_country [get_card_country $card_bin]
		}

		#
		# Check postcode format
		#
		if {[regexp {^\s*$} $postcode]} {
			set postcode_country "??"
		} elseif {[regexp -nocase $CCHK_POSTCODE_RX $postcode]} {
			set postcode_country "US"
		} else {
			set postcode_country "OK"
		}

		#
		# Form check flag string (Y for US, - for ??, N otherwise)
		#
		set check_flags ""
		switch -- $cust_country {
			US		{ append check_flags "Y" }
			??		{ append check_flags "-" }
			default	{ append check_flags "N" }
		}
		switch -- $card_country {
			US		{ append check_flags "Y" }
			??		{ append check_flags "-" }
			default	{ append check_flags "N" }
		}
		switch -- $postcode_country {
			US		{ append check_flags "Y" }
			??		{ append check_flags "-" }
			default	{ append check_flags "N" }
		}

		ob::log::write INFO {check:INFO:cust_country:$cust_country \
										card_country:$card_country \
										postcode_country:$postcode_country \
										check_flags:$check_flags}

		#
		# Look for this flag combination in the block list or the cust_country
		# in the country codes list
		#
		if {[lsearch -exact $CCHK_BLOCK_FLAGS $check_flags] >= 0} {
			ob::log::write INFO {country_check::check evaluating to bad as \
				$check_flags matches $CCHK_BLOCK_FLAGS}
			set block 1
		} elseif {[lsearch -exact $CCHK_BLOCK_CCS $cust_country] >= 0} {
			ob::log::write INFO {country_check::check evaluation to bad as \
				$cust_country in $CCHK_BLOCK_CCS}
			set block 1
		} else {
			set block 0
		}

		#
		# Log check into database
		#
		if {[catch {
			set res [tb_db::tb_exec_qry log_check\
						 $cust_id\
						 $ipaddr\
						 $card_bin\
						 $postcode\
						 $cust_country\
						 $card_country\
						 $check_flags\
						 $block]
			if {$res != ""} {
				db_close $res
			}
		} msg]} {
			ob::log::write ERROR \
				{OB::country_check::check - failed to log country check: $msg}
		}

		ob::log::write INFO \
			{OB::country_check::check - ip: ($ipaddr)}
		ob::log::write INFO \
			{OB::country_check::check - cust country:  ($cust_country)}
		ob::log::write INFO \
			{OB::country_check::check - bin: $card_bin ($card_country)}
		ob::log::write INFO \
			{OB::country_check::check - zip: $postcode ($postcode_country)}
		ob::log::write INFO \
			{OB::country_check::check - blocked: $block}
	}

	return [list $block $cust_country]

}

#
# Checks the method we use to look up country
#  and then returns the country code or '??'
# Defaults to checking IP,
# Alternatively tries from ob_login.
#
proc OB::country_check::get_cust_country {{ipaddr ""}} {

	set cust_country "??"
	if {[OT_CfgGetTrue CCHK_BY_CUST_ADDR]} {
		if {[catch {set cust_country [ob_login::get cntry_code "??"]} msg]} {
			ob::log::write DEBUG {Problem with ob_login in OB::country_check::get_cust_country.  Is it set up?}
		}
		# Can't use ob_login on registration check.
		# So if you didn't find anything in ob_login,
		# check if app_control is set.
		if {$cust_country == "??"} {
			if {[catch {
				set cust_country [app_control::get_val "country_code"]
				ob::log::write DEV "Country got from app_control:  $cust_country"
			} msg]} {
				ob::log::write DEBUG "Cannot find country code, even in app_control: $msg"
				set cust_country "??"
			}
		}
	} else {
		set cust_country [get_ip_country $ipaddr]
	}

	return $cust_country

}

#
# Helper method used to check is a customer has an block override set-up.
#
proc OB::country_check::check_block_override {cust_id} {

	global DB
	variable BLOCK_OR_REQ
	set req_id [reqGetId]

	#
	# request level caching of the block override
	#
	if { [OT_CfgGetTrue NO_OVERRIDE_CACHING]
			|| $BLOCK_OR_REQ(req_id) != $req_id } {

		#
		# See if we've a skipIPCheck flag for the customer
		#
		set skip_block 0

		if {[catch {
			set rs [tb_db::tb_exec_qry get_skip_check_flag $cust_id]
		} msg]} {
			ob::log::write ERROR \
				{failed to get skipIPCheck customer flag: $msg}
		} else {
			if {[db_get_nrows $rs] == 1} {
				set flag [db_get_col $rs 0 flag_value]
				ob::log::write INFO \
					{Retrieved Customer flag - skipIPCheck=$flag}
				if {$flag == "Y"} {set skip_block 1}
			} elseif {[db_get_nrows $rs] > 1} {
				ob::log::write INFO \
					{Error: Query returned [db_get_nrows $rs] rows}
			}

			db_close $rs
		}

		set BLOCK_OR_REQ(skip_block) $skip_block
		set BLOCK_OR_REQ(req_id) $req_id

		return $skip_block

	} else {
		return $BLOCK_OR_REQ(skip_block)
	}

}

#
# This wraps up a call to the above check method, but adds session cookie
# caching functionality. ie. When the check is first performed it will store
# the result inside a session cookie. Each call first checks if that cookie
# is present, if so then this is the result that is returned. Otherwise the
# full check method is called and then the result is stored in the cookie
#
proc OB::country_check::cookie_check {
	cust_id {ipaddr ""} {card_no ""} {postcode ""} {outcome ""}
} {

	variable COOKIE_FMT
	variable IP_CHECK_RESULTS
	global IP_COUNTRY
	set IP_COUNTRY "??"
	set IP_CHECK_RESULTS(ip_is_blocked) "N"

	ob::log::write DEBUG {cookie_check:CALL:cust_id=$cust_id \
											ipaddr=$ipaddr \
											card_no=$card_no \
											postcode=$postcode \
											outcome=$outcome}

	if {$outcome!=""} {
		upvar 1 $outcome local_outcome
	}

	set cookie [retrieve_cc_cookie]

	# Need to perform check if cookie belonged to a different customer or if
	# check info not there.

	if {
		[lindex $cookie [lsearch $COOKIE_FMT cust_id]] != $cust_id ||
		[lindex $cookie [lsearch $COOKIE_FMT ip_addr]] != $ipaddr ||
		[lindex $cookie [lsearch $COOKIE_FMT flag]] == ""
	} {
		# If we haven't been supplied the card, ip or postcode then
		# retrieve these.
		if {$ipaddr == ""} {
			set ipaddr [reqGetEnv REMOTE_ADDR]
			ob::log::write INFO {Retrieved client IP as $ipaddr}
		}

		set card_bin ""

		if {[OT_CfgGet CCHK_CHECK_CARD 0]} {
			if {$card_no == ""} {

				if {[catch {
					set rs [tb_db::tb_exec_qry get_cust_card_bin $cust_id]
				} msg]} {
					ob::log::write ERROR \
						{failed to get customer card bin: $msg}
				} else {
					if {[db_get_nrows $rs]} {
						set card_bin [db_get_col $rs 0 card_bin]
					}
					db_close $rs
				}
			} else {
				# grab the bin from the card number
				regsub -all {\D} $card_no {} card_no
				regexp {^\d\d\d\d\d\d} $card_no card_bin
			}
		}

		if {[OT_CfgGet CCHK_CHECK_POSTCODE 0]} {
			if {$postcode == ""} {
				if {[catch {
					set rs [tb_db::tb_exec_qry get_cust_postcode $cust_id]
				} msg]} {
					ob::log::write ERROR {failed to get customer postcode: $msg}
				} else {
					if {[db_get_nrows $rs] == 1} {
						set postcode [db_get_col $rs 0 addr_postcode]
						ob::log::write INFO \
							{Retrieved customer postcode: $postcode}
					} else {
						ob::log::write INFO {Error: Customer postcode query\
							returned [db_get_nrows $rs] rows}
					}
					db_close $rs
				}
			}
		}

		foreach {flag IP_COUNTRY} \
			[check $cust_id $ipaddr $card_bin $postcode ] {break}

		# Specific IP banning
		set IP_CHECK_RESULTS(ip_is_blocked) [check_ip_banned $ipaddr]

		if {$IP_CHECK_RESULTS(ip_is_blocked)=="Y"} {
			set flag 1
		}

		# See if we need to override
		if {$flag != 0} {
			if {[check_block_override $cust_id]} {
				ob::log::write INFO \
					{Overriding Customer Check for cust_id $cust_id}
				set flag 0
			}
		}

		if {[OT_CfgGet CCHK_EXTRA_FIELDS 0]} {
			store_cc_cookie $cust_id $flag $IP_COUNTRY \
				$IP_CHECK_RESULTS(ip_city) \
				$IP_CHECK_RESULTS(ip_routing) \
				$IP_CHECK_RESULTS(country_cf) \
				$IP_CHECK_RESULTS(ip_addr) \
				$IP_CHECK_RESULTS(ip_is_blocked)

		} else {
			store_cc_cookie $cust_id $flag $IP_COUNTRY \
				"" "" "" $ipaddr $IP_CHECK_RESULTS(ip_is_blocked)
		}

		if {![OT_CfgGet CCHK_BY_CUST_ADDR 0]} {
			# Insert/Update the customer flag IP_Country with this one
			if {[catch {
				set rs [tb_db::tb_exec_qry upd_cust_flag $cust_id "IP_Country" $IP_COUNTRY]
			} msg]} {
				ob::log::write ERROR "failed to insert/update customer flag IP_Country for cust_id $cust_id: $msg"
			} else {
				ob::log::write INFO "Customer flag IP_Country updated for cust_id $cust_id"
				db_close $rs
			}
		}

	} else {
		## get flag from cookie as it is okay
		set flag [lindex $cookie [lsearch $COOKIE_FMT flag]]

		## populate IP_CHECK_RESULTS with correct info
		foreach result $COOKIE_FMT {
			set IP_CHECK_RESULTS($result) \
				[lindex $cookie [lsearch $COOKIE_FMT $result]]
		}

		set IP_COUNTRY [lindex $cookie [lsearch $COOKIE_FMT ip_country]]

		ob::log::write INFO {retrieved flag of $flag from cookie}
	}

	if {$IP_CHECK_RESULTS(ip_is_blocked)=="Y"} {
		ob::log::write INFO {ip is blocked}
		set local_outcome "IP_BLOCKED"
		log_banned_ip_access $ipaddr
	} else {
		set local_outcome "IP_NOT_BLOCKED"
	}

	set IP_CHECK_RESULTS(ip_addr)    $ipaddr
	set IP_CHECK_RESULTS(ip_country) $IP_COUNTRY

	ob::log::write DEBUG {cookie_check:RETURN:$flag}
	return $flag
}

#
# Gets country check information from cookie, returns "" if there's a
# problem/nothing there
#
proc OB::country_check::retrieve_cc_cookie {} {
	variable COOKIE_FMT

	# Try and retrieve flag from cookie - this is now the responsibility of
	# the applications

	set cc_cookie_name [OT_CfgGet CC_COOKIE "cust_auth"]
	set enc_flag [OB::AUTHENTICATE::get_region_cookie]

	#See if the cookie was set or not
	#set redo_cookie 0
	if {$enc_flag == ""} {return {}}

	ob::log::write INFO \
		{Retrieved encrypted flag --> $cc_cookie_name=$enc_flag}
	#Get the crypt key
	if {[OT_CfgGet DECRYPT_KEY_HEX 0] == 0} {
		set key_type bin
		set crypt_key [OT_CfgGet DECRYPT_KEY]
	} else {
		set key_type hex
		set crypt_key [OT_CfgGet DECRYPT_KEY_HEX]
	}

	set dec_cookie [hextobin [blowfish decrypt \
		-$key_type $crypt_key -hex $enc_flag]]
	ob::log::write DEV {Decrypted cookie --> $cc_cookie_name=$dec_cookie}

	set cookie [split  $dec_cookie |]
	if {[llength $cookie] != [llength $COOKIE_FMT]} {
		#it's malformed
		ob::log::write DEBUG {cookie is malformed [llength $cookie]}
		return ""
	} elseif {[OT_CfgGet PERMANENT_COOKIE 0] == 0} {
		if {[lindex $cookie 0] < [clock seconds]} {
			#cookie has expired
			ob::log::write DEBUG {cookie has expired}
			return ""
		}
	}
	return $cookie

}

##
# country_check::store_cc_cookie - Stores customer's IP info.
#
# SYNOPSIS
#
#    [country_check::store_cc_cookie <cust_id> <flag> <ip_country> <ip_city>
#		<ip_routing> <country_cf> <ip_addr> <ip_is_blocked>]
#
# SCOPE
#
#    private
#
# PARAMS
#
#     [cust_id] -
#
#     [flag] -
#
#     [ip_country] -
#
#     [ip_city]
#
#     [ip_routing]
#
#     [country_cf] - Confidence Factor
#
#     [ip_addr]
#
#     [ip_is_banned]
# RETURN
#
#    Sets a cookie
#
# DESCRIPTION
#
#
##
proc OB::country_check::store_cc_cookie {
	cust_id
	flag
	ip_country
	ip_city
	ip_routing
	country_cf
	ip_addr
	ip_is_blocked
} {

	variable COOKIE_FMT
	variable KEEPALIVE

	#Get the crypt key
	if {[OT_CfgGet DECRYPT_KEY_HEX 0] == 0} {
		set key_type bin
		set crypt_key [OT_CfgGet DECRYPT_KEY]
	} else {
		set key_type hex
		set crypt_key [OT_CfgGet DECRYPT_KEY_HEX]
	}

	#Set the expiry time

	set now [clock seconds]
	if {$KEEPALIVE == -1} {
		if {[catch {set rs [tb_db::tb_exec_qry get_keepalive]} msg]} {
			ob::log::write ERROR \
				{failed to get country check cookie keepalive: $msg}
			set KEEPALIVE 0
		} else {
			if {[db_get_nrows $rs] == 1} {
				set KEEPALIVE [db_get_coln $rs 0]
			}
			db_close $rs
		}
	}

	set expires [expr $now + $KEEPALIVE]

	# Add each element to the cookie
	foreach v $COOKIE_FMT {
		lappend cookie_data [set $v]
	}

	set cookie_data [join $cookie_data |]

	#Encrypt the cookie data
	set enc_flag [blowfish encrypt -$key_type $crypt_key -bin $cookie_data]

	#Store in the cookie - this is now the responsibility of the calling app
	OB::AUTHENTICATE::set_region_cookie $enc_flag
}

proc OB::country_check::check_ip_banned {ip_address} {
	set banned "N"

	set decimal_ip [ip_to_dec $ip_address]

	if {[catch {
		set rs [tb_db::tb_exec_qry get_ip_blocked $decimal_ip $decimal_ip]
	} msg]} {
		ob::log::write ERROR {failed to get ip blocks $ip_address: $msg}
	} else {
		set nrows [db_get_nrows $rs]

		if {$nrows >0} {
			set banned "Y"
			ob::log::write INFO \
				{Attempt at banned action from blocked ip $ip_address}
		}
	}

	return $banned
}

proc OB::country_check::log_banned_ip_access {ip_address} {

	if {[catch {
		set res [tb_db::tb_exec_qry insert_ip_block_log $ip_address]

		if {$res != ""} {
			db_close $res
		}
	} msg]} {
		ob::log::write ERROR {failed to\
			OB::country_check::log_banned_ip_access ip_address:\
			$ip_address $msg}
	}
}

proc OB::country_check::log_checkpoint {user_id ip_addr op_code category xgame_sort channel_id sys_group_id add_name country allow} {
	#
	# Log check into database
	#

	ob::log::write DEV {OB::country_check::log_checkpoint\
		user_id:$user_id\
		ip_addr:$ip_addr\
		op_code:$op_code\
		category:$category\
		xgame_sort:$xgame_sort\
		channel_id:$channel_id\
		sys_group_id:$sys_group_id\
		add_name:$add_name\
		country:$country\
		allow:$allow}

	if {$allow} {
		#don't log to db
		return
	}

	if {$user_id != -1} {

		if {[catch {
		set res [tb_db::tb_exec_qry insert_check_item\
						 $user_id\
						 $ip_addr\
						 $op_code\
						 $category\
						 $xgame_sort\
						 $channel_id\
						 $sys_group_id\
						 $add_name\
						 $country\
						 $allow]
			if {$res != ""} {
				db_close $res
			}
		} msg]} {
			ob::log::write ERROR {OB::country_check::log_checkpoint\
				user_id:$user_id\
				ip_addr:$ip_addr\
				op_code:$op_code\
				category:$category\
				xgame_sort:$xgame_sort\
				channel_id:$channel_id\
				sys_group_id:$sys_group_id\
				add_name:$add_name\
				country:$country\
				allow:$allow - failed to log geopoint check: $msg}
		}
	} else {

		if {[catch {
			set res [tb_db::tb_exec_qry insert_check_item_no_cust_id\
						 $ip_addr\
						 $op_code\
						 $category\
						 $country\
						 $xgame_sort\
						 $channel_id\
						 $sys_group_id\
						 $add_name\
						 $allow]
			if {$res != ""} {
				db_close $res
			}
		} msg]} {
			ob::log::write ERROR {OB::country_check::log_checkpoint\
				user_id:$user_id\
				ip_addr:$ip_addr\
				op_code:$op_code\
				category:$category\
				xgame_sort:$xgame_sort\
				channel_id:$channel_id\
				sys_group_id:$sys_group_id\
				add_name:$add_name\
				country:$country\
				allow:$allow - failed to log geopoint check: $msg}
		}
	}
}

#
# checks an operation against a user looking at country to allow country-
# based control against functionality:
# returns 0, disallow operation
# returns 1, allow operation
#
proc OB::country_check::do_checkpoint {
	op_code
	{ip_addr ""}
	{application "default"}
	{cust_id ""}
	{channel "I"}
} {
	variable IP_CHECK_RESULTS

	global USER_ID

	set allow 0
	ob::log::write DEBUG {do_checkpoint:CALL:op_code=$op_code \
											 ip_addr=$ip_addr \
											 application=$application \
											 cust_id=$cust_id}


	if {$cust_id ==""} {
		set cust_id $USER_ID
	}
	cookie_check $cust_id $ip_addr "" "" ""

	# check here whether the ip-address is allowed by the admin user
	if {[catch {
		set rs_ip [tb_db::tb_exec_qry check_ip_allow $ip_addr]
	} msg]} {
		ob::log::write ERROR {failed to get ip allowed for ip $ip_addr: $msg}
	} else {
		if {[db_get_nrows $rs_ip] > 0} {
			ob::log::write INFO {IP $ip_addr is allowed by the admin, skipping country ban check}
			set allow 1
		}
		db_close $rs_ip
	}
	# if ip is allowed, then we need not do the country ban check
	if {!$allow} {
		if {$IP_CHECK_RESULTS(ip_is_blocked) != "Y"} {
			if {[catch {
				set rs [tb_db::tb_exec_qry check_country_ban_op \
					$application                                \
					$op_code                                    \
					$IP_CHECK_RESULTS(ip_country)
				]
			} msg]} {
				ob::log::write ERROR {failed to get opcode country mapping\
					$op_code $IP_CHECK_RESULTS(ip_country): $msg}
			} else {
				set nrows [db_get_nrows $rs]

				if {$nrows == 0} {
					set allow 1
				} else {
					# insert a log row into tIPCheckFail
					if {[catch {
						set rs_cf [tb_db::tb_exec_qry ins_check_fail \
								$cust_id \
								$ip_addr  \
								$channel \
								$op_code \
								$IP_CHECK_RESULTS(ip_country)
						]
					} msg]} {
						ob::log::write ERROR {failed to insert row in tIPCheckFail}
					} else {
						db_close $rs_cf
					}
				}
				db_close $rs
			}
		}
	}
	if {[check_block_override $cust_id]} {
		ob::log::write DEV \
			{geopoint check:IP block override is active for this customer}
		set allow 1
	}

	log_checkpoint \
		$cust_id \
		$IP_CHECK_RESULTS(ip_addr) \
		$op_code \
		"" \
		"" \
		"" \
		"" \
		"" \
		$IP_CHECK_RESULTS(ip_country) \
		$allow

	ob::log::write DEV {geopoint check:\
		$op_code $IP_CHECK_RESULTS(ip_country) returning: $allow}

	if {$IP_CHECK_RESULTS(ip_is_blocked) == "Y" && !$allow} {
		set return_code BLOCKED
	} else {
		set return_code [list $allow $IP_CHECK_RESULTS(ip_country)]
	}
	ob::log::write DEBUG {do_checkpoint:RETURN:$return_code}
	return $return_code
}

# Long tedious list of country names and their ISO codes
array set CC_EXPANSION {
	{ANDORRA}                           AD
	{UNITED ARAB EMIRATES}              AE
	{AFGHANISTAN}                       AF
	{ANTIGUA AND BARBUDA}               AG
	{ANTIGUA & BARBUDA}                 AG
	{ANTIGUA}                           AG
	{BARBUDA}                           AG
	{ANGUILLA}                          AI
	{ALBANIA}                           AL
	{ARMENIA}                           AM
	{NETHERLANDS ANTILLES}              AN
	{ANGOLA}                            AO
	{ANTARCTICA}                        AQ
	{ARGENTINA}                         AR
	{AMERICAN SAMOA}                    AS
	{AUSTRIA}                           AT
	{AUSTRALIA}                         AU
	{ARUBA}                             AW
	{AZERBAIJAN}                        AZ
	{BOSNIA AND HERZEGOVINA}            BA
	{BOSNIA & HERZEGOVINA}              BA
	{BOSNIA}                            BA
	{HERZEGOVINA}                       BA
	{BARBADOS}                          BB
	{BANGLADESH}                        BD
	{BELGIUM}                           BE
	{BURKINA FASO}                      BF
	{BULGARIA}                          BG
	{BAHRAIN}                           BH
	{BURUNDI}                           BI
	{BENIN}                             BJ
	{BERMUDA}                           BM
	{BRUNEI DARUSSALAM}                 BN
	{BRUNEI}                            BN
	{BOLIVIA}                           BO
	{BRAZIL}                            BR
	{BAHAMAS}                           BS
	{BHUTAN}                            BT
	{BOUVET ISLAND}                     BV
	{BOTSWANA}                          BW
	{BELARUS}                           BY
	{BELIZE}                            BZ
	{CANADA}                            CA
	{COCOS (KEELING) ISLANDS}           CC
	{COCOS ISLANDS}                     CC
	{KEELING ISLANDS}                   CC
	{CENTRAL AFRICAN REPUBLIC}          CF
	{CONGO}                             CG
	{SWITZERLAND}                       CH
	{COTE D'IVOIRE}                     CI
	{IVORY COAST}                       CI
	{COOK ISLANDS}                      CK
	{CHILE}                             CL
	{CAMEROON}                          CM
	{CHINA}                             CN
	{CHINA, PEOPLE'S REP. OF}           CN
	{CHINA, PEOPLES REP. OF}            CN
	{CHINA, PEOPLE'S REPUBLIC OF}       CN
	{CHINA, PEOPLES REPUBLIC OF}        CN
	{PEOPLE'S REP. OF CHINA}            CN
	{PEOPLES REP. OF CHINA}             CN
	{PEOPLE'S REPUBLIC OF CHINA}        CN
	{PEOPLES REPUBLIC OF CHINA}         CN
	{COLOMBIA}                          CO
	{COSTA RICA}                        CR
	{CZECHOSLOVAKIA}                    CS
	{CUBA}                              CU
	{CAPE VERDE}                        CV
	{CHRISTMAS ISLAND}                  CX
	{CYPRUS}                            CY
	{CZECH REPUBLIC}                    CZ
	{GERMANY}                           DE
	{DJIBOUTI}                          DJ
	{DENMARK}                           DK
	{DOMINICA}                          DM
	{DOMINICAN REPUBLIC}                DO
	{ALGERIA}                           DZ
	{ECUADOR}                           EC
	{ESTONIA}                           EE
	{EGYPT}                             EG
	{WESTERN SAHARA}                    EH
	{ERITREA}                           ER
	{SPAIN}                             ES
	{ETHIOPIA}                          ET
	{EUROPE}                            EU
	{FINLAND}                           FI
	{FIJI}                              FJ
	{FALKLAND ISLANDS}                  FK
	{MALVINAS}                          FK
	{MICRONESIA}                        FM
	{FAROE ISLANDS}                     FO
	{FRANCE}                            FR
	{GABON}                             GA
	{GREAT BRITAIN}                     GB
	{ENGLAND}                           GB
	{SCOTLAND}                          GB
	{WALES}                             GB
	{NORTHERN IRELAND}                  GB
	{UNITED KINGDOM}                    GB
	{UK}                                GB
	{U.K.}                              GB
	{G.B.}                              GB
	{GRENADA}                           GD
	{GEORGIA}                           GE
	{FRENCH GUIANA}                     GF
	{GHANA}                             GH
	{GIBRALTAR}                         GI
	{GREENLAND}                         GL
	{GAMBIA}                            GM
	{GUINEA}                            GN
	{GUADELOUPE}                        GP
	{EQUATORIAL GUINEA}                 GQ
	{GREECE}                            GR
	{GUATEMALA}                         GT
	{GUAM}                              GU
	{GUINEA BISSAU}                     GW
	{GUYANA}                            GY
	{HONG KONG}                         HK
	{HONG-KONG}                         HK
	{HONG KONG, CHINA}                  HK
	{HONG-KONG, CHINA}                  HK
	{HEARD AND MCDONALD ISLANDS}        HM
	{HONDURAS}                          HN
	{CROATIA}                           HR
	{HRVATSKA}                          HR
	{HAITI}                             HT
	{HUNGARY}                           HU
	{INDONESIA}                         ID
	{IRELAND}                           IE
	{IRELAND, REPUBLIC OF}              IE
	{REPUBLIC OF IRELAND}               IE
	{EIRE}                              IE
	{ISRAEL}                            IL
	{INDIA}                             IN
	{IRAQ}                              IQ
	{IRAN}                              IR
	{ISLAMIC REPUBLIC OF IRAN}          IR
	{ICELAND}                           IS
	{ITALY}                             IT
	{JAMAICA}                           JM
	{JORDAN}                            JO
	{JAPAN}                             JP
	{KENYA}                             KE
	{KYRGYZSTAN}                        KG
	{CAMBODIA}                          KH
	{KIRIBATI}                          KI
	{COMOROS}                           KM
	{SAINT KITTS AND NEVIS}             KN
	{SAINT KITTS-NEVIS}                 KN
	{SAINT KITTS & NEVIS}               KN
	{ST. KITTS AND NEVIS}               KN
	{ST. KITTS-NEVIS}                   KN
	{ST. KITTS & NEVIS}                 KN
	{NORTH KOREA}                       KP
	{KOREA, REPUBLIC OF}                KR
	{REPUBLIC OF KOREA}                 KR
	{SOUTH KOREA}                       KR
	{KOREA}                             KR
	{KUWAIT}                            KW
	{CAYMAN ISLANDS}                    KY
	{KAZAKHSTAN}                        KZ
	{LAOS}                              LA
	{LEBANON}                           LB
	{SAINT LUCIA}                       LC
	{ST. LUCIA}                         LC
	{LIECHTENSTEIN}                     LI
	{SRI LANKA}                         LK
	{LIBERIA}                           LR
	{LESOTHO}                           LS
	{LITHUANIA}                         LT
	{LUXEMBOURG}                        LU
	{LATVIA}                            LV
	{LIBYA}                             LY
	{MOROCCO}                           MA
	{MONACO}                            MC
	{MOLDOVA}                           MD
	{MADAGASCAR}                        MG
	{MARSHALL ISLANDS}                  MH
	{MACEDONIA}                         MK
	{MALI}                              ML
	{MYANMAR}                           MM
	{MONGOLIA}                          MN
	{MACAO}                             MO
	{MACAU}                             MO
	{NORTHERN MARIANA ISLANDS}          MP
	{MARTINIQUE}                        MQ
	{MAURITANIA}                        MR
	{MONTSERRAT}                        MS
	{MALTA}                             MT
	{MAURITIUS}                         MU
	{MALDIVES}                          MV
	{MALAWI}                            MW
	{MEXICO}                            MX
	{MALAYSIA}                          MY
	{MOZAMBIQUE}                        MZ
	{NAMIBIA}                           NA
	{NEW CALEDONIA}                     NC
	{NIGER}                             NE
	{NORFOLK ISLAND}                    NF
	{NIGERIA}                           NG
	{NICARAGUA}                         NI
	{NETHERLANDS}                       NL
	{THE NETHERLANDS}                   NL
	{HOLLAND}                           NL
	{NORWAY}                            NO
	{NEPAL}                             NP
	{NAURU}                             NR
	{NIUE}                              NU
	{NEW ZEALAND}                       NZ
	{AOTEAROA}                          NZ
	{OMAN}                              OM
	{PANAMA}                            PA
	{PERU}                              PE
	{FRENCH POLYNESIA}                  PF
	{PAPUA NEW GUINEA}                  PG
	{PHILIPPINES}                       PH
	{PAKISTAN}                          PK
	{POLAND}                            PL
	{ST PIERRE AND MIQUELON}            PM
	{ST PIERRE & MIQUELON}              PM
	{PITCAIRN}                          PN
	{PUERTO RICO}                       PR
	{PORTUGAL}                          PT
	{PALAU}                             PW
	{PARAGUAY}                          PY
	{QATAR}                             QA
	{REUNION}                           RE
	{ROMANIA}                           RO
	{RUSSIA}                            RU
	{RUSSIAN FEDERATION}                RU
	{RWANDA}                            RW
	{SAUDI ARABIA}                      SA
	{BRITISH SOLOMON ISLANDS}           SB
	{SOLOMON ISLANDS}                   SB
	{SEYCHELLES}                        SC
	{SUDAN}                             SD
	{SWEDEN}                            SE
	{SINGAPORE}                         SG
	{ST HELENA}                         SH
	{SLOVENIA}                          SI
	{SVALBARD AND JAN MAYEN ISLANDS}    SJ
	{SVALBARD & JAN MAYEN ISLANDS}      SJ
	{SLOVAK REPUBLIC}                   SK
	{SLOVAKIA}                          SK
	{SIERRA LEONE}                      SL
	{SAN MARINO}                        SM
	{SENEGAL}                           SN
	{SOMALIA}                           SO
	{SURINAME}                          SR
	{SAO TOME AND PRINCIPE}             ST
	{SAO TOME & PRINCIPE}               ST
	{USSR}                              SU
	{EL SALVADOR}                       SV
	{SYRIA}                             SY
	{SWAZILAND}                         SZ
	{TURKS AND CAICOS ISLANDS}          TC
	{TURKS & CAICOS ISLANDS}            TC
	{CHAD}                              TD
	{FRENCH SOUTHERN TERRITORIES}       TF
	{TOGO}                              TG
	{THAILAND}                          TH
	{TAJIKISTAN}                        TJ
	{TOKELAU}                           TK
	{TURKMENISTAN}                      TM
	{TUNISIA}                           TN
	{TONGA}                             TO
	{EAST TIMOR}                        TP
	{TURKEY}                            TR
	{TRINIDAD AND TOBAGO}               TT
	{TRINIDAD & TOBAGO}                 TT
	{TRINIDAD}                          TT
	{TOBAGO}                            TT
	{TUVALU}                            TV
	{TAIWAN}                            TW
	{TANZANIA}                          TZ
	{UKRAINE}                           UA
	{UGANDA}                            UG
	{AMERICA}                           US
	{UNITED STATES}                     US
	{U.S.}                              US
	{UNITED STATES OF AMERICA}          US
	{USA}                               US
	{U.S.A.}                            US
	{URUGUAY}                           UY
	{UZBEKISTAN}                        UZ
	{VATICAN CITY STATE}                VA
	{HOLY SEE}                          VA
	{SAINT VINCENT AND THE GRENADINES}  VC
	{SAINT VINCENT & THE GRENADINES}    VC
	{SAINT VINCENT & GRENADINES}        VC
	{SAINT VINCENT}                     VC
	{ST. VINCENT AND THE GRENADINES}    VC
	{ST. VINCENT & THE GRENADINES}      VC
	{ST. VINCENT & GRENADINES}          VC
	{ST. VINCENT}                       VC
	{THE GRENADINES}                    VC
	{VENEZUELA}                         VE
	{BRITISH VIRGIN ISLANDS}            VG
	{VIRGIN ISLANDS (BRITISH)}          VG
	{US VIRGIN ISLANDS}                 VI
	{U.S. VIRGIN ISLANDS}               VI
	{VIRGIN ISLANDS (US)}               VI
	{VIRGIN ISLANDS (U.S.)}             VI
	{VIRGIN ISLANDS}                    VI
	{VIET NAM}                          VN
	{VIETNAM}                           VN
	{VANUATU}                           VU
	{WALLIS AND FUTUNA ISLANDS}         WF
	{SAMOA}                             WS
	{YEMEN}                             YE
	{MAYOTTE}                           YT
	{YUGOSLAVIA}                        YU
	{SOUTH AFRICA}                      ZA
	{ZAMBIA}                            ZM
	{ZAIRE}                             ZR
	{ZIMBABWE}                          ZW
}
