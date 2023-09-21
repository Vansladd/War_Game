# ==============================================================
# $Id: cpm_rules.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 OpenBet Technology Ltd. All rights reserved.
# ==============================================================
##
#
# Code for "CPMRules" section under "Payments" in the Admin screens.
#
# Provides facilities for the management of Customer Payment Menthod Rules
# and Messages.
#
##



namespace eval ADMIN::CPM_RULES {

	#
	# Set up the necessary handles
	#
	asSetAct     ADMIN::CPM_RULES::GoCPMRules      [namespace code go_cpm_rules]
	asSetAct     ADMIN::CPM_RULES::GoCPMRule       [namespace code go_cpm_rule]
	asSetAct     ADMIN::CPM_RULES::DoCPMRule       [namespace code do_cpm_rule]
	asSetAct     ADMIN::CPM_RULES::GoCPMOp         [namespace code go_cpm_op]
	asSetAct     ADMIN::CPM_RULES::DoCPMOp         [namespace code do_cpm_op]
	asSetAct     ADMIN::CPM_RULES::GoGroupRules    [namespace code go_group_rules]
	asSetAct     ADMIN::CPM_RULES::GoRulesTest     [namespace code go_rules_test]
	asSetAct     ADMIN::CPM_RULES::DoRulesTest     [namespace code do_rules_test]
	
	
	##
	# ADMIN::CPM_RULES::go_cpm_rules
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::go_cpm_rules]
	#
	# SCOPE
	#
	#       public
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Gets all CPM and Message Rules from the database.
	#       Gets all payment method information for use with the rules.
	#       Binds the whole lot up and plays the necessary template.
	#
	##
	proc go_cpm_rules {} {
		ob::log::write DEBUG {==>go_pmt_rules}
		
		global DB CPM_RULES ALLOW_MTHDS
		
		array set CPM_RULES   [list]
		array set ALLOW_MTHDS [list]
		
		#
		# Are we going to show deleted rules / messages ?
		#
		set show_deleted 0
		set where        ""
		
		if {[reqGetArg showDeleted] == 1} {

			set show_deleted 1
			set where        ""

		} else {

			set show_deleted 0
			set where        "and r.status <> 'X'"

		}
		
		tpBindString showDeleted $show_deleted
		tpSetVar     showDeleted $show_deleted
		
		
		#
		# Set the back action
		#
		back_action_forward "ADMIN::CPM_RULES::go_cpm_rules showDeleted $show_deleted" 1
		
		
		#
		# Get all rule details from the DB
		#

		# Are we looking for CPM rules, or CPM message rules?
		set           rule_type    [reqGetArg CPMRuleType]
		
		if {$rule_type != "M"} {
			set rule_type "R"
		} else {
			append where " and r.msg_point = 'DEP_DECL'"
		}

		tpSetVar      CPMRuleType  $rule_type
		tpBindString  CPMRuleType  $rule_type
		
		set sql [subst {
			select
				r.rule_id,
				r.type,
				r.rule_grp,
				r.rule_name,
				r.rule_desc,
				r.cpm_allow_id,
				r.rule_type,
				r.pmt_type,
				r.msg,
				r.msg_point,
				r.channels,
				nvl (m.desc,'-') as pay_mthd,
				r.status,
				nvl(r.priority, 9999) priority
			from
				tCPMRule r,
				outer tPayMthdAllow m
			where
				r.cpm_allow_id = m.cpm_allow_id and
				r.type = '$rule_type'
				$where
			order by
				priority, type desc, rule_grp
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	
		
		#
		# Set the CPM_RULES global appropriately.
		#
		set CPM_RULES(num_rules) [db_get_nrows $res]
		
		for {set i 0} {$i < $CPM_RULES(num_rules)} {incr i} {
			set CPM_RULES($i,type)          [db_get_col $res $i type]
			set CPM_RULES($i,rule_id)       [db_get_col $res $i rule_id]
			set CPM_RULES($i,rule_grp)      [db_get_col $res $i rule_grp]
			set CPM_RULES($i,rule_name)     [db_get_col $res $i rule_name]
			set CPM_RULES($i,rule_desc)     [db_get_col $res $i rule_desc]
			set CPM_RULES($i,cpm_allow_id)  [db_get_col $res $i cpm_allow_id]
			set CPM_RULES($i,rule_type)     [db_get_col $res $i rule_type]
			set CPM_RULES($i,pmt_type)      [db_get_col $res $i pmt_type]
			set CPM_RULES($i,msg)           [db_get_col $res $i msg]
			set CPM_RULES($i,msg_point)     [db_get_col $res $i msg_point]
			set CPM_RULES($i,channels)      [db_get_col $res $i channels]
			set CPM_RULES($i,pay_mthd)      [db_get_col $res $i pay_mthd]
			set CPM_RULES($i,status)        [db_get_col $res $i status]
			set CPM_RULES($i,priority)      [db_get_col $res $i priority]
		}
		db_close $res
		
		
		#
		# Make the necessary bindings.
		#
		tpSetVar   NumCPMRules    $CPM_RULES(num_rules)
		tpBindVar  CPMRuleId      CPM_RULES rule_id      cpmrule_idx
		tpBindVar  CPMType        CPM_RULES type         cpmrule_idx
		tpBindVar  CPMRuleGrp     CPM_RULES rule_grp     cpmrule_idx
		tpBindVar  CPMRuleName    CPM_RULES rule_name    cpmrule_idx
		tpBindVar  CPMRuleDesc    CPM_RULES rule_desc    cpmrule_idx
		tpBindVar  CPMAllowId     CPM_RULES cpm_allow_id cpmrule_idx
		tpBindVar  CPMRuleType    CPM_RULES rule_type    cpmrule_idx
		tpBindVar  CPMPmtType     CPM_RULES pmt_type     cpmrule_idx
		tpBindVar  CPMMsg         CPM_RULES msg          cpmrule_idx
		tpBindVar  CPMMsgPoint    CPM_RULES msg_point    cpmrule_idx
		tpBindVar  CPMChannels    CPM_RULES channels     cpmrule_idx
		tpBindVar  CPMPayMthd     CPM_RULES pay_mthd     cpmrule_idx
		tpBindVar  CPMStatus      CPM_RULES status       cpmrule_idx
		tpBindVar  CPMPriority    CPM_RULES priority     cpmrule_idx
		
		
		
		#
		# As well as all the rules, bind up all the allow pay methods
		# (for viewing purposes only)
		#
		set orderby ""
		
		if {[reqGetArg OrderBy] == "Dep"} {
			set orderby "order by dep_order"
		}
		
		if {[reqGetArg OrderBy] == "Wtd"} {
			set orderby "order by wtd_order"
		}
		
		set sql [subst {
			select
				cpm_allow_id,
				pay_mthd,
				desc,
				nvl(cpm_type,'-') as cpm_type,
				dep_order,
				wtd_order,
				allow_dep,
				allow_wtd
			from
				tPayMthdAllow
			$orderby
		}]
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		
		# build up the array
		set ALLOW_MTHDS(num_mthds) [db_get_nrows $res]
		
		for {set i 0} {$i < $ALLOW_MTHDS(num_mthds)} {incr i} {
			set ALLOW_MTHDS($i,cpm_allow_id)          [db_get_col $res $i cpm_allow_id]
			set ALLOW_MTHDS($i,pay_mthd)              [db_get_col $res $i pay_mthd]
			set ALLOW_MTHDS($i,desc)                  [db_get_col $res $i desc]
			set ALLOW_MTHDS($i,cpm_type)              [db_get_col $res $i cpm_type]
			set ALLOW_MTHDS($i,dep_order)             [db_get_col $res $i dep_order]
			set ALLOW_MTHDS($i,wtd_order)             [db_get_col $res $i wtd_order]
			set ALLOW_MTHDS($i,allow_dep)             [db_get_col $res $i allow_dep]
			set ALLOW_MTHDS($i,allow_wtd)             [db_get_col $res $i allow_wtd]
		}
		db_close $res
		
		# make the necessary bindings
		tpSetVar   NumMthds       $ALLOW_MTHDS(num_mthds)
		tpBindVar  AllowId        ALLOW_MTHDS cpm_allow_id      allow_idx
		tpBindVar  AllowPayMthd   ALLOW_MTHDS pay_mthd          allow_idx
		tpBindVar  AllowDesc      ALLOW_MTHDS desc              allow_idx
		tpBindVar  AllowType      ALLOW_MTHDS cpm_type          allow_idx
		tpBindVar  AllowDepOrder  ALLOW_MTHDS dep_order         allow_idx
		tpBindVar  AllowWtdOrder  ALLOW_MTHDS wtd_order         allow_idx
		tpBindVar  AllowDep       ALLOW_MTHDS allow_dep         allow_idx
		tpBindVar  AllowWtd       ALLOW_MTHDS allow_wtd         allow_idx
		
		
		
		#
		# play the necessary template
		#
		ob::log::write DEBUG {<==go_pmt_rules : returning}
		
		asPlayFile -nocache pmt/cpm_rule_list.html
	}
	
	
	##
	# ADMIN::CPM_RULES::go_cpm_rule
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::go_cpm_rule]
	#
	# SCOPE
	#
	#       public
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Master procedure for a CPM/Message Rule.
	#
	##
	proc go_cpm_rule {{submit_name ""}} {
		ob::log::write DEBUG {==>go_cpm_rule}
		
		if {$submit_name == "edit"} {
			go_cpm_rule_edit
		}
		
		switch -- [reqGetArg SubmitName] { 
			"Add"     {
					ob::log::write DEBUG {go_cpm_rule: Add}
					back_action_forward "[list ADMIN::CPM_RULES::go_cpm_rule_add] CPMRuleType [reqGetArg CPMRuleType]"
					go_cpm_rule_add
			          }
			       
			"Edit"    {
					ob::log::write DEBUG {go_cpm_rule: Edit}
					back_action_forward "[list ADMIN::CPM_RULES::go_cpm_rule_edit RuleId [reqGetArg RuleId] CPMRuleType [reqGetArg CPMRuleType]]"
					go_cpm_rule_edit
			          }
			
			"Test"
				  {
					ob::log::write DEBUG {go_cpm_rule: Test}
					back_action_forward "[list ADMIN::CPM_RULES::go_rules_test]"
					go_rules_test
				  }
			
			"Refresh" {
					ob::log::write DEBUG {go_cpm_rule: Refresh}
					go_cpm_rules
			          }
				      
			default   {
					ob::log::write DEBUG {go_cpm_rule: unknown SubmitName}
			          }
		}
		
		ob::log::write DEBUG {<==go_cpm_rule}
	}
	
	
	##
	# ADMIN::CPM_RULES::go_cpm_rule_add
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::go_cpm_rule_add]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Prepares the necessary variables for playing
	#       a template which allows a user to add a CPM or
	#       Message rule.
	#
	##
	proc go_cpm_rule_add {} {
		ob::log::write DEBUG {==>go_cpm_rule_add}
		
		#
		# Make the necessary bindings.
		#
		tpSetVar adding       1
		
		set           rule_type    [reqGetArg CPMRuleType]
		tpSetVar      CPMRuleType  $rule_type
		tpBindString  CPMRuleType  $rule_type
		
		set           rule_id      [reqGetArg RuleId]
		tpBindString  RuleId       $rule_id
		
		make_common_rule_bindings $rule_id $rule_type
		
		#
		# Call to make channel bindings
		#
		make_channel_binds "IP" - 0
		
		#
		# Call to make pay scheme bindings
		#
		get_pay_schemes -1

		#
		# play the necessary template
		#
		ob::log::write DEBUG {<==go_pmt_rule_add : returning}
		
		tpBindString RuleMsgPrefix      [OT_CfgGet DEP_DECL_PREFIX "PMT_ERR_RULE_"]
		asPlayFile -nocache pmt/cpm_rule.html
	}
	
	
	##
	# ADMIN::CPM_RULES::go_cpm_rule_edit
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::go_cpm_rule_edit]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Prepares the necessary variables for playing
	#       a template which allows a user to edit a CPM or
	#       Message rule.
	#
	##
	proc go_cpm_rule_edit {} {
		ob::log::write DEBUG {==>go_cpm_rule_edit}
		
		global DB CPMS_ALLOW RULE_OPS RULE_GRPS
		
		#
		# Make the necessary bindings.
		#
		tpSetVar      editing      1
		set           rule_type    [reqGetArg CPMRuleType]
		tpSetVar      CPMRuleType  $rule_type
		tpBindString  CPMRuleType  $rule_type
		
		set           rule_id      [reqGetArg RuleId]
		tpBindString  RuleId       $rule_id
		
		make_common_rule_bindings $rule_id $rule_type
		
		set msg_code   ""
		
		
		
		
		
		#
		# Get Rule Details
		#
		set sql [subst {
			select
				rule_id,
				type,
				rule_grp,
				rule_name,
				rule_desc,
				cpm_allow_id,
				rule_type,
				pmt_type,
				msg,
				msg_point,
				channels,
				status,
				priority
			from
				tCPMRule
			where
				rule_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {set res  [inf_exec_stmt $stmt $rule_id]} msg] } {
			ob::log::write ERROR {DB ERROR : $msg}
			db_close $res
			go_cpm_rules
		}
		
		inf_close_stmt $stmt

		# bind up the detail
		ob::log::write DEBUG {[db_get_nrows $res] rows returned}
		if {[db_get_nrows $res] == 1} {
			tpBindString RuleId             [db_get_col $res 0 rule_id]
			tpBindString RuleGroup          [db_get_col $res 0 rule_grp]
			tpBindString RuleName           [db_get_col $res 0 rule_name]
			tpBindString RuleDesc           [db_get_col $res 0 rule_desc]
			tpBindString RuleAllowId        [db_get_col $res 0 cpm_allow_id]
			tpBindString RuleType           [db_get_col $res 0 rule_type]
			tpBindString PmtType            [db_get_col $res 0 pmt_type]

			# msg contains a '|' delimited set of codes
			set codes [split [db_get_col $res 0 msg] "|"]

			tpBindString RuleMsgPrefix      [OT_CfgGet DEP_DECL_PREFIX "PMT_ERR_RULE_"]
			tpBindString RuleMsg1           [lindex $codes 0]
			tpBindString RuleMsg2           [lindex $codes 1]
			tpBindString RuleMsgPoint       [db_get_col $res 0 msg_point]
			tpBindString Channels           [db_get_col $res 0 channels]
			tpBindString RuleStatus         [db_get_col $res 0 status]
			tpBindString RulePriority       [db_get_col $res 0 priority]
		} else {
			ob::log::write WARNING {WARNING - not exactly 1 row returned - this should not be happening.}
			db_close $res
			go_cpm_rules
			return
		}
		
		
		#
		# Call to make channel bindings
		#
		make_channel_binds [db_get_col $res 0 channels] - 0
		
		if {$rule_type == "M"} {
			#
			# Bind message information if it exists
			#
			if {[lindex $codes 0] != ""} {
				# Primary message
				set_dep_decl_msg [lindex $codes 0] 1
			}

			# Now repeat the process for the secondary message
			if {[lindex $codes 1] != ""} {
				set_dep_decl_msg [lindex $codes 1] 2
			}

			#
			# Call to make pay scheme bindings
			#
			get_pay_schemes $rule_id
		}

		#
		# Clean up and play the necessary template
		#
		db_close $res
		ob::log::write DEBUG {<==go_cpm_rule_edit : returning}
		
		asPlayFile -nocache pmt/cpm_rule.html
	}
	
	
	##
	# ADMIN::CPM_RULES::do_cpm_rule
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::do_cpm_rule]
	#
	# SCOPE
	#
	#       public
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Master procedure after submission of the Rule template.
	#
	##
	proc do_cpm_rule {} {
		ob::log::write DEBUG {==>do_cpm_rule}
		set submit_name [reqGetArg SubmitName]
		ob::log::write DEBUG {do_cpm_rule> : $submit_name}
		
		switch -- $submit_name {
			"Add" {
				do_cpm_rule_add
				return
			}

			"Update" {
				back_action_refresh
				do_cpm_rule_upd
				return
			}

			"Back" {
				#go_cpm_rules
				back_action_backward
				return
			}

			"NewMsg" {
				back_action_forward "ADMIN::MSG::go_ml_msg"

				# Which msg (primary/secondary) has been clicked
				set code_id [reqGetArg code_id]
				set code [ob_chk::get_arg Msg${code_id} -err_msg {Message code should only contain alphanumeric characters} {ALNUM}]

				tpBindString new_code [OT_CfgGet DEP_DECL_PREFIX "PMT_ERR_RULE_"]$code
				tpBindString dep_dec_group "sb.pmt"

				ADMIN::MSG::go_ml_msg
				return
			}

			"GoMsgCode" {
				back_action_forward "ADMIN::MSG::go_msg_code code_id [reqGetArg code_id]"
				ADMIN::MSG::go_val
#				ADMIN::MSG::go_msg_code
				return
			}

			default {
				ob::log::write DEBUG {go_cpm_rule: unknown SubmitName}
			}
		}
		
		ob::log::write DEBUG {<==do_cpm_rule}
	}
	
	##
	# ADMIN::CPM_RULES::do_cpm_rule_add
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::do_cpm_rule_add]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Adds a CPM or Message Rule to the database
	#       and then plays back the template for further editing.
	#
	##
	proc do_cpm_rule_add {} {
		ob::log::write DEBUG {==>do_cpm_rule_add}
		
		global DB
		set rule_id ""
		

		#
		# First check the permission
		#
		set rule_type [reqGetArg CPMRuleType]
		if {(![op_allowed EditCPMRules] && $rule_type == "R") || \
		    (![op_allowed EditDepDeclRules] && $rule_type == "M")} {
			err_bind "You don't have permission to add/edit rules"
			go_cpm_rules
			return
		}
		
		#
		# execute the query.
		#
		set sql [subst {
			execute procedure pInsCPMRule (
				p_type         = ?,
				p_rule_grp     = ?,
				p_rule_name    = ?,
				p_rule_desc    = ?,
				p_cpm_allow_id = ?,
				p_rule_type    = ?,
				p_pmt_type     = ?,
				p_channels     = ?,
				p_msg          = ?,
				p_msg_point    = ?,
				p_status       = ?,
				p_priority     = ?
			)
		}]

		set msg_1 ""
		set msg_2 ""
		if {[reqGetArg Msg1] != ""} {
			set msg_1 [ob_chk::get_arg Msg1 -err_msg {Message code should only contain alphanumeric characters} {ALNUM}]
		}
		if {[reqGetArg Msg2] != ""} {
			set msg_2 [ob_chk::get_arg Msg2 -err_msg {Message code should only contain alphanumeric characters} {ALNUM}]
		}

		set msg "${msg_1}|${msg_2}"

		set c [catch {
			set stmt [inf_prep_sql $DB $sql]

			set rs [inf_exec_stmt $stmt\
				[reqGetArg CPMRuleType]\
				[reqGetArg RuleGroup]\
				[reqGetArg RuleName]\
				[reqGetArg RuleDesc]\
				[reqGetArg PayMthd]\
				[reqGetArg RuleType]\
				[reqGetArg PmtType]\
				[make_channel_str "CN_"]\
				$msg\
				[reqGetArg MsgPoint]\
				[reqGetArg RuleStatus]\
				[reqGetArg Priority]\
			]
				
			set rule_id [db_get_coln $rs 0]
			
			inf_close_stmt $stmt

			db_close $rs

		} msg]

		if {[reqGetArg CPMRuleType] == "M"} {
			# Associate alternative payment methods
			set_pay_schemes $rule_id
		}

		if {$c} {
			err_bind "Could not insert payment method rule : $msg"
		} else {
			msg_bind "New Payment method rule added"
		}
		
		#
		# Clean Up and Return
		#
		ob::log::write DEBUG {<==do_cpm_rule_add rule_id=$rule_id}
		reqSetArg RuleId $rule_id
		back_action_refresh "[list ADMIN::CPM_RULES::go_cpm_rule_edit RuleId [reqGetArg RuleId] CPMRuleType [reqGetArg CPMRuleType]]"
		go_cpm_rule_edit
		
	}
	
	
	##
	# ADMIN::CPM_RULES::do_cpm_rule_upd
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::do_cpm_rule_upd]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#
	# RETURN
	#
	#
	#
	# DESCRIPTION
	#
	#       Updates a CPM or Message rule in the database.
	#       Plays back the Rule template again for further editing.
	#
	##
	proc do_cpm_rule_upd {} {
		ob::log::write DEBUG {==>do_cpm_rule_upd}
		
		global DB
		
		set rule_id [reqGetArg RuleId]
		
		
		#
		# First check the permission
		#
		set rule_type [reqGetArg CPMRuleType]
		if {(![op_allowed EditCPMRules] && $rule_type == "R") || \
		    (![op_allowed EditDepDeclRules] && $rule_type == "M")} {
			err_bind "You don't have permission to add/edit rules"
			go_cpm_rules
			return
		}
		
		
		#
		# execute the query.
		#
		set sql [subst {
			execute procedure pUpdCPMRule (
				p_rule_id      = ?,
				p_type         = ?,
				p_rule_grp     = ?,
				p_rule_name    = ?,
				p_rule_desc    = ?,
				p_cpm_allow_id = ?,
				p_rule_type    = ?,
				p_pmt_type     = ?,
				p_channels     = ?,
				p_msg          = ?,
				p_msg_point    = ?,
				p_status       = ?,
				p_priority     = ?
			)
		}]


		set msg_1 ""
		set msg_2 ""
		if {[reqGetArg Msg1] != ""} {
			set msg_1 [ob_chk::get_arg Msg1 -err_msg {Message code should only contain alphanumeric characters} {ALNUM}]
		}
		if {[reqGetArg Msg2] != ""} {
			set msg_2 [ob_chk::get_arg Msg2 -err_msg {Message code should only contain alphanumeric characters} {ALNUM}]
		}

		set msg "${msg_1}|${msg_2}"

		set c [catch {
			set stmt [inf_prep_sql $DB $sql]

			set rs [inf_exec_stmt $stmt\
				$rule_id\
				[reqGetArg CPMRuleType]\
				[reqGetArg RuleGroup]\
				[reqGetArg RuleName]\
				[reqGetArg RuleDesc]\
				[reqGetArg PayMthd]\
				[reqGetArg RuleType]\
				[reqGetArg PmtType]\
				[make_channel_str "CN_"]\
				$msg\
				[reqGetArg MsgPoint]\
				[reqGetArg RuleStatus]\
				[reqGetArg Priority]\
			]
			
			inf_close_stmt $stmt

			db_close $rs

		} msg]

		if {[reqGetArg CPMRuleType] == "M"} {
			# Update associated payment methods
			set_pay_schemes $rule_id
		}

		if {$c} {
			err_bind "Could not update payment method rule (id $rule_id) : $msg"
		} else {
			msg_bind "Payment method rule updated"
		}

		#
		# Clean Up and Return
		#
		ob::log::write DEBUG {<==do_cpm_rule_upd}
		reqSetArg RuleId $rule_id
		go_cpm_rule_edit
	}
	
	
	##
	# ADMIN::CPM_RULES::make_common_rule_bindings
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::make_common_rule_bindings <rule_id> <rule_type>]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       [rule_id]   - the id of the rule we are binding for
	#       [rule_type] - whether we are preparing for a rule or message (R/M)
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Do all necessary for template which allows updates
	#       and additions of rules.
	#           1. Bind up a list of all available rule groups
	#           2. Bind up a list of all available payment methods
	#           3. Bind up a list of the rule operation details.
	#
	##
	proc make_common_rule_bindings {rule_id rule_type} {
		ob::log::write DEBUG {==>make_common_rule_bindings rule_id=$rule_id rule_type=$rule_type}
		
		global DB CPMS_ALLOW RULE_OPS RULE_GRPS
		array set CPMS_ALLOW   [list]
		array set RULE_OPS     [list]
		array set RULE_GRPS    [list]
		
		
		#
		# Bind up a list of available rule groups
		#
		
		# do the query
		set sql [subst {
		select distinct
			rule_grp
		from
			tCPMRule
		where 
			rule_grp is not null
			and rule_grp <> ''
		}]

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {set res  [inf_exec_stmt $stmt]} msg] } {
			ob::log::write ERROR {DB ERROR : $msg}
		}
		
		# build the array
		set RULE_GRPS(num_grps) [db_get_nrows $res]
		ob::log::write DEBUG {Num Grp rows = $RULE_GRPS(num_grps)}
		
		for {set i 0} {$i < $RULE_GRPS(num_grps)} {incr i} {
			set RULE_GRPS($i,rule_grp)    [db_get_col $res $i rule_grp]
		}
		
		# do the bindings
		tpSetVar   NumGrps       $RULE_GRPS(num_grps)
		tpBindVar  RuleGrp       RULE_GRPS rule_grp   grp_idx
		db_close $res
		
		
		#
		# Bind up the avaiable payment methods for dropdown
		#
		if {$rule_type == "R"} {
		
			# do the query
			set sql [subst {
			select
				cpm_allow_id,
				pay_mthd,
				cpm_type,
				desc
			from
				tPayMthdAllow
			}]

			set stmt [inf_prep_sql $DB $sql]
			if {[catch {set res  [inf_exec_stmt $stmt $rule_id]} msg] } {
				ob::log::write ERROR {DB ERROR : $msg}
			}
			
			# build up the array
			set CPMS_ALLOW(num_mthds) [db_get_nrows $res]
		
			for {set i 0} {$i < $CPMS_ALLOW(num_mthds)} {incr i} {
				set CPMS_ALLOW($i,cpm_allow_id)    [db_get_col $res $i cpm_allow_id]
				set CPMS_ALLOW($i,pay_mthd)        [db_get_col $res $i pay_mthd]
				set CPMS_ALLOW($i,cpm_type)        [db_get_col $res $i cpm_type]
				set CPMS_ALLOW($i,desc)            [db_get_col $res $i desc]
			}
			
			#make the bindings
			tpSetVar   NumMthds       $CPMS_ALLOW(num_mthds)
			tpBindVar  CPMAllowId     CPMS_ALLOW cpm_allow_id   cpmallow_idx
			tpBindVar  CPMAllowMthd   CPMS_ALLOW pay_mthd       cpmallow_idx
			tpBindVar  CPMType        CPMS_ALLOW cpm_type       cpmallow_idx
			tpBindVar  CPMDesc        CPMS_ALLOW desc           cpmallow_idx
			
			db_close $res
		}
		
		
		#
		# Are we going to show deleted rules / messages ?
		#
		set show_deleted 0
		set where        ""
		
		if {[reqGetArg showDeleted] == 1} {

			set show_deleted 1
			set where        ""

		} else {

			set show_deleted 0
			set where        "and status <> 'X'"

		}
		
		tpBindString showDeleted $show_deleted
		tpSetVar     showDeleted $show_deleted
		
		
		#
		# Get all the ops for this rule
		#
		set op_status_only [reqGetArg op_status_only]
		
		# execute the query
		set sql [subst {
			select
				op_id,
				sequence,
				op_level,
				op_operator,
				op_left_value,
				op_right_value,
				status
			from
				tCPMOp
			where
				rule_id = ?
				$where
			order by
				sequence
		}]

		set stmt [inf_prep_sql $DB $sql]
		
		
		if {[catch {set res  [inf_exec_stmt $stmt $rule_id]} msg] } {
			ob::log::write ERROR {DB ERROR : $msg}
		}
		
		# build the array
		set RULE_OPS(num_ops) [db_get_nrows $res]
		ob::log::write DEBUG {Num Ops : $RULE_OPS(num_ops)}
		set last_active_level "none"
		
		for {set i 0} {$i < $RULE_OPS(num_ops)} {incr i} {
			set RULE_OPS($i,op_id)          [db_get_col $res $i op_id]
			set RULE_OPS($i,sequence)       [db_get_col $res $i sequence]
			set RULE_OPS($i,op_level)       [db_get_col $res $i op_level]
			set RULE_OPS($i,op_operator)    [CPMRules::get_var_desc [db_get_col $res $i op_operator]]
			set RULE_OPS($i,op_left_value)  [CPMRules::get_var_desc [db_get_col $res $i op_left_value]]
			set RULE_OPS($i,op_right_value) [CPMRules::get_var_desc [db_get_col $res $i op_right_value]]
			set RULE_OPS($i,status)         [db_get_col $res $i status]
			
			# if the level is different from the previous
			# active level then set as 'OR', 'AND' otherwise
			if {$RULE_OPS($i,status) == "A"} {
				if {$i > 0} {
					
					if {$RULE_OPS($i,op_level) == $last_active_level} {
						set RULE_OPS($i,op_level_txt) "AND"
					} else {
						set RULE_OPS($i,op_level_txt) "OR"
					}
				} else {
					set RULE_OPS($i,op_level_txt) ""
				}
				
				set last_active_level $RULE_OPS($i,op_level)
			}
		}
		
		# make the bindings
		tpSetVar   NumOps      $RULE_OPS(num_ops)
		tpBindVar  OpId        RULE_OPS op_id          op_idx
		tpBindVar  OpSequence  RULE_OPS sequence       op_idx
		tpBindVar  OpLevel     RULE_OPS op_level       op_idx
		tpBindVar  OpLevelText RULE_OPS op_level_txt   op_idx
		tpBindVar  OpOperator  RULE_OPS op_operator    op_idx
		tpBindVar  OpLHS       RULE_OPS op_left_value  op_idx
		tpBindVar  OpRHS       RULE_OPS op_right_value op_idx
		tpBindVar  OpStatus    RULE_OPS status         op_idx
		
		db_close $res
		
			
		#
		# Clean Up and Return
		#
		ob::log::write DEBUG {<==make_common_rule_bindings}
	}
	
	
	##
	# ADMIN::CPM_RULES::go_cpm_op
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::go_cpm_op]
	#
	# SCOPE
	#
	#       public
	#
	# PARAMS
	#       -
	#       
	# RETURN
	#
	#       -
	#
	# DESCRIPTION
	#
	#       First point of call for editing / creating
	#       a new operation.
	#
	##
	proc go_cpm_op {{submit_name ""}} {
		ob::log::write DEBUG {==>go_cpm_op}
		
		if {$submit_name == "edit"} {
			go_cpm_op_edit
		}
		
		switch -- [reqGetArg SubmitName] { 
			"Add"     {
					ob::log::write DEBUG {go_cpm_op: Add}
					back_action_forward "ADMIN::CPM_RULES::go_cpm_op_add"
					go_cpm_op_add
			          }
			       
			"Edit"    {
					ob::log::write DEBUG {go_cpm_op: Edit}
					back_action_forward "ADMIN::CPM_RULES::go_cpm_op_edit OpId [reqGetArg OpId]"
					go_cpm_op_edit
					
			          }
			"Refresh" {
					ob::log::write DEBUG {go_cpm_rule: Refresh}
					back_action_refresh "[list ADMIN::CPM_RULES::go_cpm_rule SubmitName Edit showDeleted [reqGetArg showDeleted]]"
					go_cpm_rule_edit
			          } 
			"All"     {
					ob::log::write DEBUG {go_cpm_rule: All}
					back_action_refresh
					go_cpm_rule_edit
			          }      
			default {
					ob::log::write DEBUG {go_cpm_op: unknown SubmitName}
			        }
		}
		
		ob::log::write DEBUG {<==go_cpm_op}
	}
	
	##
	# ADMIN::CPM_RULES::go_cpm_op_add
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::go_cpm_op_add]
	#
	# SCOPE
	#
	#       public
	#
	# PARAMS
	#       -
	#       
	# RETURN
	#
	#       -
	#
	# DESCRIPTION
	#
	#       Preparation work for displaying the form
	#       for creating a new CPM operation.
	#
	##
	proc go_cpm_op_add {} {
		ob::log::write DEBUG {==>go_cpm_op_add}
		
		
		global OP_VARS
		
		
		#
		# Make the necesary bindings
		#
		tpBindString    adding        1
		tpSetVar        adding        1
		tpSetVar        editing       0
		set             rule_id       [reqGetArg RuleId]
		tpBindString    RuleId        $rule_id
		tpBindString    CPMRuleType   [reqGetArg CPMRuleType] 
		make_op_bindings
		
		
		
		#
		# Clean Up and Return
		#
		ob::log::write DEBUG {<==go_cpm_op_add}
		asPlayFile -nocache pmt/cpm_op.html
	}
	
	##
	# ADMIN::CPM_RULES::go_cpm_op_edit
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::go_cpm_op_edit]
	#
	# SCOPE
	#
	#       public
	#
	# PARAMS
	#       -
	#       
	# RETURN
	#
	#       -
	#
	# DESCRIPTION
	#
	#       Preparation work for displaying the form
	#       for editing an existing CPM operation.
	#
	##
	proc go_cpm_op_edit {} {
		ob::log::write DEBUG {==>go_cpm_op_edit}
		
		global DB OP_VARS
		
		
		#
		# Make the necesary bindings
		#
		tpBindString    editing       1
		tpSetVar        editing       1
		tpSetVar        adding        0
		set             op_id         [reqGetArg OpId]
		set             rule_id       [reqGetArg RuleId]
		tpBindString    CPMRuleType   [reqGetArg CPMRuleType]
		set             LHStext       ""
		set             RHSText       ""
		
		
		
		#
		# Get the existing op details
		#
		set sql [subst {
			select
				op_id,
				rule_id,
				sequence,
				op_level,
				op_operator,
				op_left_value,
				op_right_value,
				status
			from
				tCPMOp
			where
				op_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {set res  [inf_exec_stmt $stmt $op_id]} msg] } {
			ob::log::write ERROR {DB ERROR : $msg}
			db_close $res
			go_cpm_rule
		}
		
		inf_close_stmt $stmt
		
		# bind up the detail
		ob::log::write DEBUG {[db_get_nrows $res] rows returned}
		if {[db_get_nrows $res] == 1} {
			tpBindString OpId               [db_get_col $res 0 op_id]
			tpBindString RuleId             [db_get_col $res 0 rule_id]
			tpBindString OpSequence         [db_get_col $res 0 sequence]
			tpBindString OpLevel            [db_get_col $res 0 op_level]
			tpBindString OpOperator         [db_get_col $res 0 op_operator]
			tpBindString OpLHS              [db_get_col $res 0 op_left_value]
			set          LHSText            [db_get_col $res 0 op_left_value]
			tpBindString OpRHS              [db_get_col $res 0 op_right_value]
			set          RHSText            [db_get_col $res 0 op_right_value]
			tpBindString OpStatus           [db_get_col $res 0 status]
		} else {
			ob::log::write WARNING {WARNING - not exactly 1 row returned - this should not be happening.}
			db_close $res
			go_cpm_rule
			return
		}
		
		
		#
		# Make Operation dropdown bindings
		#
		make_op_bindings $LHSText $RHSText
		
		
		#
		# Clean Up and Return
		#
		ob::log::write DEBUG {<==go_cpm_op_edit}
		asPlayFile -nocache pmt/cpm_op.html
	}
	
	
	##
	# ADMIN::CPM_RULES::make_op_bindings
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::make_op_bindings]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#       
	# RETURN
	#
	#       -
	#
	# DESCRIPTION
	#
	#       Makes the necessary bindings in order to
	#       display the operation detail/form page.
	#
	##
	proc make_op_bindings {{LHSText "-"} {RHSText "-"}} {
		ob::log::write DEBUG {==>make_op_bindings}
		
		global DB OP_VARS
		array set OP_VARS   [list]
		
		set rule_type [reqGetArg CPMRuleType]
		
		#
		# Make bindings for variables in dropdown.
		#
		# We are going to bind up a great big list of things
		# both LHS and RHS dropdowns can be popluated with. The
		# options can be seen as being split into groups :
		#
		#        1. BASE Elements
		#        2. Country Codes
		#        3. Currency Codes
		#        4. Payment Methods
		#        5. Card Schemes
		#        6. Card Issue countries
		#
		# The idea then is that in the javascript we can manipulate what
		# we show in one dropdown depending on what is selected in the other.
		#
		
		#
		# BASE Options
		#
		set i 0
		
		set OP_VARS($i,value) "-|ALWAYS_SHOW|-"
		set OP_VARS($i,name)  "Other->"
		incr i;
		
		set OP_VARS($i,value) "CNTRY_CODE||-"
		set OP_VARS($i,name)  ""
		incr i;
		
		set var_list [CPMRules::get_rule_vars]
		foreach v $var_list {
			
			# only want the Variable (V) list
			if {[lindex $v 2] == "V" && ([lindex $v 4] == "B" || [lindex $v 4] == $rule_type)} {
				set OP_VARS($i,value) "[lindex $v 3]|ALWAYS_SHOW|[lindex $v 0]"
				set OP_VARS($i,name)  "[lindex $v 1]"
				incr i;
			}
		}
		
		
		#
		# Country Codes 
		#
		set OP_VARS($i,value) "CNTRY_CODE||-"
		set OP_VARS($i,name)  ""
		incr i;
		set OP_VARS($i,value) "CNTRY_CODE||-"
		set OP_VARS($i,name)  "Country Codes :"
		incr i;
		set OP_VARS($i,value) "CNTRY_CODE||-"
		set OP_VARS($i,name)  "----------------------------"
		incr i;
		
		set stmt [inf_prep_sql $DB {
			select country_code,country_name, disporder
			from tcountry
			order by disporder, country_name, country_code
		}]
		set res_cntry [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		
		for {set x 0} {$x < [db_get_nrows $res_cntry]} {incr x} {
			set OP_VARS($i,value) "CNTRY_CODE||[db_get_col $res_cntry $x country_code]"
			set OP_VARS($i,name)  "[db_get_col $res_cntry $x country_code] ([db_get_col $res_cntry $x country_name])"
			incr i
		}
		
		
		#
		# Currency Codes
		#
		set OP_VARS($i,value) "CCY_CODE||-"
		set OP_VARS($i,name)  ""
		incr i;
		set OP_VARS($i,value) "CCY_CODE||-"
		set OP_VARS($i,name)  "Currency Codes :"
		incr i;
		set OP_VARS($i,value) "CCY_CODE||-"
		set OP_VARS($i,name)  "----------------------------"
		incr i;
		
		set stmt [inf_prep_sql $DB {
			select ccy_code,ccy_name, disporder
			from tccy
			order by disporder
		}]
		set res_ccy [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		
		for {set x 0} {$x < [db_get_nrows $res_ccy]} {incr x} {
			set OP_VARS($i,value) "CCY_CODE||[db_get_col $res_ccy $x ccy_code]"
			set OP_VARS($i,name)  "[db_get_col $res_ccy $x ccy_code] ([db_get_col $res_ccy $x ccy_name])"
			incr i
		}
		
		
		#
		# Customer Payment Methods
		#
		
		set OP_VARS($i,value) "CPM||-"
		set OP_VARS($i,name)  ""
		incr i;
		set OP_VARS($i,value) "CPM||-"
		set OP_VARS($i,name)  "Payment Methods :"
		incr i;
		set OP_VARS($i,value) "CPM||-"
		set OP_VARS($i,name)  "----------------------------"
		incr i;
		
		set stmt [inf_prep_sql $DB {
			select pay_mthd, desc
			from tpaymthd
		}]
		set res_cpm [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		
		for {set x 0} {$x < [db_get_nrows $res_cpm]} {incr x} {
			set OP_VARS($i,value) "CPM||[db_get_col $res_cpm $x pay_mthd]"
			set OP_VARS($i,name)  "[db_get_col $res_cpm $x pay_mthd] ([db_get_col $res_cpm $x desc])"
			incr i
		}
		
		
		#
		# Card Country Options
		#
		set OP_VARS($i,value) "CARD_CNTRY||-"
		set OP_VARS($i,name)  ""
		incr i;
		set OP_VARS($i,value) "CARD_CNTRY||-"
		set OP_VARS($i,name)  "Card Issue Countries :"
		incr i;
		set OP_VARS($i,value) "CARD_CNTRY||-"
		set OP_VARS($i,name)  "----------------------------"
		incr i;
		
		set stmt [inf_prep_sql $DB {
			select distinct country
			from tcardinfo
			order by country
		}]
		set res_ccntry [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		
		for {set x 0} {$x < [db_get_nrows $res_ccntry]} {incr x} {
			set OP_VARS($i,value) "CARD_CNTRY||[db_get_col $res_ccntry $x country]"
			set OP_VARS($i,name)  "[db_get_col $res_ccntry $x country]"
			incr i
		}
		
		
		#
		# Card Scheme Options
		#
		
		set OP_VARS($i,value) "CARD_SCHEME||-"
		set OP_VARS($i,name)  ""
		incr i;
		set OP_VARS($i,value) "CARD_SCHEME||-"
		set OP_VARS($i,name)  "Card Schemes :"
		incr i;
		set OP_VARS($i,value) "CARD_SCHEME||-"
		set OP_VARS($i,name)  "----------------------------"
		incr i;
		
		set stmt [inf_prep_sql $DB {
			select scheme, scheme_name
			from tcardschemeinfo
		}]
		set res_cscheme [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		
		for {set x 0} {$x < [db_get_nrows $res_cscheme]} {incr x} {
			set OP_VARS($i,value) "CARD_SCHEME||[db_get_col $res_cscheme $x scheme]"
			set OP_VARS($i,name)  "[db_get_col $res_cscheme $x scheme] ([db_get_col $res_cscheme $x scheme_name])"
			incr i
		}
		
		#
		# Payment GW Options
		#
		set OP_VARS($i,value) "PMT_GW||-"
		set OP_VARS($i,name)  ""
		incr i

		set OP_VARS($i,value) "PMT_GW||-"
		set OP_VARS($i,name)  "Payment Gateways :"
		incr i

		set OP_VARS($i,value) "PMT_GW||-"
		set OP_VARS($i,name)  "----------------------------"
		incr i

		set stmt [inf_prep_sql $DB {
			select distinct pg_type
			from tPmtGateHost
		}]
		set res_pmtgw [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		for {set x 0} {$x < [db_get_nrows $res_pmtgw]} {incr x} {
			set OP_VARS($i,value) "PMT_GW||[db_get_col $res_pmtgw $x pg_type]"
			set OP_VARS($i,name)  "[db_get_col $res_pmtgw $x pg_type]"
			incr i
		}

		#
		# Do the bindings
		#
		tpBindString LHSText $LHSText
		tpBindString RHSText $RHSText
		
		set OP_VARS(numVars) $i
		tpSetVar   numVars   $i
		
		tpBindVar  VarValue        OP_VARS value          var_idx
		tpBindVar  VarName         OP_VARS name           var_idx
		
		
		#
		# Clean up and return
		#
		db_close $res_ccy
		db_close $res_cntry
		db_close $res_cpm
		db_close $res_ccntry
		db_close $res_cscheme
		
		ob::log::write DEBUG {<==make_op_bindings}
	}
	
	##
	# ADMIN::CPM_RULES::do_cpm_op
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::do_cpm_op]
	#
	# SCOPE
	#
	#       public
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Master procedure after submission of Op template.
	#
	##
	proc do_cpm_op {} {
		ob::log::write DEBUG {==>do_cpm_op}
		
		switch -- [reqGetArg SubmitName] { 
			"Add"     {
					ob::log::write DEBUG {do_cpm_op: Add}
					back_action_refresh
					do_cpm_op_add
			          }
			       
			"Update"  {
					ob::log::write DEBUG {do_cpm_op: Update}
					back_action_refresh
					do_cpm_op_upd
			          }
			
			"Back"    {
					ob::log::write DEBUG {do_cpm_op: Back}
					back_action_backward
					return
			          }
				  
			default   {
					ob::log::write DEBUG {go_cpm_op: unknown SubmitName}
			          }
		}
		
		ob::log::write DEBUG {<==do_cpm_op}
	}
	
	
	##
	# ADMIN::CPM_RULES::do_cpm_op_add
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::do_cpm_op_add]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Adds a new Rule Operation to the database.
	#       Finishes by playing back the Op template for
	#       further editing.
	#
	##
	proc do_cpm_op_add {} {
		ob::log::write DEBUG {==>do_cpm_op_add}
		
		global DB
		
		set op_id ""
		
		#
		# First check the permission
		#
		set rule_type [reqGetArg CPMRuleType]
		if {(![op_allowed EditCPMRules] && $rule_type == "R") || \
		    (![op_allowed EditDepDeclRules] && $rule_type == "M")} {
			err_bind "You don't have permission to add/edit rules"
			go_cpm_rules
			return
		}

		if {[reqGetArg OpSequence] == "" || [reqGetArg OpLevel] == ""} {
			err_bind "You must enter a sequence number and level for rule components"
			go_cpm_op_add
			return
		}

		#
		# execute the query.
		#
		set sql [subst {
			execute procedure pInsCPMOp (
				p_rule_id     = ?,
				p_sequence    = ?,
				p_op_level    = ?,
				p_op_operator = ?,
				p_left_value  = ?,
				p_right_value = ?,
				p_status      = ?
			)
		}]

		set c [catch {
			set stmt [inf_prep_sql $DB $sql]

			set rs [inf_exec_stmt $stmt\
				[reqGetArg RuleId]\
				[reqGetArg OpSequence]\
				[reqGetArg OpLevel]\
				[reqGetArg OpOperator]\
				[reqGetArg OpLHS]\
				[reqGetArg OpRHS]\
				[reqGetArg OpStatus]]
				
			set op_id [db_get_coln $rs 0]
			
			inf_close_stmt $stmt

			db_close $rs

		} msg]

		if {$c} {
			err_bind "Could not insert payment method operation : $msg"
		} else {
			msg_bind "New Payment method operation added"
		}
		
		
		#
		# Clean Up and Return 
		#
		ob::log::write DEBUG {<==do_cpm_op_add}
		reqSetArg OpId $op_id
		go_cpm_op_edit
	}
	
	##
	# ADMIN::CPM_RULES::do_cpm_op_upd
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::do_cpm_op_upd]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Update an Operation in the database.
	#       Finishes by playing back the Op template to
	#       allow for further editing.
	#
	##
	proc do_cpm_op_upd {} {
		ob::log::write DEBUG {==>do_cpm_op_upd}
		
		global DB

		#
		# First check the permission
		#
		set rule_type [reqGetArg CPMRuleType]
		if {(![op_allowed EditCPMRules] && $rule_type == "R") || \
		    (![op_allowed EditDepDeclRules] && $rule_type == "M")} {
			err_bind "You don't have permission to add/edit rules"
			go_cpm_rules
			return
		}

		if {[reqGetArg OpSequence] == "" || [reqGetArg OpLevel] == ""} {
			err_bind "You must enter a sequence number and level for rule components"
			go_cpm_op_edit
			return
		}

		#
		# Get the existing data from the DB
		#
		set sql [subst {
			execute procedure pUpdCPMOp (
				p_op_id       = ?,
				p_rule_id     = ?,
				p_sequence    = ?,
				p_op_level    = ?,
				p_op_operator = ?,
				p_left_value  = ?,
				p_right_value = ?,
				p_status      = ?
			)
		}]

		set c [catch {
			set stmt [inf_prep_sql $DB $sql]

			set rs [inf_exec_stmt $stmt\
				[reqGetArg OpId]\
				[reqGetArg RuleId]\
				[reqGetArg OpSequence]\
				[reqGetArg OpLevel]\
				[reqGetArg OpOperator]\
				[reqGetArg OpLHS]\
				[reqGetArg OpRHS]\
				[reqGetArg OpStatus]]
			
			inf_close_stmt $stmt

			db_close $rs

		} msg]

		if {$c} {
			err_bind "Could not update payment method operation : $msg"
		} else {
			msg_bind "Payment method operation updated"
		}
		
		#
		# Clean Up and Return
		#
		ob::log::write DEBUG {<==do_cpm_op_upd}
		go_cpm_op_edit
	}
	
	
	##
	# ADMIN::CPM_RULES::go_group_rules
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::go_group_rules]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Gathers all CPM rules and Message rules for
	#       a particular group. Binds up the the info
	#       and plays the necessary template.
	#
	##
	proc go_group_rules {} {
		ob::log::write DEBUG {==>go_group_rules}
		
		global DB GRP_OPS
		array set GRP_OPS   [list]
		
		
		set rule_group [reqGetArg RuleGroup]
		tpBindString RuleGroup $rule_group
		
		
		#
		# Get all rules and associated ops
		# for this group
		#
		set sql [subst {
			select
				r.rule_id,
				r.type,
				r.rule_grp,
				r.rule_name,
				r.rule_desc,
				r.cpm_allow_id,
				r.rule_type,
				r.pmt_type,
				r.msg,
				r.msg_point,
				r.channels,
				r.status as rule_status,
				o.op_id,
				o.sequence,
				o.op_level,
				o.op_operator,
				nvl(o.op_left_value,'No Components defined') as op_left_value,
				o.op_right_value,
				o.status as op_status
			from
				tCPMRule r,
				outer tCPMOp o
			where
				r.rule_id = o.rule_id
				and r.status = 'A'
				and o.status = 'A'
				and r.rule_grp = ?
			order by 
				2 desc, 1
		}]

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {set res  [inf_exec_stmt $stmt $rule_group]} msg] } {
			ob::log::write ERROR {DB ERROR : $msg}
			db_close $res
			go_cpm_rules
		}
		
		inf_close_stmt $stmt
		
		
		#
		# build up the array
		#
		set GRP_OPS(total_ops) [db_get_nrows $res]
		set last_active_level  ""
		set last_rule_id       ""
		
		for {set i 0} {$i < $GRP_OPS(total_ops)} {incr i} {
			set GRP_OPS($i,type)            [db_get_col $res $i type]
			set GRP_OPS($i,rule_id)         [db_get_col $res $i rule_id]
			set GRP_OPS($i,rule_grp)        [db_get_col $res $i rule_grp]
			set GRP_OPS($i,rule_name)       [db_get_col $res $i rule_name]
			set GRP_OPS($i,rule_desc)       [db_get_col $res $i rule_desc]
			set GRP_OPS($i,cpm_allow_id)    [db_get_col $res $i cpm_allow_id]
			set GRP_OPS($i,rule_type)       [db_get_col $res $i rule_type]
			set GRP_OPS($i,pmt_type)        [db_get_col $res $i pmt_type]
			set GRP_OPS($i,msg)             [db_get_col $res $i msg]
			set GRP_OPS($i,msg_point)       [db_get_col $res $i msg_point] 
			set GRP_OPS($i,channels)        [db_get_col $res $i channels]
			set GRP_OPS($i,rule_status)     [db_get_col $res $i rule_status]
			set GRP_OPS($i,op_id)           [db_get_col $res $i op_id]
			set GRP_OPS($i,sequence)        [db_get_col $res $i sequence]
			set GRP_OPS($i,op_level)        [db_get_col $res $i op_level]
			set GRP_OPS($i,op_operator)     [CPMRules::get_var_desc [db_get_col $res $i op_operator]]
			set GRP_OPS($i,op_left_value)   [CPMRules::get_var_desc [db_get_col $res $i op_left_value]]
			set GRP_OPS($i,op_right_value)  [CPMRules::get_var_desc [db_get_col $res $i op_right_value]]
			set GRP_OPS($i,op_status)       [db_get_col $res $i op_status]
			
			#
			# set some other vars : info relative to this row
			#
			
			# if the level is different from the previous
			# active level then set as 'OR', 'AND' otherwise
			set GRP_OPS($i,op_level_txt) ""
			
			if {$i > 0} {
				# onlt set the text if we are not starting a new rule
				if {$GRP_OPS($i,rule_id) == $last_rule_id} {
					if {$GRP_OPS($i,op_level) == $last_active_level} {
						set GRP_OPS($i,op_level_txt) "AND"
					} else {
						set GRP_OPS($i,op_level_txt) "OR"
					}
				}
			} 
			
			set last_active_level $GRP_OPS($i,op_level)
			set last_rule_id      $GRP_OPS($i,rule_id)
		}
		
		
		#
		# Make the necessary bindings
		#
		tpSetVar   TotalOps       $GRP_OPS(total_ops)
		tpBindVar  GrpRuleId      GRP_OPS rule_id        grp_idx
		tpBindVar  GrpType        GRP_OPS type           grp_idx
		tpBindVar  GrpRuleGrp     GRP_OPS rule_grp       grp_idx
		tpBindVar  GrpRuleName    GRP_OPS rule_name      grp_idx
		tpBindVar  GrpRuleDesc    GRP_OPS rule_desc      grp_idx
		tpBindVar  GrpAllowId     GRP_OPS cpm_allow_id   grp_idx
		tpBindVar  GrpRuleType    GRP_OPS rule_type      grp_idx
		tpBindVar  GrpPmtType     GRP_OPS pmt_type       grp_idx
		tpBindVar  GrpMsg         GRP_OPS msg            grp_idx
		tpBindVar  GrpMsgPoint    GRP_OPS msg_point      grp_idx
		tpBindVar  GrpChannels    GRP_OPS channels       grp_idx
		tpBindVar  GrpPayMthd     GRP_OPS pay_mthd       grp_idx
		tpBindVar  GrpRuleStatus  GRP_OPS rule_status    grp_idx
		tpBindVar  GrpOpId        GRP_OPS op_id          grp_idx
		tpBindVar  GrpSequence    GRP_OPS sequence       grp_idx
		tpBindVar  GrpLevel       GRP_OPS op_level       grp_idx
		tpBindVar  GrpLevelText   GRP_OPS op_level_txt   grp_idx
		tpBindVar  GrpOperator    GRP_OPS op_operator    grp_idx
		tpBindVar  GrpLHS         GRP_OPS op_left_value  grp_idx
		tpBindVar  GrpRHS         GRP_OPS op_right_value grp_idx
		tpBindVar  GrpOpStatus    GRP_OPS op_status      grp_idx
		
		
		ob::log::write DEBUG {<==go_group_rules}
		asPlayFile -nocache pmt/cpm_rule_grp.html
	}
	
	
	##
	# ADMIN::CPM_RULES::go_rules_test
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::go_rules_test]
	#
	# SCOPE
	#
	#       public
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Plays the inital template for testing CPM
	#       and Message rules. Only makes the necessary channel
	#       bindings and plays the template.
	#
	##
	proc go_rules_test {} {
		ob::log::write DEBUG {==>go_rules_test}
		
		#
		# Make the necessary bindings
		#
		
		# call to make channel bindings
		make_channel_binds "I" - 0
		
		
		#
		# Clean Up and Return
		#
		ob::log::write DEBUG {<==go_rules_test}
		asPlayFile -nocache pmt/cpm_rules_test.html
	}
	
	
	##
	# ADMIN::CPM_RULES::do_rules_test
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::do_rules_test]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       
	#
	# DESCRIPTION
	#
	#       Runs the CPM and Message rules test based on
	#       information the user has entered. Gets results for every
	#       rules scenario in the portal and displays the results to the user.
	#
	##
	proc do_rules_test {} {
		ob::log::write DEBUG {==>do_rules_test}
		
		global DB DEP_CPMS WTD_CPMS TEST_MSGS
		array set DEP_CPMS   [list]
		array set WTD_CPMS   [list]
		array set TEST_MSGS  [list]
		
		
		switch -- [reqGetArg SubmitName] { 
			"Test"
				{
					ob::log::write DEBUG {do_rules_test: Test}
					back_action_refresh
					
				}
				   
			"Back"  {
					ob::log::write DEBUG {do_rules_test: Back}
					back_action_backward
					return
			        }
				  
			default {
					ob::log::write DEBUG {do_rules_test: unknown SubmitName}
					go_cpm_rules
					return
			        }
		}
		
		
		#
		# Get the form details
		#
		tpSetVar showingResults 1
		set test_username [reqGetArg Username]
		tpBindString Username $test_username
		set cust_id       ""
		set and_suspended [reqGetArg AndSuspended]
		set channels      [make_channel_str "CN_"]
		
		if {$and_suspended == ""} {
			set and_suspended 0
		} else {
			tpSetVar AndSuspended 1
		}
		
		
		set sql [subst {
			select
				cust_id
			from
				tCustomer
			where
				username = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {set res  [inf_exec_stmt $stmt $test_username]} msg] } {
			ob::log::write ERROR {DB ERROR : $msg}
			err_bind "DB ERROR : $msg"
			go_rules_test
			return
		} elseif {[db_get_nrows $res] != 1} {
			ob::log::write ERROR {query did not return 1 row - is this happening?}
			err_bind "User $test_username does not exist"
			go_rules_test
			return
		}
		
		set cust_id [db_get_col $res 0 cust_id]
		inf_close_stmt $stmt
		
		
		
		#
		# Build up the method information
		#
		
		# for each transaction type get the 
		# registered CPM's
		set has_dep_cpm 0
		set has_wtd_cpm 0
		
		set dep_result [CPMRules::get_active_cpm_for $cust_id "DEP" $channels 1]
		
		if {[lindex $dep_result 0]} {
			set has_dep_cpm 1
			tpSetVar hasDepCPM 1
			set mthd_desc [CPMRules::convert_mthds_to_descs [list [lindex $dep_result 1]]]
			tpBindString depCPM [lindex $mthd_desc 0]
		}
		
		set wtd_result [CPMRules::get_active_cpm_for $cust_id "WTD" $channels 1]
		
		if {[lindex $wtd_result 0]} {
			set has_wtd_cpm 1
			tpSetVar hasWtdCPM 1
			set mthd_desc [CPMRules::convert_mthds_to_descs [list [lindex $wtd_result 1]]]
			tpBindString wtdCPM [lindex $mthd_desc 0]
		}
		
		
		
		# if we dont have a previously active registerd
		# pay method for a transaction type then
		# get a list of available ones the customer would have.
		if {!$has_dep_cpm} {
			# customer does not have an active deposit method
			set result [CPMRules::check_avail_cpms $cust_id "DEP" "" $channels $and_suspended]
			set result [CPMRules::convert_mthds_to_descs $result]
			
			# set the the array
			set DEP_CPMS(num_cpms) [llength $result]
			for {set i 0} {$i < $DEP_CPMS(num_cpms)} {incr i} {
				set DEP_CPMS($i,pay_mthd) [lindex $result $i]
			}
			
			# make the bindings
			tpSetVar numDepCPMs $DEP_CPMS(num_cpms)
			tpBindVar  DepPayMthd    DEP_CPMS pay_mthd      dep_idx
		}
		
		if {!$has_wtd_cpm} {
			# customer does not have an active deposit method
			set result [CPMRules::check_avail_cpms $cust_id "WTD" "" $channels $and_suspended]
			set result [CPMRules::convert_mthds_to_descs $result]
			
			# set the the array
			set WTD_CPMS(num_cpms) [llength $result]
			for {set i 0} {$i < $WTD_CPMS(num_cpms)} {incr i} {
				set WTD_CPMS($i,pay_mthd) [lindex $result $i]
			}
			
			# make the bindings
			tpSetVar numWtdCPMs $WTD_CPMS(num_cpms)
			tpBindVar  WtdPayMthd    WTD_CPMS pay_mthd      wtd_idx
		}
		
		
		
		# now get all the messages the customer would see
		# at login, registration*, deposit, withdrawal
		
		set total_msgs 0
		foreach msg_point {"DEP" "LOGIN" "REG" "WTD"} {
			
			set mres [CPMRules::check_for_cpm_msg $cust_id $msg_point "" $channels $and_suspended]
			
			set num_msgs [lindex $mres 0]
			set msgs [lindex $mres 1]
			
			
			
			# build the array
			for {set i 0} {$i < $num_msgs} {incr i} {
				set TEST_MSGS($total_msgs,msg_point) $msg_point
				set msg_code                         [lindex $msgs $i]
				set TEST_MSGS($total_msgs,code)      $msg_code
				set TEST_MSGS($total_msgs,xlation)   "\[Message does not exist\]"
				
				# set the xlation if possible
				set code_res [get_xlate_code_id $msg_code]
				set code_id ""
				set success [lindex $code_res 0]
				if {$success} {
					set code_id [lindex $code_res 1]
					
					set en_xlation [ADMIN::MSG::ml_get_xlation $code_id "en"]
					
					if {$en_xlation != ""} {
						set TEST_MSGS($total_msgs,xlation)   $en_xlation
					} else {
						set TEST_MSGS($total_msgs,xlation) "\[English Translation not set\]"
					}
				}
		
		
				incr total_msgs
			}
			
		}
		
		tpSetVar totalMsgs    $total_msgs
		tpBindVar  MsgPoint   TEST_MSGS  msg_point msg_idx
		tpBindVar  MsgCode    TEST_MSGS  code      msg_idx
		tpBindVar  MsgXlation TEST_MSGS  xlation   msg_idx
		
		
		
		#
		# Clean Up and Return
		#
		ob::log::write DEBUG {<==do_rules_test}
		make_channel_binds $channels - 0
		asPlayFile -nocache pmt/cpm_rules_test.html
	}
	
	
