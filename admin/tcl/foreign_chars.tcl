# ==============================================================
# $Id: foreign_chars.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::FOREIGN_CHARS {

asSetAct ADMIN::FOREIGN_CHARS::GoForeignCharList [namespace code go_foreign_char_list]
asSetAct ADMIN::FOREIGN_CHARS::DoForeignChar     [namespace code do_foreign_char]

#
# ----------------------------------------------------------------------------
# Go to foreign characters list
# ----------------------------------------------------------------------------
#
proc go_foreign_char_list args {

	global DB

	set sql [subst {
		select
			character_id,
			unicode_char,
			normalised_char,
			pending_char
		from
			tUnicodeNormalisation
		order by
			normalised_char
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumForeignChars [db_get_nrows $res]

	tpBindTcl CharacterID    sb_res_data $res foreign_chars_idx character_id
	tpBindTcl UnicodeChar    sb_res_data $res foreign_chars_idx unicode_char
	tpBindTcl NormalisedChar sb_res_data $res foreign_chars_idx normalised_char
	tpBindTcl PendingChar    sb_res_data $res foreign_chars_idx pending_char

	asPlayFile -nocache foreign_char_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Go/Do foreign characters insert/update
# ----------------------------------------------------------------------------
#
proc do_foreign_char args {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_foreign_char_list
		return
	}

	if {![op_allowed AllowUnicodeUpdates]} {
		err_bind "You do not have permission to update foreign character information"
		go_foreign_char_list
		return
	}

	if {$act == "GoCharAdd"} {
		go_foreign_char_add
	} elseif {$act == "GoCharUpd"} {
		go_foreign_char_upd
	} elseif {$act == "DoCharAdd"} {
		do_foreign_char_add
	} elseif {$act == "DoCharUpd"} {
		do_foreign_char_upd
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc go_foreign_char_add args {

	tpSetVar opAdd 1

	asPlayFile -nocache foreign_char.html

}

#
#	Plays the foreign char page in update mode
#
#	Rew Args :-
#		CharacterID
#			Index from tCuniCodeNormalisation
#
proc go_foreign_char_upd args {

	global DB

	set character_id [reqGetArg CharacterID]

	set sql [subst {
		select
			unicode_char,
			normalised_char,
			pending_char
		from
			tUnicodeNormalisation
		where
			character_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $character_id]
	inf_close_stmt $stmt

	tpBindString CharacterID    $character_id
	tpBindString UnicodeChar    [db_get_col $res 0 unicode_char]
	tpBindString NormalisedChar [db_get_col $res 0 normalised_char]
	tpBindString PendingChar    [db_get_col $res 0 pending_char]

	db_close $res

	tpSetVar opAdd 0

	asPlayFile -nocache foreign_char.html

}

#
#	Adds a new letter to the mapping table
#
#	Req Args :-
#		UniCodeChar
#			Uni Code Characater to assign character to
#		PendingChar
#			New Character that we are adding to the db
#
proc do_foreign_char_add args {

	global DB

	set unicode_char [reqGetArg UnicodeChar]

	if {[regexp {[\x20-\x7E]} $unicode_char]} {
		err_bind "ASCII characters are not allowed in unicode field"
		go_foreign_char_add
		return
	}

	set sql [subst {
		insert into tUnicodeNormalisation (
			unicode_char,
			pending_char
		) values (
			?, ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$unicode_char\
			[reqGetArg PendingChar]]} msg]} {
		err_bind $msg
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	go_foreign_char_list
}

#
#	Update an existing translation
#
#	Req Args :-
#		NormalisedChar
#			Existing normalised char
#		PendingChar
#			Char that we are wishging to assign
#		UnicodeChar
#			The unicode char to assign letter to
#
proc do_foreign_char_upd args {

	global DB

	if {[reqGetArg NormalisedChar] == [reqGetArg PendingChar]} {
		# reset pending character
		set pending ""
	} elseif {[reqGetArg NormalisedChar] == "" && [reqGetArg PendingChar] == [reqGetArg UnicodeChar]} {
		# pointless setting the pending char in this case
		go_foreign_char_list
		return
	} else {
		set pending [reqGetArg PendingChar]
	}

	set sql [subst {
		update tUnicodeNormalisation set
			pending_char = ?
		where
			character_id = ?
	}]

	set char_id [reqGetArg CharacterID]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {
		set res [inf_exec_stmt $stmt\
			$pending\
			$char_id]} msg]} {
		err_bind $msg
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	go_foreign_char_list
}

}
