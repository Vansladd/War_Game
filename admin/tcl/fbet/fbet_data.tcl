# ==============================================================
# $Id: fbet_data.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval OB_fbet_data {	

	# -------------------------------------------------------------
	# Play the game search screen
	# -------------------------------------------------------------
	
	proc go_fantasy_games_search {} {
	
			get_games_and_affiliates_for_search
			OB_fbet_init::play_file fbet/game_sel.html	
	}	
	

	# -------------------------------------------------------------
	# Get the list of available games and affiliates for the search 
	# -------------------------------------------------------------
	
	proc get_games_and_affiliates_for_search {} {
		
		global DB GAME AFFS
		
		# Get and bind the game id's
		set sql {
			select
				game_id
			from 
				tGame
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set rows [db_get_nrows $res]
		for {set r 0} {$r < $rows} {incr r} {		
			set GAME($r,game_id) [db_get_col $res $r game_id]
		}
		
		tpSetVar  NumGames  $rows
		tpBindVar GameID	GAME game_id  game_idx	
		
		# Get and bind the affiliate names
		get_affiliates		
	}


	# -------------------------------------------------------------
	# Get the affiliates for use with gane search and game add/update
	# -------------------------------------------------------------
	
	proc get_affiliates {} {
		
		global DB AFFS
	
		set sql {
			select
				aff_name,
				aff_id
			from 
				tAffiliate
			where 
				status = 'A'
		}
	
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	
		set rows [db_get_nrows $res]
		for {set r 0} {$r < $rows} {incr r} {		
			set AFFS($r,aff_name) [db_get_col $res $r aff_name]
			set AFFS($r,aff_id)   [db_get_col $res $r aff_id]
		}
				
		tpSetVar  NumAffs   $rows				
		tpBindVar AffName	AFFS aff_name aff_idx
		tpBindVar AffID		AFFS aff_id   aff_idx
	}
	
	

	# -------------------------------------------------------------
	# Play the game input/update screen or the list of games
	# -------------------------------------------------------------
	
	proc go_fantasy_games {} {
	
		global AFFS
	
		# Show the list of games
		if {[reqGetArg SubmitName] == "GameShow"} {

			# Show list of games
			get_fantasy_game
			
			# Set permissions
			tpSetVar CanAddGame 1
	    	OB_fbet_init::play_file fbet/game_list.html	
			
		# Add a new game
		} elseif {[reqGetArg SubmitName] == "GameAdd"} {
		
			# Get the affiliates for the drop down
			get_affiliates

			# Go to game input screen
			tpSetVar NewGame 1
			tpSetVar Status  A
			
			# Set permissions
			tpSetVar GameUpdate 1
	    	OB_fbet_init::play_file fbet/game_input.html	
		
		# Go back
		} else {
			go_fantasy_games_search
		}
	}	


	# -------------------------------------------------------------
	# Get game from db for update
	# -------------------------------------------------------------	

	proc get_fantasy_game {} {
	
		global DB
	
		set game_id 	[reqGetArg GameID]		
		set date_sel 	[reqGetArg DateRange]
		set date_lo		[reqGetArg DateLo]
		set date_hi		[reqGetArg DateHi]
		set aff_id		[reqGetArg AffID]
		set period		[reqGetArg Period]
		set price		[reqGetArg Price]
		set status		[reqGetArg Status]

		# Sort out the date selection range
		set d_lo "'0001-01-01 00:00:00'"
		set d_hi "'9999-12-31 23:59:59'"

		if {$date_lo != "" || $date_hi != ""} {
		
			if {$date_lo != ""} {
				set d_lo "'$date_lo 00:00:00'"
			}
			
			if {$date_hi != ""} {
				set d_hi "'$date_hi 23:59:59'"
			}
		}

		set where "g.initial_start >= $d_lo and g.initial_start <= $d_hi"
		
		# Other selection criteria
		if {$game_id != 0} {
			append where " and g.game_id = '$game_id'"
		}
		
		if {$aff_id != "0" && $aff_id != ""} {
			append where " and g.aff_id = '$aff_id'"
		}
		
		if {$period != "0" && $period != ""} {
			append where " and g.period_cycle = '$period'"
		}	
		
		if {$price != "" && $price != ""} {
			append where " and g.entry_price = '$price'"
		}	
		
		if {$status != "-" && $status != ""} {
			append where " and g.status = '$status'"
		}	
		
		OT_LogWrite 9 "$where"
		
		set sql [subst {
			select 
				g.game_id,
				g.aff_id,
				g.initial_start,
				g.entry_price,
				g.status,
				a.aff_name
			from
				tGame g,
				outer tAffiliate  a
			where
				$where and
				a.aff_id = g.aff_id}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]		
		tpSetVar game_rows [db_get_nrows $res]
	
		tpBindTcl GameID 	 sb_res_data $res game_idx game_id
		tpBindTcl Price 	 sb_res_data $res game_idx entry_price
		tpBindTcl AffID 	 sb_res_data $res game_idx aff_id
		tpBindTcl AffName 	 sb_res_data $res game_idx aff_name
		tpBindTcl Start 	 sb_res_data $res game_idx initial_start
		tpBindTcl Status 	 sb_res_data $res game_idx status
	}	


	# -------------------------------------------------------------
	# Insert/Update the new game, or go back
	# -------------------------------------------------------------
	
	proc do_fantasy_game_insert {} {
		
		# Add the new game
		if {[reqGetArg SubmitName] == "AddGame"} {
		
			do_fantasy_game_insert_core
			
		# Update an existing game
		} elseif {[reqGetArg SubmitName] == "UpdGame"} {
			
			do_fantasy_game_update_core
			
		# Show associated game periods
		} elseif {[reqGetArg SubmitName] == "ShowPeriods"} {

			go_game_periods

		# Go back
		} else {
			go_fantasy_games_search
		}
	}


	# -------------------------------------------------------------
	# Actaully do the game insertion
	# -------------------------------------------------------------	
	
	proc do_fantasy_game_insert_core {} {
	
		global DB
		
		# Get the argumnets from the form
		set aff_id			[reqGetArg AffID]
		set start			[reqGetArg Start]
		set period_cycle	[reqGetArg Period]
		set entry_price		[reqGetArg Price]
		set start_balance	[reqGetArg Balance]
		set status 			[reqGetArg Status]
		set blurb 			[reqGetArg Blurb]
				
		# Query to insert a game
		set sql [subst {
			execute procedure pInsGame (
									p_aff_id		= ?,
									p_start 		= ?,
									p_period_cycle 	= ?,
									p_entry_price 	= ?,
									p_start_balance = ?,
									p_status 		= ?,
									p_blurb 		= ?
			)
		}]		
		
		set stmt [inf_prep_sql $DB $sql]
		set bad  0
		
		if {[catch {
			set res  [inf_exec_stmt $stmt \
				$aff_id \
				$start \
				$period_cycle \
				$entry_price \
				$start_balance \
				$status \
				$blurb]} msg]} {
				
			err_bind $msg
			set bad  1
		}
				
		inf_close_stmt $stmt

		if {($bad == 1) || ([db_get_nrows $res] != 1)} {
		
			# Something went wrong : go back to the game with the form elements reset
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}				
			
			reqSetArg SubmitName GameAdd
	   		OB_fbet_data::go_fantasy_games
	   		return			
		}
		
		reqSetArg GameID [db_get_coln $res 0 0]
		tpSetVar GameAdded 1
		
		db_close $res
		
	   	OB_fbet_data::display_fantasy_game	    	
	}


	# -------------------------------------------------------------
	# Update a current game
	# -------------------------------------------------------------	
	
	proc do_fantasy_game_update_core {} {
	
		global DB
		
		# Get the argumnets from the form
		set game_id			[reqGetArg GameID]
		set period_cycle	[reqGetArg Period]
		set entry_price		[reqGetArg Price]
		set start_balance	[reqGetArg Balance]
		set status 			[reqGetArg Status]
		set blurb 			[reqGetArg Blurb]
		
		# Query to update a game
		set sql [subst {
			execute procedure pUpdGame (
									p_game_id = ?,
									p_period_cycle = ?,
									p_entry_price = ?,
									p_start_balance = ?,
									p_status = ?,
									p_blurb = ?
			)
		}]	
		
		set stmt [inf_prep_sql $DB $sql]
		set bad  0
		
		if {[catch {
			set res  [inf_exec_stmt $stmt \
				$game_id \
				$period_cycle \
				$entry_price \
				$start_balance \
				$status \
				$blurb]} msg]} {
				
			err_bind $msg
			set bad  1
		}
				
		inf_close_stmt $stmt

		if {($bad == 1)} {
		
			# Something went wrong : go back to the event with the form elements reset
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}				
			
	   		OB_fbet_data::display_fantasy_game
	   		return			
		}	
		
		tpSetVar GameUpdated 1
		
		db_close $res
	
		OB_fbet_data::display_fantasy_game	
	}


	# -------------------------------------------------------------
	# Display a current game
	# -------------------------------------------------------------	

	proc display_fantasy_game {} {

		global DB

		set game_id [reqGetArg GameID]
	
		# Flag to show it's not a new game
		tpSetVar NewGame 0
		
		# Permimssions
		tpSetVar GameUpdate 1
		
		# Get the data for the game
		set sql [subst {
			select 
				g.game_id,
				g.aff_id,
				g.initial_start,
				g.period_cycle,
				g.entry_price,
				g.start_balance,
				g.status,
				g.blurb,
				a.aff_name
			from
				tGame g,
				outer tAffiliate  a
			where
				g.game_id = ? and
				a.aff_id = g.aff_id}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $game_id]
		
		tpBindString GameID 	$game_id
		tpBindString AffID		[db_get_col $res aff_id]
		tpBindString AffName	[db_get_col $res aff_name]		
		tpBindString Start		[db_get_col $res initial_start]
		tpSetVar 	 Period		[db_get_col $res period_cycle]		
		tpBindString Price 		[db_get_col $res entry_price]
		tpBindString Balance	[db_get_col $res start_balance]
		tpSetVar 	 Status 	[db_get_col $res status]
		tpBindString Blurb		[db_get_col $res blurb]
		
	   	OB_fbet_init::play_file fbet/game_input.html
		
		db_close $res
	}


	# -------------------------------------------------------------
	# Display a list of all periods associated with the game
	# -------------------------------------------------------------	

	proc go_game_periods {} {
	
		global DB
	
		set game_id [reqGetArg GameID]
		
		set sql [subst {
			select 
				p.game_period_id,
				p.period_number,
				p.start,
				p.end,
				p.pos_calc_at,
				p.status						
			from
				tGame g,
				tGamePeriod p
			where
				g.game_id = p.game_id and
				p.game_id = ?}]
		
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $game_id]	
		tpSetVar period_rows [db_get_nrows $res]
		
		tpBindString GameID	$game_id
		tpBindTcl PeriodID 		sb_res_data $res period_idx game_period_id
		tpBindTcl PeriodNumber	sb_res_data $res period_idx period_number
		tpBindTcl Start			sb_res_data $res period_idx start
		tpBindTcl End			sb_res_data $res period_idx end
		tpBindTcl Status		sb_res_data $res period_idx status
		
	   	OB_fbet_init::play_file fbet/period_list.html
		
		db_close $res
	}


	# -------------------------------------------------------------
	# Display the standings for the period
	# -------------------------------------------------------------	

	proc go_period_standings {} {
	
		global DB
		
		set period_id [reqGetArg PeriodID]
		
		# Get the period details
		set sql [subst {
			select 
				status,
				start,
				end,
				pos_calc_at,
				period_number
			from
				tGamePeriod
			where
				game_period_id = ?}]	
		
		set stmt [inf_prep_sql $DB $sql]
		set res1 [inf_exec_stmt $stmt $period_id]
		
		OT_LogWrite 9 "nrows = [db_get_nrows $res1]	"
		
		tpSetVar  	  PeriodStatus  [db_get_col $res1 status]
		tpBindString  GameID		[reqGetArg GameID]
		tpBindString  PeriodID		$period_id
		tpBindString  Status  		[db_get_col $res1 status]
		tpBindString  PeriodNumber  [db_get_col $res1 period_number]
		tpBindString  Start 		[db_get_col $res1 start]
		tpBindString  End 			[db_get_col $res1 end]
		tpBindString  PosCalcAt 	[db_get_col $res1 pos_calc_at]
		
		# Get the standings
		set sql [subst {
					select 
						g.cust_id,
						g.position,
						g.balance,
						g.total,
						g.unsettled_stakes,
						c.username
					from
						tCustGame 	g,
						tGamePeriod p,
						tCustomer 	c
					where
						g.game_period_id = p.game_period_id and
						c.cust_id 		 = g.cust_id 		and
						c.status		 = 'A'				and
						p.game_period_id = ?}]	
				
		set stmt [inf_prep_sql $DB $sql]
		set res2 [inf_exec_stmt $stmt $period_id]
		tpSetVar standings_rows [db_get_nrows $res2]	
		
		tpBindTcl CustomerName 	sb_res_data $res2 standings_idx username
		tpBindTcl Position		sb_res_data $res2 standings_idx position
		tpBindTcl Balance		sb_res_data $res2 standings_idx balance
		tpBindTcl Unsettled		sb_res_data $res2 standings_idx unsettled_stakes
		tpBindTcl Total			sb_res_data $res2 standings_idx total
		
		OB_fbet_init::play_file fbet/period_view.html
		
		db_close $res1
		db_close $res2
	}
}