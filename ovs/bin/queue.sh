#!/bin/bash

#
# $Id: queue.sh,v 1.1 2011/10/04 12:40:37 xbourgui Exp $
# $Name:  $
#
# Parameters:
#  0 - name of the box "brsux111".
#  1 - tcl/tbc
#
#

case `hostname` in
	gibux* )
		INFORMIXSERVER=gib_openbetdb_top;;
	* )
		INFORMIXSERVER=openbet_tcp;;
esac
INFORMIXDIR=/opt/informix/10.0

# set the informix environment variables
PATH=/opt/openbet/tcl/bin:/opt/openbet/appserv/bin:/opt/openbet/current/bin:/opt/informix/10.0/bin:/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/root/bin:/opt/perf/bin:/opt/openbet/bin
LD_LIBRARY_PATH=/opt/informix/10.0/lib:/opt/informix/10.0/lib/esql:/opt/openbet/tcl/lib:/opt/openbet/appserv/lib:/opt/openbet/chartdirector/lib

export INFORMIXDIR INFORMIXSERVER PATH LD_LIBRARY_PATH

# Check we have a param...
if [ -z "$1" ]; then
echo "Usage:"
echo "  $0 [environment]"
echo "  $1 [tcl/tbc]"
exit 1
fi

# Base directory for OpenBet
OPENBET_DIR=/opt/openbet
CONFIG=box_specific/queue_${1}.cfg

# The tcl file extension (tcl or tbc)
XTN=${2}

cd $OPENBET_DIR/current/ovs/bin

echo "running from `pwd`"

tclsh queue.$XTN $CONFIG

cd -

echo "Finished"

