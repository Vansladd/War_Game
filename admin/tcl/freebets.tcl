# ==============================================================
# $Id: freebets.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::FREEBETS {

asSetAct ADMIN::FREEBETS::GoTriggerTypesList [namespace code go_trigger_type_list]
asSetAct ADMIN::FREEBETS::GoTriggerType [namespace code go_trigger_type]
asSetAct ADMIN::FREEBETS::GoAddTType [namespace code go_add_trigger_type]
asSetAct ADMIN::FREEBETS::DoTriggerType [namespace code do_trigger_type]

asSetAct ADMIN::FREEBETS::GoOffersList [namespace code go_offer_list]
asSetAct ADMIN::FREEBETS::GoOffer [namespace code go_offer]
asSetAct ADMIN::FREEBETS::GoAddOffer [namespace code go_add_offer]
asSetAct ADMIN::FREEBETS::DoOffer [namespace code do_offer]

asSetAct ADMIN::FREEBETS::GoAddTrigger [namespace code go_add_trigger]
asSetAct ADMIN::FREEBETS::GoTrigger [namespace code go_trigger]
asSetAct ADMIN::FREEBETS::DoTrigger [namespace code do_trigger]
asSetAct ADMIN::FREEBETS::DoTriggerLevel [namespace code do_trigger_level]
asSetAct ADMIN::FREEBETS::GoTriggerSelect [namespace code go_trigger_select]

asSetAct ADMIN::FREEBETS::GoRValList [namespace code go_rval_list]
asSetAct ADMIN::FREEBETS::GoRVal [namespace code go_rval]
asSetAct ADMIN::FREEBETS::GoAddRVal [namespace code go_add_rval]
asSetAct ADMIN::FREEBETS::DoRVal [namespace code do_rval]
asSetAct ADMIN::FREEBETS::GoRvalDetail [namespace code go_rval_detail]

asSetAct ADMIN::FREEBETS::GoAddToken [namespace code go_add_token]
asSetAct ADMIN::FREEBETS::GoToken [namespace code go_token]
asSetAct ADMIN::FREEBETS::DoToken [namespace code do_token]

asSetAct ADMIN::FREEBETS::GoPossBet [namespace code go_pb]
asSetAct ADMIN::FREEBETS::GoAddPB [namespace code do_add_pb]
asSetAct ADMIN::FREEBETS::GoDelPB [namespace code do_pb_del]

asSetAct ADMIN::FREEBETS::go_bet_dd_level [namespace code go_bet_dd_level]
asSetAct ADMIN::FREEBETS::go_bet_dd [namespace code go_bet_dd]
asSetAct ADMIN::FREEBETS::go_bet_xgame_types [namespace code go_bet_xgame_types]
asSetAct ADMIN::FREEBETS::go_bet_xgame_bets [namespace code go_bet_xgame_bets]

asSetAct ADMIN::FREEBETS::go_bet_dd_xgame_draw   [namespace code go_bet_dd_xgame_draw]

asSetAct ADMIN::FREEBETS::GoGenerateVouchers [namespace code go_generate_vouchers]
asSetAct ADMIN::FREEBETS::GoGenerateVouchersSelect [namespace code go_generate_vouchers_select]
asSetAct ADMIN::FREEBETS::GoGenerateTriggerSelect [namespace code go_generate_trigger_select]
asSetAct ADMIN::FREEBETS::DoGenerateVouchers [namespace code do_generate_vouchers]
asSetAct ADMIN::FREEBETS::GoGenerateVoucherRunsSelect [namespace code go_num_voucher_runs_select]
asSetAct ADMIN::FREEBETS::GoDisplayFile [namespace code display_file]

asSetAct ADMIN::FREEBETS::go_netballs_dd [namespace code go_netballs_dd]

proc bind_xgame_check {} {

	global DB
	global TRIG_XGAM

	catch {unset TRIG_XGAM}

	if {[reqGetArg SelTrigCode] == "XGAMEBET" || [reqGetArg SelTrigCode] == "XGAMEBET1"} {

		OT_LogWrite 10 "XGAMEBET: 1"

		tpSetVar XGAMEBET 1

		set sql {
			select
				sort,
				name
			from
				tXGameDef
		}

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar num_sorts [db_get_nrows $rs]

		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			set TRIG_XGAM($i,code) [db_get_col $rs $i sort]
			set TRIG_XGAM($i,name) [db_get_col $rs $i name]
		}

		tpBindVar GameSort TRIG_XGAM code xgame_idx
		tpBindVar GameName TRIG_XGAM name xgame_idx

		db_close $rs

	} else {
		OT_LogWrite 10 "XGAMEBET: 0"
		tpSetVar XGAMEBET 0
	}
}

proc bind_trigger_types {} {

	global DB
	global TRIG_TYPES

	catch {unset TRIG_TYPES}

	set sql {
		select
			type_code,
			name
		from
			tTriggerType
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		err_bind $msg
		asPlayFile -nocache trigger.html
		return
	}

	inf_close_stmt $stmt

	tpSetVar num_trigs [db_get_nrows $rs]

	tpSetVar TrigCode [db_get_col $rs 0 type_code]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set TRIG_TYPES($i,code) [db_get_col $rs $i type_code]
		set TRIG_TYPES($i,name) [db_get_col $rs $i name]
	}

	tpBindVar TrigCode TRIG_TYPES code t_idx
	tpBindVar TrigName TRIG_TYPES name t_idx

	db_close $rs
}

proc bind_intro_sources {args} {
	# get the introductory source stuff from the db and bind it
	global DB
	global ITArray
	catch {unset ITArray}

	set it_sql {
		select * from thearabouttype
		where  status='A'
		order by disporder
	}
	set is_sql {
		select * from thearabout
		where  status = 'A'
		order by hear_about_type, disporder
	}

	set it_stmt [inf_prep_sql $DB $it_sql]
	set is_stmt [inf_prep_sql $DB $is_sql]

	if {[catch {set it_rs [inf_exec_stmt $it_stmt]} msg]} {
		err_bind $msg
		asPlayFile -nocache trigger.html
		return
	}

	if {[catch {set is_rs [inf_exec_stmt $is_stmt]} msg]} {
		err_bind $msg
		asPlayFile -nocache trigger.html
		return
	}

	inf_close_stmt $it_stmt
	inf_close_stmt $is_stmt

	# now do the binding
	set ITcount [db_get_nrows $it_rs]
	for {set j 0} {$j < $ITcount} {incr j} {
		set ITArray($j,type) [db_get_col $it_rs $j hear_about_type]
		set ITArray($j,desc) [db_get_col $it_rs $j desc]

		if {$is_rs == ""} {
			set ITArray($j,0,source) "[ml_printf REG_STAGE5_NONE]"
			set ITArray($j,0,desc)   "[ml_printf REG_STAGE5_NONE_AVAIL]"
			set ITArray($j,0,count)  0
		} else {
			set c 0
			set ITArray($j,0,count) 0
			for {set k 0} {$k < [db_get_nrows $is_rs]} {incr k} {
				if {![string compare [db_get_col $is_rs $k hear_about_type] \
									 [db_get_col $it_rs $j hear_about_type]]} {
					set ITArray($j,$c,source) [db_get_col $is_rs $k hear_about]
					set ITArray($j,$c,desc) [db_get_col $is_rs $k desc]
					incr ITArray($j,0,count)
					incr c
				}
				# close the for-loop over sources
			}
		}
		# now close the for-loop over the types
	}

	set ITArray(type_count) $ITcount

	# bind up the variables for stage5.html
	tpSetVar numTypes    $ITcount
	tpBindVar typeName   ITArray type     type_idx
	tpBindVar typeDesc   ITArray desc     type_idx

	tpBindVar sourceName ITArray source   type_idx source_idx
	tpBindVar sourceDesc ITArray desc     type_idx source_idx
	tpBindVar sourceType ITArray type     type_idx source_idx

	# note: ITArray(<n>,0,count) must be available to the page for all n
	# between 0 and $ITcount: ITArray(0,0,count) must ALWAYS be set.

	return
}

proc bind_voucher_types {} {

	global DB
	global VOUCHER_TYPES

	catch {unset VOUCHER_TYPES}

	set sql {
		select
			type_code,
			name
		from
			tVoucherType
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		err_bind $msg
		asPlayFile -nocache voucher.html
		return
	}

	inf_close_stmt $stmt

	tpSetVar num_vouchers [db_get_nrows $rs]

	set first_voucher_code [db_get_col $rs 0 type_code]

	tpSetVar VoucherCode [db_get_col $rs 0 type_code]
	tpBindString SelVoucherCode $first_voucher_code

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set VOUCHER_TYPES($i,code) [db_get_col $rs $i type_code]
		set VOUCHER_TYPES($i,name) [db_get_col $rs $i name]
	}

	tpBindVar VoucherCode VOUCHER_TYPES code v_idx
	tpBindVar VoucherName VOUCHER_TYPES name v_idx

	db_close $rs

	return $first_voucher_code
}

proc bind_voucher_triggers {type} {

	global DB
	global VOUCHER_TRIGGERS

	set first_trigger_id 0

	catch {unset VOUCHER_TRIGGERS}

	set sql {
		select
			o.offer_id,
			o.name,
			t.trigger_id,
			t.aff_level,
			t.aff_id,
			t.aff_grp_id
		from
			tOffer o,
			tTrigger t
		where
			o.offer_id = t.offer_id and
			t.voucher_type = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $type]} msg]} {
		err_bind $msg
		asPlayFile -nocache voucher.html
		return
	}

	inf_close_stmt $stmt

	tpSetVar num_voucher_triggers [db_get_nrows $rs]

	if {[db_get_nrows $rs] != 0} {

		set first_trigger_id [db_get_col $rs 0 trigger_id]
		tpSetVar TriggerId $first_trigger_id
		tpBindString SelVoucherTrigger $first_trigger_id

		tpBindString AffLevel [db_get_col $rs 0 aff_level]
		tpBindString AffId [db_get_col $rs 0 aff_id]
		tpBindString AffGrpId [db_get_col $rs 0 aff_grp_id]

		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

			set VOUCHER_TRIGGERS($i,trigger_id) [db_get_col $rs $i trigger_id]
			set VOUCHER_TRIGGERS($i,offer_name) [db_get_col $rs $i name]

			if {$VOUCHER_TRIGGERS($i,trigger_id) == [reqGetArg SelVoucherTrigger]} {
				tpBindString AffLevel [db_get_col $rs $i aff_level]
				tpBindString AffId [db_get_col $rs $i aff_id]
				tpBindString AffGrpId [db_get_col $rs $i aff_grp_id]
			}
		}

		tpBindVar VoucherTriggersId VOUCHER_TRIGGERS trigger_id vt_idx
		tpBindVar VoucherTriggersName VOUCHER_TRIGGERS offer_name vt_idx

	}

	db_close $rs

	return $first_trigger_id
}

proc bind_referral_offers {} {

	global DB
	global REFERRAL_OFFERS

	set first_offer_id 0

	catch {unset REFERRAL_OFFERS}

	set sql {
		select
			o.offer_id,
			o.name
		from
			tOffer o,
			tTrigger t
		where
			o.offer_id = t.offer_id and
			t.type_code = 'REFERRAL'
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		err_bind $msg
		asPlayFile -nocache trigger.html
		return
	}

	inf_close_stmt $stmt

	tpSetVar num_ref_offers [db_get_nrows $rs]

	if {[db_get_nrows $rs] != 0} {

		set first_offer_id [db_get_col $rs 0 offer_id]
		tpSetVar OfferId $first_offer_id
		tpBindString SelRefOfferId $first_offer_id

		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

			set REFERRAL_OFFERS($i,offer_id) [db_get_col $rs $i offer_id]
			set REFERRAL_OFFERS($i,offer_name) [db_get_col $rs $i name]

		}

		tpBindVar RefOfferId REFERRAL_OFFERS offer_id r_idx
		tpBindVar RefOfferName REFERRAL_OFFERS offer_name r_idx

	}

	db_close $rs

	return $first_offer_id
}


proc bind_channels {} {

	global DB
	global TRIG_CHANNELS

	catch {unset TRIG_CHANNELS}

	set sql {
		select
			channel_id,
			desc
		from
			tchannel
	}

	set stmt       [inf_prep_sql $DB $sql]
	set rs         [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar num_channels  [expr {[db_get_nrows $rs] + 1}]

	
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set TRIG_CHANNELS($i,code) [db_get_col $rs $i channel_id]
		set TRIG_CHANNELS($i,name) [db_get_col $rs $i desc]
	}

	set TRIG_CHANNELS($i,code) ""
	set TRIG_CHANNELS($i,name) "Any"

	tpBindVar ChanId   TRIG_CHANNELS code c_idx
	tpBindVar ChanName TRIG_CHANNELS name c_idx

	db_close $rs
}


# Get all the currencies associated with this offer_id
# also get all the currencies that are not in this offer
proc bind_currencies_for_offer_id {{offer_id "-1"}} {

	global DB
	global NOT_SELECTED_CCY
	global SELECTED_CCY

	OT_LogWrite 10 "bind_currencies_for_offer_id $offer_id"

	# get the currencies that are not selected for this offer
	catch {unset NOT_SELECTED_CCY}
	set sql {select
				 c.ccy_code,
				 c.ccy_name
			 from
				 tccy      c
			 where
				 c.ccy_code not in (
					 select
						 ccy_code
					 from
						 tofferccy
					 where
						 offer_id = ?
	)}

	set stmt       [inf_prep_sql $DB $sql]
	set rs         [inf_exec_stmt $stmt $offer_id]
	inf_close_stmt $stmt

	tpSetVar  NUM_NOT_SELECTED_CCYS [db_get_nrows $rs]

	set NOT_SELECTED_CCY(num_ccys) [db_get_nrows $rs]

	OT_LogWrite 10 "NUM_NOT_SELECTED_CCYS [db_get_nrows $rs]"

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set NOT_SELECTED_CCY($i,code)     [db_get_col $rs $i ccy_code]
		set NOT_SELECTED_CCY($i,name)     [db_get_col $rs $i ccy_name]
	}
	tpBindVar NOT_SELECTED_CCY_CODE     NOT_SELECTED_CCY code     ncc_idx
	tpBindVar NOT_SELECTED_CCY_NAME     NOT_SELECTED_CCY name     ncc_idx

	db_close $rs


	# get the currencies that are selected for this offer
	catch {unset SELECTED_CCY}
	set sql {select
				 c.ccy_code,
				 c.ccy_name
			 from
				 tofferccy o,
				 tccy      c
			 where
				 o.offer_id = ?
			 and
			 o.ccy_code = c.ccy_code}

	set stmt       [inf_prep_sql $DB $sql]
	set rs         [inf_exec_stmt $stmt $offer_id]
	inf_close_stmt $stmt

	tpSetVar  NUM_SELECTED_CCYS [db_get_nrows $rs]

	set SELECTED_CCY(num_ccys) [db_get_nrows $rs]

	OT_LogWrite 10 "NUM_SELECTED_CCYS [db_get_nrows $rs]"

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set SELECTED_CCY($i,code)     [db_get_col $rs $i ccy_code]
		set SELECTED_CCY($i,name)     [db_get_col $rs $i ccy_name]
	}
	tpBindVar SELECTED_CCY_CODE     SELECTED_CCY code     cc_idx
	tpBindVar SELECTED_CCY_NAME     SELECTED_CCY name     cc_idx

	db_close $rs

	OT_LogWrite 1 "BOUND CCYs for offer_id $offer_id"
}

