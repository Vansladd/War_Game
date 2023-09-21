/*
 * $Id: alert.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Alert utilities.
 * Deprecated, use Alert2 (DivPopup2 version).
 */

if(window.cvsID) {
	cvsID('alert', '$Id: alert.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'alert');
	document.Package.require('office', 'base');
	document.Package.require('office', 'div_popup');
	document.Package.require('office', 'xmlhttp');
}

document.genericAlert = null;


/**********************************************************************
 * Alert Class
 *********************************************************************/

// generic way of popping up alerts
function Alert()
{
	this.alert = null;

	this.popup = function(_title, _message, _callback) {
		if(DivPopupLoad('alertDiv', 'alert') != 200) {
			alert(_message);
			if(typeof _callback != 'undefined') _callback();
		}
		else {
			if(!this.alert) {
				this.alert = new AlertDivPopup('alertDiv', 'alertTitle', 'alertForm', 'alertTable');
			}
			this.alert.open(_title, _message, _callback);
		}
	};
}



// convenience function to pop up an alert
function PopupAlert(_title, _message, _callback)
{
	if(document.genericAlert == null) {
		document.genericAlert = new Alert();
	}

	document.genericAlert.popup(_title, _message, _callback);
}
