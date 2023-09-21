# ==============================================================
# $Id: form_runner.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


#
# ----------------------------------------------------------------------------
# Look up selection for runner 
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::lookup_runner_selection { ev_oc_id seln_ref } {
	global DB

	upvar $seln_ref seln
	set sql {
		select
			ev_oc_id,
			desc,
			disporder
		from
			tEvOC
		where
			ev_oc_id = ?
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $ev_oc_id]
	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		catch {db_close $rs}
		inf_close_stmt $stmt
		error "failed lookup_runner_selection: expected one row but got $nrows for ev_oc_id($ev_oc_id)"
	}

	set seln(ev_oc_id)  [db_get_col $rs 0 ev_oc_id]
	set seln(desc)      [db_get_col $rs 0 desc]
	set seln(disporder) [db_get_col $rs 0 disporder]

	catch {db_close $rs}
	inf_close_stmt $stmt

}


#
# ----------------------------------------------------------------------------
# Look up runner by race id and horse or cloth number
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::lookup_runner { form_provider_id ev_oc_id runner_ref } {
	global DB

	upvar $runner_ref runner
	set runner(runner_id)      ""
	set runner(horse)        ""
	set runner(cloth_num)    ""
	set runner(draw_num)     ""
	set runner(bred)         ""
	set runner(jockey)       ""
	set runner(trainer)      ""
	set runner(silk_id)      ""
	set runner(formguide)    ""
	set runner(updateable)   ""
	set runner(status)       ""

	# try to see if horse or cloth number can be matched
	set sql {
		select
			r.runner_id,
			r.competitor_id,
			r.race_id,
			r.wgt_stone,
			r.wgt_pound,
			r.age,
			r.rp_rating,
			r.unadj_master_rating,
			r.adj_master_rating,	
			r.trainer,
			r.days_since_run,
			r.runner_num,
			r.draw,
			r.jockey,
			r.owner,
			r.silk_name,
			r.form_guide,
			r.overview,
			r.sire_overview,
			r.breeding_overview,
			r.updateable runner_updateable,
			c.ext_competitor_id,
			c.name,
			c.sex,
			c.colour,
			c.updateable competitor_updateable
		from
			tFormRunner r,
			tFormCompetitor c
		where
			r.ev_oc_id = ? and
			r.form_provider_id = ? and
			r.competitor_id = c.competitor_id and
			c.form_provider_id = ?
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $ev_oc_id $form_provider_id $form_provider_id]
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set cols [db_get_colnames $rs]

		set runner(cols) $cols

		foreach col $cols {
			set runner($col)  [db_get_col $rs 0 $col]
		}
	}

	catch {db_close $rs}
	inf_close_stmt $stmt

}


#
# ----------------------------------------------------------------------------
# Go to Team Talk add/update for jockey and trainer information
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::go_runner args {

	global DB

	set ev_id     [reqGetArg EvId]
	tpBindString EvId $ev_id

	set ev_oc_id  [reqGetArg OcId]
	tpBindString OcId $ev_oc_id

	set form_provider_id [reqGetArg FormProviderId]
	tpBindString FormProviderId $form_provider_id

	ADMIN::FORM::lookup_runner_selection $ev_oc_id seln
	tpBindString EvOcName $seln(desc) 

	ADMIN::FORM::lookup_race_event $ev_id event
	ADMIN::FORM::lookup_race $form_provider_id $ev_id race

	if {$race(ext_race_id) == ""} {
		err_bind "No Form feed race exists for this horse"
		ADMIN::SELN::go_oc $ev_oc_id
		return
	}
	tpBindString RaceId $race(ext_race_id)

	# get runner information
	ADMIN::FORM::lookup_runner $form_provider_id $ev_oc_id runner

	if {$runner(runner_id) == ""} {
		err_bind "Selection has no form feed data available for this provider"
		ADMIN::EVENT::go_oc $ev_oc_id
		return

	} else {
		tpSetVar OpAdd 0

		foreach col $runner(cols) {
			tpBindString $col $runner($col)
		}

		tpSetVar RunnerUpdateable $runner(runner_updateable)
		tpSetVar CompetitorUpdateable $runner(competitor_updateable)
	}

	asPlayFile -nocache form/form_runner.html
}

