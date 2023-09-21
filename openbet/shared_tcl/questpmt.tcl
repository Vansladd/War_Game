# $Id: questpmt.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# Copyright 2006 Orbis Technology Ltd. All rights reserved.
#
# QUEST file payment gateway handler
#
# Procedures:
#   ob_questpmt::authorize
#


namespace eval ob_questpmt {
}

proc ::ob_questpmt::init {} {
	variable CFG

	OT_LogWrite DEBUG ::ob_questpmt::init

	foreach {name default} [list           \
			VERSION         ""     \
			MERCHANT_NUMBER ""     \
			OUTPUT_DIR      .      \
			FILE_PREFIX     Q001   \
			FILE_SUFFIX     .INP   \
			CVV2            0      \
			MAX_FILE_ID     999    \
	] {
		set CFG($name) [OT_CfgGet QUEST_$name $default]
		OT_LogWrite DEBUG "CFG: CFG($name) $CFG($name)"
	}

	ob_db::store_qry quest_gen_file_num {
		execute procedure pGenUid (
			p_max_id = ?
		)
	}

}

proc ob_questpmt::authorize array {
	variable CFG

	OT_LogWrite DEBUG ::ob_questpmt::authorize

	upvar $array pmt


	# Pass the amount through in pence/cents etc
	# (ie multiply by 100)
	set amount [expr {round($pmt(amount)*100)}]


	# Use the cvv2 value if it's config'd on and
	# the customer has supplied it
	set cvv2_indicator 0
	set cvv2 ""

	if {$CFG(CVV2) && $pmt(cvv2) != ""} {
		set cvv2 $pmt(cvv2)
		set cvv2_indicator 1
	}


	foreach {name value} [list                       \
		QuestVersion       $CFG(VERSION)         \
		TransactionRef     $pmt(pmt_id)          \
		OperatorRef        $pmt(pmt_id)          \
		TrainingMode       0                     \
		TransactionType    P                     \
		CcyCode            $pmt(ccy_code)        \
		PurchaseAmount     $amount               \
		CashoutAmount      0                     \
		CCNumber           $pmt(card_no)         \
		Expiry             $pmt(expiry)          \
		CardCheckIndicator $cvv2_indicator       \
		CCV                $cvv2                 \
		ECM                31                    \
		SLI                07                    \
		XID                ""                    \
		CAV                ""                    \
		VER                ""                    \
		PAR                ""                    \
		MerchantNumber     $CFG(MERCHANT_NUMBER) \
		AuthCode           ""                    \
	] {
		lappend output_names $name
		set output($name) $value
	}

	# Write the array to the log file
	foreach f $output_names {
		# Don't log certain fields
		if {[lsearch {CCNumber CCV} $f] > -1} {
			OT_LogWrite DEBUG "output($f): -- removed --"
		} else {
			OT_LogWrite DEBUG "output($f): $output($f)"
		}
	}

	OT_LogWrite INFO "Getting next file sequence number"

	# To ensure that the file sequence numbers are "monotonically increasing"
	# (ie current number is 1 greater than previous one) - until they wrap around -
	# we need to lock the tUID row, and rollback if the file write fails
	ob_db::begin_tran

	# Generate next file sequence number
	if {[catch {
		set filenum [_gen_file_num]
	} msg]} {
		OT_LogWrite ERROR "Unable to generate file number: $msg"
		ob_db::rollback_tran
		return PMT_ERR
	}
	set filename "$CFG(OUTPUT_DIR)/$CFG(FILE_PREFIX)${filenum}$CFG(FILE_SUFFIX)"

	OT_LogWrite DEBUG "Opening file $filename"
	if {[catch {
		set file [open $filename w]
	} msg]} {
		OT_LogWrite ERROR "Unable to open output file $filename: $msg"
		ob_db::rollback_tran
		return PMT_ERR
	}

	OT_LogWrite DEBUG "Writing payment to file $filename"

	# Write payment to output file
	if {[catch {
		foreach f $output_names {
			puts $file $output($f)
		}
	} msg]} {
		OT_LogWrite ERROR "Unable to write to output file $filename: $msg"
		ob_db::rollback_tran
		return PMT_ERR
	}

	OT_LogWrite DEBUG "Closing file $filename"
	if {[catch {
		close $file
	} msg]} {
		OT_LogWrite ERROR "Unable to close output file $filename: $msg"
		ob_db::rollback_tran
		return PMT_ERR
	}

	ob_db::commit_tran

	return PMT_URL_REDIRECT
}

proc ob_questpmt::_gen_file_num args {
	variable CFG

	set rs [ob_db::exec_qry quest_gen_file_num $CFG(MAX_FILE_ID)]
	set file_num [db_get_coln $rs 0]

	catch {db_close $rs}

	return [format %03s $file_num]
}
