# $Id: jockeytrainer.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::JOCKEYTRAINER {

asSetAct ADMIN::JOCKEYTRAINER::goJockeyTrainer [namespace code go_jockey_trainer]
asSetAct ADMIN::JOCKEYTRAINER::doJockey        [namespace code upd_jockey]
asSetAct ADMIN::JOCKEYTRAINER::doTrainer       [namespace code upd_trainer]



#
# ----------------------------------------------------------------------------
# Get the list of all jockeys and trainers
# ----------------------------------------------------------------------------
#
proc go_jockey_trainer { {event_date ""} } {

	global DB JOCKEYS TRAINERS

	set sql [subst {
		select distinct
			r.jockey as j_name,
			r.trainer as t_name,
			r.key_jockey,
			r.key_trainer
		from
			tFormRunner r,
			tEvOc o,
			tEv e
		where
			r.ev_oc_id = o.ev_oc_id and
			e.ev_id = o.ev_id and
			e.start_time >= ? and
			e.start_time < ?
	}]

	if {$event_date == ""} {
		set event_date [reqGetArg event_date]
	}

	# if the call is coming from update page
	# set the update message on the HTML page

	# Date defaults to today
	if {![info exists event_date] || $event_date == ""} {
		set event_date [clock format [clock scan today] -format %Y-%m-%d]
	}

	set event_date_s "$event_date 00:00:00"
	set event_date_e "$event_date 23:59:59"

	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt $event_date_s $event_date_e]
	inf_close_stmt $stmt

	set cols  [db_get_colnames $rs]
	set nrows [db_get_nrows $rs]

	set jock_list [list]
	set train_list [list]
	set jock_name_list [list]
	set train_name_list [list]
	set key_jockey_list [list]
	set key_trainer_list [list]

	# Extract the result set into two lists for sorting later
	for {set row 0} {$row < $nrows} {incr row} {
		set jock_name [db_get_col $rs $row j_name]

		# if the jockey name is an empty string or a duplicate
		# there is no reason to display it
		if {$jock_name != "" && [lsearch $jock_name_list $jock_name] < 0} {
			set temp_entry [list]
			lappend temp_entry $jock_name
			lappend temp_entry [db_get_col $rs $row key_jockey]
			lappend jock_list $temp_entry
			if {[db_get_col $rs $row key_jockey] == "Y"} {
				lappend key_jockey_list $jock_name
			}
			lappend jock_name_list $jock_name
		}

		set train_name [db_get_col $rs $row t_name]

		# if the trainer name is an empty string or a duplicate
		# there is no reason to display it
		if {$train_name != "" && [lsearch $train_name_list $train_name] < 0} {
			set temp_entry [list]
			lappend temp_entry $train_name
			lappend temp_entry [db_get_col $rs $row key_trainer]
			lappend train_list $temp_entry
			if {[db_get_col $rs $row key_trainer] == "Y"} {
				lappend key_trainer_list $train_name
			}
			lappend train_name_list $train_name
		}
	}
	db_close $rs

	# sort the lists aphabetically by the name
	set train_list [lsort -increasing -index 0 $train_list]
	set jock_list  [lsort -increasing -index 0 $jock_list]

	set JOCKEYS(nrows)  [llength $jock_list]
	set TRAINERS(nrows) [llength $train_list]

	set counter 0
	# Save the sorted result in a global array
	foreach item $jock_list {
		set JOCKEYS($counter,j_name)     [lindex $item 0]
		if {[lindex $item 1] == "Y"} {
			set JOCKEYS($counter,key_jockey) "checked "
		} else {
			set JOCKEYS($counter,key_jockey) ""
		}
		incr counter
	}

	# Save the sorted result in a global array
	set counter 0
	foreach item $train_list {
		set TRAINERS($counter,t_name)     [lindex $item 0]
		if {[lindex $item 1] == "Y"} {
			set TRAINERS($counter,key_trainer) "checked "
		} else {
			set TRAINERS($counter,key_trainer) ""
		}
		incr counter
	}

	tpSetVar num_jocks  $JOCKEYS(nrows)
	tpSetVar num_trains $TRAINERS(nrows)

	set JOCKEYS(key_jockey_list)   $key_jockey_list
	set JOCKEYS(event_date)        $event_date
	set TRAINERS(key_trainer_list) $key_trainer_list

	tpBindVar event_date       JOCKEYS  event_date
	tpBindVar key_jockey_list  JOCKEYS  key_jockey_list
	tpBindVar key_trainer_list TRAINERS key_trainer_list

	tpBindVar j_runner_id JOCKEYS  runner_id    j_idx
	tpBindVar j_name      JOCKEYS  j_name       j_idx
	tpBindVar key_jockey  JOCKEYS  key_jockey   j_idx

	tpBindVar t_runner_id TRAINERS runner_id    t_idx
	tpBindVar t_name      TRAINERS t_name       t_idx
	tpBindVar key_trainer TRAINERS key_trainer  t_idx

	asPlayFile -nocache jockeytrainer.html

	unset JOCKEYS
	unset TRAINERS
}



