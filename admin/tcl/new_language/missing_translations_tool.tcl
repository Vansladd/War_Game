# $Id: missing_translations_tool.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# Changes the configuration that will be used in the next run of the missing 
# translations tool. Also will show the result of the last run of the tool



# Action Handlers
namespace eval ::ADMIN::MISSING_TRANSLATION_TOOL {
	package require csv

	# Show the page 
	asSetAct ADMIN::MISSING_TRANSLATION_TOOL::GoMissingXlations    \
		[namespace code {go_missing_xlations}]

	# Csv operations
	asSetAct ADMIN::MISSING_TRANSLATION_TOOL::DownloadCSVFile      \
		[namespace code {download_csv_file}]
	
	asSetAct ADMIN::MISSING_TRANSLATION_TOOL::UploadCSVFile        \
		[namespace code {upload_csv_file}]
	
	asSetAct ADMIN::MISSING_TRANSLATION_TOOL::DelCSVFile           \
		[namespace code {delete_csv_file}]
	
	asSetAct ADMIN::MISSING_TRANSLATION_TOOL::ParseCSVFile         \
		[namespace code {parse_csv_file}]
	
	asSetAct ADMIN::MISSING_TRANSLATION_TOOL::ProcessCSVFile       \
		[namespace code {process_csv_file}]

	# Set config for the next execution of the missing translations tool
	asSetAct ADMIN::MISSING_TRANSLATION_TOOL::NextRunConfig        \
		[namespace code {next_run_config}]
	
	# Reset the configuration of the missing translations tool
	asSetAct ADMIN::MISSING_TRANSLATION_TOOL::ResetMissingTransCfg \
		[namespace code {reset_missing_translations_cfg}]

}



#==============================================================================
# Internal procedures
#==============================================================================



#
# Compares two files by creation date (uses descending order)
#
proc sort_by_mtime {a b} {

	global U_FILES

	if {$U_FILES($a) < $U_FILES($b)} {
		return 1
	} elseif {$U_FILES($a) > $U_FILES($b)} {
		return -1
	} else {
		set a_name [file tail $a]
		set b_name [file tail $b]
		return [string compare $a_name $b_name]
	}
}



# _get_language_groups --
#
#       Get the groups of active langs and the list of 
#       not grouped active languages.
#
# Results:
#       Result stored in the next variables that will be used in other procs:
#       LANG_GROUPS: Groups of languages. Each group has: 
#                    Name & Full/Partial translation flag & Langs(name and id)
#       grp_idx:Number of groups
#       NON_GROUPED_LANGS: Only non grouped langs can form a new group
#       not_grouped_idx: Number of non grouped languages

proc ADMIN::MISSING_TRANSLATION_TOOL::_get_language_groups {} {

	global DB

	global LANG_GROUPS
	global NON_GROUPED_LANGS

	variable grp_idx
	variable not_grouped_idx

	catch {unset LANG_GROUPS}
	catch {unset NON_GROUPED_LANGS}

	# Get the current configuration for the missing translation tool
	set lang_groups_sql {
		select
			v.site_lang_id      lang_id,
			v.value             group_name,
			c.lang              lang_name,
		 	NVL(v2.value,0) as  full_trans
		from
			tSiteLangVal v,
			tSiteLangCfg c,
		 	outer tSiteLangVal v2
		where
			v.type = "NAME_LANG_GROUPS" and
		 	v2.type = "FULL_TRANSLATION" and
			c.lang in (
			 	select
			 		lang
			 	from
			 		tlang
			 	where
					status = 'A'
			) and
			c.site_lang_id = v.site_lang_id and
		 	v.site_lang_id = v2.site_lang_id
		order by
			v.value
	}

	# The query returns the rows ordered by the name of the group
	set stmt            [inf_prep_sql $DB $lang_groups_sql]
	set res             [inf_exec_stmt $stmt]
	set n_rows          [db_get_nrows $res]
	inf_close_stmt      $stmt

	# Index of groups
	set grp_idx         0

	# Number of languages per group
	set lang_list_idx   0

	# Number of languages not grouped
	set not_grouped_idx 0

	# Name of the group being processed
	set group_name      [db_get_col $res 0 group_name]

	# Init first group parameters
	set LANG_GROUPS($grp_idx,full_xlated) [db_get_col $res 0 full_trans]
	set LANG_GROUPS($grp_idx,group_name)  $group_name

	for {set i 0} {$i < $n_rows} {incr i} {
		set lang_id                   [db_get_col $res $i lang_id]
		set current_group_name        [db_get_col $res $i group_name]
		set lang_name                 [db_get_col $res $i lang_name]

		# New group (but not the first one)
		if {($current_group_name != $group_name)} {
			# Finish processing the previous group
			set LANG_GROUPS($grp_idx,num_langs) $lang_list_idx

			if {$lang_list_idx == 1} {
				# Previous group has only 1 language. 
				# Add it to the ungrouped list
				set NON_GROUPED_LANGS($not_grouped_idx,id) \
				$LANG_GROUPS($grp_idx,0,lang_id)
				
				set NON_GROUPED_LANGS($not_grouped_idx,name) \
				$LANG_GROUPS($grp_idx,0,lang_name)
				
				incr not_grouped_idx
			}

			# Start processing the new group
			incr grp_idx
			set  group_name $current_group_name
			set  LANG_GROUPS($grp_idx,group_name) $current_group_name

			# Is the group being full translated (default no)
			set LANG_GROUPS($grp_idx,full_xlated) \
				[db_get_col $res $i full_trans]

			# Restart idx for languages per group
			set lang_list_idx 0
		}

		# Add current language to current group
		set LANG_GROUPS($grp_idx,$lang_list_idx,lang_name) $lang_name
		set LANG_GROUPS($grp_idx,$lang_list_idx,lang_id)   $lang_id
		incr lang_list_idx
	}
	
	# End processing the last group out of the loop, to avoid an extra 
	# comparison in every execution of the loop
	set LANG_GROUPS($grp_idx,num_langs) $lang_list_idx

	if {$lang_list_idx == 1} {
		# Last group had only 1 language. Add to the ungrouped list
		set NON_GROUPED_LANGS($not_grouped_idx,id) \
			$LANG_GROUPS($grp_idx,0,lang_id)

		set NON_GROUPED_LANGS($not_grouped_idx,name) \
			$LANG_GROUPS($grp_idx,0,lang_name)

		incr not_grouped_idx
	}

	db_close $res

	# The index of groups is incremented before adding an element. Adjusting
	# the value
	incr grp_idx

}



