# ======================================================================
# $Id: mlang.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# Copyright (C) 2001 Orbis Technology Ltd. All rights reserved.
#
# ----------------------------------------------------------------------
# Leaner and meaner multilingual stuff. XL handles parsing the pipe
# separated strings, whilst ml_printf handles getting translations from
# the local cache or the database if no cached value exists.
# ml_init should be called somewhere in main_init
#
# ----------------------------------------------------------------------

#open namespace
namespace eval OB_mlang {

	# export list
	namespace export ml_init
	namespace export XL
	namespace export ml_printf
	namespace export XL_inf
	namespace export ml_set_lang

	# following removed...
	# namespace export ml_set_default_lang
	# namespace export ml_set_login_lang
	# reason :
	# now uses LOGIN_DETAILS array to get lang code so should
	# either give customers lang
	# or the default (guest) users lang
	# (which should be set to the default lang)

	# array to hold message cache...
	variable MSG
	variable ML_SEM
	variable OFFSET
}


proc OB_mlang::ml_init args {

	variable OFFSET
	variable ML_SEM

	if {[OT_CfgGet MLANG_USE_SEM_LOCK 0]} {

		ob::log::write DEBUG {MLANG_USE_SEM_LOCK set , using new style xlations}

		rename ml_lookup__VALID_TILL ml_lookup

		#
		# Use a semaphore to stop everyone going to get the xlations
		#
		set ML_SEM [ipc_sem_create [OT_CfgGet PORTS 1818]]

	} else {
		ob::log::write DEBUG {MLANG_USE_SEM_LOCK not set, using old style xlations}

		rename ml_lookup__ORIG ml_lookup
	}

	set qry_cache_time [OT_CfgGet MLANG_QRY_CACHE_TIME 600]


	# return a message xlation

	db_store_qry get_message_xl {
		select x.xlation_1,
			   x.xlation_2,
			   x.xlation_3,
			   x.xlation_4
		from   tXlateCode c, tXlateVal x
		where  c.code_id = x.code_id
		and    c.code = ?
		and    x.lang = ?
	}

	db_store_qry get_messages_for_lang {
		select c.code,
			   x.xlation_1,
			   x.xlation_2,
			   x.xlation_3,
			   x.xlation_4
		from   tXlateCode c, tXlateVal x
		where  c.code_id = x.code_id
		and    x.lang = ?
	} $qry_cache_time

	db_store_qry mlang_query_charset {
		select 	charset
		from 	tlang
		where 	lang = ?
	} 1000


	#
	# To prevent everyone going to get the new Xlations
	# at the same time we subtract a random number of
	# seconds from the expiry time
	#
	set pc [expr {$qry_cache_time * 0.1}]

	if {$pc > 60} {
		set pc 60
	}

	set OFFSET [expr {int(rand() * $pc)}]
	ob::log::write DEBUG {cache_offset set to $OFFSET}
}


# ----------------------------------------------------------------------
#
# Arguments
# key  : english (or default language) text string in 'printf' format
#       including placeholder strings e.g. '%2$s' see man printf
# args : list of extra bits to fill in the placeholders in the 'key' string
#
# ----------------------------------------------------------------------
proc OB_mlang::ml_printf {key args} {

	global LANG

	set lang $LANG

	set tmp [ml_lookup $key $lang]

	if {$tmp!=""} {
		set key $tmp
	} else {
		ob::log::write ERROR {ml_printf: ERROR - translation not found for: $key in language: $lang}
	}

	OT_LogWrite 100 "ml_printf:key=$key (for lang=$lang)"

	return [eval [linsert $args 0 format $key]]
}

