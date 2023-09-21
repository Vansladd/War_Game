/*
 * $Id: set_timeout.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2007 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Cross-Browser setTimeout handler.
 * - IE cannot handle parameters within setTimeout, therefore, use a generic handler
 *   that executes a callers arguments (object method) via an eval
 */

if(window.cvsID) {
	cvsID('set_timeout', '$Id: set_timeout.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'set_timeout');
	document.Package.require('office', 'base');
}


/**********************************************************************
 * SetTimeout Class
 **********************************************************************/

document.set_timeout_id = 0;
document.set_timeout    = new Object();

function SetTimeout(_id, _queue)
{
	if(arguments.length) this._init(_id, _queue);
}



// one time init
SetTimeout.prototype._init = function(_id, _queue)
{
	this.id    = _id + (document.set_timeout_id++);
	this.queue = typeof _queue != 'undefined' && _queue ? new Array() : null;
	this.timer = null;
};



// is the timer set
SetTimeout.prototype.is_set = function()
{
	return this.timer != null;
};



// start a timeout event (wrapper for setTimeout)
// Arguments:
// - 0 is the timeout function/method
// - 1 is the timeout interval
// - 2 optional; object to call the timeout function/method
// - n optional; additional parameters to object method (can be accessed via this object)
SetTimeout.prototype.start = function()
{
	this._start(arguments);
};



// start a timeout event
SetTimeout.prototype._start = function(_args)
{
	if(_args.length < 2) throw 'SetTimeout: Invalid arguments';

	// queue this request
	if(this.queue && this.timer) {
		this.queue.push(_args);
		return;
	}

	this.stop();
	// store the arguments
	this.fn   = _args[0];
	this.tm   = _args[1];
	this.obj  = null;
	this.args = null;

	// -timeout function is an object method
	if(_args.length > 2) {
		this.obj = _args[2];
		if(this.obj && typeof this.obj != 'object') throw 'SetTimeout: Invalid object reference';

		if(_args.length > 3) {
			this.args = new Array(_args.length - 3);
			for(var i = 0, len = this.args.length; i < len; i++) this.args[i] = _args[i + 3];
		}
	}

	// start timeout
	document.set_timeout[this.id] = this;
	this.timer = setTimeout('_SetTimeoutHandler(\'' + this.id + '\')', _args[1]);
};



// stop the timeout event (if running)
SetTimeout.prototype.stop = function()
{
	if(this.timer) {
		clearTimeout(this.timer);
		this.timer = null;
	}

	if(typeof document.set_timeout[this.id] != 'undefined') delete document.set_timeout[this.id];
};



// execute the timer function directly
// -stops the timer
SetTimeout.prototype.exec = function()
{
	if(!this.timer) return;

	clearTimeout(this.timer);
	_SetTimeoutHandler(this.id);
};



// cross browser function to handle a timeout event
function _SetTimeoutHandler(_id)
{
	var s = document.set_timeout[_id], obj;

	// catch the case when the timer is no longer available
	if(typeof s !== 'undefined' && s !== null) {

		obj = s.obj;

		s.timer = null;
		delete document.set_timeout[s.id];

		// executing an object method
		// -we do not eval any method arguments, as objects will be evaluated
		//  can get access to the arguments via the SetTimeout object
		if(obj) {
			eval('obj.' + s.fn + '()');
		}

		// direct function
		else {
			eval(s.fn + '()');
		}

		if(s.queue && s.queue.length) {
			s._start(s.queue.pop());
		}
	}
}
