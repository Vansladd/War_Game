# Copyright (C) 2012 Orbis Technology Ltd. All Rights Reserved.
#
# Core video functionality
#
#
set pkg_version 1.0
package provide core::video $pkg_version

# Dependencies
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::video \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::args \
		core::check] \
	-docs xml/video/video.xml

namespace eval core::video {
	variable CORE_DEF

	set CORE_DEF(errors) [list \
		DB_ERROR \
		VIDEO_STREAM_NOT_AVAILABLE \
		VIDEO_STREAM_PROVIDER_NOT_SUPPORTED \
	]
}

#
# Init
#
core::args::register \
	-interface  core::video::init \
	-args      [list \
		[list -arg -traceware_check       -mand 0 -check  BOOL                                     -default  1      -desc {Traceware checking enabled?}]  \
		[list -arg -other_video_providers -mand 0 -check  ASCII -default_cfg OTHER_VIDEO_PROVIDERS -default  [list] -desc {Other video providers list}]  \
		[list -arg -video_shm_groups      -mand 0 -check  ASCII -default_cfg VIDEO_SHM_GROUPS      -default  [list] -desc {SHM groups used to provide video SHM Key}]  \
		[list -arg -safe_tvscust_insert   -mand 0 -check  BOOL  -default_cfg SAFE_TVSCUST_INSERT   -default 1       -desc {Check existing record before inserting in tvscust (not to break unique index)}]  \
		] \
	-body {
		if {![catch {
			package require core::harness::video 1.0
		} msg]} {
			core::log::write {INFO} {Harness is being loaded}
			core::harness::video::init
		}
	}

# Make a request to a video provider populating an array with all the relevant stream
# details that can provide us with
#
# @param -days          - number of days in the future to retrieve (1 is current day)
# @param -start_date    - start date for requesting details for
# @param -end_date      - end date for requesting details for
# @param -existing_rows - number of rows already in the detail array (can be existing data)
#
# @returns       - the number of stream details the array was populated with
#
core::args::register \
	-interface core::video::make_provider_request \
	-desc      { makes a request to video providers, used by scripts and admin } \
	-args      [list \
		[list  -arg  -provider       -mand  1  -check  ASCII  -desc  {The provider.}]  \
		[list  -arg  -start_date     -mand  0  -check  DATE   -desc  {Start date for query.} -default {} ]  \
		[list  -arg  -end_date       -mand  0  -check  DATE   -desc  {End date for query.} -default {}  ]  \
		[list  -arg  -existing_rows  -mand  0  -check  UINT   -desc  {Kept for compatibility.}]  \
	]


#
# Get Video streams allowed for this event:
#
# @param -id    : Id of the EVENT,CLASS or TYPE.
# @param -level : Level in OB hierarchy, i.e. EVENT,CLASS or TYPE.
# @param -ipaddr   : Ipaddress of caller.
# @param -country_code : Country code.
# @returns  - list of streams for this event where the country is not in the tVSQualCountry table
#            with deny = Y and the user is in a country the streams are able to be viewed from
#            and any rule(s) applied (rows in tVSQualRule) are satisfied
#
core::args::register \
	-interface core::video::get_allowed_video_streams \
	-desc      {} \
	-args      [list \
		[list  -arg  -id         -mand  0  -check  UINT    -desc  {Id of the EVENT,CLASS or TYPE.}]  \
		[list  -arg  -level      -mand  0  -check  ASCII   -desc  {Level in OB hierarchy, i.e. EVENT CLASS or TYPE.}]  \
		[list  -arg  -ipaddr        -mand  1  -check  IPADDR  -desc  {Ipaddress of caller.}]  \
		[list  -arg  -country_code  -mand  0  -check  ASCII   -default 0 -desc  {Country code}]  \
	]

#
# video::getOtherVideoProvidersForEvent
#
# Checks which video providers, other than the ones we store stream information
# for, will be providing a video stream for the specified event.
#
# @param   -ev_id - Id of event to find video providers for
#
# @returns - A list in either of the following formats:
#
#           On success - [1 <video providers>*]
#           On Failure - [0]
#
core::args::register \
	-interface core::video::get_other_video_providers_for_ev \
	-desc      { Get alternative video providers, used by OXi } \
	-args      [list \
		[list  -arg  -ev_id          -mand  1  -check  UINT    -desc {Id of the openbet event.}]   \
	]

#
# Request a URL for viewing a particular video stream
# @param -provider    : The provider.
# @param -ev_id    : Id of the openbet event.
# @param -stream_id    : Id of the stream.
# @param -remote_player    : Enable remote player?
# @param -cust_id    : Id of customer making the query.
# @param -ipaddr    : Ipaddress of caller.
# @param -channel    : Channel.
# @param -session_id    : SessionId of caller.
#
core::args::register \
	-interface core::video::get_stream_url \
	-desc      { Get the  particular video stream URL, used by OXi and the front end } \
	-returns   STRING \
	-args      [list \
		[list  -arg  -provider       -mand  1  -check  ASCII                 -desc {The provider.}]  \
		[list  -arg  -ev_id          -mand  1  -check  UINT                  -desc {Id of the openbet event.}]   \
		[list  -arg  -stream_id      -mand  0  -check  UINT    -default  -1  -desc {Id of the stream.}]  \
		[list  -arg  -remote_player  -mand  0  -check  BOOL    -default  0   -desc {Enable remote player?}]  \
		[list  -arg  -cust_id        -mand  0  -check  UINT    -default  -1  -desc {Id of customer making the query.}]  \
		[list  -arg  -ipaddr         -mand  0  -check  IPADDR  -default  {}  -desc {Ipaddress of caller.}] \
		[list  -arg  -channel        -mand  0  -check  Az      -default  "I" -desc {Channel.}] \
		[list  -arg  -session_id     -mand  0  -check  ASCII                 -desc {SessionId of caller.}] \
	]



