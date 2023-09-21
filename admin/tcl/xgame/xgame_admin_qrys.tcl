# $Id: xgame_admin_qrys.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $


proc populate_xgame_admin_queries args {

	global xgaQry

    set xgaQry(get_bet_types) {
         select
            bet_type
         from
            txgamebettype
         where
            txgamebettype.num_selns <= ?
    }

    set xgaQry(get_bet_types_detail) {
         select
            bet_type,
            stl_sort,
            bet_name,
            bet_settlement,
            num_selns,
            num_bets_per_seln,
            num_lines,
            min_combi,
            max_combi,
            min_bet,
            max_bet,
            max_losers,
            disporder,
            status,
            channels,
            blurb
         from
            txgamebettype
         where
            bet_type=?
    }

    set xgaQry(insert_min_max) {
        insert into txgameminmax (
            bet_type,
            sort,
            min_bet,
            max_bet
        ) values (?, ?, ?, ?)
    }

    set xgaQry(get_min_max) {
         select
            bet_type,
            sort,
            min_bet,
            max_bet
         from
            txgameminmax
         where
            sort=?
         and
            bet_type=?
    }

    set xgaQry(remove_all_min_max) {
        delete from
            txgameminmax
        where
            sort=?
    }

    set xgaQry(get_drawdescs_for_sort) {
        select
            desc_id,
            sort,
            name,
            desc,
            default_draw_at,
            default_shut_at,
            status,
            day,
			channels,
			shut_day
        from
            tXGameDrawDesc
        where
            sort =?
    }

	set xgaQry(get_drawdescs_for_id) {
        select
            desc_id,
            sort,
            name,
            desc,
            default_draw_at,
            default_shut_at,
            status,
            day,
			channels
        from
            tXGameDrawDesc
        where
            desc_id =?
    }

    set xgaQry(insert_drawdesc) {
        insert into tXGameDrawDesc(
            sort,
            name,
            desc,
            default_draw_at,
            default_shut_at,
            status,
            day,
			shut_day
        ) values (?, ?, ?, ?, ?, ?, ?, ?)
    }

	set xgaQry(edit_drawdesc) {
        update tXGameDrawDesc set
			name =?,
            desc =?,
            default_draw_at =?,
            default_shut_at =?,
            status =?,
            day =?
		where
			desc_id=?
    }

	set xgaQry(edit_drawdesc_channels) {
        update tXGameDrawDesc set
			channels =?
		where
			desc_id=?
    }

    set xgaQry(delete_drawdesc) {
        delete from
            tXGameDrawDesc
        where
            desc_id=?
    }

    set xgaQry(get_gamedef) {
        select
            sort,
            name,
            num_picks_max,
            num_picks_min,
            num_results_max,
            num_results_min,
            conf_needed,
            external_settle,
            has_balls,
            num_min,
            num_max,
            single_bet_alarm,
            desc,
            min_stake,
            max_stake,
            min_subs,
            max_subs,
            stake_mode,
            max_card_payout,
            cheque_payout_msg,
            max_payout,
            channels,
            xgame_attr,
            coupon_max_lines,
            max_selns,
            game_type,
            result_url,
			rules_url,
			flag_gif,
            disp_order
        from
            txgamedef
        where
            sort = ?
    }

    set xgaQry(edit_gamedef) {
        update
            txgamedef
        set
            name=?,
            num_picks_max=?,
            num_picks_min=?,
            num_results_max=?,
            num_results_min=?,
            num_min=?,
            num_max=?,
            desc=?,
            min_stake=?,
            max_stake=?,
            stake_mode=?,
            max_payout=?,
            coupon_max_lines=?,
            external_settle=?,
            max_selns=?,
            game_type=?,
            result_url=?,
			rules_url=?,
			flag_gif=?,
            min_subs=?,
            max_subs = ?,
            disp_order = ?
        where
            sort=?
    }

    set xgaQry(insert_gamedef) {
        insert into txgamedef(
            name,
            num_picks_max,
            num_picks_min,
            num_results_max,
            num_results_min,
            num_min,
            num_max,
            desc,
            min_stake,
            max_stake,
            stake_mode,
            max_payout,
            coupon_max_lines,
            sort,
            conf_needed,
            external_settle,
            has_balls,
            max_selns,
            game_type,
            result_url,
			rules_url,
			flag_gif,
            min_subs,
            max_subs,
            disp_order
        ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    }

    set xgaQry(get_max_min_picks) {
        select
            num_picks_min,
			num_picks_max
        from
            txgamedef
        where
            sort = ?
    }

    set xgaQry(get_prices) {
        select
            price_id,
            num_correct,
            num_picks,
            price_num,
		    price_den,
            valid_to,
            valid_from
        from
            txgameprice
        where
            sort = ?
        order by num_correct asc
    }

    set xgaQry(delete_all_prices) {
        delete from
            txgameprice
        where
            sort = ?
    }

    set xgaQry(add_price) {
        insert into txgameprice (
            sort,
            num_picks,
            num_correct,
            price_num,
            price_den,
			num_void
        ) values (?, ?, ?, ?, ?, 0)
    }

	set xgaQry(get_date) {
		select first 1
			extend (current, year to second),
			date(current)
		from
			systables
	}

	set xgaQry(get_gamedefs) {
		select
			sort,
			name
		from
			tXGameDef
		order by name
	}

    set xgaQry(setup_xgame) {
		execute procedure pSetupXGame (
				       p_xgame_id = ?,
				       p_sort     = ?,
				       p_comp_no  = ?,
				       p_open_at  = ?,
				       p_shut_at  = ?,
				       p_draw_at  = ?,
				       p_status   = ?,
				       p_desc     = ?,
				       p_misc_desc = ?,
				       p_draw_desc_id = ?
				       )
    }

    set xgaQry(add_xgame) {
		execute procedure pSetupXGame (
				       p_sort     = ?,
				       p_comp_no  = ?,
				       p_open_at  = ?,
				       p_shut_at  = ?,
				       p_draw_at  = ?,
				       p_status   = ?,
				       p_desc     = ?,
				       p_misc_desc = ?,
				       p_draw_desc_id = ?
				       )
    }


    set xgaQry(game_detail) {
		select
			g.xgame_id,
			g.draw_desc_id,
			g.sort,
			gd.name,
			g.comp_no,
			g.open_at,
			g.shut_at,
			g.draw_at,
			g.status,
			g.desc,
			g.misc_desc,
			g.results,
			g.wed_sat,
			gd.name,
			gd.has_balls,
			gd.conf_needed,
			gd.num_min,
			gd.num_max,
			gd.num_picks_min,
			gd.num_picks_max,
			gd.num_results_min,
			gd.num_results_max,
			gd.external_settle
		from
			tXGame g,
			tXGameDef gd
		where xgame_id = ?
		and   g.sort=gd.sort
	}

	set xgaQry(unsettle_game) {
		execute procedure pUnsettleXGame (
				p_xgame_id = ?,
				p_user_id = ?
		)
	}

	set xgaQry(game_open) {
		select 1
		from txgame
		where xgame_id = ?
		and  open_at <= CURRENT
	}




    set xgaQry(next_comp_no) {
	select max(comp_no)+1 as ncn
	from txgame
	where sort = ?
    }

    set xgaQry(get_balls) {
	select xgame_ball_id, ball_name, ball_no
	from tXGameBall where
	xgame_id = ?
	or sort = ?
    }

    set xgaQry(update_ball) {
	update tXGameBall set
	ball_name = ?
	where xgame_ball_id = ?
    }

    set xgaQry(insert_ball) {
	insert into tXGameBall
	(
	 xgame_id,
	 ball_no,
	 ball_name
	 )
	values
	(
	 ?,
	 ?,
	 ?
	 )
    }

    set xgaQry(update_results) {
	update tXGame
	set results = ?
	where xgame_id = ?
    }



    set xgaQry(delete_results) {
	execute procedure
		pDelXGameResults (
				    p_xgame_id  = ?
				 )
    }




   set xgaQry(get_valid_price) {

	select price_num,
		price_den,
		refund
	from txgameprice
	where
	sort = ?
	and (num_picks is null or num_picks = ?)
	and (num_correct is null or num_correct = ?)
	and (valid_from <= ? )
	and (valid_to is null or valid_to > ?)

  }

	set xgaQry(count_bets) {
		select
			count(*) as num_bets
		from
			tXGameBet
		where
			xgame_id = ?
	}

    set xgaQry(count_unsettled_bets) {
	select
		count(*) as num_unsettled
	from
		tXGameBet b
	where
		b.xgame_id = ? and
		b.settled = 'N' and
        b.status='A'
    }


    set xgaQry(get_bet_for_settlement) {
    select
		b.xgame_bet_id,
		b.xgame_sub_id,
		b.stake,
		b.winnings,
		b.refund,
		b.settled,
		b.output,
		b.cr_date,
		s.picks,
		s.cr_date as sub_cr_date,
		d.max_card_payout,
		d.max_payout,
		a.acct_id,
		c.ccy_code,
		c.exch_rate,
        b.bet_type,
        b.stake_per_line,
        b.num_selns,
        s.prices,
        g.sort,
        g.results,
        g.xgame_id,
        g.status,
        s.source,
		d.external_settle
	from
        txgamebet b,
        txgamesub s,
        txgame g,
        txgamedef d,
        tacct a,
		tccy c
	where
        b.xgame_bet_id = ?
	and
        b.xgame_sub_id = s.xgame_sub_id
	and
        b.settled='N'
	and
        b.status='A'
    and
        b.xgame_id = g.xgame_id
	and
        g.sort = d.sort
	and
        s.acct_id = a.acct_id
	and
        a.ccy_code = c.ccy_code
    }

    set xgaQry(get_unsettled) {
	select
		b.xgame_bet_id,
		b.xgame_sub_id,
		b.stake,
		b.winnings,
		b.refund,
		b.settled,
		b.output,
		b.cr_date,
		s.picks,
		s.cr_date as sub_cr_date,
		d.max_card_payout,
		d.max_payout,
		a.acct_id,
		c.ccy_code,
		c.exch_rate,
        b.bet_type,
        b.stake_per_line,
        b.num_selns,
        s.prices,
        g.status,
        s.source,
		d.external_settle
	from    txgamebet b,
	        txgamesub s,
	        txgame g,
	        txgamedef d,
	        tacct a,
		tccy c
	where   b.xgame_id = ?
	and     b.xgame_sub_id = s.xgame_sub_id
	and     b.settled='N'
    and b.status='A'
	and     b.xgame_id = g.xgame_id
	and     g.sort = d.sort
	and     s.acct_id = a.acct_id
	and     a.ccy_code = c.ccy_code
    }

	set xgaQry(get_unsettled_bet) {
		select
			b.xgame_bet_id,
			b.xgame_sub_id,
			b.stake,
			b.winnings,
			b.refund,
			b.settled,
			b.output,
			b.cr_date,
			s.picks,
			s.cr_date as sub_cr_date,
			d.max_card_payout,
			d.max_payout,
			a.acct_id,
			c.ccy_code,
			c.exch_rate
		from
			txgamebet b,
			txgamesub s,
			txgame g,
			txgamedef d,
			tacct a,
			tccy c
		where
			b.xgame_bet_id = ? and
			b.xgame_sub_id = s.xgame_sub_id and
			b.settled='N' and
            b.status='A' and
			b.xgame_id = g.xgame_id and
			g.sort = d.sort and
			s.acct_id = a.acct_id and
			a.ccy_code = c.ccy_code
    }

    ## Get all users with outstanding Prizebuster subscriptions
    ## Must be sent a Charity_Notification mail when the charity changes

    set xgaQry(get_users_with_outstanding_pbust_subs) {
	select distinct s.acct_id
	from   tXGameSub s, tXGame g
	where  s.xgame_id = g.xgame_id
	and    g.sort = ?
	and    s.status = 'P'
    }

    ## Get all outstanding Prizebuster 3/4 subscriptions for a user
    ## Must be sent a Charity_Notification mail when the charity changes

    set xgaQry(get_outstanding_pbust_subs_for_user) {
	select s.xgame_sub_id
	from   tXGameSub s, tXGame g
	where  s.xgame_id = g.xgame_id
	and    s.status = 'P'
	and    s.acct_id = ?
	and    g.sort = ?
    }

   set xgaQry(get_details_for_email) {
	select  a.cust_id
	from
		tXGameSub s,
		tAcct a
	where   s.acct_id = a.acct_id
	and	s.xgame_sub_id = ?

	order by s.xgame_sub_id


   }

    ## Subscriptions which haven''t had all their bets placed

    if {[OT_CfgGet XG_DYNAMIC_DRAW_DESC "0"] == "0"} {

	   ## doesn''t take into account draws field
	    set xgaQry(get_outstanding_subs) {
			select
			  s.xgame_sub_id,
			  s.stake_per_bet,
			  s.num_subs,
			  s.picks,
			  s.bet_type,
			  s.num_selns,
			  s.stake_per_line,
			  s.num_lines,
			  s.acct_id,
			  s.source,
			  count(*)
			from
			  txgamesub s,
			  txgame g,
			  txgamebet b
			where s.xgame_id = g.xgame_id
			and b.xgame_sub_id = s.xgame_sub_id
			and g.sort = ?
			and s.authorized = 'Y'
			and s.status <> 'F'
			and s.cr_date < (select shut_at from txgame where xgame_id=?)
			and not exists
			(select 1
			 from txgamebet b1
			 where b1.xgame_id = ?
			 and   b1.xgame_sub_id = s.xgame_sub_id)
			group  by 1,2,3,4,5,6,7,8,9,10
			having count(*) < s.num_subs
	    }
  } else {

	   ## does match game's draw_desc_id against any draws stored in subs...
	    set xgaQry(get_outstanding_subs) {
			select
			  s.xgame_sub_id,
			  s.stake_per_bet,
			  s.num_subs,
			  s.picks,
			  s.bet_type,
			  s.num_selns,
			  s.stake_per_line,
			  s.num_lines,
			  s.acct_id,
			  s.source,
			  count(*)
			from
			  txgamesub s,
			  txgame g,
			  txgamebet b
			where s.xgame_id = g.xgame_id
			and b.xgame_sub_id = s.xgame_sub_id
			and g.sort = ?
			and s.authorized = 'Y'
			and s.status <> 'F'
			and s.cr_date < (select shut_at from txgame where xgame_id=?)
			and s.draws like ?
			and not exists
			(select 1
			 from txgamebet b1
			 where b1.xgame_id = ?
			 and   b1.xgame_sub_id = s.xgame_sub_id)
			group  by 1,2,3,4,5,6,7,8,9,10
			having count(*) < s.num_subs
	    }
  }


    set xgaQry(game_report) {
	select b.xgame_id,
	count(*) as number_bets,
	sum(b.stake/c.exch_rate) as total_stake,
	sum(b.refund/c.exch_rate) as total_refunds,
	sum(b.winnings/c.exch_rate) as total_winnings,
	sort,
	comp_no,
	open_at,
	shut_at,
	draw_at,
	sum(
	    case when refund>0 then 1
	    else 0
	    end
	    ) as number_refunds,
	sum(
	    case when paymethod='L' and winnings>0 then 1
	    else 0
	    end
	    ) as number_paymethod_l,
	sum(
	    case when paymethod='O' and winnings>0 then 1
	    else 0
	    end
	    ) as number_paymethod_o,
	sum(
	    case when paymethod='F' and winnings>0 then 1
	    else 0
	    end
	    ) as number_paymethod_f,
	sum(
	    case when paymethod='P' and winnings>0 then 1
	    else 0
	    end
	    ) as number_paymethod_p
	from	txgamesub s,
		txgamebet b,
		txgame g,
		tAcct a,
		tCCY c
	where b.xgame_id = g.xgame_id
	and g.draw_at between ? and ?
	and b.xgame_sub_id = s.xgame_sub_id
	and s.acct_id = a.acct_id
	and a.ccy_code = c.ccy_code
	group by b.xgame_id, g.sort, comp_no, open_at, shut_at, draw_at
	order by draw_at;
    }


#
#   Same query as above but grouping by channel/affiliate
#
    set xgaQry(game_report_ca) {
    select b.xgame_id,
	c.aff_id,
	s.source,
    count(*) as number_bets,
    sum(stake/ccy.exch_rate) as total_stake,
    sum(refund/ccy.exch_rate) as total_refunds,
    sum(winnings/ccy.exch_rate) as total_winnings,
    g.sort,
    comp_no,
    open_at,
    shut_at,
    draw_at,
    sum(
        case when refund>0 then 1
        else 0
        end
        ) as number_refunds,
    sum(
        case when paymethod='L' and winnings>0 then 1
        else 0
        end
        ) as number_paymethod_l,
    sum(
        case when paymethod='O' and winnings>0 then 1
        else 0
        end
        ) as number_paymethod_o,
    sum(
        case when paymethod='F' and winnings>0 then 1
        else 0
        end
        ) as number_paymethod_f,
    sum(
        case when paymethod='P' and winnings>0 then 1
        else 0
        end
        ) as number_paymethod_p
    from txgamebet b, txgame g, txgamesub s, tacct a, tcustomer c, tCCy ccy
    where b.xgame_id = g.xgame_id
	and b.xgame_sub_id = s.xgame_sub_id
	and s.acct_id = a.acct_id
	and a.cust_id = c.cust_id
    and g.draw_at between ? and ?
	and a.ccy_code = ccy.ccy_code
    group by b.xgame_id, g.sort, comp_no, s.source,c.aff_id,open_at, shut_at, draw_at
    order by draw_at,g.sort,s.source,c.aff_id;
    }


    set xgaQry(subs_qry) {
	select sum(num_subs*stake_per_bet/c.exch_rate) as total_takings,
	sum(num_subs)               as total_entries,
	count(*)                    as total_subs,
	sort
	from	txgamesub s,
		txgame g,
		tAcct a,
		tCCY c
	where s.cr_date between ? and ?
	and s.xgame_id = g.xgame_id
	and s.acct_id = a.acct_id
	and a.ccy_code = c.ccy_code
	group by sort
    }


#
# Same query as above but with channels/affiliates break-down
#

    set xgaQry(subs_qry_ca) {
    select s.source,c.aff_id,
	sum(num_subs*stake_per_bet/ccy.exch_rate) as total_takings,
    sum(num_subs)               as total_entries,
    count(*)                    as total_subs,
    g.sort
    from txgamesub s, txgame g, tacct a, tcustomer c, tCCy ccy
    where s.cr_date between ? and ?
    and s.xgame_id = g.xgame_id
	and s.acct_id = a.acct_id
	and a.cust_id = c.cust_id
	and a.ccy_code = ccy.ccy_code
    group by g.sort,s.source,c.aff_id order by g.sort,s.source,c.aff_id
    }



    ## Dividend queries

    set xgaQry(get_dividends) {
	select points, prizes, type, xgame_dividend_id
	from tXGameDividend
	where xgame_id = ?
	order by type, prizes desc
    }

    set xgaQry(delete_dividend) {
	delete from tXGameDividend
	where xgame_dividend_id=?
    }

    set xgaQry(insert_dividend) {
	insert into tXGameDividend (xgame_id, points, prizes, type)
	values (?,?,?,?)
    }

    ## Manual authorization

    set xgaQry(get_unauthorized) {
	select	xgame_sub_id,
		s.cr_date,
		username,
		picks,
		g.sort,
		num_subs,
		stake_per_bet,
		s.free_subs free_subs,
		NVL(s.token_value,0) token_value,
		a.balance,
		a.acct_id,
		mobile,
		email,
		fname,
		lname,
		c.cust_id,
		gd.name as game_name,
		s.status,
		s.no_funds_email

	from tXGameSub s,
	tAcct     a,
	tCustomer c,
	tXGame    g,
	tXGameDef gd,
	tCustomerReg r
	where s.acct_id = a.acct_id
	and a.cust_id = c.cust_id
	and g.xgame_id = s.xgame_id
	and c.cust_id = r.cust_id
	and g.sort = gd.sort
	and authorized = 'N'
	and s.status == 'P'
    }

    	set xgaQry(authorise) {
		execute procedure pAuthXGameSub(
					p_xgame_sub_id = ?,
					p_stake = ?,
					p_jrnl_desc = ?
					)
	}

    set xgaQry(void) {
	update tXGameSub set status = 'V' where xgame_sub_id = ?
    }

    set xgaQry(no_funds_email_sent) {
	update tXGameSub set no_funds_email = 'Y' where xgame_sub_id = ?
    }


    set xgaQry(num_bets_placed_for_sub) {
		select
			count(*) num_bets_placed
		from
			tXGameBet b
		where
			b.xgame_sub_id= ?
    }


    set xgaQry(get_xgame_for_sort) {
		SELECT nvl(g.desc, gd.desc) as desc,
			misc_desc,
			g.xgame_id,
			gd.name,
			g.comp_no,
			gd.num_picks_max,
			gd.num_picks_min,
			gd.conf_needed,
			gd.has_balls,
			gd.num_min,
			gd.num_max,
			g.open_at,
			g.shut_at,
			g.draw_at
		FROM
			tXGame AS g,
			tXGameDef AS gd

		WHERE gd.sort = g.sort AND
			g.sort = ? AND
			g.status = 'A' AND
			g.open_at < CURRENT AND
			g.shut_at > CURRENT
		ORDER BY
			g.open_at
    }

    set xgaQry(get_topspot_pics) {
	select *
	from
	ttopspotpic p
	where xgame_id = ?
	order by number
    }

    set xgaQry(get_all_topspot_pics) {
	select *
	from
	ttopspotpic p
    }

     set xgaQry(remove_pictures) {
	 delete from ttopspotpic
	 where xgame_id=?
    }

    set xgaQry(add_picture) {
	insert into ttopspotpic (
				      xgame_id,
				      pic_filename,
				      small_pic_filename,
				      number
				      )
	values (
		?,
		?,
		?,
		?
		)
    }

    set xgaQry(update_pic_rectangle) {
	update ttopspotpic
	set left = ?,
	right = ?,
	top = ?,
	bottom = ?
	where topspot_pic_id = ?
    }

    set xgaQry(remove_topspot_balls) {
	delete from ttopspotball
	where topspot_pic_id = ?
    }

    set xgaQry(add_topspot_ball) {
	insert into ttopspotball (
				  topspot_pic_id,
				  number,
				  x,
				  y
				  )
	values (
		?,
		?,
		?,
		?
		)
    }
	set xgaQry(get_topspot_pictures) {
		select pic_filename,
		       number,
		       small_pic_filename,
		       topspot_pic_id
		from   tTopSpotPic
		where xgame_id = ?
	}

	set xgaQry(get_topspot_balls) {
		select b.number as ball_number,
		       p.number as pic_number,
		       b.x,
		       b.y,
		       b.topspot_ball_id
		from
		     tTopSpotPic p,
		     tTopSpotBall b
		where
		     p.topspot_pic_id = b.topspot_pic_id
		     and p.xgame_id=?
	}


	if {[OT_CfgGet ENABLE_FREEBETS "FALSE"] == "TRUE"} {
		set freebets_enabled 'Y'
	} else {
		set freebets_enabled 'N'
	}

	set xgaQry(settle_bet_bt) [subst {
	    execute procedure
	     pSettleXGameBet
	     (
	       p_xgame_bet_id     = ?,
	       p_winnings         = ?,
	       p_refund           = ?,
	       p_paymethod        = ?,
		   p_freebets_enabled = $freebets_enabled,
           p_num_lines_win    = ?,
           p_num_lines_lose   = ?,
           p_num_lines_void   = ?,
           p_settled_how      = ?,
           p_settle_info     = ?,
           p_do_tran          =?,
           p_park_by_winnings =?,
           p_enable_parking = ?,
           p_un_park_auth = ?,
		   p_op =?,
		   p_settled_by=?

	    )
	}]

    set xgaQry(settle_bet) [subst {
	    execute procedure
	     pSettleXGameBet
	     (
	       p_xgame_bet_id     = ?,
	       p_winnings         = ?,
	       p_refund           = ?,
	       p_paymethod        = ?,
		   p_freebets_enabled = $freebets_enabled,
           p_settled_by       = ?
	    )
	}]

	set xgaQry(get_bet_stk) {
		select
			stake
		from
			tXGameBet
		where   xgame_bet_id = ?
	}


	set xgaQry(get_game_options) {
		select
			option_id,
			num_picks,
			status
		from
			tXGameOption
		where   sort = ?
		order by num_picks
	}


	set xgaQry(get_game_option_details) {
		select
			sort,
			num_picks,
			status
		from
			tXGameOption
		where   option_id = ?
	}




	set xgaQry(modify_game_option_status) {
		update tXGameOption
		set status = ?
		where option_id = ?
	}



	if {[OT_CfgGet XG_PRICES "SP"] == "SP"} {
		set xgaQry(get_valid_game_prices) {
			select
				price_id,
				price_num,
				price_den,
				refund,
				num_picks,
				num_correct,
				num_void
			from
				tXGamePrice

			where
				sort = ?
			order by num_picks, num_correct, num_void
		}

	} else {
		set xgaQry(get_valid_game_prices) {
			select
				price_id,
				price_num,
				price_den,
				refund,
				num_picks,
				num_correct,
				num_void
			from
				tXGamePrice

			where

					sort = ?
				and	valid_from	<= ?
				and	(valid_to is null or valid_to > ?)
			order by num_picks, num_correct, num_void

		}

	}


	# Retrieves prices valid at a particular datetime
	# and
	# Retrieves all prices valid during a particular time interval/period
	set xgaQry(get_snapshot_price_history) {
			select
				price_id,
				price_num,
				price_den,
				refund,
				num_picks,
				num_correct,
				num_void,
				valid_from,
				valid_to
			from
				tXGamePrice

			where

					sort = ?
				and	? >= valid_from
				and	(valid_to is null or ? <= valid_to)
			order by valid_from, valid_to, num_picks, num_correct, num_void

	}


	# Retrieves all prices
	set xgaQry(get_full_price_history) {
			select
				price_id,
				price_num,
				price_den,
				refund,
				num_picks,
				num_correct,
				num_void,
				valid_from,
				valid_to
			from
				tXGamePrice

			where

					sort = ?
			order by valid_from, valid_to, num_picks, num_correct, num_void

	}


	# used by old version of admin screens?
	set xgaQry(get_game_prices) {
			select
				price_id,
				price_num,
				price_den,
				refund,
				num_picks,
				num_correct,
				num_void,
				valid_from,
				valid_to
			from
				tXGamePrice

			where
				sort = ?
			order by  num_picks, num_correct, num_void,valid_from,valid_to
	}




	set xgaQry(add_game_price) {
	    execute procedure
	     pInsXGamePrice
	     (
		p_sort			= ?,
		p_num_picks		= ?,
		p_num_correct		= ?,
		p_num_void		= ?,
		p_price_num		= ?,
		p_price_den		= ?,
		p_refund_mult		= ?,
		p_cfg_price		= ?,
		p_time_of_update	= ?,
		p_transactional		= 'Y'
	    )
	}

	set xgaQry(delete_game_price) {
	    execute procedure
	     pDelXGamePrice
	     (
		p_price_id		= ?,
		p_cfg_price		= ?,
		p_time_of_update	= ?,
		p_transactional		= 'Y'
	    )
	}


	set xgaQry(modify_game_price) {
	    execute procedure
	     pUpdXGamePrice
	     (
		p_sort			= ?,
		p_num_picks		= ?,
		p_num_correct		= ?,
		p_num_void		= ?,
		p_price_num		= ?,
		p_price_den		= ?,
		p_refund_mult		= ?,
		p_cfg_price		= ?,
		p_time_of_update	= ?,
		p_price_id		= ?,
		p_transactional		= 'Y'
	    )
	}




	set xgaQry(game_draw_desc) {
		select desc_id,
			sort,
			name,
			desc
		from tXGameDrawDesc
		where sort = ?

	}

	set xgaQry(get_stake_and_max_payout) {
		select b.stake,
		       d.max_card_payout
		from   tXGameBet b,
		       tXGame g,
		       tXGameDef d
		where  b.xgame_bet_id = ?
		and    b.xgame_id = g.xgame_id
		and    g.sort = d.sort
	}

	set xgaQry(get_cust_id_for_user) {
		select cust_id
		from   tAcct
		where  acct_id = ?
	}

	set xgaQry(ins_cust_mail) {
		execute procedure pInsCustMail (
				p_cust_mail_type = ?,
				p_cust_id = ?,
				p_ref_id = ?
		)
	}

}


