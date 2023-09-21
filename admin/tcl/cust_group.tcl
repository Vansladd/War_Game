# ==============================================================
# $Id: cust_group.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CUST_GROUP {

asSetAct ADMIN::CUST_GROUP::GoCustGroupSetup   [namespace code go_cust_group_setup]
asSetAct ADMIN::CUST_GROUP::GoCustGroupProduct [namespace code go_cust_group_product]
asSetAct ADMIN::CUST_GROUP::DoCustGroupProduct [namespace code do_cust_group_product]
asSetAct ADMIN::CUST_GROUP::GoCustGroupTier    [namespace code go_cust_group_tier]
asSetAct ADMIN::CUST_GROUP::DoCustGroupTier    [namespace code do_cust_group_tier]



#
# Display list of all available group products and tiers
#
proc go_cust_group_setup args {

	global DB
	global PRODUCTS
	global TIERS

	catch {unset PRODUCTS}
	catch {unset TIERS}

	# get all the available products
	set sql {select
				d.group_name,
				d.group_desc,
				d.group_type,
				d.dflt_grp_val_id,
				v.value_desc
			from
				tGroupDesc d, outer
				tGroupValue v
			where
				d.dflt_grp_val_id = v.group_value_id}
	
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i 1} {
		set PRODUCTS($i,name)   [db_get_col $rs $i group_name]
		set PRODUCTS($i,desc)   [db_get_col $rs $i group_desc]
		set PRODUCTS($i,type)   [db_get_col $rs $i group_type]
		set PRODUCTS($i,is_def) [db_get_col $rs $i dflt_grp_val_id]
		set PRODUCTS($i,def_desc) [db_get_col $rs $i value_desc]
	}

	# bind up the vars for products
	tpSetVar  num_products $nrows
	tpBindVar group_name   PRODUCTS name     p_idx
	tpBindVar group_desc   PRODUCTS desc     p_idx
	tpBindVar group_type   PRODUCTS type     p_idx
	tpBindVar is_default   PRODUCTS is_def   p_idx
	tpBindVar default_desc PRODUCTS def_desc p_idx


	# now get all the available tiers
	set sql {select
				group_value_id,
				group_name,
				group_value,
				value_desc
			from
				tGroupValue
			order by
				group_name,
				group_value_id}
	
	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i 1} {
		set TIERS($i,id)    [db_get_col $rs $i group_value_id]
		set TIERS($i,name)  [db_get_col $rs $i group_name]
		set TIERS($i,value) [db_get_col $rs $i group_value]
		set TIERS($i,desc)  [db_get_col $rs $i value_desc]
	}

	# Bind up all the vars for the tiers
	tpSetVar  num_tiers      $nrows
	tpBindVar group_value_id TIERS id    t_idx
	tpBindVar tier_name     TIERS name  t_idx
	tpBindVar tier_value    TIERS value t_idx
	tpBindVar tier_desc     TIERS desc  t_idx

	asPlayFile -nocache cust_group_setup.html
}



#################
# GROUP PRODUCTS
#################

#
# display details about the selected group product
#
proc go_cust_group_product args {

	global DB
	global CUST_GROUPS

	catch {unset CUST_GROUPS}

	set group_name [reqGetArg group_name]

	if {$group_name == ""} {
		# adding a new product
		tpSetVar gp_type Add
		tpBindString gp_group_type         SEG
		asPlayFile -nocache cust_group_product.html
		return
	} else {
		tpSetVar gp_type Update
	}

	# get product info
	set sql "select
				group_name,
				group_desc,
				group_type,
				multi_value,
				dflt_grp_val_id
			from
				tGroupDesc
			where
				group_name = '$group_name'"
	
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		# Error
		asPlayFile -nocache cust_group_setup.html
		return
	}

	set group_name [db_get_col $rs 0 group_name]
	set group_desc [db_get_col $rs 0 group_desc]
	set group_type [db_get_col $rs 0 group_type]
	set multi_value [db_get_col $rs 0 multi_value]
	set dflt_grp_val_id [db_get_col $rs 0 dflt_grp_val_id]

	tpBindString gp_group_name         $group_name
	tpBindString gp_group_desc         $group_desc
	tpBindString gp_group_type         $group_type
	tpBindString gp_multi_value        $multi_value
	tpBindString gp_dflt_grp_val_id $dflt_grp_val_id

	# get a list of options for the default group dropdown
	set sql "select
				group_value_id,
				value_desc
			from
				tGroupValue
			where group_name = '$group_name'";

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i 1} {
		set CUST_GROUPS($i,id)   [db_get_col $rs $i group_value_id]
		set CUST_GROUPS($i,desc) [db_get_col $rs $i value_desc]
	}

	tpSetVar def_num_rows $nrows
	tpBindVar group_val_id CUST_GROUPS id   def_idx
	tpBindVar value_desc   CUST_GROUPS desc def_idx

	asPlayFile -nocache cust_group_product.html
}



