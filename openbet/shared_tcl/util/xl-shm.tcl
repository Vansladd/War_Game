# $Id: xl-shm.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# Copyright (c) 2007 Orbis Technology Ltd. All rights reserved.
#
# Primary purpose is to translate message codes (stored in tXLateCode)
# into language-specific translations (stored in tXLateVal).
#
# This version requires that shared memory is available. If unsure,
# use the util_xl package instead.
#
# Configuration:
#   XL_SEMAPHORE_ENABLE    Enable semaphore                       (1)
#   XL_SEMAPHORE_PORT      Semaphore key (overrides PORTS)        ("")
#   XL_QRY_CACHE_TIME      The xlations query cache time.         (120)
#                          NB: this is effectively the maximum time it
#                          should take for a translation change to appear.
#   XL_RS_CACHE_TIME       The xlations rs cache time .           (99999)
#                          NB: this is effectively the maximum age of
#                          the xlations result set in shared memory -
#                          after this is reached, it'll be reloaded even
#                          if no xlations appear to have been changed.
#   XL_TP_SET_HOOK         Enable tpXlateSetHook                  (0)
#   XL_LOAD_ON_STARTUP     List of lang codes to load on startup  (_all_)
#   XL_LOAD_BY_GROUPS      Load xlations by group(s)              (0)
#   XL_LOAD_GROUPS         | delimetered list of groups           ("")
#                          NB: groups 'API %' are automatically appended
#   XL_USE_FAILOVER_LANG   if translation doesn't exist in current (0)
#                          lang then then first try falling back to
#                          the failover language
#   XL_USE_DEFAULT_LANG    If translation doesn't exist in current (0)
#                          lang then fall back to the default lang
#
# Synopsis:
#   package require util_xl_shm ?4.5?
#
# Procedures:
#   ob_xl::init            one time initialisation
#   ob_xl::get             get language information
#   ob_xl::sprintf         formatted code translation
#   ob_xl::XL              translate a phrase
#
# Notes:
#
#   * This is roughly the fifth distinct version of the translation module.
#
#   * Goals are:
#     - Minimise memory usage of child processes.
#     - Maximise performance of translation procs.
#     - Minimise time it takes for xlations changes to appear.
#     - Minimise database and CPU load.
#     - Follow the new repository coding style and interface.
#
#   * These goals above are achieved in part by:
#     - Keeping xlations in shared memory rather than huge arrays.
#     - Only loading updated xlations rather than all xlations.
#     - Using db_search -sorted to rapidly lookup xlations in shared mem.
#
#   * Ensure your SHM_CACHE_SIZE is set quite high before using this package.
#
# Known Bugs:
#
#   * Translation deletes are not picked up until the result set falls
#     out of shared memory.
#   * The result set valid_til checking from the 'slater' version is not
#     performed (see inline comments).
#   * Bad things will happen if shared memory is exhausted.
#   * Error checking is not exemplary.
#

package provide util_xl_shm 4.5



# Dependencies
#
package require util_db  4.5
package require util_log 4.5
package require util_control 4.5



# Variables
#
namespace eval ob_xl {

	variable XL
	variable CFG
	variable SEM
	variable INIT
	variable LANG

	# initially disable use of semaphore
	set SEM ""

	# set current request number
	set LANG(req_no) -1