# _bind_language_groups --
#       Print the languages groups and the list of not grouped languages.

proc ADMIN::MISSING_TRANSLATION_TOOL::_bind_language_groups {} {

	# the variables are filled in _get_language_groups
	global LANG_GROUPS NON_GROUPED_LANGS
	variable grp_idx          ;
	variable not_grouped_idx  ;

	# Build the groups
	_get_language_groups

	# Print Variables
	tpSetVar numGroups          $grp_idx
	tpSetVar numNotGroupedLangs $not_grouped_idx

	tpBindVar GroupName         LANG_GROUPS   group_name  group_idx
	tpBindVar FullTranslated    LANG_GROUPS   full_xlated group_idx
	tpBindVar NumLangs          LANG_GROUPS   num_langs   group_idx
	tpBindVar LangName          LANG_GROUPS   lang_name   group_idx lang_idx
	tpBindVar LangId            LANG_GROUPS   lang_id     group_idx lang_idx

	tpBindVar NoGroupLangId     NON_GROUPED_LANGS  id          no_group_idx
	tpBindVar NoGroupLangName   NON_GROUPED_LANGS  name        no_group_idx

}



# _get_filename --
#
#       Check if the filename already exists
#
# Arguments:
#       filename_param: new file name defined by the admin user
#       list_languages: languages of the group
#       is_upd:         0 if adding a group. 1 in other case (update, delete)
#       old_group_name: name of the group in the DB if is_upd is 1. "" i.o.c
# Results:
#       returns the name of the file or an empty string if an error occurs.

proc ADMIN::MISSING_TRANSLATION_TOOL::_get_filename {filename_param list_languages is_upd old_group_name} {

	global LANG_GROUPS
	variable grp_idx

	# Check if the filename is empty
	if {[catch {
		set filename [ob_chk::get_arg $filename_param \
			-err_msg "The filename needs to be alphanumeric(\"_\" also permited)" \
			ALNUM]
	} msg]} {
		set err_msg "$msg"

		ob_log::write INFO $err_msg
		err_bind $err_msg

		return ""
	}

	# file with just 1 language. No error if the name of the group is the 
	# name of the language
	if { $filename == $list_languages } {
		return $filename
	}

	# No error if the filename didn't change and we are updating/deleting
	if {( $is_upd == 1 ) && ( $filename == $old_group_name )} {
		return $filename
	}

	for {set current_grp 0} {$current_grp < $grp_idx} {incr current_grp} {
		if {$filename == $LANG_GROUPS($current_grp,group_name)} {
			# Name already taken for other group
			set info_msg \
			"Error creating the new group: Filename already exist"

			ob_log::write INFO $info_msg 
			err_bind $info_msg
			return ""
		}
	}

	# File name is valid. No errors
	return $filename
}



# _build_new_group_list --
#
#       Build a list with 2 strings:
#       1st string: comma separated names of the langs for the new group 
#       2nd string: comma separated 'id' of the langs for the new group
#
# Results:
#       Returns the built list. Note First string doesn't have quotes delimiting 
#       the names because of the use

proc ADMIN::MISSING_TRANSLATION_TOOL::_build_new_group_list {} {

	global   NON_GROUPED_LANGS DB
	variable not_grouped_idx

	set langs_list_names ""
	set langs_list_ids ""

	# Get the non grouped langs from the DB
	# _get_language_groups returns only active langs. No need to check here.
	_get_language_groups

	for {set idx 0} {$idx < $not_grouped_idx} {incr idx} {
		set current_lang_id   $NON_GROUPED_LANGS($idx,id)

		set current_lang_req  [ob_chk::get_arg $current_lang_id \
					-on_err 0 \
					{EXACT -args {1}}]

		if {$current_lang_req != 0} {
			# Language will be added to the new group
			ob_log::write DEBUG \
			"Adding lang=$NON_GROUPED_LANGS($idx,name) to the list of languages"

			if {$langs_list_names != ""} {
				append langs_list_names ","

				#At this point langs_list_ids != "" as well
				append langs_list_ids ","
			}
			append langs_list_ids "'$current_lang_id'"
			append langs_list_names "$NON_GROUPED_LANGS($idx,name)"
		}
	}

	return [list $langs_list_names $langs_list_ids]

}



