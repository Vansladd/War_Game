##
# $Id: paymthd_ctrl.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# Code to manage the tPayMthdCtrl
#
##

namespace eval ADMIN::PMT {

	#
	# Set up the necessary handlers
	#
	asSetAct ADMIN::PMT::GoPayMthdCtrlList [namespace code go_paymthd_ctrl_list]
	asSetAct ADMIN::PMT::GenNewDataKey     [namespace code gen_new_data_key]

	proc go_paymthd_ctrl_list {} {

		ob::log::write DEBUG {==>go_paymthd_ctrl_list}

		# Get details of the current encryption data key here, as this page also
		# allows the setting of new data keys
		if {![OT_CfgGet ENCRYPT_FROM_CONF 0]} {
			set ret [::cryptoAPI::initRequest]
			if {[lindex $ret 0] != {OK}} {
				OT_LogWrite 1 "Latest key error: [lindex $ret 1]"
				tpBindString keyVersion "Error retrieving current key"
			} else {
				# Add the request
				set ret [::cryptoAPI::addDataRequest 0 [::cryptoAPI::createDataRequest "dataKeyLatest"]]

				if {[lindex $ret 0] != {OK}} {
					OT_LogWrite 1 "Latest key error: [lindex $ret 1]"
					tpBindString keyVersion "Error retrieving current key"
				} else {
					# Retrieve latest key version
					set ret [::cryptoAPI::makeRequest]

					if {[lindex $ret 0] != {OK}} {
						OT_LogWrite 1 "Latest key error: [lindex $ret 1]"
						tpBindString keyVersion "Error retrieving current key"
					} else {
						OT_LogWrite 1 "LATEST KEY [::cryptoAPI::getResponseData 0 keyVersion]"
						tpBindString keyVersion [::cryptoAPI::getResponseData 0 keyVersion]
					}
				}
			}
		}

		#
		# play the necessary template
		#
		asPlayFile -nocache pmt/paymthd_ctrl_list.html
	}

	proc gen_new_data_key {} {

		# Check again that the user is allowed to generate new data keys
		if {![op_allowed GenNewDataKey]} {
			err_bind "You do not have permission to add new data keys"
			go_paymthd_ctrl_list
			return
		}

		# We also get details of the current encryption data key here, as this page also
		# allows the setting of new data keys
		# Initialise the request
		if {[OT_CfgGet ENCRYPT_FROM_CONF 0]} {
			OT_LogWrite 1 "Failed to generate new key, encrypt from config enabled"
			err_bind "Failed to generate new key, encrypt from config enabled"
		} else {

			set ret [::cryptoAPI::initRequest]

			if {[lindex $ret 0] != {OK}} {
				OT_LogWrite 1 "New Key Error: [lindex $ret 1]"
				err_bind "Error generating new key: [lindex $ret 1]"
			}
			
			# Add the request
			set ret [::cryptoAPI::addDataRequest 0 [::cryptoAPI::createDataRequest "dataKeyCreate"]]
			if {[lindex $ret 0] != {OK}} {
				OT_LogWrite 1 "New Key Error: [lindex $ret 1]"
				err_bind "Error generating new key: [lindex $ret 1]"
			}
			
			set ret [::cryptoAPI::makeRequest]
			if {[lindex $ret 0] != {OK}} {
				OT_LogWrite 1 "New Key Error: [lindex $ret 1]"
				err_bind "Error generating new key: [lindex $ret 1]"
			}

		}

		go_paymthd_ctrl_list
	}
}
