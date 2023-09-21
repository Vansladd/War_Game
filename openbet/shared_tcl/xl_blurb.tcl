# $Id: xl_blurb.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Translate and cache blurbs from the ev hierarchy tables and tblurbxlate
#
# Configuration:
#   XL_SEMAPHORE_ENABLE    enable sempahore                       (1)
#   XL_SEMAPHORE_PORT      sempahore ports (overrides PORTS)      ("")
#   XL_QRY_CACHE_TIME      get xlations query cache time          (600)
#   XL_LOAD_ON_STARTUP     list of lang codes to load on startup  (_none_)
#
# Synopsis:
#   package require util_blurb ?4.5?
#
# Procedures:
#   ob_blurb::init            one time initialisation
#   ob_blurb::get             get language information
#   ob_blurb::blurb           get blurb for specific ev hierarchy level and lang
#


package provide util_blurb 4.5

namespace eval ob_db {
}

proc ob_db::store_qry { name sql {cache_time {0}}} {
	global SHARED_SQL

	set SHARED_SQL($name) $sql
	set SHARED_SQL(cache,$name) $cache_time
}

proc ob_db::exec_qry { name args } {
	return [eval [concat tb_db::tb_exec_qry $name $args]]
}

proc ob_db::rs_close { rs } {
	db_close $rs
}

# Variables
#
namespace eval ob_blurb {

	variable BLURB
	variable CFG
	variable SEM
	variable LANG

	# initially disable use of sempahore
	set SEM ""

	# set current request number
	set LANG(req_no) -1
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initalisation.
#
proc ob_blurb::init {} {
	if {[info command reqGetId] == {reqGetId}} {
		_init [reqGetId]
	} else {
		_init -1
	}
}

# One time initalisation.
#
proc ob_blurb::_init {req_id} {

	variable SEM
	variable CFG

	ob_log::write DEBUG {BLURB: init}

#	# auto reset package data?
#	if {[info commands reqGetId != "reqGetId"} {
#		#error "BLURB: reqGetId not available for auto reset"
#	}

	# get configuration
	set port [OT_CfgGet PORTS 1818]
	array set OPT [list \
		default_charset   iso8859-1\
		semaphore_enable  1\
		semaphore_port    $port\
		tp_set_hook       0\
		qry_cache_time    600\
		load_on_startup   _none_]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "XL_[string toupper $c]" $OPT($c)]
	}

	# enable the semaphore
	# - semaphore protects the creation of the cached result set, therefore,
	#   stopping more than one appserv executing the same query
	#   (result-set can be quite large, as all the translations for each lang
	#   is returned)
	if {$CFG(semaphore_enable)} {
		ob_log::write INFO {BLURB: enabling semaphore port=$CFG(semaphore_port)}
		set SEM [ipc_sem_create $CFG(semaphore_port)]
	} else {
		ob_log::write WARNING {BLURB: not using semaphore}
	}

	# prepare package queries
	_prepare_qrys

	_load_all $req_id
}

# Private procedure to prepare the package queries
#
proc ob_blurb::_prepare_qrys args {

	variable CFG

	# get the last update to tBlurbXlate table for a particular language
	ob_db::store_qry ob_blurb::get_last_update {
		select
			max(last_update) as last_update
		from
		    tBlurbXlate
		where
		    lang = ?
	} [OT_CfgGet BLURB_CACHE_TIME 120]

	# get ALL the previously updated translations for a particular language
	# - query is cached for a few minutes as xlations change relatively
	#   infrequently, it's quite likely that if one does change all the
	#   appservers they will be using the same last_update args. This also
	#   helps greatly during startup, when combined with the semaphore code it
	#   means that the xlations for each language will be retrieved only once
	#   across each server.
	ob_db::store_qry ob_blurb::get_blurbs {
		select
			sort,
			ref_id,
		    xl_blurb_1,
		    xl_blurb_2,
		    xl_blurb_3
		from
		    tBlurbXlate
		where
			lang = ?
		and last_update >= ?
		and last_update <= ?
	} $CFG(qry_cache_time)

	# get language details
	ob_db::store_qry ob_blurb::get {
		select
		    lang,
		    name,
		    charset
		from
		    tLang
		where
		    status = 'A'
	} $CFG(qry_cache_time)

	ob_db::store_qry ob_blurb::update_blurb {
		update tblurbxlate set
			xl_blurb_1 = ?,
			xl_blurb_2 = ?,
			xl_blurb_3 = ?,
			last_update = current
		where
			ref_id = ? and
			sort   = ? and
			lang   = ?
	}

	ob_db::store_qry ob_blurb::insert_blurb {
		insert into tblurbxlate (
			ref_id,
			sort,
			lang,
			xl_blurb_1,
			xl_blurb_2,
			xl_blurb_3,
			last_update
			) values (
			?,
			?,
			?,
			?,
			?,
			?,
			current
		)
	}

	ob_db::store_qry ob_blurb::get_blurb {
		select
			sort,
			ref_id,
		    xl_blurb_1,
		    xl_blurb_2,
		    xl_blurb_3
		from
		    tBlurbXlate
		where
			ref_id = ? and
			sort   = ? and
			lang   = ?
	}
}



