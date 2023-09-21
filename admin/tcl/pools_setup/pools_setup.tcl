# $Id: pools_setup.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
namespace eval ADMIN::POOLS::SETUP {

asSetAct ADMIN::POOLS::SETUP::go_pools   [namespace code go_pools]

	# Code to handle pools setup and pools queries.

	proc go_pools args {

		set act [ reqGetArg SubmitName ]
		OT_LogWrite 1 "act: $act"

		if {$act == "AddPoolType" } {
			add_pooltype
		} elseif { $act == "AddPT" } {
			do_add_pooltype
		} elseif { $act == "UpdPT" } {
			tpSetVar UPDATE 1
			do_add_pooltype
		} elseif { $act == "DelPT" } {
			delete_pooltype
		} elseif { $act == "ViewPoolType" } {
			view_pooltype
		} elseif { $act == "Back" } {
			show_poolSource
		} elseif { $act == "UpdatePoolType" } {
			upd_pooltype
		} elseif { $act == "AddPool" } {
			add_pool
		} elseif { $act == "DoAddPool" } {
			do_add_pool
		} elseif { $act == "UpdatePool" } {
			tpSetVar UPDATE 1
			do_add_pool
		} elseif { $act == "QueryPool" } {
			go_query_pool		;#  this proc lives in poolquery.tcl
		} elseif { $act == "ResultPool" } {

			# different vars hold the values we want on the two pages we could have come from
			if { [reqGetArg refresh] == 1 } {
				reqSetArg sid   [reqGetArg Source]
				reqSetArg Types [ reqGetArg Type ]
				reqSetArg Pool  [ reqGetArg Pool ]
			}

			show_poolresult 	;# this lives in poolresult.tcl

		} elseif { $act == "do_div" } {
			ADMIN::POOLS::SETUP::eval_result
			} else {
				show_poolSource
			}

			return
	}

