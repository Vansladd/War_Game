#
# $Id: obj_category.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#

namespace eval ADMIN::OBJ_CATEGORY {


	asSetAct ADMIN::OBJ_CATEGORY::GoObjCategories [namespace code go_obj_categories]
	asSetAct ADMIN::OBJ_CATEGORY::GoObjCategory   [namespace code go_obj_category]


	variable SQL
	variable INIT 0

	proc init {} {
		variable INIT

		if $INIT return

		prep_qrys

		set INIT 1
	}

	proc prep_qrys {} {
		variable SQL

		# qrys for customer categories...
		set SQL(spec_cats_C) {
			select
				c.cust_cat_id cat_id,
				name,
				DECODE(NVL(l.cust_cat_id,0), 0, 0, 1) selected
			from
				tCustCat c,
				outer tCustCatLink l

			where
				l.cust_id = ?
			and
				c.cust_cat_id = l.cust_cat_id
		}

		set SQL(all_cats_C) {
			select
				cust_cat_id cat_id,
				name,
				desc
			from
				tCustCat
		}

		set SQL(get_cat_C) {
			select
				cust_cat_id cat_id,
				name,
				desc
			from
				tCustCat
			where
				cust_cat_id = ?

		}

		set SQL(upd_cat_C) {
			update tCustCat set name = ?, desc = ? where cust_cat_id = ?
		}

		set SQL(ins_cat_C) {
			insert into tCustCat (name,desc) values (?,?)
		}

		set SQL(del_cat_C) {
			delete from tCustCat where cust_cat_id = ?
		}

		set SQL(ins_cat_link_C) {
			insert into tCustCatLink (cust_id,cust_cat_id) values (?,?)
		}

		set SQL(del_cat_link_C) {
			delete from tCustCatLink where cust_id = ? and cust_cat_id = ?
		}

		# qrys for selection categories...
		set SQL(spec_cats_S) {
			select
				o.ev_oc_cat_id cat_id,
				name,
				DECODE(NVL(l.ev_oc_cat_id,0), 0, 0, 1) selected

			from
				tEvOcCat o,
				outer tEvOcCatLink l

			where
				l.ev_oc_id = ?
			and
				o.ev_oc_cat_id = l.ev_oc_cat_id
		}

		set SQL(all_cats_S) {
			select
				ev_oc_cat_id cat_id,
				name,
				desc
			from
				tEvOcCat
		}

		set SQL(get_cat_S) {
			select
				ev_oc_cat_id cat_id,
				name,
				desc
			from
				tEvOcCat
			where
				ev_oc_cat_id = ?

		}

		set SQL(upd_cat_S) {
			update tEvOcCat set name = ?, desc = ? where ev_oc_cat_id = ?
		}

		set SQL(ins_cat_S) {
			insert into tEvOcCat (name,desc) values (?,?)
		}

		set SQL(del_cat_S) {
			delete from tEvOcCat where ev_oc_cat_id = ?
		}

		set SQL(ins_cat_link_S) {
			insert into tEvOcCatLink (ev_oc_id,ev_oc_cat_id) values (?,?)
		}

		set SQL(del_cat_link_S) {
			delete from tEvOcCatLink where ev_oc_id = ? and ev_oc_cat_id = ?
		}
	}

	proc exec_qry {qry args} {

		global DB
		variable SQL

		set stmt [inf_prep_sql $DB $SQL($qry)]
		if [catch {set res [eval "inf_exec_stmt $stmt $args"]} msg] {
			err_add "Can't execute query: $msg"
			set res ""
		}
		inf_close_stmt $stmt
		return $res
	}

	proc bind_categories {cat_type id {arr_name CATS}} {

		global DB
		variable SQL

		upvar $arr_name DATA

		switch -exact $cat_type {
			{C} -
			{S} {}
			default {
				OT_LogWrite WARN "Unknown obj category: '$cat_type'"
				tpSetVar NumCats 0
				return 0
			}
		}

		set res [exec_qry "spec_cats_$cat_type" $id]

		set cols [db_get_colnames $res]

		set DATA(num_cats) [set n_rows [db_get_nrows $res]]

		for {set i 0} {$i < $n_rows} {incr i} {
			foreach f $cols {
				set DATA($i,$f) [db_get_col $res $i $f]
			}
			set DATA($i,sel_html) [expr {($DATA($i,selected)) ? {checked} : {}}]
		}
		db_close $res

		tpSetVar  NumCats     $n_rows
		tpBindVar CatId       $arr_name cat_id   cat_idx
		tpBindVar CatName     $arr_name name     cat_idx
		tpBindVar CatSelected $arr_name selected cat_idx
		tpBindVar CatSel      $arr_name sel_html cat_idx

		return 1
	}

