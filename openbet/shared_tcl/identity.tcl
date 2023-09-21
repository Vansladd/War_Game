# $Id: identity.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#  ==============================================================
#
# (c) 2008 Orbis Technology Ltd. All rights reserved.
#
# ===============================================================

# Additional customer identity information
#

namespace eval identity {

}

proc identity::prepare_queries {} {

	global SHARED_SQL

	set SHARED_SQL(update_identity) {
		execute procedure pUpdCustIdentity (
			p_cust_id = ?,
			p_prev_addr = ?,
			p_tel_no = ?,
			p_mob_no = ?,
			p_contact_no = ?,
			p_enc_with_bin = ?,
			p_card_bin = ?,
			p_enc_cc_no = ?,
			p_cc_ivec = ?,
			p_enc_passport_no = ?,
			p_passport_ivec = ?,
			p_enc_nat_id_no = ?,
			p_nat_id_ivec = ?,
			p_data_key_id =?
		)
	}
}

#
# identity::update_identity - inserts or updates a customers current identity
# information.
#
# This information requires encryption, however each field is optional.
# The data is all stored in one row in tCustIdent, and should all be encrypted
# with the same key, therefore there are checks to make sure this is the case.
#
# cust_id     - customer id
# prev_addr   - previous address
# tel_no      - telephone number
# mob_no      - mobile number
# contact_no  - contact number
# cc_no       - credit card number
# passport_no - passport number
# nat_id_no   - national identity number

proc identity::update_identity {
	cust_id
	prev_addr
	tel_no
	mob_no
	contact_no
	cc_no
	passport_no
	nat_id_no
	{oper_name ""}
} {

	set fn "identity::update_identity"

	# handle defaults
	set enc_with_bin    "N"
	set enc_cc_no       ""
	set enc_passport_no ""
	set enc_nat_id_no   ""
	set cc_ivec         "0000000000000000"
	set passport_ivec   "0000000000000000"
	set nat_id_ivec     "0000000000000000"
	set data_key_id     ""

	# Encrypt the credit card

	set card_bin  [string range $cc_no 0 5]
	set card_rem  [string range $cc_no 6 end]

	if {$cc_no != ""} {

		# validation checks

		# check between 13 and 19 digits long
		if {([string length $cc_no] < 13 || [string length $cc_no] > 19)} {
			return [list 0 ERR_CARD_LENGTH]
		}

		if {![OT_CfgGet ENCRYPT_WITH_BIN 0]} {
			set enc_rs [card_util::card_encrypt $card_rem \
												"Storing customer identity" \
												$cust_id \
												$oper_name]
			set enc_with_bin "N"
		} else {
			set card_no [string range $cc_no 8 end][string range $cc_no 0 7]
			set enc_rs [card_util::card_encrypt $card_no \
												"Storing customer identity" \
												$cust_id \
												$oper_name]
			set enc_with_bin "Y"
		}

		OT_LogWrite 1 "enc_rs = $enc_rs"
	
		if {[lindex $enc_rs 0] == 0} {
			ob::log::write ERROR {Failed to encrypt card number:\
								[lindex $enc_rs 1]}
			return [list 0 [lindex $enc_rs 1]]
		}
	
		set enc_cc_no      [lindex [lindex $enc_rs 1] 0]
		set cc_ivec        [lindex [lindex $enc_rs 1] 1]
		set cc_data_key_id [lindex [lindex $enc_rs 1] 2]
	}


	# Encrypt the passport no

	if {$passport_no != ""} {

		set enc_rs [card_util::card_encrypt $passport_no \
		                                    "Storing customer identity" \
		                                    $cust_id \
		                                    $oper_name]
	
		if {[lindex $enc_rs 0] == 0} {
			ob::log::write ERROR {Failed to encrypt passport no: \
			                     [lindex $enc_rs 1]}
			return [list 0 [lindex $enc_rs 1]]
		}
	
		set enc_passport_no      [lindex [lindex $enc_rs 1] 0]
		set passport_ivec        [lindex [lindex $enc_rs 1] 1]
		set passport_data_key_id [lindex [lindex $enc_rs 1] 2]

	}

	# Encrypt the national identity no

	if {$nat_id_no != ""} {

		set enc_rs [card_util::card_encrypt $nat_id_no \
		                                    "Storing customer identity" \
		                                    $cust_id \
		                                    $oper_name]
	
		if {[lindex $enc_rs 0] == 0} {
			ob::log::write ERROR {Failed to encrypt passport no: \
			                     [lindex $enc_rs 1]}
			return [list 0 [lindex $enc_rs 1]]
		}
	
		set enc_nat_id_no      [lindex [lindex $enc_rs 1] 0]
		set nat_id_ivec        [lindex [lindex $enc_rs 1] 1]
		set nat_id_data_key_id [lindex [lindex $enc_rs 1] 2]

	}

	# check all of the rows have been encrypted with the same key, some might
	# be blank though
	foreach key {cc_data_key_id passport_data_key_id nat_id_data_key_id} {
		if {[info exists $key] && [set $key] != ""} {
			# make a list of keys that aren't blank
			lappend keys [set $key]
		}
	}

	if {[info exists keys] && [llength $keys] != 0} {
		# remove duplicates
		set unique_keys [lsort -unique $keys]

		if {[llength $unique_keys] != 1} {
			ob::log::write ERROR {Data key changed during encryption}
			# more than one key used, key must have changed
			# TO DO throw error
			return 0
		} else {
			# one key unique, set it
			set data_key_id [lindex $unique_keys 0]
		}
	}

	if {[catch {set rs [tb_db::tb_exec_qry update_identity \
	                                       $cust_id \
	                                       $prev_addr \
	                                       $tel_no \
	                                       $mob_no \
	                                       $contact_no \
	                                       $enc_with_bin \
	                                       $card_bin \
	                                       $enc_cc_no \
	                                       $cc_ivec \
	                                       $enc_passport_no \
	                                       $passport_ivec \
	                                       $enc_nat_id_no \
	                                       $nat_id_ivec \
	                                       $data_key_id \
	]} msg]} {
		ob_log::write WARNING {$fn Failed to execute update_identity: $msg}
		return [list 0 $msg]
	}

	if {[db_get_coln $rs 0 0] != 1} {
		ob_log::write ERROR {$fn: Error failed to insert or update identity}
		return [list 0]
	}

	return 1
}

identity::prepare_queries
