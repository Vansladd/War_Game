# ==============================================================
# $Id: oc_variants.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

#------------------------------------------------------------------------------
#   SYNOPSIS:
#      Provides utility functions for handling outcome variants
#
#      A variant allows odds on an individual selections odds to be lengthened
#      by additing a conditional.
#
#      eg. market      = A player to score
#          conditional = with his left foot
#
#      These markets cover selections where the market addition is intimatly
#      coupled with the parent market, so unlike scorecast a formulaic combo
#      of two market prices will not work effectively
#------------------------------------------------------------------------------


####################################
namespace eval ::ADMIN::OC_VARIANTS {

	variable ERR_CODES
	array set ERR_CODES [list]
	set ERR_CODES(ERR_NON_NUMERIC_INPUT) "Non numeric data passed"
	set ERR_CODES(ERR_BAD_STATUS_CODE)   "Illegal Status code, use A or S"
	set ERR_CODES(DB_ERROR)              "Database error"
	set ERR_CODES(ERR_BAD_PRICE_FORMAT)  "Bad Price Format"

}
####################################



#####################################################
proc ::ADMIN::OC_VARIANTS::get_err_defn {err_code} {
#####################################################

	variable ERR_CODES

	if {[info exists ERR_CODES($err_code)]} {
		return $ERR_CODES($err_code)
	} else {
		return $err_code
	}
}





################################################################################
proc ::ADMIN::OC_VARIANTS::update_ocvar {oc_var_id status price_num price_den\
					 max_bet} {
################################################################################
#---------------------------------------------------
# Suspend a specific selection
#---------------------------------------------------
	global   DB USERNAME

	if {$max_bet == "" || $max_bet < 0.01} { 
		set max_bet -1
	}

	if {![regexp {\d+} $price_num] || ![regexp {\d+} $price_den]} {
		return [list 0 ERR_BAD_PRICE_FORMAT]
	}
	
	
	set sql { execute procedure pUpdEvOcVariant (
			p_adminuser = ?,
			p_oc_var_id = ?,
			p_status    = ?,
			p_price_num = ?,
			p_price_den = ?,
			p_max_bet   = ?
		)
	}
	
	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set rs      [inf_exec_stmt $stmt $USERNAME $oc_var_id $status $price_num\
		 $price_den $max_bet]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute pUpdEvOcVariant : $msg}
		set ret [list 0 $msg]
	} else {
		set ret [list 1 $rs]
	}
	
	return $ret

}


################################################################################
proc ::ADMIN::OC_VARIANTS::change_market_value {ev_mkt_id old_value new_value} {
################################################################################
#---------------------------------------------------
# Suspend a specific selection
#---------------------------------------------------

	global DB USERNAME
	
	set sql {	
		SELECT
			oc_var_id
		FROM
			tEvOcVariant
		WHERE
			value = ?
			AND ev_mkt_id = ?
	}
	
	set sql_ocv_value {
		execute procedure pUpdEvOcVariant (
			p_adminuser = ?,
			p_oc_var_id = ?,
			p_value    = ?,
			p_max_bet  = null
		)
	}
	
	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set rs      [inf_exec_stmt $stmt $old_value $ev_mkt_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		set ret [list 0 $msg]
	} 

	set nrows [db_get_nrows $rs]
	set last_ret [list 1 OK]
	inf_begin_tran $DB
	set rollback 0
	for {set row_idx 0} {$row_idx < $nrows} {incr row_idx} {
		set oc_var_id [db_get_col $rs $row_idx oc_var_id]
		if {[catch {
			set stmt    [inf_prep_sql $DB $sql_ocv_value]
			set last_exec      [inf_exec_stmt $stmt $USERNAME\
						 $oc_var_id $new_value]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute pUpdEvOcVariant : $msg}
			set last_ret [list 0 $msg]
			set rollback 1
			break
		} else {
			set last_ret [list 1 $last_exec]
		}
	}
	if {$rollback} {
		inf_rollback_tran $DB
	} else {
		inf_commit_tran $DB
	}
	catch {db_close $rs}
	return $last_ret
}




################################################################################
proc ::ADMIN::OC_VARIANTS::delete_market_value {ev_mkt_id value} {
################################################################################
#---------------------------------------------------
# Delete variants with the specified value
#---------------------------------------------------
	global DB

	set sql {
		DELETE FROM tEvOcVariant
		WHERE
			ev_mkt_id = ?
		AND
			value = ?
	}
	
	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set rs      [inf_exec_stmt $stmt $ev_mkt_id $value]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		set ret [list 0 $msg]
	} else {
		set ret [list 1 $rs]
	}
	
	return $ret

}

