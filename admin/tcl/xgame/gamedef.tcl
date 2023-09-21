# ==============================================================
# $Id: gamedef.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc show_gamedef {} {



    # default system ccy for informational purposes onlyy
    set sql {
		select
			ccy_code,
			ccy_name
		from tcontrol,
			tCCY
		where
			tCCY.ccy_code = tcontrol.default_ccy
    }

    set rs [xg_exec_qry $sql [reqGetArg sort]]
    if [catch {tpBindString ccy_code "[db_get_col $rs ccy_code]: [db_get_col $rs ccy_name]"} msg] {
		tpBindString ccy_code "No system currency specified: $msg"
    }
    db_close $rs



    # is the game stake allowed to be continuous (or discrete)
    set sql {
		select
			stake_mode,
			min_stake,
			max_stake,
			min_subs,
			max_subs,
			max_card_payout,
			cheque_payout_msg,
			max_payout,
--			xgame_attr,
			channels
		from tXGameDef
		where sort = ?
	}
	set rs [xg_exec_qry $sql [reqGetArg sort]]

	tpBindString max_card_payout [db_get_col $rs max_card_payout]
	tpBindString cheque_payout_msg [db_get_col $rs cheque_payout_msg]
	tpBindString MaxPayout [db_get_col $rs max_payout]

	if {[OT_CfgGet XG_HAVE_CHANNELS "0"] == "1"} {
		tpSetVar XG_HAVE_CHANNELS 1
		make_channel_binds [db_get_col $rs channels] "-"
	}

	if {[OT_CfgGet XG_DYNAMIC_SUB_LIMITS "0"] == "1"} {
		tpBindString MinSubs [db_get_col $rs min_subs]
		tpBindString MaxSubs [db_get_col $rs max_subs] "1"} {
	}


	if {[db_get_col $rs stake_mode]=="C"} {
		tpSetVar CtsStakes 1
		tpBindString sort [reqGetArg sort]
		tpBindString StakeMode "C"
		tpBindString MinStake [db_get_col $rs min_stake]
		tpBindString MaxStake [db_get_col $rs max_stake]
		db_close $rs
	} else {
		tpSetVar CtsStakes 0
		db_close $rs
		# if discrete case
		set sql {
			select
				stake
			from txgamedefstake
			where sort = ?
			order by stake asc
    	}
    	tpBindString sort [reqGetArg sort]
    	set rs [xg_exec_qry $sql [reqGetArg sort]]
    	xg_bind_rs $rs gamedefstake

    	db_close $rs
    }


    set sort [reqGetArg sort]

    if {[OT_CfgGet XG_GAME_OPTIONS "0"] == "1"} {
	    #
	    #	Populate Game Options table

	    BindGameOptions $sort
    }

	##If it's not a Littlewoods game then it has fixed odds

    if {[lsearch {"PBUST3" "PBUST4" "SATPOOL" "MONTHPOOL"} $sort] == -1} {

    	if {[OT_CfgGet XG_DYNAMIC_PRICES "0"] == "1"} {
	    #
	    #	Populate Game Price table
	    tpSetVar XG_DYNAMIC_PRICES 1
	    BindGamePrices $sort
    	}
    }

    # X_play_file gamedefstake.html
    X_play_file editgamedef.html

}




#
# Each game has a number of variations: varying the number of picks permitted for the game.
# This proc simply retrieves the details of these game variations (number of permitted picks)
# and status flag to indicate whether or not the specific variation is currently available.
#
proc BindGameOptions {sort} {

    global xgaQry

    if {$sort !=""} {
	if [catch {set rs [xg_exec_qry $xgaQry(get_game_options) $sort]} msg] {
	    return [handle_err "game_options" "error: $msg"]
	}

	xg_bind_rs $rs OPTIONS

	set nrows [db_get_nrows $rs]

	db_close $rs
  }

}
#end BindGameOptions


