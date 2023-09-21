# ==============================================================
# $Id: main.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

set xtn  [lindex $argv 0]
set argv [lrange $argv 1 e]


source ../shared_tcl/standalone.$xtn
source ../shared_tcl/err.$xtn
source ../shared_tcl/db.$xtn
source ../shared_tcl/util.$xtn

package require OB_Log
ob::log::init

readConfig

set cust [OT_CfgGet OPENBET_CUST]

source import.$xtn
source export_${cust}.$xtn
source import_${cust}.$xtn
source xgame_admin.$xtn
source xgame_admin_qrys.$xtn
source settle.$xtn
source settle-new.$xtn

array set sort_codes [list "VPOOLSM" 15 "VPOOLS11" 72 "VPOOLS10" 91 "LCLOVER3" 53 "LCLOVER5" 34]

proc dispUsage {} {
	puts stderr "Usage: main.tcl <config_file> CUST|BET|SUBCLOVER|SUBPOOLS|CONVERTSUBS|UPLOADRESULTS"
}

proc create_export_file {sort type} {

	global xgaQry

	set cr_date     [clock format [clock seconds] -format "%Y%m%d%H%M%S"]

	if {$sort != "" } {
		if {$sort == "LCLOVER%"} {
			set filename "C"
		} else {
			set filename "P"
		}
	} else {
		set filename ""
	}

	append filename "${type}DATA"
	append filename ".$cr_date"

	OT_LogWrite 20 "create_export_file: filename=$filename"

	if [catch {set rs [xg_exec_qry $xgaQry(create_export_file) $filename $sort $type]} msg] {
		return [handle_err "create_export_file"\
			    "error: $msg"]
	}

	db_close $rs

	if [catch {set rs [xg_exec_qry $xgaQry(get_export_files)]} msg] {
		return [handle_err "get_export_files"\
		    "error: $msg"]
	}

	set file_id [db_get_col $rs 0 xgame_ex_file_id]
	OT_LogWrite 1 "File id ======== $file_id"
	if {$file_id != ""} {
		export_file "F" [db_get_col $rs 0 xgame_ex_file_id]
	} else {
		return [handle_err "create_export_file" "failed to find xgame_ex_file_id"]
	}

}

proc create_bluesq_export_file args {

    global xgaQry

    if [catch {set rs [xg_exec_qry $xgaQry(get_recent_files)]} msg] {
        return [handle_err "get recent_files"\
                    "error: $msg"]
    }

    set num_files [db_get_coln $rs 0 0]

    if {$num_files == 0} {
    	set filename [clock format [clock seconds] -format "%Y%m%d%H%M%S"]
    	OT_LogWrite 1 "Creating file $filename"

    	if [catch {set rs [xg_exec_qry $xgaQry(create_export_file) $filename "Y"]} msg] {
       		 return [handle_err "create_export_file"\
                    "error: $msg"]
    	}
    	db_close $rs

    	create_physical_export_file $filename
     } else {
     		OT_LogWrite 1 "A file has already been created"
       }

}

proc handle_err {{str1 ""} {str2 ""}} {
	puts stderr "$str1 $str2"
}

proc create_physical_export_file  {filename} {
    global xgaQry

    set exportDirectory [OT_CfgGet EXPORT_DIR]
    if [catch {open $exportDirectory/$filename w 0775} exportFile] {
	OT_LogWrite 1 "Failed to open file $exportDirectory/$filename"
	return
    }

    set count_tc 0
    set count_sp 0
    set count_cp3 0
    set count_p3 0
    set count_p4 0
    set count_eff 0
    set count_essd 0
    set count_embs 0

    ## Generate records
    set record ""

    set rs [xg_exec_qry $xgaQry(get_xgame_ex_file_id) $filename]

    set xgame_ex_file_id [db_get_col $rs 0 xgame_ex_file_id]

    set rs [xg_exec_qry $xgaQry(get_bets_from_file) $xgame_ex_file_id]

    set nrows [db_get_nrows $rs]

    for {set r 0} {$r < $nrows} {incr r} {

        set sort [db_get_col $rs $r sort]
        set draw_at [db_get_col $rs $r draw_at]
        set cr_date [db_get_col $rs $r cr_date]
        set xgame_bet_id [db_get_col $rs $r xgame_bet_id]
        set comp_no [db_get_col $rs $r comp_no]
        set cust_id [db_get_col $rs $r cust_id]
        set picks [db_get_col $rs $r picks]

        # Bet_id
        append record [format {%-13d} $xgame_bet_id]

        set charity_field " "

        # Event Name
        set name "Unknown"
        switch -- $sort {
            MONTHPOOL {
                set name "Treble Chance"
                incr count_tc
            }
            SATPOOL {
                set name "Treble Chance"
                incr count_tc
            }
            BIGMATCH {
                set name "Spread Pool"
                incr count_sp
            }
            PBUST3 {
                set name "Prizebuster 3"
                incr count_p3
                set charity_field "1"
            }
            PBUST4 {
                set name "Prizebuster 4"
                incr count_p4
                set charity_field "1"
            }
            EFINAL4 {
                set name "Euro 2000 FF"
                incr count_eff
            }
            ESIXSD {
                set name "Euro 2000 SSD"
                incr count_essd
            }
            EBIGMATCH {
                set name "Euro 2000 BMS"
                incr count_embs
            }
            CPBUST3 {
                set name "Celtic Prizebuster"
                incr count_cp3
                set charity_field "3"
            }
        }
        append record [format {%-20s} $name]

        ## Competition date/time
        set date "-----------"
        set time "--------"
        regexp {[0-9][0-9]-[a-zA-Z]{3,3}-[0-9]{4,4}} $draw_at date
        regexp {[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}} $draw_at time
        append record [string tolower $date]
        append record $time

        ## Bet date/time
        set date "-----------"
        set time "--------"
        regexp {[0-9][0-9]-[a-zA-Z]{3,3}-[0-9]{4,4}} $cr_date date
        regexp {[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}} $cr_date time
        append record [string tolower $date]
        append record $time

        ## Comp no
        regexp {[0-9]{4,4}} $draw_at temp
        append temp [format {%02d} $comp_no]
        append record [format {%-8d} $temp]

        # Game Version
        append record [format {%-10s} $charity_field]

        # Cust ID (actually the account ID)
        append record [format {%-13d} $cust_id]

        # Selections
        set selections ""
        foreach p [split $picks "|"] {
            append selections [format {%02d} $p]
        }
        append record [format {%-20s} $selections]

        # Final line break - don't add to last line
	if {$r < [expr $nrows -1]} {
        	append record "\n"
	}
    }
    db_close $rs

    if [catch {set rs [xg_exec_qry $xgaQry(get_file_details) $xgame_ex_file_id]} msg] {
        return [handle_err "get_file_details"\
                    "error: $msg"]
    }
    set cr_date [db_get_col $rs 0 cr_date]
    db_close $rs

    # Write header
    set header ""
    # Bet_id = 0 in header
    append header [format %013d 0]
    # Transmission no
    append header [format {%-10d} $xgame_ex_file_id]
    # Event Name
    append header [format {%-20s} Control]

    # Sent Date/Time
    set date "-----------"
    set time "--------"
    regexp {[0-9][0-9]-[a-zA-Z]{3,3}-[0-9]{4,4}} $cr_date date
    regexp {[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}} $cr_date time
    append header $date
    append header $time

    # number of each event
    set prizebuster5 0
    foreach i {count_tc count_sp count_p3 count_p4 prizebuster5 count_embs count_eff count_essd count_cp3 } {
        append header [format {%-6d} [set $i]]
    }
    # Final line break - only add if some records exist
    if {$record != ""} {
    	append header "\n"
    }

    puts $exportFile $header$record
    close $exportFile

    ## The physical file has been created
    ## set created = Y in tXGamePhExFile

    xg_exec_qry $xgaQry(set_xgame_ph_ex_file_created) $xgame_ex_file_id

    return
}

