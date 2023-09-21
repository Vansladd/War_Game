# ==============================================================
# $Id: earthport.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2002 Orbis Technology Ltd. All rights reserved.
# ==============================================================

package require SOAP
package require util_appcontrol

namespace eval earthport {

	namespace export registerEarthportAcc
	namespace export payout_request
	namespace export deposit_request
	namespace export get_ep_account
	namespace export close_account_req
	namespace export associate_account_req
	namespace export change_bank_details

	# soap request procs
	variable NEW_ACCOUNT_REQ
	variable PAYOUT_REQ
	variable VIEW_TRADE_REQ
	variable CLOSE_ACC_REQ
	variable ASSOCIATE_ACC_REQ
	variable CHANGE_BANK_DETAILS_REQ

	# have the queries been initialised?
	variable INITIALISED
	set INITIALISED 0


	# =================================================================
	# Proc        : init_earthport
	# Description : only runs initialisation procedue if necessary
	# Author      : sluke
	# =================================================================
	proc init_earthport {} {
		variable INITIALISED
		if {$INITIALISED} {return}
		package require OB_Log
		create_soap
		prep_qrys
		set INITIALISED 1
	}


	# =================================================================
	# Proc        : create_soap
	# Description : prepares soap requests
	# Author      : sluke
	# =================================================================
	proc create_soap {} {
		variable NEW_ACCOUNT_REQ
		variable PAYOUT_REQ
		variable VIEW_TRADE_REQ
		variable CLOSE_ACC_REQ
		variable ASSOCIATE_ACC_REQ
		variable CHANGE_BANK_DETAILS_REQ

		set NEW_ACCOUNT_REQ [SOAP::create NewAccount \
					-uri    "urn:Gaming.AccountMgr" \
					-proxy  [OT_CfgGet EARTHPORT_PROXY] \
					-params {ExtID           string \
							 Description     string \
							 Country         string \
							 AccountCurrency string \
							 BankCurrency    string \
							 Bankname        string \
							 AccountName     string \
							 AccountNum      string \
							 Banksort        string \
							 Bankcode        string \
							 Bankkey         string \
							 Holding         string \
							 BranchCode      string \
							 Type            string \
							 Routing         string}]

		set PAYOUT_REQ      [SOAP::create Payout \
					-uri    "urn:Gaming.AccountMgr" \
					-proxy  [OT_CfgGet EARTHPORT_PROXY] \
					-params {VAN             long \
							 ExtID           string \
							 Amount          double \
							 Currency        string}]

		set VIEW_TRADE_REQ  [SOAP::create ViewTrade \
					-uri    "urn:Gaming.AccountMgr" \
					-proxy  [OT_CfgGet EARTHPORT_PROXY] \
					-params {TradeID        long}]

	   	set CLOSE_ACC_REQ   [SOAP::create CloseAccount \
					-uri    "urn:Gaming.AccountMgr" \
					-proxy  [OT_CfgGet EARTHPORT_PROXY] \
					-params {VAN             long}]

		set ASSOCIATE_ACC_REQ [SOAP::create AssociateAccounts \
					-uri    "urn:Gaming.AccountMgr" \
					-proxy  [OT_CfgGet EARTHPORT_PROXY] \
		   		 	-params {OldVan          long \
							 NewVan          long}]

		set CHANGE_BANK_DETAILS_REQ [SOAP::create ChangeBankDetails \
					-uri    "urn:Gaming.AccountMgr" \
					-proxy  [OT_CfgGet EARTHPORT_PROXY] \
					-params {VAN              long \
							 Description      string \
							 Country          string \
				 			 BankCurrency     string \
				 			 Bankname         string \
				 			 AccountName      string \
				 			 AccountNum       string \
				 			 Banksort         string \
				 			 Bankcode         string \
				 			 Bankkey          string \
				 			 Holding          string \
				 			 BranchCode       string \
				 			 Type             string \
				 			 Routing          string}]

		SOAP::configure -transport http -timeout [OT_CfgGet EARTHPORT_TIMEOUT] -headers {"Content-Type" "text/xml; charset=\"utf-8\""}
	}


