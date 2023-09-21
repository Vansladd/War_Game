# $Id: tb_call_record.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# =======================================================================
#
# Copyright (c) Orbis Technology 2004. All rights reserved.
#
#
# This file contains functions which are used to communicate
# openbet call information to call recording systems
#
# =======================================================================

namespace eval tb_call_record {

	namespace export witness_call_start
	namespace export witness_call_end

}

proc tb_call_record::witness_call_start {call_id ext_id} {

	# Message must start off with the length of the message (excluding the length itself)
	# Length must be padded with leading 0's - must be four digit
	# Extra \n is required.

	set witness_msg ",$ext_id,$call_id"
	set msglen [format "%04u" [string length $witness_msg]]
	set witness_msg "$msglen$witness_msg\n"

	if {[catch {set sock [socket_timeout [OT_CfgGet WITNESS_HOST] [OT_CfgGet WITNESS_PORT] [OT_CfgGet WITNESS_TIMEOUT 1000]]} err_msg]} {
		OT_LogWrite 5  "Failed to connect to witness server"
	}

	if {[catch {
		puts $sock $witness_msg
		# We can disgard the return from witness as they don't return anything
		set ret_list [read_timeout $sock [OT_CfgGet WITNESS_TIMEOUT 1000]]
	} err]} {
		OT_LogWrite 5  "Error writing to witness server"
	}

	catch {close $sock}

}


proc tb_call_record::witness_call_end {call_id {oper_id 1}} {

	OB_db::db_store_qry get_call_summary {
		select
			c.source,
			c.term_code,
			c.telephone,
			u.username,
			r.lname,
			r.code,
			t.username as operator_name,
			"" as bet_class,
			SUM(nvl(b.stake,0)) as totalstake
		from
			tCall c,
			tAcct a,
			tCustomer u,
			tCustomerReg r,
			tadminuser t,
			outer tbet b
		where
			c.acct_id = a.acct_id and
			r.cust_id = a.cust_id and
			b.call_id = c.call_id and
			u.cust_id = a.cust_id and
			t.user_id = ? and
			c.call_id = ?
		group by c.source, c.term_code,c.telephone,u.username,r.lname,r.code,t.username

		union

		select
			c.source,
			c.term_code,
			c.telephone,
			u.username,
			r.lname,
			r.code,
			t.username as operator_name,
			"pools" as bet_class,
			SUM(nvl(b.stake,0)) as totalstake
		from
			tCall c,
			tAcct a,
			tCustomer u,
			tCustomerReg r,
			tadminuser t,
			outer tpoolbet b
		where
			c.acct_id = a.acct_id and
			r.cust_id = a.cust_id and
			b.call_id = c.call_id and
			u.cust_id = a.cust_id and
			t.user_id = ? and
			c.call_id = ?
		group by c.source, c.term_code,c.telephone,u.username,r.lname,r.code,t.username

		union

		select
			c.source,
			c.term_code,
			c.telephone,
			u.username,
			r.lname,
			r.code,
			t.username as operator_name,
			"Lottery" as bet_class,
			SUM(nvl(b.stake_per_bet,0) * nvl(b.num_subs,1)) as totalstake
		from
			tCall c,
			tAcct a,
			tCustomer u,
			tCustomerReg r,
			tadminuser t,
			outer txgamesub b
		where
			c.acct_id = a.acct_id and
			r.cust_id = a.cust_id and
			b.call_id = c.call_id and
			u.cust_id = a.cust_id and
			t.user_id = ? and
			c.call_id = ?
		group by c.source, c.term_code,c.telephone,u.username,r.lname,r.code,t.username

	}

	OB_db::db_store_qry get_event_classes {
		select
			ec.name
			from
			tbet b,
			tobet o,
			tevoc eo,
			tev ev,
			tevclass ec
		where
			o.bet_id = b.bet_id and
			eo.ev_oc_id = o.ev_oc_id and
			ev.ev_id = eo.ev_id and
			ec.ev_class_id = ev.ev_class_id and
			b.call_id = ?
		group by
			ec.name
	}


	# Get the info we need for the call summary

	if {[catch {set crs [db_exec_qry get_call_summary $oper_id $call_id $oper_id $call_id $oper_id $call_id]} msg]} {
		OT_LogWrite 2 "failed to obtain call summary info: $msg"
	} else {
		set nrows [db_get_nrows $crs]
		set totalstake 0
		set bc1 ""
		set bc2 ""
		set bc3 ""

		if {$nrows != 0} {
			set term_id [db_get_col $crs 0 term_code]
			set source [db_get_col $crs 0 source]
			set ext_id [db_get_col $crs 0 telephone]
			set cust_id [db_get_col $crs 0 username]
			set surname [db_get_col $crs 0 lname]
			set group [db_get_col $crs 0 code]
			set operator_name [db_get_col $crs 0 operator_name]

			for {set i 0} {$i < $nrows} {incr i} {
				set totalstake [expr {$totalstake + [db_get_col $crs $i totalstake]}]
				if { [db_get_col $crs $i totalstake] > 0} {
					set bet_class [db_get_col $crs $i bet_class]
					if {$bet_class != ""} {
						set bc3 $bc2
						set bc2 $bc1
						set bc1 $bet_class
					} else {
						if {[catch {set ers [db_exec_qry get_event_classes $call_id]} msg]} {
						OT_LogWrite 2 "failed to obtain event classes: $msg"
						} else {
							set nrows2 [db_get_nrows $ers]
							for {set j 0} {$j < $nrows2} {incr j} {
								set bet_class [db_get_col $ers $j name]
								if {$bet_class != $bc1 && $bet_class != $bc2} {
									set bc3 $bc2
									set bc2 $bc1
									set bc1 $bet_class
								}
							}
						db_close $ers
						}
					}
				}
			}


			# Message must start off with the length of the message (excluding the length itself)
			# Length must be padded with leading 0's - must be four digit
			# Extra \n is required.

			set witness_msg ",$ext_id,$term_id,$call_id,$cust_id,$surname,$group,$source,$operator_name,$totalstake,$bc1,$bc2,$bc3"
			set msglen [format "%04u" [string length $witness_msg]]
			set witness_msg "$msglen$witness_msg\n"

			OT_LogWrite 4 "Call summary message: $witness_msg"

			if {[catch {set sock [socket_timeout [OT_CfgGet WITNESS_HOST] [OT_CfgGet WITNESS_PORT] [OT_CfgGet WITNESS_TIMEOUT 1000]]} err_msg]} {
				OT_LogWrite 5  "Failed to connect to witness server"
			}

			if {[catch {
				puts $sock $witness_msg
				# We can disgard the return from witness
				set ret_list [read_timeout $sock [OT_CfgGet WITNESS_TIMEOUT 1000]]
			} err]} {
				OT_LogWrite 5  "Error writing to witness server"
			}
			catch {close $sock}
		}
	db_close $crs
	}
}

