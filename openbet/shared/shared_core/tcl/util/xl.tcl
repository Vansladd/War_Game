# Copyright (c) 2007 Orbis Technology Ltd. All rights reserved.
#
# Primary purpose is to translate message codes (stored in tXLateCode)
# into language-specific translations (stored in tXLateVal).
#
# Known Bugs:
#
#   * Translation deletes are not picked up until the result set falls
#     out of shared memory.
#   * The result set valid_til checking from the 'slater' version is not
#     performed (see inline comments).
#   * Bad things will happen if shared memory is exhausted.
#   * Error checking is not exemplary.

set pkg_version 1.0
package provide core::xl $pkg_version

# Dependencies
package require core::log        1.0
package require core::check      1.0
package require core::args       1.0
package require core::db         1.0
package require core::control    1.0
package require core::db::schema 1.0

core::args::register_ns \
	-namespace core::xl \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args core::db core::control] \
	-docs      util/xl.xml

# Variables
namespace eval core::xl {

	variable XL
	variable CFG
	variable SEM
	variable LANG

	# initially disable use of semaphore
	set SEM ""

	# set current request number
	set LANG(req_no) -1

	# init flag
	set CFG(init) 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
core::args::register \
	-proc_name core::xl::init \
	-args [list \
		[list -arg -default_charset     -mand 0 -check STRING -default_cfg XL_DEFAULT_CHARSET     -default {iso8859-1} -desc {Default translation charset}] \
		[list -arg -semaphore_enable    -mand 0 -check BOOL   -default_cfg XL_SEMAPHORE_ENABLE    -default 1           -desc {Enable semaphore for locking result sets}] \
		[list -arg -semaphore_port      -mand 0 -check UINT   -default_cfg PORTS                  -default 1818        -desc {Semaphore key}] \
		[list -arg -tp_set_hook         -mand 0 -check BOOL   -default_cfg XL_TP_SET_HOOK         -default 0           -desc {Enable tpXlateSetHook}] \
		[list -arg -qry_cache_time      -mand 0 -check UINT   -default_cfg XL_QRY_CACHE_TIME      -default 120         -desc {The xlations query cache time}] \
		[list -arg -qry_last_cache_time -mand 0 -check UINT   -default_cfg XL_QRY_LAST_CACHE_TIME -default 10          -desc {Last update query cache time}] \
		[list -arg -rs_cache_time       -mand 0 -check UINT   -default_cfg XL_RS_CACHE_TIME       -default 99999       -desc {The xlations rs cache time}] \
		[list -arg -load_on_startup     -mand 0 -check STRING -default_cfg XL_LOAD_ON_STARTUP     -default {_blank_}   -desc {List of lang codes to load on startup}] \
		[list -arg -load_by_groups      -mand 0 -check BOOL   -default_cfg XL_LOAD_BY_GROUPS      -default 0           -desc {Load xlations by group(s)}] \
		[list -arg -load_groups         -mand 0 -check ANY    -default_cfg XL_LOAD_GROUPS         -default {}          -desc {| delimited list of groups}] \
		[list -arg -use_failover_lang   -mand 0 -check BOOL   -default_cfg XL_USE_FAILOVER_LANG   -default 0           -desc {Language to use if current lang translation doesn't exist on first try}] \
		[list -arg -use_default_lang    -mand 0 -check BOOL   -default_cfg XL_USE_DEFAULT_LANG    -default 0           -desc {Language to use if current lang translation doesn't exist}] \
		[list -arg -shm_upd_chk_frq     -mand 0 -check UINT   -default_cfg XL_SHM_UPD_CHK_FRQ     -default 0           -desc {Periodic shared memory lookups}] \
		[list -arg -shm_enable          -mand 0 -check BOOL   -default_cfg XL_SHM_ENABLE          -default 1           -desc {Enable SHM}] \
	] \
	-body {
		variable SEM
		variable CFG

		# already initialised?
		if {$CFG(init)} {
			return
		}

		# Set the config array
		foreach n [array names ARGS] {
			set CFG([string trimleft $n -]) $ARGS($n)
		}

		# Establish whether shm is available
		if {[llength [info commands asStoreRs]] && $CFG(shm_enable)} {
			set CFG(shm_avail) 1
		} else {
			set CFG(shm_avail)       0
			set CFG(shm_upd_chk_frq) 0
		}

		# init dependencies
		core::log::init
		core::control::init
		core::db::schema::init

		core::log::write DEBUG {XL: init}

		# auto reset package data?
		if {[info commands reqGetId] != "reqGetId"} {
			error "XL: reqGetId not available for auto reset"
		}

		# enable the semaphore
		# - semaphore protects the creation of the cached result set, therefore,
		#   stopping more than one appserv executing the same query
		#   (result-set can be quite large, as all the translations for each lang
		#   is returned)
		if {$CFG(semaphore_enable)} {
			core::log::write INFO {XL: enabling semaphore port=$CFG(semaphore_port)}
			set SEM [ipc_sem_create $CFG(semaphore_port)]
		} else {
			core::log::write WARNING {XL: not using semaphore}
		}

		# enable TP xlate hook
		if {$CFG(tp_set_hook)} {
			core::log::write WARNING {XL: enabling tpXlateSetHook core::xl::_sprintf_tp_hook}
			tpXlateSetHook core::xl::_sprintf_tp_hook
		}

		# prepare package queries
		_prepare_qrys

		# if the value is blank, then the config doesnt exist try the config
		# XL_LANG_ON_STARTUP and if that isnt set then default to _all_
		if {$CFG(load_on_startup) == "_blank_"} {
			set CFG(load_on_startup) [OT_CfgGet XL_LANG_ON_STARTUP "_all_"]
		}

		# load all the xlations on startup
		if {$CFG(load_on_startup) != "_none_"} {
			_load_all
		} else {
			core::log::write WARNING {XL: xlations not loaded on startup}
		}

		# successfully initialised
		set CFG(init) 1
	}



# Private procedure to prepare the package queries
#
proc core::xl::_prepare_qrys args {

	variable CFG

	set cache_time [expr {$CFG(shm_avail) ? $CFG(qry_cache_time) : $CFG(qry_last_cache_time)}]

	# are we loading translations by groups
	set groups ""
	if {$CFG(load_by_groups)} {
		core::log::write WARNING {XL: enabling load by groups}

		# prepare qry
		core::db::store_qry \
			-name  core::xl::get_groups \
			-cache $cache_time \
			-qry {
				select distinct
					group
				from
					tXlateCode
				where
					group like 'API %'
			}

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
	core::db::store_qry \
		-name  core::xl::get_last_update \
		-cache $cache_time \
		-qry {
			select
				max(last_update) as last_update
			from
				tXlateVal
			where
				lang = ?
		}

	#Get the last time the tXlateCode table was updated.
	core::db::store_qry \
		-name  core::xl::get_last_update_code \
		-cache $cache_time \
		-qry   {
			select
				max(last_update) as last_update
			from
				tXlateCode
		}

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

	set cache_time [expr {$CFG(shm_avail) ? 0 : $CFG(qry_cache_time)}]

	core::db::store_qry \
		-name  core::xl::get_xlations \
		-cache $cache_time \
		-qry   $sql

	# Prep a seperate version to run on initial load
	core::db::store_qry \
		-name  core::xl::get_xlations_load \
		-cache $cache_time \
		-qry   $sql

	# Retrieve xlation codes that were modified within a date range.
	# There may be an additional clause to restrict the xlation codes to those
	# in certain groups.
	# Note that we don't cache this query at all (and it's important that we
	# don't) - we only execute it when we're sure we need to.
	set sql [subst {
		select
		    c.code,
		    c.code_id
		from
		    tXlateCode c
		where
			c.last_update >= ?
		and c.last_update <= ?
	}]

	if {$groups != ""} {
		append sql
		append sql $groups
	}

	set cache_time [expr {$CFG(shm_avail) ? 0 : $CFG(qry_cache_time)}]

	core::db::store_qry \
		-name  core::xl::get_xlations_code \
		-cache $cache_time \
		-qry   $sql

	# Retrieve xlation codes.
	# There may be an additional clause to restrict the xlation codes to those
	# in certain groups.
	# Note that we don't cache this query at all (and it's important that we
	# don't) - we only execute it when we're sure we need to.
	set sql [subst {
		select
		    c.code,
		    c.code_id
		from
		    tXlateCode c
	}]

	if {$groups != ""} {
		set group_no_where [string range $groups 4 end]
		append sql " where " 
		append sql $group_no_where
	}

	set cache_time [expr {$CFG(shm_avail) ? 0 : $CFG(qry_cache_time)}]

	core::db::store_qry \
		-name  core::xl::get_xlations_load_code \
		-cache $cache_time \
		-qry   $sql

	# get language details
	core::db::store_qry \
		-name  core::xl::get \
		-cache 600 \
		-qry [subst {
			select
				lang,
				name,
				charset,
				[core::db::schema::add_sql_column \
					-table   tLang \
					-column  failover \
					-alias   {failover} \
					-default {'' as failover}],
				[core::db::schema::add_sql_column \
					-table   tLang \
					-column  displayed \
					-alias   {displayed} \
					-default {'Y' as displayed}]
			from
				tLang
			where
				status = 'A'
		}]
}



#--------------------------------------------------------------------------
# Get
#--------------------------------------------------------------------------

# Get language specific information, either language's charset/name or a list
# of all available language codes.
#
# This proc should be the same regardless of CFG(shm_avail)
#
# @param -item    - language item to retrieve (charset|name|failover|codes)
# @param -lang    - language code (default: "")
# @param -default - default if the requested item is not found (default: "")
# @return request item data;
#   if requesting 'code', then list of available language codes
#
core::args::register \
	-proc_name core::xl::get \
	-args [list \
		[list -arg -item    -mand 1 -check STRING             -desc {language item to retrieve (charset|name|failover|codes)}] \
		[list -arg -lang    -mand 0 -check STRING -default {} -desc {language code}] \
		[list -arg -default -mand 0 -check STRING -default {} -desc {default if the requested item is not found}] \
	] \
	-body {
		variable CFG
		variable LANG

		set item $ARGS(-item)
		set lang $ARGS(-lang)

		if {![regexp {^(charset|name|failover|codes|displayed|displayed_languages)$} $item]} {
			error "Illegal language item - $item"
		}

		# current request number
		set id [reqGetId]

		# different request, update cache
		if {$LANG(req_no) != $id} {

			# get all the active language details
			set rs [core::db::exec_qry -name core::xl::get]

			unset LANG
			set LANG(req_no) $id
			set LANG(codes)  [list]
			set LANG(displayed_languages)  [list]

			# store in cache
			set nrows [db_get_nrows $rs]
			for {set i 0} {$i < $nrows} {incr i} {
				set l                 [db_get_col $rs $i lang]
				set LANG($l,name)     [db_get_col $rs $i name]
				set LANG($l,charset)  [db_get_col $rs $i charset]
				set LANG($l,failover) [db_get_col $rs $i failover]
				set LANG($l,displayed) [db_get_col $rs $i displayed]

				if {$LANG($l,displayed) == {Y}} {
					lappend LANG(displayed_languages) $l
				}

				lappend LANG(codes) $l
			}

			core::db::rs_close -rs $rs
		}

		if {[lsearch "codes displayed_languages" $item] == -1} {
			if {[info exists LANG($lang,$item)]} {
				return $LANG($lang,$item)
			} else {
				return $ARGS(-default)
			}
		} else {
			return $LANG($item)
		}
	}


#--------------------------------------------------------------------------
# Translate xlate codes
#--------------------------------------------------------------------------


#
# Internal translation lookup procedure - MUST have previously called
# _update for the given lang within this request.
# Returns 0 or 1 depending on whether we found a translation or not
#
proc core::xl::_lookup {lang code} {

	variable CFG
	variable XL

	# If we aren't using SHM we should look in the XL cache
	if {!$CFG(shm_avail)} {
		if {[info exists XL($lang,$code)]} {
			return [list 1 $XL($lang,$code)]
		} else {
			return [list 0 $code]
		}
	}

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

		# Found the translation, return success and the translation
		return [list 1 $res]
	}

	# No translation found, just return the original translation code
	return [list 0 $code]
}

# Appserver sprintf hook wrapper
proc core::xl::_sprintf_tp_hook {lang code args} {
	return [sprintf -lang $lang -code $code -args $args]
}

##
# Translate a xlate code, where the resultant translation may contain the Tcl
# format command (equivalent to ANSI c sprintf) specifiers (e.g. %s, %d, etc)
# which refer to the format arguments supplied, as well as our own specifiers
# with syntax %{varName} which refer to the values of global Tcl variables.
#
# Parameters:
# @param -lang language code
# @param -code xlate code
# @param -args format arguments
#   ignored if the translation text contains no specifiers
#
# @return Translation text if found; otherwise the code.
#  May throw an error if a specifier is badly formed or missing a format
#  argument.
#
# Notes:
#   * Variable specifier substitution occurs in a pass before the Tcl
#     format specifier substituion.
#   * Some languages may fall back to the default language if no translation
#     was found (this is configurable).
#
core::args::register \
	-proc_name core::xl::sprintf \
	-args [list \
		[list -arg -lang    -mand 1 -check STRING             -desc {Translation langauge}] \
		[list -arg -code    -mand 1 -check ANY                -desc {Translation code}] \
		[list -arg -args    -mand 0 -check ANY    -default {} -desc {Arguments to pass to format / variable specifiers}] \
	] \
	-body {
		variable CFG

		set lang $ARGS(-lang)
		set code $ARGS(-code)

		# check for updates
		_update $lang

		# Look up the translation (will return the code if there is none).
		set ret [_lookup $lang $code]

		# Determine if we found the translation or not
		set found [lindex $ret 0]
		set xl    [lindex $ret 1]

		# If there was no translation, try the failover language instead,
		# followed by the default language, provided the relevant config options
		# are enabled and we're not already translating into the default/failover
		# language.
		if {!$found && $CFG(use_failover_lang)} {
			set failover_lang [get \
				-item failover \
				-lang $lang \
				-default $lang]

			if {$lang != $failover_lang && $failover_lang != ""} {
				_update $failover_lang
				set xl [lindex [_lookup $failover_lang $code] 1]
			}
		}

		if {!$found && $CFG(use_default_lang)} {
			set default_lang [core::control::get -name default_lang]
			if {$lang != $default_lang} {
				_update $default_lang
				set xl [lindex [_lookup $default_lang $code] 1]
			}
		}

		# Return swiftly if no specifiers present.
		if {[string first % $xl] == -1} {
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
					if {$pos >= [llength $ARGS(-args)]} {
						error "not enough arguments for all format specifiers"
					}
					switch -glob -- $specifier {
						O* {
							set ARGS(-args) [lreplace \
								$ARGS(-args) \
								$pos \
								$pos \
								[ordinal \
									-position  [lindex $ARGS(-args) $pos] \
									-lang      $lang \
									-modifiers [string range $specifier 1 end]]]

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
		# Note the silent catch is there to avoid an incorrect translation 
		# causing this proc to throw an exception.
		if {[string first % $xl] != -1} {
			catch {set xl [format $xl {*}$ARGS(-args)]}
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
core::args::register \
	-proc_name core::xl::ordinal \
	-args [list \
		[list -arg -position  -mand 1 -check ASCII             -desc {Ordinal position}] \
		[list -arg -lang      -mand 1 -check STRING            -desc {Translation language}] \
		[list -arg -modifiers -mand 0 -check ANY   -default {} -desc {}] \
	] \
	-body {
		set n         $ARGS(-position)
		set lang      $ARGS(-lang)
		set modifiers $ARGS(-modifiers)

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
# @param -lang Language to translate phrase into
# @param -str phrase to translate
# @return Translated phrase
#
core::args::register \
	-proc_name core::xl::XL \
	-args [list \
		[list -arg -lang    -mand 1 -check STRING             -desc {Translation langauge}] \
		[list -arg -str     -mand 1 -check ANY                -desc {Phrase to translate}] \
		[list -arg -force   -mand 0 -check BOOL   -default 0  -desc {Force reload from DB}] \
		[list -arg -args    -mand 0 -check ANY    -default {} -desc {Arguments to pass to format / variable specifiers}] \
	] \
	-body {

		variable CFG

		set lang  $ARGS(-lang)
		set str   $ARGS(-str)

		# check for updates
		# CHECK! are we then making a second call to update when we sprintf? Looks like it
		_update $lang $ARGS(-force)

		# parse the string
		# - adds all text not surrounded by pipes
		# - translates all text surrounded by pipes
		# - ignores pipes
		set res {}
		set close_pipe 0
		while 1 {
			set open_pipe [string first | $str $close_pipe]
			if {$open_pipe < 0} {
				append res [string range $str $close_pipe end]
				return $res
			}
			incr open_pipe -1
			append res [string range $str $close_pipe $open_pipe]
			incr open_pipe 2
			set close_pipe [string first | $str $open_pipe]
			if {$close_pipe < 0} {
				incr open_pipe -1
				append res [string range $str $open_pipe end]
				return $res
			}
			incr close_pipe -1
			set code [string range $str $open_pipe $close_pipe]

			append res [sprintf \
				-lang $lang \
				-code $code \
				-args $ARGS(-args)]

			incr close_pipe 2
		}

		return $res
	}

# Translates all symbols marked up for translation in the given phrase but only
# return the codes and code_ids used in the translation
# Symbols are marked up by enclosing them in pipes |<symbol>| e.g.
# |BORO| |VS| |BOLT| would be translated to Middlesbrough V Bolton (in english)
#
# @param - str Phrase to translate
# @param return List where the first index is 0/1 (whether there was at least one translation)
#   then its code_id and code pairs for all translatable parts of the input string
#
core::args::register \
	-proc_name core::xl::XL_only_codes \
	-args [list \
		[list -arg -str -mand 1 -check STRING -desc {Translation code}] \
		[list -arg -force -mand 0 -check UINT -desc {Force updates of code}] \
	] \
	-body {
		variable XL
		variable CFG

		set str  $ARGS(-str)
		set force $ARGS(-force)

		# check for updates
		_update_code $force
		
		# parse the string
		# - translates all text surrounded by pipes
		# - ignores pipes
		set res        {}
		set found_code 0
		set close_pipe 0
		while 1 {
			set open_pipe [string first | $str $close_pipe]
			if {$open_pipe < 0} {
				return [linsert $res 0 $found_code]
			}
			incr open_pipe 1

			set close_pipe [string first | $str $open_pipe]
			if {$close_pipe < 0} {
				return [linsert $res 0 $found_code]
			}

			incr close_pipe -1

			set code    [string range $str $open_pipe $close_pipe]
			set code_id -1
			incr found_code

			set row [db_search -sorted $XL(code,rs) [list code string $code]]
			if {$row > -1} {
				set code_id [db_get_col $XL(code,rs) $row code_id]
			}

			lappend res $code_id $code

			incr close_pipe 2
		}

		return [linsert $res 0 $found_code]
	}

# Must be called at the end of any request *or timeout* that uses this
# package
#
core::args::register \
	-proc_name core::xl::req_end \
	-body {
		variable CFG
		variable XL

		if {!$CFG(shm_avail)} {
			return
		}

		# Break the cache of the XL code->value result sets between reqs/timeouts
		# This ensures it will be refreshed from SHM at the start of a req/timeout
		if {[info exists XL(langs_updated)]} {
			foreach lang $XL(langs_updated) {
				unset XL($lang,last_req_upd)
			}
			unset XL(langs_updated)
		}

		#Break the cache of the XL code only result sets
		if {[info exists XL(code,last_req_upd)]} {
			unset -nocomplain XL(code,last_req_upd)
		}
	}



# Number to Text Conversion
#
# Takes a number (non negative) and language and returns equivalent text string
#
core::args::register \
	-proc_name core::xl::number_to_text \
	-desc {Convert number to equivalent textual representation} \
	-args [list \
		[list -arg -number -mand 1 -check UINT \
			-desc {Number whose text is required}] \
		[list -arg -lang   -mand 1 -check STRING  -desc {Language code}] \
	] \
	-body {

		switch -- $ARGS(-lang) {
			es {
				set num_text [core::xl::_convert_to_es_txt $ARGS(-number)]
				core::log::write DEBUG {core::xl::number_to_text \
					$ARGS(-number) in $ARGS(-lang): $num_text}
				return $num_text
			}
			default {
				core::log::write ERROR {core::xl::number_to_text does not \
					support lang: $ARGS(-lang)}
				error NUM_TO_TEXT_ERR  {Conversion to lang:$ARGS(-lang) \
					not supported}
			}
		}
	}



#
# Proc to indicate if a translation exists in a particular language
#
core::args::register \
	-proc_name core::xl::XL_exists \
	-desc {Check if traslation exists in this language} \
	-args [list \
		[list -arg -lang -mand 1 -check STRING -desc {Translation langauge}] \
		[list -arg -code -mand 1 -check STRING -desc {Translation code}] \
	] \
	-body {
		variable CFG

		set lang $ARGS(-lang)
		set code $ARGS(-code)

		# check for updates
		_update $lang

		# Look up the translation (will return the code if there is none).
		set ret   [_lookup $lang $code]
		set found [lindex $ret 0]

		# check if translation exists
		if {$found} {
			return 1
		}

		# we got this far so the translation doesnt exist
		return 0
	}

#--------------------------------------------------------------------------
# Load/Update translations
#--------------------------------------------------------------------------

#
# Load all the xlations which are configured to load at startup.
#
proc core::xl::_load_all {} {

	variable XL
	variable CFG

	core::log::write INFO {XL: loading xlations $CFG(load_on_startup)}

	if {$CFG(load_on_startup) == "_all_"} {
		set load_all 1
	} else {
		set load_all 0
	}

	set codes [get -item codes]
	foreach lang $codes {

		# force update on language
		set XL($lang,last_checked) -1
		set XL($lang,last_updated) "0001-01-01 00:00:00"

		if {$load_all || [lsearch $CFG(load_on_startup) $lang] >= 0} {

			if {$CFG(shm_avail)} {
				_load_lang_shm $lang
			} else {
				_update $lang 0 1
			}
		}
	}

	return
}

# Intermediary proc whilst shm/no-shm are merged
proc core::xl::_update { lang {force 0} {use_sem 0}} {

	variable CFG

	if {$CFG(shm_avail)} {
		_update_shm $lang $force
	} else {
		_update_local $lang $use_sem
	}
}


#
# Request update of the xlations in shared mem for the given language,
# and ensure that XL($lang,rs) contains a handle to the result set.
#
# This is cached for XL_QRY_CACHE_TIME and happens at most once per request.
#
proc core::xl::_update_shm { lang {force 0}} {

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
		core::log::write INFO {XL: new language $lang}
		set XL($lang,last_req_upd) -1
	}

	# When were the xlations in the database last updated?
	if {$force} {
		set rs [core::db::exec_qry \
			-name  core::xl::get_last_update \
			-force 1 \
			-args [list $lang]]
	} else {
		set rs [core::db::exec_qry \
			-name core::xl::get_last_update \
			-args [list $lang]]
	}

	set lu_db [db_get_col $rs 0 last_update]
	core::db::rs_close -rs $rs

	# Do we have any xlations in shared memory for this language, and if so,
	# when were they last updated?

	set found_ok 0
	unset -nocomplain XL($lang,rs)
	catch {
		set rs     [asFindRs "xl_rs_$lang"]
		set lu_shm [asFindString "xl_lu_$lang"]
		set XL($lang,rs) $rs
		set found_ok 1
	}

	if {!$found_ok} {
		# No, there are no xlations in shared memory for this language.
		# We need to load all the xlations.
		_load_lang_shm $lang
	} else {

		# Yes, we have xlations in shared memory for this language.
		# However, if the xlations in shared memory are older than those in
		# the DB then we need to load the updated ones into shared memory.

		core::log::write DEBUG {XL _update: db = $lu_db, shm = $lu_shm}

		if {$lu_db > $lu_shm} {
			_merge_updates $lang $rs $lu_shm $lu_db
		}
	}

	# Note the request id so we can avoid making more than one update per
	# language per request

	set XL($lang,last_req_upd) $req_id

	# Make a note that we have cached this language in this request so we can
	# break the cache at req_end
	if {![info exists XL(langs_updated)]} {
		set XL(langs_updated) [list $lang]
	} else {
		# Add this language to the list of those we have cached in this request/timeout
		if {[lsearch $XL(langs_updated) $lang] == -1} {
			lappend XL(langs_updated) $lang
		}
	}

	return
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
proc core::xl::_update_local { lang {use_sem 0} } {

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
		core::log::write WARNING {XL: _update, unknown language $lang}

		set XL($lang,last_checked) -1
		set XL($lang,last_updated) "0001-01-01 00:00:00"
		set use_sem 1
	}

	if {[catch {

		core::log::write DEV \
		    {XL: _update lang=$lang id=$id last_updated=$XL($lang,last_updated)}

		# get the last time the translations were updated
		set rs [core::db::exec_qry -name core::xl::get_last_update -args [list $lang]]
		set last_updated [db_get_col $rs 0 last_update]

		core::db::rs_close -rs $rs

		# add any translation which has changed since our last look
		if {$last_updated > $XL($lang,last_updated)} {

			_load_lang_local \
				$lang \
				$last_updated \
				$use_sem

			set XL($lang,last_updated) $last_updated
		}

		# stop multiple updates per-request
		set XL($lang,last_checked) $id

	} msg]} {
		core::log::write ERROR {XL: $msg}
	}
}


#
# If we have no xlations for the given lang in shared mem, load all xlations
# for that lang.
#
# By default, a semaphore will be used to ensure only one process does this
# at a time.
#
proc core::xl::_load_lang_shm { lang {use_sem 1} } {

	variable XL
	variable SEM
	variable CFG

	core::log::write DEBUG {XL: loading all xlations for $lang}

	# Semaphore lock?

	if {$use_sem && [string length $SEM]} {
		core::log::write INFO {XL: locking semaphore for $lang}
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

		core::log::write DEBUG {XL: xlations for $lang already present}
		if {$use_sem && [string length $SEM]} {
			ipc_sem_unlock $SEM
			core::log::write INFO {XL: unlocked semaphore for $lang}
		}

		return
	}

	# Ok, we've got the lock and the result set isn't there so we need to
	# go and retrieve it.

	core::log::write DEBUG {XL: still no xlations found in shared mem for $lang}

	# As well as the xlations themselves, we need to store the last update
	# time in shared memory. We want ALL xlations, so we must use -force to
	# ensure we get the uncached last update time from the database.

	if {[catch {
		set start "1901-01-01 00:00:00"
		set rs [core::db::exec_qry \
			-name  core::xl::get_last_update \
			-force 1 \
			-args  [list $lang]]

		set end [db_get_col $rs 0 last_update]
		core::db::rs_close -rs $rs

		set rs [core::db::exec_qry \
			-name core::xl::get_xlations_load \
			-args [list $lang $start $end]]

		# Sort the result set for quick lookup by code.
		db_sort -null-lo {code string asc} $rs

		# Store the result set and last update time in shared mem.
		asStoreRs     $rs  "xl_rs_$lang" $CFG(rs_cache_time)
		asStoreString $end "xl_lu_$lang" $CFG(rs_cache_time)

		# Record the result set handle - good for this request.
		set XL($lang,rs) $rs

		# XXX The 'slater' version used to record [db_get_valid_til $rs] in XL
		# here so that we could identify elsewhere when the appserver lies to
		# us about the result set expiring. I maintain this is unnecessary.

	} msg]} {

		if {$use_sem && [string length $SEM]} {
			ipc_sem_unlock $SEM
			core::log::write INFO {XL: unlocked semaphore for $lang}
		}

		core::log::write ERROR {XL: failed to load xlations for $lang : $msg}
		error "XL: failed to load xlations for $lang: $msg"
	}

	if {$use_sem && [string length $SEM]} {
		ipc_sem_unlock $SEM
		core::log::write INFO {XL: unlocked semaphore for $lang}
	}

	return
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
proc core::xl::_load_lang_local { lang end {use_sem 0} } {

	variable XL
	variable SEM

	set start $XL($lang,last_updated)
	core::log::write DEV {XL: _load_lang_local lang=$lang from=$start to=$end}

	# semaphore lock?
	if {$use_sem && [string length $SEM]} {
		core::log::write INFO {XL: ipc_sem_lock lang=$lang}
		ipc_sem_lock $SEM
	}

	if {[catch {
		if {$XL($lang,last_checked) != -1} {
			set rs [core::db::exec_qry \
				-name core::xl::get_xlations \
				-args [list $lang $start $end]]
		} else {
			set rs [core::db::exec_qry \
				-name core::xl::get_xlations_load \
				-args [list $lang $start $end]]
		}

		set nrows [db_get_nrows $rs]

		for {set i 0} {$i < $nrows} {incr i} {
			set code [db_get_col $rs $i code]
			set val  [db_get_col $rs $i xlation_1]
			append val [db_get_col $rs $i xlation_2]
			append val [db_get_col $rs $i xlation_3]
			append val [db_get_col $rs $i xlation_4]

			set XL($lang,$code) $val
		}
		core::db::rs_close -rs $rs
	} msg]} {
		core::log::write ERROR {XL: $msg}
	}

	# semaphore un-lock?
	if {$use_sem && [string length $SEM]} {
		ipc_sem_unlock $SEM
		core::log::write INFO {XL: ipc_sem_unlock lang=$lang}
	}
}


#
# Internal - find xlations in the DB that were modified within the given date
# range and merge them into the main result set in shared mem.
#
# We don't bother with a semaphore since:
#  a) we're not expecting any huge updates after the initial _load_lang_shm.
#  b) hopefully one child will have a cache miss on core::xl::get_last_update
#     before the others and beat the other children to it.
#
# old_rs must be the handle to the existing result set in shared memory
# for the given language.
#
proc core::xl::_merge_updates { lang old_rs start end } {

	variable XL
	variable CFG

	# Get the modified xlations from the database.
	set mod_rs [core::db::exec_qry \
		-name core::xl::get_xlations \
		-args [list $lang $start $end]]

	# Make a local copy of the existing shared result set so that we can
	# manipulate it.

	set local_rs [db_dup $old_rs]

	# It's not possible to modify existing rows in a result set, so instead we
	# remove any modified xlations from the local result set, then merge the
	# updates we've got from the db into the local rs.

	for {set i 0} {$i < [db_get_nrows $mod_rs]} {incr i} {

		set code [db_get_col $mod_rs $i code]

		set row [db_search -sorted $local_rs [list code string $code]]
		if {$row >= 0} {
			db_del_row $local_rs $row
		}

	}

	# merge the updates into the local result set (using -copy instead of -move due to AS bug)
	db_merge -copy $local_rs $mod_rs

	core::db::rs_close -rs $mod_rs

	# Sort our merged result set for quick lookup by code.

	db_sort -null-lo {code string asc} $local_rs

	# Store our merged result set into shared memory (overwriting the old
	# one) + the last update time.

	asStoreRs     $local_rs "xl_rs_$lang" $CFG(rs_cache_time)
	asStoreString $end      "xl_lu_$lang" $CFG(rs_cache_time)

	# Record the result set handle - it's good for this request.
	set XL($lang,rs) $local_rs

	return
}


# Private procedure to get all the API groups (package errors)
#
proc core::xl::_get_api_groups args {

	variable CFG

	# get groups
	set rs [core::db::exec_qry -name core::xl::get_groups]
	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {
		if {$CFG(load_groups) != ""} {
			append CFG(load_groups) |
		}
		append CFG(load_groups) [db_get_col $rs $i group]
	}

	core::db::rs_close -rs $rs

	core::log::write DEV {core::xl: load_groups=$CFG(load_groups)}
}



# core::xl::_convert_to_es_txt: Private procedure to convert number
# to spanish text.
proc core::xl::_convert_to_es_txt {num} {

	set num [string trimleft $num 0]

	if {$num == {}} {
		# set the number to zero
		set num 0
	}

	set len [string length $num]

	switch -- $len {
		1 {
			set text [core::xl::sprintf -code NUM_$num -lang es]
			return $text
		}
		2 {
			# check Rule 1
			if {[expr ($num <= 30)]} {
				# we have a two digit number
				set text [core::xl::sprintf -code NUM_$num -lang es]
				return $text
			}

			# number is greater than 30 - Rule 2 should apply
			set unit [expr ($num % 10)]
			if {$unit == 0} {
				set text "[core::xl::sprintf -code NUM_$num -lang es]"
				return $text
			}

			set tens [expr ($num - $unit)]
			set text [format "%s y %s" \
				[core::xl::sprintf -code NUM_$tens -lang es] \
				[core::xl::sprintf -code NUM_$unit -lang es]]
			return $text
		}
		3 {
			# number greater > 100
			# check if number multiple of 100

			set mult100 [expr ($num % 100)]
			if {$mult100 == 0} {
				# "just" 100 is cien rather than ciento so a different
				# translation will be used:
				if {$num == 100} {
					return "[core::xl::sprintf -code NUM_100_TAILING -lang es]"
				}
				set text [core::xl::sprintf -code NUM_$num -lang es]
				return $text
			}

			set hun [expr ($num -$mult100)]
			set text [format "%s %s" \
				[core::xl::sprintf -code NUM_$hun -lang es]\
				[_convert_to_es_txt $mult100]]
			return $text
		}
		4 -
		5 -
		6 {
			# thousands to 999,999
			# check if 1000

			if {$num == 1000} {
				set text [core::xl::sprintf -code NUM_1000 -lang es]
				return $text
			}

			set mult1000 [expr ($num % 1000)]
			set thous [expr ($num / 1000)]

			# check if number < 2000
			if {$thous == 1} {
				# 1000 - 1999 are treated differently
				if {$mult1000 == 0} {
					set text [core::xl::sprintf -code NUM_1000 -lang es]
				} else {
					set text [format "%s %s" \
						[core::xl::sprintf -code NUM_1000 -lang es] \
						[_convert_to_es_txt $mult1000]]
				}
				return $text
			}

			if {$mult1000 == 0} {
				set text [format "%s %s" \
					[_convert_to_es_txt $thous] \
					[core::xl::sprintf -code NUM_1000 -lang es]]
			} else {
				set text [format "%s %s %s" \
					[_convert_to_es_txt $thous] \
					[core::xl::sprintf -code NUM_1000 -lang es] \
					[_convert_to_es_txt $mult1000]]
			}
			return $text
		}
		7 -
		8 -
		9 {
			# million to 999,999,999
			# check if million ie 1,000,000

			if {$num == 1000000} {
				set text [core::xl::sprintf -code NUM_1000000 -lang es]
				return $text
			}

			set mult1000000 [expr ($num % 1000000)]
			set mill [expr ($num / 1000000)]

			if {$mill == 1} {
				# number < 2 million are slightly different
				if {$mult1000000 == 0} {
					set text [core::xl::sprintf -code NUM_1000000 -lang es]
				} else {
					set text [format "%s %s" \
						[core::xl::sprintf -code NUM_1000000 -lang es]\
						[_convert_to_es_txt $mult1000000]]
				}
				return $text
			}

			# For numbers greater than 2 million we add plural form, millones:
			if {$mult1000000 == 0} {
				set text [format "%s %s" \
					[_convert_to_es_txt $mill]\
					[core::xl::sprintf -code NUM_MILLIONS -lang es]]
			} else {
				set text "[_convert_to_es_txt $mill]\
					[core::xl::sprintf -code NUM_MILLIONS -lang es]\
					[_convert_to_es_txt $mult1000000]"
			}
			return $text
		}
		default {
			# only supporting numbers less than billion
			core::log::write ERROR {core::util::_convert_to_es_txt \
				does not support (higher than billion) number: $num}
			error NUM_TO_TEXT_ERR {Number $num cannot be converted to text}
		}
	}
}

#
# Code only procs, OBCORE-689. Used to generate/retrieve the translation codes.
#

# Intermediary proc whilst shm/no-shm are merged
proc core::xl::_update_code {{force 0} {use_sem 0}} {

	variable CFG

	if {$CFG(shm_avail)} {
		_update_shm_code  $force
	} else {
		_update_local_code $use_sem
	}
}

#
# Request update of the xlation codes in shared mem,
# and ensure that XL(code,rs) contains a handle to the result set.
#
# This is cached for XL_QRY_CACHE_TIME and happens at most once per request.
#
proc core::xl::_update_shm_code { {force 1} } {

	variable XL
	variable CFG

	# Get the request id so we can avoid making more than one update per
	# language per request.

	set req_id [reqGetId]
	if {($force == 0) && [info exists XL(code,last_req_upd)]} {
		if { $XL(code,last_req_upd) == $req_id && \
		     ($req_id > 0 || [db_exists $XL(code,rs)]) } {
			return
		}

		# do we only check for updates periodically anyway (to avoid the
		# additional shared memory lookups if this causes performance issues)
		if {$CFG(shm_upd_chk_frq) > 0} {
			if {[info exists XL(code,next_check_date)] && $XL(code,next_check_date) > [clock seconds]} {
				# try to just grab the result set
				if {![catch {set XL(code,rs) [asFindRs "xl_rs_code"]}]} {
					# managed to find it
					set XL(code,last_req_upd) $req_id
					return
				}
			}
		}
	} else {
		set XL(code,last_req_upd) -1
	}

	# When were the xlation codes in the database last updated?
	if {$force == 1} {
		set rs [core::db::exec_qry \
			-name  core::xl::get_last_update_code \
			-force 1 \
		]
	} else {
		set rs [core::db::exec_qry \
			-name core::xl::get_last_update_code \
		]
	}

	set lu_db [db_get_col $rs 0 last_update]
	core::db::rs_close -rs $rs
	
	# Do we have any xlation codes in shared memory, and if so,
	# when were they last updated?

	set found_ok 0
	unset -nocomplain XL(code,rs)
	catch {
		set rs     [asFindRs "xl_rs_code"]
		set lu_shm [asFindString "xl_lu_code"]
		set XL(code,rs) $rs
		set found_ok 1
	}

	if {!$found_ok} {
		# No, there are no xlation codes in shared memory for this language.
		# We need to load all the xlation codes.
		_load_code_shm
	} else {

		# Yes, we have xlation codes in shared memory.
		# However, if the xlation codes in shared memory are older than those in
		# the DB then we need to load the updated ones into shared memory.

		core::log::write DEBUG {XL _update_code: db = $lu_db, shm = $lu_shm}

		if {$lu_db > $lu_shm} {
			_merge_updates_code $rs $lu_shm $lu_db
		}
	}

	# Note the request id so we can avoid making more than one update per
	# request

	set XL(code,last_req_upd) $req_id

	return
}

# Private procedure to update the translation codes.
#
# The update is only performed once-per request and will only add those
# translation codes which have been changed since the last update call.
#
# NB: Updates are not protected by the semaphore, as the result-sets will
#     only be small (startup locks the semaphore when loading all the data).
#     Secondly, it avoids blocking a child app on startup.
#
#   use_sem - use the semaphore while loading/updating the translation codes (0)
#
proc core::xl::_update_local_code { {use_sem 0} } {

	variable XL

	# get the request id
	set id [reqGetId]

	# dont repeat update on the same request
	# - force an update if "code" unknown (allows xlation codes
	#   to be loaded on demand, but no protection from the semaphore)
	if {[info exists XL(code,last_checked)]} {
		if {$XL(code,last_checked) == $id} {
			return
		}
	} else {
		core::log::write WARNING {XL: _update_local_code, unknown "code"}

		set XL(code,last_checked) -1
		set XL(code,last_updated) "0001-01-01 00:00:00"
		set use_sem 1
	}

	if {[catch {

		core::log::write DEV \
		    {XL: _update_local_code id=$id last_updated=$XL(code,last_updated)}

		# get the last time the translation codes were updated
		set rs [core::db::exec_qry -name core::xl::get_last_update_code]
		set last_updated [db_get_col $rs 0 last_update]

		core::db::rs_close -rs $rs

		# add any translation codes which has changed since our last look
		if {$last_updated > $XL(code,last_updated)} {

			_load_code_local \
				$last_updated \
				$use_sem

			set XL(code,last_updated) $last_updated
		}

		# stop multiple updates per-request
		set XL(code,last_checked) $id

	} msg]} {
		core::log::write ERROR {XL: $msg}
	}
}


#
# If we have no xlation codes in shared mem, load all xlation codes into shared mem.
#
# By default, a semaphore will be used to ensure only one process does this
# at a time.
#
proc core::xl::_load_code_shm { {use_sem 0} } {

	variable XL
	variable SEM
	variable CFG

	core::log::write DEBUG {XL: loading all xlations code}
	# Semaphore lock?

	if {$use_sem && [string length $SEM]} {
		core::log::write INFO {XL: locking semaphore for code loading}
		ipc_sem_lock $SEM
	}

	# It's possible that while we were waiting for the semaphore, someone
	# else has loaded the xlation codes into shared mem. Check for this now.

	set found_ok 0
	catch {
		set rs [asFindRs "xl_rs_code"]

		# XXX The 'slater' version used to compare [db_get_valid_til $rs] with
		# the one we recorded previously so that we could identify when the
		# appserver lies to us about the result set expiring. I maintain this
		# is unnecessary.

		set XL(code,rs) $rs
		set found_ok 1 
	}

	if {$found_ok} {
		# No action needed - xlation codes are already there.

		core::log::write DEBUG {XL: xlations codes already present}
		if {$use_sem && [string length $SEM]} {
			ipc_sem_unlock $SEM
			core::log::write INFO {XL: unlocked semaphore for code}
		}

		return
	}

	# Ok, we've got the lock and the result set isn't there so we need to
	# go and retrieve it.

	core::log::write DEBUG {XL: still no xlation codes found in shared mem}

	# Get ALL xlation codes

	if {[catch {
		set rs [core::db::exec_qry \
			-name core::xl::get_xlations_load_code \
		]

		# Sort the result set for quick lookup by code.
		db_sort -null-lo {code string asc} $rs

		# Store the result set in shared mem.
		asStoreRs     $rs  "xl_rs_code" $CFG(rs_cache_time)

		# Record the result set handle - good for this request.
		set XL(code,rs) $rs

		# XXX The 'slater' version used to record [db_get_valid_til $rs] in XL
		# here so that we could identify elsewhere when the appserver lies to
		# us about the result set expiring. I maintain this is unnecessary.

	} msg]} {

		if {$use_sem && [string length $SEM]} {
			ipc_sem_unlock $SEM
			core::log::write INFO {XL: unlocked semaphore for code}
		}

		core::log::write ERROR {XL: failed to load xlations code : $msg}
		error "XL: failed to load xlation codes: $msg"
	}

	if {$use_sem && [string length $SEM]} {
		ipc_sem_unlock $SEM
		core::log::write INFO {XL: unlocked semaphore for code}
	}
	
	return
}

# Private procedure to load all the translation code 
# which have changed since the last load.
#
# If the cfg value XL_SEMAPHORE_ENABLE and param use_sem is set, then a
# semaphore is used to protected the creation of the translation code result-set. As
# this is cached and can yield large result-sets, the semaphore makes sure that
# only one child process is generating the set (any waiting children will
# manipulate the cached set).
#
#   end     - newest translation code modification
#             NB: last update time stored in XL(code,last_updated)
#   use_sem - use the semaphore while loading/updating the translations (0)
#
proc core::xl::_load_code_local { end {use_sem 0} } {

	variable XL
	variable SEM

	set start $XL(code,last_updated)
	core::log::write DEV {XL: _load_code_local from=$start to=$end}

	# semaphore lock?
	if {$use_sem && [string length $SEM]} {
		core::log::write INFO {XL: ipc_sem_lock translation code}
		ipc_sem_lock $SEM
	}

	if {[info exists XL(code,loaded)]} {

		if {[catch {
			set rs [core::db::exec_qry \
				-name core::xl::get_xlations_code] 

			set nrows [db_get_nrows $rs]

			for {set i 0} {$i < $nrows} {incr i} {
				set code [db_get_col $rs $i code]

				set XL(code,$code) $code
			}
			core::db::rs_close -rs $rs
		} msg]} {
			core::log::write ERROR {XL: $msg}
		}
		set XL(code,loaded) 1

		# semaphore un-lock?
		if {$use_sem && [string length $SEM]} {
			ipc_sem_unlock $SEM
			core::log::write INFO {XL: ipc_sem_unlock code}
		}

	} else {

		if {[catch {
			set rs [core::db::exec_qry \
				-name core::xl::get_xlations_load_code \
				-args [list $start $end]]

			set nrows [db_get_nrows $rs]

			for {set i 0} {$i < $nrows} {incr i} {
				set code [db_get_col $rs $i code]

				set XL(code,$code) $code
			}
			core::db::rs_close -rs $rs
		} msg]} {
			core::log::write ERROR {XL: $msg}
		}
		set XL(code,loaded) 1

		# semaphore un-lock?
		if {$use_sem && [string length $SEM]} {
			ipc_sem_unlock $SEM
			core::log::write INFO {XL: ipc_sem_unlock code}
		}
	}
}


#
# Internal - find xlations in the DB that were modified within the given date
# range and merge them into the main result set in shared mem.
#
# We don't bother with a semaphore since:
#  a) we're not expecting any huge updates after the initial _load_lang_shm.
#  b) hopefully one child will have a cache miss on core::xl::get_last_update
#     before the others and beat the other children to it.
#
# old_rs must be the handle to the existing result set in shared memory
# for the given language.
#
proc core::xl::_merge_updates_code { old_rs start end } {

	variable XL
	variable CFG

	# Get the modified xlations from the database.
	set mod_rs [core::db::exec_qry \
		-name core::xl::get_xlations_code \
		-args [list $start $end]]

	# Make a local copy of the existing shared result set so that we can
	# manipulate it.

	set local_rs [db_dup $old_rs]

	# It's not possible to modify existing rows in a result set, so instead we
	# remove any modified xlation codes from the local result set, then add them
	# back in.

	for {set i 0} {$i < [db_get_nrows $mod_rs]} {incr i} {

		set code [db_get_col $mod_rs $i code]

		set row [db_search -sorted $local_rs [list code string $code]]
		if {$row >= 0} {
			db_del_row $local_rs $row
		}

		db_add_row $local_rs [db_get_row $mod_rs $i]

	}

	core::db::rs_close -rs $mod_rs

	# Sort our merged result set for quick lookup by code.
	db_sort -null-lo {code string asc} $local_rs

	# Store our merged result set into shared memory (overwriting the old
	# one) + the last update time.

	asStoreRs     $local_rs "xl_rs_code" $CFG(rs_cache_time)
	asStoreString $end      "xl_lu_code" $CFG(rs_cache_time)

	# Record the result set handle - it's good for this request.
	set XL(code,rs) $local_rs

	return
}

