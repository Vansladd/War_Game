# ==============================================================
# $Id: hear_about.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::HEARABOUT {

# have to retain GoHearAboutList as the menu-bar expects it...
asSetAct ADMIN::HEARABOUT::GoHearAboutList [namespace code show_isource]
asSetAct ADMIN::HEARABOUT::ChooseSource    [namespace code show_isource]
asSetAct ADMIN::HEARABOUT::GoISource       [namespace code go_isource]
asSetAct ADMIN::HEARABOUT::GoType          [namespace code view_itype]
asSetAct ADMIN::HEARABOUT::GoSource        [namespace code view_isource]

#
# handle returns from the page
#
proc go_isource { args } {
	# pick up the parameter to tell us where to go
	set predicate [reqGetArg SubmitName]

	switch -exact -- $predicate {
		"View iType"    { view_itype }
		"View iSource"  {view_isource}
		"Add iType"     {reqSetArg itype ""
						 view_itype}
		"Add iSource"   {reqSetArg isource ""
						 view_isource}
		"Show Sources"  {show_isource}
		"TypeAdd"       {type_add}
		"TypeMod"       {type_update}
		"TypeDel"       {type_delete}
		"SourceAdd"     {source_add}
		"SourceDel"     {source_delete}
		"SourceUpd"     {source_update}
		"Back"          {show_isource}
		default         {show_isource}
	}

}


#
# ----------------------------------------------------------------------------
# Go to intro source list
# ----------------------------------------------------------------------------
#
proc show_isource { args } {
	# we read from tHearAboutType and tHearAbout
	# and allow updates and creations into both

	# prepare DB requests
	global DB

	set type_sql [subst {
		select hear_about_type,status,desc
		from   tHearAboutType
		order by status
	}]

	# sql is prepared, so start retrieving data and preparing it for display
	catch {unset disp_array}
	global disp_array

	set Type [reqGetArg itype]
	if {![info exists Type] || $Type == "" } { set Type "All types" }
	set Source 0
	set ctype -1

	set stmt [inf_prep_sql $DB $type_sql ]
	set type_rs [inf_exec_stmt $stmt]
	set type_rc [db_get_nrows $type_rs]
	inf_close_stmt $stmt

	OT_LogWrite 8 "rows:$type_rc"
	if {$type_rc < 1} {
		# no types found!
		OT_LogWrite 10 "Found no rows for introductory source types."
		set disp_array(0,type) "No types"
		set disp_array(0,desc) "Nothing to declare!"
		set rows 1
	} else {
		for {set i 0 } { $i < $type_rc } { incr i } {
			set disp_array($i,desc) [db_get_col $type_rs $i desc]
			set disp_array($i,type) [db_get_col $type_rs $i hear_about_type]
			if {[string compare $disp_array($i,type) $Type] == 0 } {
				set ctype $i
			}
		}
		set disp_array($i,type) "All types"
		set disp_array($i,desc) "Everything under the sun"
		set rows [incr i]
	}


	# we're showing sources as well

	if {$Type == "All types" } {
		set ctype [expr {$rows -1}]
		set source_sql [subst {
			select hear_about,hear_about_type, status,desc
			from   tHearAbout
			group by hear_about_type, hear_about, status, desc
			order by status
		}]
		set stmt [inf_prep_sql $DB $source_sql ]
		set source_rs [inf_exec_stmt $stmt]
	} else {
		set source_sql [subst {
			select hear_about,status,desc
			from   tHearAbout
			where  hear_about_type = ?
			order by status
		}]
		set stmt [inf_prep_sql $DB $source_sql ]
		set source_rs [inf_exec_stmt $stmt $Type]
	}
	set source_rc [db_get_nrows $source_rs]
	inf_close_stmt $stmt

	if {$source_rc < 1} {
		OT_LogWrite 10 "No sources found for type $Type"
		set disp_array(0,source) "No sources"
		set disp_array(0,sdesc)  "No source descriptions"
		set srows 1
	} else {
		for {set i 0 } { $i < $source_rc } { incr i } {
			set disp_array($i,source) [db_get_col $source_rs $i hear_about]
			set disp_array($i,sdesc)  [db_get_col $source_rs $i desc]
		}
		set disp_array($i,source) "All sources"
		set disp_array($i,sdesc)  "Everything there is"
		set srows [incr i]
	}

	set Source 1

	# bind up the array for the page
	tpBindVar iType  disp_array type idx
	tpSetVar numTypes $rows
	tpSetVar cType $ctype

	if {$Source == 1 } {
		tpBindVar iSource disp_array source idx
		tpSetVar SOURCES 1
		tpSetVar numSources $srows
		tpBindString Chosen $Type

	}

	asPlayFile -nocache isource.html
}

