# $Id: us-check.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# ==============================================================
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# Traceware-based customer checking
#
# The following configuration entries affect this module:
#
#   TW_LIBRARY        traceware shared library to load
#   TW_BLOCK_FLAGS    override default set of block flags
#
namespace eval OB::TW {

variable OK
variable RX_ZIP

array set QRY [list]

set OK     0

#
# Regular expression to match "dodgy" postcodes
#
set RX_ZIP {^\s*([A-Z]+\W*)?\d{5}(\W\d{4})?\D*$}

#
# Default set of flags to block (these are from BP's analysis of
# historical data)
#
variable BLOCK_FLAGS {
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

proc init args {

	variable OK
	variable QRY
	variable BLOCK_FLAGS

	if {$OK} {
		return
	}

	set lib [string trim [OT_CfgGet TW_LIBRARY ""]]
	if {![string length $lib]} {
		ob::log::write CRITICAL {OB::TW::init - no TW_LIBRARY specified}
		return
	}

	global xtn
	if {[regexp -nocase ".$xtn\$" $lib]} {
		if {[catch {source $lib} msg]} {
			ob::log::write CRITICAL {OB::TW::init - failed to source $lib ($msg)}
			return
		}
	} else {
		if {[catch {load $lib} msg]} {
			ob::log::write ERROR {OB::TW::init - failed to load $lib ($msg)}
			return
		}
	}
	db_store_qry get_card_country {
		select	country,allow_dep,allow_wtd
		from	tCardInfo
		where	card_bin = ?
	}
	db_store_qry log_check {
		insert into	tCustCheck(
			cust_id,ipaddr,lead_digits,postcode,ip_country,check_flags,result
		) values (
			?,?,?,?,?,?,?
		)
	}
	if {[set flags_block [OT_CfgGet TW_BLOCK_FLAGS none]] != "none"} {
		set BLOCK_FLAGS $flags_block
	}

	ob::log::write DEV {>>>>>>>>>>>>>completed us-check init}
	set OK 1
}

proc reset args {
}

proc check_ip ip {

	variable OK

	if {!$OK} {
		return "??"
	}
	if {[catch {set cc [string trim [ip_to_cc $ip]]} msg]} {
		ob::log::write ERROR {OB::TW::check - failed ($msg)}
		return "??"
	}
	if {[string length $cc] != 2} {
		return $cc
	}
	return $cc
}

proc check_US {cust_id ipaddr card_no postcode {op "D"}} {

	variable OK
	variable RX_ZIP
	variable BLOCK_FLAGS

	if {!$OK} {
		return -
	}

	#
	# Default state of all flags is "don't know"
	#
	set us_ip       -
	set us_card     -
	set us_postcode -

	#
	# Check IP address -  this uses the traceware library to return a
	# two character country code
	#
	set tw_country ""

	if {[regexp {^\d+\.\d+\.\d+\.\d+$} $ipaddr]} {
		catch {
			set tw_country [ip_to_cc $ipaddr]
			if {[regexp {^US} $tw_country]} {
				set us_ip Y
			} elseif {[string length $tw_country] >= 2}  {
				set us_ip N
			}
		}
	}

	#
	# Check card number - this checks against the bin number database -
	# a card is considered US is the country looks like "UNITED STATES*"
	# or the "allowed" flag is set to "N"
	#
	regsub -all {\D} $card_no {} card_no
	if {[regexp {^6\d\d\d\d\d} $card_no lead_digits]} {
		#
		# Switch/Solo/whatever card hack - all seem to begin with 6 - these
		# are UK cards - other countries might have similar schemes
		#
		set us_card N
	} elseif {[regexp {^\d\d\d\d\d\d} $card_no lead_digits]} {
		if {[catch {
			set rs_gcc [db_exec_qry get_card_country $lead_digits]
			if {[db_get_nrows $rs_gcc] == 1} {
				set db_cntry [db_get_col $rs_gcc 0 country]
				set db_allwd [expr {[string equal $op "W"] ? [db_get_col $rs_gcc 0 allow_wtd] : [db_get_col $rs_gcc 0 allow_dep]}]
				if {[regexp {^UNITED STATES} $db_cntry] || $db_allwd == "N"} {
					set us_card Y
				} else {
					set us_card N
				}
			}
			db_close $rs_gcc
		} msg]} {
			ob::log::write ERROR {failed to get card_bin: $msg}
		}
	}

	#
	# Check postcode - we use a regular expression here - it might be
	# necessary to refine this check...
	#
	if {[string length $postcode] > 0} {
		if {[regexp -nocase $RX_ZIP $postcode]} {
			set us_postcode Y
		} else {
			set us_postcode N
		}
	}

	#
	# From IP, card, postcode, make a flag string, 3 characters long, each
	# character has Y/N/- (yes,no,don't know). Each one of these combinations
	# is mapped to an idea of whether we think someone is in the US.
	#
	set flags $us_ip$us_card$us_postcode

	if {[lsearch -exact $BLOCK_FLAGS $flags] >= 0} {
		set us 1
	} else {
		set us 0
	}

	#
	# Trim card number for logging
	#
	set card_no [string range $card_no 0 5]

	#
	# Log check into database
	#
	if {[catch {
		set res [db_exec_qry log_check\
			$cust_id\
			$ipaddr\
			$card_no\
			$postcode\
			$tw_country\
			$flags\
			$us]
		if {$res != ""} {
			db_close $res
		}
	} msg]} {
		# refresh the db connection, just in case
		ob::log::write ERROR {Failed to log US check: $msg}
	}

	ob::log::write ERROR {check_US: $ipaddr,$card_no,$postcode ==> $flags ($us)}

	return $us
}

}
