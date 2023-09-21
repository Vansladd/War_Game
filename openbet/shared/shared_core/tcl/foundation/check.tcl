# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Utilities which focus on data validation
#
# Synopsis:
#     package require core::check ?1.0?
#
# If not using the package within appserv, then load libOT_Tcl.so
#
# NOTE !! - It is this file (check.tcl) that the core
#           library uses for all validation checks
#           (on arguments etc.)
#
#           (Other file validate.tcl is NOT used by core library.)
#
# This file is used by log.tcl please do not add a dependency on log.tcl in this file
#
package provide core::check 1.0

# Variables
#
namespace eval core::check {

	variable INIT 0

	variable CHKS
	array set CHKS [list]

	variable RE_CONTROL {^[\x09\x0A\x0D]*$} ;# Horizontal Tab, Line Feed, Carriage Return

	# Symbols
	#  Space - Slant (forward slash, divide)  (0x20 - 0x2F)
	#  Colon - At-sign (0x3A - 0x40)
	#  Left square bracket - Opening single quote (0x5B - 0x60)
	#  Opening curly brace - Tilde (approximate) (0x7B - 0x7E)

	variable RE_SYMBOL  {^[\x20-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]*$}

	# Numbers (U=unsigned)
	variable RE_BOOL      {^(0|1)$}
	variable RE_INT       {^[+-]?0*([0-9]+)$}
	variable RE_UINT      {^0*([0-9]+)$}
	variable RE_DECIMAL   {^[+-]?\d+(\.\d+)?$}
	variable RE_UDECIMAL  {^\d+(\.\d+)?$}
	variable RE_MONEY     {^[+-]?\d+(\.\d{1,2})?$}
	variable RE_UMONEY    {^\d+(\.\d{1,2})?$}
	variable RE_HEX       {^((?:0[xX])?(?:[0-9A-Fa-f]){2})+$}
	variable RE_BASE64    {^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$}
	variable RE_UFRACTION {^[1-9]{1}[0-9]*/[1-9]{1}[0-9]*$}

	# Strings
	# ASCII - RE_CONTROL + printable chars (Space -> Tilde (omitting Delete U+007F))
	# STR   - RE_ASCIIL  + Non-breaking space -> Hangul Jamo Extended-B, CJK Compatibility Ideographs -> Halfwidth and Fullwidth Forms
	variable RE_AZ      {^[A-Z]*$}
	variable RE_az      {^[a-z]*$}
	variable RE_Az      {^[A-Za-z]*$}
	variable RE_ALNUM   {^[[:alnum:]]*$}
	variable RE_ASCII   {^[\x09\x0A\x0D\x20-\x7E]*$}
	variable RE_STR     {^[\x09\x0A\x0D\x20-\x7E\xA0-\uD7FF\uF900-\uFFEF]*$}

	# Internet/Web Addresses

	# EMAIL - http://www.w3.org/TR/html5/forms.html#valid-e-mail-address
	variable RE_EMAIL   {^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$}
	variable RE_IPv4    {^((25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)\.){3}(25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)$}
	variable RE_IPv6    {^[A-Fa-f0-9]{4}(:[A-Fa-f0-9]{4}){7}$}

	# Private non routable addresses.
	variable RE_IPv4_A    {^10\.((25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)\.){2}(25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)$}
	variable RE_IPv4_B    {^172\.(1[6789]|2\d|3[01])\.(25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)\.(25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)$}
	variable RE_IPv4_C    {^192\.168\.(25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)\.(25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)$}
	variable RE_IPv4_LOOP {^127\.((25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)\.){2}(25[0-5]|2[0-4]\d|[01]\d\d|\d?\d)$}
	variable RE_IPv6_LOOP {^[0:]+1$}

	variable RE_DATE     {^(\d{4})-(\d{2})-(\d{2})$}
	variable RE_DATETIME {^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$}
	variable RE_TIME     {^(\d{2}):(\d{2})(:(\d{2}))?$}

