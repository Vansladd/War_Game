# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Notification interface
#
set pkg_version 1.0
package provide core::messaging::notification $pkg_version

# Dependencies
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::messaging::notification \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::args \
		core::check] \
	-docs interfaces-messaging/notification.xml

namespace eval core::messaging::notification {
	variable CORE_DEF

	set CORE_DEF(code)          [list -arg -code          -mand 1 -check STRING             -desc {Trigger Code: Indicates what notification is required - Example: WINNING_BET}]
	set CORE_DEF(cust_id)       [list -arg -cust_id       -mand 1 -check UINT                -desc {The customer id}]
	set CORE_DEF(priority)      [list -arg -priority      -mand 0 -check INT    -default 0  -desc {Numerical representation for queue process priority}]
	set CORE_DEF(calling_app)   [list -arg -calling_app   -mand 0 -check STRING -default "" -desc {Application triggering the message}]
	set CORE_DEF(source)        [list -arg -source        -mand 0 -check STRING -default "" -desc {Source / Channel}]
	set CORE_DEF(ref_key)       [list -arg -ref_key       -mand 0 -check STRING -default "" -desc {Table reference key. tBet - BET, tPmt - PMT}]
	set CORE_DEF(ref_id)        [list -arg -ref_id        -mand 0 -check ASCII  -default "" -desc {Unique id of record in referenced table used to furnish the message}]
	set CORE_DEF(reason)        [list -arg -reason        -mand 0 -check STRING -default "" -desc {Why the notification is being sent - mostly used for internal messages}]
	set CORE_DEF(content_path)  [list -arg -content_path  -mand 0 -check STRING -default "" -desc {Relative path to attachments directory and files}]
	set CORE_DEF(transactional) [list -arg -transactional -mand 0 -check {EXACT -args {Y N}} -default "N" -desc {Indicates whether to check for duplicate messages and insert into the queue in the same transaction}]
	set CORE_DEF(send_at)       [list -arg -send_at       -mand 0 -check DATETIME -default {} -desc {Indicates the time after which the message will be sent}]
	set CORE_DEF(payload)       [list -arg -payload       -mand 0 -check STRING -default "" -desc {Additional/optimised payload data associated with the message}]
	set CORE_DEF(do_exclusion_checks) [list -arg -do_exclusion_checks -mand 0 -check {EXACT -args {Y N}} -default "Y" -desc {Indicates whether to perform checks against self exclusion status}]
}

# Register the interface.
core::args::register \
	-interface core::messaging::notification::init

core::args::register \
	-interface   core::messaging::notification::trigger_message \
	-desc        {Registers the message in system and triggers its sending} \
	-errors      [list DB_ERROR] \
	-return_data [list \
			[list -arg -sent -mand 1 -check BOOL   -desc {Failure may happen when the message is OK but wasn't sent due to checks (eg. Vangard)}] \
			[list -arg -msg  -mand 0 -check STRING -desc {Description of the reason why message was not sent}] \
		] \
	-args        [list \
			$::core::messaging::notification::CORE_DEF(code) \
			$::core::messaging::notification::CORE_DEF(cust_id) \
			$::core::messaging::notification::CORE_DEF(priority) \
			$::core::messaging::notification::CORE_DEF(calling_app) \
			$::core::messaging::notification::CORE_DEF(source) \
			$::core::messaging::notification::CORE_DEF(ref_key) \
			$::core::messaging::notification::CORE_DEF(ref_id) \
			$::core::messaging::notification::CORE_DEF(reason) \
			$::core::messaging::notification::CORE_DEF(content_path) \
			$::core::messaging::notification::CORE_DEF(transactional) \
			$::core::messaging::notification::CORE_DEF(send_at) \
			$::core::messaging::notification::CORE_DEF(payload) \
			$::core::messaging::notification::CORE_DEF(do_exclusion_checks) \
		]

