# ==============================================================
# $Id: card.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CARD {

asSetAct ADMIN::CARD::GoCardQuery   [namespace code go_card_query]
asSetAct ADMIN::CARD::DoCardQuery   [namespace code do_card_query]
asSetAct ADMIN::CARD::DoBlockQuery  [namespace code do_block_query]
asSetAct ADMIN::CARD::GoCardBin     [namespace code go_card_bin]
asSetAct ADMIN::CARD::DoCardBin     [namespace code do_card_bin]
asSetAct ADMIN::CARD::GoCardBlock   [namespace code go_card_block]
asSetAct ADMIN::CARD::DoCardBlock   [namespace code do_card_block]
asSetAct ADMIN::CARD::GoCardReqList [namespace code go_card_req_list]
asSetAct ADMIN::CARD::GoCardReq     [namespace code go_card_req]
asSetAct ADMIN::CARD::DoCardReq     [namespace code do_card_req]
asSetAct ADMIN::CARD::DoSchemeUpd   [namespace code do_scheme_upd]

#
# ----------------------------------------------------------------------------
# Card bin maintenance
# ----------------------------------------------------------------------------
#
proc go_card_query args {
	_bind_card_schemes $args
	asPlayFile -nocache card_query.html
}

# Bind card schemes info
proc _bind_card_schemes args {
	ob::log::write DEBUG {_bind_card_schemes with args: $args}

	global DB DATA

	set sql [subst {
			select
				scheme,
				scheme_name,
				type,
				dep_allowed,
				wtd_allowed
			from
				tCardSchemeInfo
			}
		]
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt ]} msg] } {
		ob::log::write ERROR {failed to retreive cards details: $msg}
		return
	}

	set nrows [db_get_nrows $rs]

	ob::log::write DEBUG {_bind_card_schemes: results: $nrows}

	for {set r 0} {$r < $nrows} {incr r} {
		set DATA($r,scheme)      [db_get_col $rs $r scheme]
		set DATA($r,scheme_name) [db_get_col $rs $r scheme_name]
		set DATA($r,type)        [db_get_col $rs $r type]
		set DATA($r,dep_allowed) [db_get_col $rs $r dep_allowed]
		set DATA($r,wtd_allowed) [db_get_col $rs $r wtd_allowed]
	}	

	inf_close_stmt $stmt
	db_close $rs

	tpSetVar CardBlocks  $nrows

	tpBindVar CardScheme                 DATA  scheme      card_idx
	tpBindVar CardSchemeName             DATA  scheme_name card_idx
	tpBindVar CardSchemeType             DATA  type        card_idx
	tpBindVar CardSchemeDepAllowed       DATA  dep_allowed card_idx
	tpBindVar CardSchemesWithdrawAllowed DATA  wtd_allowed card_idx
}

# Update card schemes
proc do_scheme_upd args {

	global DB
	
	set sql [subst {
			select
				scheme,
				dep_allowed,
				wtd_allowed
			from
				tCardSchemeInfo
			}
		]
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt ]} msg] } {
		ob::log::write ERROR {failed to retreive cards details: $msg}
		return
	}

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set scheme [db_get_col $rs $r scheme]
		set new_dep_allowed [reqGetArg "deposit_allowed_$scheme"]
		set new_wit_allowed [reqGetArg "withdrawals_allowed_$scheme"]

		if {($new_dep_allowed == "Y" || $new_dep_allowed == "N") && \
		    ($new_wit_allowed == "Y" || $new_wit_allowed == "N")} {
			if {$new_dep_allowed != [db_get_col $rs $r dep_allowed] || \
			    $new_wit_allowed != [db_get_col $rs $r wtd_allowed]} {
				_update_card_scheme $scheme $new_dep_allowed $new_wit_allowed
			}
		}
	}

	inf_close_stmt $stmt
	db_close $rs
	
	go_card_query $args
}

