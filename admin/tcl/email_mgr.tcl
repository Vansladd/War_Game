# $Id: email_mgr.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $

##
#
# Email Manager
# ----------------------------------------
#
# Purpose
# --------
# The email manager allows admin users to:
#        1. create customer email templates.
#        2. queue emails for sending via a standalone tcl process
#
#
# Database :
# ----------
# The main tables associated with these rules are tEmail, tEmailType,
# tEmailBody and tEmailQueue.
##

##
# PROCEDURES
# __________________________________________________________________
# Procedure               |   Description
# ________________________|_________________________________________
# init                    |  query and variable initialisation.
#
# go_email_list           |  returns a list of email templates
# go_email                |  go to the add/modify email screen
# go_email_body           |  go to the add/modify email body screen
# do_add_email            |  actually add the email
# go_test_email           |  test an email template using the specified user
# do_email_body           |  update an email body. Also handles uploads
# do_email                |  update an email
#
##

namespace eval ADMIN::EMAILS {

ob::log::write INFO {Initialising namespace EMAILS}

asSetAct ADMIN::EMAILS::GoEmailList           [namespace code go_email_list]
asSetAct ADMIN::EMAILS::GoEmail               [namespace code go_email]
asSetAct ADMIN::EMAILS::DoTestEmail           [namespace code do_test_email]
asSetAct ADMIN::EMAILS::GoEmailBody           [namespace code go_email_body]
asSetAct ADMIN::EMAILS::DoAddEmailBody        [namespace code do_email_body]
asSetAct ADMIN::EMAILS::DoTestEmail           [namespace code do_test_email]
asSetAct ADMIN::EMAILS::DoEmail               [namespace code do_email]
asSetAct ADMIN::EMAILS::DoEmailBody           [namespace code do_email_body]

#namespace export go_email_list
#namespace export go_add_email
#namespace export do_add_email
#namespace export go_test_email


##
# EMAILS::init - initialise Email Manager namespace
#
# SYNOPSIS
#
#       [EMAILS::init]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       none
#
# RETURN
#
#       none
#
# DESCRIPTION
#
#       Sets up queries and variables needed in namespace.
#
##
proc init {} {
	ob::log::write INFO {Initialising EMAILS ....}

	#
	# Get all email templates
	#
	
	global SHARED_SQL
		
	set SHARED_SQL(get_all_emails) {
		select unique
			e.email_id,
			e.cr_date,
			e.name,
			t.name type,
			e.status,
			e.channels,
			b.language
		from
			tEmail e,
			tEmailType t,
			outer tEmailBody b
		where
			e.email_id = b.email_id and
			t.type_id = e.type
		order by e.email_id, e.status, e.cr_date
	}

	set SHARED_SQL(get_email_queue) {
		select 
			q.cr_date,
			q.cust_id,
			c.username,
			q.email_id,
			e.name as email_name, 
			q.msg_type 
		from 
			tEmailQueue q,
			tCustomer c,
			tEmail e 
		where 
			q.cust_id = c.cust_id 
			and q.email_id = e.email_id
	}

	set SHARED_SQL(get_internal_email_queue) {
		select
			q.cr_date,
			e.name as email_name,
			q.email_id,
			q.msg_type
		from
			tEmailQueue q,
			tEmail e
		where
			q.email_id = e.email_id

	}

	#
	# Get email details
	#
	set SHARED_SQL(get_single_email_details) {
		select
			e.email_id,
			e.cr_date,
			e.name,
			e.type,
			e.from_code,
			e.email_addr,
			e.status,
			e.channels,
			e.system,
			t.name type_name
		from
			tEmail e,
			tEmailType t
		where
			t.type_id = e.type and
			e.email_id = ?
	}
	
	
	#
	# Get Email Bodies for an email
	# This is per language
	#
	set SHARED_SQL(get_email_body) {
		select unique
			b.email_id,
			b.cr_date,
			b.language,
			b.format
		from
			tEmailBody b
		where
			b.email_id = ?
		order by b.cr_date
	}
	
	#
	# Get Email Body details
	# This is per language per format
	#
	set SHARED_SQL(get_body_details) {
		select
			b.body_id,
			b.email_id,
			b.body_seq_id,
			b.cr_date,
			b.language,
			b.body,
			b.format,
			l.charset,
			b.subject
		from
			tEmailBody b,
			tLang l
		where
			l.lang = b.language and
			b.email_id = ? and
			b.language = ? and
			b.format = ?
		order by b.body_id
	}
	
	# Update Email
	set SHARED_SQL(update_email) {
		execute procedure pUpdEmail(
			p_email_id = ?,
			p_name = ?,
			p_type = ?,
			p_from_code = ?,
			p_system = ?,
			p_status = ?,
			p_channels =?,
			p_email_addr = ?
		)
	}
	
	# Update Email
	set SHARED_SQL(insert_email) {
		execute procedure pInsEmail(
			p_name = ?,
			p_type = ?,
			p_from_code = ?,
			p_system = ?,
			p_status = ?,
			p_channels =?,
			p_email_addr = ?
		)
	}

	# Insert an email type
	set SHARED_SQL(insert_email_type) {
		insert into
			tEmailType (name, description)
		values
			(?, ?)
	}
	
	# Insert EmailBody
	set SHARED_SQL(insert_emailbody) {
		execute procedure pInsEmailBody(
			p_email_id = ?,
			p_body_seq_id = ?,
			p_language = ?,
			p_format = ?,
			p_body = ?,
			p_subject = ?
		)
	}
	
	# Remove EmailBodies
	# To be used prior to inserting new set of email bodies
	set SHARED_SQL(remove_emailbodies) {
		delete
		from
			tEmailBody
		where
			email_id = ? and
			language = ? and
			format = ?
	}

	# Insert Email for Queuing
	set SHARED_SQL(queue_email) {
		execute procedure pInsEmailQueue(
			p_email_type = ?,
			p_cust_id = ?
		)
	}

	set SHARED_SQL(queue_internal_email) {
		execute procedure pInsEmailQueue(
			p_email_type = ?
		)
	}
	
	# Get cust_id from username
	set SHARED_SQL(get_cust_id) {
		select
			cust_id
		from
			tcustomer
		where
			username = ?
	}

}


################################################################################
#
#                           MAIN PROCEDURES
#
################################################################################




##
# EMAILS::go_email_list
#
# SYNOPSIS
#
#       [EMAILS::go_email_list]
#
# SCOPE
#
#       public
#
# PARAMS
#
#
# RETURN
#
#
# DESCRIPTION
#       Looks in tEmail for list of emails. Displays them sorted in
#       status, cr_date order. Also displays the current email queue
##
proc go_email_list args {
	
	global DB EMAILS QUEUE QUEUE_INT
	
	ob::log::write INFO {==>go_email_list}
	
	if {[catch {set rs [tb_db::tb_exec_qry get_all_emails]} msg]} {
		ob::log::write ERROR {failed to execute get_all_emails $msg}
        return
    }
		
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		# Use email_id as index to concat languages together
		set email_id [db_get_col $rs $i email_id]

		if {![info exists EMAILS($email_id,language)]} {
			set EMAILS($email_id,language) {}
		}
		set EMAILS($email_id,email_id)      [db_get_col $rs $i email_id]
		set EMAILS($email_id,cr_date)       [db_get_col $rs $i cr_date]
		set EMAILS($email_id,type)          [db_get_col $rs $i type]
		set EMAILS($email_id,name)          [db_get_col $rs $i name]
		set EMAILS($email_id,status)        [db_get_col $rs $i status]
		set EMAILS($email_id,channels)      [db_get_col $rs $i channels]
		if {[db_get_col $rs $i language] != {}} {
			set EMAILS($email_id,language) \
				"$EMAILS($email_id,language),[db_get_col $rs $i language]"
		}
		set EMAILS($email_id,language) \
			[string trim $EMAILS($email_id,language) {,}]
	
		set EMAILS(num)      [expr {$email_id + 1}]

	}
	tpBindVar email_id   EMAILS email_id      email_idx
	tpBindVar cr_date    EMAILS cr_date       email_idx
	tpBindVar type       EMAILS type          email_idx
	tpBindVar name       EMAILS name          email_idx
	tpBindVar status     EMAILS status        email_idx
	tpBindVar channels   EMAILS channels      email_idx
	tpBindVar language   EMAILS language      email_idx


	
	