	#-------------------------
	proc show_poolSource args {
	#-------------------------

		# tPoolSource is a statically loaded table containing the details
		# of the various sources offering pools bet (e.g. Tote, Irish Tote,
		# TRNI, Slot, etc.)  This information may be viewed in the admin
		# screens, which is what this proc provides for.

		# some other procs in this file finish by calling this proc
		# to return to the main page.  If there's something to be
		# displayed as a result of a proc finishing, it can be put
		# into the tpBindString variable Message.
		# proc do_add_pool finishes like this.

		global DB

		set sql "select * from tPoolSource"
		set stmt [ inf_prep_sql $DB $sql ]
		if { [catch { set res [ inf_exec_stmt $stmt ] } msg ] } {
			log 15 "Error retrieving data from tPoolSource: $msg"
			error "Could not obtain data from tPoolSource."
			return
		}
		set rc [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt


		if { $rc < 1 } {
			log 15 "No rows returned from tPoolSource!"
			error "You do not appear to have any pool sources set up."
			return
		}

		# with a filled result set now available, bind the pieces for the html
		global SourceArray
		if { [ info exists SourceArray ] } {
			unset SourceArray
		}

		set choice 0

		for { set i 0 } { $i < $rc } { incr i } {
			set SourceArray($i,source) [ db_get_col $res $i desc ]
			set SourceArray($i,s_id)   [ db_get_col $res $i pool_source_id ]
			set SourceArray($i,ccy)    [ db_get_col $res $i ccy_code ]
			set SourceArray($i,div)    [ format %.2f [ db_get_col $res $i dividend_unit ] ]

	#		log 1 "source: [ db_get_col $res $i desc ]"
	#		log 1 "ccy_code: [ db_get_col $res $i ccy_code ]"
	#		log 1 "pool_source_id: [ db_get_col $res $i pool_source_id ]"
	#		log 1 "dividend_unit: [ db_get_col $res $i dividend_unit ]"

			if { [tpGetVar S_ID] == $SourceArray($i,s_id) } {
				set choice $i
				log 15 "Setting choice to be $choice"
			}

		}

		tpBindVar source SourceArray source idx
		tpBindVar sid    SourceArray s_id   idx
		tpBindVar ccy    SourceArray ccy    idx
		tpBindVar div    SourceArray div    idx

		tpSetVar  count  $rc
		tpBindString choice $choice

		asPlayFile "pools_setup/pools_setup_source.html"

	}

	#----------------------
	proc add_pooltype args {
	#----------------------

		#
		# when creating a new pool type, this is the first proc that gets called
		# the user will have come from the poolsource.html page, so we will
		# know the pool_source_id already.  Everything else needs to be
		# entered.  do_add_pooltype verifies and inserts the data.
		# See upd_pooltype for updating an existing pooltype
		#

		global DB

		set sid [ reqGetArg sid ]
		if { ![info exists sid] || $sid == "" } { set sid -1 }
		set sql "select * from tPoolSource where pool_source_id = '$sid'"
		set stmt [ inf_prep_sql $DB $sql ]
		set rs [ inf_exec_stmt $stmt ]
		set rc [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt
		if { $rc != 1 } {
			log 15 "Found $rc rows with source id $sid -- please check"
			error "Could not verify pool source.  Please use the back button on your browser to try again."
		}


		tpBindString Source [db_get_col $rs 0 desc]
		tpBindString sid	$sid

		asPlayFile "pools_setup/pools_setup_addpooltype.html"
	}

	#-------------------------
	proc do_add_pooltype args {
	#-------------------------

		#
		# this checks the data passed from the page and inserts it into
		# the database if it's valid.
		# note the use of string trim to remove excess whitespace
		#

		global DB
		set fail 0
		set fail_list ""

		set sid [ reqGetArg sid ]
		if { ![info exists sid] || $sid == "" } {
			log 15 "No pool source id passed.\n"
			set fail 1
			lappend fail_list "No pool source id."
		}

		set otype [ reqGetArg otype ]  ;# this is so we can update the type also
		set type [string trim [reqGetArg Type] ]
		set desc [string trim [reqGetArg Desc] ]
		set blurb [string trim [reqGetArg Blurb] ]
		set grouped_divs [reqGetArg GroupedDivs]

		if { [ regexp {^([a-zA-Z0-9-])+$} $type match ] == 0 } {
			set fail 1
			lappend fail_list "Type must consist of alphanumerics.\n"
		}
		if { [ regexp {^((?:[\w '-]+\s+)*[\w '-]+)$} $desc match ] == 0 } {
			set fail 1
			lappend fail_list "Name must consist of alphanumerics and whitespace.\n"
		}

		# double all single quotes prior to attempting to put them in the DB
		set type [ join [ split $type "'" ] "''" ]
		set desc [ join [ split $desc "'" ] "''" ]

		if { [ string length $type ] > 4 } {
			set fail 1
			lappend fail_list "Type code can have at most 4 characters\n"
		}
		if { [ string length $desc ] < 1 } {
			set desc "Unnamed type"
		}

		set legs [string trim [ reqGetArg numlegs ] ]
		set subs [string trim [ reqGetArg numsubs ] ]
		if { ![info exists legs] || $legs == "" } {
			set legs 0
		}
		if { ![info exists subs] || $subs == "" } {
			set subs 0
		}
		if { [ regexp {^[0-9]+$} $subs match ] == 0 } {
			set fail 1
			lappend fail_list "Num subs must be a non-negative integer.\n"
		}
		if { [ regexp {^[0-9]+$} $legs match ] == 0 } {
			set fail 1
			lappend fail_list "Num legs must be a non-negative integer.\n"
		}

		set min [string trim [ reqGetArg minst ] ]
		set max [string trim [ reqGetArg maxst ] ]
		set min_unit [string trim [ reqGetArg minunit ] ]
		set taxrate [string trim [ reqGetArg tax ] ]

		set stake_incr [string trim [reqGetArg StakeIncr]]

		set min_runners [string trim [reqGetArg MinRunners] ]
		set num_picks   [ string trim [reqGetArg num_picks ] ]

		set max_unit   [reqGetArg MaxUnit]
		set max_payout [reqGetArg MaxPayout]


		# handle entries left blank
		if { $min == "" } { set min 0 }
		if { $max == "" } { set max 0 }
		if { $min_unit == "" } { set min_unit 1 }
		if { $taxrate == "" } { set taxrate 0 }
		if { $min_runners == "" } { set min_runners 1 }
		if { $num_picks == "" } { set num_picks 1 }
		if { $grouped_divs == "" } { set grouped_divs N }
		if { $max_unit == "" } { set max_unit null }
		if { $max_payout == "" } { set max_payout null }

		set count 0
		set l [ list min max min_unit stake_incr taxrate ]
		set l1 [ list $min $max $min_unit $stake_incr $taxrate ]
		foreach item $l1 {
			if { [ regexp {^[0-9]+(?:\.[0-9]+)?$} $item match ] == 0 } {
				set fail 1
				lappend fail_list "[lrange $l $count $count] is invalid\n"
			}
			incr count
		}

		# these next five are select dropdowns and always populated
		set leg_type [ reqGetArg LegType ]
		set allup [ reqGetArg AllUp ]
		set favourite_avail [ reqGetArg FavAvail ]
		set voidact [ reqGetArg VoidAction ]
		set status [ reqGetArg PoolStatus ]

		set disporder [string trim [ reqGetArg disporder ] ]
		if { ![info exists disporder ] || [regexp {^([0-9])+$} $disporder match ] == 0 } {
			set disporder 0
		}

		if { $fail == 1 } {
			if { $fail_list != "" } {
				log 15 "Errors on page: [ join $fail_list "" ]"
				error "[join $fail_list ""]: please click Back on the browser and correct\n"
			} else {
				log 15 "Errors on page but fail_list is empty"
				error "An error has happened, please retry."
			}
			return
		}

		#
		# insert all the gathered data.  Note that bet-type is SGL for
		# the moment, until we find a suitable range of values for it.
		# if UPDATE is set, then we're doing update, not add
		#

		if { [tpGetVar UPDATE] == 1 } {
			if { ![info exists otype] || $otype == "" } {
				log 15 "Unable to determine type correctly"
				error "Update failed: please go back and retry."
				return
			} else {
					log 15 "Updating..."
					set sql "update tPoolType set\
					pool_type_id = '$type',\
					name = '$desc',\
					blurb = '$blurb',\
					num_legs = $legs,\
					leg_type = '$leg_type',\
					all_up_avail = '$allup',\
					favourite_avail = '$favourite_avail',\
					void_action = '$voidact',\
					min_stake = $min,\
					max_stake = $max,\
					min_unit = $min_unit,\
					max_unit = $max_unit,\
					stake_incr = $stake_incr,\
					max_payout = $max_payout,\
					tax_rate = $taxrate,\
					num_subs = $subs,\
					status = '$status',\
					disporder = $disporder,\
					min_runners = $min_runners,\
					num_picks = $num_picks,\
					grouped_divs = '$grouped_divs'\
					 where pool_type_id = '$otype'\
					 and   pool_source_id = '$sid'"
			}
		} else {
		set sql "insert into tPoolType
			 ( pool_type_id, pool_source_id, cr_date, name, blurb, num_legs,
			   leg_type, bet_type, all_up_avail, favourite_avail, void_action, min_stake,
			   max_stake, min_unit, max_unit, stake_incr, max_payout, tax_rate, num_subs, status, disporder,
			   min_runners, num_picks, grouped_divs )
			   values(\
			  '$type',\
			  '$sid',\
			  CURRENT,\
			  '$desc',\
			  '$blurb',\
			  $legs,\
			  '$leg_type',\
			  'SGL',\
			  '$allup',\
			  '$favourite_avail',\
			  '$voidact',\
			  $min,\
			  $max,\
			  $min_unit,\
			  $max_unit,\
			  $stake_incr,\
			  $max_payout,\
			  $taxrate,\
			  $subs,\
			  '$status',\
			  $disporder,
			  $min_runners,\
			  $num_picks,\
			  '$grouped_divs'\
			  );"
		}

		set stmt [ inf_prep_sql $DB $sql ]
		set rs   [ inf_exec_stmt $stmt ]
		set rc   [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt

		if { $rc != 1 } {
			log 15 "Error adding a new pool type, $rs rows returned from insert"
			error "An error has happened while trying to insert values."
			return
		}

		log 15 "Successfully added pool type."

		reqSetArg sid $sid
		view_pooltype

		return

	}

	#----------------------
	proc upd_pooltype args {
	#----------------------

		#
		# this is the proc that'll be used to modify a given pool type
		# after it's been created.
		#

		global DB

		set sid [ reqGetArg sid ]
		if { ![info exists sid] || $sid == "" } {
			log 15 "Failed to retrieve pool source id"
			error "Unable to determine the pool source, please retry"
			return
		}

		set tid [ reqGetArg Types ]
		if { ![info exists tid] || $tid=="" } {
			log 15 "Unable to retrieve pool type id"
			error "Unable to determine the pool type, please retry"
			return
		}

		set sql "select s.desc, t.* from tPoolSource s,tPoolType t where t.pool_type_id = '$tid' and t.pool_source_id = '$sid' and s.pool_source_id='$sid'"
		set stmt [ inf_prep_sql $DB $sql ]
		set rs   [ inf_exec_stmt $stmt ]
		set rc   [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt

		if { $rc != 1 } {
			log 15 "rows: $rc -- Failed to retrieve any pool type data for type $tid and source $sid"
			error "Could not locate any data for this type and source.  Please go back and check your entry."
			return
		}

		#
		# we've retrieved the data, now bind it for access from the page
		#

		tpBindString Type        $tid
		tpBindString sid         $sid
		tpBindString Source      [ db_get_col $rs 0 desc ]
		tpBindString Name        [ db_get_col $rs 0 name ]
		tpBindString Disporder   [ db_get_col $rs 0 disporder ]
		tpBindString Status      [ db_get_col $rs 0 status ]
		tpBindString Legtype     [ db_get_col $rs 0 leg_type ]
		tpBindString Numlegs     [ db_get_col $rs 0 num_legs ]
		tpBindString Allup       [ db_get_col $rs 0 all_up_avail ]
		tpBindString FavAvail    [ db_get_col $rs 0 favourite_avail ]
		tpBindString Voidaction  [ db_get_col $rs 0 void_action ]
		tpBindString Minstake    [ db_get_col $rs 0 min_stake ]
		tpBindString Maxstake    [ db_get_col $rs 0 max_stake ]
		tpBindString Minunit     [ db_get_col $rs 0 min_unit ]
		tpBindString MaxUnit     [ db_get_col $rs 0 max_unit ]
		tpBindString StakeIncr	 [ db_get_col $rs 0 stake_incr ]
		tpBindString MaxPayout   [ db_get_col $rs 0 max_payout ]
		tpBindString Taxrate     [ db_get_col $rs 0 tax_rate ]
		tpBindString Numsubs     [ db_get_col $rs 0 num_subs ]
		tpBindString NumPicks    [ db_get_col $rs 0 num_picks ]
		tpBindString MinRunners  [ db_get_col $rs 0 min_runners ]
		tpBindString GroupedDivs [ db_get_col $rs 0 grouped_divs ]
		tpBindString Blurb       [ db_get_col $rs 0 blurb ]

		tpSetVar UPDATE 1
		asPlayFile "pools_setup/pools_setup_addpooltype.html"
		return

	}

	#----------------------------
	proc delete_pooltype args {
	#----------------------------

		#
		# this deletes a viewed pool type from the database.
		#

		global DB

		set sid [ reqGetArg sid ]
		set type [ reqGetArg Type ]

		# these two together form the primary key; that's all we need

		if { ![info exists sid] || $sid == "" } {
			log 15 "Cannot delete from tPoolType without pool_source_id"
			error "This type cannot be deleted"
			return
		}
		if { ![info exists type] || $type == "" } {
			log 15 "Cannot delete from tPoolType without pool_type_id"
			error "This type cannot be deleted."
			return
		}

		set sql "delete from tpooltype\
				 where pool_type_id = '$type'\
				 and pool_source_id = '$sid'"
		set stmt [ inf_prep_sql $DB $sql ]
		set rs   [ inf_exec_stmt $stmt ]
		set rc   [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt

		if { $rc != 1 } {
			log 15 "Row count returned $rc -- which is wrong!"
			error "Error while trying to delete type."
			return
		}

		log 15 "Type $type with source id $sid successfully deleted"

		reqSetArg sid $sid
		view_pooltype

	}

	#-----------------------
	proc view_pooltype args {
	#-----------------------

		# retrieve the pooltypes for a given source and offer them

		global DB TypeArray

		set sid [ reqGetArg sid ]
		if { ![info exists sid] || $sid == "" } {
			log 15 "No pool source id passed."
			error "Cannot locate pool source id, please retry..."
			return
		}

		set sql "select pool_type_id,name from tPoolType where pool_source_id = '$sid'"
		log 15 "Executing $sql"
		set stmt [ inf_prep_sql $DB $sql ]
		set rs   [ inf_exec_stmt $stmt ]
		set rc   [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt

		if { $rc < 1 } {
			log 15 "Failed to find any rows for source id $sid"
			set rc 0
			set rs ""
		}

		# create an extra array for the poolsource.html page, then
		# go to its calling proc -- not the faster method, but OK

		for { set i 0 } { $i < $rc } { incr i } {
			set TypeArray($i,name) [ db_get_col $rs $i name ]
			set TypeArray($i,id)   [ db_get_col $rs $i pool_type_id ]
		}

		if { $rs == "" || $rc < 0 } {
			set TypeArray(0,name) "None"
			set TypeArray(0,id) -1
			set rc 1
		}

		tpSetVar  TYPE 1
		tpBindVar tname TypeArray name idx
		tpBindVar tid   TypeArray id   idx
		tpSetVar  tcount $rc
		tpSetVar  S_ID $sid

		show_poolSource

	}

	#------------------
	proc add_pool args {
	#------------------

		#
		# once we have pool types, we can add pools to them
		#

		global DB LegArray

		set sid [ reqGetArg sid ]
		set type [ reqGetArg Types ]
		set pid [ reqGetArg pid ]

		if { ![info exists sid] || $sid == "" } {
			log 15 "No source id passed; can't create pool"
			error "Failed to find source id, please retry"
			return
		}
		if { ![info exists type] || $type == "" } {
			log 15 "No type passed; can't create pool"
			error "Failed to obtain pool type, please retry"
			return
		}

		set sql "select num_legs, leg_type, all_up_avail from tPoolType where\
				 pool_source_id = '$sid' and pool_type_id = '$type'"
		set stmt [ inf_prep_sql $DB $sql ]
		set res1 [ inf_exec_stmt $stmt ]
		set rc1  [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt

		if { $rc1 != 1 } {
			log 15 "pool_source_id $sid and type_id $type returned $rc1 rows, which is wrong"
			error "Failed to obtain data from passed source and type ids. Please retry."
			return
		}

		if { ![info exists pid] } {
			# do nothing; pid won't exist for a new pool
		} else {
			if { $pid == "" } {
				log 15 "pid exists and is blank...there may be a problem"
			} else {
				set sql "select \
						 p.name,\
						 p.status,\
						 p.displayed,\
						 p.result_conf,\
						 p.settled,\
						 p.rec_dividend \
						 from tPool p where pool_id = $pid "
				set stmt [ inf_prep_sql $DB $sql ]
				set res2 [ inf_exec_stmt $stmt ]
				set rc2  [ inf_get_row_count $stmt ]
				inf_close_stmt $stmt

				if { $rc2 != 1 } {
					log 15 "$rc2 rows returned for pid $pid -- which is wrong"
					error "Could not resolve pool id: please retry"
					return
				}

				# get markets for pool next
				set sql "select m.ev_mkt_id \
						 from tpoolmkt m \
						 where m.pool_id = $pid"
				set stmt [ inf_prep_sql $DB $sql ]
				set res3 [ inf_exec_stmt $stmt ]
				set rc3  [ inf_get_row_count $stmt ]
				inf_close_stmt $stmt

				if { $rc3 < 1 } {
					log 15 "No markets attached to this pool, id: $pid"
					error "This pool appears to have no associated markets: please check"
					return
				} else {
					log 15 "Found $rc3 markets for pool_id $pid"
				}

				global IdArray
				if {[info exists IdArray]} { unset IdArray }

				for { set i 0 } { $i < $rc3 } { incr i } {
					set IdArray($i,mktid) [ return_pool "Market" [ db_get_col $res3 $i ev_mkt_id ] $i ]
					set IdArray($i,mid) [ db_get_col $res3 $i ev_mkt_id ]
					set IdArray($i,lvl) "Market"
				}


				tpBindVar    MktId     IdArray   mktid    idx
				tpBindVar    lvl       IdArray   lvl      idx
				tpBindVar    mktid     IdArray   mid      idx
				tpBindString Name      [ db_get_col $res2 0 name ]
				tpBindString Status    [ db_get_col $res2 0 status ]
				tpBindString Displayed [ db_get_col $res2 0 displayed ]
				tpBindString Result    [ db_get_col $res2 0 result_conf ]
				tpBindString Settled   [ db_get_col $res2 0 settled ]
				tpBindString Div       [ db_get_col $res2 0 rec_dividend ]
				tpSetVar UPDATE 1
				tpBindString pid $pid
			}
		}

		set num [ db_get_col $res1 0 num_legs ]
		if { $num == "" || $num < 0 } {
			set num 0
		}

		set allup [ db_get_col $res1 0 all_up_avail ]
		if { $allup == "Y" } {
			tpBindString Allup "(ALL UP)"
		} else {
			tpBindString Allup ""
		}

		# For leglist make sure that the key letter comes first so that lsearch
		# will return the correct place in the list.

		set legtype [ db_get_col $res1 0 leg_type ]
		set leglist [ list "W" "Win" "P" "Place" "O" "Ordered" "U" "Unordered" ]

		# set up the number of legs and the names for the page
		tpSetVar Numlegs $num
		for { set i 0 } { $i < $num } { incr i } {
			set LegArray($i,leg) "leg$i"
		}

		tpBindVar leg LegArray leg idx
		tpBindString Legtype [ lindex $leglist [expr {[lsearch $leglist $legtype] +1}] ]

		tpBindString sid $sid
		tpBindString type $type

		tpBindString EvMkt "Event/Market"
		tpBindString level "Category"

		asPlayFile "pools_setup/pools_setup_addpool.html"

		return

	}

	#-----------------------
	proc do_add_pool {args} {
	#-----------------------

		# actually insert the values into the db to create a pool

		global DB

		set sid  [ reqGetArg sid ]
		set pid  [ reqGetArg pid ]
		set type [ reqGetArg type ]

		if { ![info exists sid] || $sid == "" } {
			log 15 "No sid available from form to create pool with."
			error "The source id for this pool could not be located.  Please retry."
			return
		}

		if { ![info exists pid] || $pid == "" } {
			log 15 "No pid available -- must be a new pool."
		}

		if { ![info exists type] || $type == "" } {
			log 15 "No type available from form to create pool with."
			error "The pool type id for this pool could not be located.  Please retry."
			return
		}

		# get the leg information next
		set count [ reqGetArg count ]
		if { ![info exists count] || $count == "" } {
			log 15 "No count passed back -- how many legs are there then?"
			error "Can't count the legs of this pool.  Please restart."
			return
		}

		set fail 0
		set fail_list ""

		for { set i 0 } { $i < $count } { incr i } {
			if { [set level($i) [ reqGetArg level_leg$i ] ] == "" } {
				set fail 1
				lappend fail_list "No value for leg [ expr {$i + 1}] given"
				continue  ;# don't repeat error messages
			}
			if { [set id($i)    [ reqGetArg id_leg$i ] ] == "" } {
				set fail 1
				lappend fail_list "No value for leg [ expr {$i + 1}] given"
			}
		}

		set name   [ reqGetArg desc ]
		set status [ reqGetArg status ]
		set disp   [ reqGetArg displayed ]
		set div    [ reqGetArg dividend ]
		set result [ reqGetArg result ]
		set sett   [ reqGetArg settled ]
		set status   [ reqGetArg status ]

		if { ![info exists name] || $name == "" } {
			set fail 1
			lappend fail_list "Each pool must have a name"
		}

		if { $fail != 0 } {
			log 15 "Errors on page: $fail_list"
			error "Please correct the following:\n[ join $fail_list \n]\n"
		}

		if { $pid == "" } {
			# new pool, so this is an insert

			# step 1, add the pool
			set sql "execute procedure pInsPool\
					 ( p_adminuser = 'Administrator',\
					   p_pool_type_id = '$type',\
					   p_pool_source_id = '$sid',\
					   p_name = '$name',\
					   p_status = '$status',\
					   p_displayed = '$disp',\
					   p_result_conf = '$result',\
					   p_settled = '$sett',\
					   p_rec_dividend = '$div'"
			for { set i 0 } { $i < $count } { incr i } {
				set j [ expr { $i + 1 } ]
				append sql " ,p_id$j = '$id($i)'"

			}
			append sql " );"

			log 15 "sql is $sql"
			set stmt [ inf_prep_sql $DB $sql ]

			if { [catch { set res [ inf_exec_stmt $stmt ] } msg ] } {
				log 5 "Something went wrong in pInsPool: $msg"
				error "Cannot insert the new pool. Please check and try again"
				return
			}

			set rc   [ inf_get_row_count $stmt ]
			inf_close_stmt $stmt

			if { $rc != 1 } {
				log 5 "Something went wrong in pInsPool"
				error "Cannot insert the new pool. Please check and try again"
				return
			}

			tpBindString Message "Pool successfully added."

		} else {
			# updating an existing pool
			#
			# updating tPool is done through pUpdPool
			# updating the tPoolMkt entries is done by update_pool_markets
			#
			# the reason being it's much more complicated to update markets
			#

			set sql "execute procedure pUpdPool(\
					 p_adminuser='Administrator',\
					 p_pool_id=$pid,\
					 p_name = '$name',\
					 p_status = '$status',\
					 p_displayed = '$disp',\
					 p_result_conf = '$result',\
					 p_settled = '$sett',\
					 p_rec_dividend = '$div'\
					 );"
			set stmt [ inf_prep_sql $DB $sql ]
			set res3 [ inf_exec_stmt $stmt ]
			set rc3  [ inf_get_row_count $stmt ]
			inf_close_stmt $stmt

			if { $rc3 != 1 } {
				log 5 "Failed to update pool for pool_id $pid"
				error "Failed to update pool.  Please check data and retry."
				return
			}

			if { [ update_pool_markets $pid $count ] == -1 } {
				log 15 "Error happened while trying to update pool markets"
				error "Updated pool, but failed to update markets!"
				return
			}

			tpBindString Message "Pool updated successfully."

		}

		show_poolSource

		return
	}

	#--------------------------------
	proc update_pool_markets { {pid} {count} } {
	#--------------------------------

		#
		# pool_markets are awkward, so use this proc to update them
		#
		# if calling this from elsewhere, set up the ids and legs as
		# "  reqSetArg level_leg<n> E/M "
		# and " reqSetArg id_leg<n> ev_id/ev_mkt_id"
		# where n=1-9
		#

		global DB

		if { $pid == "" } {
			log 10 "No pool_id passed, cannot execute proc"
			return -1
		}

		if { $count == "" } {
			log 10 "count not passed; don't know how many args to collect"
			return -1
		}

		set fail 0
		set fail_list ""

		for { set i 0 } { $i < $count } { incr i } {
			if { [set level($i) [ reqGetArg level_leg$i ] ] == "" } {
				set fail 1
				lappend fail_list "No value for leg [ expr {$i + 1}] given"
				continue  ;# don't repeat error messages
			}
			if { [set id($i)    [ reqGetArg id_leg$i ] ] == "" } {
				set fail 1
				lappend fail_list "No value for leg [ expr {$i + 1}] given"
			}
		}

		if { $fail == 1 } {
			log 15 "Problems : $fail_list"
			error "Problems:\n [join $fail_list \n]\n"
			return -1
		}

		# that's the data collected, now get all the markets for the pool
		# from the db

		set sql "select pool_mkt_id,ev_mkt_id,leg_num \
				 from tPoolMkt \
				 where pool_id = $pid\
				 order by 3"
		set stmt [ inf_prep_sql $DB $sql ]
		set res  [ inf_exec_stmt $stmt ]
		set rc   [ inf_get_row_count $stmt ]
		inf_close_stmt $stmt

		if { $rc < 1 } {
			log 10 "No markets found for pool $pid ..."
			error "Failed to find any markets associated with this pool.  Please check and try again."
			return -1
		}

		set ev_list ""
		set mkt_list ""
		# loop through comparing the ids with those from the page
		for { set i 0 } { $i < $rc } { incr i } {
			if { $id($i) != [ db_get_col $res $i ev_mkt_id ] } {
				if { $level($i) == "E" } {
					lappend ev_list "$i,[db_get_col $res $i pool_mkt_id ]"
				} else {
					lappend mkt_list "$i,[db_get_col $res $i pool_mkt_id ]"
				}
			}
		}

		# ev_list holds those ids that have changed and are events
		# mkt_list holds those ids that have changed and are markets

		foreach item $ev_list {
			set idx [ lrange [ split $item ,] 0 0 ]
			set pmktid [ lrange [ split $item ,] 1 1 ]
			set sql "select ev_id from tEv where ev_id = $id($idx)"
			set stmt [ inf_prep_sql $DB $sql ]
			set res2 [ inf_exec_stmt $stmt ]
			set rc2  [ inf_get_row_count $stmt ]
			inf_close_stmt $stmt

			if { $rc2 < 1 } {
				log 15 "This ev_id $id($idx)  has no matching event; ignoring"
				continue
			} else {
				# ev_id matches, so get the market for it
				set sql "select t.leg_type from tPoolType t, tPool p, tPoolMkt m \
						 where m.pool_mkt_id = $pmktid and m.pool_id = p.pool_id \
						 and p.pool_source_id = t.pool_source_id \
						 and p.pool_type_id = t.pool_type_id"
				set stmt [ inf_prep_sql $DB $sql ]
				set res3 [ inf_exec_stmt $stmt ]
				set rc3  [ inf_get_row_count $stmt ]
				inf_close_stmt $stmt

				if { $rc3 != 1 } {
					log 10 "Wrong number ($rc3 ) of rows returned for leg_type"
					continue
				}

				set name_list [ list "W" "Pool Win Market" \
								"P" "Pool Place Market" \
								"U" "Pool Market Unordered" \
								"O" "Pool Market Ordered" ]
				set j [ lsearch $name_list [db_get_col $res3 0 leg_type ] ]
				if { $j == -1 } {
					log 15 "Unknown value in leg_type: [db_get_col $res3 0 leg_type]"
					continue
				}
				incr j
				set mkt_name [ lrange $name_list $j $j ]

				unset res3 rc3

				set sql "select g.ev_oc_grp_id from tEvOcGrp g, tEv e \
						 where e.ev_id = $id($idx) \
						 and e.ev_type_id = g.ev_type_id \
						 and g.name = $mkt_name"
				set stmt [ inf_prep_sql $DB $sql ]
				set res3 [ inf_exec_stmt $stmt ]
				set rc3  [ inf_get_row_count $stmt ]
				inf_close_stmt $stmt

				if { $rc3 != 1 } {
					# market doesn't exist, so create it
					set sql "select ev_type_id from tEv where ev_id = $id($idx)"
					set stmt [inf_prep_sql $DB $sql ]
					set res4 [inf_exec_stmt $stmt ]
					set rc4  [inf_exec_stmt $stmt ]
					inf_close_stmt $stmt

					if { $rc4 != 1 } {
						log 15 "Failed to obtain an ev_type_id for evid $id($idx)"
						continue
					}

					set sql "execute procedure pInsEvOcGrp( \
							 'Administrator', [db_get_col $res4 0 ev_type_id],\
							 '$mkt_name' )"
					set stmt [ inf_prep_sql $DB $sql ]
					set res5 [ inf_exec_stmt $stmt ]
					set rc5  [ inf_get_row_count $stmt ]
					inf_close_stmt $stmt

					if { $rc5 != 1 } {
						log 15 "Failed to insert evocgrp for $mkt_name"
						continue
					}

					unset res3 rc3
					set sql "select g.ev_oc_grp_id from tEvOcGrp g, tEv e \
						 where e.ev_id = $id($idx) \
						 and e.ev_type_id = g.ev_type_id \
						 and g.name = $mkt_name"
					set stmt [ inf_prep_sql $DB $sql ]
					set res3 [ inf_exec_stmt $stmt ]
					set rc3  [ inf_get_row_count $stmt ]
					inf_close_stmt $stmt

					if { $rc3 != 1 } {
						log 15 "Failed to obtain ev_oc_grp_id for $mkt_name after creating evocgrp"
						continue
					}
				}

				# if we reach here we have the ev_oc_grp_id we want in res3
					set sql "execute procedure pInsEvMkt( \
							 'Administrator', $id($idx), \
							 [db_get_col $res3 0 ev_oc_grp_id] )"
					set stmt [ inf_prep_sql $DB $sql ]
					set res6 [ inf_exec_stmt $stmt ]
					set rc6  [ inf_get_row_count $stmt ]
					inf_close_stmt $stmt

					if { $rc6 != 1 } {
						log 15 "Failed to insert market for $mkt_name"
						continue
					}

					set sql "select ev_mkt_id from tEvMkt m \
							 where ev_id = $id($idx) \
							 and   name = $mkt_name"
					set stmt [ inf_prep_sql $DB  $sql ]
					set res7 [ inf_exec_stmt $stmt ]
					set rc7  [ inf_get_row_count $stmt ]
					inf_close_stmt $stmt

				# so we have an ev_mkt_id and a pool id now, so we can do the update

				set sql "update tPoolMkt set \
						 ev_mkt_id = [ db_get_col $res7 0 ev_mkt_id ] \
						 where \
						 pool_mkt_id = $pmktid"
				set stmt [ inf_prep_sql $DB $sql ]
				set res8 [ inf_exec_stmt $stmt ]
				set rc8  [ inf_get_row_count $stmt ]
				inf_close_stmt $stmt

				if { $rc8 < 1 } {
					log 15 "Failed to update tPoolMkt for pool_mkt_id $pmktid and ev_mkt_id [db_get_col $res7 0 ev_mkt_id]"
					continue
				}
				unset res8 rc8
				# close the if branch, then the foreach
			}
		}

		catch { unset res8 rc8 }
		foreach item $mkt_list {
			set leg [ lrange [ split $item ,] 0 0]
			set pmktid [ lrange [ split $item ,] 1 1]

			set sql "update tPoolMkt set \
					 ev_mkt_id = $id($leg) \
					 where \
					 pool_mkt_id = $pmktid"
			set stmt [ inf_prep_sql $DB $sql ]
			set res8 [ inf_exec_stmt $stmt ]
			set rc8  [ inf_get_row_count $stmt ]
			inf_close_stmt $stmt

			if { $rc8 < 1 } {
				log 15 "Failed to update pool market $pmktid with ev_mkt_id $idx($leg)"
				continue
			}

		}

		log 15 "Finished updating pool markets"

		return 0

	}

	proc log {int msg} {
		OT_LogWrite $int $msg
	}

# close namespace
}

