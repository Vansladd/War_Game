# Copyright (c) 2014 Orbis Technology Ltd. All rights reserved.
#
# Package to lookup blurbs from tBlurbXlate
#
# Synopsis:
#  core::blurb::init
#  core::blurb::blurb
#
# Configs:
#  BLURB_USE_SEM_LOCK
#  BLURB_SEMAPHORE_VAL
#  BLURB_SHM_ENABLE
#  BLURB_LOAD_BY_SORTS
#  BLURB_LOAD_SORTS
#  BLURB_UPDATE_CACHE_TIME
#  BLURB_QRY_CACHE_TIME
#  BLURB_CACHE_TIME
#  BLURB_LOAD_ON_STARTUP
#  BLURB_UNSTL_LOAD_ONLY
#  BLURB_USE_FAILOVER_LANG
#  BLURB_USE_DEFAULT_LANG
#  BLURB_SHM_UPD_CHK_FRQ

set pkg_version 1.0
package provide core::blurb $pkg_version


# Dependencies
package require core::args       1.0
package require core::log        1.0
package require core::db         1.0
package require core::control    1.0
package require core::xl         1.0
package require core::db::schema 1.0

core::args::register_ns \
	-namespace core::blurb \
	-version   $pkg_version \
	-dependent [list core::args core::check core::log core::db core::control core::db::schema] \
	-docs      util/blurb.xml

# Variables
namespace eval core::blurb {

	variable CFG
	variable SEM
	variable BLURB

	set SEM ""