	# clean up
	db_close $rs

	# Bind email queue	

	if {[catch {set rs [tb_db::tb_exec_qry get_email_queue]} msg]} {
		ob::log::write ERROR {failed to execute get_email_queue $msg}
        return
    }

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set QUEUE($i,cr_date)		[db_get_col $rs $i cr_date]
		set QUEUE($i,cust_id)		[db_get_col $rs $i cust_id]
		set QUEUE($i,username)		[db_get_col $rs $i username]
		set QUEUE($i,email_id)		[db_get_col $rs $i email_id]
		set QUEUE($i,email_name)	[db_get_col $rs $i email_name]
		set QUEUE($i,msg_type)		[db_get_col $rs $i msg_type]
		
	}	

	set QUEUE(queue_size) $i
	tpBindVar qcr_date		QUEUE cr_date		queue_idx
	tpBindVar qcust_id		QUEUE cust_id		queue_idx
	tpBindVar qusername		QUEUE username		queue_idx
	tpBindVar qemail_id		QUEUE email_id		queue_idx
	tpBindVar qemail_name	QUEUE email_name	queue_idx
	tpBindVar qmsg_type		QUEUE msg_type		queue_idx

	# clean up
	db_close $rs

	if {[catch {set rs [tb_db::tb_exec_qry get_internal_email_queue]} msg]} {
		ob::log::write ERROR {failed to execute get_internal_email_queue $msg}
        return
    }

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set QUEUE_INT($i,cr_date)		[db_get_col $rs $i cr_date]
		set QUEUE_INT($i,email_id)		[db_get_col $rs $i email_id]
		set QUEUE_INT($i,email_name)	[db_get_col $rs $i email_name]
		set QUEUE_INT($i,msg_type)		[db_get_col $rs $i msg_type]
		
	}	

	set QUEUE_INT(queue_size) $i
	tpBindVar qcr_date		QUEUE_INT cr_date		queue_int_idx
	tpBindVar qemail_id		QUEUE_INT email_id		queue_int_idx
	tpBindVar qemail_name	QUEUE_INT email_name	queue_int_idx
	tpBindVar qmsg_type		QUEUE_INT msg_type		queue_int_idx

	# clean up
	db_close $rs

	# Play email list template
	asPlayFile -nocache email_list.html
	
	catch {unset EMAILS}
	catch {unset QUEUE}
	catch {unset QUEUE_INT}

	return

}

