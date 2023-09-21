# $Id: perform.tcl,v 1.1 2011/10/04 12:25:13 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Functions for managing video streaming, stream/event mapping and viewing qualification
#
# Public procedures:
#
#  video::init           - Initialises queries etc
#

#
# Dependancies (standard packages)
#
package require http
package require tdom
package require util_util

package provide perform 1

namespace eval video::perform {

}


#
# Public procedures
# ===================================================================================


#
# Retrieve mapped Perform video stream details for specified number of days
#
# days               - number of days in the future to retrieve (1 is current day)
# startDate, endDate - bounds to find streams within
#
# Returns - the number of streams returned
#
proc video::perform::doMappedPerformStreams {{days 1} {startDate ""} {endDate ""} {existing_maps 0} {perftype "PERFORM"}} {

	global DB PERFORM

	set PERFORM(ids) [list]

	OT_LogWrite INFO "$perftype: Attempting to get mapped Perform streams"

	if {$perftype == "PERFORM"} {
		if {$startDate == ""} {
			if {$days != "-"} {
				set startDate [clock format [clock scan now] -format "%Y-%m-%d"]
				set endDate   [clock format [clock scan "now + $days days"] -format "%Y-%m-%d"]
			} else {
				set startDate "0001-01-01"
				set endDate   "9999-12-31"
			}
		}
	} else {
		if {$startDate == ""} {
			if {$days != "-"} {
				set startDate [clock format [clock scan "now - $days days"] -format "%Y-%m-%d"]
				set endDate   [clock format [clock scan now] -format "%Y-%m-%d"]
			} else {
				set startDate "0001-01-01"
				set endDate   "9999-12-31"
			}
		}
	}

	if {$perftype == "PERFORM"} {
		set stmt [inf_prep_sql $DB {
			select
				vs.stream_id,
				vs.start_time as startdatetime,
				vs.end_time as enddatetime,
				vsp.pf_ev_id as id,
				vsp.content_type as contenttypeid,
				vsp.chargeable,
				vsl.content_link_id,
				vsl.level_name,
				vsl.level_id
			from
				tVideoStream vs,
				tVSPerform vsp,
				tVSContentLink vsl
			where
				vs.stream_id = vsp.stream_id
			and vs.stream_id = vsl.stream_id
			and vs.start_time >= ?
			and vs.end_time <= ?
		}]
	} else {
		set stmt [inf_prep_sql $DB {
			select
				vs.stream_id,
				vs.start_time as startdatetime,
				vs.end_time as enddatetime,
				vsp.pf_vod_ev_id as id,
				vsp.content_type as contenttypeid,
				vsl.content_link_id,
				vsl.level_name,
				vsl.level_id
			from
				tVideoStream vs,
				tVSPerformVOD vsp,
				tVSContentLink vsl
			where
				vs.stream_id = vsp.stream_id
			and vs.stream_id = vsl.stream_id
			and vs.start_time >= ?
			and vs.end_time <= ?
			and
				 ( vsp.clip_type = 3 or
					 vsp.clip_type = 6
				 )
		}]
	}

	if {[catch {set rs [inf_exec_stmt $stmt "$startDate 00:00:00" "$endDate 23:59:59"]} msg]} {
		OT_LogWrite ERROR "$perftype: couldn't retrieve mapped Perform streams : $msg"
		inf_close_stmt $stmt
		return [list 0 "Error retrieving mapped streams"]
	}

	inf_close_stmt $stmt

	set n_rows [db_get_nrows $rs]

	if {$n_rows != 0} {
		set arr_pos $existing_maps

		for {set i 0} {$i < $n_rows} {incr i} {
			lappend PERFORM(ids) [db_get_col $rs $i id]
			foreach colName [db_get_colnames $rs] {
				set PERFORM($arr_pos,$colName) [db_get_col $rs $i $colName]

				#
				# populate the Openbet information for what the stream is linked to
				#--------------------------------------------------------------------------
				if {$colName == "level_id" && $PERFORM($arr_pos,$colName) != ""} {
					switch [db_get_col $rs $i level_name] {
						CLASS {
							set stmt [inf_prep_sql $DB {
								select
									category as name,
									 name as desc
								 from
									 tEvClass
									 where
									 ev_class_id = ?
							}]

							set rs_2 [inf_exec_stmt $stmt $PERFORM($arr_pos,level_id)]
							inf_close_stmt $stmt

							set PERFORM($arr_pos,ob_link) "CLASS::GoClass&ClassId=$PERFORM($arr_pos,level_id)"
							set PERFORM($arr_pos,ob_type_name)  [db_get_col $rs_2 0 name]
							set PERFORM($arr_pos,ob_event_desc) [db_get_col $rs_2 0 desc]

							db_close $rs_2
						}
						TYPE {
							set stmt [inf_prep_sql $DB {
								select
									c.name as name,
									t.name as desc,
									t.ev_class_id as ev_class_id
								from
									tEvClass c,
									tEvType t
								where
									t.ev_class_id = c.ev_class_id and
									t.ev_type_id = ?
							}]

							set rs_2 [inf_exec_stmt $stmt $PERFORM($arr_pos,level_id)]
							inf_close_stmt $stmt

							set ev_class_id                     [db_get_col $rs_2 0 ev_class_id]
							set PERFORM($arr_pos,ob_link)       "TYPE::GoType&ClassId=$ev_class_id&TypeId=$PERFORM($arr_pos,level_id)"
							set PERFORM($arr_pos,ob_type_name)  [db_get_col $rs_2 0 name]
							set PERFORM($arr_pos,ob_event_desc) [db_get_col $rs_2 0 desc]

							db_close $rs_2
						}
						EVENT {
							set stmt [inf_prep_sql $DB {
								select
									t.name,
									e.desc
								from
									tEvType t,
									tEv e
								where
									e.ev_type_id = t.ev_type_id
									and ev_id = ?
							}]

							set rs_2 [inf_exec_stmt $stmt $PERFORM($arr_pos,level_id)]
							inf_close_stmt $stmt

							if {[db_get_nrows $rs_2] > 0} {
								set PERFORM($arr_pos,ob_link) "EVENT::GoEv&EvId=$PERFORM($arr_pos,level_id)"
								set PERFORM($arr_pos,ob_type_name)  [db_get_col $rs_2 0 name]
								set PERFORM($arr_pos,ob_event_desc) [db_get_col $rs_2 0 desc]
							}

							db_close $rs_2
						}
					}


					if {$perftype == "PERFORM"} {
						# get the blocked country codes for this event
						#-------------------------------------------------------------------------------
						set stmt [inf_prep_sql $DB {
							select
								country_code
							from
								tVSQualCountry
							where
								stream_id = ?
							and deny = 'Y'
						}]

						if {[catch {set rs_3 [inf_exec_stmt $stmt $PERFORM($arr_pos,stream_id)]} msg]} {
							# not really the end of the world, allow to keep going
							OT_LogWrite ERROR "$perftype: couldn't retrieve mapped Perform stream blocked country codes : $msg"
						} else {
							inf_close_stmt $stmt

							set n_rows_3 [db_get_nrows $rs_3]

							set blockedCountryCodes [list]

							for {set j 0} {$j < $n_rows_3} {incr j} {
								lappend blockedCountryCodes [db_get_col $rs_3 $j "country_code"]
							}

							set PERFORM($arr_pos,blockedcountrycodes) [join $blockedCountryCodes { }]
							set PERFORM($arr_pos,shortblkdcntrys) [_createShortString $PERFORM($arr_pos,blockedcountrycodes) 20]

							db_close $rs_3
						}
					}


					# get the description for this event
					#-------------------------------------------------------------------------------
					set stmt [inf_prep_sql $DB {
						select
							text as desc_chunk
						from
							tVSPerformDesc
						where
							stream_id = ?
						order by
							order
					}]

					if {[catch {set rs_4 [inf_exec_stmt $stmt $PERFORM($arr_pos,stream_id)]} msg]} {
						# not really the end of the world, allow to keep going
						OT_LogWrite ERROR "$perftype: couldn't retrieve mapped Perform stream description : $msg"
					} else {
						inf_close_stmt $stmt

						set n_rows_4 [db_get_nrows $rs_4]

						if {$n_rows_4 > 0} {
							set full_desc [list]
							for {set k 0} {$k < $n_rows_4} {incr k} {
								lappend full_desc [db_get_col $rs_4 $k "desc_chunk"]
							}

							set PERFORM($arr_pos,description) [join $full_desc ""]

							# create a short desc for nice display
							set PERFORM($arr_pos,short_desc) [_createShortString [db_get_col $rs_4 0 "desc_chunk"] 40]
						}

						db_close $rs_4
					}

					set PERFORM($arr_pos,map_status) Y
				}
			}
			incr arr_pos
		}
	}

	db_close $rs

	return $n_rows
}


