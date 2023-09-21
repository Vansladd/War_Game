# $Id: restrict_email.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Check against William Hill specific restrictions on E-Mail
#
# Configuration:
#     FUNC_RESTRICT_EMAIL    - Enables check on WillHill.  
#                              Wrap any calls to this package in 
#                              a check for that item.
#
# Synopsis:
#    package require ob_restrict_email ?1.0?
#
#

package provide util_restrict_email 1.0


# Variables
namespace eval ob_restrict_email {
	variable INIT 0
}


#----------------------------------
# Initialise.
#
#----------------------------------
proc ob_restrict_email::init {} {
	variable INIT

	if {$INIT} {
		return
	}

	set INIT 1

	_prepare_queries
}




proc ob_restrict_email::_prepare_queries {} {
	ob_db::store_qry  ob_restrict_email::get_email_restr {
		select
			r.restriction,
			r.restr_type
		from
			tEmailRestriction r
	} 5
}



#------------------------------------------------------------------------------
# Email check
#
# returns 1 if the email matches the restrictions in tEmailRestriction
# else returns 0
#
# Throws an error if unable to retrieve the restrictions.
#------------------------------------------------------------------------------

proc ob_restrict_email::is_restricted {email} {

	# Make uppercase to allow case insensitivity
	set email [string toupper $email]

	if {[catch {
		set res [ob_db::exec_qry ob_restrict_email::get_email_restr]
	} msg]} {
		error  "Unable to retrieve email restrictions: $msg"
	}
	# foreach restriction in tEmailRestrictions
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {

		# replace special characters to avoid faulty matches.
		set filtered_restr [regsub -all -- {[*?]} [db_get_col $res $i restriction] {\\\0}]
		# Make uppercase to allow case insensitivity
		set filtered_restr [string toupper $filtered_restr]

		switch -- [db_get_col $res $i restr_type] {
			PRFIX {
				set match_cmd {string match ${filtered_restr}* $email}
			}
			SUFIX {
				set match_cmd {string match *$filtered_restr $email}
			}
			EXACT {
				set match_cmd {string match $filtered_restr $email}
			}
		}

		if {[eval $match_cmd]} {
			return 1
		}
	}
	db_close $res
	return 0
}

ob_restrict_email::init
