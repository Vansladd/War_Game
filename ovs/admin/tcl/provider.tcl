# $Id: provider.tcl,v 1.1 2011/10/04 12:41:15 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# --------------------------------------------------------------
#
# Handles OVS Provider/Profile setup
#


namespace eval ADMIN::VERIFICATION::PROVIDER {

	foreach {
		action code
	} {
		GoProviderList      go_provider_list
		GoProvider          go_provider
		GoAddProvider       go_add_provider
		DoAddProvider       do_add_provider
		DoUpdProvider       do_upd_provider
		GoConn              go_conn
		GoAddConn           go_add_conn
		DoAddConn           do_add_conn
		DoUpdConn           do_upd_conn
		GoProfile           go_profile
		GoAddProfile        go_add_profile
		DoAddProfile        do_add_profile
		DoUpdProfile        do_upd_profile
		DoAddCheck          do_add_check
		DoDelCheck          do_del_check
		DoUpdateChecks      do_upd_checks
	} {
		asSetAct ADMIN::VERIFICATION::PROVIDER::$action [namespace code $code]
	}

}


#--------------------------------------------------------------------------
# Provider Procedures
#--------------------------------------------------------------------------

# Procedure to display the list of providers
#
proc ADMIN::VERIFICATION::PROVIDER::go_provider_list {} {

	global DB
	global PRFL_SETUP
	global PROV_SETUP

	array unset PRFL_SETUP
	array unset PROV_SETUP

	# Retrieve providers
	set stmt [inf_prep_sql $DB {
		select
			p.vrf_ext_prov_id,
			p.name,
			p.status,
			p.priority
		from
			tVrfExtProv p
		order by
			4, 2
	}]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# set the global
	set PROV_SETUP(num_providers) [db_get_nrows $res]

	for {set r 0} {$r < $PROV_SETUP(num_providers)} {incr r} {
		foreach field [db_get_colnames $res] {
			# special case
			if {$field == "status"} {
				set PROV_SETUP($r,${field}_txt) \
					[string map {A Active S Suspended} [db_get_col $res $r $field]]
			}

			set PROV_SETUP($r,$field) [db_get_col $res $r $field]
		}
	}

	# bind it up
	tpBindString num_providers  $PROV_SETUP(num_providers)

	tpBindVar prov_id         PROV_SETUP vrf_ext_prov_id prov_idx
	tpBindVar prov_name       PROV_SETUP name            prov_idx
	tpBindVar prov_status     PROV_SETUP status          prov_idx
	tpBindVar prov_status_txt PROV_SETUP status_txt      prov_idx
	tpBindVar prov_priority   PROV_SETUP priority        prov_idx

	# tidy up
	db_close $res


	# Retrieve profiles/checks
	set stmt [inf_prep_sql $DB {
		select
			pr.vrf_ext_prov_id prov_id,
			pr.name            prov_name,
			pf.vrf_ext_pdef_id prfl_id,
			pf.description     prfl_name,
			pf.status          prfl_status,
			c.vrf_ext_cdef_id  chk_id,
			ct.name            chk_name
		from
			tVrfExtProv    pr,
			tVrfExtPrflDef pf,
			outer (tVrfExtChkDef c, tVrfChkType ct)
		where
			pr.vrf_ext_prov_id = pf.vrf_ext_prov_id and
			pf.vrf_ext_pdef_id = c.vrf_ext_pdef_id  and
			c.vrf_chk_type     = ct.vrf_chk_type
		order by
			2, 4, 7
	}]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# set the global
	set PRFL_SETUP(num_ext_profiles)  [db_get_nrows $res]
	set last_prfl_id             -1

	for {set r 0} {$r < $PRFL_SETUP(num_ext_profiles)} {incr r} {

		set curr_prfl_id [db_get_col $res $r prfl_id]
		if {$curr_prfl_id != $last_prfl_id} {
			# we have a new ext profile

			foreach field [db_get_colnames $res] {
				set PRFL_SETUP($r,$field) [db_get_col $res $r $field]
			}

		} else {

			# it is the same as before but have an extra row for another check
			set PRFL_SETUP($r,prov_id)     [db_get_col $res $r prov_id]
			set PRFL_SETUP($r,prov_name)   ""
			set PRFL_SETUP($r,prfl_id)     [db_get_col $res $r prfl_id]
			set PRFL_SETUP($r,prfl_name)   ""
			set PRFL_SETUP($r,prfl_status) [db_get_col $res $r prfl_status]
			set PRFL_SETUP($r,chk_id)      [db_get_col $res $r chk_id]
			set PRFL_SETUP($r,chk_name)    [db_get_col $res $r chk_name]
		}

		set last_prfl_id $curr_prfl_id
	}

	# bind it up
	tpBindString num_ext_profiles  $PRFL_SETUP(num_ext_profiles)

	tpBindVar prfl_id        PRFL_SETUP prfl_id     prfl_idx
	tpBindVar prfl_name      PRFL_SETUP prfl_name   prfl_idx
	tpBindVar prfl_status    PRFL_SETUP prfl_status prfl_idx
	tpBindVar prfl_prov_id   PRFL_SETUP prov_id     prfl_idx
	tpBindVar prfl_prov_name PRFL_SETUP prov_name   prfl_idx
	tpBindVar prfl_chk_id    PRFL_SETUP chk_id      prfl_idx
	tpBindVar prfl_chk_name  PRFL_SETUP chk_name    prfl_idx

	# tidy up
	db_close $res

	# play the template
	asPlayFile -nocache ovs/ext_provider_list.html
}



