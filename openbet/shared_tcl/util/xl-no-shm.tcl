# $Id: xl-no-shm.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Primary purpose is to translate message codes (stored in tXLateCode)
# into language-specific translations (stored in tXLateVal).
#
# This version does not require that shared memory is available. If unsure,
# use the util_xl package instead.
#
# Configuration:
#   XL_SEMAPHORE_ENABLE    enable semaphore                       (1)
#   XL_SEMAPHORE_PORT      semaphore ports (overrides PORTS)      ("")
#   XL_QRY_CACHE_TIME      get xlations query cache time          (600)
#   XL_TP_SET_HOOK         enable tpXlateSetHook                  (0)
#   XL_LOAD_ON_STARTUP     list of lang codes to load on startup  (_all_)
#   XL_LOAD_BY_GROUPS      load xlations by group(s)              (0)
#   XL_LOAD_GROUPS         | delimetered list of groups           ("")
#                          NB: groups 'API %' are automatically appended
#   XL_USE_DEFAULT_LANG    if translation doesn't exist in current (0)
#                          lang then fall back to the default lang
#
# Synopsis:
#   package require util_xl_no_shm ?4.5?
#
# Procedures:
#   ob_xl::init            one time initialisation
#   ob_xl::get             get language information
#   ob_xl::sprintf         formatted code translation
#   ob_xl::XL              translate a phrase
#