#######################################################################################################
#
#                                    HELPER PROCS
#
#######################################################################################################

	##
	# ADMIN::CPM_RULES::get_xlate_code_id
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::get_xlate_code_id]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       
	# RETURN
	#
	#       <code_id> - the code_id of the message code provided       
	#
	# DESCRIPTION
	#
	#       Helper Proc. Gets the code_id for a given Multi lingual message.
	#
	##
	proc get_xlate_code_id {msg_code} {
		ob::log::write DEBUG {==>get_xlate_code_id}
		
		global DB
		set code_id ""
		
		
		#
		# Execute the query 
		#
		set sql [subst {
			select
				code_id,
				group,
				read_only
			from
				txlatecode
			where
				code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {set res  [inf_exec_stmt $stmt $msg_code]} msg] } {
			ob::log::write ERROR {DB ERROR : $msg}
			db_close $res
			return [list 0]
		}
		
		if {[db_get_nrows $res] != 1} {
			return [list 0]
		}
		
		set code_id [db_get_col $res 0 code_id]
		
		
		#
		# Clean up and Return
		#
		ob::log::write DEBUG {<==get_xlate_code_id}
		return [list 1 $code_id]
	}

	##
	# ADMIN::CPM_RULES::get_pay_schemes
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::get_pay_schemes]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       rule_id
	#
	# RETURN
	#
	#
	# DESCRIPTION
	#
	#       Helper Proc. Binds the payment method schemes for display
	#
	##
	proc get_pay_schemes {rule_id} {
		global SCHEMES DB
		catch {unset SCHEMES}

		set sql {
			select
				case
					when nvl(r.alt_cpm_id, -1) != -1 then 'checked'
					else ''
				end checked,
				c.view_constr_id,
				c.desc,
				r.disporder
			from
				tViewPMConstr c,
				outer tCPMRuleAltCPM r
			where
				r.rule_id = ? and
				r.pay_mthd = c.pay_mthd and
				r.type     = c.type
			order by
				view_constr_id
		}

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {set res [inf_exec_stmt $stmt $rule_id]} msg]} {
			ob::log::write ERROR {DB ERROR : $msg}
			return [list 0]
		}
		inf_close_stmt $stmt

		set SCHEMES(nrows) [db_get_nrows $res]
		for {set i 0} {$i < $SCHEMES(nrows)} {incr i} {
			set SCHEMES($i,pay_scheme_id)        [db_get_col $res $i view_constr_id]
			set SCHEMES($i,pay_scheme_desc)      [db_get_col $res $i desc]
			set SCHEMES($i,pay_scheme_checked)   [db_get_col $res $i checked]
			set SCHEMES($i,pay_scheme_disporder) [db_get_col $res $i disporder]
		}
		db_close $res

		tpSetVar  NumSchemes $SCHEMES(nrows)
		tpBindVar PaySchemeId   SCHEMES pay_scheme_id        scheme_idx
		tpBindVar PaySchemeDesc SCHEMES pay_scheme_desc      scheme_idx
		tpBindVar PaySchemeChkd SCHEMES pay_scheme_checked   scheme_idx
		tpBindVar PaySchemeDisp SCHEMES pay_scheme_disporder scheme_idx
	}

	##
	# ADMIN::CPM_RULES::set_pay_schemes
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::set_pay_schemes]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       [rule_id] - rule with which these CPMs are associated
	#
	# RETURN
	#
	#
	# DESCRIPTION
	#
	#       Helper Proc. Updates the set of alternative pay methods that are
	#       associated with this rule
	#
	##
	proc set_pay_schemes {rule_id} {
		global DB

		# Work out the complete set of pay methods
		set sql {
			select
				view_constr_id
			from
				tViewPMConstr
			order by
				view_constr_id
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set num_schemes [db_get_nrows $res]

		# ADD is a list that will contain the set of suggested
		# CPMs that the rule should next be associated with
		set ADD [list]
		for {set i 0} {$i < $num_schemes} {incr i} {
			set view_constr_id [db_get_col $res $i view_constr_id]
			if {[reqGetArg Sch_$view_constr_id] != ""} {
				lappend ADD $view_constr_id
				set DISP_ARG($view_constr_id) [reqGetArg DO_$view_constr_id]
			}
		}
		db_close $res

		# Work out what is already selected for this rule
		set sql {
			select
				r.alt_cpm_id,
				c.view_constr_id
			from
				tCPMRuleAltCPM r,
				tViewPMConstr c
			where
				r.rule_id = ? and
				r.pay_mthd = c.pay_mthd and
				r.type     = c.type
			order by
				view_constr_id
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $rule_id]
		inf_close_stmt $stmt

		set selected    [list]
		set alt_cpm_ids [list]
		set CURRENT(nrows) [db_get_nrows $res]
		for {set i 0} {$i < $CURRENT(nrows)} {incr i} {
			set CURRENT($i,view_constr_id) [db_get_col $res $i view_constr_id]
			set CURRENT($i,alt_cpm_id)     [db_get_col $res $i alt_cpm_id]
		}
		db_close $res

		# Work out which schemes should be disassociated
		set REM [list]
		set UPD [list]
		for {set i 0} {$i < $CURRENT(nrows)} {incr i} {
			set idx [lsearch $ADD $CURRENT($i,view_constr_id)]
			if {$idx != -1} {
				# Add to the UPD list just in case the disporder has changed
				lappend UPD $CURRENT($i,alt_cpm_id)
				set DISP($CURRENT($i,alt_cpm_id)) $DISP_ARG($CURRENT($i,view_constr_id))

				# Remove from the add list as it's already in the DB
				set ADD [lreplace $ADD $idx $idx]
			} else {
				# Add it to the remove list
				lappend REM $CURRENT($i,alt_cpm_id)
			}
		}

		# The lists REM and ADD should now have those pay methods
		# that should be removed/inserted in tCPMRuleAltCPM
		# UPD will contain the list of ids that may need
		# their disporders updating
		set sql_add {
			insert into tCPMRuleAltCPM (
				rule_id,
				pay_mthd,
				type,
				disporder
			) values (
				?,
				(select pay_mthd from tViewPMConstr where view_constr_id = ?),
				(select type from tViewPMConstr where view_constr_id = ?),
				?
			)
		}

		set sql_upd {
			update
				tCPMRuleAltCPM
			set
				disporder = ?
			where
				alt_cpm_id = ?
		}

		set sql_del {
			delete from
				tCPMRuleAltCPM
			where
				alt_cpm_id = ?
		}

		# Add the CPMs that are new
		set stmt_add [inf_prep_sql $DB $sql_add]
		foreach view_constr_id $ADD {
			inf_exec_stmt $stmt_add $rule_id $view_constr_id $view_constr_id $DISP_ARG($view_constr_id)
		}
		inf_close_stmt $stmt_add

		# Update the disporders of those that are
		# already there and not being removed
		set stmt_upd [inf_prep_sql $DB $sql_upd]
		foreach alt_cpm_id $UPD {
			inf_exec_stmt $stmt_upd $DISP($alt_cpm_id) $alt_cpm_id
		}
		inf_close_stmt $stmt_upd

		# Delete from tCPMRuleAltCPM
		set stmt_del [inf_prep_sql $DB $sql_del]
		foreach alt_cpm_id $REM {
			inf_exec_stmt $stmt_del $alt_cpm_id
		}
		inf_close_stmt $stmt_del

	}

	##
	# ADMIN::CPM_RULES::set_dep_decl_msg
	#
	# SYNOPSIS
	#
	#       [ADMIN::CPM_RULES::set_dep_decl_msg <code> <n>]
	#
	# SCOPE
	#
	#       private
	#
	# PARAMS
	#
	#       [code] - xlation code, excluding the prefix part
	#       [n]    - 1 for primary, 2 for secondary
	#
	# RETURN
	#
	#
	# DESCRIPTION
	#
	#       Helper Proc. Binds up the deposit decline message
	#
	##
	proc set_dep_decl_msg {code n} {

		set code_res [get_xlate_code_id \
			[OT_CfgGet DEP_DECL_PREFIX "PMT_ERR_RULE_"]$code]
		set success [lindex $code_res 0]

		if {$success} {
			set code_id [lindex $code_res 1]

			tpBindString MsgCodeId_$n       $code_id
			tpSetVar     MsgCodeExists_$n   1
		
			set en_xlation [ADMIN::MSG::ml_get_xlation $code_id "en"]
			if {$en_xlation != ""} {
				tpBindString MsgXlation_$n $en_xlation
				tpSetVar     en_xlation_exists_$n 1
			} else {
				tpBindString MsgXlation_$n "\[No English Translation Set\]"
				tpSetVar     en_xlation_exists_$n 0
			}
		} else {
			tpBindString MsgXlation_$n "\[No English Translation Set\]"
		}

	}
}