	# init flag
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
proc ob_xl::init args {

	variable SEM
	variable CFG

	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {XL: init}

	# auto reset package data?
	if {[info commands reqGetId] != "reqGetId"} {
		error "XL: reqGetId not available for auto reset"
	}

	# get configuration
	set port [OT_CfgGet PORTS 1818]
	array set OPT [list \
	        default_charset   iso8859-1\
	        semaphore_enable  1\
	        semaphore_port    $port\
	        tp_set_hook       0\
	        qry_cache_time    120\
	        rs_cache_time     99999\
	        load_on_startup   [OT_CfgGet XL_LANG_ON_STARTUP "_all_"]\
	        load_by_groups    0\
	        load_groups       ""\
	        use_failover_lang 0\
	        use_default_lang  0\
	        shm_upd_chk_frq   0\
	]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "XL_[string toupper $c]" $OPT($c)]
	}

	# enable the semaphore
	# - semaphore protects the creation of the cached result set, therefore,
	#   stopping more than one appserv executing the same query
	#   (result-set can be quite large, as all the translations for each lang
	#   is returned)
	if {$CFG(semaphore_enable)} {
		ob_log::write INFO {XL: enabling semaphore port=$CFG(semaphore_port)}
		set SEM [ipc_sem_create $CFG(semaphore_port)]
	} else {
		ob_log::write WARNING {XL: not using semaphore}
	}

	# enable TP xlate hook
	if {$CFG(tp_set_hook)} {
		ob_log::write WARNING {XL: enabling tpXlateSetHook ob_xl::sprintf}
		tpXlateSetHook ob_xl::sprintf
	}

	# prepare package queries
	_prepare_qrys

	# load all the xlations on startup
	if {$CFG(load_on_startup) != "_none_"} {
		_load_all
	} else {
		ob_log::write WARNING {XL: xlations not loaded on startup}
	}

	# successfully initialised
	set INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_xl::_prepare_qrys args {

	variable CFG

	# are we loading translations by groups
	set groups ""
	if {$CFG(load_by_groups)} {
		ob_log::write WARNING {XL: enabling load by groups}

		# get API groups
		_get_api_groups

		# build the group sql
		set grp [split $CFG(load_groups) |]
		foreach g $grp {
			if {$groups != ""} {
				append groups ","
			}
			append groups "'$g'"
		}
		set groups "and c.group in ($groups)"
	}

	# Get the last time the tXLateVal table was updated for a particular
	# lang. The cache time of this query effectively sets the maximum length
	# of time an xlation chnange will take to appear.
	set sql {
		select
		    max(last_update) as last_update
		from
		    tXlateVal
		where
		    lang = ?
	}
	ob_db::store_qry ob_xl::get_last_update $sql $CFG(qry_cache_time)
	# XXX Obviously, it would make more sense to use ob_db::exec_qry_force
	# rather store  a separate uncached version of the query.
	# However, exec_qry_force seems buggy in some db-multi.tcl's - unset
	# errors sometimes occur in ob_db_multi::req_end.
	ob_db::store_qry ob_xl::get_last_update_no_cache $sql

	# Retrieve xlations for a lang that were modified within a date range.
	# There may be an additional clause to restrict the xlations to those
	# in certain groups.
	# Note that we don't cache this query at all (and it's important that we
	# don't) - we only execute it when we're sure we need to.
	set sql [subst {
		select
		    c.code,
		    c.code_id,
		    v.lang,
		    v.xlation_1,
		    v.xlation_2,
		    v.xlation_3,
		    v.xlation_4
		from
		    tXlateCode c,
		    tXlateVal  v
		where
		    c.code_id = v.code_id
		and v.lang = ?
		and v.last_update >= ?
		and v.last_update <= ?
	}]
	if {$groups != ""} {
		append sql $groups
	}
	ob_db::store_qry ob_xl::get_xlations $sql

	# Prep a seperate version to run on initial load
	ob_db::store_qry ob_xl::get_xlations_load $sql

	# get language details
	ob_db::store_qry ob_xl::get {
		select
		    lang,
		    name,
		    charset,
		    failover
		from
		    tLang
		where
		    status = 'A'
	} 600
}



#--------------------------------------------------------------------------
# Get
#--------------------------------------------------------------------------

# Get language specific information, either language's charset/name or a list
# of all available language codes.
#
#    item    - language item to retrieve (charset|name|failover|codes)
#    lang    - language code (default: "")
#    def     - default if the requested item is not found (default: "")
#    returns - request item data;
#              if requesting 'code', then list of available language codes
#
proc ob_xl::get { item {lang ""} {def ""} } {

	variable CFG
	variable LANG

	if {![regexp {^(charset|name|failover|codes)$} $item]} {
		error "Illegal language item - $item"
	}

	# current request number
	set id [reqGetId]

	# different request, update cache
	if {$LANG(req_no) != $id} {

		# get all the active language details
		set rs [ob_db::exec_qry ob_xl::get]

		unset LANG
		set LANG(req_no) $id
		set LANG(codes)  [list]

		# store in cache
		set nrows [db_get_nrows $rs]
		for {set i 0} {$i < $nrows} {incr i} {
			set l                 [db_get_col $rs $i lang]
			lappend LANG(codes)   $l
			set LANG($l,name)     [db_get_col $rs $i name]
			set LANG($l,charset)  [db_get_col $rs $i charset]
			set LANG($l,failover) [db_get_col $rs $i failover]
		}
		ob_db::rs_close $rs
	}

	if {$item != "codes"} {
		if {[info exists LANG($lang,$item)]} {
			return $LANG($lang,$item)
		} else {
			return $def
		}
	} else {
		return $LANG(codes)
	}
}