# Update individual card shceme settings
#   - scheme - Scheme Code
#   - deposit_allowed - Is deposit allowed to this card (Y/N)
#   - withdrawals_allowed -Is withdrawals allowed from this card (Y/N)
# returns - nothing
proc _update_card_scheme {scheme deposit_allowed withdrawals_allowed} {
	global DB
	
	set sql [subst {
			update 
				tCardSchemeInfo
			set 
				dep_allowed = ?,
				wtd_allowed = ?
			where
				scheme = ?
			}
		]
	set stmt [inf_prep_sql $DB $sql] 

	if {[catch {
		inf_exec_stmt $stmt $deposit_allowed $withdrawals_allowed $scheme
	} msg]} {
		ob::log::write ERROR {Unable to update card scheme: $msg}
		return
	}

	inf_close_stmt $stmt
}

proc do_card_query args {

	global DB

	if {[reqGetArg SubmitName] == "BinAdd"} {
		tpSetVar opAdd 1
		# Grab and bind the scheme
		bind_card_schemes
		asPlayFile -nocache card_bin.html
		return
	}

	set bin [string trim [reqGetArg CardBin]]

	if {![regexp {^[0-9]+$} $bin]} {
		error "Bad bin number"
	}

	set bin_len [string length $bin]

	if {$bin_len < 4 || $bin_len > 6} {
		error "enter a bin of between 4 and 6 digits"
	}

	if {$bin_len == 4} {
		set bin_lo ${bin}00
		set bin_hi ${bin}99
	} elseif {$bin_len == 5} {
		set bin_lo ${bin}0
		set bin_hi ${bin}9
	} else {
		set bin_lo $bin
		set bin_hi $bin
	}

	set sql [subst {
		select
			card_bin,
			bank,
			country,
			type,
			allow_dep,
			allow_wtd
		from
			tCardInfo
		where
			card_bin between ? and ?
		order by
			card_bin asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bin_lo $bin_hi]
	inf_close_stmt $stmt

	tpSetVar NumBins [db_get_nrows $res]

	tpBindTcl CardBin      sb_res_data $res bin_idx card_bin
	tpBindTcl CardBank     sb_res_data $res bin_idx bank
	tpBindTcl CardCountry  sb_res_data $res bin_idx country
	tpBindTcl CardType     sb_res_data $res bin_idx type
	tpBindTcl CardAllowDep sb_res_data $res bin_idx allow_dep
	tpBindTcl CardAllowWtd sb_res_data $res bin_idx allow_wtd

	asPlayFile -nocache card_bin_list.html

	db_close $res
}


proc go_card_bin args {

	global DB

	if {[reqGetArg SubmitName] == "Back" && \
	    [reqGetArg action] ne "ADMIN::AUDIT::DoAuditBack"} {
		go_card_query
		return
	}

	set bin [reqGetArg CardBin]

	foreach {n v} $args {
		set $n $v
	}

	if {$bin == ""} {
		tpSetVar opAdd 1
		# Grab and bind the scheme
		bind_card_schemes
	} else {
		tpSetVar opAdd 0

		set sql [subst {
			select
				card_bin,
				bank,
				country,
				type,
				allow_dep,
				allow_wtd,
				scheme
			from
				tCardInfo
			where
				card_bin = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $bin]
		inf_close_stmt $stmt

		tpSetVar NumBins [db_get_nrows $res]

		if {[tpGetVar NumBins] > 0} {
			tpBindString CardBin      [db_get_col $res 0 card_bin]
			tpBindString CardBank     [db_get_col $res 0 bank]
			tpBindString CardCountry  [db_get_col $res 0 country]
			tpBindString CardType     [db_get_col $res 0 type]
			tpBindString CardAllowDep [db_get_col $res 0 allow_dep]
			tpBindString CardAllowWtd [db_get_col $res 0 allow_wtd]
		}

		# Grab and bind the scheme
		bind_card_schemes [db_get_col $res 0 scheme]

		db_close $res
	}

	asPlayFile -nocache card_bin.html
}


proc do_card_bin args {

	global DB USERNAME

	set bin [reqGetArg CardBin]

	set action [reqGetArg SubmitName]

	if {$action == "Back"} {
		go_card_query
		return
	}

	if {$action == "BinAdd"} {
		set op I
	} elseif {$action == "BinMod"} {
		set op U
	} elseif {$action == "BinDel"} {
		set op D
	} else {
		error "unexpected SubmitName : $action"
	}

	set sql [subst {
		execute procedure pCardBin(
			p_adminuser = ?,
			p_card_bin = ?,
			p_op = ?,
			p_bank = ?,
			p_country = ?,
			p_type = ?,
			p_allow_dep = ?,
			p_allow_wtd = ?,
			p_scheme = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CardBin]\
			$op\
			[reqGetArg CardBank]\
			[reqGetArg CardCountry]\
			[reqGetArg CardType]\
			[reqGetArg CardAllowDep]\
			[reqGetArg CardAllowWtd]\
			[reqGetArg CardReqScheme]]} msg]} {
		set bad 1
		err_bind $msg
	} else {
		catch {db_close $res}
	}
	inf_close_stmt $stmt

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar BinModFailed 1
	}
	if {$op == "D"} {
		go_card_query
	} else {
		go_card_bin
	}
}


