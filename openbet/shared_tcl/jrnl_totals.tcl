# ==============================================================
# $Id: jrnl_totals.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval jrnl_totals {

	namespace export calculate
	namespace export bind_pos_neg_and_colour_totals
	namespace export get
	namespace export yearly_totals
	namespace export unset_totals
	namespace export unset_all

}


#
# If you are going to include the call to wagerworks oxi to get
# the detailed information, using ww_casino_oxi_totals, you should do
# that before calling this

# Note that we use the variable STATUS to create the state for the data
# structures to avoid having to repeat work, when used in conjunction
# with consecutive jrnl_totals::get calls that relate to the batch of
# totals for a given customer.
#
proc jrnl_totals::calculate {acct_id {from_year ""} {to_year ""}} {

	global DB

	variable STATUS
	variable JRNL_TOTALS

	if {![info exists STATUS(acct_id)]     || \
	      $acct_id   != $STATUS(acct_id)   || \
	      $from_year != $STATUS(from_year) || \
	      $to_year   != $STATUS(to_year)} {
		jrnl_totals::unset_totals
	}

	if {[info exists STATUS(calculated)]} {
		OT_LogWrite 10 {jrnl_totals::calculate : already calculated this permutation}
		return 1
	}

	set STATUS(acct_id)   $acct_id
	set STATUS(from_year) $from_year
	set STATUS(to_year)   $to_year

	set totals_list [list "sb_stake"           \
						  "sb_open_stake"      \
						  "sb_cancel"          \
						  "sb_winnings"        \
						  "sb_refunds"         \
						  "sb_unsettled_wins"  \
						  "sb_unsettled_rfds"  \
						  "bet_corrections"    \
						  "bonus"              \
					          "sb_num_bets"]

	# Forced to use primitive inf commands to allow use in dbv and admin.
	if {$from_year == "" } {
		# Use 1970 as epoch
		set from_year "1970"
	}
	if {$to_year == "" } {
		set to_year [clock format [clock seconds] -format "%Y"]
	}

	OT_LogWrite 10 "jrnl_totals::calculate acct_id:$acct_id, from_year:$from_year, to_year:$to_year"

	set sql [subst {
		execute procedure pGetJrnlSummary (
			p_acct_id        = ?,
			p_jrnl_year_from = ?,
			p_jrnl_year_to   = ?
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set tot_rs [inf_exec_stmt $stmt $acct_id $from_year $to_year] } msg]} {
		OT_LogWrite 1 "jrnl_totals::calculate ERROR EXECUTING pb_get_jrnl_totals : $msg"
		return ""
	}

	# We should always get one row, even if its all zeros.
	if {[db_get_nrows $tot_rs] != 1} {
		OT_LogWrite 1 "jrnl_totals::calculate ERROR  pb_get_jrnl_totals did not return 1 row"
	} else {

		set first [db_get_coln $tot_rs 0 0]

		set idx 0

		# This loop relies on totals_list aligning with the returned values
		# from pGetJrnlTotals - beware of this when altering either.

		foreach total $totals_list {
			set JRNL_TOTALS($total) [db_get_coln $tot_rs 0 $idx]
			OT_LogWrite 50 "jrnl_totals::calculate setting JRNL_TOTALS($total) $JRNL_TOTALS($total) "
			incr idx
		}
	}

	# Tidy up this result set
	inf_close_stmt $stmt
	db_close       $tot_rs


	# get maximum sportsbook stake
	set sql [subst {
		execute procedure pGetJrnlMax (
			p_acct_id        = ?,
			p_j_op_type      = "BSTK",
			p_j_op_ref_key   = "ESB",
			p_jrnl_year_from = ?,
			p_jrnl_year_to   = ?
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set max_rs [inf_exec_stmt $stmt $acct_id $from_year $to_year]
	} msg]} {
		OT_LogWrite 1 "jrnl_totals::calculate ERROR EXECUTING pgetjrnlmax: $msg"
		return ""
	}

	# We should always get one row, even if its all zeros.
	if {[db_get_nrows $max_rs] != 1} {
		OT_LogWrite 1 "jrnl_totals::calculate ERROR pgetjrnlmax did not return 1 row"
	} else {
		set JRNL_TOTALS(sb_maxstake) [expr {abs([db_get_coln $max_rs 0 0])}]
	}

	# Tidy up this result set
	inf_close_stmt $stmt
	db_close       $max_rs


	# Calculate total profits, averages and so on ...
	populate_computed_totals $acct_id

	# Get the cr_date for the customer's last transaction
	# in tJrnl

	if {[OT_CfgGet DO_LAST_TRANS_DATE "N"] == "Y"} {
		last_journal_transaction $acct_id
	}

	set STATUS(calculated) 1

	return 1
}