# Retrieve Perform video stream details for specified number of days
#
# days    - number of days in the future to retrieve (1 is current day)
#
# Returns - the number of streams returned
#
proc video::perform::doPerformStreamRequest {
	{days 1} \
	{startDate ""} \
	{endDate ""} \
	{existing_maps 0} \
	{perftype "PERFORM"} \
	{subperftype {}} \
	} {

	global DB PERFORM

	# flick informix date format to Perform style
	regsub -all {[-]} $startDate {} qryStartDate
	regsub -all {[-]} $endDate {} qryEndDate

	if {$perftype == "PERFORM"} {
		OT_LogWrite INFO {PERFORM: Attempting to get Perform stream info}
		if {$days == "-"} {
			set period "&startDate=${qryStartDate}&endDate=${qryEndDate}"
		} else {
			set period "&days=${days}"
		}
	} else {
		OT_LogWrite INFO "PERFVOD($subperftype): Attempting to get Perform stream info"
		if {$days != "-"} {
			set days         [expr $days * 86400]
			set qryStartDate [clock format [expr [clock scan seconds] - $days] -format %Y%m%d]
			set qryEndDate   [clock format [clock scan seconds] -format %Y%m%d]
		}
	}

	# make a request to get the Perform 'event' xml, place it in a tdom structure
	if {$subperftype != ""} {
		set stmt [inf_prep_sql $DB {
				select
				ev_list_url
			from
				tVPPerform      vp,
				tVideoProvider  pp,
				tVideoProvider  sp
			where
				pp.video_provider    =  ?                     and
				sp.video_provider    =  ?                     and
				pp.video_provider_id =  vp.video_provider_id  and
				sp.video_provider_id =  vp.sub_provider_id
		}]
	} else {
		set stmt [inf_prep_sql $DB {
			select
				ev_list_url
			from
				tVPPerform      vp,
				tVideoProvider  pp,
				outer tVideoProvider  sp
			where
				pp.video_provider    =  ?                     and
				sp.video_provider    is null                  and
				pp.video_provider_id =  vp.video_provider_id  and
				sp.video_provider_id =  vp.sub_provider_id
		}]
	}


	if {[catch {set rs [inf_exec_stmt $stmt $perftype $subperftype]} msg]} {
		set err_msg "failed to retrieve Perform URL from database"
		OT_LogWrite ERROR "$perftype - $subperftype: $err_msg : $msg"
		err_bind $err_msg
		return [list 0 $err_msg]
	}
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 0} {
		# fail gracefully
		db_close $rs
		set err_msg "no Perform URLs to retrieve from database"
		OT_LogWrite ERROR "$perftype - $subperftype: $err_msg : $msg"
		err_bind $err_msg
		return [list 0 $err_msg]
	}

	set base_url [db_get_col $rs 0 ev_list_url]

	if {$perftype == "PERFORM"} {
		set request_url $base_url$period
	} else {
		set request_url [format $base_url $qryStartDate $qryEndDate]
	}

	db_close $rs

	OT_LogWrite INFO "$perftype: requesting Perform video stream data from $request_url"

	set proxy_name [OT_CfgGet PERFORM_USE_PROXY ""]
	OT_LogWrite INFO "proxy_name=$proxy_name"
	if {$proxy_name != ""} {
		if {![ob_util::set_proxy $proxy_name]} {
			OT_LogWrite ERROR "PERFORM - Use Proxy config item set but no proxy details defined"
			set err_msg "Proxy details not defined"
			err_bind $err_msg
			return [list 0 $err_msg]
		}
	}

	set token  [http::geturl $request_url -timeout [OT_CfgGet PERFORM_HTTP_TIMEOUT 10000]]
	set ncode  [http::ncode $token]
	set data   [http::data $token]
	set status [http::status $token]
	http::cleanup $token

	if {$proxy_name != ""} {
		ob_util::revert_proxy
	}

	OT_LogWrite INFO "$perftype: perform returned http $ncode, $data"
	OT_LogWrite INFO "$perftype: http status is $status"


	if {$ncode != 200} {
		OT_LogWrite ERROR "$perftype: http did not return 200 response, return $ncode"
			set err_msg "There was a problem getting stream information from Perform, reply HTTP: $ncode"
			err_bind $err_msg
			return [list 0 $err_msg]
	}

	OT_LogWrite INFO "Raw data from PERFORM: $data"

	set doc [dom parse -simple $data]

	if {$perftype == "PERFORM"} {
		set stream_count [_doParseDocPerform $doc $existing_maps]
	} else {
		set stream_count [_doParseVoDDocPerform $doc $existing_maps $subperftype]
	}

	$doc delete

	return $stream_count
}