################################################################################
proc ::ADMIN::OC_VARIANTS::update_ocv_for_seln {ev_oc_id status} {
################################################################################
#---------------------------------------------------
# Update OC variant status for a selection
#---------------------------------------------------
	global DB
	
	if {[lsearch {Y N} $status] < 0} {
		return [list 0 ERR_BAD_STATUS_CODE]
	}
	
	set sql {
		UPDATE
			tEvOc
		SET
			has_oc_variants = ?
		WHERE
			ev_oc_id = ?
	}
	
	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set rs      [inf_exec_stmt $stmt $status $ev_oc_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		set ret [list 0 $msg]
	} else {
		set ret [list 1 $rs]
	}
	
	return $ret
	
}


################################################################################
proc ::ADMIN::OC_VARIANTS::generate_hcap_variants {ev_mkt_id\
							 min\
							 {max ""}\
							 {increment ""}\
							 {status ""}\
							 {price_num ""}\
							 {price_den ""}\
							 {max_bet ""}
							} {
################################################################################
#---------------------------------------------------
# Create a handicap type variant for a whole market
#---------------------------------------------------

	global DB USERNAME

	if {$max == ""}       {set max $min}
	if {$min == ""}       {set min $max}
	if {$increment == ""} {set increment 1}
	if {$status == ""}    {set status S}
	if {$price_num == ""} {set price_num 1}
	if {$price_den == ""} {set price_den 100}
	if {$max_bet == ""}   {set max_bet 0}

	# Check input
	#------------
	if {![regexp {^[-]?\d+\.?\d{0,4}$} $min] || \
		![regexp {[-]?\d+\d{0,4}} $max] || \
		![regexp {\d+} $price_num] || \
		![regexp {\d+} $price_den] || \
		![regexp {\d+\d{0,4}} $increment]} {
		ob::log::write INFO {generate_hcap_variants : invalid input }
		return [list 0 ERR_NON_NUMERIC_INPUT]
	}

	if {[lsearch {A S} $status] < 0} {
		ob::log::write INFO {generate_hcap_variants : invalid input :\
					 status code $status }
		return [list 0 ERR_BAD_STATUS_CODE]
	}

	set sql_get_selections { 
		SELECT
			ev_oc_id
		FROM
			tEvOc
		WHERE
			ev_mkt_id = ?
	}
	
	set sql_mark_oc_as_var {
		UPDATE
			tEvOc
		SET
			has_oc_variants = 'Y'
		WHERE
			ev_oc_id = ?;
	}

	# Get the market selections
	#--------------------------
	if {[catch {
		set stmt    [inf_prep_sql $DB $sql_get_selections]
		set rs      [inf_exec_stmt $stmt $ev_mkt_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		set ret [list 0 $msg]
		return $ret
	} else {
		set ret [list 1 $rs]
	}
	
	set nrows [db_get_nrows $rs]

	if { $min > $max } {
		set swap $min
		set min $max
		set max $swap
	}

	# Add Teasers for the handicap range for eash selection
	#------------------------------------------------------
	for {set row_idx 0} {$row_idx < $nrows} {incr row_idx} {
		set ev_oc_id [db_get_col $rs $row_idx ev_oc_id]
		
		for {set hcap $min} {$hcap <= $max} {set hcap [expr {$hcap + $increment}]} {
			set add_variant [_add_variant $ev_oc_id \
							$ev_mkt_id \
							$price_num \
							$price_den \
							$status N \
							$hcap HC \
							$max_bet]
			if {[lindex $add_variant 0] != 1} {
				ob::log::write ERROR {trouble encountered\
				 adding evoc variant for $ev_oc_id handicap\
				 $hcap}
			}
		}

		if {[catch {
			set stmt    [inf_prep_sql $DB $sql_mark_oc_as_var]
			set rs_mark [inf_exec_stmt $stmt $ev_oc_id]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
		}
	}
	catch {db_close rs}
	return [list 1 OK]
}


#---------------------------------------- Private functions


################################################################
proc ::ADMIN::OC_VARIANTS::_add_variant {ev_oc_id \
						ev_mkt_id \
						price_num \
						price_den \
						{status S} \
						{displayed N} \
						{value 0} \
						{type -}
						{max_bet ""}} {
################################################################
#---------------------------------------------------------------------------
# Add a OC_VARIANTS to a given selection
#---------------------------------------------------------------------------
	global DB USERNAME

	if {$max_bet < 0.01} { 
		set max_bet ""
	}

	set sql {
		execute procedure pInsEvOcVariant (
			p_adminuser      = ?,
			p_ev_mkt_id      = ?,
			p_ev_oc_id       = ?,
			p_status         = ?,
			p_price_num      = ?,
			p_price_den      = ?,
			p_value          = ?,
			p_type           = ?,
			p_max_bet        = ?
		)
	}
		
	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set rs      [inf_exec_stmt $stmt $USERNAME $ev_mkt_id\
				$ev_oc_id $status $price_num $price_den\
				$value $type $max_bet]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute pInsEvOcVariant : $msg}
		set ret [list 0 $msg]
	} else {
		set ret [list 1 VARIANT_ADDED]
	}
	
	catch {db_close $rs}
	
	return $ret

}



#
# formats the handicap value for displaying
#
########################################################
proc ::ADMIN::OC_VARIANTS::format_hcap_string { mkt_sort\
						mkt_type\
						fb_result\
						hcap_value\
						hcap_value_fmt\
                         			{use_brackets_for_draw Y}} {
########################################################

	set hcap_parts    [list]
	set hcap_str_list [list]
	set hcap_str      $hcap_value_fmt
	set hcap_value    $hcap_value_fmt

	if { [OT_CfgGet SHOW_WH_HCAP_ZERO_ALT_DESC 0] &&
	     [lsearch -exact [list MH WH] $mkt_sort] != -1 &&
	     $hcap_value == 0 } {

		# Temporary Hack
		if {$use_brackets_for_draw == "N"} {
			set hcap_str ZERO_HANDICAP
		} else {
			# Another hack - add brackets in here
			set hcap_str "([ml_printf ZERO_HANDICAP])"
		}

	} elseif {$mkt_sort == "AH"} {

		if {[expr abs(int($hcap_value))] == 0} {
				set hcap_str "0.0"

		} else {
			#
			# Will format to "x.xx & x.xx" only if config item is 
			# set AND h/cap is a quarter value for Asian Handicap
			#
			if {$fb_result != "L"} {
	
				if {$fb_result == "A"} {
					set hcap_value [expr $hcap_value * -1]
				}
	
				if {([OT_CfgGet AH_DISPLAY_SPLIT_LINE 0] == 1)\
					 && ([lsearch [list 1 3]\
					 [expr (int($hcap_value)) % 4]] != -1)} {

					if {$hcap_value < 0.0} {
						lappend hcap_parts \
						 "[expr $hcap_value / 4.0 + 0.25]"\
						 "[expr $hcap_value / 4.0 - 0.25]"
					} else {
						lappend hcap_parts \
						 "[expr $hcap_value / 4.0 - 0.25]"\
						 "[expr $hcap_value / 4.0 + 0.25]"
					}
	
				} else {
					lappend hcap_parts \
						"[expr $hcap_value / 4.0]"
				}
	
				if {$hcap_value > 0.0} {

					foreach part $hcap_parts {
						if {[lsearch "0.0" $part] != -1} {
							lappend hcap_str_list \
							 "0.0"
						} else {
							lappend hcap_str_list \
							 "+$part"
						}
					}
	
				} else {
					foreach part $hcap_parts {
						if {[lsearch "0.0" $part] != -1} {
							lappend hcap_str_list \
							 "0.0"
						} else {
							lappend hcap_str_list \
							 "$part"
						}
					}
				}
	
			} else {
				if {$use_brackets_for_draw == "Y"} {
					regsub -- {-} "($hcap_str)" "" hcap_str
				}
			}
	
			if {[llength $hcap_str_list] == 0} {
				set hcap_str "Error - hcap_str not formed correctly"
	
			} elseif {[llength $hcap_str_list] == 1} {
				set hcap_str [lindex $hcap_str_list 0]
	
			} else {
				set hcap_str_list\
				 [linsert $hcap_str_list 0 "AH_HCAP_SPLIT"]
				set hcap_str\
				 [eval "OB_mlang::ml_printf $hcap_str_list"]
			}
		}

	} elseif { [lsearch -exact [list MH WH] $mkt_sort] != -1 ||
	           $mkt_type == "A" } {

		if {$fb_result == "H"} {
			if {$hcap_value > 0.0} {
				set hcap_str "+$hcap_str"
			}
		} elseif {$fb_result == "A"} {
			if {$hcap_value < 0.0} {
				# replace the '-' with a '+'
				set hcap_str [string replace $hcap_str 0 0 "+"]
			} elseif {$hcap_value > 0.0} {
				set hcap_str "-$hcap_str"
			}
		} elseif {$fb_result == "L"} {
			if {$use_brackets_for_draw=="Y"} {
				regsub -- {-} "($hcap_str)" "" hcap_str
			}
		}

	} elseif {[lsearch -exact [list HL] $mkt_sort] == -1} {
		set hcap_str ""
	}

	return $hcap_str
}
