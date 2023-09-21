# ==============================================================
# $Id: commentary.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::COMM {

asSetAct ADMIN::COMM::GoCommentaryList [namespace code go_commentary_list]
asSetAct ADMIN::COMM::GoCommentary     [namespace code go_commentary]
asSetAct ADMIN::COMM::DoCommentary     [namespace code do_commentary]
asSetAct ADMIN::COMM::ClearCommentary  [namespace code do_commentary_clear]

variable SQL

set SQL(get_ev_info) {
	select
		e.ev_id,
		e.ev_type_id,
		e.ev_class_id,
		e.desc as ev_name,
		t.name as type_name,
		cl.name as class_name
	from
		tEv e,
		tEvType t,
		tEvClass cl
	where
		e.ev_id         = ? and
		e.ev_type_id    = t.ev_type_id and
		e.ev_class_id   = cl.ev_class_id
}

set SQL(get_types) {
	select
		comment_type,
		desc,
		disporder
	from
		tBIRCommentType
	order by
		disporder
}

set SQL(get_commentary) {
	select
		c.comment_id,
		c.ev_id,
		c.comment_type,
		c.column1,
		c.column2,
		c.column3,
		c.image,
		c.disporder,
		e.ev_type_id,
		e.ev_class_id,
		e.desc as ev_name,
		t.name as type_name,
		cl.name as class_name
	from
		tBIRComment c,
		tEv e,
		tEvType t,
		tEvClass cl
	where
		c.comment_id    = ? and
		c.ev_id         = e.ev_id and
		e.ev_type_id    = t.ev_type_id and
		e.ev_class_id   = cl.ev_class_id
}

set SQL(get_commentary_list) {
	select
		c.comment_id,
		c.created,
		c.ev_id,
		c.comment_type,
		c.column1,
		c.column2,
		c.column3,
		c.image,
		c.disporder,
		e.ev_type_id,
		e.ev_class_id,
		e.desc as ev_name,
		t.name as type_name,
		cl.name as class_name
	from
		tBIRComment c,
		tEv e,
		tEvType t,
		tEvClass cl
	where
		c.ev_id         = e.ev_id and
		e.ev_type_id    = t.ev_type_id and
		e.ev_class_id   = cl.ev_class_id
	order by class_name, type_name, ev_name, comment_type, created, c.disporder
}

set SQL(get_commentary_list_by_event) {
	select
		c.comment_id,
		c.created,
		c.ev_id,
		c.comment_type,
		c.column1,
		c.column2,
		c.column3,
		c.image,
		c.disporder,
		e.ev_type_id,
		e.ev_class_id,
		e.desc as ev_name,
		t.name as type_name,
		cl.name as class_name
	from
		tBIRComment c,
		tEv e,
		tEvType t,
		tEvClass cl
	where
		c.ev_id         = ? and
		c.ev_id         = e.ev_id and
		e.ev_type_id    = t.ev_type_id and
		e.ev_class_id   = cl.ev_class_id
	order by class_name, type_name, ev_name, c.disporder, created, comment_type
}

set SQL(get_class_list) {
	select
			unique(eu.ev_class_id),
			cl.name,
			cl.disporder
	from
			tEvUnStl    eu,
			tEvClass    cl,
			tBIRComment bc
	where
			eu.ev_class_id = cl.ev_class_id and
			eu.ev_id = bc.ev_id
	order by
			cl.disporder, cl.name
}

set SQL(get_type_list) {
	select
		unique(eu.ev_type_id),
		t.name,
		t.disporder
	from
		tEvUnStl    eu,
		tEvType     t,
		tBIRComment bc
	where
		eu.ev_class_id  = ? and
		eu.ev_type_id   = t.ev_type_id and
		eu.ev_id = bc.ev_id
	order by
		t.disporder, t.name
}

# Gets the current period for version 1 commentary
set SQL(get_curr_period_v1) {
	select first 1
		c.comment_type
	from
		tBIRComment     c
	where
		ev_id      =    ?
	order by
		comment_id      desc
}

set SQL(get_event_list) {
	select
		unique(e.ev_id),
		e.desc,
		e.disporder
	from
		tEvUnStl    eu,
		tBIRComment bc,
		tEv         e
	where
		eu.ev_class_id  = ? and
		eu.ev_type_id   = ? and
		eu.ev_id = bc.ev_id and
		e.ev_id = eu.ev_id
	order by
		e.disporder, e.desc
}

