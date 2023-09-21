# $Id: validate.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Utilities which focus on data validation
#
# Synopsis:
#     package require util_validate ?4.5?
#
# If not using the package within appserv, then load libOT_Tcl.so
#
# Procedures:
#    ob_chk::register            register an input validation check
#    ob_chk::get_arg             check an input argument
#    ob_chk::get_value           check a string
#    ob_chk::get_cookie          check a cookie
#    ob_chk::pwd                 check password
#    ob_chk::pin                 check PIN
#    ob_chk::integer             check integer
#    ob_chk::signed_integer      check signed integer
#    ob_chk::ipaddr              check IP address
#    ob_chk::email               check email address
#    ob_chk::dob                 check DOB
#    ob_chk::date                check date
#    ob_chk::time                check time
#    ob_chk::integer_time        check date & time
#    ob_chk::informix_date       check informix date & time
#

package provide util_validate 4.5


# Dependencies
#
package require util_date 4.5
package require util_util 4.5



# Variables
#
namespace eval ob_chk {

	variable INIT 0
	variable BAD_PWD
	variable BAD_PIN

	variable CHKS

	array set CHKS [list]

	variable RE_NULL   {^$}
	variable RE_INT    {^[+-]?[0-9]+$}
	variable RE_UINT   {^[0-9]+$}
	variable RE_MONEY  {^[0-9]+((\.[0-9][0-9]?$)|$)}
	variable RE_AZ     {^[A-Z]+$}
	variable RE_Az     {^[A-Za-z]+$}
	variable RE_ALNUM  {^[[:alnum:]_]+$}
	variable RE_ASCII  {^[\x20-\x7E]+$}
	variable RE_IPADDR {^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$}

	set BAD_PWD { SECRET PASSWORD GAMBLE WAGER PUNTER BOOKIE BOOKMAKER }
	set BAD_PIN { 0000 00000 000000 0000000 00000000 \
	              1111 11111 111111 1111111 11111111 \
	              2222 22222 222222 2222222 22222222 \
	              3333 33333 333333 3333333 33333333 \
	              4444 44444 444444 4444444 44444444 \
	              5555 55555 555555 5555555 55555555 \
	              6666 66666 666666 6666666 66666666 \
	              7777 77777 777777 7777777 77777777 \
	              8888 88888 888888 8888888 88888888 \
	              9999 99999 999999 9999999 99999999 \
	              0123 01234 012345 0123456 01234567 \
	              1234 12345 123456 1234567 12345678 }
}



# Register a new validation type
# type:         Label for the validation
# validate_op:  Feedback function that will be called on validation
# static_args:  A list of static arguments passed to the validation function
#
# the validation function will be called as follows:
#
# [$validate_op arg_to_check $static_args $variable_args]
#
proc ob_chk::register {type validate_op static_args} {

	variable CHKS

	ob_log::write INFO {ob_chk::register type=$type op=$validate_op args=$static_args}

	if {[info exists CHKS($type,validate_op)]} {
		error "Trying to register check $type.  Already exists"
	}

	set CHKS($type,validate_op) $validate_op
	set CHKS($type,static_args) $static_args
}