	# =================================================================
	# Proc        : prep_qrys
	# Description : Prepares DB queries
	# Author      : sluke
	# =================================================================
	proc prep_qrys {} {

		global SHARED_SQL

		set SHARED_SQL(earth.get_user_details) {
			select
				c.username,
				r.lname,
				r.fname,
				l.charset
			from
				tcustomer c,
				tcustomerreg r,
				tlang l
			where
				c.cust_id = ?
			and c.cust_id = r.cust_id
			and c.lang = l.lang
		}

		set SHARED_SQL(earth.new_account) {
			execute procedure pCPMInsEP (
				p_cust_id       = ?,
				p_oper_id       = ?,
				p_auth_wtd		= ?,
				p_oper_notes    = ?,
				p_transactional = ?,
				p_cropped_VAN   = ?,
				p_earthport_VAN = ?,
				p_description   = ?,
				p_country       = ?,
				p_ac_ccy        = ?,
				p_bank_ccy      = ?,
				p_bank_name     = ?,
				p_bank_code     = ?,
				p_ac_name       = ?,
				p_ac_num        = ?,
				p_bank_sort     = ?,
				p_holding       = ?,
				p_branch_code   = ?,
				p_extID         = ?,
				p_multiple_cpm  = ?
			)
		}

		set SHARED_SQL(earth.withdraw) {
			execute procedure pPmtInsEP (
				p_acct_id       = ?,
				p_cpm_id        = ?,
				p_payment_sort  = ?,
				p_amount        = ?,
				p_commission    = ?,
				p_ipaddr        = ?,
				p_source        = ?,
				p_unique_id     = ?,
				p_transactional = ?,
				p_extra_info    = ?,
				p_min_amt		= ?,
				p_max_amt		= ?,
				p_van_to        = ?,
				p_ext_amount    = ?,
				p_ccy_code      = ?,
				p_exch_to_gbp   = ?,
				p_exch_frm_gbp  = ?,
				p_oper_id       = ?
			)
		}

		set SHARED_SQL(earth.withdraw_unknown) {
			update tPmt set
				status = 'U'
			where
				pmt_id = ?
		}

		set SHARED_SQL(earth.withdraw_complete) {
			execute procedure pPmtUpdEP (
				p_pmt_id        = ?,
				p_ref_no        = ?,
				p_status        = ?,
				p_j_op_type     = ?,
				p_payment_sort  = ?,
				p_transactional = ?,
				p_trade_id      = ?
			)
		}

		set SHARED_SQL(earth.get_details) {
			select
				e.earthport_van,
				e.description,
				e.country,
				e.ac_ccy as ep_ccy,
				e.bank_name,
				e.ac_name,
				e.ac_num,
				e.bank_sort,
				e.holding,
				e.branch_code,
				a.ccy_code as ob_ccy,
				a.acct_id
			from
				tCPMEP e,
				tCustPayMthd c,
				tAcct a
			where
				a.cust_id = c.cust_id
			and e.cpm_id = c.cpm_id
			and c.cpm_id = ?
		}

		set SHARED_SQL(earth.get_exch_rate) {
			select
				c.exch_rate
			from
				tccy c
			where
				ccy_code = ?
		}

		set SHARED_SQL(earth.get_account) {
			select
				e.cpm_id,
				e.cr_date,
				e.earthport_van,
				e.description,
				e.country,
				e.ac_ccy,
				e.bank_name,
				e.ac_name,
				e.ac_num,
				e.bank_sort,
				e.holding,
				e.branch_code,
				e.bank_code,
				e.bank_ccy
			from
				tcpmep e,
				tcustpaymthd p
			where
				e.cust_id = ?
			and p.status = 'A'
			and p.status_wtd = 'A'
			and p.status_dep = 'A'
			and e.cpm_id = p.cpm_id


		}

		set SHARED_SQL(earth.get_account_wtd) {
			select
				e.cpm_id,
				e.cr_date,
				e.earthport_van,
				e.description,
				e.country,
				e.ac_ccy,
				e.bank_name,
				e.ac_name,
				e.ac_num,
				e.bank_sort,
				e.holding,
				e.branch_code,
				e.bank_code,
				e.bank_ccy
			from
				tcpmep e,
				tcustpaymthd p
			where
				e.cust_id = ?
			and p.status = 'A'
			and p.status_wtd = 'A'
			and e.cpm_id = p.cpm_id
		}

		set SHARED_SQL(earth.get_account_dep) {
			select
				e.cpm_id,
				e.cr_date,
				e.earthport_van,
				e.description,
				e.country,
				e.ac_ccy,
				e.bank_name,
				e.ac_name,
				e.ac_num,
				e.bank_sort,
				e.holding,
				e.branch_code,
				e.bank_code,
				e.bank_ccy
			from
				tcpmep e,
				tcustpaymthd p
			where
				e.cust_id = ?
			and p.status = 'A'
			and p.status_dep = 'A'
			and e.cpm_id = p.cpm_id
		}



		set SHARED_SQL(earth.get_ref_no) {
			select
				ep.ref_no
			from
				tPmtEP ep
			where
				ep.pmt_id = ?
		}

		set SHARED_SQL(earth.get_details_from_van) {
			select
				a.acct_id,
				e.cpm_id,
				a.ccy_code
			from
				tcpmep e,
				tCustPayMthd p,
				tacct a
			where
				e.earthport_van = ?
			and e.cpm_id = p.cpm_id
			and p.cust_id = a.cust_id
			and p.status = "A"
		}

		set SHARED_SQL(earth.deposit) {
			execute procedure pPmtInsEP (
				p_acct_id       = ?,
				p_cpm_id        = ?,
				p_payment_sort  = ?,
				p_amount        = ?,
				p_commission    = ?,
				p_ipaddr        = ?,
				p_source        = ?,
				p_transactional = ?,
				p_j_op_type     = ?,
				p_trade_id      = ?,
				p_ext_id        = ?,
				p_van_from      = ?,
				p_van_to        = ?,
				p_ext_amount    = ?,
				p_ccy_code      = ?,
				p_trade_desc    = ?,
				p_trade_type    = ?,
				p_trans_time    = ?,
				p_exch_to_gbp   = ?,
				p_exch_frm_gbp  = ?
			)
		}

		set SHARED_SQL(earth.deposit_complete) {
			execute procedure pPmtUpdEP (
				p_pmt_id        = ?,
				p_status        = ?,
				p_j_op_type     = ?,
				p_payment_sort  = ?,
				p_transactional = ?
			)
		}

		set SHARED_SQL(earth.deposit_status) {
			update tPmt set
				status = 'U'
			where
				pmt_id = ?
		}

		set SHARED_SQL(earth.get_prev_details) {
			select
				first 1 cpm.cr_date,
				earthport_van
			from
				tCustomer c,
				tCustPayMthd cpm,
				tCpmEp ep
			where
				c.cust_id  = ? and
				c.cust_id  = cpm.cust_id and
				cpm.cpm_id = ep.cpm_id and
				cpm.status = 'X'
			order by
				cr_date desc
		}
	}


