# $Id: util.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Miscellaneous utilities
#
# Configuration:
#    UTIL_COOKIE_DOMAIN              cookie domain
#
# Synopsis:
#    package require util_util ?4.5?
#
# Procedures:
#    ob_util::untabify               untabify a string
#    ob_util::lead_space_count       count leading spaces
#    ob_util::comma_num_str          add commas to a value
#    ob_util::is_safe                is a character string safe
#    ob_util::get_cookie             get a HTTP cookie
#    ob_util::get_all_cookies        get all HTTP cookies
#    ob_util::set_cookie             set a HTTP cookie
#    ob_util::get_html_ccy_symbol    get a HTML currency symbol
#    ob_util::get_wml_ccy_symbol     get a WML currency symbol
#    ob_util::get_html_ccy_amount    get a HTML currency amount
#    ob_util::get_wml_ccy_amount     get a WML currency amount
#    ob_util::ip_to_int              convert dot-notation IP to integer
#    ob_util::int_to_ip              convert integer number to dot-notation IP
#    ob_util::getopts                similar tool to "getopts" as seen in shell scripting
#

package provide util_util 4.5



# Dependencies
#
package require util_log 4.5



# Variables
#
namespace eval ob_util {

	set INIT 0

}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration.
#
# Can specify any of the configuration items as a name value pair (overwrites
# file configuration), names are
#
#    -cookie_domain
#
proc ob_util::init args {

	variable CFG
	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init

	ob_log::write DEBUG {UTIL: init}

	# load the config' items via args
	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	# load config
	foreach {n v} {cookie_domain ""} {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet UTIL_[string toupper $n] $v]
		}
	}

	set INIT 1

}

#--------------------------------------------------------------------------
# Decimal manipulation utilities
#--------------------------------------------------------------------------

# e.g format 10.02 to 10,02
proc ob_util::dec_to_foreign_dec {val} {
	set sep [OT_CfgGet DECIMAL_SEPARATOR .]
	if {$sep != "."} {
		if {[regexp {([0-9]+)\.([0-9]+)} $val val before after]} {
			set val "${before}${sep}${after}"
		}
	}
	
	return $val
}

# e.g format 10,02 to 10.02
proc ob_util::foreign_dec_to_dec {val} {
	
	set sep [OT_CfgGet DECIMAL_SEPARATOR .]
	if {$sep != "."} {
		if {[regexp "(\[0-9\]+)${sep}(\[0-9\]+)" $val val before after]} {
			set val "${before}.${after}"
		}
	}
	
	return $val
}



#--------------------------------------------------------------------------
# String Utilities
#--------------------------------------------------------------------------

# Untabify a string.
# Replaces all tabs with spaces
#
#   str     - string to untabify
#   tablen  - tab length; determines the number of space characters per tab
#             (default: 4)
#
proc ob_util::untabify { str {tablen 4} } {

	set out ""
	while {[set i [string first "\t" $str]] != -1} {
		set j [expr {$tablen - ($i % $tablen)}]
		append out [string range $str 0 [incr i -1]][format %*s $j " "]
		set str [string range $str [incr i 2] end]
	}
	return $out$str
}



# Count how many leading spaces that can be stripped from each string in a list
#
#    str      - string list
#    returns  - number of leading spaces
#
proc ob_util::lead_space_count { str } {

	set min -1
	foreach s $str {
		regsub {^\s+} $s {} n
		set c [expr {[string length $s] - [string length $n]}]
		if {$min == -1} {
			set min $c
		} elseif {$c < $min} {
			set min $c
		}
	}
	return [expr {($min < 0) ? 0 : $min}]
}



# Add commas to a value (integer or decimal).
#
#    n       - value to convert
#    returns - comma delimited value
#
proc ob_util::comma_num_str { n } {

	set l [split $n .]
	set n [lindex $l 0]
	set expr {([0-9])([0-9][0-9][0-9])((,[0-9][0-9][0-9])*)$}

	#To Support European Currency Format
	if {[OT_CfgGet USE_COMMA_SEPARATOR 0] == 1} {
	 	while {[regsub $expr $n {\1,\2\3} n]} { continue }
	}

	if {[llength $l] == 2} {
		set n ${n}.[lindex $l 1]
	}

	return $n
}



