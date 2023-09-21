# $Id: bir.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# $Name:  $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle BIR utilities
#
# Synopsis:
#    This file provides functions to deal with generating and
#    checking BIR tokens.
#
# Procedures:
#    External:
#     ob_bir::init               - self-initialising - see end of file
#     ob_bir::is_bir_event       - are any of the given selns part of a BIR mkt
#     ob_bir::get_bir_index      - get the bir index for a selection
#     ob_bir::get_delay          - get total delay required for the given selns
#     ob_bir::get_token          - generate a token for the given delay (in seconds)
#     ob_bir::valid_token        - does the given token have the correct format and
#                                  have we delayed long enough
#     ob_bir::set_err            - sets an error condition
#     ob_bir::get_err            - gets the current error condition
#
#    Internal:
#     ob_bir::check_timestamp    - checks the BIR timestamp format
#     ob_bir::generate_timestamp - generates a new BIR timestamp
#
# Configuration:
#    CUST_ACCT_KEY               account number encryption key          - ("")
#    DECRYPT_KEY                 blowfish decrypt key                   - ("")
#    DECRYPT_KEY_HEX             blowfish decrypt key in hex            - ("")
#    (One of DECRYPT_KEY and DECRYPT_KEY_HEX must be set)
#    BIR_DELAY_SPAN              time between min and max delay (in seconds) - (5)
#    BIR_JUNK                    junk to add to timestamp to validate   - (0123456789)
#
# Error conditions:
#    OB_BIR_INVALID_TOKEN        - Given token is not valid
#	 OB_BIR_PLACED_EARLY         - Attempting to place the bet before the delay is up
#	 OB_BIR_PLACED_LATE          - Attempting to place the bet after the placement window
#
# Dependencies
#

# Variables
#
namespace eval ob_bir {
	variable CFG
	variable INIT
	variable ERR

	set INIT 0
}

#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration.
#
proc ob_bir::init {} {
	variable CFG
	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	OT_LogWrite 20 {BIR: init}

	# get configuration
	array set OPT [list\
	                decrypt_key     ""\
	                decrypt_key_hex ""\
					bir_delay_span  5\
	                bir_extra       "0123456789"]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "[string toupper $c]" $OPT($c)]
	}

	# reset the errors...
	ob_bir::set_err

	# successfully initialised
	set INIT 1
}


#--------------------------------------------------------------------------
# ob_bir::is_bir_event
#--------------------------------------------------------------------------
#
# Are any of the given selns part of a BIR event
# ev_oc_ids - The selection ids forming the bet.
# data_arr  - Name of an array which holds the relevant data
#             if using default MSEL then must call mult_get_selns
#             and have MSEL in callers scope.
#
# return 1 if one part of BIR event, 0 otherwise
#
proc ob_bir::is_bir_event {ev_oc_ids {data_arr OB_placebet::MSEL}} {
	upvar $data_arr DATA

	foreach id $ev_oc_ids {
		if {$id == -1} continue

		if {$DATA($id,bir_started) == "Y"} {
			return 1
		}
	}
	return 0
}


#--------------------------------------------------------------------------
# ob_bir::get_delay
#--------------------------------------------------------------------------
#
# Get total delay required for the given selns
# ev_oc_ids  - The selection ids forming the bet.
# data_arr   - Name of an array which holds the relevant data
#              if using default MSEL then must call mult_get_selns
#              and have MSEL in callers scope.
# init_delay - Initial delay value. If there are any other app/cust specific
#              factors which can affect the min delay time then pass a value
#              here and the returned delay will always be greater or equal
#              to it.
#
# returns the required delay in seconds (may be zero seconds - ie no delay)
#
proc ob_bir::get_delay {ev_oc_ids {data_arr OB_placebet::MSEL} {init_delay 0}} {
	upvar $data_arr DATA

	set min_delay [expr {($init_delay > 0) ? $init_delay : {0}}]

	foreach id $ev_oc_ids {
		if {$id == -1} continue

		if {$DATA($id,bir_started) == "Y"} {
			if {$DATA($id,bir_delay) > $min_delay} {
				set min_delay $DATA($id,bir_delay)
			}
		}
	}
	return $min_delay
}



#--------------------------------------------------------------------------
# ob_bir::get_bir_index
#--------------------------------------------------------------------------
# Returns the current bir index for a selection.
#
# ev_oc_id - selection id
# data arr - a data array holding the data
#
# returns the current bir index
#
proc ob_bir::get_bir_index {ev_oc_id {data_arr OB_placebet::MSEL}} {
	upvar $data_arr DATA

	set bir_index ""

	if {[info exists DATA($ev_oc_id,bir_index)]} {
		set bir_index $DATA($ev_oc_id,bir_index)
	}

	return $bir_index
}



#--------------------------------------------------------------------------
# ob_bir::get_token
#--------------------------------------------------------------------------
#
# Generate a token for the given delay (in seconds)
# delay - The required delay in seconds.
#
# returns the token
#
proc ob_bir::get_token {delay} {
	return [ob_bir::generate_timestamp $delay]
}


