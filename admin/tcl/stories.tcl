# ==============================================================
# $Id: stories.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::STORIES {

asSetAct ADMIN::STORIES::go_story_list    [namespace code go_story_list]
asSetAct ADMIN::STORIES::go_top_story     [namespace code go_top_story]
asSetAct ADMIN::STORIES::go_upd_top_story [namespace code go_upd_top_story]
asSetAct ADMIN::STORIES::go_new_story     [namespace code go_new_story]

proc go_story_list {} {

	global STORIES DB

	set sql {
		select
			top_story_id,
			s.story_id,
			t.ev_class_id,
			disporder,
			displayed,
			id_level,
			id_key,
			cr_date,
			headline
		from
			tTopStory t,
			tStory    s
		where
			t.story_id = s.story_id
		order by
			ev_class_id,
			disporder
	}

	set sqlclasses {
		select
			ev_class_id,
			name
		from
			tevclass
		order by
			name
	}

	set stmt [inf_prep_sql $DB $sqlclasses]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set num_classes [db_get_nrows $rs]

	set CLASSES_MAP(num_classes) $num_classes

	for {set r 0} {$r < $num_classes} {incr r} {
		set CLASSES_MAP($r,name) [db_get_col $rs $r name]
		set CLASSES_MAP($r,id)   [db_get_col $rs $r ev_class_id]
	}
	db_close $rs

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows    $rs]
	set names [db_get_colnames $rs]

	set nclasses 0

	for {set i 0} {$i < $CLASSES_MAP(num_classes)} {incr i} {

		set cid      $CLASSES_MAP($i,id)
		set nstories 0

		for {set j 0} {$j < $nrows} {incr j} {

			set channels [db_get_col $rs $j ev_class_id]
			if {$cid!=$channels} {
				continue
			}
			set STORIES($j,used) 1

			foreach n $names {
				set STORIES($nclasses,$nstories,$n) [db_get_col $rs $j $n]
			}
			set STORIES($nclasses,$nstories,target)\
				[story_link_name [db_get_col $rs $j top_story_id]]

			incr nstories
		}

		if {$nstories > 0} {
			set STORIES($nclasses,name)        $CLASSES_MAP($i,name)
			set STORIES($nclasses,name_url)    [urlencode $CLASSES_MAP($i,name)]
			set STORIES($nclasses,num_stories) $nstories
			incr nclasses
		}
	}


	#
	# all the unreferenced stories are front page stories
	#
	set nstories 0

	for {set j 0} {$j < $nrows} {incr j} {

		if {[info exists STORIES($j,used)]} {
			continue
		}

		foreach n $names {
			set STORIES($nclasses,$nstories,$n) [db_get_col $rs $j $n]
		}
		set STORIES($nclasses,$nstories,target)\
			[story_link_name [db_get_col $rs $j top_story_id]]

		incr nstories
	}

	if {$nstories > 0} {
		set STORIES($nclasses,name)        "Front Page"
		set STORIES($nclasses,name_url)    "Front%20Page"
		set STORIES($nclasses,num_stories) $nstories
		incr nclasses
	}


	set STORIES(num_classes) $nclasses

	tpBindVar class          STORIES name          class_idx
	tpBindVar class_url      STORIES name_url      class_idx
	tpBindVar top_story_id   STORIES top_story_id  class_idx story_idx
	tpBindVar story_id       STORIES story_id      class_idx story_idx
	tpBindVar id_level       STORIES id_level      class_idx story_idx
	tpBindVar id_key         STORIES id_name       class_idx story_idx
	tpBindVar displayed      STORIES displayed     class_idx story_idx
	tpBindVar headline       STORIES headline      class_idx story_idx
	tpBindVar target         STORIES target      class_idx story_idx

	db_close $rs

	asPlayFile -nocache story_list.html

	unset STORIES
}


proc go_top_story {} {

	global DB

	set top_story_id [reqGetArg top_story_id]

	set sql [subst {
		select
			headline,
		 	id_key,
			id_level,
			story_text,
			keyword,
			disporder,
			displayed,
			t.ev_class_id
		from
			tTopStory t, tStory s
		where
			t.story_id = s.story_id and
			t.top_story_id = $top_story_id
	}]

	tpBindString top_story_id $top_story_id

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	foreach n [db_get_colnames $rs] {
		tpBindString $n [db_get_col $rs $n]
	}
	if {[db_get_col $rs displayed] == "N"} {
		tpBindString not_displayed selected
	}
	set ev_class_id [db_get_col $rs ev_class_id]

	db_close $rs

	tpBindString id_name [story_link_name $top_story_id]
	tpBindString ev_class_name [reqGetArg ev_class_name]

	tpBindString class_drop_down [story_class_drop_down $ev_class_id]

	tpSetVar Insert 0
	tpBindString story_action go_upd_story
	asPlayFile -nocache story.html
}


#
# Build up class drop down
#
proc story_class_drop_down {ev_class_id} {

	global DB

	set sqlclasses {
		select
			ev_class_id,
			name
		from
			tevclass
		order by
			name
	}

	set stmt [inf_prep_sql $DB $sqlclasses]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	set drop_down ""

	for {set r 0} {$r<$nrows} {incr r} {

		set id [db_get_col $rs $r ev_class_id]
		set name [db_get_col $rs $r name]
		append class_drop_down "<option value=\"$id\""
		if {$id == $ev_class_id} {
			append class_drop_down " SELECTED"
		}
		append class_drop_down ">$name</option>"
	}

	db_close $rs

	return $class_drop_down
}

