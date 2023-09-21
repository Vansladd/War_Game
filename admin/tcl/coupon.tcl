# ==============================================================
# $Id: coupon.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1997 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::COUPON {

asSetAct ADMIN::COUPON::GoCoupon         [namespace code go_coupon]
asSetAct ADMIN::COUPON::DoCoupon         [namespace code do_coupon]
asSetAct ADMIN::COUPON::DoCouponMkts     [namespace code do_coupon_mkts]
asSetAct ADMIN::COUPON::GoCouponSelect   [namespace code go_coupon_select]
asSetAct ADMIN::COUPON::GoClassCoupon    [namespace code go_class_coupons]
asSetAct ADMIN::COUPON::GoCatCoupon      [namespace code go_cat_coupons]
asSetAct ADMIN::COUPON::GoMultiCatCoupon [namespace code go_multi_cat_coupons]

asSetAct ADMIN::COUPON::DoAutoUpdate      [namespace code do_auto_update]
asSetAct ADMIN::COUPON::GoAutoUpdate      [namespace code go_auto_update]

asSetAct ADMIN::COUPON::DoRemoveRow [namespace code do_remove_row]
asSetAct ADMIN::COUPON::DoAddRow    [namespace code do_add_row]

# Holds error messages for auto-updating coupons
variable AC_ERR