proc do_block_query args {

	global DB DATA USERNAME

	if {[reqGetArg SubmitName] == "BlockAdd"} {
		tpSetVar opAdd 1
		asPlayFile -nocache card_block.html
		return
	}

	set prefix [string trim [reqGetArg CardBlockNo]]

	set prefix [remove_char $prefix " "]

	if {![regexp {^[0-9]*$} $prefix]} {
		error "Bad bin number"
	}

	if {[string length $prefix] > 6} {
		set prefix [md5 [string range 6 end $prefix]]
		set field b.card_hash
	} else {
		set field b.bin
	}

	set sql [subst {
		select
			b.card_block_id,
			b.enc_card_no,
			b.ivec,
			b.data_key_id,
			u.username,
			b.user_id,
			b.status,
			b.allowed,
			b.comment,
			b.bin,
			b.enc_with_bin
		from
			tCardBlock b,
			outer tAdminUser u
		where
			$field like '${prefix}%' and
			b.user_id = u.user_id
		order by
			b.bin asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set DATA($i,card_block_id) [db_get_col $res $i card_block_id]
		set DATA($i,username)      [db_get_col $res $i username]
		set DATA($i,allowed)       [db_get_col $res $i allowed]
		set DATA($i,status)        [db_get_col $res $i status]
		set DATA($i,comment)       [db_get_col $res $i comment]

		# Deal with card number
		set card_block_id [db_get_col $res $i card_block_id]
		set enc_card_no   [db_get_col $res $i enc_card_no]
		set ivec          [db_get_col $res $i ivec]
		set data_key_id   [db_get_col $res $i data_key_id]

		set dec_card_no ""

		if {$enc_card_no != ""} {
			set card_dec_rs [card_util::card_decrypt $enc_card_no $ivec \
			                 $data_key_id "Card Insert Validation" "" $USERNAME]
	
			if {[lindex $card_dec_rs 0] == 0} {
				# Check on the reason decryption failed, if we encountered
				# corrupt data we should also record this fact in the db
				if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
					card_util::update_data_enc_status \
					         "tCardBlock" $card_block_id [lindex $card_dec_rs 2]
				}

				ob::log::write ERROR \
				                {failed to decrypt customers card details: $msg}
				db_close $rs
				return [list 0 PMT_ERR]
			} else {
				set dec_card_no [lindex $card_dec_rs 1]
			}
		}
		set DATA($i,card_no) [card_util::format_card_no $dec_card_no \
		             [db_get_col $res $i bin] [db_get_col $res $i enc_with_bin]]
	}

	tpSetVar NumBlocks [db_get_nrows $res]

	tpBindVar CardBlockId      DATA card_block_id bin_idx
	tpBindVar CardBlockNo      DATA card_no       bin_idx
	tpBindVar CardBlockAllowed DATA allowed       bin_idx
	tpBindVar CardBlockStatus  DATA status        bin_idx
	tpBindVar CardBlockUser    DATA username      bin_idx 
	tpBindVar CardBlockComment DATA comment       bin_idx

	asPlayFile -nocache card_block_list.html

	db_close $res
}


