# $Id: tote.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
##
# DESCRIPTION
#
#	Provides handlers and function to assist in making links between tote and normal events.
##
namespace eval ADMIN::TOTE {
	namespace export go_type_links
	namespace export do_make_type_link

	namespace export go_ev_links
	namespace export do_make_ev_link

	# create tote linking page
	asSetAct ADMIN::TOTE::GoTypeLinks		[namespace code go_type_links]
	asSetAct ADMIN::TOTE::DoMakeTypeLink	[namespace code do_make_type_link]

	asSetAct ADMIN::TOTE::GoEvLinks			[namespace code go_ev_links]
	asSetAct ADMIN::TOTE::DoMakeEvLink		[namespace code do_make_ev_link]
}

##
# DESCRIPTION
#
#	Goes to the tote type link makes
##
proc ADMIN::TOTE::go_type_links {} {
	bind_type_links [reqGetArg ev_type_id_tote] [reqGetArg ev_type_id_norm]
	asPlayFile "tote_type_link.html"
}

##
# DESCRIPTION
#
#	Binds variables for displaying tote type links.
##
proc ADMIN::TOTE::bind_type_links {ev_type_id_tote ev_type_id_norm} {
	global TYPE_TOTE TYPE_NORM

	catch {unset TYPE_TOTE}
	catch {unset TYPE_NORM}

	if {![string is integer $ev_type_id_tote] || ![string is integer $ev_type_id_norm]} {
		error "Invalid arguments: both the tote and normal type ids must be integers or empty."
	}

	if {[catch {

		if {![op_allowed CanMakeToteLink]} {
			error "You do not have access privileges for the tote."
		}

		tpBindString SELECTED_EV_TYPE_ID_TOTE $ev_type_id_tote
		tpBindString SELECTED_EV_TYPE_ID_NORM $ev_type_id_norm

		set sql {
			select
				t.ev_type_id,
				c.name||": "||t.name name,
				case when m.level is not null then 1 else 0 end is_tote,
				case when l.ev_type_id_tote is not null and l.ev_type_id_norm = t.ev_type_id then 1 else 0 end has_link_to_tote,
				case when l.ev_type_id_norm is not null and l.ev_type_id_tote = t.ev_type_id then 1 else 0 end has_link_to_norm,
				c2.name||": "||t2.name norm_name
			from
				tEvClass		c,
				tEvType			t,
			outer
				tToteMap		m,
			outer
				(tToteTypeLink	l,
				tEvType			t2,
				tEvClass		c2)
			where
				c.ev_class_id	= t.ev_class_id
			and	m.level			= "TYPE"
			and	m.id			= t.ev_type_id
			and
				(t.ev_type_id	= l.ev_type_id_tote
			or
				t.ev_type_id	= l.ev_type_id_norm)
			and m.transient		= 0
			and l.ev_type_id_norm	= t2.ev_type_id
			and t2.ev_class_id		= c2.ev_class_id
			order by
				is_tote,
				2;
		}

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt]

		set nrows	[db_get_nrows $rs]

		set n_tote	0
		set n_norm	0

		for {set r 0} {$r < $nrows} {incr r} {
			foreach col {ev_type_id name is_tote has_link_to_tote has_link_to_norm norm_name} {
				set $col	[db_get_col $rs $r $col]
   			}

			if {$is_tote && $has_link_to_tote} {
				err_bind "The event type $ev_type_id is both a tote event and has a link to a tote, this is incosistent."
			}

			if {$is_tote} {
				set TYPE_TOTE($n_tote,ev_type_id)	$ev_type_id
				set TYPE_TOTE($n_tote,name)			"$name [expr {$has_link_to_norm?" -> $norm_name":""}]"
				incr n_tote
			} else {
				set TYPE_NORM($n_norm,ev_type_id)	$ev_type_id
				set TYPE_NORM($n_norm,name)			"$name[expr {$has_link_to_tote?" *":""}]"
				incr n_norm
			}
		}
		db_close $rs
		unset sql stmt rs nrows

		tpBindVar EV_TYPE_ID_TOTE	TYPE_TOTE ev_type_id	idx
		tpBindVar NAME_TOTE			TYPE_TOTE name			idx
		tpSetVar num_type_tote $n_tote

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
#	Makes a link between the specified tote and normal events.
##
proc ADMIN::TOTE::do_make_type_link {} {
	switch -- [reqGetArg submit] {
		"Link/Unlink" {
			make_type_link [reqGetArg ev_type_id_tote] [reqGetArg ev_type_id_norm]
			go_type_links
		}
		"View Audit History" {
			go_type_audit [reqGetArg ev_type_id_tote]
		}
	}
}

##
# DESCRIPTION
#
#	Make the type link.
##
proc ADMIN::TOTE::make_type_link {ev_type_id_tote ev_type_id_norm} {
	OT_LogWrite 12 "==>[info level [info level]]"

	if {[catch {
		if {![string is integer -strict $ev_type_id_tote] || ![string is integer -strict $ev_type_id_norm]} {
			error "Invalid arguments: both a tote type and a norm type ids must be integers."
		}

		if {![op_allowed CanMakeToteLink]} {
			error "You do not have access privileges for the tote."
		}

		set sql {select 1 from tToteTypeLink where ev_type_id_tote = ? and ev_type_id_norm = ?;}
		set stmt	[inf_prep_sql $::DB $sql]
		set	rs		[inf_exec_stmt $stmt $ev_type_id_tote $ev_type_id_norm]
		set nrows	[db_get_nrows $rs]
		db_close $rs

		if {$nrows == 0} {set mode LINK} else {set mode UNLINK}

		unset sql stmt rs nrows

		switch -exact $mode {
			LINK {
				set sql {insert into tToteTypeLink (ev_type_id_tote,ev_type_id_norm) values (?,?);}
			}
			UNLINK {
				set sql {delete from tToteTypeLink where ev_type_id_tote = ? and ev_type_id_norm = ?;}
			}
		}

		set stmt	[inf_prep_sql $::DB $sql]
		inf_exec_stmt $stmt $ev_type_id_tote $ev_type_id_norm

		# success!!
		switch -exact $mode {
			LINK {
				msg_bind "Linked tote event type ($ev_type_id_tote) to normal event type ($ev_type_id_norm)."
			}
			UNLINK {
				msg_bind "Un-linked tote event type ($ev_type_id_tote) from normal event type ($ev_type_id_norm)."
			}
		}
	} msg]} {
		switch -glob $msg {
			"*23000 Unique constraint*" {
				err_bind "Only one linking of tote type to normal type may exist for any individual tote or normal type."
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
#	Make the type link.
##
proc ADMIN::TOTE::go_type_audit {ev_type_id_tote} {
	OT_LogWrite 12 "==>[info level [info level]]"

	if {[catch {
		if {![string is integer -strict $ev_type_id_tote]} {
			error "Invalid arguments: the tote type must be an integer."
		}
		reqSetArg AuditInfo ToteTypeLink
		ADMIN::AUDIT::go_audit
	} msg]} {
		err_bind $msg
		go_type_links
	}
}


##
# DESCRIPTION
#
#	Plays the ev links page.
##
proc ADMIN::TOTE::go_ev_links {} {
	bind_ev_links [reqGetArg ev_id_tote] [reqGetArg ev_id_norm] [expr {[reqGetArg today_only]=="on"}] [expr {[reqGetArg unlinked_only]=="on"}] [expr {[reqGetArg create_selections]=="on"}]
	asPlayFile "tote_ev_link.html"
}

##
# DESCRIPTION
#
#	Binds the links between evs for playing.
##
proc ADMIN::TOTE::bind_ev_links {ev_id_tote ev_id_norm today_only unlinked_only create_selections} {
	global EV_TOTE EV_NORM

	OT_LogWrite 12 "==>[info level [info level]]"

	catch {unset EV_TOTE}
	catch {unset EV_NORM}

	if {![string is integer $ev_id_tote] || ![string is integer $ev_id_norm] || ![string is boolean $today_only] || ![string is boolean $unlinked_only] || ![string is boolean $create_selections]} {
		error "Invalid arguments: tote event and normal events ids must be integers or empty, today only, unlinked_only and create_selections must be boolean or empty."
	}

	if {[catch {
		if {![op_allowed CanMakeToteLink]} {
			error "You do not have access privileges for the tote."
		}

		tpBindString SELECTED_EV_ID_TOTE $ev_id_tote
		tpBindString SELECTED_EV_ID_NORM $ev_id_norm

		# firstly do the tote rows
		set sql [subst {
			select
				e.ev_id,
				c.name||": "||t.name||" ("||extend(e.start_time,year to minute)||")" tote_name,
				case when el.ev_id_tote is not null then 1 else 0 end has_ev_link,
				c2.name||": "||t2.name||" ("||extend(e2.start_time,year to minute)||")" norm_name
			from
				tEv				e,
				tEvType			t,
				tEvClass		c,
				tToteTypeLink	tl,
				tEvType			t2,
			outer
				(tToteEvLink	el,
				tEv				e2,
				tEvClass		c2)
			where
				e.ev_type_id		= t.ev_type_id
			and t.ev_class_id		= c.ev_class_id
			and	t.ev_type_id		= tl.ev_type_id_tote
			and tl.ev_type_id_norm	= t2.ev_type_id
			and e.ev_id				= el.ev_id_tote
			and	el.ev_id_norm		= e2.ev_id
			and t2.ev_class_id		= c2.ev_class_id
			[expr {$today_only?"and extend(e.start_time, year to day) = extend(CURRENT, year to day)":""}]
			order by
				tote_name;
		}]

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt]

		set nrows	[db_get_nrows $rs]

		set n_tote	0

		for {set r 0} {$r < $nrows} {incr r} {
			foreach col {ev_id has_ev_link tote_name norm_name} {
				set $col	[db_get_col $rs $r $col]
   			}

			if {!$unlinked_only || !$has_ev_link} {
				set EV_TOTE($n_tote,ev_id)		$ev_id
				set EV_TOTE($n_tote,name)		"$tote_name[expr {$has_ev_link?" -> $norm_name":""}]"
				incr n_tote
			}
		}
		db_close $rs

		unset sql stmt rs nrows

		tpBindVar EV_ID_TOTE		EV_TOTE ev_id	idx
		tpBindVar NAME_TOTE			EV_TOTE name	idx
		tpSetVar num_ev_tote $n_tote

		# for the normal

		set sql [subst {
			select
				e.ev_id,
				c.name||": "||t.name||" ("||extend(e.start_time,year to minute)||")" norm_name,
				case when el.ev_id_tote is not null then 1 else 0 end has_ev_link,
				c2.name||": "||t2.name||" ("||extend(e2.start_time,year to minute)||")" tote_name
			from
				tEv				e,
				tEvType			t,
				tEvClass		c,
				tToteTypeLink	tl,
				tEvType			t2,
			outer
				(tToteEvLink	el,
				tEv				e2,
				tEvClass		c2)
			where
				e.ev_type_id		= t.ev_type_id
			and	t.ev_class_id		= c.ev_class_id
			and	t.ev_type_id		= tl.ev_type_id_norm
			and tl.ev_type_id_tote	= t2.ev_type_id
			and e.ev_id				= el.ev_id_norm
			and	el.ev_id_norm		= e2.ev_id
			and t2.ev_class_id		= c2.ev_class_id
			[expr {$today_only?"and extend(e.start_time, year to day) = extend(CURRENT, year to day)":""}]
			order by
				norm_name;
		}]

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt]

		set nrows	[db_get_nrows $rs]

		set n_norm	0

		for {set r 0} {$r < $nrows} {incr r} {
			foreach col {ev_id has_ev_link tote_name norm_name} {
				set $col	[db_get_col $rs $r $col]
   			}

			if {!$unlinked_only || !$has_ev_link} {
				set EV_NORM($n_norm,ev_id)		$ev_id
				set EV_NORM($n_norm,name)		"$norm_name [expr {$has_ev_link?" -> $tote_name":""}]"
				incr n_norm
			}
		}
		db_close $rs

		unset sql stmt rs nrows

		tpBindVar EV_ID_NORM		EV_NORM ev_id	idx
		tpBindVar NAME_NORM			EV_NORM name	idx
		tpSetVar num_ev_norm $n_norm

	} msg]} {
		err_bind $msg
	}

	tpSetVar today_only		$today_only
	tpSetVar unlinked_only	$unlinked_only
	tpSetVar create_selections	$create_selections
}

##
# DESCRIPTION
#
#	Delegates the various options from making a link.
##
proc ADMIN::TOTE::do_make_ev_link {} {
	switch -exact [reqGetArg submit] {
		"Reload" {
			go_ev_links
		}
		"Link/Unlink" {
			if {[reqGetArg ev_id_tote] != "" && [reqGetArg ev_id_norm] != ""} {
				make_ev_link [reqGetArg ev_id_tote] [reqGetArg ev_id_norm]
			} else {
				err_bind "Please select both a tote and normal event."
			}
			go_ev_links
		}
		"Link automatically" {
			make_ev_links_automatically [expr {[reqGetArg today_only]=="on"}]
			go_ev_links
		}
		"Create Normal Events Automatically" {
			make_normal_events [expr {[reqGetArg today_only]=="on"}] [expr {[reqGetArg create_selections]=="on"}]
			go_ev_links
		}
		"View Audit History" {
			go_ev_audit [reqGetArg ev_id_tote]
		}
		default {
			error "The submit value '[reqGetArg submit]' is not known."
		}
	}
}

##
# DESCRIPTION
#
#	Makes a link between a tote and normal event.
##
proc ADMIN::TOTE::make_ev_link {ev_id_tote ev_id_norm} {
	OT_LogWrite 12 "==>[info level [info level]]"
	if {![string is integer -strict $ev_id_tote] || ![string is integer -strict $ev_id_norm]} {
		error "Invalid arguments: both a tote event and a norm event must be integers."
	}

	if {[catch {

		# check that the arguments are ok and valid permissions
		if {![op_allowed CanMakeToteLink]} {
			error "You do not have access privilages for the tote."
		}

		# decide wether it's a link or unlink operation
		set sql 	{select 1 from tToteEvLink where ev_id_tote = ? and ev_id_norm = ?;}
		set stmt	[inf_prep_sql $::DB $sql]
		set	rs		[inf_exec_stmt $stmt $ev_id_tote $ev_id_norm]
		set nrows	[db_get_nrows $rs]
		db_close $rs

		if {$nrows == 0} {set mode LINK} else {set mode UNLINK}

		unset sql stmt rs nrows

		set sql		{select
				1
			from
				tEv				et,
				tToteTypeLink	l,
				tEv				en
			where
				et.ev_type_id	= l.ev_type_id_tote
	 		and	en.ev_type_id	= l.ev_type_id_norm
			and	et.ev_id		= ?
			and en.ev_id		= ?
		}
		set stmt	[inf_prep_sql $::DB $sql]
		set	rs		[inf_exec_stmt $stmt $ev_id_tote $ev_id_norm]
		set nrows	[db_get_nrows $rs]
		db_close $rs

		if {$nrows == 0} {
			error "The events must be of the same type to link them."
		}

		unset sql stmt rs nrows

		# set the sql based of what operation it is
		switch -exact $mode {
			LINK {
				set sql {insert into tToteEvLink (ev_id_tote,ev_id_norm) values (?,?);}
			}
			UNLINK {
				set sql {delete from tToteEvLink where ev_id_tote = ? and ev_id_norm = ?;}
			}
		}

		set stmt	[inf_prep_sql $::DB $sql]
		inf_exec_stmt $stmt $ev_id_tote $ev_id_norm

		# success, set the message
		switch -exact $mode {
			LINK {
				msg_bind "Linked tote event $ev_id_tote to normal event $ev_id_norm."
			}
			UNLINK {
				msg_bind "Un-linked tote event $ev_id_tote from normal event $ev_id_norm."
			}
		}
	} msg]} {
		switch -glob $msg {
			"*23000 Unique constraint*" {
				err_bind "Only one linking of tote event to normal event may exist for any individual tote or normal event."
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
#	Attempts to automatically make links between events.
##
proc ADMIN::TOTE::make_ev_links_automatically {today_only} {
	OT_LogWrite 12 "==>[info level [info level]]"
	if {![string is boolean -strict $today_only]} {
		error "Invalid arguments: today_only must be a boolean."
	}

	if {[catch {
		if {![op_allowed CanMakeToteLink]} {
			error "You do not have access privilages for the tote."
		}
		set sql "
			select distinct
				e.ev_id,
				extend(e.start_time,year to minute)	start_time,
				case when el.ev_id_tote is not null then 1 else 0 end has_ev_link
			from
				tEv				e,
				tEvType			t,
				tToteTypeLink	tl,
			outer
				tToteEvLink		el
			where
				e.ev_type_id		= t.ev_type_id
			and	t.ev_type_id		= tl.ev_type_id_tote
			and e.ev_id				= el.ev_id_tote
			[expr {$today_only?"and extend(e.start_time, year to day) = extend(CURRENT, year to day)":""}]
			order by
				start_time;
			"

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt]
		set nrows	[db_get_nrows $rs]

		set success	[list]
		set failed	[list]
		set skipped	[list]

		for {set r 0} {$r < $nrows} {incr r} {
			foreach col {ev_id start_time has_ev_link} {
				set $col [db_get_col $rs $r $col]
			}
			# if no link already exists make the link
			if {!$has_ev_link} {
				if {[catch {
					set ev_id_norm	[ins_ev_link $ev_id $start_time]
					lappend success	[list $ev_id $start_time]
					OT_LogWrite 9 "ADMIN::TOTE::make_ev_links_automatically: Created link $ev_id,$start_time -> $ev_id_norm"
				} msg]} {
					lappend failed	[list $ev_id $start_time $msg]
					OT_LogWrite 9 "ADMIN::TOTE::make_ev_links_automatically: $msg"
				}
			} else {
				lappend skipped [list $ev_id $start_time]
				OT_LogWrite 9 "ADMIN::TOTE::make_ev_links_automatically: Skipped $ev_id,$start_time"
			}
		}
		db_close $rs

		unset rs stmt sql nrows

		msg_bind "Linked [llength $success] event(s), failed to link [llength $failed] event(s), skipped [llength $skipped] already linked event(s)."
	} msg]} {
		err_bind $msg
	}
}

##
# DESCRIPTION
#
#	This procedures attempts find and create a suitable link from the specified event.
#	This is achieved by looking for a type linking and creating the link based on the type
#	and start time.
#
#		NORMAL					TOTE
#
#		type	--	link	--	type		poolType
#		 |						 |
#		event	--	link	--	event		pool
#								 |
#								mkt		--	poolMkt
#
#	NOTE: This procedures is used by both tote/feed/client_db.tcl and openbet/admin/tcl/tote.tcl
##
proc ADMIN::TOTE::ins_ev_link {ev_id start_time} {
	if {![string is integer -strict $ev_id] || ![regexp {^\d\d\d\d-\d\d-\d\d \d\d:\d\d(:\d\d)?$} $start_time]} {
		error "Invalid arguments: the ev_id must be an integer and the start_time must be a informix date (year to minute)."
	}

	# look up the matching event
	set sql {
		select
			en.ev_id
		from
			tEv				en,
			tEvType			tn,
			tToteTypeLink	l,
			tEvType			tt,
			tEv				et
		where
			en.ev_type_id		= tn.ev_type_id
		and tn.ev_type_id		= l.ev_type_id_norm
		and l.ev_type_id_tote	= tt.ev_type_id
		and tt.ev_type_id		= et.ev_type_id
		and et.ev_id			= ?
		and extend(en.start_time, year to minute) = extend(?,year to minute);
	}

	set stmt	[inf_prep_sql $::DB $sql]

	set rs		[inf_exec_stmt $stmt $ev_id [string range $start_time 0 15]]
	set nrows	[db_get_nrows $rs]

	if {$nrows == 1} {
		set ev_id_norm	[db_get_col $rs 0 ev_id]
	}
	db_close $rs
	if {$nrows != 1} {
		error "A suitable link could not be created for event $ev_id,$start_time because $nrows rows were found."
	}

	set sql		{insert into tToteEvLink (ev_id_tote,ev_id_norm) values (?,?);}
	set stmt	[inf_prep_sql $::DB $sql]

	db_close [inf_exec_stmt $stmt $ev_id $ev_id_norm]

	return $ev_id_norm
}

##
# DESCRIPTION
#
#	Creates normal events for all Tote events. Also creates the markets, but does not
#	populate them with selections.
##
proc ADMIN::TOTE::make_normal_events {today_only create_selections} {
	global DB USERNAME

	OT_LogWrite 12 "==>[info level [info level]]"

	if {![string is boolean -strict $today_only] || ![string is boolean -strict $create_selections]} {
		error "Invalid arguments: today_only and create_selections must be a boolean."
	}
	if {[OT_CfgGet DEVELOPMENT N] == "N"} {
		error "This functionality can only be used in a test/development environment, and may not be used live."
	}

	inf_begin_tran $DB
	if {[catch {

		# get the tote events
		set get_evs_sql [subst {
			select distinct
				e.ev_id ev_id_tote,
				l.ev_type_id_norm ev_type_id,
				e.start_time,
				e.desc
			from
				tEv				e,
				tEvType			t,
				tToteTypeLink	l
			where
				e.ev_type_id	= t.ev_type_id
			-- ensure that it has a linkable type
			and	e.ev_type_id	= l.ev_type_id_tote
			-- ensure that it's a pool
			and	exists (
					select
						1
					from
						tEvMkt		m,
						tPoolMkt	pm,
						tPool		p,
						tPoolType	pt
					where
						pt.pool_source_id	= "U"
					and	pt.pool_type_id	= p.pool_type_id
					and	p.pool_id		= pm.pool_id
					and	pm.ev_mkt_id	= m.ev_mkt_id
					and m.ev_id			= e.ev_id
				)
			-- make sure that it is today
			[expr {$today_only?"and extend(e.start_time, year to day) = extend(current,year to day)":""}]
			-- make sure that a link does not already exists
			and not exists (
				select
					1
				from
					tToteEvLink		el
				where
					el.ev_id_tote = e.ev_id
				)
		}]
		set get_evs_stmt	[inf_prep_sql $DB $get_evs_sql]

		# insert the new event
		set ins_ev_sql {
			execute procedure pInsEv(
				p_adminuser		= ?,
				p_ev_type_id	= ?,
				p_desc			= ?,
				p_start_time	= ?,
				p_channels		= "I",
				p_gen_code      = ?
			)
		}
		set ins_ev_stmt		[inf_prep_sql $DB $ins_ev_sql]

		# find the ev ocs for inserting markets
		set get_mkts_sql {
			select
				ev_oc_grp_id
			from
				tEvOcGrp
			where
				ev_type_id	= ?
		}
		set get_mkts_stmt	[inf_prep_sql $DB $get_mkts_sql]

		# insert a market for each ev oc grp
		set ins_ev_sql {
				execute procedure pInsEvMkt(
				p_adminuser		= ?,
				p_ev_id			= ?,
				p_ev_oc_grp_id	= ?
			)
		}
		set ins_mkt_stmt	[inf_prep_sql $DB $ins_ev_sql]

		# event ocs
		set get_ocs_sql {
			select
				desc
			from
				tEvOc
			where
				ev_id	= ?
		}
		set get_ocs_stmt	[inf_prep_sql $DB $get_ocs_sql]

		# insert oc
		set ins_oc_sql {
			execute procedure pInsEvOc(
				p_adminuser = ?,
				p_ev_mkt_id = ?,
				p_ev_id = ?,
				p_desc = ?,
				p_channels = "I"
			)
		}
		set ins_oc_stmt	[inf_prep_sql $DB $ins_oc_sql]

		if {[OT_CfgGet FUNC_GEN_EV_CODE 0]} {
			set gen_code Y
		} else {
			set gen_code N
		}

		# do the work
		set get_evs_rs		[inf_exec_stmt $get_evs_stmt]
		set get_evs_nrows	[db_get_nrows $get_evs_rs]

		for {set get_evs_r 0} {$get_evs_r < $get_evs_nrows} {incr get_evs_r} {

			foreach col {ev_id_tote ev_type_id start_time desc} {
				set $col	[db_get_col $get_evs_rs $get_evs_r $col]
			}
			OT_LogWrite 9 "ADMIN::TOTE::make_normal_events: Found event type=$ev_type_id, start_time=$start_time, desc=$desc"

			set ins_ev_rs [inf_exec_stmt $ins_ev_stmt $USERNAME $ev_type_id $desc $start_time $gen_code]
			set ev_id [db_get_coln $ins_ev_rs 0 0]
			db_close $ins_ev_rs
			OT_LogWrite 9 "ADMIN::TOTE::make_normal_events: Created event ev=$ev_id"

			# get the markets
			set get_mkts_rs	[inf_exec_stmt $get_mkts_stmt $ev_type_id]
			set get_mkts_nrows	[db_get_nrows $get_mkts_rs]

			for {set get_mkts_r 0} {$get_mkts_r < $get_mkts_nrows} {incr get_mkts_r} {

				foreach col {ev_oc_grp_id} {
					set $col [db_get_col $get_mkts_rs $get_mkts_r $col]
				}
				OT_LogWrite 9 "ADMIN::TOTE::make_normal_events: Found market ev_oc_grp=$ev_oc_grp_id"
				set ins_mkt_rs	[inf_exec_stmt $ins_mkt_stmt $USERNAME $ev_id $ev_oc_grp_id]
				set ev_mkt_id	[db_get_coln $ins_mkt_rs 0 0]
				db_close $ins_mkt_rs

				# create each of the selections
				# since the selections are the same for each market, we just use them
				if {$create_selections} {
					if {![info exists selections]} {

						set get_ocs_rs	[inf_exec_stmt $get_ocs_stmt $ev_id_tote]
						set get_ocs_nrows	[db_get_nrows $get_ocs_rs]

						set selections [list]
						for {set get_ocs_r 0} {$get_ocs_r < $get_ocs_nrows} {incr get_ocs_r} {
							lappend selections [db_get_col $get_ocs_rs $get_ocs_r desc]
							OT_LogWrite 9 "ADMIN::TOTE::make_normal_events: Found selection [lindex $selections end]"
						}
						db_close $get_ocs_rs
					}
					foreach desc $selections {
						db_close [inf_exec_stmt $ins_oc_stmt $USERNAME $ev_mkt_id $ev_id $desc]
					}
				}
			}
			db_close $get_mkts_rs
			if {[info exist selections]} {unset selections}
		}
		db_close $get_evs_rs

		# and do the linking
		# success!!
		if {$get_evs_nrows == 0} {
			error "Failed to find any events suitable to link, check that the type links have already been set up."
		}
		inf_commit_tran $DB

		make_ev_links_automatically $today_only

		msg_bind "Created a normal event and markets for $get_evs_nrows Tote event(s). Check that the correct markets have been created."
	} msg]} {
		inf_rollback_tran $DB
		err_bind $msg
	}
}

##
# DESCRIPTION
#
#	Make the type link.
##
proc ADMIN::TOTE::go_ev_audit {ev_id_tote} {
	OT_LogWrite 12 "==>[info level [info level]]"

	if {[catch {
		if {![string is integer -strict $ev_id_tote]} {
			error "Invalid arguments: the tote ev must be an integer."
		}
		reqSetArg AuditInfo ToteEvLink
		ADMIN::AUDIT::go_audit
	} msg]} {
		err_bind $msg
		go_ev_links
	}
}