	# =================================================================
	# Proc        : registerEarthportAcc
	# Description : as it says on the tin.
	#				strings must be converted to correct encoding. Earthport
	#				have encountered problems with encodings other than utf-8
	# Inputs      : global array EARTHPORT should be filled in appropriately
	# Outputs     : list, either:
	#                   if sucessful: 1, earthport van, cpm id
	#                   else: 0, admin error message, user error message
	# Author      : sluke
	# =================================================================
	proc registerEarthportAcc {} {
		variable NEW_ACCOUNT_REQ
		global EARTHPORT
		global CHARSET

		set rs [tb_db::tb_exec_qry earth.get_user_details $EARTHPORT(CUST_ID)]

		if {[db_get_nrows $rs] != 1} {
			ob::log::write ERROR {Failed to get customerreg details for customer $EARTHPORT(CUST_ID), query returned returned [db_get_nrows $rs] rows}
			return [list 0 "A database error occured - could not retrieve customers details" EP_REG_ERR]
		}

		set fname [db_get_col $rs 0 fname]
		set lname [db_get_col $rs 0 lname]
		set username [db_get_col $rs 0 username]
		set charset [db_get_col $rs 0 charset]

show_conversion_debug "Encoding names:" $charset fname $fname lname $lname username $username

		set fname [encoding convertfrom $charset $fname]
		set lname [encoding convertfrom $charset $lname]
		set username [encoding convertfrom $charset $username]

		# reference for earthport.  Contains userid, time (last 6 digits - so id is unique), last & firstnames then username.
		# info will help earthport assign payments without references.  Curtailed to 50 characters which is the max earthport will
		# accept.
		set ExtID ${EARTHPORT(CUST_ID)}^[string range [clock seconds] 4 end]^${lname}^${fname}^${username}
		set ExtID [string range $ExtID 0 50]

		foreach name {BANKSORT BRANCHCODE OPER_ID BANK_CODE OPER_NOTES BANK_KEY TYPE ROUTING MULT_CPM} {
			if {![info exists EARTHPORT($name)]} {set EARTHPORT($name) ""}
		}

		if {![info exists EARTHPORT(ALLOW_WTD)]} {set EARTHPORT(ALLOW_WTD) "P"}

show_conversion_debug "Encoding bank details:" $CHARSET Description $EARTHPORT(DESCRIPTION) {Bank Name} $EARTHPORT(BANKNAME) {Account Name} $EARTHPORT(ACNAME) Holding $EARTHPORT(HOLDING)
show_conversion_debug "Are we sure we didn't mean:" $charset Description $EARTHPORT(DESCRIPTION) {Bank Name} $EARTHPORT(BANKNAME) {Account Name} $EARTHPORT(ACNAME) Holding $EARTHPORT(HOLDING)

		if {[catch {set result [$NEW_ACCOUNT_REQ \
				$ExtID\
				[ep_strip_string [encoding convertfrom $CHARSET $EARTHPORT(DESCRIPTION)]] \
				$EARTHPORT(COUNTRY) \
				$EARTHPORT(ACCCY) \
				$EARTHPORT(BANKCCY) \
				[ep_strip_string [encoding convertfrom $CHARSET $EARTHPORT(BANKNAME)]] \
				[ep_strip_string [encoding convertfrom $CHARSET $EARTHPORT(ACNAME)]] \
				$EARTHPORT(ACNUM) \
				$EARTHPORT(BANKSORT) \
				$EARTHPORT(BANK_CODE) \
				$EARTHPORT(BANK_KEY) \
				[ep_strip_string [encoding convertfrom $CHARSET $EARTHPORT(HOLDING)]] \
				$EARTHPORT(BRANCHCODE) \
				$EARTHPORT(TYPE) \
				$EARTHPORT(ROUTING)]} msg]} {
			unset EARTHPORT
			ob::log::write ERROR {A problem occurred when communicating with earthport: $msg}
			return [list 0 "problem communicating with banking system" EP_REG_ERR]
		}

		ob::log::write INFO {value returned from earthport: $result}

		# reply will be in format: {key DATA value {item {item 3400290146654}}} {key ERROR value 0}
		if {[lindex [lindex $result 1] 3] == 0} {
			set earthport_van [lindex [lindex [lindex [lindex $result 0] 3] 1] 1]
			ob::log::write INFO {new earthport_van is $earthport_van}

			# Check if customer has previously created Earthport a/cs
			set acc_rs [tb_db::tb_exec_qry earth.get_prev_details $EARTHPORT(CUST_ID)]

			# Send message to earthport which associates the old VAN with the new VAN
			if {[db_get_nrows $acc_rs] > 0} {
				set old_van [db_get_col $acc_rs 0 earthport_van]
				set acc_result [associate_account_req $old_van $earthport_van]

				# If error occurs, write error message to log rather than interrupting the registration process
				if {[lindex $acc_result 0] == 1} {
					ob::log::write INFO { associate_acc_req $old_van $earthport_van => Successful }
				} else {
					ob::log::write INFO {[lindex $acc_result 1]}
				}
			}
		} else {
			set err_code [lindex [lindex $result 1] 3]
			unset EARTHPORT
			return [list 0 "Payment could not be inserted, earthport reported error code: $err_code" EP_ERR_$err_code]
		}

		foreach name {BANKSORT BRANCHCODE OPER_ID BANK_CODE} {
			if {$EARTHPORT($name) == ""} {set EARTHPORT($name) -1}
		}

		if {$EARTHPORT(ALLOW_WTD) == ""} {
			set EARTHPORT(ALLOW_WTD) "Y"
		}

		#set wtd_allowed "Y"
		if {$EARTHPORT(MULT_CPM) == ""} {
			set EARTHPORT(MULT_CPM) "N"
			#set wtd_allowed "P"
		}

		if {[catch {set rs [tb_db::tb_exec_qry earth.new_account \
			$EARTHPORT(CUST_ID) \
			$EARTHPORT(OPER_ID) \
			$EARTHPORT(ALLOW_WTD) \
			$EARTHPORT(OPER_NOTES) \
			Y \
			[string range $earthport_van [expr {[string length $earthport_van] - 3}] end] \
			$earthport_van \
			$EARTHPORT(DESCRIPTION) \
			$EARTHPORT(COUNTRY) \
			$EARTHPORT(ACCCY) \
			$EARTHPORT(BANKCCY) \
			$EARTHPORT(BANKNAME) \
			$EARTHPORT(BANK_CODE) \
			$EARTHPORT(ACNAME) \
			$EARTHPORT(ACNUM) \
			$EARTHPORT(BANKSORT) \
			$EARTHPORT(HOLDING) \
			$EARTHPORT(BRANCHCODE) \
			[encoding convertto utf-8 $ExtID] \
			$EARTHPORT(MULT_CPM)]} msg]} {
				ob::log::write ERROR {Error inserting new earthport account: $msg}
				unset EARTHPORT
				return [list 0 "Problem writing to db: $msg" EP_REG_ERR]
		}

		set cpm_id [db_get_coln $rs 0]
		db_close $rs

		# Send to fraud screening
		set monitor_details [fraud_check::screen_customer_bank\
			$EARTHPORT(CUST_ID)\
			""\
			""\
		]

		# If fraud screening isn't on, we won't get anything back
		# so no point sending to ticker
		if {[llength $monitor_details] != 0} {
			lappend monitor_details bank_sort_code  $EARTHPORT(BANKSORT)
			lappend monitor_details bank_acct_name  $EARTHPORT(ACNAME)
			lappend monitor_details bank_acct_no    $EARTHPORT(ACNUM)
			lappend monitor_details bank_addr_1     ""
			lappend monitor_details bank_addr_2     ""
			lappend monitor_details bank_addr_city  ""

			eval fraud_check::send_ticker $monitor_details
		}


	### Send message to Monitor ###

	set cust_id $EARTHPORT(CUST_ID)
	set channel $EARTHPORT(CHANNEL)
	set amount "N/A"
	set mthd "EP"
	set generic_pmt_mthd_id $earthport_van
	set other $EARTHPORT(BANKNAME)

	OB_gen_payment::send_pmt_method_registered \
		$cust_id \
		$channel \
		$amount \
		$mthd \
		$cpm_id \
		$generic_pmt_mthd_id \
		$other

	### End of Monitor code ###


		unset EARTHPORT
		return [list 1 $earthport_van $cpm_id]
	}