proc go_card_block {{id ""}} {

	global DB USERNAME

	if {[reqGetArg SubmitName] == "Back"} {
		go_card_query
		return
	}

	if {$id == ""} {
		set id [reqGetArg CardBlockId]
	}

	if {$id == ""} {
		tpSetVar opAdd 1
	} else {
		tpSetVar opAdd 0

		set sql [subst {
			select
				card_block_id,
				enc_card_no,
				ivec,
				data_key_id,
				status,
				comment,
				allowed,
				bin,
				enc_with_bin
			from
				tCardBlock
			where
				card_block_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $id]
		inf_close_stmt $stmt

		tpBindString CardBlockId      [db_get_col $res 0 card_block_id]
		tpBindString CardBlockStatus  [db_get_col $res 0 status]
		tpBindString CardBlockAllowed [db_get_col $res 0 allowed]
		tpBindString CardBlockComment [db_get_col $res 0 comment]

		# Need to decrypt the card number
		set card_block_id [db_get_col $res 0 card_block_id]
		set bin           [db_get_col $res 0 bin]
		set enc_card_no   [db_get_col $res 0 enc_card_no]
		set ivec          [db_get_col $res 0 ivec]
		set data_key_id   [db_get_col $res 0 data_key_id]
		set enc_with_bin  [db_get_col $res 0 enc_with_bin]

		if {$enc_card_no != ""} {
			set card_dec_rs [card_util::card_decrypt $enc_card_no \
			                                         $ivec \
			                                         $data_key_id \
			                                         "View Card Block" \
			                                         "" \
			                                         USERNAME]

			if {[lindex $card_dec_rs 0] == 0} {
				# Check on the reason decryption failed, if we encountered 
				# corrupt data we should also record this fact in the db
				if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
					card_util::update_data_enc_status "tCardBlock" \
					$card_block_id [lindex $card_dec_rs 2]
				}
				ob::log::write ERROR {failed to decrypt customers card details:\
				                      $msg}
				db_close $rs
				return [list 0 PMT_ERR]
			} else {
				set dec_card_no [card_util::format_card_no \
				                     [lindex $card_dec_rs 1] $bin $enc_with_bin]
			}
		} else {
			set dec_card_no $bin
		}

		tpBindString CardBlockNo $dec_card_no

		db_close $res
	}

	asPlayFile -nocache card_block.html
}