set SQL(get_clear_commentary_log) {
	select
		au.username,
		cl.cr_date,
		cl.ev_id
	from
		tComClearLog cl,
		tAdminUser au
	where
		cl.oper_id = au.user_id and
		cl.cr_date < (current year to second) and
		cl.cr_date >= (current year to second) - (interval (30) day to day)
}

#
# ----------------------------------------------------------------------------
# Go to Commentary list
# ----------------------------------------------------------------------------
#
proc go_commentary_list args {

	global DB COMMENTARY CLASS_LIST TYPE_LIST EVENT_LIST CLEAR_LOG
	variable SQL

	# Get the class, type and event we should be displaying
	set ev_id     [reqGetArg event]
	set type_id   [reqGetArg type]
	set class_id  [reqGetArg class]

	# Build up the class list
	set stmt [inf_prep_sql $DB $SQL(get_class_list)]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# If a class isn't selected, default to the first one available
	# If none are available, default to -1 for the type list
	if {$class_id == ""} {
		if {[db_get_nrows $res] > 0} {
			set class_id  [db_get_col $res 0 ev_class_id]
		} else {
			set class_id -1
		}
	}

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set CLASS_LIST($i,ev_class_id)   [db_get_col $res $i ev_class_id]
		set CLASS_LIST($i,name)          [db_get_col $res $i name]

		if {[db_get_col $res $i ev_class_id] == $class_id} {
			set CLASS_LIST($i,selected)    {selected="selected"}
		} else {
			set CLASS_LIST($i,selected)    {}
		}
	}

	tpSetVar NumClasses [db_get_nrows $res]

	db_close $res


	# Build up the type list (the class_id should be something meaningful by now)
	set stmt [inf_prep_sql $DB $SQL(get_type_list)]
	set res [inf_exec_stmt $stmt $class_id]
	inf_close_stmt $stmt

	# If a type isn't selected, default to the first one available
	# If none are available, default to -1 for the event list
	if {$type_id == ""} {
		if {[db_get_nrows $res] > 0} {
			set type_id  [db_get_col $res 0 ev_type_id]
		} else {
			set type_id -1
		}
	}

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set TYPE_LIST($i,ev_type_id)    [db_get_col $res $i ev_type_id]
		set TYPE_LIST($i,name)          [db_get_col $res $i name]

		if {[db_get_col $res $i ev_type_id] == $type_id} {
			set TYPE_LIST($i,selected)    {selected="selected"}
		} else {
			set TYPE_LIST($i,selected)    {}
		}
	}

	tpSetVar NumTypes [db_get_nrows $res]

	db_close $res


	# Build up the event list (the class_id and type_id should be something
	# meaningful by now)
	set stmt [inf_prep_sql $DB $SQL(get_event_list)]
	set res [inf_exec_stmt $stmt $class_id $type_id]
	inf_close_stmt $stmt

	# If an event isn't selected, default to the first one available
	# If none are available, default to -1 for the event list
	if {$ev_id == ""} {
		if {[db_get_nrows $res] > 0} {
			set ev_id  [db_get_col $res 0 ev_id]
		} else {
			set ev_id -1
		}
	}

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set EVENT_LIST($i,ev_id)         [db_get_col $res $i ev_id]
		set EVENT_LIST($i,name)          [db_get_col $res $i desc]

		if {[db_get_col $res $i ev_id] == $ev_id} {
			set EVENT_LIST($i,selected)    {selected="selected"}
		} else {
			set EVENT_LIST($i,selected)    {}
		}
	}

	tpSetVar NumEvents [db_get_nrows $res]

	db_close $res


	# Get the event information
	set stmt [inf_prep_sql $DB $SQL(get_commentary_list_by_event)]
	set res  [inf_exec_stmt $stmt $ev_id]

	inf_close_stmt $stmt

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		foreach c {
			comment_id
			ev_id
			comment_type
			column1
			column2
			column3
			image
			disporder
			ev_type_id
			ev_class_id
			ev_name
			type_name
			class_name
		} {
			set COMMENTARY($i,$c) [db_get_col $res $i $c]
		}
	}

	tpSetVar NumComments [db_get_nrows $res]

	db_close $res
	
	# Get the clear commentary log information

	set stmt [inf_prep_sql $DB $SQL(get_clear_commentary_log)]
	set res [inf_exec_stmt $stmt]

	inf_close_stmt $stmt
	
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		foreach c {
			username
			cr_date
			ev_id
		} {
			set CLEAR_LOG($i,$c) [db_get_col $res $i $c]
		}
	}
	tpSetVar NumLogs [db_get_nrows $res]
	
	db_close $res
	
	
	# Bind up everything

	tpBindVar CommentId       COMMENTARY  comment_id      comment_idx
	tpBindVar EvClass         COMMENTARY  class_name      comment_idx
	tpBindVar EvClassId       COMMENTARY  ev_class_id     comment_idx
	tpBindVar EvType          COMMENTARY  type_name       comment_idx
	tpBindVar EvTypeId        COMMENTARY  ev_type_id      comment_idx
	tpBindVar Ev              COMMENTARY  ev_name         comment_idx
	tpBindVar EvId            COMMENTARY  ev_id           comment_idx
	tpBindVar CommentType     COMMENTARY  comment_type    comment_idx
	tpBindVar CommentCol1     COMMENTARY  column1         comment_idx
	tpBindVar CommentCol2     COMMENTARY  column2         comment_idx
	tpBindVar CommentCol3     COMMENTARY  column3         comment_idx
	tpBindVar Disporder       COMMENTARY  disporder       comment_idx

	tpBindVar CLASS_ID        CLASS_LIST  ev_class_id     class_idx
	tpBindVar CLASS_NAME      CLASS_LIST  name            class_idx
	tpBindVar CLASS_SELECTED  CLASS_LIST  selected        class_idx

	tpBindVar TYPE_ID         TYPE_LIST   ev_type_id      type_idx
	tpBindVar TYPE_NAME       TYPE_LIST   name            type_idx
	tpBindVar TYPE_SELECTED   TYPE_LIST   selected        type_idx

	tpBindVar EVENT_ID        EVENT_LIST  ev_id           event_idx
	tpBindVar EVENT_NAME      EVENT_LIST  name            event_idx
	tpBindVar EVENT_SELECTED  EVENT_LIST  selected        event_idx
	
	tpBindVar USERNAME         CLEAR_LOG   username       clear_log_idx
	tpBindVar C_DATE          CLEAR_LOG   cr_date         clear_log_idx
	tpBindVar EV_ID           CLEAR_LOG   ev_id           clear_log_idx
	tpBindString ShowEvId     $ev_id
	
	asPlayFile -nocache commentary_list.html
}