proc go_new_story {} {

	tpSetVar Insert 1
	tpBindString ev_class_name "New Top News Story"
	tpBindString class_drop_down [story_class_drop_down -1]
	asPlayFile -nocache story.html
}




proc ins_top_story {} {

	global DB

	if {![op_allowed UpdStories]} {
		tpBindString Error "User does not have UpdateStories permission"
		go_story_list
	}

	set sql_story {
		insert into tStory (
			keyword,
			headline,
			story_text
		) values
			?,?,?
		)
	}

	set sql_top {
		insert into tTopStory (
			story_id,
			ev_class_id,
			disporder,
			displayed,
			id_level,
			id_key
		) values (
			?,?,?,?,?,?
		)
	}

	foreach a {
		keyword
		headline
		story_text
		disporder
		ev_class_id
		disporder
		displayed
		key
		level
		name
	} {
		set $a [reqGetArg $a]
	}

	if {$key == "" || $level == "" || $keyword == "" || $headline == ""} {
		foreach a {
			keyword
			headline
			story_text
			disporder
			ev_class_id
			disporder
			displayed
			key
			level
		} {
			tpBindString $a [reqGetArg $a]
		}
		tpBindString id_key $key
		tpBindString id_level $level
		tpBindString id_name $name
		go_new_story
		return 0
	}

	if {$disporder == ""} {
		set disporder 0
	}


	inf_begin_tran $DB

	if [catch {
		set stmt [inf_prep_sql $DB $sql_story]
		inf_exec_stmt $stmt $keyword $headline $story_text
		set story_id [inf_get_serial $stmt]
		inf_close_stmt $stmt
		set stmt [inf_prep_sql $DB $sql_top]
		inf_exec_stmt $stmt\
			$story_id $ev_class_id $disporder $displayed $level $key
		inf_close_stmt $stmt
	} msg] {
		inf_rollback_tran $DB
		OT_LogWrite 1 "Failed to insert new story: $msg"
		error $msg
		return
	}
	inf_commit_tran $DB

	return 1
}


proc go_upd_top_story {} {

	if {![op_allowed UpdStories]} {
		tpBindString Error "User does not have UpdateStories permission"
		go_story_list
	}

	switch -- [reqGetArg SubmitName] {
		Delete {
			set ret [del_top_story]
		}
		Update {
			set ret [upd_top_story]
		}
		Insert {
			if {![ins_top_story]} {
				return
			}
		}
	}

	go_story_list
}

proc upd_top_story {} {

	global DB

	set sql_top {
		update tTopStory set
			ev_class_id = ?,
			id_level  = ?,
			id_key    = ?,
			displayed = ?,
			disporder = ?
		where
			top_story_id   = ?
	}

	set sql_story {
		update tStory set
			keyword = ?,
			headline = ?,
			story_text = ?
		where
			story_id = (select story_id from ttopstory where top_story_id=?)
	}

	set key          [reqGetArg key]
	set level        [reqGetArg level]
	set ev_class_id  [reqGetArg ev_class_id]
	set displayed    [reqGetArg displayed]
	set keyword      [reqGetArg keyword]
	set headline     [reqGetArg headline]
	set story_text   [reqGetArg story_text]
	set top_story_id [reqGetArg top_story_id]
	set disporder    [reqGetArg disporder]

	inf_begin_tran $DB

	set stmt [inf_prep_sql $DB $sql_top]
	inf_exec_stmt $stmt\
		$ev_class_id $level $key $displayed $disporder $top_story_id
	inf_close_stmt $stmt

	set stmt [inf_prep_sql $DB $sql_story]
	inf_exec_stmt $stmt $keyword $headline $story_text $top_story_id
	inf_close_stmt $stmt

	inf_commit_tran $DB

	OT_LogWrite 5 "Done upd_top_story"

	return 1
}


proc del_top_story {} {

	global DB

	set top_story_id [reqGetArg top_story_id]

	set sql [subst {
		delete from
			tTopStory
		where
			top_story_id = $top_story_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt
	inf_close_stmt $stmt

	return 1
}


proc story_link_name {top_story_id} {

	global DB

	set top_story {
		select
			*
		from
			ttopstory
		where
			top_story_id = ?
	}

	set from_CLASS {
		select
			c.name as name
		from
			tEvClass c
		where
			c.ev_class_id=?
	}
	set from_TYPE {
		select
			t.name as name
		from
			tEvType t
		where
			t.ev_type_id=?
	}
	set from_EVENT {
		select
			e.desc as name
		from
		   tEv e
		where
		   e.ev_id=?
	}
	set from_MARKET {
		select
			g.name as name
		from
			tEvMkt m,
			tEvOcGrp g
		where
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.ev_mkt_id=?
	}
	set from_SELECTION {
		select
			desc name
		from
			tEvOc
		where
			ev_oc_id=?
	}

	set stmt [inf_prep_sql $DB $top_story]
	set rs [inf_exec_stmt $stmt $top_story_id]
	inf_close_stmt $stmt
	set id_level [db_get_col $rs 0 id_level]
	set id_key   [db_get_col $rs 0 id_key]
	db_close $rs

	if {$id_level!=""} {
		set stmt [inf_prep_sql $DB [set from_${id_level}]]
		set rs [inf_exec_stmt $stmt $id_key]
		inf_close_stmt $stmt
		set name [db_get_col $rs 0 name]
		db_close $rs
	} else {
		set name ""
	}

	return $name
}

}