##
# EMAILS::go_email
#
# SYNOPSIS
#
#       [EMAILS::go_email]
#
# SCOPE
#
#       public
#
# PARAMS
#
#
# RETURN
#
#
# DESCRIPTION
#       Looks in tEmailBody and tEmailType for email details
#
##
proc go_email args {
	
	global DB EMAIL_DETAILS CHANNEL_MAP FLAGS TYPES
	
	set email_id [reqGetArg email_id]
	
	ob::log::write INFO {==>go_email : $email_id}

	set action [reqGetArg SubmitName]
	if {$action == "AddEmailType"} {
		make_email_type_binds
		asPlayFile -nocache email_type.html
		return
	}
	
	if {$email_id == {}} {
		tpSetVar opAdd 1
		make_channel_binds  "" - 1
		make_system_source_binds
		make_type_binds
		tpBindString disabled "Disabled"
		asPlayFile -nocache email_details.html
		return
	}
	
	
	if {[catch {set rs [tb_db::tb_exec_qry get_single_email_details $email_id]} msg]} {
		ob::log::write ERROR {failed to execute get_single_email_details $msg}
		return
    }

		tpBindString email_id      [db_get_col $rs 0 email_id]
		tpBindString cr_date       [db_get_col $rs 0 cr_date]
		tpBindString type          [db_get_col $rs 0 type]
		tpBindString name          [db_get_col $rs 0 name]
		tpBindString from_code     [db_get_col $rs 0 from_code]
		tpBindString email_addr    [db_get_col $rs 0 email_addr]
		tpBindString status        [db_get_col $rs 0 status]
		tpBindString system        [db_get_col $rs 0 system]
		tpBindString channels      [db_get_col $rs 0 channels]
		tpBindString typename      [db_get_col $rs 0 type_name]
		set system                 [db_get_col $rs 0 system]
		set channels               [db_get_col $rs 0 channels]
		set type                   [db_get_col $rs 0 type]

	set em [db_get_col $rs 0 email_addr]

	if {[string length $em]} {
		tpBindString Check "Checked='Checked'"
		tpBindString disabled ""
	} else {
		#tpBindString Check "Checked='Checked'"
		#tpBindString FixedDest "false"
		tpBindString Check ""
		tpBindString disabled "Disabled"
		#tpBindString FixedDest "true"
	}

	

	# clean up
	db_close $rs	
	
	if {[catch {set rs [tb_db::tb_exec_qry get_email_body $email_id]} msg]} {
		ob::log::write ERROR {failed to execute get_email_body $msg}
		return
    }
	
	set index 0	
	
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		# Multiple entries can appear if different body segments have different
		# cr_date seconds. Only want one to display
		set email_id [db_get_col $rs $i email_id]
		set cr_date  [db_get_col $rs $i cr_date]
		set language [db_get_col $rs $i language]
		set format   [db_get_col $rs $i format]
		if [info exists EXISTS($email_id,$language,$format)] {
			continue
		}
		set EMAIL_DETAILS($index,email_id)      $email_id
		set EMAIL_DETAILS($index,cr_date)       $cr_date
		set EMAIL_DETAILS($index,language)      $language
		set EMAIL_DETAILS($index,format)        $format
		set EXISTS($email_id,$language,$format) 1
		incr index
	}

	set EMAIL_DETAILS(num) $index
	tpBindVar cr_date     EMAIL_DETAILS cr_date     body_idx
	tpBindVar language    EMAIL_DETAILS language    body_idx
	tpBindVar format      EMAIL_DETAILS format      body_idx


	# clean up
	db_close $rs

	# now map channels for binding
	make_channel_binds $channels -
	
	# Get system_source flags
	make_system_source_binds $system
	
	# Get Email Types
	make_type_binds $type
	
	
	# Play email list template
	tpSetVar opAdd 0
	asPlayFile -nocache email_details.html

	catch {unset EMAIL_DETAILS CHANNEL_MAP FLAGS TYPES}

}