proc do_card_block args {

	global DB USERNAME

	set bin [reqGetArg CardBin]
	set card_block_id [reqGetArg CardBlockId]

	set action [reqGetArg SubmitName]

	if {$action == "Back"} {
		go_card_query
		return
	}

	if {$action == "BlockAdd"} {
		set op I
	} elseif {$action == "BlockMod"} {
		set op U
	} elseif {$action == "BlockDel"} {
		reqSetArg CardBlockStatus "X"
		set op D
	} elseif {$action == "BlockAud"} {
		set op A
	} else {
		error "unexpected SubmitName : $action"
	}


	if {$op == "A"} {
		# If we want the audit history...
		# Show it
		set sql [subst {
			select
				aud_time,
				aud_op,
				user_id,
				status,
				allowed,
				comment,
				bin
			from
				tCardBlock_aud
			where
				card_block_id = ?
			order by 1
		}]

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {
			set res  [inf_exec_stmt $stmt $card_block_id]
		} msg]} {
			set bad 1
			err_bind $msg
		}

		inf_close_stmt $stmt

		tpSetVar NumRows [db_get_nrows $res]

		tpBindString CardBlockNo [reqGetArg CardBlockNo]

		tpBindTcl aud_time    sb_res_data $res bin_idx aud_time
		tpBindTcl aud_op      sb_res_data $res bin_idx aud_op
		tpBindTcl user_id     sb_res_data $res bin_idx user_id
		tpBindTcl CardBlockStatus      sb_res_data $res bin_idx status
		tpBindTcl CardBlockAllowed     sb_res_data $res bin_idx allowed
		tpBindTcl CardBlockComment     sb_res_data $res bin_idx comment

		asPlayFile -nocache card_block_audit.html

		db_close $res

		return

		}

	# Otherwise if we dont want audit history..
	set card_no     [remove_char [reqGetArg CardBlockNo] " "]
	set card_hash   [md5 $card_no]
	set bin         [string range $card_no 0 5]
	set bad         0
	set range_block "Y"
	set enc_card_no ""
	set data_key_id -1
	set ivec        ""

	if {[string length $card_no] > 6} {

		# We're trying to block a specific card number rather than a bin range,
		# check we've entered enough digits
		set range_block "N"

		set sql_card_length [subst {
			select
				num_digits
			from
				tCardScheme
			where
				bin_lo <= $bin
			and     bin_hi >= $bin
		}]

		set stmt_card_length [inf_prep_sql $DB $sql_card_length]
	
		if {[catch {
			set res_card_length [inf_exec_stmt $stmt_card_length]
		} msg]} {
			set bad 1
			err_bind $msg
			do_block_query
			return
		}
	
		inf_close_stmt $stmt_card_length
	
		if {[db_get_nrows $res_card_length] == 0} {
			set bad 1
			err_bind "The card no is not valid"
			db_close $res_card_length
			do_block_query
			return
		}
	
		if {[db_get_coln $res_card_length 0 0] != [string length $card_no]} {
			set bad 1
			err_bind "The length of the card should be\
			          [db_get_coln $res_card_length 0 0] for a full card number\
			          or inferior to 6 for a card bin"
			db_close $res_card_length
			do_block_query
			return
		}
		db_close $res_card_length

		# We also need to encrypt the card number to store
		if {[string range $card_no 6 end] != ""} {
			set enc_rs [card_util::card_encrypt \
			         [string range $card_no 6 end] "Blocking card" "" $USERNAME]
		
			if {[lindex $enc_rs 0] == 0} {
				set bad 1
				err_bind [lindex $enc_rs 1]
				do_block_query
				return
			}
		
			set enc_card_no [lindex [lindex $enc_rs 1] 0]
			set ivec        [lindex [lindex $enc_rs 1] 1]
			set data_key_id [lindex [lindex $enc_rs 1] 2]
		}
	}

	set sql [subst {
		execute procedure pCardBlock(
			p_card_block_id = ?,
			p_adminuser = ?,
			p_enc_card_no = ?,
			p_ivec = ?,
			p_data_key_id = ?,
			p_card_hash = ?,
			p_op = ?,
			p_status = ?,
			p_allowed = ?,
			p_comment = ?,
			p_bin = ?,
			p_range_block = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]
	
	if {[catch {
		set res [inf_exec_stmt $stmt\
			$card_block_id\
			$USERNAME\
			$enc_card_no\
			$ivec\
			$data_key_id\
			$card_hash\
			$op\
			[reqGetArg CardBlockStatus]\
			[reqGetArg CardBlockAllowed]\
			[reqGetArg CardBlockComment]\
			$bin\
			$range_block]} msg]} {
		set bad 1
		err_bind $msg
	} else {
		set card_block_id [db_get_coln $res 0]
		catch {db_close $res}
	}
	inf_close_stmt $stmt

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar BlockModFailed 1
	}
	if {$op == "D"} {
		go_card_query
	} else {
		go_card_block $card_block_id
	}
}


