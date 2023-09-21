# $Id: pools_setup_picker.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# this file handles the popup windows for selecting an event or market
# for the pools screens
# there's no reason a customer couldn't have several of these windows
# open at once, so be extra vigilant with global variables

namespace eval ADMIN::POOLS::SETUP {

asSetAct ADMIN::POOLS::SETUP::go_pool_pick   [namespace code go_pool_picker]

	#------------------------
	proc go_pool_picker args {
	#------------------------

		# new version
		global DB

		set number [ reqGetArg no ]

		# come from a normal link
		set level   [ reqGetArg level ]
		set curr_id [ reqGetArg id ]

		# come from a nav link
		set to      [ reqGetArg to ]
		set from    [ reqGetArg from ]
		set curr_id [ reqGetArg curr_id ]

		# check that we have the level we're at: either level or from must be set
		if { (![info exists level] || $level == "" ) && \
			 (![info exists from] || $from == "" ) } {
			log 15 "Don't know what level we're looking at: reverting to category"
			set level "Category"
			set from ""
		}
		if { ![info exists level] } { set level "" }
		if { ![info exists from] } {  set from "" }

		if { ![info exists curr_id] || $curr_id == "" } {
			log 15 "No id passed through; reverting to category"
			set level "Category"
			set from ""
		}

		if { ![info exists to] } { set to "" }

		# use curr_id and level to get all the higher level ids
		if { $from == "" } {
			set lvl $level
		} else {
			set lvl $from
		}
		set lv -1
		if { $lvl == "Category" } {
			set sql ""
			set lv 0
		} elseif { $lvl == "Class" } {
		set sql "select c.category as cat_id from tevcategory c, \
					 tevclass cl where cl.ev_class_id = $curr_id \
					 and cl.category = c.category"
			set lv 1
		} elseif { $lvl == "Type" } {
		set sql "select c.category as cat_id, cl.ev_class_id as class_id\
					 from tevcategory c, tevclass cl, tevtype t \
					 where c.category = cl.category \
					 and cl.ev_class_id = t.ev_class_id \
					 and t.ev_type_id = $curr_id"
			set lv 2
		} elseif { $lvl == "Event" } {
		set sql "select c.category as cat_id, cl.ev_class_id as class_id,\
					 t.ev_type_id as type_id \
					 from tevcategory c, tevclass cl, tevtype t, tev e \
					 where c.category = cl.category \
					 and cl.ev_class_id = t.ev_class_id \
					 and t.ev_type_id = e.ev_type_id and e.ev_id = $curr_id"
			set lv 3
		} else {
			# lvl == Market
		set sql "select c.category as cat_id, cl.ev_class_id as class_id,\
					 t.ev_type_id as type_id, e.ev_id as ev_id \
					 from tevcategory c, tevclass cl, tevtype t, tev e, tevmkt m \
					 where c.category = cl.category \
					 and cl.ev_class_id = t.ev_class_id \
					 and t.ev_type_id = e.ev_type_id \
					 and e.ev_id = m.ev_id and m.ev_mkt_id = $curr_id"
			set lv 4
		}

		if { $sql != "" } {
			set stmt [ inf_prep_sql $DB $sql ]
			set res  [ inf_exec_stmt $stmt ]
			set rc   [ inf_get_row_count $stmt ]
			inf_close_stmt $stmt
		} else {
			set res ""
		}

		set cat_id $curr_id
		set class_id ""
		set type_id ""
		set ev_id ""
		set ev_mkt_id ""

		if { $res != "" } {
			if { $rc < 1 } {
				log 15 "rows returned: $rc -- this is wrong"
				set level "Category"
				set from ""
			} else {
				if { $lv >= 1 } {
					set cat_id [ db_get_col $res 0 cat_id ]
					set class_id $curr_id
					if { $lv >= 2 } {
						set class_id [ db_get_col $res 0 class_id ]
						set type_id $curr_id
						if { $lv >= 3 } {
							set type_id [ db_get_col $res 0 type_id ]
							set ev_id $curr_id
							if { $lv == 4 } {
								set ev_id [ db_get_col $res 0 ev_id ]
								set ev_mkt_id $curr_id
							}
						}
					}
				}
			}
		}

		# now create the sql for getting the next page
		# if to is set, we're using the nav links, so that's the next page
		if { $to != "" } { set lvl $to }

		if { $lvl == "Category" } {
		set sql "select category as id, category as name from tevcategory"
			set uplevel "Class"
		} elseif { $lvl == "Class" } {
			set sql "select cl.ev_class_id as id, cl.name as name from tevclass cl,\
				 tevcategory c where c.category = '$cat_id' \
					 and c.category = cl.category"
			set uplevel "Type"
		} elseif { $lvl == "Type" } {
			set sql "select ev_type_id as id, name as name from tevtype \
					 where ev_class_id = $class_id"
			set uplevel "Event"
		} elseif { $lvl == "Event" } {
			set sql "select ev_id as id, desc as name from tev \
					 where ev_type_id = $type_id"
			set uplevel "Market"
		} else {
			set sql "select m.ev_mkt_id as id, g.name as name,e.desc as evname 
					 from tev e, tevmkt m, \
					 tevocgrp g where m.ev_id = $ev_id and e.ev_id = m.ev_id\
					 and m.ev_oc_grp_id = g.ev_oc_grp_id"
			set uplevel ""
		}

		set stmt [ inf_prep_sql $DB $sql ]
		set res1 [ inf_exec_stmt $stmt ]
		set rc1  [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt

		set norows 0
		if { $rc1 < 1 } {
			log 15 "Failed to get the data for the next page.  level is $lvl, curr_id is $curr_id"
			set norows 1
		}

		# load the array with the data

		global LinkArray
		if { [info exists LinkArray] } { unset LinkArray }
		if { $norows == 0 } {
			for { set i 0 } { $i < $rc1 } { incr i } {
				set LinkArray($i,id) [ db_get_col $res1 $i id ]
				set LinkArray($i,name) [ db_get_col $res1 $i name ]
			}

			# need the ev_id at the market level if just selecting events
			if { $lvl == "Market" } {
				tpSetVar MARKET 1
				set LinkArray(0,evid) $ev_id
				tpBindString EvId $ev_id
				tpBindString EvName [ db_get_col $res1 0 evname ]
				# need all the markets for the Ev, so use Ev level 
				log 15 "[return_pool Event $ev_id $number ]"
				log 15 "lvl is $lvl , ev_id is $ev_id and number is $number"
			}

			tpBindVar id   LinkArray id idx
			tpBindVar name LinkArray name idx
		}

		# bind the rest of the variables
		tpSetVar NOROWS $norows
		tpSetVar count $rc1
		tpBindString Title $lvl
		tpBindString number $number

		tpBindString catid $cat_id
		tpBindString classid $class_id
		tpBindString typeid $type_id
		tpBindString evid $ev_id
		tpBindString mktid $ev_mkt_id

		tpBindString uplevel $uplevel
		tpBindString level $lvl
		asPlayFile "pools_setup/pools_setup_picker.html"


	} 

	#---------------------
	proc go_pool_picker2 args {
	#---------------------

		global DB

		set number [ reqGetArg no ] ;# this is the leg we came from
		set level  [ reqGetArg level ] ;# which step we're up to
		set curr_id [ reqGetArg curr_id ]	;# get extra info for the sql query
		set cat_id [ reqGetArg cat_id ]  ;# only some of these next 4 will exist
		set class_id [ reqGetArg class_id ]
		set type_id [ reqGetArg type_id ]
		set ev_id   [ reqGetArg ev_id ]
		set back [ reqGetArg back ] ;# indicates nav link rather than selection
		set popup [ reqGetArg popup ]  ;# this only exists when popup is opened

		if { ![info exists number] || $number == "" } {
			log 15 "Opened popup from the wrong place."
			error "Incorrect popup.  Please close and continue"
			return
		}

		if { ![info exists level] || $level == "" } {
			set level "Category"	;# if level is missing, start at the beginning
		}

		if { ![info exists back] || $back != 1 } {
			# come from a selection link, so make sure curr_id is set
			if { ( ![info exists curr_id ] || $curr_id == "" ) && ( $level != "Category" ) } {
				log 15 "No id passed for level $level -- can't continue"
				error "Insufficient information to continue.  Please close and try again"
				return
			}
		} else {
			# come from a back link, so curr_id won't be set
			if { [info exists curr_id] && $curr_id != "" } {
				# come from the opening of the popup, everything's fine
			} elseif { $level == "Category" } { 
				set curr_id $cat_id 
			} elseif { $level == "Class" } {
				set curr_id $class_id
			} elseif { $level == "Type" } {
				set curr_id $type_id
			} elseif { $level == "Event" } {
				set curr_id $ev_id
			} 
		}

		log 15 "level is $level"
		log 15 "class_id is $class_id"
		log 15 "cat_id   is $cat_id"
		log 15 "type_id  is $type_id"
		log 15 "event_id is $ev_id"
		log 15 "curr_id  is $curr_id"

		if { [info exists popup] && $popup == 1 } {
			# just opened popup
			if { [info exists ev_id] && $ev_id != "" } {
				# not the first selection
				set level "Market"
				set curr_id $ev_id
			}
		}

		# curr_id exists at this stage, so put it in
		# even if we've come from a nav link, we need all of these if they exist
		if { ![info exists back] || $back != 1 } {
		  if { $level == "Category" } {
			set cat_id $curr_id
		} elseif { $level == "Class" } {
			set class_id $curr_id
		} elseif { $level == "Type" } {
			set type_id $curr_id
		} elseif { $level == "Event" } {
			set ev_id $curr_id
		}
		}
		# pick the sql statement for the level.  Note we always select as id and
		# name as it makes the array setup for LinkArray much simpler.

		set sql ""

		if { $level == "Category" } {
		set sql "select category as id, category as name from tEvCategory"
			set uplevel "Class"
		} elseif { $level == "Class" } {
		set sql "select cl.ev_class_id as id, cl.name from tEvClass cl, tEvCategory c where c.category = '$curr_id' and c.category = cl.category"
			set uplevel "Type"
		} elseif { $level == "Type" } {
			set sql "select ev_type_id as id, name from tEvType where ev_class_id = $curr_id"
			set uplevel "Event"
		} elseif { $level == "Event" } {
			set sql "select ev_id as id, desc as name from tEv where ev_type_id = $curr_id"
			set uplevel "Market"
		} elseif { $level == "Market" } {
			set sql "select m.ev_mkt_id as id,m.ev_id as evid, e.desc as evname, \
					g.name as name from tEvMkt m,tEv e,tEvOcGrp g \
					where m.ev_id = $curr_id \
					and e.ev_id = m.ev_id and m.ev_oc_grp_id = g.ev_oc_grp_id"
			set uplevel "Event"
		}

		if { $sql == "" } {
			log 15 "Unknown level: level passed is $level"
			error "Unable to construct a query for this stage.  Please close and retry."
			return
		}

		set stmt [ inf_prep_sql $DB $sql ]
		set res  [ inf_exec_stmt $stmt ]
		set rc   [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt

		# create LinkArray and make sure we don't have someone else's junk in it
		global LinkArray
		if { [info exists LinkArray] } { unset LinkArray }

		if { $rc < 1 } {
			log 15 "No rows returned for level $level , id $curr_id"
			tpSetVar NOROWS 1
		} else {
			# load the result set into an array for the page
			for { set i 0 } { $i < $rc } { incr i } {
				set LinkArray($i,name) [ db_get_col $res $i name ]	
				set LinkArray($i,id)   [ db_get_col $res $i id ]
			}

			tpBindVar name LinkArray name idx
			tpBindVar id   LinkArray id   idx
			tpSetVar NOROWS 0
		}

		if { $level == "Market" && [tpGetVar NOROWS] == 0 } {
			# need evid available for the TP_TCL command as well as a BindString
			set LinkArray(0,evid) [db_get_col $res 0 evid]
			tpSetVar MARKET 1
			tpBindString EvId [db_get_col $res 0 evid]
			tpBindString EvName [ db_get_col $res 0 evname ]
		}


		tpSetVar count $rc
		tpBindString Title $level
		tpBindString number $number
		tpBindString uplevel $uplevel
		tpBindString catid $cat_id
		tpBindString classid $class_id
		tpBindString typeid $type_id
		tpBindString evid $ev_id

		asPlayFile "pools_setup/pools_setup_picker.html"

	}

	#------------------------------------------
	proc return_pool { {level} {id} {number} } {
	#------------------------------------------

		#
		# This generates the string that will appear in the box on the pool form
		# It is called from the page using TP_TCL
		#

		global DB

		if { $level == "" || $id == "" || $number == "" } {
			log 15 "Error - enough info not passed to return_pool: level $level id $id number $number"
			error "Unable to determine what kind of event/market this is.  Please retry"
			return
		}

		if { $level == "Market" } {
			set sql "select \
					  g.name as n1, e.desc as n2, t.name as n3, cl.name as n4, cl.category as n5\
					 from \
					  tEvOcGrp g,\
					  tEv e,\
					  tEvType t,\
					  tEvClass cl,\
					  tEvMkt m\
					 where \
					 m.ev_mkt_id = $id \
					 and m.ev_oc_grp_id = g.ev_oc_grp_id\
					 and m.ev_id = e.ev_id\
					 and g.ev_type_id = t.ev_type_id\
					 and t.ev_class_id = cl.ev_class_id"
			} else {
				# level == Event
				set sql "select \
						 '' as n1, e.desc as n2, t.name as n3, cl.name as n4, cl.category as n5\
						 from \
						  tEv e,\
						  tEvType t,\
						  tEvClass cl\
						 where \
						  e.ev_id = $id\
						 and e.ev_type_id = t.ev_type_id\
						 and t.ev_class_id = cl.ev_class_id"
			}

		set stmt [ inf_prep_sql $DB $sql ]
		set res  [ inf_exec_stmt $stmt ]
		set rc   [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt

		if { $rc != 1 } {
			log 15 "$rc rows returned from sql query; should only be one"
			error "Unable to uniquely determine your chosen event.  Please try again."
			return
		}

		set str ""
		foreach item {n5 n4 n3 n2} {
			append str [ db_get_col $res 0 $item ]
			if { $item != "n2" } { append str " -> " }
		}
		if { $level == "Market" } {
			append str " -> "
			append str [ db_get_col $res 0 n1 ]
		}

		return $str
	}
	
# close namespace
} 
