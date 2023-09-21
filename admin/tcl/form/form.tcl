# ==============================================================
# $Id: form.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================
namespace eval ADMIN::FORM {

asSetAct ADMIN::FORM::GoRace        [namespace code go_race]
asSetAct ADMIN::FORM::DoRace        [namespace code do_race]
asSetAct ADMIN::FORM::GoRunner      [namespace code go_runner]
asSetAct ADMIN::FORM::DoRunner      [namespace code do_runner]
asSetAct ADMIN::FORM::GoFormLinks   [namespace code go_type_links]
asSetAct ADMIN::FORM::GoManualLinks [namespace code go_manual_links]
asSetAct ADMIN::FORM::DoManualLinks [namespace code do_manual_links]
asSetAct ADMIN::FORM::GoDD          [namespace code go_dd]
}

proc ADMIN::FORM::make_form_feed_provider_binds {} {

	global DB FORM_PROVIDER

	catch {unset FORM_PROVIDER}

	set default_form_provider_id ""

	set sql {
		select
			provider,
			form_provider_id
		from
			tFormFeedProvider
		where
			displayed = 'Y'
		order by
			form_provider_id asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		set FORM_PROVIDER($i,provider) [db_get_col $res $i provider]
		set FORM_PROVIDER($i,form_provider_id) [db_get_col $res $i form_provider_id]

		if {$i == 0} {
			set default_form_provider_id [db_get_col $res $i form_provider_id]
		}
	}

	tpSetVar NumFormProviders $nrows

	tpBindVar FORM_PROVIDER_NAME FORM_PROVIDER provider         form_idx
	tpBindVar FORM_PROVIDER_ID   FORM_PROVIDER form_provider_id form_idx

	return $default_form_provider_id
}


