##
# ~name      ob::ftp
# ~type      tcl file
# ~title     ftp.tcl
# ~copyright Copyright (c) 2003 Orbis Technology
# ~summary   FTPs a file to a variety of hosts and locations
# ~version   $Id: ftp.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
##
package require ftp
package require dns

namespace eval ob::ftp {
#namespace exports -GO HERE... *
	namespace export init
	namespace export put
}
# end of namespace ob::ftp

##
# init -- Iniates the params - must be called before other funcs
#
# SYNOPSIS
#
# [init nameserver]
#
# SCOPE
#
# public
#
# PARAMS
#
#   nameserver - dns nameserver
#
# RETURNS
#
#  NONE
##
proc ob::ftp::init {nameserver} {
	variable v_nameserver
	set v_nameserver nameserver

	::dns::configure -nameserver $nameserver
}

##
# put -- ftps a file over to a remote server
#
# SYNOPSIS
#
# [put file server location username password resolve]
#
# SCOPE
#
# public
#
# PARAMS
#
#   file:         file to be transfered
#   server:       remote server to put file on
#   locations:    list of remote directories to put the file to
#   username:     username for ftp
#   password:     password for ftp
#   resolve:      1|0 - 1 will try to resolve the server address this may be useful when
#                         ftping to various boxes
#   timeout       seconds to timeout trying to get a connection
#   type          binary|ascii
#   cont_on_err   1|0 - 0 will return an error upon file transfer failing on the first box
#                       1 will continue to try the other servers
#
# RETURNS
#
#  list 1 transfer_log : transfer was successful
#  or   0 transfer_log : err_desc
#
##
proc ob::ftp::put {files
				   server
				   locations
				   username
				   password
				   {resolve 0}
				   {timeout 30}
				   {type binary}
				   {cont_on_err 1}} {
	set log ""
	set ok  1

	if {$resolve} {
		set tok [::dns::resolve $server]
		if {[::dns::status $tok] == "ok"} {
			set addrs [::dns::address $tok]
		} else {
			return [list 0 "Unable to resolve host: $server"]
		}
	} else {
		set addrs $server
	}

	foreach addr $addrs {
		set ftp_h [::ftp::Open $addr $username $password -timeout $timeout]

		if {$ftp_h == -1} {
			append log "Unable to connect to host: $addr\n"
			if {$cont_on_err} {
				set ok 0
				continue
			} else {
				return [list 0 $log]
			}
		}

		::ftp::Type $ftp_h $type

		foreach location $locations {
			if {![::ftp::Cd $ftp_h $location]} {
				append log "unknown directory $location on remote server $addr\n"
				if {$cont_on_err} {
					set ok 0
					continue
				} else {
					::ftp::Close $ftp_h
					return [list 0 $log]
				}
			}

			foreach file $files {
				if {![::ftp::Put $ftp_h $file]} {
					append log "Error transferring file $file to $addr:$location\n"
					if {$cont_on_err} {
						set ok 0
						continue
					} else {
						::ftp::Close $ftp_h
						return [list 0 $log]
					}
				}

				append log "$file successfully transfered to $addr:$location\n"
			}
		}
		::ftp::Close $ftp_h
	}

	return [list $ok $log]
}