#
# Prices are associated with user selecting X picks and getting so many correct.
# This proc retrieves such information from the price table.
# Retrieves information on current valid prices.
#
proc BindGamePrices {sort} {


    global xgaQry


    if {$sort != ""} {

	if {[OT_CfgGet XG_PRICES "SP"] == "SP"} {

		# Bind prices already setup
		if [catch {set rs [xg_exec_qry $xgaQry(get_valid_game_prices) $sort]} msg] {
		    return [handle_err "game_prices" "error: $msg"]
		}
	} else {
		set curr_date_time [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

		# Bind prices already setup
		if [catch {set rs [xg_exec_qry $xgaQry(get_valid_game_prices) $sort $curr_date_time $curr_date_time]} msg] {
		    return [handle_err "game_prices" "error: $msg"]
		}

	}

	xg_bind_rs $rs

	set nrows [db_get_nrows $rs]

	db_close $rs

    }
}
#end BindGamePrices



proc delete_gamedef_stake {} {

    set sql {
	delete from tXGameDefStake
	where sort = ?
	and stake = ?
    }

    set rs [xg_exec_qry $sql [reqGetArg sort] [reqGetArg stake]]
    db_close $rs

    show_gamedef

}

proc add_gamedef_stake {} {

    set sql {
	insert into tXGameDefStake (sort,stake)
	values (?,?)
    }

    set rs [xg_exec_qry $sql [reqGetArg sort] [reqGetArg stake]]
    db_close $rs

    show_gamedef
}

proc modify_gamedef_stake {} {
	set sort		[reqGetArg sort]
	set stake_mode 	[reqGetArg stake_mode]
	set min_stake 	[reqGetArg min_stake]
	set max_stake	[reqGetArg max_stake]

	if {[regexp {[^0-9\.]} $min_stake]} {
		return [handle_err "Incorrect stake" "The Min Stake contained an invalid character."]
    }
	if {[regexp {[^0-9\.]} $max_stake]} {
		return [handle_err "Incorrect stake" "The Max Stake contained an invalid character."]
    }
	if {$min_stake > $max_stake} {
		return [handle_err "Incorrect stake" "The Min Stake should be less than or equal to Max Stake."]
    }

	set sql {
		update tXGameDef
		set min_stake	= ?	,
			max_stake	= ?
		where sort = ? and
			stake_mode 	= ?
    }

    set rs [xg_exec_qry $sql $min_stake $max_stake $sort $stake_mode]
    db_close $rs

 	show_gamedef
}


#
#	Updates gamedef table fields used to restrict number of subscriptions permitted.
#
proc modify_gamedef_sub_limits {} {
	set sort	[reqGetArg sort]
	set min_subs 	[reqGetArg min_subs]
	set max_subs	[reqGetArg max_subs]


	if {[regexp {[^0-9\.]} $min_subs]} {
		return [handle_err "Incorrect number of minimum subscriptions." "The field contained an invalid character."]
    }
	if {[regexp {[^0-9\.]} $max_subs]} {
		return [handle_err "Incorrect number of maximum subscriptions." "The field contained an invalid character."]
    }
	if {$min_subs > $max_subs} {
		return [handle_err "Incorrect restriction placed on number of subscriptions taken for a game." "The Min Subscriptions should be less than or equal to Max Stake."]
    }

	set sql {
		update tXGameDef
		set min_subs	= ?	,
		    max_subs	= ?
		where sort = ?
    }

    set rs [xg_exec_qry $sql $min_subs $max_subs $sort ]
    db_close $rs

    show_gamedef
}

proc modify_xgdef_chans {} {
	set sort [reqGetArg sort]
	set channels [make_channel_str]

	set sql {
		update tXGameDef
		set channels = ?
		where sort = ?
	}

	set rs [xg_exec_qry $sql $channels $sort]
	db_close $rs

	show_gamedef
}

proc modify_gamedef_max_card_payout {} {
	set sort [reqGetArg sort]
	set max_card_payout [reqGetArg max_card_payout]
	set cheque_payout_msg [reqGetArg cheque_payout_msg]

	if {[regexp {[^0-9\.]} $max_card_payout]} {
		return [handle_err "Incorrect Maximum card payout" "The Maximum Card payout contained an invalid character."]
    }

	set sql {
		update tXGameDef
		set max_card_payout = ?,
		    cheque_payout_msg = ?
		where sort = ?
	}

	set rs [xg_exec_qry $sql $max_card_payout $cheque_payout_msg $sort]
	db_close $rs

	show_gamedef
}

proc modify_gamedef_max_payout {} {
	set sort [reqGetArg sort]
	set max_payout [reqGetArg max_payout]

	if {[regexp {[^0-9\.]} $max_payout]} {
		return [handle_err "Incorrect Maximum payout" "The Maximum payout contained an invalid character."]
    }

	set sql {
		update tXGameDef
		set max_payout = ?
		where sort = ?
	}

	set rs [xg_exec_qry $sql $max_payout $sort]
	db_close $rs

	show_gamedef
}

#
#	Adds new price for a game - to be given when punter get so many balls of X picks correct.
#
proc add_game_price {} {
	global xgaQry


	# read request params
	set PRICE_INFO(sort)		[reqGetArg sort]
	set PRICE_INFO(num_picks)	[reqGetArg num_picks]
	set PRICE_INFO(num_correct)	[reqGetArg num_correct]
	set PRICE_INFO(num_void)	[reqGetArg num_void]
	set PRICE_INFO(price_num)	[reqGetArg price_num]
	set PRICE_INFO(price_den)	[reqGetArg price_den]
	set PRICE_INFO(refund_mult)	[reqGetArg refund_mult]

	set PRICE_INFO(pricing_type)    [OT_CfgGet XG_PRICES]
	set PRICE_INFO(cr_date_time)    [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]


	# validate against db constraints
	if {[validate_price_change [array get PRICE_INFO]] != 1} {
		return;
	}

	if [catch {xg_exec_qry $xgaQry(add_game_price)\
		$PRICE_INFO(sort)\
		$PRICE_INFO(num_picks)\
		$PRICE_INFO(num_correct)\
		$PRICE_INFO(num_void)\
		$PRICE_INFO(price_num)\
		$PRICE_INFO(price_den)\
		$PRICE_INFO(refund_mult)\
		$PRICE_INFO(pricing_type)\
		$PRICE_INFO(cr_date_time)} msg] {
		return [handle_err "add_game_price" "err: $msg"]
	}

	# return to gamedef page
        show_gamedef
}
# end add_game_price



#
#	Deletes  price for a game
#
proc delete_game_price {} {
	global xgaQry

	set price_id	 [reqGetArg price_id]
	set cr_date_time [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	set pricing_type [OT_CfgGet XG_PRICES]

	if [catch {xg_exec_qry $xgaQry(delete_game_price)\
		$price_id\
		$pricing_type\
		$cr_date_time} msg] {
		return [handle_err "delete_game_price" "err: $msg"]
	}

	# return to gamedef page
        show_gamedef

}
# end delete_game_price




#
#	Updates  price for a game
#
proc modify_game_price {} {
	global xgaQry



	set PRICE_INFO(sort)		[reqGetArg sort]
	set PRICE_INFO(num_picks)	[reqGetArg num_picks]
	set PRICE_INFO(num_correct)	[reqGetArg num_correct]
	set PRICE_INFO(num_void)	[reqGetArg num_void]
	set PRICE_INFO(price_num)	[reqGetArg price_num]
	set PRICE_INFO(price_den)	[reqGetArg price_den]
	set PRICE_INFO(refund_mult)	[reqGetArg refund_mult]

	set PRICE_INFO(pricing_type)    [OT_CfgGet XG_PRICES]
	set PRICE_INFO(cr_date_time)    [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	set PRICE_INFO(price_id)	[reqGetArg price_id]



	# validate against db constraints
	if {[validate_price_change [array get PRICE_INFO]] != 1} {
		return;
	}


	if [catch {xg_exec_qry $xgaQry(modify_game_price)\
		$PRICE_INFO(sort)\
		$PRICE_INFO(num_picks)\
		$PRICE_INFO(num_correct)\
		$PRICE_INFO(num_void)\
		$PRICE_INFO(price_num)\
		$PRICE_INFO(price_den)\
		$PRICE_INFO(refund_mult)\
		$PRICE_INFO(pricing_type)\
		$PRICE_INFO(cr_date_time)\
		$PRICE_INFO(price_id)} msg] {
		return [handle_err "modify game price" "err: $msg"]
	}




	# return to gamedef page
        show_gamedef

}
# end modify_game_price



#       args:
#		LIST_PRICE - list representation of array holding price info to be validated
#
#	Validates user price request against db constraings.
#
proc validate_price_change {LIST_PRICE} {


	array set PRICE_INFO $LIST_PRICE

	# Check price
	if {$PRICE_INFO(num_picks) != "" && $PRICE_INFO(num_picks) <= 0}  {
		return [handle_err "Incorrect number of picks. " "Num picks should be greater than 0 or NA"]
	}

	if {$PRICE_INFO(num_correct) != "" && $PRICE_INFO(num_correct) <= 0}  {
		return [handle_err "Incorrect number correct. " "Num correct should be greater than 0 or NA"]
	}

	if {$PRICE_INFO(num_void) != "" && $PRICE_INFO(num_void) < 0}  {
		return [handle_err "Incorrect number void. " "Num void should be equal to greater than 0 or NA"]
	}

	if {$PRICE_INFO(price_num) == "" && $PRICE_INFO(price_den) == "" && $PRICE_INFO(refund_mult) == ""} {
		return [handle_err "No price or refund multiplier has been entered." "Please enter values for one of these fields"]
	}


	if {$PRICE_INFO(price_num) != "" && $PRICE_INFO(price_den) != "" && $PRICE_INFO(refund_mult) != ""} {
		return [handle_err "Both price and refund multiplier has been entered." "Only one entry is possible at a time."]
	}

	if {$PRICE_INFO(price_num) != "" && [regexp {[^0-9\.]} $PRICE_INFO(price_num)] } {
		return [handle_err "Incorrect number for price_num. " "The field contained an invalid character."]
	}

	if {$PRICE_INFO(price_den) != "" && [regexp {[^0-9\.]} $PRICE_INFO(price_den)] } {
		return [handle_err "Incorrect number for price_den. " "The field contained an invalid character."]
	}

	if {$PRICE_INFO(price_num) != "" && $PRICE_INFO(price_den) != ""} {
		if {$PRICE_INFO(price_den) < 1 || $PRICE_INFO(price_num) < 1 } {
			return [handle_err "Invalid price entered." "A zero has been entered in the price."]
		}
	}

	if {$PRICE_INFO(refund_mult) != "" && [regexp {[^0-9\.]} $PRICE_INFO(refund_mult)] } {
		return [handle_err "Incorrect number for refund multiplier. " "A decimal value is required."]
	}

	if {$PRICE_INFO(refund_mult) != "" && $PRICE_INFO(refund_mult) < 0 || $PRICE_INFO(refund_mult) > 1} {
		return [handle_err "Incorrect number for refund multiplier. " "Please select a value between 0 and 1"]
	}

	if {$PRICE_INFO(num_correct) != "" && $PRICE_INFO(num_picks) != "" && $PRICE_INFO(num_picks) < $PRICE_INFO(num_correct)} {
		return [handle_err "Incorrect combination" "Number correct is less than the number picked"]
	}

	return 1;

}
# end validate_price_change




#
#	Update status of game options
#
proc modify_game_options {} {
	global xgaQry




	set status_list_string	   [reqGetArg status_list]
	set option_id_list_string [reqGetArg option_id_list]


	set status_list     [split $status_list_string |]
	set option_id_list  [split $option_id_list_string |]




	# make sure both are of same length
	set nOptions [llength $option_id_list]

	if {$nOptions != [llength $status_list]} {
		return [handle_err "Unable to modify game options: " "err: modify_game_options has been passed inadequate data. See Administrator"]
	}


	# Now update each
	foreach s $status_list opt $option_id_list {

		if [catch {xg_exec_qry $xgaQry(modify_game_option_status)\
			$s\
			$opt} msg] {
			return [handle_err "modify game option status" "err: $msg"]
		}
	}



	# return to gamedef page
        show_gamedef

}
# end modify_game_options


