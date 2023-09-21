# Copyright 2015 OpenBet Technology Ltd. All Rights Reserved.
#
# This module provides a generic interface for customers to implement
# different types of one time password authentication system.
#
# Synopsis:
#   package require core::cust::one_time_password 1.0
#
# Procedures:
# core::cust::one_time_password::init           - Initialise this package.
# core::cust::one_time_password::generate       - Get an otp for a customer
# core::cust::one_time_password::validate       - Validate a give otp for a customer
#
# Configuration:
#   CORE.CUSTOMER.OTP.PACKAGES
#     - Allows for a set of packages to be automatically initialized alongside
#       the otp module (eg: those containing any callback definitions).
#       This is a list of each package definition, with each item containing
#       elements: the package name, package version, and an optional init proc
#       to be invoked.
#


set pkg_version 1.0

package provide core::cust::one_time_password $pkg_version

package require core::args 1.0

core::args::register_ns \
	-namespace core::cust::one_time_password \
	-version   $pkg_version \
	-dependent [list core::args] \
	-docs      "xml/cust/one_time_password.xml"

namespace eval core::cust::one_time_password {}

# interface for initializing the package implementing an OTP system
#
# no input parameters
# no return values
#
core::args::register \
	-interface core::cust::one_time_password::init \
	-desc "Initialize the package that implements the OTP" \
	-returns NONE

# interface for generating one time passwords
#
# @param -cust_id     The customer for whom we are generating an otp
# @param -reason      The reason why this OTP is generated
# @param -user_id     The id of the administrator user that initiates the OTP generation
# @param -challenge1  Optional challenge answer. It should match the answer for challenge 1
# @param -challenge2  Optional challenge answer. It should match the answer for challenge 2
# @param -mobile      Optional mobile phone number to receive the OTP
# @param -email       Optional email to receive the OTP
#
# @return -session a unique id for the session of this otp.
#
core::args::register \
	-interface core::cust::one_time_password::generate \
	-desc "Generate a new otp for a given customer" \
	-args [list \
		[list -arg -cust_id             -mand 1 -check INT                -desc {The customer for whom we are generating an otp.}]                       \
		[list -arg -reason              -mand 0 -check ASCII  -default {} -desc {The reason why this OTP is generated}]                                  \
		[list -arg -user_id             -mand 0 -check ASCII              -desc {The id of the administrator user that initiates the OTP generation}]    \
		[list -arg -challenge_response1 -mand 0 -check STRING             -desc {Optional challenge answer. It should match the answer for challenge 1}] \
		[list -arg -challenge_response2 -mand 0 -check STRING             -desc {Optional challenge answer. It should match the answer for challenge 2}] \
		[list -arg -mobile              -mand 0 -check STRING             -desc {Optional mobile phone number to receive the OTP}]                       \
		[list -arg -email               -mand 0 -check STRING             -desc {Optional email to receive the OTP}]                                     \
	] \
	-return_data [list \
		[list -arg -session             -mand 1 -check STRING  -desc "A unique id for the session of the OTP to be used for verification"] \
	] \
	-errors [list \
		DB_ERROR               \
		DB_EMPTY_RS            \
		OTP_ERROR              \
		INVALID_RESPONSE_ERROR \
		VALUE_NOT_ALLOWED      \
	]


# interface for validating a given OTP
#
# @param -cust_id The customer for whom we are generating an otp.
# @param -otp     The OTP that the user has in his hands
# @param -reason  The reason why this OTP is used for
# @param -session The session for this OTP as it was given during generation
#
# @returns nothing
#
core::args::register \
	-interface core::cust::one_time_password::validate \
	-desc "validate a one time password with the OTP system" \
	-args [list \
		[list -arg -cust_id -mand 1 -check INT                -desc {The customer for whom we are generating an otp.}]            \
		[list -arg -otp     -mand 1 -check STRING             -desc {The OTP that the user has in his hands}]                     \
		[list -arg -reason  -mand 0 -check ASCII  -default {} -desc {The reason why this OTP was generated/used}]                 \
		[list -arg -session -mand 0 -check STRING             -desc {The session for this OTP as it was given during generation}] \
	] \
	-returns NONE \
	-errors [list \
		DB_ERROR               \
		DB_EMPTY_RS            \
		OTP_ERROR              \
		OTP_INVALID            \
		OTP_EXPIRED            \
		OTP_USED               \
		INVALID_RESPONSE_ERROR \
		VALUE_NOT_ALLOWED      \
	]