# Get all the currencies associated with this token_id
# also get all the currencies that are not in this offer
proc bind_token_amounts {{token_id ""} {offer_id ""}} {

	global DB TOKEN_CCY

	if {$token_id == ""} {

		# we are adding a token
		set sql "   select  ccy_code,
							'' amount,
							'' percentage_amount,
							'' amount_max
					from    tofferccy
					where   offer_id = ?"

		set stmt       [inf_prep_sql $DB $sql]
		set rs         [inf_exec_stmt $stmt $offer_id]

	} else {

		# we are amending an existing token
		set sql "   select  ta.ccy_code,
							ta.amount,
					ta.percentage_amount,
					ta.amount_max
					from    ttoken  t,
						ttokenamount ta
					where   ta.token_id = t.token_id and
						t.token_id = $token_id"
		set stmt       [inf_prep_sql $DB $sql]
		set rs         [inf_exec_stmt $stmt]
	}

	inf_close_stmt $stmt

	tpSetVar  NUM_TOKEN_CCYS [db_get_nrows $rs]
	set TOKEN_CCY(num_ccys)  [db_get_nrows $rs]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set TOKEN_CCY($i,code)     [db_get_col $rs $i ccy_code]
		set amount [db_get_col $rs $i amount]
		if {$token_id == "" || $amount == ""} {
			set amount [reqGetArg Value_$TOKEN_CCY($i,code)]
		}
		set TOKEN_CCY($i,amount)   $amount
		set TOKEN_CCY($i,percentage_amount)   [db_get_col $rs $i percentage_amount]
		set TOKEN_CCY($i,amount_max)          [db_get_col $rs $i amount_max]
	}

	tpBindVar TOKEN_CCY_CODE              TOKEN_CCY code   cc_idx
	tpBindVar TOKEN_CCY_AMOUNT            TOKEN_CCY amount cc_idx
	tpBindVar TOKEN_CCY_PERCENTAGE_AMOUNT TOKEN_CCY percentage_amount cc_idx
	tpBindVar TOKEN_CCY_AMOUNT_MAX        TOKEN_CCY amount_max cc_idx

	db_close $rs

	OT_LogWrite 10 "BOUND CCYs for token_id $token_id or offer_id $offer_id"
}

# Get all the currencies associated with this trigger_id
# also get all the currencies that are not in this offer
proc bind_trigger_amounts {{trigger_id ""} {offer_id ""}} {

	global DB TRIGGER_CCY

	if {$trigger_id == ""} {

		# we are adding a trigger
		set sql "   select  ccy_code,
							'' amount
					from    tofferccy
					where   offer_id = ?"

		set stmt       [inf_prep_sql $DB $sql]
		set rs         [inf_exec_stmt $stmt $offer_id]

	} else {

		# we are amending an existing trigger
		set sql "   select  ta.ccy_code,
							ta.amount
					from    ttrigger       t,
							ttriggeramount ta
					where
							ta.trigger_id = t.trigger_id and
							t.trigger_id  = $trigger_id"

		set stmt       [inf_prep_sql $DB $sql]
		set rs         [inf_exec_stmt $stmt]
	}

	inf_close_stmt $stmt
	tpSetVar  NUM_TRIGGER_CCYS [db_get_nrows $rs]
	set TRIGGER_CCY(num_ccys)  [db_get_nrows $rs]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set TRIGGER_CCY($i,code)     [db_get_col $rs $i ccy_code]
		set TRIGGER_CCY($i,amount)   [db_get_col $rs $i amount]
	}

	tpBindVar TRIGGER_CCY_CODE   TRIGGER_CCY code   cc_idx
	tpBindVar TRIGGER_CCY_AMOUNT TRIGGER_CCY amount cc_idx

	db_close $rs

	OT_LogWrite 10 "BOUND CCYs for trigger_id $trigger_id or offer_id $offer_id"
}



proc bind_affiliates {} {

	global DB
	global TRIG_AFF

	catch {unset TRIG_AFF}

	set sql {
		select
			aff_id,
			aff_name
		from
			taffiliate
		where
			status = 'A'
		order by aff_name
	}

	set stmt       [inf_prep_sql $DB $sql]
	set rs         [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar  num_aff [db_get_nrows $rs]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set TRIG_AFF($i,code) [db_get_col $rs $i aff_id]
		set TRIG_AFF($i,name) [db_get_col $rs $i aff_name]
	}

	tpBindVar AffCode TRIG_AFF code aff_idx
	tpBindVar AffName TRIG_AFF name aff_idx

	db_close $rs
}

proc bind_affiliate_groups {} {

	global DB
	global TRIG_AFF_GRP

	catch {unset TRIG_AFF_GRP}

	set sql {
		select
			aff_grp_id,
			aff_grp_name
		from
			taffiliategrp
		where
			status = 'A'
		order by aff_grp_name
	}

	set stmt       [inf_prep_sql $DB $sql]
	set rs         [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar  num_aff_grp [db_get_nrows $rs]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set TRIG_AFF_GRP($i,code) [db_get_col $rs $i aff_grp_id]
		set TRIG_AFF_GRP($i,name) [db_get_col $rs $i aff_grp_name]
	}

	tpBindVar AffGrpCode TRIG_AFF_GRP code aff_grp_idx
	tpBindVar AffGrpName TRIG_AFF_GRP name aff_grp_idx

	db_close $rs


}

proc bind_countries {} {

	global DB
	global TRIG_COUNTRY

	catch {unset TRIG_COUNTRY}

	set sql {
		select
			country_code,
			country_name,
			disporder
		from
			tcountry
		where
			status = 'A'
		order by
			disporder

	}

	set stmt       [inf_prep_sql $DB $sql]
	set rs         [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar num_countries [db_get_nrows $rs]
	OT_LogWrite 10 "num_countries: [db_get_nrows $rs]"

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set TRIG_COUNTRY($i,code) [db_get_col $rs $i country_code]
		set TRIG_COUNTRY($i,name) [db_get_col $rs $i country_name]
	}

	tpBindVar CountryCode TRIG_COUNTRY code cn_idx
	tpBindVar CountryName TRIG_COUNTRY name cn_idx

	db_close $rs

}

proc bind_languages {} {

	global DB
	global TRIG_LANG

	catch {unset TRIG_LANG}

	set sql {
		select
			lang,
			name,
			disporder
		from
			tlang
		where
			status = 'A'
		order by
			disporder

	}

	set stmt       [inf_prep_sql $DB $sql]
	set rs         [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar  num_langs [db_get_nrows $rs]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set TRIG_LANG($i,code) [db_get_col $rs $i lang]
		set TRIG_LANG($i,name) [db_get_col $rs $i name]
	}

	tpBindVar LangCode TRIG_LANG code l_idx
	tpBindVar LangName TRIG_LANG name l_idx

	db_close $rs
}



proc go_trigger_type_list {} {

	global DB

	tpSetVar opAdd 0
	set sql {
		select
			type_code,
			name,
			qualification,
			description
		from
			tTriggerType
		order by
			name
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	tpSetVar NumTTypes  $rows

	tpBindTcl Code sb_res_data $res type_idx type_code
	tpBindTcl Name sb_res_data $res type_idx name
	tpBindTcl Qual sb_res_data $res type_idx qualification
	tpBindTcl Desc sb_res_data $res type_idx desc

	asPlayFile -nocache trigger_type_list.html

	db_close $res
}

proc go_trigger_type {} {

	global DB

	set type_code [reqGetArg Code]

	set sql {
		select
			type_code,
			name,
			qualification,
			description
		from
			tTriggerType
		where
			type_code = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $type_code]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 0} {
		err_bind "Could not locate trigger"
		go_trigger_type_list
		return
	}

	tpBindString Code          [db_get_col $res 0 type_code]
	tpBindString Name          [db_get_col $res 0 name]
	tpBindString Qualification [db_get_col $res 0 qualification]
	tpBindString Desc          [db_get_col $res 0 description]
	tpSetVar opAdd 0

	db_close $res

	asPlayFile -nocache trigger_type.html
}

proc go_add_trigger_type {} {

	tpSetVar opAdd 1

	asPlayFile -nocache trigger_type.html

}

proc do_trigger_type {} {

	set action [reqGetArg SubmitName]

	OT_LogWrite 10 "do_trigger_type ($action)"

	if {$action == "TypeAdd"} {
		do_trigger_type_add
	} elseif {$action == "TypeMod"} {
		do_trigger_type_upd
	} elseif {$action == "TypeDel"} {
		do_trigger_type_del
	} elseif {$action == "Back"} {
		go_trigger_type_list
	} else {
		error "Unexpected action : $action"
	}
}

proc do_trigger_type_add {} {

	global DB

	set code [reqGetArg Code]
	set name [reqGetArg Name]
	set qual [reqGetArg Qualification]
	set desc [reqGetArg Desc]

	set sql {

		insert into tTriggerType (
			type_code,
			name,
			qualification,
			description
		) values (
			?, ?, ?, ?
		)

	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt $stmt\
				$code\
				$name\
				$qual\
				$desc\
	]} msg]

	catch {
		inf_close_stmt $stmt
		db_close $res
	}

	if {$c} {
		err_bind $msg
		go_trigger_type
		return
	}

	tpSetVar TypeAdded 1

	msg_bind "Trigger type added"
	go_trigger_type_list
}

proc do_trigger_type_upd args {

	global DB

	set code [reqGetArg Code]
	set name [reqGetArg Name]
	set qual [reqGetArg Qualification]
	set desc [reqGetArg Desc]


	set sql {
		update
			tTriggerType
		set
			name = ?,
			qualification = ?,
			description= ?
		where
			type_code = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt $stmt\
				$name\
				$qual\
				$desc\
				$code\
	]} msg]

	if {$c} {
		err_bind $msg
		go_trigger_type
		return
	}

	inf_close_stmt $stmt
	catch {db_close $res}

	msg_bind "Trigger type updated"
	go_trigger_type
}

proc do_trigger_type_del args {

	global DB

	set code [reqGetArg Code]

	set sql {
		delete from
			tTriggerType
		where
			type_code = ?
	}


	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt $stmt $code]
	} msg]

	inf_close_stmt $stmt
	catch {db_close $res}

	if {$c} {
		err_bind $msg
		go_trigger_type
		return
	}

	msg_bind "Trigger type deleted"
	go_trigger_type_list
}


proc go_offer_list args {

	global DB

	set sql_temp {
		select distinct
			t.offer_id
		from
			ttrigger t,
			ttoken k,
			tredemptionval r,
			tpossiblebet p
		where
			t.offer_id = k.offer_id and
			p.token_id = k.token_id and
			p.redemption_id = r.redemption_id
		into temp ttemp_tr
	}
	set sql_idx {
		create unique index ttemp_tr on ttemp_tr(offer_id)
	}

	set sql_res {
		select
			o.offer_id,
			o.name,
			o.start_date,
			o.end_date,
			o.need_qualification,
			o.on_settle,
			o.description,
			NVL(o.channels, "Any") channels,
			NVL(o.lang, "Any") lang,
			NVL(o.country_code, "Any") country_code,
			o.max_claims,

			case when
				r.offer_id is not null and
				((CURRENT between o.start_date and o.end_date) or o.end_date is null)
			then 'A'
			when
				r.offer_id is not null and not
				((CURRENT between o.start_date and o.end_date) or o.end_date is null)
			then 'P'
			else 'S'
			end as status,
			case
				when not exists (select t.offer_id from ttrigger t where t.offer_id = o.offer_id)
					then 'No Triggers defined'
				when not exists (select t.offer_id from ttoken t where t.offer_id = o.offer_id)
					then 'No Tokens defined'
				when r.offer_id is null then 'No Redemption Values Defined'
				when (o.end_date is not null and not (CURRENT between o.start_date and o.end_date))
					then 'Offer date range excludes the present time'
				else ''
			end as info

		from
			tOffer o,
			outer ttemp_tr r
		where
			o.offer_id = r.offer_id
		order by
			o.start_date
	}

	set sql_drop {
		drop table ttemp_tr
	}


	foreach sql {sql_temp sql_idx sql_res sql_drop} {

		set stmt [inf_prep_sql $DB [set $sql]]

		if {[catch {set rs  [inf_exec_stmt $stmt]} msg]} {

			catch {
					set stmt [inf_prep_sql $DB $sql_drop]
					inf_exec_stmt $stmt
					inf_close_stmt $stmt
			}

			err_bind $msg
			asPlayFile -nocache offer_list.html
			return
		}

		if {$sql == "sql_res"} {
			set res $rs
		}

		inf_close_stmt $stmt
	}


	set rows [db_get_nrows $res]

	tpSetVar NumOffers  $rows

	tpBindTcl OfferID       sb_res_data $res type_idx offer_id
	tpBindTcl Name          sb_res_data $res type_idx name
	tpBindTcl StartDate     sb_res_data $res type_idx start_date
	tpBindTcl EndDate       sb_res_data $res type_idx end_date
	tpBindTcl QualNeeded    sb_res_data $res type_idx need_qualification
	tpBindTcl OnSettle      sb_res_data $res type_idx on_settle
	tpBindTcl Chan          sb_res_data $res type_idx channels
	tpBindTcl Lang          sb_res_data $res type_idx lang
	tpBindTcl Cntry         sb_res_data $res type_idx country_code
	tpBindTcl MaxClaims     sb_res_data $res type_idx max_claims
	tpBindTcl Status        sb_res_data $res type_idx status
	tpBindTcl Info          sb_res_data $res type_idx info

	asPlayFile -nocache offer_list.html

	db_close $res
}