# ob_chk::get_arg input_arg \
#                 ?-default value?\
#                 ?-on_err value?\
#                 ?-unsafe?\
#                 ?-multi?\
#                 ?-err_msg error_string?\
#                 ?-err_list err_list?\
#                 ?-val_list \
#                 ?-pp / -preprocess trimws|rmallspace|num|none?\
#                 ?-value?\
#                 ?--?
#                 chk1 chk2 ... chkN
#
# input_arg:  The arg from the HTTP request.
#
# default:    Default value (can't use with -multi).
#
# on_err:     If err, return this value
#
# unsafe:     Will call reqGetArg with the -unsafe flag
#
# multi:      Will call reqGetArgs and return a list of args matching the name
#
# err_msg:    The error that is thrown or added to the error list
#             on a check failure
#
# err_list:   If supplied the error will not be thrown but instead
#             appended to this list.
#             List has to be in the scope of the calling function.
#
# val_list:   Indicate that the checks are passed in as a list.
#
# preprocess: Processing of the input string before it is checked.
#
# value:      input_arg passed in is the value to check not
#             [reqGetArg input_arg]
#
# chkN:       Check to perform on the input_arg
#             Has the form {CHECK_NAME ?-arg1 val1? ?-arg2 val2? ...
#                                      ?-argN valN?}
#             CHECK_NAME:    Identifier of the check.
#             Possible values for argN are:
#                      args:    valN represents a list of arguments that will be
#                               sent to the verification function.
#                               Only certain verification function, such as RE and EXACT,
#                               will use these parameters
#                      min_num: valN is a number.
#                               input_arg would have to be greater or equal to valN
#                      max_num: valN is a number.
#                               input_arg would have to be less than or equal to valN
#                      min_str: valN is an integer.
#                               The length of the input string would need to be at
#                               least valN
#                      max_str: valN is an integer.
#                               The length of the input string would need to be at
#                               most valN
#
# Examples:
#
# Retrieve a parameter "ev_oc_id" that we expect to be a positive integer
# % set ev_oc_id [ob_chk::get_arg "ev_oc_id" UINT]
#
# Retrieve the optional form field "amount".  Do not throw an error on
# failure.
# % set errors [list]
# % set amount [ob_chk::get_arg "amount" -err_list errors NULL MONEY]
#
# Retrieve a manadatory "accept_TNC".  Add a pre-defined error to the list
# on failure:
# % set errors [list]
# % set msg "Please accept the Terms and Conditions"
# % set tnc [ob_chk::get_arg "accept_TNC"\
#               -err_list errors -err_msg $msg\
#               {EXACT -args {"Y" "N"}}]
#
# Retrieve an optional "day" field - trim off any leading zeros
# % set day [ob_chk::get_arg "day" -pp num NULL {UINT -min_num 1 -max_num 31}]
#
# Check a value $ev_oc_id parsed from a cookie string
# % set ev_oc_id [ob_chk::get_arg $ev_oc_id -is_value 1 UINT]
#
# Retrieve an optional "max_deposit" field that can be a monetary value or
# the string "NO_LIMIT".  Trim any zeros if a monetary value. The monetary
# value needs to be between 10 and 10,000
# % set max_deposit [ob_chk::get_arg "max_deposit" -pp num\
#                       NULL\
#                       {EXACT -args "NO_LIMIT"}\
#                       {MONEY -min_num 10 -max_num 10000}]
#
proc ob_chk::get_arg { input_arg args } {
	set safe_flag    -safe
	set is_value     0
	set is_multi     0

	set idx 0
	foreach arg $args {
		switch -exact -- $arg {
			"-unsafe" {set safe_flag -unsafe}
			"-value"  {set is_value 1}
			"-multi"  {set is_multi 1}
			"-default" {set default [lindex $args [expr {$idx+1}]]}
			"--"      {break}
		}
		incr idx
	}

	# Legacy handling for people calling get_arg to validate a value
	if {$is_value} {
		ob_log::write INFO {'ob_chk::get_arg -value' is deprecated - please use ob_chk::get_value}
		return [eval ob_chk::_check_value {$input_arg} $args]
	}

	set arg_list [reqGetArgs $safe_flag $input_arg]

	# If we're only expecting a single value, only use the first item in the list
	if {!$is_multi} {
		# use default if one is supplied and no arguments were found
		if {[info exists default] && [llength $arg_list] == 0} {
			set arg_list $default
		} else {
			set arg_list [list [lindex $arg_list 0]]
		}
	}

	set ret_list [list]
	foreach arg $arg_list {
		lappend ret_list [eval ob_chk::_check_value {$arg} $args]
	}

	# If they only wanted 1 item, only return that item
	if {!$is_multi} {
		return [lindex $ret_list 0]
	}

	return $ret_list
}

proc ob_chk::get_value { value args } {
	return [eval ob_chk::_check_value {$value} $args]
}

proc ob_chk::get_cookie { cookie_name args } {
	# _check_value defaults to converting to/from utf8 which screws with cookie
	# so we need to disable it.
	set args [concat -no_utf8 $args]
	set cookie_value [ob_util::get_cookie $cookie_name]
	return [eval ob_chk::_check_value {$cookie_value} $args]
}

