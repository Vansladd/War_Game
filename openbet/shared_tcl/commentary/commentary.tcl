# ==============================================================
# $Id: commentary.tcl,v 1.1 2011/10/04 12:27:04 xbourgui Exp $
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================

package provide commentary 1.0

namespace eval commentary {
	variable INIT 0
	variable EVENT_SETUP
	variable EVENT_DETAILS
	variable CODES
}

# secs         - time to cache if we have caching turned on
# always_cache - time to cache even if we're not caching most queries
proc commentary::_get_qry_cache_time {secs {always_cache 0}} {
	if {[OT_CfgGet COMMENTARY_QRY_NO_CACHE 0]} {
		return $always_cache
	} else {
		return $secs
	}
}

proc commentary::init {} {
	variable INIT
	variable EVENT_SETUP
	variable EVENT_DETAILS
	variable SPORT_STAT_TOTAL
	variable CODES
	variable THRESHOLD
	variable DEFAULT_SCORES

	if {$INIT} return

	commentary::_prep_queries

	array set SPORT_STAT_TOTAL [list]
	set SPORT_STAT_TOTAL(available) ""
	# Create a lookup for the sports that have thier scores
	# sumed in a stat
	set sprt_stat_ttls [OT_CfgGet SPORT_STAT_TOTAL ""]
	foreach {sprt stat} $sprt_stat_ttls {
		lappend SPORT_STAT_TOTAL(available)   $sprt
		set SPORT_STAT_TOTAL($sprt,stat)      $stat
	}

	# Create a lookup for the thersholds of football matches
	#depending on their stat

	set THRESHOLD(avail_stats) ""

	set football_threshold [OT_CfgGet FOOTBALL_THRESHOLDS ""]
	foreach {stat threshold} $football_threshold {
		lappend THRESHOLD(avail_stats) $stat
		set THRESHOLD($stat) $threshold
	}

	array set EVENT_SETUP       [list]
	set EVENT_SETUP(available)  ""
	set CODES(available)        "N"

	# Populate the CODES array if necessary
	commentary::_get_all_codes

	array set EVENT_DETAILS      [list]
	set EVENT_DETAILS(available) ""

	# setup the default scores for sports
	set DEFAULT_SCORES(FOOTBALL)   "0-0"
	set DEFAULT_SCORES(BASKETBALL) "0-0"
	set DEFAULT_SCORES(BASEBALL)   "0-0"

	set INIT 1
}