#
# Procedure to display the details of a provider
#
proc ADMIN::VERIFICATION::PROVIDER::go_provider { {prov_id ""} } {

	global DB
	global CONN_SETUP
	global PRFL_SETUP

	array unset CONN_SETUP
	array unset PRFL_SETUP

	if {$prov_id == ""} {
		set prov_id [reqGetArg prov_id]
	}

	tpSetVar prov_id $prov_id

	# Retrieve provider
	set stmt [inf_prep_sql $DB {
		select
			p.vrf_ext_prov_id,
			p.name,
			p.status,
			p.priority
		from
			tVrfExtProv p
		where
			p.vrf_ext_prov_id = ?
	}]

	set res [inf_exec_stmt $stmt $prov_id]
	inf_close_stmt $stmt

	# bind it up
	tpBindString prov_id       [db_get_col $res 0 vrf_ext_prov_id]
	tpBindString prov_name     [db_get_col $res 0 name]
	tpBindString prov_priority [db_get_col $res 0 priority]

	tpSetVar prov_status [db_get_col $res 0 status]

	# tidy up
	db_close $res


	# Retrieve connections
	set stmt [inf_prep_sql $DB {
		select
			vrf_ext_conn_id conn_id,
			action          conn_action,
			type            conn_type,
			status          conn_status
		from
			tVrfExtProvConn
		where
			vrf_ext_prov_id = ?
		order by
			2
	}]

	set res [inf_exec_stmt $stmt $prov_id]
	inf_close_stmt $stmt

	# set the global
	set CONN_SETUP(num_conn) [db_get_nrows $res]

	for {set r 0} {$r < $CONN_SETUP(num_conn)} {incr r} {
		foreach field [db_get_colnames $res] {
			if {$field == "conn_type"} {
				set CONN_SETUP($r,${field}_txt) \
					[string map {A Authenticate L Log O Other} [db_get_col $res $r $field]]
			}

			set CONN_SETUP($r,$field) [db_get_col $res $r $field]
		}
	}

	# bind it up
	tpBindString num_conn  $CONN_SETUP(num_conn)

	tpBindVar conn_id       CONN_SETUP conn_id       conn_idx
	tpBindVar conn_action   CONN_SETUP conn_action   conn_idx
	tpBindVar conn_type     CONN_SETUP conn_type     conn_idx
	tpBindVar conn_type_txt CONN_SETUP conn_type_txt conn_idx
	tpBindVar conn_status   CONN_SETUP conn_status   conn_idx

	# tidy up
	db_close $res


	# Retrieve profile/checks
	set stmt [inf_prep_sql $DB {
		select
			pf.vrf_ext_pdef_id prfl_id,
			pf.description     prfl_name,
			pf.status          prfl_status,
			c.vrf_ext_cdef_id  chk_id,
			ct.name            chk_name
		from
			tVrfExtPrflDef pf,
			outer (tVrfExtChkDef c, tVrfChkType ct)
		where
			pf.vrf_ext_pdef_id = c.vrf_ext_pdef_id and
			c.vrf_chk_type     = ct.vrf_chk_type   and
			pf.vrf_ext_prov_id = ?
		order by
			2
	}]

	set res [inf_exec_stmt $stmt $prov_id]
	inf_close_stmt $stmt

	# set the global
	set PRFL_SETUP(num_ext_profiles) [db_get_nrows $res]
	set last_prfl_id                -1

	for {set r 0} {$r < $PRFL_SETUP(num_ext_profiles)} {incr r} {

		set curr_prfl_id [db_get_col $res $r prfl_id]
		if {$curr_prfl_id != $last_prfl_id} {

			# we have a new ext profile
			foreach field [db_get_colnames $res] {
				set PRFL_SETUP($r,$field) [db_get_col $res $r $field]
			}

		} else {

			# it is the same as before but have an extra row for another check
			set PRFL_SETUP($r,prfl_id)     [db_get_col $res $r prfl_id]
			set PRFL_SETUP($r,prfl_name)   ""
			set PRFL_SETUP($r,prfl_status) [db_get_col $res $r prfl_status]
			set PRFL_SETUP($r,chk_id)      [db_get_col $res $r chk_id]
			set PRFL_SETUP($r,chk_name)    [db_get_col $res $r chk_name]
		}

		set last_prfl_id $curr_prfl_id
	}

	# bind it up
	tpBindString num_ext_profiles  $PRFL_SETUP(num_ext_profiles)

	tpBindVar prfl_id       PRFL_SETUP prfl_id     prfl_idx
	tpBindVar prfl_name     PRFL_SETUP prfl_name   prfl_idx
	tpBindVar prfl_status   PRFL_SETUP prfl_status prfl_idx
	tpBindVar prfl_chk_id   PRFL_SETUP chk_id      prfl_idx
	tpBindVar prfl_chk_name PRFL_SETUP chk_name    prfl_idx

	# tidy up
	db_close $res

	# play the template
	asPlayFile -nocache ovs/ext_provider.html
}



