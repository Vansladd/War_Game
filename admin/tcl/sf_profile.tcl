# ==============================================================
# $Id: sf_profile.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 Orbis Technology Ltd. All rights reserved.
#
# Handlers for screens which control Stake Factor Profiles
# ==============================================================

namespace eval ADMIN::SFPROFILE {

	asSetAct ADMIN::SFPROFILE::GoProfileList [namespace code go_profile_list]
	asSetAct ADMIN::SFPROFILE::GoProfileAdd  [namespace code go_profile_add]
	asSetAct ADMIN::SFPROFILE::DoProfileAdd  [namespace code do_profile_add]
	asSetAct ADMIN::SFPROFILE::GoProfileUpd  [namespace code go_profile_upd]
	asSetAct ADMIN::SFPROFILE::DoProfileUpd  [namespace code do_profile_upd]
	asSetAct ADMIN::SFPROFILE::DoProfileDel  [namespace code do_profile_del]

# Gets all stake factor profiles and binds them up to display all in
# sf_profile_list.html
#
proc go_profile_list {} {
	global DB PROFILE

	if {![op_allowed ManageSFProfiles]} {
		err_bind "You don't have permission to manage stake factor profiles"
		asPlayFile -nocache error_rpt.html
		return
	}

	# Get all the profiles, ordered by name for useability
	set sql {
		select
			sf_prf_id,
			name
		from
			tStkFacProfile
		order by
			2,1
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	# Fill the PROFILE array for binding up
	for {set i 0} {$i < $nrows} {incr i} {
		set PROFILE($i,id)   [db_get_col $rs $i sf_prf_id]
		set PROFILE($i,name) [db_get_col $rs $i name]
	}

	db_close $rs

	tpSetVar NumProfiles $nrows

	tpBindVar Id   PROFILE id   profile_idx
	tpBindVar Name PROFILE name profile_idx

	asPlayFile -nocache sf_profile_list.html

	catch {unset PROFILE}
}



# Go to the add profile page
proc go_profile_add {} {

	if {![op_allowed ManageSFProfiles]} {
		err_bind "You don't have permission to manage stake factor profiles"
		asPlayFile -nocache error_rpt.html
		return
	}

	tpSetVar     AddProfile 1
	tpBindString NextTo     0

	asPlayFile -nocache sf_profile_main.html
}



# Add a new profile
proc do_profile_add {} {
	global DB

	set fn {ADMIN::SFPROFILE::do_profile_add}

	if {![op_allowed ManageSFProfiles]} {
		err_bind "You don't have permission to manage stake factor profiles"
		asPlayFile -nocache error_rpt.html
		return
	}

	# Insert the new profile, then loop over the limit factors and hierarchy
	# links to create the link rows
	set name_check_sql {
		select
			name
		from
			tStkFacProfile
	}

	set insert_profile_sql {
		insert into tStkFacProfile (
			name
		) values (
			?
		)
	}

	set insert_period_sql {
		insert into tStkFacPrfPeriod (
			sf_prf_id,
			mins_before_from,
			mins_before_to,
			stake_factor
		) values (
			?, ?, ?, ?
		)
	}

	set name [reqGetArg ProfileName]

	if {[catch {
		set stmt [inf_prep_sql $DB $name_check_sql]
		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} mst]} {
		ob_log::write ERROR {$fn: Failed to get current names - $msg}
		err_bind "Failed to get current profile names from DB - $msg"
		go_profile_add
		return
	}

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		if {$name == [db_get_col $rs $i name]} {
			db_close $rs
			ob_log::write ERROR {$fn: Profile name already exists ($name)}
			err_bind "Failed to create profile, name '$name' is already in use"
			go_profile_add
			return;
		}
	}

	db_close $rs

	if {[catch {
		set stmt [inf_prep_sql $DB $insert_profile_sql]
		inf_exec_stmt $stmt $name
		set sf_prf_id [inf_get_serial $stmt]
		inf_close_stmt $stmt
	} msg]} {
		ob_log::write ERROR {$fn: Failed to insert new profile - $msg}
		err_bind "Failed to insert new profile: $msg"
		go_profile_add
		return
	}

	reqSetArg ProfileId $sf_prf_id

	# The limits are submitted as three lists
	set from_list [split [reqGetArg FromList] ","]
	set to_list   [split [reqGetArg ToList] ","]
	set sf_list   [split [reqGetArg SfList] ","]

	if {[catch {set stmt [inf_prep_sql $DB $insert_period_sql]} msg]} {
		ob_log::write ERROR {$fn: Failed to prep insert_period_sql - $msg}
		err_bind "Failed to prep SQL - $msg"
		go_profile_upd
		return
	}

	set prev_to -1

	foreach from $from_list to $to_list sf $sf_list {
		# Convert from hours to minutes (to should never be blank)
		if {$from != ""} {set from [expr $from * 60]}
		set to [expr $to * 60]

		# Server-side verification for these values
		if {![verify_period_input $from $to $prev_to $sf]} {
			go_profile_upd
			return
		}

		if {[catch {
			inf_exec_stmt $stmt $sf_prf_id $from $to $sf
		} msg]} {
			ob_log::write ERROR {$fn: Failed to add limit to profile - $msg}
			err_bind "Failed to add limit to new profile - $msg"
			go_profile_upd
			return
		}

		set prev_to $to
	}
	catch {inf_close_stmt $stmt}

	# Now add the hierarchy levels which have been linked
	set link_sql {
		insert into tStkFacPrfLink (
			sf_prf_id,
			level,
			id
		) values (
			?,?,?
		)
	}

	if {[catch {set link_stmt [inf_prep_sql $DB $link_sql]} msg]} {
		ob_log::write ERROR {$fn: Failed to prep link_sql - $msg}
		err_bind "Failed to prepare link SQL - $msg"
		go_profile_upd
		return
	}

	set categories [split [reqGetArg "CategoryList"] ","]
	set classes    [split [reqGetArg "ClassList"] ","]
	set types      [split [reqGetArg "TypeList"] ","]
	set events     [split [reqGetArg "EventList"] ","]

	foreach category $categories {
		if {[catch {
			inf_exec_stmt $link_stmt $sf_prf_id "CATEGORY" $category
		} msg]} {
			ob_log::write ERROR {$fn: Failed to add category link\
									  ($sf_prf_id,$category)}
			err_bind "Failed to add category link - $msg"
		}
	}

	foreach class $classes {
		if {[catch {
			inf_exec_stmt $link_stmt $sf_prf_id "CLASS" $class
		} msg]} {
			ob_log::write ERROR {$fn: Failed to add class link\
									  ($sf_prf_id,$class)}
			err_bind "Failed to add class link - $msg"
		}
	}

	foreach type $types {
		if {[catch {
			inf_exec_stmt $link_stmt $sf_prf_id "TYPE" $type
		} msg]} {
			ob_log::write ERROR {$fn: Failed to add type link\
									  ($sf_prf_id,$type)}
			err_bind "Failed to add type link - $msg"
		}
	}

	foreach event $events {
		if {[catch {
			inf_exec_stmt $link_stmt $sf_prf_id "EVENT" $event
		} msg]} {
			ob_log::write ERROR {$fn: Failed to add event link\
									  ($sf_prf_id,$event)}
			err_bind "Failed to add event link - $msg"
		}
	}

	msg_bind "Successfully added profile $name"
	go_profile_upd
}



proc go_profile_upd {} {
	global DB LIMIT CATEGORY CLASS TYPE EVENT

	set fn {ADMIN::SFPROFILE::go_profile_upd}

	if {![op_allowed ManageSFProfiles]} {
		err_bind "You don't have permission to manage stake factor profiles"
		asPlayFile -nocache error_rpt.html
		return
	}

	catch {unset LIMIT}

	set period_sql {
		select
			p.name,
			f.mins_before_from,
			f.mins_before_to,
			f.stake_factor
		from
			tStkFacProfile p,
			outer tStkFacPrfPeriod f
		where
				p.sf_prf_id = f.sf_prf_id
			and p.sf_prf_id = ?
		order by
			f.mins_before_to asc
	}

	set sf_prf_id [reqGetArg ProfileId]

	# Get the period stake factors
	if {[catch {
		set stmt [inf_prep_sql $DB $period_sql]
		set rs   [inf_exec_stmt $stmt $sf_prf_id]
		inf_close_stmt $stmt
	} msg]} {
		ob_log::write ERROR {$fn: Failed to get limits ($sf_period_id) - $msg}
		err_bind "Failed to get limits ($sf_prf_id) - $msg"
		go_profile_list
		return
	}

	set nrows [db_get_nrows $rs]
	set name [db_get_col $rs 0 name]
	set next_to 0

	for {set i 0} {$i < $nrows} {incr i} {
		set LIMIT($i,from) [db_get_col $rs $i mins_before_from]
		set LIMIT($i,to)   [db_get_col $rs $i mins_before_to]
		set LIMIT($i,sf)   [db_get_col $rs $i stake_factor]

		# Convert minutes to hours
		if {$LIMIT($i,to) != ""} {
			set LIMIT($i,to) [expr $LIMIT($i,to) / 60]
		}

		if {$LIMIT($i,from) != ""} {
			set LIMIT($i,from) [expr $LIMIT($i,from) / 60]
			set next_to $LIMIT($i,from)
		} elseif {$LIMIT($i,to) != ""} {
			# Hide the Add New Limit box if the final limit has no "From" value
			tpSetVar HideAdd 1
		}
	}

	db_close $rs

	# If there's no stake factor or to column then we've got nothing in the limits
	if {$LIMIT(0,to) == "" && $LIMIT(0,sf) == ""} {
		set nrows 0
	}

	# Bind up limit values
	tpSetVar     NumLimits   $nrows
	tpBindString ProfileName $name
	tpBindString ProfileId   $sf_prf_id
	tpBindString NextTo      $next_to

	tpBindVar From LIMIT from limit_idx
	tpBindVar To   LIMIT to   limit_idx
	tpBindVar Sf   LIMIT sf   limit_idx

	# Bind up each hierarchy level into the relevant array - CATEGORY, CLASS,
	# TYPE and EVENT
	set link_sql [subst {
		select
			'CATEGORY' as level,
			l.id,
			y.name
		from
			tStkFacPrfLink l,
			tEvCategory y
		where
				l.id = y.ev_category_id
			and l.sf_prf_id = $sf_prf_id
			and l.level = 'CATEGORY'
		union
		select
			'CLASS' as level,
			l.id,
			c.name
		from
			tStkFacPrfLink l,
			tEvClass c
		where
				l.id = c.ev_class_id
			and l.sf_prf_id = $sf_prf_id
			and l.level = 'CLASS'
		union
		select
			'TYPE' as level,
			l.id,
			t.name
		from
			tStkFacPrfLink l,
			tEvType t
		where
				l.id = t.ev_type_id
			and l.sf_prf_id = $sf_prf_id
			and l.level = 'TYPE'
		union
		select
			'EVENT' as level,
			l.id,
			e.desc as name
		from
			tStkFacPrfLink l,
			tEv e
		where
				l.id = e.ev_id
			and l.sf_prf_id = $sf_prf_id
			and l.level = 'EVENT'
	}]

	if {[catch {
		set link_stmt [inf_prep_sql $DB $link_sql]
		set rs [inf_exec_stmt $link_stmt]
		inf_close_stmt $link_stmt
	} msg]} {
		ob_log::write ERROR {$fn: Failed to get hierarchy links\
								  ($sf_prf_id) - $msg}
		err_bind "Failed to get hierarchy links ($sf_prf_id) - $msg"
	} else {
		# Bind up the classes/types/events
		set CATEGORY_ids ""
		set CLASS_ids    ""
		set TYPE_ids     ""
		set EVENT_ids    ""

		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			set level              [db_get_col $rs $i level]
			set id                 [db_get_col $rs $i id]
			set ${level}($id,name) [db_get_col $rs $i name]
			lappend ${level}_ids $id
		}

		db_close $rs

		tpSetVar CategoryList $CATEGORY_ids
		tpSetVar ClassList    $CLASS_ids
		tpSetVar TypeList     $TYPE_ids
		tpSetVar EventList    $EVENT_ids

		tpBindVar CategoryName CATEGORY name category_idx
		tpBindVar ClassName    CLASS    name class_idx
		tpBindVar TypeName     TYPE     name type_idx
		tpBindVar EventName    EVENT    name event_idx
	}

