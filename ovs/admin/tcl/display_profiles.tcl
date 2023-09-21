# $Id: display_profiles.tcl,v 1.1 2011/10/04 12:41:15 xbourgui Exp $
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::VERIFICATION::PROFILES {

asSetAct ADMIN::VERIFICATION::PROFILES::getprofiles    [namespace code get_avail_profiles]



proc get_avail_profiles args {
	
	global OVSCHK EXACT_PROF DB
	
	set profile_def_id [reqGetArg profile_def_id]
	#
	#get all of the profiles 
	#
	set matching_profiles [ADMIN::VERIFICATION::PROVIDER::do_check_matching $profile_def_id]

	OT_LogWrite ERROR "COMPLETED do_check_matching (OUTSIDE PROC!!!!!)******BYOUNG******"
	OT_LogWrite ERROR "matching_profiles = $matching_profiles"

	#BEGIN Get OVS Checks
		set sql [subst {
			select
				vrf_chk_type as check_name
			from
				tVrfChkDef
			where
				vrf_prfl_def_id = $profile_def_id
		}]
	
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set check_num [db_get_nrows $res]

		for {set j 0} {$j < $check_num} {incr j} {
			set OVSCHK($j,check_name) [db_get_col $res $j check_name]
		}

		tpSetVar num_sub_checks $check_num

		tpBindVar submitted_checks   OVSCHK check_name      chan_idx

		
		#More Housekeeping
		ob_db::rs_close $res
	#END Get OVS Checks




	#
	#  do_check_matching will return a  list of lists [ [list1] [list2] [list3] ]
	#
	#  list1 - contains a list of profile_ids for exact matches
	#  list2 - contains a list of profile_ids that are complete profiles
	#	   but are not an exact match.
	#  list3 - contains a list of profile_ids for profiles that are incomplete

	
	#
	#  Build the sql IN clause for the required sections
	#
	#Set in clause to be the start 
	set in_clause_exact "("
	set in_clause_complete "("
	set in_clause_incomplete "("

	set a [llength $matching_profiles]
	OT_LogWrite ERROR "matching profiles length= $a"

	#Check to see list length is correct
	if {[llength $matching_profiles] != 3} {
		#Housten, we have a problem!
		
		
	}
	
	#Flag to determine if there is any exact profiles
	# 0=no exact profiles (default)
	set skip_best_fit 0

	#Check to see if there is any exact profiles
	set exact [lindex $matching_profiles 0]
	set prof_comp [lindex $matching_profiles 1]
	set prof_incomp [lindex $matching_profiles 2]


	set a [llength $exact]
	set b [llength $prof_comp]
	set c [llength $prof_incomp]
	OT_LogWrite ERROR "exact profiles length= $a"
	OT_LogWrite ERROR "complete profiles length= $b"
	OT_LogWrite ERROR "incomplete profiles length= $c"


	if { [llength $exact] > 0 } {

		OT_LogWrite ERROR "found exact match"
		#Exact matches exist
		foreach elem $exact {
			#Add the profile id to the list
			append in_clause_exact $elem
		}

		#Just do the exact match
		set skip_best_fit 1
		
		#close the in_clause_ list
		append in_clause_exact ")"		
		OT_LogWrite ERROR "finished exact"
	} else {
		OT_LogWrite ERROR "exact else"
		#No exact matches 
		#Add all complete and incomplete profiles to each
		#of the vars for use in the respective queries
		
		#BEGIN Complete Checks
			foreach elem $prof_comp {
				#Add the profile id to the list
				append in_clause_complete $elem
			}
			
			#close the in_clause_ list
			append in_clause_complete ")"		
		#END Complete Checks

		#BEGIN Incomplete Checks
			foreach elem2 $prof_incomp {
				#Add the profile id to the list
				append in_clause_incomplete $elem2
			}
			
			#close the in_clause_ list
			append in_clause_incomplete ")"		
		#END Incomplete Checks
	}


	if {$skip_best_fit == 1} {
		OT_LogWrite ERROR "enter exact logic"
		#--------------------------------------------------------------
		#
		#    			Exact Profile matching
		#
		#	This section is called when there is one or more provider
		#   profiles that exactly match the submitted OVS profile. 
		#   This negates the need for best fit profile matching.
		#
		#---------------------------------------------------------------
	
	
		OT_LogWrite ERROR "ente2r clause = $in_clause_exact"

		#BEGIN Exact Profiles Found
		
			set sql [subst {
				select
					c.vrf_ext_prov_id,
					c.name as prov_name,
					c.priority,
					a.vrf_ext_pdef_id as profile_id,
					a.prov_prf_id as provider_uuid,
					a.description as desc
				from
					tVrfExtProv  c,
					tVrfExtPrflDef   a
				where
					c.vrf_ext_prov_id = a.vrf_ext_prov_id AND
					c.status = 'A' AND
					a.status = 'A' AND
					a.vrf_ext_pdef_id IN $in_clause_exact
				order by
					c.priority ASC
			}]
		
			OT_LogWrite ERROR "before 1"
			set stmt [inf_prep_sql $DB $sql]
			OT_LogWrite ERROR "before 2"
			set res2  [inf_exec_stmt $stmt]
			OT_LogWrite ERROR "before 3"
			inf_close_stmt $stmt
			
			for {set i 0} {$i < [db_get_nrows $res2]} {incr i} {
				
				set EXACT_PROF($i,profileID) [db_get_col $res2 $i profile_id]
				set EXACT_PROF($i,provider_uuid) [db_get_col $res2 $i provider_uuid]
				set EXACT_PROF($i,prov_name) [db_get_col $res2 $i prov_name]
				set EXACT_PROF($i,description) [db_get_col $res2 $i desc]
				OT_LogWrite ERROR "EXACT_PROF($i,profileID) = $EXACT_PROF($i,profileID)"
				OT_LogWrite ERROR "EXACT_PROF($i,prov_name) = $EXACT_PROF($i,prov_name)"
			}

			#set pcount [db_get_nrows $res2]

			#tpSetVar num_profs $pcount
			#tpBindVar Provider  EXACT_PROF prov_name    prov_idx
			#tpBindVar Desc	    EXACT_PROF description  prov_idx
			OT_LogWrite ERROR "returning"
			return [array get EXACT_PROF]
			#OT_LogWrite ERROR "playing file"
			#asPlayFile -nocache display_profiles.html

		#END Exact Profiles Found

	} else {

		#---------------------------------------------------------------------
		#
		#    			Best Fit Profile matching
		#
		#	This section is called when there is no profiles that exactly
		#   match the one being submitted.  In this case, other profiles 
		#   (complete or incomplete) have to used to produce a 'best fit'
		#
		#   NOTE: For more information on how this is done, see provider.tcl
		#   
		#----------------------------------------------------------------------
	
	
		#BEGIN Completed Profiles








		#END Completed Profiles



		#
		#  Also check the incomplete profiles
		#
		#
		#BEGIN Incomplete Profiles








		#END Incomplete Profiles
		

		
		#asPlayFile -nocache display_profiles.html

	};#End Else

}
#End get_avail_profiles


}
#Close namespace