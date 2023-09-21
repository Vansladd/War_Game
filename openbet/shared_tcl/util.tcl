# $Id: util.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# =======================================================================
#
# Copyright (c) Orbis Technology 2000. All rights reserved.
#
#
# This file contains some general utility functions not related
# to any particular part of openbet but (hopefully) of some use
#
# =======================================================================


# -------------------------------------------------------------------
# parameters: a cookie name
# returns:    the named cookie as set in the cgi-environment
# depends:    none
# side affects: none
# -------------------------------------------------------------------
proc get_cookie {name} {
	set nl [string length $name]
	if [catch {set str [reqGetEnv HTTP_COOKIE]} msg] {
		return ""
	}

	# find the request cookie within the list
	set cl [split $str \;]
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

proc set_cookie { cookie { path / } { expires "" } } {

	append cookie "; path=${path}"

	if { [string length $expires] } {
		if { [string is integer $expires] } {
			set expires [clock format $expires \
							-format {%a, %d %b %Y %H:%M:%S GMT} -gmt 1]
		}
		append cookie "; expires=${expires}"
	}

	if {[OT_CfgGet SET_COOKIE_DOMAIN 0] == 1} {
		append cookie "; domain=[OT_CfgGet DOMAIN]"
	}

	tpBufAddHdr "Set-Cookie" "$cookie"
}



# -----------------------------------------------------------------------------
# Advanced version of set_cookie / get_cookie
# -----------------------------------------------------------------------------

# This is a wrapper for set_cookie.
# If you use this to set a cookie, you _must_ use get_cookie_adv to retrieve it
#
# expiry_time:  Supply this as the lifetime in days
#               If it is unset or set to 0, the cookie will be session-only
#               If it is set to > 0, TWO cookies will be created - a session-only one
#               and a persistent one (which will be named ${cookie_name}_persist)
#
# cookie_list:  Unlike the normal get/set cookie, this takes a list and
#               converts name/value pairs into a single string to be stored in
#               the cookie. This will be converted back by get_cookie_adv.
proc set_cookie_adv {cookie_name cookie_list {expiry_time 0}} {
	set cookie_value [join $cookie_list "|"]

	#
	# Create the session-only cookie
	#
	set_cookie $cookie_name=$cookie_value /

	#
	# Create the persistent cookie (if necessary)
	#
	if { $expiry_time } {

		set exp_secs [expr { [clock seconds] + $expiry_time * 86400 }]
		set_cookie ${cookie_name}_persist=$cookie_value / $exp_secs

	}

}


# See set_cookie_adv
#
# Note: This will attempt to retrieve data from the session-only cookie.
#       Only if that is unavailable will it check the persistent one.
#
# If a single value was stored, this will return a single value, otherwise
# it will return a list of name-value pairs
proc get_cookie_adv cookie_name {

	#
	# Get the session-only cookie
	#
	set cookie_value [get_cookie $cookie_name]

	#
	# Get the persistent cookie if the session-only one isn't set
	#
	if { ![string length $cookie_value] } {
		set cookie_value [get_cookie ${cookie_name}_persist]
	}

	#
	# Convert the cookie back into a map
	#
	set cookie_list [split $cookie_value |]

	#
	# If we were just storing a single value, we return the single value
	#
	if { [llength $cookie_list] == 1 } {
		return [lindex $cookie_list 0]
	}

	#
	# If the cookie is buggered and has an odd number of elements, return an
	# empty list.
	#
	if { [llength $cookie_list] % 1 } {
		return [list]
	}

	return $cookie_list

}


# -------------------------------------------
# Dump out a result_set structure to the log
# -------------------------------------------

proc ob_dbg_dump_rs rs {

	set n_r [db_get_nrows $rs]
	set n_c [db_get_ncols $rs]

	ob::log::write DEV {Num_rows=$n_r}
	ob::log::write DEV {Num_cols=$n_c}

	if {$n_r > 0 && $n_c > 0} {

		for {set r 0} {$r < $n_r} {incr r} {
			for {set c 0} {$c < $n_c} {incr c} {
				ob::log::write DEV {r= $r,c= $c}
				ob::log::write DEV {(row $r,col $c)=[db_get_coln $rs $r $c]}
			}
		}
	}
}


#--------------------------------------------------------------
# Break up a result set into a global associative array, grouped by
# the column called $gCol
#--------------------------------------------------------------

proc ob_group_data {gCol gName {rs default}} {

	global [set aName a${gName}]

	if [info exists $aName] {
		unset $aName
	}

	set nrows  [db_get_nrows $rs]
	set cols   [db_get_colnames $rs]

	set ${aName}(groups) [list]

	for {set r 0} {$r < $nrows} {} {

		set g [db_get_col $rs $r $gCol]
		set i 0

		while {$r < $nrows && $g == [db_get_col $rs $r $gCol]} {
			foreach c $cols {
				set ${aName}($g,$i,$c) [db_get_col $rs $r $c]
			}
			incr r
			incr i
		}

		set ${aName}($g,rows)     $i
		set ${aName}($g,groupCol) $g

		lappend ${aName}(groups) $g
	}
}



proc ob_group_data_by_cols {rs gName args} {

	global $gName

	if [info exists $gName] {
		unset $gName
	}

	set nrows [db_get_nrows $rs]
	set i_idx 0
	for {set i 0} {$i < $nrows} {incr i_idx} {

		set i [group_cols $rs $gName $i $i_idx "" $args]

	}

	return
}

proc group_cols {rs gName st_i i_idcs c_idcs cols} {

	global $gName

	set col   [lindex $cols 0]

	if {[llength $cols] > 1} {
		set more 1
		set cols  [lrange $cols 1 end]

	} else {
		set more 0
		set colnames [db_get_colnames $rs]
		set i_idcs [join "i $i_idcs" ","]
		set c_idcs [join "c $c_idcs" ","]

	}

	set nrows [db_get_nrows $rs]
	set g [db_get_col $rs $st_i $col]

	set i_idx 0
	for {set i $st_i} {$i < $nrows && $g == [db_get_col $rs $i $col]} {} {
		if {$more} {
			set i [group_cols $rs $gName $i "$i_idcs $i_idx" "$c_idcs $g" $cols]
		} else {
			foreach c $colnames {

				set ${gName}($i_idcs,$i_idx,$c) \
					[db_get_col $rs $i $c]

				set ${gName}($c_idcs,$g,$c) \
					[db_get_col $rs $i $c]
			}
			incr i
		}

		incr i_idx
	}

	return $i
}



#---------------------------------------------------------------------------
# Utility functions used elsewhere in this file
#---------------------------------------------------------------------------

proc min args {
	switch [llength $args] {
		0 {return {}}
		1 {return [lindex $args 0]}
		default {
			set a [lindex $args 0]
			set b [eval min [lrange $args 1 end]]
			if {$b == ""} {
				return $a
			} elseif {$a == ""} {
				return $b
			} elseif {$a < $b} {
				return $a
			} else {
				return $b
			}
		}
	}
}

proc max args {
	switch [llength $args] {
		0 {return {}}
		1 {return [lindex $args 0]}
		default {
			set a [lindex $args 0]
			set b [eval max [lrange $args 1 end]]
			if {$b == ""} {
				return $a
			} elseif {$a == ""} {
				return $b
			} elseif {$a > $b} {
				return $a
			} else {
				return $b
			}
		}
	}
}

proc left_pad {str char length} {
	set pad_number [expr $length - [string length $str]]

	for {set i 0} {$i < $pad_number} {incr i} {
		set str $char$str
	}

	return $str
}

# Generates a URL for the page we're servicing.
# Useful if you need to create a back button on a page
# you're linking to

proc my_url {{all_encode 0}} {
	set url "[OT_CfgGet CGI_URL]"
	if {$all_encode==0} {
		set qstn_mk "?"
		set amprsnd "&"
	} else {
		set qstn_mk [urlencode "?"]
		set amprsnd [urlencode "&"]
	}
	set numargs [reqGetNumVals]
	if {$numargs!=0} {
	append url $qstn_mk
	}
	for {set i 0} {$i<$numargs} {incr i} {
	if {$i!=0} {
		append url $amprsnd
	}
	append url "[reqGetNthName $i]="
	append url [urlencode [reqGetNthVal $i]]
	}
	return $url
}

# ------------------------------------
# Make suitable image name from string
# ------------------------------------

proc ob_mk_img_name {img} {

	# More efficient to use string map than regsubs!
	return [string map {" " _ "|" ""} [string tolower $img]]
}

#
# Given a chain of status flags, A or S, return A or S. S "dominates" A.
#
proc agg_status args {
	foreach a $args {
		if {$a == "S"} {
			return S
		}
	}
	return A
}

#
# Put commas in numbers (this one's just for Declan Kelly)
#
proc comma_num_str {n {remove_trailing_zeros 0}} {
	set l [split $n .]
	set n [lindex $l 0]
	set x {([0-9])([0-9][0-9][0-9])((,[0-9][0-9][0-9])*)$}
	while {[regsub $x $n {\1,\2\3} n]} { continue }
	if {[llength $l] == 2 && ([lindex $l 1]!="00" || $remove_trailing_zeros==0)} {
		set n ${n}.[lindex $l 1]
	}
	return $n
}

#
# Print a currency amount
#
proc print_ccy {amt {ccy_code DEFAULT} {html_chars 1} {less_than_one_special 0} {remove_trailing_zeros 0}} {

	global LOGIN_DETAILS

	# If amount already has ccy_symbol just return it.
	if {![regexp {^[0-9.,-]*$} $amt {}]} {
		return $amt
	}

	if { [lsearch -exact [list O W M] [OT_CfgGet CHANNEL "I"]] != -1 } {
		return [OB_wap::wml_print_ccy $amt $ccy_code $less_than_one_special]
	}

	if {$amt==""} {
		return ""
	}

	if {$ccy_code=="DEFAULT"} {
		if [info exists LOGIN_DETAILS(CCY_CODE)] {
			set ccy_code $LOGIN_DETAILS(CCY_CODE)
		} else {
			set ccy_code [OT_CfgGet DEFAULT_CCY "GBP"]
		}
	}

	set output ""
	if {$amt < 0} {
		append output "-"
		set amt [expr {0 - $amt}]
	}

	switch -- $ccy_code {
		"GBP"   {
			if { $amt < 1 && $less_than_one_special == 1} {
				append output "[expr {round($amt*100)}]p"
			} else {
				set amt
				append output [print_ccy_symbol $ccy_code $html_chars]
				append output "[comma_num_str [format {%.2f} $amt] $remove_trailing_zeros]"
			}
		}
		default {
			append output [print_ccy_symbol $ccy_code $html_chars]
			append output "[comma_num_str [format {%.2f} $amt]]"
		}
	}
	return $output
}

proc print_ccy_symbol {{ccy_code GBP} {html_chars 1}} {

	if {$html_chars} {
		# Html entities
		set pound "&pound;"
		set euro  "&euro;"
		set space "&nbsp;"
	} else {
		# Unicode values
		set pound "\\u00A3"
		set euro  "\\u20AC"
		set space " "
	}

	switch -- $ccy_code {
		"GBP"   { set output $pound}
		"IEP"   { set output "IR${pound}"}
		"USD"   { set output "$" }
		"EUR"   { set output $euro}
		default { set output "$ccy_code${space}"}
	}
	return $output
}

proc tp_write_rc {V row col name} {

	global $V

	set r [tpGetVar $row]
	set c [tpGetVar $col]

	tpBufWrite [set ${V}($r,$c,$name)]
}

proc tp_write_r {V row name} {

	global $V

	set r [tpGetVar $row]

	tpBufWrite [set ${V}($r,$name)]
}

proc tp_write {V args} {

	global $V

	set argl [expr {[llength $args] - 1}]

	set str ""
	for {set i 0} {$i < $argl} {incr i} {
		append str "[tpGetVar [lindex $args $i]],"
	}

	append str [lindex $args $argl]

	tpBufWrite [set ${V}($str)]
}



# -------------------------------------------------------------------
# rounding routine for decimal numbers; the required decimal place (dp)
# must be >= 1.
# -------------------------------------------------------------------

proc dec_round {num {dp 2}} {

	set len [string length $num]
	set point_pos -1
	for {set i 0} {$i < $len} {incr i} {
		if {[string index $num $i] == "."} {
			set point_pos $i
			break
		}
	}
	if {$point_pos == -1 || [expr $point_pos + $dp] >= $len} {
		return [format %0.${dp}f $num]
	}
	set digit [string index $num [expr $point_pos + $dp + 1]]
	if {$digit >= 5} {
		set round_up 1
	} else {
		set round_up 0
	}

	set retStr [string range $num 0 [expr $point_pos + [expr $dp -1]]]
	append retStr [expr [string index $num [expr $point_pos + $dp]]+$round_up]
	return $retStr
}
## Validate a phone number by stripping out everything but numbers and a
## leading '+'
proc validate_phone_no {phoneNo} {

	regsub -all {[^0-9+]} $phoneNo "" phoneNo

	if {$phoneNo!=""} {

		set plus [string index $phoneNo 0]
		regsub -all {\+} $phoneNo "" phoneNo
		if {$plus=="+"} {
			set phoneNo "+$phoneNo"
		}
	}

	return $phoneNo
}


## Escape a string as HTML:
## Replace <, >, & with &gt;, &lt;, &amp;
##

proc escape_html {toencode} {
	regsub -all {&} $toencode  {\&amp;} toencode
	regsub -all "\xA3" $toencode  {\&pound;} toencode
	regsub -all {\"} $toencode {\&quot;} toencode
	regsub -all {>} $toencode  {\&gt;} toencode
	regsub -all {<} $toencode  {\&lt;} toencode
	return $toencode
}

## Escape a string in such a way that it doesn't choke
## our javascript.
## ' -> \'
## " -> \"
proc escape_javascript {toencode} {
	set toencode [unicode_escape $toencode]
	return [string map {' \\' \" \\\"} $toencode]
}

# Replace non-ASCII characters in the given string
# with "unicode escapes" of the form \uXXXX.
#
proc unicode_escape { str } {
    set rslt ""
    foreach c [split $str {}] {
        set codepoint [scan $c "%c"]
        if { ($codepoint >= 32 && $codepoint < 128) } {
            append rslt $c
        } else {
            append rslt [format "\\u%04x" $codepoint]
        }
    }
    return $rslt
}


##
## Turns an associative array mapping key -> value
## into an associative array mapping value -> key
##
## If the mapping is not 1-1 then the result is an
## array which maps the original values into a list
## of all the original keys which were mapped to them
##
proc array_invert {in out} {

	upvar $in source
	upvar $out dest
	foreach {a b} [array get source] {
		lappend dest($b) $a
	}
}

##
## Doesn't blow up if your variable is unset
##

proc safe_incr args {

	if {[llength $args] == 1} {
		set target [lindex $args 0]
		set delta 1
	} elseif {[llength $args] == 2} {
		set target [lindex $args 0]
		set delta [lindex $args 1]
	} else {
		error "usage: safe_incr variable ?delta?"
	}

	upvar $target t

	if [catch {incr t $delta}] {
		set t $delta
	} else {
		return $t
	}
}

## e.g.
## map "fred" "bob 1 fred 2 algernon 3"
## returns "1"
##
## map "unknown" "bob 1 fred 2 algernon 3"
## returns ""

## This is only efficient for very small lists
proc map {in mapping} {
	foreach {x y} $mapping {
		if {$in==$x} {
			return $y
		}
	}
	return ""
}

## Just like the unix uniq command. Takes a list and removes adjacent
## duplicates.
proc uniq {in} {

	set out {}

	if {$in=={}} {return $out}

	set last "not[lindex $in 0]"

	foreach x $in {
		if {$last!=$x} {
			lappend out $x
		}
		set last $x
	}
	return $out
}

proc pretty_num {num} {
	switch -- $num {
		"1" {return "1st"}
		"2" {return "2nd"}
		"3" {return "3rd"}
		default {return "${num}th"}
	}
}

proc print_rs_col {rs idx col} {

	tpBufWrite [db_get_col $rs [tpGetVar $idx] $col]

}

#
# Helper method to format a string into "proper" case - ie. the
# first letter of each word is capitalised
#
proc to_proper_case {str} {

	# Lower case everything to begin with
	set str [string tolower $str]

	# Split into words
	set dest ""
	foreach word [split $str] {
		append dest [string totitle $word]
		append dest " "
	}

	return $dest
}

#
# Helper method used to log the details of a method and it's calling method
#
proc log_proc_call args {

	ob::log::write_stack DEV
}

proc socket_timeout {host port timeout} {

	global __connected

	set __connected ""

	set id   [after $timeout {set ::__connected "TIMED_OUT"}]

	set sock [socket -async $host $port]

	fileevent $sock w {set ::__connected "OK"}

	vwait __connected

	after cancel $id

	fileevent $sock w {}

	if {$__connected == "TIMED_OUT"} {
		catch {close $sock}
		error "Connection attempt timed out after $timeout ms"

	} else {
		fconfigure $sock -blocking 0
		if [catch {gets $sock a}] {
			close $sock
			error "Connection failed"
		}
		fconfigure $sock -blocking 1 -buffering line
	}

	return $sock
}

proc read_timeout {sock timeout} {

	set ::__read ""

	fconfigure $sock -blocking 0 -buffering line

	set id [after $timeout {set ::__read "TIMED_OUT"}]

	fileevent $sock r {set ::__read "OK"}

	vwait ::__read

	after cancel $id

	fileevent $sock r {}

	if {$::__read == "TIMED_OUT"} {
		error "read timed out after $timeout ms"
	} else {
		return [gets $sock]
	}
}

#
# Convert IP address to hex
#
proc ip_to_hex {ipaddr} {
	set b [split [string trim $ipaddr] .]
	set hex {}

	foreach item $b {
		append hex [format "%02X" $item]
	}
	return $hex
}

#
# Convert a decimal number to a different base
# The base_def param is a string of all the chars in the other base
#
proc dec_to_base_x {n base_def} {
	set s ""
	set l [string length $base_def]

	while {1} {
		set s [string index $base_def [expr {$n % $l}]]$s
		if {![set n [expr {$n/$l}]]} {
			break
		}
	}
	return $s
}

#
# Convert a number from a different base back to decimal
# The base_def param is a string of all the chars in the other base
#
proc base_x_to_dec {s base_def} {
	set n 0
	set l [string length $base_def]

	foreach c [split $s ""] {
		set n [expr {$n * $l +[string first $c $base_def]}]
	}
	return $n
}

global BASE64
set BASE64 "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

#
# Convert all numbers with more than 4 digits to base 64 to save space.
# Prefix the new numbers with a '!' so they can be recognised and converted back to dec later.
#
proc num_compress {string_to_conv} {
	global BASE64

	regsub -all {([0-9]{4,})} $string_to_conv {![dec_to_base_x \1 $BASE64]} string_to_conv
	set string_to_conv [subst $string_to_conv]
	return $string_to_conv
}

#
# Convert all 'compressed' numbers back to decimal again.
# Compressed numbers have a '!' so they can be recognised and converted here.
#
proc num_decompress {string_to_conv} {
	global BASE64

	regsub -all {!([0-9a-zA-Z+/]+)} $string_to_conv {[base_x_to_dec \1 $BASE64]} string_to_conv
	set string_to_conv [subst $string_to_conv]
	return $string_to_conv
}

#
# Convert an ip address from char(15) to decimal(12,0)
# e.g. 192.168.0.1 -> 192168000001
#      10.0.0.1    -> 10000000001
#
proc ip_to_dec {ip_address} {

	# trim the string
	set ip_address [string trim $ip_address]

	# split it by .
	set blocks [split $ip_address .]

	# init ip_decimal
	set ip_decimal {}

	# ensure each block has 3 chars and construct the decimal ip address
	foreach block $blocks {
		append ip_decimal [format %03s $block]
	}

	# return the ip address
	return $ip_decimal
}

#
# Convert an ip address from decimal(12,0) to char(15)
# e.g. 192168000001 -> 192.168.0.1
#      10000000001  -> 10.0.0.1
#
proc dec_to_ip {ip_decimal} {

	# trim the string
	set ip_decimal [string trim $ip_decimal]

	# left pad it with 0s so that it is 12 chars long
	set ip_decimal [left_pad $ip_decimal 0 12]

	# init the block list
	set blocks [list]

	# split it into 3 char blocks
	for {set i 0} {$i < 12} {set i [expr $i + 3]} {
		lappend blocks [string range $ip_decimal $i [expr $i + 2]]
	}

	# init ip address
	set ip_address {}

	# remove leading 0s from each block and construct dotted ip address
	foreach block $blocks {
		if {$block == 0} {
			set block 0
		} else {
			set block [string trimleft $block 0]
		}
		append ip_address $block .
	}

	# trim trailing .
	set ip_address [string trimright $ip_address .]

	# return the ip address
	return $ip_address
}



# Url encode only the reserved/unsafe characters (rather than all chars that
# aren't in the range A-Z,a-z,0-9,_ as is done by appserv urlencode)
#
#    str - the string to encode
#
#    returns - the urlencoded string
#
proc urlencode_unsafe {str} {

	set encode ""

	for {set i 0} {$i<[string length $str]} {incr i} {
		set char [string range $str $i $i]

		if {[string match {[^a-zA-Z0-9$_.!*'(),-]} $char]} {
			append encode $char
		} elseif {$char == " "} {
			append encode "+"
		} else {
			binary scan $char H2 charval
			append encode "%$charval"
		}
	}

	return $encode
}

#
# formats the handicap value for displaying on the customer screens
#
proc format_hcap_string { mkt_sort
                          mkt_type
                          fb_result
                          hcap_value
                          hcap_value_fmt
                          {use_brackets_for_draw Y}} {

	set hcap_parts    [list]
	set hcap_str_list [list]
	set hcap_str      $hcap_value_fmt
	set hcap_value    $hcap_value_fmt

	if { [OT_CfgGet SHOW_WH_HCAP_ZERO_ALT_DESC 0] &&
	     [lsearch -exact [list MH WH] $mkt_sort] != -1 &&
	     $hcap_value == 0 } {

		# Temporary Hack
		if {$use_brackets_for_draw == "N"} {
			set hcap_str ZERO_HANDICAP
		} else {
			# Another hack - add brackets in here
			set hcap_str "([ml_printf ZERO_HANDICAP])"
		}

	} elseif {$mkt_sort == "AH"} {

		if {[expr abs(int($hcap_value))] == 0} {
				set hcap_str "0.0"

		} else {
			#
			# Will format to "x.xx & x.xx" only if config item is set AND
			# h/cap is a quarter value for Asian Handicap
			#
			if {$fb_result != "L"} {

				if {$fb_result == "A"} {
					set hcap_value [expr $hcap_value * -1]
				}

				if {([OT_CfgGet AH_DISPLAY_SPLIT_LINE 0] == 1) &&  \
					([lsearch [list 1 3] [expr (int($hcap_value)) % 4]] != -1)} {

					if {$hcap_value < 0.0} {
						lappend hcap_parts "[expr $hcap_value / 4.0 + 0.25]"\
						                   "[expr $hcap_value / 4.0 - 0.25]"
					} else {
						lappend hcap_parts "[expr $hcap_value / 4.0 - 0.25]"\
						                   "[expr $hcap_value / 4.0 + 0.25]"
					}

				} else {
					lappend hcap_parts "[expr $hcap_value / 4.0]"
				}

				if {$hcap_value > 0.0} {

					foreach part $hcap_parts {
						if {[lsearch "0.0" $part] != -1} {
							lappend hcap_str_list "0.0"
						} else {
							lappend hcap_str_list "+$part"
						}
					}

				} else {
					foreach part $hcap_parts {
						if {[lsearch "0.0" $part] != -1} {
							lappend hcap_str_list "0.0"
						} else {
							lappend hcap_str_list "$part"
						}
					}
				}

			} else {
				if {$use_brackets_for_draw == "Y"} {
					regsub -- {-} "($hcap_str)" "" hcap_str
				}
			}

			#
			# Formats the hcap_string using translations if needed for split style.
			#
			if {[llength $hcap_str_list] == 0} {
				set hcap_str "Error - hcap_str not formed correctly"

			} elseif {[llength $hcap_str_list] == 1} {
				set hcap_str [lindex $hcap_str_list 0]

			} else {
				set hcap_str_list [linsert $hcap_str_list 0 "AH_HCAP_SPLIT"]
				set hcap_str [eval "OB_mlang::ml_printf $hcap_str_list"]
			}
		}

	} elseif { [lsearch -exact [list MH WH] $mkt_sort] != -1 ||
	           $mkt_type == "A" } {

		if {$fb_result == "H"} {
			if {$hcap_value > 0.0} {
				set hcap_str "+$hcap_str"
			}
		} elseif {$fb_result == "A"} {
			if {$hcap_value < 0.0} {
				# replace the '-' with a '+'
				set hcap_str [string replace $hcap_str 0 0 "+"]
			} elseif {$hcap_value > 0.0} {
				set hcap_str "-$hcap_str"
			}
		} elseif {$fb_result == "L"} {
			if {$use_brackets_for_draw=="Y"} {
				regsub -- {-} "($hcap_str)" "" hcap_str
			}
		}

	} elseif {[lsearch -exact [list HL] $mkt_sort] == -1} {
		set hcap_str ""
	}

	return $hcap_str
}



array set SPECIAL_PRICE [list 13/8 2.62 15/8 2.87 11/8 2.37 8/13 1.61 2/7 1.28 1/8 1.12]


#-----------------------------------------------------
# Convert odds into string in customer specific format
#-----------------------------------------------------
proc get_price_str {lp_avail n d {gp_avail "N"} {is_decimal "N"} {use_html "1"} {mkt_sort ""}} {

	global LOGIN_DETAILS
	global SPECIAL_PRICE
	global LANG
	global DEFAULT_PRICE_TYPE

	set ah_price_type [OT_CfgGet AH_DISPLAY_PRICE_TYPE ""]

	# override price type if AH price type is configured
	if {[string length $ah_price_type] && $mkt_sort == "AH"} {
		set PriceStrType $ah_price_type
		ob::log::write DEBUG {overriding price type with AH price type $ah_price_type}
	} elseif {![info exists LOGIN_DETAILS(PRICE_TYPE)]} {
		set PriceStrType $DEFAULT_PRICE_TYPE
	} else {
		set PriceStrType $LOGIN_DETAILS(PRICE_TYPE)
	}

	# ..but ultimately allow customer preferences to take precedence
	if {![catch {
		set price_type_pref [OB_prefs::get_pref PRICE_TYPE]
	}] && [string length $price_type_pref]} {
		set PriceStrType $price_type_pref
	}

	if {$lp_avail == "Y"} {
		if {$n == "" && $d == ""} {
			return "-"
		}

		switch -- $PriceStrType {
			DECIMAL {
				if {$is_decimal == "Y"} {
					set price_str
				} elseif {![info exists SPECIAL_PRICE($n/$d)]} {
					set dec_price [expr {1.0 + double($n)/double($d)}]

					if {$d > 100} {
						set dps 3
						set scale 1000
					} else {
						set dps 2
						set scale 100
					}

					set scaled_price [expr {$dec_price * $scale}]
					# Round down using truncation
					set scaled_price_int [lindex [split $scaled_price "."] 0]
					set integer  [string range $scaled_price_int \
						0 end-$dps]
					set fraction [string range $scaled_price_int \
						end-[expr {$dps-1}] end]
					if {[string length $integer] == 0} {
						set integer "0"
					}
					if {[string length $fraction] == 0} {
						set fraction "0"
					}
					set price_str "${integer}.${fraction}"
				} else {
					set price_str $SPECIAL_PRICE($n/$d)
				}
				if {$gp_avail=="Y"} {
					append price_str " (GP)"
				}
				if {[regexp { } $price_str]} {
					if {$use_html == 1} {
						return "<nobr>$price_str</nobr>"
					} else {
						return $price_str
					}
				} else {
					return $price_str
				}
			}
			ODDS -
			default {
				if {$is_decimal == "Y"} {
					set price_str [util_convertToFraction $n]
				} elseif {$d == ""} {
					set price_str  "$n - 1"
				} elseif {$n == $d} {
					set price_str evens
				} else {
					set price_str "$n - $d"
				}
				if {$gp_avail=="Y"} {
					append price_str " (GP)"
				}
				if {[regexp { } $price_str]} {
					if {$use_html == 1} {
						return "<nobr>$price_str</nobr>"
					} else {
						return $price_str
					}
				} else {
					return $price_str
				}
			}
		}
	} else {
		return "SP"
	}
}

# ======================================================================
# Encryption/decryption functions for passwords pins etc
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# generate salt for password encryption
# ----------------------------------------------------------------------

proc generate_salt {} {

	set salt [string range [md5 [expr rand()]] 16 31]

	return $salt
}


# ----------------------------------------------------------------------
# encrypt the password using either md5 or sha1
# ----------------------------------------------------------------------

proc encrypt_password {pwd {salt ""}} {

	variable cfg

	# Append the salt if supplied
	if {$salt != ""} {
		set pwd ${pwd}[hextobin ${salt}]
	}

	if {[OT_CfgGet CUST_PWD_ENCRYPTION md5] == "sha1"} {
		return [sha1 -bin $pwd]
	} else {
		return [md5 -bin $pwd]
	}
}

# ----------------------------------------------------------------------
# encrypt the pin
# ----------------------------------------------------------------------

proc encrypt_pin {pin} {
	variable cfg

	if {[OT_CfgGet NO_ENCRYPT_ACCT 0]} {
		return $pin
	}

	set e [md5 $pin]
	set r ""

	foreach p {4 6 10 12 16 18 22 28} {
		append r [string index $e $p]
	}
	return $r
}



# Gets the salt for an admin user, looking by username
#
#   username - the username of the admin user to get salt for
#   returns  - either NO_SUCH_USER or the user's salt
#
proc get_admin_salt { username } {
	global DB

	set sql {
		select
			u.password_salt
		from
			tAdminUser u
		where
			u.username = ?
	}

	set stmt    [inf_prep_sql  $DB $sql]
	set rs      [inf_exec_stmt $stmt $username]
	set numrows [db_get_nrows $rs]

	if {$numrows < 1} {
		inf_close_stmt $stmt
		db_close $rs
		return [list ERROR NO_SUCH_USER]
	}

	set salt [db_get_col $rs 0 password_salt]
	db_close $rs
	return [list OK $salt]
}



# Resets the specified user's password hash salt.
#
# ** ONLY USE WHEN CHANGING THE PASSWORD FOR AN ACCOUNT **
# Changing this without updating the stored hash to match will
# invalidate a user's account.
#
#   username - the username of the admin user to generate salt for
#   returns  - either NO_SUCH_USER or the user's new salt
#
proc reset_admin_salt { username {new_salt ""} } {
	global DB

	if {$new_salt == ""} {
		set new_salt [generate_salt]
	}

	set sql {
		update
			tAdminUser
		set
			tAdminUser.password_salt = ?
		where
			tAdminUser.username = ?;
	}

	set stmt    [inf_prep_sql  $DB $sql]
	inf_exec_stmt $stmt $new_salt $username
	set numrows [inf_get_row_count $stmt]
	inf_close_stmt $stmt

	if {$numrows < 1} {
		return [list ERROR NO_SUCH_USER]
	}

	return [list OK $new_salt]
}



# Encrypt an admin user password
#
#   pwd     - plain text password to encrypt
#   salt    - optional salt to append before hashing
#   returns - encrypted password
#
proc encrypt_admin_password {pwd {salt ""}} {
	if {$salt != ""} {
		set pwd ${pwd}[hextobin ${salt}]
	}

	switch [string toupper [OT_CfgGet ADMIN_PASSWORD_HASH MD5]] {
		SHA1 {
			return [sha1 -bin $pwd]
		}
		MD5 -
		default {
			return [md5  -bin $pwd]
		}
	}
}


# Converts an existing password hash into salted SHA-1
#
#   username - the username of the user to change
#   password - the password of the user to change
#
#  returns:
#	- SUCCESS      - password hash successfully changed to SHA-1
#	- WRONG_LOGIN  - username/password is not valid, this may be due to an
#                    existing SHA-1 hash
#
proc convert_admin_password_hash {username password} {
	global DB

	set sql {
		select
			u.user_id as user_id
		from
			tAdminUser u
		where
			u.username = ? and
			u.password = ?
		group by u.username, u.user_id;
	}

	set stmt    [inf_prep_sql  $DB $sql]
	set rs      [inf_exec_stmt $stmt \
		                       $username \
							   [md5 -bin $password]]

	set numrows [db_get_nrows $rs]
	if {$numrows < 1} {
		inf_close_stmt $stmt
		db_close $rs
		return WRONG_LOGIN
	}

	set user_id [db_get_col $rs 0 "user_id"]
	inf_close_stmt $stmt
	db_close $rs

	set sql {
		update
			tAdminUser
		set
			tAdminUser.password = ?,
			tAdminUser.password_salt = ?
		where
			tAdminUser.user_id = ?;
	}

	set salt [generate_salt]
	set hash [encrypt_admin_password $password $salt]

	set stmt    [inf_prep_sql  $DB $sql]
	set rs      [inf_exec_stmt $stmt \
		                       $hash \
							   $salt \
							   $user_id]
	inf_close_stmt $stmt

	add_admin_sha1_flag $username

	return SUCCESS
}

# Adds a flag to the tAdminUserFlags table, marking the given
# user as having an SHA-1 password hash. Will silently fail if
# one already exists.
#
#    username - the username of the user to be affected
#
#  returns:
#	- SUCCESS      - flag successfully added
#	- ALREADY_SHA1 - flag already exists
#	- NO_SUCH_USER - user_id does not exist
#
proc add_admin_sha1_flag {username} {
	global DB

	# Look for a matching user and check for a SHA-1 flag
	set sql {
		select
			u.user_id as user_id,
			count(f.user_id) as has_flag
		from
			tAdminUser u,
			outer tAdminUserFlag f
		where
			u.user_id = f.user_id and
			u.username = ? and
			f.flag_name = "HASH_IS_SHA1"
		group by
			u.user_id;
	}

	set stmt    [inf_prep_sql  $DB $sql]
	set rs      [inf_exec_stmt $stmt \
		                       $username]
	set numrows [db_get_nrows $rs]
	if {$numrows < 1} {
		inf_close_stmt $stmt
		db_close $rs
		return NO_SUCH_USER
	}

	set user_id  [db_get_col $rs 0 "user_id"]
	set has_flag [db_get_col $rs 0 "has_flag"]
	inf_close_stmt $stmt
	db_close $rs


	# If there's no SHA-1 flag, add one.
	if {$has_flag < 1} {

		set sql {
			insert
			into tAdminUserFlag
				(user_id, flag_name)
			values
				(?, "HASH_IS_SHA1");
		}

		set stmt    [inf_prep_sql  $DB $sql]
		set rs      [inf_exec_stmt $stmt \
								   $user_id]
		inf_close_stmt $stmt

		return SUCCESS
	}
	return ALREADY_SHA1
}



# Checks for the presence of an entry in tAdminPassHist that conflicts
# with the given username and password. Also checks against the current
# password in tAdminUser.
#
#    username - the username of the user to be checked
#    password - the password to be checked for
#
#  returns:
#	- PWD_IS_OK      - no conflict with old password found
#	- PWD_IS_BAD     - new password matches old password
#
proc is_prev_admin_pwd {username password} {
	global DB

	set num_pwds [get_prev_admin_pwd_count]

	# Grab password entries
	set sql {
		select
			u.password,
			u.password_salt
		from
			tAdminUser u
		where
			u.username = ?
	}

	set stmt    [inf_prep_sql  $DB $sql]
	set rs      [inf_exec_stmt $stmt \
		                       $username]

	set numrows [db_get_nrows $rs]
	if {$numrows < 1} {
		return PWD_IS_OK
	}

	set old_hash [db_get_col $rs 0 "password"]
	set old_salt [db_get_col $rs 0 "password_salt"]

	set new_hash [ob_crypt::encrypt_admin_password $password \
												   $old_salt]

	if {$new_hash == $old_hash} {
		inf_close_stmt $stmt
		db_close $rs
		return PWD_IS_BAD
	}

	inf_close_stmt $stmt
	db_close $rs

	set sql [subst {
		select first $num_pwds
			u.user_id,
			h.hist_pass_id,
			h.password,
			h.password_salt
		from
			tAdminUser u,
			tAdminPassHist h
		where
			u.user_id = h.user_id and
			u.username = ?
		order by h.hist_pass_id desc;
	}]

	set stmt    [inf_prep_sql  $DB $sql]
	set rs      [inf_exec_stmt $stmt \
		                       $username]

	set numrows [db_get_nrows $rs]

	for {set i 0} {$i <  $numrows} {incr i} {
		set old_hash [db_get_col $rs $i "password"]
		set old_salt [db_get_col $rs $i "password_salt"]

		if {[string length $old_hash] < 40} {
			set new_hash [md5 $password]
		} else {
			set new_hash [encrypt_admin_password $password \
			                                     $old_salt]
		}

		if {$new_hash == $old_hash} {
			inf_close_stmt $stmt
			db_close $rs
			return PWD_IS_BAD
		}
	}

	inf_close_stmt $stmt
	db_close $rs
	return PWD_IS_OK
}



# Grabs the number of previous admin passwords to check from the database
proc get_prev_admin_pwd_count {} {
	global DB

	# Grab the number of old passwords to check
	set sql {
		select
			admn_pwd_num_rpt
		from
			tControl;
	}

	set stmt    [inf_prep_sql  $DB $sql]
	set rs      [inf_exec_stmt $stmt]

	set num_pwds  [db_get_col $rs 0 "admn_pwd_num_rpt"]

	inf_close_stmt $stmt
	db_close $rs

	return $num_pwds
}



# remove all the chars given in parameters from the string
proc remove_char {str char} {
	return [string map [list $char {}] $str]
}



# returns a list of active languages
proc get_active_langs {} {
	global DB

	set sql {
		select
			lang,
			name
		from
			tlang
		where
			status == 'A'
		order by
			disporder
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set lang_list [list]

	set nrows [db_get_nrows $rs]
	for {set r 0} {$r < $nrows} {incr r} {
		lappend lang_list [db_get_col $rs $r lang] [db_get_col $rs $r name]
	}

	db_close $rs

	return $lang_list
}

#
# Build the SOAP XML wrapper
#
# returns - the soap:Body child
#
proc build_soap_xml args {
	ob::log::write DEBUG {===>build_soap_xml}

	# SOAP Envelope
	set doc [dom createDocument soap:Envelope]

	set root [$doc documentElement]
	$root setAttribute \
		xmlns:xsi  {http://www.w3.org/2001/XMLSchema-instance} \
		xmlns:xsd  {http://www.w3.org/2001/XMLSchema} \
		xmlns:soap {http://schemas.xmlsoap.org/soap/envelope/}
		
	# SOAP Body
	set body [$doc createElement soap:Body]
	$root appendChild $body
	ob::log::write DEBUG {<===build_soap_xml}

	return [list $doc $body]
}


# Retrieve description of a language code
proc get_lang_name {lang} {

	global LANGUAGES

	init_languages

	if {[info exists LANGUAGES($lang)]} {
		return $LANGUAGES($lang)
	}

	return $lang
}


# Initialise languages
proc init_languages {} {

	global LANGUAGES
	global DB

	if {[info exists LANGUAGES(langs)] && [llength $LANGUAGES(langs)]} {
		return
	}

	# retrieve language codes and descriptions
	set sql {
		select
			lang,
			name
		from
			tlang
		where
			displayed = 'Y'
		order by
			disporder
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {

		set lang [db_get_col $rs $i lang]
		set name [db_get_col $rs $i name]

		set LANGUAGES($lang) $name
		lappend LANGUAGES(langs) $lang
	}

	db_close $rs
	return
}