proc ADMIN::VERIFICATION::PROVIDER::go_add_provider {} {

	asPlayFile -nocache ovs/ext_provider.html
}



# Procedure to add a provider
#
proc ADMIN::VERIFICATION::PROVIDER::do_add_provider {} {

	global DB

	set name     [reqGetArg name]
	set code     [reqGetArg code]
	set status   [reqGetArg status]
	set priority [reqGetArg priority]

	set stmt [inf_prep_sql $DB {
		execute procedure pInsVrfExtProv
			(
			p_name            = ?,
			p_code            = ?,
			p_status          = ?,
			p_priority        = ?
			)
	}]

	if {[catch {
		set res [inf_exec_stmt $stmt \
			$name \
			$code \
			$status \
			$priority]

		inf_close_stmt $stmt

		set prov_id [db_get_coln $res 0 0]

		db_close $res
	} msg]} {

		set text "Could not update verification provider"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"

		go_add_provider

		return
	}

	go_provider $prov_id
}



# Procedure to update a provider
#
proc ADMIN::VERIFICATION::PROVIDER::do_upd_provider {} {

	global DB

	set prov_id  [reqGetArg prov_id]
	set name     [reqGetArg name]
	set code     [reqGetArg code]
	set status   [reqGetArg status]
	set priority [reqGetArg priority]

	set stmt [inf_prep_sql $DB {
		execute procedure pUpdVrfExtProv
			(
			p_vrf_ext_prov_id = ?,
			p_name            = ?,
			p_code            = ?,
			p_status          = ?,
			p_priority        = ?
			)
	}]

	if {[catch {
		set res [inf_exec_stmt $stmt \
			$prov_id \
			$name \
			$code \
			$status \
			$priority]

		inf_close_stmt $stmt

		db_close $res
	} msg]} {

		set text "Could not update verification provider"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"
	}

	go_provider $prov_id
}



#--------------------------------------------------------------------------
# Provider Connection Procedures
#--------------------------------------------------------------------------

