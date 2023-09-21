# ==============================================================
# $Id: oc_variants.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#------------------------------------------------------------------------------
#    SYNOPSIS:
#       Provides shared functionality for account transactions and enquiries
#------------------------------------------------------------------------------


namespace eval ::OB_OcVariant { }



proc ::OB_OcVariant::init {} {
	_prepare_stmt
}



# Bind the variant data for the ev_oc_ids passed
proc ::OB_OcVariant::bind_variant_data {ids {what ev_oc_id}} {

	global OC_VARIANT

	catch {unset OC_VARIANT}

	# Build up the OC_VARIANT array
	get_variant_data $ids $what

	tpBindVar ocv_num_variants    OC_VARIANT num_variants   ocvar_ev_oc_id
	tpBindVar ocv_oc_var_id       OC_VARIANT oc_var_id      ocvar_ev_oc_id var_idx
	tpBindVar ocv_value           OC_VARIANT value          ocvar_ev_oc_id var_idx
	tpBindVar ocv_desc            OC_VARIANT desc           ocvar_ev_oc_id var_idx
	tpBindVar ocv_price_num       OC_VARIANT price_num      ocvar_ev_oc_id var_idx
	tpBindVar ocv_price_den       OC_VARIANT price_den      ocvar_ev_oc_id var_idx
	tpBindVar ocv_price_str       OC_VARIANT price_str      ocvar_ev_oc_id var_idx
	tpBindVar ocv_status          OC_VARIANT status         ocvar_ev_oc_id var_idx
	tpBindVar ocv_type            OC_VARIANT type           ocvar_ev_oc_id var_idx
	tpBindVar ocv_max_bet         OC_VARIANT max_bet        ocvar_ev_oc_id var_idx
	tpBindVar ocv_apply_price     OC_VARIANT apply_price    ocvar_ev_oc_id var_idx
	tpBindVar ocv_disporder       OC_VARIANT disporder      ocvar_ev_oc_id var_idx
	tpBindVar ocv_pegged          OC_VARIANT pegged         ocvar_ev_oc_id var_idx
	tpBindVar ocv_hcap_fmt        OC_VARIANT hcap_value_fmt ocvar_ev_oc_id var_idx
	tpBindVar ocv_ev_oc_id        OC_VARIANT ev_oc_id       ocvar_ev_oc_id var_idx
	tpBindVar ocv_ev_mkt_id       OC_VARIANT ev_mkt_id      ocvar_ev_oc_id var_idx

	return [list 1 OK]
}



# Build array with current variant info for selections
proc ::OB_OcVariant::get_variant_data {ids what} {

	global OC_VARIANT

	switch -exact $what {
		ev_oc_id  {set qry oc_var_get_variants_for_ocs}
		ev_mkt_id {set qry oc_var_get_variants_for_mkt}
	}

	set err_count 0

	while {[llength $ids] > 0} {

		set ev_oc_ids [lrange $ids 0 9]
		set ids       [lrange $ids 10 end]

		for {set padding [llength $ev_oc_ids]} {$padding < 10} {incr padding} {
			lappend ev_oc_ids -1
		}

		if {[catch {
			set rs [eval "db_exec_qry $qry $ev_oc_ids"]
		} msg]} {
			ob::log::write ERROR {unable to retrieve oc variant data: $msg }
			catch {db_close $rs}
			incr err_count
			continue
		}
		set nrows [db_get_nrows $rs]

		set row_idx 0
		while {$row_idx < $nrows} {

			set ev_oc_id [db_get_col $rs $row_idx ev_oc_id]

			set var_idx 0
			while {$row_idx < $nrows && $ev_oc_id == [db_get_col $rs $row_idx ev_oc_id]} {

				set oc_key "$ev_oc_id,$var_idx"

				set OC_VARIANT($oc_key,oc_var_id)   [db_get_col $rs $row_idx oc_var_id]
				set OC_VARIANT($oc_key,value)       [db_get_col $rs $row_idx value]
				set OC_VARIANT($oc_key,desc)        [db_get_col $rs $row_idx desc]
				set OC_VARIANT($oc_key,status)      [db_get_col $rs $row_idx status]
				set OC_VARIANT($oc_key,type)        [db_get_col $rs $row_idx type]
				set OC_VARIANT($oc_key,max_bet)     [db_get_col $rs $row_idx max_bet]
				set OC_VARIANT($oc_key,apply_price) [db_get_col $rs $row_idx apply_price]
				set OC_VARIANT($oc_key,ev_mkt_id)   [db_get_col $rs $row_idx ev_mkt_id]
				set OC_VARIANT($oc_key,ev_oc_id)    [db_get_col $rs $row_idx ev_oc_id]
				set OC_VARIANT($oc_key,hcap_value)  [db_get_col $rs $row_idx hcap_value]

				if {[db_get_col $rs $row_idx apply_price] == "R"} {
					set OC_VARIANT($oc_key,price_num) \
					        [expr {[db_get_col $rs $row_idx price_num] * \
					               [db_get_col $rs $row_idx lp_num]}]
					set OC_VARIANT($oc_key,price_den) \
					        [expr {[db_get_col $rs $row_idx price_den] * \
					               [db_get_col $rs $row_idx lp_den]}]
				} else {
					set OC_VARIANT($oc_key,price_num) [db_get_col $rs $row_idx price_num]
					set OC_VARIANT($oc_key,price_den) [db_get_col $rs $row_idx price_den]
				}

				set OC_VARIANT($oc_key,price_str) [get_price_str "Y" \
				                                          $OC_VARIANT($oc_key,price_num) \
				                                          $OC_VARIANT($oc_key,price_den) \
				                                          "N" "N" "0"]


				# Flag up handicap type variant
				#------------------------------
				if {$OC_VARIANT($oc_key,type) == "HC"} {

					set ev_mkt_id [db_get_col $rs $row_idx ev_mkt_id]

					set OC_VARIANT($ev_mkt_id,hcap_variant) 1
					set OC_VARIANT($oc_key,pegged)          0

					if {$OC_VARIANT($oc_key,value) == $OC_VARIANT($oc_key,hcap_value)} {
						set OC_VARIANT($oc_key,pegged)   1
					}

					set value_fmt [format \
					        "%0.[db_get_col $rs $row_idx hcap_precision]f" \
					        $OC_VARIANT($oc_key,value)]

					set OC_VARIANT($oc_key,hcap_value_fmt) \
					        [format_hcap_string \
					            [db_get_col $rs $row_idx mkt_sort] \
					            [db_get_col $rs $row_idx mkt_type] \
					            [db_get_col $rs $row_idx fb_result] \
					            [db_get_col $rs $row_idx value] \
					            $value_fmt]

				}

				incr var_idx
				incr row_idx
			}
			set OC_VARIANT($ev_oc_id,num_variants) $var_idx
		}
	}

	if {$err_count > 0} {return [list 0 ERROR]}
	return [list 1 OK]
}



