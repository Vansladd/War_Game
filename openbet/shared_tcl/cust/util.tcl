# $Id: util.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Utilities which focus on customers/users.
#
# Synopsis:
#     package require cust_util ?4.5?
#
# If not using the package within appserv, then load libOT_Tcl.so
#
# Procedures:
#    ob_cust::init              one time initialisation
#    ob_cust::upd_idx           update customer indexed identifiers
#    ob_cust::normalise_unicode Replace German, spanish or Greek characters
#                               with their english equivalents
#    ob_cust::gen_latin_regex   Generate a regex that includes german,
#                               spanish and greel
#    ob_cust::get_cust_key     calculate the LiveServ channel ID from the customer ID
#

package provide cust_util 4.5



# Dependencies
#
package require util_log 4.5
package require util_db  4.5



# Variables
#
namespace eval ob_cust {

	variable INIT

	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
proc ob_cust::init args {

	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {CUST: init}

	# prepare SQL queries
	_prepare_qrys

	# init unicode map
	_load_unicode_normalisations

	# init
	set INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_cust::_prepare_qrys args {

	# get the necessary values for populating tCustIndexedId
	ob_db::store_qry ob_cust::get_cust_idx_values {
		select
			nvl(email,'') email,
			nvl(replace(addr_postcode,' ',''),'') addr_postc,
			nvl(replace(fname,' ',''),'') fname,
			nvl(replace(lname,' ',''),'') lname,
			nvl(replace(addr_street_1,' ',''),'')||NVL(replace(addr_street_2,' ',''),'') address
		from
			tCustomerReg
		where
			cust_id = ?
	}

	# update/add tCustIndexedId entries
	ob_db::store_qry ob_cust::upd_cust_idx_entry {
		execute procedure pUpdCustIdxEntry(
			p_cust_id    = ?,
			p_type       = ?,
			p_identifier = ?
		)
	}

	# retrieve unicode data
	ob_db::store_qry ob_cust::get_unicode_normalisations {
		select
			unicode_char,
			normalised_char
		from
			tUnicodeNormalisation
	}
}



#--------------------------------------------------------------------------
# Miscellaneous Utilities
#--------------------------------------------------------------------------

# Update/insert customer indexed identifiers via the stored procedure
# pUpdCustIdx.
#
#   cust_id   - customer identifier
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#
proc ob_cust::upd_idx { cust_id {in_tran 0} } {

	ob_log::write DEBUG {CUST: upd_idx cust_id=$cust_id in_tran=$in_tran}

	# update
	if {[catch {set rs [ob_db::exec_qry ob_cust::get_cust_idx_values $cust_id]} msg]} {
		ob_log::write ERROR {CUST: get_cust_idx_values $msg}
		error $msg
	}

	# start update
	if {!$in_tran} {
		ob_db::begin_tran
	}

	foreach type [db_get_colnames $rs] {
		set identifier [normalise_unicode [db_get_col $rs 0 $type] 0 1]
		# update
		if {[catch {ob_db::exec_qry ob_cust::upd_cust_idx_entry $cust_id $type $identifier} msg]} {
			ob_log::write ERROR {CUST: upd_cust_idx_entry $msg}
			if {!$in_tran} {
				ob_db::rollback_tran
			}
			error $msg
		}
	}

	# commit update
	if {!$in_tran} {
		ob_db::commit_tran
	}

}

#
# Loads the unicode normalisation map to memory
#
proc ob_cust::_load_unicode_normalisations args {

	global UNICODE_MAP

	ob_log::write DEBUG {CUST: _load_unicode_normalisations}

	# load normalisations
	if {[catch {set rs [ob_db::exec_qry ob_cust::get_unicode_normalisations]} msg]} {
		ob_log::write ERROR {CUST: _load_unicode_normalisations: $msg}
		error $msg
	}

	set UNICODE_MAP(allowed)   [list]
	set UNICODE_MAP(map)       [list]
	set UNICODE_MAP(force_map) [list]
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		if {[info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8"} {
			set unicode [db_get_col $rs $i unicode_char]
		} else {
			set unicode [encoding convertfrom utf-8 [db_get_col $rs $i unicode_char]]
		}
		set normalised [db_get_col $rs $i normalised_char]

		# for checking
		lappend UNICODE_MAP(allowed) $unicode

		# for normalisation
		if {$normalised != ""} {
			lappend UNICODE_MAP(map) $unicode
			lappend UNICODE_MAP(map) $normalised

			lappend UNICODE_MAP(force_map) $unicode
			lappend UNICODE_MAP(force_map) $normalised
		} else {
			lappend UNICODE_MAP(force_map) $unicode
			lappend UNICODE_MAP(force_map) [OT_CfgGet FORCE_CHAR_FOR_UNICODE_NORM "X"]
		}

		# for whatever else
		set UNICODE_MAP($unicode) $normalised

	}

}

#
# Checks a string contains only allowed characters
#		String
#			- String to check
#
proc ob_cust::allowed_unicode { string } {

	global UNICODE_MAP

	# build regular expression

	# ASCII
	set re {\x20-\x7E}
	# allowed list
	append re [join $UNICODE_MAP(allowed) {}]


	set ret [regexp "^\[$re\]*$" [encoding convertfrom utf-8 $string]]

	ob_log::write DEBUG {CUST: allowed_unicode: regexp ^\[$re\]*$ [encoding convertfrom utf-8 $string] = $ret}

	return $ret

}


#
# Normalises a unicode string for searching purposes
#		string
#			- The string to convert
#		force
#			- Use the force conversion list that picks up configed maps
#		to_upper
#			- Convert the mapped string to upper
#
proc ob_cust::normalise_unicode { string {force 0} {upper 1}} {

	global UNICODE_MAP

	if {$force} {
		set map $UNICODE_MAP(force_map)
	} else {
		set map $UNICODE_MAP(map)
	}

	# We need to be careful here.
	if {!([info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8")} {
		set string [encoding convertfrom utf-8 $string]
	}

	set norm_string [string map $map $string]
	if {$upper} {
		set norm_string [string toupper $norm_string]
	}

	ob_log::write DEBUG {CUST: normalise_unicode: string map $map [string toupper $string] = $norm_string}

	if {!([info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8")} {
		set norm_string [encoding convertto utf-8 $norm_string]
	}

	return $norm_string
}


#
# gen_latin_regex
#	Adds latin characters for spanish, french and german
#
#	pre  -   Start of the regex
#	post -   End of the regex
#	Returns - $pre+regexs +$post
proc ob_cust::gen_latin_regex {pre post} {
	
	set cregex [join [OT_CfgGet FOREIGN_CHARACTERS {}] {}]
	set cregex [string map "{ } {}" $cregex]

	return "$pre$cregex$post"
}

# Calculate the LiveServ channel ID from the customer ID.
#
#     cust_id    customer identifier
#
proc ob_cust::get_cust_key {cust_id} {
	return [_semi_flip [_circular_left_shift $cust_id 24]]
}

# Semi-flip function.
# Specifically, it flips all odd numbered bits (1st, 3th, 5th bits etc.)
# and preserves all the even numbered bits.
#
#   n    the input number
#
proc ob_cust::_semi_flip {n} {
	return [expr {$n ^ 0x55555555}]
}

# Circular left-shift with the sign bit preserved.
#
#   n    the input number
#   k    the number of positions to shift by
#
proc ob_cust::_circular_left_shift {n k} {
	set r 0

	for {set i 0} {$i < [expr {31 - $k}]} {incr i} {
		set r [expr {$r | (($n & (1 << $i)) << $k)}]
	}
	
	for {set i [expr {31 - $k}]} {$i < 31} {incr i} {
		set r [expr {$r | (($n & (1 << $i)) >> (31 - $k))}]
	}
	
	return $r
}
