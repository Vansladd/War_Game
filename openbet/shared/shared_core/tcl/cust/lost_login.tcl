# Copyright (C) 2012 OpenBet Technology Ltd. All Rights Reserved.
#
# Lost Login interface
#
# Synopsis:
#   This is the interface for the process of a customer attempting to retrive
#   lost username or reset their password if they have forgotten it.
#
set pkg_version 1.0
package provide core::cust::lost_login $pkg_version

# Dependencies
package require core::args   1.0
package require core::check  1.0
package require core::log    1.0

core::args::register_ns \
	-namespace core::cust::lost_login \
	-version   $pkg_version \
	-dependent [list \
		core::args \
		core::check \
	] \
	-docs xml/cust/lost_login.xml

namespace eval core::cust::lost_login {
	variable CORE_DEF
	set CORE_DEF(username)    [list -arg -username    -mand 1 -check STRING -desc {Customers username}]
	set CORE_DEF(email)       [list -arg -email       -mand 1 -check STRING -desc {Customers email address}]
	set CORE_DEF(ip_addr)     [list -arg -ip_addr     -mand 1 -check IPADDR -desc {Customers IP address}]
	set CORE_DEF(channel)     [list -arg -channel     -mand 1 -check ASCII  -desc {Channel the request comes from}]
	set CORE_DEF(application) [list -arg -application -mand 1 -check ASCII  -desc {Calling application}]
	set CORE_DEF(cust_id)     [list -arg -cust_id     -mand 1 -check UINT   -desc {Customer ID}]

}

# Register lost_login interface

core::args::register \
	-interface core::cust::lost_login::init \
	-desc {Initialises the lost login package} \
	-args [list \
		[list -arg -token_crypt_key             -mand 0 -check HEX   -default_cfg CUST_LOST_LOGIN_CRYPT_KEY    -default {}              -desc {aes crypt key for the email link token}] \
		[list -arg -token_mac_key               -mand 0 -check HEX   -default_cfg CUST_LOST_LOGIN_MAC_KEY      -default {}              -desc {hmac key for the email link token}] \
		[list -arg -password_reset_token_expiry -mand 0 -check UINT  -default_cfg CUST_LOST_LOGIN_TOKEN_EXPIRY -default 1800            -desc {Email link Token expiry time from creation, in seconds}] \
		[list -arg -token_type                  -mand 0 -check ASCII -default_cfg CUST_LOST_LOGIN_TOKEN_TYPE   -default {LOST_PASSWORD} -desc {Token Type}] \
		[list -arg -lost_password_link          -mand 0 -check ASCII -default_cfg CUST_LOST_LOGIN_LINK         -default {}              -desc {Base URL for the password reset page}] \
	]

core::args::register \
	-interface core::cust::lost_login::get_security_checks_password_recovery \
	-desc {Retrieve the security questions for a customer} \
	-returns ASCII \
	-args [list \
		[list -arg -token       -mand 1 -check STRING -desc {Token given to customer in password recovery email}] \
		$::core::cust::lost_login::CORE_DEF(ip_addr) \
		$::core::cust::lost_login::CORE_DEF(channel) \
		$::core::cust::lost_login::CORE_DEF(application) \
	]

core::args::register \
	-interface core::cust::lost_login::answer_security_checks_password_recovery \
	-desc {Check the given answers correctly answer the customers security questions and sets a new password} \
	-returns ASCII \
	-args [list \
		$::core::cust::lost_login::CORE_DEF(cust_id) \
		$::core::cust::lost_login::CORE_DEF(ip_addr) \
		$::core::cust::lost_login::CORE_DEF(application) \
		$::core::cust::lost_login::CORE_DEF(channel) \
		[list -arg -answer_1    -mand 1 -check STRING -desc {Answer to security question 1}] \
		[list -arg -answer_2    -mand 1 -check STRING -desc {Answer to security question 2}] \
		[list -arg -password    -mand 1 -check STRING -desc {Customers new password}] \
	]

core::args::register \
	-interface core::cust::lost_login::email_reset_link \
	-desc {Send an email with a link to the password recovery page with a single use token} \
	-returns ASCII \
	-args [list \
		[list -arg -dob -mand 0 -check DATE -default {} -desc {Customers date of birth}] \
		$::core::cust::lost_login::CORE_DEF(email) \
		$::core::cust::lost_login::CORE_DEF(ip_addr) \
		$::core::cust::lost_login::CORE_DEF(channel) \
		[list -arg -application -mand 0 -check ASCII -default {unknown} -desc {Calling application}] \
	]

core::args::register \
	-interface core::cust::lost_login::get_questions_attempts_remaining \
	-desc {Return how many attempts the user has left to answer their questions} \
	-returns ASCII \
	-args [list \
		[list -arg -type -mand 1 -check ASCII -desc {type of attempt - questions or answers}]
	]

core::args::register \
	-interface core::cust::lost_login::email_username_details \
	-desc {Send an email with the customers username} \
	-returns ASCII \
	-args [list \
		[list -arg -dob -mand 1 -check DATE -desc {Customers date of birth}] \
		$::core::cust::lost_login::CORE_DEF(email) \
		$::core::cust::lost_login::CORE_DEF(ip_addr) \
		$::core::cust::lost_login::CORE_DEF(channel) \
		$::core::cust::lost_login::CORE_DEF(application) \
	]

core::args::register \
	-interface core::cust::lost_login::email_temporary_password \
	-desc {Send an email to the customer with a temporary password} \
	-returns ASCII \
	-args [list \
		[list -arg -dob -mand 1 -check DATE -desc {Customers date of birth}] \
		$::core::cust::lost_login::CORE_DEF(username) \
		$::core::cust::lost_login::CORE_DEF(email) \
		$::core::cust::lost_login::CORE_DEF(ip_addr) \
		$::core::cust::lost_login::CORE_DEF(channel) \
		$::core::cust::lost_login::CORE_DEF(application) \
	]

core::args::register \
	-interface core::cust::lost_login::generate_link_reset_password \
	-desc {Generate a link to reset password of a customer} \
	-returns ASCII \
	-args [list \
		$::core::cust::lost_login::CORE_DEF(cust_id) \
		$::core::cust::lost_login::CORE_DEF(username) \
		$::core::cust::lost_login::CORE_DEF(email) \
	]
