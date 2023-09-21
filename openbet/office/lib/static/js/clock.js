/*
 * $Id: clock.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2008 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Clock
 * - display a simple clock within a dom element
 */

if(window.cvsID) {
	cvsID('clock', '$Id: clock.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'clock');
	document.Package.require('office', 'base');
	document.Package.require('office', 'date');
	document.Package.require('office', 'set_timeout');
}



/**********************************************************************
 * Clock Class
 **********************************************************************/

function Clock(_id, _format)
{
	if(arguments.length) this._init(_id, _format);
}



// init
Clock.prototype._init = function(_id, _format)
{
	this.timer = new SetTimeout('Clock');
	this.date  = new Date();

	this.format = _format;
	this.dom    = getObject(_id);
};



// start or refresh the clock
Clock.prototype.start = function(_ifx_date)
{
	if(
		typeof _ifx_date == 'undefined' ||
		!_ifx_date.length ||
		!this.date.fromInformixString(_ifx_date)
	) {
		throw 'Clock: Invalid start date';
	}

	this.timer.stop();

	this.show();
	this.timer.start("_update", 1000, this);
};



// show the current (local) time
Clock.prototype.show = function()
{
	if(!this.dom) throw 'Clock: Cannot find clock dom element';
	addText(this.dom, this.date.format(this.format));
};



// update the clock
Clock.prototype._update = function()
{
	this.date.setTime(this.date.getTime() + 1000);

	this.show();
	this.timer.start("_update", 1000, this);
};