proc go_offer {} {
	global DB
	global ALL_CCYS
	global SELECTED_CCY

	set offer_id [reqGetArg OfferID]

	tpSetVar opAdd 0

	# Offer
	set sql {

		select
			o.name,
			o.start_date,
			o.end_date,
			o.need_qualification,
			o.description,
			o.channels,
			NVL(o.lang, "Any")         lang,
			NVL(o.country_code, "Any") country_code,
			o.on_settle,
			o.max_claims
		from
			tOffer o
		where
			o.offer_id = ?

	}

	set stmt [inf_prep_sql $DB $sql]
	set OffRes [inf_exec_stmt $stmt $offer_id]
	inf_close_stmt $stmt

	tpBindString MaxClaims          [db_get_col $OffRes 0 max_claims]
	tpBindString OfferID            $offer_id
	tpBindString OfferName          [db_get_col $OffRes 0 name]
	tpBindString StartDate          [db_get_col $OffRes 0 start_date]
	tpBindString EndDate            [db_get_col $OffRes 0 end_date]
	tpBindString QUALIFICATION_REQD [db_get_col $OffRes 0 need_qualification]
	tpBindString Desc               [db_get_col $OffRes 0 description]
	tpBindString ON_SETTLE          [db_get_col $OffRes 0 on_settle]

	tpBindString SelChannel         [db_get_col $OffRes 0 channels]
	tpBindString SelLang            [db_get_col $OffRes 0 lang]
	tpBindString SelCountry         [db_get_col $OffRes 0 country_code]

	set current [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	if {[db_get_col $OffRes 0 start_date] <= $current} {
		OT_LogWrite 20 "Offer started!"
		tpSetVar OffStarted 1
		tpBindString OffStarted 1
	}

	db_close $OffRes

	bind_channels

	bind_currencies_for_offer_id $offer_id

	bind_languages

	bind_countries
      
	

	

	#
	# Triggers
	#

	set stmt [inf_prep_sql $DB {

		select
			t.trigger_id,
			t.type_code,
			y.name,
			t.rank,
			y.qualification qual
		from
			tTrigger     t,
			tTriggerType y
		where
			offer_id    = ?
		and t.type_code = y.type_code
		order by
			qualification desc,
			rank

	}]
	set rs [inf_exec_stmt $stmt $offer_id]
	inf_close_stmt $stmt

	global fb_triggers

	set NumTriggers [db_get_nrows $rs]

	for { set i 0 } { $i < $NumTriggers } { incr i } {

		set fb_triggers($i,id)   [db_get_col $rs $i trigger_id]
		set fb_triggers($i,type) [db_get_col $rs $i type_code]
		set fb_triggers($i,rank) [db_get_col $rs $i rank]
		set fb_triggers($i,name) [db_get_col $rs $i name]
		set fb_triggers($i,qual) [db_get_col $rs $i qual]

	}

	db_close $rs

	tpSetVar NumTriggers $NumTriggers

	tpBindVar TrigID   fb_triggers id   trigger_idx
	tpBindVar TrigType fb_triggers type trigger_idx
	tpBindVar TrigRank fb_triggers rank trigger_idx
	tpBindVar TrigName fb_triggers name trigger_idx
	tpBindVar TrigQual fb_triggers qual trigger_idx

	set stmt [inf_prep_sql $DB {

		select
			t.token_id,
			t.absolute_expiry,
			t.relative_expiry
		from
			tToken t
		where
			t.offer_id = ?
		order by
			absolute_expiry asc

	}]
	set rs [inf_exec_stmt $stmt $offer_id]
	inf_close_stmt $stmt

	set NumTokens [db_get_nrows $rs]

	global fb_tokens

	for { set i 0 } { $i < $NumTokens } { incr i } {

		set fb_tokens($i,id)      [db_get_col $rs $i token_id]
		set fb_tokens($i,abs_exp) [db_get_col $rs $i absolute_expiry]
		set fb_tokens($i,rel_exp) [db_get_col $rs $i relative_expiry]

	}

	db_close $rs

	tpSetVar NumTokens $NumTokens

	tpBindVar TokenID     fb_tokens id      token_idx
	tpBindVar TokenAbsExp fb_tokens abs_exp token_idx
	tpBindVar TokenRelExp fb_tokens rel_exp token_idx

	asPlayFile -nocache offer.html

	catch { unset fb_triggers }
	catch { unset fb_tokens   }

}

proc go_add_offer {} {

	global DB ALL_CCYS

	tpSetVar opAdd 1
	tpBindString MaxClaims "1"

	bind_channels

e	bind_currencies_for_offer_id

	bind_languages

	bind_countries

	asPlayFile -nocache offer.html
}

proc do_offer {} {

	set action [reqGetArg SubmitName]

	OT_LogWrite 10 "=> do_offer ($action)"

	if {$action == "OfferAdd"} {
		do_offer_add
	} elseif {$action == "OfferMod"} {
		do_offer_upd
	} elseif {$action == "OfferDel"} {
		do_offer_del
	} elseif {$action == "Back"} {
		go_offer_list
	} else {
		error "Unexpected action : $action"
	}
}

#
# Add new offer
#

proc do_offer_add {} {
	global DB

	set err 0

	set name            [reqGetArg Name]
	set start           [reqGetArg StartDate]
	set end             [reqGetArg EndDate]
	set qual            [reqGetArg Qualification]
	set on_settle       [reqGetArg OnSettle]
	set desc            [reqGetArg Desc]
	set channel         [reqGetArg Channel]
	set ccy_codes       [reqGetArgs Currencies]
	set lang            [reqGetArg Language]
	set country_code    [reqGetArg Country]
	set max_claims      [reqGetArg MaxClaims]

	OT_LogWrite 10 "name          = $name"
	OT_LogWrite 10 "start         = $start"
	OT_LogWrite 10 "end           = $end"
	OT_LogWrite 10 "qual          = $qual"
	OT_LogWrite 10 "on_settle     = $on_settle"
	OT_LogWrite 10 "desc          = $desc"
	OT_LogWrite 10 "channel       = $channel"
	OT_LogWrite 10 "ccy_codes     = $ccy_codes"
	OT_LogWrite 10 "country_code  = $country_code"
	OT_LogWrite 10 "max_claims    = $max_claims"

	# Check for reqd field before we attempt to insert the offer
	if {$ccy_codes == ""} {
		set err 1
		err_bind "You must select at least one currency"
	} elseif {$name == ""} {
		set err 1
		err_bind "You must supply an offer name"
	} elseif {$start == ""} {
		set err 1
		err_bind "You must supply a start date"
	}

	if {$err} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_add_offer
		return
	}
	#set one for channel id
	#add to pInsOffer
	set sql {execute procedure pInsOffer(
			p_name          = ?,
			p_start_date    = ?,
			p_end_date      = ?,
			p_qualification = ?,
			p_on_settle     = ?,
			p_description   = ?,
			p_channels      = ?,
			p_lang          = ?,
			p_country_code  = ?,
			p_max_claims    = ?
		)}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$name\
			$start\
			$end\
			$qual\
			$on_settle\
			$desc\
			$channel\
			$lang\
			$country_code\
			$max_claims\
		]
	} msg]} {
		set err 1
		err_bind $msg
	} else {

		# insert all the currencies for this offer
		set offer_id [db_get_coln $res 0 0]

		catch {db_close $res}

		set sql {execute procedure pInsOfferCcy(p_offer_id = ?, p_ccy_code = ?)}

		set stmt [inf_prep_sql $DB $sql]

		# foreach selected ccy add it to the offer
		foreach ccy_code $ccy_codes {
			OT_LogWrite 1 "Adding ccy $ccy_code for offer $offer_id..."
			if {[catch {set res [inf_exec_stmt $stmt $offer_id $ccy_code]} msg]} {
				set err 1
				err_bind $msg
			}

		}
	}

	if {$err} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		go_add_offer
		return
	}

	inf_close_stmt $stmt

	tpSetVar OfferAdded 1

	go_offer_list
}

#
# Modify offer
#
proc do_offer_upd args {

	global DB

	set err 0

	set offer_id                [reqGetArg OfferID]
	set name                    [reqGetArg Name]
	set start                   [reqGetArg StartDate]
	set end                     [reqGetArg EndDate]
	set qual                    [reqGetArg Qualification]
	set on_settle               [reqGetArg OnSettle]
	set desc                    [reqGetArg Desc]
	set channel                 [reqGetArg Channel]
	set ccy_codes               [reqGetArgs Currencies]
	set ccy_codes_to_remove     [reqGetArgs Currencies_not]
	set lang                    [reqGetArg Language]
	set country_code            [reqGetArg Country]
	set max_claims              [reqGetArg MaxClaims]


	OT_LogWrite 10 " offer_id                   [reqGetArg OfferID]"
	OT_LogWrite 10 " name                       [reqGetArg Name]"
	OT_LogWrite 10 " start                      [reqGetArg StartDate]"
	OT_LogWrite 10 " end                        [reqGetArg EndDate]"
	OT_LogWrite 10 " qual                       [reqGetArg Qualification]"
	OT_LogWrite 10 " on_settle                  [reqGetArg OnSettle]"
	OT_LogWrite 10 " desc                       [reqGetArg Desc]"
	OT_LogWrite 10 " channel                    [reqGetArg Channel]"
	OT_LogWrite 10 " ccy_codes                  [reqGetArgs Currencies]"
	OT_LogWrite 10 " ccy_codes_to_remove        [reqGetArgs Currencies_not]"
	OT_LogWrite 10 " lang                       [reqGetArg Language]"
	OT_LogWrite 10 " country_code               [reqGetArg Country]"
	OT_LogWrite 10 " max_claims                 [reqGetArg MaxClaims]"

	set sql {
		execute procedure pUpdOffer(
			p_offer_id       = ?,
			p_name           = ?,
			p_start_date     = ?,
			p_end_date       = ?,
			p_qualification  = ?,
			p_on_settle      = ?,
			p_description    = ?,
			p_channels	 = ?,
			p_lang           = ?,
			p_country_code   = ?,
			p_max_claims     = ?)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$offer_id\
			$name\
			$start\
			$end\
			$qual\
			$on_settle\
			$desc\
			$channel\
			$lang\
			$country_code\
			$max_claims\
		]} msg]
	} {
		err_bind $msg
		set err 1
		OT_LogWrite 1 "failed to update offer: $msg"
	} else {
		# insert all the currencies for this offer
		catch {db_close $res}
		inf_close_stmt $stmt

		set sql {execute procedure pInsOfferCcy(p_offer_id = ?, p_ccy_code = ?)}
		set stmt [inf_prep_sql $DB $sql]
		# foreach selected ccy add it to the offer
		foreach ccy_code $ccy_codes {
			if {[catch {set res [inf_exec_stmt $stmt $offer_id $ccy_code]} msg]} {
				set err 1
				err_bind $msg
				OT_LogWrite 1 "failed to add $ccy_code"
				go_offer
				return
			}
		}
		inf_close_stmt $stmt
		catch {db_close $res}

		set sql {execute procedure pDelOfferCcy(p_offer_id = ?, p_ccy_code = ?)}
		set stmt [inf_prep_sql $DB $sql]
		# foreach unselected ccy remove it to the offer
		foreach ccy_code $ccy_codes_to_remove {
			if {[catch {set res [inf_exec_stmt $stmt $offer_id $ccy_code]} msg]} {
				set err 1
				err_bind $msg
				OT_LogWrite 1 "failed to remove $ccy_code"
				go_offer
				return
			}
		}
		inf_close_stmt $stmt
		catch {db_close $res}

	}

	if {$err} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		err_bind "Failed to update the offer: $msg"
		go_offer
		return
	}

	msg_bind "Offer has been updated successfully"
	go_offer
}

#
# Delete an offer
#
proc do_offer_del args {

	global DB

	set offer_id [reqGetArg OfferID]
	set err 0

	set sql {
		execute procedure pDelOffer (
			p_offer_id = ?)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt $offer_id]} msg]} {
		err_bind $msg
		set err 1
	}

	inf_close_stmt $stmt
	catch {db_close $res}

	if {$err} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		go_offer
		return
	}

	go_offer_list
}

proc do_trigger {} {

	set action [reqGetArg SubmitName]

	OT_LogWrite 10 "do_trigger ($action)"

	if {$action == "TriggerAdd"} {
		do_trigger_add
	} elseif {$action == "TriggerMod"} {
		do_trigger_upd
	} elseif {$action == "TriggerDel"} {
		do_trigger_del
	} elseif {$action == "Back"} {
		go_offer
	} else {
		error "Unexpected action : $action"
	}
}

proc do_trigger_add {} {
	global DB TRIGGER_CCY

	set aff_id ""
	set aff_grp_id ""

	set offer_id     [reqGetArg OfferID]
	set code         [reqGetArg SelTrigCode]
	set rank         [reqGetArg Rank]
	set text         [reqGetArg GameSort]
	set aff_level    [reqGetArg AffOption]
	set voucher_type [reqGetArg SelVoucherCode]
	set ref_offer_id [reqGetArg SelRefOfferId]
	set is_type      [reqGetArg IStype]; # these two for Introductory Sources
	set is_source    [reqGetArg ISsource]
	set promo_code   [reqGetArg promo_code]

	set channel_strict    [reqGetArg ChannelStrict]

	# to store the introductory source element details we hijack
	# the text field -- this is normally used for XGames stuff
	if {$code == "INTRO"} {
		set text [join [list $is_type $is_source] :]
	}

	switch -exact -- $aff_level {
		All     {set aff_id ""}
		None    {set aff_id ""}
		Single  {set aff_id     [reqGetArg Affiliate]}
		Group   {set aff_grp_id [reqGetArg AffiliateGrp]}
		default {set aff_id ""}
	}

	set sql {
		execute procedure pInsTrigger (
			p_offer_id       = ?,
			p_type_code      = ?,
			p_rank           = ?,
			p_text           = ?,
			p_aff_level      = ?,
			p_aff_id         = ?,
			p_aff_grp_id     = ?,
			p_voucher_type   = ?,
			p_ref_offer_id   = ?,
			p_channel_strict = ?,
			p_promo_code     = ?
		)
	}

	OT_LogWrite 10 "Adding trigger with offer_id $offer_id,\
										code $code,\
										rank $rank,\
										text $text,\
										aff_level $aff_level,\
										aff_id $aff_id,\
										aff_grp_id $aff_grp_id,\
										voucher_type $voucher_type\
										ref_offer_id $ref_offer_id,\
										promo_code $promo_code"

	inf_begin_tran $DB

	set stmt [inf_prep_sql $DB $sql]
	set c [catch {
		set res [inf_exec_stmt $stmt \
			$offer_id \
			$code \
			$rank \
			$text \
			$aff_level \
			$aff_id \
			$aff_grp_id \
			$voucher_type \
			$ref_offer_id \
			$channel_strict]

		inf_close_stmt $stmt
	} msg]

	if {$c} {
		inf_rollback_tran $DB
		OT_LogWrite 1 "Error adding trigger: $msg"
		err_bind $msg
		go_add_trigger
		return
	} else {
		set trigger_id [db_get_coln $res 0 0]
		reqSetArg TriggerID $trigger_id

		# now change the amounts
		bind_trigger_amounts $trigger_id

		set sql {
			execute procedure pUpdTriggerAmount(
				p_trigger_id = ?,
				p_ccy_code   = ?,
				p_amount     = ?)
		}

		set stmt [inf_prep_sql $DB $sql]

		for {set i 0} {$i < $TRIGGER_CCY(num_ccys)} {incr i} {

			set ccy_code $TRIGGER_CCY($i,code)
			set value    [reqGetArg Value_$ccy_code]

			if {$value != ""} {
				OT_LogWrite 10 "Updating trigger amount for $ccy_code"

				set c [catch {
					inf_exec_stmt $stmt $trigger_id $ccy_code   $value
				} msg]

				if {$c} {
					OT_LogWrite 3 "Failed to update trigger amount for $ccy_code. $msg"
					err_bind $msg
					inf_rollback_tran $DB
					ADMIN::FREEBETS::rebind_request_data
					go_add_trigger
					return
				}

			}
		}

		inf_commit_tran $DB

		inf_close_stmt $stmt
		# end of amount changing
	}

	catch {db_close $res}

	msg_bind "Trigger added successfully"

	go_trigger
}

