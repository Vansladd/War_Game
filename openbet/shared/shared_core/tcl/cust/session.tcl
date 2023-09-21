# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Customer session functionality and interfaces
#
set pkg_version 1.0
package provide core::cust::session $pkg_version

# Dependencies
package require core::payment  1.0
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::cust::session \
	-version   $pkg_version \
	-desc      {API for session management} \
	-dependent [list \
		core::cust \
		core::log \
		core::args \
		core::check] \
	-docs xml/cust/session.xml

namespace eval core::cust::session {
	variable CORE_DEF

	set CORE_DEF(cust_id)    [list -arg -cust_id     -mand 1 -check UINT              -desc {Customer identifier}]
	set CORE_DEF(session_id) [list -arg -session_id  -mand 1 -check UINT              -desc {Session identifier}]
	set CORE_DEF(user_id)    [list -arg -user_id     -mand 0 -check ASCII -default {} -desc {Admin user identifier}]
	set CORE_DEF(ipaddr)     [list -arg -ipaddr      -mand 0 -check ASCII -default {} -desc {The ipaddr of the user who made the payment}]
}

# Register customer session.
core::args::register \
	-interface core::cust::session::init

# Start a customer session.
core::args::register \
	-interface core::cust::session::start \
	-desc      {Start a customer session.} \
	-returns   ASCII \
	-args [list \
		$::core::cust::session::CORE_DEF(cust_id) \
		$::core::cust::session::CORE_DEF(user_id) \
		$::core::cust::session::CORE_DEF(ipaddr) \
		[list -arg -term_code      -mand 0 -check ASCII -default {}   -desc {Teminal code}] \
		[list -arg -source         -mand 0 -check ASCII -default {I}  -desc {Source / Channel}] \
		[list -arg -session_type   -mand 0 -check ASCII -default {M}  -desc {Session type}] \
		[list -arg -aff_id         -mand 0 -check ASCII -default {}   -desc {Affiliate identifier}] \
		[list -arg -expire_seconds -mand 0 -check ASCII -default {}   -desc {Expiry time (seconds)}] \
		[list -arg -in_tran        -mand 0 -check BOOL  -default 0    -desc {Whether we are already in a transacton}] \
	]

# Check if there is an active session for this session id.
core::args::register \
	-interface core::cust::session::check \
	-desc      {Check if there is an active session for this session id} \
	-returns   ASCII \
	-args [list \
		$::core::cust::session::CORE_DEF(session_id) \
		$::core::cust::session::CORE_DEF(ipaddr) \
	]

# Ends session for customer currently logged in.
core::args::register \
	-interface core::cust::session::end \
	-desc      {Ends session for customer currently logged in} \
	-returns   ASCII \
	-args [list \
		$::core::cust::session::CORE_DEF(session_id) \
		[list -arg -end_reason -mand 0 -check {ENUM -args {L T P C}} -default {L} \
			-desc {
				reason that the session was ended
					L - Logout
					T - Timeout
					P - Single Session Time Limit
					C - Cummulative Session Time Limit
			}] \
	]

# Cancels a session for customer. Ends the session and and records a reason as
core::args::register \
	-interface core::cust::session::cancel \
	-desc      {Cancels a session for customer. Ends the session and and records a reason as} \
	-returns   ASCII \
	-args [list \
		$::core::cust::session::CORE_DEF(session_id) \
		[list -arg -cancel_code -mand 1 -check ASCII -desc {Cancel Code}] \
		[list -arg -cancel_txt  -mand 1 -check ASCII -desc {Cancel Text}] \
	]

# Cancels a session for customer. Ends the session and and records a reason as
core::args::register \
	-interface core::cust::session::get \
	-desc      {Retrieve session details} \
	-args [list \
		[list -arg -name    -mand 0 -check ASCII -default {} -desc {Session detail name}] \
		[list -arg -default -mand 0 -check ASCII -default {} -desc {Default value}] \
	]