#
# ----------------------------------------------------------------------------
# Go to single tv channel add/update
# ----------------------------------------------------------------------------
#
proc go_commentary args {

	global DB COMMENTTYPE
	variable SQL

	set comment_id    [reqGetArg CommentId]
	set ev_id         [reqGetArg ShowEvId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString CommentId $comment_id
	set comment_type ""

	if {$comment_id == ""} {
		if {$ev_id != ""} {
			tpSetVar opAdd 1

			# Bind up class information
			set stmt [inf_prep_sql $DB $SQL(get_ev_info)]
			set res  [inf_exec_stmt $stmt $ev_id]

			inf_close_stmt $stmt

			tpBindString EvClass         [db_get_col $res 0 class_name]
			tpBindString EvClassId       [db_get_col $res 0 ev_class_id]
			tpBindString EvType          [db_get_col $res 0 type_name]
			tpBindString EvTypeId        [db_get_col $res 0 ev_type_id]
			tpBindString Ev              [db_get_col $res 0 ev_name]
			tpBindString EvId            [db_get_col $res 0 ev_id]

			db_close $res
		} else {
			# They shouldn't be here - return them to the commentary list
			ob::log::write INFO {Made it to go_commentary with no comment_id or ev_id - redirecting to list}
			go_commentary_list
			return
		}
	} else {

		tpSetVar opAdd 0

		#
		# Get information
		#
		set stmt [inf_prep_sql $DB $SQL(get_commentary)]
		set res  [inf_exec_stmt $stmt $comment_id]

		inf_close_stmt $stmt

		tpBindString CommentId       [db_get_col $res 0 comment_id]
		tpBindString EvClass         [db_get_col $res 0 class_name]
		tpBindString EvClassId       [db_get_col $res 0 ev_class_id]
		tpBindString EvType          [db_get_col $res 0 type_name]
		tpBindString EvTypeId        [db_get_col $res 0 ev_type_id]
		tpBindString Ev              [db_get_col $res 0 ev_name]
		tpBindString EvId            [db_get_col $res 0 ev_id]
		tpBindString CommentType     [db_get_col $res 0 comment_type]
		tpBindString CommentCol1     [db_get_col $res 0 column1]
		tpBindString CommentCol2     [db_get_col $res 0 column2]
		tpBindString CommentCol3     [db_get_col $res 0 column3]
		tpBindString CommentImage    [db_get_col $res 0 image]
		tpBindString Disporder       [db_get_col $res 0 disporder]

		set comment_type [db_get_col $res 0 comment_type]

		db_close $res
	}

	# Bind up the comment type information
	set stmt [inf_prep_sql $DB $SQL(get_types)]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set COMMENTTYPE($i,comment_type) [db_get_col $res $i comment_type]
		set COMMENTTYPE($i,desc)         [db_get_col $res $i desc]
		set COMMENTTYPE($i,disporder)    [db_get_col $res $i disporder]

		if {$comment_type == [db_get_col $res $i comment_type]} {
			set COMMENTTYPE($i,selected)   {selected="selected"}
		} else {
			set COMMENTTYPE($i,selected)   {}
		}
	}

	tpSetVar NumTypes [db_get_nrows $res]

	tpBindVar TypeName        COMMENTTYPE  comment_type     type_idx
	tpBindVar TypeDesc        COMMENTTYPE  desc             type_idx
	tpBindVar TypeSel         COMMENTTYPE  selected         type_idx

	db_close $res

	asPlayFile -nocache commentary.html
}