proc do_trigger_upd args {

	global DB TRIGGER_CCY

	set aff_id ""
	set aff_grp_id ""

	set offer_id       [reqGetArg OfferID]
	set rank           [reqGetArg Rank]
	set text           [reqGetArg GameSort]
	set trigger_id     [reqGetArg TriggerID]
	set aff_level      [reqGetArg AffOption]
	set voucher_type   [reqGetArg SelVoucherCode]
	set is_type        [reqGetArg IStype]
	set is_source      [reqGetArg ISsource]
	set type_code      [reqGetArg SelTrigCode]
	set promo_code     [reqGetArg promo_code]

	set channel_strict    [reqGetArg ChannelStrict]

	if {$is_type != "" && $is_source != ""} {
		set text [join [list $is_type $is_source] :]
	}

	switch -exact -- $aff_level {
		All     {set aff_id ""}
		None    {set aff_id ""}
		Single  {set aff_id [reqGetArg Affiliate]}
		Group   {set aff_grp_id [reqGetArg AffiliateGrp]}
		default {set aff_id ""}
	}

	inf_begin_tran $DB

	set stmt [inf_prep_sql $DB {
		execute procedure pUpdTrigger (
			p_trigger_id     = ?,
			p_type_code      = ?,
			p_rank           = ?,
			p_text           = ?,
			p_aff_level      = ?,
			p_aff_id         = ?,
			p_aff_grp_id     = ?,
			p_voucher_type   = ?,
			p_channel_strict = ?,
			p_promo_code     = ?
		)
	}]

	set c [catch {
		inf_exec_stmt $stmt\
				$trigger_id\
				$type_code\
				$rank\
				$text \
				$aff_level \
				$aff_id \
				$aff_grp_id \
				$voucher_type \
				$channel_strict \
				$promo_code
	} msg]

	inf_close_stmt $stmt

	if {$c} {
		inf_rollback_tran $DB
		err_bind $msg
		go_trigger
		return
	}

	# now change the amounts
	bind_trigger_amounts $trigger_id

	set stmt [inf_prep_sql $DB {
		execute procedure pUpdTriggerAmount (
			p_trigger_id = ?,
			p_ccy_code   = ?,
			p_amount     = ?
		)
	}]

	for {set i 0} {$i < $TRIGGER_CCY(num_ccys)} {incr i} {

		set ccy_code $TRIGGER_CCY($i,code)
		set value    [reqGetArg Value_$ccy_code]

		if {$value != ""} {

			OT_LogWrite 10 "Updating trigger amount for $ccy_code"

			set c [catch {
				inf_exec_stmt $stmt $trigger_id $ccy_code   $value
			} msg]

			if {$c} {
				inf_close_stmt $stmt
				OT_LogWrite 3 "Failed to update trigger amount for $ccy_code. $msg"
				err_bind $msg
				inf_rollback_tran $DB
				ADMIN::FREEBETS::rebind_request_data
				go_add_trigger
				return
			}

		}

	}

	inf_close_stmt $stmt

	inf_commit_tran $DB

	# end of amount changing

	msg_bind "Trigger updated successfully"
	go_trigger
}

proc do_trigger_del args {

	global DB

	set trigger_id [reqGetArg TriggerID]
	set offer_id   [reqGetArg OfferID]

	set sql {
		execute procedure pDelTrigger(
									p_trigger_id = ?
									)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		inf_exec_stmt $stmt $trigger_id
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		err_bind $msg
		go_trigger
		return
	}

	msg_bind "Trigger deleted"
	go_offer
}


proc go_trigger {} {

	global DB
	global ITArray

	OT_LogWrite 1 "=> go_trigger ([reqGetArg TriggerID])"

	set trigger_id [reqGetArg TriggerID]

	tpSetVar opAdd 0

	OT_LogWrite 1 "OffStarted=[reqGetArg OffStarted]"
	tpSetVar OffStarted [reqGetArg OffStarted]
	tpBindString OffStarted [reqGetArg OffStarted]

	set sql {

		select
			t.trigger_id,
			t.offer_id,
			t.type_code,
			t.promo_code,
			t.rank,
			t.text text,
			t.aff_level,
			t.aff_id,
			t.aff_grp_id,
			t.voucher_type,
			t.ref_offer_id,
			case
				when t.type_code = 'REFEREE'
				then (select name from toffer where offer_id = ref_offer_id)
			end as ref_offer_name,
			y.name,
			t.channel_strict
		from
			tTriggerType        y,
			tTrigger            t,
			outer tTriggerLevel l
		where y.type_code  = t.type_code
		  and t.trigger_id = l.trigger_id
		  and t.trigger_id = ?

	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $trigger_id]
	inf_close_stmt $stmt

	set name      [db_get_col $rs 0 name]
	set type_code [db_get_col $rs 0 type_code]

	tpBindString TriggerID     $trigger_id
	tpBindString SelTrigCode   $type_code
	tpBindString Name          $name
	tpBindString OfferID       [db_get_col $rs offer_id]
	tpBindString Rank          [db_get_col $rs rank]
	tpBindString AffId         [db_get_col $rs aff_id]
	tpBindString AffGrpId      [db_get_col $rs aff_grp_id]
	tpBindString ChannelStrict [db_get_col $rs channel_strict]
	tpBindString PromoCode     [db_get_col $rs promo_code]

	if {$type_code == "INTRO"} {
		# introductory source elements uses the text field as well
		set txt    [db_get_col $rs 0 text]
		set type   [string range $txt 0 [expr {[string first : $txt] -1}]]
		set source [string range $txt [expr {[string first : $txt] +1}] end]

		# need to retrieve their proper names from the db as well
		set is_sql  {select desc from thearabout where hear_about = ?}
		set it_sql  {select desc from thearabouttype where hear_about_type =?}
		set it_stmt [inf_prep_sql $DB $it_sql]
		set is_stmt [inf_prep_sql $DB $is_sql]
		if {[catch {set it_rs [inf_exec_stmt $it_stmt $type]} msg ]} {
			set it_rs ""
		}
		if {[catch {set is_rs [inf_exec_stmt $is_stmt $source]} msg ]} {
			set is_rs ""
		}

		if {$is_rs != ""} {
			if {[catch {set sname [db_get_col $is_rs 0 desc]} msg ]} {
				set sname "Unknown"
			}
		} else {
			set sname "Unknown"
		}

		if {$it_rs != ""} {
			if {[catch {set tname [db_get_col $it_rs 0 desc]} msg ]} {
				set tname "Unknown"
			}
		} else {
			set tname "Unknown"
		}

		tpBindString Type       $type
		tpBindString TypeName   $tname
		tpBindString Source     $source
		tpBindString SourceName $sname

	} else {
		tpBindString DBGameSort [db_get_col $rs 0 text]
	}

	set aff_level [db_get_col $rs 0 aff_level]

	switch -exact -- $aff_level {
		All     {
			tpBindString ALL_CHECKED checked
			tpSetVar AFF_OPTION "All"
		}
		None    {
			tpBindString NONE_CHECKED checked
			tpBindString AFF_OPTION "None"

		}
		Single  {
			tpBindString SINGLE_CHECKED checked
			tpBindString AFF_OPTION "Single"
			tpSetVar AFF_OPTION "single"
			tpBindString SelAff [db_get_col $rs 0 aff_id]
		}
		Group   {
			tpBindString GROUP_CHECKED checked
			tpBindString AFF_OPTION "Group"
			tpSetVar AFF_OPTION "group"
			tpBindString SelAffGrp  [db_get_col $rs 0 aff_grp_id]
		}
		default {
			tpBindString ALL_NONE_CHECKED checked
			tpBindString AFF_OPTION "N/A"
		}
	}

	reqSetArg SelTrigCode $type_code

	bind_trigger_types
	bind_trigger_levels $trigger_id
	bind_intro_sources

	# Set the default type for intro source offers
	set selType 0

	if {$type_code == "INTRO"} {
		for {set i 0} {$i < $ITArray(type_count)} {incr i} {
			if {[info exists ITArray($i,type)]} {
				if {$ITArray($i,type) == $type} {
					set selType $i
				}
			}
		}
	}

	tpSetVar selectedType $selType

	if {[OT_CfgGet ENABLE_FREEBET_VOUCHERS "FALSE"]} {
		bind_voucher_types
	}

	bind_referral_offers

	tpBindString SelVoucherCode  [db_get_col $rs 0 voucher_type]
	tpBindString SelRefOfferId   [db_get_col $rs 0 ref_offer_id]
	tpBindString SelRefOfferName [db_get_col $rs 0 ref_offer_name]

	bind_trigger_amounts $trigger_id
	bind_xgame_check
	bind_affiliates
	bind_affiliate_groups

	tpSetVar TrigCode $type_code

	asPlayFile -nocache trigger.html

	db_close $rs
}


proc bind_trigger_levels trigger_id {

	global TRIGGER_LEVELS

	array unset TRIGGER_LEVELS

	set stmt [inf_prep_sql $::DB {

		select
			l.level,
			l.id,
			case
				when l.level = 'XGAME'
				then (select '' || sort from txgame where xgame_id = l.id)
				when l.level = 'CLASS'
				then (select '' || name from tevclass where ev_class_id = l.id)
				when l.level = 'TYPE'
				then (select '' || name from tevtype where ev_type_id = l.id)
				when l.level = 'EVENT'
				then (select '' || desc from tev where ev_id = l.id)
				when l.level = 'MARKET'
				then (select
						  '' || g.name
					  from
						  tevocgrp g,
						  tevmkt m
					  where m.ev_mkt_id    = l.id
						and m.ev_oc_grp_id = g.ev_oc_grp_id)
				when l.level = 'SELECTION'
				then (select '' || desc from tevoc where ev_oc_id = l.id)
				when l.level = 'COUPON'
				then (select '' || desc from tcoupon where coupon_id = l.id)
			end as name
		from
			tTriggerLevel l
		where l.trigger_id = ?
		order by
			l.level,
			l.id

	}]
	set rs [inf_exec_stmt $stmt $trigger_id]
	inf_close_stmt $stmt

	set n    [db_get_nrows $rs]
	set cols [list level id name]

	for {set r 0} {$r < $n} {incr r} {
		foreach col $cols {
			set TRIGGER_LEVELS($r,$col) [db_get_col $rs $r $col]
		}
	}

	ob_db::rs_close $rs

	foreach col $cols {
		tpBindVar bet_$col TRIGGER_LEVELS $col i
	}

	tpSetVar num_levels $n

}


proc go_add_trigger {} {

	global ALL_CCYS
	global ITArray

	tpSetVar opAdd 1
	tpSetVar XGAMEBET 0

	tpBindString OfferID [reqGetArg OfferID]

	if {[reqGetArg OfferID] == ""} {
		err_bind "You must create the offer first"
		go_add_offer
		return
	}

	bind_trigger_types
	bind_intro_sources

	if {[OT_CfgGet ENABLE_FREEBET_VOUCHERS "FALSE"]} {
		bind_voucher_types
	}
	bind_referral_offers
	bind_affiliates
	bind_affiliate_groups
	bind_trigger_amounts "" [reqGetArg OfferID]

	tpBindString ALL_NONE_CHECKED checked
	tpBindString SelVoucherCode [reqGetArg SelVoucherCode]

	asPlayFile -nocache trigger.html
}

proc go_trigger_select {} {

	global DB
	global ITArray
	rebind_request_data

	tpSetVar opAdd [reqGetArg opAdd]

	bind_trigger_types
	bind_intro_sources

	if {[OT_CfgGet ENABLE_FREEBET_VOUCHERS "FALSE"]} {
		bind_voucher_types
	}
	bind_referral_offers
	bind_xgame_check
	bind_affiliates
	bind_affiliate_groups
	bind_trigger_amounts "" [reqGetArg OfferID]

	tpBindString SelVoucherCode [reqGetArg SelVoucherCode]
	tpSetVar TrigCode [reqGetArg SelTrigCode]
	tpSetVar selectedType 0

	set aff_option [reqGetArg AffOption]
	switch -exact -- $aff_option {
		All {tpBindString ALL_CHECKED checked}
		None {tpBindString NONE_CHECKED checked}
		Single {tpBindString SINGLE_CHECKED checked}
		Group {tpBindString GROUP_CHECKED checked}
		default {tpBindString ALL_NONE_CHECKED checked}
	}

	asPlayFile -nocache trigger.html

	catch {db_close $xgam_res}
}


# Insert or delete a trigger level
#
proc do_trigger_level {} {

	set trigger_id [reqGetArg TriggerID]
	set level      [reqGetArg Level]
	set id         [reqGetArg ID]
	set submit     [reqGetArg Submit]

	switch $submit {

		Insert {
			set sql {
				insert into tTriggerLevel(trigger_id, level, id)
					values (?, ?, ?)
			}
			set stmt [inf_prep_sql $::DB $sql]
			inf_exec_stmt $stmt $trigger_id $level $id
			inf_close_stmt $stmt

			msg_bind "Inserted trigger level"
		}

		Delete {
			set sql {
				delete from tTriggerLevel
				where trigger_id = ? and level = ? and id = ?
			}
			set stmt [inf_prep_sql $::DB $sql]
			inf_exec_stmt $stmt $trigger_id $level $id
			set nrows [inf_get_row_count $stmt]
			inf_close_stmt $stmt

			if {$nrows == 0} {
				error "Failed to delete trigger level"
			}

			msg_bind "Delete trigger level"

		}

		default {
			error "Unknown submit"
		}

	}

	go_trigger

}


proc go_rval_list args {

	global DB

	set sql {
		select
			redemption_id rval_id,
			bet_level,
			bet_type,
			bet_id,
			case
				when bet_level = 'XGAME'
				then (select sort from txgame where xgame_id = bet_id)
				when bet_level = 'CLASS'
				then (select name from tevclass where ev_class_id = bet_id)
				when bet_level = 'TYPE'
				then (select name from tevtype where ev_type_id = bet_id)
				when bet_level = 'EVENT'
				then (select desc from tev where ev_id = bet_id)
				when bet_level = 'MARKET'
				then (select g.name from tevocgrp g, tevmkt m where m.ev_mkt_id = bet_id and m.ev_oc_grp_id=g.ev_oc_grp_id)
				when bet_level = 'SELECTION'
				then (select desc from tevoc where ev_oc_id = bet_id)
				when bet_level = 'COUPON'
				then (select desc from tcoupon where coupon_id = bet_id)
			end as bet_name,
			name
		from
			tredemptionval
		order by
			bet_level, bet_type, bet_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $rs]

	tpSetVar NumRVals   $rows

	tpBindTcl RValID   sb_res_data $rs rval_idx rval_id
	tpBindTcl BetLevel sb_res_data $rs rval_idx bet_level
	tpBindTcl BetType  sb_res_data $rs rval_idx bet_type
	tpBindTcl BetID    sb_res_data $rs rval_idx bet_id
	tpBindTcl Name     sb_res_data $rs rval_idx name
	tpBindTcl BetName  sb_res_data $rs rval_idx bet_name

	asPlayFile -nocache rval_list.html

	db_close $rs
}
proc go_rval {} {

	global DB

	set rval_id [reqGetArg RValID]

	tpSetVar opAdd 0

	set sql {
		select
			bet_level,
			bet_type,
			bet_id,
			name
		from
			tRedemptionVal
		where
			redemption_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $rval_id]
	inf_close_stmt $stmt

	tpBindString RValID $rval_id
	tpBindString BetLevel [db_get_col $res 0 bet_level]
	tpBindString BetType [db_get_col $res 0 bet_type]
	tpBindString BetID [db_get_col $res 0 bet_id]
	tpBindString RName [db_get_col $res 0 name]

	OT_LogWrite 15 "RValID $rval_id"
	OT_LogWrite 15 "BetLevel [db_get_col $res 0 bet_level]"
	OT_LogWrite 15 "BetType [db_get_col $res 0 bet_type]"
	OT_LogWrite 15 "BetID [db_get_col $res 0 bet_id]"
	OT_LogWrite 15 "RName [db_get_col $res 0 name]"


	asPlayFile -nocache rval.html
}