# _build_upd_group_list --
#
#       Build a list with 3 strings, depending on the arguments:
#       If delete_group is 0 the strings will be as follow:
#          1st: comma separated names of the langs to be removed from the group 
#          2nd: comma separated 'id' of the langs to be removed from the group
#          3rd: comma separated 'id' of the langs that will remain in the group
#       If delete_group is 1 the strings will be as follow:
#          1st: comma separated names of the langs of the group
#          2nd: comma separated 'id' of the langs of the group
#          3rd:  Empty
#
# Arguments:
#       group_name     Name of the group stored in the DB
#       delete_group   (optional) Default to 0. 
#                      A group is being ungrouped (value 1) or not (value 0)
# Results:
#       Returns the built list. Note First string doesn't have quotes delimiting 
#       the names because of the use

proc ADMIN::MISSING_TRANSLATION_TOOL::_build_upd_group_list {group_name {delete_group 0}} {

	global DB

	# Get the languages that belongs to the group "group_name"
	set upd_group_sql [subst {
		select
			v.site_lang_id      lang_id,
			c.lang              lang_name
		from
			tSiteLangVal v,
			tSiteLangCfg c
		where
			v.type = "NAME_LANG_GROUPS" and
			v.value = "$group_name" and
			c.lang in (
			 	select
			 		lang
			 	from
			 		tlang
			 	where
					status = 'A'
			) and
			c.site_lang_id = v.site_lang_id
	}]

	set stmt       [inf_prep_sql $DB $upd_group_sql]
	set res        [inf_exec_stmt $stmt]
	set n_rows     [db_get_nrows $res]
	inf_close_stmt $stmt

	# String with the names of the langs to be removed
	set langs_list_names ""

	# String with the ids of the langs to be removed 
	set langs_list_ids   ""

	# String with the ids of the langs that will be kept in the group
	set langs_list_checked_ids ""

	for {set i 0} {$i < $n_rows} {incr i} {
		set current_lang_id     [db_get_col $res $i lang_id]
		set current_lang_name   [db_get_col $res $i lang_name]

		if {$delete_group} {
			set lang_to_keep 0
		} else {
			set current_param $group_name
			set lang_to_keep  [ob_chk::get_arg \
					[append current_param $current_lang_id] \
						-on_err 0 \
						{EXACT -args {1}}]
		}

		if {!$lang_to_keep} {
			# Languages that will form unary groups: The language 
			# doesn't belong to the group anymore.
			ob_log::write DEBUG \
			"Mark lang=$current_lang_name to create a unary group with it"

			if {$langs_list_names != ""} {
				append langs_list_names ","

				#At this point langs_list_ids != "" as well
				append langs_list_ids ","
			}

			append langs_list_ids "'$current_lang_id'"
			append langs_list_names "$current_lang_name"
		} else {
			# The language still belongs to the group
			ob_log::write DEBUG \
			"Mark lang=$current_lang_name to delete full translations"

			if {$langs_list_checked_ids != ""} {
				append langs_list_checked_ids ","
			}

			append langs_list_checked_ids "'$current_lang_id'"
		}
	}

	db_close $res
	return [list $langs_list_names $langs_list_ids $langs_list_checked_ids]

}



# _process_args --
#
#       Read request parameters for add/upd/delete a group and manage errors
#
# Arguments:
#       action   Indicates if a group is being added (value AddGroup),
#                updated (UpdGroup) or deleted (DeleteGroup)
# Results:
#        Returns a list with the request parameter values