# ----------------------------------------------------------------------------
# Do TV Channel insert/update/delete
# ----------------------------------------------------------------------------
#
proc do_commentary args {

	global DB USERNAME
	variable SQL

	set act [reqGetArg SubmitName]

	if {$act == "CommentAdd" || $act == "CommentMod"} {
		set comment_type    [reqGetArg CommentType]
		set ev_id           [reqGetArg EvId]
		set current_period  ""

		set bad 0

		# We need to get the current period to check if this has changed.
		if {$comment_type != "GEN" && [OT_CfgGet POPULATE_COM_VER3_CLOCK 0]} {
			set stmt [inf_prep_sql $DB $SQL(get_curr_period_v1)]
			if {[catch {
				set res [inf_exec_stmt $stmt\
					$ev_id \
				]

				if {[db_get_nrows $res] == 1} {
					set current_period [db_get_coln $res 0 0]
				}

			} msg]} {
				inf_close_stmt $stmt
				err_bind $msg
				set bad 1
			}

			catch {db_close $res}
			inf_close_stmt $stmt

			if {$current_period != $comment_type} {
				_update_com_clock $ev_id $current_period $comment_type 1
			}
		}

		if {$bad} {
                	for {set a 0} {$a < [reqGetNumVals]} {incr a} {
                        	tpBindString [reqGetNthName $a] [reqGetNthVal $a]
                	}
                	go_commentary
                	return
	        }
	}


	if {$act == "CommentAdd"} {
		do_commentary_add
	} elseif {$act == "CommentMod"} {
		do_commentary_upd
	} elseif {$act == "CommentDel"} {
		do_commentary_del
	} elseif {$act == "Back"} {
		go_commentary_list
		return
	} elseif {$act == "ChangeLang"} {
		go_commentary
		return
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_commentary_add args {

	global DB USERNAME
	variable SQL

	set comment_type    [reqGetArg CommentType]
	set ev_id           [reqGetArg EvId]
	set current_period  ""

	set sql [subst {
			execute procedure pInsBIRComment(
			p_adminuser       = ?,
			p_ev_id           = ?,
			p_comment_type    = ?,
			p_column1         = ?,
			p_column2         = ?,
			p_column3         = ?,
			p_image           = ?,
			p_disporder       = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$ev_id\
			$comment_type\
			[reqGetArg CommentCol1]\
			[reqGetArg CommentCol2]\
			[reqGetArg CommentCol3]\
			[reqGetArg CommentImage]\
			[reqGetArg Disporder]\
		]

		set channel_id [db_get_coln $res 0 0]
		reqSetArg channel_id $channel_id
	} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt

	catch {db_close $res}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			go_commentary
			return
		}
	}

	go_commentary_list
}


proc do_commentary_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdBIRComment(
			p_adminuser       = ?,
			p_comment_id      = ?,
			p_ev_id           = ?,
			p_comment_type    = ?,
			p_column1         = ?,
			p_column2         = ?,
			p_column3         = ?,
			p_image           = ?,
			p_disporder       = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CommentId]\
			[reqGetArg EvId]\
			[reqGetArg CommentType]\
			[reqGetArg CommentCol1]\
			[reqGetArg CommentCol2]\
			[reqGetArg CommentCol3]\
			[reqGetArg CommentImage]\
			[reqGetArg Disporder]\
		]
	} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_commentary
		return
	}

	go_commentary_list
}

