# ======================================================================
# $Id: mlang_db_search.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# Copyright (C) 2001 Orbis Technology Ltd. All rights reserved.
#

#
# This is yet another rewrite of the mlang code, this timie the objective is
# to reduce the amount of memory consumed by the child processes whilst
# preserving the nice properties of the other recent mlang versions (being
# light on the database, picking up updates quickly and at the same time across
# all children).
#
# This version makes use of the newly added db_search functionality which
# allows us to search an ordered result set for a certain row using a quick
# binary search algorithm. By doing this we can avoid the use of the large
# tcl arrays that were consuming many MB of memory. Oddly enough it also
# appears to be more efficient in terms of cpu usage.
#
# The result set caching is done directly from within this file rather than
# through db.tcl so we can manage the caching directly.
#
# When updates occur in the db, a local copy is made of the result set in
# shared memory. The updated rows are deleted and replaced with their new
# versions, the new result set is sorted and placed in shared memory to replace
# the old version. A string is also stored containing the date of the last
# update for each language so that we can determine whether
#


namespace eval OB_mlang {

	variable MSG
	variable SEM ""
	variable CFG

	# Grab configs

	array set CFG [list FLAGS_COOKIE [OT_CfgGet FLAGS_COOKIE [list]]]

	namespace export ml_init
	namespace export ml_printf
	namespace export ml_lookup
	namespace export ml_set_lang
	namespace export XL
	namespace export get_xl_codes_by_lang
}

proc OB_mlang::ml_init {{preload_langs {}}} {

	variable SEM
	variable MSG

	_prepare_queries

	if {[OT_CfgGet MLANG_USE_SEM_LOCK 1]} {

		if {[set SEM_VAL [OT_CfgGet MLANG_SEMAPHORE_VAL ""]] == ""} {
			set SEM_VAL [OT_CfgGet PORTS]
		}
		set MSG(use_sem_lock) 1
		set SEM [ipc_sem_create $SEM_VAL]
	} else {
		set MSG(use_sem_lock) 0
	}

	set MSG(log_missing) [OT_CfgGet MLANG_LOG_MISSING_XL 0]

	_load_all_data $preload_langs

}

proc OB_mlang::_prepare_queries {} {

	OB_db::db_store_qry ml_get_langs {
		select
			lang,
			charset
		from
			tLang
	}

	#
	# We'll cache this query for a bit to stop everybody hammering to get
	# the updates when the site is busy.
	#
	OB_db::db_store_qry ml_get_last_update {
		select
		    max(last_update) as last_update
		from
		    tXLateVal v
		where
		    v.lang = ?
	} 120

	OB_db::db_store_qry ml_get_xl_updates {
		select
		    c.code,
			xlation_1,
			xlation_2,
			xlation_3,
			xlation_4
		from
			tXLateCode c,
		    tXLateVal  v
		where
		    c.code_id = v.code_id
		and v.lang    = ?
		and v.last_update >= ?
		and v.last_update <= ?
	}
}

#
# Run at startup to load the translations, as the query may take
# several seconds it uses a semaphore to make sure we only get the
# data once at startup
#

proc OB_mlang::_load_all_data {preload_langs} {

	variable MSG

	if {$preload_langs == "_all_"} {
		set preload_all 1
	} else {
		set preload_all 0
	}

	#
	# Retrieve all the languages
	#
	set rs [OB_db::db_exec_qry ml_get_langs]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set lang [db_get_col $rs $i lang]

		set MSG($lang,charset)     [db_get_col $rs $i charset]
		set MSG($lang,last_check_req) -1
		set MSG($lang,rs_key)      "_xlations,$lang"
		set MSG($lang,lu_key)      "_xlations_last_upd,$lang"
		set MSG($lang,cache_time)  [OT_CfgGet MLANG_CACHE_TIME 86400]
		set MSG($lang,valid_til)   0

		if {$preload_all || [lsearch $preload_langs $lang] >= 0} {

			 _load_lang $lang
		}
	}
}


