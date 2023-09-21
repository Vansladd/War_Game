namespace eval ADMIN::CUST {
	asSetAct ADMIN::CUST::ListUsernames          [namespace code do_list_username]
	
	proc do_list_username args {
		global DB CUST_UNAMES
		
		set stmt [inf_prep_sql $DB {
			select
				username
			from
				tcustomer
			}]
			
		set res_list_uname [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res_list_uname]
		
		tpSetVar NumUnames $nrows

		for {set i 0} {$i < $nrows} {incr i} {
			set CUST_UNAMES($i,uname) [db_get_col $res_list_uname $i username]
		}
		
		tpBindVar UNAME CUST_UNAMES uname cust_list_uames_idx
		
		asPlayFile -nocache training_cust_list.html
		catch {unset CUST_UNAMES}
	}
}