	asPlayFile -nocache sf_profile_main.html

	catch {unset LIMIT}
}



# Do the update for a particular profile
proc do_profile_upd {} {
	global DB

	set fn {ADMIN::SFPROFILE::do_profile_upd}

	if {![op_allowed ManageSFProfiles]} {
		err_bind "You don't have permission to manage stake factor profiles"
		asPlayFile -nocache error_rpt.html
		return
	}

	set sf_prf_id   [reqGetArg ProfileId]
	set name_submit [reqGetArg ProfileName]

	# Has the name changed?
	set name_sql {
		select
			name
		from
			tStkFacProfile
		where
			sf_prf_id = ?
	}

	if {[catch {
		set name_stmt [inf_prep_sql $DB $name_sql]
		set rs [inf_exec_stmt $name_stmt $sf_prf_id]
		inf_close_stmt $name_stmt
	} msg]} {
		ob_log::write ERROR {$fn: Failed to get name from DB - $msg}
		err_bind "Failed to get name from DB - $msg"
		go_profile_upd
		return
	}

	if {[db_get_nrows $rs] > 0} {
		set name_db [db_get_col $rs 0 name]
	} else {
		ob_log::write ERROR {$fn: Failed to find profile $sf_prf_id - $msg}
		err_bind "Failed to find profile $sf_prf_id - $msg"
		go_profile_upd
		return
	}

	db_close $rs

	if {$name_db != $name_submit} {
		# Update to new name
		set upd_name_sql {
			update tStkFacProfile set
				name = ?
			where
				sf_prf_id = ?
		}

		if {[catch {
			set upd_name_stmt [inf_prep_sql $DB $upd_name_sql]
			inf_exec_stmt $upd_name_stmt $name_submit $sf_prf_id
			inf_close_stmt $upd_name_stmt
		} msg]} {
			ob_log::write ERROR {$fn: Failed to update profile name\
								($sf_prf_id,$name_submit) - $msg}
			err_bind "Failed to update profile name - $msg"
			go_profile_upd
			return
		}
	}


	# First get out what's in the database, so we know whether we need to insert
	# new limits or just update the old ones
	set sel_sql {
		select
			sf_prf_period_id,
			mins_before_from,
			mins_before_to,
			stake_factor
		from
			tStkFacPrfPeriod
		where
			sf_prf_id = ?
		order by
			mins_before_to
	}

	# SQL for updating/deleting old rows or inserting new ones
	# NOTE - The orderings for the updates/inserts ARE IMPORTANT
	# Be very careful if modifying, as they accept the values in the same order
	# in the for loop where we execute the statements
	set upd_sql {
		update tStkFacPrfPeriod set
			mins_before_from = ?,
			mins_before_to = ?,
			stake_factor = ?
		where
			sf_prf_period_id = ?
	}

	set ins_sql {
		insert into tStkFacPrfPeriod (
			mins_before_from,
			mins_before_to,
			stake_factor,
			sf_prf_id
		) values (
			?,?,?,?
		)
	}

	set del_sql {
		delete from
			tStkFacPrfPeriod
		where
			sf_prf_period_id = ?
	}

	# Set the statements in a catch in case of DB error
	if {[catch {
		set sel_stmt [inf_prep_sql $DB $sel_sql]
		set upd_stmt [inf_prep_sql $DB $upd_sql]
		set ins_stmt [inf_prep_sql $DB $ins_sql]
		set del_stmt [inf_prep_sql $DB $del_sql]
	} msg]} {
		ob_log::write ERROR {$fn: Failed to prep update_sql - $msg}
		err_bind "Failed to prep SQL - $msg"
		go_profile_upd
		return
	}

	# Fill an array with the current data
	if {[catch {
		set rs [inf_exec_stmt $sel_stmt $sf_prf_id]
		inf_close_stmt $sel_stmt
	} msg]} {
		ob_log::write ERROR {$fn: Failed to get profile $sf_prf_id - $msg}
		err_bind "Failed to get profile from DB - $msg"
		go_profile_upd
		return
	}

	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {
		set DB_LIMITS($i,sf_prf_period_id) [db_get_col $rs $i sf_prf_period_id]
		set DB_LIMITS($i,mins_before_from) [db_get_col $rs $i mins_before_from]
		set DB_LIMITS($i,mins_before_to)   [db_get_col $rs $i mins_before_to]
		set DB_LIMITS($i,stake_factor)     [db_get_col $rs $i stake_factor]
	}

	db_close $rs

	# The limits are submitted as three lists
	set from_list [split [reqGetArg FromList] ","]
	set to_list   [split [reqGetArg ToList] ","]
	set sf_list   [split [reqGetArg SfList] ","]

	set count 0
	set prev_to -1

	# Loop over the user-submitted values, then update/delete/insert where
	# appropriate
	foreach from $from_list to $to_list sf $sf_list {
		# Convert hours to minutes
		if {$from != ""} {set from [expr $from * 60]}
		if {$to != ""} {set to [expr $to * 60]}

		# Server-side verification - does all the error binding etc on failure
		if {![verify_period_input $from $to $prev_to $sf]} {
			go_profile_upd
			return
		}

		# Update/insert any new values
		set updating 1
		if {$count >= $nrows} {
			# We're definitely inserting
			set stmt $ins_stmt
			set id $sf_prf_id
		} elseif {$from != $DB_LIMITS($count,mins_before_from) ||
					$to != $DB_LIMITS($count,mins_before_to) ||
					$sf != $DB_LIMITS($count,stake_factor)} {
			# Something's changed so let's update
			set stmt $upd_stmt
			set id   $DB_LIMITS($count,sf_prf_period_id)
		} else {
			# Nothing's changed
			set updating 0
		}

		if {$updating == 1} {
			if {[catch {
				inf_exec_stmt $stmt $from $to $sf $id
			} msg]} {
				ob_log::write ERROR {$fn: Failed to update profile $sf_prf_id\
										  ($from,$to,$sf) - $msg}
				err_bind "Failed to update profile From=$from,To=$to,Stake\
						  Factor=$sf - $msg"
			}
		}
		set prev_to $to
		incr count
	}

	if {$count < $nrows} {
		# If this is the case then we've got stuff to delete
		for {set i $count} {$i < $nrows} {incr i} {
			if {[catch {
				inf_exec_stmt $del_stmt $DB_LIMITS($i,sf_prf_period_id)
			} msg]} {
				ob_log::write ERROR {$fn: Failed to delete profile period\
										  $sf_prf_id - $msg}
				err_bind "Failed to delete previous profile From=$from,To=$to,\
						  Stake Factor=$sf - $msg"
			}
		}
	}

	# Cleanup
	catch {inf_close_stmt $ins_stmt}
	catch {inf_close_stmt $upd_stmt}
	catch {inf_close_stmt $del_stmt}

	# TODO - hierarchy stuff
	# Get the current ID's out the database, then compare with what's been
	# submitted and then add/delete where appropriate
	set sel_level_sql {
		select
			l.level,
			l.id
		from
			tStkFacPrfLink l
		where
			l.sf_prf_id = ?
	}

	set ins_level_sql {
		insert into tStkFacPrfLink (
			sf_prf_id,
			level,
			id
		) values (
			?,?,?
		)
	}

	# Note - there's a unique constraint on id,level
	set del_level_sql {
		delete from
			tStkFacPrfLink
		where
				id = ?
			and level = ?
	}

	if {[catch {
		set sel_level_stmt [inf_prep_sql $DB $sel_level_sql]
		set ins_level_stmt [inf_prep_sql $DB $ins_level_sql]
		set del_level_stmt [inf_prep_sql $DB $del_level_sql]

		set rs [inf_exec_stmt $sel_level_stmt $sf_prf_id]
		inf_close_stmt $sel_level_stmt
	} msg]} {
		ob_log::write ERROR {$fn: Failed to get current hierarchy levels - $msg}
		err_bind "Failed to get current hierarchy levels - $msg"
		go_profile_upd
		return
	}

	set CATEGORY_db ""
	set CLASS_db    ""
	set TYPE_db     ""
	set EVENT_db    ""

	# Build up lists of what's currently in each part of the hierarchy
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set level [db_get_col $rs $i level]
		lappend ${level}_db [db_get_col $rs $i id]
	}

	db_close $rs

	set CATEGORY_db [lsort -integer -unique $CATEGORY_db]
	set CLASS_db    [lsort -integer -unique $CLASS_db]
	set TYPE_db     [lsort -integer -unique $TYPE_db]
	set EVENT_db    [lsort -integer -unique $EVENT_db]

	set CATEGORY_submit [lsort -integer -unique [split [reqGetArg CategoryList] ","]]
	set CLASS_submit    [lsort -integer -unique [split [reqGetArg ClassList] ","]]
	set TYPE_submit     [lsort -integer -unique [split [reqGetArg TypeList] ","]]
	set EVENT_submit    [lsort -integer -unique [split [reqGetArg EventList] ","]]

	# Add the new hierarchy levels which we're associating with the profile.
	# We remove any from the _db lists as we we go along so that we're
	# eventually left with a list of those levels which have been removed
	foreach category $CATEGORY_submit {
		set idx [lsearch -sorted $CATEGORY_db $category]
		if {$idx > -1} {
			# We've already got it in the DB, so we can remove from the list
			set CATEGORY_db [lreplace $CATEGORY_db $idx $idx]
		} else {
			# It's a new category so insert it
			if {[catch {
				inf_exec_stmt $ins_level_stmt $sf_prf_id "CATEGORY" $category
			} msg]} {
				ob_log::write ERROR {$fn: Failed to insert category $category - $msg}
				err_bind "Failed to insert category $category - $msg"
			}
		}
	}

	foreach class $CLASS_submit {
		set idx [lsearch -sorted $CLASS_db $class]
		if {$idx > -1} {
			# We've already got it in the DB, so we can remove from the list
			set CLASS_db [lreplace $CLASS_db $idx $idx]
		} else {
			# It's a new class so insert it
			if {[catch {
				inf_exec_stmt $ins_level_stmt $sf_prf_id "CLASS" $class
			} msg]} {
				ob_log::write ERROR {$fn: Failed to insert class $class - $msg}
				err_bind "Failed to insert class $class - $msg"
			}
		}
	}

	foreach type $TYPE_submit {
		set idx [lsearch -sorted $TYPE_db $type]
		if {$idx > -1} {
			# We've already got it in the DB, so we can remove from the list
			set TYPE_db [lreplace $TYPE_db $idx $idx]
		} else {
			# It's a new type so insert it
			if {[catch {
				inf_exec_stmt $ins_level_stmt $sf_prf_id "TYPE" $type
			} msg]} {
				ob_log::write ERROR {$fn: Failed to insert type $type - $msg}
				err_bind "Failed to insert type $type - $msg"
			}
		}
	}

	foreach event $EVENT_submit {
		set idx [lsearch -sorted $EVENT_db $event]
		if {$idx > -1} {
			# We've already got it in the DB, so we can remove from the list
			set EVENT_db [lreplace $EVENT_db $idx $idx]
		} else {
			# It's a new event so insert it
			if {[catch {
				inf_exec_stmt $ins_level_stmt $sf_prf_id "EVENT" $event
			} msg]} {
				ob_log::write ERROR {$fn: Failed to insert event $event - $msg}
				err_bind "Failed to insert event $event - $msg"
			}
		}
	}

	# We're now left with the lists of items which need to be deleted
	foreach category $CATEGORY_db {
		if {[catch {
			inf_exec_stmt $del_level_stmt $category "CATEGORY"
		} msg]} {
			ob_log::write ERROR {$fn: Failed to delete category $category - $msg}
			err_bind "Failed to delete category $category - $msg"
		}
	}

	foreach class $CLASS_db {
		if {[catch {
			inf_exec_stmt $del_level_stmt $class "CLASS"
		} msg]} {
			ob_log::write ERROR {$fn: Failed to delete class $class - $msg}
			err_bind "Failed to delete class $class - $msg"
		}
	}

	foreach type $TYPE_db {
		if {[catch {
			inf_exec_stmt $del_level_stmt $type "TYPE"
		} msg]} {
			ob_log::write ERROR {$fn: Failed to delete type $type - $msg}
			err_bind "Failed to delete type $type - $msg"
		}
	}

	foreach event $EVENT_db {
		if {[catch {
			inf_exec_stmt $del_level_stmt $event "EVENT"
		} msg]} {
			ob_log::write ERROR {$fn: Failed to delete event $event - $msg}
			err_bind "Failed to delete event $event - $msg"
		}
	}

	# Cleanup
	catch {inf_close_stmt $ins_level_stmt}
	catch {inf_close_stmt $del_level_stmt}

	msg_bind "Successfully updated profile $name_submit"
	go_profile_list
}