proc go_card_req_list args {

	global DB

	set submit_name [reqGetArg SubmitName]

	if {$submit_name == "CardReqQry"} {
		# find a range for a card bin
		set sql {
			select
				s.bin_lo
			from
				tCardScheme s
			where
				s.bin_lo = (select max(c.bin_lo) from tCardScheme c where c.bin_lo <= ?) and
				s.bin_hi >= ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt [reqGetArg CardBin] [reqGetArg CardBin]]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			go_card_req [db_get_col $res 0 bin_lo]
		} elseif {$nrows == 0} {
			err_bind "Card bin range does not exist for this card bin"
			go_card_query
		} else {
			err_bind "CardReqQry Query expected 1 row"
			go_card_query
			# something has gone wrong
		}

	} elseif {$submit_name == "CardReqAdd"} {
		# add a range
		go_card_req

	} else {
		# show all
		set sql {
	
			select
				s.bin_lo as bin_lo,
				s.bin_hi as bin_hi,
				i.scheme_name as scheme_name,
				s.num_digits as num_digits,
				s.issue_length as issue_length,
				s.start_date as start_date,
				s.expiry_date as expiry_date,
				decode (s.threed_secure_pol,0,'Resubmit',
											1,'Mandatory',
											2,'Never') threed_secure_pol
			from
				tCardScheme s,
				tCardSchemeInfo i
			where
				s.scheme = i.scheme
			order by
				bin_lo
		}
	
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	
		tpSetVar NumCardReqs [db_get_nrows $res]
	
		tpBindTcl CardReqBinLo     sb_res_data $res req_idx bin_lo
		tpBindTcl CardReqBinHi     sb_res_data $res req_idx bin_hi
		tpBindTcl CardReqType      sb_res_data $res req_idx scheme_name
		tpBindTcl CardReqDigits    sb_res_data $res req_idx num_digits
		tpBindTcl CardReqIssue     sb_res_data $res req_idx issue_length
		tpBindTcl CardReqStart     sb_res_data $res req_idx start_date
		tpBindTcl CardReqExpiry    sb_res_data $res req_idx expiry_date
		tpBindTcl CardReq3dsPol    sb_res_data $res req_idx threed_secure_pol
	
		asPlayFile -nocache card_req_list.html
	
		db_close $res

	}
}


proc go_card_req {{bin_lo ""}} {

	global DB

	set  CardReqScheme ""

	if {[reqGetArg SubmitName] == "CardReqAdd"} {
		tpSetVar AddNew 1

	} else {

		if {$bin_lo == ""} {
			set bin_lo [reqGetArg bin_lo]
		}

		set sql {
			select
					s.bin_lo as bin_lo,
					s.bin_hi as bin_hi,
					s.scheme as scheme,
					s.num_digits as num_digits,
					s.issue_length as issue_length,
					s.start_date as start_date,
					s.expiry_date as expiry_date,
					s.cvv2_length as cvv2_length,
					s.check_flag,
					s.first_dep_pol,
					s.flag_channels,
					s.threed_secure_pol
			  from
					tCardScheme s
			  where
					s.bin_lo = ?

		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $bin_lo]
		inf_close_stmt $stmt

		tpSetVar AddNew 0

		tpBindString CardReqBinLo     [db_get_col $res 0 bin_lo]
		tpBindString CardReqBinHi     [db_get_col $res 0 bin_hi]
		set  CardReqScheme            [db_get_col $res 0 scheme]
		tpBindString CardReqDigits    [db_get_col $res 0 num_digits]
		tpBindString CardReqIssue     [db_get_col $res 0 issue_length]
		tpBindString CardReqStart     [db_get_col $res 0 start_date]
		tpBindString CardReqExpiry    [db_get_col $res 0 expiry_date]
		tpBindString CardReqCVV2Length  [db_get_col $res 0 cvv2_length]
		tpBindString CardReqCheckFlag   [db_get_col $res 0 check_flag]
		tpBindString CardReqFirstDepPol [db_get_col $res 0 first_dep_pol]
		tpBindString CardReq3dSecurePol [db_get_col $res 0 threed_secure_pol]

		# now channels
		make_channel_binds [db_get_col $res 0 flag_channels] -

		db_close $res

	}

	# Bind up the card schemes to choose from.
	# Get this info from tcardschemeinfo.
	bind_card_schemes $CardReqScheme

	asPlayFile -nocache card_req.html
}