proc go_add_rval {} {

	tpSetVar opAdd 1

	asPlayFile -nocache rval.html
}

proc go_bet_dd_level {} {

	global BET_DD
	catch {unset BET_DD}

	tpBindString title "Bet Type"

	tpSetVar show_link 1
	tpSetVar no_select 0

	set id 0
	set BET_DD($id,key)         $id
	set BET_DD($id,bet_level)   "ANY"
	set BET_DD($id,bet_type)    ""
	set BET_DD($id,bet_id)      ""
	set BET_DD($id,name)        "Any"
	set BET_DD($id,link_action) ""
	incr id

	set BET_DD($id,key)         $id
	set BET_DD($id,bet_level)   "XGAME"
	set BET_DD($id,name)        "External Game"
	set BET_DD($id,link_action) "ADMIN::FREEBETS::go_bet_dd"
	incr id

	set BET_DD($id,key)         $id
	set BET_DD($id,bet_level)   "CATEGORY"
	set BET_DD($id,name)        "Event Class (& drilldown)"
	set BET_DD($id,link_action) "ADMIN::BESTBETS::go_bbet_dd"
	incr id

	set BET_DD($id,key)         $id
	set BET_DD($id,bet_level)   "EVENT"
	set BET_DD($id,name)        "Event Sort"
	set BET_DD($id,link_action) "ADMIN::FREEBETS::go_bet_dd"
	incr id

	set BET_DD($id,key)         $id
	set BET_DD($id,bet_level)   "MARKET"
	set BET_DD($id,name)        "Market Sort"
	set BET_DD($id,link_action) "ADMIN::FREEBETS::go_bet_dd"
	incr id

	set BET_DD($id,key)         $id
	set BET_DD($id,bet_level)   "CLASS"
	set BET_DD($id,name)        "Class Sort"
	set BET_DD($id,link_action) "ADMIN::FREEBETS::go_bet_dd"
	incr id

	set BET_DD($id,key)         $id
	set BET_DD($id,bet_level)   "BALLS"
	set BET_DD($id,name)        "Netballs"
	set BET_DD($id,link_action) "ADMIN::FREEBETS::go_netballs_dd"
	incr id

	tpSetVar dd_rows $id
	tpBindVar key         BET_DD key dd_idx
	tpBindVar bet_level   BET_DD bet_level dd_idx
	tpBindVar name        BET_DD name dd_idx
	tpBindVar link_action BET_DD link_action dd_idx

	asPlayFile -nocache fbet_dd.html
}

proc go_bet_dd {} {

	global DB
	global BET_DD

	catch {unset BET_DD}

	tpSetVar show_link 1
	tpSetVar no_select 0

	set bet_level [reqGetArg bet_level]
	set bet_type [reqGetArg bet_type]


	OT_LogWrite 15 "level: $bet_level"
	OT_LogWrite 15 "type:  $bet_type"

	switch -exact $bet_level {

		"XGAME"  {go_bet_dd_xgame}
		"MARKET" {go_bet_dd_market}
		"EVENT"  {go_bet_dd_event}
		"CLASS"  {go_bet_dd_class}

		default {error "Unknown level ($bet_level)"}
	}

	asPlayFile -nocache fbet_dd.html
}

proc go_bet_dd_any {} {

	global DB
	global BET_DD

	tpSetVar show_link 0
	tpBindString title "Any Bet"

	tpSetVar dd_rows 1

	set BET_DD(0,key)        $i
	set BET_DD(0,bet_level)  "ANY"
	set BET_DD(0,bet_type)   ""
	set BET_DD(0,bet_id)     ""
	set BET_DD(0,name)       "Any Bet"
	set BET_DD(0,link_action) "ADMIN::FREEBETS::go_bet_dd"

}

proc go_bet_dd_market {} {

	global DB
	global BET_DD

	tpSetVar show_link 0
	tpBindString title "Market Sort"

	set sql {
		select
			distinct (sort) val,
			sort name
		from
			tevmkt
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	tpSetVar dd_rows $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		set BET_DD($i,key)        $i
		set BET_DD($i,bet_level)  "MARKET"
		set BET_DD($i,bet_type)   [db_get_col $rs $i val]
		set BET_DD($i,bet_id)     ""
		set BET_DD($i,name)       [db_get_col $rs $i name]
		set BET_DD($i,link_action) "ADMIN::FREEBETS::go_bet_dd"
	}

	tpBindVar key         BET_DD key dd_idx
	tpBindVar bet_level   BET_DD bet_level dd_idx
	tpBindVar bet_type    BET_DD bet_type dd_idx
	tpBindVar bet_id      BET_DD bet_id dd_idx
	tpBindVar name        BET_DD name dd_idx
	tpBindVar link_action BET_DD link_action dd_idx
}

proc go_bet_dd_event {} {

	global DB
	global BET_DD

	tpSetVar show_link 0
	tpBindString title "Event Sort"

	set sql {
		select
			distinct (sort) val,
			sort name
		from
			tev
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	tpSetVar dd_rows $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		set BET_DD($i,key)        $i
		set BET_DD($i,bet_level)  "EVENT"
		set BET_DD($i,bet_type)   [db_get_col $rs $i val]
		set BET_DD($i,bet_id)     ""
		set BET_DD($i,name)       [db_get_col $rs $i name]
		set BET_DD($i,link_action) "ADMIN::FREEBETS::go_bet_dd"
	}

	tpBindVar key         BET_DD key dd_idx
	tpBindVar bet_level   BET_DD bet_level dd_idx
	tpBindVar bet_type    BET_DD bet_type dd_idx
	tpBindVar bet_id      BET_DD bet_id dd_idx
	tpBindVar name        BET_DD name dd_idx
	tpBindVar link_action BET_DD link_action dd_idx
}


proc go_bet_dd_class {} {

	global DB
	global BET_DD

	tpSetVar show_link 0
	tpBindString title "Class Sort"

	set sql {
		select
			distinct (sort) val,
			sort name
		from
			tevclass
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	tpSetVar dd_rows $nrows

	global MKT_STD

	for {set i 0} {$i < $nrows} {incr i} {
		set BET_DD($i,key)        $i
		set BET_DD($i,bet_level)  "CLASS"
		set BET_DD($i,bet_type)   [db_get_col $rs $i val]
		set BET_DD($i,bet_id)     ""
		set BET_DD($i,name)       [db_get_col $rs $i name]
		set BET_DD($i,link_action) "ADMIN::FREEBETS::go_bet_dd"

		if {[OT_CfgGet USE_MKT_PROP_NAMES 0] && \
			[set idx [ADMIN::MKTPROPS::mkt_class_sort_idx $BET_DD($i,bet_type)]] != -1 && \
			[info exists MKT_STD($idx,sort_name)]} {
		set BET_DD($i,name) $MKT_STD($idx,sort_name)
		OT_LogWrite 10 "Setting BET_DD($i,name)=$BET_DD($i,name)"
		}
	}

	tpBindVar key         BET_DD key dd_idx
	tpBindVar bet_level   BET_DD bet_level dd_idx
	tpBindVar bet_type    BET_DD bet_type dd_idx
	tpBindVar bet_id      BET_DD bet_id dd_idx
	tpBindVar name        BET_DD name dd_idx
	tpBindVar link_action BET_DD link_action dd_idx
}


proc go_bet_dd_xgame {} {

	global DB
	global BET_DD

	set level [reqGetArg id]
	set type  [reqGetArg id2]

	OT_LogWrite 15 "go_bet_dd_xgame: level $level"
	OT_LogWrite 15 "go_bet_dd_xgame: type  $type"

	if {$type == ""} {
		set sql {
			select
				sort val,
				name
			from
				tXGameDef
		}
		tpBindString title "External Game Types"
	} else {
		tpSetVar show_link 0
		set sql [subst {
			select
				xgame_id val,
				"Draw " || comp_no name
			from
				tXGame
			where
				sort = '$type' and
				status = 'A' and
				shut_at > CURRENT
		}]
		tpBindString title "External Game Draws"
	}


	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	tpSetVar dd_rows $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		set BET_DD($i,key)        $i
		set BET_DD($i,level)      "XGAME"

		if {$type == ""} {
			set BET_DD($i,type)      [db_get_col $rs $i val]
			set BET_DD($i,id)        ""
		} else {
			set BET_DD($i,type)      ""
			set BET_DD($i,id)        [db_get_col $rs $i val]
		}

		set BET_DD($i,name)       [db_get_col $rs $i name]
		set BET_DD($i,link_action) "ADMIN::FREEBETS::go_bet_dd_xgame_draw"
	}



	tpBindVar key         BET_DD key dd_idx
	tpBindVar bet_id          BET_DD id dd_idx
	tpBindVar level       BET_DD level dd_idx
	tpBindVar name        BET_DD name dd_idx
	tpBindVar bet_type        BET_DD type dd_idx
	tpBindVar id2         BET_DD type dd_idx
	tpBindVar link_action BET_DD link_action dd_idx

}



proc go_bet_dd_xgame_draw {} {

	global DB
	global BET_DD

	set level [reqGetArg level]
	set type  [reqGetArg bet_type]

	OT_LogWrite 15 "go_bet_dd_xgame_draw: level $level"
	OT_LogWrite 15 "go_bet_dd_xgame_draw: type  $type"

	tpSetVar show_link 0
	set sql [subst {
		select
			xgame_id val,
			"Draw " || comp_no draw
		from
			tXGame
		where
			sort = '$type' and
			status = 'A' and
			shut_at > CURRENT
	}]



	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	tpSetVar dd_rows $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		set BET_DD($i,key)        $i
		set BET_DD($i,level)      "XGAME"

		set BET_DD($i,type)      ""
		set BET_DD($i,id)        [db_get_col $rs $i val]

		set BET_DD($i,name)       [db_get_col $rs $i draw]
		set BET_DD($i,link_action) "ADMIN::FREEBETS::go_bet_dd"
	}

	set sql [subst {
			select name
			from   tXGameDef
			where  sort = '$type'
		}]

	set stmt [inf_prep_sql $DB $sql]
	set res   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString title "[db_get_col $res 0 name] Draws"

	tpBindVar key         BET_DD type dd_idx
	tpBindVar id          BET_DD id dd_idx
	tpBindVar id3         BET_DD type dd_idx
	tpBindVar level       BET_DD level dd_idx
	tpBindVar name        BET_DD name dd_idx
	tpBindVar type        BET_DD type dd_idx
	tpBindVar link_action BET_DD link_action dd_idx

	asPlayFile -nocache fbet_dd.html
}


proc do_rval {} {

	set action [reqGetArg SubmitName]

	OT_LogWrite 10 "=> do_rval ($action)"

	if {$action == "RValAdd"} {
		do_rval_add
	} elseif {$action == "RValMod"} {
		do_rval_upd
	} elseif {$action == "RValDel"} {
		do_rval_del
	} elseif {$action == "Back"} {
		go_rval_list
	} else {
		error "Unexpected action : $action"
	}
}

proc do_rval_add {} {

	global DB

	set rname  [reqGetArg rname]
	set name   [reqGetArg name]
	set ilevel [reqGetArg level]
	set bet_id [reqGetArg key]
	set type   [reqGetArg type]

	OT_LogWrite 15 "rname    : $rname"
	OT_LogWrite 15 "name     : $name"
	OT_LogWrite 15 "bet_level: $ilevel"
	OT_LogWrite 15 "bet_type : $type"
	OT_LogWrite 15 "bet_id   : $bet_id"

	set sql {
		execute procedure pInsRedemptionVal(
			p_name = ?,
			p_bet_level = ?,
			p_bet_type = ?,
			p_bet_id = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		inf_exec_stmt $stmt\
			$rname\
			$ilevel\
			$type\
			$bet_id
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		rebind_request_data
		err_bind $msg
		go_add_rval
		return
	}

	msg_bind "Redemption value added"

	go_rval_list
}

proc do_rval_upd args {

	global DB

	set err 0

	set rval_id [reqGetArg RValID]
	set rname  [reqGetArg rname]
	set name   [reqGetArg name]
	set ilevel [reqGetArg level]
	set bet_id [reqGetArg key]
	set type   [reqGetArg type]
	set xgame_bet_id [reqGetArg id3]

	if {$ilevel == "XGAME"} {
		if {$xgame_bet_id == ""} {
			set bet_id ""
		} else {
			set type ""
			set bet_id $xgame_bet_id
		}
	}

	set sql {
		execute procedure pUpdRedemptionVal (
			p_redemption_id = ?,
			p_name = ?,
			p_bet_level = ?,
			p_bet_type = ?,
			p_bet_id=? )
		}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
				$rval_id\
				$rname\
				$ilevel\
				$type\
				$bet_id
			]} msg]} {
		err_bind $msg
		set err 1
	}

	if {$err} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_rval
		return
	}

	inf_close_stmt $stmt
	catch {db_close $res}

	go_rval_list
}

#
# Delete a redemption val
#
proc do_rval_del args {

	global DB

	set rval_id [reqGetArg RValID]

	OT_LogWrite 15 "Deleting Redemption val $rval_id"

	set sql {
		delete from tRedemptionVal
		where redemption_id = ?
		}

	set err 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
				$rval_id\
			]} msg]} {
		err_bind $msg
		set err 1
	}
	inf_close_stmt $stmt
	catch {db_close $res}

	if {$err} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_rval
		return
	}

	go_rval_list
}


proc do_token {} {

	set action [reqGetArg SubmitName]
	OT_LogWrite 10 "==> do_token ($action)"

	if {$action == "TokenAdd"} {
		do_token_add
	} elseif {$action == "TokenMod"} {
		do_token_upd
	} elseif {$action == "TokenDel"} {
		do_token_del
	} elseif {$action == "Back"} {
		go_offer
	} else {
		error "Unexpected action : $action"
	}
}