#
# Add/Update/Delete a group product, or go back to the group list
#
proc do_cust_group_product args {

	set submit_name [reqGetArg SubmitName]

	switch -exact -- $submit_name {
		Add {
			_do_add_cust_group_product
		}
		Update {
			_do_update_cust_group_product
		}
		Back {
			go_cust_group_setup
		}
		Delete {
			_do_delete_cust_group_product
		}
		default {
			OT_LogWrite 2 "CUST_GROUP: Invalid SubmitName in do_cust_group_product."
			go_cust_group_product
		}
	}

}



#
# Update a group product
#
proc _do_update_cust_group_product args {

	global DB

	# get the request parameters
	set group_name      [reqGetArg group_name]
	set group_desc      [reqGetArg group_desc]
	set group_type      [reqGetArg group_type]
	set multi_value     [reqGetArg multi_value]

	if {$group_name == ""} {
		OT_LogWrite 2 "CUST_GROUP: Error Group name is a required field"
		tpSetVar IsError 1
		tpBindString ErrMsg "Error Group name is a required field"
		go_cust_group_product
		return
	}

	# create query
	set sql "update
				tGroupDesc
			set
				group_desc      = '$group_desc',
				group_type      = '$group_type',
				multi_value     = '$multi_value'
			where
				group_name      = '$group_name'"
				
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 2 "CUST_GROUP: Error updating tGroupDesc for group_name=$group_name: $msg"
		tpSetVar isError 1
		tpBindString ErrMsg "Error updating Customer Group Product: $msg"
		go_cust_group_product
		return
	}

	# otherwise, display setup page
	go_cust_group_setup
}



#
# Add a new group product
#
proc _do_add_cust_group_product args {

	global DB

	# get the request parameters
	set group_name      [reqGetArg group_name]
	set group_desc      [reqGetArg group_desc]
	set group_type      [reqGetArg group_type]
	set multi_value     [reqGetArg multi_value]

	
	if {$group_name == ""} {
		OT_LogWrite 2 "CUST_GROUP: Error Group name is a required field"
		tpSetVar IsError 1
		tpBindString ErrMsg "Error Group name is a required field"
		go_cust_group_product
		return
	}

	set sql "insert into tGroupDesc (
				group_name,
				group_desc,
				group_type,
				multi_value)
			values (
				'$group_name',
				'$group_desc',
				'$group_type',
				'$multi_value'
			)"
	
	set stmt [inf_prep_sql $DB $sql]
	
	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 2 "CUST_GROUP: Error inserting into tGroupDesc for group_name=$group_name: $msg"
		tpSetVar IsError 1
		tpBindString ErrMsg "Error inserting Customer Group Product: $msg"
		go_cust_group_product
		return
	}

	# otherwise, display setup page
	go_cust_group_setup
}



#
# Delete a group product
#
proc _do_delete_cust_group_product args {

	global DB

	set group_name [reqGetArg group_name]

	# check for linked tables - tGroupDesc and tCustGroupChng
	# if any customer has ever been assigned to a group within selected
	# product, it cannot be deleted

	set sql "select
				1
			from
				tGroupValue
			where
				group_name = '$group_name'"

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set group_value_nrows [db_get_nrows $rs]

	set sql "select
				1
			from
				tCustGroupChng
			where
				group_name = '$group_name'"
	
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set cust_group_chng_nrows [db_get_nrows $rs]

	if {$cust_group_chng_nrows > 0 || $group_value_nrows > 0} {
		# product referenced by other tables - cannot delete
		err_bind "Cannot delete product. Product has either got tiers set up or a customer has been assigned to a tier within this product"
		go_cust_group_product
		return
	}

	# nothing references it, so do the delete

	set sql "delete from
				tGroupDesc
			where
				group_name = '$group_name'"
	
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt} msg]} {
		err_bind "Error deleting group: $msg"
		go_cust_group_tier
		return
	}

	# otherwise, display setup page
	go_cust_group_setup
}



