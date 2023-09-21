# $Id: payment_BANK.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# Openbet
#
# Copyright (C) 2000 Orbis Technology Ltd. All rights reserved.
#

package require util_appcontrol

namespace eval payment_BANK {

	variable INIT 0

	namespace export init

}

proc payment_BANK::init args {

	variable INIT

	if {$INIT} {
		return
	}

	set INIT 1

	ob_db::init

	# Get bank template - which determines what fields are required
	ob_db::store_qry get_bank_template {
		select
			bank_template
		from
			tCountry
		where
			country_code = ?
	}

	# Get bank template - which determines what fields are required
	ob_db::store_qry get_envoy_template {
		select
			envoy_template
		from
			tCountry
		where
			country_code = ?
	}
}


#
# payment_BANK::get_templates
#
# Returns array of bank templates
#
# BANK_TEMPLATES(template_id_list) <LIST OF template ids>
# BANK_TEMPLATES(<template id>) <template name>
# BANK_TEMPLATES(<template id>,req_fields) <LIST OF REQUIRED FIELDS>
# BANK_TEMPLATES(<template id>,<field_name>,desc) <TRANSLATABLE TOKEN>
# BANK_TEMPLATES(<template id>,<field_name>,regex) <regular expression for validation>
# BANK_TEMPLATES(<template id>,<field_name>,check_proc) <procedure to validate value>
# BANK_TEMPLATES(<template id>,<field_name>,field_class) <class for customer screen field>
proc payment_BANK::get_templates {ARRAY} {
	upvar 1 $ARRAY BANK_TEMPLATES

	foreach template [OT_CfgGet BANK_TEMPLATE] {
		set template_id   [lindex $template 0]
		set template_name [lindex $template 1]
		set req_fields [OT_CfgGet BANK_TEMPLATE_$template_name]

		lappend BANK_TEMPLATES(template_id_list) $template_id
		set BANK_TEMPLATES($template_id) $template_name

		foreach reqField [OT_CfgGet BANK_TEMPLATE_$template_name] {
			set field_name [lindex $reqField 0]
			lappend BANK_TEMPLATES($template_id,req_fields) $field_name
			set BANK_TEMPLATES($template_id,$field_name,desc) \
				[lindex $reqField 1]
			set BANK_TEMPLATES($template_id,$field_name,regex) \
				[lindex $reqField 2]
			set BANK_TEMPLATES($template_id,$field_name,check_proc) \
				[lindex $reqField 3]
			set BANK_TEMPLATES($template_id,$field_name,field_class) \
				[lindex $reqField 4]
		}
	}
}



#  Check IBAN field
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
proc payment_BANK:check_iban {iban} {

	if {[ob_chk::iban $iban] == "OB_OK"} {
		return [list 1 IBAN_GOOD]
	} else {
		return [list 0 IBAN_FAILED]
	}
}



# Get the template id for a specific country
proc payment_BANK::get_bank_template_id {country_code} {
	# Determine what fields to be getting based on template
	if {[catch {set rs [ob_db::exec_qry get_bank_template \
					$country_code]} msg]} {
		catch {db_close $rs}
		ob_log::write ERROR \
				{payment_BANK::get_bank_template_id: couldn't get country template: $msg}
		return OB_ERR_BANK_TEMPLATE
	}

	set bank_template [db_get_coln $rs 0 0]
	db_close $rs

	return $bank_template
}



# Get the template id for a specific country
proc payment_BANK::get_envoy_template_id {country_code} {
	# Determine what fields to be getting based on template
	if {[catch {set rs [ob_db::exec_qry get_envoy_template \
					$country_code]} msg]} {
		catch {db_close $rs}
		ob_log::write ERROR \
				{payment_BANK::get_bank_template_id: couldn't get country template: $msg}
		return OB_ERR_BANK_TEMPLATE
	}

	set bank_template [db_get_coln $rs 0 0]
	db_close $rs

	return $bank_template
}
