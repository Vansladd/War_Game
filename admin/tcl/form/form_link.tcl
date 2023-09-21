# ==============================================================
# $Id: form_link.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


##
# DESCRIPTION
#
#	Provides handlers and function to assist in making links between form and normal events.
##
namespace eval ADMIN::FORM {
	namespace export go_type_links
	namespace export do_make_type_link

	# create linking page
	asSetAct ADMIN::FORM::GoTypeLinks		[namespace code go_type_links]
	asSetAct ADMIN::FORM::DoMakeTypeLink	[namespace code do_make_type_link]
}

##
# DESCRIPTION
#
#	Goes to the form type link makes
##
proc ADMIN::FORM::go_type_links {} {

	set default_form_provider_id [make_form_feed_provider_binds]

	set form_provider_id [reqGetArg FormProviderId]

	if {$form_provider_id == ""} {
		set form_provider_id $default_form_provider_id
	}
	
	bind_type_links $form_provider_id [reqGetArg ev_type_id_form] [reqGetArg ev_type_id_norm]
	
	asPlayFile "form/form_type_link.html"
}

##
# DESCRIPTION
#
#	Binds variables for displaying form type links.
##
proc ADMIN::FORM::bind_type_links {form_provider_id ev_type_id_form ev_type_id_norm} {
	global TYPE_FORM TYPE_NORM

	catch {unset TYPE_FORM}
	catch {unset TYPE_NORM}

	if {![string is integer $ev_type_id_form] || ![string is integer $ev_type_id_norm]} {
		error "Invalid arguments: both Form and normal type ids must be integers or empty."
	}

	if {[catch {

		if {![op_allowed CanMakeFormLink]} {
			error "You do not have access privileges for Form linking"
		}

		tpBindString SELECTED_EV_TYPE_ID_FORM $ev_type_id_form
		tpBindString SELECTED_EV_TYPE_ID_NORM $ev_type_id_norm
		tpBindString SELECTED_FORM_PROVIDER_ID $form_provider_id

		set sql {
			select
				t.ev_type_id,
				m.course_id,
				c.name||": "||t.name name,
			    m.name form_name,
				case when m.course_id is not null then 1 else 0 end is_form,
				case when m.course_id is not null then 1 else 0 end has_link_to_norm
			from
				tEvClass		c,
				tEvType			t,
			outer
				tFormCourse		m
			where
				c.ev_class_id	= t.ev_class_id
			and m.ev_type_id	= t.ev_type_id
			and m.form_provider_id = ?

			union all

			select
				-1 ev_type_id,
				m.course_id,
				"" name,
				m.name form_name,
				1 is_form,
				0 has_link_to_norm
			from 
				tFormCourse m
			where
				m.ev_type_id is null and
				m.form_provider_id = ?

			order by
				is_form, 3, 4;
		}

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt $form_provider_id $form_provider_id]

		set nrows	[db_get_nrows $rs]

		set n_form	0
		set n_norm	0

		for {set r 0} {$r < $nrows} {incr r} {
			foreach col {ev_type_id name is_form has_link_to_norm form_name course_id} {
				set $col	[db_get_col $rs $r $col]
				#ob::log::write DEBUG "$r row: $col is [set $col]"
   			}

			if {$is_form} {
				set TYPE_FORM($n_form,ev_type_id)	$course_id
				set TYPE_FORM($n_form,name)			"$form_name [expr {$has_link_to_norm?" -> $name":""}]"
				incr n_form
			} else {
				set TYPE_NORM($n_norm,ev_type_id)	$ev_type_id
				set TYPE_NORM($n_norm,name)			$name
				incr n_norm
			}
		}
		db_close $rs
		unset sql stmt rs nrows

		tpBindVar EV_TYPE_ID_FORM	TYPE_FORM ev_type_id	idx
		tpBindVar NAME_FORM			TYPE_FORM name			idx
		tpSetVar num_type_form $n_form

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
#	Makes a link between the specified form and normal events.
##
proc ADMIN::FORM::do_make_type_link {} {
	switch -- [reqGetArg submit] {
		"Link/Unlink" {
			make_type_link [reqGetArg ev_type_id_form] [reqGetArg ev_type_id_norm]
			go_type_links
		}
		"View Audit History" {
			go_type_audit [reqGetArg ev_type_id_form]
		}
		"Generate" {
			make_all_links [reqGetArg ev_type_id_form]
			go_type_links
		}
	}
}

##
# DESCRIPTION
#
#	Make the type link.
##
proc ADMIN::FORM::make_type_link {ev_type_id_form ev_type_id_norm} {
	OT_LogWrite 12 "==>[info level [info level]]"

	if {[catch {
		if {![string is integer -strict $ev_type_id_form]} {
			error "Invalid arguments: You must have a valid Form course selected."
		}

		if {![op_allowed CanMakeFormLink]} {
			error "You do not have access privileges for Form linking."
		}

		set sql {select ev_type_id from tFormCourse where course_id = ?;}
		set stmt	[inf_prep_sql $::DB $sql]
		set	rs		[inf_exec_stmt $stmt $ev_type_id_form $ev_type_id_norm]
		set nrows	[db_get_nrows $rs]

		if {[db_get_col $rs 0 ev_type_id] == ""} {
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
				set sql {update tFormCourse set ev_type_id = ? where course_id = ?;}
				set stmt	[inf_prep_sql $::DB $sql]
				inf_exec_stmt $stmt $ev_type_id_norm $ev_type_id_form
				ob::log::write DEBUG "RAN: update tFormCourse set ev_type_id = $ev_type_id_form where course_id = $ev_type_id_norm"
			}
			UNLINK {
				set sql {update tFormCourse set ev_type_id = null where course_id = ?;}
				set stmt	[inf_prep_sql $::DB $sql]
				inf_exec_stmt $stmt $ev_type_id_form
				ob::log::write DEBUG "RAN: update tFormCourse set ev_type_id = null where course_id = $ev_type_id_form"
			}
		}

		# success!!
		switch -exact $mode {
			LINK {
				msg_bind "Linked form course ($ev_type_id_form) to normal event type ($ev_type_id_norm)."
			}
			UNLINK {
				msg_bind "Un-linked Form course ($ev_type_id_form) from normal event types"
			}
		}
	} msg]} {
		switch -glob $msg {
			"*23000 Unique constraint*" {
				err_bind "Only one linking of Form course to normal type may exist for any individual Form course or normal type."
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
proc ADMIN::FORM::make_all_links {ev_type_id_form} {

	global USERNAME

	OT_LogWrite 12 "==>[info level [info level]]"

	if {[catch {
		if {![string is integer -strict $ev_type_id_form]} {
			error "Invalid arguments: You must have a valid Form course selected."
		}

		if {![op_allowed CanMakeFormLink]} {
			error "You do not have access privileges for Form feed linking."
		}

		set sql {execute procedure pFormLinkCourse (p_adminuser = ?,p_course_id = ?);}
		set stmt	[inf_prep_sql $::DB $sql]
		OT_LogWrite 1 "ev_type_id_form = $ev_type_id_form"
		set	rs		[inf_exec_stmt $stmt $USERNAME $ev_type_id_form]
		set nrows	[db_get_nrows $rs]

		if { $nrows != 1} {
			error "Expected 1 row from pFormGenerateLinks"
		}

		if {[db_get_coln $rs 0 0] == -1} {
			error "Failed to generate links, course is unlinked to ev type"
		}

		db_close $rs

		msg_bind "Linked all events and selections under this Form course (id: $ev_type_id_form)"
		
	} msg]} {
		err_bind $msg
	}
}

##
# DESCRIPTION
#
#	Make the type link.
##
proc ADMIN::FORM::go_type_audit {ev_type_id_form} {
	OT_LogWrite 12 "==>[info level [info level]]"

	if {[catch {
		if {![string is integer -strict $ev_type_id_form]} {
			error "Invalid arguments: the form type must be an integer."
		}
		reqSetArg AuditInfo FormCourse
		ADMIN::AUDIT::go_audit
	} msg]} {
		err_bind $msg
		go_type_links
	}
}
