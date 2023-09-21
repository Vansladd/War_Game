/*
 * $Id: json.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2010 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * JSON Javascript Utilities
 */

if(window.cvsID) {
	cvsID('json', '$Id: json.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'json');
	document.Package.require('office', 'form');
	document.Package.require('office', 'base');
}



// Use native JSON parser if possible
function parseJSON(_json)
{
	// Try to use the native JSON parser first
	if(window.JSON && window.JSON.parse) {
		// Make sure leading/trailing whitespace is removed (IE can't handle it)
		return window.JSON.parse(strTrimLT(_json));
	}

	return eval(['(', _json, ')'].join(''));
}