#
# The artist formerly known as ob_chk::get_arg.
# This function takes a string, processes it, validates it and sanitises it.
# Please use one of the following wrapper functions:
#   ob_chk::get_value  - Validating a string
#   ob_chk::get_cookie - Validating a cookie
#   ob_chk::get_arg    - Validating an arg from the current HTTP request
#
proc ob_chk::_check_value { input_str args } {

	variable CHKS

	# arg_state: Holds the state of the next argument we're expecting to read.
	# FLAG:           An optional flag
	# FLAG_VAL:       The value of a flag
	# UPVAR_FLAG_VAL: The value of a flag to be evaluated one level up the stack
	# CHECKS:         Reading argument checks
	set arg_state "FLAG"

	# Defaults
	set err_msg      ""
	set use_err_list 0
	set unsafe       0
	set is_utf8      1
	set val_list     0
	set preprocess   "trimws"
	set checks       [list]
	set default      ""

	if {[llength $args] < 1} {
		error "ob_chk::get_arg - No check types supplied."
	}

	# Process the input arguments:

	foreach arg $args {

		if {$arg_state == "FLAG"} {
			switch -exact -- $arg {
				"-unsafe" {}
				"-value"  {}
				"-multi"  {}
				"-utf8"   {set is_utf8 1}
				"-no_utf8" {set is_utf8 0}
				"-err_msg" {
					set flag_var err_msg
					set arg_state "FLAG_VAL"
				}
				"-preprocess" -
				"-pp" {
					set flag_var preprocess
					set arg_state "FLAG_VAL"
				}
				"-default" {
					set flag_var default
					set arg_state "FLAG_VAL"
				}
				"-on_err" {
					set flag_var on_err
					set arg_state "FLAG_VAL"
				}
				"-err_list" {
					set use_err_list 1
					set flag_var err_list
					set arg_state "UPVAR_FLAG_VAL"
				}
				"-val_list" {
					set val_list 1
				}
				"--" {
					set arg_state "CHECKS"
					continue
				}
				default {
					set arg_state "CHECKS"
				}
			}
		} elseif {$arg_state eq "FLAG_VAL"} {
			set $flag_var $arg
			set arg_state "FLAG"
		} elseif {$arg_state eq "UPVAR_FLAG_VAL"} {
			upvar 2 $arg $flag_var
			set arg_state "FLAG"
		}

		if {$arg_state eq "CHECKS"} {
			lappend checks $arg
		}
	}

	# End of optional arguments.
	# If the validation rules have been passed in one list the pull them out
	if {$val_list} {
		set checks [lindex $checks 0]
	}

	if {!([info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) eq "UTF-8") && $is_utf8} {
		# AS_CHARSET is not on. We need to apply any validation regexs
		# to nicely formed tcl strings. This is not ideal. We really
		# want to turn AS_CHARSET on but there are other implications

		set input_str [encoding convertfrom utf-8 $input_str]
	}

	# Pre-process the string; stripping unwanted characters.
	switch -- $preprocess {
		"trimws" {
			set input_str [string trim $input_str]
		}
		"rmallspace" {
			regsub -all {\s+} $input_str {} input_str
		}
		"num" {
			set input_str [_clean_num $input_str]
		}
		"none"       -
		default      {}
	}

	# Check the argument.
	set err [list]

	foreach chk $checks  {
		set chk_name      [lindex $chk 0]

		set further_chks  [list]
		set variable_args [list]

		foreach {n v} [lrange $chk 1 end] {
			if {$n eq "-args"} {
				set variable_args $v
			} else {
				lappend further_chks  $n $v
			}
		}

		if {![info exists CHKS($chk_name,validate_op)]} {
			error "Unknown check type $chk_name"
		}

		set validate_op $CHKS($chk_name,validate_op)
		set static_args $CHKS($chk_name,static_args)

		set ok [$validate_op $input_str $static_args $variable_args]

		if {!$ok} {
			lappend err $chk_name
			continue
		}

		foreach {n v} $further_chks {

			set fail 0
			switch -exact -- $n {
				"-min_num" {
					if {$input_str < $v} {set fail 1}
				}
				"-max_num" {
					if {$input_str > $v} {set fail 1}
				}
				"-min_str" {
					if {[string length $input_str] < $v} {set fail 1}
				}
				"-max_str" {
					if {[string length $input_str] > $v} {set fail 1}
				}
				default {
					error "Unknown further check $n"
				}
			}

			if {$fail} {
				set ok 0
				lappend err $n
			}
		}

		if {$ok} {

			# The input arg has passed the check
			break
		}
	}

	# Deal with the error
	if {!$ok} {

		if {$err_msg != ""} {
			set err $err_msg
		}

		# We now have three choices on how to handle the error
		# 1. Throw it
		# 2. Append it to a passed in error list - see use_err_list
		# 3. Substitute it for a default value   - see on_err

		if {$use_err_list} {
			lappend err_list $err
			if {[info exists on_err]} {
				set input_str $on_err
			}
		} elseif {[info exists on_err]} {
			# Don't throw the error
			set input_str $on_err
		} else {
			# Throw the error
			error $err
		}
	}

	if {!([info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) eq "UTF-8") && $is_utf8} {
		# We need to convert back in order to be consistent with
		# the rest of the system

		set input_str [encoding convertto utf-8 $input_str]
	}

	return $input_str
}



