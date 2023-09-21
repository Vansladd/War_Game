# ==============================================================
# $Id: pmt_rules.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {

	asSetAct ADMIN::PMT::GoPmtRules        	    [namespace code go_pmt_rules]
	asSetAct ADMIN::PMT::GoAddRule              [namespace code go_add_rule]
	asSetAct ADMIN::PMT::GoUpPriority           [namespace code go_up_priority]
	asSetAct ADMIN::PMT::GoRule                 [namespace code go_rule]
	asSetAct ADMIN::PMT::GoAddCCRule            [namespace code go_add_CC_rule]
	asSetAct ADMIN::PMT::GoSuspendCCRule        [namespace code go_suspend_CC_rule]
	asSetAct ADMIN::PMT::GoActivateCCRule       [namespace code go_activate_CC_rule]
	asSetAct ADMIN::PMT::GoAddCCRuleClause      [namespace code go_add_CC_rule_clause]
	asSetAct ADMIN::PMT::GoRemoveCCRuleClause   [namespace code go_remove_CC_rule_clause]
	asSetAct ADMIN::PMT::GoUpdCCRule            [namespace code go_upd_CC_rule]

	asSetAct ADMIN::PMT::GoViewHist             [namespace code go_view_hist]
	asSetAct ADMIN::PMT::GoRulesAtDate          [namespace code go_rules_at_date]
	asSetAct ADMIN::PMT::GoRuleAtDate           [namespace code go_rule_at_date]


	## Selecting one of these criteria affects the available values
	## for all the others

	set related_criteria [list bank country scheme type]

	set bank_base_qry "select distinct bank\
			   from tCardInfo"

	set country_base_qry "select distinct country\
                              from tCardInfo"

	set scheme_base_qry "select distinct scheme\
			     from tCardInfo"

	set type_base_qry "select distinct case type\
					when 'D' then 'DBT'\
					when 'C' then 'CDT'\
			   end as type
                           from tCardInfo"

	set currency_base_qry "select distinct ccy_code\
			       from tCCY\
			       where status = 'A'"


	set card_bin_exists "select first 1 *\
			      from tCardInfo"

	set num_bins "select count(*)\
		      from tCardInfo"

	proc init_pmt_rules {} {

		global CRITERIA_DEF
		variable VALID_DATA

		OT_LogWrite 4 "ADMIN::PMT::init_pmt_rules"

		set CRITERIA_DEF(criteria) [list transaction type scheme country bank amount currency card_bin]

		## some clauses in a rule can be made up of multiple
		## propositions involving one criterion
		## e.g country == "UNITED KINGDOM" or country == "FRANCE"

		set multi_prop [list N Y Y Y Y N Y Y]

		## S -> String
		## N -> Number

		set data_types [list S S S S S N S N]

		## the value for some criteria (e.g. amount) is specified by
		## the user and not selected from a list of possible values
		## returned by a query

		set qry_based  [list N Y Y Y Y N Y N]

		## For each criteria set up some defaults

		for {set i 0} {$i < [llength $CRITERIA_DEF(criteria)]} {incr i} {
			set CRITERIA_DEF(multi_prop,[lindex $CRITERIA_DEF(criteria) $i]) [lindex $multi_prop $i]
			set CRITERIA_DEF(data_type,[lindex $CRITERIA_DEF(criteria) $i]) [lindex $data_types $i]
			set CRITERIA_DEF(qry_based,[lindex $CRITERIA_DEF(criteria) $i]) [lindex $qry_based $i]

			## Construct the list as a javascript list

			set CRITERIA_DEF(valid_operators,[lindex $CRITERIA_DEF(criteria) $i]) "\["
			## If a criterion has string values then we want to use
			## [string equal] and ![string equal] instead of
			## == and !=

			if {[string equal $CRITERIA_DEF(data_type,[lindex $CRITERIA_DEF(criteria) $i]) "S"]} {
				append CRITERIA_DEF(valid_operators,[lindex $CRITERIA_DEF(criteria) $i]) "\"string equal\", \"!string equal\""
			} else {
				append CRITERIA_DEF(valid_operators,[lindex $CRITERIA_DEF(criteria) $i]) "\"==\", \"!=\", \">\", \"<\", \">=\", \"<=\""
			}

			## If a criterion is multi-propositional then allow
			## the user to specify a list of values to which
			## the criterion must belong

			if {[string equal $CRITERIA_DEF(multi_prop,[lindex $CRITERIA_DEF(criteria) $i]) "Y"]} {
				append CRITERIA_DEF(valid_operators,[lindex $CRITERIA_DEF(criteria) $i]) " ,\"in\""
			}
			if {[string equal [lindex $CRITERIA_DEF(criteria) $i] "card_bin"]} {
				append CRITERIA_DEF(valid_operators,[lindex $CRITERIA_DEF(criteria) $i]) ", \"between\""
			}
			append CRITERIA_DEF(valid_operators,[lindex $CRITERIA_DEF(criteria) $i]) "\]"
		}
		get_existing_CC_rule_clauses
	}

	proc clear_arrays args {
		global RULE
		global UNUSED_CRITERIA
		global RULE_CLAUSES
		global PMT_GATEWAYS
		global WARNING

		## Clear out contents of arrays

		if {[info exists RULE]} {
			unset RULE
		}
		if {[info exists UNUSED_CRITERIA]} {
			unset UNUSED_CRITERIA
		}
		if {[info exists RULE_CLAUSES]} {
			unset RULE_CLAUSES
		}
		if {[info exists PMT_GATEWAYS]} {
			unset PMT_GATEWAYS
		}
		if {[info exists WARNING]} {
			unset WARNING
		}
	}

	proc generate_qry_clauses {used_where} {
		global RULE
		variable related_criteria

		set qry_clauses ""

		## Append the first clause of the query
		## using where, all the others using and

		if {[string equal $RULE(present,transaction) Y]} {
			if {$used_where == 0} {
				append qry_clauses " where"
				set used_where  1
			} else {
				append qry_clauses " and"
			  }
			set op $RULE(operator,transaction)
			switch -- $op {
				"string equal"    {set op "="}
				"!string equal"	  {set op "!="}
			}
			if {[lsearch $RULE(values,transaction) D] != -1} {
				append qry_clauses " allow_dep $op 'Y'"
			} elseif {[lsearch $RULE(values,transaction) W] != -1} {
				append qry_clauses " allow_wtd $op 'Y'"
			  }
		}

		## For each of the related_criteria that are present
		## take them into account when building the query

		foreach criterion $related_criteria {
			if {[string equal $RULE(present,$criterion) Y]} {
				set op $RULE(operator,$criterion)
				switch -- $op {
					"string equal"    {set op "="}
					"!string equal"	  {set op "!="}
				}
				if {$used_where == 0} {
					append qry_clauses " where "
					set used_where 1
				} else {
					append qry_clauses " and "
	  	  	          }
				append qry_clauses "$criterion $op "
				set len [llength $RULE(values,$criterion)]
				if {$len > 1} {
					append qry_clauses "("
				}
				for {set i 0} {$i < $len} {incr i} {
					set value [lindex $RULE(values,$criterion) $i]
					if {[string equal $value "DBT"]} {
						set value "D"
					}
					if {[string equal $value "CDT"]} {
						set value "C"
					}
					regsub -all "'" $value "''" value
					append qry_clauses "'$value'"
					if {$i != [expr $len -1]} {
						append qry_clauses ", "
					}
				}
				if {$len > 1} {
					append qry_clauses ")"
				}
			}
		}
		return $qry_clauses
	}

	## Generate a new card rule

	proc generate_valid_CC_data args {
		global DB
		global UNUSED_CRITERIA
		variable related_criteria
		global RULE
		global CRITERIA_DEF
		global RULE_CLAUSES

		set UNUSED_CRITERIA(nrows) 0
		set RULE_CLAUSES(nrows) 0

		if {[string equal $RULE(present,transaction) N]} {
			set RULE(allowed_values,transaction) "\[\"D\", \"W\"\]"
		}

        	foreach criterion $CRITERIA_DEF(criteria) {

			## If criterion has not already been selected
			## run a query to populate values for that criterion
			## e.g if bank has not been selected so far
			## find the list of available banks based on the
			## criteria selected so far

			if {([string equal $RULE(present,$criterion) N]) && ([string equal $CRITERIA_DEF(qry_based,$criterion) Y])} {
				variable ${criterion}_base_qry
				set ${criterion}_qry [subst $[subst ${criterion}_base_qry]]

				## e.g. available banks will be stored in an array called BANK

				set ARRAY_NAME [string toupper $criterion]
				global [string toupper $criterion]

				if {[lsearch $related_criteria $criterion] != -1} {
					append ${criterion}_qry [generate_qry_clauses 0]

				}
				set stmt [inf_prep_sql $DB [subst $[subst ${criterion}_qry]]]
				if [catch {set rs [inf_exec_stmt $stmt]} msg] {
					err_bind $msg
					set err 1
					return
				}
				set nrows [db_get_nrows $rs]

				## Construct the list as a javascript list

				set RULE(allowed_values,$criterion) "\["
				for {set j 0} {$j < $nrows} {incr j} {
					set data [db_get_coln $rs $j 0]

					## Escape any commas for the javascript

					regsub -all "," $data "\," data
					append RULE(allowed_values,$criterion) "\"$data\""
					if {$j != [expr $nrows -1]} {
						append RULE(allowed_values,$criterion) ","
					}
				}
				append RULE(allowed_values,$criterion) "\]"
				set ${ARRAY_NAME}(nrows) $nrows
				tpBindVar data ${ARRAY_NAME} data data_idx
				db_close $rs
				inf_close_stmt $stmt
			}

			if {[string equal $RULE(present,$criterion) N]} {

				## Allow user to add only the criteria that have
				## not been used in the rule already

				set UNUSED_CRITERIA($UNUSED_CRITERIA(nrows),criterion) $criterion
				incr UNUSED_CRITERIA(nrows)
			} else {

				## If a criterion has been added to the rule already,
				## display the appropriate clause for that criterion

				set RULE_CLAUSES($RULE_CLAUSES(nrows),clause_criterion) $criterion
			 	set operator $RULE(operator,$criterion)
				set RULE_CLAUSES($RULE_CLAUSES(nrows),operator) $operator
				regsub -all "string equal" $operator "=" operator
				regsub -all "==" $operator "=" operator
				regsub -all "in" $operator "is one of" operator
				set values $RULE(values,$criterion)
				if {[string equal $operator "is one of"]} {
					set value_list ""
					for {set i 0} {$i < [llength $values]} {incr i} {
						append value_list [lindex $values $i]

						## Separate list elements with |. bank names
						## contain both spaces and commas

						if {$i != [expr [llength $values] - 1]} {
							append value_list "|"
						}
					}
					set RULE_CLAUSES($RULE_CLAUSES(nrows),values) $value_list
					set RULE_CLAUSES($RULE_CLAUSES(nrows),clause) "$criterion $operator ($value_list)"
				} else {
					if {[string equal $operator "between"]} {
						set value_list ""
						for {set i 0} {$i < [llength $values]} {set i [expr $i + 2]} {
							append value_list "([lindex $values $i] and [lindex $values [expr $i + 1]])"
							if {$i != [expr [llength $values] - 2]} {
								append value_list " or "
							}
						}
						set RULE_CLAUSES($RULE_CLAUSES(nrows),values) $value_list
						set RULE_CLAUSES($RULE_CLAUSES(nrows),clause) "$criterion $operator $value_list"
				  	} else {
						set RULE_CLAUSES($RULE_CLAUSES(nrows),values) [lindex $RULE(values,$criterion) 0]
						set RULE_CLAUSES($RULE_CLAUSES(nrows),clause) "$criterion $operator $RULE(values,$criterion)"
				   	}
				}
				set RULE_CLAUSES($RULE_CLAUSES(nrows),clause_criterion) $criterion
				incr RULE_CLAUSES(nrows)
			  }
        	}
		tpSetVar  num_criteria $UNUSED_CRITERIA(nrows)
		tpBindVar criterion UNUSED_CRITERIA criterion criterion_idx
		tpSetVar num_clauses $RULE_CLAUSES(nrows)
		tpBindVar clause RULE_CLAUSES clause clause_idx
		tpBindVar clause_criterion RULE_CLAUSES clause_criterion clause_idx
		tpBindVar operator  RULE_CLAUSES operator  clause_idx
		tpBindVar values RULE_CLAUSES values clause_idx
		get_valid_pmt_gtwy_info

	}

	proc get_valid_pmt_gtwy_info {} {

		global PMT_GATEWAYS
		global DB

		## Get available payment gateways

		set pg_rule_id [reqGetArg pg_rule_id]

		if {$pg_rule_id == ""} {
			set acct_sql [subst {
				select  pg_acct_id,
					desc,
					pg_type
				from
				tPmtGateAcct
				where status = 'A'
				and pay_mthd = 'CC'
			}]
			set host_sql [subst {
				select  pg_host_id,
					desc
				from
				tPmtGateHost
				where status = 'A'
				and   pg_type = ?
			}]
		} else {
			set acct_sql [subst {
				select a.pg_acct_id,
				       a.desc,
				       a.pg_type,
				       d.percentage
				from   tPmtGateAcct a,
				       outer tPmtRuleDest d
				where  a.status = 'A'
				and    a.pay_mthd = 'CC'
				and    a.pg_acct_id = d.pg_acct_id
				and    d.pg_rule_id = $pg_rule_id
			}]
			set host_sql [subst {
				select h.pg_host_id,
				       h.desc,
				       d.percentage
				from   tPmtGateHost h,
				       outer tPmtRuleDest d
				where  h.status = 'A'
				and    h.pg_host_id = d.pg_host_id
				and    d.pg_rule_id = $pg_rule_id
				and    d.pg_acct_id = ?
				and    h.pg_type = ?
			}]
		 }

		set acct_stmt   [inf_prep_sql $DB $acct_sql]
		set host_stmt   [inf_prep_sql $DB $host_sql]
		set accts  [inf_exec_stmt $acct_stmt]
		inf_close_stmt $acct_stmt

		set numAccts [db_get_nrows $accts]
		set PMT_GATEWAYS(numAccts) $numAccts
		for {set i 0} {$i < $numAccts} {incr i} {
			set PMT_GATEWAYS($i,pg_acct_id) [db_get_col $accts $i pg_acct_id]
			set PMT_GATEWAYS($i,acct_desc)  [db_get_col $accts $i desc]
			set pg_type [db_get_col $accts $i pg_type]

			if {$pg_rule_id == ""} {
				set hosts [inf_exec_stmt $host_stmt $pg_type]
				set PMT_GATEWAYS($i,percentage) [reqGetArg percentage_$PMT_GATEWAYS($i,pg_acct_id)]

			} else {
				set hosts [inf_exec_stmt $host_stmt $PMT_GATEWAYS($i,pg_acct_id) $pg_type]
				set PMT_GATEWAYS($i,percentage) [db_get_col $accts $i percentage]
			  }
			set numHosts [db_get_nrows $hosts]
			set PMT_GATEWAYS($i,numHosts) $numHosts
			set selected_pg_host_id [reqGetArg host_$PMT_GATEWAYS($i,pg_acct_id)]
			for {set j 0} {$j < $numHosts} {incr j} {
				set PMT_GATEWAYS($i,$j,pg_host_id) [db_get_col $hosts $j pg_host_id]
				set PMT_GATEWAYS($i,$j,host_desc) [db_get_col $hosts $j desc]
				if {($pg_rule_id != "") && ([db_get_col $hosts $j percentage] > 0)} {
					set PMT_GATEWAYS($i,$j,selected) "selected"
				} else {
					if {$PMT_GATEWAYS($i,$j,pg_host_id) == $selected_pg_host_id} {
						set PMT_GATEWAYS($i,$j,selected) "selected"
					} else {
						set PMT_GATEWAYS($i,$j,selected) ""
					  }
				  }
			}
		}
		inf_close_stmt $host_stmt

		tpBindVar pg_acct_id PMT_GATEWAYS pg_acct_id acct_idx
		tpBindVar acct_desc  PMT_GATEWAYS acct_desc  acct_idx
		tpBindVar percentage PMT_GATEWAYS percentage acct_idx
		tpBindVar pg_host_id PMT_GATEWAYS pg_host_id acct_idx host_idx
		tpBindVar host_desc  PMT_GATEWAYS host_desc  acct_idx host_idx
		tpBindVar selected   PMT_GATEWAYS selected   acct_idx host_idx
	}


	proc go_pmt_rules args {

		global DB
		global EXISTING_RULES


		if {[info exists EXISTING_RULES]} {
			unset EXISTING_RULES
		}

		## Get list of payment methods

		set sql [subst {
			select pay_mthd,
			       desc
			from   tPayMthd
		}]

		set stmt [inf_prep_sql $DB $sql]
		set pay_mthds [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set numMthds [db_get_nrows $pay_mthds]
		set EXISTING_RULES(numMthds) $numMthds

		for {set i 0} {$i < $numMthds} {incr i} {
			## Get list of Rules for this pay_mthd

			set pay_mthd [db_get_col $pay_mthds $i pay_mthd]
			set EXISTING_RULES($i,pay_mthd) $pay_mthd

			set EXISTING_RULES($i,desc) [db_get_col $pay_mthds $i desc]

			set sql [subst {
				select
				c.pg_rule_id,
				c.priority,
				c.status,
				c.condition_desc,
				c.condition_tcl_1,
				c.condition_tcl_2,
				c.pay_mthd
				from
				tPmtGateChoose c,
				tPayMthd m
				where c.pay_mthd   = m.pay_mthd
				and   m.pay_mthd   = '$pay_mthd'
				order by
		 		c.pay_mthd, c.priority
			}]

			set stmt   [inf_prep_sql $DB $sql]
			set rules  [inf_exec_stmt $stmt]

			inf_close_stmt $stmt

			set numRules [db_get_nrows $rules]
			set EXISTING_RULES($i,numRules) $numRules

			for {set j 0} {$j < $numRules} {incr j} {
				set EXISTING_RULES($i,$j,pg_rule_id)     [db_get_col $rules $j pg_rule_id]
				set EXISTING_RULES($i,$j,priority)       [db_get_col $rules $j priority]
				set EXISTING_RULES($i,$j,status)         [db_get_col $rules $j status]
				set EXISTING_RULES($i,$j,condition_desc) [db_get_col $rules $j condition_desc]
			}

		}
		tpBindVar pay_mthd       EXISTING_RULES pay_mthd       pay_mthd_idx
		tpBindVar pay_mthd_desc  EXISTING_RULES desc 	       pay_mthd_idx
		tpBindVar pg_rule_id     EXISTING_RULES pg_rule_id     pay_mthd_idx rule_idx
		tpBindVar priority       EXISTING_RULES priority       pay_mthd_idx rule_idx
		tpBindVar status         EXISTING_RULES status         pay_mthd_idx rule_idx
		tpBindVar condition_desc EXISTING_RULES condition_desc pay_mthd_idx rule_idx

		asPlayFile -nocache pmt/pmt_rules.html

		db_close $rules
	}

	proc get_existing_CC_rule_clauses args {
		global CRITERIA_DEF
		global RULE


		set toRemove [reqGetArg toRemove]
		if {[string equal $toRemove "card_bin"]} {
			tpSetVar check_bins 0
		}
		set rule_name [reqGetArg name]

		set RULE(numPresent) 0
        	foreach criterion $CRITERIA_DEF(criteria) {
			set present [reqGetArg $criterion]

			## If user wants to remove a clause
			## do not process it in this function

			if {($present != "") && ($criterion != $toRemove)} {
				incr RULE(numPresent)
				set RULE(present,$criterion) "Y"
				set RULE(operator,$criterion) [reqGetArg operator_$criterion]
				if {[string equal $RULE(operator,$criterion) "between"]} {
					set RULE(values,$criterion) [list]
					set value_pairs [split [reqGetArg values_$criterion] "or"]
					foreach value_pair $value_pairs {
						if {![string equal $value_pair ""]} {
							set value_pair [string trim $value_pair " ()"]
							set values [split $value_pair "and"]
							foreach value $values {
								if {![string equal $value ""]} {
									set value [string trim $value]
									lappend RULE(values,$criterion) $value
								}
							}
						}
					}

				} else {
					set RULE(values,$criterion) [split [reqGetArg values_$criterion] "|"]
				  }
			} else {
				set RULE(present,$criterion) "N"
			  }
		}
		tpBindString rule_name $rule_name
	}

	proc go_add_CC_rule_clause args {
		global RULE
		global CRITERIA_DEF
		global PMT_GATEWAYS

		clear_arrays

		## Get existing rule clauses

		get_existing_CC_rule_clauses

		## Get the new rule clause

		set criterion  [reqGetArg criterion]
		if {$criterion != ""} {
			set RULE(present,$criterion) "Y"
			set rule_name  [reqGetArg name]
			set operator   [reqGetArg operator]
			set RULE(operator,$criterion) $operator
			if {![string equal $criterion "card_bin"]} {
				if {[string equal $CRITERIA_DEF(data_type,[reqGetArg criterion]) "S"]} {
					set RULE(values,$criterion) [split [reqGetArg value_list] |]
				} else {
					set RULE(values,$criterion) [reqGetArg value]
		  	  	}
			} else {
				if {[lsearch {in between} $operator] == -1} {
					set RULE(values,$criterion) [reqGetArg value]
				} else {
					set RULE(values,$criterion) [split [reqGetArg bin_list] |]
				  }
			  }
		}
		generate_valid_CC_data

		## We may be adding this clause to an existing rule

		tpSetVar existing_rule [reqGetArg existing_rule]
		tpBindString pg_rule_id [reqGetArg pg_rule_id]
		tpSetVar status [reqGetArg status]

		if {[string equal $criterion "card_bin"]} {
			tpSetVar check_bins 1
		}

		asPlayFile -nocache pmt/pmt_edit_rule.html
	}

	proc go_add_rule args {
		global RULE
		global CRITERIA_DEF

		set pay_mthd [reqGetArg NewRuleMthd]

		switch -- $pay_mthd {
			CC	{go_add_CC_rule_clause}
			default {}
		}
	}

	proc go_remove_CC_rule_clause args {
		global RULE
		global CRITERIA_DEF
		global PMT_GATEWAYS

		clear_arrays
		get_existing_CC_rule_clauses
		generate_valid_CC_data

		## We may be removing clause from an existing rule

		tpSetVar existing_rule [reqGetArg existing_rule]
		tpBindString pg_rule_id [reqGetArg pg_rule_id]
		tpSetVar status [reqGetArg status]

		asPlayFile -nocache pmt/pmt_edit_rule.html
	}

	proc check_card_bins args {
		global RULE
		global WARNING
		global DB
		global CRITERIA_DEF
		global UNUSED_CRITERIA
		global RULE_CLAUES
		global PMT_GATEWAYS
		variable card_bin_exists
		variable num_bins

		set WARNING(nrows) 0

		## Make sure we actually know something about each range

		set operator $RULE(operator,card_bin)
		if {[string equal $operator "between"]} {
			set num_pairs [expr {[llength $RULE(values,card_bin)] / 2}]
			foreach {bin_lo bin_hi} $RULE(values,card_bin) {
				set exists_qry "$card_bin_exists where card_bin >= $bin_lo and card_bin <= $bin_hi"

				set exists_stmt [inf_prep_sql $DB $exists_qry]
				if [catch {set rs [inf_exec_stmt $exists_stmt]} msg] {
					err_bind $msg
					set err 1
					return
				}
				set nrows [db_get_nrows $rs]
				db_close $rs
				inf_close_stmt $exists_stmt
				if {$nrows == 0} {
					set WARNING($WARNING(nrows),msg) "There is no information available for any card bin in the range $bin_lo - $bin_hi"
					incr WARNING(nrows)
				} else {
					set count_qry "$num_bins where card_bin >= $bin_lo and card_bin <= $bin_hi"
					set count_stmt [inf_prep_sql $DB $count_qry]

					set relevant_count_qry $count_qry
					append relevant_count_qry [generate_qry_clauses 1]
					set relevant_count_stmt [inf_prep_sql $DB $relevant_count_qry]

					if [catch {set rs [inf_exec_stmt $count_stmt]} msg] {
						err_bind $msg
						set err 1
						return
					}
					set count [db_get_coln $rs 0 0]
					db_close $rs
					inf_close_stmt $count_stmt

					if [catch {set rs [inf_exec_stmt $relevant_count_stmt]} msg] {
						err_bind $msg
						set err 1
						return
					}
					set relevant_count [db_get_coln $rs 0 0]
					db_close $rs
					inf_close_stmt $relevant_count_stmt

					if {$relevant_count == 0} {
						set WARNING($WARNING(nrows),msg) "None of the card bins in the range $bin_lo - $bin_hi match the other criteria you have specified."
						incr WARNING(nrows)
					} elseif {$relevant_count != $count} {
						set WARNING($WARNING(nrows),msg) "Some of the card bins in the range $bin_lo - $bin_hi do not match the other criteria you have specified."
						incr WARNING(nrows)
					  }
			  	}
			}
		} else {
			set stop 0
		  	regsub "==" $operator "=" operator
			set values [join $RULE(values,card_bin) ","]
			if {[string equal $operator "in"]} {
				set values "($values)"
			}
			set count_qry "$num_bins where card_bin $operator $values"
			set count 1
			if {[lsearch {=} $operator] != -1} {
				set exists_qry "$card_bin_exists where card_bin $operator $values"

				set exists_stmt [inf_prep_sql $DB $exists_qry]
				if [catch {set rs [inf_exec_stmt $exists_stmt]} msg] {
					err_bind $msg
					set err 1
					return
				}
				set nrows [db_get_nrows $rs]
				db_close $rs
				inf_close_stmt $exists_stmt
				if {$nrows == 0} {
					set WARNING($WARNING(nrows),msg) "There is no information available for any card bin(s) $operator $values"
					incr WARNING(nrows)
					set stop 1
		    		}
			} else {
				if {[string equal $operator "in"]} {
					set num_in_list [llength $RULE(values,card_bin)]
				}
				set count_stmt [inf_prep_sql $DB $count_qry]
				if [catch {set rs [inf_exec_stmt $count_stmt]} msg] {
					err_bind $msg
					set err 1
					return
				}
				set count [db_get_coln $rs 0 0]
				db_close $rs
				inf_close_stmt $count_stmt
				if {$count == 0} {
					set WARNING($WARNING(nrows),msg) "There is no information available for any card bin $operator $values"
					incr WARNING(nrows)
		    		} elseif {[string equal $operator "in"] && $num_in_list != $count} {
					set WARNING($WARNING(nrows),msg) "There is no information available for some card bin(s) in $values"
					incr WARNING(nrows)
		    	  	}
				set stop 1
			  }
			if {!$stop} {
				set relevant_count_qry $count_qry
				append relevant_count_qry [generate_qry_clauses 1]
				set relevant_count_stmt [inf_prep_sql $DB $relevant_count_qry]
				if [catch {set rs [inf_exec_stmt $relevant_count_stmt]} msg] {
					err_bind $msg
					set err 1
					return
				}
				set relevant_count [db_get_coln $rs 0 0]
				db_close $rs
				inf_close_stmt $relevant_count_stmt

				if {$relevant_count == 0} {
					if {[lsearch {=} $operator] != -1} {
						set WARNING($WARNING(nrows),msg) "The card_bin clause does not match the other criteria you have specified."
					} else {
						set WARNING($WARNING(nrows),msg) "None of the card bins $operator $values match the other criteria you have specified."
					  }
					incr WARNING(nrows)
				} elseif {$relevant_count != $count} {
					set WARNING($WARNING(nrows),msg) "Some of the card bins $operator $values do not match the other criteria you have specified."
					incr WARNING(nrows)
			  	}
			}
		  }
		if {$WARNING(nrows) > 0} {
			generate_valid_CC_data

			tpSetVar num_warning_msgs $WARNING(nrows)
			tpBindVar msg WARNING msg msg_idx

			tpSetVar existing_rule [reqGetArg existing_rule]
			tpBindString pg_rule_id [reqGetArg pg_rule_id]
			tpSetVar check_bins 0
			tpSetVar status [reqGetArg status]

			asPlayFile -nocache pmt/pmt_edit_rule.html
		} else {
			## If there are no warnings then add/update the rule
			set pg_rule_id [reqGetArg pg_rule_id]
			if {$pg_rule_id != ""} {
				upd_CC_rule_in_database
			} else {
				insert_CC_rule_into_database
			  }
		  }
	}

	proc go_add_CC_rule args {
		global RULE

		clear_arrays
		get_existing_CC_rule_clauses
		if {[string equal $RULE(present,card_bin) "Y"] && [reqGetArg check_bins]} {
			check_card_bins
		} else {
			insert_CC_rule_into_database
		  }
	}

	proc go_upd_CC_rule args {
		global RULE

		clear_arrays
		get_existing_CC_rule_clauses
		if {[string equal $RULE(present,card_bin) "Y"] && [reqGetArg check_bins]} {
			check_card_bins
		} else {
			upd_CC_rule_in_database
	          }
	}

	proc go_suspend_CC_rule args {
		suspend_CC_rule
		go_pmt_rules
	}

	proc go_activate_CC_rule args {
		activate_CC_rule
		go_pmt_rules
	}

	proc upd_CC_rule_in_database args {
		global DB
		global WARNING
		global PMT_GATEWAYS
		global RULE
		global CRITERIA_DEF

		set selected_accts [reqGetArg selected_accts]
		set accts [split $selected_accts]

		set pg_rule_id [reqGetArg pg_rule_id]
		set condition_tcl [construct_rule]
		set WARNING(nrows) 0
		if {[string length $condition_tcl] > 512} {
			set WARNING($WARNING(nrows),msg) "The rule is too long."
			incr WARNING(nrows)
			tpSetVar tooLong 1

			generate_valid_CC_data
			tpSetVar num_warning_msgs $WARNING(nrows)
			tpBindVar msg WARNING msg msg_idx
			tpSetVar existing_rule [reqGetArg existing_rule]
			tpBindString pg_rule_id [reqGetArg pg_rule_id]
			tpSetVar check_bins 0
			tpSetVar status [reqGetArg status]

			asPlayFile -nocache pmt/pmt_edit_rule.html
			return
		}
		tpSetVar tooLong 0

		if {[catch { set condition_tcl_parts [split_to_pieces 255 $condition_tcl 2 N]  } msg]} {

			set WARNING($WARNING(nrows),msg) $msg
			incr WARNING(nrows)

			generate_valid_CC_data
			tpSetVar num_warning_msgs $WARNING(nrows)
			tpBindVar msg WARNING msg msg_idx
			tpSetVar existing_rule [reqGetArg existing_rule]
			tpBindString pg_rule_id [reqGetArg pg_rule_id]
			tpSetVar check_bins 0
			tpSetVar status [reqGetArg status]

			asPlayFile -nocache pmt/pmt_edit_rule.html
			return
		}


		set condition_tcl_1 [lindex $condition_tcl_parts 0]

		set condition_tcl_2 [lindex $condition_tcl_parts 1]

		set condition_desc [reqGetArg name]

		set upd_rule [subst {
			update tPmtGateChoose
			set condition_desc='$condition_desc',
			    condition_tcl_1='$condition_tcl_1',
			    condition_tcl_2='$condition_tcl_2',
			    pay_mthd='CC'
			where pg_rule_id = $pg_rule_id
		}]

		set delete_rule_dests [subst {
			delete from tPmtRuleDest
			where pg_rule_id = $pg_rule_id
		}]

		set rule_dests [subst {
				insert into tPmtRuleDest(pg_rule_id,pg_acct_id,pg_host_id,percentage)\
				values(?,?,?,?)
		}]


		if [catch {inf_begin_tran $DB} msg] {
			OT_LogWrite 1 "Failed to start Transaction: $msg"
			return
		}

		set stmt_upd_rule           [inf_prep_sql $DB $upd_rule]
		set stmt_delete_rule_dests  [inf_prep_sql $DB $delete_rule_dests]
		set stmt_rule_dests  	    [inf_prep_sql $DB $rule_dests]

		set c [catch {
			inf_exec_stmt $stmt_upd_rule
			inf_exec_stmt $stmt_delete_rule_dests
			foreach pg_acct_id $accts {
				if {$pg_acct_id != ""} {
					set percentage [reqGetArg percentage_$pg_acct_id]
					set pg_host_id [reqGetArg host_$pg_acct_id]
					inf_exec_stmt $stmt_rule_dests\
						      $pg_rule_id\
						      $pg_acct_id\
						      $pg_host_id\
						      $percentage
				}
			}
		} msg]

		inf_close_stmt $stmt_upd_rule
		inf_close_stmt $stmt_delete_rule_dests
		inf_close_stmt $stmt_rule_dests

		if {$c == 0} {
			inf_commit_tran $DB
		} else {
			inf_rollback_tran $DB
			err_bind $msg
		  }
		go_pmt_rules
	}

	proc suspend_CC_rule args {
		global DB

		set pg_rule_id [reqGetArg pg_rule_id]

		set get_priority [subst {
				select priority
				from   tPmtGateChoose
				where  pg_rule_id = $pg_rule_id
		}]

		set get_min_priority [subst {
				select min(priority) as min_priority
				from   tPmtGateChoose
		}]

		set suspend_rule [subst {
				update tPmtGateChoose
				set status = 'S',
				    priority = ?
				where pg_rule_id = $pg_rule_id
		}]


		set update_priorities [subst {
					update tPmtGateChoose
					set priority = priority - 1
					where pay_mthd = 'CC'
					and priority > ?
		}]

		if [catch {inf_begin_tran $DB} msg] {
			OT_LogWrite 1 "Failed to start transaction: $msg"
			return
		}

		set stmt_get_priority      [inf_prep_sql $DB $get_priority]
		set stmt_get_min_priority  [inf_prep_sql $DB $get_min_priority]
		set stmt_suspend_rule	   [inf_prep_sql $DB $suspend_rule]
		set stmt_update_priorities [inf_prep_sql $DB $update_priorities]

		set c [catch {
			set rs [inf_exec_stmt $stmt_get_priority]
			set priority [db_get_col $rs 0 priority]
			db_close $rs
			set rs [inf_exec_stmt $stmt_get_min_priority]
			set min_priority [db_get_col $rs 0 min_priority]
			db_close $rs
			if {$min_priority == 1} {
				set suspended_priority -1
			} else {
				set suspended_priority [expr $min_priority - 1]
 			  }
			inf_exec_stmt $stmt_suspend_rule $suspended_priority
			inf_exec_stmt $stmt_update_priorities $priority
		} msg]

		inf_close_stmt $stmt_get_priority
		inf_close_stmt $stmt_suspend_rule
		inf_close_stmt $stmt_update_priorities

		if {$c == 0} {
			inf_commit_tran $DB
		} else {
			inf_rollback_tran $DB
			err_bind $msg
		  }

	}

	proc activate_CC_rule args {
		global DB

		set pg_rule_id [reqGetArg pg_rule_id]

		set get_max_priority [subst {
				select max(priority) priority
				from   tPmtGateChoose
		}]

		set activate_rule [subst {
				update tPmtGateChoose
				set status = 'A',
				    priority = ?
				where pg_rule_id = $pg_rule_id
		}]



		if [catch {inf_begin_tran $DB} msg] {
			OT_LogWrite 1 "Failed to start transaction: $msg"
			return
		}

		set stmt_get_max_priority  [inf_prep_sql $DB $get_max_priority]
		set stmt_activate_rule	   [inf_prep_sql $DB $activate_rule]

		set c [catch {
			set rs [inf_exec_stmt $stmt_get_max_priority]
			set max_priority [db_get_col $rs 0 priority]
			set new_priority [expr $max_priority + 1]
			db_close $rs
			inf_exec_stmt $stmt_activate_rule $new_priority
		} msg]

		inf_close_stmt $stmt_get_max_priority
		inf_close_stmt $stmt_activate_rule

		if {$c == 0} {
			inf_commit_tran $DB
		} else {
			inf_rollback_tran $DB
			err_bind $msg
		  }

	}

	proc insert_CC_rule_into_database args {
		global DB
		global PMT_GATEWAYS
		global RULE
		global CRITERIA_DEF

		set selected_accts [reqGetArg selected_accts]
		set accts [split $selected_accts]

		set priority_sql [subst {
					select max(priority)
					from   tPmtGateChoose
					where  pay_mthd = 'CC'
		}]

		set stmt [inf_prep_sql $DB $priority_sql]

		if [catch {set rs [inf_exec_stmt $stmt]} msg] {
			err_bind $msg
			set err 1
			return
		}

		set max_priority [db_get_coln $rs 0 0 ]
		db_close $rs
		inf_close_stmt $stmt

		set priority [expr $max_priority + 1]
		set condition_tcl  [construct_rule]
		set WARNING(nrows) 0
		if {[string length $condition_tcl] > 512} {
			set WARNING($WARNING(nrows),msg) "The rule is too long."
			incr WARNING(nrows)
			tpSetVar tooLong 1

			generate_valid_CC_data
			tpSetVar num_warning_msgs $WARNING(nrows)
			tpBindVar msg WARNING msg msg_idx
			tpSetVar existing_rule [reqGetArg existing_rule]
			tpBindString pg_rule_id [reqGetArg pg_rule_id]
			tpSetVar check_bins 0
			tpSetVar status [reqGetArg status]

			asPlayFile -nocache pmt/pmt_edit_rule.html
			return

		}
		tpSetVar tooLong 0

		if {[catch { set condition_tcl_parts [split_to_pieces 255 $condition_tcl 2 N]  } msg]} {

			set WARNING($WARNING(nrows),msg) $msg
			incr WARNING(nrows)

			generate_valid_CC_data
			tpSetVar num_warning_msgs $WARNING(nrows)
			tpBindVar msg WARNING msg msg_idx
			tpSetVar existing_rule [reqGetArg existing_rule]
			tpBindString pg_rule_id [reqGetArg pg_rule_id]
			tpSetVar check_bins 0
			tpSetVar status [reqGetArg status]
			asPlayFile -nocache pmt/pmt_edit_rule.html
			return
		}


		set condition_tcl_1 [lindex $condition_tcl_parts 0]

		set condition_tcl_2 [lindex $condition_tcl_parts 1]

		set condition_desc [reqGetArg name]

		set rule [subst {
				insert into tPmtGateChoose(priority,condition_desc,condition_tcl_1,condition_tcl_2,pay_mthd)\
				values($priority,'$condition_desc','$condition_tcl_1','$condition_tcl_2','CC')
		}]

		set get_rule_id [subst {
				select pg_rule_id
				from   tPmtGateChoose
				where  priority = '$priority'
				and    pay_mthd = 'CC'
		}]

		set rule_dest [subst {
				insert into tPmtRuleDest(pg_rule_id,pg_acct_id,pg_host_id,percentage)\
				values(?,?,?,?)
		}]

		if [catch {inf_begin_tran $DB} msg] {
			OT_LogWrite 1 "Failed to start Transaction: $msg"
			return
		}

		set stmt_rule [inf_prep_sql $DB $rule]
		set stmt_get_rule_id [inf_prep_sql $DB $get_rule_id]
		set stmt_rule_dests [inf_prep_sql $DB $rule_dest]

		set c [catch {
			inf_exec_stmt $stmt_rule
			set rs [inf_exec_stmt $stmt_get_rule_id]
			set pg_rule_id [db_get_col $rs 0 pg_rule_id]
			catch {db_close $rs}
			foreach pg_acct_id $accts {
				if {$pg_acct_id != ""} {
					set percentage [reqGetArg percentage_$pg_acct_id]
					set pg_host_id [reqGetArg host_$pg_acct_id]
					inf_exec_stmt $stmt_rule_dests\
						      $pg_rule_id\
						      $pg_acct_id\
						      $pg_host_id\
						      $percentage
				}
			}
		} msg]

		inf_close_stmt $stmt_rule
		inf_close_stmt $stmt_get_rule_id
		inf_close_stmt $stmt_rule_dests

		if {$c == 0} {
			inf_commit_tran $DB
		} else {
			inf_rollback_tran $DB
			err_bind $msg
		  }
		go_pmt_rules
	}


	proc construct_card_bin_between_clause {} {
		global RULE

		## Deal with card_bin clause
		set num_pairs [expr [llength $RULE(values,card_bin)] / 2]
		set rule_clause "("
		set pair 0
		foreach {bin_lo bin_hi} $RULE(values,card_bin) {
			append rule_clause "(\[expr \{\$card_bin >= $bin_lo\}\] && \[expr \{\$card_bin <= $bin_hi\}\])"
			if {$pair < [expr {$num_pairs -1}]} {
				append rule_clause " || "
			}
			incr pair
		}
		append rule_clause ")"
		return $rule_clause
	}

	## This procedure builds condition_tcl for tPmtGateChoose based on
	## the contents of the RULE array

	proc construct_rule args {
		global RULE
		global CRITERIA_DEF

		set rule ""
		if {$RULE(numPresent) > 1} {
			append rule "expr \{"
		}
		set criterion_num 0
		foreach criterion $CRITERIA_DEF(criteria) {
			if {[string equal $RULE(present,$criterion) "Y"]} {
				if {$RULE(numPresent) > 1} {
					append rule "\["
				}

				## If the list has only one item do an equals operation not an in

				set num_values [llength $RULE(values,$criterion)]
				## escape any ' characters

				regsub -all "'" $RULE(values,$criterion) "''" RULE(values,$criterion)
				if {$num_values == 1} {
					if {[string equal $RULE(operator,$criterion) "in"]} {
						switch -- $CRITERIA_DEF(data_type,$criterion) {
							"S" {set RULE(operator,$criterion) "string equal"}
							"N" {set RULE(operator,$criterion) "=="}
						}
					}
				}
				switch -glob $RULE(operator,$criterion) {
					"*string equal" {append rule "expr \{\[string equal "}
					"in" {append rule "expr \{\[lsearch "}
					"between" {}
					default {append rule "expr \{"}
				}
				switch -- $criterion {
					"transaction" {set var "\$pay_sort "}
					"scheme" {set var "\$card_scheme"}
					"currency" {set var "\$ccy_code "}
					"between" {}
					default {set var "\$$criterion "}
				}
				switch -- $RULE(operator,$criterion) {
					"string equal"  {append rule "$var $RULE(values,$criterion)] == 1\}"}
					"!string equal"  {append rule "$var $RULE(values,$criterion)] != 1\}"}
					"in" {append rule "{$RULE(values,$criterion)} $var] != -1\}"}
					"between" {append rule [construct_card_bin_between_clause]}
					default {append rule "$var $RULE(operator,$criterion) {$RULE(values,$criterion)}\}"}
				}
				if {$RULE(numPresent) > 1} {
					append rule "\]"
				}
				if {$criterion_num != [expr $RULE(numPresent) - 1]} {
					append rule " && "
				}
				incr criterion_num
			}

		}
		if {$RULE(numPresent) > 1} {
			append rule "\}"
		}
		return $rule
	}

	proc deconstruct_rule {rule} {
		global RULE
		global CRITERIA_DEF

		set rule [string trimleft $rule "expr \{"]
		regsub "\}\$" $rule "" rule


		## First deal with the card_bin clause if it exists

		set begin [string first "((" $rule]
		set end   [string last "))" $rule]

		if {$begin != -1 && $end != -1} {
			## We have a card_bin clause

			set RULE(present,card_bin) "Y"
			set RULE(operator,card_bin) "between"
			set RULE(values,card_bin) [list]
			set card_bin_clause [string range $rule $begin $end]
			set card_bin_clause [string trimleft $card_bin_clause "("]
			set card_bin_clause [string trimright $card_bin_clause ")"]
			set rule [string range $rule 0 [expr $begin - 1]]
			set rule [string trimright $rule " &"]

			## Process card_bin clause
			set card_bin_pairs [split $card_bin_clause "||"]
			foreach pair $card_bin_pairs {
				if {$pair != ""} {
					set pair [string trim $pair "()"]
					set card_bins [split $pair "&&"]
					foreach card_bin $card_bins {
						if {$card_bin != ""} {
							regexp {(\d{6})} $card_bin match card_bin
							lappend RULE(values,card_bin) $card_bin
						}
					}
				}
			}
		}

		## We are going to split the rule on &&
		## so first we need to replace any instances of & in country or bank names with
		## a sequence of characters that is unlikely to feature in a country or bank name
		## so that the rule doesn't split on single &s

		regsub -all {([^&])&([^&])} $rule "\\1%~@\\2" rule
		set rule_clauses [split $rule "&&"]
		regsub -all "%~@" $rule_clauses "\\&" rule_clauses
		foreach clause $rule_clauses {
			if {$clause != ""} {
				set clause [string trim $clause]
				if {[regsub  {^\[expr \{} $clause "" clause]} {
					regsub  {\}\]$} $clause "" clause
				}
				if {[string first "\[lsearch " $clause] != -1} {
					set clause [string trimleft $clause "\[lsearch "]
					set clause [string trimright $clause "\] != -1"]
					set operator "in"
					set values [string range $clause [expr [string first "\{" $clause]+1] [expr [string last "\}" $clause]-1]]
					set var [string range $clause [expr [string last "\}" $clause] + 2] [string length $clause]]
			   	} elseif {[string first "\[string equal " $clause] != -1} {
					set clause [string trimleft $clause "\[string equal "]
					set clause [string trimright $clause " 1\}"]
					regsub -all "]" $clause "" clause
					set var [lindex $clause 0]
					set values "\"[lindex $clause 1]\""
					set op [lindex $clause 2]
					switch -- $op {
						"=="    {set operator "string equal"}
						"!="	{set operator "!string equal"}
					}
			   	} else {
					set var [lindex $clause 0]
					set operator [lindex $clause 1]
					set values [lindex $clause 2]
			     	}
			   	set var [string trimleft $var "\$"]
			   	switch -- $var {
			   		"pay_sort"	{set criterion "transaction"}
					"card_scheme"   {set criterion "scheme"}
					"ccy_code"      {set criterion "currency"}
					default		{set criterion $var}
			   	}
			   	set RULE(present,$criterion) "Y"
			   	set RULE(operator,$criterion) $operator
			    set RULE(values,$criterion) $values
			   }
		}

	}

	proc go_CC_rule args {
		global DB
		global RULE
		global CRITERIA_DEF
		global PMT_GATEWAYS

		set pg_rule_id [reqGetArg pg_rule_id]
		set sql [subst {
				select  condition_desc,
						condition_tcl_1,
						condition_tcl_2
				from    tPmtGateChoose
				where 	pg_rule_id = $pg_rule_id
		}]
		set stmt [inf_prep_sql $DB $sql]
		if [catch {set rs [inf_exec_stmt $stmt]} msg] {
			err_bind $msg
			set err 1
			return
		}
		inf_close_stmt $stmt
		set condition_tcl [db_get_col $rs 0 condition_tcl_1]
		append condition_tcl [db_get_col $rs 0 condition_tcl_2]
		deconstruct_rule $condition_tcl
		tpBindString rule_name [db_get_col $rs 0 condition_desc]
		db_close $rs
		set sql [subst {
				select  pg_acct_id,
					pg_host_id,
					percentage
				from    tPmtRuleDest
				where 	pg_rule_id = $pg_rule_id
		}]
		set stmt [inf_prep_sql $DB $sql]
		if [catch {set rs [inf_exec_stmt $stmt]} msg] {
			err_bind $msg
			set err 1
			return
		}
		inf_close_stmt $stmt
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			tpSetVar percentage_[db_get_col $rs $i pg_acct_id] [db_get_col $rs $i percentage]
			tpSetVar host_[db_get_col $rs $i pg_acct_id] [db_get_col $rs $i pg_host_id]
		}
		generate_valid_CC_data
		tpSetVar existing_rule "Y"
		tpBindString pg_rule_id [reqGetArg pg_rule_id]
		tpSetVar status [reqGetArg status]

		asPlayFile -nocache pmt/pmt_edit_rule.html
	}

	proc go_rule args {
		clear_arrays
		get_existing_CC_rule_clauses
		set pay_mthd [reqGetArg pay_mthd]
		switch -- $pay_mthd {
			CC	{go_CC_rule}
			default {}
		}
	}

	proc go_up_priority args {
		global DB

		set pg_rule_id [reqGetArg pg_rule_id]

		set get_rule_info [subst {
					select priority,
					       pay_mthd
					from   tPmtGateChoose
					where  pg_rule_id = $pg_rule_id
		}]

		set get_max_priority [subst {
					select max(priority)
					from   tPmtGateChoose
					where  pay_mthd = ?
		}]

		set update_rule [subst {
					update tPmtGateChoose
					set    priority = ?
					where  priority = ?
					and    pay_mthd = ?
		}]

		if [catch {inf_begin_tran $DB} msg] {
			OT_LogWrite 1 "Failed to start Transaction: $msg"
			return
		}

		set get_rule_info_stmt    [inf_prep_sql $DB $get_rule_info]
		set get_max_priority_stmt [inf_prep_sql $DB $get_max_priority]
		set update_rule_stmt      [inf_prep_sql $DB $update_rule]

		set c [catch {
			set rs [inf_exec_stmt $get_rule_info_stmt]
			set priority [db_get_col $rs 0 priority]
			set pay_mthd [db_get_col $rs 0 pay_mthd]
			db_close $rs
			set rs [inf_exec_stmt $get_max_priority_stmt $pay_mthd]
			set max_priority [db_get_coln $rs 0 0]
			db_close $rs
			set tmp_priority [expr $max_priority + 1]
			inf_exec_stmt $update_rule_stmt $tmp_priority $priority $pay_mthd
			inf_exec_stmt $update_rule_stmt $priority [expr $priority - 1] $pay_mthd
			inf_exec_stmt $update_rule_stmt [expr $priority - 1] $tmp_priority $pay_mthd
		} msg]

		inf_close_stmt $get_rule_info_stmt
		inf_close_stmt $get_max_priority_stmt
		inf_close_stmt $update_rule_stmt

		if {$c == 0} {
			inf_commit_tran $DB
		} else {
			inf_rollback_tran $DB
			err_bind $msg
		  }
		go_pmt_rules
	}

	proc go_view_hist args {

        global DB
		global DATES

		set pay_mthd [reqGetArg pay_mthd]


        set get_rule_hist_dates [subst {
                    select distinct(aud_time)
                    from   tPmtGateChoose_AUD
                    where  pay_mthd = '$pay_mthd'
					and    pg_rule_id is not null
					order  by aud_time
        }]

        set stmt    [inf_prep_sql $DB $get_rule_hist_dates]
        if [catch {set rs [inf_exec_stmt $stmt]} msg] {
            err_bind $msg
            set err 1
            return
        }
        inf_close_stmt $stmt
		set nrows [db_get_nrows $rs]
        for {set i 0} {$i < $nrows} {incr i} {
            set DATES($i,change_date) [db_get_col $rs $i aud_time]
        }

		tpSetVar pay_mthd $pay_mthd
		tpBindString pay_mthd $pay_mthd
        tpSetVar num_dates $nrows
        tpBindVar change_date DATES change_date date_idx

        asPlayFile -nocache pmt/pmt_rule_hist.html
    }

	proc go_rules_at_date args {
		global DB
		global RULES

		set pay_mthd [reqGetArg pay_mthd]
		set change_date [reqGetArg change_date]

        set get_rules_at_date [subst {
                    select  pg_rule_id,
							priority,
							status,
							condition_desc
                    from    tPmtGateChoose_AUD a
                    where   pay_mthd = '$pay_mthd'
					and     pg_rule_id is not null
					and   	aud_time =
								(select max(aud_time)
								 from tPmtGateChoose_AUD b
								 where aud_time <= '$change_date'
							     and a.pg_rule_id = b.pg_rule_id
								)
					and    aud_op != 'D'
					and    aud_order = (
								select max(aud_order)
								from tPmtGateChoose_AUD c
								where a.pg_rule_id = c.pg_rule_id
								and a.aud_time = c.aud_time
								)
					order  by priority
        }]

        set stmt    [inf_prep_sql $DB $get_rules_at_date]
        if [catch {set rs [inf_exec_stmt $stmt]} msg] {
            err_bind $msg
            set err 1
            return
        }
        inf_close_stmt $stmt
		set num_rules_at_date [db_get_nrows $rs]
		for {set i 0} {$i < $num_rules_at_date} {incr i} {
            set RULES($i,pg_rule_id)     [db_get_col $rs $i pg_rule_id]
            set RULES($i,priority)       [db_get_col $rs $i priority]
            set RULES($i,status)         [db_get_col $rs $i status]
            set RULES($i,condition_desc) [db_get_col $rs $i condition_desc]
        }

		tpSetVar pay_mthd $pay_mthd
		tpBindString pay_mthd $pay_mthd
		tpBindString change_date $change_date
		tpSetVar change_date $change_date
        tpSetVar num_rules $num_rules_at_date
        tpBindVar pg_rule_id      RULES pg_rule_id     rule_idx
        tpBindVar priority        RULES priority       rule_idx
        tpBindVar status          RULES status         rule_idx
        tpBindVar condition_desc  RULES condition_desc rule_idx

        asPlayFile -nocache pmt/pmt_rules_at_date.html

	}

	proc go_rule_at_date args {
		global DB
		global RULE
		global ACCTS
		global CRITERIA_DEF

		clear_arrays
		get_existing_CC_rule_clauses

		set pay_mthd [reqGetArg pay_mthd]
		set change_date [reqGetArg change_date]
		set pg_rule_id [reqGetArg pg_rule_id]

        set get_rule_at_date [subst {
				select      priority,
							status,
							condition_desc,
							condition_tcl_1,
                            condition_tcl_2
                    from    tPmtGateChoose_AUD a
                    where   pay_mthd = '$pay_mthd'
                    and     pg_rule_id = $pg_rule_id
                    and     aud_time =
								(select max(aud_time)
								 from tPmtGateChoose_AUD
								 where pg_rule_id = $pg_rule_id
								 and   aud_time <= '$change_date'
								)
					and    aud_order = (
								select max(aud_order)
								from tPmtGateChoose_AUD b
								where a.pg_rule_id = b.pg_rule_id
								and a.aud_time = b.aud_time
								)
					and     aud_op != 'D'

        }]

        set stmt    [inf_prep_sql $DB $get_rule_at_date]
        if [catch {set rs [inf_exec_stmt $stmt]} msg] {
            err_bind $msg
            set err 1
            return
        }
        inf_close_stmt $stmt
		set nrows [db_get_nrows $rs]
		if {$nrows != 1} {
				OT_LogWrite 1 "get_rule_at_date: failed to retrieve changed rule"
				return
		}

        set condition_tcl   [db_get_col $rs 0 condition_tcl_1]
        append  condition_tcl   [db_get_col $rs 0 condition_tcl_2]

		deconstruct_rule $condition_tcl

		tpBindString pay_mthd  $pay_mthd
		tpBindString change_date $change_date
		tpBindString rule_name [db_get_col $rs 0 condition_desc]
		tpBindString priority  [db_get_col $rs 0 priority]
		tpBindString status    [db_get_col $rs 0 status]

		generate_valid_CC_data

		set sql [subst {
				select  a.desc acct,
						h.desc host,
						d.percentage
				from    tPmtRuleDest_AUD d,
						tPmtGateAcct a,
						tPmtGateHost h
				where 	d.pg_rule_id = $pg_rule_id
				and    	d.pg_host_id = h.pg_host_id
				and     d.pg_acct_id = a.pg_acct_id
				and     d.aud_time =
								(select max(aud_time)
								 from tPmtRuleDest_AUD
								 where pg_rule_id = $pg_rule_id
								 and   aud_time <= '$change_date'
								)
				and     d.aud_op != 'D'

		}]
		set stmt [inf_prep_sql $DB $sql]
		if [catch {set rs [inf_exec_stmt $stmt]} msg] {
			err_bind $msg
			set err 1
			return
		}
		inf_close_stmt $stmt
		set nrows [db_get_nrows $rs]
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		 	set ACCTS($i,acct)       [db_get_col $rs $i acct]
		 	set ACCTS($i,host)       [db_get_col $rs $i host]
		 	set ACCTS($i,percentage) [db_get_col $rs $i percentage]
		}

		tpSetVar num_accts $nrows
		tpBindVar acct       ACCTS acct       acct_idx
		tpBindVar host       ACCTS host       acct_idx
		tpBindVar percentage ACCTS percentage acct_idx

        asPlayFile -nocache pmt/pmt_rule_at_date.html

	}



	ADMIN::PMT::init_pmt_rules

}