#
# Remove a mapping between a stream and an Openbet hierachy entry
# @param -provider    : The provider
#
core::args::register \
	-interface core::video::delete_stream_map \
	-desc      { Remove a mapping of a stream in the OB hierarchy, used by admin } \
	-args      [list \
		[list -arg -provider         -mand 1 -check ASCII -desc {The provider}] \
		[list -arg -del_list         -mand 0 -check LIST  -desc {List of events to delete} -default [list]] \
		[list -arg -event_unset_list -mand 0 -check LIST  -desc {List of events to unset}  -default [list]]\
	]

#
# Add a mapping between a stream and an Openbet hierachy entry.
# @param -provider    : The provider.
# @param -event_list    : List of events to map.
#
core::args::register \
	-interface core::video::add_stream_mapping \
	-desc      { Add a mapping of a stream to the OB hierarchy, used by admin } \
	-args      [list \
		[list  -arg  -provider    -mand  1  -check  ASCII   -desc  {The provider.}]  \
		[list  -arg  -event_list  -mand  0  -check  STRING  -desc  {List of events to map.}]  \
	]

#
# Create automatting mapping of streams to the OB hierarchy, used by admin.
#
# @param -provider        : The provider.
# @param -start_date      : Lowest  start date of streams to consider.
#                            (NB : PERFORM defaults to now).
# @param -end_date        : Highest start date of streams to consider.
#                            (NB : PERFORM defaults to now + 1d).
# @param -result_unmapped : Result mapped, for COBAIN.
core::args::register \
	-interface core::video::auto_stream_mapping \
	-desc      { Create automatting mapping of streams to the OB hierarchy, used by admin } \
	-args      [list \
		[list -arg -provider        -mand 1 -check ASCII -desc {The provider.}] \
		[list -arg -start_date      -mand 0 -check DATE  -desc {Lowest  start date of streams to consider.}] \
		[list -arg -end_date        -mand 0 -check DATE  -desc {Highest start date of streams to consider.}] \
		[list -arg -result_unmapped -mand 0 -check ASCII -desc {Result mapped.}] \
	]

#
# Find the start and end time of a video stream, used by OXi.
#
# @param -provider    : The provider.
core::args::register \
	-interface core::video::get_stream_time \
	-desc      { Find the start and end time of a video stream, used by OXi } \
	-args      [list \
		[list  -arg  -stream_id  -mand  1  -check  UINT  -desc  {Id of the stream in tVideoStream.}]  \
	]

#
# Perform a query against the db populating an array with all relevant stream details
# that have already been mapped, including the Openbet details of the mapping.
#
# @param -provider    : The provider.
# @param -start_date  : Start date for query.
# @param -end_date    : End date for query.
# @param -existing_rows    : Kept for compatibility.
core::args::register \
	-interface core::video::do_mapped_streams_request \
	-desc      { Perform a query against the db populating an array with all relevant stream details
 that have already been mapped, including the Openbet details of the mapping } \
	-args      [list \
		[list  -arg  -provider       -mand  1  -check  ASCII  -desc  {The provider.}]  \
		[list  -arg  -start_date     -mand  0  -check  DATE   -desc  {Start date for query.}]  \
		[list  -arg  -end_date       -mand  0  -check  DATE   -desc  {End date for query.}]  \
		[list  -arg  -existing_rows  -mand  0  -check  UINT   -desc  {Kept for compatibility.}]  \
	]

#
# Update a customer's stream status
#
# @param -provider : The video stream provider
# @param -level    : The level in the OB hierarchy
# @param -level_id : The OB ID at the given level
# @param -cust_id  : The customer ID
# @param -status   : The status the customer's stream status will be updated to
core::args::register \
	-interface core::video::update_cust_stream_status \
	-desc      { Update the customer's stream status } \
	-args      [list \
		[list  -arg  -provider       -mand  1  -check  ASCII     -desc {The video stream provider.}]  \
		[list  -arg  -level          -mand  1  -check  ASCII     -desc {The level in the OB hierarchy.}]  \
		[list  -arg  -level_id       -mand  1  -check  UINT      -desc {The OB ID at the given level.}]  \
		[list  -arg  -cust_id        -mand  1  -check  UINT      -desc {The customer ID.}]  \
		[list  -arg  -status         -mand  1  -check  ASCII     -desc {The status the customer's stream status will be updated to.}]  \
	]

#
# Returns the stream type of a stream currently linked to an Openbet id in the Event hierarchy
#
# @param -provider : The video stream provider
# @param -level    : The level in the OB hierarchy
# @param -level_id : The OB ID at the given level
core::args::register \
	-interface   core::video::get_stream_type \
	-desc        { Returns stream type } \
	-errors      $::core::video::CORE_DEF(errors) \
	-return_data [list \
		[list  -arg  -stream_type    -mand  1  -check  ASCII     -desc {The stream type.}] \
	] \
	-args        [list \
		[list  -arg  -provider       -mand  1  -check  ASCII     -desc {The video stream provider.}]  \
		[list  -arg  -id             -mand  1  -check  UINT      -desc {The OB ID at a given level of the OB hierarchy.}]  \
		[list  -arg  -level          -mand  1  -check  ASCII     -desc {The level in the OB hierarchy.}]  \
	]
