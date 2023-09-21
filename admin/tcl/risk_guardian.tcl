# ==============================================================
# $Id: risk_guardian.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 OpenBet Technology Ltd. All rights reserved.
# ==============================================================
#
# Allows for the configuration of Risk Guardian settings to be adjusted
#
namespace eval ADMIN::RISKGUARDIAN {

	asSetAct ADMIN::RISKGUARDIAN::GoRGChoose               [namespace code go_rg_choose]
	asSetAct ADMIN::RISKGUARDIAN::GoEditCondition          [namespace code go_edit_condition]
	asSetAct ADMIN::RISKGUARDIAN::GoInsertCondition        [namespace code go_insert_condition]
	asSetAct ADMIN::RISKGUARDIAN::GoChangeStatus           [namespace code go_change_status]

	# Displays Risk Guardian settings
	#
	proc go_rg_choose args {

		global DB

		set sql [subst {
			select status
			from tRGHost
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]

		set nrows [db_get_nrows $res]

		if {$nrows != 1} {
			# we have a problem, there should only be one host listed in this table..
			error "More than one Risk Guardian host in the database. There should be only one"
		} else {
			set status [db_get_col $res 0 status]

			if {$status == "A"} {
				tpBindString status "Active"
				tpBindString opp_status "Inactive"
			} else {
				tpBindString status "Inactive"
				tpBindString opp_status "Active"
			}
		}

		inf_close_stmt $stmt
		db_close $res

		set sql [subst {
			select count(*) as count from tRGCondition
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]

		set count [db_get_col $res 0 count]
		inf_close_stmt $stmt
		db_close $res

		if {$count == 0} {
			tpSetVar no_conditions "true"
		} else {
			tpSetVar no_conditions "false"
		}

		asPlayFile rg/rg_choose.html
	}

	# Enables/Disables Risk Guardian
	#
	proc go_change_status args {

		global DB

		if {![op_allowed RGModStatus]} {
			err_bind "You do not have permission to change the Risk Guardian status!"
			go_rg_choose
			return
		}

		set long_status [reqGetArg status]

		if {$long_status == "Active"} {
			set status "S"
		} else {
			set status "A"
		}

		set sql [subst {
			update tRGHost set status = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $status

		go_rg_choose
	}

	# Allows one to edit Risk Guardian conditions
	#
	proc go_edit_condition args {

		global DB DATA

		if {![op_allowed RGModCondition]} {
			err_bind "You do not have permission to add/edit Risk Guardian conditions!"
			go_rg_choose
			return
		}

		set type [reqGetArg type]

		switch -- $type {
			amount {
				## get amounts already selected (if any)
				set sql [subst {
					select type, i_value
					from tRGCondition
					where type like ?
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt "amount/%"]

				set numAmounts [db_get_nrows $res]
				set ccyList [list]

				for {set r 0} {$r < $numAmounts} {incr r} {
					set val [db_get_col $res $r type]
					set both [split $val "/"]
					set ccy_code [lindex $both 1]
					lappend ccyList $ccy_code

					set DATA($r,amount) [db_get_col $res $r i_value]
					append DATA($r,amount) " "
					append DATA($r,amount) $ccy_code
				}
				inf_close_stmt $stmt
				db_close $res

				tpSetVar numAmounts $numAmounts
				tpBindVar amount DATA amount amount_idx

				# get list of available currencies
				set sql [subst {
					select distinct ccy_code from tCCY
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt]

				set numAvailCurrencies [db_get_nrows $res]
				set numCurrencies 0

				for {set r 0} {$r < $numAvailCurrencies} {incr r} {
					set ccy_code [db_get_col $res $r ccy_code]

					if {[llength $ccyList] > 0} {
						set okToAdd 1
						for {set i 0} {$i < [llength $ccyList]} {incr i} {
							if {[lindex $ccyList $i] == $ccy_code} {
								set okToAdd 0
							}
						}
						if {$okToAdd == 1} {
							set DATA($numCurrencies,availCurrency) $ccy_code
							incr numCurrencies
						}
					} else {
						set DATA($r,availCurrency) $ccy_code
						set numCurrencies $numAvailCurrencies
					}
				}
				inf_close_stmt $stmt
				db_close $res

				tpSetVar numAvailCurrencies $numCurrencies
				tpBindVar availCurrency DATA availCurrency availCurrency_idx

				asPlayFile rg/rg_edit_amount.html
			}
			currency {
				## get currencies already selected (if any)
				set sql [subst {
					select c_value
					from tRGCondition
					where type = ?
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt "currency"]

				set numSelectedCurrencies [db_get_nrows $res]
				for {set r 0} {$r < $numSelectedCurrencies} {incr r} {
					set DATA($r,selectedCurrency) [db_get_col $res $r c_value]
				}
				inf_close_stmt $stmt
				db_close $res

				tpSetVar numSelectedCurrencies $numSelectedCurrencies
				tpBindVar selectedCurrency DATA selectedCurrency selCurrency_idx

				# get list of available currencies
				set sql [subst {
					select distinct ccy_code from tCCY
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt]

				set numTotalAvailCurrencies [db_get_nrows $res]
				set numAvailCurrencies 0
				for {set r 0} {$r < $numTotalAvailCurrencies} {incr r} {
					set aCurrency [db_get_col $res $r ccy_code]

					set newCurrency "true"
					for {set q 0} {$q < $numSelectedCurrencies} {incr q} {
						if {$DATA($q,selectedCurrency) == $aCurrency} {
							## don't need to add as this currency already in selected list
							set newCurrency "false"
						}
					}
					if {$newCurrency == "true"} {
						set DATA($numAvailCurrencies,availCurrency) $aCurrency
						incr numAvailCurrencies
					}
				}

				inf_close_stmt $stmt
				db_close $res

				tpSetVar numAvailCurrencies $numAvailCurrencies
				tpBindVar availCurrency DATA availCurrency availCurrency_idx

				asPlayFile rg/rg_edit_currency.html
			}
			country {
				## get countries already selected (if any)
				set sql [subst {
					select c_value
					from tRGCondition
					where type = ?
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt "country"]

				set numSelectedCountries [db_get_nrows $res]
				for {set r 0} {$r < $numSelectedCountries} {incr r} {
					set DATA($r,selectedCountry) [db_get_col $res $r c_value]
				}
				inf_close_stmt $stmt
				db_close $res

				tpSetVar numSelectedCountries $numSelectedCountries
				tpBindVar selectedCountry DATA selectedCountry selCountry_idx

				# get list of available countries
				set sql [subst {
					select distinct country from tCardInfo
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt]

				set numTotalAvailCountries [db_get_nrows $res]
				set numAvailCountries 0
				for {set r 0} {$r < $numTotalAvailCountries} {incr r} {
					set aCountry [db_get_col $res $r country]

					set newCountry "true"
					for {set q 0} {$q < $numSelectedCountries} {incr q} {
						if {$DATA($q,selectedCountry) == $aCountry} {
							## don't need to add as this country already in selected list
							set newCountry "false"
						}
					}
					if {$newCountry == "true"} {
						set DATA($numAvailCountries,availCountry) $aCountry
						incr numAvailCountries
					}
				}
				inf_close_stmt $stmt
				db_close $res

				tpSetVar numAvailCountries $numAvailCountries
				tpBindVar availCountry DATA availCountry availCountry_idx

				asPlayFile rg/rg_edit_country.html
			}
			ip_address {
				## get IP addresses already selected (if any)
				set sql [subst {
					select c_value
					from tRGCondition
					where type = ?
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt "ip_address"]

				set numIPAddresses [db_get_nrows $res]
				for {set r 0} {$r < $numIPAddresses} {incr r} {
					set DATA($r,IPAddress) [db_get_col $res $r c_value]
				}
				inf_close_stmt $stmt
				db_close $res

				tpSetVar numIPAddresses $numIPAddresses
				tpBindVar IPAddress DATA IPAddress IPAddress_idx

				asPlayFile rg/rg_edit_ip_address.html
			}
			card_bin {
				## get card bins already selected (if any)
				set sql [subst {
					select c_value
					from tRGCondition
					where type = ?
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt "card_bin"]

				set numCardBins [db_get_nrows $res]
				for {set r 0} {$r < $numCardBins} {incr r} {
					set DATA($r,cardBin) [db_get_col $res $r c_value]
				}
				inf_close_stmt $stmt
				db_close $res

				tpSetVar numCardBins $numCardBins
				tpBindVar cardBin DATA cardBin cardBin_idx

				asPlayFile rg/rg_edit_card_bin.html
			}
			reg_date {
				## get reg date check
				set sql [subst {
					select c_value
					from tRGCondition
					where type = ?
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt "reg_date"]

				set num_rows [db_get_nrows $res]

				if {$num_rows > 0} {
					tpBindString reg_date [db_get_col $res 0 c_value]
				}

				asPlayFile rg/rg_edit_reg_date.html
			}
			1st_dep_date {
				## get first dep date check
				set sql [subst {
					select c_value
					from tRGCondition
					where type = ?
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res  [inf_exec_stmt $stmt "1st_dep_date"]

				set num_rows [db_get_nrows $res]

				if {$num_rows > 0} {
					tpBindString reg_date [db_get_col $res 0 c_value]
				}

				asPlayFile rg/rg_edit_1st_dep_date.html
			}
			default {
			}
		}
	}

	# Inserts a Risk Guardian condition
	proc go_insert_condition args {

		global DB

		set toList [list];
		set typeList [list];
		set type [reqGetArg type]

		set num_args [reqGetNumArgs to]
		for {set r 0} {$r < $num_args} {incr r} {
			set val [reqGetNthArg to $r]

			if {$type == "amount"} {
				# strip off currency from the amount and add it to the string 'amount'
				set both [split $val " "]
				set amount [lindex $both 0]
				set ccy_code [lindex $both 1]

				lappend toList $amount

				set amountType $type
				append amountType "/"
				append amountType $ccy_code
				lappend typeList $amountType
			} else {
				lappend toList $val
			}
		}

		## delete first so we don't have to work out which entries are
		## new and which are old entries
		if {$type == "amount"} {
			set delete_sql [subst {
				delete from tRGCondition where type like ?
			}]
			set delete_stmt [inf_prep_sql $DB $delete_sql]
			set amountType $type
			append amountType "/%"
			inf_exec_stmt $delete_stmt $amountType

			set insert_sql [subst {
				insert into tRGCondition (type, i_value) values (?, ?)
			}]
		} else {
			set delete_sql [subst {
				delete from tRGCondition where type = ?
			}]
			set delete_stmt [inf_prep_sql $DB $delete_sql]
			inf_exec_stmt $delete_stmt $type

			set insert_sql [subst {
				insert into tRGCondition (type, c_value) values (?, ?)
			}]
		}
		inf_close_stmt $delete_stmt

		set insert_stmt [inf_prep_sql $DB $insert_sql]

		for {set r 0} {$r < [llength $toList]} {incr r} {

			if {$type == "amount"} {
				inf_exec_stmt $insert_stmt [lindex $typeList $r] [lindex $toList $r]
			} else {
				inf_exec_stmt $insert_stmt $type [lindex $toList $r]
			}
		}
		inf_close_stmt $insert_stmt

		asPlayFile rg/rg_choose.html
	}

}