################
# GROUP TIERS
################

#
# Display detailed information about a group tier
#
proc go_cust_group_tier args {

	global DB
	global GROUP_PRODUCTS

	set group_value_id [reqGetArg group_value_id]

	if {$group_value_id == ""} {
		# Adding a new tier
		tpSetVar gt_type Add
	} else {
		tpSetVar gt_type Update
	}

	# get group value data
	if {$group_value_id != ""} {
		set sql "select
					group_value_id,
					group_name,
					group_value,
					value_desc
				from
					tGroupValue
				where
					group_value_id = $group_value_id"

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		set nrows [db_get_nrows $rs]

		if {$nrows != 1} {
			# error
		} else {
			tpBindString gt_group_value_id [db_get_col $rs 0 group_value_id]
			tpBindString gt_group_name     [db_get_col $rs 0 group_name]
			tpBindString gt_group_value    [db_get_col $rs 0 group_value]
			tpBindString gt_value_desc     [db_get_col $rs 0 value_desc]

			set group_name [db_get_col $rs 0 group_name]
		}

		# find out if this is the default tier for the selected product
		set sql "select
					dflt_grp_val_id
				from
					tGroupDesc
				where
					group_name = '$group_name'"

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		if {[db_get_col $rs 0 dflt_grp_val_id] == $group_value_id} {
			# this is the default value
			tpBindString default_for_group "Y"
		} else {
			tpBindString default_for_group "N"
		}

	}

	# get a list of all the available group_names
	set sql {select
				group_name
			from
				tGroupDesc}
	
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i 1} {
		set GROUP_PRODUCTS($i,name) [db_get_col $rs $i group_name]
	}

	tpSetVar num_products $nrows
	tpBindVar group_name GROUP_PRODUCTS name p_idx

	asPlayFile -nocache cust_group_tier.html
}






#
# Add/Update/Delete a group tier or go Back to the group list
#
proc do_cust_group_tier args {

	set submit_name [reqGetArg SubmitName]

	switch -exact -- $submit_name {
		Add {
			_do_add_cust_group_tier
		}
		Update {
			_do_update_cust_group_tier
		}
		Back {
			go_cust_group_setup
		}
		Delete {
			_do_delete_cust_group_tier
		}
		default {
			OT_LogWrite 2 "CUST_GROUP: Invalid SubmitName in do_cust_group_product."
			go_cust_group_tier
		}
	}
}