	proc update_selected_categories {id cat_type new_ids} {

		global DB
		variable SQL

		if [bind_categories $cat_type $id DATA] {

			set ins_stmt [inf_prep_sql $DB $SQL(ins_cat_link_$cat_type)]
			set del_stmt [inf_prep_sql $DB $SQL(del_cat_link_$cat_type)]

			for {set i 0} {$i < $DATA(num_cats)} {incr i} {
				set cat_id   $DATA($i,cat_id)
				set selected $DATA($i,selected)

				# is this id one that should be selected...
				set needed [expr {[lsearch $new_ids $cat_id] != -1}]

				OT_LogWrite DEBUG "needed=$needed; selected=$selected"

				if {$needed && !$selected} {
					# insert...
					set res [inf_exec_stmt $ins_stmt $id $cat_id]
					db_close $res
				} elseif {!$needed && $selected} {
					# delete...
					set res [inf_exec_stmt $del_stmt $id $cat_id]
					db_close $res
				} else {
					# do nothing...
				}
			}

			inf_close_stmt $ins_stmt
			inf_close_stmt $del_stmt

			return 1
		}
		return 0
	}

	proc go_obj_categories {} {

		global DB CATS
		variable SQL

		set cat_type [reqGetArg cat_type]
		switch -exact $cat_type {
			{C} {
				tpBindString TITLE {Customer Categories}
			}
			{S} {
				tpBindString TITLE {Selection Categories}
			}
			default {
				OT_LogWrite WARN "Unknown obj category: '$cat_type'"
				err_add "Unknown obj category: '$cat_type'"
				asPlayFile -nocache obj_categories.html
				return
			}
		}

		set res [exec_qry "all_cats_$cat_type"]

		set cols [db_get_colnames $res]

		set CATS(num_cats) [set n_rows [db_get_nrows $res]]

		for {set i 0} {$i < $n_rows} {incr i} {
			foreach f $cols {
				set CATS($i,$f) [db_get_col $res $i $f]
			}
		}
		db_close $res

		tpBindString CAT_TYPE $cat_type

		tpSetVar NUM_CATS $CATS(num_cats)
		foreach col $cols {
			tpBindVar [string toupper $col] CATS $col cats_idx
		}

		asPlayFile -nocache obj_categories.html

		unset CATS
	}

	proc go_obj_category {} {

		set cat_type   [reqGetArg cat_type]
		set cat_id     [reqGetArg cat_id]
		set SubmitName [reqGetArg SubmitName]

		switch -exact $cat_type {
			{C} {
				tpBindString TITLE {Customer Category}
			}
			{S} {
				tpBindString TITLE {Selection Category}
			}
			default {
				OT_LogWrite WARN "Unknown obj category: '$cat_type'"
				err_add "Unknown obj category: '$cat_type'"
				asPlayFile -nocache obj_category.html
				return
			}
		}

		tpBindString CAT_TYPE $cat_type
		tpBindString CAT_ID   $cat_id

		switch -exact $SubmitName {
			{ObjCatAdd} {
				sel_obj_category $cat_type ""
			}
			{ObjCatIns} {
				ins_obj_category $cat_type
			}
			{ObjCatUpd} {
				upd_obj_category $cat_type $cat_id
			}
			{ObjCatIns} {
				ins_obj_category $cat_type
			}
			{ObjCatDel} {
				del_obj_category $cat_type $cat_id
			}
			{ObjCatBack} {
				go_obj_categories
			}
			default {
				sel_obj_category $cat_type $cat_id
			}
		}
	}

	proc sel_obj_category {cat_type cat_id} {

		tpBindString CAT_TYPE $cat_type
		tpSetVar CAT_ID $cat_id

		if {$cat_id != ""} {

			set res [exec_qry "get_cat_$cat_type" $cat_id]

			if {[db_get_nrows $res] == 1} {
				set cols [db_get_colnames $res]
				foreach f $cols {
					tpBindString [string toupper $f] [db_get_col $res 0 $f]
				}
			} else {
				OT_LogWrite ERROR "Wrong number of rows: [db_get_nrows $res]"
				err_add "Wrong number of rows: [db_get_nrows $res]"
			}
			db_close $res
		}

		asPlayFile -nocache obj_category.html
	}

	proc ins_obj_category {cat_type} {

		set name [reqGetArg name]
		set desc [reqGetArg desc]

		tpBindString NAME $name
		tpBindString DESC $desc

		if {$name == ""} {
			OT_LogWrite DEBUG "Empty name field"
			err_add "Empty name field"
			asPlayFile -nocache obj_category.html
		} else {

			set res [exec_qry "ins_cat_$cat_type" $name $desc]
			catch {db_close $res}
			go_obj_categories
		}
	}

	proc del_obj_category {cat_type cat_id} {

		if {$cat_id == ""} {
			OT_LogWrite DEBUG "No category id"
			err_add "No category id"
			go_obj_categories
		} else {

			set res [exec_qry "del_cat_$cat_type" $cat_id]
			catch {db_close $res}
			go_obj_categories
		}
	}

	proc upd_obj_category {cat_type cat_id} {

		set name [reqGetArg name]
		set desc [reqGetArg desc]

		tpBindString NAME $name
		tpBindString DESC $desc

		if {$cat_id == ""} {
			OT_LogWrite DEBUG "No category id"
			err_add "No category id"
			go_obj_categories

		} elseif {$name == ""} {
			OT_LogWrite DEBUG "Empty name field"
			err_add "Empty name field"
			asPlayFile -nocache obj_category.html

		} else {

			set res [exec_qry "upd_cat_$cat_type" $name $desc $cat_id]
			catch {db_close $res}
			go_obj_categories
		}
	}

} ; # end namespace

# initialise...
ADMIN::OBJ_CATEGORY::init