proc ADMIN::VERIFICATION::PROVIDER::go_conn { {conn_id ""} } {

	global DB

	if {$conn_id == ""} {
		set conn_id [reqGetArg conn_id]
	}

	# Retrieve profile
	set stmt [inf_prep_sql $DB {
		select
			p.vrf_ext_prov_id prov_id,
			p.name            prov_name,
			c.vrf_ext_conn_id conn_id,
			c.uri             conn_uri,
			c.action          conn_action,
			c.status          conn_status,
			c.type            conn_type,
			c.uname           conn_uname,
			c.password        conn_passwd
		from
			tVrfExtProv     p,
			tVrfExtProvConn c
		where
			p.vrf_ext_prov_id = c.vrf_ext_prov_id and
			c.vrf_ext_conn_id = ?
	}]

	set res [inf_exec_stmt $stmt $conn_id]
	inf_close_stmt $stmt

	# bind it up
	tpBindString prov_id     [db_get_col $res 0 prov_id]
	tpBindString prov_name   [db_get_col $res 0 prov_name]
	tpBindString conn_id     [db_get_col $res 0 conn_id]
	tpBindString conn_uri    [db_get_col $res 0 conn_uri]
	tpBindString conn_uname  [db_get_col $res 0 conn_uname]
	tpBindString conn_action [db_get_col $res 0 conn_action]
	tpBindString conn_passwd [db_get_col $res 0 conn_passwd]

	tpSetVar conn_status [db_get_col $res 0 conn_status]
	tpSetVar conn_type   [db_get_col $res 0 conn_type]

	tpSetVar conn_id $conn_id

	# play the template
	asPlayFile -nocache ovs/ext_conn.html
}



proc ADMIN::VERIFICATION::PROVIDER::go_add_conn {} {

	global DB

	set prov_id [reqGetArg prov_id]

	# Retrieve profile
	set stmt [inf_prep_sql $DB {
		select
			p.vrf_ext_prov_id prov_id,
			p.name            prov_name
		from
			tVrfExtProv     p
		where
			p.vrf_ext_prov_id = ?
	}]

	set res [inf_exec_stmt $stmt $prov_id]
	inf_close_stmt $stmt

	# bind it up
	tpBindString prov_id     [db_get_col $res 0 prov_id]
	tpBindString prov_name   [db_get_col $res 0 prov_name]

	# play the template
	asPlayFile -nocache ovs/ext_conn.html
}



# Procedure to add a provider connection
#
proc ADMIN::VERIFICATION::PROVIDER::do_add_conn {} {

	global DB

	set prov_id  [reqGetArg prov_id]
	set uri      [reqGetArg uri]
	set caction  [reqGetArg caction]
	set uname    [reqGetArg uname]
	set password [reqGetArg password]
	set status   [reqGetArg status]
	set type     [reqGetArg type]

	#Encrypt the password
	set hex [OT_CfgGet OVS_DECRYPT_KEY_HEX] 
	set crpt_password [blowfish encrypt -hex $hex -bin $password]

	set stmt [inf_prep_sql $DB {
		execute procedure pInsVrfExtProvConn
			(
			p_vrf_ext_prov_id = ?,
			p_uri             = ?,
			p_action          = ?,
			p_uname           = ?,
			p_password        = ?,
			p_status          = ?,
			p_type            = ?
			)
	}]

	if {[catch {
		set res [inf_exec_stmt $stmt \
			$prov_id \
			$uri \
			$caction \
			$uname \
			$crpt_password \
			$status \
			$type]

		inf_close_stmt $stmt

		set conn_id [db_get_coln $res 0 0]

		db_close $res
	} msg]} {

		set text "Could not update connection"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"

		go_add_conn

		return
	}

	go_conn $conn_id
}



# Procedure to update a provider connection
#
proc ADMIN::VERIFICATION::PROVIDER::do_upd_conn {} {

	global DB

	set conn_id  [reqGetArg conn_id]
	set uri      [reqGetArg uri]
	set caction  [reqGetArg caction]
	set uname    [reqGetArg uname]
	set password [reqGetArg password]
	set status   [reqGetArg status]
	set type     [reqGetArg type]

	set stmt [inf_prep_sql $DB {
		execute procedure pUpdVrfExtProvConn
			(
			p_vrf_ext_conn_id = ?,
			p_uri             = ?,
			p_action          = ?,
			p_uname           = ?,
			p_password        = ?,
			p_status          = ?,
			p_type            = ?
			)
	}]

	if {[catch {
		set res [inf_exec_stmt $stmt \
			$conn_id \
			$uri \
			$caction \
			$uname \
			$password \
			$status \
			$type]

		inf_close_stmt $stmt

		db_close $res
	} msg]} {

		set text "Could not update connection"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"
	}

	go_conn $conn_id
}

#--------------------------------------------------------------------------
# Profile Procedures
#--------------------------------------------------------------------------