proc OB_mlang::ml_lookup__VALID_TILL {key lang} {

	variable MSG
	variable ML_SEM
	variable OFFSET

	if {![info exists MSG($lang,valid_til)] || ([clock seconds] > $MSG($lang,valid_til))} {

		ipc_sem_lock   $ML_SEM
		if {[catch {set rs [db_exec_qry get_messages_for_lang $lang]}]} {
			ipc_sem_unlock $ML_SEM
			return ""
		}
		ipc_sem_unlock $ML_SEM

		foreach e [array names MSG "*,$lang"] {
			unset MSG($e)
		}

		set nrows [db_get_nrows $rs]
		for {set i 0} {$i < $nrows} {incr i} {
			set xl "[db_get_col $rs $i xlation_1][db_get_col $rs $i xlation_2][db_get_col $rs $i xlation_3][db_get_col $rs $i xlation_4]"
			set MSG([db_get_col $rs $i code],$lang) $xl
		}

		set MSG($lang,valid_til) [expr {[db_get_valid_til $rs] - $OFFSET}]
		db_close $rs
	}

	if {[info exists MSG($key,$lang)]} {
		return $MSG($key,$lang)
	} else {
		return ""
	}
}

proc OB_mlang::ml_lookup__ORIG {key lang} {

	variable MSG

	# does a translation exist in the cache?
	if {[info exists MSG($key,$lang)]} {
		set tmp $MSG($key,$lang)
	} else {
		set tmp [get_message $key $lang]
		ml_insert $key $lang $tmp
	}

	return $tmp
}

proc OB_mlang::get_message {key lang} {

	# attempt the query
	if {[catch {set rs [db_exec_qry get_message_xl $key $lang]} msg]} {
		ob::log::write ERROR {get_message query failed for $key, $lang : $msg}
		return ""
	}

	# should return 1 row
	if {[db_get_nrows $rs] != 1} {
		set message ""
	} else {
		set message "[db_get_col $rs 0 xlation_1][db_get_col $rs 0 xlation_2][db_get_col $rs 0 xlation_3][db_get_col $rs 0 xlation_4]"
	}

	db_close $rs
	return $message
}

proc OB_mlang::ml_set_lang_cookie {lang} {
	tpBufAddHdr "Set-Cookie" "LANG=$lang; path=/; expires=Sat, 01 Jan 3000 00:00:00;"
}

# ----------------------------------------------------------------------
# Put an entry in MSG
# key is the english version
# lang is 2 character language code
# xlation is the relevant translation
# ----------------------------------------------------------------------

proc OB_mlang::ml_insert {key lang xlation} {
	variable MSG

	set MSG($key,$lang) $xlation
}


# ----------------------------------------------------------------------
# XL translates all symbols marked up for translation in the given phrase
# symbols are marked up by enclosing them in pipes |<symbol>|
# |ARSE| |VS| |MANU| should be transalated to
# Arsenal V Manchester Utd (in english)
# ----------------------------------------------------------------------

proc OB_mlang::XL {str} {

	set res ""
	while {[regexp {([^\|]*)\|([^\|]*)\|(.*)} $str match head code str]} {
		append res $head
		append res [ml_printf $code]
	}
	append res $str
	return $res
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

	# grab the language from the cookie (if available)
	set cookie_language   [get_cookie "LANG"]
	set argument_language [reqGetArg "LANG"]

	# first check if user is logged in
	if {[::OB_login::ob_is_guest_user]} {

		set LANG $dflt_lang

		if {$cookie_language != ""} {
			set LANG $cookie_language
		}

		if {$argument_language != ""} {
			set LANG $argument_language
		}

	} else {

		if {![info exists LOGIN_DETAILS(LANG)]} {
			ob::log::write ERROR {ml_set_lang: ERROR - you must call ob_check_login before this...}
		} elseif {$LOGIN_DETAILS(LANG) != ""} {
			set LANG $LOGIN_DETAILS(LANG)
		}
	}


	# now set the charset based upon the language
	if {$LANG == $dflt_lang} {
		set CHARSET $dflt_charset

	} else {
		set rs [db_exec_qry mlang_query_charset $LANG]
		if {$rs == 0} {
			set LANG    $dflt_lang
			set CHARSET $dflt_charset
		} else {
			set CHARSET [db_get_col $rs charset]
		}
		db_close $rs
	}

	# set cookie value if different from current
	if {$cookie_language != $LANG} {
				ml_set_lang_cookie $LANG
	}

	ob::log::write DEBUG {ml_set_lang : $LANG}
	ob::log::write DEBUG {ml_set_lang : Encoding is $CHARSET}
}