	# Please note that this may not be the perfect and best fit. Please improve if there is room.
	variable RE_HTTP_HOST {^https?:\/\/(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$}

	# HTTP components.
	# Based on http://tools.ietf.org/html/rfc2616 and http://tools.ietf.org/html/rfc6265.
	variable RE_HTTP_HEADER_VALUE {^[\x09\x20-\x7E]*$}
	set http_token {^[\x21\x23-\x27\x2A\x2B\x2D\x2E\x30-\x39\x41-\x5A\x5E-\x60\x61-\x7A\x7C\x7E]+$}
	variable RE_COOKIE_NAME $http_token
	set cookie_octet {[\x21\x23-\x2B\x2D-\x3A\x3C-\x5B\x5D-\x7E]}
	variable RE_COOKIE_VALUE "^(?:(?:${cookie_octet}*)|(?:\"${cookie_octet}*\"))\$"

	# A unique ID following the RFC 4122 version 4 UUID standard.
	variable RE_UUID {^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[a-f0-9]{4}-[a-f0-9]{12}$}


}



# Initialise common checks
#
proc core::check::init {} {

	variable INIT

	if {$INIT} {
		return
	}

	# TODO - We need to have a utf8 parse

	# Register default validation types
	register "INT"               core::check::integer           {}
	register "UINT"              core::check::unsigned_integer  {}
	register "DIGITS"            core::check::unsigned_integer  {}
	register "DECIMAL"           core::check::decimal           {}
	register "UDECIMAL"          core::check::unsigned_decimal  {}
	register "MONEY"             core::check::money             {}
	register "UMONEY"            core::check::unsigned_money    {}
	register "HEX"               core::check::hex               {}
	register "BASE64"            core::check::base64            {}
	register "UFRACTION"         core::check::unsigned_fraction {}
	register "BOOL"              core::check::bool              {}
	register "ALNUM"             core::check::alnum             {}
	register "IPv4"              core::check::ipv4              {}
	register "IPv6"              core::check::ipv6              {}
	register "IPADDR"            core::check::ip                {}
	register "DATE"              core::check::date              {}
	register "DATETIME"          core::check::datetime          {}
	register "TIME"              core::check::time              {}
	register "LOOSEDATE"         core::check::loosedate         {}
	register "RE"                core::check::exp               {__ARG__}
	register "EXACT"             core::check::enum              {DUMMY}
	register "ENUM"              core::check::enum              {DUMMY}
	register "AZ"                core::check::upper_case        {}
	register "az"                core::check::lower_case        {}
	register "Az"                core::check::letters           {}
	register "EMAIL"             core::check::email             {}
	register "STRING"            core::check::is_string         {}
	register "LIST"              core::check::is_list           {}
	register "EMPTY"             core::check::exp               {^$}
	register "ASCII"             core::check::ascii             {}
	register "ANY"               core::check::any               {}
	register "NONE"              core::check::any               {}
	register "DEPRECATED"        core::check::any               {}
	register "NVPAIRS"           core::check::nvpairs           {}
	register "HTTP_HEADER_VALUE" core::check::http_header_value {}
	register "COOKIE_NAME"       core::check::cookie_name       {}
	register "COOKIE_VALUE"      core::check::cookie_value      {}
	register "HTTP_HOST"         core::check::http_host         {}
	register "UUID"              core::check::uuid              {}

	set INIT 1
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
proc core::check::register {type cmd static_args} {

	variable CHKS

	if {[info exists CHKS($type,cmd)]} {
		error "Check $type is already registered" {} CHECK_EXISTS
	}

	set CHKS($type,cmd)         $cmd
	set CHKS($type,static_args) $static_args
}



# Return the command used to validate a value of a particular type.
#
proc core::check::command_for_type { type } {

	variable CHKS

	if {![info exists CHKS($type,cmd)]} {
		return [list 0]
	}
	return [list \
		1 \
		$CHKS($type,cmd) \
		$CHKS($type,static_args)]
}

# Validate a value against a particular type.
#
proc core::check::check { type value args } {

	set ret [core::check::command_for_type $type]
	if {[lindex $ret 0] != 1 || [llength $ret] < 2} {
		error "Invalid type: $type"
	}

	set command [lindex $ret 1]
	return [$command $value {*}$args]
}


# The value has to pass *all* checks.
#
# Parameters   :  value - value to check
#                 combine_type - method to combine multiple checks, either:
#                                'AND' (default)
#                                'OR'
#                 checks - list of checks
#                 arg_name - Optional name corresponding to <value>, to write in error
#                           messages so debugger knows which argument/item failed
#
# Returns      :  0 - if checks failed
#                 1 - if checks passed
#                 TCL_ERROR - if some processing error
proc core::check::check_value { value combine_type checks {arg_name ""} } {

	variable CHKS

	# No checks so fail. Need to explicitly pass -check NONE to skip check
	if {[llength $checks] == 0} {
		error "No checks defined for argument '$arg_name'. Use -check NONE if you want to skip checking" {} MISSING_CHECK
	}

	foreach check $checks {
		set check_result 0

		set check_type [lindex $check 0]
		set check_args [lrange $check 1 end]

		if {![info exists CHKS($check_type,cmd)]} {
			error "Unknown check type $check_type for argument '$arg_name'" {} UNKNOWN_CHECK
		}

		set cmd          $CHKS($check_type,cmd)
		set static_args  $CHKS($check_type,static_args)
		set dynamic_args $check_args

		set arg_list [list]
		if {[llength $static_args] > 0} {
			lappend arg_list {*}$static_args
		}

		if {[llength $dynamic_args] > 0} {
			lappend arg_list {*}$dynamic_args
		}

		set check_result [$cmd $value {*}$arg_list]

		if {$combine_type == "OR" && $check_result == 1} {
			# At least one check passed, so we are good.
			return 1
		}

		if {$combine_type == "AND" && $check_result == 0} {
			# At least one check failed, so the whole thing failed.
			return 0
		}
	}

	if {$combine_type == "OR"} {
		# If we reached here, then that means that not a single check passed.
		# (Otherwise we would have already returned true.)
		# Thus all checks failed.
		return 0

	} elseif {$combine_type == "AND"} {
		# Not a single check failed. How nice.
		# So they must have all passed.
		return 1

	} else {
		error "Invalid combine_type $combine_type for argument '$arg_name'" {} INVALID_COMBINE_TYPE
	}
}

#----------------------------------------------------------------------------
# Numbers
#----------------------------------------------------------------------------

# Check if a valid integer.
#
#   int     - integer to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::integer { int args } {

	variable RE_INT

	foreach {n v} $args {
		switch -- $n {
			-min_num { set min_num $v }
			-max_num { set max_num $v }
		}
	}

	if {![regexp $RE_INT $int all int]} {
		return 0
	}

	if {[info exists min_num] && $int < $min_num} {
		return 0
	}

	if {[info exists max_num] && $int > $max_num} {
		return 0
	}

	return 1
}



# Check if a valid unsigned integer.
#
#   int     - integer to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::unsigned_integer { int args } {

