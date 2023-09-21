# Copyright 2015 OpenBet Technology Ltd. All Rights Reserved.
#
# Core funding interface intended to offer a account agnostic method of
# acquiring funds for a product purchase.
#
# Note: the details of what happens in any given implementation should not
#       leak upward into the product codebase itself hence this interface is
#       very simplistic.
#
# If you're wanting to add something here that isn't related solely to the
# logical stages of ANY purchase transaction then you're likely looking at the
# problem in the wrong way. Your implementation may be complicated sorry!
#

set version 1.0

package provide core::funding $version

package require core::args 1.0
package require core::check 1.0

core::args::register_ns \
	-namespace core::funding \
	-version $version \
	-dependent [list \
		core::args \
		core::check \
	] \
	-docs  interfaces/funding/funding.xml\
	-desc {Defines a generic interface to the platform funding system.}

core::args::register_ns \
	-namespace core::funding::debit \
	-version $version \
	-dependent [list \
		core::args \
		core::check \
	] \
	-desc {Sub-namespace for debit operations.}

core::args::register_ns \
	-namespace core::funding::credit \
	-version $version \
	-dependent [list \
		core::args \
		core::check \
	] \
	-desc {Sub-namespace for credit operations.}

namespace eval core::funding {

	variable definition

	set failure_code_check [list "ENUM" -args [list \
		"GENERAL_EXCEPTION" \
		"PREREQUISITE_FAILED" \
		"CANCELLATION"
	]]

	# Define a new validation type which describes the format of the data object
	# representing the breakdown of what the funds are being requested for. This
	# object contains the following keys;
	#
	#   `id`        : a unique reference for the purchased item in the originating
	#                 system
	#   `type`      : a reference to the type of transaction being performed intended
	#                 to allow grouping or lookup against an appropriate service
	#   `sub_type`  : a reference to the sub-type of transaction within the type to allow
	#                 sub-categorizing the type of transaction (optional)
	#   `amount`    : the absolute monetary value of the purchased item
	#   `desc`      : a free-text description intended for display within an account
	#                 history
	#
	# For example;
	#
	# [list \
	#   [dict create \
	#     id        123 \
	#     type      "sports-bet" \
	#     sub_type  "in-play"\
	#     amount    5.00 \
	#     desc      "Hockey / NHL / Calgary Flames at Vancouver Canucks (7:00 PST 20th Feb 2015) / Vancouver Canucks @ 2.30" \
	#   ] \
	#   ...
	# ]
	#
	catch {
		core::check::register "core::funding::PRODUCTBREAKDOWN" core::funding::_check_type_BREAKDOWN [dict create \
			name       "core::funding::PRODUCTBREAKDOWN" \
			definition [list \
				id       core::check::is_string       1\
				type     core::check::is_string       1\
				sub_type core::check::is_string       0\
				amount   core::check::money           1\
				desc     core::check::is_string       1\
			]
		]
	}

	# Define a new validation type which describes the format of the data object
	# representing the breakdown of what promotional funding sources have been
	# requested to be used with the purchase. This object contains the following
	# keys;
	#
	#   `id`         : a unique reference for the purchased item in the originating
	#                  system
	#   `type`       : a reference to the type of transaction being performed
	#                  intended to allow grouping or lookup against an appropriate
	#                  service
	#   `amount`     : the absolute monetary value of the purchased item
	#   `product_id` : the id of the item with the product breakdown that this
	#                  funding source should be used against
	#
	# For example;
	#
	# [list \
	#   [dict create \
	#     id 456 \
	#     type "ob-freebet" \
	#     amount 3.00 \
	#     product_id 123 \
	#   ] \
	#   ...
	# ]
	#
	catch {
		core::check::register "core::funding::PROMOBREAKDOWN" core::funding::_check_type_BREAKDOWN [dict create \
			name       "core::funding::PROMOBREAKDOWN" \
			definition [list \
				id         core::check::is_string      1\
				type       core::check::is_string      1\
				amount     core::check::unsigned_money 1\
				product_id core::check::is_string      1\
			]
		]
	}