proc commentary::_prep_queries {} {

	ob_db::store_qry commentary::get_codes {
		select
			ob_id,
			ob_level,
			stat_code code,
			'STAT'    type
		from
			tComSportStat
		UNION
		select
			ob_id,
			ob_level,
			score_code code,
			'SCRE'     type
		from
			tComSportScore
		UNION
		select
			ob_id,
			ob_level,
			period_code code,
			'PERD'      type
		from
			tComSportPeriod
		order by
			ob_level,
			ob_id,
			type

	} [_get_qry_cache_time 10]

	ob_db::store_qry get_event_setup {
		select
			'S'                                  type,
			lower(s.stat_code)                   code,
			'STAT_CODE_' || upper(s.stat_code)   trans_code,
			nvl(s.recorded,ss.generate_msg)      recorded
		from
			tComEvSetup         s,
			outer(tComStatType ss)
		where
			s.ev_id        =  ?                        and
			ss.stat_code   =  s.stat_code
		UNION
		select
			'P' type,
			lower(period_code) code,
			'PERIOD_CODE_' || upper(period_code) trans_code,
			'Y'                                  recorded
		from
			tComSportPeriod
		where
			ob_id          = ?                         and
			ob_level       = ?
		order by
			type
	} [_get_qry_cache_time 5]


	# Only get the event details with the event
	ob_db::store_qry get_ev_sport_details {
		select
			y.category,
			y.ev_category_id         y_id,
			NVL(s1.commentary_ver,1) y_com_ver,
			NVL(s2.ob_id,-1)         c_id,
			c.name                   c_name,
			NVL(s2.commentary_ver,1) c_com_ver,
			e.country                ev_country
		from
			tEv         e,
			tEvClass    c,
			tEvCategory y,
			outer (tComSport s1),
			outer (tComSport s2)
		where
			e.ev_id       = ?                and
			c.ev_class_id = e.ev_class_id    and
			y.category    = c.category       and
			s1.ob_id      = y.ev_category_id and
			s1.ob_level   = 'Y'              and
			s2.ob_id      = c.ev_class_id    and
			s2.ob_level   = 'C'
		order by
			5 asc
	} [_get_qry_cache_time 300 300]


	# Get the current event desciption
	ob_db::store_qry get_event_desc {
		select
			nvl(d.desc,e.desc)    desc
		from
			tEv                   e,
			outer tComEvDesc      d
		where
			e.ev_id               =   ?       and
			d.ev_id               =   e.ev_id
	} [_get_qry_cache_time 15]

	ob_db::store_qry get_event_has_stats {
		select
			first 1
			s.ev_id
		from
			tComSummary  s
		where
			s.ev_id   =  ?
	} [_get_qry_cache_time 5]

	ob_db::store_qry get_event_has_comments {
		select
			first 1
			b.comment_id
		from
			tBIRComment  b
		where
			b.ev_id   =  ?
	} [_get_qry_cache_time 5]

	ob_db::store_qry get_event_has_setup {
		select first 1
			s.ev_id
		from
			tComEvSetup s
		where
			s.ev_id     =  ?
	} [_get_qry_cache_time 5]

	ob_db::store_qry get_event_competitors {
		select
			nvl(s.desc,p.desc)    desc,
			p.ev_oc_id                ,
			p.ext_id                  ,
			p.is_active
		from
			tComParticipant           p,
			outer(tEvOc               s)
		where
			p.ev_id         =         ?            and
			p.part_type     =         'C'          and
			p.ev_oc_id      =         s.ev_oc_id
	} [_get_qry_cache_time 5]

	ob_db::store_qry of_com::get_selection_comps {
		select first 2
			case when s.fb_result = 'H' then  0
			else 1
			end ext_id,
			s.ev_oc_id,
			s.desc,
			0 as is_active
		from
			tEvOc        s,
			tEvMkt       m
		where
			s.ev_id      =  ?            and
			s.fb_result  in ('H','A')    and
			s.ev_mkt_id  =  m.ev_mkt_id
		order by
			m.disporder,
			s.disporder
	} [_get_qry_cache_time 5]

	# Get the current commentary message in order of when they happened
	# rather then why they were entered into the systme
	ob_db::store_qry get_com_msgs {
		select
			m.ev_msg_id,
			m.stat_code,
			m.period_code,
			m.period_num,
			p.ext_id comp_ext_id,
			cast(m.clock_time as interval hour to second) clock_time,
			m.free_txt,
			m.free_txt_lang
		from
			tComMsg           m,
			tComParticipant   p,
			tComPeriodType    pt
		where
			m.ev_id           =  ?                   and
			(m.free_txt_lang  =  ?                   or
			 m.free_txt_lang  is null)               and

			pt.period_code    =  m.period_code       and

			p.ev_id           =  m.ev_id             and
			p.ext_id          =  m.competitor_id     and
			p.part_type       =  'C'
		order by
			pt.temporal_order desc,
			m.clock_time      desc,
			m.ev_msg_id       desc
	} [_get_qry_cache_time 5]

	# Get the commentary event flags
	ob_db::store_qry get_event_flags {
		select
			f.flag,
			f.value
		from
			tComEvFlag   f
		where
			f.ev_id   =  ?
	} [_get_qry_cache_time 30]

	# Get the current clock offset
	ob_db::store_qry get_com_clock {
		select
			y.category,
			y.ev_category_id         y_id,
			NVL(s1.commentary_ver,1) y_com_ver,
			NVL(s2.ob_id,-1)         c_id,
			c.name                   c_name,
			NVL(s2.commentary_ver,1) c_com_ver,
			s.state,
			s.period_code,
			nvl(s.offset, "0 00:00:00") as offset,
			nvl(cast((case
				when s.state = 'R' then CURRENT       - s.offset - e.start_time
				when s.state = 'S' then s.last_update - s.offset - e.start_time
			end) as interval day to second), "0 00:00:00") clock_time
		from
			tEv         e,
			tEvClass    c,
			tEvCategory y,
			tComClockState s,
			outer (tComSport s1),
			outer (tComSport s2)
		where
			e.ev_id       = ?                and
			s.ev_id       = e.ev_id          and
			c.ev_class_id = e.ev_class_id    and
			y.category    = c.category       and
			s1.ob_id      = y.ev_category_id and
			s1.ob_level   = 'Y'              and
			s2.ob_id      = c.ev_class_id    and
			s2.ob_level   = 'C'
		order by
			4 asc
	} [_get_qry_cache_time 15]

	# Returns the summary of commentary for a event
	ob_db::store_qry get_event_summary {
		select
			case when
				s.period_num is null
			then
				s.period_code
			else
				s.period_code || s.period_num
			end period_code,
			case when
				s.stat_code = 'scre'
			then
				s.score_code
			else
				s.stat_code
			end code,
			nvl(s.count, s.score) value,
			s.alt_score,
			s.competitor_id,
			s.player_id
		from
			tComSummary             s
		where
			s.ev_id      =          ?
		order by
			1
	} [_get_qry_cache_time 10]


	# Get the current period and laste update
	# from the old commentary table
	ob_db::store_qry get_bir_com_period {
		select first 1
			c.comment_type      period_code,
			c.created
		from
			tBIRComment      c
		where
			c.ev_id     =    ?
		order by
			c.comment_id     desc
	}

	# Returns latest commentary from the new commentary system
	# This includes scores and current period.
	ob_db::store_qry get_com_period {
		select
			first 1
			UPPER(s.period_code) period_code,
			i.last_update        created
		from
			tComLastIncident  i,
			tComSummary       s,
			tComPeriodType    p
		where
			p.period_code =  s.period_code and
			i.ev_id       =  s.ev_id       and
			s.ev_id       =  ?
		order by
			p.temporal_order desc
	} [_get_qry_cache_time 10]

	# Returns latest commentary from the new commentary system
	# This includes scores and current period.
	ob_db::store_qry get_com_score_stat {
		select
			s.competitor_id,
			s.score,
			s.alt_score
		from
			tComSummary       s
		where
			s.period_code  =  'tot'     and
			s.ev_id        =  ?         and
			s.stat_code    =  ?         and
			s.score_code  is not null
		order by
			s.competitor_id
	} [_get_qry_cache_time 10]

	# Get a events score by period and score code
	ob_db::store_qry get_com_score_perd {
		select first 2
			s.competitor_id,
			s.score,
			s.alt_score,
			e.country        ev_country
		from
			tComSummary      s,
			tEv              e
		where
			e.ev_id       =  s.ev_id       and
			s.ev_id       =  ?             and
			s.score_code  =  ?             and
			s.period_code =  ?
		order by
			s.competitor_id                asc
	} [_get_qry_cache_time 10]

	# Get the current games score from tBIRComment
	# This is the admin screen commentary system
	ob_db::store_qry get_com_score_sum_v1 {
		select first 1
			c.column1,
			c.column2
		from
			tBIRComment    c
		where
				c.ev_id    = ?
		order by
			c.comment_id   desc
	} [_get_qry_cache_time 10]

	# Get the current game score from version three
	ob_db::store_qry get_com_score_sum_v3 {
		select
			s.competitor_id        ,
			sum(s.score)      score,
			sum(s.alt_score)  alt_score,
			e.country         ev_country
		from
			tComSummary       s,
			tEv               e
		where
			e.ev_id        =  s.ev_id       and
			s.period_code  =  'tot'     and
			s.ev_id        =  ?         and
			s.score_code   != 'ps'      and
			s.score_code  is not null
		group by
			1,4
		order by
			s.competitor_id
	} [_get_qry_cache_time 15]

	# Returns the current batsman which is annoying stored
	# as a flag rather then a Participant
	ob_db::store_qry get_batsmen {
		select first 2
			f.flag           btm,
			f.value          player_name
		from
			tComEvFlag    f
		where
			f.ev_id     =    ?              and
			f.flag  in     ('btm1','btm2')
		order by
			f.flag                          desc
	}  [_get_qry_cache_time 10]

}


# commentary_avail
# - returns if commentary is availalble or not
proc commentary::commentary_avail {ev_id {com_ver 3}} {
	set avail 0

	switch -- $com_ver  {
		3 {
			set rs_avail [ob_db::exec_qry get_event_has_stats $ev_id]
		}
		2 {
			set rs_avail [ob_db::exec_qry get_event_has_comments $ev_id]
		}
	}

	if {[db_get_nrows $rs_avail]} {
		set avail 1
	}

	ob_db::rs_close $rs_avail

	return $avail
}

#
#  get_com_digest
#     Fetches digest data
#
#     ev_id      -  Event ID to get digest for
#
#     Retuns a list of :
#     type       -  The current period
#     score      -  Current score in the format of "1-2"
#     score2     -  Any alternative score if there is one
#     created    -  DT of last update to the score
#     event id   -  Event ID
#     add_clock  -  Should a clock been shown
#
proc commentary::get_com_digest {ev_id} {
	variable EVENT_DETAILS

	if {![_get_ev_sport_details $ev_id]} {
		set EVENT_DETAILS($ev_id,com_ver) 1
	}

	set scores [get_sport_score $ev_id]

	set score      [lindex $scores 0]
	set score2     [lindex $scores 1]

	switch -exact -- $EVENT_DETAILS($ev_id,com_ver) {
		1 {
			set rs_period [ob_db::exec_qry get_bir_com_period $ev_id]
		}
		3 {
			set rs_period [ob_db::exec_qry get_com_period $ev_id]
		}
	}

	if {[db_get_nrows $rs_period] != 1} {
		set msg "get_com_digest:: ($ev_id) does not have a current period."
		ob_log::write ERROR {$msg}
		ob_db::rs_close $rs_period
		return [list "ERROR" $msg]
	}

	set type     [db_get_col $rs_period 0 period_code]
	set created  [db_get_col $rs_period 0 created]

	ob_db::rs_close $rs_period

	set add_clock 0

	if {$EVENT_DETAILS($ev_id,category) == "FOOTBALL"} {
		set add_clock 1
	}

	return [list "OK" $type $score $score2 $created $ev_id $add_clock]
}

