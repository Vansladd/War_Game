# ==============================================================
# $Id: lang_cfg.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 OpenBet Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::LANG_CFG {

asSetAct ADMIN::LANG_CFG::GoLangCfg   [namespace code go_lang_cfg]
asSetAct ADMIN::LANG_CFG::DoLangCfg   [namespace code do_lang_cfg]



proc go_lang_cfg args {

	ADMIN::MSG::bind_langs
	set default_type [_bind_types]
	_bind_values $default_type

	asPlayFile -nocache lang_cfg.html
}



proc do_lang_cfg args {

	global DB

	set lang [reqGetArg saveLang]
	set type [reqGetArg saveType]

	if {[reqGetArg noSave] ne ""} {
		go_lang_cfg
		return
	}

	if {$lang eq "" || $type eq ""} {
		go_lang_cfg
		return
	}

	set status "OK"
	inf_begin_tran $DB

	if {$status eq "OK"} {
		# Get site_lang_id, or create if doesn't exist
		foreach {status site_lang_id} [_get_site_lang_id $lang] {break}
	}

	if {$status eq "OK"} {
		# Remove all rows for this $site_lang_id and $type
		set status [_remove_rows $site_lang_id $type]
	}

	if {$status eq "OK"} {
		# Insert the new rows
		set i 0
		while {$status eq "OK" && [reqGetArg "hidden_$i"] ne ""} {
			set status [_insert_row $site_lang_id $type [string trim [reqGetArg hidden_$i]] $i]
			incr i
		}
	}

	if {$status eq "OK"} {
		inf_commit_tran $DB
		msg_bind "Changes saved"
	} else {
		inf_rollback_tran $DB
		err_bind "An error occured"
	}

	go_lang_cfg
}



proc _remove_rows {site_lang_id type} {

	global DB

	set sql [subst {
		delete from
			tSiteLangVal
		where
			site_lang_id = $site_lang_id
		and type         = "$type"
	}]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 2 "Could not remove rows: $msg"
		inf_close_stmt $stmt
		return ERR
	}
	inf_close_stmt $stmt
	return OK
}



proc _insert_row {site_lang_id type val disporder} {

	ob_log::write INFO {_insert_value $site_lang_id $type $val $disporder}

	global DB

	set sql [subst {
		insert into tSiteLangVal
			(site_lang_id, type, value, disporder)
		values
			($site_lang_id, "$type", "$val", $disporder)
	}]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 2 "Could not insert row: $msg"
		inf_close_stmt $stmt
		return ERR
	}
	inf_close_stmt $stmt
	return OK
}



# Get tSiteLangCfg.site_lang_id (or create it if doesn't exist for $lang)
proc _get_site_lang_id {lang} {

	global DB

	set sql [subst {
		select
			site_lang_id
		from
			tSiteLangCfg
		where
			lang = "$lang"
	}]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		OT_LogWrite 2 "Could not get site_lang_id: $msg"
		inf_close_stmt $stmt
		return ERR
	}
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	if {$nrows} {
		set site_lang_id [db_get_coln $rs 0 0]
		db_close $rs
	} else {

		db_close $rs

		set sql [subst {
			insert into tSiteLangCfg
				(lang)
			values
				("$lang")
		}]

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {inf_exec_stmt $stmt} msg]} {
			OT_LogWrite 2 "Could not insert site_lang_id: $msg"
			inf_close_stmt $stmt
			return ERR
		}
		set site_lang_id [inf_get_serial $stmt]
		inf_close_stmt $stmt
	}

	return [list OK $site_lang_id]
}



proc _bind_types {} {

	global DB

	set sql {
		select unique type from tSiteLangVal order by 1
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		OT_LogWrite 2 "Could not get types : $msg"
		inf_close_stmt $stmt
		return ""
	}
	inf_close_stmt $stmt

	global TYPES
	unset -nocomplain TYPES

	set nrows [db_get_nrows $rs]
	set def [db_get_coln $rs 0 0]
	for {set i 0} {$i < $nrows} {incr i} {
		set TYPES($i,type) [db_get_coln $rs $i 0]
	}
	db_close $rs

	tpSetVar num_types $nrows
	tpBindVar type TYPES type type_idx

	return $def
}



proc _bind_values { def_type } {

	global DB

	set lang [reqGetArg lang]
	if {$lang eq ""} {
		set lang "en"
	}

	set type [reqGetArg type]
	if {$type eq ""} {
		set type $def_type
	}

	set sql [subst {
		select
			v.value,
			v.disporder
		from
			tSiteLangVal v,
			tSiteLangCfg c
		where
			v.site_lang_id = c.site_lang_id
		and c.lang = "$lang"
		and v.type = "$type"
	}]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		OT_LogWrite 2 "Could not get values : $msg"
		inf_close_stmt $stmt
		return ""
	}
	inf_close_stmt $stmt

	global VALUES
	unset -nocomplain VALUES

	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {
		set VALUES($i,value) [db_get_coln $rs $i 0]
	}
	db_close $rs

	tpSetVar num_values $nrows
	tpBindVar value VALUES value value_idx
}



# close namespace
}