#--------------------------------------------------------------------------
# ob_bir::valid_token
#--------------------------------------------------------------------------
#
# Does the given token have the correct format and have we delayed long enough
# token - The token to check.
#
# returns 1 if we've delayed long enough, 0 otherwise. If 0 is returned then an
# error condition is available via ob_bir::get_err.
#
proc ob_bir::valid_token {token} {

	set timestamps [ob_bir::check_timestamp $token]

	# Error decoding the token...
	if {$timestamps == ""} {
		ob_bir::set_err OB_BIR_INVALID_TOKEN
		return 0
	}

	set timestamps [split $timestamps |]
	set min_timestamp [lindex $timestamps 0]
	set max_timestamp [lindex $timestamps 1]

	set current [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	if {$min_timestamp == {0} || $max_timestamp == {0}} {
		ob_bir::set_err OB_BIR_INVALID_TOKEN

	} elseif {$current < $min_timestamp} {
		ob_bir::set_err OB_BIR_PLACED_EARLY

	} elseif {$current > $max_timestamp} {
		ob_bir::set_err OB_BIR_PLACED_LATE

	} else {
		return 1
	}
	return 0
}


#--------------------------------------------------------------------------
# ob_bir::set_err
#--------------------------------------------------------------------------
#
# Sets an error condition (no param effectively resets the error condition)
#
proc ob_bir::set_err {{code ""}} {
	variable ERR
	set ERR(code) $code
}


#--------------------------------------------------------------------------
# ob_bir::get_err
#--------------------------------------------------------------------------
#
# returns the current error condition (empty string if no error).
#
proc ob_bir::get_err {} {
	variable ERR
	return $ERR(code)
}

#--------------------------------------------------------------------------
# Internal Functions
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
# Check timestamp
#--------------------------------------------------------------------------

# Checks the BIR timestamp to see if it's a valid format
#
#   timestamp - the timestamp to check
#   returns   - min and max valid times
#              or an empty string if timestamp is invalid
#
proc ob_bir::check_timestamp {timestamp} {
	variable CFG

	# check that timestamp contains more than one hex char...
	if ![regexp {^[[:xdigit:]]+$} $timestamp] {
		OT_LogWrite 2 "BIR timestamp '$timestamp' is not valid - is \"\" or contains non-hex chars"
		return ""
	}

	set ts $timestamp

	# Get the crypt key
	if {$CFG(decrypt_key_hex) == ""} {
		set key_type bin
		set crypt_key $CFG(decrypt_key)
	} else {
		set key_type hex
		set crypt_key $CFG(decrypt_key_hex)
	}

	# Decrypt timestamp
	set ts [hextobin [blowfish decrypt -$key_type $crypt_key -hex $ts]]

	# Extract seed
	set seed [string range $ts [expr {[string length $ts] - 3}] end]
	set seed [string trimleft $seed "0"]
	set ts [string range $ts 0 [expr {[string length $ts] - 4}]]
	if {! [regexp {^[0-9]+$} $seed]}  {
		OT_LogWrite 2 "BIR timestamp $timestamp is not valid - seed is $seed"
		return ""
	}

	# Unshuffle timestamp
	for {set n 0} {$n < $seed} {incr n}  {
		# Swap first and 2nd chars
		set ts "[string index $ts 1][string index $ts 0][string range $ts 2 end]"
		# Move last char to start
		set len [string length $ts]
		set ts "[string index $ts [expr {$len - 1}]][string range $ts 0 [expr {$len-2}]]"
	}

	# Remove extra digits and check they are correct
	set extra [string range $ts [expr {[string length $ts] - 10}] end]
	set ts [string range $ts 0 [expr {[string length $ts] - 11}]]
	if {$extra != $CFG(bir_extra)}  {
		OT_LogWrite 2 "BIR timestamp $timestamp is not valid - extra digits are $extra"
		return ""
	}

	return $ts
}


#--------------------------------------------------------------------------
# Generate timestamp
#--------------------------------------------------------------------------

# Generates a new BIR timestamp
#
#   bir_delay - time from now when bet can be placed
#   returns   - BIR timestamp
#
proc ob_bir::generate_timestamp {bir_delay} {
	variable CFG

	set ts [clock format [expr {$bir_delay + [clock seconds] -1}] -format "%Y-%m-%d %H:%M:%S"]
	set ts "$ts|[clock format [expr {$bir_delay + $CFG(bir_delay_span) + [clock seconds] -1}] -format "%Y-%m-%d %H:%M:%S"]"

	# Need to shuffle it before encrypting it, otherwise pattern is too obvious
	# Also add in some extra digits which will act as an integrity check before shuffling.
	append ts $CFG(bir_extra)
	set seed [expr {20 + int(50 * rand())}]
	for {set n 0} {$n < $seed} {incr n}  {
		# Move first char to end
		set ts "[string range $ts 1 end][string index $ts 0]"
		# Swap first and 2nd chars
		set ts "[string index $ts 1][string index $ts 0][string range $ts 2 end]"
	}

	# Need to store seed as well, otherwise decoding it could be tricky
	set seed "00$seed"
	append ts [string range $seed [expr {[string length $seed] - 3}] end]

	# Get the crypt key
	if {$CFG(decrypt_key_hex) == ""} {
		set key_type bin
		set crypt_key $CFG(decrypt_key)
	} else {
		set key_type hex
		set crypt_key $CFG(decrypt_key_hex)
	}

	# Encrypt shuffled timestamp
	set ts [blowfish encrypt -$key_type $crypt_key -bin $ts]
	return $ts
}

# Initialise
ob_bir::init