# Procedure to display the details of a provider
#
proc ADMIN::VERIFICATION::PROVIDER::go_profile { {prfl_id ""} } {

	global DB
	global PRFL_SETUP CHK_TYPES

	array unset PRFL_SETUP
	array unset CHK_TYPES

	if {$prfl_id == ""} {
		set prfl_id [reqGetArg prfl_id]
	}

	tpSetVar prfl_id $prfl_id

	# Retrieve profile
	set stmt [inf_prep_sql $DB {
		select
			pr.vrf_ext_prov_id prov_id,
			pr.name            prov_name,
			pf.vrf_ext_pdef_id prfl_id,
			pf.prov_prf_id     prfl_ext_id,
			pf.description     prfl_name,
			pf.status          prfl_status
		from
			tVrfExtProv    pr,
			tVrfExtPrflDef pf
		where
			pr.vrf_ext_prov_id = pf.vrf_ext_prov_id and
			pf.vrf_ext_pdef_id = ?
	}]

	set res [inf_exec_stmt $stmt $prfl_id]
	inf_close_stmt $stmt

	# bind it up
	tpBindString prov_id       [db_get_col $res 0 prov_id]
	tpBindString prov_name     [db_get_col $res 0 prov_name]
	tpBindString prfl_id       [db_get_col $res 0 prfl_id]
	tpBindString prfl_ext_id   [db_get_col $res 0 prfl_ext_id]
	tpBindString prfl_name     [db_get_col $res 0 prfl_name]

	tpSetVar prfl_status [db_get_col $res 0 prfl_status]

	# tidy up
	db_close $res


	# Retrieve checks
	set stmt [inf_prep_sql $DB {
		select
			c.vrf_ext_cdef_id chk_id,
			c.status          status,
			ct.name           chk_name
		from
			tVrfExtChkDef c,
			tVrfChkType ct
		where
			c.vrf_chk_type    = ct.vrf_chk_type and
			c.vrf_ext_pdef_id = ?
		order by
			3
	}]

	set res [inf_exec_stmt $stmt $prfl_id]
	inf_close_stmt $stmt

	# set the global
	set PRFL_SETUP(num_ext_checks) [db_get_nrows $res]

	for {set r 0} {$r < $PRFL_SETUP(num_ext_checks)} {incr r} {
		foreach field [db_get_colnames $res] {
			set PRFL_SETUP($r,$field) [db_get_col $res $r $field]
		}
	}

	db_close $res

	# bind it up
	tpBindString num_ext_checks  $PRFL_SETUP(num_ext_checks)

	tpBindVar chk_id       PRFL_SETUP chk_id      chk_idx
	tpBindVar chk_name     PRFL_SETUP chk_name    chk_idx
	tpBindVar chk_status   PRFL_SETUP status      chk_idx

	set stmt [inf_prep_sql $DB {
		select
			vrf_chk_type chk_type,
			name         chk_name
		from
			tVrfChkType
		where
			vrf_chk_type not in (
				select
					vrf_chk_type
				from
					tVrfExtChkDef
				where
					vrf_ext_pdef_id = ?
			)
		order by
			2
	}]

	set res [inf_exec_stmt $stmt $prfl_id]
	inf_close_stmt $stmt

	set CHK_TYPES(num_chks) [db_get_nrows $res]

	for {set r 0} {$r < $CHK_TYPES(num_chks)} {incr r} {
		foreach field [db_get_colnames $res] {
			set CHK_TYPES($r,$field) [db_get_col $res $r $field]
		}
	}

	tpSetVar num_chk_types $CHK_TYPES(num_chks)

	tpBindVar chk_type      CHK_TYPES chk_type chk_type_idx
	tpBindVar chk_type_name CHK_TYPES chk_name chk_type_idx


	# play the template
	asPlayFile -nocache ovs/ext_profile.html
}



# Procedure to add a profile
#
proc ADMIN::VERIFICATION::PROVIDER::go_add_profile {} {

	global DB

	set prov_id [reqGetArg prov_id]

	# Retrieve profile
	set stmt [inf_prep_sql $DB {
		select
			p.vrf_ext_prov_id prov_id,
			p.name            prov_name
		from
			tVrfExtProv     p
		where
			p.vrf_ext_prov_id = ?
	}]

	set res [inf_exec_stmt $stmt $prov_id]
	inf_close_stmt $stmt

	# bind it up
	tpBindString prov_id     [db_get_col $res 0 prov_id]
	tpBindString prov_name   [db_get_col $res 0 prov_name]

	# play the template
	asPlayFile -nocache ovs/ext_profile.html
}



