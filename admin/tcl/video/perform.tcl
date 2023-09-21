# $Id: perform.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Functions for managing video streaming, stream/event mapping and viewing
# qualification
#
# Public procedures:
#
#  ADMIN::PERFORM::init           - Initialises queries etc
#

namespace eval ADMIN::PERFORM {

	asSetAct ADMIN::PERFORM::GoPerformControl \
				[namespace code go_perform_control]
	asSetAct ADMIN::PERFORM::DoPerformControl \
				[namespace code do_perform_control]
	asSetAct ADMIN::PERFORM::GoPerformStreamList \
				[namespace code go_perform_streamlist]
	asSetAct ADMIN::PERFORM::DoPerformStreamReq \
				[namespace code do_perform_streamreq]
	asSetAct ADMIN::PERFORM::GoPerformStream \
				[namespace code go_perform_stream]
	asSetAct ADMIN::PERFORM::GoStreamRequest \
				[namespace code goStreamRequest]
	asSetAct ADMIN::PERFORM::DoMapStreamRequest \
				[namespace code doMapStreamRequest]
	asSetAct ADMIN::PERFORM::DoDeleteStreamRequest \
				[namespace code doDeleteStreamRequest]
	asSetAct ADMIN::PERFORM::GoMapPerformStreams \
				[namespace code goMapPerformStreams]
	asSetAct ADMIN::PERFORM::GoProviderPerform \
				[namespace code goProviderPerform]
	asSetAct ADMIN::PERFORM::DoProviderPerform \
				[namespace code doProviderPerform]
	asSetAct ADMIN::PERFORM::GoVSQualifyBets \
				[namespace code go_vs_qualify_bets]
	asSetAct ADMIN::PERFORM::GoVSQualifyBet \
				[namespace code go_vs_qualify_bet]
	asSetAct ADMIN::PERFORM::DoVSQualifyBet \
				[namespace code do_vs_qualify_bet]
	asSetAct ADMIN::PERFORM::GoVSQualifyBetCCy \
				[namespace code go_vs_qualify_bet_ccy]
	asSetAct ADMIN::PERFORM::DoMapHorseRacing \
				[namespace code do_map_horse_racing]

}


#
# Public procedures
# ==============================================================================


