# ==============================================================
# $Id: xsyssub.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#
# Handles external system subscription querying and details.
#

namespace eval ADMIN::XSYSSUB {

	package require csv

	asSetAct ADMIN::XSYSSUB::GoSubQuery    [namespace code go_sub_query]
	asSetAct ADMIN::XSYSSUB::DoSubQuery    [namespace code do_sub_query]
	asSetAct ADMIN::XSYSSUB::DoSubDetails  [namespace code do_sub_details]
	asSetAct ADMIN::XSYSSUB::GoSubCSVDets  [namespace code go_sub_details_csv]
}



#
# Displays the external system subscription query page. Parameters for cust_id
# and sys_name (tXSyshost.name) can be provided in which case these will be
# hardcoded into the page and not selectable
#
proc ADMIN::XSYSSUB::go_sub_query {{cust_id ""} {sys_name ""}} {

	global DB SYSHOST


	# if a cust id exists, get cust details to display on page
	if {$cust_id != ""} {

		set sql {
			select
				username,
				acct_no
			from
				tCustomer c
			where
				c.cust_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cust_id]

		inf_close_stmt $stmt

		tpBindString CustId     $cust_id
		tpBindString Username   [db_get_col $res 0 username]
		tpBindString AcctNo     [db_get_col $res 0 acct_no]

		db_close $res
	}


	# get all system details
	set sql {
		select
			system_id,
			name
		from
			tXSysHost
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	set system_exists 0

	for {set i 0} {$i < $nrows} {incr i} {

		set system_id [db_get_col $res $i system_id]
		set name      [db_get_col $res $i name]

		# a system may have been specified so see if it exists, if it does
		# we won't need to provide a list of systems
		if {[string toupper $name] == [string toupper $sys_name]} {

			set system_exists 1

			tpBindString SystemName $name
			tpBindString SystemId   $system_id

			break
		}

		set SYSHOST($i,sys_id)   $system_id
		set SYSHOST($i,sys_name) $name
	}

	db_close $res

	tpSetVar system_exists $system_exists
	if {!$system_exists} {

		tpSetVar num_systems $nrows
		tpBindVar SystemName       SYSHOST sys_name      sys_idx
		tpBindVar SystemId         SYSHOST sys_id        sys_idx
	}


	# bind up date range information
	bind_date_ranges

	asPlayFile -nocache xsyssub_query.html
}



#
# Displays results of subscription query. Also handles showing Next/Previous
# page when viewing listings
#
proc ADMIN::XSYSSUB::do_sub_query {} {

	global DB SUBDATA

	tpBindString cust_id        [set cust_id         [reqGetArg cust_id]]
	tpBindString username       [set username        [reqGetArg username]]
	tpBindString case_insens    [set case_insens     [reqGetArg case_insens]]
	tpBindString first_name     [set first_name      [reqGetArg first_name]]
	tpBindString last_name      [set last_name       [reqGetArg last_name]]
	tpBindString email          [set email           [reqGetArg email]]
	tpBindString acct_no        [set acct_no         [reqGetArg acct_no]]
	tpBindString date_from      [set date_from       [reqGetArg date_from]]
	tpBindString date_to        [set date_to         [reqGetArg date_to]]
	tpBindString system_id      [set system_id       [reqGetArg system_id]]
	tpBindString system_name    [set system_name     [reqGetArg system_name]]
	tpBindString ext_sub_id     [set ext_sub_id      [reqGetArg ext_sub_id]]
	tpBindString status         [set status          [reqGetArg status]]
	tpBindString items_per_page [set items_per_page  [reqGetArg items_per_page]]

	set submit_name                [reqGetArg SubmitName]

	# min and max cr_dates from current listing
	set curr_min_cr_date           [reqGetArg curr_min_cr_date]
	set curr_max_cr_date           [reqGetArg curr_max_cr_date]

	set curr_first_sub_id          [reqGetArg curr_first_sub_id]
	set curr_last_sub_id           [reqGetArg curr_last_sub_id]

	# store page_no to help with returning to previous page's query listings
	set page_no                    [reqGetArg page_no]

	# see if we're returning to search page
	if {$submit_name == "NewSearch"} {

		go_sub_query $cust_id $system_name
		return
	}

	set sql {
		select $sel_first
			c.cust_id,
			c.username,
			nvl(nvl(f.ext_ccy_code,h.ccy_code),a.ccy_code) as ccy_code,
			c.acct_no,
			s.xsys_sub_id,
			s.ext_sub_id,
			s.acct_id,
			s.cr_date,
			s.end_date,
			s.status,
			s.desc,
			h.name as sys_name,
			NVL(m.cash_in,0.0) summary_cash_in,
			NVL(m.cash_out,0.0) summary_cash_out,
			sum(case when f.xfer_type = 'S' then f.amount else 0 end) as total_staked,
			sum(case when f.xfer_type = 'R' then f.amount else 0 end) as total_returned,
			count(f.xfer_type) as num_xfers
		from
			tXSysSub s,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			tXSysHost h,
			outer tXSysSubSumm m,
			outer tXSysSubXfer f
		where
			s.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			r.cust_id = c.cust_id and
			m.xsys_sub_id = s.xsys_sub_id and
			f.xsys_sub_id = s.xsys_sub_id and
			s.system_id = h.system_id and
			a.owner   <> 'D'
			$where
		group by
			1,2,3,4,5,6,7,8,9,10,11,12,13,14
		order by
			s.cr_date desc, s.xsys_sub_id asc
	}

	# set default items per page if none entered
	if {$items_per_page == ""} {

		set items_per_page 25
	}

	# construct where clause based on action/query
	set where ""

	# if cust id exists, use it, else look at what search criteria has been
	# entered
	if {$cust_id == ""} {

		set criteria_entered 0
		if {$username != ""} {

			if {$case_insens == "Y"} {

				append where " and c.username_uc = '[string toupper $username]'"
			} else {

				append where " and c.username = '$username'"
			}

			set criteria_entered 1
		}

		if {$first_name != ""} {

			append where " and r.fname = '$first_name'"
			set criteria_entered 1
		}

		if {$last_name != ""} {

			append where " and r.lname = '$last_name'"
			set criteria_entered 1
		}

		if {$email != ""} {

			append where " and r.email like '%$email%'"
			set criteria_entered 1
		}

		if {$acct_no != ""} {

			append where " and c.acct_no = '$acct_no'"
			set criteria_entered 1
		}
		if {"${date_from}${date_to}${system_id}${ext_sub_id}${status}" != ""} {
			# if any of these have been entered
			# we deal with them later though
			set criteria_entered 1
		}

		if {!$criteria_entered} {

			err_bind "No search criteria has been entered"
			go_sub_query $cust_id $system_name
			return
		}
	} else {

		append where " and c.cust_id = $cust_id"
	}

	# set dates for query depending on action to take.
	set sel_first "first $items_per_page"
	set first_row 0
	set from_id ""
	set to_id   ""
	switch -- $submit_name {
		"DoSearch" {
			set from $date_from
			set to   $date_to

			set page_no 1
		}
		"DoNext" {
			# remember items are displayed in reverse cr_date order
			set from $date_from
			set to   $curr_min_cr_date

			set from_id $curr_last_sub_id
			set to_id   $curr_first_sub_id

			incr page_no
		}
		"DoPrevious" {
			set from $curr_max_cr_date
			set to   $date_to

			incr page_no -1

			set to_id $curr_first_sub_id

			# if we are returning to the previous page we get all items up to
			# the current page's highest cr_date and then take the last n rows
			set sel_first ""
			set first_row [expr {($page_no - 1) * $items_per_page}]
		}
		"DoAllCSV" {
			# we want all the results, so we can shove em in a CSV file

			set sel_first ""
			set from $curr_min_cr_date
			set to   $curr_max_cr_date
		}
		"DoCSV" {

			set from $curr_min_cr_date
			set to   $curr_max_cr_date
		}
		default {
			err_bind "Unrecognised action - $submit_name"
			ob_log::write ERROR "ADMIN::XSYSSUB::do_sub_query - Unrecognised \
					submit name $submit_name"
			go_sub_query $cust_id $system_name
			return
		}
	}

	if {$to != ""} {

		if {![valid_informix_date $to]} {
			err_bind "Invalid date $to, must be in format yyyy-mm-dd hh:mm:ss"
			go_sub_query $cust_id $system_name
			return
		}
		# if to is what the user has entered then we need to check <= else we
		# just do < as this date will already have been shown
		if {$to == $date_to || $curr_last_sub_id == ""} {
			append where " and s.cr_date <= '$to'"
		} else {
			append where " and ((s.cr_date == '$to' and s.xsys_sub_id > $curr_last_sub_id)"
			append where "      or s.cr_date < '$to')"
		}

	}

	if {$from != ""} {

		if {![valid_informix_date $from]} {
			err_bind "Invalid date $from, must be in format yyyy-mm-dd hh:mm:ss"
			go_sub_query $cust_id $system_name
			return
		}
		# if from is what the user has entered then we need to check >= else we
		# just do > as this date will already have been shown
		# also need to check on $curr_first_sub_id, for potential overspill cases
		if {$from == $date_from || $curr_first_sub_id == ""} {
			append where " and s.cr_date >= '$from'"
		} else {
			append where " and ((s.cr_date == '$from' and s.xsys_sub_id < $curr_first_sub_id)"
			append where "       or s.cr_date > '$from')"
		}

	}


	# set status if required
	if {$status != ""} {
		append where " and s.status = '$status'"
	}

	# set system id if required
	if {$system_id != ""} {
		append where " and s.system_id = $system_id"
	}

	if {$ext_sub_id != ""} {
		append where " and s.ext_sub_id = '$ext_sub_id'"
	}

	ob_log::write INFO "ADMIN::XSYSSUB::do_sub_query - Query is: \n [subst $sql]"

	set stmt [inf_prep_sql $DB [subst $sql]]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]



	set idx 0
	for {set i $first_row} {$i < $nrows} {incr i} {

		set SUBDATA($idx,cust_id)      [db_get_col $res $i cust_id]
		set SUBDATA($idx,username)     [db_get_col $res $i username]
		set SUBDATA($idx,ccy_code)     [db_get_col $res $i ccy_code]
		set SUBDATA($idx,acct_no)      [db_get_col $res $i acct_no]
		set SUBDATA($idx,xsys_sub_id)  [db_get_col $res $i xsys_sub_id]
		set SUBDATA($idx,ext_sub_id)   [db_get_col $res $i ext_sub_id]
		set SUBDATA($idx,acct_id)      [db_get_col $res $i acct_id]
		set SUBDATA($idx,cr_date)      [db_get_col $res $i cr_date]
		set SUBDATA($idx,end_date)     [db_get_col $res $i end_date]
		set SUBDATA($idx,sys_name)     [db_get_col $res $i sys_name]

		if {$SUBDATA($idx,end_date) == ""} {
			set SUBDATA($idx,end_date) "--"
		}

		set status [db_get_col $res $i status]
		if {$status == "A"} {
			set SUBDATA($idx,status) "Active"
		} else {
			set SUBDATA($idx,status) "Closed"
		}

		set SUBDATA($idx,description)    [db_get_col $res $i desc]

		if {[db_get_col $res $i num_xfers] > 0} {
			set SUBDATA($idx,total_staked) \
			    [print_ccy [db_get_col $res $i total_staked]   $SUBDATA($idx,ccy_code)]
			set SUBDATA($idx,total_returned) \
			    [print_ccy [db_get_col $res $i total_returned] $SUBDATA($idx,ccy_code)]
		} else {
			set SUBDATA($idx,total_staked) \
			    [print_ccy [db_get_col $res $i summary_cash_out]   $SUBDATA($idx,ccy_code)]
			set SUBDATA($idx,total_returned) \
			    [print_ccy [db_get_col $res $i summary_cash_in] $SUBDATA($idx,ccy_code)]
		}

		incr idx
	}
	db_close $res

	# need to stop here if we're doing CSV
	if {$submit_name == "DoCSV" || $submit_name == "DoAllCSV"} {
		# manually set up the column names and headers
		set headers [list "Sub Id" "Username" "Acct No" "System" "External Sub Id" "Description" "Session Start" "Session End" "Session Status" "Cash To Table" "Cash From Table"]
		set columns [list xsys_sub_id username acct_no sys_name ext_sub_id description cr_date end_date status total_staked total_returned]
		build_csv_from_array $headers $columns SUBDATA $idx "subscriptions"

		catch {unset SUBDATA}

		return
	}

	tpSetVar num_subs $idx

	# bind up min/max query cr_date
	if {$idx > 0} {

		tpBindString curr_max_cr_date  $SUBDATA(0,cr_date)
		tpBindString curr_first_sub_id $SUBDATA(0,xsys_sub_id)
		tpBindString curr_min_cr_date  $SUBDATA([expr {$idx-1}],cr_date)
		tpBindString curr_last_sub_id  $SUBDATA([expr {$idx-1}],xsys_sub_id)
	}

	# depending on action and number of rows returned determine whether next and
	# previous buttons should be displayed
	set show_prev 1
	set show_next 1
	if {$page_no == 1} {

		set show_prev 0
	}
	if {$idx < $items_per_page} {

		set show_next 0
	}

	tpSetVar show_prev $show_prev
	tpSetVar show_next $show_next

	tpBindString page_no $page_no

	tpBindVar SubCustId       SUBDATA cust_id        sub_idx
	tpBindVar SubUsername     SUBDATA username       sub_idx
	tpBindVar SubCcyCode      SUBDATA ccy_code       sub_idx
	tpBindVar SubAcctNo       SUBDATA acct_no        sub_idx
	tpBindVar SubAcctId       SUBDATA acct_id        sub_idx
	tpBindVar SubXSysSubId    SUBDATA xsys_sub_id    sub_idx
	tpBindVar SubExtSubId     SUBDATA ext_sub_id     sub_idx
	tpBindVar SubStartDate    SUBDATA cr_date        sub_idx
	tpBindVar SubEndDate      SUBDATA end_date       sub_idx
	tpBindVar SubStatus       SUBDATA status         sub_idx
	tpBindVar SubDescription  SUBDATA description    sub_idx
	tpBindVar SubCashStaked   SUBDATA total_staked   sub_idx
	tpBindVar SubCashReturns  SUBDATA total_returned sub_idx
	tpBindVar SubHeldFunds    SUBDATA held_funds     sub_idx
	tpBindVar SubSysName      SUBDATA sys_name       sub_idx

	asPlayFile -nocache xsyssub_list.html

	catch {unset SUBDATA}

}



