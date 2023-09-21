# ==============================================================
# $Id: teamtalk.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================
namespace eval ADMIN::TEAMTALK {

asSetAct ADMIN::TEAMTALK::GoRace  [namespace code go_race]
asSetAct ADMIN::TEAMTALK::DoRace  [namespace code do_race]
asSetAct ADMIN::TEAMTALK::GoRide  [namespace code go_ride]
asSetAct ADMIN::TEAMTALK::DoRide  [namespace code do_ride]
asSetAct ADMIN::TEAMTALK::GoTTLinks [namespace code go_type_links]
}



