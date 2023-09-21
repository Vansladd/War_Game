# $Header $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Generic functions for managing video streams
#

namespace eval video {

}


#
# Public procedures
# ===================================================================================


# Make a request to a video provider populating an array with all the relevant stream
# details that can provide us with
#
# days          - number of days in the future to retrieve (1 is current day)
# startDate     - start date for requesting details for
# endDate       - end date for requesting details for
# existing_rows - number of rows already in the detail array (can be existing data)
#
# returns       - the number of stream details the array was populated with
#
proc video::doStreamRequest {provider {days 1} {startDate ""} {endDate ""} {existing_rows 0} {subProvider ""}} {
	OT_LogWrite DEBUG "VIDEO: doStreamRequest for $provider details"
	switch $provider {
		PERFORM {
			video::perform::doPerformStreamRequest $days $startDate $endDate $existing_rows $provider
		}
		PERFVOD {
			video::perform::doPerformStreamRequest $days $startDate $endDate $existing_rows $provider $subProvider
		}
	}
}


#
# Perform a query against the db populating an array with all relevant stream details
# that have already been mapped, including the Openbet details of the mapping
#
# days          - number of days in the future to retrieve (1 is current day)
# startDate     - start date for requesting details for
# endDate       - end date for requesting details for
# existing_rows - number of rows already in the detail array (can be existing data)
#
# returns       - the number of stream details the array was populated with
#
proc video::doMappedStreamsRequest {provider {days 1} {startDate ""} {endDate ""} {existing_rows 0}} {
	OT_LogWrite DEBUG "VIDEO: doMappedStreamsRequest for $provider details"
	switch $provider {
		PERFORM {
			video::perform::doMappedPerformStreams $days $startDate $endDate $existing_rows $provider
		}
		PERFVOD {
			video::perform::doMappedPerformStreams $days $startDate $endDate $existing_rows $provider
		}
	}
}


#
# Request a URL for viewing a particular video stream
#
proc video::getVideoStreamURL {provider ev_id stream_id} {
	OT_LogWrite DEBUG "VIDEO: retrieving URL to view for $provider stream_id $stream_id"
	switch $provider {
		PERFORM {
			video::perform::getPerformVideoStreamURL $ev_id $stream_id
		}
	}
}


#
# Provide a SHM caching key based on where the user is located.
# Groups are defined in the config VIDEO_SHM_GROUPS
#
proc video::getVideoSHMKey  {} {

	set use_cookie 1
	set read_guest_cookie 1

	set country_code [OB::country_check::get_ip_country [reqGetEnv REMOTE_ADDR] $use_cookie $read_guest_cookie]

	OT_LogWrite DEV "VIDEO: the country code is $country_code"

	set shm_key ""

	foreach row [OT_CfgGet VIDEO_SHM_GROUPS] {
		if {[lindex $row 0] == $country_code} {
			set shm_key [lindex $row 1]
		}
	}
	OT_LogWrite DEV "VIDEO: the shm_key is $shm_key"
	return $shm_key
}


#
# Perform a check to ensure a customer qualifies to view a video stream, individual
# provider rules will be different
#
proc video::viewStreamGatewayCheck {provider stream_id} {

	OT_LogWrite INFO {video::gatewayCheck: Running video stream gateway checks}

	switch $provider {
		PERFORM {
			video::perform::getPerformVideoStreamURL $stream_id
		}
	}
}
