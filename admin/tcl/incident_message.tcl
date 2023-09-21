# ==============================================================
# $Id: incident_message.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TB_INCIDENTS {

asSetAct ADMIN::INCIDENT_MESSAGE::GoIncidentMessages      [namespace code go_incidents_messages]
asSetAct ADMIN::INCIDENT_MESSAGE::DoIncidentMessages      [namespace code do_incidents_messages]

proc go_incidents_messages {} {
	global DB
	global INCIDENTS

	set sql {
		select
			sentence_id as id,
			short_desc as name,
			full_txt as text
		from
			tXSysSyncIncidentSentences
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt]
	set nrows [db_get_nrows $rs]

	# Grab all the message definitons.
	for {set i 0} {$i < $nrows} {incr i} {
		set INCIDENTS($i,id)    [db_get_col $rs $i id]
		set INCIDENTS($i,name)  [db_get_col $rs $i name]

		# Cap the max length of the sentence to 40 in view screen.
		set i_text [db_get_col $rs $i text]
		if {[string length $i_text] > 40} {
			set INCIDENTS($i,text)  "[string range $i_text 0 40]..."
		} else {
			set INCIDENTS($i,text)  $i_text
		}
	}

	db_close $rs

	# Bind.
	tpSetVar num_incidents $nrows
	tpBindVar id       INCIDENTS id      idx
	tpBindVar name     INCIDENTS name    idx
	tpBindVar text     INCIDENTS text    idx

	# Play.
	asPlayFile -nocache view_incident_message.html
}

proc go_upd_incident_message {id} {
	global DB
	global INCIDENT

	# If is 
	if {$id != ""} {
		set sql {
			select
				sentence_id as id,
				short_desc as name,
				full_txt as text
			from
				tXSysSyncIncidentSentences
			where
				sentence_id = ?
		}
	
		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt $id]

		if {![db_get_nrows $rs]} {
			error "Message with id: $id, doesn't exist"
		}

		# Bind
		tpBindString id   [db_get_col $rs 0 id]
		tpBindString name [db_get_col $rs 0 name]
		tpBindString text [db_get_col $rs 0 text]

		db_close $rs
	}

	# Play.
	asPlayFile -nocache upd_incident_message.html
}

proc del_incident_message {id} {
	global DB

	set sql {
		delete from
			tXSysSyncIncidentSentences
		where
			sentence_id = ?
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $id]
	db_close $rs

	# Play
	go_incidents_messages
}

proc upd_incident_message {id} {
	global DB
	global INCIDENT

	set name [reqGetArg name]
	set text [reqGetArg text]

	if {$id != ""} {
		set sql {
			update
				tXSysSyncIncidentSentences
			set
				short_desc    = ?,
				full_txt      = ?
			where
				sentence_id = ?
		}
	} else {
		set sql {
			insert into tXSysSyncIncidentSentences (
				short_desc,
				full_txt
			) values (
				?, ?
			)
		}
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $name $text $id]
	db_close $rs

	# Play
	go_incidents_messages
}


proc do_incidents_messages {} {
	set id [reqGetArg id]
	if {[catch {
		switch -- [reqGetArg SubmitName] {
			UpdSentence {
				upd_incident_message $id
			}
			AddSentence {
				go_upd_incident_message $id
			}
			DelSentence {
				del_incident_message $id
			}
			Back -
			default {
				go_incidents_messages
			}
		}
	} msg]} {
		err_bind "An error occured, msg: $msg"
	}
}

# End namespace
}
