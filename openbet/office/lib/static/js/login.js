/*
 * $Id: login.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Handle Login
 */

if(window.cvsID) {
	cvsID('login', '$Id: login.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

var loginPopup = null;


if(document.Package) {
	document.Package.provide('office', 'login');
	document.Package.require('office', 'form');
	document.Package.require('office', 'div_popup');
}



/**********************************************************************
 * Login Popup
 *********************************************************************/

function loginOpen()
{
	// create the popup
	if(!loginPopup) {
		loginPopup = new DivPopup('loginDiv', 'loginTitle');
		loginPopup.form  = document.forms['loginForm'];
		loginPopup.table = getObject('loginTable');
		loginPopup.noModalParent = true;
		loginPopup.trackFocus();
		loginPopup.disableCloseButton();
	}

	loginPopup.open();
	loginPopup.centerInnerWindow();
	loginPopup.setMinMaxInnerWindow();

	if(
		typeof loginPopup.form !== 'undefined' &&
		loginPopup.form !== null &&
		typeof loginPopup.form.username !== 'undefined' &&
		loginPopup.form.username !== null
	) {
		loginPopup.form.username.focus();
	}
}



function checkSubmit(_form, _action, _valUname)
{
	checksubmit=blockSubmit;
	loginSubmit(_form , _action, _valUname);
	return false
}



function blockSubmit()
{
	return false
}



/**********************************************************************
 * Login
 *********************************************************************/

// attempt login
function loginSubmit(_form, _action, _valUname)
{
	var username = strTrim(_form.username.value, " "),
		password = strTrim(_form.password.value, " ");

	_form.username.blur();
	_form.password.blur();

	err.reset();

	if(!ckMandatory(username, 1, 32, _valUname)) {
		err.add("Invalid username");
	}
	if(!ckMandatory(password, 1, 32, false)) {
		err.add("Invalid password");
	}

	if(err.isErr()) {
		err.divAlert2('Login error', {'center' : true});
		return false;
	}

	_form.username.value = username;
	_form.password.value = password;


	return submitOBForm(_form.name, _action, _form.login);
}