	# Declare a validation type to describe a "repeat purchase" associated with a product.
	# A repeat purchase allows the originating system to provide the service or product in a timely and delayed manner
	# rather than serving n times the same product all at once.
	# This object contains the following key:
	#
	#   `id`         : a unique reference for the repeat purchase instance in the originating system
	#   `product_id` : the id of the item with the product breakdown that this
	#                  funding source should be used against
	#   `num_repeat` : The number of desired repeats or "to_infinity"
	#
	# For example:
	#
	# [list \
	#   [dict create \
	#      id          1234\
	#      product_id  123\
	#      num_repeat  10 \
	#   ] \
	#   ...
	# ]
	#
	catch {
		core::check::register "core::funding::REPEATBREAKDOWN" core::funding::_check_type_BREAKDOWN [dict create \
			name       "core::funding::REPEATBREAKDOWN" \
			definition [list \
				id          core::check::is_string          1\
				num_repeat  core::funding::check_num_repeat 1\
				product_id  core::check::is_string          1\
			]
		]
	}

	set definition(cust_id)              [list -arg "-cust_id"           -mand 1 -check "UINT"                            -desc "Openbet customer id (tCustomer.cust_id) which the transaction is being perfomed against."]
	set definition(ccy_code)             [list -arg "-ccy_code"          -mand 1 -check "STRING"                          -desc "Currency code the transaction amount is in."]
	set definition(amount)               [list -arg "-amount"            -mand 1 -check "UMONEY"                          -desc "Absolute monetary value of the transaction."]
	set definition(promo_breakdown)      [list -arg "-promo_breakdown"   -mand 1 -check "core::funding::PROMOBREAKDOWN"   -desc "List of dicts representing the breakdown of any promotional funding sources requested to be used in this purchase. Each dict must contain `id`, `type`, `amount` and `product_id` keys."]
	set definition(uid)                  [list -arg "-uid"               -mand 1 -check "STRING"                          -desc "Id which uniquely identifies this transaction in the requesting platform. Note this should remain constant through the purchase lifecycle."]
	set definition(product_breakdown)    [list -arg "-product_breakdown" -mand 1 -check "core::funding::PRODUCTBREAKDOWN" -desc "List of dicts representing the breakdown of the transaction to individual items. Each dict must contain `id`, `type`, `amount` and `desc` keys."]
	set definition(failure_code)         [list -arg "-failure_code"      -mand 1 -check $failure_code_check               -desc "A code representing the type of purchase failure."]
	set definition(source,opt)           [list -arg "-source"            -mand 0 -check "STRING"                          -desc "The channel/source this transaction is instigated from" -default {}]
	set definition(repeat_breakdown,opt) [list -arg "-repeat_breakdown"  -mand 0 -check "core::funding::REPEATBREAKDOWN"  -desc "List of dicts representing the breakdown of the transaction to individual items to be repeated n times. Each dict must contain `id`, `num_repeat`, and `product_id` keys." -default [list]]

}
namespace eval core::funding::debit {}
namespace eval core::funding::credit {}

core::args::register \
	-interface core::funding::init \
	-desc {Called to provide an opportunity to initialise the funding system implementation.}

core::args::register \
	-interface core::funding::balance \
	-desc {Called when the available balance in the funding system is required.} \
	-args [list \
		$::core::funding::definition(cust_id) \
	]

core::args::register \
	-interface core::funding::free_money_tokens \
	-desc {Called when the available free money tokens in the funding system are required.} \
	-args [list \
		$::core::funding::definition(cust_id) \
	]


