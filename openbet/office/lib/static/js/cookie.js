/*
 * $Id: cookie.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Cookies
 */

if(window.cvsID) {
	cvsID('cookie', '$Id: cookie.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'cookie');
	document.Package.require('office', 'form');
}


/**********************************************************************
 * Cookie Utilities
 *********************************************************************/

// get a cookie
function getCookie(_name)
{
	var dc = document.cookie.split(';'),
		prefix = _name + "=",
		i = 0,
		len = dc.length;

	for(; i < len; i++) {
		dc[i] = strTrimLT(dc[i], ' ');
		if(dc[i].indexOf(prefix) != -1) return unescape(dc[i].substr(prefix.length));
	}

	return null;
}



// set a cookie
function setCookie(_name, _value, _expire, _path, _domain, _secure)
{
	var c = new Array();

	c[c.length] = _name;
	c[c.length] = '=';
	c[c.length] = escape(_value);

	if(_expire && typeof(_expire) == 'object') {
		c[c.length] = ';expires=';
		c[c.length] = _expire.toGMTString();
	}

	if(_path != null && _path.length) {
		c[c.length] = ';path=';
		c[c.length] = _path;
	}

	if(_domain != null && _domain.length) {
		c[c.length] = ';domain=';
		c[c.length] = _domain;
	}

	if(_secure != null && _secure.length) {
		c[c.length] = ';secure';
	}

	document.cookie = (c = c.join(''));

	return c;
}
