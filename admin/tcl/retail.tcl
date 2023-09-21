# ==============================================================
# $Id: retail.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# This file handles requests for selecting, adding and updating shops and districts
#

namespace eval ADMIN::RETAIL {

asSetAct ADMIN::RETAIL::GoRetailSearch   [namespace code go_retail_search]
asSetAct ADMIN::RETAIL::GoShop           [namespace code go_shop]
asSetAct ADMIN::RETAIL::GoAddShop        [namespace code go_add_shop]
asSetAct ADMIN::RETAIL::DoUpdateShop     [namespace code do_update_shop]
asSetAct ADMIN::RETAIL::DoAddShop        [namespace code do_add_shop]
asSetAct ADMIN::RETAIL::GoDistrict       [namespace code go_district]
asSetAct ADMIN::RETAIL::GoAddDistrict    [namespace code go_add_district]
asSetAct ADMIN::RETAIL::DoUpdateDistrict [namespace code do_update_district]
asSetAct ADMIN::RETAIL::DoDeleteDistrict [namespace code do_delete_district]
asSetAct ADMIN::RETAIL::DoAddDistrict    [namespace code do_add_district]

}

#
# ----------------------------------------------------------------------------
# Play the search screen for shops and districts
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::go_retail_search args {
	asPlayFile -nocache retail_search.html
}

#
# ----------------------------------------------------------------------------
# Play the shop screen with details populated from a single shop
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::go_shop args {

	global DB

	set shop_no [reqGetArg ShopNumber]

	#
	# load shop details
	#
	set stmt [inf_prep_sql $DB {
		select
			s.shop_name,
			s.addr_line_1,
			s.addr_line_2,
			s.addr_line_3,
			s.addr_postcode,
			s.telephone,
			s.short_dial,
			d.district_no,
			d.district_manager
		from
			tRetailShop s,
			tRetailDistrict d
		where
			s.district_id = d.district_id
		and
			shop_no = ?
	}]

	set rs [inf_exec_stmt $stmt $shop_no]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 1} {
		tpBindString ShopNumber      $shop_no
		tpBindString ShopName        [db_get_col $rs 0 shop_name]
		tpBindString AddrLine1       [db_get_col $rs 0 addr_line_1]
		tpBindString AddrLine2       [db_get_col $rs 0 addr_line_2]
		tpBindString AddrLine3       [db_get_col $rs 0 addr_line_3]
		tpBindString AddrPostcode    [db_get_col $rs 0 addr_postcode]
		tpBindString Telephone       [db_get_col $rs 0 telephone]
		tpBindString ShortDial       [db_get_col $rs 0 short_dial]
		tpBindString DistrictNo      [db_get_col $rs 0 district_no]
		tpBindString DistrictManager [db_get_col $rs 0 district_manager]
		db_close $rs
		tpSetVar AllowAction "UPDATING"
		asPlayFile -nocache shop.html
	} else {
		db_close $rs
		err_bind "Shop does not exist"
		asPlayFile -nocache retail_search.html
	}
}

#
# ----------------------------------------------------------------------------
# Play the shop screen with no details populated
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::go_add_shop args {
	tpBindString DistrictNo [reqGetArg DistrictNo]
	tpSetVar AllowAction "ADDING"
	asPlayFile -nocache shop.html
}

#
# ----------------------------------------------------------------------------
# Update a shop with new details
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::do_update_shop args {

	global DB

	set shop_no          [reqGetArg ShopNumber]
	set shop_name        [reqGetArg ShopName]
	set addr_line_1      [reqGetArg AddrLine1]
	set addr_line_2      [reqGetArg AddrLine2]
	set addr_line_3      [reqGetArg AddrLine3]
	set addr_postcode    [reqGetArg AddrPostcode]
	set telephone        [reqGetArg Telephone]
	set short_dial       [reqGetArg ShortDial]
	set district_no      [reqGetArg DistrictNo]
	set district_manager [reqGetArg DistrictManager]

	tpBindString ShopNumber   $shop_no
	tpBindString ShopName     $shop_name
	tpBindString AddrLine1    $addr_line_1
	tpBindString AddrLine2    $addr_line_2
	tpBindString AddrLine3    $addr_line_3
	tpBindString AddrPostcode $addr_postcode
	tpBindString Telephone    $telephone
	tpBindString ShortDial    $short_dial
	tpBindString DistrictNo   $district_no
	tpBindString DistrictManager $district_manager

	tpSetVar AllowAction "UPDATING"
	tpSetVar PreviousAction "UPDATE"

	#
	# get the district id
	#
	set stmt [inf_prep_sql $DB {
		select
			district_id
		from
			tRetailDistrict
		where
			district_no = ?
	}]

	set rs [inf_exec_stmt $stmt $district_no]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		err_bind "District $district_no does not exist"
		asPlayFile -nocache shop.html
		return
	}

	set district_id [db_get_col $rs 0 district_id]
	db_close $rs

	#
	# update shop details
	#
	set stmt [inf_prep_sql $DB {
		update
			tRetailShop
		set
			shop_name     = ?,
			addr_line_1   = ?,
			addr_line_2   = ?,
			addr_line_3   = ?,
			addr_postcode = ?,
			telephone     = ?,
			short_dial    = ?,
			district_id   = ?
		where
			shop_no = ?
	}]

	set sql_err [catch {
		set rs [inf_exec_stmt $stmt $shop_name $addr_line_1 $addr_line_2 $addr_line_3 $addr_postcode $telephone $short_dial $district_id $shop_no]
	} msg]

	inf_close_stmt $stmt

	if {$sql_err == 0} {
		db_close $rs
		msg_bind "Shop updated"
	} else {
		err_bind "Failed to update shop: $msg"
	}

	asPlayFile -nocache shop.html
}