# Check a password.and username
# Password must match a verification
# pwd, not equal to a username and does not equal to any easy guess words.
# pwd1 between 6 - 15 characters
# username between 6 - 15 characters
# pwd and username only contain alphanumeric characters
#
#   pwd1     - password to check (unencrypted)
#   pwd2     - verification pwd
#   username - username
#   returns  - status string (OB_OK denotes success)
#
proc ob_chk::pwd { pwd1 pwd2 username } {

	variable RE_ALNUM
	variable BAD_PWD

	set errs [list]

	# If case insensitive passwords, then make all uppercase
	if {[OT_CfgGet CUST_PWD_CASE_INSENSITIVE 0]} {
		set pwd1         [string toupper $pwd1]
		set pwd2         [string toupper $pwd2]
	}

	# If password and username the same
	if {[string toupper $pwd1] == [string toupper $username]} {
		lappend errs REG_ERR_VAL_PWDUSERNAME
	}

	if {[OT_CfgGet ALLOW_SPECIFIED_USERNAME 0]} {
		# If username incorrect length
		set length [string length $username]
		if {$length < 6 || $length > 15} {
			lappend errs REG_ERR_USERNAME_LEN
		}
	}

	# If passwords do not match
	if {$pwd1 != $pwd2} {
		lappend errs REG_ERR_VFY_PASSWORD
	}

	# If password is too easy to guess
	if {[lsearch $BAD_PWD [string toupper $pwd1]] >= 0} {
		lappend errs REG_ERR_VAL_EASYPWD
	}

	# If password incorrect length
	set length [string length $pwd1]
	if {$length < 6 || $length > 15} {
		lappend errs REG_ERR_CUST_PWD_LEN ;#in DB and xlations.sql
	}

	# If password contains bad characters
	if {![regexp $RE_ALNUM $pwd1]} {
		lappend errs REG_ERR_PASSWORD
	}

	if {$errs == ""} {
		return OB_OK
	} else {
		return $errs
	}
}



# Check if a valid integer.
#
#   int     - integer to check
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::integer { int } {

	variable RE_UINT

	if {![regexp $RE_UINT $int]} {
		return OB_ERR_VAL_BAD_INT
	}

	return OB_OK
}



# Check if a valid signed integer (+|-).
#
#   int     - integer to check
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::signed_integer { int } {

	variable RE_INT

	if {![regexp $RE_INT $int]} {
		return OB_ERR_VAL_BAD_INT
	}

	return OB_OK
}



# Check a PIN.
# PIN and PIN verify must be the same
# and not equal to any easy guess PINs.
#
#   pin1     - PIN to check (unencrypted)
#   pin2     - verification PIN
#   returns  - status string (OB_OK denotes success)
#
proc ob_chk::pin { pin1 pin2 } {

	variable BAD_PIN

	if {$pin1 != $pin2} {
		return OB_ERR_VAL_DIFFPIN
	}

	if {[lsearch $BAD_PIN $pin1] >= 0} {
		return OB_ERR_VAL_EASYPIN
	}

	return OB_OK
}



# Check an email address.
#
#   email     - email address to check
#   strict    - performs a slightly strictier regexp, requires both @ and .
#               default (N)
#   If EMAIL_CHECK_ENHANCED flag is set then calls ob_chk::email_enhanced
#   returns   - status string (OB_OK denotes success)
#
proc ob_chk::email {email {strict N} } {
	if { [OT_CfgGet EMAIL_CHECK_ENHANCED 0]} {
		return [ob_chk::email_enhanced $email]
	} else {

		if {$strict == "Y"} {
			set re {^[^@]+\@([-a-zA-Z0-9]+\.)+[a-zA-Z]+$}
		} else {
			set re {^[^@]+\@([-a-zA-Z0-9]+\.)*[a-zA-Z]+$}
		}

		if {![regexp $re $email]} {
			return OB_ERR_VAL_BAD_EMAIL
		}

		return OB_OK

	}
}

# More stringent check of an email address
#
#   email     - email address to check
#   returns   - status string (OB_OK denotes success)
#