#
# ----------------------------------------------------------------------------
# Generate and bind data for display video perform
# ----------------------------------------------------------------------------
#
proc ADMIN::PERFORM::go_perform_control args {

	global DB

	set columns {vp_perform_id video_provider_id\
				ev_list_url admin_req_len\
				cron_req_len archive_days\
	}

	set stmt [inf_prep_sql $DB {
		select
			*
		from
			tVPPerform
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumVPerform [set n_rows [db_get_nrows $rs]]

	if {$n_rows == 0} {

	} else {
		foreach col $columns {
			tpBindString VIDEO_[string toupper $col] [db_get_col $rs 0 $col]
		}
	}

	asPlayFile -nocache video/perform/control.html
}


#
# ----------------------------------------------------------------------------
# update data for display video perform
# ----------------------------------------------------------------------------
#
proc ADMIN::PERFORM::do_perform_control args {

	global DB DATA

	set video_provider [reqGetArg video_provider]
	set url            [reqGetArg url]
	set admin_req      [reqGetArg admin_req]
	set cron_req       [reqGetArg cron_req]
	set achive_days    [reqGetArg achive_days]
	set perform_id     [reqGetArg vp_perf_id]

	set sql [subst {
		update
			tVPPerform
		set
			video_provider = ?,
			ev_list_url   = ?,
			admin_req_len  = ?,
			cron_req_len   = ?,
			archive_days   = ?
		where
		   vp_perform_id  = ?
	}]
	set stmt [inf_prep_sql $DB $sql]

	if {[catch [inf_exec_stmt $stmt $video_provider\
											$url\
											$admin_req\
											$cron_req\
											$achive_days\
											$perform_id] msg]} {
		err_bind $msg
	}

	inf_close_stmt $stmt

	ADMIN::PERFORM::go_perform_control
}


#
# ----------------------------------------------------------------------------
# Generate and bind data for display video perform
# ----------------------------------------------------------------------------
#
proc ADMIN::PERFORM::go_perform_streamlist {{status "U"} {class_id ""}} {

	global DB STREAM

	set status   [reqGetArg status]
	set class_id [reqGetArg class_id]

	_bind_class
	set stmt [_prep_qrys $status]

	set rs_str [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set columns [db_get_colnames $rs_str]

	tpSetVar num_str [set n_rows [db_get_nrows $rs_str]]

	for {set r 0} {$r < $n_rows} {incr r} {
		foreach col $columns {
			set STREAM($r,$col)  [db_get_col $rs_str $r $col]
		}
	}

	foreach col $columns {
		tpBindVar STREAM_[string toupper $col]  STREAM  $col str_idx
	}

	asPlayFile -nocache video/perform/stream_list.html
}


#
# ----------------------------------------------------------------------------
# Generate and bind data for display video perform
# ----------------------------------------------------------------------------
#
proc ADMIN::PERFORM::go_perform_stream args {

	global DB STREAM

	set stream_id  [reqGetArg StreamId]

	set sql [subst {
		select
			v.stream_id as id,
			p.text,
			v.cr_date,
			v.start_time,
			v.end_time,
			v.channels,
			v.displayed,
			p.order
		from
			tVideoStream v,
			tVSPerformDesc p
		where
			 v.stream_id = ?
		and v.stream_id = p.stream_id

	}]

	set stmt [inf_prep_sql $DB $sql]

	set rs [inf_exec_stmt $stmt $stream_id]
	inf_close_stmt $stmt

	set columns [db_get_colnames $rs]

	set n_rows [db_get_nrows $rs]

	if {$n_rows != 0} {
		foreach col $columns {
			tpBindString STREAM_[string toupper [db_get_col $rs 0 $col]]
		}
	}

	asPlayFile -nocache video/perform/stream.html
}


#
# Retrieve and store the latest stream information for a
# particular video provider
#
proc ADMIN::PERFORM::goStreamRequest {} {

	global PERFORM

	array unset PERFORM

	set n_mapped_streams   0
	set n_unmapped_streams 0
	set result_mapped      [list 0 ""]
	set result_unmapped    [list 0 ""]

	set perftype      [reqGetArg perftype]
	set days          [reqGetArg days]
	set dateStart     [reqGetArg dateStart]
	set dateEnd       [reqGetArg dateEnd]
	set mapped        [reqGetArg mapped]

	OT_LogWrite INFO {$perftype: Handling request for Perform stream details}

	# whether we're displaying only mapped, unmapped or both, we still need to
	# query everything so we know what's mapped and what's not, and what to
	# show and what to not

	# get mapped events from the db (rows in tVSContentLink)
	set result_mapped [video::doMappedStreamsRequest $perftype\
						$days $dateStart $dateEnd 0]

	# try and get unmapped events
	if {$days == "-" && ($dateStart == "" || $dateEnd == "")} {
		msg_bind "Unmapped Perform streams not shown, mandatory search\
					period missing"
		set result_unmapped [list 0 ""]
	} else {
		# get stream info via xml from Perform
		if {$perftype != "PERFVOD"} {
			set result_unmapped [video::doStreamRequest $perftype $days $dateStart\
							$dateEnd [lindex $result_mapped 0]]
		} else {

			set RP_unmapped [video::doStreamRequest $perftype $days $dateStart\
						$dateEnd [lindex $result_mapped 0] "RP"]

			set ATR_unmapped [video::doStreamRequest $perftype $days $dateStart\
						$dateEnd [llength $PERFORM(ids)]  "ATR"]

			set result_unmapped [expr {[lindex $RP_unmapped 0] + [lindex $ATR_unmapped 0]}]
			set result_unmapped [list $result_mapped "[lindex $RP_unmapped 1][lindex $ATR_unmapped 1]"]
		}

	}

	if {[lindex $result_mapped 1] != ""} {
		OT_LogWrite ERROR "$perftype: Error retrieving mapped Perform streams"
		err_bind "Couldn't retrieve mapped Perform Streams,\
				[lindex $result_mapped 1]"
	} elseif {[lindex $result_unmapped 1] != ""} {
		OT_LogWrite ERROR "$perftype: Error "
		err_bind "Couldn't retrieve unmapped Perform Streams,\
				[lindex $result_unmapped 1]"
	}

	# remember that the total could be less than result_unmapped +
	# result_unampped as there could be overlap, since the stream might
	# send down stuff we've already mapped
	set total_streams [llength $PERFORM(ids)]

	# bind the array to appropriate values
	set PERFORM(nrows) $total_streams

	for {set i 0} {$i < $total_streams} {incr i} {
		if {$perftype == "PERFORM"} {
			set columns [list \
						stream_id \
						id \
						contenttypeid \
						startdatetime \
						enddatetime \
						short_desc \
						description \
						chargeable \
						shortblkdcntrys \
						blockedcountrycodes \
						map_status \
						content_link_id \
						ob_link \
						ob_event_id \
						ob_event_desc \
						ob_type_name \
						status]
		} else {
			set columns [list \
						stream_id \
						id \
						contenttypeid \
						startdatetime \
						enddatetime \
						short_desc \
						description \
						shortblkdcntrys \
						map_status \
						content_link_id \
						ob_link \
						ob_event_id \
						ob_event_desc \
						ob_type_name \
						status \
						startsec3 \
						endsec3 \
						startsec4 \
						endsec4 \
						externalpath3 \
						externalpath4 \
						subProvider]
		}

		set PERFORM($i,startdatetime) [_convert_BST $PERFORM($i,startdatetime)]
		set PERFORM($i,enddatetime)   [_convert_BST $PERFORM($i,enddatetime)]

		foreach attr $columns {
			tpBindVar [string toupper $attr] PERFORM $attr perform_idx
		}

	}

	# rebind search parameters so we can display the page again
	foreach searchTerm {days dateStart dateEnd mapped} {
		tpBindString $searchTerm [set $searchTerm]
	}

	if {$perftype == "PERFORM"} {
		tpBindString perftype PERFORM
	} else {
		tpBindString perftype PERFVOD
	
		tpSetVar hide_chargable 1
		tpSetVar hide_blocked_countries 1
	}

	# display the page
	asPlayFile -nocache video/perform_list.html

}


#
# Map a Perform stream to an Openbet hierachy entry
#
proc ADMIN::PERFORM::doMapStreamRequest {} {

	set addList    [list]
	set perftype       [reqGetArg perftype]

	OT_LogWrite INFO {$perftype: Handling request to create Perform stream map}

	for {set n 0} {$n < [reqGetNumVals]} {incr n} {

		if {[regexp {^MAP_ID_(\d+)$} [reqGetNthName $n] all arrId]} {

			set obId [reqGetNthVal $n]
			if {$obId != {}} {
				if {$perftype == "PERFORM"} {
					foreach ob_ev_id [split $obId "|"] {
						set performId           [reqGetArg PERFORM_ID_$arrId]
						set obLevel             [reqGetArg MAP_LEVEL_$arrId]
						set contentTypeId       [reqGetArg CONTENTTYPEID_$arrId]
						set startDateTime       [reqGetArg STARTDATETIME_$arrId]
						set endDateTime         [reqGetArg ENDDATETIME_$arrId]
						set description         [reqGetArg DESCRIPTION_$arrId]
						set chargeable          [reqGetArg CHARGEABLE_$arrId]
						set blockedCountryCodes \
							[reqGetArg BLOCKEDCOUNTRYCODES_$arrId]
	
						lappend addList [list $performId \
										$ob_ev_id \
										$obLevel \
										$contentTypeId \
										$startDateTime \
										$endDateTime \
										$description $chargeable \
										$blockedCountryCodes]
					}
				} else {
					foreach ob_ev_id [split $obId "|"] {
						set performId           [reqGetArg PERFORM_ID_$arrId]
						set obLevel             [reqGetArg MAP_LEVEL_$arrId]
						set contentTypeId       [reqGetArg CONTENTTYPEID_$arrId]
						set startDateTime       [reqGetArg STARTDATETIME_$arrId]
						set endDateTime         [reqGetArg ENDDATETIME_$arrId]
						set description         [reqGetArg DESCRIPTION_$arrId]
						set chargeable          [reqGetArg CHARGEABLE_$arrId]
						set startsec3           [reqGetArg STARTSEC3_$arrId]
						set endsec3             [reqGetArg ENDSEC3_$arrId]
						set startsec4           [reqGetArg STARTSEC4_$arrId]
						set endsec4             [reqGetArg ENDSEC4_$arrId]
						set extpath3            [reqGetArg EXTERNALPATH3_$arrId]
						set extpath4            [reqGetArg EXTERNALPATH4_$arrId]
						set subProvider         [reqGetArg SUB_PROVIDER_$arrId]
	
						lappend addList [list $performId \
										$ob_ev_id \
										$obLevel \
										$contentTypeId \
										$startDateTime \
										$endDateTime \
										$description \
										$chargeable \
										$startsec3 \
										$endsec3 \
										$startsec4 \
										$endsec4 \
										$extpath3 \
										$extpath4 \
										$subProvider]
					}
				}
			}
		}
	}

	set result [video::perform::doPerformMapping $addList $perftype]

	if {[lindex $result 0] != 1} {
		OT_LogWrite ERROR "$perftype: Error while attempting to map	Perform stream, [lindex $result 1]"
		set err_msg "There's a problem mapping the stream : [lindex $result 1]"
		err_bind $err_msg
	}

	reqSetArg perftype $perftype
	ADMIN::PERFORM::goStreamRequest
	return
}


#
# Delete a Perform stream mapping and the associated db entries
#
proc ADMIN::PERFORM::doDeleteStreamRequest {} {

	set perftype [reqGetArg perftype]

	OT_LogWrite INFO {$perftype: Handling request to delete Perform stream map}

	set result [video::perform::doPerformMapDelete]

	if {[lindex $result 0] != 1} {
		OT_LogWrite ERROR "PERFORM: Error while attempting to delete Perform\
							stream, [lindex $result 1]"
		set err_msg "There was a problem deleting the stream"
		err_bind $err_msg
	}

	reqSetArg perftype $perftype
	ADMIN::PERFORM::goStreamRequest
	return
}


#
# Provide Perform stream search screen, links through to mapping screen
#
proc ADMIN::PERFORM::goMapPerformStreams {} {

	asPlayFile -nocache video/perform_search.html

}


#
# Display the details of tVPPerform for editing
#
proc ADMIN::PERFORM::goProviderPerform {} {

	global DB

	set stmt [inf_prep_sql $DB {
		select
			v.video_provider_id,
			v.video_provider,
			v.name,
			NVL(p.ev_list_url, '') as ev_list_url,
			NVL(p.admin_req_len, '') as admin_req_len,
			NVL(p.cron_req_len, '') as cron_req_len,
			NVL(p.archive_days, '') as archive_days
		from
			tVideoProvider v,
			tVPPerform p
		where
			v.video_provider_id = p.video_provider_id
	}]

	set rs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	foreach col {video_provider_id video_provider name ev_list_url} {
		OT_LogWrite DEV "PERFORM: bindstring $col as [db_get_col $rs 0 $col]"
		tpBindString [string toupper $col] [db_get_col $rs 0 $col]
	}

	# if we want to show the cron control columns set the config appropriately
	tpSetVar showCronSpecific    [OT_CfgGet PERFORM_CRON_MODE 0]
	tpSetVar showCountrySpecific [OT_CfgGet PERFORM_COUNTRY_CONTROL 1]

	ADMIN::PERFORM::bind_countries_for_perform

	asPlayFile -nocache video/perform_details.html
}


#
# Update the details of tVPPerform
#
proc ADMIN::PERFORM::doProviderPerform {} {

	global DB USERNAME

	set video_provider_id [reqGetArg video_provider_id]
	set video_provider    [reqGetArg video_provider]
	set provider_name     [reqGetArg provider_name]
	set ev_list_url       [reqGetArg ev_list_url]
	set admin_req_len     [reqGetArg admin_req_len]
	set cron_req_len      [reqGetArg cron_req_len]
	set archive_days      [reqGetArg achive_days]
	set avail_countries   [reqGetArgs Countries]
	set begin_countries   [reqGetArg begin_countries]

	# update tVPPerform
	set sql [subst {
		execute procedure pUpdVPPerform (
			p_video_provider_id = ?,
			p_ev_list_url       = ?,
			p_admin_req_len     = ?,
			p_cron_req_len      = ?,
			p_archive_days      = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $video_provider_id\
											$ev_list_url\
											$admin_req_len\
											$cron_req_len\
											$archive_days]} msg]} {
		OT_LogWrite ERROR "PERFORM: error updating the Perform details : $msg"
		err_bind $msg
	}

	inf_close_stmt $stmt
	db_close $rs

	# update tVideoProvider
	set sql [subst {
		execute procedure pUpdVideoProvider (
			p_video_provider_id = ?,
			p_video_provider    = ?,
			p_name              = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $video_provider_id\
						$video_provider $provider_name]} msg]} {
		OT_LogWrite ERROR "PERFORM: error updating the\
							video provider details : $msg"
		err_bind $msg
	}

	inf_close_stmt $stmt
	db_close $rs

	OT_LogWrite INFO "PERFORM: the allowed countries are $avail_countries"
	OT_LogWrite INFO "PERFORM: the original countries were $begin_countries"

	#
	# Deal with any new countries that can view Perform streams
	set new_countries     [list]

	foreach new_country $avail_countries {
		if {[lsearch $begin_countries $new_country] < 0} {
			lappend new_countries $new_country
		}
	}

	set sql {
		execute procedure pInsVPQualCountry (
			p_video_provider = ?,
			p_country_code   = ?,
			p_deny           = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	foreach country_code $new_countries {
		OT_LogWrite 1 "Adding country $country_code as an allowed\
						country to view Perform streams"
		if {[catch {set res [inf_exec_stmt $stmt\
			[OT_CfgGet PERFORM_VP_TAG "PERFORM"] $country_code "N"]} msg]} {
			OT_LogWrite ERROR "PERFORM: there was an error attempting\
								to insert a new Perform country"
			err_bind $msg
		}
	}

	#
	# Deal with any countries that have been removed from the
	# available countries list
	set removed_countries [list]

	foreach old_country $begin_countries {
		if {[lsearch $avail_countries $old_country] < 0} {
			lappend removed_countries $old_country
		}
	}

	set sql {
		execute procedure pDelVPQualCountry (
			p_video_provider  = ?,
			p_country_code    = ?,
			p_adminuser      = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	foreach country_code $removed_countries {
		OT_LogWrite 1 "Removing country $country_code from the allowed\
						countries to view Perform streams"
		if {[catch {set res [inf_exec_stmt $stmt\
			[OT_CfgGet PERFORM_VP_TAG "PERFORM"]\
			$country_code $USERNAME]} msg]} {
			OT_LogWrite ERROR "PERFORM: there was an error attempting\
								to remove a Perform country"
			err_bind $msg
		}
	}

	ADMIN::PERFORM::goProviderPerform
}


proc ADMIN::PERFORM::go_vs_qualify_bets {} {

	global DB

	variable QBET
	GC::mark ADMIN::PERFORM::QBET

	set sql {
		select
			qlfy_bet_id,
			name,
			status
		from
			tVSQualifyBet
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $res] {
			set QBET($i,$c) [db_get_col $res $i $c]
		}
	}

	tpSetVar num_qbets $nrows
	foreach c [db_get_colnames $res] {
		tpBindVar qbet_${c} ADMIN::PERFORM::QBET $c qbet_idx
	}

	db_close $res

	asPlayFile -nocache video/qbets.html

}



proc ADMIN::PERFORM::go_vs_qualify_bet {} {

	set qlfy_bet_id [ob_chk::get_arg qlfy_bet_id -on_err { -1 } UINT]

	if {$qlfy_bet_id == -1} {
		asPlayFile -nocache video/qbet.html
	} else {
		go_upd_vs_qualify_bet $qlfy_bet_id
	}
}



proc ADMIN::PERFORM::go_upd_vs_qualify_bet {qlfy_bet_id} {

	global DB

	variable QBETON
	variable QBETONSUB

	GC::mark ADMIN::PERFORM::QBETON
	GC::mark ADMIN::PERFORM::QBETONSUB

	#Retrieve basic informations on the group
	set sql {
		select
			name,
			status,
			amount
		from
			tVSQualifyBet
		where
			qlfy_bet_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $qlfy_bet_id]
	inf_close_stmt $stmt

	tpBindString qbet_name   [db_get_col $res 0 name]
	tpBindString qbet_status [db_get_col $res 0 status]
	tpBindString qbet_amount [db_get_col $res 0 amount]

	db_close $res

	#Retrieve bets in the group
	set sql {
		select
			qlfy_bet_on_id,
			qlfy_bet_on_name,
			ob_level,
			ob_id
		from
			tVSQualifyBetOn
		where
			qlfy_bet_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $qlfy_bet_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $res] {
			set QBETON($i,$c) [db_get_col $res $i $c]
		}
	}

	tpSetVar num_qbeton $nrows
	foreach c [db_get_colnames $res] {
		tpBindVar qbeton_${c} ADMIN::PERFORM::QBETON $c qbeton_idx
	}

	db_close $res

	#Retrieve subscription event in the group
	set sql {
		select
			qlfy_bet_on_sub_id,
			qlfy_bet_on_sub_name,
			ev_id
		from
			tVSQualifyBetOnSub
		where
			qlfy_bet_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $qlfy_bet_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $res] {
			set QBETONSUB($i,$c) [db_get_col $res $i $c]
		}
	}

	tpSetVar num_qbetonsub $nrows
	foreach c [db_get_colnames $res] {
		tpBindVar ${c} ADMIN::PERFORM::QBETONSUB $c qbetonsub_idx
	}

	db_close $res


	tpSetVar QBET_ID $qlfy_bet_id
	asPlayFile -nocache video/qbet.html

}



proc ADMIN::PERFORM::do_vs_qualify_bet {} {

	global DB

	set act         [ob_chk::get_arg SubmitName -on_err "" Az]
	set qlfy_bet_id [ob_chk::get_arg qlfy_bet_id -on_err -1 UINT]

	switch -exact $act {
		"UpdVSQualifyBet" {
			if {$qlfy_bet_id == -1} {
				err_bind "Error updating streaming group"
				return
			}

			set status  [ob_chk::get_arg qbet_status -on_err S\
						{EXACT -args { "A" "S" }}]
			set name    [ob_chk::get_arg qbet_name   -on_err "" SAFE]
			set amount  [ob_chk::get_arg qbet_amount -on_err 0 MONEY]

			set sql {
				update
					tVSQualifyBet
				set
					name = ? ,
					status = ?,
					amount = ?
				where
					qlfy_bet_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
							$name\
							$status\
							$amount\
							$qlfy_bet_id]} msg]} {
				err_bind "There was an error updating the group"
				OT_LogWrite ERROR "ADMIN::PERFORM::do_vs_qualify_bet, unable\
									to update group: $msg"
			}

			inf_close_stmt $stmt
			catch {db_close $res}

			set ccy_amount_change [ob_chk::get_arg ccy_amount_change -on_err 0\
									{EXACT -args {0 1}}]
			set ccy_amount_str    [ob_chk::get_arg ccy_amount_str -on_err ""\
									SAFE]

			if {$ccy_amount_change} {
				upd_qbet_ccy $qlfy_bet_id $ccy_amount_str
			}

			go_vs_qualify_bets
		}
		"AddVSQualifyBet" {

			set status      [ob_chk::get_arg qbet_status -on_err S\
							{EXACT -args { "A" "S" }}]
			set name        [ob_chk::get_arg qbet_name -on_err "" SAFE]
			set amount      [ob_chk::get_arg qbet_amount -on_err 0 MONEY]

			set sql {
				insert into
					tVSQualifyBet (video_provider_id,name,status,amount)
				values (
					(
						select
							video_provider_id
						from
							tVideoProvider
						where
							video_provider = 'PERFORM'
					),
					?,
					?,
					?)
			}
			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
							$name\
							$status\
							$amount]} msg]} {
				err_bind "There was an error adding the group : $msg"
				OT_LogWrite ERROR "ADMIN::PERFORM::do_vs_qualify_bet, unable\
									to add group: $msg"
			}

			inf_close_stmt $stmt
			catch {db_close $res}
			go_vs_qualify_bets
		}
		"AddVSQualifyBetOn" {

			set ob_level [ob_chk::get_arg add_qbet_ob_level -on_err "" {EXACT \
							-args { "CLASS" "TYPE" "EVENT"}}]
			set ob_id    [ob_chk::get_arg add_qbet_ob_id -on_err -1 UINT]
			set ob_name  [ob_chk::get_arg add_qbet_name -on_err "" SAFE]

			if {$qlfy_bet_id == -1 || $ob_level == "" || $ob_id == -1} {
				err_bind "Error updating streaming group"
				go_vs_qualify_bets
				return
			}

			set sql {
				insert into
					tVSQualifyBetOn (
						qlfy_bet_id,
						qlfy_bet_on_name,
						ob_level,
						ob_id
					)
				values (?,?,?,?)
			}

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
							$qlfy_bet_id\
							$ob_name\
							$ob_level\
							$ob_id]} msg]} {
				err_bind "There was an error updating the group : $msg"
				OT_LogWrite ERROR "ADMIN::PERFORM::do_vs_qualify_bet, unable\
									to update group: $msg"
			}

			inf_close_stmt $stmt
			catch {db_close $res}
			go_upd_vs_qualify_bet $qlfy_bet_id
		}
		"DeleteVSQualifyBetOn" {
			set to_delete [ob_chk::get_arg delete_qbeton_id -on_err -1 UINT]
			if {$to_delete == -1} {
				err_bind "There was an error updating the group"
				go_upd_vs_qualify_bet $qlfy_bet_id
				return
			}

			set sql {
				delete from tVSQualifyBetOn where qlfy_bet_on_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
							$to_delete]} msg]} {
				err_bind "There was an error updating the group : $msg"
				OT_LogWrite ERROR "ADMIN::PERFORM::do_vs_qualify_bet, unable\
									to update group: $msg"
			}

			inf_close_stmt $stmt
			catch {db_close $res}
			go_upd_vs_qualify_bet $qlfy_bet_id

		}
		"AddVSQualifyBetOnSub" {
			set ob_level [ob_chk::get_arg add_qbetsub_ob_level -on_err "" {\
							EXACT -args { "EVENT" "TYPE" "CLASS" }}]
			set ob_id    [ob_chk::get_arg add_qbetsub_ob_id -on_err -1 UINT]
			set ob_name  [ob_chk::get_arg add_qbetsub_name -on_err "" SAFE]

			if {$qlfy_bet_id == -1} {
				err_bind "Error updating streaming group"
				go_vs_qualify_bets
				return
			}

			if {$ob_level != "EVENT"} {
				err_bind "A subscription can only be linked to a $ob_level"
			}

			set sql {
				insert into
					tVSQualifyBetOnSub (qlfy_bet_id,qlfy_bet_on_sub_name,ev_id)
				values (?,?,?)
			}

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
							$qlfy_bet_id\
							$ob_name\
							$ob_id]} msg]} {
				err_bind "There was an error updating the group : $msg"
				OT_LogWrite ERROR "ADMIN::PERFORM::do_vs_qualify_bet, unable\
									to update group: $msg"
			}

			inf_close_stmt $stmt
			catch {db_close $res}
			go_upd_vs_qualify_bet $qlfy_bet_id
		}
		"DeleteVSQualifyBetOnSub" {
			set to_delete [ob_chk::get_arg delete_qbetonsub_id -on_err -1 UINT]
			if {$to_delete == -1} {
				err_bind "There was an error updating the group"
				go_upd_vs_qualify_bet $qlfy_bet_id
				return
			}

			set sql {
				delete from tVSQualifyBetOnSub where qlfy_bet_on_sub_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
							$to_delete]} msg]} {
				err_bind "There was an error updating the group : $msg"
				OT_LogWrite ERROR "ADMIN::PERFORM::do_vs_qualify_bet, unable\
									to update group: $msg"
			}

			inf_close_stmt $stmt
			catch {db_close $res}
			go_upd_vs_qualify_bet $qlfy_bet_id
		}
		"Back" {
			go_vs_qualify_bets
		}
		default {
			go_vs_qualify_bets
		}
	}

}


