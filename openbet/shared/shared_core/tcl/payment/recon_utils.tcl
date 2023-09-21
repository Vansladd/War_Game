# Copyright (C) 2016 Openbet Ltd. All Rights Reserved.
#
# reconciliation utils interface
#
set pkg_version 1.0
package provide core::payment::recon_utils $pkg_version

# Dependencies
package require core::payment 1.0
package require core::args    1.0
package require core::log     1.0
package require core::check   1.0

core::args::register_ns \
	-namespace core::payment::recon_utils \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::args \
		core::check] \
	-docs      xml/payment/recon_utils.xml

namespace eval core::payment::recon_utils {
	variable CORE_DEF

	set CORE_DEF(message)            [list -arg -message           -mand 1             -check ASCII                       -desc {The decrypted message to be processed}]
	set CORE_DEF(paymthd)            [list -arg -paymthd           -mand 1             -check ASCII                       -desc {The payment method the reconciliation file refers to}]
	set CORE_DEF(filename)           [list -arg -filename          -mand 1             -check ASCII                       -desc {the name of the file to be processed, created or deleted}]
	set CORE_DEF(complete)           [list -arg -complete          -mand 1             -check BOOL                        -desc {Flag that shows whether recon file is partial or not}]
}


core::args::register \
	-interface core::payment::recon_utils::process_message \
	-desc      {Process reconciliation message line by line and call reconciliation proc for each payment.} \
	-args       [list \
		$::core::payment::recon_utils::CORE_DEF(message)  \
		$::core::payment::recon_utils::CORE_DEF(paymthd)  \
		$::core::payment::CORE_DEF(oper_id)               \
		$::core::payment::recon_utils::CORE_DEF(filename) \
	] \
	-return_data [list \
		[list -arg -status -mand 1 -check {BOOL} -desc {Status of the process}] \
	] \
	-errors      [list \
		RECON_ERR \
		INVALID_ARGS \
	]



core::args::register \
	-interface core::payment::recon_utils::delete_file \
	-desc      {Delete a reconciliation backup, temporary or results file} \
	-args      [list \
		$::core::payment::recon_utils::CORE_DEF(filename)  \
	] \
	-return_data [list \
		[list -arg -status -mand 1 -check {BOOL} -desc {Status of the write}] \
	] \
	-errors      [list \
		ERR_DELETE_FILE \
		INVALID_ARGS \
	]



core::args::register \
	-interface core::payment::recon_utils::make_file \
	-desc      {Write a reconciliation backup or temporary file} \
	-return_data [list \
		[list -arg -status -mand 1 -check {BOOL} -desc {Status of the write}] \
	] \
	-args       [list \
		$::core::payment::recon_utils::CORE_DEF(paymthd)  \
		$::core::payment::recon_utils::CORE_DEF(message)  \
		$::core::payment::recon_utils::CORE_DEF(filename) \
		$::core::payment::recon_utils::CORE_DEF(complete) \
	]