proc ob_chk::email_enhanced {email} {
	set emailparts [split $email @]
	if {[llength $emailparts] != 2} {
		return OB_ERR_VAL_BAD_EMAIL
	}

	set part1 [lindex $emailparts 0]
	set part2 [lindex $emailparts 1]
	if {[string length $part1] > 64 || [string length $part2] > 255} {
		return OB_ERR_VAL_BAD_EMAIL
	}

	# local part
	set atext {[A-Za-z0-9\x27\x2f!#$%&*+=?^_`{|}~-]}
    	set local_part [subst {$atext+\(.$atext+\)*}]

	# domain part
	set dchar {a-zA-Z0-9}
	set dtext [subst {(\[$dchar\]\[$dchar-\]{0,61}\[$dchar\]|\[$dchar\]{1,63})}]

	set domain_part [subst {$dtext\(.$dtext\)*\\.\[$dchar\]{2,63}}]

	# combined
	set re [subst {^\($local_part\)@\($domain_part\)$}]

	if {![regexp $re $email]} {
		return OB_ERR_VAL_BAD_EMAIL
	}

	return OB_OK
}




# Check date-of-birth.
# DOB must be valid date and 18+
#
#   year    - year
#   month   - month
#   day     - day
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::dob { year month day } {

	set year  [string trimleft $year 0]
	set month [string trimleft $month 0]
	set day   [string trimleft $day 0]

	set status [_date $year $month $day]
	if {$status != "OB_OK"} {
		return $status
	}

	# over 18?
	set d [clock format [clock seconds] -format %Y-%m-%d]
	foreach {y m d} [split $d -] {
		set curr_year  [string trimleft $y 0]
		set curr_month [string trimleft $m 0]
		set curr_day   [string trimleft $d 0]
	}
	set diff [expr {$curr_year - $year}]
	if {$diff < 18 || ($diff == 18 && $curr_month < $month) || \
		        ($diff == 18 && $curr_month == $month && $curr_day < $day)} {
		return OB_ERR_VAL_NOT18
	}

	return OB_OK
}



# Check a date.
#
#   date    - date to check
#   fmt     - date format (default: DDMMYYYY)
#             YYYYMMDD
#             DDMMYYYY
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::date { date {fmt DDMMYYYY} } {

	if {($fmt == "YYYYMMDD" && ![regexp {^(....)(..)(..)$} $date all y m d]) ||\
	    ($fmt != "YYYYMMDD" && ![regexp {^(..)(..)(....)$} $date all d m y])} {
		return OB_ERR_VAL_BAD_DATE
	}

	return [_date [string trimleft $y 0] [string trimleft $m 0]\
	        [string trimleft $d 0]]
}



# Private procedure to check a date
#
#   year    - year
#   month   - month
#   day     - day
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::_date { year month day } {

	# must be a 4 digit year!
	if {[integer $year] != "OB_OK" || $year <= 0 || \
		        [string length $year] != 4} {
		return OB_ERR_VAL_BAD_YEAR
	}
	if {[integer $month] != "OB_OK" || $month <= 0 || $month > 12} {
		return OB_ERR_VAL_BAD_MONTH
	}
	if {[integer $day] != "OB_OK" || \
		        [ob_date::days_in_month $month $year] < $day} {
		return OB_ERR_VAL_BAD_DAY
	}

	return OB_OK
}



# Check a time (HH:MM:SS)
#
#   time    - time to check
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::time { time } {

	if {![regexp {^(..):(..):(..)$} $time all hour min sec]} {
		return OB_ERR_VAL_BAD_TIME
	}

	return [_time $hour $min $sec]
}



# Private procedure to check a time (HH:MM:SS)
#
#   time    - time to check
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::_time { hour min sec } {

	# check hour, minute & second
	if {[integer $hour] != "OB_OK" || $hour > 23} {
		return OB_ERR_VAL_BAD_HOUR
	}
	if {[integer $min] != "OB_OK" || $min > 59} {
		return OB_ERR_VAL_BAD_MINUTE
	}
	if {[integer $sec] != "OB_OK" || $sec > 59} {
		return OB_ERR_VAL_BAD_SECOND
	}

	return OB_OK
}



# Check date & time when represented as a system-dependent integer value.
# Value is usually defined as total elapsed time from an 'epoch'
#
#   seconds - elapsed time from an 'epoch'
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::integer_time { seconds } {

	if {[signed_integer $seconds] != "OB_OK"} {
		return OB_ERR_VAL_BAD_INTEGER_TIME
	}

	return OB_OK
}



# Check an Informix formatted date (YYYY-MM-DD HH:MM:SS by default)
#
#   date    - informix formatted date
#   fmt  - long or short. short = without the time
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::informix_date { date {fmt "long"}} {

	if {$fmt == "short"} {
		if {![regexp {^(....)-(..)-(..)$} $date all y m d]} {
			return OB_ERR_VAL_BAD_INFORMIX_DATE
		}
		# check the date
		if {[eval {set s [_date $y $m $d]}] != "OB_OK"} {
			return $s
		}

	} else {
		if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $date all y m d H M S]} {
			return OB_ERR_VAL_BAD_INFORMIX_DATE
		}
		# check the date and time
		if {[eval {set s [_date $y $m $d]}] != "OB_OK" ||\
					[eval {set s [_time $H $M $S]}] != "OB_OK"} {
			return $s
		}
	}

	return "OB_OK"
}