proc do_token_add {} {

	global DB TOKEN_CCY

	OT_LogWrite 10 "=> do_token_add"

	set offer_id [reqGetArg OfferID]

	set absolute [reqGetArg AbsoluteEx]
	set relative [reqGetArg RelativeEx]

	OT_LogWrite 10 "Adding token, $offer_id, $absolute, $relative"
	inf_begin_tran $DB

	set sql {
		execute procedure pInsToken(
			p_offer_id = ?,
			p_absolute_expiry = ?,
			p_relative_expiry = ?)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt $stmt $offer_id $absolute $relative]
	} msg]

	if {$c} {
		OT_LogWrite 3 "Failed to add token $msg"
		err_bind $msg
		inf_rollback_tran $DB
		ADMIN::FREEBETS::rebind_request_data
		go_add_token
		return
	} else {
		set token_id [db_get_coln $res 0 0]
		reqSetArg TokenID $token_id
		OT_LogWrite 1 "Token added with id $token_id"

		# now change the amounts
		bind_token_amounts $token_id

		set sql {
			execute procedure pUpdTokenAmount(
											  p_token_id = ?,
											  p_ccy_code = ?,
											  p_amount   = ?,
											  p_percentage_a = ?,
											  p_amount_max = ?)
		}

		set stmt1 [inf_prep_sql $DB $sql]

		for {set i 0} {$i < $TOKEN_CCY(num_ccys)} {incr i} {
			set ccy_code            $TOKEN_CCY($i,code)
			set value               [reqGetArg Value_$ccy_code]
			set percentage_amount   [reqGetArg PercentageAmount_$ccy_code]
			set amount_max          [reqGetArg AmountMax_$ccy_code]

			if {$value != ""} {
				OT_LogWrite 10 "Updating token amount for $ccy_code"

				set c [catch {
				inf_exec_stmt $stmt1    $token_id $ccy_code $value $percentage_amount $amount_max
				} msg]

				if {$c} {
				OT_LogWrite 3 "Failed to update token amount for $ccy_code. $msg"
				err_bind $msg
				inf_rollback_tran $DB
				ADMIN::FREEBETS::rebind_request_data
				go_add_token
				return
				}
			}
		}

		inf_close_stmt $stmt1
		# end of amount changing
	}

	inf_commit_tran $DB

	inf_close_stmt $stmt

	# end of token put
	go_token
}

proc do_token_upd args {

	global DB TOKEN_CCY

	set token_id [reqGetArg TokenID]
	set offer_id [reqGetArg OfferID]
	set absolute [reqGetArg AbsoluteEx]
	set relative [reqGetArg RelativeEx]
	set aff_id   [reqGetArg Affiliate]

	inf_begin_tran $DB

	set sql {
		execute procedure pUpdToken(
			p_token_id = ?,
			p_offer_id = ?,
			p_absolute_expiry =?,
			p_relative_expiry =?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt $stmt\
					 $token_id\
					 $offer_id\
					 $absolute\
					 $relative]
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		inf_rollback_tran $DB
		err_bind $msg
		go_token
		return
	}

	catch {db_close $res}

	# now change the amounts
	bind_token_amounts $token_id

	set sql {
		execute procedure pUpdTokenAmount(
										  p_token_id = ?,
										  p_ccy_code = ?,
										  p_amount   = ?,
										  p_percentage_a = ?,
										  p_amount_max = ?)
	}

	set stmt [inf_prep_sql $DB $sql]

	for {set i 0} {$i < $TOKEN_CCY(num_ccys)} {incr i} {

		set ccy_code $TOKEN_CCY($i,code)
		set value    [reqGetArg Value_$ccy_code]
		set percentage_amount [reqGetArg PercentageAmount_$ccy_code]
		set amount_max [reqGetArg AmountMax_$ccy_code]

		if {$value != ""} {
			OT_LogWrite 10 "Updating token amount for $ccy_code"

			set c [catch {
				inf_exec_stmt $stmt $token_id $ccy_code $value $percentage_amount $amount_max
			} msg]

			if {$c} {
				OT_LogWrite 3 "Failed to update token amount for $ccy_code. $msg"
				err_bind $msg
				inf_rollback_tran $DB
				ADMIN::FREEBETS::rebind_request_data
				go_add_token
				return
			}

		}
	}

	inf_commit_tran $DB

	inf_close_stmt $stmt
	# end of amount changing

	msg_bind "Token updated"
	go_token
}

proc do_token_del args {

	global DB
	OT_LogWrite 10 "=> do_token_del [reqGetArg TokenID]"

	set token_id [reqGetArg TokenID]

	set sql {
		execute procedure pDelToken(
									p_token_id = ?
									)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		inf_exec_stmt $stmt $token_id
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		err_bind $msg
		go_token
		return
	}
	msg_bind "Token deleted"
	go_offer
}

proc go_token {} {

	global DB

	set token_id [reqGetArg TokenID]

	OT_LogWrite 5 "==> go_token ($token_id)"
	tpSetVar opAdd 0

	# Token information
	set sql {
		select
			t.offer_id,
			t.absolute_expiry,
			t.relative_expiry
		from
			tToken t
		where
			token_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set tokenRes [inf_exec_stmt $stmt $token_id]
	inf_close_stmt $stmt

	tpBindString OfferID    [db_get_col $tokenRes 0 offer_id]
	tpBindString AbsoluteEx [db_get_col $tokenRes 0 absolute_expiry]
	tpBindString RelativeEx [string trim [db_get_col $tokenRes 0 relative_expiry]]
	tpBindString TokenID    [reqGetArg TokenID]

	bind_token_amounts $token_id

	# redemption value
	set sql {
		select
			r.redemption_id rval_id,
			name,
			bet_level,
			bet_type,
			bet_id
		from
			tRedemptionVal r,
			tPossibleBet p
		where
			r.redemption_id = p.redemption_id and
			p.token_id = ?
		order by
			bet_level, bet_type, bet_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set RValRes [inf_exec_stmt $stmt $token_id]
	inf_close_stmt $stmt

	tpSetVar NumRVals [db_get_nrows $RValRes]

	tpBindTcl RValID sb_res_data $RValRes rval_idx rval_id
	tpBindTcl Name sb_res_data $RValRes rval_idx name
	tpBindTcl BetLevel sb_res_data $RValRes rval_idx bet_level
	tpBindTcl BetType sb_res_data $RValRes rval_idx bet_type
	tpBindTcl BetID sb_res_data $RValRes rval_idx bet_id

	asPlayFile -nocache token.html

	db_close $tokenRes
	db_close $RValRes
}

proc go_add_token {} {

	global DB
	global CURR_ARRAY

	catch {unset CURR_ARRAY}

	set offer_id [reqGetArg OfferID]

	if {$offer_id == ""} {
		err_bind "You must create the offer first"
		go_add_offer
		return
	}

	bind_token_amounts "" $offer_id

	tpSetVar opAdd 1

	asPlayFile -nocache token.html
}


proc go_pb {} {

	global DB

	tpSetVar AddPB 1

	set sql {
		select
			redemption_id rval_id,
			bet_level,
			bet_type,
			bet_id,
			name
		from
			tRedemptionVal
		order by
			bet_level, bet_type, bet_id
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set res  [inf_exec_stmt $stmt]} msg]} {
		err_bind $msg
		asPlayFile -nocache rval_list.html
		return
	}

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	tpSetVar NumRVals   $rows

	tpBindTcl RValID sb_res_data $res rval_idx rval_id
	tpBindTcl BetLevel sb_res_data $res rval_idx bet_level
	tpBindTcl BetType sb_res_data $res rval_idx bet_type
	tpBindTcl BetID  sb_res_data $res rval_idx bet_id
	tpBindTcl Name sb_res_data $res rval_idx name

	asPlayFile -nocache rval_list.html

	db_close $res
}

proc do_add_pb {} {
	global DB

	set err 0

	set token_id [reqGetArg TokenID]
	set rval_id [reqGetArg RValID]

	set sql {   insert into tPossibleBet
			values (?, ?)
		}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
				$token_id\
				$rval_id\
		]} msg]} {
		set err 1
		err_bind $msg
	}

	catch {db_close $res}

	if {$err} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		go_pb

		return
	}

	inf_close_stmt $stmt

	tpSetVar PBAdded 1

	go_token
}

proc do_pb_del {} {

	global DB

	set token_id [reqGetArg TokenID]
	set rval_id [reqGetArg RValID]
	tpBindString TokenID $token_id

	set sql {
		delete from
			tPossibleBet
		where
			token_id = ? and
			redemption_id = ?
	}

	set c [catch {
		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt $token_id $rval_id]
		inf_close_stmt $stmt
		db_close $res
	} msg]

	if {$c} {
		err_bind $msg
	}

	go_token
}

proc rebind_request_data {} {
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		tpBindString [reqGetNthName $i] [reqGetNthVal $i]
   }
}

############################################################
## Show the generate vouchers admin screen
##############################################################
proc go_generate_vouchers {} {
	set VOUCHER_URL [OT_CfgGet VOUCHER_URL]

	tpBindString VOUCHER_URL $VOUCHER_URL

	set voucher_type [bind_voucher_types]

	set trigger_id [bind_voucher_triggers $voucher_type]

	get_voucher_runs $trigger_id

	tpBindString FORM_CHECKED "checked"

	asPlayFile -nocache voucher.html
}

############################################################
## Handle changing voucher type on voucher Generation screen
############################################################
proc go_generate_vouchers_select {} {

	global DB

	rebind_request_data

	set trigger_id [bind_voucher_triggers [reqGetArg SelVoucherCode]]
	tpBindString SelVoucherTrigger [reqGetArg SelVoucherTrigger]

	generic_voucher_reselect_stuff $trigger_id

}

############################################################
## Handle changing trigger on voucher Generation screen
## refreshes run log section
############################################################
proc go_generate_trigger_select {} {

	global DB

	rebind_request_data

	bind_voucher_triggers [reqGetArg SelVoucherCode]

	set trigger_id [reqGetArg SelVoucherTrigger]
	tpBindString SelVoucherTrigger $trigger_id

	generic_voucher_reselect_stuff $trigger_id

}

proc go_num_voucher_runs_select {} {

	global DB

	rebind_request_data

	bind_voucher_triggers [reqGetArg SelVoucherCode]

	set trigger_id [reqGetArg SelVoucherTrigger]
	tpBindString SelVoucherTrigger $trigger_id

	generic_voucher_reselect_stuff $trigger_id

}

proc generic_voucher_reselect_stuff {trigger_id} {

	if {[reqGetArg DateOption] == "dob"} {
		tpBindString dob_checked "checked"
	} elseif {[reqGetArg DateOption] == "reg"} {
		tpBindString reg_checked "checked"
	}

	set voucher_type [bind_voucher_types]

	get_voucher_runs $trigger_id

	tpSetVar VoucherCode [reqGetArg SelVoucherCode]
	tpBindString SelVoucherCode [reqGetArg SelVoucherCode]
	tpBindString SelNumVoucherRuns [reqGetArg SelNumVoucherRuns]

	asPlayFile -nocache voucher.html


}

##############################################################
## Gets logged voucher runs for a particular offer via the
## trigger id of the voucher trigger on that offer
##############################################################
proc get_voucher_runs {trigger_id} {

	global DB
	global VOUCHER_RUNS

	OT_LogWrite 1 "Entering get_voucher_runs........."

	catch {unset VOUCHER_RUNS}


	set num_disp_runs [reqGetArg SelNumVoucherRuns]

	if {$num_disp_runs == ""} {
		set first ""
	} else {
		set first "first $num_disp_runs"
	}

	set sql "
		select
			$first
			r.voucher_run_id,
			r.cr_date,
			r.generate_option,
			r.vouchers_expected,
			r.sigdt,
			r.sigdt_option,
			r.inact_period,
			r.incen_number,
			r.acct_no,
			r.username,
			r.upload_filename,
			r.file_created,
			r.export_filename,
			v.valid_from,
			v.valid_to,
			count(v.voucher_id) as vouchers_created
		from
			tVoucherRun r,
			tVoucher v
		where
			r.voucher_run_id = v.voucher_run_id and
			v.trigger_id = ?
		group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
		order by 2 DESC
	"

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $trigger_id]} msg]} {
		err_bind $msg
		asPlayFile -nocache voucher.html
		return
	}

	inf_close_stmt $stmt

	tpSetVar num_voucher_runs [db_get_nrows $rs]

	if {[db_get_nrows $rs] != 0} {

		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

			foreach n [db_get_colnames $rs] {

				set VOUCHER_RUNS($i,$n)     [db_get_col $rs $i $n]
			}
		}

		foreach n [db_get_colnames $rs] {

			tpBindVar $n VOUCHER_RUNS $n vr_idx
		}
	}

	db_close $rs

}

############################################################
## Calls procs to generate voucher list based on whether
## user wants to use screen options or an input file
############################################################
proc do_generate_vouchers {} {

	global VOUCHER
	global VOUCHER_FILE


	set VOUCHER(generate_option)    [reqGetArg GenerateOption]
	set VOUCHER(voucher_type)       [reqGetArg SelVoucherCode]
	set VOUCHER(trigger_id)         [reqGetArg SelVoucherTrigger]
	set VOUCHER(valid_from)         [reqGetArg ValidFrom]
	set VOUCHER(valid_to)           [reqGetArg ValidTo]
	set VOUCHER(sigdt)              [reqGetArg date]
	set VOUCHER(sigdt_option)       [reqGetArg DateOption]
	set VOUCHER(inact_period)       [reqGetArg period]
	set VOUCHER(incen_number)       [reqGetArg number]
	set VOUCHER(acct_no)            [reqGetArg acct_no]
	set VOUCHER(username)           [reqGetArg username]
	set VOUCHER(upload_filename)    [reqGetArg filename]
	set VOUCHER(aff_level)          [reqGetArg AffLevel]
	set VOUCHER(aff_id)             [reqGetArg AffId]
	set VOUCHER(aff_grp_id)         [reqGetArg AffGrpId]

	OT_LogWrite 10 "generate_option :   $VOUCHER(generate_option)"
	OT_LogWrite 10 "type                :   $VOUCHER(voucher_type)"
	OT_LogWrite 10 "trigger_id      :   $VOUCHER(trigger_id)"
	OT_LogWrite 10 "valid_from      :   $VOUCHER(valid_from)"
	OT_LogWrite 10 "valid_to            :   $VOUCHER(valid_to)"
	OT_LogWrite 10 "sigdt           :   $VOUCHER(sigdt)"
	OT_LogWrite 10 "sigdt_option        :   $VOUCHER(sigdt_option)"
	OT_LogWrite 10 "inact_period        :   $VOUCHER(inact_period)"
	OT_LogWrite 10 "incen_number        :   $VOUCHER(incen_number)"
	OT_LogWrite 10 "acct_no         :   $VOUCHER(acct_no)"
	OT_LogWrite 10 "username            :   $VOUCHER(username)"
	OT_LogWrite 10 "filename            :   $VOUCHER(upload_filename)"


	# validate run options selected
	if {[validate_options]} {

		# log details of the voucher run and generate a run id
		set VOUCHER(voucher_run_id) [create_voucher_run]
		OT_LogWrite 1 "voucher run id = $VOUCHER(voucher_run_id)"

		if {$VOUCHER(voucher_run_id) > 0} {

			if {[create_voucher_file]} {

				# process options depending on whether user selected options or uploaded file
				if {$VOUCHER(generate_option) == "form"} {
					set voucher_list [new_form_voucher_list]

				} elseif {$VOUCHER(generate_option) == "file"} {
					set voucher_list [new_file_voucher_list]

				} else {
					set voucher_list 0
				}

				close $VOUCHER_FILE

				if {$voucher_list != "0"} {
					msg_bind "Created voucher file [OT_CfgGet EXPORT_DIR]/voucher/$VOUCHER(export_filename)"
				}
			}
		}
	}

	tpBindString VOUCHER_URL [OT_CfgGet VOUCHER_URL]

	set voucher_type [bind_voucher_types]

	bind_voucher_triggers $VOUCHER(voucher_type)

	get_voucher_runs $VOUCHER(trigger_id)

	tpBindString SelVoucherTrigger $VOUCHER(trigger_id)

	tpSetVar VoucherCode $VOUCHER(voucher_type)
	tpBindString SelVoucherCode $VOUCHER(voucher_type)
	tpBindString SelNumVoucherRuns [reqGetArg SelNumVoucherRuns]

	unset VOUCHER
	unset VOUCHER_FILE
	asPlayFile -nocache voucher.html
}