#
# Displays transfer breakdowns within a subscription
#
proc ADMIN::XSYSSUB::do_sub_details {} {

	global DB SUBINFO

	set xsys_sub_id [reqGetArg xsys_sub_id]

	set sql {
		select
			s.cr_date as start_date,
			s.end_date,
			s.ext_sub_id,
			s.status,
			s.desc,
			NVL(s.client_ip,'--')as client_ip,
			NVL(s.proxy_ip,'--') as proxy_ip,
			h.name as sys_name,
			h.ccy_code,
			c.cust_id,
			c.username,
			NVL(m.cash_in,0.0) cash_in,
			NVL(m.cash_out,0.0) cash_out,
			NVL(m.returns,0.0) returns
		from
			tXSysSub s,
			tXSysHost h,
			tAcct a,
			tCustomer c,
			outer tXSysSubSumm m
		where
			s.system_id = h.system_id and
			s.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			s.xsys_sub_id = m.xsys_sub_id and
			s.xsys_sub_id = ?
	}

	set stmt  [inf_prep_sql $DB $sql]
	set res   [inf_exec_stmt $stmt $xsys_sub_id]
	inf_close_stmt $stmt

	# get subscription information from first row
	set sub_start        [db_get_col $res 0 start_date]
	set sub_end          [db_get_col $res 0 end_date]
	set sub_ext_sub_id   [db_get_col $res 0 ext_sub_id]
	set sub_desc         [db_get_col $res 0 desc]
	set sub_client_ip    [db_get_col $res 0 client_ip]
	set sub_proxy_ip     [db_get_col $res 0 proxy_ip]
	set sub_sysname      [db_get_col $res 0 sys_name]
	set sub_username     [db_get_col $res 0 username]
	set sub_cust_id      [db_get_col $res 0 cust_id]
	set host_ccy_code    [db_get_col $res 0 ccy_code]
	set summary_staked   [db_get_col $res 0 cash_out]
	set summary_returned [db_get_col $res 0 cash_in]
	set summary_winnings [db_get_col $res 0 returns]

	set sub_status "Closed"
	if {[db_get_col $res 0 status] == "A"} {
		set sub_status "Active"
	}

	# set transfer type description
	set stake_desc "Transferred funds to $sub_sysname"
	set return_desc "Funds returned from $sub_sysname"


	set sql [subst {
		select
			xfer_id,
			amount,
			held_amount,
			xfer_type,
			cr_date,
			NVL(desc,'') as xfer_desc,
			ext_ccy_code
		from
			tXSysSubXfer
		where
			xsys_sub_id = ?
	}]

	set stmt  [inf_prep_sql $DB $sql]
	set res   [inf_exec_stmt $stmt $xsys_sub_id]
	inf_close_stmt $stmt

	set xfer_exists 1

	set total_staked 0.0
	set total_returned 0.0

	set nrows [db_get_nrows $res]

	if {$nrows == 0} {
		set total_staked   $summary_staked
		set total_returned $summary_returned
		set winnings       $summary_winnings
		set sub_ccy_code   $host_ccy_code
	} else {
		for {set i 0} {$i < $nrows} {incr i} {

			set xfer_id                    [db_get_col $res $i xfer_id]
			set amount                     [db_get_col $res $i amount]
			set held_amount                [db_get_col $res $i held_amount]
			set xfer_type                  [db_get_col $res $i xfer_type]
			set xfer_date                  [db_get_col $res $i cr_date]
			set xfer_desc                  [db_get_col $res $i xfer_desc]
			set sub_ccy_code               [db_get_col $res $i ext_ccy_code]
			set xfer_type_desc             ""

			if {$sub_ccy_code == ""} {
				set sub_ccy_code $host_ccy_code
			}

			set fmt_amount                 [print_ccy $amount $sub_ccy_code]
			set amount_desc                $fmt_amount

			if {$xfer_type == ""} {
				# no xfers found, type can not be null
				set xfer_exists 0
				break
			} elseif {$xfer_type == "S"} {
				set total_staked      [expr {$total_staked + $amount}]
				set amount            [expr {$amount * -1}]
				set xfer_type_desc    $stake_desc

				# format the stuff here
				set fmt_amount      [print_ccy $amount $sub_ccy_code]
				set amount_desc $fmt_amount
				set fmt_held_amount [print_ccy $held_amount $sub_ccy_code]

				if {$held_amount > 0.0} {
					set amount_desc "$fmt_amount cash to $sub_sysname of which \
							$fmt_held_amount came from held funds"
				}
			} else {
				set total_returned       [expr {$total_returned + $amount}]
				set xfer_type_desc       $return_desc
				set fmt_held_amount [print_ccy $held_amount $sub_ccy_code]

				if {$held_amount > 0.0} {
					set amount_desc "$fmt_amount cash from $sub_sysname of which \
							$fmt_held_amount returns to held funds"
				}
			}

			set SUBINFO($i,xfer_id)         $xfer_id
			set SUBINFO($i,xfer_desc)       $xfer_desc
			set SUBINFO($i,xfer_type_desc)  $xfer_type_desc
			set SUBINFO($i,xfer_date)       $xfer_date
			set SUBINFO($i,amount_desc)     $amount_desc
		}

		set winnings [expr {$total_returned - $total_staked}]
		if {$winnings < 0.0} {
			set winnings 0.0
		}
	}


	tpSetVar num_xfers $nrows
	tpSetVar xfer_exists $xfer_exists

	tpBindString SubStart      $sub_start
	tpBindString SubEnd        $sub_end
	tpBindString SubExtSubId   $sub_ext_sub_id
	tpBindString SubDesc       $sub_desc
	tpBindString SubClientIP   $sub_client_ip
	tpBindString SubProxyIP    $sub_proxy_ip
	tpBindString SubSysName    $sub_sysname
	tpBindString SubStatus     $sub_status
	tpBindString SubUsername   $sub_username
	tpBindString SubCustId     $sub_cust_id
	tpBindString SubStaked     [print_ccy $total_staked   $sub_ccy_code]
	tpBindString SubReturned   [print_ccy $total_returned $sub_ccy_code]
	tpBindString SubWinnings   [print_ccy $winnings       $sub_ccy_code]

	tpBindVar XferId          SUBINFO xfer_id           xfer_idx
	tpBindVar XferDesc        SUBINFO xfer_desc         xfer_idx
	tpBindVar XferTypeDesc    SUBINFO xfer_type_desc    xfer_idx
	tpBindVar XferDate        SUBINFO xfer_date         xfer_idx
	tpBindVar AmountDesc      SUBINFO amount_desc       xfer_idx

	# bind up extra info
	if {[catch {do_sub_extra_info $xsys_sub_id $sub_ccy_code} msg]} {
		ob_log::write DEBUG "do_sub_extra_info failed: $msg"
	}

	asPlayFile -nocache xsyssub_details.html

	catch {unset SUBINFO}

}