# Validate a Swift(BIC) banking codes.
#
#   swift_code - BIC (swift) banking code is "should" be in the format:
#       DEUT       DE            FF             123
#       [bank code][country code][location code][branch code]
#       [A-Z]      [A-Z]         [A-Z1-9]       [A-Z0-9]
#   return - success(0/1)
#
proc ob_chk::swift {swift_code} {
	# Check its of the correct format.
	if {[regexp {^[A-Z]{6}[A-Z1-9]{2}([A-Z0-9]{3})?$} $swift_code]} {
		return OB_OK
	} else {
		return OB_ERR_VAL_BAD_SWIFT
	}
}



# Validate a IBAN banking code.
#   iban_code - IBAN banking code is "should" be in the format:
#       [country code][checksums][country specific account numbers]
#   return - success(0/1)
#
proc ob_chk::iban {iban_code} {
	# Break apart the IBAN string.
	set country_code [string range $iban_code 0 1]
	set chk_sum      [string range $iban_code 2 3]
	set reg_num      [string range $iban_code 4 end]

	# Move first 4 chars to the end of the string for validation.
	set iban_chk_str "${reg_num}${country_code}${chk_sum}"

	# Convert letters to number representation.
	# Convert char codes to a=10, b=11, c=12 etc...
	set iban_chk_no {}
	for {set i 0} {$i < [string length $iban_chk_str]} {incr i} {
		# Get letter in upper case.
		set cur_char [string toupper [string range $iban_chk_str $i $i]]

		if {![string is digit $cur_char]} {
			scan $cur_char "%c" ascii_ccode
			# a=10, b=11, c=12 etc... so minus 55 from its ascii value.
			set iban_chk_no "${iban_chk_no}[expr {$ascii_ccode - 55}]"
		} else {
			set iban_chk_no "${iban_chk_no}${cur_char}"
		}
	}

	# Remove the leading zeros we don't need these.
	set iban_chk_no [string trimleft $iban_chk_no "0"]

	# Do [expr {iban_chk_no % 97}] number to big to do this.
	#   So do old school long division.
	set idx      0
	set rmdr     [string range $iban_chk_no 0 0]
	while {$idx < [string length $iban_chk_no]} {
		if {$rmdr >= 97} {
			set rmdr [expr {$rmdr % 97}]
		} else {
			incr idx
			set rmdr "[expr {$rmdr ? $rmdr : ""}][string range $iban_chk_no $idx $idx]"
		}
	}

	# If the remainder is '1' then it is valid.
	if {$rmdr == 1} {
		return OB_OK
	} else {
		return OB_ERR_VAL_BAD_IBAN
	}
}



#--------------------------------------------------------------------------
# Validation Utilities
#--------------------------------------------------------------------------

# Check if mandatory text has been supplied.
# The text must be supplied and bigger than min' (unless set to 0) and less
# then max (unless set to 0). Also checks if text contains any un-safe
# characters (see ob_util::is_safe)
#
#   str     - string to check
#   min     - min string length (default 0, which case do not check)
#   max     - max string length (default 0, which case do not check)
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::mandatory_txt { str {min 0} {max 0} } {

	if {$str == ""} {
		return OB_ERR_VAL_EMPTY_STR
	}

	return [optional_txt $str $min $max]
}



# Check if optional text.
# If text is supplied, then it must not contains any un-safe characters
# (see ob_util::is_safe) and bigger than min' (unless set to 0) and less
# then max (unless set to 0).
# If no text is supplied, no checks are made.
#
#   str     - string to check
#   min     - min string length (default 0, which case do not check)
#   max     - max string length (default 0, which case do not check)
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::optional_txt { str {min 0} {max 0} } {

	if {$str != ""} {

		set len [string length $str]
		if {$min > 0 && $len < $min} {
			return OB_ERR_VAL_MIN_STR
		}
		if {$max > 0 && $len > $max} {
			return OB_ERR_VAL_MAX_STR
		}
		if {![ob_util::is_safe $str]} {
			return OB_ERR_VAL_UNSAFE_STR
		}
	}

	return OB_OK
}



# Check if a monetary value is valid.
# The amount must either be a zero, one or two decimal placed number.
#
#   amount  - amount to check
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::money { amount } {

	variable RE_MONEY

	if {![regexp $RE_MONEY $amount]} {
		return OB_ERR_VAL_BAD_MONEY
	}

	return OB_OK
}