##
# EMAILS::go_email_body
#
# SYNOPSIS
#
#       [EMAILS::go_email_body]
#
# SCOPE
#
#       public
#
# PARAMS
#
#
# RETURN
#
#
# DESCRIPTION
#       Looks in tEmailBody for email details
#
##
proc go_email_body args {

	global DB EMAIL_DETAILS CHANNEL_MAP LANG_MAP USE_LANG_MAP PLACEHOLDERS
	
	set email_id [reqGetArg email_id]
	set email_type [reqGetArg email_type]
	set language [reqGetArg language]
	set format   [reqGetArg format]
	
	set action [reqGetArg action]
	ob::log::write INFO {==>go_email_body : $email_id $language $format}
	
	# Bind up placeholders from config file
	set pholders [OT_CfgGet PLACEHOLDERS ""]
	if {[llength $pholders]} {
		for {set r 0} {$r < [llength $pholders]} {incr r} {
			set PLACEHOLDERS($r,pholder_code)  [lindex [lindex $pholders $r] 1]
			set PLACEHOLDERS($r,pholder_value) [lindex [lindex $pholders $r] 0]
		}
	} else {
		ob::log::write ERROR {No PLACEHOLDERS found in config file}
		set r 0
	}
	
	# Bind up any Email Type Specific Placeholders
	# Each Email Type with additional placeholders will need a cfg item
	# in the format "EMAIL_TYPE_PLACEHOLDERS"
	set mkt_pholders [OT_CfgGet ${email_type}_PLACEHOLDERS [list]]

	# Add on market abandon placeholders onto the existing list
	# and ensure that the placeholder index ('r') is getting updated
	foreach placeholder_pair $mkt_pholders {
		set PLACEHOLDERS($r,pholder_code)  [lindex $placeholder_pair 1]
		set PLACEHOLDERS($r,pholder_value) [lindex $placeholder_pair 0]
		incr r
	}

	tpSetVar  NumPHolders $r
	tpBindVar pholder_code     PLACEHOLDERS pholder_code     pholder_idx
	tpBindVar pholder_value    PLACEHOLDERS pholder_value    pholder_idx
	
	# Bind up file upload data
	tpBindString upload_type {EM_BODY}
	
	
	if {[reqGetArg SubmitName] == {AddEmailBody}} {
		tpSetVar opAdd 1
		make_language_binds {} - 0 "SELECTED"
		tpBindString email_id [reqGetArg email_id]
		asPlayFile -nocache email_body.html
		return
	}

	if {[catch {set rs [tb_db::tb_exec_qry get_body_details $email_id $language $format]} msg]} {
		ob::log::write ERROR {failed to execute get_single_email_details $msg}
		return
    } else {
		ob::log::write CRITICAL {found [db_get_nrows $rs] rows }
	}
		
	set body {}
	set num_bodies [db_get_nrows $rs]
	for {set i 0} {$i < $num_bodies} {incr i} {
		
		set body_part [db_get_col $rs $i body]
		
		# Informix libraries skip trailing spaces
		# Append them unless its the last body		
		if {([string length $body_part] < 2048) && $i < [expr {$num_bodies - 1}]} {
			set num [expr {2048 - [string length $body_part]}]
			append body_part [string repeat { } $num]
		}

		append body $body_part
	}
	
	tpBindString body         $body
	if {[db_get_nrows $rs] > 0} {
	tpBindString email_id     [db_get_col $rs 0 email_id]
	tpBindString cr_date      [db_get_col $rs 0 cr_date]
	tpBindString CHARSET      [db_get_col $rs 0 charset]
	tpBindString language     [db_get_col $rs 0 language]
	tpBindString subject      [db_get_col $rs 0 subject]
	tpBindString format       [db_get_col $rs 0 format]
	set language              [db_get_col $rs 0 language]

	# bind format type
	tpBindString FormatSel_[db_get_col $rs 0 format] "SELECTED"
	} else {
		set language {}
	}
	
		
	# clean up
	db_close $rs	
	
	make_language_binds $language - 0 "SELECTED"
	
	# Play email list template
	tpSetVar opAdd 0
	asPlayFile -nocache email_body.html

	catch {unset EMAIL_DETAILS FLAGS TYPES CHANNEL_MAP LANG_MAP USE_LANG_MAP}
	catch {unset PLACEHOLDERS}

}