#
# ----------------------------------------------------------------------------
# Go to coupon page
# ----------------------------------------------------------------------------
#
proc go_coupon args {

	global TYPE EVENT MKT NUMBERGROUPS NUMBERSELS

	set class_id  [reqGetArg ClassId]
	set category  [reqGetArg Category]
	set coupon_id [reqGetArg CouponId]

	#this should be in config file - NOT hard coded
	set noSelsAllowed 5
	tpSetVar NumSelsAllowed $noSelsAllowed

	for {set i 0} {$i < $noSelsAllowed} {incr i} {
		set NUMBERSELS($i,num) [expr $i + 1]
	}

	tpBindVar SelNum NUMBERSELS num num_idx

	set is_BBuster [reqGetArg IsBBuster]
	if {$is_BBuster == "Y"} {
		tpSetVar ISBBUSTER "Y"
		tpBindString ISBBUSTER "Y"
		tpBindString CouponDesc [reqGetArg CouponDesc]
	}

	foreach {n v} $args {
		set $n $v
	}

	tpBindString ClassId $class_id
	tpBindString Category $category
	tpBindString FromClass [reqGetArg FromClass]
	set class_id_list $class_id

	set is_multi_cat 0
	set current_multi_cat ""

	# Get the class list for this category
	if {[OT_CfgGet FUNC_MULTI_CAT_COUPONS 0] && $category == "" && $class_id == ""} {

		set ret [_bind_multi_cat_list]

		set is_multi_cat 1
		set current_multi_cat [reqGetArg MultiCatCouponCat]
		if {$current_multi_cat == ""} {
			set current_multi_cat $ret
		}
		set class_id_list [_get_coupon_class_list $current_multi_cat]

	} elseif {[OT_CfgGet FUNC_CATEGORY_COUP 0] && $category != ""} {

		set class_id_list [_get_coupon_class_list $category]

	}

	if {[OT_CfgGet COUPON_SORTS ""] != ""} {
		set coupon_sorts [OT_CfgGet COUPON_SORTS]
	} else {
		set coupon_sorts "'','Standard', 'AH','Asian Handicap',\
						  'WH','Straight handicap', 'EC','Event coupon',\
						  'DC','Double Chance', 'MR','Win Draw Win',\
						  'hl','Hi-Lo coupon'"
		if {[OT_CfgGet COUPONS_EXTRA ""] != ""} {
			append coupon_sorts ", [OT_CfgGet COUPONS_EXTRA]"
		}
	}
	tpSetVar COUPON_SORTS $coupon_sorts

	if {$coupon_id == ""} {

		tpSetVar opAdd 1

		set channels   "-"
		set langs      ""
		set class_sort ""

		# This is probably zero because there are no classes in the
		# category selected when FUNC_CATEGORY_COUP is 1.
		if {[llength $class_id_list] > 0} {
			set sql [subst {
				select
					sort class_sort,
					channels,
					languages
				from
					tEvClass
				where
					ev_class_id in ($class_id_list)
			}]

			set stmt [inf_prep_sql $::DB $sql]
			set res  [inf_exec_stmt $stmt]
			inf_close_stmt $stmt
			if {([OT_CfgGet FUNC_CATEGORY_COUP 0] && $category != "") || $is_multi_cat == 1} {
				set channels -
			} else {
				set channels [db_get_col $res 0 channels]
			}
			set langs        [db_get_col $res 0 languages]
			set class_sort   [db_get_col $res 0 class_sort]
		}

		make_channel_binds "" $channels 0
		make_language_binds $langs - 1
		make_cpn_tag_binds  $class_sort

		if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
			make_view_binds "" - 0
			tpBindString lang_list "No Views Selected"
		}

		# It's a new coupon so it's not auto-updated
		tpBindString IsAutoUpdated "N"

	} else {

		tpBindString CouponId $coupon_id

		tpSetVar opAdd 0

		set class_join "tEvClass c"

		# If we have a category coupon and its just been insterted
		# then it will not be attached to any classes yet
		if {([OT_CfgGet FUNC_CATEGORY_COUP 0] && $category != "") || $is_multi_cat == 1} {
			set class_join "outer tEvClass c"
		}

		#
		# Get coupon information
		#
		set sql [subst {
			select
				p.coupon_id,
				p.ev_class_id,
				p.cr_date,
				p.displayed,
				p.disporder,
				p.desc,
				p.blurb,
				p.flags,
				p.sort,
				p.channels,
				p.languages,
				p.fastkey,
				c.name class_name,
				c.channels channel_mask,
				c.languages language_mask,
				c.sort class_sort
			from
				tCoupon p,
				$class_join
			where
				p.coupon_id = ? and
				p.ev_class_id = c.ev_class_id
		}]

		set stmt     [inf_prep_sql $::DB $sql]
		set res_coup [inf_exec_stmt $stmt $coupon_id]
		inf_close_stmt $stmt

		set channel_mask  [db_get_col $res_coup 0 channel_mask]
		set language_mask [db_get_col $res_coup 0 language_mask]

		# There is no lang, or channel in tEvCategory, so compensate here
		if {$channel_mask == ""} {
			set channel_mask -
		}

		tpBindString ClassName       [db_get_col $res_coup 0 class_name]
		tpBindString CouponDisplayed [db_get_col $res_coup 0 displayed]
		tpBindString CouponDisporder [db_get_col $res_coup 0 disporder]
		tpBindString CouponDesc      [db_get_col $res_coup 0 desc]
		tpBindString CouponSort      [db_get_col $res_coup 0 sort]
		tpBindString CouponBlurb     [db_get_col $res_coup 0 blurb]
		tpBindString CouponFastkey   [db_get_col $res_coup 0 fastkey]

		make_channel_binds  [db_get_col $res_coup 0 channels]  $channel_mask
		make_language_binds [db_get_col $res_coup 0 languages] -
		make_cpn_tag_binds  [db_get_col $res_coup 0 class_sort]\
			 [db_get_col $res_coup 0 flags]

		# Get the coupon's auto-update status
		set sql [subst {
			select
				c.auto_updated
			from
				tCoupon c
			where
				c.coupon_id = ?
		}]

		set stmt     [inf_prep_sql $::DB $sql]
		set res_auto [inf_exec_stmt $stmt $coupon_id]
		inf_close_stmt $stmt

		tpBindString IsAutoUpdated [db_get_col $res_auto 0 auto_updated]

		db_close $res_auto

		#need to bind up the sort so can test for BBuster
		set sort [db_get_col $res_coup 0 sort]
		if {$sort == "BB"} {
			tpSetVar ISBBUSTER "Y"
			tpBindString ISBBUSTER "Y"

			# if the type is a BBuster then need to get the extra info from
			# tBlockBuster

			set sql [subst {
				select
					b.max_sel_grp,
					b.bonus_1,
					b.bonus_2,
					b.bonus_3,
					b.bonus_4,
					b.bonus_5
				from
					tBlockBuster b
				where
					b.coupon_id = ?
			}]

			set stmt     [inf_prep_sql $::DB $sql]
			set res_bb [inf_exec_stmt $stmt $coupon_id]
			inf_close_stmt $stmt

			tpSetVar MaxNumSel [db_get_col $res_bb 0 max_sel_grp]
			tpBindString Bonus1 [db_get_col $res_bb 0 bonus_1]
			tpBindString Bonus2 [db_get_col $res_bb 0 bonus_2]
			tpBindString Bonus3 [db_get_col $res_bb 0 bonus_3]
			tpBindString Bonus4 [db_get_col $res_bb 0 bonus_4]
			tpBindString Bonus5 [db_get_col $res_bb 0 bonus_5]
		}

		if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
			#
			# Build up the View array
			#
			set sql [subst {
				select
					view
				from
					tView
				where
					id   = ?
				and sort = ?
			}]
			set stmt [inf_prep_sql $::DB $sql]
			set rs   [inf_exec_stmt $stmt $coupon_id COUPON]
			inf_close_stmt $stmt

			set view_list [list]

			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				lappend view_list [db_get_col $rs $i view]
			}

			make_view_binds $view_list -

			db_close $rs

			#
			# Build up a list of languages that will need to be translated
			# with the current view list
			#
			set sql [subst {
				select distinct
					name
				from
					tView c,
					tViewLang v,
					tLang l
				where
					c.view = v.view and
					v.lang = l.lang and
					c.id   = ? and
					c.sort = ?
			}]

			set stmt [inf_prep_sql $::DB $sql]
			set rs   [inf_exec_stmt $stmt $coupon_id COUPON]
			inf_close_stmt $stmt

			set lang_list [list]

			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				lappend lang_list [db_get_col $rs $i name]
			}

			if {[llength $lang_list] < 1} {
				set lang_list "No Views Selected"
			}

			tpBindString lang_list $lang_list

			db_close $rs
		}

		#
		# Get coupon markets
		#
		set sql {
			select
				t.name                type_name,
				t.disporder           type_order,
				t.ev_type_id,
				e.desc,
				e.start_time,
				e.ev_id,
				m.ev_mkt_id,
				m.disporder           mkt_order,
				m.sort                mkt_sort,
				m.ev_oc_grp_id,
				m.name                market_name,
				cm.displayed          flag,
				cm.grp_id             grp_id,
				ec.name               class_name,
				ec.category
			from
				tcoupon     c,
				tcouponmkt cm,
				tevmkt      m,
				tev         e,
				tevtype     t,
				tevclass    ec
			where
				c.coupon_id    = ?              and
				c.coupon_id    = cm.coupon_id   and
				cm.ev_mkt_id   = m.ev_mkt_id    and
				m.ev_id        = e.ev_id        and
				e.ev_type_id   = t.ev_type_id   and
				t.ev_class_id  = ec.ev_class_id
		}

		if {[llength $class_id_list] > 0} {
			append sql [subst {
				union
				select
					t.name                type_name,
					t.disporder           type_order,
					t.ev_type_id,
					e.desc,
					e.start_time,
					e.ev_id,
					m.ev_mkt_id,
					m.disporder           mkt_order,
					m.sort                mkt_sort,
					m.ev_oc_grp_id,
					m.name                market_name,
					'-'                   flag,
					-1                    grp_id,
					ec.name               class_name,
					ec.category
				from
					tEvUnstl    eu,
					tevtype     t,
					tevclass    ec,
					tev         e,
					tevmkt      m
				where
					eu.ev_class_id in ($class_id_list) and
					eu.ev_type_id  = t.ev_type_id   and
					eu.ev_id       = e.ev_id        and
					t.ev_class_id  = ec.ev_class_id and
					t.ev_type_id   = e.ev_type_id   and
					t.ev_class_id  = ec.ev_class_id and
					e.ev_id        = m.ev_id        and
					e.settled      = 'N'            and
					e.start_time   > CURRENT        and
					e.sort         = 'MTCH'         and
					e.ev_id        = m.ev_id        and
					m.ev_mkt_id not in (
						select ev_mkt_id from tcouponmkt where coupon_id = ?
					)
			}]
		}

		append sql {
			order by
				1, 2, 5, 6, 8, 7
		}

		set stmt   [inf_prep_sql $::DB $sql]
		set res_cm [inf_exec_stmt $stmt $coupon_id $coupon_id]
		set rows   [db_get_nrows $res_cm]

		set N_TYPE -1
		set N_EV   -1
		set N_MKT  -1
		set C_TYPE ""
		set C_EV   ""

		set max_mkt_length  0
		set TYPE(num_types) 0

		# Paramerers to track how many hilo markets are selected on this coupon.
		set AllHilo 1
		set NoHilo 1
		set mkt_sels_other_cats [list]

		for {set r 0} {$r < $rows} {incr r} {

			set ev_id    [db_get_col $res_cm $r ev_id]
			set grp_num_sel [db_get_col $res_cm $r grp_id]
			set mkt_id   [db_get_col $res_cm $r ev_mkt_id]
			set mkt_name [db_get_col $res_cm $r market_name]
			set mkt_sel  [db_get_col $res_cm $r flag]
			set mkt_sort [db_get_col $res_cm $r mkt_sort]
			set type     [db_get_col $res_cm $r type_name]
			set class    [db_get_col $res_cm $r class_name]
			set category [db_get_col $res_cm $r category]

			set desc [db_get_col $res_cm $r desc]

			if {$mkt_sel == "Y"} {
				set mkt_sel SELECTED
				# Checks for the asain hilo market
				if {$mkt_sort == "hl"} {
					set NoHilo 0
				} else {
					set AllHilo 0
				}
				if {$is_multi_cat} {
					if {$category != $current_multi_cat} {
						lappend mkt_sels_other_cats $mkt_id
						continue
					}
				}

			} else {
				set mkt_sel ""
			}

			if {$type != $C_TYPE} {
				set C_TYPE $type
				incr N_TYPE
				set TYPE($N_TYPE,type_name) $type
				set TYPE($N_TYPE,type_key)  $N_TYPE
				set TYPE($N_TYPE,ev_count)  0
				set C_EV ""
				set N_EV -1
				incr TYPE(num_types)
			}

			if {$desc != $C_EV} {
				set  C_EV $desc
				incr N_EV
				set N_MKT -1

				set start_time [db_get_col $res_cm $r start_time]

				set EVENT($N_TYPE,$N_EV,desc)      $desc
				set EVENT($N_TYPE,$N_EV,start)     $start_time
				set EVENT($N_TYPE,$N_EV,ev_id)     $ev_id
				set EVENT($N_TYPE,$N_EV,grp_num_sel)     $grp_num_sel
				set EVENT($N_TYPE,$N_EV,mkt_count) 0

				incr TYPE($N_TYPE,ev_count)

			} elseif {$grp_num_sel != -1} {
				set EVENT($N_TYPE,$N_EV,grp_num_sel) $grp_num_sel
			}

			incr N_MKT
			incr EVENT($N_TYPE,$N_EV,mkt_count)

			set MKT($N_TYPE,$N_EV,$N_MKT,mkt_id)   $mkt_id
			set MKT($N_TYPE,$N_EV,$N_MKT,mkt_name) $mkt_name
			set MKT($N_TYPE,$N_EV,$N_MKT,mkt_sel)  $mkt_sel

			if {[string length $mkt_name] > $max_mkt_length} {
				set max_mkt_length [string length $mkt_name]
			}
		}


		set num_types $TYPE(num_types)

		if {[expr $rows - [llength $mkt_sels_other_cats]] == 0 } {
            set num_events 0
        } else {
            set num_events $TYPE($N_TYPE,ev_count)
        }

		if {$sort == "BB"} {
			#this should be in config file - NOT hard coded
			set noGroupsAllowed 20
			tpSetVar NumGroupsAllowed $noGroupsAllowed

			for {set i 0} {$i < $noGroupsAllowed} {incr i} {
				set NUMBERGROUPS($i,num) [expr $i + 1]
			}

			tpBindVar GroupNum NUMBERGROUPS num num_idx
		}

		tpSetVar NumCoupTypes $TYPE(num_types)
		# Multiplication to (approx) turn char length into pixel width
		tpBindString MaxMktLength [expr $max_mkt_length * 7]

		tpBindVar CTypeName  TYPE  type_name  ctype_idx
		tpBindVar CClassName TYPE  class_name ctype_idx
		tpBindVar CEvStart   EVENT start      ctype_idx cev_idx
		tpBindVar CEvDesc    EVENT desc       ctype_idx cev_idx
		tpBindVar CEvId      EVENT ev_id      ctype_idx cev_idx
		tpBindVar GrpNumSel  EVENT grp_num_sel     ctype_idx cev_idx
		tpBindVar CMktId     MKT   mkt_id     ctype_idx cev_idx cmkt_idx
		tpBindVar CMktName   MKT   mkt_name   ctype_idx cev_idx cmkt_idx
		tpBindVar CMktSel    MKT   mkt_sel    ctype_idx cev_idx cmkt_idx

		tpBindString CNoHilo $NoHilo
		tpBindString CAllHilo $AllHilo
		tpBindString MktSelOtherCats [join $mkt_sels_other_cats ,]
		tpBindString MultiCatCouponCat $current_multi_cat


	}

	asPlayFile coupon.html

	if {$coupon_id != ""} {
		db_close $res_coup
		db_close $res_cm
	}

	catch {unset TYPE}
	catch {unset EVENT}
	catch {unset MKT}
}


