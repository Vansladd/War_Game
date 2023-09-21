# ==============================================================
# $Id: order.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999,2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::ORDER {

asSetAct ADMIN::ORDER::GoOrderQuery   	[namespace code go_order_query]
asSetAct ADMIN::ORDER::DoOrderQuery   	[namespace code do_order_query]
asSetAct ADMIN::ORDER::go_order_dd  	[namespace code get_order_classes]
asSetAct ADMIN::ORDER::go_order_types   [namespace code go_order_types]
asSetAct ADMIN::ORDER::go_order_events  [namespace code go_order_events]
asSetAct ADMIN::ORDER::go_order_markets [namespace code go_order_markets]
asSetAct ADMIN::ORDER::go_order_selns   [namespace code go_order_selns]
asSetAct ADMIN::ORDER::GoOrderReceipt  	[namespace code go_order_receipt]
asSetAct ADMIN::ORDER::DoCancelOrder	[namespace code do_cancel_order]


#
# ----------------------------------------------------------------------------
# Generate order selection criteria
# ----------------------------------------------------------------------------
#
proc go_order_query {} {

	#Removed call to get_mkt_events query, as this is not used by the template

	asPlayFile -nocache order_query.html
}

proc do_order_query {} {
	global DB ORDER

	set where [list]
	#
	# Customer fields
	#
	if {[string length [set name [reqGetArg Customer]]] > 0} {
		if {[reqGetArg UpperCust] == "Y"} {
			lappend where "[upper_q c.username] like [upper_q '${name}%']"
		} else {
			lappend where "c.username like \"${name}%\""
		}
	}
	if {[string length [set fname [reqGetArg FName]]] > 0} {
		lappend where "[upper_q r.fname] = [upper_q '$fname']"
	}
	if {[string length [set lname [reqGetArg LName]]] > 0} {
		lappend where "[upper_q r.lname] = [upper_q '$lname']"
	}
	if {[string length [set email [reqGetArg Email]]] > 0} {
		lappend where "upper(r.email) like upper('%${email}%')"
	}
	if {[string length [set acctno [reqGetArg AcctNo]]] > 0} {
		lappend where "c.acct_no = '$acctno'"
	}

	#
	# Order date fields:
	#
	set od1 [reqGetArg OrderDate1]
	set od2 [reqGetArg OrderDate2]

	if {([string length $od1] > 0) || ([string length $od2] > 0)} {
		lappend where [mk_between_clause d.cr_date date $od1 $od2]
	}

	#
	# Order stake
	#
	set s1 [reqGetArg Stake1]
	set s2 [reqGetArg Stake2]

	if {([string length $s1] > 0) || ([string length $s2] > 0)} {
		lappend where [mk_between_clause d.stake number $s1 $s2]
	}

	#
	# Settlement date
	#
	set sd1 [reqGetArg StlDate1]
	set sd2 [reqGetArg StlDate2]

	if {([string length $sd1] > 0) || ([string length $sd2] > 0)} {
		lappend where [mk_between_clause b.settled_at date $sd1 $sd2]
	}

	#
	# Winnings
	#
	set w1 [reqGetArg Wins1]
	set w2 [reqGetArg Wins2]

	if {([string length $w1] > 0) || ([string length $w2] > 0)} {
		lappend where [mk_between_clause b.winnings number $w1 $w2]
	}


	#
	# Order Settled
	#
	if {[string length [set settled [reqGetArg Settled]]] > 0} {
		lappend where "b.settled = '$settled'"
	}

	#
	# Order Matched
	#
	if {[string length [set matched [reqGetArg Matched]]] > 0} {
		if {$matched =="M"} {
			lappend where "b.stake = d.stake"
		} elseif {$matched =="P"} {
			lappend where "b.stake < d.stake and b.stake > 0 "
		} elseif {$matched =="U"} {
			lappend where "b.stake = 0 and  d.stake > 0"
		}
	}

	#
	# Selection: build up selection query
	#
	foreach a {classid type eventid market level key} {
		set $a [reqGetArg $a]
	}

	if {$classid > 0} {
		lappend where "t.ev_class_id = $classid"
	}

	if {$type > 0} {
		lappend where "g.ev_type_id = $type"
	}

	if {$eventid > 0} {
		lappend where "s.ev_id = $eventid"
	}

	if {$market > 0} {
		lappend where "s.ev_mkt_id = $market"
	}

	if {$level == "SELECTION"} {
		lappend where "s.ev_oc_id = $key"
	}

	#
	# Don't run a query with no search criteria...
	#
	if {![llength $where]} {
		# Nothing selected
		err_bind "Please enter some search criteria"
		go_order_query
		return
	}

	set where_auth     [concat and [join $where " and "]]

	set sql [subst {
			select
				c.cust_id,
				c.username,
				a.ccy_code,
				d.cr_date,
				b.receipt,
				b.stake as matched_stake,
				d.stake,
				b.settled,
				b.winnings,
				b.refund,
				b.num_lines,
				b.bet_type,
				b.leg_type,
				e.desc ev_name,
				g.name mkt_name,
				s.desc seln_name,
				s.result,
				s.ev_mkt_id,
				s.ev_oc_id,
				s.ev_id,
				o.bet_id,
				o.leg_no,
				o.part_no,
				o.leg_sort,
				o.price_type,
				o.o_num,
				o.o_den
			from
				tBet 		b,
				tOrder 		d,
				tOBet 		o,
				tAcct 		a,
				tCustomer 	c,
				tEvOc 		s,
				tEvMkt 		m,
				tEvOcGrp 	g,
				tEv 		e,
				tCustomerReg r,
				tEvType   	t
			where
				b.bet_id 	= o.bet_id and
				b.acct_id 	= a.acct_id and
				b.bet_id 	= d.bet_id and
				a.cust_id 	= c.cust_id and
				r.cust_id 	= c.cust_id and
				o.ev_oc_id 	= s.ev_oc_id and
				s.ev_mkt_id = m.ev_mkt_id and
				m.ev_oc_grp_id = g.ev_oc_grp_id and
				s.ev_id 	= e.ev_id and
				t.ev_type_id = e.ev_type_id	and
				t.ev_type_id = g.ev_type_id
				$where_auth
			order by
				o.bet_id desc,o.leg_no asc,o.part_no asc
			}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	# play
	if {$rows == 1} {
		go_order_receipt bet_id [db_get_col $res 0 bet_id]

		db_close $res
		return
	}

	bind_order_list $res

	asPlayFile -nocache order_list.html

}


##
#  Returns a result set containing everything
#
#  The result set should be closed after use
##
proc get_mkt_events {} {
	global DB

	set sql [subst {
 	select distinct
   	 	t.ev_type_id,
		e.ev_id,
		e.desc as event_name
	from
		tEvClass  	c,
		tEvType   	t,
		tEv 		e,
		tEvMkt 		m,
		tEvCategory cat,
		tEvOcGrp  	g,
		outer tEvOc o,
		outer tBlurbxlate x
	where
		t.ev_class_id   = c.ev_class_id and
		x.ref_id        = c.ev_class_id and
 		t.ev_type_id    = e.ev_type_id	and
		t.ev_type_id    = g.ev_type_id	and
 		e.ev_id         = m.ev_id		and
		o.ev_id         = e.ev_id		and
		o.ev_mkt_id     = m.ev_mkt_id	and
		g.ev_oc_grp_id  = m.ev_oc_grp_id and
		x.ref_id        = t.ev_type_id	and
		(x.sort = 'CLASS' or x.sort = 'TYPE' or x.sort = 'MARKET') and
		c.displayed     = 'Y'			and
		t.displayed     = 'Y'			and
		e.displayed     = 'Y'			and
 		m.displayed     = 'Y'			and
		o.displayed     = 'Y'			and
		c.channels      like "%P%"		and
		t.channels      like "%P%"		and
 		e.channels      like "%P%"		and
   		m.channels      like "%P%"		and
		g.channels      like "%P%"		and
		o.channels      like "%P%"		and
 		e.start_time > current - interval(90) minute to minute and
   		e.result_conf   = "N"			and
		x.lang          = "en"
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

  	return $rs
}

# ----------------------------------------------------------------------------
# Create appropriate bindings for order list
# ----------------------------------------------------------------------------
#
proc bind_order_list {res} {

	global ORDER

	set rows [db_get_nrows $res]

	set cur_id 0
	set b -1

	array set ORDER [list]

	for {set r 0} {$r < $rows} {incr r} {

		set bet_id [db_get_col $res $r bet_id]

		if {$bet_id != $cur_id} {
			set cur_id $bet_id
			set l 0
			incr b
			set ORDER($b,num_selns) 0
		}
		incr ORDER($b,num_selns)

		if {$l == 0} {
			set ORDER($b,bet_id) $bet_id
			set ORDER($b,receipt)   [db_get_col $res $r receipt]
			set ORDER($b,bet_time)  [db_get_col $res $r cr_date]
			set ORDER($b,bet_type)  [db_get_col $res $r bet_type]
			set ORDER($b,stake)     [db_get_col $res $r stake]
			set ORDER($b,matched_stake) [db_get_col $res $r matched_stake]
			set ORDER($b,ccy)       [db_get_col $res $r ccy_code]
			set ORDER($b,cust_id)   [db_get_col $res $r cust_id]
			set ORDER($b,cust_name) [db_get_col $res $r username]
			set ORDER($b,settled)   [db_get_col $res $r settled]
			set ORDER($b,winnings)  [db_get_col $res $r winnings]
			set ORDER($b,refund)    [db_get_col $res $r refund]
		}
		set price_type          [db_get_col $res $r price_type]
		if {$price_type == "L" || $price_type == "S"} {
			set o_num [db_get_col $res $r o_num]
			set o_den [db_get_col $res $r o_den]
			set p_str [mk_price $o_num $o_den]
			if {$p_str == ""} {
				set p_str "SP"
			}
		} else {
			set p_str "DIV"
		}
		set ORDER($b,$l,price)    $p_str
		set ORDER($b,$l,event)    [db_get_col $res $r ev_name]
		set ORDER($b,$l,mkt)      [db_get_col $res $r mkt_name]
		set ORDER($b,$l,seln)     [db_get_col $res $r seln_name]
		set ORDER($b,$l,result)   [db_get_col $res $r result]
		set ORDER($b,$l,ev_id)    [db_get_col $res $r ev_id]
		set ORDER($b,$l,ev_mkt_id) \
							    [db_get_col $res $r ev_mkt_id]
		set ORDER($b,$l,ev_oc_id) \
								[db_get_col $res $r ev_oc_id]
		incr l
	}

	tpSetVar NumOrders [expr {$b+1}]
	tpBindVar CustId      	ORDER cust_id   idx
	tpBindVar CustName    	ORDER cust_name idx
	tpBindVar OrderId       ORDER bet_id    idx
	tpBindVar OrderReceipt  ORDER receipt   idx
	tpBindVar OrderTime     ORDER bet_time  idx
	tpBindVar OrderSettled  ORDER settled   idx
	tpBindVar OrderType     ORDER bet_type  idx
	tpBindVar OrderStake    ORDER stake     idx
	tpBindVar BetStake		ORDER matched_stake idx
	tpBindVar Winnings    	ORDER winnings  idx
	tpBindVar Refund      	ORDER refund    idx
	tpBindVar BetLegNo    	ORDER leg_no    idx seln_idx
	tpBindVar BetLegSort  	ORDER leg_sort  idx seln_idx
	tpBindVar EvDesc      	ORDER event     idx seln_idx
	tpBindVar MktDesc     	ORDER mkt       idx seln_idx
	tpBindVar SelnDesc    	ORDER seln      idx seln_idx
	tpBindVar Price       	ORDER price     idx seln_idx
	tpBindVar Result      	ORDER result    idx seln_idx
	tpBindVar EvId        	ORDER ev_id     idx seln_idx
	tpBindVar EvMktId     	ORDER ev_mkt_id idx seln_idx
	tpBindVar EvOcId      	ORDER ev_oc_id  idx seln_idx
}

#
# Generate class list
#
proc get_order_classes {} {
	global DB

	set sql {
		select
			c.ev_class_id,
			c.name as class_name,
			c.disporder,
			c.channels
		from
			tEvClass c
		where c.channels like "%P%"
		order by
			c.disporder
	}

	set stmt [inf_prep_sql $DB [subst $sql]]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]

	tpSetVar show_link 1

	tpBindTcl id   "sb_res_data $rs dd_idx ev_class_id"
	tpBindTcl key  "sb_res_data $rs dd_idx ev_class_id"
	tpBindTcl name "sb_res_data $rs dd_idx class_name"

	tpBindString level   CLASS
	tpBindString title   Classes
	tpBindString link_action go_order_types

	asPlayFile -nocache order_dd.html

	db_close $rs
}


#
# show types and coupons
#
proc go_order_types {} {
	global DB

	set sql {
		select distinct
			'T' as type,
			'T' || t.ev_type_id as key,
			t.ev_type_id as id,
			t.name       as name,
			t.disporder
		from
			tevclass  c,
			tevtype   t,
			tev       e
		where
			c.ev_class_id   = ?
		and c.ev_class_id   = t.ev_class_id
		and t.ev_type_id    = e.ev_type_id
		and e.start_time    > current - interval(7) day to day
		and e.result_conf   = 'N'
		and c.channels like "%P%"
		and e.channels like "%P%"
		and t.channels like "%P%"

		union all

		select distinct
			'C' as type,
			'C' || u.coupon_id as key,
			u.coupon_id as id,
			u.desc      as name,
			0
		from
			tevclass   c,
			tevtype    t,
			tcoupon    u,
			tcouponmkt cm,
			tev        e,
			tevmkt     m
		where
			c.ev_class_id   = ?
		and t.ev_class_id   = c.ev_class_id
		and t.ev_type_id    = e.ev_type_id
		and e.ev_id         = m.ev_id
		and u.ev_class_id   = c.ev_class_id
		and u.coupon_id     = cm.coupon_id
		and cm.ev_mkt_id    = m.ev_mkt_id
		and e.start_time    > current - interval(7) day to day
		and e.result_conf   = 'N'
		and c.channels like "%P%"
		and t.channels like "%P%"
		and u.channels like "%P%"
		and e.channels like "%P%"
		and m.channels like "%P%"
		order by 5
	}

	set class [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $class $class]
	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]

	tpBindTcl id     "sb_res_data $rs dd_idx id"
	tpBindTcl key    "sb_res_data $rs dd_idx key"
	tpBindTcl name   "sb_res_data $rs dd_idx name"
	tpBindTcl level  "ADMIN::ORDER::print_level $rs dd_idx type"

	tpBindString link_action go_order_events

	tpBindString title "Types/Coupons"
	tpBindString class_id $class

	asPlayFile -nocache order_dd.html

	db_close $rs
}

#
# show Events
#
proc go_order_events {} {
	global DB

	set sql {
		select
			c.ev_class_id,
			e.ev_id,
			e.desc as event_name,
			e.start_time,
			e.disporder as ev_disporder
		from
			tEvClass    c,
			tEvType     t,
			tEv         e
		where
			t.ev_class_id   = c.ev_class_id
		and t.ev_type_id    = e.ev_type_id
		and t.ev_type_id    = ?
		and t.ev_type_id    = e.ev_type_id
		and e.start_time    > current - interval(7) day to day
		and e.result_conf   = 'N'
		and e.channels like "%P%"
		and t.channels like "%P%"
		order by
			e.start_time,
			e.disporder
	}

	set type [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $type]
	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 1
	tpBindTcl id   "sb_res_data $rs dd_idx ev_id"
	tpBindTcl key  "sb_res_data $rs dd_idx ev_id"
	tpBindTcl name "sb_res_data $rs dd_idx event_name"

	tpBindString level   EVENT
	tpBindString title   Events

	set class [db_get_col $rs 0 ev_class_id]
	tpBindString class_id $class
	tpBindString type_id $type

	tpBindString link_action go_order_markets

	asPlayFile -nocache order_dd.html

	db_close $rs
}

#
# show markets
#
proc go_order_markets {} {

	global DB

	set sql {
		select distinct
			t.ev_class_id,
			t.ev_type_id,
			e.ev_id,
			m.ev_mkt_id,
			g.name as mkt_name,
			g.disporder
		from
			tEvClass    c,
			tEvType     t,
			tEv         e,
			tEvMkt      m,
			tEvOcGrp    g
		where
			t.ev_class_id   = c.ev_class_id
		and t.ev_type_id    = e.ev_type_id
		and e.ev_id         = ?
		and m.ev_id         = e.ev_id
		and m.ev_oc_grp_id  = g.ev_oc_grp_id
		and t.ev_type_id    = g.ev_type_id
		and e.start_time    > current - interval(7) day to day
		and e.result_conf   = 'N'
		and c.channels like "%P%"
		and t.channels like "%P%"
		and e.channels like "%P%"
		and m.channels like "%P%"
		order by
			g.disporder
	}

	set event [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $event]
	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 1
	tpBindTcl id   "sb_res_data $rs dd_idx ev_mkt_id"
	tpBindTcl key  "sb_res_data $rs dd_idx ev_mkt_id"
	tpBindTcl name "sb_res_data $rs dd_idx mkt_name"

	tpBindString class_id 	[db_get_col $rs 0 ev_class_id]
	tpBindString type_id 	[db_get_col $rs 0 ev_type_id]
	tpBindString event_id 	[db_get_col $rs 0 ev_id]

	tpBindString level   MARKET
	tpBindString title   Markets
	tpBindString link_action go_order_selns
	asPlayFile -nocache order_dd.html

	db_close $rs
}


#
# show selections
#
proc go_order_selns {} {

	global DB

	set sql {
		select distinct
			o.ev_mkt_id,
			t.ev_class_id,
			t.ev_type_id,
			m.ev_id ,
			o.ev_oc_id,
			o.desc,
			o.disporder
		from
			tEvOc  o,
			tEvClass    c,
			tEvType     t,
			tEv         e,
			tEvMkt      m,
			tEvOcGrp    g
		where
			o.ev_mkt_id = ?
			and o.ev_mkt_id 	= m.ev_mkt_id
			and t.ev_class_id   = c.ev_class_id
			and t.ev_type_id    = e.ev_type_id
			and m.ev_id         = e.ev_id
			and m.ev_oc_grp_id  = g.ev_oc_grp_id
			and t.ev_type_id    = g.ev_type_id
			and e.start_time    > current - interval(7) day to day
			and e.result_conf   = 'N'
			and c.channels like "%P%"
			and t.channels like "%P%"
			and e.channels like "%P%"
			and m.channels like "%P%"
			and o.channels like "%P%"
		order by
			o.disporder
	}

	set mkt  [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $mkt]
	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 0
	tpBindTcl id   "sb_res_data $rs dd_idx ev_oc_id"
	tpBindTcl key  "sb_res_data $rs dd_idx ev_oc_id"
	tpBindTcl name "sb_res_data $rs dd_idx desc"

	tpBindString class_id 	[db_get_col $rs 0 ev_class_id]
	tpBindString type_id 	[db_get_col $rs 0 ev_type_id]
	tpBindString event_id 	[db_get_col $rs 0 ev_id]
	tpBindString market_id	[db_get_col $rs 0 ev_mkt_id]

	tpBindString level   SELECTION
	tpBindString title   Selections

	asPlayFile -nocache order_dd.html

	db_close $rs
}

proc print_level {rs row col} {
	if {[db_get_col $rs [tpGetVar $row] type] == "T"} {
		tpSetVar show_link 1
		tpBufWrite TYPE
	} else {
		tpSetVar show_link 0
		tpBufWrite COUPON
	}
}

#
# ----------------------------------------------------------------------------
# Order receipt
# ----------------------------------------------------------------------------
#
proc go_order_receipt args {

	global DB BET

	catch {unset BET}

	set bet_id [reqGetArg BetId]

	foreach {n v} $args {
		set $n $v
	}

	set sql_m [subst {
		select
			b.bet_id,
			b.cr_date,
			b.bet_type,
			b.acct_id,
			o.order_id,
			o.stake as order_stake,
			o.commission_rate,
			o.commission,
			o.polarity,
			o.expired,
			o.expire_at,
			o.send_email,
			a.ccy_code,
			c.cust_id,
			c.username,
			c.acct_no,
			c.lang,
			b.stake,
			b.tax_type,
			b.tax,
			b.stake_per_line,
			b.max_payout,
			b.tax_rate,
			b.num_selns,
			b.num_legs,
			b.leg_type,
			b.num_lines,
			b.receipt,
			b.settled,
			b.settled_at,
			NVL(b.settled_how,"-") settled_how,
			b.settle_info,
			b.user_id,
			m.username admin_user,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			b.winnings,
			b.refund,
			p.cr_date parked_date,
			p.num_lines_win p_num_lines_win,
			p.num_lines_lose p_num_lines_lose,
			p.num_lines_void p_num_lines_void,
			p.winnings p_winnings,
			p.refund p_refund,
			p.tax p_tax
		from
			tBet b,
			tOrder o,
			tAcct a,
			tCustomer c,
			outer tBetStlPending p,
			outer tAdminUser m
		where
			b.bet_id = ? and
			b.bet_id = o.bet_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			b.bet_id = p.bet_id and
			b.user_id = m.user_id
	}]

	set stmt [inf_prep_sql $DB $sql_m]
	set res  [inf_exec_stmt $stmt $bet_id]
	inf_close_stmt $stmt

	set parked_date [db_get_col $res 0 parked_date]
	set tax_type    [db_get_col $res 0 tax_type]
	set tax_rate    [db_get_col $res 0 tax_rate]

	tpSetVar TaxType [expr {$tax_rate == 0.0 ? "-" : $tax_type}]

	tpBindString BetId      $bet_id
	tpBindString CustId     [db_get_col $res 0 cust_id]
	tpBindString AcctNo     [db_get_col $res 0 acct_no]
	tpBindString Username   [db_get_col $res 0 username]
	tpBindString BetType    [db_get_col $res 0 bet_type]
	tpBindString LegType    [db_get_col $res 0 leg_type]
	tpBindString NumLines   [db_get_col $res 0 num_lines]
	tpBindString BetDate    [db_get_col $res 0 cr_date]
	tpBindString ccyCode    [db_get_col $res 0 ccy_code]
	tpBindString Stake      [db_get_col $res 0 stake]
	tpBindString StakePerLine [db_get_col $res 0 stake_per_line]
	tpBindString TaxInfo    [db_get_col $res 0 tax]
	tpBindString TaxRate    $tax_rate
	tpBindString TaxType    $tax_type
	tpBindString Receipt    [db_get_col $res 0 receipt]
	tpBindString MaxPayout  [db_get_col $res 0 max_payout]
	tpBindString OrderId	[db_get_col $res 0 order_id]
	tpBindString OrderStake	[db_get_col $res 0 order_stake]
	tpBindString CommissionRate [db_get_col $res 0 commission_rate]
	tpBindString Commission	[db_get_col $res 0 commission]

	if {[db_get_col $res 0 polarity]=="F"} {
		tpBindString Polarity 	"For"
	} else {
		tpBindString Polarity 	"Against"
	}

	if {[db_get_col $res 0 expired] =="N"} {
		tpBindString Expired	"No"
	} else {
		tpBindString Expired	"Yes"
	}

	tpBindString Expire_at	[db_get_col $res 0 expire_at]

	if {[db_get_col $res 0 send_email]	 =="N"} {
		tpBindString SendMail	"No"
	} else {
		tpBindString SendMail	"Yes"
	}
	set filled	[format %0.0f [expr "100.00*[db_get_col $res 0 stake]/[db_get_col $res 0 order_stake]"]]
	tpBindString Filled $filled

	if {[db_get_col $res 0 settled] == "Y"} {
		tpSetVar settled YES
		tpBindString SettledAt    [db_get_col $res 0 settled_at]
		tpBindString SettleInfo   [db_get_col $res 0 settle_info]
		tpBindString SettledBy    [db_get_col $res 0 admin_user]
		tpBindString SettledHow   [db_get_col $res 0 settled_how]
		tpBindString Winnings     [db_get_col $res 0 winnings]
		tpBindString Refunds      [db_get_col $res 0 refund]
		tpBindString NumLinesWin  [db_get_col $res 0 num_lines_win]
		tpBindString NumLinesLose [db_get_col $res 0 num_lines_lose]
		tpBindString NumLinesVoid [db_get_col $res 0 num_lines_void]
	} elseif {$parked_date != ""} {
		tpSetVar settled PENDING
		tpBindString P_Winnings     [db_get_col $res 0 p_winnings]
		tpBindString P_Refund       [db_get_col $res 0 p_refund]
		tpBindString P_NumLinesWin  [db_get_col $res 0 p_num_lines_win]
		tpBindString P_NumLinesLose [db_get_col $res 0 p_num_lines_lose]
		tpBindString P_NumLinesVoid [db_get_col $res 0 p_num_lines_void]
		tpBindString P_Tax          [db_get_col $res 0 p_tax]
	} else {
		tpSetVar settled NO
	}

	set num_legs [db_get_col $res 0 num_legs]

	tpSetVar num_legs $num_legs

	db_close $res

	set sql_d [subst {
		select
			o.bet_id,
			o.leg_no-1 leg_no,
			o.part_no-1 part_no,
			o.leg_sort,
			o.ev_oc_id,
			o.o_num,
			o.o_den,
			o.price_type,
			NVL(o.ew_fac_num,m.ew_fac_num) ew_fac_num,
			NVL(o.ew_fac_den,m.ew_fac_den) ew_fac_den,
			NVL(o.ew_places,m.ew_places)   ew_places,
			o.hcap_value,
			g.name,
			case
				when e.result_conf='Y' or s.result_conf='Y'
				then s.result else '-'
			end result,
			s.place,
			s.ev_oc_id ev_oc_id,
			s.desc seln_desc,
			s.lp_num,
			s.lp_den,
			s.sp_num,
			s.sp_den,
			s.fb_side,
			g.name mkt_name,
			m.ev_mkt_id,
			m.sort mkt_sort,
			m.hcap_makeup,
			e.desc ev_desc,
			e.ev_id ev_id,
			e.start_time,
			t.name type_name,
			c.name class_name
		from
			tOBet o,
			tEvOc s,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tEvType t,
			tEvClass c
		where
			o.bet_id = ? and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			s.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id
		order by
			2 asc,
			3 asc
	}]

	set stmt [inf_prep_sql $DB $sql_d]
	set res  [inf_exec_stmt $stmt $bet_id]
	inf_close_stmt $stmt

	set cur_leg_no -1

	array set BET [list]

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {

		set leg_no  [db_get_col $res $r leg_no]
		set part_no [db_get_col $res $r part_no]

		if {$leg_no != $cur_leg_no} {

			set cur_leg_no $leg_no

			set BET($leg_no,leg_sort)   [db_get_col $res $r leg_sort]
			set BET($leg_no,class)      [db_get_col $res $r class_name]
			set BET($leg_no,type)       [db_get_col $res $r type_name]
			set BET($leg_no,ev_id)      [db_get_col $res $r ev_id]
			set BET($leg_no,event)      [db_get_col $res $r ev_desc]
			set BET($leg_no,start_time) [db_get_col $res $r start_time]
			set BET($leg_no,ev_mkt_id)  [db_get_col $res $r ev_mkt_id]
			set BET($leg_no,market)     [db_get_col $res $r mkt_name]
			set BET($leg_no,mkt_sort)   [db_get_col $res $r mkt_sort]
		}

		set BET($leg_no,num_parts) [expr {$part_no+1}]

		set BET($leg_no,$part_no,ev_oc_id) [db_get_col $res $r ev_oc_id]
		set BET($leg_no,$part_no,seln)     [db_get_col $res $r seln_desc]

		set o_pt  [db_get_col $res $r price_type]

		if {$o_pt == "L"} {
			set o_num [db_get_col $res $r o_num]
			set o_den [db_get_col $res $r o_den]
			set price [mk_price $o_num $o_den]

			set mkt_sort $BET($leg_no,mkt_sort)

			if {$mkt_sort == "AH" || $mkt_sort == "WH"} {

				set fb_side    [db_get_col $res $r fb_side]
				set hcap_value [db_get_col $res $r hcap_value]

				set hcap_str [mk_hcap_str $mkt_sort $fb_side $hcap_value]

				append price " \[$hcap_str\]"
			}
		} elseif {$o_pt == "S"} {
			set price SP
		} elseif {$o_pt == "D"} {
			set price DIV
		} elseif {$o_pt == "B"} {
			set price BP
		} elseif {$o_pt == "N"} {
			set price NP
		} elseif {$o_pt == "1"} {
			set price FS
		} elseif {$o_pt == "2"} {
			set price SS
		} else {
			set price "???"
		}

		set BET($leg_no,$part_no,price) $price

		set result [db_get_col $res $r result]
		set place  [db_get_col $res $r place]
		set sp_num [db_get_col $res $r sp_num]
		set sp_den [db_get_col $res $r sp_den]

		if {$place != ""} {
			append result " (place $place)"
		}
		if {$sp_num != ""} {
			set sp [mk_price $sp_num $sp_den]
			append result " (SP=$sp)"
		}

		set BET($leg_no,$part_no,result) $result
	}

	tpBindVar EventClass  BET class      leg_idx
	tpBindVar EventType   BET type       leg_idx
	tpBindVar EventStart  BET start_time leg_idx
	tpBindVar EventName   BET event      leg_idx
	tpBindVar EventId     BET ev_id      leg_idx
	tpBindVar LegSort     BET leg_sort   leg_idx
	tpBindVar MarketName  BET market     leg_idx
	tpBindVar MarketId    BET ev_mkt_id  leg_idx
	tpBindVar SelnId      BET ev_oc_id   leg_idx part_idx
	tpBindVar SelnName    BET seln       leg_idx part_idx
	tpBindVar SelnResult  BET result     leg_idx part_idx
	tpBindVar SelnPrice   BET price      leg_idx part_idx

	asPlayFile -nocache order_receipt.html

	db_close $res

	unset BET
}

#
# ----------------------------------------------------------------------------
# Cancel Order
# ----------------------------------------------------------------------------
#
proc do_cancel_order {} {

	if {![op_allowed VoidBet]} {
		err_bind "You don't have permission to cancel orders"
		return
	}

 	set order_id [reqGetArg OrderId]
	set Receipt	 [reqGetArg Receipt]
	# call tMsgQueue
	set sql [subst {
		execute procedure pCancelOrder( p_order_id = ? )
	}]

	set stmt [inf_prep_sql $DB $sql]

	# Send a message to the BMS
	if {[catch {set res [inf_exec_stmt $stmt $order_id]} msg]} {
			set bad 1
			err_bind $msg
	}
	inf_close_stmt $stmt

	tpBindString result "Your request to cancel this order is being processed and your account details will be updated shortly."
	tpBindString order_id $order_id
	tpBindString Receipt $Receipt

	asPlayFile -nocache order_cancel.html

}




}