# wrapper for all external system extra info gatherers
proc ADMIN::XSYSSUB::do_sub_extra_info {xsys_sub_id ccy_code} {

	global DB SUBINFO

	ADMIN::XSYSSUB::do_crypto_sub_extra_info $xsys_sub_id $ccy_code

	ADMIN::XSYSSUB::do_vegas_sub_extra_info $xsys_sub_id $ccy_code
}

proc ADMIN::XSYSSUB::do_crypto_sub_extra_info {xsys_sub_id ccy_code} {
	global DB SUBINFO

	# get any extra info from other tables that might have info about the
	# subscription

	set sql [subst {
		select
			i.action,
			i.action_seq_no,
			NVL(i.xfer_id,x.xfer_id) as xfer_id,
			NVL(i.remote_unique_id,x.remote_unique_id) as remote_unique_id,
			i.remote_unique_id,
			i.game_id,
			i.user_exch_rate,
			i.settle_exch_rate,
			i.house_fee,
			i.entry_fee,
			i.table_ccy,
			i.tnmt_ccy,
			i.hands_played,
			i.high_bet_limit,
			i.low_bet_limit,
			i.rake_amount,
			i.rake_points,
			i.seconds_played,
			i.bbt,
			i.rfl,
			i.game_name,
			i.amount_staked,
			i.opening_game_bal,
			i.closing_game_bal
		from
			tCryptoSubInfo i,
			outer tXSysXfer x
		where
			i.xsys_sub_id = ?         and
			i.xfer_id     = x.xfer_id

		union

		select
			i.action,
			i.action_seq_no,
			NVL(i.xfer_id,x.xfer_id) as xfer_id,
			NVL(i.remote_unique_id,x.remote_unique_id) as remote_unique_id,
			i.remote_unique_id,
			i.game_id,
			i.user_exch_rate,
			i.settle_exch_rate,
			i.house_fee,
			i.entry_fee,
			i.table_ccy,
			i.tnmt_ccy,
			i.hands_played,
			i.high_bet_limit,
			i.low_bet_limit,
			i.rake_amount,
			i.rake_points,
			i.seconds_played,
			i.bbt,
			i.rfl,
			i.game_name,
			i.amount_staked,
			i.opening_game_bal,
			i.closing_game_bal
		from
			tCryptoSubInfo i,
			outer tXSysXfer x
		where
			i.xsys_sub_id      = ?                   and
			i.remote_unique_id = x.remote_unique_id
		order by
			i.action, i.action_seq_no
	}]

	set stmt   [inf_prep_sql $DB $sql]
	set res    [inf_exec_stmt $stmt $xsys_sub_id $xsys_sub_id]
	inf_close_stmt $stmt

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {

		# set up the ccy to use for formatting
		set fmt_ccy_code $ccy_code

		# always ensure any _ccy cols are before any amounts
		# that you might wish to format
		foreach {col fmt} {
			action             0
			action_seq_no      0
			xfer_id            0
			remote_unique_id   0
			game_id            0
			user_exch_rate     0
			settle_exch_rate   0
			table_ccy          0
			tnmt_ccy           0
			house_fee          1
			entry_fee          1
			hands_played       0
			high_bet_limit     1
			low_bet_limit      1
			rake_amount        1
			rake_points        0
			seconds_played     0
			bbt                0
			rfl                0
			game_name          0
			amount_staked      1
			opening_game_bal   1
			closing_game_bal   1
		} {

			set val [db_get_col $res $r $col]
			if {$val == {}} {
				# neaten the displayed output
				set val "--"
			} elseif {$fmt} {
				# format any currency amounts
				if {$col == "house_fee" || $col == "entry_fee"} {
					set val [print_ccy $val $ccy_code]
				} else {
					set val [print_ccy $val $fmt_ccy_code]
				}
			} elseif {$col == "tnmt_ccy" || $col == "table_ccy"} {
				# I know this predicate looks a bit dodgy
				# what if we get both?!
				# We won't. see oxixmlserver_base.cfg:XSYSSUB.CRYPOKER etc
				set fmt_ccy_code $val
			}
			set SUBINFO(crypto,$r,$col) $val

			ob_log::write DEBUG "SUBINFO(crypto,$r,$col) : $SUBINFO(crypto,$r,$col)"
		}
	}

	tpSetVar xicrypto_nrows    [db_get_nrows $res]
	tpSetVar crypto         crypto

	tpBindVar XICryptoAction               SUBINFO action              crypto xicrypto_idx
	tpBindVar XICryptoActionSeqNo          SUBINFO action_seq_no       crypto xicrypto_idx
	tpBindVar XICryptoXferId               SUBINFO xfer_id             crypto xicrypto_idx
	tpBindVar XICryptoRemoteUniqueId       SUBINFO remote_unique_id    crypto xicrypto_idx
	tpBindVar XICryptoGameId               SUBINFO game_id             crypto xicrypto_idx
	tpBindVar XICryptoUserExchRate         SUBINFO user_exch_rate      crypto xicrypto_idx
	tpBindVar XICryptoSettleExchRate       SUBINFO settle_exch_rate    crypto xicrypto_idx
	tpBindVar XICryptoHouseFee             SUBINFO house_fee           crypto xicrypto_idx
	tpBindVar XICryptoEntryFee             SUBINFO entry_fee           crypto xicrypto_idx
	tpBindVar XICryptoTableCCY             SUBINFO table_ccy           crypto xicrypto_idx
	tpBindVar XICryptoTNMTCCY              SUBINFO tnmt_ccy            crypto xicrypto_idx
	tpBindVar XICryptoHandsPlayed          SUBINFO hands_played        crypto xicrypto_idx
	tpBindVar XICryptoHighBetLimit         SUBINFO high_bet_limit      crypto xicrypto_idx
	tpBindVar XICryptoLowBetLimit          SUBINFO low_bet_limit       crypto xicrypto_idx
	tpBindVar XICryptoRakeAmount           SUBINFO rake_amount         crypto xicrypto_idx
	tpBindVar XICryptoRakePoints           SUBINFO rake_points         crypto xicrypto_idx
	tpBindVar XICryptoSecondsPlayed        SUBINFO seconds_played      crypto xicrypto_idx
	tpBindVar XICryptoBBT                  SUBINFO bbt                 crypto xicrypto_idx
	tpBindVar XICryptoRFL                  SUBINFO rfl                 crypto xicrypto_idx
	tpBindVar XICryptoGameName             SUBINFO game_name           crypto xicrypto_idx
	tpBindVar XICryptoAmountStaked         SUBINFO amount_staked       crypto xicrypto_idx
	tpBindVar XICryptoOpeningGameBal       SUBINFO opening_game_bal    crypto xicrypto_idx
	tpBindVar XICryptoClosingGameBal       SUBINFO closing_game_bal    crypto xicrypto_idx

	db_close $res

}

