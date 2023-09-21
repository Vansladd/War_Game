# Copyright (C) 2014 Openbet Ltd. All Rights Reserved.
#
# Cash Card payment interface
#
set pkg_version 1.0
package provide core::payment::CSCD $pkg_version

# Dependencies
package require core::payment 1.0
package require core::log     1.0
package require core::args    1.0
package require core::check   1.0

core::args::register_ns \
	-namespace core::payment::CSCD \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs      xml/payment/CSCD.xml

namespace eval core::payment::CSCD {
	variable CORE_DEF

	set CORE_DEF(status)            [list -arg -status        -mand 1 -check ASCII                  -desc {Cash Card status}]

	# Cash Card specific parameters
	set CORE_DEF(ret,opt)           [list -arg -ret           -mand 0 -check BOOL      -default 0   -desc {Denotes whether the procedure was successful}]
	set CORE_DEF(err_code,opt)      [list -arg -err_code      -mand 0 -check ASCII     -default ""  -desc {the associated error code if the procedure was unsuccessful}]
	set CORE_DEF(allow_linked,opt)  [list -arg -allow_linked  -mand 0 -check BOOL      -default 0   -desc {Allow creation even if a linked account has a Cash Card}]
	set CORE_DEF(timeout,opt)       [list -arg -timeout       -mand 0 -check UINT      -default 0   -desc {Timeout for 3rd party requests}]
	set CORE_DEF(activation_id,opt) [list -arg -activation_id -mand 0 -check ASCII     -default ""  -desc {Key to activate a Cash Card}]
	set CORE_DEF(start_date,opt)    [list -arg -start_date    -mand 0 -check DATETIME  -default ""  -desc {Start date for transaction search}]
	set CORE_DEF(end_date,opt)      [list -arg -end_date      -mand 0 -check DATETIME  -default ""  -desc {End date for transaction search}]
	set CORE_DEF(channel,opt)       [list -arg -channel       -mand 0 -check ASCII     -default ""  -desc {Source / Channel}]
	set CORE_DEF(balance,opt)       [list -arg -balance       -mand 0 -check MONEY                  -desc {Cash Card balance}]
	set CORE_DEF(cpm_id)            [list -arg -cpm_id        -mand 1 -check INT                    -desc {This would overwrite the def in core::payment}]
	set CORE_DEF(pmt_id)            [list -arg -pmt_id        -mand 1 -check INT                    -desc {The payment ID}]
}

# Register Cash Card interface
core::args::register \
	-interface core::payment::CSCD::init \
	-desc      {Initialisation procedure for Cash Card payment method} \
	-args      [list]

core::args::register \
	-interface core::payment::CSCD::insert_cpm \
	-desc      {Register a new Cash Card for a customer} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CSCD::CORE_DEF(allow_linked,opt) \
	] \
	-return_data [list \
		$::core::payment::CSCD::CORE_DEF(ret,opt) \
		$::core::payment::CSCD::CORE_DEF(err_code,opt) \
		$::core::payment::CSCD::CORE_DEF(cpm_id) \
	]

core::args::register \
	-interface core::payment::CSCD::can_register \
	-desc      {Check if a new Cash Card can be added for a customer} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CSCD::CORE_DEF(channel,opt) \
		$::core::payment::CSCD::CORE_DEF(allow_linked,opt) \
	] \
	-return_data [list \
		$::core::payment::CSCD::CORE_DEF(ret,opt) \
		$::core::payment::CSCD::CORE_DEF(err_code,opt) \
	]

core::args::register \
	-interface core::payment::CSCD::get_default_cpm \
	-desc      {Get the default Cash Card for a customer} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
	] \
	-return_data [list \
		$::core::payment::CSCD::CORE_DEF(ret,opt) \
		$::core::payment::CSCD::CORE_DEF(err_code,opt) \
		$::core::payment::CSCD::CORE_DEF(cpm_id) \
		[list -arg -status -mand 0 -check ASCII -desc {CPM status}] \
	]

core::args::register \
	-interface core::payment::CSCD::update_cpm \
	-desc      {Update a Cash Card} \
	-args      [list \
		$::core::payment::CSCD::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CSCD::CORE_DEF(status) \
		$::core::payment::CSCD::CORE_DEF(activation_id,opt) \
	] \
	-return_data [list \
		$::core::payment::CSCD::CORE_DEF(ret,opt) \
		$::core::payment::CSCD::CORE_DEF(err_code,opt) \
	]

core::args::register \
	-interface core::payment::CSCD::make_deposit \
	-desc      {Make a Cash Card deposit} \
	-args      [list \
		$::core::payment::CSCD::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(unique_id,opt) \
		$::core::payment::CSCD::CORE_DEF(channel,opt) \
		$::core::payment::CSCD::CORE_DEF(timeout,opt) \
	] \
	-return_data [list \
		$::core::payment::CSCD::CORE_DEF(ret,opt) \
		$::core::payment::CSCD::CORE_DEF(err_code,opt) \
		$::core::payment::CSCD::CORE_DEF(pmt_id) \
	]

core::args::register \
	-interface core::payment::CSCD::make_withdrawal \
	-desc      {Make a Cash Card withdrawal} \
	-args      [list \
		$::core::payment::CSCD::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(unique_id,opt) \
		$::core::payment::CSCD::CORE_DEF(channel,opt) \
		$::core::payment::CSCD::CORE_DEF(timeout,opt) \
	] \
	-return_data [list \
		$::core::payment::CSCD::CORE_DEF(ret,opt) \
		$::core::payment::CSCD::CORE_DEF(err_code,opt) \
		$::core::payment::CSCD::CORE_DEF(pmt_id) \
	]

core::args::register \
	-interface core::payment::CSCD::get_external_status \
	-desc      {Get external status of a Cash Card} \
	-args      [list \
		$::core::payment::CSCD::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
	] \
	-return_data [list \
		$::core::payment::CSCD::CORE_DEF(ret,opt) \
		$::core::payment::CSCD::CORE_DEF(err_code,opt) \
		$::core::payment::CSCD::CORE_DEF(status) \
		$::core::payment::CSCD::CORE_DEF(balance,opt) \
	]
