# ==============================================================
# $Id: teamtalk_link.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


##
# DESCRIPTION
#
#	Provides handlers and function to assist in making links between teamtalk and normal events.
##
namespace eval ADMIN::TEAMTALK {
	namespace export go_type_links
	namespace export do_make_type_link

	# create tote linking page
	asSetAct ADMIN::TEAMTALK::GoTypeLinks		[namespace code go_type_links]
	asSetAct ADMIN::TEAMTALK::DoMakeTypeLink	[namespace code do_make_type_link]
}

##
# DESCRIPTION
#
#	Goes to the teamtalk type link makes
##
proc ADMIN::TEAMTALK::go_type_links {} {
	bind_type_links [reqGetArg ev_type_id_teamtalk] [reqGetArg ev_type_id_norm]
	asPlayFile "teamtalk_type_link.html"
}

##
# DESCRIPTION
#
#	Binds variables for displaying teamtalk type links.
##
proc ADMIN::TEAMTALK::bind_type_links {ev_type_id_teamtalk ev_type_id_norm} {
	global TYPE_TEAMTALK TYPE_NORM

	catch {unset TYPE_TEAMTALK}
	catch {unset TYPE_NORM}

	if {![string is integer $ev_type_id_teamtalk] || ![string is integer $ev_type_id_norm]} {
		error "Invalid arguments: both Teamtalk and normal type ids must be integers or empty."
	}

	if {[catch {

		if {![op_allowed CanMakeTeamtalkLink]} {
			error "You do not have access privileges for Teamtalk linking"
		}

		tpBindString SELECTED_EV_TYPE_ID_TEAMTALK $ev_type_id_teamtalk
		tpBindString SELECTED_EV_TYPE_ID_NORM $ev_type_id_norm

		set sql {
			select
				t.ev_type_id,
				m.course_id,
				c.name||": "||t.name name,
			    m.name tt_name,
				case when m.course_id is not null then 1 else 0 end is_teamtalk,
				case when m.course_id is not null then 1 else 0 end has_link_to_norm
			from
				tEvClass		c,
				tEvType			t,
			outer
				tTeamtalkCourse		m
			where
				c.ev_class_id	= t.ev_class_id
			and m.ob_type_id	= t.ev_type_id

			union all

			select
				-1 ev_type_id,
				m.course_id,
				"" name,
				m.name tt_name,
				1 is_teamtalk,
				0 has_link_to_norm
			from 
				tTeamtalkCourse m
			where
				m.ob_type_id is null

			order by
				is_teamtalk, 3, 4;
		}

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt]

		set nrows	[db_get_nrows $rs]

		set n_teamtalk	0
		set n_norm	0

		for {set r 0} {$r < $nrows} {incr r} {
			foreach col {ev_type_id name is_teamtalk has_link_to_norm tt_name course_id} {
				set $col	[db_get_col $rs $r $col]
				#ob::log::write DEBUG "$r row: $col is [set $col]"
   			}

			if {$is_teamtalk} {
				set TYPE_TEAMTALK($n_teamtalk,ev_type_id)	$course_id
				set TYPE_TEAMTALK($n_teamtalk,name)			"$tt_name [expr {$has_link_to_norm?" -> $name":""}]"
				incr n_teamtalk
			} else {
				set TYPE_NORM($n_norm,ev_type_id)	$ev_type_id
				set TYPE_NORM($n_norm,name)			$name
				incr n_norm
			}
		}
		db_close $rs
		unset sql stmt rs nrows

		tpBindVar EV_TYPE_ID_TEAMTALK	TYPE_TEAMTALK ev_type_id	idx
		tpBindVar NAME_TEAMTALK			TYPE_TEAMTALK name			idx
		tpSetVar num_type_teamtalk $n_teamtalk

		tpBindVar EV_TYPE_ID_NORM 	TYPE_NORM ev_type_id	idx
		tpBindVar NAME_NORM			TYPE_NORM name			idx
		tpSetVar num_type_norm $n_norm
	} msg]} {
		err_bind $msg
	}
}

##
# DESCRIPTION
#
#	Makes a link between the specified teamtalk and normal events.
##
proc ADMIN::TEAMTALK::do_make_type_link {} {
	switch -- [reqGetArg submit] {
		"Link/Unlink" {
			make_type_link [reqGetArg ev_type_id_teamtalk] [reqGetArg ev_type_id_norm]
			go_type_links
		}
		"View Audit History" {
			go_type_audit [reqGetArg ev_type_id_teamtalk]
		}
		"Generate" {
			make_all_links [reqGetArg ev_type_id_teamtalk]
			go_type_links
		}
	}
}