proc find_games_to_export args {
	global xgaQry

	if [catch {set rs [xg_exec_qry $xgaQry(get_lw_games_closed_in_last_five_mins)]} msg] {
        	return [handle_err "get_lw_games_closed_in_last_five_mins"\
                    "error: $msg"]
	}
	set nrows [db_get_nrows $rs]
	if {$nrows == 0} {
		exit 0
	} else {
		## If a file has been created since the game closed do nothing
		set shut_at [db_get_col $rs 0 shut_at]
		set filename [string map {"-" "" " " "" ":" ""} $shut_at]
		if [catch {set files [xg_exec_qry $xgaQry(get_files) $filename]} msg] {
			return [handle_err "get_file" "error: $msg"]
		}
		set num_files [db_get_nrows $files]
		if {$num_files > 0} {
			exit 0
		}
		db_close $files
	  }
	db_close $rs
	exit 1
}

#
# ----------------------------------------------------------------------------
# Open additional log files - this is used mainly for debugging/testing
# ----------------------------------------------------------------------------
#
proc main_aux_logs args {

        set LOG_AUX [string trim [OT_CfgGet LOG_AUX ""]]

        if {$LOG_AUX == ""} {
                return
        }

        foreach ld $LOG_AUX {

                foreach {l_tok l_name l_level l_mode l_rot} $ld { break }

                global $l_tok

                if {$l_tok == "LOG_EMAIL"} {
                        set LOG_AUX_DIR [string trim [OT_CfgGet EMAIL_LOG_DIR]]
                } else {
                        set LOG_AUX_DIR [string trim [OT_CfgGet LOG_DIR ""]]
                  }

                set c [catch {
                        set l [OT_LogOpen\
                                -rotation $l_rot\
                                -mode     $l_mode\
                                -level    $l_level [file join $LOG_AUX_DIR $l_name]]
                } msg]

                if {!$c} {
                        set $l_tok $l
                }
        }
}

## Main code to execute relevant export routine
namespace import OB_db::*
db_init


## Prepare queries
populate_xgame_import_queries
populate_xgame_export_queries
populate_xgame_admin_queries


global argv EMAIL_TYPES

if {[llength $argv] < 2} {
	dispUsage
	exit 0
}

foreach {email_type email_id} [OT_CfgGet EMAIL_TYPES ""] {
	set EMAIL_TYPES($email_type) $email_id
}

# Set up the failed-email log to track emails which were not sent
# to BlueSQ customer services

main_aux_logs

switch -- [lindex $argv 1] {
	"CUST" {
		create_customers_export_file F
	}

	"BET" {
		if {[OT_CfgGet OPENBET_CUST] == "BlueSQ"} {
			create_bluesq_export_file "" "BET"
		} else {
			create_export_file "" "BET"
		  }
	}

	"CHECKCLOSETIMES" {
		find_games_to_export
	}

	"SUBCLOVER" {
		create_export_file "LCLOVER%" "SUB"
	}

	"SUBPOOLS" {
		create_export_file "VPOOLS%" "SUB"
	}

	"CONVERTSUBS" {
		global_insert_outstanding_subs "-"
	}

	"UPLOADRESULTS" {
		xgame_import_file "[lindex $argv 2]"
	}

	default {
		dispUsage
		exit 0
	}

}

puts stderr "**** Finished output [lindex $argv 1] ****"
exit 0
