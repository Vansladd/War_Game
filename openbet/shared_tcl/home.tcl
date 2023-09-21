# $Id: home.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval OB_home {


namespace export init_home
namespace export hm_show_home
namespace export hm_print_bb_link


variable  HOME_LINKS
array set HOME_LINKS [list\
				  CLASS  {?action=go_types&class_id=$id_key}\
				  COUPON {?action=go_coupon&coupon_id=$id_key}\
				  TYPE   {?action=go_events&type_id=$id_key}\
				  MARKET {?action=go_market&ev_mkt_id=$id_key}\
				  EVENT  {?action=go_event&ev_id=$id_key}]


proc init_home {} {
	prepare_home_qrys
}

proc prepare_home_qrys {} {

	db_store_qry hm_get_control {
		select
			  num_bets,
			  num_news
		from
			  tHomeControl
	}



	db_store_qry hm_get_bbets {
		select
			  id_key,
			  id_level,
			  disp_title title,
			  desc,
			  image,
			  disporder,
			  displayed
		from
			  vBestbets
		where
			  displayed='Y'
		order by
			  disporder
	}

	db_store_qry hm_get_news {
		select
			  nvl(link_title, info_url) title,
			  info_url,
				  news,
			  small_image image,
			  disporder
		from
			  tNews
		order by
			  disporder
	}


		db_store_qry hm_get_bbets_special {
		select
		      id_key,
		      id_level,
		      disp_title title,
		      desc,
		      image,
		      disporder,
		      displayed
		from
		      vBestbets
		where
			  displayed = 'Y' and
			  disporder = 1011 and
			  to_date > CURRENT and
			  from_date < CURRENT
		order by
		      disporder
	}

}



proc hm_get_control {bbet_var news_var} {

	upvar 1 $bbet_var num_bets $news_var num_news

	set rs [db_exec_qry hm_get_control]

	if {[db_get_nrows $rs] < 1} {
		ob::log::write WARNING {home control query returned no rows}
		set num_bets 100
		set num_news 100
	} else {
		set num_bets [db_get_col $rs num_bets]
		set num_news [db_get_col $rs num_news]
	}
	db_close $rs
}


proc hm_get_bbets {} {
	return [db_exec_qry hm_get_bbets]
}

proc hm_get_news {} {
	return [db_exec_qry hm_get_news]
}

proc hm_show_home {{home_template home.html}} {

	global BBETS NEWS CATEGORY CLASS

	set CATEGORY HOME
	tpSetVar is_home Y

	hm_get_control num_bets num_news

	set rs_bb [hm_get_bbets]
	set rs_nw [hm_get_news]

	hm_bind_bbets $rs_bb $num_bets
	hm_bind_news  $rs_nw $num_news

	play_file $home_template

	db_close $rs_bb
	db_close $rs_nw
}


proc hm_bind_bbets {rs num_bets} {

	global BBETS
	variable HOME_LINKS

	if [info exists BBETS] {
		unset BBETS
	}

	set num_bets [min $num_bets [db_get_nrows $rs]]
	set BBETS(colnames) [db_get_colnames $rs]

	for {set i 0} {$i < $num_bets} {incr i} {
		foreach c $BBETS(colnames) {
			set BBETS($i,$c) [db_get_col $rs $i $c]
		}
	}

	set BBETS(num_bets) $num_bets

	tpSetVar bb_idx 0

	tpBindTcl BB_LINK  hm_print_bb_link

	tpBindVar BB_IMAGE BBETS image bb_idx
	tpBindVar BB_TITLE BBETS title bb_idx
	tpBindVar BB_DESC  BBETS desc  bb_idx

	if {$num_bets > 0} {

		# set up variable for substitution into the link
		foreach c $BBETS(colnames) {
				set $c $BBETS(0,$c)
		}

		tpBindString BB_LINK1  [subst $HOME_LINKS($BBETS(0,id_level))]
		tpBindString BB_IMAGE1 $BBETS(0,image)
		tpBindString BB_TITLE1 $BBETS(0,title)
		tpBindString BB_DESC1  $BBETS(0,desc)
	}

}

proc hm_print_bb_link {} {

	global BBETS
	variable HOME_LINKS

	set bb_idx [tpGetVar bb_idx]

	# set up variable for substitution into the link
	foreach c $BBETS(colnames) {
		set $c $BBETS($bb_idx,$c)
	}

	tpBufWrite [subst $HOME_LINKS($BBETS($bb_idx,id_level))]
}


proc hm_bind_news {rs num_news} {

	global NEWS

	if [info exists NEWS] {
		unset NEWS
	}

	set num_news [min $num_news [db_get_nrows $rs]]
	set NEWS(colnames) [db_get_colnames $rs]

	for {set i 0} {$i < $num_news} {incr i} {
		foreach c $NEWS(colnames) {
			set NEWS($i,$c) [db_get_col $rs $i $c]
		}
	}

	set NEWS(num_news) $num_news

	tpBindVar NEWS_LINK  NEWS info_url    news_idx
	tpBindVar NEWS_IMG   NEWS image       news_idx
	tpBindVar NEWS_TITLE NEWS title       news_idx
	tpBindVar NEWS_DESC  NEWS news        news_idx

}



# close namespace
}