#
# Load all the xlations for a given language with an update time <= to that
# passed in. The query result set is not cached as we are going to sort it
# and then cache it ourselves directly.
#

proc OB_mlang::_load_lang {lang} {

	variable MSG
	variable SEM

	if {$MSG(use_sem_lock)} {
		ob::log::write DEV {MLANG: Locking xlation load semaphore}
		ipc_sem_lock $SEM
	}

	# now that we have the semaphore check that we havn't been blocked whilst
	# someone else was loading the result set we are after

	set found_ok 0

	catch {

		set rs [asFindRs $MSG($lang,rs_key)]

		#
		# We have to do all this tom foolery because the appserver caching
		# lies to us sometimes because the cache time is nearly up and it wants
		# to avoid everybody hitting the db at the same time.
		#
		# So we need to check if the valid_til time has changed, if it has
		# then the appserver wasn't lying but somebody else has gone and got it
		# db. Otherwise we should go and get it.
		#

		if {!$MSG($lang,valid_til) ||
			$MSG($lang,valid_til) != [db_get_valid_til $rs]} {

			set MSG($lang,valid_til) [db_get_valid_til $rs]
			set MSG($lang,rs) $rs
			set found_ok 1
		}
	}

	if {$found_ok} {
		if {$MSG(use_sem_lock)} {ipc_sem_unlock $SEM}
		return
	}

	#
	# Ok, we've got the lock and the result set isn't there so we need to
	# go and retrieve it.
	#

	ob::log::write DEV {MLANG: Result set still not found}


	set start "0001-01-01 00:00:00"

	#
	# We use the _force here to avoid recently updated translations going
	# going missing alltogether.
	#

	set rs  [OB_db::db_exec_qry_force ml_get_last_update $lang]
	set end [db_get_col $rs 0 last_update]
	OB_db::db_close $rs


	if {[catch {

		set rs [OB_db::db_exec_qry ml_get_xl_updates $lang $start $end]

		db_sort -null-lo {code string asc} $rs

		asStoreRs     $rs  $MSG($lang,rs_key) $MSG($lang,cache_time)
		asStoreString $end $MSG($lang,lu_key) $MSG($lang,cache_time)

		set MSG($lang,rs) $rs
		set MSG($lang,valid_til) [db_get_valid_til $rs]

	} msg]} {

		if {$MSG(use_sem_lock)} {ipc_sem_unlock $SEM}
		ob::log::write ERROR {MLANG: Failed to load translations : $msg}
		error "MLANG: failed to retrieve translations : $msg"
	}

	if {$MSG(use_sem_lock)} {ipc_sem_unlock $SEM}
}


#
# This function will check for updates once per request (per language).
# Actually the query that checks for updates is cached so we don't actually
# check the db on every request.
#
# This function also retrieves the result set from shared memory so that we can
# use it for translation lookups during this request. If it's not there it will
# go off to the db and get it.
#