	variable RE_UINT

	foreach {n v} $args {
		switch -- $n {
			-min_num { set min_num $v }
			-max_num { set max_num $v }
		}
	}

	if {![regexp $RE_UINT $int all int]} {
		return 0
	}

	if {[info exists min_num] && $int < $min_num} {
		return 0
	}

	if {[info exists max_num] && $int > $max_num} {
		return 0
	}

	return 1
}


# Check for optionally signed (+ or -) decimal number
# The decimal place must exist if there are digits after the decimal place.
#
# support optional min_num and max_num too
proc core::check::decimal { value args } {

	variable RE_DECIMAL

	foreach {n v} $args {
		switch -- $n {
			-min_num { set min_num $v }
			-max_num { set max_num $v }
		}
	}

	if {![regexp $RE_DECIMAL $value]} {
		return 0
	}

	if {[info exists min_num] && $value < $min_num} {
		return 0
	}

	if {[info exists max_num] && $value > $max_num} {
		return 0
	}

	return 1
}


# Check for valid unsigned decimal value.
# The decimal place must exist if there are digits after the decimal place.
#
# support optional min_num and max_num too
proc core::check::unsigned_decimal { value args } {

	variable RE_UDECIMAL

	foreach {n v} $args {
		switch -- $n {
			-min_num { set min_num $v }
			-max_num { set max_num $v }
		}
	}

	if {![regexp $RE_UDECIMAL $value]} {
		return 0
	}

	if {[info exists min_num] && $value < $min_num} {
		return 0
	}

	if {[info exists max_num] && $value > $max_num} {
		return 0
	}

	return 1
}

# Check for an optionally signed (+ or -) monetary amount is valid
# The amount must either be a zero, one or two decimal placed number.
#
#   amount  - amount to check
#   returns - 0 if invalid, otherwise 1
#
# support optional min_num and max_num too
proc core::check::money { amount args } {

	variable RE_MONEY

	foreach {n v} $args {
		switch -- $n {
			-min_num { set min_num $v }
			-max_num { set max_num $v }
		}
	}

	if {![regexp $RE_MONEY $amount]} {
		return 0
	}

	if {[info exists min_num] && $amount < $min_num} {
		return 0
	}

	if {[info exists max_num] && $amount > $max_num} {
		return 0
	}

	return 1
}