#
# ----------------------------------------------------------------------------
# Updates the jockey list
# ----------------------------------------------------------------------------
#
proc upd_jockey {} {

	global DB


	set key_jockey_list [string trim [reqGetArg key_jockey_list]]
	set event_date [string trim [reqGetArg event_date]]

	set event_date_s "$event_date 00:00:00"
	set event_date_e "$event_date 23:59:59"

	set new_added_key_jockeys [list]
	set new_removed_key_jockeys [list]

	set KEY_JOCKEY_REGEXP "^KEY_JOCK_(.*)$"

	# Get the list of newly added key jockeys
	for {set n 0} {$n < [reqGetNumVals]} {incr n} {
		if {[regexp -- $KEY_JOCKEY_REGEXP [reqGetNthName $n] all key_runner_name ] } {
			if {[lsearch -exact $key_jockey_list $key_runner_name] == -1} {
				lappend new_added_key_jockeys $key_runner_name
			}
		}
	}

	# Get the list of newly removed key jockeys
	foreach jockey_name $key_jockey_list {
		if {[reqGetArg "KEY_JOCK_$jockey_name"] == ""} {
			lappend new_removed_key_jockeys $jockey_name
		}
	}

	# Add newly set key jockeys for all the events in the day
	while { [llength $new_added_key_jockeys] > 0 } {
		set items_upto_20 [list]
		if {[llength $new_added_key_jockeys] > 20} {
			# first 20 of items
			set items_upto_20 [lrange $new_added_key_jockeys 0 19]
			# the rest of the list
			set new_added_key_jockeys [lrange $new_added_key_jockeys 20 end]
		} else {
			set items_upto_20 $new_added_key_jockeys
			set new_added_key_jockeys [list]
		}
		set count 0
		foreach item $items_upto_20 {
			set var${count} $item
			incr count
		}
		# if count is less than 20, fill in the rest of variables with dummies
		while {$count < 20} {
			set var${count} -1
			incr count
		}

		set items_upto_20 [join $items_upto_20 ,]
		set sql [subst {
			update tFormRunner
				set key_jockey = "Y"
			where ev_oc_id in (
				select
					ev_oc_id
				from
					tEvOc o, tEv e
				where
					e.ev_id = o.ev_id
					and e.start_time >= ?
					and e.start_time < ?
					and jockey in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
					and o.ev_oc_id = ev_oc_id
					and (key_jockey = "N"  or key_jockey is null)
				)
		}]
		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $event_date_s $event_date_e $var0 $var1 $var2 $var3 $var4 $var5 $var6 $var7 $var8 $var9 $var10 $var11 $var12 $var13 $var14 $var15 $var16 $var17 $var18 $var19
		inf_close_stmt $stmt
	}

	# Remove the unset key jockeys for all the events in the day in bacthes of 20
	while { [llength $new_removed_key_jockeys] > 0 } {
		set items_upto_20 [list]
		if {[llength $new_removed_key_jockeys] > 20} {
			# first 20 of items
			set items_upto_20 [lrange $new_removed_key_jockeys 0 19]
			# the rest of the list
			set new_removed_key_jockeys [lrange $new_removed_key_jockeys 20 end]
		} else {
			set items_upto_20 $new_removed_key_jockeys
			set new_removed_key_jockeys [list]
		}
		set count 0
		foreach item $items_upto_20 {
			set var${count} $item
			incr count
		}
		# if count is less than 20, fill in the rest of variables with dummies
		while {$count < 20} {
			set var${count} -1
			incr count
		}

		set items_upto_20 [join $items_upto_20 ,]
		set sql [subst {
			update tFormRunner
				set key_jockey = "N"
			where ev_oc_id in (
				select
					ev_oc_id
				from
					tEvOc o, tEv e
				where
					e.ev_id = o.ev_id
					and e.start_time >= ?
					and e.start_time < ?
					and jockey in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
					and o.ev_oc_id = ev_oc_id
					and (key_jockey = "Y"  or key_jockey is null)
				)
		}]
		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $event_date_s $event_date_e $var0 $var1 $var2 $var3 $var4 $var5 $var6 $var7 $var8 $var9 $var10 $var11 $var12 $var13 $var14 $var15 $var16 $var17 $var18 $var19
		inf_close_stmt $stmt
	}


	msg_bind "The jockey has been successfully updated"
	go_jockey_trainer $event_date

}



