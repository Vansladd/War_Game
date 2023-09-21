# $Id: delay_script.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
set xtn  [lindex $argv 0]
set argv [lrange $argv 1 e]

source ../shared_tcl/standalone.$xtn
readConfig


package require OB_Log

source ../shared_tcl/err.$xtn
source ../shared_tcl/db.$xtn
source ../shared_tcl/tb_db.$xtn
source ../shared_tcl/util.$xtn
source ../shared_tcl/payment_CC.$xtn
source ../shared_tcl/payment_gateway.$xtn
source make_payment.$xtn
source ../shared_tcl/card_util.$xtn
source ../shared_tcl/marqisa.$xtn
source ../shared_tcl/build_xml.$xtn

if {[OT_CfgGet USE_DCASH_XML 0] == 1} {
	source ../shared_tcl/acct-dcash-xml.$xtn
} else {
	source ../shared_tcl/acct-dcash.$xtn
}

proc new_write args {

	global LOG

	switch -- [llength $args] {
		2 {
			foreach {level msg} $args {}
			if {[set level [_is_OKtoAdd $level $LOG(fd)]]} {
				OT_LogWrite $LOG(fd) $level [uplevel subst [list $msg]]
			}
		}
		3 {
			foreach {log_fd level msg} $args {}
			if {[set level [_is_OKtoAdd $level $log_fd]]} {
				OT_LogWrite $log_fd $level [uplevel subst [list $msg]]
			}
		}
		default {
			error "Usage: ob::log::write ?log? level message"
		}
	}
}

rename ob::log::write ob::log::__write
rename new_write ob::log::write

## overide reqGetEnv procedure
proc reqGetEnv {v} {
	switch $v {
		"REMOTE_ADDR" {
				return "194.100.1.90"
		}
	}
	return ""
}

set speed_restriction [OT_CfgGet WTD_DELAY_SPEED_LIMIT_MS 120000]

ob::log::write INFO {############################################################}
ob::log::write INFO {##################### Starting script ######################}

namespace import OB_db::*
db_init

set where {
	and
		p.cr_date < current - 5 units minute
	and
		p.cr_date > current - 3 units day
}

# If we are using this to process Mastercard payments
# that have been delayed because the customer was
# playing poker, the check when we can actually process
# the payment
if {[OT_CfgGet POKER_DELAY_WTD 0]} {
	set where {
	and
		p.delay_process_date < current
	}
}

# prepare sql
set main_sql {
	select
		min(pmt_id) pmt_id,
		p.acct_id
	from
		tPmt p,
		tCustPaymthd m
	where
		p.cpm_id = m.cpm_id
	and
		NVL(m.type,'') != 'OP'
	and
		p.payment_sort = 'W'
	and
		p.ref_key = 'CC'
	and
		p.status = 'P'
	$where
	group by
		p.acct_id
}

set total_num_pmts 0

# Now loop until we've processed all pending pmts
# (ie until the query returns 0 rows)
while {1} {

	set stmt [inf_prep_sql $DB [subst $main_sql]]

	set num_done 0

	ob::log::write INFO {Getting payments now...}
	if {[catch {set res [inf_exec_stmt $stmt]} msg]} {
		ob::log::write ERROR {error getting pending CC WTD payments: $msg}
	}

	set num_pending [db_get_nrows $res]

	if {$num_pending == 0} {
		ob::log::write INFO {Got 0 pending payments - stopping}
		break
	}

	ob::log::write INFO {Got $num_pending pending payments}

	for {set r 0} {$r < $num_pending} {incr r} {
		set pmt_id [db_get_col $res $r pmt_id]
		ob::log::write INFO {completing CC payment: $pmt_id}
		ADMIN::PMT::auth_payment_CC $pmt_id "Y" 1 ""
		incr num_done
	}
	db_close $res
	inf_close_stmt $stmt

	ob::log::write INFO {Completed $num_done payments}

	incr total_num_pmts $num_done

	# wait before looping thru again
	after $speed_restriction
}

ob::log::write INFO {Completed $total_num_pmts payments in total}

ob::log::write INFO {########################### Done ###########################}
ob::log::write INFO {############################################################}