proc OB_mlang::_check_for_updates {lang} {

	variable MSG
	variable SEM

	# look for any reasons to check the translations result set for expiry

	set check_rs 0

	if {[info exists MSG($lang,rs)] && [info exists MSG($lang,last_check_req)]} {

		if {[lsearch -exact [db_get_rslt_list] $MSG($lang,rs)] == -1} {

			# our result set handle has been purged
			set check_rs 1

		} elseif {$MSG($lang,last_check_req) != [reqGetId]} {

			# we're in a new request
			set check_rs 1
		}

	} else {

		# we don't appear to have retrieved a result set at all yet
		set check_rs 1
	}

	if {!$check_rs} {

		# no point checking to see if the result set has expired
		return
	}

	set MSG($lang,last_check_req) [reqGetId]

	ob::log::write DEV {MLANG: checking updates for $lang}

	#
	# Get the last update time for this language
	#

	set lu_rs  [OB_db::db_exec_qry ml_get_last_update $lang]
	set lu_db  [db_get_col $lu_rs 0 last_update]
	OB_db::db_close $lu_rs

	#
	# Retrieve the result set from shared memory, asFindRs will throw an error
	# if the result set is not found. In whch case we need to head off to the
	# db to get it.
	#
	if {[catch {

		set rs [asFindRs     $MSG($lang,rs_key)]
		set lu [asFindString $MSG($lang,lu_key)]

		set MSG($lang,rs) $rs
		set MSG($lang,valid_til) [db_get_valid_til $rs]

		#
		# If there are new updates in the db we need to get them and add them
		# into out result set
		#
		if {$lu_db > $lu} {
			ob::log::write DEV {MLANG: loading updates for $lang}

			if {[catch {_load_updates $rs $lang $lu $lu_db} msg]} {
				ob::log::write DEV {MLANG: failed load updates : $msg}
			}

		}
	} msg]} {

		ob::log::write DEV {MLANG: Failed to locate rs, loading from db : $msg}

		_load_lang $lang
	}
}

#
# Load any updated translations and merge them into the main result set. This
# is where the scary stuff happens.
#

proc OB_mlang::_load_updates {main_rs lang from to} {

	variable MSG

	set upd_rs [OB_db::db_exec_qry ml_get_xl_updates $lang $from $to]

	#
	# Make a local copy of the shared result set so that we can manipulate it
	#
	set new_rs [db_dup $main_rs]

	#
	# We need delete the old rows from the result set before adding the new ones	#

	for {set i 0} {$i < [db_get_nrows $upd_rs]} {incr i} {

		set code [db_get_col $upd_rs $i code]

		if {[set row [db_search -sorted $new_rs [list code string $code]]] >= 0} {
			ob::log::write DEV {MLANG: deleting updated code $code}
			db_del_row $new_rs $row
		}

		db_add_row $new_rs [db_get_row $upd_rs $i]
	}

	OB_db::db_close $upd_rs

	#
	# Re-sort the result set based on code
	#

	db_sort -null-lo {code string asc} $new_rs

	#
	# Store the whole thing back into shared memory.
	#

	asStoreRs $new_rs $MSG($lang,rs_key) $MSG($lang,cache_time)
	asStoreString $to $MSG($lang,lu_key) $MSG($lang,cache_time)

	set MSG($lang,rs) $new_rs
}


#=============================================================================
#
# Below are the translation functions that are availaible to application code
# They should all map through to a call to _xl_code. I have no idea why there
# are quite as many functions that seem to be identical, but in the interest
# of backwards compatibility they have all been replicated.
#

#
# Standard translation function, will translate a string containing
# arbitrary numbers of '|' quoted strings.
#

proc OB_mlang::XL {str} {

	variable MSG
	global LANG

	_check_for_updates $LANG

	set reg {([^\|]*)\|([^\|]*)\|(.*)}

	set res ""

	while {[regexp $reg $str match head code str]} {

		append res $head
		append res [_xl_code $code $LANG]
	}

	append res $str
	return $res
}


#
# For use from TP_OB_mlang callback
#
proc OB_mlang::xl_code {code lang} {

	_check_for_updates $lang

	return [_xl_code $code $lang]

}


#
# This is the function that actually retrieves the translation directly from
# the result set by doing a binary search.
#

proc OB_mlang::_xl_code {code lang} {

	variable MSG

	set rs  $MSG($lang,rs)

	if {[set row [db_search -sorted $rs [list code string $code]]] >= 0} {

		set    res [db_get_col $rs $row xlation_1]
		append res [db_get_col $rs $row xlation_2]
		append res [db_get_col $rs $row xlation_3]
		append res [db_get_col $rs $row xlation_4]

	} else {
		set res $code
	}

	return $res
}


#
# Wrapper for ml_lookup that prints if translation is missing and returns code
#