#
#
#
proc ADMIN::PERFORM::go_vs_qualify_bet_ccy {} {

	global DB
	variable QBET_CCY

	GC::mark ADMIN::PERFORM::QBET_CCY

	set qlfy_bet_id [ob_chk::get_arg qlfy_bet_id -on_err "" UINT]

	set sql {
		select
			b.amount,
			c.ccy_code,
			c.ccy_name
		from
			tCCy c,
			outer tVSQualifyBetCCy b
		where
			    b.qlfy_bet_id = ?
			and c.ccy_code = b.ccy_code
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $qlfy_bet_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $res] {
			set QBET_CCY($i,$c) [db_get_col $res $i $c]
		}
	}

	tpSetVar NumQBetCCy $nrows

	foreach c [db_get_colnames $res] {
		tpBindVar qbetccy_${c} ADMIN::PERFORM::QBET_CCY $c ccy_idx
	}

	db_close $res

	asPlayFile -nocache video/qbet_ccy.html
}



#
# Mapping horse racing events
#
proc ADMIN::PERFORM::do_map_horse_racing {} {

	global PERFORM

	catch {unset PERFORM}

	set perftype      [reqGetArg perftype]
	set days          [reqGetArg days]
	set dateStart     [reqGetArg dateStart]
	set dateEnd       [reqGetArg dateEnd]

	set PERFORM(ids)  [list]

	# we need to know mapped events list in order to know which one is
	# not mapped. get mapped events from the db (rows in tVSContentLink)
	set result_mapped [video::doMappedStreamsRequest \
						$perftype $days $dateStart $dateEnd 0]

	# try and get unmapped events
	if {$days == "-" && ($dateStart == "" || $dateEnd == "")} {
		msg_bind "Unmapped Perform streams not shown, mandatory search\
					period missing"
		set result_unmapped [list 0 ""]
		catch {unset PERFORM}
	} else {
		# get stream info via xml from Perform

		set RP_unmapped [video::doStreamRequest $perftype $days $dateStart\
							$dateEnd [lindex $result_mapped 0] "RP"]

		set ATR_unmapped [video::doStreamRequest $perftype $days $dateStart\
							$dateEnd [llength $PERFORM(ids)] "ATR"]

		ADMIN::PERFORM::doPerformHorseRacingAutoMapping $result_mapped\
												[llength $PERFORM(ids)] $perftype
	}

	goStreamRequest
	return
}



