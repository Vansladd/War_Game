/*
 * $Id: alert2.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2010 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Alert2 utilities - uses DivPopup2 Popup class.
 */

if(window.cvsID) {
	cvsID('alert',
		  '$Id: alert2.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $',
		  'office');
}

setupInheritance(DivPopup2, Alert2);



/**********************************************************************
 * Alert2 Globals
 *********************************************************************/

/* Popup/Display the Alert.
 * Will dynamically load the Alert from a server (as set within DivPopup2.init). The server must
 * enable Office. If the DivPopup2 popup cannot be loaded, then a standard alert is displayed.
 *
 * Caller should use this function, instead of an Alert2 object/instance.
 *
 *    _title    - alert title
 *    _message  - alert message
 *    _opt      - optional arguments [associated array/hash]
 *                  'stdAlert'    - use standard alert (false)
 *                  'callback'    - notification callback which is called when popup is closed
 *                                  default null
 *                  'center'      - center the popup; default false
 *                  'nearButtons' - popup near a button/object; default null
 *                                  if defined, will set _opt.center = false
 */
Alert2.popup = function(_title, _message, _opt)
{
	var def = {'stdAlert': false};
	_opt = associatedArray(def, _opt);


	// DivPopup2 not installed or want to use standard alert
	if(_opt.stdAlert || typeof document.divPopup2 !== 'object') {
		Alert2._stdAlert(_message,
						 typeof _opt === 'object' && typeof _opt.callback === 'function'
						   ? _opt.callback
						   : null);
		return;
	}


	// open
	var cfg = document.divPopup2;
	if(typeof cfg.genericAlert !== 'object') cfg.genericAlert = new Alert2();
	cfg.genericAlert.open(_title, _message, _opt);
};



/**********************************************************************
 * Alert2 Public
 *********************************************************************/

/* Constructor
 */
function Alert2()
{
	this._init();
}



/* Open the Alert.
 *
 *    _title    - alert title
 *    _message  - alert message
 *    _opt      - optional arguments [associated array/hash]
 *                [see Alert2.popup]
 */
Alert2.prototype.open = function(_title, _message, _opt)
{
	var a = this.alert2;

	// stop recusive Alert2s if RequestBroker fails
	if(typeof a.open === 'boolean') return;

	var def = {
		'callback'  : null,
		'center'    : false,
		'nearButton': null,
		'break_line': true
	};

	_opt = associatedArray(def, _opt);
	if(_opt.nearButton !== null) _opt.center = false;

	a.open = true;

	if(!Alert2.superclass.open.call(this,
									{
										'center'        : _opt.center,
										'centerOnCreate': _opt.center
									})) {
		Alert2._stdAlert(_message, _opt.callback);
	}
	else {

		this.setTitle(_title);

		// add message
		var m = this.getNodeIds().genericAlert2Message;
		m.innerHTML = _opt.break_line ? _message.replace(/\n/g, '<br/>') : _message;

		// -increase width of popup if message too wide
		if(m.offsetWidth > this.default_offsetWidth) {
			this.popup.style.width = [this.default_width +
									 (m.offsetWidth -
									 this.default_offsetWidth), 'px'].join('');
		}
		else {
			this.popup.style.width = [this.default_width,'px'].join('');
		}

		// If we are manual altering the width of the popup contents then we also need
		// to resize the move container so it is consistent with the new width
		if(typeof this.title._resizeMoveContainer === 'boolean') {
			this._resizeMoveContainer();
		}

		// move near a button
		if(_opt.nearButton) {

			var b = _opt.nearButton,
			d = getElementPos(b),
			popup = this.popup,
			pos, x, y;

			if(typeof this.pos === 'undefined') pos = (this.pos = new Dimension(popup));
			else (pos = this.pos).get();

			moveXY(popup,
				   (x = d.left - (pos.width / 2) - 10) > 10 ? x : 10,
				   (y = d.top - pos.height - 10) > 10 ? y : 10);
		}


		a.callback = _opt.callback !== null ? _opt.callback : null;
	}

	delete a.open;
};



/**********************************************************************
 * Alert2 Private
 *********************************************************************/

/* Private method to initialise the object
 */
Alert2.prototype._init = function(_opt)
{
	if(typeof _opt === 'undefined') _opt = {};

	//default widths used to calculate whether the popup width needs to be increased
	this.default_width = 280;
	this.default_offsetWidth = 199;

	var def = {
		'id'        : 'genericAlert2',
		'modal'     : true,
		'width'     : this.default_width,
		'tButtons'  : {'close': true},
		'moveable'  : true,
		'rButtons'  : [{'text': 'Ok', 'fn': 'close', 'className' : 'red'}],
		'readOnly'  : true,
		'formPost'  : 'alert2',
		'getAction' : 'ob_office::GoPopup'
	}

	_opt = associatedArray(def, _opt);

	Alert2.superclass._init.call(this, _opt);

	this.alert2 = {};
};




/* Private method (class) to display the standard alert
 *
 *    _message  - alert message
 *    _callback - notification callback which called after closing the alert
 */
Alert2._stdAlert = function(_message, _callback)
{
	alert(_message);
	if(_callback !== null) _callback();
};



/**********************************************************************
 * Alert2 Notifications
 *********************************************************************/

/* Private method to handle a close notification.
 * Will call user supplied callback (if defined when opened - see Alert2.popup)
 */
Alert2.prototype._onClose = function()
{
	if(this.alert2.callback !== null) this.alert2.callback();
};
