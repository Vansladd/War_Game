# $Id: xl.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# Copyright (c) 2007 Orbis Technology Ltd. All rights reserved.
#
# Primary purpose is to translate message codes (stored in tXLateCode)
# into language-specific translations (stored in tXLateVal).
#
# This is a stub package; it will load either the util_xl_shm package or
# the util_xl_no_shm package depending on whether shared memory is
# available and configured.
#
# Configuration:
#   XL_SHM_ENABLE          enable use of shared memory            (1)
#   XL_SEMAPHORE_ENABLE    enable semaphore                       (1)
#   XL_SEMAPHORE_PORT      semaphore ports (overrides PORTS)      ("")
#   XL_QRY_CACHE_TIME      get xlations query cache time          (varies)
#   XL_TP_SET_HOOK         enable tpXlateSetHook                  (0)
#   XL_LOAD_ON_STARTUP     list of lang codes to load on startup  (_all_)
#   XL_LOAD_BY_GROUPS      load xlations by group(s)              (0)
#   XL_LOAD_GROUPS         | delimited list of groups             ("")
#                          NB: groups 'API %' are automatically appended
#   XL_USE_FAILOVER_LANG   if translation doesn't exist in current (0)
#                          lang then then first try falling back to
#                          the failover language
#   XL_USE_DEFAULT_LANG    if translation doesn't exist in current (0)
#                          lang then fall back to the default lang
#
# Synopsis:
#   package require util_xl ?4.5?
#
# Procedures:
#   ob_xl::init            one time initialisation
#   ob_xl::get             get language information
#   ob_xl::sprintf         formatted code translation
#   ob_xl::XL              translate a phrase
#

package provide util_xl 4.5


# Dependencies
#
if {[llength [info commands asStoreRs]] &&
	[OT_CfgGet XL_SHM_ENABLE 1]} {
	package require util_xl_shm 4.5
} else {
	package require util_xl_no_shm 4.5
}