proc validate_options {} {

	global VOUCHER

	if {$VOUCHER(generate_option) == "form"} {

		# general form options validation
		set date_pattern {[0-9]{4}[-][0-9]{2}[-][0-9]{2}}

		if {$VOUCHER(valid_from) != ""} {
			if {![regexp $date_pattern $VOUCHER(valid_from)]} {
				OT_LogWrite 1 "Date format is invalid"
				err_bind "Valid From Date format is invalid"
				return 0
			}
		}
		if {$VOUCHER(valid_to) != ""} {
			if {![regexp $date_pattern $VOUCHER(valid_to)]} {
				OT_LogWrite 1 "Date format is invalid"
				err_bind "Valid To Date format is invalid"
				return 0
			}
		}
		if {$VOUCHER(trigger_id) == ""} {
			OT_LogWrite 1 "No trigger id supplied"
			err_bind "You must select an offer to which the vouchers are to be applied"
			return 0
		}
		# voucher type specific validation
		switch -exact -- $VOUCHER(voucher_type) {

			SIGDT {
				if {$VOUCHER(sigdt) == ""} {
					OT_LogWrite 1 "Significant date not entered."
					err_bind "Significant date not entered"
					return 0
				} else {
					if {![regexp $date_pattern $VOUCHER(sigdt)]} {
						OT_LogWrite 1 "Date format is invalid"
						err_bind "Significant Date format is invalid"
						return 0
					}
				}
			}
			INACT {
				if {$VOUCHER(inact_period) == ""} {
					OT_LogWrite 1 "Inactive period not entered."
					err_bind "Inactive period not entered"
					return 0
				} else {

					if {![string is integer $VOUCHER(inact_period)]} {
						OT_LogWrite 1 "Period entered in invalid integer"
						err_bind "Inactive period must be an integer"
						return 0
					}
				}
			}
			INCEN {

				if {$VOUCHER(incen_number) == ""} {
					OT_LogWrite 1 "Number of vouchers not entered."
					err_bind "Number of vouchers not entered"
					return 0
				}

				if {![string is integer $VOUCHER(incen_number)]} {

					OT_LogWrite 1 "Invalid value for number of vouchers"
					err_bind "Invalid input. Please enter a valid number of vouchers"
					return 0
				}

				if {!($VOUCHER(incen_number) > 0)} {
					OT_LogWrite 1 "Invalid value for number of vouchers"
					err_bind "Must request at least one voucher"
					return 0
				}
			}
			VAGUE {
				if {($VOUCHER(acct_no) == "") && ($VOUCHER(username) == "")} {
					OT_LogWrite 1 "Account Number or Username not entered"
					err_bind "Account Number or Username not entered"
					return 0
				}
				if {($VOUCHER(acct_no) != "") && ($VOUCHER(username) != "")} {
					OT_LogWrite 1 "Account Number and Username both entered"
					err_bind "Account Number and Username both entered"
					return 0
				}
				# will check that account number or username produces a valid
				# customer later when query is run to retrieve details
			}
			default {
				OT_LogWrite 1 "Unknown voucher type."
				err_bind "Unknown voucher type."
				return 0
			}

		}


	} elseif {$VOUCHER(generate_option) == "file"} {
		# should we do any validation here??
		# surely they should just get the file format right......

		# could strip out the filename here i suppose

		set filename_length [string length $VOUCHER(upload_filename)]

		set bslash_pos [string last "\\" $VOUCHER(upload_filename)]
		set fslash_pos [string last "/" $VOUCHER(upload_filename)]

		if {$bslash_pos == $fslash_pos} {
			# filename doenst contain either as both must have evaluated to -1
		} else {
			if {$bslash_pos > $fslash_pos} {
				# take filename to be after that backslash
				set VOUCHER(upload_filename) [string range $VOUCHER(upload_filename) [expr $bslash_pos + 1] [expr $filename_length - 1]]

			} else {
				# take filename to be after the forwardslash
				set VOUCHER(upload_filename) [string range $VOUCHER(upload_filename) [expr $fslash_pos + 1] [expr $filename_length - 1]]
			}
		}
		OT_LogWrite 10 "extracted filename = $VOUCHER(upload_filename)"
	}

	return 1
}

#########################################################################################
# Logs voucher run option in tVoucherRun so we have a history of what voucher batches
# are made
#########################################################################################
proc create_voucher_run {} {

	global DB
	global VOUCHER

	OT_LogWrite 10 "Entering create_voucher_run........"

	# insert a run record into tVoucherRun returning the run id

	set sql {
		execute procedure pInsVoucherRun(
			p_generate_option = ?,
			p_sigdt = ?,
			p_sigdt_option = ?,
			p_inact_period = ?,
			p_incen_number = ?,
			p_acct_no = ?,
			p_username = ?,
			p_upload_filename = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set rs [inf_exec_stmt   $stmt\
								$VOUCHER(generate_option)\
								$VOUCHER(sigdt)\
								$VOUCHER(sigdt_option)\
								$VOUCHER(inact_period)\
								$VOUCHER(incen_number)\
								$VOUCHER(acct_no)\
								$VOUCHER(username)\
								$VOUCHER(upload_filename)]
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		OT_LogWrite 3 "Failed to create voucher run $msg"
		err_bind $msg
		return 0
	}

	# get the run id from the result set

	set run_id [db_get_coln $rs 0 0]

	return $run_id

}
#########################################################################################
# Logs voucher run option in tVoucherRun so we have a history of what voucher batches
# are made
#########################################################################################
proc update_voucher_run {} {

	global DB
	global VOUCHER

	OT_LogWrite 10 "Entering update_voucher_run........"

	# update the run record in tVoucherRun

	set sql {
		update
			tVoucherRun
		set
			vouchers_expected = ?,
			file_created = ?,
			export_filename = ?
		where
			voucher_run_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set rs [inf_exec_stmt   $stmt\
								$VOUCHER(vouchers_expected)\
								$VOUCHER(file_created)\
								$VOUCHER(export_filename)\
								$VOUCHER(voucher_run_id)]
			inf_close_stmt $stmt
	} msg]

	if {$c} {
		OT_LogWrite 3 "Failed to update voucher run $msg"
		err_bind $msg
		return 0
	}

	return 1

}

#############################################################################
## Generates vouchers based upon the options on the generate
## vouchers screen
#############################################################################
proc new_form_voucher_list {} {

	global DB
	global VOUCHER
	global VOUCHER_FILE

	OT_LogWrite 10 "Entering new_form_voucher_list........"

	# do different stuff depending on the voucher type we are generating a file for
	switch -exact -- $VOUCHER(voucher_type) {

		SIGDT {
			##############################################################################
			# stuff for the significant date vouchers
			##############################################################################

			# set up sepecific query options for different date types

			switch -exact -- $VOUCHER(sigdt_option) {
				dob {set date_field "cr.dob"}
				reg {set date_field "c.cr_date"}
				default {}
			}

			set aff_table ""

			switch -exact -- $VOUCHER(aff_level) {
				All     {set aff_clause "and c.aff_id is not null"}
				None    {set aff_clause "and c.aff_id is null"}
				Single  {set aff_clause "and c.aff_id == $VOUCHER(aff_id)"}
				Group   {
							set aff_table ",taffiliate a"
							set aff_clause "and c.aff_id = a.aff_id and a.aff_grp_id = $VOUCHER(aff_grp_id)"
						}
				default {set aff_clause ""}
			}

			# create the query using the options set above
			set sql "
				select
					c.cust_id,
					c.acct_no,
					c.aff_id,
					cr.email,
					cr.addr_street_1,
					cr.addr_street_2,
					cr.addr_street_3,
					cr.addr_street_4,
					cr.addr_city,
					cr.addr_country,
					cr.addr_postcode,
					$date_field
				from
					tcustomer c,
					tcustomerreg cr
					$aff_table
				where
					c.cust_id = cr.cust_id and
					day($date_field) = ? and
					month($date_field) = ?
					$aff_clause
			"

			set year    [string range $VOUCHER(sigdt) 0 3]
			set month   [string range $VOUCHER(sigdt) 5 6]
			set day     [string range $VOUCHER(sigdt) 8 9]

			if {$year == "0000"} {
				# we want to match any customers with date matching day and month

				OT_LogWrite 1 " sql stmt = $sql"

				set stmt [inf_prep_sql $DB $sql]
				set rs [inf_exec_stmt $stmt $day $month]
			} else {
				# we want to match specific date

				append sql " and \n year($date_field) = ?"
				OT_LogWrite 1 " sql stmt = $sql"

				set stmt [inf_prep_sql $DB $sql]
				set rs [inf_exec_stmt $stmt $day $month $year]
			}

			inf_close_stmt $stmt

			set nrows [db_get_nrows $rs]
			set VOUCHER(vouchers_expected) $nrows

			update_voucher_run

			set voucher_list ""

			# create as many vouchers as there are customers in the results set

			for {set i 0} {$i < $nrows} {incr i} {

				OT_LogWrite 10 "    Processing voucher [expr $i + 1] of $nrows"
				set cust_id     [db_get_col $rs $i cust_id]
				set acct_no     [db_get_col $rs $i acct_no]

				set new_voucher [generate_voucher $cust_id]

				# check whether voucher was generated properly
				if {$new_voucher == ""} {
					OT_LogWrite 1 " *** Error generating voucher. ***"
				} else {

					set voucher_line ""
					append voucher_line "$cust_id,$new_voucher,$acct_no"

					# retreive values from the results set
					foreach field {email addr_street_1 addr_street_2 addr_street_3\
									addr_street_4 addr_city addr_country addr_postcode} {

						set data [db_get_col $rs $i $field]
						append voucher_line ",$data"
					}

					puts $VOUCHER_FILE $voucher_line
				}
			}

			db_close $rs

		}
		INACT {
			##############################################################################
			# stuff for the inactive customer vouchers
			##############################################################################

			OT_LogWrite 10 "    We are creating an inactive voucher list."

			# format the inactive period on which the query is based
			set period $VOUCHER(inact_period)
			append period " 00:00:00.000"

			set aff_table ""

			switch -exact -- $VOUCHER(aff_level) {
				All     {set aff_clause "and c.aff_id is not null"}
				None    {set aff_clause "and c.aff_id is null"}
				Single  {set aff_clause "and c.aff_id == $VOUCHER(aff_id)"}
				Group   {
							set aff_table ",taffiliate a"
							set aff_clause "and c.aff_id = a.aff_id and a.aff_grp_id = $VOUCHER(aff_grp_id)"
						}
				default {set aff_clause ""}
			}

			set sql "
				select
					c.cust_id,
					c.acct_no,
					c.aff_id,
					cr.email,
					cr.addr_street_1,
					cr.addr_street_2,
					cr.addr_street_3,
					cr.addr_street_4,
					cr.addr_city,
					cr.addr_country,
					cr.addr_postcode
				from
					tcustomer c,
					tcustomerreg cr
					$aff_table
				where
					c.cust_id = cr.cust_id and
					((c.last_bet is null) or
					((CURRENT - c.last_bet) > ?))
					$aff_clause

			"

			OT_LogWrite 1 "INACT:: $sql"

			set stmt [inf_prep_sql $DB $sql]
			set rs [inf_exec_stmt $stmt $period]
			inf_close_stmt $stmt

			set nrows [db_get_nrows $rs]
			set VOUCHER(vouchers_expected) $nrows

			update_voucher_run

			# create as many vouchers as there are customers in the results set
			set voucher_list ""

			for {set i 0} {$i < $nrows} {incr i} {

				OT_LogWrite 1 " Processing voucher [expr {$i + 1}] of $nrows"

				set cust_id     [db_get_col $rs $i cust_id]
				set acct_no     [db_get_col $rs $i acct_no]

				set new_voucher [generate_voucher $cust_id]

				if {$new_voucher == ""} {
					OT_LogWrite 1 " *** Error generating voucher. ***"
				} else {

					set voucher_line ""
					append voucher_line "$cust_id,$new_voucher,$acct_no"

					# retreive values from the results set
					foreach field {email addr_street_1 addr_street_2 addr_street_3\
									addr_street_4 addr_city addr_country addr_postcode} {

						set data [db_get_col $rs $i $field]
						append voucher_line ",$data"
					}
					puts $VOUCHER_FILE $voucher_line
				}
			}

			db_close $rs

		}
		INCEN {
			##############################################################################
			# stuff for the incentive / prize vouchers
			# generates a specified number of non-customer-specific vouchers
			##############################################################################

			OT_LogWrite 10 "    We are creating an incentive voucher list."

			set VOUCHER(vouchers_expected) $VOUCHER(incen_number)

			update_voucher_run

			for {set i 0} {$i < $VOUCHER(incen_number)} {incr i} {

				OT_LogWrite 10 "    Processing voucher [expr $i + 1] of $VOUCHER(incen_number)"

				set new_voucher [generate_voucher ""]

				if {$new_voucher == ""} {
					OT_LogWrite 1 " *** Error generating voucher. ***"
				} else {
					set voucher_line ""
					append voucher_line $new_voucher
					puts $VOUCHER_FILE $voucher_line
				}
			}
		}
		VAGUE {
			##############################################################################
			# stuff for the miscellaneous customer vouchers
			##############################################################################

			OT_LogWrite 10 "    We are creating an miscellaneous voucher list."

			if {$VOUCHER(acct_no) != ""} {
				set vague_field "acct_no"
				set vague_value $VOUCHER(acct_no)
			} elseif {$VOUCHER(username) != ""} {
				set vague_field "username"
				set vague_value $VOUCHER(username)
			}

			set aff_table ""

			switch -exact -- $VOUCHER(aff_level) {
				All     {set aff_clause "and c.aff_id is not null"}
				None    {set aff_clause "and c.aff_id is null"}
				Single  {set aff_clause "and c.aff_id == $VOUCHER(aff_id)"}
				Group   {
							set aff_table ",taffiliate a"
							set aff_clause "and c.aff_id = a.aff_id and a.aff_grp_id = $VOUCHER(aff_grp_id)"
						}
				default {set aff_clause ""}
			}

			set sql "
				select
					c.cust_id,
					c.acct_no,
					cr.email,
					cr.addr_street_1,
					cr.addr_street_2,
					cr.addr_street_3,
					cr.addr_street_4,
					cr.addr_city,
					cr.addr_country,
					cr.addr_postcode
					$aff_table
				from
					tcustomer c,
					tcustomerreg cr
				where
					c.cust_id = cr.cust_id and
					c.$vague_field = ?
					$aff_clause
			"

			set stmt [inf_prep_sql $DB $sql]
			set rs [inf_exec_stmt $stmt $vague_value]
			inf_close_stmt $stmt

			set nrows [db_get_nrows $rs]
			set VOUCHER(vouchers_expected) $nrows

			update_voucher_run
			OT_LogWrite 1 " Number of vouchers to create = $nrows"

			if {$VOUCHER(vouchers_expected) != "1"} {
				# we should have only one voucher to create
				OT_LogWrite 3 "Should only be creating voucher for 1 customer"
				err_bind "Invalid acct_no or username"
				return 0
			}

			# create as many vouchers as there are customers in the results set

			set voucher_list ""

			set cust_id     [db_get_col $rs 0 cust_id]
			set acct_no     [db_get_col $rs 0 acct_no]

			set new_voucher [generate_voucher $cust_id]

			if {$new_voucher == ""} {
				OT_LogWrite 1 " *** Error generating voucher. ***"
			} else {

				tpSetVar DisplayVoucher 1
				tpBindString VAGUE_VOUCHER $new_voucher
				tpBindString VAGUE_FIELD $vague_field
				tpBindString VAGUE_VALUE $vague_value

				set voucher_line ""
				append voucher_line "$cust_id,$new_voucher,$acct_no"

				# retreive values from the results set
				foreach field {email addr_street_1 addr_street_2 addr_street_3\
								addr_street_4 addr_city addr_country addr_postcode} {
					set data [db_get_col $rs 0 $field]
					append voucher_line ",$data"
				}
				puts $VOUCHER_FILE $voucher_line
			}

			db_close $rs

		}
		default {
			# types we havent thought of yet
		}
	}
}