#--------------------------------------------------------------------------
# Translate xlate codes
#--------------------------------------------------------------------------


#
# Internal translation lookup procedure - MUST have previously called
# _update for the given lang within this request.
#
proc ob_xl::_lookup { lang code } {

	variable XL

	# Get handle to result set in shared mem for this lang. The _update proc
	# will have ensured that it exists during this request.

	set rs $XL($lang,rs)

	# The result set has been sorted for quick lookup by code.
	set row [db_search -sorted $rs [list code string $code]]

	if {$row >= 0} {

		set    res [db_get_col $rs $row xlation_1]
		append res [db_get_col $rs $row xlation_2]
		append res [db_get_col $rs $row xlation_3]
		append res [db_get_col $rs $row xlation_4]

	} else {

		# No translation found - return the code instead.

		set res $code

	}

	return $res
}


##
# Translate a xlate code, where the resultant translation may contain the Tcl
# format command (equivalent to ANSI c sprintf) specifiers (e.g. %s, %d, etc)
# which refer to the format arguments supplied, as well as our own specifiers
# with syntax %{varName} which refer to the values of global Tcl variables.
#
# Parameters:
#   lang    - language code
#   code    - xlate code
#   args    - format arguments
#             ignored if the translation text contains no specifiers
# Returns:
#  Translation text if found; otherwise the code.
#  May throw an error if a specifier is badly formed or missing a format
#  argument.
#
# Notes:
#   * Variable specifier substitution occurs in a pass before the Tcl
#     format specifier substituion.
#   * Some languages may fall back to the default language if no translation
#     was found (this is configurable).
#
##
proc ob_xl::sprintf { lang code args } {

	variable CFG

	# check for updates
	_update $lang

	# Look up the translation (will return the code if there is none).
	set xl [_lookup $lang $code]

	# If there was no translation, try the failover language instead,
	# followed by the default language, provided the relevant config options
	# are enabled and we're not already translating into the default/failover
	# language.

	if { [string equal $xl $code] && $CFG(use_failover_lang)} {
		set failover_lang [ob_xl::get failover $lang $lang]
		if {$lang != $failover_lang && $failover_lang != ""} {
			_update $failover_lang
			set xl [_lookup $failover_lang $code]
		}
	}

	if {[string equal $xl $code] && $CFG(use_default_lang)} {
		set default_lang [ob_control::get default_lang]
		if {$lang != $default_lang} {
			_update $default_lang
			set xl [_lookup $default_lang $code]
		}
	}

	# Return swiftly if no specifiers present.
	if { [string first % $xl] == -1 } {
		return $xl
	}

	# Substitute special specifiers:
	#
	#   %{varName}   : replaced the global variable "varName"
	#   %(specifier) : replaced with %s after modifying the appropriate parameter

	if {[regexp "%\[^duioxXbcsfeEgG%\]*\[\{(\]" $xl]} {
		set idx 0
		set arg -1
		set xl_new ""

		while {$idx < [string length $xl]} {
			# find next format specifier

			set idx_next [string first % $xl $idx]
			if {$idx_next == -1} {
				append xl_new [string range $xl $idx end]
				break
			} else {
				append xl_new [string range $xl $idx $idx_next]
				set idx [incr idx_next]
			}

			# xl_new should now include everything up to and
			# including the % of the current format specifier

			set modifiers ""
			set extra_args 0

			while {[string first [string index $xl $idx] "duioxXbcsfeEgG%\{("] == -1} {
				append modifiers [string index $xl $idx]
				incr idx
				if {[string index $xl $idx] == "*"} {
					# * as a width or precision consumes an extra argument
					incr extra_args
				}
			}
			if {[string index $xl $idx] != "\{" && [string index $xl $idx] != "%"} {
				# neither %% nor %{varName} consume an argument
				incr arg
			}
			regexp {^(0*([1-9]\d*)\$)?(.*)$} $modifiers all xpg3 pos modifiers
			if {[string length $pos]} {
				# XPG3 positions are 1-based
				incr pos -1
			} else {
				# use our argument count
				set pos $arg
			}
			incr arg $extra_args
			incr pos $extra_args

			# idx should now be pointing at the specifier itself
			# and pos should be pointing at the appropriate argument

			if {[string index $xl $idx] == "\{"} {
				# variable substitution
				set idx_last [string first "\}" $xl $idx]
				if {$idx_last == -1} {
					error "unbalanced field specifier \"\{\""
				}
				set varname [string range $xl [expr {$idx + 1}] [expr {$idx_last - 1}]]
				if {[info exists ::$varname] && ![array exists ::$varname]} {
					set xl_new [string replace $xl_new end end [format "%${modifiers}s" [set ::$varname]]]
				} else {
					set xl_new [string replace $xl_new end end [format "%${modifiers}s" $varname]]
				}
				set idx [incr idx_last]
			} elseif {[string index $xl $idx] == "("} {
				# extended specifier
				set idx_last [string first ")" $xl $idx]
				if {$idx_last == -1} {
					error "unbalanced field specifier \")\""
				}
				set specifier [string range $xl [expr {$idx + 1}] [expr {$idx_last - 1}]]
				if {$pos >= [llength $args]} {
					error "not enough arguments for all format specifiers"
				}
				switch -glob -- $specifier {
					O* {
						set args [lreplace $args $pos $pos [ordinal [lindex $args $pos] $lang [string range $specifier 1 end]]]
						append xl_new "${xpg3}${modifiers}s"
					}
					default {
						append xl_new "${xpg3}${modifiers}s"
					}
				}
				set idx [incr idx_last]
			} else {
				append xl_new "${xpg3}${modifiers}[string index $xl $idx]"
				incr idx
			}
		}

		set xl $xl_new
	}

	# Substitute any Tcl format specifiers (%s, %d etc).

	if { [string first % $xl] != -1 } {
		catch {set xl [eval [linsert $args 0 format $xl]]}
	}

	return $xl
}



