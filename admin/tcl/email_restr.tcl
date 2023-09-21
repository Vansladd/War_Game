# ==============================================================
# $Id: email_restr.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::EMAIL_RESTR {
	asSetAct ADMIN::EMAIL_RESTR::Go      [namespace code _go]
	asSetAct ADMIN::EMAIL_RESTR::Do      [namespace code do]
}



proc ADMIN::EMAIL_RESTR::_go {} {
	global  DB  RESTR  RESTR_TYPE

	set type_list [list EXACT Exact PRFIX Prefix SUFIX Suffix]
	set i 0
	foreach {code text} $type_list {
		set RESTR_TYPE($i,code) $code
		set RESTR_TYPE($i,text) $text
		set RESTR_TYPE($code) $text
		incr i
	}
	tpSetVar numTypes $i
	tpBindVar RestrTypeCode RESTR_TYPE code restrTypeIdx
	tpBindVar RestrTypeText RESTR_TYPE text restrTypeIdx

	# retrieve and bind email registration restrictions
	set sql {
		select
			r.restr_id,
			r.restriction,
			r.restr_type
		from
			tEmailRestriction r
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt  $stmt]
	inf_close_stmt $stmt

	set numRows [db_get_nrows $res]
	for {set i 0} {$i < $numRows} {incr i} {
		set RESTR($i,id)          [db_get_col $res $i restr_id]
		set RESTR($i,restriction) [db_get_col $res $i restriction]
		set RESTR($i,restr_type)  $RESTR_TYPE([db_get_col $res $i restr_type])
	}
	db_close $res

	tpSetVar  numRestr  $numRows
	tpBindVar RestrID     RESTR      id           restrIndex
	tpBindVar Restriction RESTR      restriction  restrIndex
	tpBindVar RestrType   RESTR      restr_type   restrIndex

	asPlayFile -nocache  email_restr.html
}



proc ADMIN::EMAIL_RESTR::do {} {
	global DB
	switch -- [reqGetArg SubmitName] {
		remove_restr {
			set sql {
				execute procedure pDelEmailRestriction (
					p_adminuser = ?,
					p_restr_id  = ?
				)
			}
			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt  $stmt  $::USERNAME  [reqGetArg restr_id]]
			inf_close_stmt $stmt
			db_close $res
			_go
		}
		add_restr {
			set sql {
				execute procedure pInsEmailRestriction (
					p_adminuser    = ?,
					p_restr_type   = ?,
					p_restriction  = ?
				)
			}
			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt  $stmt  $::USERNAME \
			                                [reqGetArg restr_type] \
			                                [reqGetArg restriction]]
			inf_close_stmt $stmt
			db_close $res
			_go
		}
		default {
			err_bind "un-known SubmitName"
			_go
		}
	}
}