# Check if a valid IP address.
#
#   ip      - IP address to check
#   returns - status string (OB_OK denotes success)
#
proc ob_chk::ipaddr { ip } {

	variable RE_IPADDR

	if {![regexp $RE_IPADDR $ip]} {
		return OB_ERR_VAL_BAD_IP
	}

	return OB_OK
}



# Initiates the package
#
proc ob_chk::init {} {

	variable RE_NULL
	variable RE_INT
	variable RE_UINT
	variable RE_MONEY
	variable RE_AZ
	variable RE_Az
	variable RE_ALNUM
	variable RE_ASCII
	variable RE_IPADDR
	variable INIT

	if {$INIT != 0} {
		return
	}

	# General
	register "NULL"   ob_chk::_re     $RE_NULL
	register "EXACT"  ob_chk::_exact  {}
	register "RE"     ob_chk::_re     {__use_custom__}
	register "SAFE"   ob_chk::_safe   {}
	register "FORBID" ob_chk::_forbid {}

	# Numbers
	register "DIGITS" ob_chk::_re     $RE_UINT
	register "UINT"   ob_chk::_num    $RE_UINT
	register "INT"    ob_chk::_num    $RE_INT
	register "MONEY"  ob_chk::_num    $RE_MONEY

	# Dates
	register "INF_DATE"        ob_chk::_test_inf_date {}
	register "INF_SHORT_DATE"  ob_chk::_test_inf_shortdate {}

	# Strings
	register "AZ"     ob_chk::_re     $RE_AZ
	register "Az"     ob_chk::_re     $RE_Az
	register "ALNUM"  ob_chk::_re     $RE_ALNUM
	register "ASCII"  ob_chk::_re     $RE_ASCII

	# Idents
	register "EMAIL"           ob_chk::_email  {}

	# Networks
	register "IPADDR" ob_chk::_re     $RE_IPADDR

	# Banking
	register "IBAN"   ob_chk::_iban   {}
	register "SWIFT"  ob_chk::_swift  {}

	set INIT 1
}



# Checks args against a regular expression.
#
proc ob_chk::_re {input_arg re alt_re} {

	if {$re eq "__use_custom__"} {
		set re $alt_re
	}

	if {[regexp $re $input_arg]} {
		return 1
	} else {
		return 0
	}
}



# Checks number
#
proc ob_chk::_num {input_arg num_re variable_ignored} {

	if {![regexp $num_re $input_arg]} {
		return 0
	}

	# Check there are no leading characters
	if {$input_arg != [_clean_num $input_arg]} {
		return 0
	}

	return 1
}



# Checks arg against a known list of values.
#
proc ob_chk::_exact {input_arg static_ignored match_list} {

	if {[lsearch -exact $match_list $input_arg] != -1} {
		return 1
	} else {
		return 0
	}
}


#
# Checks arg against a list of forbidden values
#
proc ob_chk::_forbid {input_arg static_ignored match_list} {

	return [expr {![_exact $input_arg $static_ignored $match_list]}]
}



# Check the srtring doesn't have rogue characters.
#
proc ob_chk::_safe {input_arg static_ignored variable_ignored} {

	if {$input_arg eq ""} {
		return 0
	}

	return [ob_util::is_safe $input_arg]
}



# Wrapper for ob_chk::email - registered as an
# argument checking routine.
#
proc ob_chk::_email {input_arg strict variable_ignored} {

	if {$strict == ""} {
		set strict "N"
	}

	if {[ob_chk::email $input_arg $strict] eq "OB_OK"} {
		return 1
	} else {
		return 0
	}
}


# Wrapper for ob_chk::iban - registered as an
# argument checking routine.
#
proc ob_chk::_iban {iban static_ignored variable_ignored} {

	if {[ob_chk::iban $iban] eq "OB_OK"} {
		return 1
	} else {
		return 0
	}
}



# Wrapper for ob_chk::swift - registered as an
# argument checking routine.
#
proc ob_chk::_swift {swift static_ignored variable_ignored} {

	if {[ob_chk::swift $swift] eq "OB_OK"} {
		return 1
	} else {
		return 0
	}
}

# Wrapper for ob_chk::informix_date - registered as an
# argument checking routine.
#
proc ob_chk::_test_inf_date {input_arg static_ignored variable_ignored} {

	if {[informix_date $input_arg] != "OB_OK" } {
		return 0
	}

	return 1
}