#
#  get_clock
#        Fetches the clock data for an event
#
#  format_time - formats the time, if disabled then the actual Informix
#                interval format is returned (interval format is used by PUSH)
#
#  returns - Returns a list of:
#              state - from tComClockState, but with an additional "X" status
#                      for when we don't have a row in tComClockState
#              period_code - from tComClockState, blank if no row
#              clock_time - the actual time interval from the start, formatted
#                      if format_time flag is 1
#
proc commentary::get_clock {ev_id {format_time 1}} {

	variable EVENT_DETAILS

	set rs [ob_db::exec_qry get_com_clock $ev_id]

	set state        "X"
	set period_code  ""
	set clock_time   [expr {$format_time == 1 ? "00" : "0 00:00:00"}]
	set offset       "0 00:00:00"

	set n [db_get_nrows $rs]

	if {[db_get_nrows $rs] == 1} {
		set state       [db_get_col $rs 0 state]
		set period_code [db_get_col $rs 0 period_code]
		set clock_time  [string trim [db_get_col $rs 0 clock_time]]
		set sport       [db_get_col $rs 0 category]
		set offset      [db_get_col $rs 0 offset]

		if {$sport == "BASKETBALL" && $period_code == "ovrt"} {
			set period_code "qua5"
		}

		if {$format_time} {
			# Format the time correctly (MM:SS or MMM:SS)
			set clock_time [display_clock_time $clock_time $sport $period_code]
		}
	}
	ob_db::rs_close $rs

	return [list $state $period_code $clock_time $offset]

}

proc commentary::_get_cricket_score {ev_id} {

	set value       "-"
	set alt_score   "-"

	set competitor_id -1

	set rs_competitors [ob_db::exec_qry get_event_competitors $ev_id]
	set ncompetitors   [db_get_nrows $rs_competitors]

	for {set i 0} {$i < $ncompetitors} {incr i} {
		if {[db_get_col $rs_competitors $i is_active] == "Y"} {
			set competitor_id [db_get_col $rs_competitors $i ext_id]
			break
		}
	}
	ob_db::rs_close $rs_competitors

	if {$competitor_id == -1} {
		return "-/-"
	}

	set rs_perd_score [ob_db::exec_qry get_com_score_perd $ev_id "runs" "tot"]
	if {[db_get_nrows $rs_perd_score] == 2} {
		set value [db_get_col $rs_perd_score $competitor_id score]
	}
	ob_db::rs_close $rs_perd_score

	set rs_perd_score [ob_db::exec_qry get_com_score_perd $ev_id "wic" "tot"]
	if {[db_get_nrows $rs_perd_score] == 2} {
		set alt_score [db_get_col $rs_perd_score $competitor_id alt_score]
	}
	ob_db::rs_close $rs_perd_score

	# If they are both empty then return  -/-
	if {$value == 0 && $alt_score == 0} {
		set value       "-"
		set alt_score   "-"
	}

	# final check for empty values
	if {$alt_score == ""} {
		set alt_score 0
	}

	if {$value == ""} {
		set value 0
	}

	return "$value/$alt_score"
}


#
# Gets the commentary sport score for an event, switching between commentary
# version.  Version 1 used the tBIRComment table, version 3 uses tComSummary
# and has sports-specific handling
#
# ev_id   - from tEv
# version - either 1 or 3 or blank to find it from tComSport
#
# returns - score string (e.g. "1-0") or empty string if nothing found or error
#
proc commentary::get_sport_score {ev_id {version ""}} {

	set fn {commentary::get_sport_score}

	variable EVENT_DETAILS

	if {$version == ""} {
		if {[_get_ev_sport_details $ev_id]} {
			set version $EVENT_DETAILS($ev_id,com_ver)
		} else {
			# If we have no sport information then it is most probably
			# using the tBIRComment table
			set version "1"
		}
	}

	set scores ""

	switch -exact -- $version {
		1 {
			ob_log::write INFO {$fn: Getting commentary version 1 for $ev_id}
			set scores [commentary::get_sport_score_v1 $ev_id]
		}
		3 {
			ob_log::write INFO {$fn: Getting commentary version 3 for $ev_id}
			set scores [commentary::get_sport_score_v3 $ev_id]

			set us_format_ctries [OT_CfgGet US_FORMAT_CTRIES [list "US" "USA" "Canada"]]

			if {[lindex $scores ] != "" && [lsearch $us_format_ctries $EVENT_DETAILS($ev_id,ev_country)] != -1} {
				ob_log::write INFO "$fn Flipping scores for US format. Before '$scores'"
				set sucess [regexp -nocase {([0-9]*)\-([0-9]*)} [lindex $scores 0] match away home]
				set scores "{$home-$away}"
			}

		}
		default {
			ob_log::write INFO {$fn: Invalid commentary version for $ev_id,\
						returning empty string}
			return ""
		}
	}

	return $scores
}

#
# Gets version 2 of the commentary, from tBIRComment
#
proc commentary::get_sport_score_v1 {ev_id} {

	set rs [ob_db::exec_qry get_com_score_sum_v1 $ev_id $ev_id]

	if {[db_get_nrows $rs] != 1} {
		# Either we've got no old commentary or something's gone wrong with
		# the query - should only return one row
		return ""
	} else {
		# Note, column1 is the actual score, column2 is secondary score (e.g.
		# penalties)
		set score1 [db_get_col $rs 0 column1]
		set score2 [db_get_col $rs 0 column2]

		# If there's nothing, return nothing (otherwise won't match "")
		if {$score1 == "" && $score2 == ""} {
			return ""
		} else {
			return "$score1 $score2"
		}
	}

}

#
# _get_ev_sport_details
#    Fetchs static event details
#
#   EVENT_DETAILS :
#       category
#       ev_country
#       Sport
#       ob_id
#       ob_level
#       com_ver
#
#   ev_id  -   Event ID to get information for
#
proc commentary::_get_ev_sport_details {ev_id} {
	set fn "commentary::get_ev_sport_details: "

	variable EVENT_DETAILS

	set rs    [ob_db::exec_qry get_ev_sport_details $ev_id]
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {

		foreach c {
			category
			ev_country
			y_id
			y_com_ver
			c_name
			c_id
			c_com_ver
		} {
			set $c [db_get_col $rs 0 $c]
		}

		set EVENT_DETAILS($ev_id,category) $category

		if {$c_id != -1} {
			# Give precedence to class-level commentary version, if we have it
			set EVENT_DETAILS($ev_id,sport)      $c_name
			set EVENT_DETAILS($ev_id,ob_id)      $c_id
			set EVENT_DETAILS($ev_id,ob_level)   "C"
			set EVENT_DETAILS($ev_id,com_ver)    $c_com_ver
			set EVENT_DETAILS($ev_id,ev_country) $ev_country
		} else {
			# Else take category-level commentary version
			set EVENT_DETAILS($ev_id,sport)      $category
			set EVENT_DETAILS($ev_id,ob_id)      $y_id
			set EVENT_DETAILS($ev_id,ob_level)   "Y"
			set EVENT_DETAILS($ev_id,com_ver)    $y_com_ver
			set EVENT_DETAILS($ev_id,ev_country) $ev_country
		}

	} else {
		ob_log::write INFO "$fn Unable to get the event details for '$ev_id'"
		return 0
	}

	return 1
}