proc go_hear_about_list args {

	global DB

	set type [reqGetArg itype]

	if { $type == "" || $type == "All types" } {
		set sql [subst {
			select
				hear_about,
				hear_about_type as type,
				desc,
				channels,
				lang,
				status,
				disporder
			from
				tHearAbout
			order by
				type, disporder asc, hear_about asc
		}]
	} else {
		set sql [subst {
			select hear_about,
				   hear_about_type as type,
				   desc,
				   channels,
				   lang,
				   status,
				   disporder
			from
				   thearAbout
			where  hear_about_type = '$type'
			order by disporder asc, hear_about asc
		}]
	}


	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	set rows [db_get_nrows $res]
	inf_close_stmt $stmt

	tpSetVar NumHearAbout [db_get_nrows $res]

	if { $type == "" || $type == "All types" } {
		set type "all types"
		tpSetVar ShowTypes 1
	} else {
		tpSetVar ShowTypes 0
	}

	tpBindString Maintype $type
	tpBindTcl Code			    sb_res_data $res hear_about_idx hear_about
	tpBindTcl Description       sb_res_data $res hear_about_idx desc
	tpBindTcl Channels			sb_res_data $res hear_about_idx channels
	tpBindTcl Disporder		    sb_res_data $res hear_about_idx disporder
	tpBindTcl Status            sb_res_data $res hear_about_idx status
	tpBindTcl Type              sb_res_data $res hear_about_idx type
	tpBindTcl Language          sb_res_data $res hear_about_idx lang

	global Status
	for { set i 0 } { $i < $rows} { incr i } {
		if { [db_get_col $res $i status] == "A" } {
			set Status($i,row) "active"
		} else {
			set Status($i,row) "suspended"
		}
	}
	tpBindVar Colour Status row hear_about_idx

	asPlayFile -nocache hear_about_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Go to single Intro Source add/update
# ----------------------------------------------------------------------------
#
proc view_isource args {

	global DB

	set source [reqGetArg isource]
	set type   [reqGetArg itype]

	if { $source == "All sources" } {
		go_hear_about_list
		return
	}
	foreach {n v} $args {
		set $n $v
	}

	tpBindString HearAboutCode $source
	tpSetVar Type $type

	if {$source == ""} {

		tpSetVar opAdd 1
		make_channel_binds  "" - 1
		make_language_binds "" - 1

		#
		# Get type list
		#
		set t_sql [subst {
			select hear_about_type from tHearAboutType
		}]
		set t_stmt [inf_prep_sql $DB $t_sql]
		set t_res  [inf_exec_stmt $t_stmt]
		inf_close_stmt $t_stmt

		global typeArray
		for {set i 0 } {$i < [db_get_nrows $t_res]} { incr i } {
			set typeArray($i,typ) [db_get_col $t_res $i hear_about_type]
		}
		tpBindVar Type typeArray typ idx
		tpBindString HearAboutDisporder 0
		tpSetVar TC [db_get_nrows $t_res]
		OT_LogWrite 8 "[tpGetVar TC] rows in typeArray"
		db_close $t_res


	} else {

		tpSetVar opAdd 0

		#
		# Get Intro Source information
		#
		set sql [subst {
			select
				hear_about,
				hear_about_type as type,
				desc,
				channels,
				disporder,
				status,
				lang
			from
				tHearAbout
			where
				hear_about = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $source]
		inf_close_stmt $stmt

		tpBindString HearAboutCode 	  	  	   [db_get_col $res 0 hear_about]
		tpBindString HearAboutDescription      [db_get_col $res 0 desc]
		tpBindString HearAboutDisporder		   [db_get_col $res 0 disporder]
		tpBindString Status                    [db_get_col $res 0 status]

		make_channel_binds [db_get_col $res 0 channels] -
		make_language_binds [db_get_col $res 0 lang] -

		db_close $res
	}

	asPlayFile -nocache hear_about.html
}


#
# view_itype
#
# Desc: allow the addition/modification of an Introductory Source Type
#       i.e. show everything needed to allow a row to be added to
#       tHearAboutType.
#
proc view_itype { args } {

	global DB

	set type [reqGetArg itype]
	if { $type == "All types" } {
		tpBindString iErr "Types must be viewed and modified individually!"
		tpSetVar Errors 1
		show_isource
		return
	}

	foreach {n v} $args {
		set $n $v
	}

	tpBindString HearAboutType $type

	if {$type == ""} {
		# add new type
		tpSetVar opAdd 1
		make_channel_binds  "" - 1
		make_language_binds "" - 1

	} else {
		# modify existing type
		tpSetVar opAdd 0

		#
		# Get Type information
		#
		set sql [subst {
			select
				hear_about_type as type,
				desc,
				channels,
				disporder,
				status,
				lang
			from
				tHearAboutType
			where
				hear_about_type = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $type]
		inf_close_stmt $stmt

		tpBindString Type 	  	  	   [db_get_col $res 0 type]
		tpBindString Description       [db_get_col $res 0 desc]
		tpBindString Disporder		   [db_get_col $res 0 disporder]
		tpBindString Status            [db_get_col $res 0 status]

		make_channel_binds [db_get_col $res 0 channels] -
		make_language_binds [db_get_col $res 0 lang] -

		db_close $res
	}

	asPlayFile -nocache itype.html
}

proc source_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsHearAbout(
			p_adminuser = ?,
			p_type = ?,
			p_hear_about = ?,
			p_desc = ?,
			p_channels = ?,
			p_disporder = ?,
			p_status = ?,
			p_language = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg HearAboutType]\
			[reqGetArg HearAboutCode]\
			[reqGetArg HearAboutDescription]\
			[make_channel_str]\
			[reqGetArg HearAboutDisporder]\
			[reqGetArg Status]\
			[make_language_str] ]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	}

	show_isource
}