#
# ----------------------------------------------------------------------------
# Add/Update coupon
# ----------------------------------------------------------------------------
#
proc do_coupon args {

	set act [reqGetArg SubmitName]

	if {$act == "CouponAdd"} {
		do_coupon_add
	} elseif {$act == "CouponMod"} {
		do_coupon_upd
	} elseif {$act == "CouponDel"} {
		do_coupon_del
	} elseif {$act == "Back"} {
		if {[reqGetArg FromClass] == 1} {
			ADMIN::CLASS::go_class
		} elseif {[reqGetArg Category] != ""} {
			go_cat_coupons
		} else {
			go_class_coupons
		}
	} elseif {$act == "AutoUpdate"} {
		go_auto_update
	} elseif {$act == "DoAutoUpdate"} {
		do_auto_update
	} elseif {$act == "RowAdd"} {
		do_add_row
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_coupon_add args {

	set class_id [reqGetArg ClassId]
	set category [reqGetArg Category]

	set cpn_tags ""

	if {$class_id != ""} {
		set cpn_tags [make_cpn_tag_str [get_class_sort $class_id]]
	}

	set sql [subst {
		execute procedure pInsCoupon(
			p_adminuser = ?,
			p_ev_class_id = ?,
			p_category = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_desc = ?,
			p_sort = ?,
			p_blurb = ?,
			p_channels = ?,
			p_fastkey = ?,
			p_languages = ?,
			p_flags = ?
		)
	}]


	set bad  0
	set stmt [inf_prep_sql $::DB $sql]

	if {[catch {

		inf_begin_tran $::DB

		set res [inf_exec_stmt $stmt\
			$::USERNAME\
			$class_id\
			$category\
			[reqGetArg CouponDisplayed]\
			[reqGetArg CouponDisporder]\
			[reqGetArg CouponDesc]\
			[reqGetArg CouponSort]\
			[reqGetArg CouponBlurb]\
			[make_channel_str]\
			[reqGetArg CouponFastkey]\
			[make_language_str]\
			$cpn_tags
			]

		inf_close_stmt $stmt

		if {[db_get_nrows $res] != 1} {
			err_bind "Failed to add coupon (no coupon_id retrieved)"
			set bad 1
		} else {
			set coupon_id [db_get_coln $res 0 0]
		}
		catch {db_close $res}

	} msg]} {
		set bad 1
		err_bind $msg
	}

	if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $bad == 0} {
		set upd_view [ADMIN::VIEWS::upd_view COUPON $coupon_id]
		if {[lindex $upd_view 0]} {
			err_bind [lindex $upd_view 1]
			set bad 1
		}
	}

	if {$bad} {
		#
		# Something went wrong
		#
		inf_rollback_tran $::DB

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar CouponAddFailed 1
		go_coupon
		return
	}

	inf_commit_tran $::DB
	msg_bind "successfully added coupon"

	#need to do extra stuff here to add block buster into tBlockBuster

	if {[reqGetArg CouponSort] == "BB" && $bad == 0} {

		set sql [subst {
			execute procedure pInsBlockBuster(
				p_coupon_id   = ?,
				p_max_sel_grp = ?,
				p_bonus_1     = ?,
				p_bonus_2     = ?,
				p_bonus_3     = ?,
				p_bonus_4     = ?,
				p_bonus_5     = ?
			)
		}]

		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {

			set res [inf_exec_stmt $stmt\
				$coupon_id\
				[reqGetArg SelNum]\
				[reqGetArg bonus1]\
				[reqGetArg bonus2]\
				[reqGetArg bonus3]\
				[reqGetArg bonus4]\
				[reqGetArg bonus5]
				]

			inf_close_stmt $stmt

			catch {db_close $res}

		} msg]} {
			err_bind $msg
		}

	}

	tpSetVar CouponAdded 1
	go_coupon coupon_id $coupon_id
}

proc do_coupon_upd args {

	set sql [subst {
		execute procedure pUpdCoupon(
			p_adminuser = ?,
			p_coupon_id = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_desc = ?,
			p_sort = ?,
			p_blurb = ?,
			p_channels = ?,
			p_fastkey = ?,
			p_languages = ?,
			p_flags = ?
		)
	}]

	# Error checking for asain hi-lo market. Don't let them set up invalid coupons.

	if {[reqGetArg CouponSort] == "hl"} {
		if {![reqGetArg AllHilo]} {
			err_bind "Cannot change coupon to sort hi-lo as it contains markets that are not hi-lo markets"
			go_coupon
			return
		}
	} else {
		if {![reqGetArg NoHilo]} {
			err_bind "Cannot change coupon sort away from hi-lo as it contains hi-lo markets"
			go_coupon
			return
		}
	}


	set bad 0
	set coupon_id [reqGetArg CouponId]
	set stmt [inf_prep_sql $::DB $sql]

	if {[catch {

		inf_begin_tran $::DB

		set cpn_tags ""
		set class_id [reqGetArg ClassId]

		if {$class_id != ""} {
			set cpn_tags [make_cpn_tag_str [get_class_sort $class_id]]
		}

		set res [inf_exec_stmt $stmt\
			$::USERNAME\
			[reqGetArg CouponId]\
			[reqGetArg CouponDisplayed]\
			[reqGetArg CouponDisporder]\
			[reqGetArg CouponDesc]\
			[reqGetArg CouponSort]\
			[reqGetArg CouponBlurb]\
			[make_channel_str]\
			[reqGetArg CouponFastkey]\
			[make_language_str]\
			$cpn_tags]

		inf_close_stmt $stmt
		catch {db_close $res}

	} msg]} {
		err_bind $msg
		set bad 1
	}

	# if its a BlockBuster then need to update in tBlockBuster as well

	if {[reqGetArg CouponSort] == "BB"} {

		set sql [subst {
		execute procedure pUpdBlockBuster(
			p_coupon_id    = ?,
			p_max_grps     = ?,
			p_bonus1       = ?,
			p_bonus2       = ?,
			p_bonus3       = ?,
			p_bonus4       = ?,
			p_bonus5       = ?
		)
		}]

		set bad 0
		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {

			set res [inf_exec_stmt $stmt\
				[reqGetArg CouponId]\
				[reqGetArg SelNum]\
				[reqGetArg bonus1]\
				[reqGetArg bonus2]\
				[reqGetArg bonus3]\
				[reqGetArg bonus4]\
				[reqGetArg bonus5]]

			inf_close_stmt $stmt
			catch {db_close $res}

		} msg]} {
			err_bind $msg
			go_coupon
			return
		}
	}

	# Update coupon views
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $bad !=1} {
		set upd_view [ADMIN::VIEWS::upd_view COUPON $coupon_id]
		if {[lindex $upd_view 0]} {
			err_bind [lindex $upd_view 1]
			set bad 1
		}
	}

	if {$bad} {
		#
		# Something went wrong
		#
		inf_rollback_tran $::DB

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_coupon
		return
	}

	inf_commit_tran $::DB

	msg_bind "Successfully updated coupon"

	tpSetVar CouponUpdated 1
	ADMIN::COUPON::go_coupon
}

proc do_coupon_del args {

	set sql [subst {
		execute procedure pDelCoupon(
			p_adminuser = ?,
			p_coupon_id = ?
		)
	}]

	set bad 0
	set stmt      [inf_prep_sql $::DB $sql]
	set coupon_id [reqGetArg CouponId]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$::USERNAME\
			$coupon_id]} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt
	catch {db_close $res}

	#
	# Delete views for Event Class
	#
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		set del_view [ADMIN::VIEWS::del_view COUPON $coupon_id]
		if {[lindex $del_view 0]} {
			err_bind [lindex $del_view 1]
			set bad 1
		}
	}

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_coupon
		return
	}

	if {[reqGetArg FromClass] == 1} {
		ADMIN::CLASS::go_class
	} elseif {[reqGetArg Category] != ""} {
		go_cat_coupons
	} else {
		go_class_coupons
	}
}


