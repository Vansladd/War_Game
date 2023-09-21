# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Register callbacks for formatting of account history
#

set pkg_version 1.0
package provide core::history::formatter $pkg_version

# Dependencies
package require core::log            1.0
package require core::args           1.0
package require core::interface      1.0

core::args::register_ns \
	-namespace core::history::formatter \
	-version   $pkg_version \
	-dependent [list core::log core::args core::interface] \
	-docs      history/formatter.xml

namespace eval core::history::formatter {
	variable FORMATTER
	array set FORMATTER {}
}

# Interface that must be met by each callback
core::interface::register \
	-interface core::history::formatter::formatter \
	-args [list \
		[list -arg -item         -mand 1 -check ANY    -desc {Item requiring formatting}] \
		[list -arg -acct_id      -mand 0 -check UINT   -desc {Account id}] \
		[list -arg -lang         -mand 0 -check ASCII  -desc {Language code for customer}] \
		[list -arg -detail_level -mand 0 -check ASCII  -desc {Detail level of the history item}] \
	]

# Add a formatter callback
core::args::register \
	-proc_name core::history::formatter::add \
	-args [list \
		[list -arg -group -check ASCII -mand 1 \
			-desc {Group to apply formatter callback to}] \
		[list -arg -formatter -check ASCII -mand 1 \
			-desc {Callback which takes an unformatted item and outputs a formatted item. This should accept the following parameters: -acct_id -lang -detail_level -item}] \
	] \
	-body {
		variable FORMATTER

		set group $ARGS(-group)
		set formatter $ARGS(-formatter)

		if {[lsearch [core::history::get_groups] $group] == -1} {
			error INVALID_GROUP
		}

		core::interface::check_proc -interface core::history::formatter::formatter -proc_name $formatter

		set FORMATTER($group) $formatter
		core::log::write INFO {Using $formatter to format $group items}
}

# Apply a formatter callback
core::args::register \
	-proc_name core::history::formatter::apply \
	-is_public 0 \
	-args [list \
		[list -arg -item -check ANY -mand 1 -desc {History item requiring formatting}] \
		[list -arg -lang -check ASCII -mand 1 -desc {Language of the customer}] \
		[list -arg -acct_id -check INT -mand 1 -desc {Account ID of the customer}] \
		[list -arg -detail_level -check ASCII -mand 1 -desc {Detail level of the item}] \
	] \
	-body {
		variable FORMATTER
		set args [core::args::check core::history::formatter::apply {*}$args]

		set item  [dict get $args -item]
		set group [dict get $item group]

		if {![info exists FORMATTER($group)]} {
			core::log::write DEBUG {No formatter defined for \"$group\"}
			return [dict get $args -item]
		}

		return [core::interface::run_proc \
			-interface        core::history::formatter::formatter \
			-proc_name        $FORMATTER($group) \
			-args             $args]
}