# Wrapper for ob_chk::informix_date - registered as an
# argument checking routine.
#
proc ob_chk::_test_inf_shortdate {input_arg static_ignored variable_ignored} {

	if {[informix_date $input_arg "short"] != "OB_OK" } {
		return 0
	}

	return 1
}

# _clean_num:  Removes leading zeros/spaces/+ from a number
#
proc ob_chk::_clean_num {str} {

	if {![regexp {^\s*\+?(-?)([0-9.]+)\s*$} $str -> sign num]} {
		# Not a valid number
		return $str
	}

	if {[regexp {^0+\.?$} $num]} {
		set num 0
	} else {
		set num [string trimleft $num "0"]
	}

	return "$sign$num"
}


# Test
#
proc ob_chk::_test {} {
	global test_args

	set test_args(int)            "1234"
	set test_args(strip_int)      "    +001234  "
	set test_args(neg_int)        "-123"
	set test_args(illegal_int)    "23a"
	set test_args(money)          "1234"
	set test_args(strip_money)    "   001234.12  "
	set test_args(money2)         "12.30"
	set test_args(illegal_money)  "12.303"
	set test_args(illegal_money2) "1.2.3"
	set test_args(AZ)             "GBP"
	set test_args(AZ_strip)       "  GBP "
	set test_args(AZ_illegal)     "GBp"
	set test_args(Az)             "zzGBP"
	set test_args(Az_illegal)     "GB p "
	set test_args(yes)            "Y"
	set test_args(no)             "N"
	set test_args(price_type)     "ODDS"
	set test_args(ps1)            "AS,ERT"
	set test_args(ps2)            "AS,ERTDF"
	set test_args(valid_email)    "bob@asda.com"
	set test_args(invalid_email)  "bobasda.com"
	set test_args(valid_iban)     "IT85AUNWFC32843910536086263"
	set test_args(invalid_iban)   "IT62AUNWFC32843910536086263"
	set test_args(valid_bic)      "IGNKITUDXXX"
	set test_args(invalid_bic)    "IGNKITUDXXX12"

	proc reqGetArg args {
		global test_args

		set arg [lindex $args end]
		if {[info exists test_args($arg)]} {
			return $test_args($arg)
		} else {
			return ""
		}
	}

	foreach {input_arg valid_op} {
		int            INT
		strip_int      INT
		neg_int        INT
		illegal_int    INT
		money          MONEY
		money2         MONEY
		strip_money    MONEY
		illegal_money  MONEY
		illegal_money2 MONEY
		AZ             AZ
		AZ_strip       AZ
		AZ_illegal     AZ
		Az             Az
		Az_illegal     Az
		valid_email    EMAIL
		invalid_email  EMAIL
		valid_iban     IBAN
		invalid_iban   IBAN
		valid_bic      SWIFT
		invalid_bic    SWIFT
	} {
		foreach pp {num none trimws} {
			set err_list [list]
			set val [ob_chk::get_arg $input_arg -pp $pp -err_list err_list $valid_op]
			puts "PP=$pp before=\"$test_args($input_arg)\" after = \"$val\" errs = $err_list"
		}
	}

	set err_list [list]
	set val [ob_chk::get_arg yes -err_list err_list {EXACT -args {"Y" "N"}}]
	puts "yes = \"$val\" errs = $err_list"

	set err_list [list]
	set val [ob_chk::get_arg no -err_list err_list {EXACT -args {"Y" "N"}}]
	puts "no = \"$val\" errs = $err_list"

	set err_list [list]
	set val [ob_chk::get_arg price_type\
		-err_msg "price_type should be Y or N"\
		-err_list err_list {EXACT -args {"Y" "N"}}]
	puts "no = \"$val\" errs = $err_list"

	set err_list [list]
	set val [ob_chk::get_arg not_there -err_list err_list NULL {EXACT -args {"Y" "N"}}]
	puts "not_there = \"$val\" errs = $err_list"

	set err_list [list]
	set val [ob_chk::get_arg int -err_list err_list {INT -min_num 0 -max_num 100}]
	puts "int = \"$val\" errs = $err_list"

	set err_list [list]
	set val [ob_chk::get_arg neg_int -err_list err_list {INT -min_num 0 -max_num 100}]
	puts "neg_int = \"$val\" errs = $err_list"

	set re {^[A-Z]{2,4},[A-Z-]{2,4}$}

	set err_list [list]
	set val [ob_chk::get_arg ps1 -err_list err_list [list RE -args $re]]
	puts "ps1 = \"$val\" errs = $err_list"

	set err_list [list]
	set val [ob_chk::get_arg ps2 -err_list err_list [list RE -args $re]]
	puts "ps2 = \"$val\" errs = $err_list"
}