##
# DESCRIPTION
#
#	Make the type link.
##
proc ADMIN::TEAMTALK::make_type_link {ev_type_id_teamtalk ev_type_id_norm} {
	OT_LogWrite 12 "==>[info level [info level]]"

	if {[catch {
		if {![string is integer -strict $ev_type_id_teamtalk]} {
			error "Invalid arguments: You must have a valid Teamtalk course selected."
		}

		if {![op_allowed CanMakeTeamtalkLink]} {
			error "You do not have access privileges for Teamtalk linking."
		}

		set sql {select ob_type_id from tTeamtalkCourse where course_id = ?;}
		set stmt	[inf_prep_sql $::DB $sql]
		set	rs		[inf_exec_stmt $stmt $ev_type_id_teamtalk $ev_type_id_norm]
		set nrows	[db_get_nrows $rs]

		if {[db_get_col $rs 0 ob_type_id] == ""} {
			set mode LINK
		} else {
			set mode UNLINK
		}
		db_close $rs

		ob::log::write DEBUG "mode is set to: $mode"

		unset sql stmt rs nrows

		switch -exact $mode {
			LINK {
				if {![string is integer -strict $ev_type_id_norm]} {
					error "Invalid arguments: You must have a valid Normal event type selected"
				}		
				set sql {update tTeamtalkCourse set ob_type_id = ? where course_id = ?;}
				set stmt	[inf_prep_sql $::DB $sql]
				inf_exec_stmt $stmt $ev_type_id_norm $ev_type_id_teamtalk
				ob::log::write DEBUG "RAN: update tTeamtalkCourse set ob_type_id = $ev_type_id_teamtalk where course_id = $ev_type_id_norm"
			}
			UNLINK {
				set sql {update tTeamtalkCourse set ob_type_id = null where course_id = ?;}
				set stmt	[inf_prep_sql $::DB $sql]
				inf_exec_stmt $stmt $ev_type_id_teamtalk
				ob::log::write DEBUG "RAN: update tTeamtalkCourse set ob_type_id = null where course_id = $ev_type_id_teamtalk"
			}
		}

		# success!!
		switch -exact $mode {
			LINK {
				msg_bind "Linked teamtalk course ($ev_type_id_teamtalk) to normal event type ($ev_type_id_norm)."
			}
			UNLINK {
				msg_bind "Un-linked Teamtalk course ($ev_type_id_teamtalk) from normal event types"
			}
		}
	} msg]} {
		switch -glob $msg {
			"*23000 Unique constraint*" {
				err_bind "Only one linking of Teamtalk course to normal type may exist for any individual Teamtalk course or normal type."
			}
			* {
				err_bind $msg
			}
		}
	}
}

##
# DESCRIPTION
#
#	Uses our stored proc to generate all links at race and selection level
##
proc ADMIN::TEAMTALK::make_all_links {ev_type_id_teamtalk} {
	OT_LogWrite 12 "==>[info level [info level]]"

	if {[catch {
		if {![string is integer -strict $ev_type_id_teamtalk]} {
			error "Invalid arguments: You must have a valid Teamtalk course selected."
		}

		if {![op_allowed CanMakeTeamtalkLink]} {
			error "You do not have access privileges for Teamtalk linking."
		}

		set sql {execute procedure pTTFLink (p_tt_type_id = ?, p_ev_type_id = (select ob_type_id from tTeamtalkCourse where course_id = ?));}
		set stmt	[inf_prep_sql $::DB $sql]
		set	rs		[inf_exec_stmt $stmt $ev_type_id_teamtalk $ev_type_id_teamtalk]
		set nrows	[db_get_nrows $rs]
		db_close $rs

		msg_bind "Linked all events and selections under this Teamtalk course (id: $ev_type_id_teamtalk)"
		
	} msg]} {
		err_bind $msg
	}
}

##
# DESCRIPTION
#
#	Make the type link.
##
proc ADMIN::TEAMTALK::go_type_audit {ev_type_id_teamtalk} {
	OT_LogWrite 12 "==>[info level [info level]]"

	if {[catch {
		if {![string is integer -strict $ev_type_id_teamtalk]} {
			error "Invalid arguments: the teamtalk type must be an integer."
		}
		reqSetArg AuditInfo TeamtalkCourse
		ADMIN::AUDIT::go_audit
	} msg]} {
		err_bind $msg
		go_type_links
	}
}