#
# ----------------------------------------------------------------------------
# Set coupon markets
# ----------------------------------------------------------------------------
#
proc do_coupon_mkts args {

	global DB USERNAME

	if {[reqGetArg SubmitName] == "Back"} {
		if {[reqGetArg FromClass] == 1} {
			ADMIN::CLASS::go_class
		} elseif {[reqGetArg Category] != ""} {
			go_cat_coupons
		} else {
			go_class_coupons
		}
		return
	}

	set mkt_id_list [list]

	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		set n [reqGetNthName $i]
		if {[string range $n 0 9] == "CouponMkt_"} {
			set mkt_id [reqGetNthVal $i]
			if {$mkt_id != "" && $mkt_id != "0"} {
				lappend mkt_id_list $mkt_id
			}
		}
	}
	if {[reqGetArg MktSelOtherCats] != ""} {
		set mkt_id_list [concat $mkt_id_list [split [reqGetArg MktSelOtherCats] ,]]
	}

	set grp_id_list [list]

	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		set n [reqGetNthName $i]
		if {[string range $n 0 11] == "GroupNumber_"} {
			set grp_id [reqGetNthVal $i]
			if {$grp_id != "" && $grp_id != "0"} {
				lappend grp_id_list $grp_id
			}
		}
	}

	OT_LogWrite 1 "do_mkts -> mkt_id_list = $mkt_id_list"
	OT_LogWrite 1 "do_mkts -> grp_id_list = $grp_id_list"

	# need to make sure the group ids are consectutive

	set grp_id_consec_list [list]

	foreach id $grp_id_list {

		set found [lsearch $grp_id_consec_list $id]

		if {$found == -1} {
			lappend grp_id_consec_list $id
		}
	}

	#now is a good time to check that the num groups * max sel < 25

	set max_sel [reqGetArg SelNum]
	set num_grp [llength $grp_id_consec_list]

	set perms 0

	if {$num_grp != 0} {
		set perms [expr $max_sel * $num_grp]
	}

	if {$perms > [OT_CfgGet BB_COUPON_MAX_PERMS 100]} {
		err_bind "Please check that (max number of selections * num groups) is lower than [OT_CfgGet BB_COUPON_MAX_PERMS 100]"
		go_coupon
		return
	}

	# The extra checks to cfg and admin op to override the check so that the customer can create coupons
	# that aren't intended for use on the sportsbook, they are intended for affiliates via
	# dbpublish.
	if {![OT_CfgGet COUPONS_ALLOW_UNLIMITED_SELNS 0] || ![op_allowed ManageAdvancedCoupon]} {

		if {[reqGetArg category] == "" && [reqGetArg ClassId] == "" && [OT_CfgGet FUNC_MULTI_CAT_COUPONS 0]} {
			set num_markets_allowed [OT_CfgGet COUPON_MULTI_CAT_NUM_MARKETS 100]
		} else {
			set num_markets_allowed [OT_CfgGet COUPON_NUM_MAX_MARKETS 25]
		}
		if {$perms > $num_markets_allowed} {
			err_bind "max perms $num_markets_allowed"
			go_coupon
			return
		}
	}

	OT_LogWrite 1 "do_mkts -> grp_id_consec_list = $grp_id_consec_list"

	# sort the list then replace the list entries in the original list with the
	# positions in the new list

	set grp_id_consec_list [lsort -integer $grp_id_consec_list]

	OT_LogWrite 1 "after sort -> grp_id_consec_list = $grp_id_consec_list"

	array set GRPID [list]
	set num_entries 0

	for {set i 0} {$i <[llength $grp_id_list]} {incr i} {

		set id [lindex $grp_id_list $i]

		set pos [lsearch $grp_id_consec_list $id]

		if {$pos != -1} {
			incr pos
			set GRPID(num,$i) $pos
			incr num_entries
		}
	}

	set orig_max_grp_id [lindex $grp_id_consec_list end]
	set grp_id_list [list]

	for {set i 0} {$i < $num_entries} {incr i} {
		lappend grp_id_list $GRPID(num,$i)
	}

	# check if we had to do some reorganising to fit the 'consecutive grp' requirement.
	set had_to_resort 0
	if {[lsearch $grp_id_list $orig_max_grp_id] == -1} {
		set had_to_resort 1
	}

	OT_LogWrite 1 "after replace -> grp_id_list = $grp_id_list"


	set coupon_id [reqGetArg CouponId]
	set class_id  [reqGetArg ClassId]

	# grab the coupon sort
	set sql [subst {
		select
			coupon_id,
			sort
		from
			tcoupon
		where
			coupon_id = $coupon_id
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res      [inf_exec_stmt $stmt]


	if {[set rows [db_get_nrows $res]] != 1} {
		error "more than one coupon for id $coupon_id"

	}
	set coupon_sort [db_get_col $res 0 sort]

	inf_close_stmt $stmt
	db_close $res

	if {[llength $mkt_id_list] > 0} {
		# Limit users who can create mismatched markets to those with training
		# to create coupons for the affiliates via dbpublish
		if {([OT_CfgGet COUPONS_ALLOW_MISMATCHED_MARKETS 0] == 0 || ![op_allowed ManageAdvancedCoupon])} {
			#
			# Check that all the markets specified have the same number
			# of selections
			#
			set sql [subst {
				select
					ev_mkt_id,
					count(*) num_selns
				from
					tevoc
				where
					ev_mkt_id in ([join $mkt_id_list ,])
				group by
					ev_mkt_id
			}]
			set stmt [inf_prep_sql $::DB $sql]
 			set res  [inf_exec_stmt $stmt]

			set ok 1

			if {[set rows [db_get_nrows $res]] > 1} {

				set r0 [db_get_col $res 0 num_selns]

				for {set r 1} {$r < $rows} {incr r} {
					set rn [db_get_col $res $r num_selns]

					if {$rn != $r0} {
						set ok 0
					}
				}
			}

			inf_close_stmt $stmt
			db_close $res

			if {$ok == 0} {
				err_bind "Markets within a coupon must have the same number of selections"
				go_coupon
				return
			}
		}

		set sql [subst {
			select
				ev_mkt_id,
				type
			from
				tevmkt
			where
				ev_mkt_id in ([join $mkt_id_list ,])
		}]

		set stmt     [inf_prep_sql $DB $sql]
		set res      [inf_exec_stmt $stmt]

		set all_hl 1
		set no_hl 1

		if {[set rows [db_get_nrows $res]] > 0} {

			for {set r 0} {$r < $rows} {incr r} {
				set type [db_get_col $res $r type]
				OT_LogWrite 5 "type $type"
				if {$type == "l"} {
					set no_hl 0
				} else {
					set all_hl 0
				}
			}
		}

		inf_close_stmt $stmt
		db_close $res

		if {$coupon_sort == "hl" && $all_hl == 0} {
			error "not all markets in this hi-lo coupon are of type hi-lo"
		} elseif {$coupon_sort != "hl" && $no_hl == 0} {
			error "you can only add hi-lo markets to a coupon of sort hi-lo"
		}
	}
	#
	# begin tran
	#    delete old ids
	#    insert all new ones
	# commit tran
	#
	set coupon_id [reqGetArg CouponId]
	set class_id  [reqGetArg ClassId]

	ob::log::write 1 "coupon_sort = $coupon_sort"
	# if its a BB coupon then need to check that each selected market has
	# a group

	set extra_entries ""

	if {$coupon_sort == "BB"} {
		if {[llength $mkt_id_list] != [llength $grp_id_list]} {
			err_bind "each market needs to be assigned to a group"
			go_coupon
			return
		}
	}

	inf_begin_tran $::DB

	if {[catch {

		set sql [subst {
			delete from
				tCouponMkt
			where
				coupon_id = $coupon_id
		}]

		set stmt [inf_prep_sql $::DB $sql]
		inf_exec_stmt $stmt
		inf_close_stmt $stmt

		set sql [subst {
			delete from
				tCouponLink
			where
				coupon_id = $coupon_id
		}]

		set stmt [inf_prep_sql $::DB $sql]
		inf_exec_stmt $stmt
		inf_close_stmt $stmt

		set sql [subst {
			execute procedure pInsCouponMkt(
				p_adminuser = ?,
				p_coupon_id = ?,
				p_ev_mkt_id = ?,
				p_displayed = ?,
				p_grp_id = ?,
				p_num_grp = ?
			)
		}]

		set stmt [inf_prep_sql $::DB $sql]

		set i 0
		foreach mkt $mkt_id_list {

			set grp_id ""
			if {$coupon_sort == "BB"} {
				set grp_id [lindex $grp_id_list $i]
			}

			set res [inf_exec_stmt $stmt\
				$::USERNAME\
				$coupon_id\
				$mkt\
				Y\
				$grp_id\
				$num_grp]

			catch {db_close $res}

			incr i
		}

		inf_close_stmt $stmt
	} msg]} {
		err_bind $msg
		inf_rollback_tran $::DB
	} else {
		inf_commit_tran $::DB
		set msg "Successfully updated coupon markets."
		if {$had_to_resort} {
			append msg " Some markets were assigned to different groups than those requested to ensure consecutiveness"
		}
		msg_bind $msg
	}

	go_coupon
}

proc make_cpn_tag_str {c_sort {prefix CPNTAG_}} {

	set res [list]

	foreach {t n} [ADMIN::MKTPROPS::class_flag $c_sort coupon-tags] {
		if {[reqGetArg ${prefix}$t] != ""} {
			lappend res $t
		}
	}
	return [join $res ,]
}

proc make_cpn_tag_binds {c_sort {str ""}} {

	global CPNTAG

	set tag_list [ADMIN::MKTPROPS::class_flag $c_sort coupon-tags]
	set tag_used [split $str ,]

	set i 0

	foreach {t n} $tag_list {
		set CPNTAG($i,code) $t
		set CPNTAG($i,name) $n

		if {[lsearch -exact $tag_used $t] >= 0} {
			set CPNTAG($i,selected) CHECKED
		} else {
			set CPNTAG($i,selected) ""
		}
		incr i
	}

	tpSetVar NumCpnTags $i

	tpBindVar CpnTagName CPNTAG name     cpn_tag_idx
	tpBindVar CpnTagCode CPNTAG code     cpn_tag_idx
	tpBindVar CpnTagSel  CPNTAG selected cpn_tag_idx
}

proc get_class_sort {class_id} {

	set sql {
		select
			sort
		from
			tEvClass
		where
			ev_class_id = ?
	}

	set stmt [inf_prep_sql $::DB $sql]
	if {[catch {
		set res [inf_exec_stmt $stmt $class_id]
	} msg]} {
		err_bind $msg
	}
	return [db_get_col $res 0 sort]
}

proc _get_coupon_class_list {category} {

	# Grab a list of all the class id's
	# for that category

	set sql {
		select
			ev_class_id
		from
			tevclass
		where
			status = 'A' and
			displayed = 'Y' and
			category = ?
	}

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt $category]
	inf_close_stmt $stmt

	set class_id_list [list]

	set nrows [db_get_nrows $res]
	for {set i 0} {$i < $nrows} {incr i} {
		lappend class_id_list [db_get_col $res $i ev_class_id]
	}

	db_close $res

	set class_id_list [join $class_id_list ,]

	return $class_id_list
}