#
#    get_sport_score - commentary version 3, using tComSummary
#        Returns the current score for a sport
#        This does so though in the old school method where
#        only two competitors and no players are expected.
proc commentary::get_sport_score_v3 {ev_id} {
	variable SPORT_STAT_TOTAL
	variable EVENT_DETAILS
	variable DEFAULT_SCORES

	if {![_get_ev_sport_details $ev_id]} {
		ob_log::write DEBUG "Unable to get event details for \
			'$ev_id' defaulting the score"

		return "{} {}"
	}

	set score  0
	set score2 ""

	if {$EVENT_DETAILS($ev_id,category) == "CRICKET"} {
		return [_get_cricket_score $ev_id]
	}

	set sprt_name $EVENT_DETAILS($ev_id,category)

	# Does the sport have a statsum for each period
	# Like in tennis where each set it totaled up as a statsum
	set is_sprt_stat_ttl [lsearch $SPORT_STAT_TOTAL(available) $sprt_name]

	if {$is_sprt_stat_ttl != -1} {
		set stat $SPORT_STAT_TOTAL($sprt_name,stat)

		set rs_score [ob_db::exec_qry get_com_score_perd $ev_id $stat "tot"]

		# One for each competitor
		# This commentary method only supports 2 competitors
		if {[db_get_nrows $rs_score] != 2} {
			ob_log::write DEBUG {No score information for $ev_id}

			set default_score {}
			
			if {[info exists DEFAULT_SCORES($EVENT_DETAILS($ev_id,category))]} {
				set default_score $DEFAULT_SCORES($EVENT_DETAILS($ev_id,category))
			}

			return "$default_score {}"
		}

		set comp1_scre    [db_get_col $rs_score 0 score]
		set comp2_scre    [db_get_col $rs_score 1 score]

		if {$sprt_name == "TENNIS"} {
			set comp1_scre [_convert_tennis_scre $comp1_scre]
			set comp2_scre [_convert_tennis_scre $comp2_scre]
		}


	} else {
		set rs_score [ob_db::exec_qry get_com_score_sum_v3 $ev_id]

		if {[db_get_nrows $rs_score] != 2} {
			ob_log::write DEBUG {There should be a row foreach comp. ($ev_id)}
			ob_db::rs_close $rs_score

			set default_score {}
			
			if {[info exists DEFAULT_SCORES($EVENT_DETAILS($ev_id,category))]} {
				set default_score $DEFAULT_SCORES($EVENT_DETAILS($ev_id,category))
			}

			return "$default_score {}"
		}

		set comp1_scre   [db_get_col $rs_score 0 score]
		set comp2_scre   [db_get_col $rs_score 1 score]
	}
	set score "{$comp1_scre-$comp2_scre}"

	ob_db::rs_close $rs_score

	# If there's nothing, return nothing (otherwise won't match "")
	if {$score == "" && $score2 == ""} {
		return ""
	} else {
		return "$score $score2"
	}
}

# _load_ev_setup
#    - ev_id
#        Event ID from tEv of the event setup to load from
#        tComEvSetup
#    Sets up the EVENT_SETUP array with expected stat codes for
#    each event.
proc commentary::_load_ev_setup {ev_id} {
	variable EVENT_SETUP

	array set EVENT_SETUP [list]

	set ob_id    $EVENT_DETAILS($ev_id,ob_id)
	set ob_level $EVENT_DETAILS($ev_id,ob_level)

	set rs_event [ob_db::exec_qry get_event_setup $ev_id $ob_id $ob_level]

	set nrows    [db_get_nrows $rs_event]

	set EVENT_SETUP($ev_id,stat_codes) ""

	set curr_period_code ""

	for {set r 0} {$r < $nrows} {incr r} {

		set code [db_get_col $rs_event $r code]
		set type [db_get_col $rs_event $r type]

		if {$type == "S"} {
			lappend EVENT_SETUP($ev_id,stat_codes)    $code
		} else {
			lappend EVENT_SETUP($ev_id,period_codes)  $code
		}

		set EVENT_SETUP($code,recorded)    [db_get_col $rs_event $r recorded]
		set EVENT_SETUP($code,trans_code)  [db_get_col $rs_event $r trans_code]
	}

	lappend EVENT_SETUP(available) $ev_id

	ob_db::rs_close $rs_event
}

#    _get_flags
#     Returns any commentary flags that have been set against the event
proc commentary::_get_flags {ev_id} {
	variable FLAGS

	set FLAGS($ev_id,flags) ""

	set rs_flags [ob_db::exec_qry get_event_flags $ev_id]
	set nrows    [db_get_nrows $rs_flags]

	for {set r 0} {$r < $nrows} {incr r} {

		set flag  [db_get_col $rs_flags $r flag]
		set value [db_get_col $rs_flags $r value]

		lappend FLAGS($ev_id,flags) $flag
		set FLAGS($ev_id,$flag)     $value
	}

	return 1
}

#
# _load_competitors
#    Get the compeitor information from either the WDW market or
#    from tComParticipant if they have been provided
#
proc commentary::_load_competitors {ev_id} {
	ob_log::write DEBUG {PROC:: commentary::_load_competitor($ev_id)}
	variable COMPETITORS
	array set COMPETITORS [list]

	# Next get the competitor information for this event
	set rs_competitors [ob_db::exec_qry get_event_competitors $ev_id]

	if {[db_get_nrows $rs_competitors] < 2} {
		ob_db::rs_close $rs_competitors

		if {[catch {set rs_competitors \
			[ob_db::exec_qry of_com::get_selection_comps $ev_id]} ErrMsg]} {
			 ob_log::write DEBUG "Unable to load competitors for $ev_id.\n $ErrMsg"
		}
	}

	lappend COMPETITORS(available) $ev_id

	set COMPETITORS($ev_id,ncompetitors)   [db_get_nrows $rs_competitors]
	set COMPETITORS($ev_id,ext_ids)        ""

	for {set i 0} {$i < $COMPETITORS($ev_id,ncompetitors)} {incr i} {
		set ev_oc_id  [db_get_col $rs_competitors $i ev_oc_id]
		set ext_id    [db_get_col $rs_competitors $i ext_id]
		set is_active [db_get_col $rs_competitors $i is_active]

		lappend COMPETITORS($ev_id,ext_ids) $ext_id
		set COMPETITORS($ev_oc_id)          $ext_id
	}

	ob_db::rs_close $rs_competitors

}


# _get_dis_clock_time
#  Returns a formated clock time
#
proc commentary::_get_dis_clock_time {clock_time {ev_id ""}} {
	# Format the time correctly (MM:SS or MMM:SS)
	set clock_list [split $clock_time ":"]
	set hours      [lindex $clock_list 0]
	set minutes    [lindex $clock_list 1]
	set seconds    [lindex $clock_list 2]

	# Remove any leading 0's as these will cause the number to be treated as octal
	if {$hours != 00} {
		set hours   [string trimleft $hours "0"]
	}
	if {$minutes != 00} {
		set minutes [string trimleft $minutes "0"]
	}

	set minutes [expr {$minutes + ($hours * 60)}]
	set clock_time "$minutes:$seconds"

	# Add leading 0 if necessary
	if {[string length $clock_time] == 4} {
		set clock_time "0$clock_time"
	}

	return $clock_time
}


proc commentary::_string_trans_codes {text} {
	set clean_txt [string map {"%s" {} "%d" {}} $text]
	return $clean_txt
}

