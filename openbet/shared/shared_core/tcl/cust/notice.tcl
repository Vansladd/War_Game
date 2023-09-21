
# Copyright (C) 2012 Orbis Technology Ltd. All Rights Reserved.
#
# Core notice functionality
#
#
set pkg_version 1.0

package provide core::cust::notice $pkg_version

# Dependencies
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::cust::notice \
	-version   $pkg_version \
	-dependent [list \
	core::log \
	core::args \
	core::check] \
	-docs xml/cust/notice.xml

namespace eval core::cust::notice {}

core::args::register \
	-interface core::cust::notice::init \
	-args [list]

core::args::register \
	-interface  core::cust::notice::get_notice_count \
	-desc      {Get the count of read and unread notices for a customer.} \
	-args      [list \
		[list  -arg  -cust_id      -mand  1  -check  UINT      -desc  {The customer id.}]  \
	]

core::args::register \
	-interface core::cust::notice::insert \
	-desc      {Create a customer notice for a given customer.} \
	-args      [list \
		[list  -arg  -cust_id      -mand  1  -check  UINT      -desc  {The customer id.}]  \
		[list  -arg  -notice_type  -mand  1  -check  Az        -desc  {Type of the notice, either B or I}]  \
		[list  -arg  -body         -mand  0  -check  ANY       -desc  {Body of the notice, can be html.}]  \
		[list  -arg  -xl_code      -mand  0  -check  ANY       -desc  {Translation code.}]  \
		[list  -arg  -title        -mand  1  -check  STRING    -desc  {Title of notice.}]  \
		[list  -arg  -from_date    -mand  0  -check  DATETIME  -desc  {Start date of the notice.}]  \
		[list  -arg  -to_date      -mand  0  -check  DATETIME  -desc  {End date of the notice.}]  \
		[list  -arg  -msg_from     -mand  0  -check  STRING    -desc  {Notice sender}]  \
		[list  -arg  -user_id      -mand  0  -check  ASCII     -desc  {Admin user identifier}] \
	]


core::args::register \
	-interface core::cust::notice::get \
	-desc      {Get one notice for a customer.} \
	-args      [list \
		[list  -arg  -cust_id    -mand  1  -check  UINT  -desc  {The customer id.}]  \
		[list  -arg  -notice_id  -mand  1  -check  UINT  -desc  {The id of the notice to be retrieved.}]  \
	]


core::args::register \
	-interface core::cust::notice::get_all \
	-desc      {Get all notices for a customer by specified filters (optional).} \
	-args      [list \
		[list  -arg  -cust_id      -mand  1  -check  UINT   -desc  {The customer id.}]  \
		[list  -arg  -filters      -mand  0  -check  ANY    -desc  {The list of key/value pairs}]  \
	]


core::args::register \
	-interface core::cust::notice::mark_read \
	-desc      {Mark read a list of notices.} \
	-args      [list \
		[list  -arg  -cust_id          -mand  1  -check  UINT   -desc  {The customer id.}]  \
		[list  -arg  -list_notice_ids  -mand  1  -check  ASCII  -desc  {List of notice ids to be marked read.}]  \
	]

core::args::register \
	-interface core::cust::notice::update \
	-desc      {Updates a notice. } \
	-args      [list \
		[list  -arg  -cust_id      -mand  1  -check  UINT      -desc  {The customer id.}]  \
		[list  -arg  -notice_id    -mand  1  -check  UINT      -desc  {The id of the notice to be retrieved.}]  \
		[list  -arg  -body         -mand  0  -check  ANY       -desc  {Body of the notice, can be html.}]  \
		[list  -arg  -xl_code      -mand  0  -check  ANY       -desc  {Translation code.}]  \
		[list  -arg  -title        -mand  1  -check  STRING    -desc  {Title of notice.}]  \
		[list  -arg  -from_date    -mand  0  -check  DATETIME  -desc  {Start date of the notice.}]  \
		[list  -arg  -to_date      -mand  0  -check  DATETIME  -desc  {End date of the notice.}]  \
		[list  -arg  -msg_from     -mand  0  -check  STRING    -desc  {Notice sender}]  \
		[list  -arg  -user_id      -mand  0  -check  ASCII     -desc  {Admin user identifier}] \
	]

core::args::register \
	-interface core::cust::notice::delete \
	-desc      {Delete a list of notices.} \
	-args      [list \
		[list  -arg  -cust_id          -mand  1  -check  UINT   -desc  {The customer id.}]  \
		[list  -arg  -list_notice_ids  -mand  1  -check  ASCII  -desc  {List of notice ids to be deleted.}]  \
		[list  -arg  -user_id          -mand  0  -check  ASCII  -desc  {Admin user identifier}] \
	]

core::args::register \
	-interface core::cust::notice::clean \
	-desc      {Delete all read notices before this date.} \
	-args      [list \
		[list  -arg  -delete_from  -mand  1  -check  DATETIME  -desc  {All read notices whose creation date is before this date will be deleted.}]  \
	]