proc OB_mlang::ml_printf {code args} {
	variable MSG
	global LANG

	_check_for_updates $LANG

	set val [_xl_code $code $LANG]

	if {$MSG(log_missing) && $val == $code} {

		ob::log::write ERROR {ml_printf: ERROR - translation not found for: $code in language: $LANG}

	}

	return [eval [linsert $args 0 format $val]]
}


#
# Returns the translation text for the specified key in the specified language,
# WTF is this for? It was in the old mlang.tcl so I've kept it for now.
#

proc OB_mlang::get_message {key lang} {
	return [xl_code $key $lang]
}

proc OB_mlang::ml_lookup {key lang} {
	return [xl_code $key $lang]
}



# ----------------------------------------------------------------------
# this function replaces both ml_set_default_lang and ml_set_login_lang
# which are normally called as part of req_init, this function should also
# be called in req_init after ob_check_login...
#
# Just call this after ob_check_login in req_init
#
# There are four possible places to get the language information:
#     1) default (from db)
#     2) cookie
#     3) argument to the page
#     4) user information (from db) if logged in
# ----------------------------------------------------------------------

proc OB_mlang::ml_set_lang {{dflt_lang "en"} {dflt_charset "iso8859-1"}} {

	global LOGIN_DETAILS
	global LANG CHARSET
	variable MSG
	variable CFG

	# Get our site flags / preferences cookie
	set flags_cookie      [get_cookie $CFG(FLAGS_COOKIE)]
	set flags             ""
	set cookie_language   ""

	if {$flags_cookie != ""} {
		set flags           [split $flags_cookie |]
		set cookie_language [lindex $flags 0]
	}

	# grab the language from the request as well
	set argument_language [ob_chk::get_arg LANG -on-err "" {RE -args {^[a-zA-Z]{2}$}}]

	# first check if user is logged in
	if {[::OB_login::ob_is_guest_user]} {
		set LANG [expr {$cookie_language   != "" ? $cookie_language   : $dflt_lang}]
		set LANG [expr {$argument_language != "" ? $argument_language : $LANG}]
	} else {

		if {![info exists LOGIN_DETAILS(LANG)]} {
			ob::log::write ERROR {MLANG:ml_set_lang: ERROR - you must call ob_check_login before this...}
		} elseif {$LOGIN_DETAILS(LANG) != ""} {
			set LANG $LOGIN_DETAILS(LANG)
		}
	}


	# now set the charset based upon the language
	if {$LANG == $dflt_lang} {
		set CHARSET $dflt_charset

	} else {
		set CHARSET $MSG($LANG,charset)
	}

	ob::log::write DEBUG {ml_set_lang : $LANG}
	ob::log::write DEBUG {ml_set_lang : Encoding is $CHARSET}
}

#
# This proc will return the list of translation codes for the language
# that has been passed in (after checking for updates)
#
proc OB_mlang::get_xl_codes_by_lang {lang} {

	variable MSG

	set tb_translations [list]

	_check_for_updates $lang

	for {set i 0} {$i < [db_get_nrows $MSG($lang,rs)]} {incr i} {
		set code [db_get_col $MSG($lang,rs) $i code]

		foreach {cur_code} [OT_CfgGet TB_TRANSLATION_CODES] {
			if {[string first $cur_code $code] != -1 && \
					[db_get_col $MSG($lang,rs) $i xlation_1] != "" && \
					[db_get_col $MSG($lang,rs) $i xlation_1] != "."} {
				set code_val                 [db_get_col $MSG($lang,rs) $i xlation_1]
				append code_val              [db_get_col $MSG($lang,rs) $i xlation_2]
				append code_val              [db_get_col $MSG($lang,rs) $i xlation_3]
				append code_val              [db_get_col $MSG($lang,rs) $i xlation_4]
				lappend tb_translations $code $code_val
			}
		}
	}
	return $tb_translations
}
