# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Utility tcl package index file.
# Sourced either when an application starts up or by a "package unknown"
# script.  It invokes the "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically in response to
# "package require" commands.  When this script is sourced, the variable
# $dir must contain the full path name of this file's directory.
#

global xtn admin_screens p2p_server

# default to tbc file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
	set xtn tbc
}

# default to standalone or customer screens (not admin)
if {![info exists admin_screens]} {
	set admin_screens 0
}

if {![info exists p2p_server]} {
	set p2p_server 0
}

set util_pkg [list \
	util_base85       4.5 base85\
	util_db           4.5 db\
	util_db_compat    4.5 db-compat\
	util_db_multi     4.5 db-multi\
	util_db_informix    4.5 db-informix\
	util_db_postgreSQL  4.5 db-postgreSQL\
	util_db_core      4.5 db-core\
	util_db_failover  4.5 db-failover\
	util_tb_db_compat 4.5 tb_db-compat\
	util_log          4.5 log\
	util_log_compat   4.5 log-compat\
	OB_Log            1.0 log-compat\
	util_util         4.5 util\
	util_control      4.5 control\
	util_date         4.5 date\
	util_xl           4.5 xl\
	util_xl_compat    4.5 xl-compat\
	util_xl_shm       4.5 xl-shm\
	util_xl_no_shm    4.5 xl-no-shm\
	util_crypt        4.5 crypt\
	util_price        4.5 price\
	util_price_compat 4.5 price-compat\
	util_req_time     4.5 req-time\
	util_gc           4.5 gc\
	util_validate     4.5 validate\
	util_email        4.5 email\
	util_sms          4.5 sms\
	util_sms_test     4.5 sms/test\
	util_sms_mobilepay 4.5 sms/mobilepay\
	util_xml          4.5 xml\
	util_err          4.5 err\
	util_esc          4.5 esc\
	util_dec          4.5 dec\
	util_appcontrol   1.0 app_control\
	util_exchange     1.0 exchange\
	util_restrict_email 1.0 restrict_email\
	util_ping         4.5 ping\
	util_tmp_pwd_generator 1.0 tmp_pwd_generator\
	util_xmlrpc       4.5 xmlrpc\
	util_throttle     4.5 throttle\
	shm               1.0 shm\
	util_xmlrpc       4.5 xmlrpc\
	util_html         1.0 html\
]

foreach {pkg version file} $util_pkg {

	if {$pkg == "util_db"} {
		if {$admin_screens} {
			set file "db-admin"
		} elseif {$p2p_server} {
			set file "db-p2p"
		}
	}
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}
