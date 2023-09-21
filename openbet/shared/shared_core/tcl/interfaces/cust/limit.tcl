# Copyright 2015 OpenBet Technology Ltd. All Rights Reserved.
#
# This module provides a generic interface for customers to implement
# different types of limits.
#
# Synopsis:
#   package require core::cust::limit 1.0
#
# Procedures:
# core::cust::limit::init           - Initialise this package.
# core::cust::limit::get            - Get a customer limit details.
# core::cust::limit::get_remaining  - Get a customer's remaining limit.
# core::cust::limit::get_reset_time - Get a customer's limit reset time.
# core::cust::limit::apply          - Set a limit for a customer.
# core::cust::limit::remove         - Remove a limit for a customer.
#
# Configuration:
#   CORE.CUSTOMER.LIMIT.PACKAGES
#     - Allows for a set of packages to be automatically initialized alongside
#       the limit module (eg: those containing any callback definitions).
#       This is a list of each package definition, with each item containing
#       elements: the package name, package version, and an optional init proc
#       to be invoked.
#


set pkg_version 1.0

package provide core::cust::limit $pkg_version

package require core::log  1.0
package require core::args 1.0
package require core::util 1.0

core::args::register_ns \
	-namespace core::cust::limit \
	-version   $pkg_version \
	-dependent [list core::log core::args] \
	-docs      "xml/cust/limit.xml"

namespace eval core::cust::limit {
	variable CFG
	variable INIT 0
}



core::args::register \
	-proc_name core::cust::limit::init \
	-desc      "Initialises the customer limit module." \
	-args [list \
		[list -arg -packages -mand 0 -check LIST  -default_cfg CORE.CUSTOMER.LIMIT.PACKAGES -default [list]  -desc {A list of packages which implement the limits interfaces}] \
	] \
	-body {

		variable CFG
		variable INIT

		if {$INIT} {
			return
		}

		set fn core::cust::limit::init

		core::log::write INFO {$fn}

		# Read package configuration argument.
		set CFG(packages) $ARGS(-packages)

		# Load any additional packages needed.
		foreach package $CFG(packages) {
			lassign $package module version init
			if {[catch {
				core::util::load_package -package $module -version $version
				if {$init != {}} {
					$init
				}
			} err]} {
				core::log::write ERROR \
					{$fn: Could not initialize package '$package' - $err}
			}
		}

		set INIT 1
	}



# interface for getting limit details
#
# @param -cust_id The customer that we want to get the limit of.
# @param -type    The limit type.
#
# @return -limits A dict containing an active limit and any pending limits
#
core::args::register \
	-interface core::cust::limit::get \
	-desc "Get a limit of the specified type of a customer." \
	-args [list \
		[list -arg -cust_id -mand 1 -check INT    -desc "The customer that we want to check against."] \
		[list -arg -type    -mand 1 -check STRING -desc "The limit type."]                             \
	] \
	-return_data [list \
		[list -arg -limits -mand 1 -check NVPAIRS -desc "A dict containing an active limit and any pending limits of the specified type."] \
	] \
	-errors [list \
		DB_ERROR               \
		DB_EMPTY_RS            \
		LIMIT_ERROR            \
		INVALID_RESPONSE_ERROR \
		SORT_NOT_SUPPORTED     \
		VALUE_NOT_ALLOWED      \
	]



# interface for getting the remaining limit amount
#
# @param -cust_id The customer that we want to get the remaining limit of
# @param -type    The limit type.
#
# @return -remaining The remaining limit amount.
#
core::args::register \
	-interface core::cust::limit::get_remaining \
	-desc "Get the remaining limit" \
	-args [list \
		[list -arg -cust_id -mand 1 -check INT -desc "The customer that we want to check against."] \
		[list -arg -type    -mand 1 -check STRING -desc "The limit type."]                          \
	] \
	-return_data [list \
		[list -arg -remaining -mand 1 -check DECIMAL -desc "The remaining limit amount."] \
	] \
	-errors [list \
		DB_ERROR               \
		DB_EMPTY_RS            \
		LIMIT_ERROR            \
		INVALID_RESPONSE_ERROR \
		SORT_NOT_SUPPORTED     \
		VALUE_NOT_ALLOWED      \
	]



# interface for get_reset_time
#
# @param -cust_id The customer that we want to get the details of.
# @param -type    The limit type.
#
# @return -datetime The time when the next period begins.
#
core::args::register \
	-interface core::cust::limit::get_reset_time \
	-desc "Get the time when the next period begins." \
	-args [list \
		[list -arg -cust_id -mand 1 -check INT    -desc "The customer that we want to check against."] \
		[list -arg -type    -mand 1 -check STRING -desc "The limit type."]                             \
	] \
	-return_data [list \
		[list -arg -datetime -mand 1 -check DATETIME -desc "The time when the next period beings."] \
	] \
	-errors [list \
		DB_ERROR               \
		DB_EMPTY_RS            \
		LIMIT_ERROR            \
		INVALID_RESPONSE_ERROR \
		SORT_NOT_SUPPORTED     \
		VALUE_NOT_ALLOWED      \
	]



# interface for setting a customer's limit.
#
# @param -cust_id    The customer to set the limit against.
# @param -type       The limit type.
# @param -definition A list of name/value pairs describing the limit.
# @param -from       Limit begin datetime.
# @param -to         Limit end datetime.
# @param -force      Force the new limit to take effect immediately.
# @param -oper_id    Optional admin user ID.
#
core::args::register \
	-interface core::cust::limit::apply \
	-desc "Set a limit against a customer." \
	-args [list \
		[list -arg -cust_id    -mand 1             -check INT      -desc "The customer to set the limit against."]           \
		[list -arg -type       -mand 1             -check STRING   -desc "The limit type."]                                  \
		[list -arg -definition -mand 1             -check LIST     -desc "A list of Name/value pairs describing the limit."] \
		[list -arg -from       -mand 0 -default "" -check DATETIME -desc "The date and time when this limit begins."]        \
		[list -arg -to         -mand 0 -default "" -check DATETIME -desc "The date and time when this limit ends."]          \
		[list -arg -force      -mand 0 -default 0  -check BOOL     -desc "Force the limit into taking immediate effect."]    \
		[list -arg -oper_id    -mand 0 -default "" -check INT      -desc "Admin user id"]                                    \
	] \
	-errors [list \
		DB_ERROR               \
		DB_EMPTY_RS            \
		LIMIT_ERROR            \
		INVALID_RESPONSE_ERROR \
		SORT_NOT_SUPPORTED     \
		VALUE_NOT_ALLOWED      \
	]



# interface for removing a customer's limit.
#
# @param -cust_id The customer to remove the limit from.
# @param -type    The limit type.
# @param -force   Force the remove immediately.
# @param -oper_id Optional admin user ID.
#
core::args::register \
	-interface core::cust::limit::remove \
	-desc "Remove limit(s)" \
	-args [list \
		[list -arg -cust_id    -mand 1             -check INT    -desc "The customer that we want to have the limits removed from."] \
		[list -arg -type       -mand 1             -check STRING -desc "The limit type."]                                            \
		[list -arg -force      -mand 0 -default 0  -check BOOL   -desc "Force the limit into taking immediate effect."]              \
		[list -arg -oper_id    -mand 0 -default "" -check INT    -desc "Admin user id"]                                              \
	] \
	-errors [list \
		DB_ERROR               \
		DB_EMPTY_RS            \
		LIMIT_ERROR            \
		INVALID_RESPONSE_ERROR \
		SORT_NOT_SUPPORTED     \
		VALUE_NOT_ALLOWED      \
	]
