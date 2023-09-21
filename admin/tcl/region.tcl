# ==============================================================
# $Id: region.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::REGION {


asSetAct ADMIN::REGION::GoRegions   [namespace code go_regions]
asSetAct ADMIN::REGION::GoRegion    [namespace code go_region]
asSetAct ADMIN::REGION::DoRegion    [namespace code do_region]



proc go_regions args {

	global DB
	variable REGIONS

	GC::mark ADMIN::REGION::REGIONS

	set sql {
		select
			region_id,
			name,
			status,
			languages
		from
			tRegion
		order by disporder
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c {
			region_id
			name
			status
			languages
		} {
			set REGIONS($i,$c) [db_get_col $res $i $c]
		}
	}

	tpSetVar num_regions $nrows

	tpBindVar region_id      ADMIN::REGION::REGIONS region_id        region_idx
	tpBindVar region_name    ADMIN::REGION::REGIONS name      region_idx
	tpBindVar region_status  ADMIN::REGION::REGIONS    status    region_idx
	tpBindVar region_languages  ADMIN::REGION::REGIONS languages region_idx

	catch {db_close $res}

	asPlayFile -nocache regions.html
}

proc go_region args {

	global DB

	set region_id [reqGetArg region_id]

	if {$region_id != ""} {

		set sql {
			select
				region_id,
				name,
				status,
				languages,
				disporder
			from
				tRegion
			where
				region_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt $region_id]

		inf_close_stmt $stmt

		foreach c {
			region_id
			name
			status
			languages
			disporder
		} {
			tpBindString reg_$c [db_get_col $res 0 $c]
		}

		make_language_binds [db_get_col $res 0 languages] "-" 0

		catch {db_close $res}

	} else {

		make_language_binds "" "-" 1
		tpSetVar region_add 1

	}

	asPlayFile -nocache region.html

}

proc do_region args {

	global DB

	set type [reqGetArg SubmitName]

	set region_name   [reqGetArg region_name]
	set reg_status    [reqGetArg reg_status]
	set language      [make_language_str]
	set reg_disporder [reqGetArg reg_disporder]

	if {$reg_disporder eq ""} {
		set reg_disporder 0
	}

	switch -exact -- $type {
		"regionAdd" {

			set sql {
				execute procedure pInsRegion(
					p_name     = ?,
					p_status   = ?,
					p_languages = ?,
					p_disporder = ?
				)
			}

			set stmt [inf_prep_sql $DB $sql]

			inf_begin_tran $DB

			if { [catch {

				set res [inf_exec_stmt $stmt\
					$region_name\
					$reg_status\
					$language\
					$reg_disporder]

				inf_close_stmt $stmt
				catch {db_close $res}

			} msg]} {
				inf_rollback_tran $DB
				OT_LogWrite 2 "Failed to insert region: $msg"
			} else {
				inf_commit_tran $DB
			}
			go_regions
		}
		"regionUpd" {
			set region_id [reqGetArg region_id]
			set sql {
				execute procedure pUpdRegion(
					p_region_id = ?,
					p_name = ?,
					p_status   = ?,
					p_languages = ?,
					p_disporder = ?
				)
			}

			set stmt [inf_prep_sql $DB $sql]

			inf_begin_tran $DB

			if {[catch {

				set res [inf_exec_stmt $stmt\
					$region_id\
					$region_name\
					$reg_status\
					$language\
					$reg_disporder]

				inf_close_stmt $stmt
				catch {db_close $res}

			} msg]} {
				inf_rollback_tran $DB
				OT_LogWrite 2 "Failed to update region: $msg"
			} else {
				inf_commit_tran $DB
			}
			go_regions
		}
		"Back" {
			go_regions
			return
		}
	}
}


}
#end of namespace