# Vegas/Games extra info
proc ADMIN::XSYSSUB::do_vegas_sub_extra_info {xsys_sub_id ccy_code} {

	global DB SUBINFO

	# get extra info from tVegasSubInfo
	set sql [subst {
		select
			i.action,
			i.action_seq_no,
			NVL(i.xfer_id,x.xfer_id) as xfer_id,
			NVL(i.remote_unique_id,x.remote_unique_id) as remote_unique_id,
			i.amount_staked,
			i.ccy_code
		from
			tVegasSubInfo   i,
			outer tXSysXfer x
		where
			i.xsys_sub_id = ?           and
			i.xfer_id     = x.xfer_id

		union

		select
			i.action,
			i.action_seq_no,
			NVL(i.xfer_id,x.xfer_id) as xfer_id,
			NVL(i.remote_unique_id,x.remote_unique_id) as remote_unique_id,
			i.amount_staked,
			i.ccy_code
		from
			tVegasSubInfo   i,
			outer tXSysXfer x
		where
			i.xsys_sub_id      = ?                  and
			i.remote_unique_id = x.remote_unique_id
		order by
			i.action, i.action_seq_no
	}]

	set stmt        [inf_prep_sql $DB $sql]
	set res         [inf_exec_stmt $stmt $xsys_sub_id $xsys_sub_id]
	inf_close_stmt  $stmt

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {

		set fmt_ccy_code $ccy_code

		foreach {col fmt} {
			action             0
			action_seq_no      0
			xfer_id            0
			remote_unique_id   0
			ccy_code           0
			amount_staked      1
		} {
			set val [db_get_col $res $r $col]
			if {$val == {}} {
				# neaten the displayed output
				set val "--"
			} elseif {$fmt} {
				# format any currency amounts
				set val [print_ccy $val $fmt_ccy_code]
			} elseif {$col == "ccy_code"} {
				# I know this predicate looks a bit dodgy
				# what if we get both?!
				# We won't. see oxixmlserver_base.cfg:XSYSSUB.CRYPOKER etc
				set fmt_ccy_code $val
			}
			set SUBINFO(vegas,$r,$col) $val

			ob_log::write DEBUG "SUBINFO(vegas,$r,$col) : $SUBINFO(vegas,$r,$col)"
		}
	}

	tpSetVar xivegas_nrows [db_get_nrows $res]
	tpSetVar vegas         vegas

	tpBindVar XIVegasAction	        SUBINFO  action            vegas xivegas_idx
	tpBindVar XIVegasActionSeqNo    SUBINFO  action_seq_no     vegas xivegas_idx
	tpBindVar XIVegasXferId         SUBINFO  xfer_id           vegas xivegas_idx
	tpBindVar XIVegasRemoteUniqueId SUBINFO  remote_unique_id  vegas xivegas_idx
	tpBindVar XIVegasAmountStaked   SUBINFO  amount_staked     vegas xivegas_idx
	tpBindVar XIVegasCCY            SUBINFO  ccy_code          vegas xivegas_idx


}