##
# This procedure translate the ordinals in the following languages:
#
#   - English
#   - French
#   - Spanish
##
proc ob_xl::ordinal {n lang {modifiers {}}} {

	# Reject non-positive integers
	if {![regexp {^[1-9]\d*$} $n]} {
		return $n
	}

	switch -- $lang {
		en {
			switch -glob -- $n {
				*11 -
				*12 -
				*13 -
				*[04-9] {
					return "${n}th"
				}
				*1 {
					return "${n}st"
				}
				*2 {
					return "${n}nd"
				}
				*3 {
					return "${n}rd"
				}
			}
		}
		fr {
			switch -- $n {
				1 {
					if {[string first "f" $modifiers] == -1} {
						return "1<sup>er</sup>"
					} else {
						return "1<sup>re</sup>"
					}
				}
				default {
					return "${n}<sup>e</sup>"
				}
			}
		}
		es {
			if {[string first "f" $modifiers] == -1} {
				if {
					[info exists ::env(AS_CHARSET)] &&
					[string equal $::env(AS_CHARSET) "UTF-8"]
				} {
					return "${n}\u00BA"
				} else {
					return "${n}\xC2\xBA"
				}
			} else {
				if {
					[info exists ::env(AS_CHARSET)] &&
					[string equal $::env(AS_CHARSET) "UTF-8"]
				} {
					return "${n}\u00AA"
				} else {
					return "${n}\xC2\xAA"
				}
			}
		}
		default {
			return "${n}."
		}
	}
}