#
# Map a Perform stream to an Openbet hierachy entry. The details of the Perform
# stream will be added to the db
#
proc video::perform::doPerformMapping {addList {perftype "PERFORM"}} {

	global DB

	OT_LogWrite INFO "doPerformMapping: addList: $addList perftype: $perftype"

	if {![llength $addList]} {
		 err_bind "No streams have been selected for mapping"
		 return [list 0 "No streams selected for mapping"]
	}

	set eventMapped 0
	set eventNotMapped 0

	# Add the mapping for all events selected
	foreach eventList $addList {

		if {$perftype == "PERFORM"} {
			set performId           [lindex $eventList 0]
			set obId                [lindex $eventList 1]
			set obLevel             [lindex $eventList 2]
			set contentTypeId       [lindex $eventList 3]
			set startDateTime       [lindex $eventList 4]
			set endDateTime         [lindex $eventList 5]
			set description         [lindex $eventList 6]
			set chargeable          [lindex $eventList 7]
			set blockedCountryCodes [lindex $eventList 8]

			set stmt [inf_prep_sql $DB {
				execute procedure pInsVSMapPerform (
					p_video_provider = ?,
					p_start_time     = ?,
					p_end_time       = ?,
					p_level_name     = ?,
					p_level_id       = ?,
					p_pf_ev_id       = ?,
					p_content_type   = ?,
					p_chargeable     = ?,
					p_transactional  = ?
				)
			}]
		} else {
			set performId           [lindex $eventList 0]
			set obId                [lindex $eventList 1]
			set obLevel             [lindex $eventList 2]
			set contentTypeId       [lindex $eventList 3]
			set startDateTime       [lindex $eventList 4]
			set endDateTime         [lindex $eventList 5]
			set description         [lindex $eventList 6]
			set chargeable          [lindex $eventList 7]
			set startsec3           [lindex $eventList 8]
			set endsec3             [lindex $eventList 9]
			set startsec4           [lindex $eventList 10]
			set endsec4             [lindex $eventList 11]
			set extpath3            [lindex $eventList 12]
			set extpath4            [lindex $eventList 13]
			set subProvider         [lindex $eventList 14]

			set stmt [inf_prep_sql $DB {
				execute procedure pInsVSMapPerformVOD (
					p_video_provider = ?,
					p_sub_provider   = ?,
					p_start_time     = ?,
					p_end_time       = ?,
					p_level_name     = ?,
					p_level_id       = ?,
					p_pf_vod_ev_id   = ?,
					p_content_type   = ?,
					p_start_sec_a    = ?,
					p_end_sec_a      = ?,
					p_start_sec_b    = ?,
					p_end_sec_b      = ?,
					p_ext_path_a     = ?,
					p_ext_path_b     = ?,
					p_transactional  = ?
				)
			}]
		}

		if {$perftype == "PERFORM"} {
			if {[catch {set rs [inf_exec_stmt $stmt \
									[OT_CfgGet PERFORM_VP_TAG "PERFORM"] \
									$startDateTime \
									$endDateTime \
									$obLevel \
									$obId \
									$performId \
									$contentTypeId \
									$chargeable \
									Y
			]} msg]} {
				OT_LogWrite ERROR "$perftype: couldn't insert Perform stream mapping : $msg"
				err_bind "Failure inserting the Perform mapping"
				inf_close_stmt $stmt

				incr eventNotMapped
				continue
			}
		} else {
			if {[catch {set rs [inf_exec_stmt $stmt \
									[OT_CfgGet PERFVOD_VP_TAG "PERFVOD"] \
									$subProvider \
									$startDateTime \
									$endDateTime \
									$obLevel \
									$obId \
									$performId \
									$contentTypeId \
									$startsec3 \
									$endsec3 \
									$startsec4 \
									$endsec4 \
									$extpath3 \
									$extpath4 \
									Y
			]} msg]} {
				OT_LogWrite ERROR "$perftype: couldn't insert Perform stream mapping : $msg"
				err_bind "Failure inserting the Perform mapping"
				inf_close_stmt $stmt

				incr eventNotMapped
				continue
			}
		}

		incr eventMapped
		set streamId [db_get_coln $rs 0 0]

		db_close $rs

		# store the blocked country codes
		#---------------------------------------------------------------------------------------
		if {$perftype == "PERFORM"} {
			foreach cntry_code [split $blockedCountryCodes { }] {

				set stmt [inf_prep_sql $DB {
					execute procedure pInsVSQualCountry (
						p_stream_id    = ?,
						p_country_code = ?,
						p_deny         = ?
					)
				}]

				# Perform use ISO-3166 country encoding, we don't... this is the only one that matter though
				set country_code [string map {GB UK} $cntry_code]

				if {[catch {set rs [inf_exec_stmt $stmt $streamId $country_code "Y"]} msg]} {
					OT_LogWrite ERROR "$perftype: couldn't insert Perform blocked country entry : $msg"
					#err_bind "Failure storing the Perform blocked country codes"
					inf_close_stmt $stmt

					#return [list 0 "Failure storing blocked country codes"]
				}

				db_close $rs
			}
		}


		# store the description
		#---------------------------------------------------------------------------------------
		set descLength [string length $description]
		set begin 0
		set end   254
		set i     0

		set add_chunk 1
		while {$add_chunk} {
			set chunk [string range $description $begin $end]

			set stmt [inf_prep_sql $DB {
				execute procedure pInsVSPerformDesc (
					p_stream_id = ?,
					p_text      = ?,
					p_order     = ?
				)
			}]

			if {[catch {set rs [inf_exec_stmt $stmt $streamId $chunk $i]} msg]} {

				OT_LogWrite ERROR "$perftype: couldn't insert Perform stream description : $msg"

				inf_close_stmt $stmt

				#return [list 0 "Failure storing stream description"]
			}

			db_close $rs

			incr i
			incr begin 255
			incr end   255

			# stop when there is no more string left
			if {$begin > $descLength} {
				set add_chunk 0
			}
		}
	}

	msg_bind "$eventMapped Events have been mapped"

	if {$eventNotMapped} {
		err_bind "$eventNotMapped Events have not been mapped"
	} else {
		tpSetVar     IsError 0
	}

	return 1
}