#
# ----------------------------------------------------------------------------
# Add a new shop
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::do_add_shop args {

	global DB

	set shop_no       [reqGetArg ShopNumber]
	set shop_name     [reqGetArg ShopName]
	set addr_line_1   [reqGetArg AddrLine1]
	set addr_line_2   [reqGetArg AddrLine2]
	set addr_line_3   [reqGetArg AddrLine3]
	set addr_postcode [reqGetArg AddrPostcode]
	set telephone     [reqGetArg Telephone]
	set short_dial    [reqGetArg ShortDial]
	set district_no   [reqGetArg DistrictNo]

	tpBindString ShopNumber      $shop_no
	tpBindString ShopName        $shop_name
	tpBindString AddrLine1       $addr_line_1
	tpBindString AddrLine2       $addr_line_2
	tpBindString AddrLine3       $addr_line_3
	tpBindString AddrPostcode    $addr_postcode
	tpBindString Telephone       $telephone
	tpBindString ShortDial       $short_dial
	tpBindString DistrictNo      $district_no

	tpSetVar PreviousAction "UPDATE"

	#
	# check that district exists, and get manager name
	#
	set stmt [inf_prep_sql $DB {
		select
			district_id,
			district_manager
		from
			tRetailDistrict
		where
			district_no = ?
	}]

	set rs [inf_exec_stmt $stmt $district_no]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		tpSetVar AllowAction "ADDING"
		err_bind "District does not exist"
		asPlayFile -nocache shop.html
		return
	}

	set district_id      [db_get_col $rs 0 district_id]
	set district_manager [db_get_col $rs 0 district_manager]
	db_close $rs

	#
	# insert shop details
	#
	set stmt [inf_prep_sql $DB {
		insert into tRetailShop (
			shop_no, shop_name, addr_line_1, addr_line_2, addr_line_3, addr_postcode, telephone, short_dial, district_id
		) values (
			?, ?, ?, ?, ?, ?, ?, ?, ?
		);
	}]

	tb_db::tb_begin_tran

	set sql_err [catch {
		set rs [inf_exec_stmt $stmt $shop_no $shop_name $addr_line_1 $addr_line_2 $addr_line_3 $addr_postcode $telephone $short_dial $district_id]
		set shop_id [inf_get_serial $stmt]
	} msg]

	inf_close_stmt $stmt

	if {$sql_err == 0} {
		db_close $rs

		set success [ADMIN::RETAIL::_create_fielding_accounts $shop_id $shop_no]

		if {$success} {
			tb_db::tb_commit_tran

			tpBindString DistrictManager $district_manager

			tpSetVar AllowAction "UPDATING"
			msg_bind "Shop added"
			asPlayFile -nocache shop.html
			return;
		} else {
			set msg "Failed to create the shop fielding accounts"
		}
	}

	tb_db::tb_rollback_tran
	tpSetVar AllowAction "ADDING"
	err_bind "Failed to add shop: $msg"
	asPlayFile -nocache shop.html
}