#
# Generates the clock time to be displayed
#
proc commentary::display_clock_time {incident_time sport period {mins_only 0}} {

	variable THRESHOLD

	set time_list [split $incident_time ":"]

	#Export hour minutes and seconds to be displayed
	set dd [lindex [split [lindex $time_list 0] " "] 0]
	set hh [lindex [split [lindex $time_list 0] " "] 1]
	set mm [lindex $time_list 1]
	set ss ""

	# In case we get an actual db time instead of an incident
	if {$hh == ""} {
		set clock_list [split $incident_time ":"]
		set hh    [lindex $clock_list 0]
		set mm    [lindex $clock_list 1]
		set ss    [lindex $clock_list 2]
	}

	# "" * 24 will throw an error so default here
	if {$dd == ""} {
		set dd 0
	}

	if {$dd > 0} {
		set dd [string trimleft $dd "0"]
	}

	if {$hh > 0} {
		set hh [string trimleft $hh "0"]
	}

	if {$mm > 0} {
		set mm [string trimleft $mm "0"]
	}

	if {$ss == ""} {
		set ss [lindex $time_list 2]
	}

	set mm [expr {($dd * 24 * 60) + ($hh * 60) + $mm}]

	set incident_time "$mm:$ss"

	if {[string length $incident_time] < 5} {
		set incident_time "0$incident_time"
	}

	#
	# If the clock time is associated with a football match,
	# the clock will be displayed without the seconds and
	# in the format threshold_time'+extra_time' e.g
	# if we are in the first half at minute 47 the time will
	# be formatted as 45'+2'
	#
	if {$mins_only && $sport == "FOOTBALL"  && [OT_CfgGet SHOW_ONLY_MINUTES 0]} {

		if { $ss > 0 ||  [OT_CfgGet ROUND_UP_MINUTE 0]} {
			set mm [expr $mm + 1]
		}

		set extra_time 0

		if {[lsearch $THRESHOLD(avail_stats) $period] != -1} {
			set threshold_time $THRESHOLD($period)
			set extra_time [expr $mm - $threshold_time]
		}

		if { $extra_time > 0 } {
			set incident_time "$threshold_time'+$extra_time'"
		} else {
			set incident_time "$mm'"
		}
	}

	return $incident_time
}


