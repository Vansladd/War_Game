# Copyright (C) 2014 OpenBet Technology Ltd. All Rights Reserved.
#
# Login interfaces
#
# Synopsis:
#   This file contains various interfaces to be used for customer login
#
set pkg_version 1.0
package provide core::cust::login $pkg_version

# Dependencies
package require core::args   1.0
package require core::check  1.0
package require core::log    1.0

core::args::register_ns \
	-namespace core::cust::login \
	-version   $pkg_version \
	-dependent [list \
		core::args \
		core::check \
	] \
	-docs xml/cust/login.xml

namespace eval core::cust::login {
}



##
# @brief Register login interfaces
#
core::args::register \
	-interface core::cust::login::validate_login_by_phone \
	-desc {Validate login using the customers phone number and pin} \
	-args [list \
		[list -arg -telephone     -mand 1 -check ASCII                                     -desc {Phone number to identify the customer to login by}] \
		[list -arg -pin           -mand 0 -check {RE -args {^\d\d\d\d$}}       -default {} -desc {Pin number to use for login}] \
		[list -arg -encrypted_pin -mand 0 -check BASE64                        -default {} -desc {Encrypted Pin number to use for login}] \
		[list -arg -channel       -mand 0 -check {ALNUM -min_str 1 -max_str 1} -default I  -desc {Channel being logged in through}] \
	] \
	-body {
		set pin 0
		set enc_pin 0

		foreach {param value} $args {
			switch -exact -- $param {
				-pin {
					set pin 1
				}
				-encrypted_pin {
					set enc_pin 1
				}
			}
		}

		if {($pin && $enc_pin) || (!$pin && !$enc_pin)} {
			error {Must specify a PIN or encrypted PIN to login by telephone number} {} INTERNAL_ERROR
		}
	} \
	-return_data [list \
		[list -arg -cust_id      -mand 1 -check UINT              -desc {The cust id of the customer login has been validated for}] \
		[list -arg -status_flags -mand 0 -check ASCII -default {} -desc {List containing the status flags active for the customer}] \
	] \
	-errors [list LOGIN_NOT_OK INTERNAL_ERROR]



##
# @brief Initialisation of the login configuration and prepare the queries.
#
core::args::register \
	-interface core::cust::login::init \
	-desc      {Initialisation of the login configuration and prepare the queries.} \
	-mand_impl 0