##
# EMAILS::do_email
#
# SYNOPSIS
#
#       [EMAILS::do_email]
#
# SCOPE
#
#       public
#
# PARAMS
#
#
# RETURN
#
#
#
# DESCRIPTION
#       Updates tEmail with new email details
#
##
proc do_email args {

	set action [reqGetArg SubmitName]
	if {$action == "Back"} {
		go_email_list
		return
	} elseif {$action == "DoTestEmail"} {
		do_test_email
		return
	}
	
	global DB FLAGS CHANNEL_MAP
	
	if {$action == "EmailTypeAdd"} {
		set name         [reqGetArg name]
		set desc         [reqGetArg desc]
	} else {
		set email_id     [reqGetArg email_id]
		set name         [reqGetArg name]
		set type         [reqGetArg type]
		set from_code    [reqGetArg from_code]
		set status       [reqGetArg status]
		set channels ""
		set system   ""
		set email_addr   [reqGetArg email_addr]
	
		ob::log::write INFO {==>do_email : $email_id}	
	
		# Check sources that need storing
		set system [reqGetArg system_source]
		
		# Get selected channels
		make_channel_binds  "" - 1
		foreach key [array names CHANNEL_MAP] {
			set channel [reqGetArg CN_$CHANNEL_MAP($key)]
			if {$channel == "on"} {
				append channels "$CHANNEL_MAP($key)"
			}
		}

		#Check we aren't adding / updating so that its possible that a customer
		#could receive two emails, if so we need to get them to change it.......

		if {$status == "A"} {
			set append_sql ""
		
			if {$action == "EmailMod"} {
				set append_sql "and e.email_id != $email_id "
			}
		
			if {$system != "ALL"} {
				append append_sql "and (e.system = 'ALL' or e.system = '$system')"
			}
		
			set sql [subst {
				select
					1
				from
					tEmail e,
					tEmailType t
				where
					e.type = t.type_id and
					t.type_id = $type and
					e.status = 'A' and
					e.channels MATCHES '*\[$channels]*'
					$append_sql
			}]
		
			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt]
		
			inf_close_stmt $stmt
		
			if {[db_get_nrows $res] != 0} {
				err_bind "Already exists an active email for classification of customers defined"
				db_close $res
		
				reqSetArg email_id $email_id
				go_email
				return
			}
		
			db_close $res
		}
	}
	
	if {$action == "EmailAdd"} {
		ob::log::write INFO {Inserting email $name}
		if {[catch {set rs [tb_db::tb_exec_qry insert_email \
				$name \
				$type \
				$from_code \
				$system \
				$status \
				$channels \
				$email_addr \
				]} msg]} {
			ob::log::write ERROR {failed to insert email details $msg}
			err_bind "failed to insert email details $msg"
			go_email
			return
		}	
		# Get new email_id to go to
		reqSetArg email_id [db_get_coln $rs 0]
		
		# clean up
		db_close $rs
	} elseif {$action == "EmailTypeAdd"} {
		ob::log::write INFO {Inserting email type $name}
		if {[catch {set rs [tb_db::tb_exec_qry insert_email_type \
				$name \
				$desc \
				]} msg]} {
			ob::log::write ERROR {failed to insert email type $msg}
			err_bind "failed to insert email type $msg"
			go_email
			return
		}	
		# clean up
		db_close $rs	
	} else {
		ob::log::write INFO {Updating email $email_id}
		if {[catch {set rs [tb_db::tb_exec_qry update_email \
				$email_id \
				$name \
				$type \
				$from_code \
				$system \
				$status \
				$channels \
				$email_addr \
				]} msg]} {
			ob::log::write ERROR {failed to update email details $msg}
			err_bind "failed to update email details $msg"
			go_email
			return
		}	
		# clean up
		db_close $rs	
	}

	go_email


}

