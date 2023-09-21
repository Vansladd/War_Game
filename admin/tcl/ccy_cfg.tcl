# ==============================================================
# $Id: ccy_cfg.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CCY_CFG {

asSetAct ADMIN::CCY_CFG::GoCcyCfg   [namespace code go_ccy_cfg]
asSetAct ADMIN::CCY_CFG::DoCcyCfg   [namespace code do_ccy_cfg]



proc go_ccy_cfg args {

	_bind_ccys
	set default_type [_bind_types]
	_bind_values $default_type

	asPlayFile -nocache ccy_cfg.html
}



proc do_ccy_cfg args {

	global DB

	set ccy  [reqGetArg saveCcy]
	set type [reqGetArg saveType]

	if {[reqGetArg noSave] ne ""} {
		go_ccy_cfg
		return
	}

	if {$ccy eq "" || $type eq ""} {
		go_ccy_cfg
		return
	}

	set status "OK"
	inf_begin_tran $DB

	if {$status eq "OK"} {
		# Get site_ccy_id, or create if doesn't exist
		foreach {status site_ccy_id} [_get_site_ccy_id $ccy] {break}
	}

	if {$status eq "OK"} {
		# Remove all rows for this $site_ccy_id and $type
		set status [_remove_rows $site_ccy_id $type]
	}

	if {$status eq "OK"} {
		# Insert the new rows
		set i 0
		while {$status eq "OK" && [reqGetArg "hidden_$i"] ne ""} {
			set status [_insert_row $site_ccy_id $type [string trim [reqGetArg hidden_$i]] $i]
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

	go_ccy_cfg
}



proc _remove_rows {site_ccy_id type} {

	global DB

	set sql [subst {
		delete from
			tSiteCcyVal
		where
			site_ccy_id = $site_ccy_id
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



proc _insert_row {site_ccy_id type val disporder} {

	ob_log::write INFO {_insert_value $site_ccy_id $type $val $disporder}

	global DB

	set sql [subst {
		insert into tSiteCcyVal
			(site_ccy_id, type, value, disporder)
		values
			($site_ccy_id, "$type", "$val", $disporder)
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



# Get tSiteCcyCfg.site_ccy_id (or create it if doesn't exist for $ccy)
proc _get_site_ccy_id {ccy} {

	global DB

	set sql [subst {
		select
			site_ccy_id
		from
			tSiteCcyCfg
		where
			ccy_code = "$ccy"
	}]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		OT_LogWrite 2 "Could not get site_ccy_id: $msg"
		inf_close_stmt $stmt
		return ERR
	}
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	if {$nrows} {
		set site_ccy_id [db_get_coln $rs 0 0]
		db_close $rs
	} else {

		db_close $rs

		set sql [subst {
			insert into tSiteCcyCfg
				(ccy_code)
			values
				("$ccy")
		}]

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {inf_exec_stmt $stmt} msg]} {
			OT_LogWrite 2 "Could not insert site_ccy_id: $msg"
			inf_close_stmt $stmt
			return ERR
		}
		set site_ccy_id [inf_get_serial $stmt]
		inf_close_stmt $stmt
	}

	return [list OK $site_ccy_id]
}



proc _bind_ccys {} {

	global DB CCYS
	unset -nocomplain CCYS

	set sql {
		select ccy_code, ccy_name from tCcy order by disporder
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		OT_LogWrite 2 "Could not get currencies: $msg"
		inf_close_stmt $stmt
		return ""
	}
	inf_close_stmt $stmt

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set CCYS($i,ccy) [db_get_col $rs $i ccy_code]
		set CCYS($i,ccy_name) [db_get_col $rs $i ccy_name]
	}
	db_close $rs

	tpBindVar ccy      CCYS ccy      ccy_idx
	tpBindVar ccy_name CCYS ccy_name ccy_idx

	tpSetVar num_ccys $i
	tpBindString num_ccys $i
}



proc _bind_types {} {

	global DB

	set sql {
		select unique type from tSiteCcyVal order by 1
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

	set ccy [reqGetArg ccy]
	if {$ccy eq ""} {
		set ccy "GBP"
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
			tSiteCcyVal v,
			tSiteCcyCfg c
		where
			v.site_ccy_id = c.site_ccy_id
		and c.ccy_code    = "$ccy"
		and v.type        = "$type"
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