# ==============================================================
# $Id: product_source.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PRODUCTCODE {
	asSetAct ADMIN::PRODUCTCODE::GoProductSourceList    [namespace code go_product_source_list]
	asSetAct ADMIN::PRODUCTCODE::GoProductCode          [namespace code go_product_code]
	asSetAct ADMIN::PRODUCTCODE::DoProductCode          [namespace code do_product_code]
}


proc ADMIN::PRODUCTCODE::go_product_source_list {} {

	global DB PRODUCTCODE

	set sql {
		select
			product_source,
			product_name
		from
			tProductSource
		order by
			product_source
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set PRODUCTCODE($r,Code)           [db_get_col $rs $r product_source]
		set PRODUCTCODE($r,Name)           [db_get_col $rs $r product_name]
	}

	tpSetVar NumCodes $nrows

	db_close $rs

	tpBindVar Code    PRODUCTCODE Code           idx
	tpBindVar Name    PRODUCTCODE Name           idx

	asPlayFile -nocache product_source.html
}



proc ADMIN::PRODUCTCODE::go_product_code {} {

	global DB

	set code [reqGetArg Code]

	if {$code == ""} {
		tpSetVar opAdd 1
	} else {

		set sql [subst {
			select
				product_source,
				product_name
			from
				tProductSource
			where
				product_source = '$code'
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpBindString Code           [db_get_col $rs 0 product_source]
		tpBindString Product        [db_get_col $rs 0 product_name]

		db_close $rs
	}

	asPlayFile -nocache product_code.html
}



proc ADMIN::PRODUCTCODE::do_product_code {} {

	switch -- [reqGetArg SubmitName] {
		CodeDel {
			delete_product_code
		}
		CodeMod {
			modify_product_code
		}
		CodeAdd	{
			add_product_code
		}
		Back {
			go_product_source_list
			return
		}
	}
	go_product_source_list
}



proc ADMIN::PRODUCTCODE::delete_product_code {} {

	global DB

	set sql {
		delete from
			tProductSource
		where
			code = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		inf_exec_stmt $stmt [reqGetArg Code]
	} msg]} {
		tpBindString Error "Cannot delete this product code"
	}

	inf_close_stmt $stmt
}



proc ADMIN::PRODUCTCODE::modify_product_code {} {

	global DB

	set sql {
		update tProductSource set
			product_name = ?
		where
			product_source = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	inf_exec_stmt $stmt\
		[reqGetArg Name]\
		[reqGetArg Code]

	inf_close_stmt $stmt
}



proc ADMIN::PRODUCTCODE::add_product_code {} {

	global DB

	set sql {
		insert into tProductSource(
			product_source,product_name
		)
		values (
			?, ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	inf_exec_stmt $stmt\
			[reqGetArg Code]\
			[reqGetArg Name]

	inf_close_stmt $stmt
}