##
# EMAILS::do_email_body
#
# SYNOPSIS
#
#       [EMAILS::do_email_body]
#
# SCOPE
#
#       public
#
# PARAMS
#
#
# RETURN
#
#
#
# DESCRIPTION
#       Updates tEmailBody with new email details
#
##
proc do_email_body args {

	set action [reqGetArg SubmitName]
	if {$action == "Back"} {
		go_email
		return
	}

	global DB REQ_FILES
	
	set body_id      [reqGetArg body_id]
	set email_id     [reqGetArg email_id]
	set language     [reqGetArg language]
	set language_old [reqGetArg language_old]
	set format       [reqGetArg format]
	set format_old   [reqGetArg format_old]
	set body         [reqGetArg body]
	set subject      [reqGetArg subject]
	
	ob::log::write INFO {==>do_email_body : $body_id : $email_id}
	
	# Check for uploaded file
	if {[info exists REQ_FILES(uploadfile)] && $REQ_FILES(uploadfile) != ""} {
		ob::log::write INFO {Using email body upload file}
		set body $REQ_FILES(uploadfile)
	}
	
	# Now need to split up the email body to be tEmailBody.body length long
	# Should have set of vars: body_0, body_1, body_2 for inserting each
	# into tEmailBody.
		
	set index 0
	set body_$index [string range $body 0 2047]
	set body [string replace $body 0 2047 {}]
	while {[string length $body] > 2047} {
		incr index
		set body_$index [string range $body 0 2047]
		set body [string replace $body 0 2047 {}]
	}
	if {$body != {}} {
		incr index
		set body_$index [string range $body 0 2047]
	}

	if {$action == "EmailBodyMod" || $action == "UploadEmail"} {
		# Due to body_seq_ids being being different, no point in updating
		# email bodies. Just delete all bodies and re-insert.
		ob::log::write INFO {Removing email bodies for $email_id:$language_old:$format_old}
		if {[catch {set rs [tb_db::tb_exec_qry remove_emailbodies \
			$email_id \
			$language_old \
			$format_old \
		]} msg]} {
			ob::log::write ERROR {failed to remove email bodies $msg}
			err_bind "failed to remove email body $msg"
		}
		# Also remove email bodies already existing for this format/language
		if {[catch {set rs [tb_db::tb_exec_qry remove_emailbodies \
			$email_id \
			$language \
			$format \
		]} msg]} {
			ob::log::write ERROR {failed to remove email bodies $msg}
			err_bind "failed to remove email body $msg"
		}
	}
	
	if {$action == "EmailBodyAdd" || $action == "EmailBodyMod" \
		|| $action == "UploadEmail" } {
		for {set i 0} {$i <= $index} {incr i} {
			ob::log::write INFO {Inserting email body to $email_id:$i}
			if {[catch {set rs [tb_db::tb_exec_qry insert_emailbody \
				$email_id \
				$i \
				$language \
				$format \
				[set body_$i] \
				$subject \
			]} msg]} {
				ob::log::write ERROR {failed to insert email body $msg}
				err_bind "failed to insert email body $msg"
			}
		}
	} else {
		ob::log::write ERROR {Unknown action : $action}
		err_bind "Unknown action : $action"
	}
		
	# clean up
	db_close $rs	

	go_email

}