# Check for an unsigned monetary value.
# The amount must either be a zero, one or two decimal placed number.
#
#   amount  - amount to check
#   returns - 0 if invalid, otherwise 1
#
# support optional min_num and max_num too
proc core::check::unsigned_money { amount args } {

	variable RE_UMONEY

	foreach {n v} $args {
		switch -- $n {
			-min_num { set min_num $v }
			-max_num { set max_num $v }
		}
	}

	if {![regexp $RE_UMONEY $amount]} {
		return 0
	}

	if {[info exists min_num] && $amount < $min_num} {
		return 0
	}

	if {[info exists max_num] && $amount > $max_num} {
		return 0
	}

	return 1
}


# Check if a hexdecimal value is valid.
#
#   hex     - hexadecimal value to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::hex { hex args } {

	variable RE_HEX

	if {![regexp $RE_HEX $hex]} {
		return 0
	}

	return 1
}

# Check that string is allowed control chars.
#
#   control - control value to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::control { control args } {

	variable RE_CONTROL

	if {![regexp $RE_CONTROL $control]} {
		return 0
	}

	return 1
}

# Check that string is allowed symbols (non-alphanumeric).
#
#   symbols - value to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::symbol { symbols args } {

	variable RE_SYMBOL

	if {![regexp $RE_SYMBOL $symbols]} {
		return 0
	}

	return 1
}

# Check if a base64 encoded value is valid.
#
#   b64
#   returns - 0 if invalud, otherwise 1
#
proc core::check::base64 { b64 args } {

	variable RE_BASE64

	if {![regexp $RE_BASE64 $b64]} {
		return 0
	}

	return 1
}

# Check for an unsigned fraction
#
#   fraction
#   returns - 0 if invalid, otherwise 1
#
proc core::check::unsigned_fraction { fraction args } {

	variable RE_UFRACTION

	if {![regexp $RE_UFRACTION $fraction]} {
		return 0
	}

	return 1
}



#----------------------------------------------------------------------------
# Strings
#----------------------------------------------------------------------------

# Check if a string is a boolean value
#
#   str     - string to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::bool {str args} {

	variable RE_BOOL

	if {![regexp $RE_BOOL $str]} {
		return 0
	}

	return 1
}



# Check if a string is just composed of uppercase ascii letters.
#
#   str     - string to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::upper_case {str args} {

	variable RE_AZ

	if {![regexp $RE_AZ $str]} {
		return 0
	}

	if {![_check_string_length $str {*}$args]} {
		return 0
	}

	return 1
}



# Check if a string is just composed of lowercase ascii letters.
#
#   str     - string to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::lower_case {str args} {

	variable RE_az

	if {![regexp $RE_az $str]} {
		return 0
	}

	if {![_check_string_length $str {*}$args]} {
		return 0
	}

	return 1
}



# Check if a string is just composed of ascii letters.
#
#   str     - string to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::letters {str args} {

	variable RE_Az

	if {![regexp $RE_Az $str]} {
		return 0
	}

	if {![_check_string_length $str {*}$args]} {
		return 0
	}

	return 1
}



# Check if a string is just composed of alphanumeric characters.
#
#   str     - string to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::alnum {str args} {

	variable RE_ALNUM

	if {![regexp $RE_ALNUM $str]} {
		return 0
	}

	if {![_check_string_length $str {*}$args]} {
		return 0
	}

	return 1
}



# Check if a string is just composed of ascii characters.
#
#   str     - string to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::ascii {str args} {

	variable RE_ASCII

	if {![regexp $RE_ASCII $str]} {
		return 0
	}

	if {![_check_string_length $str {*}$args]} {
		return 0
	}

	return 1
}

# Check if a string is composed of just ascii characters.
#
#   str     - string to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::is_string {str args} {

	variable RE_STR

	if {![regexp $RE_STR $str]} {
		return 0
	}

	if {![_check_string_length $str {*}$args]} {
		return 0
	}

	return 1
}

# Check if a string is a valid list
#
#   str     - string to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::is_list {str args} {

	if {[catch {string is list $str}]} {
		return 0
	}

	return 1
}

# Check that the list has an even number of elements
# @param list List to check
# @return 0 if invalid, otherwise 1
proc core::check::nvpairs {list args} {

	if {[llength $list] % 2} {
		return 0
	}

	return 1
}



