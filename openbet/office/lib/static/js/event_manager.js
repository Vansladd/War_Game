/*
 * $Id: event_manager.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2007 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Event Management.
 *
 * Keeps track of event hooks and provides quick access to unhook those events
 * (avoids the need to traul the DOM tree looking for event hooks).
 * Unhooking the events will avoid memory leaks with those events which hold a reference
 * to an existing/living object e.g. via functional 'closures'.
 */

if(window.cvsID) {
	cvsID('event_manager_id', '$Id: event_manager.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}



/**********************************************************************
 * EventManager
 *********************************************************************/

function EventManager()
{
	this._init();
}



/* One time init
 */
EventManager.prototype._init = function()
{
	this.events = {};
};



/* Hook an event to a DOM element
 *
 *   _idx   - unique key to identify the hook (string)
 *   _dom   - dom element (string|object)
 *            if string, must be the element identifier
 *            if object, will set the event
 *   _event - event name (string)
 *   _fn    - event function hook (function); default none
 */
EventManager.prototype.hook = function(_idx, _dom, _event, _fn)
{
	var id;

	if(typeof _dom === 'object') {
		if(typeof _fn !== 'function') return;
		_dom[_event] = _fn;
		id = _dom.id;
	}
	else {
		id = _dom;
	}

	if(typeof this.events[_idx] === 'undefined') this.events[_idx] = {};
	if(typeof this.events[_idx][id] === 'undefined') this.events[_idx][id] = {};
	this.events[_idx][id][_event] = _dom;
};



/* Unhook an event from a DOM element
 *
 *   _idx   - unique key to identify the hook (string); default none
 *            if not defined, then ALL keys will be unhooked
 *   _dom   - dom element (string|object); default none
 *            if not defined, then ALL elements
 *   _event - event name (string); default none
 *            if not defined, then ALL events
 *
 */
EventManager.prototype.unhook = function(_idx, _dom, _event)
{
	// all keys
	if(typeof _idx === 'undefined') {
		for(_idx in this.events) {
			this.unhook(_idx);
		}

		return;
	}
	else if(typeof this.events[_idx] === 'undefined') {
		return;
	}


	// all dom elements
	if(typeof _dom === 'undefined') {
		for(_dom in this.events[_idx]) {
			this.unhook(_idx, _dom);
		}

		return;
	}

	var id = typeof _dom === 'string' ? _dom : _dom.id;

	if(typeof this.events[_idx][id] === 'undefined') {
		return;
	}


	// all events
	if(typeof _event === 'undefined') {
		for(_event in this.events[_idx][id]) {
			this.unhook(_idx, id, _event);
		}

		return;
	}
	else if(typeof this.events[_idx][id][_event] === 'undefined') {
		return;
	}


	// unhook event
	var dom = this.events[_idx][id][_event],
	i;

	if(typeof dom === 'string') dom = getObject(dom);     // dom is an identifier
	if(dom) {
		try { dom[_event] = null; }
		catch(_e) { }
	}

	delete this.events[_idx][id][_event];


	/*printfire('EventManager.unhook:', _idx, id, _event);*/


	// have any more hooked events
	for(i in this.events[_idx][id]) return;
	delete this.events[_idx][id];

	for(i in this.events[_idx]) return;
	delete this.events[_idx];
};



/* Get all DOM objects that are hooked to a particular event
 * for a particular hook.
 *
 *   _event   - Name of the event (string)
 *   _idx     - Key of the hook (string). If none passed, return
 *              all hooked objects
 *   returns  - an array containing DOM objects hooked with this
 *              event.
 */
EventManager.prototype.get_hooked_items = function(_event, _idx)
{
	if (typeof _event !== 'string') return [];

	var h = [],
	e = this.events,
	k = [],
	i, l, d, id, hook;

	if (typeof _idx === 'undefined') {
		for (hook in this.events) {
			k[k.length] = hook;
		}
	}

	else {
		k[k.length] = _idx;
	}

	l = k.length, i = 0;

	for (; i < l; i++) {
		for (var _id in e[k[i]]) {
			_d = e[k[i]][_id][_event];
			if (typeof _d === 'undefined') continue;
			if (typeof _d === 'object') h[h.length] = _d;
			if (typeof _d === 'string') h[h.length] = getObject(_d);
		}
	}
	return h;
};