# Check whether a tcl string contains any unsafe characters '[][${}\\]'.
# If CHARSET is set, the string will be encoded first.
#
#   str     - string to check
#   returns - non-zero if the string is safe, else zero if unsafe
#
proc ob_util::is_safe { str } {

	global CHARSET

	if {[info exists CHARSET]} {
		if {!([info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8")} {
			set str [encoding convertfrom $CHARSET $str]
		}
	}

	if {[regexp {[][${}\\]} $str]} {
		return 0
	}
	return 1
}


#--------------------------------------------------------------------------
# Cookie Utilities
#--------------------------------------------------------------------------

# Get a HTTP cookie.
#
# We look in the INSTANT_COOKIES variable (set via set_instant_cookie) before
# looking in the HTTP_COOKIE request header.
#
#   name    - cookie name to find
#   returns - cookie value, or an empty string if name not found
#
proc ob_util::get_cookie {name} {

	variable INSTANT_COOKIES

	# get cookie list from HTTP header
	if {[catch {set list [reqGetEnv HTTP_COOKIE]} msg]} {
		ob_log::write ERROR {UTIL: $msg}
		return ""
	}

	# prepend INSTANT_COOKIES value to list of cookies from header
	if {[info exists INSTANT_COOKIE]} {
		set list "$INSTANT_COOKIES $list"
	}

	# find the request cookie within the list
	set cl [split $list \;]
	foreach c $cl {
		set ct [string trim $c]
		if {$ct != ""} {
			set idx [string first "=" $ct]
			if {$idx == -1} {
				continue
			}
			set cn [string range $ct 0 [expr {$idx - 1}]]
			if {$cn == $name} {
				return [string range $ct [expr {$idx + 1}] end]
			}
		}
	}

	return ""
}



# Get all HTTP cookies
#
#    returns - list of name/value pairs, each '=' delimited
#
proc ob_util::get_all_cookies args {

	if {[catch {set list [reqGetEnv HTTP_COOKIE]} msg]} {
		ob_log::write ERROR {UTIL: $msg}
		return [list]
	}

	return [split $list \;]
}



# Set a HTTP cookie.
# If UTIL_COOKIE_DOMAIN cfg value is set, then cookie will have
# the domain set.
#
#   cookie - cookie
#   path   - cookie path (default: /)
#   secure - secure cookie (default: 0)
#   expiry - expiry time in seconds since epoch (i.e. clock seconds)
#   domain = allow a specific domain to be set
#
proc ob_util::set_cookie { cookie { path / } { secure 0 } { expiry "" } { domain "" } {http_only 0}} {

	variable CFG

	if { [string length $expiry] } {
		set expires [clock format $expiry \
			-format {%a, %d %b %Y %H:%M:%S GMT} -gmt 1]
		append cookie "; expires=$expires"
	}

	append cookie "; path=$path"

	if { $domain ne "" } {
		append cookie "; domain=$domain"
	} elseif { [string length $CFG(cookie_domain)] } {
		append cookie "; domain=$CFG(cookie_domain)"
	}

	if { $secure } {
		append cookie "; secure"
	}

	if { $http_only } {
		append cookie "; HttpOnly"
	}

	ob_log::write DEBUG {ob_util::set_cookie: $cookie}

	tpBufAddHdr Set-Cookie $cookie

}

# Remove all cookies from the response
#
proc ob_util::remove_cookies {} {
	tpBufDelHdr "Set-Cookie"
}

# Force the cookie domain
#
proc ob_util::set_cookie_domain {domain} {

	variable CFG

	set CFG(cookie_domain) $domain
}

# Set a HTTP cookie, but also make the new cookie value available immediately.
# i.e. subsequent get_cookie calls within the same request will return the new
# value of the cookie.
#
proc ob_util::set_instant_cookie { cookie { path / } { secure 0 } { expiry "" } } {

	variable INSTANT_COOKIES
	ob_gc::add ::ob_util::INSTANT_COOKIES

	append INSTANT_COOKIES "$cookie; "

	ob_util::set_cookie $cookie $path $secure $expiry

}



#--------------------------------------------------------------------------
# HTML/WML/Flash Utilities
#--------------------------------------------------------------------------

# Get a HTML currency symbol.
#
#   ccy_code   		- currency code
#   display_format 	- use HTML characters (1 = html, 2 = unicode)
#   returns    		- HTML currency symbol
#
proc ob_util::get_html_ccy_symbol { ccy_code {display_format 1} } {

	if {$display_format == 2} {
		# Unicode values
		set pound "\\u00A3"
		set euro  "\\u20AC"
		set space " "
	} elseif {$display_format} {
		set pound "&pound;"
		set euro  "&euro;"
		set space "&nbsp;"
	} else {
		set pound "GBP"
		set space " "
		set euro  "EUR"
	}

	switch -- $ccy_code {
		"GBP"   { return $pound }
		"IEP"   { return "IR${pound}" }
		"USD"   { return "$" }
		"EUR"   { return $euro }
		default { return "$ccy_code${space}" }
	}
}



# Get a WML currency symbol.
#
#   ccy_code    - currency code
#   euro_symbol - enable the euro symbol (0)
#   returns     - WML currency symbol
#
proc ob_util::get_wml_ccy_symbol { ccy_code {euro_symbol 0} } {

	if {$euro_symbol} {
		set euro "&#xA4"
	} else {
		set euro "EUR "
	}

	switch -- $ccy_code {
		"GBP"   { return "&#163" }
		"IEP"   { return "IR&#163" }
		"USD"   { return "$$" }
		"EUR"   { return $euro }
		default { return "${ccy_code}&nbsp;" }
	}
}


#Get a Flash coded currency symbol for rendering in htmlText
#textfields, &pound does not code.
#
#   ccy_code	-	currency code
#   euro_symbol -	enable the euro symbol (0)
#   returns 	-	Flash currency symbol
#
proc ob_util::get_flash_ccy_symbol {  ccy_code {euro_symbol 0} } {

	if {$euro_symbol} {
	        set euro "&#8364;"
        } else {
                set euro "EUR"
	}

	switch -- $ccy_code {
		  "GBP" { return "&#163;" }
		  "USD" { return "&#36;" }
		  "EUR" { return $euro }
		  default { return "${ccy_code}&nbsp;" }
	}
}

# Get a Flash currency amount.
#
#   amount                - amount
#   ccy_code              - currency code
#   uro_symbol            - enable the euro symbol (0)
#   less_than_one_special - set to pence if less than 1 pound (0)
#                           (only applicable if GBP)
#   returns               - amount with a prefixed HTML currency code
#                           the amount is comma delimited
#
proc ob_util::get_flash_ccy_amount { amount ccy_code\
                                {euro_symbol 0} {less_than_one_special 0} } {
      	  return [_get_ccy_amount flash $amount $ccy_code $euro_symbol\
	              $less_than_one_special]


}


# Get a HTML currency amount.
#
#   amount                - amount
#   ccy_code              - currency code
#   html_chars            - use HTML characters (1)
#   less_than_one_special - set to pence if less than 1 pound (0)
#                           (only applicable if GBP)
#   returns               - amount with a prefixed HTML currency code
#                           the amount is comma delimited
#
proc ob_util::get_html_ccy_amount { amount ccy_code\
	                        {html_chars 1} {less_than_one_special 0} } {

	return [_get_ccy_amount html $amount $ccy_code $html_chars\
	        $less_than_one_special]
}



# Get a WML currency amount.
#
#   amount                - amount
#   ccy_code              - currency code
#   eruo_symbol           - enable the euro symbol (0)
#   less_than_one_special - set to pence if less than 1 pound (0)
#                           (only applicable if GBP)
#   returns               - amount with a prefixed HTML currency code
#                           the amount is comma delimited
#
proc ob_util::get_wml_ccy_amount { amount ccy_code\
	                        {euro_symbol 0} {less_than_one_special 0} } {

	return [_get_ccy_amount wml $amount $ccy_code $euro_symbol\
	    $less_than_one_special]
}



# Private procedure to get a currency amount
#
#   type                  - html|wml|flash
#   amount                - amount
#   ccy_code              - currency code
#   sym_param             - get_type_ccy_symbol extra parameter
#   less_than_one_special - set to pence if less than 1 pound
#                           (only applicable if GBP)
#   returns               - amount with a prefixed HTML currency code
#                           the amount is comma delimited
#
proc ob_util::_get_ccy_amount { type amount ccy_code sym_param\
	                        less_than_one_special } {

	# amount already has ccy symbol prefixed
	if {$amount == "" || ![regexp {^[0-9.,-]*$} $amount]} {
		return $amount
	}

	set less_than_zero 0
	if {$amount < 0} {
		set less_than_zero 1
		set amount [expr {abs($amount)}]
	}

	# get symbol
	set symbol [eval [subst "get_${type}_ccy_symbol $ccy_code $sym_param"]]

	if {$ccy_code == "GBP" && $amount < 1 && $less_than_one_special} {
		set return_str "[expr {round($amount * 100)}]p"
	} else {
		if {![OT_CfgGet FUNC_CCY_AFTER_AMOUNT 0]} {
			set return_str "${symbol}[comma_num_str [format "%.2f" $amount]]"
		} else {
			set return_str "[comma_num_str [format "%.2f" $amount]]${symbol}"
		}
	}

	if {$less_than_zero} {
		set return_str "-${return_str}"
	}

	return $return_str
}



#--------------------------------------------------------------------------
# Network Utilities
#--------------------------------------------------------------------------

# Convert an ip address to a unique integer
#
#    ip_address - ip address
#    returns    - integer unique to the ip address
#
proc ob_util::ip_to_int {ip_address} {

	set ip_address [string trim $ip_address]

	set blocks [split $ip_address .]

	set ip_num ""

	foreach block $blocks {
		append ip_num [format %03s $block]
	}

	set x [string trimleft $ip_num "0"]

	if {$x == ""} {
		set x 0
	}

	return $x
}



# Convert an integer to a unique ip address
#
#    ip_num  - integer
#    returns - ip address unique to the integer
#
proc ob_util::int_to_ip {ip_num} {

	set ip_num [string trim $ip_num]

	set ip_num [format %012s $ip_num]

	set blocks [list]

	for {set i 0} {$i < 4} {incr i} {
		set x [expr {$i * 3}]
		set d [string range $ip_num $x [expr {$x + 2}]]
		if {$d != 0} {
			set d [string trimleft $d 0]
		} else {
			#
			# ...could have more than one 0 at the front
			#
			set d 0
		}

		lappend blocks $d
	}

	return [join $blocks "."]
}



# Update the tLicenseExpiry table in order to keep track of license key
# expiries.  The procedure called here (pUpdLicenseExpiry) two return values,
# a status and date, which are as follows:
#
# STATUS |       DATE         | DESC
# -------|--------------------|---------------
#    1   | same as $expiry    | Inserted new app into tLicenseExpiry
#    2   |       "            | No update, $expiry was the same
#    3   | date before update | Updated to new $expiry
#
#    app_name - name of the app to update
#    expiry   - expiry date of the current licence key
#
proc ob_util::update_license_expiry {} {

	global DB

	# Just runs the stored proc to update the table
	if {[catch {

		# Don't set a default as we don't want to insert anything into tLicenseExpiry
		# if we have no idea what app we're running
		set app_name [OT_CfgGet APP_TAG]
		set expiry   [clock format [asGetLicenceExp] -format {%Y-%m-%d %H:%M:%S}]
		set hostname [info hostname]

		# We can't use the DB packages here as certain apps (such as DBV and crypto
		# server) don't use these packages, so trying to use them exclusively for
		# this doesn't make sense, and rewriting these apps to use the DB packages
		# is more trouble than it's worth (when this functionality was added at
		# least).
		set sql {
			execute procedure pUpdLicenseExpiry(
				p_hostname = ?,
				p_app_name = ?,
				p_expiry = ?
			)
		}
		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt $hostname $app_name $expiry]

		if {[db_get_nrows $rs] == 1} {
			set status     [db_get_coln $rs 0 0]
			set old_expiry [db_get_coln $rs 0 1]

			switch -exact -- $status {

				1 {ob_log::write INFO {ob_util::update_license_expiry:\
						Inserted $app_name license expiry date $expiry}}
				2 {ob_log::write INFO {ob_util::update_license_expiry:\
						No need to update $app_name license expiry date to $expiry}}
				3 {ob_log::write INFO {ob_util::update_license_expiry:\
						Updated $app_name license expiry date from\
						$old_expiry to $expiry}}
				default: {ob_log::write WARNING {ob_util::update_license_expiry:\
						Status not recognised}}

			}
		} else {
			ob_log::write WARNING {ob_util::update_license_expiry: Did not\
																return one row}
		}

		inf_close_stmt $stmt

	} msg]} {
		ob_log::write ERROR {ob_util::update_license_expiry: Failed\
												to update tLicenseExpiry: $msg}
	}
}



#
# Split <str> into one or more pieces, with the length of each
# piece no greater than <piecelen> when measured in bytes.
#
# If <max_pieces> is non-blank then at most <max_pieces> pieces
# will be returned. If this is not possible (i.e. <str> is too long)
# then an error will be returned.
#
# The <trailing_spaces> argument controls whether the piece(s) may
# end in space (ASCII 0x20) characters. This is important if the
# piece(s) will be stored in Informix CHAR fields since subsequent
# retrieval is likely to remove any trailing space.
#
# It may take the following values:
#
# <trailing_space>   Meaning
#
# Y                  The piece(s) may end in spaces.
#
# N                  The piece(s) may never end in spaces. An error
#                    will be returned if this is unavoidable.
#
# M                  The piece(s) will end in spaces only if <str>
#                    could not otherwise be accomodated in <max_pieces>
#                    pieces or fewer.
#
# Note that if <trailing_space> is N or M, trailing spaces will be
# stripped from <str> prior to splitting.
#
proc ob_util::split_str_to_pieces {piecelen str max_pieces trailing_space} {

	# Sanity checks

	if {$max_pieces != "" && \
		(![string is integer -strict $max_pieces] || $max_pieces < 1)} {
		error "max_pieces must be blank or at least 1"
	}

	if {[lsearch [list Y M N] $trailing_space] == -1} {
		error "trailing_space must be one of Y,M or N"
	}

	# Quick check on length first.
	# Note that we can still run out of room later since a piece
	# will be less than <piecelen> bytes if:
	#  a) we cannot fit a multibyte character in at the end of the piece
	# or
	#  b) we have had to move spaces to the start of the
	#     next piece to meet the <trailing_space> requirement.

	if {$max_pieces != ""} {
		if {[string bytelength $str] > ($piecelen * $max_pieces)} {
			error "string too long ([string bytelength $str] bytes)"
		}
	}

	# If <trailing_space> is M, recurse with a <trailing_space> of N
	# first, and if that fails try again with a <trailing_space> of Y.

	if {$trailing_space == "M"} {

		if {[catch {
			set pieces [split_str_to_pieces $piecelen $str $max_pieces N]
		}]} {
			set str [string trimright $str " "]
			set pieces [split_str_to_pieces $piecelen $str $max_pieces Y]
		}

		return $pieces

	}

	# If we have restrictions on trailing space in output
	# then strip any trailing space in input.

	if {$trailing_space == "N"} {

		set str [string trimright $str " "]
	}

	# List of pieces to return

	set pieces [list]

	# Current piece we are building up

	set piece ""

	# Whether we had to move spaces to prevent
	# them trailing

	set moved_spaces 0

	# Loop over characters in <str>

	foreach c [split $str {}] {

		set c_b [string bytelength $c]
		set p_b [string bytelength $piece]

		# Is there room to add this character?

		if {$p_b + $c_b <= $piecelen} {

			append piece $c

		} else {

			# No more room, so start new piece.

			# Check first whether we've hit <max_pieces> yet

			if {$max_pieces != "" && [llength $pieces] == $max_pieces} {
				set msg "unable to fit string into $max_pieces \
					   of length $piecelen bytes"
				if {$moved_spaces} {
					append msg " without leaving trailing spaces"
				}
				error $msg
			}

			if {$trailing_space == "Y"} {

				lappend pieces $piece
				set piece $c

			} else {

				# We must not leave spaces at the end of our current piece
				# since they will get stripped on retrieval.

				if {[regexp {^[ ]*$} $piece]} {

					# However, in this case there's not much we can do since the
					# whole piece consists of space.
					error "unable to split string without creating pieces with trailing space"

				} else {

					# Move trailing space into start of new piece

					set spaces {}
					while {[string index $piece end] == " "} {
						append spaces [string index $piece end]
						set piece [string range $piece 0 end-1]
					}

					if {[string length $spaces] > 0} {
						set moved_spaces 1
					}

					lappend pieces $piece
					set piece $spaces
					append piece $c

				}

			}

		}
	}

	# Need not check for trailing space in the last piece
	# since if <trailing_space> was N, we removed any
	# trailing space from the input earlier.

	if {[string length $piece] > 0} {
		lappend pieces $piece
	}

	# However, we should check if we've exceeded <max_pieces>.

	if {$max_pieces != "" && [llength $pieces] > $max_pieces} {
		set msg "unable to fit string into $max_pieces \
			   of length $piecelen bytes"
		if {$moved_spaces} {
			append msg " without leaving trailing spaces"
		}
		error $msg
	}


	return $pieces

}



# Called with the config item that contains the proxy details as a pipe 
# seperated list in the format proxy_name|proxy_port and sets as the current
#
proc ob_util::set_proxy {proxy_name} {

	variable CFG
	variable default_proxy_host
	variable default_proxy_port

	ob_log::write INFO {ob_util::set_proxy - proxy_name=$proxy_name}

	set default_proxy_port [::http::config -proxyport]
	set default_proxy_host [::http::config -proxyhost]

	ob_log::write INFO {ob_util::set_proxy - default_proxy_host=\
				$default_proxy_host, default_proxy_port=$default_proxy_port}

	set new_proxy_host $CFG(proxy,${proxy_name},host)
	set new_proxy_port $CFG(proxy,${proxy_name},port)

	ob_log::write INFO {ob_util::set_proxy - new_proxy_host=\
				$new_proxy_host, new_proxy_port=$new_proxy_port}

	if {$new_proxy_host == "" || $new_proxy_port == ""} {
		return 0
	}

	::http::config -proxyhost $new_proxy_host
	::http::config -proxyport $new_proxy_port

	return 1

}



# Sets the proxy back to the origonal settings
#
proc ob_util::revert_proxy {} {

	variable default_proxy_host
	variable default_proxy_port

	ob_log::write INFO {::ob_util::revert_proxy - default_proxy_host=\
				$default_proxy_host, default_proxy_port=$default_proxy_port}

	::http::config -proxyhost $default_proxy_host
	::http::config -proxyport $default_proxy_port

}


# A similar tool to getopts as seen in shell scripting
#
# Arguments
#   opt_args - An n v list of optional arguments the calling proc
#              has and their default values.
#              E.g. [list "-show_markets" 1 "-display_outrights" 0
#                         "-show_bir_events" 1 "-price_style" fractional]
#
#   args_set - An n v list of flags passed in to the calling proc.
#              E.g -show_markets 0 -price_style decimal
#
# Returns
#   A string that the calling proc can [eval] that will set variables and values
#   for all the flags that have been set and set variables and default values
#   for all flags that haven't been set.
#
proc ob_util::getopts {opt_args args_set} {

	set argc [llength $opt_args]
	if {$argc % 2} {
		error {must have an even number of options.}
	}

	set argc [llength $args_set]
	if {$argc % 2} {
		error {must have an even number of arguments.}
	}

	# First set up default values for all the optional arguments
	foreach {opt_arg dflt} $opt_args {
		set opts($opt_arg) $dflt
	}

	# Now get the args that have been explicitly set
	foreach {arg_set val} $args_set {

		if {![info exists opts($arg_set)]} {
			error "Invalid optional arg: $arg_set"
		}

		set opts($arg_set) $val
	}

	# Finally, create a string that, when "eval"ed, will setup
	# values for all the optional flags

	set flag_set_str ""
	foreach {n v} [array get opts] {

		# Strip the leading "-" from the flag
		set n [string range $n 1 end]
		append flag_set_str "set $n {$v}; "
	}

	return "$flag_set_str"

}
