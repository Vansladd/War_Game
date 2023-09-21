# $Id: pay_mthd.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C)2006 Orbis Technology Ltd. All rights reserved.
#
# File for updating payment method via the admin screens.
#
# Configuration:
#   FUNC_MENU_PAY_METHODS = 1
#
# Permission:
#   ManagePayMthd
#



# Variables
#
namespace eval ADMIN::PAY_MTHD {
	asSetAct ADMIN::PAY_MTHD::go_pay_mthds [namespace code go_pay_mthds]
	asSetAct ADMIN::PAY_MTHD::go_pay_mthd  [namespace code go_pay_mthd]
	asSetAct ADMIN::PAY_MTHD::do_pay_mthd  [namespace code do_pay_mthd]

	variable CONF

	foreach pmt_mthd_setting [OT_CfgGet PMT_MTHD_FIELDS_EDITABLE] {
		foreach {pay_mthd fields} $pmt_mthd_setting {}
		set CONF($pay_mthd,editables) $fields
	}
}


# Show payment methods.
#
proc ADMIN::PAY_MTHD::go_pay_mthds {} {

	global PAY_MTHDS

	array unset PAY_MTHDS

	if {![op_allowed ManagePayMthd]} {
		error "You do not have permission to do this"
	}

	set sql {
		select
			*
		from
			tPayMthd    m,
		outer
			tPayMthdChq q
		where
			m.pay_mthd = q.pay_mthd
		order by
			m.pay_mthd
	}

	set stmt [inf_prep_sql $::DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		foreach n $colnames {
			set PAY_MTHDS($r,$n) [db_get_col $rs $r $n]
		}
	}


	db_close $rs

	tpSetVar nrows $nrows

	foreach n $colnames {
		tpBindVar $n PAY_MTHDS $n idx
	}

	asPlayFile -nocache pay_mthds.html
}


# Show a single payment method.
#
proc ADMIN::PAY_MTHD::go_pay_mthd {} {

	variable CONF

	if {![op_allowed ManagePayMthd]} {
		error "You do not have permission to do this"
	}

	set pay_mthd [reqGetArg pay_mthd]

	set sql {
		select
			*
		from
			tPayMthd    m,
		outer
			tPayMthdChq q
		where
			m.pay_mthd = q.pay_mthd
		and m.pay_mthd = ?
		order by
			m.pay_mthd
	}

	set stmt [inf_prep_sql $::DB $sql]
	set rs [inf_exec_stmt $stmt $pay_mthd]
	inf_close_stmt $stmt

	set colnames [db_get_colnames $rs]

	foreach n $colnames {
		tpBindString $n [db_get_col $rs 0 $n]
	}

	db_close $rs

	if {[info exists CONF($pay_mthd,editables)]} {
		tpSetVar update_mthd 1
	}

	if {[info exists CONF($pay_mthd,editables)]} {
		foreach f $CONF($pay_mthd,editables) {
			switch -exact $f {
				"cancel_pending" {
					tpSetVar update_pending 1
				}
				"wtd_batch_time" {
					tpSetVar update_batch_time 1
				}
				"wtd_we_batch_time" {
					tpSetVar update_we_batch_time 1
				}
				"wtd_deferred_to" {
					tpSetVar update_defer_to 1
				}
				"wtd_delay_mins" {
					tpSetVar update_fraud_delay_mins 1
				}
				"deposit_check" {
					tpSetVar update_deposit_check 1
				}
			}
		}
	}

	asPlayFile -nocache pay_mthd.html
}


# Update a payment method.
#
# This is a bit of a stubb of an action, and will only allow you to update
# the cheque part of the payment method.
#
proc ADMIN::PAY_MTHD::do_pay_mthd {} {

	variable CONF

	if {![op_allowed ManagePayMthd]} {
		error "You do not have permission to do this"
	}

	set pay_mthd       [reqGetArg pay_mthd]
	set chq_no         [reqGetArg chq_no]
	set max_chq_no     [reqGetArg max_chq_no]
	set max_chq_no_amt [reqGetArg max_chq_no_amt]
	set submit         [reqGetArg submit]
	set cancel_pending [reqGetArg cancel_pending]
	set deposit_check  [reqGetArg deposit_check]

	switch $submit {
		"Update" {
			if {[info exists chq_no] && [string length $chq_no]} {
				set sql {
					update tPayMthdChq set chq_no = ?, max_chq_no = ?,
						max_chq_no_amt = ? where pay_mthd = ?
				}

				set stmt [inf_prep_sql $::DB $sql]

				inf_exec_stmt $stmt $chq_no $max_chq_no $max_chq_no_amt $pay_mthd

				set nrows [inf_get_row_count $stmt]

				inf_close_stmt $stmt

				# If no rows are affected, then we need to insert one.
				#
				if {$nrows == 0} {

					set sql {
						insert into tPayMthdChq (
							pay_mthd, chq_no, max_chq_no, max_chq_no_amt
						) values (
							?, ?, ?, ?
						)
					}

					set stmt [inf_prep_sql $::DB $sql]

					inf_exec_stmt $stmt $pay_mthd $chq_no $max_chq_no \
						$max_chq_no_amt

					inf_close_stmt $stmt
				}
			}

			set sql_upd_pay_mthd {
				update tPayMthd
					set $sql_set
				where
					pay_mthd = '$pay_mthd'
			}

			set sql_set_list [list]
			set bad 0
			if {[info exists CONF($pay_mthd,editables)]} {
				foreach f $CONF($pay_mthd,editables) {

					set val [reqGetArg $f]
					set update_field 1

					# do some validation
					switch -exact $f {
						"wtd_batch_time" -
						"wtd_we_batch_time" {
							# check batch_time is in correct format.
							if {![regexp {^$|[0-2]\d(:[0-5]\d){2}$} $val]} {
								set update_field 0
								set bad 1
								err_bind "Invalid time format"
							}
						}
						"wtd_deferred_to" {
							if {![regexp {^$|(\d){4}-[0-1]\d-[0-3]\d$} $val]} {
								set update_field 0
								set bad 1
								err_bind "Invalid date format"
							}
						}
					}

					if {$update_field} {
						lappend sql_set_list "$f = '$val'"
					}
				}
			}

			if {[llength $sql_set_list]} {

				set sql_set [join $sql_set_list " , "]

				set stmt [inf_prep_sql $::DB [subst $sql_upd_pay_mthd]]
				inf_exec_stmt $stmt
				inf_close_stmt $stmt
			}
			if {!$bad} {
				msg_bind "Updated payment method"
			}
		}
		default {
			error "Unknown submit"
		}
	}

	go_pay_mthd
}
