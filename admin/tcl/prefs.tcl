# ==============================================================
# $Id: prefs.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Customer preferences
# ----------------------------------------------------------------------------
#
set CUST(name) [OT_CfgGet OPENBET_CUST ""]

if {$CUST(name) == "SLOT"} {
	set CUST(CUST_SEARCH_ORDER)   c.acct_no
	set CUST(CUST_SEARCH_NOUPPER) 1
}