package provide util_xl_no_shm 4.5



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
	        qry_cache_time    600\
	        qry_last_cache_time 10\
	        load_on_startup   [OT_CfgGet XL_LANG_ON_STARTUP "_all_"]\
	        load_by_groups    0\
	        load_groups       ""\
	        use_failover_lang 0\
	        use_default_lang  0]

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

	# get the last update to tXLateVal table for a particular language
	ob_db::store_qry ob_xl::get_last_update {
		select
		    max(last_update) as last_update
		from
		    tXlateVal
		where
		    lang = ?
	} $CFG(qry_last_cache_time)

	# get ALL the previously updated translations for a particular language
	# - query is cached for a few minutes as xlations change relatively
	#   infrequently, it's quite likely that if one does change all the
	#   appservers they will be using the same last_update args. This also
	#   helps greatly during startup, when combined with the semaphore code it
	#   means that the xlations for each language will be retrieved only once
	#   across each server.
	# - maybe restricted by a group
	set sql [subst {
		select
		    c.code,
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
	ob_db::store_qry ob_xl::get_xlations $sql $CFG(qry_cache_time)

	# Prep a seperate version to run on initial load
	ob_db::store_qry ob_xl::get_xlations_init $sql $CFG(qry_cache_time)

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

	variable XL
	variable CFG

	# check for updates
	_update $lang

	# Look up the translation (will return the code if there is none).
	if { [info exists XL($lang,$code)] } {
		set xl $XL($lang,$code)
	} else {
		set xl $code
	}

	# If there was no translation, try the failover language instead,
	# followed by the default language, provided the relevant config options
	# are enabled and we're not already translating into the default/failover
	# language.

	if { [string equal $xl $code] && $CFG(use_failover_lang) } {
		set failover_lang [ob_xl::get failover $lang $lang]
		if {$lang != $failover_lang && $failover_lang != ""} {
			_update $failover_lang
			if { [info exists XL($failover_lang,$code)] } {
				set xl $XL($failover_lang,$code)
			}
		}
	}

	if { [string equal $xl $code] && $CFG(use_default_lang) } {
		set default_lang [ob_control::get default_lang]
		if {$lang != $default_lang} {
			_update $default_lang
			if { [info exists XL($default_lang,$code)] } {
				set xl $XL($default_lang,$code)
			}
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
		if {[info exists XL($lang,$code)]} {
			append res $XL($lang,$code)
		} elseif {$use_failover_lang && [info exists XL($failover_lang,$code)]} {
			append res $XL($failover_lang,$code)
		} elseif {$use_default_lang && [info exists XL($default_lang,$code)]} {
			append res $XL($default_lang,$code)
		} else {
			append res $code
		}
		incr closePipe 2
	}

	return $res
}



#--------------------------------------------------------------------------
# Load/Update translations
#--------------------------------------------------------------------------

# Load all the xlations on startup.
#
proc ob_xl::_load_all args {

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

		# force update on language
		set XL($lang,last_checked) -1
		set XL($lang,last_updated) "0001-01-01 00:00:00"

		# load the language codes now, or on demand
		# - we need to set the semaphore
		if {$load_all || [lsearch $CFG(load_on_startup) $lang] >= 0} {
			_update $lang 1
		}
	}
}


# Private procedure to update the translations for particular language.
#
# The update is only performed once-per request and will only add those
# translations which have been changed since the last update call.
#
# NB: Updates are not protected by the semaphore, as the result-sets will
#     only be small (startup locks the semaphore when loading all the data).
#     Secondly, it avoids blocking a child app on startup.
#
#   lang    - language
#   use_sem - use the semaphore while loading/updating the translations (0)
#
proc ob_xl::_update { lang {use_sem 0} } {

	variable XL

	# get the request id
	set id [reqGetId]

	# dont repeat update on the same request
	# - force an update with an unknown language (allows a language xlations
	#   to be loaded on demand, but no protection from the semaphore)
	if {[info exists XL($lang,last_checked)]} {
		if {$XL($lang,last_checked) == $id} {
			return
		}
	} else {
		ob_log::write WARNING {XL: _update, unknown language $lang}

		set XL($lang,last_checked) -1
		set XL($lang,last_updated) "0001-01-01 00:00:00"
		set use_sem 1
	}

	if {[catch {

		ob_log::write DEV \
		    {XL: _update lang=$lang id=$id last_updated=$XL($lang,last_updated)}

		# get the last time the translations were updated
		set rs [ob_db::exec_qry ob_xl::get_last_update $lang]
		set last_updated [db_get_col $rs 0 last_update]
		ob_db::rs_close $rs

		# add any translation which has changed since our last look
		if {$last_updated > $XL($lang,last_updated)} {

			_load $lang $last_updated $use_sem
			set XL($lang,last_updated) $last_updated
		}

		# stop multiple updates per-request
		set XL($lang,last_checked) $id

	} msg]} {
		ob_log::write ERROR {XL: $msg}
	}
}



# Private procedure to load all the translations for a particular language
# which have changed since the last load.
#
# If the cfg value XL_SEMAPHORE_ENABLE and param use_sem is set, then a
# semaphore is used to protected the creation of the translation result-set. As
# this is cached and can yield large result-sets, the semaphore makes sure that
# only one child process is generating the set (any waiting children will
# manipulate the cached set).
#
#   lang    - language
#   end     - newest translation modification
#             NB: last update time stored in XL($lang,last_updated)
#   use_sem - use the semaphore while loading/updating the translations (0)
#
proc ob_xl::_load { lang end {use_sem 0} } {

	variable XL
	variable SEM

	set start $XL($lang,last_updated)
	ob_log::write DEV {XL: _load lang=$lang from=$start to=$end}

	# semaphore lock?
	if {$use_sem && [string length $SEM]} {
		ob_log::write INFO {XL: ipc_sem_lock lang=$lang}
		ipc_sem_lock $SEM
	}

	if {[catch {
		if {$XL($lang,last_checked) != -1} {
			set rs [ob_db::exec_qry ob_xl::get_xlations $lang $start $end]
		} else {
			set rs [ob_db::exec_qry ob_xl::get_xlations_init $lang $start $end]
		}
		set nrows [db_get_nrows $rs]

		for {set i 0} {$i < $nrows} {incr i} {
			set val [db_get_col $rs $i xlation_1]
			append val [db_get_col $rs $i xlation_2]
			append val [db_get_col $rs $i xlation_3]
			append val [db_get_col $rs $i xlation_4]

			set XL($lang,[db_get_col $rs $i code]) $val
		}
		ob_db::rs_close $rs
	} msg]} {
		ob_log::write ERROR {XL: $msg}
	}

	# semaphore un-lock?
	if {$use_sem && [string length $SEM]} {
		ipc_sem_unlock $SEM
		ob_log::write INFO {XL: ipc_sem_unlock lang=$lang}
	}
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