proc bind_card_schemes {{selected_scheme ""}} {

	global DB SCHEMES

	#
	# Retrieve card schemes
	#
	set scheme_sql {
		select
			scheme,
			scheme_name
		from
			tCardSchemeInfo
		order by
			scheme
	}

	set stmt [inf_prep_sql $DB $scheme_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumSchemes [set n_rows [db_get_nrows $res]]

	array set SCHEMES ""

	for {set r 0} {$r < $n_rows} {incr r} {

		set scheme [db_get_col $res $r scheme]

		set SCHEMES($r,scheme) $scheme
		set SCHEMES($r,scheme_name) [db_get_col $res $r scheme_name]

		if {$selected_scheme == $scheme} {
			set SCHEMES($r,scheme_sel) SELECTED
		} else {
			set SCHEMES($r,scheme_sel) ""
		}
	}

	tpBindVar Scheme     SCHEMES scheme      scheme_idx
	tpBindVar SchemeName SCHEMES scheme_name scheme_idx
	tpBindVar SchemeSel  SCHEMES scheme_sel  scheme_idx

	db_close $res
}


proc do_card_req args {

	set action [reqGetArg SubmitName]

	if {$action == "Back"} {
		go_card_req_list
	} elseif {$action == "CardReqIns"} {
		do_card_req_ins
	} elseif {$action == "CardReqMod"} {
		do_card_req_mod
	} elseif {$action == "CardReqDel"} {
		do_card_req_del
	} else {
		error "Unknown action ($action)"
	}
}


proc do_card_req_ins args {

	global DB USERNAME
	set sql [subst {
		execute procedure pInsCardReqFields(
			p_adminuser = ?,
			p_bin_lo = ?,
			p_bin_hi = ?,
			p_scheme = ?,
			p_num_digits = ?,
			p_issue_len = ?,
			p_start_date = ?,
			p_expiry_date = ?,
			p_cvv2_length = ?,
			p_check_flag = ?,
			p_first_dep_pol = ?,
			p_threed_secure_pol = ?,
			p_flag_channels = ?
		)
	}]

	set flag_channels [make_channel_str]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CardReqBinLo]\
			[reqGetArg CardReqBinHi]\
			[reqGetArg CardReqScheme]\
			[reqGetArg CardReqDigits]\
			[reqGetArg CardReqIssue]\
			[reqGetArg CardReqStart]\
			[reqGetArg CardReqExpiry]\
			[reqGetArg CardReqCVV2Length]\
			[reqGetArg CardReqCheckFlag]\
			[reqGetArg CardReqFirstDepPol]\
			[reqGetArg CardReq3dSecurePol]\
			$flag_channels]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		reqSetArg SubmitName "CardReqAdd"
		go_card_req
		return
	}

	msg_bind "Card bin range inserted"
	
	go_card_req [reqGetArg CardReqBinLo]
}


proc do_card_req_mod args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdCardReqFields(
			p_adminuser = ?,
			p_bin_lo_old = ?,
			p_bin_hi_old = ?,
			p_bin_lo = ?,
			p_bin_hi = ?,
			p_scheme = ?,
			p_num_digits = ?,
			p_issue_len = ?,
			p_start_date = ?,
			p_expiry_date = ?,
			p_cvv2_length = ?,
			p_check_flag = ?,
			p_first_dep_pol = ?,
			p_threed_secure_pol = ?,
			p_flag_channels = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set flag_channels [make_channel_str]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg bin_lo]\
			[reqGetArg bin_hi]\
			[reqGetArg CardReqBinLo]\
			[reqGetArg CardReqBinHi]\
			[reqGetArg CardReqScheme]\
			[reqGetArg CardReqDigits]\
			[reqGetArg CardReqIssue]\
			[reqGetArg CardReqStart]\
			[reqGetArg CardReqExpiry]\
			[reqGetArg CardReqCVV2Length]\
			[reqGetArg CardReqCheckFlag]\
			[reqGetArg CardReqFirstDepPol]\
			[reqGetArg CardReq3dSecurePol]\
			$flag_channels]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		go_card_req
		return
	}

	msg_bind "Card bin range modified"

	go_card_req [reqGetArg CardReqBinLo]
}


proc do_card_req_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelCardReqFields(
			p_adminuser = ?,
			p_bin_lo = ?,
			p_bin_hi = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg bin_lo]\
			[reqGetArg bin_hi]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		go_card_req
		return
	}
	go_card_req_list
}

}