core::args::register \
	-interface core::funding::debit::purchase_pending \
	-desc {Called when a purchase transaction is about to commence. Provides a hook to either fund an account or prepare for doing so.} \
	-errors [list \
		LOW_FUNDS             \
		BUILD_EXCEPTION       \
		EXECUTE_EXCEPTION     \
		ERR_ACCT              \
		ERR_INVALID_ACCT_TYPE \
		ERR_INSUFFICIENT_FUND \
		ERR_DAY_DEP_LIMIT     \
		ERR_DEP_LIMIT         \
		ERR_NO_DAY_LIMIT      \
		ERR_DDA_NOT_FOUND     \
		ERR_DDA_EXPIRED       \
		ERR_WTD_CLOSED        \
		ERR_DEP_CLOSED        \
		ERR_SYNTAX            \
		ERR_MAND_FIELD        \
		ERR_VERSION           \
		ERR_DUPLICATE         \
		ERR_MERCH_ID          \
		ERR_SYSTEM            \
		ERR_VALIDATION        \
		ERR_INT_ERROR         \
		ERR_AUTO_PMT          \
		] \
	-args [list \
		$::core::funding::definition(cust_id) \
		$::core::funding::definition(ccy_code) \
		$::core::funding::definition(amount) \
		$::core::funding::definition(promo_breakdown) \
		$::core::funding::definition(uid) \
		$::core::funding::definition(product_breakdown) \
		$::core::funding::definition(source,opt)\
		$::core::funding::definition(repeat_breakdown,opt)\
	]

core::args::register \
	-interface core::funding::debit::purchase_succeeded \
	-desc {Called when a purchase transaction has concluded successfully. Provides a hook to either confirm funds have been spent, or fund a purchase if that needs to occur post.} \
	-args [list \
		$::core::funding::definition(cust_id) \
		$::core::funding::definition(ccy_code) \
		$::core::funding::definition(amount) \
		$::core::funding::definition(promo_breakdown) \
		$::core::funding::definition(uid) \
		$::core::funding::definition(product_breakdown) \
		$::core::funding::definition(source,opt)\
		$::core::funding::definition(repeat_breakdown,opt)\
	]

core::args::register \
	-interface core::funding::debit::purchase_failed \
	-desc {Called when a purchase transaction has concluded unsuccessfully. Provides a hook to refund any funds acquired in earlier transaction stages.} \
	-args [list \
		$::core::funding::definition(cust_id) \
		$::core::funding::definition(ccy_code) \
		$::core::funding::definition(amount) \
		$::core::funding::definition(promo_breakdown) \
		$::core::funding::definition(uid) \
		$::core::funding::definition(product_breakdown) \
		$::core::funding::definition(failure_code) \
		$::core::funding::definition(source,opt)\
		$::core::funding::definition(repeat_breakdown,opt)\
	]

core::args::register \
	-interface core::funding::credit::disburse \
	-desc {Called when a disbursement to the funding system should occur.} \
	-args [list \
		$::core::funding::definition(cust_id) \
		$::core::funding::definition(ccy_code) \
		$::core::funding::definition(amount) \
		$::core::funding::definition(uid) \
		$::core::funding::definition(product_breakdown) \
		$::core::funding::definition(source,opt) \
		$::core::funding::definition(repeat_breakdown,opt)\
	]


# Helper procedure to implement a type check given a name and dict definition.
proc core::funding::_check_type_BREAKDOWN {dicts args} {
	if {![core::check::is_list $dicts]} {
		return 0
	}

	set config [lindex $args 0]
	foreach d $dicts {
		foreach {name check mandatory} [dict get $config definition] {

			if {$mandatory && ![dict exists $d $name]} {
				core::log::write INFO {[dict get $config name] validation failed - no $name field defined}
				return 0
			}

			if {[dict exists $d $name] && ![$check [dict get $d $name]]} {
				core::log::write INFO {[dict get $config name] validation failed - $name is not of type $check}
				return 0
			}
		}
	}

	return 1
}


# Check validity of the number of repeats
proc core::funding::check_num_repeat {val args} {

	if {[core::check::unsigned_integer $val] || $val == "to_infinity"} {
		return 1
	}

	return 0
}


