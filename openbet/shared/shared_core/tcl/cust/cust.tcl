# Copyright (C) 2012 Orbis Technology Ltd. All Rights Reserved.
#
# Core customer functionality
#
#
set pkg_version 1.0
package provide core::cust $pkg_version

# Dependencies
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::cust \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::args \
		core::check] \
	-docs xml/cust/cust.xml

namespace eval core::cust {}

core::args::register \
	-interface core::cust::update_indexes \
	-desc      {Update the Indexed registration fields for a customer} \
	-args      [list \
		[list -arg -cust_id       -mand 1 -check UINT                                     -desc {Customer Id to update}] \
		[list -arg -trigger_op    -mand 0 -check {ENUM -args {insert update}} -default {} -desc {The customer operation that triggered the update}] \
		[list -arg -transactional -mand 0 -check BOOL                         -default 1  -desc {Should we perform this in a transaction}] \
	] \
	-returns   NONE