proc ADMIN::MISSING_TRANSLATION_TOOL::_process_args {action} {

	# Prefix added to the parameters of the forms. If we are adding a group
	# old_group_name will be empty, but if we are updating|delting a group
	# old_group_name is the name that the group has currently in the DB
	set old_group_name [reqGetArg groupName]

	if {( $action != "AddGroup" ) && ( $old_group_name == "" )} {
		set info_msg \
		"The filename needs to be alphanumeric(\"_\" also permited)"

		ob_log::write INFO $info_msg 
		err_bind $info_msg
		return [list]
	}

	# Check if group is full translated
	set full_translated_param $old_group_name

	set full_xlated [ob_chk::get_arg \
			[append full_translated_param "fullTranslation"] \
			-on_err 0 \
			{EXACT -args {1}}]


	set langs_list_names ""
	set langs_list_ids   ""
	set langs_list_checked_ids ""

	# Zero if we are adding a group
	set is_upd 0

	switch $action {
		"AddGroup"    {
			foreach  {langs_list_names langs_list_ids} \
				[_build_new_group_list] {break}

			if {$langs_list_ids == ""} {
				set info_msg \
				"Error processing the group: No languages selected"

				ob_log::write INFO $info_msg 
				err_bind $info_msg
				return [list]
			}
		} 
		"UpdGroup"    {
			set is_upd 1

			foreach  {langs_list_names \
					langs_list_ids langs_list_checked_ids} \
					[_build_upd_group_list $old_group_name] {
				break
			}
			
			if {$langs_list_checked_ids == ""} {
				set info_msg \
				"Error updating the group: No languages left selected"

				ob_log::write INFO $info_msg
				err_bind $info_msg
				return [list]
			}
		}
		"DeleteGroup" {
			set is_upd 1

			foreach  {langs_list_names \
					langs_list_ids langs_list_checked_ids} \
					[_build_upd_group_list $old_group_name 1] {
				break
			}

			# langs_list_names should have all the langs of the group
			if {$langs_list_names == ""} {
				# This should never happen
				set error_msg \
				"Error deleting the group: Unable to find the languages of the group"

				ob_log::write ERROR $error_msg
				err_bind $error_msg
				return [list]
			}
		}
	}


	# Check filename

	# Avoid to overwrite the value of old_group_name when append is used
	set old_group_name_param $old_group_name

	set filename [_get_filename \
	 		[append old_group_name_param "langGroupName"] \
	 		$langs_list_names \
	 		$is_upd \
	 		$old_group_name]

	if {$filename == ""} {
		# There has been an error. Error_msg is printed in _get_filename
		return [list]
	}
	
	if {( $action == "UpdGroup" ) && ( $langs_list_names == "" ) \
					&& ( $filename == $old_group_name )} {
		# Check if full translated parameter has changed
		set full_translated_param $old_group_name

		set full_xlated_upd [ob_chk::get_arg isFullXlated \
			-on_err 0 \
			{EXACT -args {1}}]

		if {$full_xlated_upd == $full_xlated} {
			# Error, nothing has been modified in the form
			set info_msg "Update group: No changes made"
			ob_log::write INFO $info_msg
			err_bind $info_msg
			return [list]
		}
	}

	switch $action {
		"AddGroup"    {
			return [list $filename $full_xlated $langs_list_ids]
		} 
		default {
			# UpdGroup or DeleteGroup
			return [list $old_group_name \
			 	$filename \
			 	$full_xlated \
			 	$langs_list_names \
			 	$langs_list_ids \
			 	$langs_list_checked_ids]
		}
	}

}



# _add_group_languages --
#
#       Add a new group of languages into the database
#
# Arguments:
#       arg_list   List of request parameter values: 
#                  name of the new group (alphanumeric or _ characters only)
#                  full translated group flag (values 0 or 1)  
#                  new_group_list_ids Ids of the languages of the group
# Results:
#       The new group details are stored in the database if there is no errors
#       while executing the queries. Returns to the missing translations page
#       showing a success|error message.

proc ADMIN::MISSING_TRANSLATION_TOOL::_add_group_languages {arg_list} {

	# Variables are filled in _get_language_groups
	global DB

	# Read params
	foreach {filename full_xlated new_group_list_ids} $arg_list {break}

	# Delete the full translations info for the languages that has been grouped
	ob_log::write INFO "MISSING_TRANSLATION_TOOL:Delete info for the old groups"

	set delete_full_xlation_sql [subst {
		delete from
			tSiteLangVal
		where
			type  = "FULL_TRANSLATION" and
			site_lang_id in ($new_group_list_ids)
	}]

	if {[catch {
		set delete_full_xlation_stmt \
			[inf_prep_sql $DB $delete_full_xlation_sql]

		set delete_full_xlation_res  \
			[inf_exec_stmt $delete_full_xlation_stmt]

		inf_close_stmt               $delete_full_xlation_stmt
		db_close                     $delete_full_xlation_res
	} msg]} {
		catch {inf_close_stmt        $delete_full_xlation_stmt}
		catch {db_close              $delete_full_xlation_res}

		set err_msg \
		"Error trying to remove the configuration of the old groups: $msg"

		err_bind    \
		"Group has not been created $err_msg"

		ob_log::write ERROR "Group has not been created $err_msg"

		go_missing_xlations
		return
	}

	# Insert the new group
	ob_log::write INFO "MISSING_TRANSLATION_TOOL:Inserting new group $filename"
	set add_group_sql [subst {
		update
			tSiteLangVal
		set
			value = '$filename'
		where
			type = "NAME_LANG_GROUPS" and
			site_lang_id in ($new_group_list_ids)
	}]


	if {[catch {
		set add_group_stmt    [inf_prep_sql $DB $add_group_sql]
		set add_group_res     [inf_exec_stmt $add_group_stmt]
		inf_close_stmt        $add_group_stmt
		db_close              $add_group_res
	} msg]} {
		catch {inf_close_stmt $add_group_stmt}
		catch {db_close       $add_group_res}

		set error_msg "Error creating the new group: $msg"
		err_bind $error_msg
		ob_log::write ERROR $error_msg
		go_missing_xlations
		return
	}

	# Insert full translation parameter if the group is full translated
	if {$full_xlated == 1} {
		ob_log::write INFO \
		"MISSING_TRANSLATION_TOOL:Inserting full translation parameter for $filename"

		set full_xlated_sql [subst {
			insert into 
				tsitelangval(
				 	site_lang_id,
				 	type,
				 	value,
				 	disporder
				) select site_lang_id,
				 	"FULL_TRANSLATION",
				 	1,
				 	0
				from 
					tSiteLangCfg 
				where 
					tSiteLangCfg.site_lang_id in ($new_group_list_ids)
		}]

		if {[catch {
			set full_xlated_stmt  [inf_prep_sql $DB $full_xlated_sql]
			set full_xlated_res   [inf_exec_stmt $full_xlated_stmt]
			inf_close_stmt        $full_xlated_stmt
			db_close              $full_xlated_res
		} msg]} {
			catch {inf_close_stmt $full_xlated_stmt}
			catch {db_close       $full_xlated_res}

			set error_msg \
			"Error inserting full translation value for the new group: $msg"

			err_bind $error_msg
			ob_log::write ERROR $error_msg

			go_missing_xlations
			return
		}
	}

	set success_msg "Group $filename Successfully created"
	msg_bind $success_msg
	ob_log::write INFO $success_msg

	go_missing_xlations
	return

}



