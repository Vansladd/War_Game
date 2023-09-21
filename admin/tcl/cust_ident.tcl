# =============================================================================
# $Id: cust_ident.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# =============================================================================

# -----------------------------------------------------------------------------
# Customer Identification Management
# -----------------------------------------------------------------------------

namespace eval ADMIN::CUSTIDENT {
}

#-------------------------------------------------------------------------------
# Initialisation
#-------------------------------------------------------------------------------

# One off initialisation
#
proc ADMIN::CUSTIDENT::init {} {

	# Action handlers
	asSetAct ADMIN::CUSTIDENT::GoIdent [namespace code H_go_ident]
	asSetAct ADMIN::CUSTIDENT::DoIdent [namespace code H_do_ident]

}



#-------------------------------------------------------------------------------
# Action handlers
#-------------------------------------------------------------------------------

# Go to customer identification page
#
proc ADMIN::CUSTIDENT::H_go_ident {} {

	global DB

	if {![op_allowed ManageCustIdent]} {
		error "You are not allowed to manage customer identification"
	}

	set cust_id [reqGetArg CustId]

	set sql {
		select
			prev_addr,
			tel_no,
			mob_no,
			contact_no,
			enc_with_bin,
			card_bin,
			enc_cc_no,
			cc_ivec,
			enc_passport_no,
			passport_ivec,
			enc_nat_id_no,
			nat_id_ivec,
			data_key_id
		from
			tCustIdent
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows} {

		tpSetVar IsUpdate 1

		foreach col [list prev_addr tel_no mob_no contact_no] {
			tpBindString CustIdent_$col [db_get_col $res 0 $col]
		}

		set enc_with_bin    [db_get_col $res 0 enc_with_bin]
		set card_bin        [db_get_col $res 0 card_bin]
		set data_key_id     [db_get_col $res 0 data_key_id]

		# Required values for decryption
		set enc_db_vals [list]
		foreach {col ivec} {
			enc_cc_no       cc_ivec
			enc_passport_no passport_ivec
			enc_nat_id_no   nat_id_ivec
		} {
			lappend enc_db_vals [list\
				[db_get_col $res 0 $col] [db_get_col $res 0 $ivec]]
		}
	
		set decrypt_rs  [card_util::batch_decrypt_db_row $enc_db_vals \
		                                                 $data_key_id \
		                                                 $cust_id \
		                                                 "tCustIdent"]
	
		if {[lindex $decrypt_rs 0] == 0} {
			ob_log::write ERROR "Error decrypting customer identity info;\
			                     [lindex $decrypt_rs 1]"
			err_bind "Error decrypting customer identity info;\
			          [lindex $decrypt_rs 1]"

			tpBindString CustId $cust_id

			asPlayFile -nocache cust_ident.html
			return
		} else {
			set decrypted_vals [lindex $decrypt_rs 1]
		}
	
		set cc_no       [lindex $decrypted_vals 0]
		set passport_no [lindex $decrypted_vals 1]
		set nat_id_no   [lindex $decrypted_vals 2]

		set card_no [card_util::format_card_no $cc_no $card_bin $enc_with_bin]
	
		if {![op_allowed ViewCardNumber]} {
			set card_no [card_util::card_replace_midrange $card_no 1]
		}
	
		tpBindString CustIdent_cc_no $card_no
		tpBindString CustIdent_nat_id_no $nat_id_no
		tpBindString CustIdent_passport_no $passport_no

	}

	tpBindString CustId $cust_id

	db_close $res

	asPlayFile -nocache cust_ident.html

}



# Do customer identification
#
proc ADMIN::CUSTIDENT::H_do_ident {} {

	if {![op_allowed ManageCustIdent]} {
		error "You are not allowed to manage customer identification"
	}

	set cust_id [reqGetArg CustId]
	set action  [reqGetArg SubmitName]

	if {$action == "Back"} {
		ADMIN::CUST::go_cust
	} elseif {$action == "Insert" || $action == "Update"} {
		_update $cust_id
	} elseif {$action == "Delete"} {
		_delete $cust_id
	} else {
		error "Unknown action: $action"
	}

}



