# $Id: token.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval OB_token {

    
    ##
    # OB_token::cust_token - create cust_token identifier
    #
    # SYNOPSIS
    #
    #	[ob::encrypt::cust_token <cust_id> <acct_id> <enc_key>]
    #
    # SCOPE
    #
    #	public
    #
    # PARAMS
    #
    #	[cust_id] - used to create cust_token
    #	[acct_id] - used to create cust_token
    #	[enc_key] - Encryption key
    #
    # RETURN
    #
    #	A string
    #
    # DESCRIPTION
    #
    #	Blowfish encryption
    #
    ##
    proc ::OB_token::cust_token {cust_id acct_id enc_key} {

	set pad_size 5
	
	# pad $acct_id to min size of $pad_size
	while {[string length $acct_id] < $pad_size} {
	    append acct_id 0
	}

	# md5 acct_id
	set acct_id [md5 $acct_id]
	
	return [blowfish encrypt -hex $enc_key -bin $acct_id$cust_id]
    }
}