#--------------------------------------------------------------------------
# get
#--------------------------------------------------------------------------
# Get language specific information, either language's charset/name or a list
# of all available language codes.
#
#    item    - language item to retreive (charset|name|codes)
#    lang    - language code (default: "")
#    def     - default if the requested item is not found (default: "")
#    returns - request item data;
#              if requesting 'code', then list of available language codes
#
proc ob_blurb::get {item {lang ""} {def ""}} {
	if {[info command reqGetId] == {reqGetId}} {
		return [_get $item [reqGetId] $lang $def]
	}

	return [_get $item -1 $lang $def]
}


#--------------------------------------------------------------------------
# _get - called via public get function above
#--------------------------------------------------------------------------
# Get language specific information, either language's charset/name or a list
# of all available language codes.
#
#    item    - language item to retreive (charset|name|codes)
#    req_id  - request id
#    lang    - language code (default: "")
#    def     - default if the requested item is not found (default: "")
#    returns - request item data;
#              if requesting 'code', then list of available language codes
#
proc ob_blurb::_get {item id {lang ""} {def ""}} {
	variable CFG
	variable LANG

	if {![regexp {^(charset|name|codes)$} $item]} {
		error "Illegal language item - $item"
	}

	# get all the active language details
	set rs [ob_db::exec_qry ob_blurb::get]

	unset LANG
	set LANG(req_no) $id
	set LANG(codes)  [list]

	# store in cache
	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {
		set l                [db_get_col $rs $i lang]
		lappend LANG(codes)  $l
		set LANG($l,name)    [db_get_col $rs $i name]
		set LANG($l,charset) [db_get_col $rs $i charset]
	}
	ob_db::rs_close $rs

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
# Get blurbs
#--------------------------------------------------------------------------
proc ob_blurb::blurb {lang sort ref_id} {
	if {[info command reqGetId] == {reqGetId}} {
		return [_blurb $lang $sort $ref_id [reqGetId]]
	}

	return [_blurb $lang $sort $ref_id -1]
}

#--------------------------------------------------------------------------
# Get blurbs - called via public blurb function above
#--------------------------------------------------------------------------
proc ob_blurb::_blurb {lang sort ref_id req_id} {
	variable BLURB

	# Check for expiry of language cache.
	_update $lang $req_id

	if {[info exists BLURB($lang,$sort,$ref_id)]} {
		return $BLURB($lang,$sort,$ref_id)
	} else {
		if {[OT_CfgGet USE_EN_AS_DEFAULT 1] == 1} {
			# The way the blurbs used to work was that they would essentially "default"
			# to the blurb in the event/news hierarachy tables (english), and over-ride
			# this with a multi-lingual version should one exist. We need to keep this
			# behaviour due to the way the blurbs are used in the admin screens. For eg,
			# we tyically have a, say, spanish news item, specific to the spanish view,
			# and the spanish text for the news item goes into tnews.news and not the
			# tblurbxlate tables.

			if {$lang != {en}} {
				_update en $req_id

				if {[info exists BLURB(en,$sort,$ref_id)]} {
					return $BLURB(en,$sort,$ref_id)
				}
			}
		}

		return {}
	}
}

#--------------------------------------------------------------------------
# Load/Update translations
#--------------------------------------------------------------------------

# Load all the xlations on startup.
#
# If the cfg value XL_SEMAPHORE_ENABLE is set, then a semaphore is used to
# protected the creation of the translation result-set. As this is cached and
# can yield large result-sets, the semaphore makes sure that only one child
# process is generating the set (any waiting children will manipulate the
# cached set).
#
proc ob_blurb::_load_all {req_id} {
	variable BLURB
	variable CFG

	ob_log::write INFO {BLURB: loading xlations $CFG(load_on_startup)}

	if {$CFG(load_on_startup) == "_all_"} {
		set load_all 1
	} else {
		set load_all 0
	}

	set codes [_get codes $req_id]
	foreach lang $codes {

		# force update on language
		set BLURB($lang,last_check_req) -1
		set BLURB($lang,last_updated) "0001-01-01 00:00:00"
		set BLURB($lang,loaded) 0

		# load the language codes now, or on demand
		if {$load_all || [lsearch $CFG(load_on_startup) $lang] >= 0} {
			catch {_update $lang $req_id}
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
#   lang - language
#
proc ob_blurb::_update {lang id} {
	variable BLURB
	variable SEM

	# dont repeat update on the same request
	# - force an update with an unknown language (allows a language xlations
	#   to be loaded on demand, but no protection from the semaphore)
	#
	# -1 is treated as a special case - for feeds that don't have reqGetId. We need
	# to always do the update.
	if {[info exists BLURB($lang,last_check_req)] && $id != -1} {
		if {$BLURB($lang,last_check_req) == $id} {
			return
		}

		set BLURB($lang,last_check_req) $id
	} else {
		ob::log::write WARNING {BLURB: _update, unknown language $lang}
		set BLURB($lang,last_check_req) -1
		set BLURB($lang,last_updated) "0001-01-01 00:00:00"
	}

	# If this is the first time we have loaded the language then use
	# a sempahore around the query so only one child does the work
	if {[info exists BLURB($lang,loaded)] && !$BLURB($lang,loaded) && [string length $SEM]} {
		set use_sem_lock 1
	} else {
		set use_sem_lock 0
	}

	if {[catch {

		ob_log::write DEV \
			{BLURB: _update lang=$lang id=$id last_updated=$BLURB($lang,last_updated)}

		# get the last time the translations were updated
		set rs [ob_db::exec_qry ob_blurb::get_last_update $lang]
		set last_updated [db_get_col $rs 0 last_update]
		ob_db::rs_close $rs

		ob_log::write DEV {BLURB: _update last_updated is $last_updated}

		# If this is the first time we are loading the language then we try to
		# flatten the last_update to the start of the day. This means we won't
		# store too many copies of the xlations in shared memory and we will
		# also make the most of cached data
		set do_catchup 0
		if {!$BLURB($lang,loaded)} {
			set start_of_day [clock format [clock seconds] -format "%Y-%m-%d 00:00:00"]
			if {$last_updated > $start_of_day} {
				set do_catchup 1
			}

			ob::log::write INFO {BLURB:Flatten $lang last_update $last_updated -> $start_of_day}
			set last_update_orig $last_updated
			set last_updated $start_of_day
		}

		if {$last_updated > $BLURB($lang,last_updated)} {
			_load $lang $BLURB($lang,last_updated) $last_updated $use_sem_lock

			set BLURB($lang,last_updated) $last_updated
			set BLURB($lang,loaded) 1

			# If we flattened the last_update value to the start of the day
			# we haven't got all of the latest xlations, do another catchup
			if {$do_catchup} {
				_load $lang $BLURB($lang,last_updated) $last_update_orig $use_sem_lock
				set BLURB($lang,last_updated) $last_update_orig
			}

		}
	} msg]} {
		ob_log::write ERROR {BLURB: $msg}
	}
}



# Private procedure to load all the translations for a particular language
# which have changed since the last load.
#
#   lang - language
#   end  - newest translation modification
#          NB: last update time stored in BLURB($lang,last_updated)
#
proc ob_blurb::_load {lang start end use_sem_lock} {
	variable BLURB
	variable SEM

	if {$use_sem_lock} {
		ipc_sem_lock $SEM
	}

	if {[catch {set rs [ob_db::exec_qry ob_blurb::get_blurbs $lang $start $end]} msg]} {
		if {$use_sem_lock} {
			ipc_sem_unlock $SEM
		}

		ob::log::write ERROR {ob_blurb::_load: Failed to load blurbs}
		error "Unable to load blurb updates: $msg"
	}

	if {$use_sem_lock} {
		ipc_sem_unlock $SEM
	}

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set val [string trim [join [list [db_get_col $rs $i xl_blurb_1] [db_get_col $rs $i xl_blurb_2] [db_get_col $rs $i xl_blurb_3]] ""]]

		set BLURB($lang,[db_get_col $rs $i sort],[db_get_col $rs $i ref_id]) $val
	}
	ob_db::rs_close $rs
}

#--------------------------------------------------------------------------
# Update Blurb
#--------------------------------------------------------------------------
#
proc ob_blurb::update_blurb {lang sort ref_id blurb} {
	set b1 [string range $blurb 0 254]
	set b2 [string range $blurb 255 509]
	set b3 [string range $blurb 510 764]

	if {[catch {
		set rs [ob_db::exec_qry ob_blurb::get_blurb $ref_id $sort $lang]

		if {[db_get_nrows $rs]} {
			if {[catch {
				ob_log::write DEV \
					{BLURB: update_blurb lang=$lang ref_id=$ref_id blurb=$blurb}

				set rs_u [ob_db::exec_qry ob_blurb::update_blurb $b1 $b2 $b3 $ref_id $sort $lang]
				ob_db::rs_close $rs_u
			} msg]} {
				ob_log::write WARNING {BLURB: update_blurb: $msg}
			}
		} else {
			if {[catch {
				ob_log::write DEV \
					{BLURB: insert_blurb lang=$lang ref_id=$ref_id blurb=$blurb}

				set rs_i [ob_db::exec_qry ob_blurb::insert_blurb $ref_id $sort $lang $b1 $b2 $b3]
				ob_db::rs_close $rs_i
			} msg]} {
				ob_log::write WARNING {BLURB: insert_blurb: $msg}
			}
		}

		ob_db::rs_close $rs
	} msg]} {
		ob_log::write WARNING {BLURB: update_blurb: $msg}
	}
}

namespace eval ob_log {
}

proc ob_log::write { level msg } {
	OT_LogWrite 3 [uplevel subst [list $msg]]
}
