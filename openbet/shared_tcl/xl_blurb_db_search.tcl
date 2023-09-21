# ======================================================================
# $Id: xl_blurb_db_search.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# Copyright (C) 2006 Orbis Technology Ltd. All rights reserved.
#
#
# This is yet another rewrite of the blurb code, along the lines of the work
# done with mlang.
#
# Configuration:
#   BLURB_SEMAPHORE_ENABLE    enable sempahore                       (1)
#   BLURB_SEMAPHORE_PORT      sempahore ports (overrides PORTS)      ("")
#   BLURB_QRY_CACHE_TIME      get xlations query cache time          (600)
#   BLURB_LOAD_ON_STARTUP     list of lang codes to load on startup  (_none_)
#
# Synopsis:
#   package require util_blurb ?4.5?
#
# Procedures:
#   ob_blurb::init            one time initialisation
#   ob_blurb::get             get language information
#   ob_blurb::blurb           get blurb for specific ev hierarchy level and lang
#   ob_blurb::update_blurb    update a blurb
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

	# Grab configs

	#array set CFG [list \
		#FLAGS_COOKIE [OT_CfgGet FLAGS_COOKIE]
	#]

	namespace export init
	namespace export blurb
	namespace export update_blurb
}

proc ob_blurb::_prepare_queries {} {
	# get the last update to tBlurbXlate table for a particular language
	OB_db::db_store_qry ob_blurb::get_last_update {
		select
			max(last_update) as last_update
		from
		    tBlurbXlate
		where
		    lang = ?
	} [OT_CfgGet BLURB_UPDATE_CACHE_TIME 120]

	# get ALL the previously updated translations for a particular language
	# - query is cached for a few minutes as xlations change relatively
	#   infrequently, it's quite likely that if one does change all the
	#   appservers they will be using the same last_update args. This also
	#   helps greatly during startup, when combined with the semaphore code it
	#   means that the xlations for each language will be retrieved only once
	#   across each server.
	OB_db::db_store_qry ob_blurb::get_blurbs {
		select {+INDEX (iblurbxlate_x1)}
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
	} [OT_CfgGet BLURB_QRY_CACHE_TIME 600]

	# Get all the blurbs
	if {[OT_CfgGet BLURB_UNSTL_LOAD_ONLY 0]} {
		OB_db::db_store_qry ob_blurb::get_all_blurbs {
			select {+INDEX (iblurbxlate_x1)}
				x.sort,
				x.ref_id,
				x.xl_blurb_1,
				x.xl_blurb_2,
				x.xl_blurb_3
			from
				tBlurbXlate x
			where
				x.lang      = ? and
				x.sort not in ('EVENT','EV_MKT')

			union

			select {+INDEX (iblurbxlate_x1)}
				x.sort,
				x.ref_id,
				x.xl_blurb_1,
				x.xl_blurb_2,
				x.xl_blurb_3
			from
				tBlurbXlate x,
				tEvUnstl    u
			where
				x.lang     = ?       and
				x.sort     = 'EVENT' and
				x.ref_id   = u.ev_id

			union

			select {+INDEX (iblurbxlate_x1)}
				x.sort,
				x.ref_id,
				x.xl_blurb_1,
				x.xl_blurb_2,
				x.xl_blurb_3
			from
				tBlurbXlate x,
				tEvMkt      m
			where
				x.lang    = ?           and
				x.sort    = 'EV_MKT'    and
				x.ref_id  = m.ev_mkt_id and
				m.settled = 'N'
		}

	} else {
		OB_db::db_store_qry ob_blurb::get_all_blurbs {
			select {+INDEX (iblurbxlate_x1)}
				sort,
				ref_id,
				xl_blurb_1,
				xl_blurb_2,
				xl_blurb_3
			from
				tBlurbXlate
			where
				lang = ?
		}
	}

	# get language details
	OB_db::db_store_qry ob_blurb::get_langs {
		select
		    lang,
		    name,
		    charset
		from
		    tLang
	} [OT_CfgGet BLURB_QRY_CACHE_TIME 600]

	OB_db::db_store_qry ob_blurb::update_blurb {
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

	OB_db::db_store_qry ob_blurb::insert_blurb {
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

	OB_db::db_store_qry ob_blurb::get_blurb {
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

proc ob_blurb::init {{preload_langs {}}} {

	variable SEM
	variable BLURB

	_prepare_queries

	if {[OT_CfgGet BLURB_USE_SEM_LOCK 1]} {

		if {[set SEM_VAL [OT_CfgGet BLURB_SEMAPHORE_VAL ""]] == ""} {
			set SEM_VAL [OT_CfgGet PORTS]
		}
		set BLURB(use_sem_lock) 1
		set SEM [ipc_sem_create $SEM_VAL]
	} else {
		set BLURB(use_sem_lock) 0
	}

	_load_all_data $preload_langs
}

#
# Run at startup to load the translations, as the query may take
# several seconds it uses a semaphore to make sure we only get the
# data once at startup
#

proc ob_blurb::_load_all_data {preload_langs} {
	variable BLURB

	if {$preload_langs == "_all_"} {
		set preload_all 1
	} else {
		set preload_all 0
	}

	#
	# Retrieve all the languages
	#
	set rs [OB_db::db_exec_qry ob_blurb::get_langs]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set lang [db_get_col $rs $i lang]

		set BLURB($lang,charset)     [db_get_col $rs $i charset]
		set BLURB($lang,last_check_req) -1
		set BLURB($lang,rs_key)      "_blurbs,$lang"
		set BLURB($lang,lu_key)      "_blurbs_last_upd,$lang"
		set BLURB($lang,cache_time)  [OT_CfgGet BLURB_CACHE_TIME 86400]
		set BLURB($lang,valid_til)   0

		if {$preload_all || [lsearch $preload_langs $lang] >= 0} {
			 _load_lang $lang
		}
	}
}


#
# Load all the blurbs for a given language with an update time <= to that
# passed in. The query result set is not cached as we are going to sort it
# and then cache it ourselves directly.
#

proc ob_blurb::_load_lang {lang} {
	variable BLURB
	variable SEM

	if {$BLURB(use_sem_lock)} {
		ob::log::write DEV {BLURB: Locking xlation load semaphore}
		ipc_sem_lock $SEM
	}

	# now that we have the semaphore check that we havn't been blocked whilst
	# someone else was loading the result set we are after

	set found_ok 0

	catch {

		set rs [asFindRs $BLURB($lang,rs_key)]

		#
		# We have to do all this tom foolery because the appserver caching
		# lies to us sometimes because the cache time is nearly up and it wants
		# to avoid everybody hitting the db at the same time.
		#
		# So we need to check if the valid_til time has changed, if it has
		# then the appserver wasn't lying but somebody else has gone and got it
		# db. Otherwise we should go and get it.
		#

		if {!$BLURB($lang,valid_til) ||
			$BLURB($lang,valid_til) != [db_get_valid_til $rs]} {

			set BLURB($lang,valid_til) [db_get_valid_til $rs]
			set BLURB($lang,rs) $rs
			set found_ok 1
		}
	}

	if {$found_ok} {
		if {$BLURB(use_sem_lock)} {ipc_sem_unlock $SEM}
		return
	}

	#
	# Ok, we've got the lock and the result set isn't there so we need to
	# go and retrieve it.
	#

	ob::log::write DEV {BLURB: Result set still not found}

	#
	# Force loading of last update (with an uncached query)
	#
	set rs  [OB_db::db_exec_qry ob_blurb::get_last_update $lang]
	set end [db_get_col $rs 0 last_update]
	OB_db::db_close $rs

	if {[catch {
		if {[OT_CfgGet BLURB_UNSTL_LOAD_ONLY 0]} {
			set rs [OB_db::db_exec_qry ob_blurb::get_all_blurbs $lang $lang $lang]
		} else {
			set rs [OB_db::db_exec_qry ob_blurb::get_all_blurbs $lang]
		}

		if {[db_get_nrows $rs] > 0} {
			db_sort -null-lo {ref_id int asc sort string asc} $rs
		}

		asStoreRs     $rs  $BLURB($lang,rs_key) $BLURB($lang,cache_time)
		asStoreString $end $BLURB($lang,lu_key) $BLURB($lang,cache_time)

		set BLURB($lang,rs) $rs
		set BLURB($lang,valid_til) [db_get_valid_til $rs]
	} msg]} {

		if {$BLURB(use_sem_lock)} {ipc_sem_unlock $SEM}
		ob::log::write ERROR {BLURB: Failed to load translations : $msg}
		error "BLURB: failed to retrieve translations : $msg"
	}

	if {$BLURB(use_sem_lock)} {ipc_sem_unlock $SEM}
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

proc ob_blurb::_check_for_updates {lang} {
	variable BLURB

	if {$BLURB($lang,last_check_req) == [reqGetId]} {
		return
	}

	set BLURB($lang,last_check_req) [reqGetId]

	ob::log::write DEV {BLURB: checking updates for $lang}

	#
	# Get the last update time for this language
	#

	set lu_rs  [OB_db::db_exec_qry ob_blurb::get_last_update $lang]
	set lu_db  [db_get_col $lu_rs 0 last_update]
	OB_db::db_close $lu_rs

	#
	# Retrieve the result set from shared memory, asFindRs will throw an error
	# if the result set is not found. In whch case we need to head off to the
	# db to get it.
	#
	if {[catch {

		set rs [asFindRs     $BLURB($lang,rs_key)]
		set lu [asFindString $BLURB($lang,lu_key)]

		set BLURB($lang,rs) $rs
		set BLURB($lang,valid_til) [db_get_valid_til $rs]

		#
		# If there are new updates in the db we need to get them and add them
		# into out result set
		#
		if {$lu_db > $lu} {
			ob::log::write DEV {BLURB: loading updates for $lang}
			_load_updates $rs $lang $lu $lu_db
		}

	} msg]} {
		ob::log::write INFO {BLURB: Failed to locate rs, loading from db: $msg}
		_load_lang $lang
	}
}

#
# Load any updated translations and merge them into the main result set. This
# is where the scary stuff happens.
#
proc ob_blurb::_load_updates { main_rs lang from to } {

	variable BLURB
	variable SEM

	#
	# If we're using the semaphore, then try to lock it: if we can't, one of our
	# peers is already updating the result-set, so we use our current version
	# and pick up the changes automatically when they become available.
	#
	if { $BLURB(use_sem_lock) } {
		if { [ipc_sem_lock $SEM -nowait] } {
			ob::log::write DEV {BLURB: Locked xlation load semaphore}
		} else {
			ob::log::write DEV {BLURB: Failed to lock xlation load semaphore}
			return
		}
	}

	if { [catch {

		set upd_rs [OB_db::db_exec_qry ob_blurb::get_blurbs $lang $from $to]

		#
		# Make a local copy of the shared result set so that we can manipulate
		# it.
		#
		set new_rs [db_dup $main_rs]

		#
		# We need delete the old rows from the result set before adding the new
		# ones.
		#
		for { set i 0; set n [db_get_nrows $upd_rs] } { $i < $n } { incr i } {

			set sort   [db_get_col $upd_rs $i sort]
			set ref_id [db_get_col $upd_rs $i ref_id]

			set row [db_search -sorted $new_rs [list ref_id int $ref_id \
													 sort string $sort]]

			if { $row >= 0 } {
				ob::log::write DEV \
					{BLURB: deleting updated ref_id: $ref_id, sort: $sort}
				db_del_row $new_rs $row
			}

			db_add_row $new_rs [db_get_row $upd_rs $i]

		}

		OB_db::db_close $upd_rs

		#
		# Re-sort the result set based on ref_id, then sort.
		#
		if {[db_get_nrows $new_rs] > 0} {
			db_sort -null-lo { ref_id int asc sort string asc } $new_rs
		}

		#
		# Store the whole thing back into shared memory.
		#
		asStoreRs $new_rs $BLURB($lang,rs_key) $BLURB($lang,cache_time)
		asStoreString $to $BLURB($lang,lu_key) $BLURB($lang,cache_time)

		set BLURB($lang,rs) $new_rs

	} err] } {
		ob::log::write INFO {BLURB: failed load updates : $err}
	}

	if { $BLURB(use_sem_lock) } {
		ipc_sem_unlock $SEM
	}

}

#=============================================================================
#
# Below are the blurb functions that are availaible to application code
# They should all map through to a call to _xl_blurb.
#

#--------------------------------------------------------------------------
# Get blurbs
#--------------------------------------------------------------------------
proc ob_blurb::blurb {lang sort ref_id} {
	return [_blurb $lang $sort $ref_id]
}

#--------------------------------------------------------------------------
# Get blurbs - called via public blurb function above
#--------------------------------------------------------------------------
proc ob_blurb::_blurb {lang sort ref_id} {
	variable BLURB

	# Check for expiry of language cache.
	_check_for_updates $lang

	set rs  $BLURB($lang,rs)

	if {[set row [db_search -sorted $rs [list ref_id int $ref_id sort string $sort]]] >= 0} {
		return [string trim [join [list [db_get_col $rs $row xl_blurb_1] [db_get_col $rs $row xl_blurb_2] [db_get_col $rs $row xl_blurb_3]] ""]]
	} else {
		if {[OT_CfgGet USE_EN_AS_DEFAULT 1] == 1} {
			# The way the blurbs used to work was that they would essentially "default"
			# to the blurb in the event/news hierarachy tables (english), and over-ride
			# this with a multi-lingual version should one exist. We need to keep this
			# behaviour due to the way the blurbs are used in the admin screens. For eg,
			# we tyically have a, say, spanish news item, specific to the spanish view,
			# and the spanish text for the news item goes into tnews.news and not the
			# tblurbxlate tables.

			_check_for_updates en
			set rs  $BLURB(en,rs)

			if {[set row [db_search -sorted $rs [list ref_id int $ref_id sort string $sort]]] >= 0} {
				return [string trim [join [list [db_get_col $rs $row xl_blurb_1] [db_get_col $rs $row xl_blurb_2] [db_get_col $rs $row xl_blurb_3]] ""]]
			}

			return {}
		}
	}
}

#--------------------------------------------------------------------------
# Update Blurb - old style - kept in for backwards compatibility.
#--------------------------------------------------------------------------
#
proc ob_blurb::update_blurb {lang sort ref_id blurb} {
	set b1 [string range $blurb 0 254]
	set b2 [string range $blurb 255 509]
	set b3 [string range $blurb 510 764]

	if {[catch {
		set rs [OB_db::db_exec_qry ob_blurb::get_blurb $ref_id $sort $lang]

		if {[db_get_nrows $rs]} {
			if {[catch {
				ob_log::write DEV \
					{BLURB: update_blurb lang=$lang ref_id=$ref_id blurb=$blurb}

				set rs_u [OB_db::db_exec_qry ob_blurb::update_blurb $b1 $b2 $b3 $ref_id $sort $lang]
				OB_db::db_close $rs_u
			} msg]} {
				ob_log::write WARNING {BLURB: update_blurb: $msg}
			}
		} else {
			if {[catch {
				ob_log::write DEV \
					{BLURB: insert_blurb lang=$lang ref_id=$ref_id blurb=$blurb}

				set rs_i [OB_db::db_exec_qry ob_blurb::insert_blurb $ref_id $sort $lang $b1 $b2 $b3]
				OB_db::db_close $rs_i
			} msg]} {
				ob_log::write WARNING {BLURB: insert_blurb: $msg}
			}
		}

		OB_db::db_close $rs
	} msg]} {
		ob_log::write WARNING {BLURB: update_blurb: $msg}
	}
}

namespace eval ob_log {
}

proc ob_log::write { level msg } {
	OT_LogWrite $level [uplevel subst [list $msg]]
}
