# $Id: ip2location.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::IP2LOCATION {

asSetAct ADMIN::IP2LOCATION::Go            [namespace code go]
asSetAct ADMIN::IP2LOCATION::AddIPAllow    [namespace code add_ip_allow]
asSetAct ADMIN::IP2LOCATION::UpdIPAllow    [namespace code upd_ip_allow]
asSetAct ADMIN::IP2LOCATION::DoIPSearch    [namespace code do_ip_search]

proc go {} {

	global DB IPALLOW

	set rs [_get_ip_allow_rs]

	set nrows [db_get_nrows $rs]

	set sql {
		select
			country_code,
			country_name,
			isp_name
		from
			tIP2Location
		where
			ip_from = (
				select max(ip_from)
				from
					tIP2Location
				where
					ip_from <= ?
			)
		and ip_to   >= ?
	}

	set stmt [inf_prep_sql $DB $sql]

	array set IPALLOW [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set ip_address [db_get_col $rs $i ip_address]

		set ip_num [_get_ipnum_from_ipaddr $ip_address]

		set rs_loc [inf_exec_stmt $stmt $ip_num $ip_num]
		if {[db_get_nrows $rs_loc] == 1} {
			set country_code [db_get_col $rs_loc 0 country_code]
			set country_name [db_get_col $rs_loc 0 country_name]
			set isp_name     [db_get_col $rs_loc 0 isp_name]
		} else {
			set country_code "-"
			set country_name "-"
			set isp_name     "-"
		}
		db_close $rs_loc
		set IPALLOW($i,ip_address)   $ip_address
		set IPALLOW($i,allow_id)     [db_get_col $rs $i allow_id]
		set IPALLOW($i,status)       [db_get_col $rs $i status]
		set IPALLOW($i,country_code) $country_code
		set IPALLOW($i,country_name) $country_name
		set IPALLOW($i,isp_name)     $isp_name
		
	}
	inf_close_stmt $stmt

	db_close $rs

	tpSetVar NumIPs $nrows
	tpBindVar AllowId   IPALLOW allow_id     ip_idx
	tpBindVar IPAddress IPALLOW ip_address   ip_idx
	tpBindVar Status    IPALLOW status       ip_idx
	tpBindVar CntryCode IPALLOW country_code ip_idx
	tpBindVar CntryName IPALLOW country_name ip_idx
	tpBindVar ISPName   IPALLOW isp_name     ip_idx

	asPlayFile ip2location.html

	unset IPALLOW
}

proc add_ip_allow {} {

	global DB

	set ip_address [reqGetArg NewIPAddress]
	
	set exp {^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$}

	if {[string length $ip_address] > 15 || [regexp $exp $ip_address] == 0} {
		err_bind "Invalid IP Address: $ip_address"
		go
		return
	}

	set sql {
		insert into tIPAllow (
			ip_address,
			status
		) values (
			?,?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $ip_address "S"
	inf_close_stmt $stmt

	tpSetVar IPAdded 1

	go
}


proc upd_ip_allow {} {
	global DB

	set rs [_get_ip_allow_rs]
	set nrows [db_get_nrows $rs]

	set del_sql {
		delete from tIPAllow
		where
			allow_id = ?
	}
	set upd_sql {
		update tIPAllow
		set
			status = ?
		where
			allow_id = ?
		and	status <> ?
	}

	set del_stmt [inf_prep_sql $DB $del_sql]
	set upd_stmt [inf_prep_sql $DB $upd_sql]

	for {set i 0} {$i < $nrows} {incr i} {
		set allow_id [db_get_col $rs $i allow_id]
		set status   [db_get_col $rs $i status]

		set del [reqGetArg del_${allow_id}]
		if {$del != ""} {
			inf_exec_stmt $del_stmt $allow_id
		} else {
			set active [reqGetArg active_${allow_id}]
			set upd_status ""
			if {$active != "" && $status == "S"} {
				set upd_status "A"
			} elseif {$active == "" && $status == "A"} {
				set upd_status "S"
			}
			if {$upd_status != ""} {
				inf_exec_stmt $upd_stmt $upd_status $allow_id $upd_status
			}
		}
	}
	inf_close_stmt $del_stmt
	inf_close_stmt $upd_stmt

	tpSetVar IPUpdated 1

	go
}


proc _get_ip_allow_rs {} {
	global DB

	set sql {
		select
			allow_id,
			ip_address,
			status
		from
			tIPAllow
		order by
			ip_address
	}
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	return $rs
}

proc do_ip_search {} {

	global DB

	set ipaddr [reqGetArg IPAddress]
	
	set ip_num [_get_ipnum_from_ipaddr $ipaddr]
	
	set sql {
		select FIRST 1
			country_code,
			country_name,
			isp_name,
			ip_to - ip_from as range_size
		from
			tIP2Location
		where
			ip_from = (
				select max(ip_from)
				from
					tIP2Location
				where
					ip_from <= ?
			)
			and ip_to >= ?
		order by
			range_size
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $ip_num $ip_num]} msg]} {
		err_bind $msg
	}
	
	if {[db_get_nrows $rs] == 1} {
		set country_code [db_get_col $rs 0 country_code]
		set country_name [db_get_col $rs 0 country_name]
		set isp_name     [db_get_col $rs 0 isp_name]
	} else {
		set country_code "Not found"
		set country_name ""
		set isp_name ""

	}
	inf_close_stmt $stmt

	db_close $rs

	tpBindString IPAddress $ipaddr
	tpBindString Country_Code $country_code
	tpBindString Country_Name $country_name
	tpBindString ISP $isp_name
	
	

	asPlayFile ipdetails.html

}

proc _get_ipnum_from_ipaddr {ipaddr} {

	foreach {w x y z} [split $ipaddr "."] {}

	set ip_num [expr {($w * 16777216.0) + ($x * 65536.0) + ($y * 256) + $z}]
	set dp [string first "." $ip_num]
	if {$dp >= 0} {
		set ip_num [string range $ip_num 0 [expr {$dp-1}]]
	}

	return $ip_num
}

# close namespace
}