proc go_coupon_select args {

	set sql [subst {
		select
			ev_class_id,
			name,
			category,
			disporder,
			displayed,
			status,
			channels,
			flags,
			fastkey,
			languages
		from
			tEvClass
		where
			status = 'A'
		order by
			displayed desc, disporder asc, name asc
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumRows $rows
	tpSetVar NumClasses $rows

	tpBindTcl Status    sb_res_data $res class_idx status
	tpBindTcl Displayed sb_res_data $res class_idx displayed
	tpBindTcl Disporder sb_res_data $res class_idx disporder
	tpBindTcl CatClass  sb_res_data $res class_idx category
	tpBindTcl ClassId   sb_res_data $res class_idx ev_class_id
	tpBindTcl ClassName sb_res_data $res class_idx name
	tpBindTcl Channels  sb_res_data $res class_idx channels
	tpBindTcl Flags     sb_res_data $res class_idx flags
	tpBindTcl Fastkey   sb_res_data $res class_idx fastkey
	tpBindTcl Languages sb_res_data $res class_idx languages

	set cat_sql {
		select
			category
		from
			tEvCategory
		where
			displayed = 'Y'
	}

	set cat_stmt [inf_prep_sql $::DB $cat_sql]
	set cat_res  [inf_exec_stmt $cat_stmt]
	inf_close_stmt $cat_stmt

	set rows [db_get_nrows $cat_res]

	tpSetVar NumCats $rows

	tpBindTcl Category sb_res_data $cat_res cat_idx category

	asPlayFile -nocache coupon_chooser.html

	db_close $res
	db_close $cat_res


}

proc go_coupon_list args {

	#
	# get coupon information
	#
	set sql [subst {
		select
			coupon_id,
			ev_class_id,
			displayed,
			desc,
			languages,
			languages,
			channels,
			fastkey
		from
			tCoupon
		where
			ev_class_id = ?
		order by
			coupon_id asc
	}]

	set stmt     [inf_prep_sql $::DB $sql]
	set res_coup [inf_exec_stmt $stmt $class_id]
	inf_close_stmt $stmt

	tpSetVar NumCoupons [db_get_nrows $res_coup]

	tpBindTcl CouponId       sb_res_data $res_coup coupon_idx coupon_id
	tpBindTcl CouponDesc     sb_res_data $res_coup coupon_idx desc
	tpBindTcl CouponDisp     sb_res_data $res_coup coupon_idx displayed
	tpBindTcl CouponChannels sb_res_data $res_coup coupon_idx channels
	tpBindTcl CouponFastkey  sb_res_data $res_coup coupon_idx fastkey
	tpBindTcl CouponLangs    sb_res_data $res_coup coupon_idx languages
}

# This may look a bit pointless but it allows us to re-use the code

# This way the same code and html files are used if we goto coupons
# via the coupons page or through the old event class way

proc go_class_coupons args {

	tpSetVar ClassId [reqGetArg ClassId]
	asPlayFile coupon_main_menu.html

}

proc go_cat_coupons args {

	tpSetVar Category [reqGetArg Category]
	asPlayFile coupon_main_menu.html

}



proc go_multi_cat_coupons args {

	tpSetVar Category ""
	tpSetVar ClassId ""
	asPlayFile coupon_main_menu.html

}



proc get_class_coupons {class_id {from_class 0}} {

	global COUPON

	set sql [subst {
		select
			coupon_id,
			ev_class_id,
			displayed,
			desc,
			languages,
			languages,
			channels,
			fastkey
		from
			tCoupon
		where
			ev_class_id = ?
		order by
			coupon_id asc
	}]

	set stmt     [inf_prep_sql $::DB $sql]
	set res_coup [inf_exec_stmt $stmt $class_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res_coup]
	tpSetVar NumCoupons $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c {coupon_id desc displayed channels fastkey languages} {
			set COUPON($i,$c) [db_get_col $res_coup $i $c]
		}
	}

	db_close $res_coup

	tpBindVar CouponId       COUPON coupon_id coupon_idx
	tpBindVar CouponDesc     COUPON desc coupon_idx
	tpBindVar CouponDisp     COUPON displayed coupon_idx
	tpBindVar CouponChannels COUPON channels coupon_idx
	tpBindVar CouponFastkey  COUPON fastkey coupon_idx
	tpBindVar CouponLangs    COUPON languages coupon_idx

	tpBindString ClassId   $class_id
	tpBindString FromClass $from_class

	# Need to use the version of play file that isn't compressed
	# if you are playing files within another one
	w__asPlayFile coupon_sub_menu.html

}

proc get_cat_coupons {category} {

	global COUPON

	set sql [subst {
		select
			coupon_id,
			ev_class_id,
			displayed,
			desc,
			languages,
			languages,
			channels,
			fastkey
		from
			tCoupon
		where
			category = ?
		order by
			coupon_id asc
	}]

	set stmt     [inf_prep_sql $::DB $sql]
	set res_coup [inf_exec_stmt $stmt $category]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res_coup]
	tpSetVar NumCoupons $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c {coupon_id desc displayed channels fastkey languages} {
			set COUPON($i,$c) [db_get_col $res_coup $i $c]
		}
	}

	db_close $res_coup

	tpBindVar CouponId       COUPON coupon_id coupon_idx
	tpBindVar CouponDesc     COUPON desc coupon_idx
	tpBindVar CouponDisp     COUPON displayed coupon_idx
	tpBindVar CouponChannels COUPON channels coupon_idx
	tpBindVar CouponFastkey  COUPON fastkey coupon_idx
	tpBindVar CouponLangs    COUPON languages coupon_idx

	tpBindString Category $category

	# Need to use the version of play file that isn't compressed
	# if you are playing files within another one
	w__asPlayFile coupon_sub_menu.html

}