proc jrnl_totals::last_journal_transaction {acct_id} {

	variable STATUS
	variable JRNL_TOTALS

	global DB

	OT_LogWrite 50 "jrnl_totals::last_journal_transaction IN (acct_id:$acct_id)"

	set sql [subst {
		select max(cr_date) from tjrnl where acct_id = ?
	}]


	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set cr_rs [inf_exec_stmt $stmt $acct_id] } msg]} {
		OT_LogWrite 1  {ERROR Retrieving max journal date : $msg}
		return ""
	}

	if {[db_get_nrows $cr_rs] == 1} {
		set JRNL_TOTALS(last_trans_date) [db_get_coln $cr_rs 0 0]
		OT_LogWrite 15  {Last transaction time retrieved : $JRNL_TOTALS(last_trans_date)}
	} else {
		OT_LogWrite 15  {No rows returned for finding customer's last transaction}
	}

	inf_close_stmt $stmt
	db_close $cr_rs

	return 1
}

#
# Insert calls to this procedure in this file to dump the contents of
# JRNL_TOTALS to the log at various stages
#
proc jrnl_totals::debug_totals {} {

	variable JRNL_TOTALS

	OT_LogWrite 50 "DEBUG : IN jrnl_totals::debug_totals "

	foreach name [lsort [array names JRNL_TOTALS]] {
		OT_LogWrite 50 "DEBUG : JRNL_TOTALS($name)=$JRNL_TOTALS($name) "
	}

}