#
# return the results of the query as a csv
#
proc ADMIN::XSYSSUB::go_sub_details_csv {} {
	global DB SUBINFO

	set xsys_sub_id [reqGetArg xsys_sub_id]

	set sql [subst {
		select
			s.cr_date as start_date,
			s.end_date,
			s.ext_sub_id,
			s.status,
			s.desc,
			h.name as sys_name,
			NVL(f.amount,0.0) as amount,
			NVL(f.held_amount,0.0) as held_amount,
			NVL(f.xfer_type,'') as xfer_type,
			NVL(f.cr_date,'') as cr_date,
			c.cust_id,
			c.username
		from
			tXSysSub s,
			tXSysHost h,
			outer tXSysSubXfer f,
			tAcct a,
			tCustomer c
		where
			s.xsys_sub_id = ? and
			s.system_id = h.system_id and
			f.xsys_sub_id = s.xsys_sub_id and
			s.acct_id = a.acct_id and
			a.cust_id = c.cust_id
	}]

	set stmt  [inf_prep_sql $DB $sql]
	set res   [inf_exec_stmt $stmt $xsys_sub_id]
	inf_close_stmt $stmt

	set headers [list "Start Date" "End Date" "External Sub Id" "Status" "Description" "System Name" "Amount" "Held Amount" "Transfer Type" "Creation Date" "Customer ID" "Username"]
	set columns [list start_date end_date ext_sub_id status desc sys_name amount held_amount xfer_type cr_date cust_id username]

	ob_log::write DEBUG {Doing CSV}
	build_csv_from_rs $headers $columns $res "subscriptions"

	db_close $res

}