#
# ----------------------------------------------------------------------------
# Play the district screen with details populated from a single district
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::go_district args {

	global DB SHOPS

	set district_no [reqGetArg DistrictNo]

	#
	# load district details
	#
	set stmt [inf_prep_sql $DB {
		select
			district_id,
			district_manager,
			geographic_region,
			area_code
		from
			tRetailDistrict
		where
			district_no = ?
	}]

	set rs [inf_exec_stmt $stmt $district_no]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		err_bind "District does not exist"
		asPlayFile -nocache retail_search.html
		return
	}

	set district_id [db_get_col $rs 0 district_id]

	tpBindString DistrictNo          $district_no
	tpBindString DistrictManager     [db_get_col $rs 0 district_manager]
	tpBindString GeographicRegion    [db_get_col $rs 0 geographic_region]
	tpBindString AreaCode            [db_get_col $rs 0 area_code]
	db_close $rs

	#
	# load shop details for district
	#
	set stmt [inf_prep_sql $DB {
		select
			shop_no,
			shop_name,
			telephone
		from
			tRetailShop
		where
			district_id = ?
		order by
			shop_no
	}]

	set rs [inf_exec_stmt $stmt $district_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	tpSetVar shop_rows $nrows

	array set SHOPS [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set SHOPS($i,shop_no)   [db_get_col $rs $i shop_no]
		set SHOPS($i,shop_name) [db_get_col $rs $i shop_name]
		set SHOPS($i,telephone) [db_get_col $rs $i telephone]
	}

	db_close $rs

	tpBindVar ShopNumber SHOPS shop_no   shop_idx
	tpBindVar ShopName   SHOPS shop_name shop_idx
	tpBindVar Telephone  SHOPS telephone shop_idx

	tpSetVar AllowAction "UPDATING"
	asPlayFile -nocache district.html
}

#
# ----------------------------------------------------------------------------
# Play the district screen with no details populated
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::go_add_district args {
	tpSetVar AllowAction "ADDING"
	asPlayFile -nocache district.html
}

#
# ----------------------------------------------------------------------------
# Update a district with new details
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::do_update_district args {

	global DB

	set district_no       [reqGetArg DistrictNo]
	set district_manager  [reqGetArg DistrictManager]
	set geographic_region [reqGetArg GeographicRegion]
	set area_code         [reqGetArg AreaCode]

	tpBindString DistrictNo       $district_no
	tpBindString DistrictManager  $district_manager
	tpBindString GeographicRegion $geographic_region
	tpBindString AreaCode         $area_code

	tpSetVar AllowAction "UPDATING"
	tpSetVar PreviousAction "UPDATE"

	#
	# update district details
	#
	set stmt [inf_prep_sql $DB {
		update
			tRetailDistrict
		set
			district_manager  = ?,
			geographic_region = ?,
			area_code         = ?
		where
			district_no = ?
	}]

	set sql_err [catch {
		set rs [inf_exec_stmt $stmt $district_manager $geographic_region $area_code $district_no]
	}]

	inf_close_stmt $stmt

	if {$sql_err == 0} {
		db_close $rs
		msg_bind "District updated"
	} else {
		err_bind "Failed to update district"
	}

	asPlayFile -nocache district.html
}

#
# ----------------------------------------------------------------------------
# Delete a district - can only be called when no shops are attached to it
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::do_delete_district args {

	global DB

	set district_no       [reqGetArg DistrictNo]

	#
	# delete district
	#
	set stmt [inf_prep_sql $DB {
		delete from
			tRetailDistrict
		where
			district_no  = ?
	}]

	set sql_err [catch {
		set rs [inf_exec_stmt $stmt $district_no]
	}]

	inf_close_stmt $stmt

	if {$sql_err == 0} {
		db_close $rs
		msg_bind "District deleted"
		asPlayFile -nocache retail_search.html
	} else {
		err_bind "Failed to delete district"
		tpSetVar PreviousAction "UPDATE"
		go_district
	}
}

#
# ----------------------------------------------------------------------------
# Add a new district
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::do_add_district args {

	global DB

	set district_no       [reqGetArg DistrictNo]
	set district_manager  [reqGetArg DistrictManager]
	set geographic_region [reqGetArg GeographicRegion]
	set area_code         [reqGetArg AreaCode]

	tpBindString DistrictNo       $district_no
	tpBindString DistrictManager  $district_manager
	tpBindString GeographicRegion $geographic_region
	tpBindString AreaCode         $area_code

	tpSetVar PreviousAction "UPDATE"

	#
	# add district details
	#
	set stmt [inf_prep_sql $DB {
		insert into tRetailDistrict (
			district_no, district_manager, geographic_region, area_code
		) values (
			?, ?, ?, ?
		);
	}]

	set sql_err [catch {
		set rs [inf_exec_stmt $stmt $district_no $district_manager $geographic_region $area_code]
	}]

	inf_close_stmt $stmt

	if {$sql_err == 0} {
		db_close $rs
		tpSetVar AllowAction "UPDATING"
		msg_bind "District added"
	} else {
		tpSetVar AllowAction "ADDING"
		err_bind "Failed to add district"
	}

	asPlayFile -nocache district.html
}