# Some of the totals displayed are the result of result
proc jrnl_totals::populate_computed_totals {acct_id} {

	variable JRNL_TOTALS

	#------------------------
	# Sportsbook
	#------------------------

	if {$JRNL_TOTALS(sb_num_bets) == 0} {
		set JRNL_TOTALS(sb_average) 0.00
	} else {
		set JRNL_TOTALS(sb_average) [format "%0.2f" [expr {$JRNL_TOTALS(sb_stake) / \
		                                                   $JRNL_TOTALS(sb_num_bets)}]]
	}

	set JRNL_TOTALS(sb_profit) [format "%0.2f" [expr {\
		                                 $JRNL_TOTALS(sb_stake)          -\
		                                 $JRNL_TOTALS(sb_open_stake)     +\
		                                 $JRNL_TOTALS(sb_winnings)       +\
		                                 $JRNL_TOTALS(sb_refunds)        +\
		                                 $JRNL_TOTALS(sb_cancel)         +\
		                                 $JRNL_TOTALS(sb_unsettled_wins) +\
		                                 $JRNL_TOTALS(sb_unsettled_rfds) +\
		                                 $JRNL_TOTALS(bet_corrections)   +\
		                                 $JRNL_TOTALS(bonus)} ]]

	set JRNL_TOTALS(sb_gross_winnings) [format "%0.2f" [expr {\
	                                     $JRNL_TOTALS(sb_winnings) +\
	                                     $JRNL_TOTALS(sb_unsettled_wins)}]]

	set JRNL_TOTALS(sb_gross_refunds) [format "%0.2f" [expr {\
	                                     $JRNL_TOTALS(sb_refunds) +\
	                                     $JRNL_TOTALS(sb_unsettled_rfds)}]]


	# Grand Totals
	# So far we're only dealing with sb but these totals can be extended later
	# to include games/poker/etc.

	set JRNL_TOTALS(total_stake)     [format "%0.2f" $JRNL_TOTALS(sb_stake)]

	set JRNL_TOTALS(total_winnings)  $JRNL_TOTALS(sb_winnings)

	set JRNL_TOTALS(total_gross_winnings) [format "%0.2f"\
		       [expr {$JRNL_TOTALS(total_winnings)   +\
		              $JRNL_TOTALS(sb_unsettled_wins)}]]

	# format total winnings
	set JRNL_TOTALS(total_winnings) [format "%0.2f"\
	                  $JRNL_TOTALS(total_winnings)]

	set JRNL_TOTALS(total_refunds) [expr {\
		              $JRNL_TOTALS(sb_cancel)     +\
		              $JRNL_TOTALS(sb_refunds)}]

	set JRNL_TOTALS(total_gross_refunds) [format "%0.2f"\
		       [expr {$JRNL_TOTALS(total_refunds)   +\
		              $JRNL_TOTALS(sb_unsettled_rfds)}]]

	# format total refunds
	set JRNL_TOTALS(total_refunds) [format "%0.2f"\
	                  $JRNL_TOTALS(total_refunds)]

	# Total Profit. This will be reversed so that is from the bookmakers perspective
	# So far just the sb. We can add games/poker/etc functionality later.

	set JRNL_TOTALS(total_profit)        [format "%0.2f" $JRNL_TOTALS(sb_profit)]

	# Customers profit is from the customers point of few
	# So far just the sb. We can add games/poker/etc functionality later.

	set JRNL_TOTALS(customers_profit)    [format "%0.2f" $JRNL_TOTALS(sb_profit)]

	set JRNL_TOTALS(total_bet_count)     $JRNL_TOTALS(sb_num_bets)


	if {[OT_CfgGet DO_TOTAL_AVG_STAKE "N"] == "Y"} {
		# Final average
		# =============
		if {$JRNL_TOTALS(total_stake) > 0 && $JRNL_TOTALS(total_bet_count) > 0} {
			set JRNL_TOTALS(total_average) [expr {$JRNL_TOTALS(total_stake) / $JRNL_TOTALS(total_bet_count)}]
		} else {
			set JRNL_TOTALS(total_average) 0
		}
	}


}


proc jrnl_totals::bind_pos_neg_and_colour_totals {acct_id} {

	variable STATUS

	OT_LogWrite 10 "jrnl_totals::bind_pos_neg_and_colour_totals : Binding data"

	if {![info exists STATUS(acct_id)] || $acct_id != $STATUS(acct_id)} {
		jrnl_totals::unset_totals
		jrnl_totals::calculate $acct_id
	} elseif {![info exists STATUS(calculated)]} {
		jrnl_totals::calculate $acct_id
	}

	# Adjust positive and negative signs for display purposes
	jrnl_totals::pos_neg_abs

	# Add red/green tint for certain figures
	jrnl_totals::green_red_colour

	# Do the binding
	jrnl_totals::bind_totals
}

# Before we release the customer totals to be bound we need to adjust the figures so
# that they are positive or negative, FROM THE BOOKMAKERS PERSPECTIVE for displaying
# in the dbv and admin only

proc jrnl_totals::pos_neg_abs {} {

	variable JRNL_TOTALS

	OT_LogWrite 50 "jrnl_totals::pos_neg_abs : DEBUG : IN "

	# Reverse all the profits, and totalled profits

	foreach name [list         \
		"sb_profit"            \
		"total_profit"         \
		"sb_stake"             \
		"sb_open_stake"        \
		"sb_unsettled_wins"    \
		"sb_unsettled_rfds"    \
		"total_stake"          \
		"sb_average"] {

		if {[info exists JRNL_TOTALS($name)]          && \
			![info exists JRNL_TOTALS($name,altered)] && \
			$JRNL_TOTALS($name) != 0                  && \
			$JRNL_TOTALS($name) != "ERROR"            && \
			$JRNL_TOTALS($name) != "" } {

			OT_LogWrite 50 "jrnl_totals::pos_neg_abs DEBUG : swapping JRNL_TOTALS($name) "

			set JRNL_TOTALS($name) [eval format "%0.2f" [expr {$JRNL_TOTALS($name) * -1}]]
			set JRNL_TOTALS($name,altered) 1
		}
	}

	# Absolute value the bet corrections

	if {[info exists JRNL_TOTALS(bet_corrections)] && ![info exists JRNL_TOTALS(bet_corrections,altered)]} {
		OT_LogWrite 50 "jrnl_totals::pos_neg_abs DEBUG : abs JRNL_TOTALS($name) "
		set JRNL_TOTALS(bet_corrections) [eval format "%0.2f" [expr abs($JRNL_TOTALS(bet_corrections))]]
		set JRNL_TOTALS(bet_corrections,altered) 1
	}
}

