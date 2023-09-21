# $Id: video.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Generic functions for managing video streams
#

namespace eval ADMIN::VIDEO {

    asSetAct ADMIN::VIDEO::GoVideoProvidersList     [namespace code goVideoProvidersList]
    asSetAct ADMIN::VIDEO::GoVideoProvider          [namespace code goVideoProvider]

}


#
# Public procedures
# ===================================================================================


proc ADMIN::VIDEO::goVideoProvidersList {} {

	global DB PROVIDER

	array unset PROVIDER

	OT_LogWrite DEBUG "VIDEO: goVideoProvidersList request"

	set stmt [inf_prep_sql $DB {
		select
			video_provider_id,
			video_provider,
			name
		from
			tVideoProvider
	}]

	set rs [inf_exec_stmt $stmt]
	set n_rows [db_get_nrows $rs]

	inf_close_stmt $stmt

	set configurable_vp [list PERFORM]
	set idx 0

	if {$n_rows == 0} {
		err_bind "No video providers currently exist"
	} else {
		for {set i 0} {$i < $n_rows} {incr i} {
			OT_LogWrite DEV "VIDEO: video provider $i"

			if {[lsearch $configurable_vp [db_get_col $rs $i video_provider]] > -1} {
				foreach col {video_provider_id video_provider name} {

					OT_LogWrite DEV "VIDEO: binding [string toupper $col] as [db_get_col $rs $i $col]"
					set PROVIDER($idx,$col) [db_get_col $rs $i $col]
					tpBindVar [string toupper $col] PROVIDER $col provider_idx
				}

				incr idx
			}
		}
	}

	set PROVIDER(nrows) $idx

	db_close $rs

	asPlayFile video/video_provider_list.html
}


proc ADMIN::VIDEO::goVideoProvider args {

	set provider [reqGetArg video_provider]

	OT_LogWrite DEBUG "VIDEO: goVideoProvider $provider request"

	switch $provider {
		PERFORM {
			ADMIN::PERFORM::goProviderPerform
		}
		default {
			# at least bail out gracefully...
			asPlayFile error.html
		}
	}
}