#
# ----------------------------------------------------------------------------
# Bind up an array of all shop details
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::bind_all_shop_details args {

	global DB ALL_SHOPS

	#
	# bind all shop numbers into an array
	#
	set stmt [inf_prep_sql $DB {
		select
			s.shop_no,
			s.shop_name,
			d.district_no
		from
			tRetailShop s,
			tRetailDistrict d
		where
			s.district_id = d.district_id
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	tpBindString total_shops $nrows

	array set ALL_SHOPS [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set ALL_SHOPS($i,shop_idx)  $i
		set ALL_SHOPS($i,shop_no)     [db_get_col $rs $i shop_no]
		set ALL_SHOPS($i,shop_name)   [db_get_col $rs $i shop_name]
		set ALL_SHOPS($i,district_no) [db_get_col $rs $i district_no]
	}

	db_close $rs

	tpBindVar ShopIndexVar      ALL_SHOPS shop_idx    shop_idx
	tpBindVar ShopNumberVar     ALL_SHOPS shop_no     shop_idx
	tpBindVar ShopNameVar       ALL_SHOPS shop_name   shop_idx
	tpBindVar DistrictNumberVar ALL_SHOPS district_no shop_idx
}

#
# ----------------------------------------------------------------------------
# Upon creation of a new shop this proc is called to create the standard fielding accounts
# ----------------------------------------------------------------------------
#
proc ADMIN::RETAIL::_create_fielding_accounts {shop_id shop_no} {

	global DB

	#
	# get the channel for shop fielding accounts
	#
	set stmt [inf_prep_sql $DB {
		select
			channel_id
		from
			tchangrplink
		where
			channel_grp = 'SHFL';
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		err_bind "No channel/group defined for Shop Fielding accounts, no accounts were created."
		return
	}

	set channel [db_get_col $rs 0 channel_id]
	db_close $rs

	reqSetArg source $channel
	#set CUSTDETAIL(reg_combi)       [reqGetArg reg_combi]
	reqSetArg acct_owner "F"

	reqSetArg gen_acct_no_on_reg "N"

	#set CUSTDETAIL(currency_code)   [encoding convertfrom $CHARSET [reqGetArg currency_code]]
	reqSetArg acct_type "CDT"

	reqSetArg over18 "Y"
	reqSetArg read_rules "Y"

	reqSetArg card_required "N"

	reqSetArg ignore_mand "Y"

	reqSetArg price_type "ODDS"
	reqSetArg min_repay "0.00"
	reqSetArg min_funds "0.00"
	reqSetArg min_settle "0.00"
	reqSetArg credit_limit [OT_CfgGet SHOP_FIELDING_CRED_LIMIT "9999999999.99"]
	reqSetArg pay_pct "100"
	reqSetArg settle_type "N"

	reqSetArg cust_sort "R"

	foreach f {elite ap_on tax_on contact_ok ptnr_contact_ok mkt_contact_ok stmt_brief} {
		reqSetArg $f "N"
	}

	foreach f {stmt_available stmt_on} {
		reqSetArg $f "Y"
	}

	# Statements
	reqSetArg freq_amt "2"
	reqSetArg freq_unit "W"
	reqSetArg dlv_method "E"
	reqSetArg brief "N"
	reqSetArg enforce_period "Y"

	reqSetArg ShopId $shop_id

	reqSetArg country_code "UK"

	#
	# All of the common arguments have been set, now add an account for each of the standard shop fielding types
	#

	append username " LBO_" $shop_no

	reqSetArg username   [append user_stranger $username "_STR"]
	reqSetArg OwnerType  "STR"
	set cust_id_stranger [tb_register::tb_do_registration PASSWD "N"]
	ob_log::write INFO   {Created account: cust id = $cust_id_stranger, username = $user_stranger}

	if {$cust_id_stranger == 0} {
		return 0
	}

	reqSetArg username  [append user_various $username "_VAR"]
	reqSetArg OwnerType  "VAR"
	set cust_id_various [tb_register::tb_do_registration PASSWD "N"]
	ob_log::write INFO  {Created account: cust id = $cust_id_various, username = $user_various}

	if {$cust_id_various == 0} {
		return 0
	}

	reqSetArg username     [append user_occasional $username "_OCC"]
	reqSetArg OwnerType  "OCC"
	set cust_id_occasional [tb_register::tb_do_registration PASSWD "N"]
	ob_log::write INFO     {Created account: cust id = $cust_id_occasional, username = $user_occasional}

	if {$cust_id_occasional == 0} {
		return 0
	}

	reqSetArg username  [append user_regular $username "_REG"]
	reqSetArg OwnerType  "REG"
	set cust_id_regular [tb_register::tb_do_registration PASSWD "N"]
	ob_log::write INFO  {Created account: cust id = $cust_id_regular, username = $user_regular}

	if {$cust_id_regular == 0} {
		return 0
	}

	return 1
}