#
# ----------------------------------------------------------------------------
# Manage Team Talk runner information
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::do_runner args {

	set act [reqGetArg SubmitName]

	switch -- $act {
		"Back"    { ADMIN::SELN::go_oc_upd }
		"RunnerMod" { do_runner_upd }
		default   { error "unexpected SubmitName: $act" }
	}

}

#
# ----------------------------------------------------------------------------
# Update Team Talk Runner Information
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::do_runner_upd args {

	global DB USERNAME

	# update the runner
	
	set sql {
		execute procedure pUpdFormRunner (
			p_adminuser  = ?,
			p_form_provider_id = ?,
			p_ext_competitor_id = ?,
			p_race_id = ?,
			p_name = ?,
			p_wgt_stone = ?,
			p_wgt_pound = ?,
			p_age = ?,
			p_rp_rating = ?,
			p_unadj_master_rating = ?,
			p_adj_master_rating = ?,
			p_trainer = ?,
			p_days_since_run = ?,
			p_runner_num = ?,
			p_draw = ?,
			p_jockey = ?,
			p_owner = ?,
			p_silk_name = ?,
			p_form_guide = ?,
			p_updateable = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {

		set res [inf_exec_stmt $stmt $USERNAME\
		                             [reqGetArg FormProviderId]\
		                             [reqGetArg ExtCompetitorId]\
		                             [reqGetArg RaceId]\
		                             [reqGetArg Name]\
		                             [reqGetArg WgtStone]\
		                             [reqGetArg WgtPound]\
		                             [reqGetArg Age]\
		                             [reqGetArg RpRating]\
		                             [reqGetArg UnAdjMasterRating]\
		                             [reqGetArg AdjMasterRating]\
		                             [reqGetArg Trainer]\
		                             [reqGetArg DaysSinceRun]\
		                             [reqGetArg RunnerNum]\
		                             [reqGetArg Draw]\
		                             [reqGetArg Jockey]\
		                             [reqGetArg Owner]\
		                             [reqGetArg SilkName]\
		                             [reqGetArg FormGuide]\
		                             [reqGetArg RunnerUpdateable]]
	} msg]} {
		
		err_bind $msg
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	# bit of a hack - we have to update the overviews seperately as they are
	# text blobs, and we cant add this into a sp as we want to be able to have 
	# defaults which you can't generate inside an sp

	set sql {
		update
			tFormRunner
		set
			overview = ?,
			sire_overview = ?,
			breeding_overview = ?
		where
			runner_id = ? and
			form_provider_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {

		set res [inf_exec_stmt -inc-type $stmt [reqGetArg Overview] TEXT\
		                             [reqGetArg SireOverview] TEXT\
		                             [reqGetArg BreedingOverview] TEXT\
		                             [reqGetArg RunnerId] STRING\
		                             [reqGetArg FormProviderId] STRING]
	} msg]} {
		
		err_bind $msg
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	set sql {
		execute procedure pUpdFormComp (
			p_adminuser  = ?,
			p_form_provider_id = ?,
			p_ext_competitor_id = ?,
			p_name = ?,
			p_sex = ?,
			p_colour = ?,
			p_updateable = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {

		set res [inf_exec_stmt $stmt $USERNAME\
		                             [reqGetArg FormProviderId]\
		                             [reqGetArg ExtCompetitorId]\
		                             [reqGetArg Name]\
		                             [reqGetArg Sex]\
		                             [reqGetArg Colour]\
		                             [reqGetArg CompetitorUpdateable]]
	} msg]} {
		
		err_bind $msg
	}

	inf_close_stmt $stmt
	catch {db_close $res}

	go_runner
}