# Translates all symbols marked up for translation in the given phrase.
#
# Symbols are marked up by enclosing them in pipes |<symbol>| e.g.
# |BORO| |VS| |BOLT| would be translated to Middlesbrough V Bolton (in english)
#
#   str     - phrase to translate
#   returns - translated phrase
#
proc ob_xl::XL { lang str args } {

	variable CFG

	set force 0

	# process arguments
	foreach arg $args {
		switch -- $arg {
			"-force" {
				set index [lsearch $args "-force"]
				set value [lindex $args [expr {$index + 1}]]
				if {[lsearch [list 0 1] $value] == -1} {
					error "force should only be 1 or 0"
				}
				set force $value
				set args [lreplace $args $index [expr {$index + 1}]]
			}
			default {}
		}
	}

	# check for updates
	_update $lang $force

	# parse the string
	# - adds all text not surrounded by pipes
	# - translates all text surrounded by pipes
	# - ignores pipes
	set res {}
	set closePipe 0
	while 1 {
		set openPipe [string first | $str $closePipe]
		if {$openPipe < 0} {
			append res [string range $str $closePipe end]
			return $res
		}
		incr openPipe -1
		append res [string range $str $closePipe $openPipe]
		incr openPipe 2
		set closePipe [string first | $str $openPipe]
		if {$closePipe < 0} {
			incr openPipe -1
			append res [string range $str $openPipe end]
			return $res
		}
		incr closePipe -1
		set code [string range $str $openPipe $closePipe]

		append res [ob_xl::sprintf $lang $code $args]

		incr closePipe 2
	}

	return $res
}

# Translates all symbols marked up for translation in the given phrase but only
# return the codes and code_ids used in the translation
# Symbols are marked up by enclosing them in pipes |<symbol>| e.g.
# |BORO| |VS| |BOLT| would be translated to Middlesbrough V Bolton (in english)
#
#   str     - phrase to translate
#   returns - list where the first index is 0/1 (whether there was at least one translation)
#             then its code_id and code pairs for all translatable parts of the input string
#
proc ob_xl::XL_only_codes { lang str } {

	variable XL
	variable CFG

	# check for updates
	_update $lang

	# if the translation doesn't exist in the current language,
	# first try in the failover language and then the default language
	# (provided the relevant configs are enabled & the default/failover
	# languages aren't the same as the current language)

	set use_failover_lang 0
	set use_default_lang 0

	if {$CFG(use_failover_lang)} {
		set failover_lang [ob_xl::get failover $lang $lang]
		if {$failover_lang != $lang && $failover_lang != ""} {
			_update $failover_lang
			set use_failover_lang 1
		}
	}

	if {$CFG(use_default_lang)} {
		set default_lang [ob_control::get default_lang]
		if {$default_lang != $lang} {
			_update $default_lang
			set use_default_lang 1
		}
	}

	# parse the string
	# - translates all text surrounded by pipes
	# - ignores pipes
	set res       {}
	set foundXL   0
	set closePipe 0
	while 1 {
		set openPipe [string first | $str $closePipe]
		if {$openPipe < 0} {
			lappend res -1 [string range $str $closePipe end]
			return [linsert $res 0 $foundXL]
		}
		incr openPipe -1

		lappend res -1 [string range $str $closePipe $openPipe]

		incr openPipe 2

		set closePipe [string first | $str $openPipe]
		if {$closePipe < 0} {
			incr openPipe -1
			lappend res -1 [string range $str $openPipe end]
			return [linsert $res 0 $foundXL]
		}

		incr closePipe -1

		set code [string range $str $openPipe $closePipe]

		set code_id -1

		set row  [db_search -sorted $XL($lang,rs) [list code string $code]]
		if {$row > -1} {
			incr foundXL
			set code_id [db_get_col $XL($lang,rs) $row code_id]
		}

		if {$use_failover_lang && ($code_id == -1)} {
			set row  [db_search -sorted $XL($failover_lang,rs) [list code string $code]]
			if {$row > -1} {
				set code_id [db_get_col $XL($failover_lang,rs) $row code_id]
			}
		}

		if {$use_default_lang && ($code_id == -1)} {
			set row  [db_search -sorted $XL($default_lang,rs) [list code string $code]]
			if {$row > -1} {
				set code_id [db_get_col $XL($default_lang,rs) $row code_id]
			}
		}

		lappend res $code_id $code

		incr closePipe 2
	}

	return [linsert $res 0 $foundXL]
}

#--------------------------------------------------------------------------
# Load/Update translations
#--------------------------------------------------------------------------

#
# Load all the xlations which are configured to load at startup.
#
proc ob_xl::_load_all {} {

	variable XL
	variable CFG

	ob_log::write INFO {XL: loading xlations $CFG(load_on_startup)}

	if {$CFG(load_on_startup) == "_all_"} {
		set load_all 1
	} else {
		set load_all 0
	}

	set codes [get codes]
	foreach lang $codes {
		if {$load_all || [lsearch $CFG(load_on_startup) $lang] >= 0} {
			_load_lang $lang
		}
	}

	return
}


