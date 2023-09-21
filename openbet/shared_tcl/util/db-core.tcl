# $Id: db-core.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C)2005 Orbis Technology Ltd. All rights reserved.
#
# Provides a backend neutral system for common application that can be used
# by other implementation of a database interface.
#
# Configuration:
#    none
#
# Synopsis:
#   package require util_db_core ?4.5?
#
# Procedures:
#    ob_db_core::init         - initialize
#    ob_db_core::is_64bit_db  - find out if a connection is 64bit
#    ob_db_core::log_locks    - log the locks on the current database server
#



# Dependecies
#
package provide util_db_core 4.5
package require util_log



# Variables
#
namespace eval ob_db_core {

	variable INIT 0
	variable CFG

	# An array of connections indicating if they're connected to a
	# 64 bit database.
	#
	variable IS_64BIT_DB
}



#---------------------------------------------------------------------------
# Initialisation
#---------------------------------------------------------------------------

# Initialise.
#
proc ob_db_core::init args {

	variable INIT
	variable CFG

	if {$INIT} {
		return
	}

	if { [catch {
		package present Infsql
	}] } {

		if { [catch {
			load libOT_InfTcl[info sharedlibextension]
		} err] } {
			error "failed to load Informix TCL library: $err"
		}

	}

	set INIT 1
}



#---------------------------------------------------------------------------
# Procedures
#---------------------------------------------------------------------------

# Determines if the Informix server is a 64bit server
#
#   conn    - name of the connection as returned by inf_open_conn
#   returns - 0 or 1
#
proc ob_db_core::is_64bit_db {conn} {

	variable IS_64BIT_DB

	# We cache these results.
	#
	if {[info exists IS_64BIT_DB($conn)]} {
		return $IS_64BIT_DB($conn)
	}

	# Use the tabid trick to get database information.
	#
	set sql {
		select DBINFO('version','os') from sysTables where tabid = 1
	}

	set stmt [inf_prep_sql $conn $sql]
	set rs  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	switch -- [db_get_coln $rs 0 0] {
		F {
			set IS_64BIT_DB($conn) 1
		}
		T -
		U -
		H {
			set IS_64BIT_DB($conn) 0
		}
		default {
			# this error is not expected
			error "Unknown database version/os"
		}
	}

	db_close $rs

	return $IS_64BIT_DB($conn)
}



# Log current database locks.
#
#   conn - name of the database
#
proc ob_db_core::log_locks {conn} {

	variable CFG

	ob_log::write WARNING {DB: locks: [format \
		{%-18s %-18s %4s %6s %5s %-16s %6s} \
		database \
		table \
		lock \
		sid \
		pid \
		hostname \
		age(s)]}

	ob_log::write WARNING {DB: locks: [format \
		{%-18s %-18s %4s %6s %5s %-16s %6s} \
		------------------ \
		------------------ \
		---- \
		------ \
		----- \
		---------------- \
		------]}


	# 64-bit servers have slightly different sysmaster tables.
	# Note that we log all locks, since they are shared across databases
	# and the problem may not be with a lock on our database.
	#
	set sql [subst {
		select
			l.partnum,
			p.dbsname,
			p.tabname,
			l.rowidr,
			l.keynum,
			l.grtime,
			DECODE(l.type,
				 0, 'NONE',
				 1, 'BYTE',
				 2, 'IS',
				 3, 'S',
				 4, 'SR',
				 5, 'U',
				 6, 'UR',
				 7, 'IX',
				 8, 'SIX',
				 9, 'X',
				10, 'XR') type,
			r.sid,
			s.pid,
			s.hostname
		from
			sysmaster:syslcktab l,
			sysmaster:systabnames p,
			sysmaster:systxptab x,
			sysmaster:sysrstcb r,
			sysmaster:sysscblst s
		where
			l.partnum  <> 1048578
		and l.partnum  = p.partnum
		and l.owner    = x.address
		and x.owner    = r.address
		and r.sid      = s.sid
			[expr {[is_64bit_db $conn] ? {
				and l.ownerpad = x.addresspad
				and x.ownerpad = r.addresspad
			} : {}}]
		order by
			l.grtime desc
	}]

	set now [clock seconds]

	set stmt [inf_prep_sql $conn $sql]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {

		set dbsname  [db_get_col $rs $r dbsname]
		set tabname  [db_get_col $rs $r tabname]
		set type     [db_get_col $rs $r type]
		set sid      [db_get_col $rs $r sid]
		set pid      [db_get_col $rs $r pid]
		set hostname [db_get_col $rs $r hostname]
		set grtime   [db_get_col $rs $r grtime]

		set line [format {%-18s %-18s %4s %6d %5d %-16s %6d}\
			$dbsname \
			$tabname \
			$type \
			$sid \
			$pid \
			$hostname \
			[expr {$now - $grtime}]]

		ob_log::write WARNING {DB: locks: $line}
	}

	db_close $rs
}