#
# Private procedures
# ==============================================================================

#
# Prepare queries
#
proc ADMIN::PERFORM::_prep_qrys {status} {

	global SHARED_SQL DB

	set get_mapped_streams {
		select
			vs.vs_perform_id,
			v.stream_id,
			v.cr_date,
			v.start_time,
			v.end_time,
			v.channels,
			v.displayed,
			vs.pf_ev_id,
			vs.content_type,
			vs.cntry_block,
			vs.chargeable
		from
			tVSperform vs,
			tvideostream v,
			tPerformCMap pcm,
			tPerformCType pct,
			tEvClass c
		where
			 v.stream_id = vs.stream_id
		and vs.content_type = pct.pf_ctype_id
		and pcm.pf_ctype_id = pct.pf_ctype_id
		and pcm.ev_class_id = c.ev_class_id
	}

	set get_unmapped_streams {
		select
			vp.video_provider_id as provider_id,
			v.stream_id,
			p.pf_desc_id,
			p.text,
			v.cr_date,
			v.start_time,
			v.end_time,
			v.channels,
			v.displayed,
			p.order
		from
			tVideoProvider vp,
			tVideoStream v,
			tVSPerformDesc p
		where
			 vp.video_provider_id = v.video_provider_id
		and v.stream_id = p.stream_id

	}

	if {$status == "U"} {
		set stmt [inf_prep_sql $DB $get_unmapped_streams]
	} elseif {$status == "M"} {
		set stmt [inf_prep_sql $DB $get_mapped_streams]
	} else {
	   set stmt [inf_prep_sql $DB $get_unmapped_streams]
	}

	return $stmt
}