#
# Request update of the xlations in shared mem for the given language,
# and ensure that XL($lang,rs) contains a handle to the result set.
#
# This is cached for XL_QRY_CACHE_TIME and happens at most once per request.
#
proc ob_xl::_update { lang {force 0}} {

	variable XL
	variable CFG

	# Get the request id so we can avoid making more than one update per
	# language per request.

	set req_id [reqGetId]
	if {!$force && [info exists XL($lang,last_req_upd)]} {
		if { $XL($lang,last_req_upd) == $req_id && \
		     ($req_id > 0 || [db_exists $XL($lang,rs)]) } {
			return
		}

		# do we only check for updates periodically anyway (to avoid the
		# additional shared memory lookups if this causes performance issues)
		if {$CFG(shm_upd_chk_frq) > 0} {
			if {[info exists XL($lang,next_check_date)] && $XL($lang,next_check_date) > [clock seconds]} {
				# try to just grab the result set
				if {![catch {set XL($lang,rs) [asFindRs "xl_rs_$lang"]}]} {
					# managed to find it
					set XL($lang,last_req_upd) $req_id
					return
				}
			}
		}
	} else {
		ob_log::write INFO {XL: new language $lang}
		set XL($lang,last_req_upd) -1
	}

	# When were the xlations in the database last updated?
	if {$force} {
		set rs [ob_db::exec_qry ob_xl::get_last_update_no_cache $lang]
	} else {
		set rs [ob_db::exec_qry ob_xl::get_last_update $lang]
	}

	set lu_db [db_get_col $rs 0 last_update]
	ob_db::rs_close $rs

	# Do we have any xlations in shared memory for this language, and if so,
	# when were they last updated?

	set found_ok 0
	unset -nocomplain XL($lang,rs)
	catch {
		set rs [asFindRs "xl_rs_$lang"]
		set lu_shm [asFindString "xl_lu_$lang"]
		set XL($lang,rs) $rs
		set found_ok 1
	}

	if {!$found_ok} {

		# No, there are no xlations in shared memory for this language.
		# We need to load all the xlations.

		_load_lang $lang

	} else {

		# Yes, we have xlations in shared memory for this language.
		# However, if the xlations in shared memory are older than those in
		# the DB then we need to load the updated ones into shared memory.

		ob_log::write DEBUG {XL _update: db = $lu_db, shm = $lu_shm}

		if {$lu_db > $lu_shm} {
			_merge_updates $lang $rs $lu_shm $lu_db
		}

	}

	# Note the request id so we can avoid making more than one update per
	# language per request.

	set XL($lang,last_req_upd) $req_id

	return
}