#
# Removed a mapping between a Perform stream and an Openbet hierachy entry
#
proc video::perform::doPerformMapDelete {} {

	global DB USERNAME

	set delList [list]
	for {set n 0} {$n < [reqGetNumVals]} {incr n} {
			if {[regexp {^DELETE_(\d+)$} [reqGetNthName $n] all deleteId]} {
					lappend delList [reqGetArg DELETE_ID_$deleteId]
			}
	}

	OT_LogWrite INFO "PERFORM: doPerformMapDelete called, delList = $delList"

	if {![llength $delList]} {
		 err_bind "No streams have been selected for deletion"
		 return [list 0 "No streams selected for deletion"]
	}

	# Delete the mapping for all events selected
	set errorCount 0
	foreach contentLinkId $delList {

		set stmt [inf_prep_sql $DB {
			execute procedure pDelVSMapPerform (
				p_content_link_id = ?,
				p_adminuser       = ?,
				p_transactional   = ?
			)
		}]

		if {[catch {set rs [inf_exec_stmt $stmt \
								$contentLinkId \
								$USERNAME \
								Y
		]} msg]} {
			OT_LogWrite ERROR "PERFORM: couldn't delete Perform stream mapping : $msg"
			inf_close_stmt $stmt
			return [list 0 "Error deleting mapping"]
		}

		db_close $rs
	}

	if {!$errorCount} {
		msg_bind "[llength $delList] Perform stream mappings have been deleted"
	}

	return 1
}