proc source_update args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdHearAbout(
		   p_adminuser = ?,
			p_hear_about = ?,
			p_desc = ?,
			p_channels = ?,
			p_disporder = ?,
			p_status = ?,
			p_language = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0


	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg HearAboutCode]\
			[reqGetArg HearAboutDescription]\
			[make_channel_str]\
			[reqGetArg HearAboutDisporder]\
			[reqGetArg Status]\
			[make_language_str] ]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_hear_about
		return
	}
	go_hear_about_list
}

proc source_delete args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelHearAbout(
			p_adminuser = ?,
			p_hear_about= ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg HearAboutCode]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_hear_about
		return
	}

	go_hear_about_list
}

proc type_add { args } {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsHearAboutType(
			p_adminuser = ?,
			p_type = ?,
			p_desc = ?,
			p_channels = ?,
			p_disporder = ?,
			p_status = ?,
			p_language = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg Type]\
			[reqGetArg Description]\
			[make_channel_str]\
			[reqGetArg Disporder]\
			[reqGetArg Status]\
			[make_language_str] ]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	}

	show_isource


}

proc type_update { args } {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdHearAboutType(
		   p_adminuser = ?,
			p_type = ?,
			p_desc = ?,
			p_channels = ?,
			p_disporder = ?,
			p_status = ?,
			p_language = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0


	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg Type]\
			[reqGetArg Description]\
			[make_channel_str]\
			[reqGetArg Disporder]\
			[reqGetArg Status]\
			[make_language_str] ]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_hear_about
		return
	}

	show_isource
}

proc type_delete { args } {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelHearAboutType(
			p_adminuser = ?,
			p_type      = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg Type]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_hear_about
		return
	}

	show_isource

}


}
