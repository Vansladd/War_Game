# ==============================================================
# $Id: pmt_basc.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc ADMIN::PMT::do_pay_mthd_pmt_BASC {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id       [reqGetArg cpm_id]
	set uid          [reqGetArg uniqueId]
	set cust_id      [reqGetArg CustId]
	set ip           [reqGetEnv REMOTE_ADDR]
	set amount       [reqGetArg Amount]
	set type         [reqGetArg DepWtd]
	set location     [reqGetArg location]
	set ref_number   [reqGetArg ref_number]

	#
	# get acct_id, and currency code
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		go_pay_mthd_pmt [reqGetArg DepWtd]
		return
	}

	if {$type == "WTD"} {
		set pay_sort W

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg wtd_charge]

		# if withdrawal remember that money has not yet been transferred
		set is_pmt_done 0
	} else {
		set pay_sort D

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg dep_charge]

		# if deposit remember that money has been transferred
		set is_pmt_done 1
	}

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {
		#
		# first get the currency to calc commmission
		#
		set ccy_code [getCcyCode $cust_id]
	
		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission BASC {} $ccy_code $pay_sort $amount $is_pmt_done]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set amount      [lindex $comm_list 1]
		set tPmt_amount [lindex $comm_list 2]

		#
		# override the min/max amount
		#
		set min_amt   $tPmt_amount
		set max_amt   $amount

	} else {
	    
	    	set commission  0.0
		set tPmt_amount $amount
		
		#
		# override the min/max amount
		#
		set min_amt   $amount
		set max_amt   $amount
	}

	#
	# attempt to make the payment
	#
	set result [insert_payment_BASC $acct_id \
	                $cpm_id \
	                $pay_sort \
	                $amount \
	                $commission \
	                $ip \
	                $USERID \
	                $uid \
	                $location \
	                $ref_number \
	                $tPmt_amount \
	                $min_amt \
	                $max_amt]

	#
	# process the result
	#
	if {[lindex $result 0]} {
		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		# Check whether the payment should be automatically authorised or not
		set sql [subst {
			select
				i.auto_auth_[string tolower $type]
			from
				tBasicPayInfo i,
				tCPMBasic b
			where
				i.basic_info_id = b.basic_info_id and
				b.cpm_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cpm_id]
		inf_close_stmt $stmt

		if {[db_get_coln $res 0 0] == "Y"} {
			set result [auth_payment_BASC $pmt_id "Y" $USERID NULL]

			if {$result != "OK"} {
				error "failed to authorise payment"
				go_pay_mthd_auth
				return
			}
		}

		if {[lindex $pmt_detail 0] == "W"} {
			set prefix "withdrawn from"
		} elseif {[lindex $pmt_detail 0] == "D"} {
			set prefix "deposited into"
		} else {
			error "failed to retrieve payment id from payment table"
		}
		msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully $prefix the users account"

		go_pay_mthd_auth
	} else {
		rebind_request_data
		err_bind "[lindex $result 1]"
		go_pay_mthd_pmt [reqGetArg DepWtd]
	}
}

proc ADMIN::PMT::send_basic_payment_email {pmt_id} {
	global DB PAYMTHD LOGIN_DETAILS

	# Get customer details
	set sql {
		select
			r.email,
			r.title,
			r.fname,
			r.lname,
			c.lang,
			l.charset,
			i.name,
			i.deposit_email,
			i.withdrawal_email,
			p.payment_sort,
			p.amount
		from
			tCustomerReg r,
			tCustomer c,
			tLang l,
			tBasicPayInfo i,
			tCPMBasic b,
			tPmt p
		where
			contact_how like "%E%" and
			p.pmt_id = ? and
			b.cpm_id = p.cpm_id and
			c.cust_id = b.cust_id and
			r.cust_id = b.cust_id and
			l.lang = c.lang and
			i.basic_info_id = b.basic_info_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	# Check if they want to be contacted
	if {[db_get_nrows $res] != 1} {
		ob::log::write INFO {Email: Not sent: Customer does not wish to be emailed}
		return
	}

	set method [db_get_col $res 0 payment_sort]

	# Check if an email should be sent for this Agent
	if {$method == "D" && [db_get_col $res 0 deposit_email] == "N"} {
		ob::log::write INFO {Email: Not sent: No deposit emails are to be sent for this agent}
		return
	} elseif {$method == "W" && [db_get_col $res 0 withdrawal_email] == "N"} {
		ob::log::write INFO {Email: Not sent: No withdrawal emails are to be sent for this agent}
		return
	} elseif {$method != "W" && $method != "D"} {
		ob::log::write ERROR {Email: Not sent: method set to $method and should be W or D}
		error "Error in sending email - invalid value for method $method"
	}

	set email_address               [db_get_col $res 0 email]
	set title                       [db_get_col $res 0 title]
	set fname                       [db_get_col $res 0 fname]
	set lname                       [db_get_col $res 0 lname]

	# Check if they have an email address set
	if {$email_address == ""} {
		ob::log::write INFO {Email: Not sent: Customer has not entered an email address}
		return
	}

	# Bind default things to be used in the emails
	tpBindString FullName         "$title $fname $lname"
	tpBindString Amount           [db_get_col $res 0 amount]

	# Strip spaces out of the agent's name for the directory
	set agent                     [db_get_col $res 0 name]
	regsub -all -- { } $agent {} agent_dir_name

	set to                        $email_address
	set lang                      [db_get_col $res 0 lang]
	set charset                   [db_get_col $res 0 charset]

	set replyto                   [ADMIN::XLATE::get_translation $lang EMAIL_BASICPAY_FROM]
	set subject                   [ADMIN::XLATE::get_translation $lang EMAIL_BASICPAY_${method}_SUBJECT]
	set body                      [w__asPlayFile -nocache -tostring "pmt/basic_payment/${agent_dir_name}/email_${method}_${lang}.html"]

	# Check whether we have that language or not and if not, default to english
	if {[string length [lindex $body 0]] == 0} {
		ob::log::write INFO {no email available for language $lang - falling back to en}
		set body                  [w__asPlayFile -nocache -tostring "pmt/basic_payment/${agent_dir_name}/email_${method}_en.html"]
		set replyto               [ADMIN::XLATE::get_translation en EMAIL_BASICPAY_FROM]
		set subject               [ADMIN::XLATE::get_translation en EMAIL_BASICPAY_${method}_SUBJECT]
	}

	set from                      [OT_CfgGet SMTP_USER $replyto]

	if {[catch {
		ADMIN::EMAIL::send_email $from $to $replyto $subject $body $charset html 1
	} msg]} {
		# Email was unsuccessful
		ob::log::write ERROR {Unable to send email: $msg}
		error "$msg"
	} else {
		ob::log::write DEBUG {email successfully sent to $to}
	}
}

#
# Get the list of basic agents
#
proc ADMIN::PMT::get_basc_agents {} {
	global DB Basic_Agent

	# Basic Pay: Make a list of agents to be displayed
	set sql [subst {
		select
			basic_info_id,
			name
		from
			tBasicPayInfo i
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	ob::log::write INFO {Binding Agents}

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {
		ob::log::write INFO {  - [db_get_col $res $r basic_info_id] : [db_get_col $res $r name]}
		set Basic_Agent($r,agent_id)   [db_get_col $res $r basic_info_id]
		set Basic_Agent($r,agent_name) [db_get_col $res $r name]
	}
	set Basic_Agent(nrows) [db_get_nrows $res]
	db_close $res
}