# Deletes a profile
proc do_profile_del {} {
	global DB

	set fn {ADMIN::SFPROFILE::do_profile_del}

	if {![op_allowed ManageSFProfiles]} {
		err_bind "You don't have permission to manage stake factor profiles"
		asPlayFile -nocache error_rpt.html
		return
	}

	set sf_prf_id [reqGetArg ProfileId]
	set name      [reqGetArg ProfileName]
	# Rebind in case of error
	tpBindString ProfileId $sf_prf_id

	# First delete the period limits
	set sql {
		delete from
			tStkFacPrfPeriod
		where
			sf_prf_id = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $sf_prf_id
		inf_close_stmt $stmt
	} msg]} {
		ob_log::write ERROR {$fn: Failed to delete profile periods - $msg}
		err_bind "Unable to delete period limits for profile - $msg"
		go_profile_upd
		return
	}

	# Then delete the hierarchy links
	set sql {
		delete from
			tStkFacPrfLink
		where
			sf_prf_id = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $sf_prf_id
		inf_close_stmt $stmt
	} msg]} {
		ob_log::write ERROR {$fn: Failed to delete profile links - $msg}
		err_bind "Unable to delete links for profile - $msg"
		go_profile_upd
		return
	}

	# Finally delete the profile itself
	set sql {
		delete from
			tStkFacProfile
		where
			sf_prf_id = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $sf_prf_id
		inf_close_stmt $stmt
	} msg]} {
		ob_log::write ERROR {$fn: Failed to delete profile - $msg}
		err_bind "Unable to delete profile - $msg"
		go_profile_upd
		return
	}

	msg_bind "Successfully deleted profile $name"
	go_profile_list
}


# Runs some basic verification checks to make sure that the from, to and stake
# factor values for period limits
#
# from    - corresponding to tStkFacPrfPeriod.mins_before_from
# to      - corresponding to tStkFacPrfPeriod.mins_before_to
# prev_to - the "to" from the previous row for the profile
# sf      - corresponding to tStkFacPrfPeriod.stake_factor
#
proc verify_period_input {from to prev_to sf} {
	set fn {ADMIN::SFPROFILE::verify_period_input}

	if {![string is integer -strict $to] ||
			![string is integer $from] ||
			![string is double -strict $sf] ||
			$prev_to >= $to ||
			($from != "" && $from <= $to) || $sf < 0 || $sf > 99} {
		# Failed verification checks, log it and bind it
		ob_log::write ERROR {$fn: Failed validation check ($from,$to,$prev_to,$sf)}
		err_bind "Invalid values: From = $from, To = $to, Stake Factor = $sf,\
					Previous To = $prev_to"
		return 0
	} else {
		return 1
	}
}


}
