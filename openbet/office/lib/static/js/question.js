/*
 * $Id: question.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Question-Alert utilities
 */

if(window.cvsID) {
	cvsID('question', '$Id: question.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'question');
	document.Package.require('office', 'base');
	document.Package.require('office', 'div_popup');
	document.Package.require('office', 'xmlhttp');
}

document.genericQuestionAlert = null;

/**********************************************************************
 * QuestionAlert Class
 *********************************************************************/

// generic way of popping up question alerts
function QuestionAlert()
{
	this.alert = null;


	// open the alert
	this.popup = function(_callback, _title, _message) {

		if(DivPopupLoad('questionDiv', 'question') == 200) {
			if(!this.alert) {
				this.alert = new QuestionDivPopup();
				this.alert.disableCloseButton();
			}
			this.alert.open(_callback, _title, _message);
		}
	};
}



// convenience function to pop up an question alert
function PopupQuestionAlert(_callback, _title, _message)
{
	if(document.genericQuestionAlert == null) {
		document.genericQuestionAlert = new QuestionAlert();
	}

	document.genericQuestionAlert.popup(_callback, _title, _message);
}