#
# ----------------------------------------------------------------------------
# Updates the trainer list
# ----------------------------------------------------------------------------
#
proc upd_trainer {} {

	global DB

	set key_trainer_list [string trim [reqGetArg key_trainer_list]]
	set event_date [string trim [reqGetArg event_date]]

	set event_date_s "$event_date 00:00:00"
	set event_date_e "$event_date 23:59:59"

	set new_added_key_trainers [list]
	set new_removed_key_trainers [list]

	set KEY_TRAINER_REGEXP "^KEY_TRAIN_(.*)$"

	# Get the list of newly added key trainers
	for {set n 0} {$n < [reqGetNumVals]} {incr n} {
		if {[regexp -- $KEY_TRAINER_REGEXP [reqGetNthName $n] all key_runner_name ] } {
			if {[lsearch -exact $key_trainer_list $key_runner_name] == -1} {
				lappend new_added_key_trainers $key_runner_name
			}
		}
	}

	# Get the list of newly removed key trainers
	foreach trainer_name $key_trainer_list {
		if {[reqGetArg "KEY_TRAIN_$trainer_name"] == ""} {
			lappend new_removed_key_trainers $trainer_name
		}
	}

	# Add the newly set key trainers for all the events in the day
	while { [llength $new_added_key_trainers] > 0 } {
		set items_upto_20 [list]
		if {[llength $new_added_key_trainers] > 20} {
			# first 20 of items
			set items_upto_20 [lrange $new_added_key_trainers 0 19]
			# the rest of the list
			set new_added_key_trainers [lrange $new_added_key_trainers 20 end]
		} else {
			set items_upto_20 $new_added_key_trainers
			set new_added_key_trainers [list]
		}
		set count 0
		foreach item $items_upto_20 {
			set var${count} $item
			incr count
		}
		# if count is less than 20, fill in the rest of variables with dummies
		while {$count < 20} {
			set var${count} -1
			incr count
		}

		set items_upto_20 [join $items_upto_20 ,]
		set sql [subst {
			update tFormRunner
				set key_trainer = "Y"
			where ev_oc_id in (
				select
					ev_oc_id
				from
					tEvOc o, tEv e
				where
					e.ev_id = o.ev_id
					and e.start_time >= ?
					and e.start_time < ?
					and trainer in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
					and o.ev_oc_id = ev_oc_id
					and (key_trainer = "N" or key_trainer is null)
				)
		}]
		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $event_date_s $event_date_e $var0 $var1 $var2 $var3 $var4 $var5 $var6 $var7 $var8 $var9 $var10 $var11 $var12 $var13 $var14 $var15 $var16 $var17 $var18 $var19
		inf_close_stmt $stmt
	}

	# Remove the unset key trainers for all the events in the day
	while { [llength $new_removed_key_trainers] > 0 } {
		set items_upto_20 [list]
		if {[llength $new_removed_key_trainers] > 20} {
			# first 20 of items
			set items_upto_20 [lrange $new_removed_key_trainers 0 19]
			# the rest of the list
			set new_removed_key_trainers [lrange $new_removed_key_trainers 20 end]
		} else {
			set items_upto_20 $new_removed_key_trainers
			set new_removed_key_trainers [list]
		}
		set count 0
		foreach item $items_upto_20 {
			set var${count} $item
			incr count
		}
		# if count is less than 20, fill in the rest of variables with dummies
		while {$count < 20} {
			set var${count} -1
			incr count
		}

		set items_upto_20 [join $items_upto_20 ,]
		set sql [subst {
			update tFormRunner
				set key_trainer = "N"
			where ev_oc_id in (
				select
					ev_oc_id
				from
					tEvOc o, tEv e
				where
					e.ev_id = o.ev_id
					and e.start_time >= ?
					and e.start_time < ?
					and trainer in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
					and o.ev_oc_id = ev_oc_id
					and (key_trainer = "Y" or key_trainer is null)
				)
		}]
		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $event_date_s $event_date_e $var0 $var1 $var2 $var3 $var4 $var5 $var6 $var7 $var8 $var9 $var10 $var11 $var12 $var13 $var14 $var15 $var16 $var17 $var18 $var19
		inf_close_stmt $stmt
	}

	msg_bind "The trainer has been successfully updated"
	go_jockey_trainer $event_date

}



#
# 'Bucketises' a list into 3-column rows
# Input: num_items - number of items in the list
# Output: an array of rows
#
proc bucketise_jockeys {num_items {num_columns 3.0}} {

	set buckets      [list]
	set rev_buckets  [list]
	set max_col      0

	# max length of a column
	set max_v [expr {int(ceil($num_items/$num_columns))}]

	set j 0
	set bucket [list]


	# divide all items into columns
	for {set i 0} {$i < $num_items} {incr i} {
		lappend bucket $i
		# reset j at the end of the column
		if { $j == [expr {$max_v-1}] || $i == [expr {$num_items -1}] } {
			set j -1
			lappend buckets $bucket
			# keep track of the longest column
			if {[llength $bucket] >= $max_col} {
				set max_col [llength $bucket]
			}
			set bucket [list]
		}
		incr j
	}

	# group data from the columns into rows
	for {set j 0} {$j < $max_col} {incr j} {
		set row [list]
		for {set i 0} {$i < [llength $buckets]} {incr i} {
			if {[lindex [lindex $buckets $i] $j] != ""} {
				lappend row [lindex [lindex $buckets $i] $j]
			}
		}
		lappend rev_buckets $row
	}
	return $rev_buckets
}

}