# Get the sport for the given event.  This is a kludge so we don't have to
# bother about LANG.
proc commentary::get_event_sport {event_id} {

	set rs [ob_db::exec_qry get_event_sport $event_id]

	if {[db_get_nrows $rs] == 1} {
		set res [list "OK" [db_get_col $rs 0 sport]]
	} else {
		ob_log::write ERROR {Couldn't find sport for event_id=$event_id}
		set res [list "ERROR" "Couldn't find sport"]
	}

	ob_db::rs_close $rs

	return $res
}


#
# get_event_desc
#   Populates the EVENT_DETAILS ns varuable with
#      + desc        -- Description of event
#
proc commentary::get_event_desc {event_id lang} {
	set fn "commentary::get_event_desc :- "
	ob_log::write DEBUG {$fn ($event_id,$lang)}

	variable EVENT_DETAILS

	set rs [ob_db::exec_qry get_event_desc $event_id $lang]

	if {[db_get_nrows $rs] != 0} {
			set EVENT_DETAILS($event_id,desc)  [db_get_col $rs 0 desc]
	} else {
		ob_log::write INFO "$fn Unable to get the event desc for '$event_id' '$lang'"
		return 0
	}

	ob_db::rs_close $rs

	return 1
}

#
# _get_all_codes
#   Returns all the stat and period codes PER SPORT
#
proc commentary::_get_all_codes args {
	variable CODES

	# Has CODES been populated already?
	if {$CODES(available) == "Y"} {
		return
	}

	if {[catch {set rs [ob_db::exec_qry commentary::get_codes]} ErrMsg]} {
		ob_log::write ERROR {Failed to retrieve incident/period codes - $ErrMsg}
		return
	}

	set nrows [db_get_nrows $rs]

	set curr_id    ""
	set curr_lvl   ""
	set curr_type  ""

	for {set i 0} {$i < $nrows} {incr i} {
		set ob_id    [db_get_col $rs $i ob_id]
		set ob_level [db_get_col $rs $i ob_level]
		set code     [db_get_col $rs $i code]
		set type     [db_get_col $rs $i type]

		# Sanity check to make sure we are looking at the same
		# - ob id
		# - ob level
		# - code type (period, stat, score)
		set is_curr_id   [expr {$curr_id == $ob_id}]
		set is_curr_lvl  [expr {$curr_lvl == $ob_level}]
		set is_curr_type [expr {$curr_type == $type}]

		if {!$is_curr_id || !$is_curr_lvl  || !$is_curr_type} {
			set curr_id    $ob_id
			set curr_lvl   $ob_level
			set curr_type  $type

			set CODES($ob_level,$ob_id,$type,codes)  ""
			# Endemol can't handle codes that start with a number
			set CODES($ob_level,$ob_id,types)        ""

			if {$type == "PERD"} {
				set CODES($ob_level,$ob_id,$type,codes) "TOTAL"
			}
		}

		lappend CODES($ob_level,$ob_id,$type,codes)  $code
		lappend CODES($ob_level,$ob_id,types)        $type

	}
	ob_db::rs_close $rs

	set CODES(available) "Y"
}


#
#  _convert_tennis_scre
#    Some tennis scores are special values. These need converting before displaying
#
proc commentary::_convert_tennis_scre {score} {
	switch $score {
		403 {
			set score "A"
		}
		404 {
			set score "D"
		}
	}

	return $score
}


#
# revert_numbers
#        Reverts a code into a format that is supported by the endemol
#        flash front end.
#
proc commentary::revert_numbers {code} {
	set no_chars [string length $code]

	set no_nums 0

	for {set i 0} {$i < $no_chars} {incr i} {
		set char [string range $code $no_nums $i]

		if {[string is integer -strict $char]} {
			incr no_nums
		} else {
			break
		}
	}

	set chr_int_idx [expr {$no_nums-1}]
	set numbers [string range $code 0 $chr_int_idx]

	set letters [string range $code $no_nums $no_chars]

	return "$letters$numbers"
}

################################################################
# Functions that return XML / take input of XML nodes
################################################################


#
# create_xml
#  Main function to create a full XML document with commentary for
#  the endemol flash app.
#     ev_id   -   Event id to produce the XML for
#     lang    -   Visitors language
#
proc commentary::create_xml {ev_id lang} {
	variable EVENT_DETAILS
	variable FLAGS

	# First get the commentary version from the DB
	if {[get_ev_sport_details $ev_id]} {
		set commentary_ver $EVENT_DETAILS($ev_id,com_ver)
	} else {
		set commentary_ver "1"
	}

	commentary::_load_competitors $ev_id
	commentary::_get_flags        $ev_id

# get_refresh_rate is currently in the non ns flash_app.tcl
	set refresh_rate [get_refresh_rate "commentary" $ev_id]

	# Create XML root element
	dom setResultEncoding "UTF-8"
	set doc [dom createDocument "commentary"]
	$doc systemId "bir.dtd"

	set rootnode [$doc documentElement]
	# Add basic attributes
	$rootnode setAttribute "version"     $commentary_ver
	$rootnode setAttribute "refreshRate" $refresh_rate
	$rootnode setAttribute "language"    [tp_lang]
	$rootnode setAttribute "server_time" \
	[clock format [clock seconds] -format "%Y-%m-%d %T"]

	commentary::_add_ev_desc $doc $rootnode $ev_id
	commentary::_add_ev_header $doc $rootnode $ev_id
	commentary::_add_competitors $doc $rootnode $ev_id
	commentary::_add_clock $doc $rootnode $ev_id
	commentary::_add_summary $doc $rootnode $ev_id
	commentary::_add_messages $doc $rootnode $ev_id

	return $doc
}

#
# _add_summary
#   adds the summary information to the out going commentary
#     doc     -  The XML document
#     parent  -  The XML parent node
#     ev_id   -  The event ID
#
proc commentary::_add_summary {doc parent ev_id} {
	ob_log::write DEBUG {PROC:: commentary::_add_summary($doc,$ev_id)}

	variable EVENT_DETAILS
	variable EVENT_SETUP
	variable COMPETITORS
	variable CODES

	# Load all stat, and score codes relevant to this event

	set ob_lvl $EVENT_DETAILS($ev_id,ob_level)
	set ob_id  $EVENT_DETAILS($ev_id,ob_id)
	set sport  $EVENT_DETAILS($ev_id,sport)

	set stat_codes   $EVENT_SETUP($ev_id,stat_codes)
	set score_codes  $CODES($ob_lvl,$ob_id,SCRE,codes)

	set period_codes ""

	# Get all competitor ids for this event
	set competitor_list $COMPETITORS($ev_id,ext_ids)

	# The summary root should always be displayed
	set sum_tot_root [$doc createElement "summary"]
	set sum_tot_root [$parent appendChild $sum_tot_root]

	$sum_tot_root setAttribute "period" "total"


	set cur_per_code ""
	# Get all summary information for this event
	set rs    [ob_db::exec_qry get_event_summary $ev_id]
	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set period_code   [db_get_col $rs $i period_code]
		set code          [db_get_col $rs $i code]
		set competitor_id [db_get_col $rs $i competitor_id]
		set player_id     [db_get_col $rs $i player_id]
		set value         [db_get_col $rs $i value]
		set alt_score     [db_get_col $rs $i alt_score]

		if {$period_code != $cur_per_code} {
			lappend period_codes [set cur_per_code $period_code]
		}

		# Tennis requires these special score values to be converted
		if {$sport == "TENNIS"} {
			set value [_convert_tennis_scre $value]
		}

		# This is for cricket: only display the "normalised"
		# score (Runs/Wickets) when the period_code is "total"
		if {$sport == "CRICKET" && ($code == "in2" || $code == "in1")} {
			# Make sure the vaules are set

			set overs_score "0"

			set rs_perd_score [ob_db::exec_qry get_com_score_perd $ev_id "ovr" $code]
			if {[db_get_nrows $rs_perd_score] == 2} {
					set overs_score [db_get_col $rs_perd_score $competitor_id score]
				}
			ob_db::rs_close $rs_perd_score

			if {$value == 0 && $alt_score == 0 && $overs_score == 0} {
				set value       "-"
				set alt_score   "-"
				set overs_score "-"
			}

			if {$alt_score == ""} {
				set alt_score 0
			}

			set value "$value/$alt_score ($overs_score)"
		}


		# In case of wickets
		if {$value == "" && $alt_score != ""} {
			set value $alt_score
		}

		if {$value == ""} {
			set value 0
		}

		set SUMMARY($period_code,$code,$competitor_id) $value
	}
	ob_db::rs_close $rs

	# Is this a Tennis/Cricket event? If so, then the score codes for
	# when the period is "total" are the period codes (st1, etc.)
	# up to the highest set played so far.
	if {$sport == "TENNIS" || $sport == "CRICKET" || $sport == "BASKETBALL"} {
		switch $sport {
			"TENNIS" {
				set sport_periods [list st1 st2 st3 st4 st5]
			}
			"CRICKET" {
				set sport_periods [list in1 in2]
			}
			"BASKETBALL" {
				set sport_periods [list 1qua 2qua 3qua 4qua ovrt]
			}
		}

		set tot_score_codes {}
		# Only add codes for the periods that exist
		foreach element $sport_periods {
			if {[lsearch $period_codes $element] > -1} {
				lappend tot_score_codes $element
			}
		}
	}

	# We should always show the total period box
	if {[lsearch $period_codes "tot"] == -1} {
		lappend period_codes "tot"
	}

	# Now go through each period, stat/score, and competitor
	foreach period $period_codes {
		if {$period != "tot"} {
			set sum_root [$doc createElement "summary"]
			set sum_root [$parent appendChild $sum_root]

			set disp_code $period

			# Another patch for endemol
			if {$sport == "BASKETBALL" && $period == "ovrt"} {
				set disp_period "qua5"
			} else {
				set disp_period [revert_numbers $period]
			}

			$sum_root setAttribute "period" $disp_period
		} else {
			set sum_root $sum_tot_root
		}

		# Special case for Tennis/Cricket
		if {$period == "tot" && ($sport == "TENNIS" || $sport == "CRICKET" || $sport == "BASKETBALL") } {
			set codes "$stat_codes $score_codes $tot_score_codes"
		} else {
			set codes "$stat_codes $score_codes"
		}



		# Player count
		set bts1_score "-"
		set bts2_score "-"

		foreach code $codes {
			foreach competitor $competitor_list {
				set statsum_root [$doc createElement "statsum"]
				set statsum_root [$sum_root appendChild $statsum_root]

				if {$sport == "BASKETBALL" && $code == "ovrt"} {
					set disp_code "qua5"
				} else {
					set disp_code [revert_numbers $code]
				}

				$statsum_root setAttribute "id"         $disp_code
				$statsum_root setAttribute "competitor" $competitor


				set score_value 0
				set manual_score 0

				# Duplicate the score for both the competitors
				if {
					$sport == "CRICKET" && \
					($code == "bts1" || $code == "bts2") && \
					$competitor != 0 \
				} {
					switch -- $code {
						"bts1" {
								set score_value $bts1_score
						}
						"bts2" {
								set score_value $bts2_score
						}
					}

					set manual_score 1
				}

				set score_exists [info exists SUMMARY($period,$code,$competitor)]

				if {$manual_score == 0 && !$score_exists} {
					set score_value 0
				} elseif {$manual_score == 0} {

					if {$sport == "CRICKET"} {
						switch -- $code {
							"bts1" {
									set bts1_score $SUMMARY($period,$code,$competitor)
								}
							"bts2" {
									set bts2_score $SUMMARY($period,$code,$competitor)
							}
						}
					}

					set score_value $SUMMARY($period,$code,$competitor)
				}

				# If it is cricket we will need to add
				# the batsman info to the total
				if {\
					$sport == "CRICKET" && $period == "tot" && \
					($code == "bts1" || $code == "bts2")\
				} {
					_add_bms_element $doc $sum_root $code $ev_id $competitor
				}

				$statsum_root appendChild [$doc createCDATASection $score_value]
			}
		}

	}

}