#
# If we have no xlations for the given lang in shared mem, load all xlations
# for that lang.
#
# By default, a semaphore will be used to ensure only one process does this
# at a time.
#
proc ob_xl::_load_lang { lang {use_sem 1} } {

	variable XL
	variable SEM
	variable CFG

	ob_log::write DEBUG {XL: loading all xlations for $lang}

	# Semaphore lock?

	if {$use_sem && [string length $SEM]} {
		ob_log::write INFO {XL: locking semaphore for $lang}
		ipc_sem_lock $SEM
	}

	# It's possible that while we were waiting for the semaphore, someone
	# else has loaded the xlations into shared mem. Check for this now.

	set found_ok 0
	catch {
		set rs [asFindRs "xl_rs_$lang"]

		# XXX The 'slater' version used to compare [db_get_valid_til $rs] with
		# the one we recorded previously so that we could identify when the
		# appserver lies to us about the result set expiring. I maintain this
		# is unnecessary.

		set XL($lang,rs) $rs
		set found_ok 1
	}

	if {$found_ok} {

		# No action needed - xlations are already there.

		ob_log::write DEBUG {XL: xlations for $lang already present}
		if {$use_sem && [string length $SEM]} {
			ipc_sem_unlock $SEM
			ob_log::write INFO {XL: unlocked semaphore for $lang}
		}

		return

	}

	#
	# Ok, we've got the lock and the result set isn't there so we need to
	# go and retrieve it.
	#

	ob_log::write DEBUG {XL: still no xlations found in shared mem for $lang}

	#
	# As well as the xlations themselves, we need to store the last update
	# time in shared memory. We want ALL xlations, so we must use _force to
	# ensure we get the uncached last update time from the database.
	#

	set start "1901-01-01 00:00:00"
	# XXX Obviously, it would make more sense to use ob_db::exec_qry_force
	# here rather than a separate uncached version of the query.
	# However, exec_qry_force seems buggy in some db-multi.tcl's - unset
	# errors then occur in ob_db_multi::req_end.
	set rs    [ob_db::exec_qry ob_xl::get_last_update_no_cache $lang]
	set end   [db_get_col $rs 0 last_update]
	ob_db::rs_close $rs

	if {[catch {

		set rs [ob_db::exec_qry ob_xl::get_xlations_load $lang $start $end]

		# Sort the result set for quick lookup by code.

		db_sort -null-lo {code string asc} $rs

		# Check if we have actually read any translation
		if {[db_get_nrows $rs] != 0} {
			# Store the result set and last update time in shared mem.
			asStoreRs     $rs  "xl_rs_$lang" $CFG(rs_cache_time)
			asStoreString $end "xl_lu_$lang" $CFG(rs_cache_time)
		}

		# Record the result set handle - good for this request.
		set XL($lang,rs) $rs

		# XXX The 'slater' version used to record [db_get_valid_til $rs] in XL
		# here so that we could identify elsewhere when the appserver lies to
		# us about the result set expiring. I maintain this is unnecessary.

	} msg]} {

		if {$use_sem && [string length $SEM]} {
			ipc_sem_unlock $SEM
			ob_log::write INFO {XL: unlocked semaphore for $lang}
		}

		ob_log::write ERROR {XL: failed to load xlations for $lang : $msg}
		error "XL: failed to load xlations for $lang: $msg"

	}

	if {$use_sem && [string length $SEM]} {
		ipc_sem_unlock $SEM
		ob_log::write INFO {XL: unlocked semaphore for $lang}
	}

	return
}


#
# Internal - find xlations in the DB that were modified within the given date
# range and merge them into the main result set in shared mem.
#
# We don't bother with a semaphore since:
#  a) we're not expecting any huge updates after the initial _load_lang.
#  b) hopefully one child will have a cache miss on ob_xl::get_last_update
#     before the others and beat the other children to it.
#
# old_rs must be the handle to the existing result set in shared memory
# for the given language.
#
proc ob_xl::_merge_updates { lang old_rs start end } {

	variable XL
	variable CFG

	# Get the modified xlations from the database.

	set mod_rs [ob_db::exec_qry ob_xl::get_xlations $lang $start $end]

	# Make a local copy of the existing shared result set so that we can
	# manipulate it.

	set local_rs [db_dup $old_rs]

	# It's not possible to modify existing rows in a result set, so instead we
	# remove any modified xlations from the local result set, then add them
	# back in.

	for {set i 0} {$i < [db_get_nrows $mod_rs]} {incr i} {

		set code [db_get_col $mod_rs $i code]

		set row [db_search -sorted $local_rs [list code string $code]]
		if {$row >= 0} {
			db_del_row $local_rs $row
		}

		db_add_row $local_rs [db_get_row $mod_rs $i]

	}

	ob_db::rs_close $mod_rs

	# Sort our merged result set for quick lookup by code.

	db_sort -null-lo {code string asc} $local_rs

	# Store our merged result set into shared memory (overwriting the old
	# one) + the last update time.

	asStoreRs $local_rs "xl_rs_$lang" $CFG(rs_cache_time)
	asStoreString $end "xl_lu_$lang" $CFG(rs_cache_time)

	# Record the result set handle - it's good for this request.
	set XL($lang,rs) $local_rs

	return
}


# Private procedure to get all the API groups (package errors)
#
proc ob_xl::_get_api_groups args {

	variable CFG

	# prepare qry
	ob_db::store_qry ob_xl::get_groups {
		select distinct
		    group
		from
		    tXlateCode
		where
		    group like 'API %'
	}

	# get groups
	set rs [ob_db::exec_qry ob_xl::get_groups]
	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {
		if {$CFG(load_groups) != ""} {
			append CFG(load_groups) |
		}
		append CFG(load_groups) [db_get_col $rs $i group]
	}
	ob_db::rs_close $rs

	ob_log::write DEV {ob_xl: load_groups=$CFG(load_groups)}
}