##
# @brief Set mobile pin
#
core::args::register \
	-interface core::cust::login::set_mobile_pin \
	-desc {Set mobile pin} \
	-args [list \
		[list -arg -cust_id         -mand 1 -check UINT                    -desc {Customer's id}] \
		[list -arg -password        -mand 1 -check ASCII                   -desc {Plaintext customer password}] \
		[list -arg -mobile_pin      -mand 0 -check {RE -args {^\d\d\d\d$}} -default {}    -desc {Customer PIN}] \
		[list -arg -admin_user_id   -mand 1 -check INT                     -desc {Admin user id}] \
		[list -arg -ipaddr          -mand 1 -check IPADDR                  -desc {IP Address of the customer}] \
		[list -arg -app_name        -mand 0 -check ASCII    -default {}    -desc {App name that the customer is using}] \
	] \
	-return_data [list \
		[list -arg -token           -mand 1 -check STRING   -default {}    -desc {If PIN is set, then customer specific authentication token is returned}] \
	] \
	-errors        [list \
		OB_ERR_CUST_BAD_MOBILE_PIN \
		DB_ERROR \
		OB_ERR_CUST_PARAMS_INCOMPLETE \
		OB_ERR_CUST_BAD_PARAM \
	]



##
# @brief Unset mobile pin
#
core::args::register \
	-interface core::cust::login::unset_mobile_pin \
	-desc {Unset mobile pin} \
	-args [list \
		[list -arg -cust_id         -mand 1 -check UINT                    -desc {Customer's id}] \
		[list -arg -admin_user_id   -mand 1 -check INT                     -desc {Admin user id}] \
		[list -arg -ipaddr          -mand 1 -check IPADDR                  -desc {IP Address of the customer}] \
		[list -arg -app_name        -mand 0 -check ASCII    -default {}    -desc {App name that the customer is using}] \
	] \
	-errors        [list \
		OB_ERR_CUST_NOT_FOUND \
		DB_ERROR\
		OB_ERR_CUST_PARAMS_INCOMPLETE \
	]



##
# @brief Check if the mobile pin is set
#
core::args::register \
	-interface core::cust::login::is_mobile_pin_set \
	-desc {Check if the mobile pin is set} \
	-args [list \
		[list -arg -cust_id         -mand 1 -check UINT        -desc {Customer's id}] \
	] \
	-return_data [list \
		[list -arg -status            -mand 1 -check {EXACT -args {MOBILE_PIN_SET MOBILE_PIN_NOT_SET MOBILE_PIN_REMOVED}}                 -desc {Confirms Mobile PIN status}] \
		[list -arg -last_unset_date   -mand 0 -check DATE                                                                   -default {}   -desc {Last date when the PIN was unset}] \
		[list -arg -status_reason     -mand 0 -check STRING                                                                 -default {}   -desc {Reason for the current status, will only be populated if status is MOBILE_PIN_REMOVED}] \
	] \
	-errors        [list \
		OB_ERR_CUST_NOT_FOUND \
	]



##
# @brief do login
#
core::args::register \
	-interface core::cust::login::login \
	-desc {Log the customer in using password/bib pin or mobile pin.} \
	-args [list \
		[list -arg -admin_user_id      -mand 0 -check INT                      -default {}    -desc {Admin user id}] \
		[list -arg -cust_id            -mand 0 -check UINT                     -default {}    -desc {Customer's id}] \
		[list -arg -username           -mand 0 -check ASCII                    -default {}    -desc {Customer username}] \
		[list -arg -password           -mand 0 -check STRING                   -default {}    -desc {Customer password}] \
		[list -arg -acct_no            -mand 0 -check ASCII                    -default {}    -desc {Account number for the customer}] \
		[list -arg -pin                -mand 0 -check INT                      -default {}    -desc {BIB PIN}] \
		[list -arg -mobile_pin         -mand 0 -check {RE -args {^\d\d\d\d$}}  -default {}    -desc {Customer PIN}] \
		[list -arg -dob                -mand 0 -check DATE                     -default {}    -desc {Customer Date of birth}] \
		[list -arg -login_uid          -mand 0 -check ASCII                    -default {}    -desc {Login ID}] \
		[list -arg -enable_elite       -mand 0 -check INT                      -default 0     -desc {Switch to perform elite check}] \
		[list -arg -ambiguous_login    -mand 0 -check INT                      -default 0     -desc {}] \
		[list -arg -do_site_checking   -mand 0 -check INT                      -default 1     -desc {check to see if the user is trying to login the same site as his registration one}] \
		[list -arg -channel            -mand 0 -check ASCII                    -default {}    -desc {Channel used to login}] \
		[list -arg -ipaddr             -mand 0 -check IPADDR                   -default {}    -desc {IP Address of the customer}] \
		[list -arg -lock_on_failure    -mand 0 -check INT                      -default 1     -desc {}] \
		[list -arg -token              -mand 0 -check STRING                   -default {}    -desc {Token stored on customer browser}] \
		[list -arg -app_name           -mand 0 -check ASCII                    -default {}    -desc {App name that the customer is using}] \
	] \
	-return_data [list \
		[list -arg -cust_id            -mand 1 -check UINT      -desc {The cust id of the customer, if the login was successful}] \
		[list -arg -username           -mand 1 -check ASCII     -desc {The username of the customer, if the login was successful}] \
		[list -arg -acct_no            -mand 1 -check ASCII     -desc {The account number of the customer, if the login was successful}] \
	] \
	-errors        [list \
		OB_ERR_CUST_ACCT_LOCKED \
		OB_ERR_CUST_ACCT_BLOCKED \
		OB_ERR_CUST_ACCT_FAILED \
		OB_ERR_CUST_BAD_UNAME \
		OB_ERR_CUST_BAD_REG \
		OB_ERR_CUST_PARAMS_INCOMPLETE \
		OB_ERR_CUST_SEQ \
		OB_ERR_CUST_BAD_ACCT \
		OB_ERR_CUST_BAD_PIN \
		OB_ERR_CUST_ACCT_SUS \
		OB_ERR_CUST_ACCT_LOCKED \
		OB_ERR_CUST_ELITE \
		OB_ERR_CUST_ACCT_CLOSED \
		OB_ERR_CUST_IN_SELF_EXCL \
		OB_ERR_CUST_OUT_SELF_EXCL \
		OB_ERR_ACCT_SUS_NOT_AGE_VRF \
		OB_ERR_CUST_PIN_LEN \
		OB_ERR_CUST_NO_PINPWD \
		OB_ERR_CUST_PWD_LEN \
		OB_ERR_CUST_PT_FUN_ACCT \
		OB_ERR_CUST_ACCT_SOFT_LOCKED \
		OB_ERR_CUST_LOSTL_PARAMS_INCOMPLETE \
		OB_ERR_CUST_LOSTL_HARD_LOCKED \
		OB_ERR_CUST_LOSTL_CC_HARD_LOCKED \
		OB_ERR_CUST_BAD_PIN_TOKEN \
		OB_ERR_CUST_NO_PIN_TOKEN_SUPPLIED \
		OB_ERR_CUST_BAD_CREDENTIALS \
		OB_ERR_CUST_BAD_MIGRATION \
		DB_ERROR \
	]