#-------------------------------------------------------------------------------
# Utilities
#-------------------------------------------------------------------------------

# Insert a new identification
#
#    cust_id - customer identifier
#
proc ADMIN::CUSTIDENT::_update { cust_id } {

	global DB
	global USERNAME

	set prev_addr       [reqGetArg prev_addr]
	set tel_no          [reqGetArg tel_no]
	set mob_no          [reqGetArg mob_no]
	set contact_no      [reqGetArg contact_no]
	set cc_no           [reqGetArg cc_no]
	set update_cc_no    [reqGetArg update_cc_no]
	set passport_no     [reqGetArg passport_no]
	set nat_id_no       [reqGetArg nat_id_no]

	if {$update_cc_no == 0} {
		# if we aren't updating the credit card as the user doesn't have
		# permission to view the card we need to decrypt the current card, as
		# update_identity encrypts a whole row in tcustidentity with the same
		# key. IF we re-encrypt one row, we need to re-encrypt them all.
		set sql {
			select
				enc_with_bin,
				card_bin,
				enc_cc_no,
				cc_ivec,
				data_key_id
			from
				tCustIdent
			where
				cust_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt
	
		set nrows [db_get_nrows $res]
	
		if {$nrows == 1} {

			set card_bin      [db_get_col $res 0 card_bin]
			set enc_cc_no     [db_get_col $res 0 enc_cc_no]
			set cc_ivec       [db_get_col $res 0 cc_ivec]
			set data_key_id   [db_get_col $res 0 data_key_id]
			set enc_with_bin  [db_get_col $res 0 enc_with_bin]
	
			set card_dec_rs [card_util::card_decrypt $enc_cc_no \
			                                         $cc_ivec \
			                                         $data_key_id]
	
			if {[lindex $card_dec_rs 0] == 0} {
				# Check on the reason decryption failed, if we encountered 
				# corrupt data we should also record this fact in the db
				if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
					card_util::update_data_enc_status "tCPMCC" \
					                                   $cpm_id \
					                                  [lindex $card_dec_rs 2]
				}
	
				err_bind "Decryption error: [lindex $card_dec_rs 1]"
				tpBindString CustId $cust_id
				H_go_ident
				return
			} else {
				set dec_card_no [lindex $card_dec_rs 1]
			}
	
			set cc_no [card_util::format_card_no $dec_card_no \
			                                     $card_bin \
			                                     $enc_with_bin]

		} else {
			err_bind "Failed to update identification: unexpected rows returned"
			tpBindString CustId $cust_id
			H_go_ident
			return
		}
	}

	set update_ret [identity::update_identity $cust_id \
	                                          $prev_addr \
	                                          $tel_no \
	                                          $mob_no \
	                                          $contact_no \
	                                          $cc_no \
	                                          $passport_no \
	                                          $nat_id_no\
	                                          $USERNAME]

	set update_result [lindex $update_ret 0]
	set update_err    [lindex $update_ret 1]

	if {$update_result == 1} {
		msg_bind "Successfully updated customer identification"
	} else {
		err_bind "Failed to update identification: $update_err"
	}

	H_go_ident
}



# Delete an identification
#
#    cust_id - customer identifier
#
proc ADMIN::CUSTIDENT::_delete { cust_id } {

	global DB

	set sql {
		delete from
			tCustIdent
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		inf_exec_stmt $stmt \
			$cust_id
	} msg]} {

		ob_log::write ERROR \
			{Error deleting identification, cust_id: $cust_id, msg: $msg}
		err_bind "Failed to delete identification"
		H_go_ident
		return
	}

 	if {![inf_get_row_count $stmt]} {
		ob_log::write ERROR \
			{Failed to delete identification, cust_id: $cust_id}
		err_bind "Failed to delete identification"
		H_go_ident
		return
	}

	inf_close_stmt $stmt

	msg_bind "Successfully deleted customer identification"

	ADMIN::CUST::go_cust

}

# initialisation
ADMIN::CUSTIDENT::init