# _upd_group_languages --
#
#       Update or delete a group of languages stored the database. When a group
#       of languages is deleted, a new group is created per each language of 
#       the group. That's why the action is referred as ungroup
#
# Arguments:
#       arg_list     List of request parameter values:
#                    1. Name of the group in the database
#                    2. Name of the new group (alphanumeric or _ characters only)
#                    3. Full translated group flag (values 0 or 1)
#                    4. Names of the languages to be removed of the group (all 
#                       of the langs of the group if a group is being deleted)
#                    5. Ids of the languages to be removed of the group (all of 
#                       the langs of the group if if a group is being deleted)
#                    6. Ids of the languages to be kept in the group (Empty if 
#                       a group is being deleted
#       delete_group (optional) Default to 0. 
#                    A group is being ungrouped (value 1) or not (value 0)
# Results:
#       If there is no errors while executing the queries, the group details 
#       will be updated|ungrouped in the database. Returns to the missing 
#       translations page showing a success|error message.

proc ADMIN::MISSING_TRANSLATION_TOOL::_upd_group_languages {arg_list {delete_group 0}} {

	global DB

	# Read params
	foreach {old_filename \
		new_filename \
		full_xlated \
		langs_group_names \
		langs_group_ids \
		langs_list_checked_ids} $arg_list {
			break
	}

	# Delete the full translations info for the langs of the old group
	ob_log::write INFO \
		"MISSING_TRANSLATION_TOOL:Delete info for the old groups"

	
	set langs_old_group_ids ""

	if {$langs_list_checked_ids == ""} {
		set langs_old_group_ids $langs_group_ids
	} elseif {$langs_group_ids == ""} {
		set langs_old_group_ids $langs_list_checked_ids
	} else {
		set langs_old_group_ids \
			[subst $langs_group_ids,$langs_list_checked_ids]
	}

	if {$langs_old_group_ids == ""} {
		# This should never happen
		set error_msg "Unable to get the languages of the group"
		ob_log::write ERROR $error_msg
		err_bind $error_msg
		return
	}

	set delete_full_xlation_sql [subst {
		delete from
			tSiteLangVal
		where
			type  = "FULL_TRANSLATION" and
			site_lang_id in ($langs_old_group_ids)
	}]

	if {[catch {
		set delete_full_xlation_stmt \
			[inf_prep_sql $DB $delete_full_xlation_sql]

		set delete_full_xlation_res  \
			[inf_exec_stmt $delete_full_xlation_stmt]

		inf_close_stmt               $delete_full_xlation_stmt
		db_close                     $delete_full_xlation_res
	} msg]} {
		catch {inf_close_stmt        $delete_full_xlation_stmt}
		catch {db_close              $delete_full_xlation_res}

		set err_msg \
		"Error trying to remove the configuration of the old groups: $msg"

		err_bind    "Group has not been updated $err_msg"
		ob_log::write ERROR "Group has not been updated $err_msg"

		go_missing_xlations
		return
	}

	# Update the list of languages. Remove the unchecked languages from the group
	# If a group is being deleted, Remove all the languages from the group
	set lang_names_list [split $langs_group_names ,]
	set lang_ids_list   [split $langs_group_ids ,]

	set lang_id_index 0
	
	foreach lang_name $lang_names_list {
		set current_idx [lindex $lang_ids_list $lang_id_index]

		set ungroup_langs_sql [subst {
			update
				tSiteLangVal
			set
				value = "$lang_name"
			where
				type = "NAME_LANG_GROUPS" and
				value = "$old_filename" and
				site_lang_id = $current_idx
		}]


		if {[catch {
			set ungroup_langs_stmt \
				[inf_prep_sql $DB $ungroup_langs_sql]

			set ungroup_langs_res  \
				[inf_exec_stmt $ungroup_langs_stmt]

			inf_close_stmt         $ungroup_langs_stmt
			db_close               $ungroup_langs_res
		} msg]} {
			catch {inf_close_stmt  $ungroup_langs_stmt}
			catch {db_close        $ungroup_langs_res}

			set error_msg \
			"Error while updating the group. $lang_id_index langs changed: $msg"

			err_bind $error_msg
			ob_log::write ERROR  $error_msg
			go_missing_xlations
			return
		}

		incr lang_id_index
	}

	# Update the name of the group, if needed, if it is not being deleted.
	if {( $delete_group == 0 ) && ( $old_filename != $new_filename )} {
		ob_log::write INFO \
		"MISSING_TRANSLATION_TOOL:Inserting new group $new_filename"

		set upd_filename_sql [subst {
			update
				tSiteLangVal
			set
				value = '$new_filename'
			where
				type = "NAME_LANG_GROUPS" and
				value = '$old_filename'
		}]
	
	
		if {[catch {
			set upd_filename_stmt \
				[inf_prep_sql $DB $upd_filename_sql]

			set upd_filename_res  \
				[inf_exec_stmt $upd_filename_stmt]

			inf_close_stmt        $upd_filename_stmt
			db_close              $upd_filename_res
		} msg]} {
			catch {inf_close_stmt $upd_filename_stmt}
			catch {db_close       $upd_filename_res}

			set error_msg "Error creating the new group: $msg"
			ob_log::write ERROR $error_msg
			err_bind $error_msg
			go_missing_xlations
			return
		}

	}

	# Update the full translation flag of the group, if needed, if it is 
	# not being deleted.
	if {( $delete_group == 0 ) && ( $full_xlated == 1 )} {
		ob_log::write INFO \
		"MISSING_TRANSLATION_TOOL:Inserting full translation parameter for $new_filename"

		set full_xlated_sql [subst {
			insert into 
				tsitelangval(
				 	site_lang_id,
				 	type,
				 	value,
				 	disporder
				) select site_lang_id,
				 	"FULL_TRANSLATION",
				 	1,
				 	0
				from 
					tSiteLangVal 
				where 
					value = "$new_filename" and
					type  = "NAME_LANG_GROUPS"
		}]

		if {[catch {
			set full_xlated_stmt [inf_prep_sql $DB $full_xlated_sql]
			set full_xlated_res  [inf_exec_stmt $full_xlated_stmt]
			inf_close_stmt     $full_xlated_stmt
			db_close           $full_xlated_res
		} msg]} {
			catch {inf_close_stmt $full_xlated_stmt}
			catch {db_close       $full_xlated_res}

			set error_msg \
			"Error inserting full translation flag for the new group: $msg"

			ob_log::write ERROR $error_msg
			err_bind $error_msg
			go_missing_xlations
			return
		}
	}

	# Success messages
	if {$delete_group} {
		set success_msg "Group $new_filename Successfully Ungrouped"
	} else {
		set success_msg "Group $new_filename Successfully Updated"
	}

	msg_bind $success_msg
	ob_log::write INFO $success_msg

	go_missing_xlations
	return

}