#
# Make a watch request to perform so that a customer is allowed to view a stream,
# and if successful return the URL needed to display the flash stream player.
#
proc video::perform::getPerformVideoStreamURL  {cust_id ev_id eventId stream_id} {

	set base_url  [OT_CfgGet PERFORM_ADD_USER_URL {}]
	set partnerId [OT_CfgGet PERFORM_PARTNER_ID {}]
	set seed      [OT_CfgGet PERFORM_ACCESS_SEED {}]
	set watch_url [OT_CfgGet PERFORM_WATCH_URL {}]

	set md5_string "${cust_id}${partnerId}${eventId}L${seed}"

	set key [urlencode [bintob64 [hextobin [md5 $md5_string]]]]

	set add_user_url "${base_url}?partnerId=${partnerId}&eventId=${eventId}&userId=${cust_id}&key=${key}"
	OT_LogWrite INFO "PERFORM: making Perform add user request to $add_user_url"

	set proxy_name [OT_CfgGet PERFORM_USE_PROXY ""]
	if {$proxy_name != ""} {
		if {![ob_util::set_proxy $proxy_name]} {
			OT_LogWrite ERROR "PERFORM - Use Proxy config item set but no proxy details defined"
			set err_msg "Proxy details not defined"
			err_bind $err_msg
			return [list 0 $err_msg]
		}
	}

	if {[catch {set token [http::geturl $add_user_url -timeout [OT_CfgGet PERFORM_HTTP_TIMEOUT 10000]]} msg]} {
		set return_status $msg
	} else {

		set ncode  [http::ncode $token]
		set data   [http::data $token]
		set status [http::status $token]
		http::cleanup $token

		if {$proxy_name != ""} {
			ob_util::revert_proxy
		}

		OT_LogWrite INFO "PERFORM: perform returned http $ncode, $data"
		OT_LogWrite INFO "PERFORM: http status is $status"

		if {$ncode != 200} {
			OT_LogWrite ERROR "PERFORM: http did not return 200 response, return $ncode"
				set err_msg "There was a problem getting stream information from Perform, reply HTTP: $ncode"
				err_bind $err_msg
				return [list 0 $err_msg]
		}

		if {[regexp {^[a-zA-Z]*} $data return_status]} {
			if {$return_status == "success"} {
				return [list 1 "$watch_url?partnerId=$partnerId&eventId=$eventId&userId=$cust_id&flash=y"]
			}
		} else {
			set return_status $data
		}
	}

	OT_LogWrite ERROR "PERFORM: add_user request failed: $return_status"
	return [list 0 $return_status]
}