proc do_commentary_clear args {
	global DB USERID
	
	set sql {
		execute procedure pClrCommentary(
			p_ev_id = ?,
			p_oper_id = ?
		)
	}
	
	set stmt [inf_prep_sql $DB $sql]

	set bad 0
	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg EvId] $USERID]} msg]} {
		err_bind $msg
		OT_LogWrite INFO "::do_commentary_clear Failed to clear the commentary. Reason : $msg"
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	tpBindString EvId    [reqGetArg EvId]
	msg_bind "The Log was cleared succesfully"

	ADMIN::EVENT::go_ev_upd
	
}

proc do_commentary_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelBIRComment(
			p_adminuser     = ?,
			p_comment_id    = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CommentId]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_commentary
		return
	}

	go_commentary_list
}


# Calculate what updates are required to the clock to go into tComClockState
proc _update_com_clock {ev_id current_period new_period {is_old_style 0}} {


	array set period_map [OT_CfgGet MAP_COM_PERIODS ""]

	set period_code ""
	set new_time    "00:00:00"
	set operation   "S"
	# Do we need to call the Stored Proc
	set do_upd       0

	if {[info exists period_map($new_period)]} {
		set period_code $period_map($new_period)
	}

	switch -- $new_period  {
		"NS" {
			set do_upd 1
		}
		"ST" -
		"1HALF" {
			# This will cause the clock to default to 0
			# and the status of 'ns' and status of S
			set operation "C"
			set do_upd 1
		}
		"1HFE80" {
			# Adjust the clock time first
			set new_time "01:30:00"
			_adj_com_clock  $ev_id $period_code $new_time "A"
			set operation "C"
			set do_upd 1
		}
		"HALFT" {
			set operation "S"
			set do_upd 1
		}
		"2HALF" {
			set operation "C"
			set do_upd 1
		}
		"XTIME"  {
			# Adjust the clock time
			set new_time "1:45:00"
			_adj_com_clock  $ev_id $period_code $new_time "A"
			set operation "C"

			set do_upd 1
		}
		"SO" {
			# Adjust the clock time
			set new_time "2:00:00"
			_adj_com_clock  $ev_id $new_period $new_time "A"
			set operation "S"
			set do_upd 1
		}
		"FINISH" {
			set operation "S"
			set do_upd 1
		}
		"1SET" -
		"2SET" -
		"3SET" -
		"4SET" -
		"5SET" -
		"1QAR" -
		"2QAR" -
		"3QAR" -
		"4QAR" -
		"OT"   -
		"1PER" -
		"2PER" -
		"3PER" -
		"1HF80" {
			set operation "O"
			set do_upd 1
		}

	}

	# Force clock updates for commentary v1
	if {$is_old_style} {
		set operation "O"
	}

	if {!$do_upd} {
		return 0;
	}

	_adj_com_clock $ev_id $new_period $new_time $operation

	return 1
}

# Adjust the actual clock
proc _adj_com_clock {ev_id period_code new_time operation} {

	global DB

	set sql {
		execute procedure pUpdComClock(
			p_ev_id       = ?,
			p_period_code = ?,
			p_new_time    = ?,
			p_operation   = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {

		set res [inf_exec_stmt $stmt\
			$ev_id\
			$period_code\
			$new_time\
			$operation\
		]
	} msg]} {
		inf_close_stmt $stmt
		err_bind $msg
		return 0
	}


	catch {db_close $res}
	inf_close_stmt $stmt
}

}