#
#  _add_competitors
#   Adds the compeitor information to the XML response
#
proc commentary::_add_competitors {doc parent ev_id lang} {
	ob_log::write DEBUG {PROC:: commentary::_add_competitors($doc,$parent,$ev_id)}

	set rs_competitors [ob_db::exec_qry get_event_competitors $ev_id]

	set comp_root  [$doc createElement "competitors"]
	set comp_root  [$parent appendChild $comp_root]

	set ncompetitors   [db_get_nrows $rs_competitors]

	for {set i 0} {$i < $ncompetitors} {incr i} {
		set ev_oc_id  [db_get_col $rs_competitors $i ev_oc_id]
		set ext_id    [db_get_col $rs_competitors $i ext_id]
		set desc      [db_get_col $rs_competitors $i desc]
		set is_active [db_get_col $rs_competitors $i is_active]

		set clean_desc [ob_xl::sprintf $lang $desc]

		set comp_node  [$doc createElement "competitor"]
		set comp_node  [$comp_root appendChild $comp_node]

		$comp_node setAttribute "id" $ext_id

		# We only show the attribute if the comp is active
		if {$is_active == "Y" || $is_active == "1"} {
			$comp_node setAttribute "active" "Y"
		}

		$comp_node appendChild [$doc createCDATASection $clean_desc]
	}

	ob_db::rs_close $rs_competitors
}



#
# _add_messages
#    Adds commentary message from tComMsg to a parent XML node
#
#    doc     -  The XML document
#    parent  -  The XML parent node to add the messages to
#    ev_id   -  The event id
#    lang    -  The desired language for lang specific messages
#
proc commentary::_add_messages {doc parent ev_id lang} {
	ob_log::write DEBUG {PROC:: commentary::_add_messages($doc,$parent,$ev_id)}

	variable EVENT_DETAILS

	set rs_msgs [ob_db::exec_qry get_com_msgs $ev_id $lang]

	set nrows [db_get_nrows $rs_msgs]

	# Add messages element to a messages container
	set msg_root  [$doc createElement "messages"]
	set msg_root  [$parent appendChild $msg_root]

	ob_log::write DEBUG "number of messages is nmesages='$nrows'"

	for {set i 0} {$i < $nrows} {incr i} {

		# Add the main msg sub node
		set msg_node [$doc createElement "msg"]
		set msg_node [$msg_root appendChild $msg_node]

		$msg_node   setAttribute  "id"          [db_get_col $rs_msgs $i ev_msg_id]

		set type [string tolower [db_get_col $rs_msgs $i stat_code]]
		set dis_type [revert_numbers $type]

		$msg_node   setAttribute  "type"       $dis_type

		set period_code [db_get_col $rs_msgs $i period_code]
		set disp_perd   [revert_numbers $period_code]

		$msg_node   setAttribute  "period" $disp_perd

		set period_num [db_get_col $rs_msgs $i period_num]

		if {$period_num != ""} {
			$msg_node setAttribute "period_num" $period_num
		}

		$msg_node   setAttribute  "competitor"  [db_get_col $rs_msgs $i comp_ext_id]

		set full_txt                            [db_get_col $rs_msgs $i free_txt]
		set full_txt_lang                       [db_get_col $rs_msgs $i free_txt_lang]

		if {$full_txt_lang == "" && $full_txt != ""} {
			set items [llength $full_txt]

			# The full translated text (parameters translated)
			set full_trans_txt  [lindex $full_txt 0]

			# translate the parmeters as well
			for {set j 1} {$j < $items} {incr j} {
				set param [lindex $full_txt $j]
				# ob_xl::sprintf can not handle empty parameters
				if {$param != ""} {
					set translated_param [ob_xl::sprintf $lang $param]
					set full_trans_txt "$full_trans_txt {$translated_param}"
					}
			}
			# Set the translated and then remove any remaining pipes
			set translated [string map {"|" ""} [eval "ob_xl::sprintf $lang $full_trans_txt"]]
		} else {
			# The message is a message with a lang so just display with out translation
			set translated $full_txt
		}
		$msg_node appendChild [$doc createCDATASection $translated]

		set db_clock_time [db_get_col $rs_msgs $i clock_time]

		if {[_get_ev_sport_details $ev_id]} {
			set sport $EVENT_DETAILS($ev_id,category)
			set clock_time [display_clock_time $db_clock_time $sport $period_code 1]
		} else {
			set clock_time [_get_dis_clock_time $db_clock_time]
		}

		$msg_node   setAttribute  "time"        $clock_time
	}

	ob_db::rs_close $rs_msgs
}

#
#  _add_ev_desc
#    Add event description to the header of the commentray
#
proc commentary::_add_ev_desc {doc parent ev_id} {
	ob_log::write DEBUG {PROC:: commentary::_add_ev_desc($doc,$parent,$ev_id)}

	variable EVENT_DETAILS

	set event_root  [$doc createElement "event"]
	set event_root  [$parent appendChild $event_root]

	$event_root setAttribute "id" $ev_id

	# Check to see if there has been an update to tComEvDesc
	get_event_desc $ev_id

	set desc ""
	set full_desc $EVENT_DETAILS($ev_id,desc)

	if {$full_desc != ""} {
	    	set desc [string map {"|" ""} [eval "ob_xl::sprintf $lang $full_desc"]]
	} else {
		ob_log::write DEBUG "No event description found for ev_id='$ev_id'"
	}

	set has_stats   "N"
	set has_score   "N"
	set has_perform "N"

	set rs [ob_db::exec_qry get_event_perform_id $ev_id]
	if {[db_get_nrows $rs] == 1} {
		set has_perform "Y"
	}
	ob_db::rs_close $rs

	set rs [ob_db::exec_qry get_event_has_stats $ev_id]
	if {[db_get_nrows $rs] == 1} {
		set has_stats "Y"
	}
	ob_db::rs_close $rs

	set rs [ob_db::exec_qry get_event_has_setup $ev_id]
	if {[db_get_nrows $rs] == 1} {
		set has_score "Y"
	}
	ob_db::rs_close $rs

	$event_root   setAttribute  "stats_avail"    $has_stats
	$event_root   setAttribute  "score_avail"    $has_score
	$event_root   setAttribute  "perform_avail"  $has_perform

	$event_root   appendChild   [$doc createCDATASection $desc]

}