# Convert any oc_var ids in ids to their base ev_oc_id
proc ::OB_OcVariant::convert_to_evocs {ids} {

	# Find any oc_vars present
	set oc_var_ids [list]
	foreach id $ids {
		if {[string index $id 0] == "V"} {
			lappend oc_var_ids [string range $id 1 end]
		}
	}

	if {[llength $oc_var_ids] < 1} {return $ids}

	# Pad list to fit query
	for {set padding [llength $oc_var_ids]} {$padding <= 10} {incr padding} {
		lappend oc_var_ids -1
	}

	# Execute query
	if {[catch {
		set rs [eval "db_exec_qry oc_var_get_base_ev_oc_ids $oc_var_ids"]
	} msg]} {
		ob::log::write ERROR {OB_OcVariant: unable to find base ev_oc_ids : $msg }
	}
	set nrows [db_get_nrows $rs]
	for {set row_idx 0} {$row_idx < $nrows} {incr row_idx} {
		set OC_VAR_MAP(V[db_get_col $rs $row_idx oc_var_id]) \
		        [db_get_col $rs $row_idx ev_oc_id]
	}

	# Recreate list with oc_var_ids substituted for their base ev_oc_ids
	set ev_oc_ids [list]
	foreach id $ids {
		if {[string index $id 0] == "V"} {
			if {[info exists OC_VAR_MAP($id)]} {
				lappend ev_oc_ids $OC_VAR_MAP($id)
			}
		} else {
			lappend ev_oc_ids $id
		}
	}
	return $ev_oc_ids
}



# DB Initialisation
proc ::OB_OcVariant::_prepare_stmt {} {

	# Find the base ev_ocs for a given set of oc_var_ids (max 10)
	db_store_qry  oc_var_get_base_ev_oc_ids {
		SELECT
			oc_var_id,
			ev_oc_id
		FROM
			tEvOcVariant
		WHERE
			oc_var_id IN (?,?,?,?,?,?,?,?,?,?)
	}


	# get the outcome variants for given evocids
	db_store_qry oc_var_get_variants_for_ocs {
		SELECT
			v.oc_var_id,
			v.ev_oc_id,
			v.ev_mkt_id,
			v.value,
			v.desc,
			v.price_num,
			v.price_den,
			v.displayed,
			v.status,
			v.type,
			v.apply_price,
			v.disporder,
			v.max_bet,
			m.hcap_value,
			m.hcap_precision,
			m.type as mkt_type,
			m.sort as mkt_sort,
			e.fb_result,
			e.lp_num,
			e.lp_den
		FROM
			tEvOcVariant v,
			tEvMkt m,
			tEvOc e
		WHERE
			v.ev_oc_id IN (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		AND v.status = 'A'
		AND e.ev_oc_id = v.ev_oc_id
		AND m.status = 'A'
		AND m.ev_mkt_id = v.ev_mkt_id
		ORDER BY
			v.ev_oc_id, v.disporder, v.value
	}

	# get the outcome variants for given market
	db_store_qry oc_var_get_variants_for_mkt {
		SELECT
			v.oc_var_id,
			v.ev_oc_id,
			v.ev_mkt_id,
			v.value,
			v.desc,
			v.price_num,
			v.price_den,
			v.displayed,
			v.status,
			v.type,
			v.apply_price,
			v.disporder,
			v.max_bet,
			m.hcap_value,
			m.hcap_precision,
			m.type as mkt_type,
			m.sort as mkt_sort,
			e.fb_result,
			e.lp_num,
			e.lp_den
		FROM
			tEvOcVariant v,
			tEvMkt m,
			tEvOc e
		WHERE
			m.ev_mkt_id IN (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		AND v.status = 'A'
		AND e.ev_oc_id = v.ev_oc_id
		AND m.status = 'A'
		AND m.ev_mkt_id = v.ev_mkt_id
		ORDER BY
			v.ev_oc_id, v.disporder, v.value
	} 30
}