proc ADMIN::PERFORM::_bind_class args {

	global DB DATA

	set stmt [inf_prep_sql $DB {
		select
			ev_class_id as class_id,
			name
		from
			tevclass
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar num_class [set n_rows [db_get_nrows $rs]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set DATA($r,class_id)  [db_get_col $rs $r class_id]
		set DATA($r,name)      [db_get_col $rs $r name]
	}

	tpBindVar CLASS_ID   DATA  class_id  class_idx
	tpBindVar CLASS_NAME DATA  name      class_idx
}


#
# Private procedures
# ==============================================================================


# Get all the countries Perform streams are allowed to be viewed from
proc ADMIN::PERFORM::bind_countries_for_perform {} {

	global DB
	global NOT_SELECTED_CTRS
	global SELECTED_CTRS

	set stmt [inf_prep_sql $DB {
			select
				qc.country_code,
				c.country_name
			from
				tVideoProvider vp,
				tVPPerform vpp,
				tVPQualCountry qc,
				tCountry c
			where
				vp.video_provider_id = vpp.video_provider_id
			and qc.provider_id = vpp.video_provider_id
			and qc.country_code = c.country_code
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NUM_SELECTED_CTRS [set n_rows [db_get_nrows $rs]]

	set SELECTED_CTRS(num_countries) $n_rows

	OT_LogWrite DEBUG "NUM_SELECTED_CTRS $n_rows"

	set begin_countries [list]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set SELECTED_CTRS($i,code)     [db_get_col $rs $i country_code]
		set SELECTED_CTRS($i,name)     [db_get_col $rs $i country_name]
		lappend begin_countries [db_get_col $rs $i country_code]
	}

	db_close $rs

	tpBindVar SELECTED_CTR_CODE     SELECTED_CTRS code     ctr_idx
	tpBindVar SELECTED_CTR_NAME     SELECTED_CTRS name     ctr_idx

	tpBindString BEGIN_COUNTRIES $begin_countries

	# get the countries that are not allowed for Perform
	#---------------------------------------------------------------------------
	catch {unset NOT_SELECTED_CTRS}
	set sql [subst {
			select distinct
				c.country_code,
				c.country_name,
				c.disporder
			from
				tCountry c,
				tVideoProvider vp,
				tVPPerform vpp
			where
				vp.video_provider_id = vpp.video_provider_id
			and c.status = 'A'
			and c.country_code not in
				(
				select
					qc.country_code
				from
					tVPQualCountry qc
				where
					qc.deny = 'N'
				and
					qc.provider_id = vpp.video_provider_id
				)
			order by c.disporder, c.country_code
	}]

 	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar  NUM_NOT_SELECTED_CTRS [db_get_nrows $rs]

	set NOT_SELECTED_CTRS(num_countries) [db_get_nrows $rs]

	OT_LogWrite DEBUG "NUM_NOT_SELECTED_CTRS [db_get_nrows $rs]"

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set NOT_SELECTED_CTRS($i,code) [db_get_col $rs $i country_code]
		set NOT_SELECTED_CTRS($i,name) [db_get_col $rs $i country_name]
	}
	tpBindVar NOT_SELECTED_CTR_CODE     NOT_SELECTED_CTRS code     nctr_idx
	tpBindVar NOT_SELECTED_CTR_NAME     NOT_SELECTED_CTRS name     nctr_idx

	db_close $rs
}


proc ADMIN::PERFORM::upd_qbet_ccy {qlfy_bet_id str} {

	global DB

	OT_LogWrite DEBUG "ADMIN::PERFORM::upd_qbet_ccy str=$str "

	set sql {
		select
			ccy_code,
			amount
		from
			tVSQualifyBetCcy
		where
			qlfy_bet_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $qlfy_bet_id]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]
	array set D [list]

	for {set r 0} {$r < $n_rows} {incr r} {
		set D([db_get_col $res $r ccy_code]) [db_get_col $res $r amount]
	}

	#
	# Now work out which statements to run
	#
	set STMT(I) [list]
	set STMT(U) [list]
	set STMT(D) [list]

	foreach {l d} [split $str ,] {

		set a [ob_chk::get_arg $d -value -on_err "junk" MONEY]

		if {$a == "junk"} {
			unset D($l)
			continue
		}

		if {![info exists D($l)]} {
			if {[string length $d]} {
				lappend STMT(I) $l $d
			}
		} else {
			if {$d == ""} {
				lappend STMT(D) $l
			} elseif {$D($l) == $d} {
				# unchanged - do nothing
			} else {
				lappend STMT(U) $l $d
			}
			unset D($l)
		}
	}

	# Anything left in the array must be deleted
	foreach l [array names D] {
		lappend STMT(D) $l
	}

	set sql_i [subst {
		insert into tVSQualifyBetCCy (
			amount,ccy_code,qlfy_bet_id
		) values (
			?, ?, ?
		)
	}]

	set sql_u [subst {
		update tVSQualifyBetCCy set
			amount = ?
		where
			ccy_code = ? and qlfy_bet_id = ?
	}]

	set sql_d [subst {
		delete from
			tVSQualifyBetCCy
		where
			ccy_code = ? and qlfy_bet_id = ?
	}]

	if [llength $STMT(I)] { set stmt_i [inf_prep_sql $DB $sql_i] }
	if [llength $STMT(U)] { set stmt_u [inf_prep_sql $DB $sql_u] }
	if [llength $STMT(D)] { set stmt_d [inf_prep_sql $DB $sql_d] }


	set c [catch {

		foreach {l d} $STMT(I) {
			inf_exec_stmt $stmt_i $d $l $qlfy_bet_id
		}
		foreach {l d} $STMT(U) {
			inf_exec_stmt $stmt_u $d $l $qlfy_bet_id
		}
		foreach l $STMT(D) {
			inf_exec_stmt $stmt_d $l $qlfy_bet_id
		}

	} msg]

	if {[info exists stmt_i]} { inf_close_stmt $stmt_i }
	if {[info exists stmt_u]} { inf_close_stmt $stmt_u }
	if {[info exists stmt_d]} { inf_close_stmt $stmt_d }

}

#
# Map a Perform stream to an Openbet hierachy entry. The details of the Perform
# stream will be added to the db
#
proc ADMIN::PERFORM::doPerformHorseRacingAutoMapping {
	result_mapped result_unmapped {type "PERFORM"}} {
	global DB PERFORM USERNAME

	set addList      [list]
	set addLevelList [list]
	set dd_key       [OT_CfgGet HR_AUTO_MAPPING_CLASS]

	set sql [subst {
		select
			ev_class_id
		from
			tEvClass c,
			tDDObjectCfgs o
		where
			dd_key = '$dd_key'
			and o.id = c.ev_class_id
	}]

	set stmt      [inf_prep_sql $DB $sql]
	set res_class [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $res_class] != 1} {
		 err_bind "Can't find \"Horse Racing - Live\" class."
		 return [list 0 "Can't find \"Horse Racing - Live\" class"]
	}

	set ev_class_id [db_get_col $res_class 0 ev_class_id]

	for {set n $result_mapped} {$n < $result_unmapped} {incr n} {
		if {$PERFORM($n,contenttypeid) == 1} {
			set sql [subst {
				select
					e.ev_id
				from
					tEv e,
					tEvType t
				where
					t.ev_class_id = ?
					and t.ev_type_id = e.ev_type_id
					and lower(t.name) = lower(?)
					and e.start_time = ?
			}]

			set stmt      [inf_prep_sql $DB $sql]
			set res_event [inf_exec_stmt $stmt $ev_class_id\
			$PERFORM($n,location) [_convert_BST $PERFORM($n,startdatetime)]]
			inf_close_stmt $stmt

			# Avoid to map the event if it does not have a valid location.
			if {[db_get_nrows $res_event] != 1} {
				ob_log::write WARNING {Perform not mapped. Id:$PERFORM($n,id)}
				continue
			}

			if {$type == "PERFORM"} {
				set performId           $PERFORM($n,id)
				set ob_ev_id            [db_get_col $res_event 0 ev_id]
				set obLevel             EVENT
				set contentTypeId       $PERFORM($n,contenttypeid)
				set startDateTime       [_convert_BST $PERFORM($n,startdatetime)]
				set endDateTime         [_convert_BST $PERFORM($n,enddatetime)]
				set description         $PERFORM($n,description)
				set chargeable          $PERFORM($n,chargeable)
				set blockedCountryCodes $PERFORM($n,blockedcountrycodes)
		
				lappend addList [list $performId \
								$ob_ev_id \
								$obLevel \
								$contentTypeId \
								$startDateTime \
								$endDateTime \
								$description \
								$chargeable \
								$blockedCountryCodes]
			} else {
				if {[catch {
					set performId           $PERFORM($n,id)
					set ob_ev_id            [db_get_col $res_event 0 ev_id]
					set obLevel             EVENT
					set contentTypeId       $PERFORM($n,contenttypeid)
					set startDateTime       [_convert_BST $PERFORM($n,startdatetime)]
					set endDateTime         [_convert_BST $PERFORM($n,enddatetime)]
					set description         $PERFORM($n,description)
					set chargeable          $PERFORM($n,chargeable)
					set startsec3           $PERFORM($n,startsec3)
					set endsec3             $PERFORM($n,endsec3)
					set startsec4           $PERFORM($n,startsec4)
					set endsec4             $PERFORM($n,endsec4)
					set extpath3            $PERFORM($n,externalpath3)
					set extpath4            $PERFORM($n,externalpath4)
				} msg]} {
					ob_log::write INFO {doPerformHorseRacingAutoMapping: Incomplete data from feed for $PERFORM($n,id)}
				} else {
					lappend addList [list $performId \
									$ob_ev_id \
									$obLevel \
									$contentTypeId \
									$startDateTime \
									$endDateTime \
									$description \
									$chargeable \
									$startsec3 \
									$endsec3 \
									$startsec4 \
									$endsec4 \
									$extpath3 \
									$extpath4]
				}
			}
		}
	}

	# now check already mapped ones
	if {[OT_CfgGet AUTO_REMAP_PERFVOD 0] && $type == "PERFVOD"} {
		for {set n 0} {$n < $result_mapped} {incr n} {
			if {$PERFORM($n,contenttypeid) == 1 && $PERFORM($n,level_name) == "EVENT"} {
	
				set sql [subst {
					select
						e.ev_id
					from
						tEv e,
						tEvType t
					where
						t.ev_class_id = ?
						and t.ev_type_id = e.ev_type_id
						and lower(t.name) = lower(?)
						and e.start_time = ?
				}]
		
				set stmt      [inf_prep_sql $DB $sql]
				set res_event [inf_exec_stmt $stmt $ev_class_id\
				$PERFORM($n,location) [_convert_BST $PERFORM($n,startdatetime)]]
				inf_close_stmt $stmt
	
				set matched_ev_id [db_get_col $res_event 0 ev_id]
		
				# check to see if the one we have matches the one on record
				if {$matched_ev_id != $PERFORM($n,level_id)} {
					ob_log::write WARNING {Perform mapping changed from $PERFORM($n,level_id) to $matched_ev_id}
					# delete and add to add list
	
					set stmt [inf_prep_sql $DB {
						execute procedure pDelVSMapPerform (
							p_content_link_id = ?,
							p_adminuser       = ?,
							p_transactional   = ?
						)
					}]
			
					if {[catch {set rs [inf_exec_stmt $stmt \
											$PERFORM($n,content_link_id) \
											$USERNAME \
											Y
					]} msg]} {
						OT_LogWrite ERROR "PERFORM: couldn't delete Perform stream mapping : $msg"
						inf_close_stmt $stmt
						err_bind "PERFORM: couldn't delete Perform stream mapping : $msg"
						db_close $rs
						return
					}
			
					db_close $rs
	
					if {[catch {
						set performId           $PERFORM($n,id)
						set ob_ev_id            [db_get_col $res_event 0 ev_id]
						set obLevel             EVENT
						set contentTypeId       $PERFORM($n,contenttypeid)
						set startDateTime       [_convert_BST $PERFORM($n,startdatetime)]
						set endDateTime         [_convert_BST $PERFORM($n,enddatetime)]
						set description         $PERFORM($n,description)
						set chargeable          $PERFORM($n,chargeable)
						set startsec3           $PERFORM($n,startsec3)
						set endsec3             $PERFORM($n,endsec3)
						set startsec4           $PERFORM($n,startsec4)
						set endsec4             $PERFORM($n,endsec4)
						set extpath3            $PERFORM($n,externalpath3)
						set extpath4            $PERFORM($n,externalpath4)
					} msg]} {
						ob_log::write INFO {doPerformHorseRacingAutoMapping: Incomplete data from feed for $PERFORM($n,id)}
					} else {
						lappend addList [list $performId \
										$ob_ev_id \
										$obLevel \
										$contentTypeId \
										$startDateTime \
										$endDateTime \
										$description \
										$chargeable \
										$startsec3 \
										$endsec3 \
										$startsec4 \
										$endsec4 \
										$extpath3 \
										$extpath4]
					}
	
				}
	
			}
		}
	}

	set result [video::perform::doPerformMapping $addList $type]

	if {[lindex $result 0] != 1} {
		OT_LogWrite ERROR "PERFORM: Error while attempting to map\
							Perform stream, [lindex $result 1]"
		set err_msg "There's a problem mapping the stream : [lindex $result 1]"
		err_bind $err_msg
	}

}

proc ADMIN::PERFORM::_convert_BST {date} {
	set result [clock format [clock scan "$date" -gmt true]\
				-format {%Y-%m-%d %H:%M:%S}]
	return $result
}