# Procedure to add a profile
#
proc ADMIN::VERIFICATION::PROVIDER::do_add_profile {} {

	global DB

	set prov_id     [reqGetArg prov_id]
	set prov_prf_id [reqGetArg prov_prf_id]
	set description [reqGetArg description]
	set status      [reqGetArg status]

	set stmt [inf_prep_sql $DB {
		execute procedure pInsVrfExtPrflDef
			(
			p_vrf_ext_prov_id = ?,
			p_prov_prf_id     = ?,
			p_description     = ?,
			p_status          = ?
			)
	}]

	if {[catch {
		set res [inf_exec_stmt $stmt \
			$prov_id \
			$prov_prf_id \
			$description \
			$status]

		inf_close_stmt $stmt

		set prfl_id [db_get_coln $res 0 0]

		db_close $res
	} msg]} {

		set text "Could not insert profile"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"

		go_add_profile

		return
	}

	go_profile $prfl_id
}



# Procedure to update a profile
#
proc ADMIN::VERIFICATION::PROVIDER::do_upd_profile {} {

	global DB

	set prfl_id     [reqGetArg prfl_id]
	set prov_prf_id [reqGetArg prov_prf_id]
	set description [reqGetArg description]
	set status      [reqGetArg status]

	set stmt [inf_prep_sql $DB {
		execute procedure pUpdVrfExtPrflDef
			(
			p_vrf_ext_pdef_id = ?,
			p_prov_prf_id     = ?,
			p_description     = ?,
			p_status          = ?
			)
	}]

	if {[catch {
		set res [inf_exec_stmt $stmt \
			$prfl_id \
			$prov_prf_id \
			$description \
			$status]

		inf_close_stmt $stmt

		db_close $res
	} msg]} {

		set text "Could not update profile"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"
	}

	go_profile $prfl_id
}


#--------------------------------------------------------------------------
# Check Procedures
#--------------------------------------------------------------------------

# Procedure to add a check to a profile
#
proc ADMIN::VERIFICATION::PROVIDER::do_add_check {} {

	global DB

	set prfl_id  [reqGetArg prfl_id]
	set chk_type [reqGetArg chk_type]

	set stmt [inf_prep_sql $DB {
		execute procedure pInsVrfExtChkDef
			(
			p_vrf_chk_type    = ?,
			p_vrf_ext_pdef_id = ?
			)
	}]

	if {[catch {
		set res [inf_exec_stmt $stmt \
			$chk_type \
			$prfl_id]

		set vrf_ext_cdef_id [db_get_coln $res 0 0]

		inf_close_stmt $stmt

		db_close $res
	} msg]} {

		set text "Could not create verification external check definition"
		OT_LogWrite 1 "ERROR - $text: $msg"
		err_bind "$text: $msg"
	}

	go_profile
}



# Procedure to delete a check from a profile
#
proc ADMIN::VERIFICATION::PROVIDER::do_del_check {} {

	global DB

	set chk_id [reqGetArg chk_id]

	set stmt [inf_prep_sql $DB {
		delete from
			tVrfExtChkDef
		where
			vrf_ext_cdef_id = ?
	}]

	if {$chk_id != ""} {
		inf_exec_stmt $stmt $chk_id
		inf_close_stmt $stmt
	}

	go_profile
}

# Procedure to update a check's status
#
proc ADMIN::VERIFICATION::PROVIDER::do_upd_checks {} {

	global DB

	#Init SQL
	set sql {
		update
			tVrfExtChkDef
		set
			status = ?
		where
			vrf_ext_cdef_id = ?
	}
	set stmt [inf_prep_sql $DB $sql]

	#Pull the number from the vrf_ext_cdef_id from the score field
	for {set n 0} {$n < [reqGetNumVals]} {incr n} {
	        set arg [reqGetNthName $n]
		set arg_value [reqGetNthVal $n]

		if { [string match "status_*" $arg] } {
			set split_status [split $arg _]
			set chk_status_id [lindex $split_status [expr [llength $split_status] - 1] ]

			if {[catch {
				inf_exec_stmt $stmt $arg_value $chk_status_id
			} msg]} {
				set text "Could not update external check status"
				OT_LogWrite 1 "ERROR - $text: $msg"
				err_bind "$text: $msg"
				new_profile_def
			}
		}
	}

	inf_close_stmt $stmt
	go_profile
}
