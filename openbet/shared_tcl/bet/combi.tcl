################################################################################
# $Id: combi.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Produces standard combinations of legs for each of the bet types
#
# Configuration:
#    Does not read config file use ob_bet::init -[various options] to
#    customise
#
# Synopsis:
#    package require bet_bet ?4.5?
#
# Procedures:
#    ob_bet::bet_type_lines bet_type = returns bet_type lines for bet_type
################################################################################

namespace eval ob_bet {
}


proc ::ob_bet::_bet_type_lines {bet_type} {

	variable TYPE

	#only need to look up the result once
	if {[info exists TYPE($bet_type,lines)]} {
		return $TYPE($bet_type,lines)
	}

	#make sure this type is in the DB
	if {![info exists TYPE($bet_type,num_selns)]} {
		error\
			"Bet type $bet_type not in DB"\
			""\
			COMBI_INVALID_BET_TYPE
	}

	set lines [list]

	#make a list of legs we will be combining
	set legs [list]
	for {set i 0} {$i < $TYPE($bet_type,num_selns)} {incr i} {
		lappend legs $i
	}

	switch -- $TYPE($bet_type,line_type) {
		"M" {
			#lines are retrieved by looking at the min max selns
			set min_combi $TYPE($bet_type,min_combi)
			set max_combi $TYPE($bet_type,max_combi)

			for {set i $min_combi} {$i <= $max_combi} {incr i} {
				if {[catch {
					set combis [ot::genCombis $i $legs]
				} msg]} {
					error\
						"Unable to generate combinations $msg"\
						""\
						COMBI_CANT_GET_COMBIS
				}

				foreach c $combis {
					lappend lines $c
				}
			}
		}
		"S" {
			#these are stakes about lines
			set lines [ot::genPerms 2 $legs]
		}
		"-" {
			#these are bet types with exotic line combinations
			#such as the union jack bet
			set lines [_get_lines_for_exotic_type $bet_type]

		}
		default {
			error\
				"Unknown line type for bet type: $bet_type"\
				""\
				COMBI_BET_TYPE_LINE_TYPE_INVALID
		}
	}

	set TYPE($bet_type,lines) $lines
	return $lines
}



proc ::ob_bet::_get_lines_for_exotic_type {bet_type} {

	switch -- $bet_type {
		"UJK" {
			#Union Jack: legs 0-8 in a square:
			# 0 1 2
			# 3 4 5
			# 6 7 8
			#and then trebles
			#placed through the 3 verticals, 3 horizontals
			#and 2 diagonals
			set lines {
				{0 3 6} {1 4 7} {2 5 8}
				{0 1 2} {3 4 5} {6 7 8}
				{0 4 8} {2 4 6}
			}
		}
		"L7B" {
			#Lucky 7 Bingo: Arrange 7 legs like an "H"
			# 0   1
			# 2 3 4
			# 5   6
			# and then doubles of the corners and the horizontal
			# trebles of the diagonals
			# fivefold of the corners and middle
			# and the sevenfold
			set lines {
				{0 1} {0 5} {0 6} {1 5} {1 6} {5 6} {2 3} {2 4} {3 4}
				{0 3 6} {1 3 5}
				{0 1 3 5 6} {0 1 2 3 4 5 6}
			}
		}
		"MAG7" {
			#Magnificent Seven:
			#put all 7 selections in order then take all
			#the consecutavive singles,doubles etc.. up to the seven fold
			set lines {
				{0 1 2 3 4 5 6}
				{0 1 2 3 4 5} {1 2 3 4 5 6}
				{0 1 2 3 4} {1 2 3 4 5} {2 3 4 5 6}
				{0 1 2 3} {1 2 3 4} {2 3 4 5} {3 4 5 6}
				{0 1 2} {1 2 3} {2 3 4} {3 4 5} {4 5 6}
				{0 1} {1 2} {2 3} {3 4} {4 5} {5 6}
				0 1 2 3 4 5 6
			}
		}
		"PON" {
			#Ponderosa:
			#put all 6 selections in order then take all
			#the consecutavive singles,doubles etc.. up to the six fold
			set lines {
				{0 1 2 3 4 5}
				{0 1 2 3 4} {1 2 3 4 5}
				{0 1 2 3} {1 2 3 4} {2 3 4 5}
				{0 1 2} {1 2 3} {2 3 4} {3 4 5}
				{0 1} {1 2} {2 3} {3 4} {4 5}
				0 1 2 3 4 5
			}
		}
		"FSP" {
			#Five Spot:
			#put all 5 selections in order then take all
			#the consecutavive singles,doubles etc.. up to the five fold
			set lines {
				{0 1 2 3 4}
				{0 1 2 3} {1 2 3 4}
				{0 1 2} {1 2 3} {2 3 4}
				{0 1} {1 2} {2 3} {3 4}
				0 1 2 3 4
			}
		}
		"ROB" {
			#pick 2 from 3,the treble and
			#single stakes about on the three selns
			set lines {
				{0 1} {0 2} {1 2} {0 1 2}
				{0 1} {1 0} {1 2} {2 1} {0 2} {2 0}
			}
		}
		"FLG" {
			#pick 2 from 4, 3 from 4, the fourfold
			#single stakes about on the four selections
			set lines {
				{0 1} {0 2} {0 3} {1 2} {1 3} {2 3}
				{0 1 2} {0 1 3} {0 2 3} {1 2 3}
				{0 1 2 3}
				{0 1} {1 0} {0 2} {2 0} {0 3} {3 0}
				{1 2} {2 1} {1 3} {3 1} {2 3} {3 2}
			}
		}
		default {
			error\
				"Unknown lines for bet type: $bet_type"\
				""\
				COMBI_BET_TYPE_LINES_UNKNOWN
		}
	}

	return $lines
}

::ob_bet::_log INFO "sourced combi.tcl"