# Shows the auto-update settings for a coupon
proc go_auto_update args {

	global DB MARKETS COUPON_ROWS

	set coupon_id [reqGetArg CouponId]

	# Get the coupon's auto-update status and sort
	set sql [subst {
		select
			c.auto_updated,
			c.sort
		from
			tCoupon c
		where
			c.coupon_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set rs   [inf_exec_stmt $stmt $coupon_id]
	inf_close_stmt $stmt

	set auto_updated [db_get_col $rs 0 auto_updated]
	tpBindString IsAutoUpdated $auto_updated

	# If sort is an empty string, assume the Standard sort
	set sort [db_get_col $rs 0 sort]
	if {[string length $sort] != 2} {
		set sort "--"
	}

	# If it's already set to be auto updated, fill in the fields already
	if {$auto_updated == "Y"} {
		set sql [subst {
			select
				a.auto_coupon_id,
				a.start_date,
				a.end_date,
				a.mkt_name
			from
				tAutoCouponSetup a
			where
				a.coupon_id = ?
		}]

		set stmt [inf_prep_sql $::DB $sql]
		set rs   [inf_exec_stmt $stmt $coupon_id]
		inf_close_stmt $stmt

		set auto_coupon_id [db_get_col $rs 0 auto_coupon_id]
		set mkt_name       [db_get_col $rs 0 mkt_name]

		tpBindString AutoUpdate_Start [db_get_col $rs 0 start_date]
		tpBindString AutoUpdate_End   [db_get_col $rs 0 end_date]
	} else {
		set auto_coupon_id -1

		tpBindString AutoUpdate_Start ""
		tpBindString AutoUpdate_End ""

		set mkt_name ""
	}

	tpBindString AutoCouponId $auto_coupon_id

	set market_categories [list]
	set market_classes    [list]
	set market_types      [list]

	# Market dropdown list
	if {$auto_updated == "Y"} {
		set sql [subst {
			select
				oc.name
			from
				tAutoCouponSource a,
				tEvOcGrp oc
			where
				a.auto_coupon_id = ? and
				a.level = 'T' and
				a.level_id = oc.ev_type_id and
				oc.sort = ?
			union
			select
				oc.name
			from
				tEvType t,
				tAutoCouponSource a,
				tEvOcGrp oc
			where
				a.auto_coupon_id = ? and
				a.level = 'C' and
				a.level_id = t.ev_class_id and
				t.ev_type_id = oc.ev_type_id and
				oc.sort = ?
			union
			select
				oc.name
			from
				tEvType t,
				tEvClass c,
				tEvCategory y,
				tAutoCouponSource a,
				tEvOcGrp oc
			where
				a.auto_coupon_id = ? and
				a.level = 'Y' and
				a.level_id = y.ev_category_id and
				y.category = c.category and
				c.ev_class_id = t.ev_class_id and
				t.ev_type_id = oc.ev_type_id and
				oc.sort = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $auto_coupon_id $sort $auto_coupon_id $sort $auto_coupon_id $sort]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]

	} else {
		set sql [subst {
			select
				oc.name
			from
				tEvType t,
				tEvClass c,
				tCoupon co,
				tEvOcGrp oc
			where
				co.coupon_id = ? and
				co.ev_class_id = c.ev_class_id and
				c.ev_class_id = t.ev_class_id and
				t.ev_type_id = oc.ev_type_id and
				oc.sort = ?
			union
			select
				oc.name
			from
				tEvType t,
				tEvClass c,
				tCoupon co,
				tEvOcGrp oc
			where
				co.coupon_id = ? and
				co.category = c.category and
				c.ev_class_id = t.ev_class_id and
				t.ev_type_id = oc.ev_type_id and
				oc.sort = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $coupon_id $sort $coupon_id $sort]

		set nrows [db_get_nrows $rs]
	}

	tpSetVar NumMarkets $nrows

	for {set i 0} {$i < $nrows} {incr i} {

		set market_name [db_get_col $rs $i name]
		set MARKETS($i,name) $market_name

		if {$market_name == $mkt_name} {
			set MARKETS($i,selected) "selected=true"
		} else {
			set MARKETS($i,selected) ""
		}
	}

	db_close $rs

	tpBindVar MarketName MARKETS name     market_idx
	tpBindVar Selected   MARKETS selected market_idx

	# Category/class/type table for the auto coupon
	if {$auto_updated == "Y"} {

		set sql [subst {
			select
				a.ac_source_id,
				a.level,
				a.level_id
			from
				tAutoCouponSource a
			where
				a.auto_coupon_id = ?
		}]

		set stmt     [inf_prep_sql $DB $sql]
		set res       [inf_exec_stmt $stmt $auto_coupon_id]
		inf_close_stmt $stmt

		set total_nrows [db_get_nrows $res]

		set coupon_classes ""
		set coupon_types ""

		for {set i 0} {$i < $total_nrows} {incr i} {

			set level        [db_get_col $res $i level]
			set level_id     [db_get_col $res $i level_id]

			set COUPON_ROWS($i,ac_source_id) [db_get_col $res $i ac_source_id]

			switch $level {
				Y {
					set sql [subst {
						select
							y.category
						from
							tEvCategory y
						where
							y.ev_category_id = ?
					}]

					set stmt     [inf_prep_sql $DB $sql]
					set rs       [inf_exec_stmt $stmt $level_id]
					inf_close_stmt $stmt

					set nrows [db_get_nrows $rs]
					if {$nrows != 1} {
						continue
					}

					set COUPON_ROWS($i,ev_category) [db_get_col $rs 0 category]
					set COUPON_ROWS($i,ev_class)    "ALL"
					set COUPON_ROWS($i,ev_class_id) -1
					set COUPON_ROWS($i,ev_type)     "ALL"
					set COUPON_ROWS($i,ev_type_id)  -1
				}
				C {
					set sql [subst {
						select
							y.category,
							y.ev_category_id,
							c.name as class_name,
							c.ev_class_id
						from
							tEvClass c,
							tEvCategory y
						where
							c.ev_class_id = ? and
							c.category = y.category
					}]

					set stmt     [inf_prep_sql $DB $sql]
					set rs       [inf_exec_stmt $stmt $level_id]
					inf_close_stmt $stmt

					set nrows [db_get_nrows $rs]
					if {$nrows != 1} {
						continue
					}

					set COUPON_ROWS($i,ev_category) [db_get_col $rs 0 category]
					set COUPON_ROWS($i,ev_class)    [db_get_col $rs 0 class_name]
					set COUPON_ROWS($i,ev_class_id) [db_get_col $rs 0 ev_class_id]
					set COUPON_ROWS($i,ev_type)     "ALL"
					set COUPON_ROWS($i,ev_type_id)  -1

					if {$coupon_classes == ""} {
						append coupon_classes "[db_get_col $rs 0 ev_category_id] [db_get_col $rs 0 class_name]"
					} else {
						append coupon_classes ",[db_get_col $rs 0 ev_category_id] [db_get_col $rs 0 class_name]"
					}
				}
				T {
					set sql [subst {
						select
							y.category,
							y.ev_category_id,
							c.name as class_name,
							c.ev_class_id,
							t.name as type_name,
							t.ev_type_id
						from
							tEvType t,
							tEvClass c,
							tEvCategory y
						where
							t.ev_type_id = ? and
							t.ev_class_id = c.ev_class_id and
							c.category = y.category
					}]

					set stmt     [inf_prep_sql $DB $sql]
					set rs       [inf_exec_stmt $stmt $level_id]
					inf_close_stmt $stmt

					set nrows [db_get_nrows $rs]
					if {$nrows != 1} {
						continue
					}

					set COUPON_ROWS($i,ev_category) [db_get_col $rs 0 category]
					set COUPON_ROWS($i,ev_class)    [db_get_col $rs 0 class_name]
					set COUPON_ROWS($i,ev_class_id) [db_get_col $rs 0 ev_class_id]
					set COUPON_ROWS($i,ev_type)     [db_get_col $rs 0 type_name]
					set COUPON_ROWS($i,ev_type_id)  [db_get_col $rs 0 ev_type_id]

					if {$coupon_types == ""} {
						append coupon_types "[db_get_col $rs 0 ev_category_id] [db_get_col $rs 0 ev_class_id] [db_get_col $rs 0 type_name]"
					} else {
						append coupon_types ",[db_get_col $rs 0 ev_category_id] [db_get_col $rs 0 ev_class_id] [db_get_col $rs 0 type_name]"
					}
				}
			}
		}

		db_close $res
		tpSetVar NumRows $total_nrows

		tpBindVar ACSourceId COUPON_ROWS ac_source_id classes_idx
		tpBindVar Category   COUPON_ROWS ev_category  classes_idx
		tpBindVar Class      COUPON_ROWS ev_class     classes_idx
		tpBindVar ClassId    COUPON_ROWS ev_class_id  classes_idx
		tpBindVar Type       COUPON_ROWS ev_type      classes_idx
		tpBindVar TypeId     COUPON_ROWS ev_type_id   classes_idx

		tpBindString CouponClasses $coupon_classes
		tpBindString CouponTypes $coupon_types
	}

	tpBindString CouponId       $coupon_id
	tpBindString CouponClassId  [reqGetArg ClassId]
	tpBindString CouponCategory [reqGetArg Category]
	tpBindString IsBBuster      [reqGetArg IsBBuster]
	tpBindString CouponDesc     [reqGetArg CouponDesc]

	asPlayFile coupon_auto_update.html
}



# Updates the auto-update settings for a coupon
proc do_auto_update args {

	global DB

	set error 0

	set start_date ""
	set end_date ""
	set market_name ""

	set coupon_id [reqGetArg CouponId]

	# Get the coupon's current auto-update status
	set sql [subst {
		select
			c.category,
			y.ev_category_id,
			c.ev_class_id,
			c.auto_updated
		from
			tCoupon c,
			outer tEvCategory y
		where
			c.coupon_id = ? and
			y.category = c.category
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $coupon_id]
	inf_close_stmt $stmt

	set curr_auto_updated [db_get_col $rs 0 auto_updated]
	set category          [db_get_col $rs 0 category]
	set category_id       [db_get_col $rs 0 ev_category_id]
	set class_id          [db_get_col $rs 0 ev_class_id]

	tpBindString CouponCategory $category

	# Now get the new auto-update status
	set new_auto_updated [reqGetArg auto_update]

	if {$new_auto_updated == "Y"} {
		set start_date  [reqGetArg start_date]
		set end_date    [reqGetArg end_date]
		set market_name [reqGetArg market_name]
	} elseif {$curr_auto_updated == "Y"} {
		set sql [subst {
			select
				a.start_date,
				a.end_date,
				a.mkt_name
			from
				tAutoCouponSetup a
			where
				a.coupon_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $coupon_id]
		inf_close_stmt $stmt

		set start_date  [db_get_col $rs 0 start_date]
		set end_date    [db_get_col $rs 0 end_date]
		set market_name [db_get_col $rs 0 mkt_name]
	}

	if {$new_auto_updated == "Y" && $market_name == ""} {
		err_bind "Error: must select a market name"
		go_auto_update
		return
	}

	# Start the transaction
	inf_begin_tran $DB

	# Set the new status in the DB
	set sql [subst {
		update
			tCoupon
		set
			auto_updated = ?
		where
			coupon_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set rs [inf_exec_stmt $stmt $new_auto_updated $coupon_id]} msg] {
		inf_rollback_tran $DB
		err_bind "Error updating coupon: $msg"
		set error 1
	}
	inf_close_stmt $stmt

	if {$curr_auto_updated == "N"} {
		if {$new_auto_updated == "Y"} {

			# Insert new row into tAutoCouponSetup
			set sql [subst {
				execute procedure pInsAutoCoupon(
					p_start_date = ?,
					p_end_date   = ?,
					p_mkt_name   = ?,
					p_coupon_id  = ?
				)
			}]

			set stmt [inf_prep_sql $DB $sql]
			if [catch {set rs [inf_exec_stmt $stmt $start_date $end_date $market_name $coupon_id]} msg] {
				inf_rollback_tran $DB
				err_bind "Error updating coupon: $msg"
				set error 1
			}
			inf_close_stmt $stmt

			if [catch {set auto_coupon_id [db_get_coln $rs 0 0]} msg] {
				inf_rollback_tran $DB
				err_bind "Error updating coupon: $msg"
				set error 1
			}

			# Add the coupon's default class or category in tAutoUpdateSource
			if {$category_id != "" } {
				set sql [subst {
					execute procedure pInsACSource(
						p_auto_coupon_id = ?,
						p_level          = "Y",
						p_level_id       = ?
					)
				}]

				set stmt [inf_prep_sql $DB $sql]
				if [catch {set rs [inf_exec_stmt $stmt $auto_coupon_id $category_id]} msg] {
					inf_rollback_tran $DB
					err_bind "Error updating coupon: $msg"
					set error 1
				}
			} elseif {$class_id != ""} {
				set sql [subst {
					execute procedure pInsACSource(
						p_auto_coupon_id = ?,
						p_level          = "C",
						p_level_id       = ?
					)
				}]

				set stmt [inf_prep_sql $DB $sql]
				if [catch {set rs [inf_exec_stmt $stmt $auto_coupon_id $class_id]} msg] {
					inf_rollback_tran $DB
					err_bind "Error updating coupon: $msg"
					set error 1
				}
			}

			inf_close_stmt $stmt
		}
	} elseif {$curr_auto_updated == "Y"} {

		# Get the auto coupon ID
		set sql [subst {
			select
				c.auto_coupon_id
			from
				tAutoCouponSetup c
			where
				c.coupon_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		if [catch {set rs [inf_exec_stmt $stmt $coupon_id]} msg] {
			inf_rollback_tran $DB
			err_bind "Error updating coupon: $msg"
			set error 1
		}
		inf_close_stmt $stmt

		if [catch {set auto_coupon_id [db_get_col $rs 0 auto_coupon_id]} msg] {
			inf_rollback_tran $DB
			err_bind "Error updating coupon: $msg"
			set error 1
		}

		if {$new_auto_updated == "Y"} {

			# Update all details from the form
			set sql [subst {
				update
					tAutoCouponSetup
				set
					start_date = ?,
					end_date = ?,
					mkt_name = ?
				where
					auto_coupon_id = ?
			}]

			set stmt [inf_prep_sql $DB $sql]
			if [catch {set rs [inf_exec_stmt $stmt $start_date $end_date $market_name $auto_coupon_id]} msg] {
				inf_rollback_tran $DB
				err_bind "Error updating coupon: $msg"
				set error 1
			}
			inf_close_stmt $stmt

		} elseif {$new_auto_updated == "N"} {

			# Delete from tAutoCouponSource and tAutoCouponSetup
			set sql [subst {
				execute procedure pDelAutoCoupon (
					p_auto_coupon_id = ?
				)
			}]

			set stmt [inf_prep_sql $DB $sql]
			if [catch {set rs [inf_exec_stmt $stmt $auto_coupon_id]} msg] {
				inf_rollback_tran $DB
				err_bind "Error updating coupon: $msg"
				set error 1
			}
			inf_close_stmt $stmt
		}
	}

	if {$error == 0} {
		# Commit transaction
		inf_commit_tran $DB
	}

	go_auto_update
}



# Removes an event type, class or category from an auto coupon.
proc do_remove_row args {

	global DB

	set ac_source_id   [reqGetArg ac_source_id]
	set category       [reqGetArg Category]
	set coupon_id      [reqGetArg CouponId]
	set auto_coupon_id [reqGetArg AutoCouponId]
	set class_id       [reqGetArg ClassId]

	set rows_sql {
		select
			count(*) as rows
		from
			tAutoCouponSource
		where
			auto_coupon_id = ?
	}

	set rows_stmt [inf_prep_sql $DB $rows_sql]
	set rows_rs   [inf_exec_stmt $rows_stmt $auto_coupon_id]

	set num_rows [db_get_col $rows_rs 0 rows]

	inf_close_stmt $rows_stmt

	if {$num_rows == 1} {
			ob::log::write 5 "Deleting row with ID $ac_source_id from \
						  tAutoCouponSource, tAutoCouponSetup.  Set \
						  auto_updated = N"

		# Delete from tAutoCouponSource
		set sql {
			execute procedure pDelAutoCoupon (
				p_auto_coupon_id = ?
			)
		}

		set sql2 {
			update
				tCoupon
			set
				auto_updated = 'N'
			where
				coupon_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set stmt2 [inf_prep_sql $DB $sql2]
		set rs   [inf_exec_stmt $stmt $auto_coupon_id]
		set rs2   [inf_exec_stmt $stmt2 $coupon_id]
		inf_close_stmt $stmt
		inf_close_stmt $stmt2

		tpBindString ClassId        $class_id
		tpBindString CouponCategory $category
		tpBindString CouponId       $coupon_id

		go_coupon args

	} else {

		ob::log::write 5 "Deleting row with ID $ac_source_id from \
						  tAutoCouponSource"

		set sql {
			delete from
				tAutoCouponSource
			where
				ac_source_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $ac_source_id]

		inf_close_stmt $stmt

		tpBindString ClassId        $class_id
		tpBindString CouponCategory $category
		go_auto_update
	}
}



# Adds an event type, class or category to an auto coupon.
proc do_add_row args {

	global DB

	set auto_coupon_id [reqGetArg AutoCouponId]
	set id             [reqGetArg Id]
	set level          [reqGetArg Level]

	if {$level != "TYPE" && $level != "CLASS" && $level != "CATEGORY"} {
		_ac_add_err "Invalid level" rowAdd
		go_auto_update
		return
	}

	# If an existing row is included in a row to be added, delete the existing row
	if {$level != "TYPE"} {
		set existing_ids [find_existing_rows $auto_coupon_id $id $level]
		if {$existing_ids != ""} {
			set sql {
				delete from
					tAutoCouponSource
				where
					ac_source_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]

			foreach existing_id [split $existing_ids] {
				inf_exec_stmt $stmt $existing_id
			}

			inf_close_stmt $stmt
		}
	}

	switch $level {
		CATEGORY {
			# Check category doesn't already exist in table
			set sql {
				select
					y.category
				from
					tAutoCouponSource a,
					tEvCategory y
				where
					a.auto_coupon_id = ? and
					a.level = 'Y' and
					a.level_id = ? and
					y.ev_category_id = a.level_id
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $auto_coupon_id $id]

			if {[db_get_nrows $rs] > 0} {
				_ac_add_err "The category [db_get_col $rs 0 category] is already selected to be auto-updated." rowAdd
				go_auto_update
				return
			}

			db_close $rs
			inf_close_stmt $stmt

			set sql {
				execute procedure pInsACSource (
					p_auto_coupon_id = ?,
					p_level          = "Y",
					p_level_id       = ?
				)
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $auto_coupon_id $id]
		}
		CLASS {
			# Check class doesn't already exist in table
			set sql {
				select
					c.name
				from
					tAutoCouponSource a,
					tEvClass c
				where
					a.auto_coupon_id = ? and
					a.level = 'C' and
					a.level_id = ? and
					a.level_id = c.ev_class_id
				union
				select
					c.name
				from
					tAutoCouponSource a,
					tEvClass c,
					tEvCategory y
				where
					a.auto_coupon_id = ? and
					a.level = 'Y' and
					a.level_id = y.ev_category_id and
					y.category = c.category and
					c.ev_class_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $auto_coupon_id $id $auto_coupon_id $id]

			if {[db_get_nrows $rs] > 0} {
				_ac_add_err "The class [db_get_col $rs 0 name] is already selected to be auto-updated." rowAdd
				go_auto_update
				return
			}

			db_close $rs
			inf_close_stmt $stmt

			set sql {
				execute procedure pInsACSource (
					p_auto_coupon_id = ?,
					p_level          = "C",
					p_level_id       = ?
				)
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $auto_coupon_id $id]
		}
		TYPE {
			# Check type doesn't already exist in table
			set sql {
				select
					t.name
				from
					tAutoCouponSource a,
					tEvType t
				where
					a.auto_coupon_id = ? and
					a.level = 'T' and
					a.level_id = ? and
					a.level_id = t.ev_type_id
				union
				select
					t.name
				from
					tAutoCouponSource a,
					tEvType t,
					tEvClass c
				where
					a.auto_coupon_id = ? and
					a.level = 'C' and
					a.level_id = c.ev_class_id and
					c.ev_class_id = t.ev_class_id and
					t.ev_type_id = ?
				union
				select
					t.name
				from
					tAutoCouponSource a,
					tEvType t,
					tEvClass c,
					tEvCategory y
				where
					a.auto_coupon_id = ? and
					a.level = 'Y' and
					a.level_id = y.ev_category_id and
					y.category = c.category and
					c.ev_class_id = t.ev_class_id and
					t.ev_type_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $auto_coupon_id $id $auto_coupon_id $id $auto_coupon_id $id]

			if {[db_get_nrows $rs] > 0} {
				_ac_add_err "The type [db_get_col $rs 0 name] is already selected to be auto-updated." rowAdd
				go_auto_update
				return
			}

			db_close $rs
			inf_close_stmt $stmt

			set sql {
				execute procedure pInsACSource (
					p_auto_coupon_id = ?,
					p_level          = "T",
					p_level_id       = ?
				)
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $auto_coupon_id $id]
		}
	}

	inf_close_stmt $stmt

	go_auto_update
}



# Checks if a row is already included in the auto-updates for a coupon.
# Returns empty string if not; otherwise returns a list of IDs for all the rows
# that would be duplicated if the new row is added.
proc find_existing_rows {auto_coupon_id id level} {

	global DB

	set existing_ids ""

	switch $level {
		CATEGORY {
			# Check classes or types of this category don't already exist in table
			set sql {
				select
					a.ac_source_id
				from
					tEvClass c,
					tEvCategory y,
					tAutoCouponSource a
				where
					a.auto_coupon_id = ? and
					a.level = 'C' and
					c.ev_class_id = a.level_id and
					c.category = y.category and
					y.ev_category_id = ?
				union
				select
					a.ac_source_id
				from
					tEvType t,
					tEvClass c,
					tEvCategory y,
					tAutoCouponSource a
				where
					a.auto_coupon_id = ? and
					a.level = 'T' and
					t.ev_type_id = a.level_id and
					c.ev_class_id = t.ev_class_id and
					c.category = y.category and
					y.ev_category_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $auto_coupon_id $id $auto_coupon_id $id]

			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				append existing_ids "[db_get_col $rs $i ac_source_id]"
			}
		}
		CLASS {
			# Check types of this class don't already exist in table
			set sql {
				select
					a.ac_source_id
				from
					tEvType t,
					tAutoCouponSource a
				where
					a.auto_coupon_id = ? and
					a.level = 'T' and
					t.ev_type_id = a.level_id and
					t.ev_class_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs   [inf_exec_stmt $stmt $auto_coupon_id $id]

			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				append existing_ids "[db_get_col $rs $i ac_source_id]"
			}
		}
	}

	catch {
		db_close $rs
		inf_close_stmt $stmt
	}

	return $existing_ids
}



proc print_level {rs row col} {

	if {[db_get_col $rs [tpGetVar $row] type] == "T"} {
		tpSetVar show_link 0
		tpBufWrite TYPE
	} elseif {[db_get_col $rs [tpGetVar $row] type] == "CL"} {
		tpSetVar show_link 1
		tpBufWrite CLASS
	}
}



# Adds a message to the internal error list for auto-updating coupons.
proc _ac_add_err {msg action} {

	variable AC_ERR

	GC::mark ADMIN::COUPON::AC_ERR

	if {![info exists AC_ERR($action)]} {
		set AC_ERR($action) [list]
	}

	lappend AC_ERR($action) $msg
}



# Returns the total number of error messages added for the given action.
proc _ac_get_total {action}  {

	variable AC_ERR

	GC::mark ADMIN::COUPON::AC_ERR

	if {[info exists AC_ERR($action)]} {
		return [llength $AC_ERR($action)]
	}

	return 0
}



# Gets all the error messages added for the given action, separated by <br> by
# default.
proc _ac_get {action {sep "<br>"}} {

	variable AC_ERR

	GC::mark ADMIN::COUPON::AC_ERR

	if {[info exists AC_ERR($action)]} {
		return [join $AC_ERR($action) $sep]
	}

	return [list]
}



proc get_multi_cat_coupons args {

	global COUPON

	set sql [subst {
		select
			coupon_id,
			ev_class_id,
			displayed,
			desc,
			languages,
			languages,
			channels,
			fastkey
		from
			tCoupon
		where
			category    is null and
			ev_class_id is null
		order by
			coupon_id asc
	}]

	set stmt     [inf_prep_sql $::DB $sql]
	set res_coup [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res_coup]
	tpSetVar NumCoupons $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c {coupon_id desc displayed channels fastkey languages} {
			set COUPON($i,$c) [db_get_col $res_coup $i $c]
		}
	}

	db_close $res_coup

	tpBindVar CouponId       COUPON coupon_id coupon_idx
	tpBindVar CouponDesc     COUPON desc coupon_idx
	tpBindVar CouponDisp     COUPON displayed coupon_idx
	tpBindVar CouponChannels COUPON channels coupon_idx
	tpBindVar CouponFastkey  COUPON fastkey coupon_idx
	tpBindVar CouponLangs    COUPON languages coupon_idx

	tpBindString Category ""
	tpBindString ClassId  ""

	# Need to use the version of play file that isn't compressed
	# if you are playing files within another one

	w__asPlayFile coupon_sub_menu.html

}

proc _bind_multi_cat_list args {

	global COUPON

	set sql {
		select
			category
		from
			tEvCategory
		where
			displayed = 'Y'
		order by disporder asc
	}

	set stmt     [inf_prep_sql $::DB $sql]
	set res_coup [inf_exec_stmt $stmt]
	set nrows [db_get_nrows $res_coup]

	set default_val ""

	for {set i 0} {$i < $nrows} {incr i} {
		if {$default_val == ""} {
			set default_val [db_get_col $res_coup $i category]
		}
		set COUPON($i,cat_list) [db_get_col $res_coup $i category]
	}

	tpBindVar MultiCouponCats COUPON cat_list multi_coupon_cats_idx

	tpSetVar NumMultiCouponCats $nrows


	return $default_val

}

}
