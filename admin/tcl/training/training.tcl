namespace eval TRAINING {

	asSetAct TRAINING_PlayPage              [namespace code go_play_page]
	asSetAct TRAINING_PlayPageIncl          [namespace code go_play_page_incl]
	asSetAct TRAINING_tpBindString          [namespace code go_tpBindString]
	asSetAct TRAINING_tpSetVar              [namespace code go_tpSetVar]
	asSetAct TRAINING_ifelse                [namespace code go_ifelse]
	asSetAct TRAINING_loop                  [namespace code go_loop]
	asSetAct TRAINING_dbvalues              [namespace code go_dbvalues]
	asSetAct TRAINING_dbcriteria            [namespace code go_dbcriteria]
	asSetAct TRAINING_go_reqGetArg          [namespace code go_reqGetArg]
	asSetAct TRAINING_do_reqGetArg          [namespace code do_reqGetArg]
	asSetAct TRAINING_go_catch              [namespace code go_catch]
	asSetAct TRAINING_do_catch              [namespace code do_catch]
	asSetAct TRAINING_do_catch_details      [namespace code do_catch_details]
	asSetAct TRAINING_do_drilldown		[namespace code do_drilldown]
	#asSetAct TRAINING_get_details           [namespace code get_details]

	proc go_play_page args {
		asPlayFile -nocache training/page.html
	}

	proc go_play_page_incl args {
		asPlayFile -nocache training/page-incl.html
	}

	proc go_tpBindString args {
		global USERNAME
		
		tpBindString username $USERNAME
		#tpBindString username [expr 5 * 65] #;username in html page can be any value even the result of an expression
		asPlayFile -nocache training/tpBindString.html
	}
	

	proc go_tpSetVar args {
		global USERNAME
		tpBindString username $USERNAME
		
		tpSetVar show_username 1

		asPlayFile -nocache training/tpSetVar.html
	}

	proc go_ifelse args {
		global USERNAME
		
		tpBindString username $USERNAME
		
		tpSetVar show_username 1
		
		tpSetVar display_hrz_line 1
		
		asPlayFile -nocache training/if-else.html
	}

	proc go_loop args {
		global PEOPLE
		
		set PEOPLE(0,name) "John"
		set PEOPLE(1,name) "Tom"
		set PEOPLE(2,name) "Will"
		
        	set PEOPLE(0,age) 23
        	set PEOPLE(1,age) 34
        	set PEOPLE(2,age) 44
        	
        	set PEOPLE(3,name) "Paul"
		set PEOPLE(3,age) 54
		
		#tpSetVar num_people 3
		tpSetVar num_people [expr [array size PEOPLE] / 2]
		

		tpBindVar THE_NAME PEOPLE name people_idx
        	tpBindVar THE_AGE  PEOPLE age  people_idx
		
		asPlayFile -nocache training/loop.html
	}

	proc go_dbvalues args {
		global DB
		global CUST
		
		set sql {
			select first 10
				username,
				password
			from
				tcustomer
		}
		
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]
		
		inf_close_stmt $stmt
		
		set num_custs [db_get_nrows $rs]
		tpSetVar num_custs $num_custs
		
		for {set i 0} {$i < $num_custs} {incr i} {
			set CUST($i,uname) [db_get_col $rs $i username]
			set CUST($i,pwrd)  [db_get_col $rs $i password]
		}
		
		db_close $rs
		
		tpBindVar CUST_UNAME CUST uname cust_idx
		tpBindVar CUST_PWRD  CUST pwrd  cust_idx
		
		asPlayFile -nocache training/dbvalues.html
	}

	proc go_dbcriteria args {
		global DB
		global CUST
		
		set sql {
			select
				cust_id,
				username,
				password
			from
				tcustomer
			where
				cust_id >= ? and
				cust_id <= ?
		}
		
		set low_cust_id  3
		set high_cust_id 9
		
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $low_cust_id  $high_cust_id]
		
		inf_close_stmt $stmt
		
		set num_custs [db_get_nrows $rs]
		tpSetVar num_custs $num_custs
		
		for {set i 0} {$i < $num_custs} {incr i} {
			set CUST($i,id)    [db_get_col $rs $i cust_id]
			set CUST($i,uname) [db_get_col $rs $i username]
			set CUST($i,pwrd)  [db_get_col $rs $i password]
		}
		
		db_close $rs
		
		tpBindVar CUST_ID    CUST id    cust_idx
		tpBindVar CUST_UNAME CUST uname cust_idx
		tpBindVar CUST_PWRD  CUST pwrd  cust_idx
		
		asPlayFile -nocache training/dbcriteria.html
	}
	
	proc go_reqGetArg args {
		
		asPlayFile -nocache training/reqGetArg.html
	}

	proc do_reqGetArg {} {
		global DB
		
		set cust_id [reqGetArg cust_id]
		
		set sql {
			select
				username,
				password
			from
				tcustomer
			where
				cust_id = ?
		}
		
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $cust_id]
		
		inf_close_stmt $stmt
		
		if {[db_get_nrows $rs]} {
			tpSetVar found_cust 1
		}
		
		tpBindString CUST_ID    $cust_id
		tpBindString CUST_UNAME [db_get_col $rs 0 username]
		tpBindString CUST_PWRD  [db_get_col $rs 0 password]
		
		db_close $rs
		
		asPlayFile -nocache training/reqGetArg.html
	}
	
	proc go_catch args {
		
		asPlayFile -nocache training/catch.html
	}

	proc do_catch {} {
		global DB
		
		set cust_id [reqGetArg cust_id]
		
		set sql {
			select first 10
				cust_id,
				username,
				password
			from
				tcustomer
			where
				cust_id = ?
		}
		
		if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache training/catch.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $cust_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache training/catch.html
			return
		}
		
		catch {inf_close_stmt $stmt}
		
		if {[db_get_nrows $rs]} {
			tpSetVar found_cust 1
			tpBindString CUST_ID    [db_get_col $rs 0 cust_id]
			tpBindString CUST_UNAME [db_get_col $rs 0 username]
			tpBindString CUST_PWRD  [db_get_col $rs 0 password]
		}
		
		
		
		
		catch {db_close $rs}
		
		asPlayFile -nocache training/catch.html
	}
	
	proc do_catch_details {} {
		global DB
		
		set cust_id [reqGetArg cust_id]
		
		set sql {
			select first 10
				tcustomerreg.fname as fname,
				tcustomerreg.lname as lname,
				tcustomer.bet_count as bet_count
			from
				tcustomerreg
			inner join
				tcustomer on tcustomerreg.cust_id = tcustomer.cust_id
			where
				tcustomer.cust_id = ?
		}
		
		
		
		if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache training/catch.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $cust_id]} msg]} {
			tpBindString err_msg "error occured while executing query"
			ob::log::write ERROR {===>error: $msg}
            		catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache training/catch.html
			return
		}
		
		catch {inf_close_stmt $stmt}
		
		if {[db_get_nrows $rs]} { ;#where data is gathered
			tpSetVar found_details 1
			tpBindString FNAME [db_get_col $rs 0 fname]
			tpBindString LNAME [db_get_col $rs 0 lname]
			tpBindString BET_COUNT [db_get_col $rs 0 bet_count]
		}
		
		
		
		catch {db_close $rs}
		
		
		do_catch ;#do_catch has the correct file to call
	}
	
	

	proc confused_do_drilldown args {
		global DB results
		
		set level [reqGetArg level]
		set clicked [reqGetArg clicked]
		
		set structure(0,name) "Category"
		set structure(0,table) tevcategory
		set structure(0,column) name
		set structure(0,specific) ""
		
		
		set structure(1,name) "Class"
		set structure(1,table) tevclass
		set structure(1,column) name
		set structure(1,specific) "category"
		
		
		set structure(2,name) "Type"
		set structure(2,table) tevtype
		set structure(2,column) name
		set structure(2,specific) "ev_class_id"
		
		
		set structure(3,name) "Event"
		set structure(3,table) tev
		set structure(3,column) desc
		#set structure(3,specific) 
		
		
		set structure(4,name) "Market"
		set structure(4,table) tevmkt
		set structure(4,column) name
		
		set structure(5,name) "Outcome"
		set structure(5,table) tevoc
		set structure(5,column) desc
		
		
		set length [array size structure]
		
		
		set length [expr $length / 3]
		
		set newLevel [expr $level + 1]
		
		
		if { $length > $newLevel} {
			set level $newLevel
		}
			
		
		set sql {
			SELECT
				? as results
			FROM
				tevcategory
		}
		
		puts $structure($level,column)
		
		if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			puts "bad prepare"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache training/drilldown.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $structure($level,column)]} msg]} {
			tpBindString err_msg "error occured while executing query"
			puts "bad execute"
			ob::log::write ERROR {===>error: $msg}
            		catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache training/drilldown.html
			return
		}
		
		catch {inf_close_stmt $stmt}
		
		
		set count [db_get_nrows $rs]
		set results(0,name) {}
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			set count [expr $count + 1]
			set results($i,name) [db_get_col $rs $i results]
			puts "========= [db_get_col $rs $i results]"
			#tpBindString RESULT [db_get_col $rs i results]
		}
		
		puts $results(1,name)
		tpSetVar num_results $count ;#sends number of results
		tpBindVar THE_RESULTS results name results_idx ;#sends all the results
		
		#tpBindVar THE_NAME PEOPLE name people_idx
		
		asPlayFile -nocache training/drilldown.html
	}

	
	proc do_drilldown args {
		global DB results
		
		set level [reqGetArg level]
		set clicked [reqGetArg clicked]
		
		set structure(0,name) "Category"
		set structure(0,table) tevcategory
		set structure(0,column) category
		set structure(0,specific) ""
		
		set structure(0,sql) {
			SELECT
				category as results
			FROM
				tevcategory
		}

		
		
		set structure(1,name) "Class"
		set structure(1,table) tevclass
		set structure(1,column) name
		set structure(1,specific) "category"
		
		set structure(1,sql) {
			SELECT
				name as results
			FROM
				tevclass
			WHERE
				category = ?
		}
		
		
		set structure(2,name) "Type"
		set structure(2,table) tevtype
		set structure(2,column) name
		set structure(2,specific) "ev_class_id"
		
		set structure(2,sql) {
			SELECT
				name as results
			FROM
				tevtype
			WHERE
				1 = 1
		}
		
		
		set structure(3,name) "Event"
		set structure(3,table) tev
		set structure(3,column) desc
		#set structure(3,specific)
		
		set structure(3,sql) {
			SELECT
				desc as results
			FROM
				tev
		}
		
		
		set structure(4,name) "Market"
		set structure(4,table) tevmkt
		set structure(4,column) name

		set structure(4,sql) {
			SELECT
				name as results
			FROM
				tevmkt
		}
		
		set structure(5,name) "Outcome"
		set structure(5,table) tevoc
		set structure(5,column) desc

		set structure(5,sql) {
			SELECT
				desc as results
			FROM
				tevoc
		}

		
		
		set length [array size structure]
		
		
		set length [expr $length / 3]
		
		
		puts $level
		
		set newLevel [expr $level + 1]
		
		puts $newLevel
		
		#if { $length > $newLevel} {}
		if { 6 > $newLevel} {
			set level $newLevel
		}
			
		
		
		if {[catch {set stmt [inf_prep_sql $DB $structure($level,sql)]} msg]} {
			tpBindString err_msg "error occured while preparing statement"
			puts "bad prepare"
			ob::log::write ERROR {===>error: $msg}
			tpSetVar err 1
			asPlayFile -nocache training/drilldown.html
			return
		}
		
		if {[catch {set rs [inf_exec_stmt $stmt $clicked]} msg]} {
			tpBindString err_msg "error occured while executing query"
			puts "bad execute"
			ob::log::write ERROR {===>error: $msg}
            		catch {inf_close_stmt $stmt}
			tpSetVar err 1
			asPlayFile -nocache training/drilldown.html
			return
		}
		
		catch {inf_close_stmt $stmt}
		
		
		set count [db_get_nrows $rs]
		set results(0,name) {}
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			set results($i,name) [db_get_col $rs $i results]
			#puts "========= [db_get_col $rs $i results]"
			#tpBindString RESULT [db_get_col $rs i results]
		}
		
		tpSetVar num_results $count ;#sends number of results
		tpBindVar THE_RESULTS results name results_idx ;#sends all the results
		tpBindString LEVEL $level
		
		
		#tpBindVar THE_NAME PEOPLE name people_idx
		
		asPlayFile -nocache training/drilldown.html
	}
	
	
	proc go_play_page_new args {
		
		core::view::add_header \
			-name  "Content-Type" \
			-value "text/html;"
		
		core::view::play -filename training/page.html
	}
	
	proc go_tpBindString_new args {
		global USERNAME
		
		tpBindString username $USERNAME
		
		core::view::add_header \
			-name  "Content-Type" \
			-value "text/html;"
		
		core::view::play -filename training/tpBindString.html
	}
	
	
	proc go_reqGetArg_new args {
		
		core::view::add_header \
			-name  "Content-Type" \
			-value "text/html;"
		
		core::view::play -filename training/reqGetArgNew.html
	}

	proc do_reqGetArg_new {} {
		global DB
		
		set cust_id [reqGetArg cust_id]
		
		set sql {
			select
				username,
				password
			from
				tcustomer
			where
				cust_id = ?
		}
		
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $cust_id]
		
		inf_close_stmt $stmt
		
		if {[db_get_nrows $rs]} {
			tpSetVar found_cust 1
		}
		
		tpBindString CUST_ID    $cust_id
		tpBindString CUST_UNAME [db_get_col $rs 0 username]
		tpBindString CUST_PWRD  [db_get_col $rs 0 password]
		
		db_close $rs
		
		core::view::add_header \
			-name  "Content-Type" \
			-value "text/html;"
		
		core::view::play -filename training/reqGetArgNew.html
	}
}