	# =================================================================
	# Proc        : payout_request
	# Description : Withdraw funds.
	#               Basically - retrieves user details, converts currency (if necessary),
	#               records in database, sets payment status to U (unknown), makes call to
	#               earthport then records result.
	# Inputs      : values set up in EARTHPORT global array - see code
	# Outputs     : list
	#                   if successful, 1 then pmt_id
	#                   else, 0 then admin error message and customer error code (& pmt_id if known)
	# Author      : sluke
	# =================================================================
	proc payout_request {} {
		variable PAYOUT_REQ
		global EARTHPORT

		foreach name {oper_id min_amt max_amt} {
		if {![info exists EARTHPORT($name)]} {set EARTHPORT($name) ""}
		}

		set rs [tb_db::tb_exec_qry earth.get_details $EARTHPORT(cpm_id)]
		if {[db_get_nrows $rs] != 1} {
			ob::log::write ERROR {Failed to get details for Earthport payment method $EARTHPORT(cpm_id), query returned returned [db_get_nrows $rs] rows}
			return [list 0 "A database error occurred - could not retrieve customers earthport details" EP_WTD_ERR]
		}

		set acct_id [db_get_col $rs 0 acct_id]
		set ep_ccy  [db_get_col $rs 0 ep_ccy]
		set van     [db_get_col $rs 0 earthport_van]
		set ob_ccy  [db_get_col $rs 0 ob_ccy]

		db_close $rs

		# convert amount into ep currency if necessary.
		set list [convert_currency $EARTHPORT(amount) $ob_ccy $ep_ccy EP]
		if {[lindex $list 0] == 1} {
			set ext_amount [lindex $list 1]
			set exch_to_gbp [lindex $list 2]
			set exch_frm_gbp [lindex $list 3]
		} else {
			ob::log::write ERROR {Couldn't convert currency from openbet ccy to earthport currency}
			unset EARTHPORT
			return [list 0 "Currency conversion error" EP_WTD_ERR]
		}

		#make db call and set status to pending
		if {[catch {set rs [tb_db::tb_exec_qry earth.withdraw \
					$acct_id \
					$EARTHPORT(cpm_id) \
					W \
					$EARTHPORT(tPmt_amount) \
					$EARTHPORT(commission) \
					$EARTHPORT(ip) \
					$EARTHPORT(source) \
					$EARTHPORT(uid) \
					Y \
					$EARTHPORT(extra_info) \
					$EARTHPORT(min_amt) \
					$EARTHPORT(max_amt) \
					$van \
					$ext_amount \
					$ep_ccy\
					$exch_to_gbp\
					$exch_frm_gbp\
					$EARTHPORT(oper_id)\
		]} msg]} {

			ob::log::write ERROR {Problem writing transaction to database: $msg}
			unset EARTHPORT
			if {[string first "AX6000" $msg] != -1} {
				return [list 0 "error writing to db: $msg" EP_WTD_PEND_ERR]
			}
			return [list 0 "error writing to db: $msg" EP_WTD_ERR]
		}

		set pmt_id [db_get_coln $rs 0]
		db_close $rs

		#
		# grab the apacs ref_no (generated during insert pmt)
		# and mark payment status as unknown
		#
		if {[catch {set rs [tb_db::tb_exec_qry earth.get_ref_no $pmt_id]} msg]} {
			ob::log::write ERROR {Error retrieving apacs ref; $msg}
			return [list 0 "Could not retrieve apacs ref: $msg" EP_WTD_ERR $pmt_id]
		}

		#
		# The number returned by pGenApacsUID is padded with zeroes and prefixed with a
		# number from the config file.  This ensure that systems that use different
		# databases but talk to the same payment gateway don't overlap
		# payment reference numbers.
		#
		set ref_no_prefix            [OT_CfgGet REF_NO_PREFIX 1]
		set apacs_ref                [format "$ref_no_prefix%06u" [db_get_coln $rs 0 0] ]
		db_close $rs

		if {[catch {tb_db::tb_exec_qry earth.withdraw_unknown $pmt_id} msg]} {
			ob::log::write ERROR {Can't set payment status to unknown for pmt_id $pmt_id, problem is $msg}
			unset EARTHPORT
			return [list 0 "Problem changing status of payment: $msg" EP_WTD_ERR $pmt_id]
		}

		if {[catch {set result [$PAYOUT_REQ \
					$van\
					$apacs_ref\
					$ext_amount \
					$ep_ccy]} msg]} {
			unset EARTHPORT
			ob::log::write ERROR {Problem communicating with earthport: $msg}
			return [list 0 "Problem communicating with earthport system" EP_WTD_ERR $pmt_id]
		}

		# reply is in format: {key DATA value {item {item 25}}} {key ERROR value 0}
		if {[lindex [lindex $result 1] 3] == 0} {
			set trade_id [lindex [lindex [lindex [lindex $result 0] 3] 1] 1]
			#record payment as successful
			if {[catch {tb_db::tb_exec_qry earth.withdraw_complete \
						$pmt_id \
						$apacs_ref \
						Y \
						WTD \
						W \
						Y \
						$trade_id} msg]} {
				ob::log::write ERROR {failed to update payment in database: $msg}
				return [list 0 "failed to update payment in database: $msg" EP_WTD_ERR $pmt_id]
			}
			unset EARTHPORT
			return [list 1 $pmt_id]
		} else {
			#record payment as failed
			if {[catch {tb_db::tb_exec_qry earth.withdraw_complete \
						$pmt_id \
						$apacs_ref \
						N \
						WTD \
						W \
						Y \
						""} msg]} {
				ob::log::write ERROR {Can't record payment $pmt_id as failed: $msg}
						}
			set err_code [lindex [lindex $result 1] 3]
			ob::log::write ERROR {Payment refused for reason: $err_code}
			unset EARTHPORT
			return [list 0 "Payment refused by earthport error code: $err_code" EP_ERR_$err_code $pmt_id]
		}
	}


	# =================================================================
	# Proc        : deposit_request
	# Description : this calls earthport to determine the details of the deposit,
	#               then inserts into db.
	# Inputs      : trade_id - earthport reference number
	# Author      : sluke
	# =================================================================
	proc deposit_request {trade_id} {
		variable VIEW_TRADE_REQ

		if {[catch {set result [$VIEW_TRADE_REQ $trade_id]} msg]} {
			ob::log::write ERROR {Could not make view trade request to earthport: $msg}
			return [list 0 "Problem contacting earthport: $msg"]
		}
		ob::log::write INFO "Got $result"

		#result will be in format {key DATA value {item {238 3400290147269 3400290146599 1200.79 EUR {Centralisation of funds} 23 1032255527343 00000005_00000A5S8B97VQ6 0}}} {key ERROR value 0}
		if {[lindex [lindex $result 1] 3] != 0} {
			#an error has occurred
			return [list 0 "earthport error [lindex [lindex $result 1] 3] has occurred"]
		}

		set result_list [lindex [lindex [lindex $result 0] 3] 1]

		set tradeId     [lindex $result_list 0]
		set vanFrom     [lindex $result_list 1]
		set vanTo       [lindex $result_list 2]
		set ep_amount   [lindex $result_list 3]
		set ep_ccy_code [lindex $result_list 4]
		set tradeDesc   [lindex $result_list 5]
		set tradeType   [lindex $result_list 6]
		set transTime   [lindex $result_list 7]
		set extId       [lindex $result_list 8]

		set rs [tb_db::tb_exec_qry earth.get_details_from_van $vanFrom]
		if {[db_get_nrows $rs] != 1} {
			ob::log::write ERROR {Can't retrieve acct_id or cpm_id for VAN $vanFrom}
			return [list 0 "Can't retrieve acct_id or cpm_id for VAN $vanFrom"]
		}

		set acct_id     [db_get_col $rs 0 acct_id]
		set cpm_id      [db_get_col $rs 0 cpm_id]
		set ob_ccy_code [db_get_col $rs 0 ccy_code]

		db_close $rs

		set list [convert_currency $ep_amount $ob_ccy_code $ep_ccy_code OB]
		if {[lindex $list 0] == 1} {
			set amount [lindex $list 1]
			set exch_to_gbp [lindex $list 2]
			set exch_frm_gbp [lindex $list 3]
		} else {
			ob::log::write ERROR {Unable to convert currency from $ep_ccy_code $ep_amount to $ob_ccy_code}
			return [list 0 "Unable to convert currency from $ep_ccy_code $ep_amount to $ob_ccy_code"]
		}

		# config item to turn on payment commissions
		if {[OT_CfgGet CHARGE_COMMISSION 0]} {
			#
			# calculate the commission, amount to go through the payment gateway,
			# and amount to be inserted into tPmt
			# amount passed to calcCommission is the amount that went through the payment gateway
			#
			# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
			# commission is the amount of commission to be paid on this payment
			# payment_amount is the amount to go through the payment gateway
			# tPmt_amount is the amount to be inserted into tPmt
			#
			set comm_list [payment_gateway::calcCommission EP {} $ob_ccy_code D $amount true]

		} else {
			set comm_list [list 0 $amount $amount]
		}

		#
		# get the commission, and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set tPmt_amount [lindex $comm_list 2]

		if {[catch {
			set rs [tb_db::tb_exec_qry earth.deposit \
				$acct_id \
				$cpm_id \
				D \
				$tPmt_amount \
				$commission \
				- \
				I \
				Y \
				DEP \
				$tradeId \
				$extId \
				$vanFrom \
				$vanTo \
				$ep_amount \
				$ep_ccy_code \
				$tradeDesc \
				$tradeType \
				[clock format [string range $transTime 0 [expr {[string length $transTime] -4}]] -format {%Y-%m-%d %H:%M:%S}] \
				$exch_to_gbp \
				$exch_frm_gbp \
		]} msg]} {
			ob::log::write ERROR {Error while inserting payment in database: $msg}
			return [list 0 "Error while inserting payment in database: $msg"]
		}

		set pmt_id [db_get_coln $rs 0]

		if {[catch {
			tb_db::tb_exec_qry earth.deposit_status $pmt_id

			tb_db::tb_exec_qry earth.deposit_complete \
				$pmt_id \
				Y \
				DEP \
				D \
				N
			} msg]} {
			ob::log::write ERROR {Error while updating payment (pmt id: $pmt_id) in database: $msg}
			return [list 0 "Error while updating payment (pmt id: $pmt_id) in database: $msg"]
		}

		return [list 1 $pmt_id]
	}


	# =================================================================
	# Proc        : convert_currency
	# Description : Converts between earthport and openbet currencies
	# Inputs      : amount - amount to be converted
	#               ob_ccy_code - ccy of users openbet account
	#               ep_ccy_code - ccy of users earthport account
	#               to_ccy - 'EP' if amount is in ob ccy and should be converted to ep ccy
	#                        'OB' if amount is in ep ccy and should be converted to ob ccy.
	# Outputs     : list of :-
	#                   error code - 1 if successful, 0 otherwise.
	#                   converted amount
	#                   exch rate to ? (or -1 if not used)
	#                   exch rate from ? (or -1 if not used)
	# Author      : sluke
	# =================================================================
	proc convert_currency {amount ob_ccy_code ep_ccy_code to_ccy} {
		set exch_to_gbp  -1
		set exch_frm_gbp -1
		if {$to_ccy == "OB"} {
			set ccy1 $ep_ccy_code
			set ccy2 $ob_ccy_code
		} elseif {$to_ccy == "EP"} {
			set ccy1 $ob_ccy_code
			set ccy2 $ep_ccy_code
		} else { return 0}

		if {$ccy1 != $ccy2} {
			#first convert amount to pence (or cents, whatever..) to conserve precision
			set amount [expr {round($amount * 100)}]
			if {$ccy1 != "GBP"} {
				#must convert amount to pounds
				set list [conv_ccy $amount from $ccy1]
				if {[lindex $list 0] == 1} {
					set amount [lindex $list 1]
					set exch_to_gbp [lindex $list 2]
				} else {return 0}
			}
			if {$ccy2 != "GBP"} {
				#must convert amount from pounds
				   set list [conv_ccy $amount to $ccy2]
				   if {[lindex $list 0] == 1} {
					   set amount [lindex $list 1]
					   set exch_frm_gbp [lindex $list 2]
				} else {return 0}
			}
			#round amount down - stop people from making pence by transferring money back and forth
			set amount [expr {floor($amount)}]
			#convert back to decent size currency units - eg pounds not pence
			set amount [format %.2f [expr {$amount / 100}]]
		}
		return [list 1 $amount $exch_to_gbp $exch_frm_gbp]
	}


	# =================================================================
	# Proc        : conv_ccy
	# Description : Performs simple currency conversion - no rounding so
	#               accuracy is conserved across multiple conversions
	# Inputs      : $amount - amount to convert
	#               dirn - direction - either 'to' or 'from' ccy_code
	#               ccy_code - currency code to convert to or from
	# Outputs     : list, containing:-
	#                   error code - 1 if successful, else 0
	#                   amount - converted amount
	#                   exch - exchange rate used
	# Author      : sluke
	# =================================================================
	 proc conv_ccy {amount dirn ccy_code} {
		set rs [tb_db::tb_exec_qry earth.get_exch_rate $ccy_code]
		if {[db_get_nrows $rs] != 1} {return -1}
		set exch [db_get_col $rs 0 exch_rate]
		if {$dirn == "to"} {
			set amount [expr {$amount*$exch}]
		} else {
			set amount [expr {$amount/$exch}]
		}
		db_close $rs
		return [list 1 $amount $exch]
	}



	# =================================================================
	# Proc        : get_ep_account
	# Description : retrieves earthport account (if one exists) for customer
	# Inputs      : cust_id - obvious
	#               OUT - array to return results to
	#				mthd - DEP or WTD for specific ep usage
	# Outputs     : values are put int OUT array
	# Author      : sluke
	# =================================================================
	proc get_ep_account {cust_id OUT {mthd ""} } {
		upvar 1 $OUT DATA

		set rs [tb_db::tb_exec_qry earth.get_account $cust_id]
		if {$mthd!=""} {
			switch $mthd							\
				"DEP" {set qry earth.get_account_dep} \
				"WTD" {set qry earth.get_account_wtd} \
				"default" {set DATA(ep_available) "N"; return}

			set rs [tb_db::tb_exec_qry $qry $cust_id]
			if {[db_get_nrows $rs] == 0} {
				set DATA(ep_available) N
				return
			}
		} else {
			set rs [tb_db::tb_exec_qry earth.get_account $cust_id]
			if {[db_get_nrows $rs] == 0} {
				set DATA(ep_available) N
				return
			}
		}

		set DATA(ep_available) Y

		foreach col_name [db_get_colnames $rs] {
			set DATA($col_name) [db_get_col $rs 0 $col_name]
		}
	}

	# =================================================================
	# Proc        : ep_strip_string
	# Description : removes all wickedness and purifies strings before
	#               they are passed to Earthport
	# Inputs      : impure - string for cleansing
	# Outputs     : luke - string worthy of Earthport
	# Author      : should have been sluke but jrenniso did it cuz he's
	#               wrapped round her little finger
	# =================================================================
	proc ep_strip_string {impure} {

	# All the filthiness must wiped out
	regsub -all {[%#&+=:;?/\\\t\n]} $impure {} luke

	return $luke
	}

	# set up SOAP requests and DB queries
	init_earthport

	proc show_conversion_debug {heading charset args} {
		array set encoding [list]
		foreach {n v} $args {
			if {[regexp {[^\040-\176]} $v]} {
				set encoding($n) [list [hex_esc $v] [hex_esc [encoding convertfrom $charset $v]]]
			}
		}
		if {[llength [array names encoding]]} {
			ob::log::write ERROR {(show_conversion_debug) $heading}
			foreach key [array names encoding] {
				ob::log::write ERROR {(show_conversion_debug) $key: "[lindex $encoding($key) 0]" => "[lindex $encoding($key) 1]"}
			}
		}
	}

	proc hex_esc {str} {
		set escstr ""
		set hex [list]
		foreach c [split $str {}] {
		if {[regexp {[^\040-\176]} $c]} {
				binary scan $c H2 ch
				lappend hex [string toupper $ch]
			} else {
				if {[llength $hex]} {
					append escstr "\033\[1m\[[join $hex { }]\]\033\[0m"
					set hex [list]
				}
				append escstr $c
			}
		}
		if {[llength $hex]} {
			append escstr "\033\[1m\[[join $hex { }]\]\033\[0m"
		}
		return $escstr
	}

	# =================================================================
	# Proc        : close_account_req
	# Description : Marks virtual accounts as closed so they cannot be
	#               used for pay-ins and payouts
	# Inputs      : van - the virtual account number of the earthport a/c
	#
	# Outputs     : list of :-
	#                   0 if error occured plus error details.
	#                   1 if successful
	#
	# Author      : dcoleman
	# =================================================================
	proc close_account_req {van} {
		# Don't send a close account request to EarthPort
		# as requested by LBR (29/6/2004)
		return [list 1]

		variable CLOSE_ACC_REQ

		if {[catch {set result [$CLOSE_ACC_REQ $van]} msg]} {
			ob::log::write ERROR {Problem communicating with earthport: $msg}
			return [list 0 "Problem contacting earthport: $msg"]
		}

		ob::log::write INFO {REQUEST: [SOAP::dump -request $CLOSE_ACC_REQ]\n}
		ob::log::write INFO {REPLY: [SOAP::dump -reply $CLOSE_ACC_REQ]\n}

		set err_code [lindex [lindex $result 1] 3]

		if {$err_code == 0} {
		return [list 1]
		} else {
			return [list 0 "Error occured (error_status_id) : $err_code"]
		}
	}

	# =================================================================
	# Proc        : associate_account_req
	# Description : Keeps track of virtual accounts previously created by
	#               the customer
	# Inputs      : old_van - the VAN of the last earthport a/c previously
	#                         created by the user but was removed
	#               new_van - the VAN of the newly created earthport a/c
	#
	# Outputs     : list of :-
	#                   0 if error occured plus error details
	#                   1 if successful
	#
	# Author      : dcoleman
	# =================================================================
	proc associate_account_req {old_van new_van} {
		global EARTHPORT
		variable ASSOCIATE_ACC_REQ

		if {[catch {set result [$ASSOCIATE_ACC_REQ $old_van $new_van]} msg]} {
			ob::log::write ERROR {Problem communicating with earthport: $msg}
			return [list 0 "Problem contacting earthport: $msg"]
		}

		ob::log::write INFO {REQUEST: [SOAP::dump -request $ASSOCIATE_ACC_REQ]\n}
		ob::log::write INFO {REPLY: [SOAP::dump -reply $ASSOCIATE_ACC_REQ]\n}

		set err_code  [lindex [lindex $result 1] 3]

		if {$err_code == 0} {
		return [list 1]
		} else {
			return [list 0 "Error occured (error_status_id) : $err_code"]
		}
	}

	# =================================================================
	# Proc        : change_bank_details
	# Description : Changes a customers bank details but preserves their
	#               virtual account number
	# Inputs      : van_id        - the virtual account number of the earthport a/c
	#
	# Outputs     : list of :-
	#                   0 if error occured plus error details
	#                   1 if successful
	#
	# Author      : dcoleman
	# =================================================================
	proc change_bank_details {van_id} {

		global EARTHPORT CHARSET
		variable CHANGE_BANK_DETAILS_REQ

	   	foreach name {BANK_KEY TYPE ROUTING MULT_CPM ALLOW_WTD OPER_NOTES} {
			if {![info exists EARTHPORT($name)]} {set EARTHPORT($name) ""}
		}

		# Send the update request message
		if {[catch {set result [$CHANGE_BANK_DETAILS_REQ \
											$van_id \
											$EARTHPORT(DESCRIPTION) \
											$EARTHPORT(COUNTRY)\
											$EARTHPORT(BANKCCY) \
											$EARTHPORT(BANKNAME) \
											$EARTHPORT(ACNAME) \
											$EARTHPORT(ACNUM) \
											$EARTHPORT(BANKSORT) \
											$EARTHPORT(BANK_CODE) \
											$EARTHPORT(BANK_KEY) \
											$EARTHPORT(HOLDING) \
											$EARTHPORT(BRANCHCODE) \
											$EARTHPORT(TYPE) \
											$EARTHPORT(ROUTING)]} msg]} {
			ob::log::write ERROR {Problem communicating with earthport: $msg}
			return [list 0 "Problem contacting earthport: $msg"]
		}

		ob::log::write INFO {REQUEST: [SOAP::dump -request $CHANGE_BANK_DETAILS_REQ]\n}
		ob::log::write INFO {REPLY: [SOAP::dump -reply $CHANGE_BANK_DETAILS_REQ]\n}

		set err_code  [lindex [lindex $result 1] 3]

		# Success if error_code = 0, then insert customers new EP details
		# into tcpmep using the old earthport van number
		if {$err_code == 0} {

			# Get static customer details
			set rs [tb_db::tb_exec_qry earth.get_user_details $EARTHPORT(CUST_ID)]

			if {[db_get_nrows $rs] != 1} {
				ob::log::write ERROR {Failed to get customerreg details for customer $EARTHPORT(CUST_ID), query returned returned [db_get_nrows $rs] rows}
				return [list 0 "A database error occured - could not retrieve customers details" EP_REG_ERR]
			}

			set fname [db_get_col $rs 0 fname]
			set lname [db_get_col $rs 0 lname]
			set username [db_get_col $rs 0 username]
			set charset [db_get_col $rs 0 charset]

			db_close $rs
			unset rs

			show_conversion_debug "Encoding names:" $charset fname $fname lname $lname username $username

			set fname [encoding convertfrom $charset $fname]
			set lname [encoding convertfrom $charset $lname]
			set username [encoding convertfrom $charset $username]

			# reference for earthport.  Contains userid, time (last 6 digits - so id is unique), last & firstnames then username.
			# info will help earthport assign payments without references.  Curtailed to 50 characters which is the max earthport will
			# accept.
			set ExtID ${EARTHPORT(CUST_ID)}^[string range [clock seconds] 4 end]^${lname}^${fname}^${username}
			set ExtID [string range $ExtID 0 50]

			# Insert customers EP details
			if {[catch {set rs [tb_db::tb_exec_qry earth.new_account \
														$EARTHPORT(CUST_ID) \
		  												$EARTHPORT(OPER_ID) \
														$EARTHPORT(ALLOW_WTD) \
														$EARTHPORT(OPER_NOTES) \
														Y \
														[string range $van_id [expr {[string length $van_id] - 3}] end] \
														$van_id \
														$EARTHPORT(DESCRIPTION) \
														$EARTHPORT(COUNTRY) \
														$EARTHPORT(ACCCY) \
														$EARTHPORT(BANKCCY) \
														$EARTHPORT(BANKNAME) \
														$EARTHPORT(BANK_CODE) \
														$EARTHPORT(ACNAME) \
														$EARTHPORT(ACNUM) \
														$EARTHPORT(BANKSORT) \
														$EARTHPORT(HOLDING) \
														$EARTHPORT(BRANCHCODE) \
														[encoding convertto utf-8 $ExtID] \
														$EARTHPORT(MULT_CPM)]} msg]} {
				ob::log::write ERROR {Error inserting new earthport account: $msg}
				unset EARTHPORT
				return [list 0 "Problem writing to db: $msg" EP_REG_ERR]
			}
			unset EARTHPORT
			set new_cpm_id [db_get_coln $rs 0 0]
			return [list 1 $new_cpm_id]
		} else {
			unset EARTHPORT
			return [list 0 "Error occured (error_status_id) : $err_code"]
		}
	}
}
