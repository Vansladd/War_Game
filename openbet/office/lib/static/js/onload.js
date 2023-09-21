/*
 * $Id: onload.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Handle Multi-onload functions
 */

if(window.cvsID) {
	cvsID('onload', '$Id: onload.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'onload');
}

/**********************************************************************
 * MultiOnload class
 *********************************************************************/

function MultiOnLoad()
{
	// list of onload functions
	this.ol = new Array();


	// push a onload function
	this.push = function(_fn) {
		this.ol.push(_fn);
	};


	// execute all the unload functions
	this.execute = function() {

		for(var i = 0, len = this.ol.length; i < len; i++) {
			this.ol[i]();
		}
	};
}