#
# Update a group tier
#
proc _do_update_cust_group_tier args {

	global DB

	# get the request parameters
	set group_name     [reqGetArg group_name]
	set group_value_id [reqGetArg group_value_id]
	set group_value    [reqGetArg group_value]
	set value_desc     [reqGetArg value_desc]

	if {$group_name == ""} {
		OT_LogWrite 2 "CUST_GROUP: Error Group name is a required field"
		tpSetVar IsError 1
		tpBindString ErrMsg "Group name is a required field"
		go_cust_group_tier
		return	
	}
	if {$group_value == ""} {
		OT_LogWrite 2 "CUST_GROUP: Error Group value is a required field"
		tpSetVar IsError 1
		tpBindString ErrMsg "Group value is a required field"
		go_cust_group_tier
		return	
	}


	# create query
	set sql "update
				tGroupValue
			set
				group_name      = '$group_name',
				group_value     = '$group_value',
				value_desc      = '$value_desc'
			where
				group_value_id  = '$group_value_id'"
				
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 2 "CUST_GROUP: Error updating tGroupValue for group_value_id=$group_value_id: $msg"
		tpSetVar IsError 1
		tpBindString ErrMsg "Error updating Customer Group Tier: $msg"
		go_cust_group_tier
		return
	}

	# update the default tier
	set default_for_group [reqGetArg default_for_group]
	set default_sql ""
	
	if {$default_for_group eq "Y"} {

		# easy case - if set to Y, set the default value for the group to this tier
		set default_sql "update
							tGroupDesc
						set
							dflt_grp_val_id = $group_value_id
						where
							group_name      = '$group_name'"
	} else {

		# slightly more complicated - if set to N, check to see what the current
		# default value is - if it's not this tier, do nothing. If it is currently
		#this tier, clear it.

		set sql "select
					dflt_grp_val_id
				from
					tGroupDesc
				where
					group_name = '$group_name'"

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		set curr_default [db_get_col $rs 0 dflt_grp_val_id]

		if {$curr_default == $group_value_id} {
			set default_sql "update
								tGroupDesc
							set
								dflt_grp_val_id = null
							where
								group_name      = '$group_name'"
		}
	}

	if {$default_sql ne ""} {
		set stmt [inf_prep_sql $DB $default_sql]

		if {[catch {inf_exec_stmt $stmt} msg]} {
			OT_LogWrite 2 "CUST_GROUP: Error updating dflt_grp_val_id in tGroupDesc for group_name=$group_name: $msg"
			tpSetVar IsError 1
			tpBindString ErrMsg "Error setting default tier: $msg"
			go_cust_group_tier
			return
		}
	}

	# otherwise, display setup page
	go_cust_group_setup
}



#
# Add a group tier
#
proc _do_add_cust_group_tier args {

	global DB

	# get the request parameters
	set group_name     [reqGetArg group_name]
	set group_value    [reqGetArg group_value]
	set value_desc     [reqGetArg value_desc]

	if {$group_name == ""} {
		OT_LogWrite 2 "CUST_GROUP: Error Group name is a required field"
		tpSetVar IsError 1
		tpBindString ErrMsg "Error Group name is a required field"
		go_cust_group_tier
		return
	}

	if {$group_value == ""} {
		OT_LogWrite 2 "CUST_GROUP: Error Group value is a required field"
		tpSetVar IsError 1
		tpBindString ErrMsg "Error Group value is a required field"
		go_cust_group_tier
		return
	}


	set sql {
		execute procedure pInsGroupValue(
			p_group_name  = ?,
			p_group_value = ?,
			p_value_desc  = ?
		);
	}
	
	set stmt [inf_prep_sql $DB $sql]
	
	if {[catch {inf_exec_stmt $stmt \
					$group_name \
					$group_value \
					$value_desc
		} msg]} {
		OT_LogWrite 2 "CUST_GROUP: Error inserting into tGroupValue: $msg"
		tpSetVar IsError 1
		tpBindString ErrMsg "Error inserting Customer Group Tier: $msg"
		go_cust_group_tier
		return
	}

	# get the new group_value_id
	set group_value_id [db_get_col $msg 0 [db_get_colnames $msg]]
	db_close $msg

	# now if this has been selected as default, set it
	set default_for_group [reqGetArg default_for_group]

	if {$default_for_group eq "Y"} {
		set sql "update
					tGroupDesc
				set
					dflt_grp_val_id = $group_value_id
				where
					group_name      = '$group_name'"

		set stmt [inf_prep_sql $DB $sql]
		
		if {[catch {inf_exec_stmt $stmt} msg]} {
			OT_LogWrite 2 "CUST_GROUP: Error inserting default value into tGroupDesc: $msg"
			tpSetVar IsError 1
			tpBindString ErrMsg "Error setting default value for Customer Group: $msg"
			go_cust_group_tier
			return
		}
	}
	# otherwise, display setup page
	go_cust_group_setup
}



#
# Delete a group Tier
#
proc _do_delete_cust_group_tier args {

	global DB

	set group_value_id [reqGetArg group_value_id]
	set group_name     [reqGetArg group_name]

	set sql {
		execute procedure pDelGroupValue(
			p_group_value_id = ?
		);
	}
	
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt $group_value_id} msg]} {
		err_bind "Error deleting group: $msg"
		go_cust_group_tier
		return
	}

	# otherwise, display setup page
	go_cust_group_setup

}

}