##
# EMAILS::do_test_email
#
# SYNOPSIS
#
#       [EMAILS::do_test_email]
#
# SCOPE
#
#       public
#
# PARAMS
#
#
# RETURN
#
#
#
# DESCRIPTION
#       Queues a test email
#
##
proc do_test_email args {

	if {[reqGetArg SubmitName] == "Back"} {
		go_email
		return
	}
	
	global DB REQ_FILES
	
	set test_username  [reqGetArg test_username]
	set email_id       [reqGetArg email_id]
	
	ob::log::write INFO {==>do_test_email : $test_username on $email_id}


	if {$test_username != ""} {
		# Get cust_id
		if {[catch {set rs [tb_db::tb_exec_qry get_cust_id \
			$test_username
		]} msg]} {
			ob::log::write ERROR {failed to get cust_id for $test_username $msg}
			err_bind "failed to get cust_id for $test_username $msg"
		}
			
		if {[db_get_nrows $rs] > 0} {
			set cust_id [db_get_col $rs 0 cust_id]
		} else {
			ob::log::write ERROR {Username not found : $test_username}
			err_bind "Username not found : $test_username"
			go_email
			return
		}
		db_close $rs

		if {[catch {set rs [tb_db::tb_exec_qry queue_email \
			[reqGetArg type_name] \
			$cust_id \
		]} msg]} {
			ob::log::write ERROR {failed to queue test email $msg}
			err_bind "failed to queue test email $msg"
			go_email
			return
    	}
		# clean up
		db_close $rs	

		msg_bind "Added test email to queue for: $test_username"
	} else {
		if {[catch {set rs [tb_db::tb_exec_qry queue_internal_email \
			[reqGetArg type_name] \
		]} msg]} {
			ob::log::write ERROR {failed to queue test email $msg}
			err_bind "Failed to queue test internal email $msg"
			go_email
			return
    	}
		# clean up
		db_close $rs	

		msg_bind "Added test internal email to queue"
	}
	

	
	go_email

}

#
# Internal function for binding system source flags
#
proc make_system_source_binds {{system -}} {

	global DB FLAGS
	
	set sql {
		select
			decode(nvl(description,''),'',flag_value,description) desc,
			flag_value
		from
			tcustflagval
		where
			flag_name = 'system_source'
		order by
			1
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumFlags [set n_rows [db_get_nrows $res]]

	set flags [split $system |]
	
	for {set r 0} {$r < $n_rows} {incr r} {

		set flag_desc   [db_get_col $res $r desc]
		set flag_value  [db_get_col $res $r flag_value]

		set FLAGS($r,flag_desc)    $flag_desc
		set FLAGS($r,flag_value)   $flag_value
		
		# Get chosen system flags
		foreach flag $flags {
			if {$flag == $flag_value} {
				#set FLAGS($r,flag_sel) CHECKED
				tpBindString flag_sel $flag
			}
		}
		
	}

	tpBindVar flag_value  FLAGS flag_value  flag_idx
	#tpBindVar flag_sel    FLAGS flag_sel    flag_idx
	tpBindVar flag_desc   FLAGS flag_desc   flag_idx

	
}

#
# Internal function for binding email types
#
proc make_type_binds {{type ""}} {

	global TYPES DB
	
	set sql {
		select
			type_id,
			name,
			description
		from
			temailtype
		order by
			name
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumTypes [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {

		set TYPES($r,type_id)     [db_get_col $res $r type_id]
		set TYPES($r,type_name)   [db_get_col $res $r name]
		set TYPES($r,description) [db_get_col $res $r description]
		
		if {$type == $TYPES($r,type_id)} {
			set TYPES($r,type_sel) SELECTED
		} else {
			set TYPES($r,type_sel) ""
		}
	}

	tpBindString type_sel    $type
	
	tpBindVar type_id        TYPES type_id        type_idx
	tpBindVar type_name      TYPES type_name      type_idx
	tpBindVar description    TYPES description    type_idx
	
	db_close $res

}



#
# Internal function for binding email types
#
proc make_email_type_binds {} {

	global TYPES DB
	
	set sql {
		select
			product_source
		from
			tProductSource p
		order by
			product_source
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumTypes [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set TYPES($r,type_name) "SB_ACCT_REG_[db_get_col $res $r product_source]"
	}

	tpBindVar type_name      TYPES type_name      type_idx
	
	db_close $res

}

# initialise this namespace
init

# close namespace
}