proc commentary::_add_ev_header {doc parent ev_id} {
	ob_log::write DEBUG {PROC:: commentary::_add_ev_header($doc,$parent,$ev_id)}
	variable EVENT_SETUP
	variable EVENT_DETAILS
	variable CODES
	variable FLAGS

	commentary::_load_ev_setup $ev_id

	set eventheader_root   [$doc createElement "eventheader"]
	set eventheader_root   [$parent appendChild $eventheader_root]

	$eventheader_root setAttribute "locale" $lang

	set ob_lvl $EVENT_DETAILS($ev_id,ob_level)
	set ob_id  $EVENT_DETAILS($ev_id,ob_id)
	set sport  $EVENT_DETAILS($ev_id,sport)

	# Create a defaultMessage Token in the transaltions
	set header_element [$doc createElement "translation"]

	$eventheader_root appendChild $header_element

	$header_element setAttribute "token" "defaultMessage"

	set translated_txt  [ob_xl::sprintf $lang "COM_DEFAULT_MSG"]
	$header_element appendChild [$doc createCDATASection $translated_txt]

	set abrv_tkn_prefix "abrv_"
	set abrv_prefix     "PERD_ABRV_"

	# If we have one of these sport we will also need a short code of the
	# period translation. E.g. 1st / 2nd or Ins etc
	if {$sport == "TENNIS" || \
			$sport == "CRICKET" || \
			$sport == "BASKETBALL" || \
			$sport == "BASEBALL" \
			} {

		foreach abvr $CODES($ob_lvl,$ob_id,PERD,codes) {
			set header_element [$doc createElement "translation"]

			$eventheader_root appendChild $header_element

			set disp_abvr [revert_numbers $abvr]

			set sport $EVENT_DETAILS($ev_id,sport)
			if {$sport == "BASKETBALL" && $abvr == "ovrt"} {
				set disp_abvr  "qua5"
			} else {
				set disp_abvr [revert_numbers $abvr]
			}

			$header_element setAttribute "token" "$abrv_tkn_prefix$disp_abvr"

			set untranslated_txt "$abrv_prefix[string toupper $abvr]"

			set translated_txt [ob_xl::sprintf $lang $untranslated_txt]

			$header_element appendChild [$doc createCDATASection $clean_txt]

		}
	}

	set stat_prefix "STAT_HEADER_"
	foreach stat_code $CODES($ob_lvl,$ob_id,STAT,codes) {
		if {$stat_code == "scre"} {
			continue
		}
		set header_element [$doc createElement "translation"]

		$eventheader_root appendChild $header_element

		set disp_stat [revert_numbers $stat_code]
		$header_element setAttribute "token"  $disp_stat

		set untranslated_txt "$stat_prefix[string toupper $stat_code]"

		set translated_txt [ob_xl::sprintf $lang $untranslated_txt]

		if {[lsearch $EVENT_SETUP($ev_id,stat_codes) $stat_code] != -1} {
			if {$EVENT_SETUP($stat_code,recorded) == "Y"} {
				$header_element setAttribute "recorded"  "Y"
			}
		}

		set clean_txt [commentary::_string_trans_codes $translated_txt]
		$header_element appendChild [$doc createCDATASection $clean_txt]
	}

	set scre_prefix "SCORE_HEADER_"
	foreach score_code $CODES($ob_lvl,$ob_id,SCRE,codes) {
		set header_element [$doc createElement "translation"]

		$eventheader_root appendChild $header_element

		$header_element setAttribute "token"  $score_code

		$header_element setAttribute "recorded"  "Y"

		set untranslated_txt "$scre_prefix[string toupper $score_code]"

		set translated_txt [ob_xl::sprintf $lang $untranslated_txt]

		set clean_txt [commentary::_string_trans_codes $translated_txt]
		$header_element appendChild [$doc createCDATASection $clean_txt]
	}

	set perd_prefix "PERIOD_CODE_"

	foreach period_code $CODES($ob_lvl,$ob_id,PERD,codes) {
		set header_element [$doc createElement "translation"]

		$eventheader_root appendChild $header_element

		set sport $EVENT_DETAILS($ev_id,sport)
		if {$sport == "BASKETBALL" && $period_code == "ovrt"} {
			set disp_perd_code  "qua5"
		} else {
			set disp_perd_code [revert_numbers $period_code]
		}

		$header_element setAttribute "token"  [string tolower $disp_perd_code]

		set untranslated_txt "$perd_prefix[string toupper $period_code]"

		set translated_txt [ob_xl::sprintf $lang $untranslated_txt]

		set clean_txt [commentary::_string_trans_codes $translated_txt]
		$header_element appendChild [$doc createCDATASection $clean_txt]
	}

	if {[lsearch $FLAGS($ev_id,flags) "BSTOF"] != -1} {
		set value $FLAGS($ev_id,BSTOF)

		set header_element [$doc createElement "bestOf"]

		$eventheader_root appendChild $header_element

		$header_element appendChild [$doc createCDATASection $value]
	}
}


#
# Adds a populated clock node to a give parent
#   ev_id  -  Event ID
#   parent -  XML Parent node to add clock to
#   doc    -  The XML document it's self
#
proc commentary::_add_clock {doc parent ev_id} {
	ob_log::write DEBUG {PROC:: commentary::_add_clock($doc,$parent,$ev_id)}
	variable EVENT_DETAILS

	set clock_root  [$doc createElement "clock"]
	set clock_root  [$parent appendChild $clock_root]

	foreach {state period_code clock_time} [get_clock $ev_id] {}

	$clock_root setAttribute "state"  $state
	set disp_perd [revert_numbers $period_code]
	$clock_root setAttribute "period" $disp_perd
	$clock_root appendChild [$doc createCDATASection $clock_time]

}

#
# add_com_digest
#     Fetches data and then adds the node to the parent_node
#  doc          -  XML Document
#  parent_node  -  XML Parent node to add the digest to
#  ev_id        -  Event ID to produce digest for
#
proc commentary::add_com_digest {doc parent_node ev_id} {

	set res [get_com_digest $ev_id]

	if {[lindex $res 0] == "ERROR"} {
		return -1
	}

	foreach {ok type score score2 created ev_id add_clock} $res {
		add_com_digest_node $doc $parent_node $type \
			$score $score2 $created $ev_id $add_clock
	}

	return 1
}

#
# add_com_digest
#    Adds the old format commentary to a parent node
#  doc          -  XML Document
#  parent_node  -  XML Parent node to add digest to
#  type         -  Event state
#  score        -  Main score
#  score2       -  Alternative score
#  created      -  When was the last update
#  ev_id        -  Event ID
#  (add_clock)  -  Should a clock element be shown
#               -  Defaults to no
#
proc commentary::add_com_digest_node {doc parent_node \
	type score score2 created ev_id {add_clock 0}} {

	set element  [$doc createElement "EventState"]
	set evstate  [$parent_node appendChild $element]

	$evstate setAttribute  "state"    $type
	$evstate setAttribute  "updated"  $created


	set element  [$doc createElement "EventScores"]
	set evscores [$parent_node appendChild $element]

	$evscores setAttribute "score_1"  $score
	$evscores setAttribute "score_2"  $score2

	if {$add_clock} {
		commentary::_add_clock $doc $parent_node $ev_id
	}
}


#
# Adds the bats man name to a score element
#
proc commentary::_add_bms_element {doc sum_root code ev_id competitor} {

	array set currt_batsmen [list]
	set rs [ob_db::exec_qry get_batsmen $ev_id]
	set curr_batsmen(nrows) [db_get_nrows $rs]

	if {$curr_batsmen(nrows) != 2} {
		ob_log::write DEBUG \
		"There is no currents bats men for '$code' '$competitor'"
		return -1
	}

	for {set r 0} {$r < $curr_batsmen(nrows)} {incr r} {
		set btm         [db_get_col $rs $r btm]
		set player_name [db_get_col $rs $r player_name]

		if {$btm == "btm1"} {
			set curr_batsmen(bts1,ply_name)  $player_name
			set curr_batsmen(bts1,id_token) "btm1"
		} else {
			set curr_batsmen(bts2,ply_name)  $player_name
			set curr_batsmen(bts2,id_token)  "btm2"
		}

	}

	set player_name $curr_batsmen($code,ply_name)
	set id_token    $curr_batsmen($code,id_token)

	set statsum_root [$doc createElement "statsum"]
	set statsum_root [$sum_root appendChild $statsum_root]

	$statsum_root setAttribute "id"         $id_token
	$statsum_root setAttribute "competitor" $competitor

	$statsum_root appendChild [$doc createCDATASection $player_name]

	return 1
}
