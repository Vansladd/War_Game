# ==============================================================
# $Id: ext_promo.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Handlers for 'External System Promo Code' actions
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::EXT_PROMO {

asSetAct ADMIN::EXT_PROMO::GoPromoList [namespace code go_promo_list]
asSetAct ADMIN::EXT_PROMO::GoPromo     [namespace code go_promo]
asSetAct ADMIN::EXT_PROMO::DoPromo     [namespace code do_promo]

}



#
# ----------------------------------------------------------------------------
# Go to promo code list
# ----------------------------------------------------------------------------
#
proc ADMIN::EXT_PROMO::go_promo_list args {

	global DB EXT_PROMO

	set sql {
		select
			h.name,
			p.system_id,
			p.xsys_promo_code,
			p.status,
			p.start_date,
			p.end_date
		from
			tXSysPromo p,
			tXSysHost  h
		where
			p.system_id = h.system_id
		order by
			system_id, xsys_promo_code
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	tpSetVar NumPromoCodes $nrows
	
	for {set i 0} {$i < $nrows} {incr i} {
		set EXT_PROMO($i,system_id)       [db_get_col $res $i system_id]
		set EXT_PROMO($i,name)            [db_get_col $res $i name]
		set EXT_PROMO($i,xsys_promo_code) [db_get_col $res $i xsys_promo_code]
		set EXT_PROMO($i,status)          [db_get_col $res $i status]
		set EXT_PROMO($i,start_date)      [db_get_col $res $i start_date]
		set EXT_PROMO($i,end_date)        [db_get_col $res $i end_date]


	}
	
	db_close $res
	
	tpBindVar SystemId      EXT_PROMO system_id       ext_promo_idx
	tpBindVar SystemName    EXT_PROMO name            ext_promo_idx
	tpBindVar PromoCode     EXT_PROMO xsys_promo_code ext_promo_idx
	tpBindVar Status        EXT_PROMO status          ext_promo_idx
	tpBindVar StartDate     EXT_PROMO start_date      ext_promo_idx
	tpBindVar EndDate       EXT_PROMO end_date        ext_promo_idx

	asPlayFile -nocache ext_promo_list.html
}



#
# ----------------------------------------------------------------------------
# Go to single promo code add/update/delete
# ----------------------------------------------------------------------------
#
proc ADMIN::EXT_PROMO::go_promo args {

	global DB PROMO_SYSTEM

	set action [reqGetArg SubmitName]

	if {$action == "Add"} {
		tpSetVar opAdd 1

		set sql {
			select
				system_id,
				name
			from
				tXSysHost
			where
				promo_available = 'Y'
			order by
				name
		}
	
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
	
		inf_close_stmt $stmt
	
		set nrows [db_get_nrows $res]
		tpSetVar NumPromoSystems $nrows
		
		for {set i 0} {$i < $nrows} {incr i} {
			set PROMO_SYSTEM($i,system_id)       [db_get_col $res $i system_id]
			set PROMO_SYSTEM($i,name)            [db_get_col $res $i name]
		}
		
		db_close $res
		
		tpBindVar SystemId   PROMO_SYSTEM system_id  system_idx
		tpBindVar SystemName PROMO_SYSTEM name       system_idx
		
		tpBindString Status "A"
	} else {
		tpBindString SystemId   [reqGetArg SystemId]
		tpBindString SystemName [reqGetArg SystemName]
		tpBindString PromoCode  [reqGetArg PromoCode]
		tpBindString Status     [reqGetArg Status]
		tpBindString StartDate  [reqGetArg StartDate]
		tpBindString EndDate    [reqGetArg EndDate]

	}

	asPlayFile -nocache ext_promo.html
}



#
# ----------------------------------------------------------------------------
# Do action on a single promo code
# ----------------------------------------------------------------------------
#
proc ADMIN::EXT_PROMO::do_promo args {

	global DB PROMO_SYSTEM

	set action     [reqGetArg SubmitName]
	set system     [reqGetArg System]
	set promo_code [reqGetArg PromoCode]
	set status     [reqGetArg Status]
	set start_date [reqGetArg StartDate]
	set end_date   [reqGetArg EndDate]

	if {$action == "Back"} {

		go_promo_list
		return

	} elseif {$action == "Add"} {

		set split_pos   [string first _ $system]
		set system_id   [string range $system 0 [expr $split_pos - 1]]
		set system_name [string range $system [expr $split_pos + 1] [string length $system]]
		
		set sql {
			execute procedure pInsExtPromo(
				p_system_id = ?,
				p_promo_code = ?,
				p_status = ?,
				p_start_date = ?,
				p_end_date = ?
			)
		}
	
		set stmt [inf_prep_sql $DB $sql]
		
		if {[catch {
			inf_exec_stmt $stmt $system_id $promo_code $status $start_date $end_date
		} msg]} {
			inf_close_stmt $stmt
			ob_log::write ERROR {ERROR: $msg}
			err_bind $msg
			
			reqSetArg SubmitName "Add"
			ADMIN::EXT_PROMO::go_promo
			return
		}
	
		inf_close_stmt $stmt

		tpBindString SystemId   $system_id
		tpBindString SystemName $system_name
		
	} elseif {$action == "Upd"} {
		
		set sql {
			update tXSysPromo set
				status     = ?,
				start_date = ?,
				end_date   = ?
			where
				xsys_promo_code = ?
		}
	
		set stmt [inf_prep_sql $DB $sql]
		
		if {[catch {
			inf_exec_stmt $stmt $status $start_date $end_date $promo_code
		} msg]} {
			inf_close_stmt $stmt
			ob_log::write ERROR {ERROR: $msg}
			err_bind $msg
			
			set status [reqGetArg OriginalStatus]
		}
	
		inf_close_stmt $stmt
		
	} elseif {$action == "Del"} {
		
		set sql {
			delete from tXSysPromo
			where xsys_promo_code = ?
		}
	
		set stmt [inf_prep_sql $DB $sql]
		
		if {[catch {
			inf_exec_stmt $stmt $promo_code
		} msg]} {
			inf_close_stmt $stmt
			ob_log::write ERROR {ERROR: $msg}
			err_bind $msg
			

			
		} else {
			inf_close_stmt $stmt
			ADMIN::EXT_PROMO::go_promo_list
			return
		}
	}


	tpBindString PromoCode  $promo_code
	tpBindString Status     $status
	tpBindString StartDate  $start_date
	tpBindString EndDate    $end_date

	asPlayFile -nocache ext_promo.html
}