	set CFG(init) 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
core::args::register \
	-proc_name core::blurb::init \
	-desc {Initialise. Wherever relevant uses the same config names as the legacy ob_blurb package} \
	-args [list \
		[list -arg -semaphore_enable    -mand 0  -check BOOL   -default_cfg BLURB_USE_SEM_LOCK      -default {}     -desc {\
			Whether to use semaphore locking}]\
		[list -arg -semaphore_val       -mand 0  -check UINT   -default_cfg BLURB_SEMAPHORE_VAL     -default 0     -desc {\
			Semaphore key}]\
		[list -arg -shm_enable          -mand 0  -check BOOL   -default_cfg BLURB_SHM_ENABLE        -default 1     -desc {\
			Enable SHM}]\
		[list -arg -load_by_sorts       -mand 0  -check BOOL   -default_cfg BLURB_LOAD_BY_SORTS     -default 0     -desc {\
			Only load certain blurb sort(s)}] \
		[list -arg -load_sorts          -mand 0  -check LIST   -default_cfg BLURB_LOAD_SORTS        -default {}    -desc {\
			List of sort(s) to load}]\
		[list -arg -qry_last_cache_time -mand 0  -check UINT   -default_cfg BLURB_UPDATE_CACHE_TIME -default 10    -desc {\
			How long to cache the qry to retrieve the last update time}]\
		[list -arg -qry_cache_time      -mand 0  -check UINT   -default_cfg BLURB_QRY_CACHE_TIME    -default 0     -desc {\
			How long to cache the blurb queries for}]\
		[list -arg -rs_cache_time       -mand 0  -check UINT   -default_cfg BLURB_CACHE_TIME        -default 0     -desc {\
			Cache time for blurb RS. Requires SHM to be enabled}]\
		[list -arg -unstl_load_only     -mand 0  -check BOOL   -default_cfg BLURB_UNSTL_LOAD_ONLY   -default 0     -desc {\
			Only load unsettled blurbs. Relevant to event hierarchy blurbs only}]\
		[list -arg -load_on_startup     -mand 0  -check STRING -default_cfg BLURB_LOAD_ON_STARTUP   -default {_blank_}    -desc {\
			A list of languages to pre-load on startup}]\
		[list -arg -use_failover_lang   -mand 0  -check BOOL   -default_cfg BLURB_USE_FAILOVER_LANG -default {}    -desc {\
			Fallback to the blurb from tLang.failover if none found for requested lang and supported by schema}]\
		[list -arg -use_default_lang    -mand 0  -check BOOL   -default_cfg BLURB_USE_DEFAULT_LANG  -default {}    -desc {\
			Fallback to the blurb from tControl.default_lang if none found for the requested language}]\
		[list -arg -shm_upd_chk_frq     -mand 0  -check UINT   -default_cfg BLURB_SHM_UPD_CHK_FRQ   -default 0     -desc {\
			Periodic shared memory lookups}]\
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

		# Backwards config compatibility
		foreach {new_switch old_switch undefined_value default_value} {
			load_on_startup    XL_BLURB_LOAD_ON_STARTUP     _blank_   _all_
			semaphore_val      XL_BLURB_SEMAPHORE_PORT      0         9999
			qry_cache_time     XL_BLURB_QRY_CACHE_TIME      0         120
			rs_cache_time      XL_BLURB_SHARED_CACHE_TIME   0         86400
			semaphore_enable   XL_BLURB_SEMAPHORE_ENABLE    {}        1
			use_default_lang   XL_BLURB_USE_DEFAULT_LANG    {}        0
			use_failover_lang  XL_BLURB_USE_DEFAULT_BY_LANG {}        0
		} {
			if {$CFG($new_switch) == $undefined_value} {
				set CFG($new_switch) [OT_CfgGet $old_switch $default_value]
			}
		}

		# Establish whether shm is available
		if {[llength [info commands asStoreRs]] && $CFG(shm_enable)} {
			set CFG(shm_avail) 1
		} else {
			set CFG(shm_avail)       0
			set CFG(shm_upd_chk_frq) 0
		}

		# Make sure dependencies are initialised
		core::log::init
		core::xl::init
		core::db::schema::init

		# enable the semaphore
		# - semaphore protects the creation of the cached result set, therefore,
		#   stopping more than one appserv executing the same query
		#   (result-set can be quite large, as all the blurbs for each lang
		#   is returned)
		if {$CFG(semaphore_enable)} {
			core::log::write INFO {BLURB: enabling semaphore port=$CFG(semaphore_val)}
			set SEM [ipc_sem_create $CFG(semaphore_val)]
		} else {
			core::log::write WARNING {BLURB: not using semaphore}
		}

		_prepare_qrys

		# Do we need to pre-load certain languages?
		if {$CFG(load_on_startup) != "_none_"} {
			_load_on_startup
		} else {
			core::log::write WARNING {BLURB: Not loading any language on startup}
		}

		# successfully initialised
		set CFG(init) 1
	}


core::args::register \
	-proc_name core::blurb::get_config \
	-desc {Public accessor to the config array}\
	-args [list\
		[list -arg -cfg -mand 1 -check STRING -desc {Name of cfg item}] \
	]\
	-body {
		variable CFG

		if {[info exists CFG($ARGS(-cfg))]} {
			return $CFG($ARGS(-cfg))
		}

		return {}
	}

core::args::register \
	-proc_name core::blurb::blurb \
	-desc      {Return the blurb value in a given language for a given item}\
	-args [list \
		[list -arg -lang    -mand 1 -check STRING   -desc {Langauge}] \
		[list -arg -sort    -mand 1 -check STRING   -desc {Blurb sort e.g EVENT, EV_MKT, NEWS, etc}] \
		[list -arg -ref_id  -mand 1 -check UINT     -desc {Element identifier e.g ev_id, ev_mkt_id, news_id etc}] \
		[list -arg -default -mand 0 -check STRING   -desc {Default blurb} -default {}] \
	] \
	-body {
		variable CFG

		set lang   $ARGS(-lang)
		set sort   $ARGS(-sort)
		set ref_id $ARGS(-ref_id)

		# check for updates
		_update $lang

		# Look up the blurbs (empty string if no match).
		lassign [_lookup $lang $sort $ref_id] found blurb

		# If there was no blurb for that language, try the failover language instead
		if {!$found && $CFG(use_failover_lang)} {
			set failover_lang [core::xl::get -item failover -lang $lang -default {}]
			if {$lang != $failover_lang && $failover_lang != ""} {
				core::log::write DEBUG {BLURB Blurb not found. Trying failover $failover_lang}
				_update $failover_lang
				lassign [_lookup $failover_lang $sort $ref_id] found blurb
			}
		}

		# If we still haven't found a blurb, use the default language provided it's
		# different from any of the languages we tried before
		if {!$found && $CFG(use_default_lang)} {
			set default_lang [core::control::get -name default_lang]
			if {$lang != $default_lang && (!$CFG(use_failover_lang) || $failover_lang != $default_lang)} {
				core::log::write DEBUG {BLURB Blurb not found. Trying default $default_lang}
				_update $default_lang
				lassign [_lookup $default_lang $sort $ref_id] found blurb
			}
		}

		# Finally, if we still haven't found a blurb, return the default
		if {!$found} {
			return $ARGS(-default)
		}

		return $blurb
	}


core::args::register \
	-proc_name core::blurb::req_end \
	-desc {Clean up. Must be called at the end of any request *or timeout* that uses this package}\
	-body {
		variable CFG
		variable BLURB

		if {!$CFG(shm_avail)} {
			return
		}

		# Reset the req_id for those languages that we've updated the SHM for
		# This ensures it will be refreshed from SHM at the start of a req/timeout
		if {[info exists BLURB(langs_updated)]} {
			foreach lang $BLURB(langs_updated) {
				unset BLURB($lang,last_req_upd)
			}
			unset BLURB(langs_updated)
		}
	}


#--------------------------------------------------------------------------
# Private
#--------------------------------------------------------------------------

#
# Blurb lookup procedure - MUST have previously called
# _update for the given lang within this request.
#
proc core::blurb::_lookup {lang sort ref_id} {

	variable CFG
	variable BLURB

	# If we aren't using SHM we should look in the BLURB package cache
	if {!$CFG(shm_avail)} {
		if {[info exists BLURB($lang,$sort,$ref_id)]} {
			return [list 1 $BLURB($lang,$sort,$ref_id)]
		} else {
			return [list 0 ""]
		}
	}

	# Get handle to result set in shared mem for this lang. The _update proc
	# will have ensured that it exists during this request.
	set rs $BLURB($lang,rs)

	# The result set has been sorted for quick lookup by sort and ref_id
	set row [db_search -sorted $rs [list sort string $sort ref_id int $ref_id]]

	if {$row >= 0} {
		set    res [db_get_col $rs $row xl_blurb_1]
		append res [db_get_col $rs $row xl_blurb_2]
		append res [db_get_col $rs $row xl_blurb_3]
		append res [db_get_col $rs $row xl_blurb_4]
		append res [db_get_col $rs $row xl_blurb_5]
		append res [db_get_col $rs $row xl_blurb_6]
		append res [db_get_col $rs $row xl_blurb_7]
		append res [db_get_col $rs $row xl_blurb_8]
		append res [db_get_col $rs $row xl_blurb_9]
		append res [db_get_col $rs $row xl_blurb_10]

		# Found the blurb, return success and the blurb itself
		return [list 1 $res]
	}

	# No blurb found
	return [list 0 ""]
}


# Check for updates
#
proc core::blurb::_update {lang {force 0}} {

	variable CFG

	if {$CFG(shm_avail)} {
		set ret [_update_shm $lang $force]
	} else {
		set ret [_update_local $lang]
	}

	return $ret
}



# Request update of the blurbs in shared mem for the given language,
# and ensure that BLURB($lang,rs) contains a handle to the result set.
#
# This happens at most once per request.
#
proc core::blurb::_update_shm {lang {force 0}} {
	variable BLURB
	variable CFG

	# Get the request id so we can avoid making more than one update per
	# language per request.

	set req_id [reqGetId]
	if {!$force && [info exists BLURB($lang,last_req_upd)]} {
		if { $BLURB($lang,last_req_upd) == $req_id && \
		     ($req_id > 0 || [db_exists $BLURB($lang,rs)]) } {
			return
		}

		# do we only check for updates periodically anyway (to avoid the
		# additional shared memory lookups if this causes performance issues)
		if {$CFG(shm_upd_chk_frq) > 0} {
			if {[info exists BLURB($lang,next_check_date)] && $BLURB($lang,next_check_date) > [clock seconds]} {
				# try to just grab the result set
				if {![catch {set BLURB($lang,rs) [asFindRs "blurb_rs_$lang"]}]} {
					# managed to find it
					set BLURB($lang,last_req_upd) $req_id
					return
				}
			}
		}
	} else {
		core::log::write INFO {BLURB: new language $lang}
		set BLURB($lang,last_req_upd) -1
	}

	# When were the blurbs in the database last updated?
	if {$force} {
		set rs [core::db::exec_qry \
			-name  core::blurb::get_last_update \
			-force 1 \
			-args [list $lang]]
	} else {
		set rs [core::db::exec_qry \
			-name core::blurb::get_last_update \
			-args [list $lang]]
	}

	set lu_db [db_get_col $rs 0 last_update]
	core::db::rs_close -rs $rs

	# Do we have any blurbs in shared memory for this language, and if so,
	# when were they last updated?

	set found_ok 0
	unset -nocomplain BLURB($lang,rs)
	catch {
		set rs     [asFindRs     "blurb_rs_$lang"]
		set lu_shm [asFindString "blurb_lu_$lang"]
		set BLURB($lang,rs) $rs
		set found_ok 1
	}

	if {!$found_ok} {
		# No, there are no blurbs in shared memory for this language.
		# We need to load all the blurbs.
		_load_lang_shm $lang
	} else {

		# Yes, we have blurbs in shared memory for this language.
		# However, if the blurbs in shared memory are older than those in
		# the DB then we need to load the updated ones into shared memory.

		core::log::write INFO {BLURB _update: db = $lu_db, shm = $lu_shm}

		if {$lu_db > $lu_shm} {
			_merge_updates $lang $rs $lu_shm $lu_db
		}
	}

	# Note the request id so we can avoid making more than one update per
	# language per request

	set BLURB($lang,last_req_upd) $req_id

	# Make a note that we have cached this language in this request so we can
	# break the cache at req_end
	if {![info exists BLURB(langs_updated)]} {
		set BLURB(langs_updated) [list $lang]
	} else {
		# Add this language to the list of those we have cached in this request/timeout
		if {[lsearch $BLURB(langs_updated) $lang] == -1} {
			lappend BLURB(langs_updated) $lang
		}
	}

	return 1
}


# Load all blurbs for a lang into SHM
#
# By default, a semaphore will be used to ensure only one process does this
# at a time.
#
proc core::blurb::_load_lang_shm {lang} {

	variable SEM
	variable CFG
	variable BLURB

	core::log::write INFO {BLURB: loading all blurbs for $lang}

	set use_sem [expr {$CFG(semaphore_enable) && [string length $SEM]}]

	# Semaphore lock
	if {$use_sem} {
		core::log::write INFO {BLURB: locking semaphore for $lang}
		ipc_sem_lock $SEM
	}

	# It's possible that while we were waiting for the semaphore, another child
	# has loaded the blurbs into shared mem. Check for this now.

	set found_ok 0
	catch {
		set rs [asFindRs "blurb_rs_$lang"]

		set BLURB($lang,rs) $rs
		set found_ok 1
	}

	if {$found_ok} {
		# No action needed - blurbs are already in SHM

		core::log::write DEBUG {BLURB: xlations for $lang already present}
		if {$use_sem} {
			ipc_sem_unlock $SEM
			core::log::write INFO {BLURB: unlocked semaphore for $lang}
		}

		return
	}

	# Ok, we've got the lock and the result set isn't there so we need to
	# go and retrieve it.

	core::log::write DEBUG {BLURB: still no xlations found in shared mem for $lang}

	# As well as the blurbs themselves, we need to store the last update
	# time in shared memory. We want ALL blurbs, so we must use -force to
	# ensure we get the uncached last update time from the database.

	if {[catch {
		set start "1901-01-01 00:00:00"
		set rs [core::db::exec_qry \
			-name  core::blurb::get_last_update \
			-force 1 \
			-args  [list $lang]]

		set end [db_get_col $rs 0 last_update]
		core::db::rs_close -rs $rs

		set qry_args [list $lang $start $end]

		if {$CFG(unstl_load_only)} {
			if {!$CFG(load_by_sorts) || [lsearch $CFG(load_sorts) "EVENT"] != -1} {
				set qry_args [list $lang {*}$qry_args]
			}
			if {!$CFG(load_by_sorts) || [lsearch $CFG(load_sorts) "EV_MKT"] != -1} {
				set qry_args [list $lang {*}$qry_args]
			}
		}

		set rs [core::db::exec_qry \
			-name core::blurb::get_blurbs_load \
			-args $qry_args
		]

		# Sort the result set for quick lookup by sort and ref_id.
		db_sort -null-lo {sort string asc ref_id int asc} $rs

		# Store the result set and last update time in shared mem.
		asStoreRs     $rs  "blurb_rs_$lang" $CFG(rs_cache_time)
		asStoreString $end "blurb_lu_$lang" $CFG(rs_cache_time)

		# Record the result set handle - good for this request.
		set BLURB($lang,rs) $rs

	} msg]} {

		if {$use_sem} {
			ipc_sem_unlock $SEM
			core::log::write INFO {BLURB: unlocked semaphore for $lang}
		}

		core::log::write ERROR {BLURB: failed to load blurbs for $lang : $msg}
		error "BLURB: failed to load xlations for $lang: $msg"
	}

	if {$use_sem} {
		ipc_sem_unlock $SEM
		core::log::write INFO {BLURB: unlocked semaphore for $lang}
	}

	return

}



# Private - find blurbs in the DB that were modified within the given date
# range and merge them into the main result set in shared mem.
#
# We don't bother with a semaphore since:
#  a) we're not expecting any huge updates after the initial _load_lang_shm.
#  b) hopefully one child will have a cache miss on core::blurb::get_last_update
#     before the others and beat the other children to it.
#
# @params
#     lang   - the language to take the updates for
#     old_rs - The current rs that was found in SHM
#
proc core::blurb::_merge_updates { lang old_rs start end } {

	variable BLURB
	variable CFG

	# Get the modified blurbs from the database.
	set mod_rs [core::db::exec_qry \
		-name core::blurb::get_blurb_updates\
		-args [list $lang $start $end]]

	# Make a local copy of the existing shared result set so that we can
	# manipulate it.

	set local_rs [db_dup $old_rs]

	# It's not possible to modify existing rows in a result set, so instead we
	# remove any modified blurbs from the local result set, then add them
	# back in.

	for {set i 0} {$i < [db_get_nrows $mod_rs]} {incr i} {

		set sort   [db_get_col $mod_rs $i sort]
		set ref_id [db_get_col $mod_rs $i ref_id]

		set row [db_search -sorted $local_rs [list sort string $sort ref_id int $ref_id]]
		if {$row >= 0} {
			db_del_row $local_rs $row
		}

		db_add_row $local_rs [db_get_row $mod_rs $i]
	}

	core::db::rs_close -rs $mod_rs

	# Sort our merged result set for quick lookup by sort and ref_id.

	db_sort -null-lo {sort string asc ref_id int asc} $local_rs

	# Store our merged result set into shared memory (overwriting the old
	# one) + the last update time.

	asStoreRs     $local_rs "blurb_rs_$lang" $CFG(rs_cache_time)
	asStoreString $end      "blurb_lu_$lang" $CFG(rs_cache_time)

	# Record the result set handle - it's good for this request.
	set BLURB($lang,rs) $local_rs

	return
}



# Private procedure to update the blurbs for particular language.
#
# The update is only performed once-per request and will only add those
# blurbs which have been changed since the last update call.
#
# NB: Updates are not protected by the semaphore, as the result-sets will
#     only be small (startup locks the semaphore when loading all the data).
#     Secondly, it avoids blocking a child app on startup.
#
#   lang    - language
#
proc core::blurb::_update_local {lang} {
	variable BLURB

	# get the request id
	set id [reqGetId]

	# dont repeat update on the same request
	# - force an update with an unknown language (allows a language
	#   to be loaded on demand, but no protection from the semaphore)
	if {[info exists BLURB($lang,last_checked)]} {
		if {$BLURB($lang,last_checked) == $id} {
			return
		}
		set use_sem 0
	} else {
		core::log::write WARNING {BLURB: _update, unknown language $lang}

		set BLURB($lang,last_checked) -1
		set BLURB($lang,last_updated) "1901-01-01 00:00:00"
		set use_sem 1
	}

	if {[catch {

		core::log::write DEV \
		    {BLURB: _update lang=$lang id=$id last_updated=$BLURB($lang,last_updated)}

		# get the last time the blurbs were updated
		set rs [core::db::exec_qry -name core::blurb::get_last_update -args [list $lang]]
		set last_updated [db_get_col $rs 0 last_update]

		core::db::rs_close -rs $rs

		# add any blurb which has changed since our last look
		if {$last_updated > $BLURB($lang,last_updated)} {

			_load_blurb_local \
				$lang \
				$last_updated \
				$use_sem

			set BLURB($lang,last_updated) $last_updated
		}

		# stop multiple updates per-request
		set BLURB($lang,last_checked) $id

	} msg]} {
		core::log::write ERROR {BLURB: $msg}
	}
}


# Private procedure to load all the blurbs for a particular language
# which have changed since the last load (last load can be "0001-01-01 00:00:00"
# depending on what is in BLURB($lang,last_updated))
#
# If package initialised with -semaphore_enable and param use_sem is set, then a
# semaphore is used to protected the creation of the blurb result-set. As
# this is cached and can yield large result-sets, the semaphore makes sure that
# only one child process is generating the set (any waiting children will
# manipulate the cached set).
#
#   lang    - language
#   end     - newest blurb modification
#   use_sem - use the semaphore while loading/updating the blurbs (0)
#
proc core::blurb::_load_blurb_local { lang end {use_sem 0} } {

	variable CFG
	variable BLURB
	variable SEM

	set start $BLURB($lang,last_updated)
	core::log::write DEV {BLURB: _load_lang_local lang=$lang from=$start to=$end}

	if {$use_sem} {
		if {!$CFG(semaphore_enable) || ![string length $SEM]} {
			set use_sem 0
		}
	}

	# semaphore lock?
	if {$use_sem} {
		core::log::write INFO {BLURB: ipc_sem_lock lang=$lang}
		ipc_sem_lock $SEM
	}

	if {[catch {
		if {$BLURB($lang,last_checked) != -1} {
			# We've already loaded some blurbs during a previous request.
			# Only get updates
			set rs [core::db::exec_qry \
				-name core::blurb::get_blurb_updates \
				-args [list $lang $start $end]]
		} else {
			# This child has never loaded any blurbs before. Get them all
			set qry_args [list $lang $start $end]
			if {$CFG(unstl_load_only)} {
				if {!$CFG(load_by_sorts) || [lsearch $CFG(load_sorts) "EVENT"] != -1} {
					set qry_args [list $lang {*}$qry_args]
				}
				if {!$CFG(load_by_sorts) || [lsearch $CFG(load_sorts) "EV_MKT"] != -1} {
					set qry_args [list $lang {*}$qry_args]
				}
			}
			set rs [core::db::exec_qry \
				-name core::blurb::get_blurbs_load \
				-args $qry_args\
			]
		}

		set nrows [db_get_nrows $rs]

		for {set i 0} {$i < $nrows} {incr i} {
			set sort   [db_get_col $rs $i sort]
			set ref_id [db_get_col $rs $i ref_id]

			set val    [db_get_col $rs $i xl_blurb_1]
			append val [db_get_col $rs $i xl_blurb_2]
			append val [db_get_col $rs $i xl_blurb_3]
			append val [db_get_col $rs $i xl_blurb_4]
			append val [db_get_col $rs $i xl_blurb_5]
			append val [db_get_col $rs $i xl_blurb_6]
			append val [db_get_col $rs $i xl_blurb_7]
			append val [db_get_col $rs $i xl_blurb_8]
			append val [db_get_col $rs $i xl_blurb_9]
			append val [db_get_col $rs $i xl_blurb_10]

			set BLURB($lang,$sort,$ref_id) $val
		}
		core::db::rs_close -rs $rs
	} msg]} {
		core::log::write ERROR {BLURB: $msg}
	}

	# semaphore un-lock?
	if {$use_sem} {
		ipc_sem_unlock $SEM
		core::log::write INFO {BLURB: ipc_sem_unlock lang=$lang}
	}
}


# Pre-load certain languages
#
proc core::blurb::_load_on_startup args {

	variable CFG
	variable BLURB

	core::log::write INFO {BLURB: loading blurbs for langs $CFG(load_on_startup)}

	if {$CFG(load_on_startup) == "_all_"} {
		set load_all 1
	} else {
		set load_all 0
	}

	set codes [core::xl::get -item codes]
	foreach lang $codes {

		# force update on language
		set BLURB($lang,last_checked) -1
		set BLURB($lang,last_updated) "0001-01-01 00:00:00"

		if {$load_all || [lsearch $CFG(load_on_startup) $lang] >= 0} {

			if {$CFG(shm_avail)} {
				_load_lang_shm $lang
			} else {
				_update_local $lang
			}
		}
	}
}


# Get select clause for schema based tBlurbXlate.xl_blurb_* columns
#
proc core::blurb::_extra_select_blurb_clause args {

	set sql [list]
	for {set i 4} {$i <= 10} {incr i} {
		lappend sql [core::db::schema::add_sql_column\
			-table   tBlurbXlate\
			-column  "xl_blurb_${i}"\
			-alias   "xl_blurb_${i}"\
			-default "'' as xl_blurb_${i}"\
		]
	}
	return [join $sql ,]
}


# Private procedure to prepare the package queries
#
proc core::blurb::_prepare_qrys args {

	variable CFG

	# Get last update time
	set cache_time [expr {$CFG(shm_avail) ? $CFG(qry_cache_time) : $CFG(qry_last_cache_time)}]
	core::db::store_qry\
		-name core::blurb::get_last_update\
		-qry  {
			select
				max(last_update) as last_update
			from
				tBlurbXlate
			where
				lang = ?
		}\
		-cache $cache_time

	# Actually pull out the blurbs. There's 2 versions
	#   - initial load (either on init or never loaded the blurbs before)
	#   - changes between two dates
	set base_sql [subst {
		select
			sort,
			ref_id,
			xl_blurb_1,
			xl_blurb_2,
			xl_blurb_3,
			[core::blurb::_extra_select_blurb_clause]
		from
		    tBlurbXlate
		where
			lang = ?
		and last_update >= ?
		and last_update <= ?
		%s
	}]

	set cache_time [expr {$CFG(shm_avail) ? 0 : $CFG(qry_cache_time)}]

	set where_sorts {}
	if {$CFG(load_by_sorts) && [llength $CFG(load_sorts)]} {
		set where_sorts "and sort in ('[join $CFG(load_sorts) {','}]')"
	}

	set sql [format $base_sql $where_sorts]

	# Store version for getting blurb updates
	# This is valid even if -unstl_load_only is on as presumably updates
	# to blurbs are only done on unsettled data. It's not dramatic if the rogue
	# one happens on something settled.
	core::db::store_qry\
		-name  core::blurb::get_blurb_updates\
		-qry   $sql\
		-cache $cache_time

	if {!$CFG(unstl_load_only)} {
		# - Versions for initial load and updates are identical
		core::db::store_qry\
			-name  core::blurb::get_blurbs_load\
			-qry   $sql\
			-cache $cache_time
	} else {
		# - We exclude settled data from the initial load only

		# List of subqueries
		set sql   [list]
		# Sorts to explicitly include or exclude in the "catch all" subquery
		set exclude_sorts [list]

		if {!$CFG(load_by_sorts) || [set idx [lsearch $CFG(load_sorts) "EVENT"]] != -1} {
			lappend sql [subst {
				select
					x.sort,
					x.ref_id,
					x.xl_blurb_1,
					x.xl_blurb_2,
					x.xl_blurb_3,
					[core::blurb::_extra_select_blurb_clause]
				from
					tBlurbXlate x,
					tEvUnstl    u
				where
					x.lang     = ?
				and x.sort     = 'EVENT'
				and x.ref_id   = u.ev_id
			}]

			lappend exclude_sorts "EVENT"
		}

		if {!$CFG(load_by_sorts) || [set idx [lsearch $CFG(load_sorts) "EV_MKT"]] != -1} {
			lappend sql [subst {
				select
					x.sort,
					x.ref_id,
					x.xl_blurb_1,
					x.xl_blurb_2,
					x.xl_blurb_3,
					[core::blurb::_extra_select_blurb_clause]
				from
					tBlurbXlate x,
					tEvMkt      m,
					tEvUnstl    u
				where
					x.lang    = ?
				and x.sort    = 'EV_MKT'
				and x.ref_id  = m.ev_mkt_id
				and m.settled = 'N'
				and u.ev_id   = m.ev_id
			}]

			lappend exclude_sorts "EV_MKT"
		}

		set where_sorts {}
		if {[llength $exclude_sorts]} {
			append where_sorts "and sort not in ('[join $exclude_sorts {','}]')"
		}

		if {$CFG(load_by_sorts) && [llength $CFG(load_sorts)]} {
			set include_sorts $CFG(load_sorts)
			if {[set idx [lsearch $include_sorts "EV_MKT"]] != -1} {
				set include_sorts [lreplace $include_sorts $idx $idx]
			}
			if {[set idx [lsearch $include_sorts "EVENT"]] != -1} {
				set include_sorts [lreplace $include_sorts $idx $idx]
			}
			if {[llength $include_sorts]} {
				append where_sorts " and sort in ('[join $include_sorts {','}]')"
			}
		}

		lappend sql [format $base_sql $where_sorts]

		core::db::store_qry\
			-name  core::blurb::get_blurbs_load\
			-qry   [join $sql "\n union \n"]\
			-cache $cache_time
	}

}