#
# Private procedures
# ===================================================================================


#
# Helper function to provide a short text result from a long string
#
proc video::perform::_createShortString {text short_length} {
	if {[string length $text] > $short_length} {
		set short_desc "[string range $text 0 [expr {$short_length - 3}]]..."
	} else {
		set short_desc $text
	}
}

#
# Helper function to parse the returned XML file for Perform streams
#
proc video::perform::_doParseDocPerform {doc {existing_maps 0}} {

	global PERFORM

	set old_pos -1

	if {[catch {
		# parse ...
		set streams [$doc getElementsByTagName "event"]
		OT_LogWrite INFO "PERFORM: we have the following streams $streams"

		set arr_pos $existing_maps
		set map_exists_id -1

		for {set i 0} {$i < [llength $streams]} {incr i} {
			foreach attr {id contentTypeId startDateTime endDateTime description chargeable location blockedCountryCodes} {
				set arr_attr [string tolower $attr]
				switch $attr {
					"id" {
						set id [[lindex $streams $i] getAttribute $attr]
						# let's see if this id is in the mapped list
						set existing_id_pos [lsearch $PERFORM(ids) $id]
						if {$existing_id_pos > -1} {
							set map_exists_id $id
							set old_pos $arr_pos
							set arr_pos $existing_id_pos
						} else {
							set map_exists_id -1
							lappend PERFORM(ids) $id
							set PERFORM($arr_pos,$arr_attr) $id
							set old_pos -1
						}
					}
					"startDateTime" -
					"endDateTime" {
						# informix format datetime
						regsub {T} [[lindex $streams $i] getAttribute $attr] { } full_time
						set inf_time [string range $full_time 0 18]
						if {$map_exists_id > -1} {
							foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
								set PERFORM($existing_pos,$arr_attr) $inf_time
							}
						} else {
							set PERFORM($arr_pos,$arr_attr) $inf_time
						}
					}
					"chargeable" {
						if {$map_exists_id > -1} {
							foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
								set PERFORM($existing_pos,$arr_attr) [string map {false N true Y} [[lindex $streams $i] getAttribute $attr]]
							}
						} else {
							set PERFORM($arr_pos,$arr_attr) [string map {false N true Y} [[lindex $streams $i] getAttribute $attr]]
						}
					}
					default {
						if {$map_exists_id > -1} {
							foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
								set PERFORM($existing_pos,$arr_attr) [[lindex $streams $i] getAttribute $attr]
							}
						} else {
							set PERFORM($arr_pos,$arr_attr) [[lindex $streams $i] getAttribute $attr]
						}

						# extra parameters bound for some attributes
						switch $attr {
							"description" {

								if {$map_exists_id > -1} {
									foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
										set PERFORM($existing_pos,short_desc) [_createShortString [[lindex $streams $i] getAttribute $attr] 40]
									}
								} else {
									set PERFORM($arr_pos,short_desc) [_createShortString [[lindex $streams $i] getAttribute $attr] 40]
								}

							}
							"blockedCountryCodes" {
								if {$map_exists_id > -1} {
									foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
										set PERFORM($existing_pos,shortblkdcntrys) [_createShortString [[lindex $streams $i] getAttribute $attr] 20]
									}
								} else {
									set PERFORM($arr_pos,shortblkdcntrys) [_createShortString [[lindex $streams $i] getAttribute $attr] 20]
								}
							}
						}
					}
				}
			}

			if {$old_pos > -1} {
				set arr_pos $old_pos
				set old_pos -1
			} else {
				# add dummy rows for non xml array elements
				set PERFORM($arr_pos,map_status) ""
				set PERFORM($arr_pos,ob_event_desc) ""

				incr arr_pos
			}
		}
	} msg]} {
		OT_LogWrite ERROR "PERFORM: failed to parse : $msg"
	}

	return [llength $streams]

}