#==============================================================================
# Action Handlers 
#==============================================================================



# go_missing_xlations --
#
#       Display the page where you can configure "missing translations" tool, or 
#       manage the csv translations files

proc ADMIN::MISSING_TRANSLATION_TOOL::go_missing_xlations {} {

	global LANGS
	global LANG_MAP
	global U_FILES
	global S_FILES
	global FILES

	if {[info exists U_FILES]} {unset U_FILES}
	if {[info exists S_FILES]} {unset S_FILES}
	if {[info exists FILES]}   {unset FILES}

	# Setup language info
	read_language_info
	set lang [reqGetArg Language]

	for {set i 0} {$i < $LANG_MAP(num_langs)} {incr i} {
		set LANGS($i,code) $LANG_MAP($i,code)
		set LANGS($i,name) $LANG_MAP($i,name)
	}

	set LANGS($LANG_MAP(num_langs),code) "-"
	set LANGS($LANG_MAP(num_langs),name) "All"

	tpSetVar NrLangs [expr $LANG_MAP(num_langs) + 1]

	tpBindVar LangCode LANGS code lang_idx
	tpBindVar LangDesc LANGS name lang_idx

	if {$lang == ""} {
		tpBindString Language "-"
	} else {
		tpBindString Language $lang
	}

	# Get files containing translations
	set xlations_dir [OT_CfgGet XLATIONS_DIR]

	if {$lang == "-" || $lang == ""} {
		set files [glob -nocomplain $xlations_dir/*]
	} else {
		set files [glob -nocomplain $xlations_dir/*_${lang}_*]
	}

	foreach f $files {
		file stat $f f_stat
		set U_FILES($f) $f_stat(mtime)
	}

	# Sort the FILES array by creation date
	set S_FILES [lsort -command sort_by_mtime [array names U_FILES]]

	set i 0
	foreach f $S_FILES {
		set FILES($i,full_name) $f
		set FILES($i,name)      [file tail $f]
		set FILES($i,mtime)     [clock format $U_FILES($f) -format "%Y-%h-%d %H:%M:%S"]

		incr i
	}

	tpSetVar  NrFiles $i
	tpBindVar FileName     FILES name      file_idx
	tpBindVar FileFullName FILES full_name file_idx
	tpBindVar FileMtime    FILES mtime     file_idx

	_bind_language_groups
	#bind_config_form
	asPlayFile -nocache new_language/missing_xlations.html
}



# next_run_config --
#
#       Modify the configuration for the next run of the missing translation
#       tool, Adding groups or languages or updating|ungrouping the existing 
#       ones.
#

proc ADMIN::MISSING_TRANSLATION_TOOL::next_run_config {} {

	if {[catch {
		set submitName [ob_chk::get_arg SubmitName \
			-on_err "" \
			-err_msg "The action is not permited" \
			{EXACT -args { "AddGroup" "UpdGroup" "DeleteGroup" }}]
	} msg]} {

		set err_msg "Failed to read the submitName: $msg"
		ob_log::write ERROR "Configure missing translations: $err_msg"
		err_bind $err_msg
		go_missing_xlations
		return
	}

	set args_list [_process_args $submitName]

	if {[llength $args_list] == 0} {

		# There are errors in the request parameters. Error msgs already printed
		go_missing_xlations
		return

	}

	switch $submitName {
		"AddGroup"    {return [_add_group_languages $args_list]}
		"UpdGroup"    {return [_upd_group_languages $args_list]}
		"DeleteGroup" {return [_upd_group_languages $args_list 1]}
	}

}



# reset_missing_translations_cfg --
#
#       Action handler to change the configuration for the next run of the
#       missing translations tool to be the default one

proc ADMIN::MISSING_TRANSLATION_TOOL::reset_missing_translations_cfg {} {
	global DB

	set reset_cfg_sql {
		execute procedure pResetCfgMissingTranslations()
	}


	if {[catch {

		set reset_cfg_stmt [inf_prep_sql $DB $reset_cfg_sql]
		set reset_cfg_res  [inf_exec_stmt $reset_cfg_stmt]
		inf_close_stmt     $reset_cfg_stmt
		db_close           $reset_cfg_res

	} msg]} {

		catch {inf_close_stmt $reset_cfg_stmt}
		catch {db_close       $reset_cfg_res}

		set error_msg \
		"Error trying to reset missing tranlsations tool configuration: $msg"

		ob_log::write ERROR $error_msg
		err_bind $error_msg
		go_missing_xlations
		return

	}

	set success_msg "Configuration successfully reset to default"

	ob_log::write INFO $success_msg

	msg_bind $success_msg

	go_missing_xlations

	return

}

# Download a CSV file containing translations for a language
proc ADMIN::MISSING_TRANSLATION_TOOL::download_csv_file {} {

	global CHARSET

	set filename [reqGetArg filename]

	tpBufAddHdr "Content-Type"  "text/csv; charset=$CHARSET"
	tpBufAddHdr "Content-Disposition" "filename=[file tail $filename];"

	asPlayFile -nocache $filename
}



# Upload a CSV file containing translations for a language
proc ADMIN::MISSING_TRANSLATION_TOOL::upload_csv_file {} {

	global REQ_FILES

	set filename [file rootname [reqGetArg filename]]
	set xlations_dir [OT_CfgGet XLATIONS_DIR]

	ob_log::write INFO "Uploading file $filename to directory: $xlations_dir"

	if {[OT_CfgGet UPLOAD_ALLOW_FILENAME_SPACES 1]} {
		set filename [string map {" " "_"} $filename]
	}

	set filename   "${xlations_dir}/${filename}"
	set num_suffix ""

	if {[file exists "${filename}.csv"]} {
		set i 1
		while {$num_suffix == ""} {

			if {![file exists "${filename}_${i}.csv"]} {
				set num_suffix "_$i"
			}
			incr i
		}
	}

	set filename "${filename}${num_suffix}.csv"

	set err [catch {
		set fp [open $filename w]
	} msg]

	if {$err} {
		err_bind "Failed to write file $filename: $msg"
		go_missing_xlations
		return
	}

	fconfigure $fp -encoding binary

	puts -nonewline $fp $REQ_FILES(filename)
	close $fp

	go_missing_xlations
}




# Delete a CSV file
proc ADMIN::MISSING_TRANSLATION_TOOL::delete_csv_file {} {

	set filename [file tail [reqGetArg filename]]

	set xlations_dir [OT_CfgGet XLATIONS_DIR]
	
	if {![file exists "$xlations_dir/$filename"]} {
		error "File $filename does not exist"
		go_missing_xlations
		return
	}

	ob::log::write INFO "Deleting uploaded translations file: $filename"

	if {[catch {
		file delete "$xlations_dir/$filename"
	} msg]} {
		error "Failed to delete file $filename"
	}

	go_missing_xlations
}

# Parse a CSV file where the fields may contain newlines and returns a list of
# lines.
proc ADMIN::MISSING_TRANSLATION_TOOL::parse_csv_file {filename} {

	global tcl_platform
	set lines [list]

	# Read the file into memory and convert to TCL's internal Unicode representation
	set err [catch {
		set in_file [open $filename r]
	} msg]

	if {$err} {
		err_bind "Failed to open file $filename for reading: $msg"
		return $lines
	}

	# Find the endianness of the file
	set f [open $filename r]
	fconfigure $f -translation binary
	fconfigure $f -encoding binary

	set raw_data [read $f 2]
	close $f

	if {[binary scan $raw_data "H4" bom]} {
		if {$bom == "feff"} {
			set endianness "bigEndian"
		} elseif {$bom == "fffe"} {
			set endianness "littleEndian"
		} else {
			err_bind "File $filename is not valid unicode"
			return $lines
		}
	} else {
		return $lines
	}

	if {$endianness == $tcl_platform(byteOrder)} {
		fconfigure $in_file -encoding unicode

		# Skip the BOM
		read $in_file 1

		set data [read $in_file]
	} else {
		# Read file as binary then swap the bytes around
		fconfigure $in_file -translation binary
		fconfigure $in_file -encoding binary

		# Skip the BOM, which is 2 characters here as we're reading in binary mode
		read $in_file 2

		set raw_data [read $in_file]
		binary scan $raw_data s* elements
		set data [encoding convertfrom unicode [binary format S* $elements]]
	}

	close $in_file

	# Convert all line terminators to Windows terminators for consistency
	set sub_count [regsub -all -- "(\[^\r\])\n" $data "\\1\r\n" new_data]
	set data $new_data

	# Parse the file into a list of lines
	set i 0
	set mode "start"
	set data_len [string length $data]
	set line ""
	set field_str ""

	set quote {"} ; # {"}
	set eol "\r\n"
	set separator "\t"

	while {$i < $data_len} {
		switch -- $mode {
			"start" {
				if {[string index $data $i] == $quote} {
					set mode "quoted"
					incr i
				} else {
					set mode "normal"
				}
			}
			"normal" {
				# It's a normal non-quoted field
				if {[regexp -indices -start $i -- "${separator}|${eol}" $data lrange]} {
					set match_begin [lindex $lrange 0]
					set match_end   [lindex $lrange 1]

					set match_str    [string range $data $match_begin $match_end]
					append field_str [string range $data $i [expr {$match_begin - 1}]]
					set i [expr {$match_end + 1}]

					if {$line == ""} {
						set line "$field_str"
					} else {
						set line "$line\t$field_str"
					}
					set field_str ""

					if {$match_str == $eol} {
						# New line
						lappend lines $line
						set line ""
					}
					set mode "start"
				} else {
					# Reached EOF
					append field_str [string range $data $i end]
					set i $data_len
				}

			}
			"quoted" {
				# It's a quoted string field
				while {1} {
					set string_i [string first $quote $data $i]
					if {$string_i == -1} {
						# Reached EOF
						append field_str [string range $i end]
						set i $data_len
						break
					}
					if {[string index $data [expr {$string_i + 1}]] == $quote} {
						append field_str [string range $data $i $string_i]
						set i [expr {$string_i + 2}]
					} else {
						# Reached end of string
						append field_str [string range $data $i [expr {$string_i - 1}]]
						set i [expr {$string_i + 1}]
						set mode "normal"
						break
					}
				}
			}
		}
	}

	if {$field_str != ""} {
		if {$line == ""} {
			set line "$field_str"
		} else {
			set line "$line\t$field_str"
		}
	}

	if {$line != ""} {
		lappend lines $line
	}

	set lines [encoding convertto utf-8 $lines]

	return $lines
}


# Process a CSV file containing translations for a language
proc ADMIN::MISSING_TRANSLATION_TOOL::process_csv_file {} {

	global DB

	set sql {
		execute procedure pInsXlation (
			p_code = ?,
			p_xlation = ?,
			p_group = ?,
			p_lang = ?
		)
	}

	set filename [reqGetArg filename]
	ob::log::write INFO "Processing uploaded translations file: $filename"

	set lines [parse_csv_file $filename]
	if {[llength $lines] == 0} {
		go_missing_xlations
		return
	}

	# Check the file header
	set header [csv::split [lindex $lines 0] "\t"]
	if {![ADMIN::UPLOAD::upload_val_line "translations" $header 1]} {
		err_bind "Invalid header for file $filename"
		go_missing_xlations
		return
	}

	set nr_loaded 0

	foreach line [lrange $lines 1 end] {

		set data [csv::split $line "\t"]
                if {[llength $data] == 0} {
                        continue
                }

		if {[ADMIN::UPLOAD::upload_val_line "translations" $data]} {
			foreach {code group status english lang trans} $data {}

			if {[catch {
				set stmt [inf_prep_sql $DB $sql]
				set rs   [inf_exec_stmt $stmt $code $trans $group $lang]
				inf_close_stmt $stmt
                                incr nr_loaded
			} msg]} {
				err_bind "Error inserting translation: check file format is correct"
				go_missing_xlations
				return
			}
		} else {
			err_bind "Invalid line in file $filename"
			go_missing_xlations
			return
		}
	}

	ob_log::write INFO "Parsed $nr_loaded translation lines(s) from file $filename"
	msg_bind "Successfully parsed $nr_loaded translation lines(s) from file $filename"

	go_missing_xlations
}



# print_result --
#
#       Debug procedure that prints the array of the group of languages built by 
#       _get_language_groups

proc ADMIN::MISSING_TRANSLATION_TOOL::print_result {} {

	global LANG_GROUPS
	variable grp_idx

	ob_log::write DEBUG "============ GROUP OF LANGUAGES =================="
	for {set debug 0} {$debug < $grp_idx} {incr debug} {

		set debug_group_name    $LANG_GROUPS($debug,group_name)
		set debug_num_lang      $LANG_GROUPS($debug,num_langs)
		set debug_full_xlated   $LANG_GROUPS($debug,full_xlated)

		ob_log::write DEBUG "GROUP NAME=$debug_group_name"
		ob_log::write DEBUG "full translated=$debug_full_xlated"
		ob_log::write DEBUG "number of languages=$debug_num_lang"

		for {set debug2 0} {$debug2 < $debug_num_lang} {incr debug2} {

			ob_log::write DEBUG "language id=$LANG_GROUPS($debug,$debug2,lang_id)*language name=$LANG_GROUPS($debug,$debug2,lang_name)"

		}
	}
	ob_log::write DEBUG "============ END GROUP OF LANGUAGES =============="

}