#----------------------------------------------------------------------------
# Internet/Web Addresses
#----------------------------------------------------------------------------

# Check an email address. If EMAIL_CHECK_ENHANCED config is turned on then
# calls core::check::email_enhanced instead.
#
#   email   - email address to check
#   returns - 0 if invalid, otherwise 1
#
proc core::check::email {email args } {

	variable CFG
	variable RE_EMAIL

	if {![regexp $RE_EMAIL $email]} {
		return 0
	}

	return 1
}



# Check if valid loose IP address
#
#    ip - IP to check
#
proc core::check::ip { ip args } {

	return [expr {[core::check::ipv4 $ip] || [core::check::ipv6 $ip]}]
}



# Check if a valid IP address.
#
#   ip      - IPv4 address to check
#   returns - status string (OB_OK denotes success)
#
proc core::check::ipv4 { ip args } {

	variable RE_IPv4

	if {![regexp $RE_IPv4 $ip]} {
		return 0
	}

	return 1
}



# Check if a valid IP address.
#
#   ip      - IP address to check
#   returns - status string (OB_OK denotes success)
#
proc core::check::ipv6 { ip args } {

	variable RE_IPv6

	if {![regexp $RE_IPv6 $ip]} {
		return 0
	}

	return 1
}





# Procedure to determine if IP a local address
# (10.0.0.0 - 10.255.255.255, 192.168.00.00 - 192.168.255.255,
# 172.16.0.0 - 172.31.255.255)
#
#    ipaddr  - ip to check
#    returns - 1/0
#
proc core::check::is_ipv4_private {ipaddr} {
	variable RE_IPv4_A
	variable RE_IPv4_B
	variable RE_IPv4_C

	if {[regexp $RE_IPv4_A $ipaddr] || \
	    [regexp $RE_IPv4_B $ipaddr] || \
	    [regexp $RE_IPv4_C $ipaddr] \
	} {
		return 1
	} else {
		return 0
	}
}


# Procedure to see if IP is a loopback address
# (range 127.0.0.0 - 127.255.255.255)
#
#    ipaddr  - ip to check
#    returns - 1/0
#
proc core::check::is_ipv4_localhost {ipaddr} {
	variable RE_IPv4_LOOP
	return [regexp $RE_IPv4_LOOP $ipaddr]

}


#
# Checks if ip6 address is a loopback address (::1 with possible preceding zeros)
#    ip6addr - ip to check
#    returns - 1 if it's a localhost address, 0 otherwise
#
proc core::check::is_ipv6_localhost {ip6addr} {
	variable RE_IPv6_LOOP
	return [regexp  $RE_IPv6_LOOP $ip6addr]
}


#
# Checks if ip address is a loopback address
#    ip      - ip to check
#    returns - 1 if it's a localhost address, 0 otherwise
#
proc core::check::is_ip_localhost {ip} {
	return [expr {[core::check::is_ipv4_localhost $ip] || [core::check::is_ipv6_localhost $ip]}]
}

#----------------------------------------------------------------------------
# HTTP Components
#----------------------------------------------------------------------------

#
# Checks if a HTTP header value contains any unsafe characters
#    http_header_value - value to check
#    returns - 1 if it contains no unsafe characters, 0 otherwise
#
proc core::check::http_header_value {http_header_value} {
	variable RE_HTTP_HEADER_VALUE
	return [regexp  $RE_HTTP_HEADER_VALUE $http_header_value]
}

# Check if a valid cookie name.
#
# @param cookie_name cookie name to check
# @return 1 if it is a valid cookie name, 0 otherwise
proc core::check::cookie_name {cookie_name} {
	variable RE_COOKIE_NAME
	return [regexp $RE_COOKIE_NAME $cookie_name]
}

# Check if a valid cookie value.
#
# @param cookie_value cookie value to check
# @return 1 if it is a valid cookie value, 0 otherwise
#
# NB: opinions differ on exactly what is allowed in a cookie value;
#     this module aims to follow the reasonably strict RFC 6265 -
#     in particular commas and non-ASCII values are disallowed.
#
proc core::check::cookie_value {cookie_value} {
	variable RE_COOKIE_VALUE
	return [regexp $RE_COOKIE_VALUE $cookie_value]
}

#
# Checks if a HTTP host is a accepted
#    http_host - value to check
#    returns - 1 if it accepted, 0 otherwise
#
proc core::check::http_host {http_host} {
	variable RE_HTTP_HOST
	return [regexp  $RE_HTTP_HOST $http_host]
}