#
# Helper function to parse the returned XML file for VoD Perform streams
#
proc video::perform::_doParseVoDDocPerform {doc {existing_maps 0} {sub_perf_type {}}} {

	global PERFORM

	set old_pos -1

	if {[catch {
		# parse ...
		set streams [$doc getElementsByTagName "event"]
		set no_of_streams [llength $streams]
		OT_LogWrite INFO "PERFVOD($sub_perf_type): we have the following streams $streams"

		set arr_pos $existing_maps
		set map_exists_id -1

		for {set i 0} {$i < [llength $streams]} {incr i} {
			foreach attr {id contentTypeId startDateTime endDateTime description chargeable location} {
				set arr_attr [string tolower $attr]
				switch $attr {
					"id" {
						set id [[lindex $streams $i] getAttribute $attr]
						# let's see if this id is in the mapped list
						set existing_id_pos [lsearch $PERFORM(ids) $id]
						if {$existing_id_pos > -1} {
							set map_exists_id $id
							set old_pos $arr_pos
							set arr_pos $existing_id_pos
						} else {
							set map_exists_id -1
							lappend PERFORM(ids) $id
							set PERFORM($arr_pos,$arr_attr)   $id
							set old_pos -1
						}
						set PERFORM($arr_pos,subProvider) $sub_perf_type
					}
					"startDateTime" -
					"endDateTime" {
						# informix format datetime
						regsub {T} [[lindex $streams $i] getAttribute $attr] { } full_time
						set inf_time [string range $full_time 0 18]
						if {$map_exists_id > -1} {
							foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
								set PERFORM($existing_pos,$arr_attr) $inf_time
							}
						} else {
							set PERFORM($arr_pos,$arr_attr) $inf_time
						}
					}
					"chargeable" {
						if {$map_exists_id > -1} {
							foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
								set PERFORM($existing_pos,$arr_attr) [string map {false N true Y} [[lindex $streams $i] getAttribute $attr]]
							}
						} else {
							set PERFORM($arr_pos,$arr_attr) [string map {false N true Y} [[lindex $streams $i] getAttribute $attr]]
						}
					}
					default {
						if {$map_exists_id > -1} {
							foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
								set PERFORM($existing_pos,$arr_attr) [[lindex $streams $i] getAttribute $attr]
							}
						} else {
							set PERFORM($arr_pos,$arr_attr) [[lindex $streams $i] getAttribute $attr]
						}

						# extra parameters bound for some attributes
						switch $attr {
							"description" {

								if {$map_exists_id > -1} {
									foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
										set PERFORM($existing_pos,short_desc) [_createShortString [[lindex $streams $i] getAttribute $attr] 40]
									}
								} else {
									set PERFORM($arr_pos,short_desc) [_createShortString [[lindex $streams $i] getAttribute $attr] 40]
								}

							}
						}
					}
				}
			}

			# Get the clip info for VoD
			set clips [[lindex $streams $i] getElementsByTagName "clips"]
			set clip  [[lindex $clips 0]    getElementsByTagName "clip"]

			for {set j 0} {$j < [llength $clip]} {incr j} {
				set clipType     [[lindex $clip $j] getAttribute "clipType"]
				set startSec     [[lindex $clip $j] getAttribute "startSec"]
				set endSec       [[lindex $clip $j] getAttribute "endSec"]
				set file         [[lindex $clip $j] getElementsByTagName "file"]
				set externalPath [[lindex $file 0]  getAttribute "externalPath"]

				switch $clipType {
					6 -
					3 {
						if {$map_exists_id > -1} {
							foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
								set PERFORM($existing_pos,startsec3)     $startSec
								set PERFORM($existing_pos,endsec3)       $endSec
								set PERFORM($existing_pos,externalpath3) $externalPath
							}
						} else {
							set PERFORM($arr_pos,startsec3)     $startSec
							set PERFORM($arr_pos,endsec3)       $endSec
							set PERFORM($arr_pos,externalpath3) $externalPath
						}
					}
					7 -
					4 {
						if {$map_exists_id > -1} {
							foreach existing_pos [lsearch -all $PERFORM(ids) $map_exists_id] {
								set PERFORM($existing_pos,startsec4)     $startSec
								set PERFORM($existing_pos,endsec4)       $endSec
								set PERFORM($existing_pos,externalpath4) $externalPath
							}
						} else {
							set PERFORM($arr_pos,startsec4)     $startSec
							set PERFORM($arr_pos,endsec4)       $endSec
							set PERFORM($arr_pos,externalpath4) $externalPath
						}

					}
				}
			}

			if {$old_pos > -1} {
				set arr_pos $old_pos
				set old_pos -1
			} else {
				# If we have no externalPath at this stage, then we do not
				# care about this stream at this point. delete all references to it!
				if {[llength $externalPath] > 0} {
					# add dummy rows for non xml array elements
					set PERFORM($arr_pos,map_status) ""
					set PERFORM($arr_pos,ob_event_desc) ""

					incr arr_pos
				} else {
					set no_of_ids    [llength $PERFORM(ids)]
					set PERFORM(ids) [lrange $no_of_ids 0 end-1]

					if {[catch {
						# Unset all the entries we dont want binded/used later
						unset PERFORM($arr_pos,id)
						unset PERFORM($arr_pos,contentTypeId)
						unset PERFORM($arr_pos,startDateTime)
						unset PERFORM($arr_pos,endDateTime)
						unset PERFORM($arr_pos,description)
						unset PERFORM($arr_pos,chargeable)
						unset PERFORM($arr_pos,location)

						unset PERFORM($arr_pos,startsec3)
						unset PERFORM($arr_pos,endsec3)
						unset PERFORM($arr_pos,externalpath3)
						unset PERFORM($arr_pos,startsec4)
						unset PERFORM($arr_pos,endsec4)
						unset PERFORM($arr_pos,externalpath4)
					}]} {}

					incr no_of_streams -1
				}
			}
		}
	} msg]} {
		OT_LogWrite ERROR "PERFVOD($sub_perf_type): failed to parse : $msg"
	}

	return $no_of_streams

}