proc jrnl_totals::green_red_colour {} {

	variable JRNL_TOTALS

	OT_LogWrite 50 "DEBUG : IN jrnl_totals::green_red_colour "

	# Positive is green, negative is red
	foreach name [list "total_profit" "sb_profit"] {
		if {[info exists JRNL_TOTALS($name)]} {
			set JRNL_TOTALS($name,colour) 1
		}
	}

}



#
# This procedure will take the contents of the JRNL_TOTALS
# and bind it to capitalised version of the variable name,
#
# i.e. JRNL_TOTALS(something) is bound as JRNL_TOTALS_SOMETHING
#
# Furthermore, if the  JRNL_TOTALS(something,colour) is set then
# the value will be bound up to a green for positive and red for
# negative colours
#
proc jrnl_totals::bind_totals {} {

	OT_LogWrite 50 "jrnl_totals::bind_totals :IN"

	variable JRNL_TOTALS

	foreach name [lsort [array names JRNL_TOTALS]] {

		set title [string toupper $name]

		if {[info exists JRNL_TOTALS($name,colour)]} {
			OT_LogWrite 50 "jrnl_totals::bind_totals JRNL_TOTALS($name,colour) found colored "
			tpBindString JRNL_TOTALS_${title} [colour $JRNL_TOTALS($name)]
		} else {
			# Do a regular bind
			tpBindString JRNL_TOTALS_${title}  "$JRNL_TOTALS($name)"
		}

		OT_LogWrite 50 "jrnl_totals::bind_totals : Binding JRNL_TOTALS_${title}"
	}
}

#
# Add red or green font tags to a string depending on value
#
proc jrnl_totals::colour {value} {

	if {$value > 0} {
		return  "<font color=\"green\">$value</font>"
	} elseif {$value < 0} {
		return  "<font color=\"red\">$value</font>"
	} else {
		return  "$value"
	}

}


#
# This can be called from any code and it will trigger the corresponding
# execution of pGetJrnlTotals, and the results will populate the variable
# JRNL_TOTALS structure.
#
# Subsenquent calls to this procedure within the same call will not incur
# another call to the stored procedure because state is held in ::calculate,
# provided the acct_id and year range do not change.
#
proc jrnl_totals::get {acct_id field {from_year ""} {to_year ""}} {

	variable STATUS
	variable JRNL_TOTALS

	if {![info exists STATUS(calculated)]} {
		OT_LogWrite 50 {in get - not calculated yet}
		jrnl_totals::calculate $acct_id $from_year $to_year
	}

	if {[info exists JRNL_TOTALS($field)]} {
		OT_LogWrite 10 "jrnl_totals::get JRNL_TOTALS($field) found"
		return $JRNL_TOTALS($field)
	} else {
		OT_LogWrite 5 "jrnl_totals::get JRNL_TOTALS($field) does not exist"
		return 0.00
	}

}

proc jrnl_totals::unset_totals {} {

	variable STATUS
	variable JRNL_TOTALS

	OT_LogWrite 50 {jrnl_totals::unset_totals Unsetting journal totals}

	catch {unset STATUS(calculated)}
	catch {unset STATUS(acct_id)}
	catch {unset STATUS(from_year)}
	catch {unset STATUS(to_year)}

	catch {unset JRNL_TOTALS}
}

proc jrnl_totals::unset_all {} {

	variable STATUS
	variable JRNL_TOTALS

	OT_LogWrite 50 {jrnl_totals::unset_all Unsetting journal totals data}

	catch {unset STATUS}
	catch {unset JRNL_TOTALS}

}