# Check if valid v4 UUID
#
#    uuid - UUID to check
#
proc core::check::uuid { uuid args } {

	variable RE_UUID

	if {![regexp $RE_UUID $uuid]} {
		return 0
	}

	return 1
}

#----------------------------------------------------------------------------
# Dates / Time / Timestamp
#----------------------------------------------------------------------------

#
#
proc core::check::date { datestring args } {

	variable RE_DATE

	if {! [regexp $RE_DATE $datestring dummy year month day]} {
		return 0
	}

	return [_date $year $month $day]
}


proc core::check::datetime { datetime_string args } {

	variable RE_DATETIME

	if {! [regexp $RE_DATETIME $datetime_string dummy year month day hour minute second]} {
		return 0
	}

	if {! [_date $year $month $day]} {
		return 0
	}

	return [_time $hour $minute $second]
}



proc core::check::time { time_string args } {

	variable RE_TIME

	if {! [regexp $RE_TIME $time_string dummy hour minute dummy second]} {
		return 0
	}

	if {$second == ""} {
		set second 0
	}

	return [_time $hour $minute $second]
}



# Validate a string with a regular expression
#
proc core::check::exp {input_arg re args} {

	array set options $args

	if {$re eq "__ARG__"} {
		# Use dynamically passed regular expression. Let it error if not passed.
		set re $options(-args)
	}

	if {[regexp $re $input_arg]} {
		return 1
	} else {
		return 0
	}
}



# Check that that an object is part of a set
#
# @param str String to check
# @param args List set to check str against
# @return 1 or 0 depending on whether str is part of set args
proc core::check::enum {input_arg ignore args} {

	array set options $args

	set match_list $options(-args)

	if {[lsearch -exact $match_list $input_arg] != -1} {
		return 1
	} else {
		return 0
	}
}



proc core::check::_date {y m d} {

	# We need a 4 digit year!
	if {! [unsigned_integer $y -min_num 0001 -max_num 9999]} {
		return 0
	}

	# And sensible months.
	if {! [unsigned_integer $m -min_num 1 -max_num 12]} {
		return 0
	}

	# Strip leading zeros.
	set m [scan $m %d]

	#                            Ja Fe Mr Ap My Jn Jl Au Se Oc Nv De
	set month_lengths [list null 31 28 31 30 31 30 31 31 30 31 30 31]
	set max_days      [lindex $month_lengths $m]

	if {$m == 2 && [_is_leap_year $y]} {
		incr max_days
	}

	# Finally the day.
	return [unsigned_integer $d -min_num 1 -max_num $max_days]
}


proc core::check::_is_leap_year {y} {
	if {$y%4 != 0} {
		return 0
	} elseif {$y%100 != 0} {
		return 1
	} elseif {$y%400 != 0} {
		return 0
	} else {
		return 1
	}
}

proc core::check::_time {h m s} {

	return [expr {
		[unsigned_integer $h -min_num 0 -max_num 23] &&
		[unsigned_integer $m -min_num 0 -max_num 59] &&
		[unsigned_integer $s -min_num 0 -max_num 59]
	}]
}



# Sometimes we might need something that is either a date or a datetime.
# (Or blank.)
#
proc core::check::loosedate { loosedatestring args } {

	# Blank string is fine.
	if {$loosedatestring == ""} {
		return 1
	}

	if {[core::check::date $loosedatestring]} {
		return 1
	}

	if {[core::check::datetime $loosedatestring]} {
		return 1
	}

	return 0
}



#
#
proc core::check::_check_string_length { str args } {

	set length [string length $str]

	foreach {n v} $args {
		switch -- $n {
			-min_str { set min_str $v }
			-max_str { set max_str $v }
		}
	}

	if {[info exists min_str] && $length < $min_str} {
		return 0
	}

	if {[info exists max_str] && $length > $max_str} {
		return 0
	}

	return 1
}

proc core::check::any { str args } {
	return 1
}

# Pre-process procs.
# Stripping unwanted characters from input string.
proc core::check::trimws {input_str} {
	return [string trim $input_str]
}

proc core::check::rmallspace {input_str} {
	return [regsub -all {\s+} $input_str {} input_str]
}

proc core::check::num {input_str} {
	return [_clean_num $input_str]
}

# _clean_num:  Removes leading zeros/spaces/+ from a number
#
proc core::check::_clean_num {str} {

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