#########################################################################
## Generates vouchers based upon an imported file
#########################################################################
proc new_file_voucher_list {} {

	global DB
	global VOUCHER
	global VOUCHER_FILE

	OT_LogWrite 8 "Entering new_file_voucher_list..........."

	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR]

	set filename "$UPLOAD_DIR/voucher/$VOUCHER(upload_filename)"

	if [catch {set file [open $filename r]} fileId] {
		return [handle_err "File Error" "$fileId"]
	}

	set voucher_import [gets $file]
	set line 1
	set voucher_list ""

	if ![regexp {^([A-Z]{5})[,]([0-9]{10,10})[,]([0-9]{10,10})[,]([0-9]{4}[-][0-9]{2}[-][0-9]{2}[ ][0-9]{2}[:][0-9]{2}[:][0-9]{2})[,]([0-9]{4}[-][0-9]{2}[-][0-9]{2}[ ][0-9]{2}[:][0-9]{2}[:][0-9]{2})} $voucher_import junk voucher_type total_vouchers trigger_id valid_from valid_to] {
		OT_LogWrite 3 "Invalid format for header line: $voucher_import"
		err_bind "Invalid format for header line: $voucher_import"
		return 0
	}

	set total_vouchers [string trimleft $total_vouchers "0"]
	set VOUCHER(vouchers_expected) $total_vouchers
	set VOUCHER(voucher_type) $voucher_type
	set VOUCHER(valid_from) $valid_from
	set VOUCHER(valid_to) $valid_to
	set VOUCHER(trigger_id) [string trimleft $trigger_id "0"]

	OT_LogWrite 10 "    voucher_type = $VOUCHER(voucher_type)"
	OT_LogWrite 10 "    total vouchers = $total_vouchers"
	OT_LogWrite 10 "    trigger id = $VOUCHER(trigger_id)"

	update_voucher_run

	# need to check that the voucher type is appropriate for the trigger id

	set sql {
		select  voucher_type
		from    ttrigger
		where   trigger_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $VOUCHER(trigger_id)]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		# we have some kind of error
		OT_LogWrite 1 " Unable to get voucher_type for trigger with id $VOUCHER(trigger_id)"
		err_bind "Unable to get voucher type for trigger $VOUCHER(trigger_id)"
		return 0
	} else {
		# check that they match
		set trg_voucher_type [db_get_col $rs 0 voucher_type]
		db_close $rs

		if {$VOUCHER(voucher_type) != $trg_voucher_type} {
			# voucher types differ so error
			OT_LogWrite 1 "Voucher type in file $VOUCHER(voucher_type) different to voucher type on trigger $trg_voucher_type"
			err_bind "Voucher type in file not matching trigger"
			return 0
		}
	}

	set num_vouchers_expected 0
	set num_vouchers_created 0
	set num_voucher_lines 0

	# loop through the rows in the file putting data into an array
	while {1} {
		set voucher_import [gets $file]
		incr line

		if {$voucher_import==""} {
			OT_LogWrite 1 "Unexpected end of file."
			err_bind "Unexpected end of file. Encountered a record which is neither a data record nor a trailer record at line $line"
			return 0
		}

		# expression to get the cust id
		regexp {^(.*)} $voucher_import junk acct_no


		set FILE_VOUCHER($line,acct_no) $acct_no

		if {$acct_no == "00000000"} {
			# trailer record so get out of loop
			break
		}
		incr num_voucher_lines
	}

	# check that number of voucher lines match total in file header (Except incentive vouchers)
	if {$voucher_type != "INCEN"} {
		if {$num_voucher_lines != $total_vouchers} {
			OT_LogWrite 1 "The number of voucher lines in the file doesnt match the voucher total in the file header."
			err_bind "File header total and number of voucher lines don't match"
			return 0
		}
	}

	# now loop over created array to create tokens
	for {set i 2} {$i < $line} {incr i} {
		# run query to get customer data for the export file
		set sql {
			select
				c.cust_id,
				c.acct_no,
				cr.email,
				cr.addr_street_1,
				cr.addr_street_2,
				cr.addr_street_3,
				cr.addr_street_4,
				cr.addr_city,
				cr.addr_country,
				cr.addr_postcode
			from
				tcustomer c,
				tcustomerreg cr
			where
				c.cust_id = cr.cust_id and
				c.acct_no = ?
		}

		if {$voucher_type == "INCEN"} {

			for {set j 0} {$j < $total_vouchers} {incr j} {

				set new_voucher [generate_voucher ""]

				if {$new_voucher == ""} {
					OT_LogWrite 1 " *** Error generating voucher. ***"
				} else {
					set voucher_line ""
					append voucher_line "$new_voucher"
					puts $VOUCHER_FILE $voucher_line
				}
			}

		} else {

			set stmt [inf_prep_sql $DB $sql]
			set rs [inf_exec_stmt $stmt $FILE_VOUCHER($i,acct_no)]
			inf_close_stmt $stmt

			set nrows [db_get_nrows $rs]

			if {$nrows != 1} {
				# we have some kind of error
				OT_LogWrite 1 " Unable to get data for customer with acct_no $FILE_VOUCHER($i,acct_no)"
				err_bind "Unable to get data for a customer"
				return 0
			} else {

				set db_cust_id  [db_get_col $rs 0 cust_id]
				set acct_no     [db_get_col $rs 0 acct_no]

				set new_voucher [generate_voucher $db_cust_id]

				if {$new_voucher == ""} {
					OT_LogWrite 1 " *** Error generating voucher. ***"
				} else {

					set voucher_line ""
					append voucher_line "$db_cust_id,$new_voucher,$acct_no"

					# retreive values from the results set
					foreach field {email addr_street_1 addr_street_2 addr_street_3\
									addr_street_4 addr_city addr_country addr_postcode} {
						set data [db_get_col $rs 0 $field]
						append voucher_line ",$data"
					}

					puts $VOUCHER_FILE $voucher_line
				}
			}
			db_close $rs
		}
	}

	close $file

}

#########################################################################
## Opens and creates the export file
#########################################################################
proc create_voucher_file {} {

	global VOUCHER VOUCHER_FILE

	set filename "voucher_run_$VOUCHER(voucher_run_id)"
	append filename "."
	append filename [clock format [clock seconds] -format "%Y.%m.%d-%H:%M:%S"]
	OT_LogWrite 1 "Creating file $filename"

	set exportDirectory [OT_CfgGet EXPORT_DIR]

	if [catch {open $exportDirectory/voucher/$filename w 0775} VOUCHER_FILE] {
		OT_LogWrite 1 "Failed to open file $exportDirectory/voucher/$filename"
		err_bind "Failed to open file $exportDirectory/voucher/$filename"
		set VOUCHER(file_created) "N"
		set VOUCHER(export_filename) ""
		return 0
   }

	set VOUCHER(file_created) "Y"
	set VOUCHER(export_filename) "$filename"
	return 1
}

proc display_file {} {

	global FILE_LINE

	OT_LogWrite 1 "Entering display_file........."

	set exportDirectory [OT_CfgGet EXPORT_DIR]
	set uploadDirectory [OT_CfgGet UPLOAD_DIR]

	set filename        [reqGetArg DisplayFilename]
	set filetype        [reqGetArg DisplayFiletype]
	set fromline        [reqGetArg FromLine]
	set toline          [reqGetArg ToLine]
	set totallines      [reqGetArg TotalLines]
	set submitoption    [reqGetArg SubmitOption]
	set acctno          [reqGetArg AcctNo]
	set vouchertype     [reqGetArg VoucherType]

	tpBindString filename $filename
	tpBindString filetype $filetype
	tpBindString fromline $fromline
	tpBindString toline $toline
	tpBindString totallines $totallines
	tpBindString vouchertype $vouchertype
	tpSetVar vouchertype $vouchertype
	tpSetVar submitoption $submitoption

	if {$filetype == "voucher"} {
		set filename "$exportDirectory/voucher/$filename"
	} elseif {$filetype == "upload"} {
		set filename "$uploadDirectory/voucher/$filename"
	}

	if [catch {open $filename r 0775} DISPLAY_FILE] {
		OT_LogWrite 1 "Failed to open file $filename"
		err_bind "Failed to open file $filename"
		return 0
   }

	set fileline 0
	set displine 0
	foreach line [split [read $DISPLAY_FILE] \n] {

		incr fileline

		if {$submitoption == "search"} {

			# need to split the line into its components
			set line_list [split $line ,]
			set file_acctno [lindex $line_list 2]

			if {$file_acctno == $acctno} {

				# we have a match so retreive line data
				set FILE_LINE($displine,lineno) $fileline

				set list_index 0
				foreach field {custid voucher acct_no email} {

					set FILE_LINE($displine,$field) [lindex $line_list $list_index]
					incr list_index

				}
				foreach field {addr_street_1 addr_street_2 addr_street_3 addr_street_4 addr_city addr_country addr_postcode} {

					append FILE_LINE($displine,address) [lindex $line_list $list_index]
					if {$list_index != 10} {
						append FILE_LINE($displine,address) ","
					}
					incr list_index

				}
				incr displine

			}

		} else {

			if {($fileline >= $fromline) && ($fileline <= $toline)} {
				# we've reached the section to display

				# now need to split the line into its components
				set FILE_LINE($displine,lineno) $fileline

				if {$vouchertype != "INCEN"} {
					set line_list [split $line ,]
					set list_index 0

					foreach field {custid voucher acct_no email} {

						set FILE_LINE($displine,$field) [lindex $line_list $list_index]
						incr list_index

					}
					foreach field {addr_street_1 addr_street_2 addr_street_3 addr_street_4 addr_city addr_country addr_postcode} {

						append FILE_LINE($displine,address) [lindex $line_list $list_index]
						if {$list_index != 9} {
							append FILE_LINE($displine,address) ","
						}
						incr list_index

					}
				} else {
					set FILE_LINE($displine,voucher) $line
				}
				incr displine
			}
		}

		if {$fileline > $toline} {

			# we've finished the section we want to display
			# so close the file and exit to save time
			break
		}
	}
	close $DISPLAY_FILE

	tpSetVar num_file_lines $displine
	tpBindString numlines $displine
	if {$vouchertype != "INCEN"} {
		foreach field {lineno custid voucher acct_no email address} {
			tpBindVar $field FILE_LINE $field line_idx
		}
	} else {
		foreach field {lineno voucher} {
			tpBindVar $field FILE_LINE $field line_idx
		}
	}
	asPlayFile -nocache voucher_file.html

	if {[info exists FILE_LINE]} {
		unset FILE_LINE
	}
}

########################################################################
## Encrypts the voucher string using the blowfish key from the cfg file
########################################################################
proc voucher_encrypt {voucher_id voucher_key} {

	if {[string length $voucher_id] != 8} {
		return ""
   }

	if {[string length $voucher_key] != 8} {
		return ""
   }

	set enc_voucher_id [blowfish encrypt -hex $voucher_key -bin $voucher_id]

	return $enc_voucher_id
}

#######################################################################
## Generates the unique voucher code by creating a voucher string and
## passing it on to be excrypted. Returns the actual code to be entered
## by the customer.
#######################################################################
proc generate_voucher {cust_id} {

	global DB
	global VOUCHER
	global VOUCH_STMT

	# need to create a random voucher key to put in the db and use to encrypt the voucher
	# number will be an 8 digit hex number for use with blowfish encryption

	set voucher_key ""

	for {set i 0} {$i < 8} {incr i} {

		set random_float    [expr {rand()}]
		set random_float    [expr {($random_float * 1000) / 66}]
		set random_int      [expr {round($random_float)}]
		set random_hex      [format "%x" $random_int]

		append voucher_key $random_hex

	}

	# insert a new voucher into tVoucher returning the voucher id

	if {![info exists VOUCH_STMT]} {
		set sql {
			execute procedure pInsVoucher(
				p_voucher_key = ?,
				p_type_code = ?,
				p_voucher_run_id = ?,
				p_cust_id = ?,
				p_trigger_id = ?,
				p_valid_from = ?,
				p_valid_to = ?
			)
		}
		set VOUCH_STMT [inf_prep_sql $DB $sql]
	}

	set c [catch {
		set rs [inf_exec_stmt   $VOUCH_STMT\
								$voucher_key\
								$VOUCHER(voucher_type)\
								$VOUCHER(voucher_run_id)\
								$cust_id\
								$VOUCHER(trigger_id)\
								$VOUCHER(valid_from)\
								$VOUCHER(valid_to)]
	} msg]

	if {$c} {
		OT_LogWrite 3 "Failed to create voucher $msg"
		err_bind $msg
		return
	}

	# get the voucher id from the result set

	set voucher_id [db_get_coln $rs 0 0]

	# now need to pad the voucher id with zeros before encryption
	# this will make sure all voucher are the same length
	# zeros will be stripped during validation when voucher is redeemed

	set voucher_id [format "%08s" $voucher_id]

	set enc_voucher_id [voucher_encrypt $voucher_id $voucher_key]

	# now need to format the voucher into 6 groups of 4 digits, separated by '-'s
	# this is the format in which the codes will be presented to the customer
	set raw_voucher [string toupper "$voucher_id$enc_voucher_id"]

	set r {^(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})$}

	if {[regexp $r $raw_voucher a p1 p2 p3 p4 p5 p6]} {
		set voucher "${p1}-${p2}-${p3}-${p4}-${p5}-${p6}"
	} else {
		OT_LogWrite 2 "bad voucher $raw_voucher"
		set voucher ""
		return
	}

	return $voucher

}

proc go_netballs_dd {} {
	global BET_DD

	set id 0

	foreach {bet_level name} [OT_CfgGet NETBALLS_REDEMPTION_TYPES ""] {
		OT_LogWrite 15 "MRP: $id"
		OT_LogWrite 15 "MRP: $bet_level"
		OT_LogWrite 15 "MRP: $name"

		set BET_DD($id,key) $id
		set BET_DD($id,bet_level) $bet_level
		set BET_DD($id,name) $name
		incr id
	}

	tpSetVar dd_rows $id
	tpBindVar key         BET_DD key dd_idx
	tpBindVar name        BET_DD name       dd_idx
	tpBindVar bet_level   BET_DD bet_level  dd_idx

	tpSetVar show_link 0

	asPlayFile -nocache fbet_dd.html
}

# close namespace
}
