/*
 * $Id: div_popup2.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2010 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Div Popup (V2) management
 */

if(window.cvsID) {
	cvsID('div_popup2',
		  '$Id: div_popup2.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $',
		  'office');
}


/**********************************************************************
 * Div Popup Globals
 *********************************************************************/

/* Initialise the DivPopup2 base configuration.
 * All DivPopup2 instances will use this configuration as a default; can be overridden.
 * The script calls this function using the defaults, but can be called (at any time) to change any
 * setting.
 *
 *    _opt   - optional arguments [associated array/hash]
 *              'requestBroker'   - Request Broker object used to get dynamic HTML (form container)
 *                                  via a POST request; default null
 *                                  To avoid bloated HTML we can dynamically fetch the form
 *                                  container HTML (inner part of the Popup we have no direct
 *                                  control over)
 *                                  The broker must have a valid URL defined on construction
 *              'getPriority'     - Get-popup request priority; default 0
 *              'getAction'       - Get-popup POST action; default null
 *              'submitPriority'  - Submit popup request priority; default 0
 *              'submitAction'    - Submit popup POST action; default null
 *              'staticVersion    - Static version which is appended to CSS images
 *                                  default document.staticVersion
 *              'helpURL'         - Dynamic Help URL; default null
 *                                  The URL does should not include the .htm instance, this will be
 *                                  added by the DivPopup2 object
 *              'helpWindow'      - Help window name; default HELP
 *              'buttonAnimation' - Function which can animate a button click; default null
 *                                  Signature: function(_button, _enable)
 */
DivPopup2.init = function(_opt)
{
	var cfg = typeof document.divPopup2 === 'object' ? document.divPopup2 : null,
	def = {
		'requestBroker'  : cfg ? cfg.requestBroker : null,
		'getPriority'    : cfg ? cfg.getPriority : 0,
		'getAction'      : cfg ? cfg.getAction : null,
		'submitPriority' : cfg ? cfg.submitPriority : 0,
		'submitAction'   : cfg ? cfg.submitAction : null,
		'staticVersion'  : cfg
			? cfg.staticVersion
			: typeof document.staticVersion === 'string' ? document.staticVersion : null,
		'helpURL'        : cfg ? cfg.helpURL : null,
		'helpWindow'     : cfg ? cfg.helpWindow : 'HELP',
		'buttonAnimation': cfg ? cfg.buttonAnimation : null
	};

	_opt = associatedArray(def, _opt);

	if(!cfg) {
		cfg = (document.divPopup2 = {}),
		css = {};

		cfg.total = 0;
		cfg.browser = browser.ffox
			? 'ffox'
			: (browser.ie8 ? 'ie ie8' : (browser.ie7 ? 'ie7 ie ' : (browser.chrome ? 'chrome' : '')));


		// get Popup Styles
		getCSSRules(css, ['div_popup2.css'], DivPopup2._getCSS);

		// -add static version to images
		if(_opt.staticVersion !== null) {

			var v = _opt.staticVersion,
			b = ['help', 'close', 'min', 'max'],
			i = 0,
			len = b.length,
			c;

			for(; i < len; i++) {
				c = css[['tbutton', b[i]].join('')];
				c.style.backgroundImage = c.style.backgroundImage.replace(/.gif/,
																		  ['.gif', v].join(''));
			}
		}
	}

	cfg.requestBroker = _opt.requestBroker;
	cfg.getPriority = _opt.getPriority;
	cfg.getAction = _opt.getAction;
	cfg.submitPriority = _opt.submitPriority;
	cfg.submitAction = _opt.submitAction;
	cfg.helpURL = _opt.helpURL;
	cfg.helpWindow = _opt.helpWindow;
	cfg.baseZIndex = 1000;
	cfg.buttonAnimation = _opt.buttonAnimation;
};



/* Private function to get CSS rules.
 *
 *    _cache        - CSS cache to store the rules
 *    _selectorText - CSS selector text
 *    _rule         - CSS rule object
 */
DivPopup2._getCSS = function(_cache, _selectorText, _rule)
{
	var m,
	expr;

	if(typeof _cache.expr === 'undefined') {
		expr = (_cache.expr = {});
		expr.tbutton = /^\.divPopup2 \.titleButtonContainer \.(close|help|min|max)$/;
	}
	else {
		expr = _cache.expr;
	}

	if(_selectorText === '.ie#divPopup2ModalContainer') {
		_cache.modalContainerIE = _rule;
	}
	else if((m = expr.tbutton.exec(_selectorText)) && m.length === 2) {
		_cache[['tbutton', m[1]].join('')] = _rule;
	}
};



/**********************************************************************
 * Div Popup - Public
 *********************************************************************/

/* Constructor.
 * Builds a Popup, no HTML is needed other than the Form Content.
 *
 *    _opt  - optional arguments
 *            'modal'          - Is the popup modal; default true
 *            'id'             - Popup identifier; default null
 *                               Can be supplied as string or an object if caller has defined their
 *                               own popup HTML [not recommended]
 *            'title'          - Popup title; default null
 *            'tButtons'       - Title buttons; default object [see below]
 *                               Supplied as an associated array, value a boolean:
 *                                 'help'     - Dynamic Help; default false
 *                                              _opt.helpPage and global helpURL need to be defined
 *                                 'min'      - Minimise popup; default false
 *                                 'max'      - Maximise popup; default false
 *                                 'close'    - Close popup; default true
 *            'className'      - Optional className added to popup div; default null
 *            'moveable'       - Is the popup moveable; default true
 *            'width'          - Width; default 0
 *                               If supplied will set the MinWidth and Width at element level.
 *                               The dimensions can be defined by opt.className
 *            'height'         - Height; default 0
 *                               If supplied will set the MinHeight and Height at element level.
 *                               The dimensions can be defined by opt.className
 *            'rButtons'       - Bottom Right buttons; default object [see below]
 *                               Supplied as an array of objects, where each defines the
 *                               button:
 *                                 'text'      - button text
 *                                 'fn'        - button onclick function [see DivPopup2._HOnclick]
 *                                 'disable'   - initially disabled; default false
 *                                 'className' - extra class name; default null
 *                                 'submit'    - submit button; default false
 *                                 'id'        - identifier; default null
 *                                 'label'     - string to titlelise a button default null
 *                               Default: Cancel and Ok (disabled)
 *            'lButtons'       - Bottom Left buttons; default null
 *                               Format as opt.rButtons
 *            'helpPage'       - Dynamic Help page; default null
 *                               Appended to global helpURL (.htm is not needed) and used when
 *                               title help link is clicked
 *            'readOnly'       - Popup placed into read-only mode; default false
 *            'tabRow'         - Tab row; default null
 *                               Tab is added between the title and form containers
 *                               Supplied as an array of objects, where each defines a tab:
 *                                 'text'      - tab text (keep it short)
 *                                 'formId'    - identifier the form to select when clicked
 *                                 'selected'  - selected tab; default false
 *                                 'className' - extra class name; default null
 *            'formHTML'       - Form HTML; default null
 *                               HTML which will be added the form container (inner part of the
 *                               popup, which is managed by the caller) can be supplied as a DOM
 *                               object or identifier. The HTML must be available someplace within
 *                               the body, and can only be used by 1 popup (other popup will steal
 *                               the HTML). opt.formPost is recommended
 *            'formPost'       - Form POST argument; default null
 *                               Used to identify the name of the form container which can be
 *                               dynamically loaded via a POST request (Request Broker must be
 *                               configured). Dynamic content allows the the body to be free of
 *                               HTML until actually needed. opt.formPost is recommended way of
 *                               defining the form content.
 *                               The server only needs to play HTML as plain/text template, or a
 *                               bad HTTP status on failure, e.g. 403 if the requested content does
 *                               exists, etc..
 *            'requestBroker'  - Request broker; default document.divPopup2.requestBroker
 *                               Override the global request broker [see DivPopup2.init]
 *            'getPriority'    - Get-popup request priority
 *                               default document.divPopup2.getPriority
 *                               Override the global getPriority [see DivPoup2.init]
 *            'getAction'      - Get-popup POST action; default document.divPopup2.getAction
 *                               Override the global getAction [see DivPoup2.init]
 *            'submitPriority' - Submit popup request priority
 *                               default document.divPopup2.submitPriority
 *                               Override the global submitPriority [see DivPoup2.init]
 *            'submitAction'   - Submit popup POST action; ; default document.divPopup2.submitAction
 *                               Override the global submitAction [see DivPoup2.init]
 */
function DivPopup2(_opt)
{
	if(arguments.length) this._init(_opt);
}



/* Open/Create the popup. If the popup does not exist, then creates/builds
 *
 * Fires the following notifications (if defined by a child):
 *  _onCreate()       - successfully create/built the popup
 *  _onDisplay()      - successfully displayed the popup
 *  _onOpen()         - successfully opens the popup
 *
 *    _opt    - optional arguments [associated array]
 *               'center'          - center the popup
 *               'centerOnCreate'  - center the popup if creating/building
 *               'display'         - display the popup
 *    returns - true if successfull opened the popup, false if failed (HTTP failure loading dynamic
 *              popup)
 */
DivPopup2.prototype.open = function(_opt)
{
	var def = {
		'center'        : false,
		'centerOnCreate': true,
		'display'       : true
	};
	_opt = associatedArray(def, _opt);


	// create the popup
	if(typeof this.popup === 'undefined') {
		if(!this._create()) return false;

		if(_opt.centerOnCreate) _opt.center = true;

		if(typeof this._onCreate === 'function') this._onCreate();
	}

	// display the popup
	if(_opt.display) this._display(_opt.center);

	if(typeof this._onOpen === 'function') this._onOpen();

	return true;
};



/* Close the popup.
 *
 * Fires the following notification (if defined by a child):
 *  _onClose(_minimised)   - successfully closed the popup
 *
 *    _minimised  - flag to denote if minimised the popup
 */
DivPopup2.prototype.close = function(_minimised)
{
	if(typeof this.popup === 'undefined' || !this.popup.offsetWidth) return;

	var cfg = document.divPopup2;

	addClass(this.popup, 'divPopup2DisplayNone');
	cfg.total--;

	if(!cfg.total && this.modal) {
		addClass(cfg.modalContainer, 'divPopup2DisplayNone');
	}
	else {
		cfg.modalContainer.style.zIndex = cfg.baseZIndex + (cfg.total - 1);
	}

	if(typeof this._onClose === 'function') this._onClose(_minimised);
};



/* Close the iconised popup. The popup itself is already closed (total updated, etc),
 * so simply destroy the iconised container
 */
DivPopup2.prototype.closeMin = function()
{
	var cfg = document.divPopup2;

	if(typeof this.minPopup === 'object' && this.minPopup.offsetWidth) {
		cfg.minContainer.removeChild(this.minPopup);
	}
}



/* Submit the form container.
 * Displays an alert and stops the submit if any of the auto-checks fail on a changed item.
 *
 * Fires the following notifications (if defined by a child):
 *    _onChkChanged()  - on completion of checking the changed nodes
 *
 *    _button  - button which triggered submit
 */
DivPopup2.prototype.submit = function(_button)
{
	if(this.readOnly) return;

	this.chkChanged();

	if(err.isErr()) {
		err.divAlert2(this.title.text, {'nearButton': _button});
		return;
	}

	if(
		this.requestBroker === null ||
		typeof this.requestBroker !== 'object' ||
		this.submitAction === null ||
		typeof this.submitAction !== 'string' ||
		!this.submitAction.length
	) {
		return;
	}

	var self = this;
	this.requestBroker.send({
		'priority': this.submitPriority,
		'method'  : 'POST',
		'action'  : this.submitAction,
		'post'    : this.getPost(),
		'async'   : true,
		'callback': function(_resp) { self._submit_cb(_resp, _button); }
	});
};



/* Center the popup within the inner browser window.
 */
DivPopup2.prototype.center = function()
{
	if(typeof this.popup === 'undefined' || !this.popup.offsetWidth) return;

	var popup = this.popup,
	pos, x, y, scroll;

	if(typeof this.pos === 'undefined') pos = (this.pos = new Dimension(popup));
	else (pos = this.pos).get();

	x = (getWindowInnerWidth() / 2) - (pos.width / 2);
	y = (getWindowInnerHeight() / 2) - (pos.height / 2);
	scroll = getScrollXY();

	if(y < 0) y = 10 + scroll.y;
	if(x < 0) x = 10 + scroll.x;

	moveXY(popup, x, y);
};



/* Popup Dynamic Help.
 */
DivPopup2.prototype.help = function()
{
	var page = this.helpPage,
	cfg = document.divPopup2,
	url = cfg.helpURL;

	if(page === null || !page.length || !url || !url.length) return;

	window.open([url, '/', page, '.htm'].join(''), cfg.helpWindow);
};



/* Minimise the popup.
 * Closes the popup and displays 'minimised' version within the minContainer (bottom of the screen)
 */
DivPopup2.prototype.min = function()
{
	if(typeof this.popup === 'undefined' || !this.popup.offsetWidth) return;

	var cfg = document.divPopup2,
	c = cfg.minContainer;

	if(!c.offsetHeight) removeClass(c, 'divPopup2DisplayNone');

	if(typeof this.minPopup === 'undefined') {
		var d = (this.minPopup = document.createElement('div')),
		html = [],
		title = this.title.text,
		self = this,
		e;

		htmlwBegin(html, 'div',
			{
				'class': 'close',
				'onclick': ['DivPopup2._HOnclick(this,\'',
										   self.id,
										   '\',\'',
										   'closeMin', '\')'].join('')
			},
			{'endNode' : true}
		);

		c.appendChild(d);
		d.innerHTML = html.join('');

		e = document.createElement('div');
		e.onclick = function() { self._HMinOnclick(); };
		e.className = 'minTitle';
		if(title !== null && title.length) e.innerHTML = title;

		d.appendChild(e);

	}
	else {
		c.appendChild(this.minPopup);
	}


	this.close(true);
};



/* Maximises the popup.
 * If the browser re-sizes while maximised, the popup is not automatically adjusted
 *
 * Fires the following notification (if defined by a child):
 *  _onResizeFormContainer()   - form container has been re-sized
 */
DivPopup2.prototype.max = function()
{
	if(typeof this.popup === 'undefined' || !this.popup.offsetWidth) return;

	var p = this.popup;

	if(typeof this.maxPopup === 'object') {
		var d = this.maxPopup;

		p.style.width = [d.width, 'px'].join('');
		p.style.left = [d.left, 'px'].join('');
		p.style.top = [d.top, 'px'].join('');

		removeClass(p, 'maximised');
		delete this.maxPopup;

		// reset the height of the form container
		if(typeof this.formContainer === 'object') {
			this._resizeFormContainer(false);
		}

	}
	else {
		this.maxPopup = new Dimension(p);
		addClass(p, 'maximised');

		p.style.width = [getWindowInnerWidth() - 4, 'px'].join('');

		// adjust the height of the form container
		if(typeof this.formContainer === 'object' && this.formContainer.offsetHeight) {
			this._resizeFormContainer(true);
		}
	}


	// adjust width of move container
	if(this.moveable) this._resizeMoveContainer();
};



/* Get ALL the form container identifiers.
 *
 *    returns    - associated array of nodes
 *                 where name is the identifier and value is the DOM object
 */
DivPopup2.prototype.getNodeIds = function()
{
	if(typeof this.formContainer === 'undefined') return {};

	return typeof this.nodes === 'object' && this.nodes !== null
		? this.nodes
		: (this.nodes = getNodeIds(this.formContainer));
};



/* Get POST arguments
 * Adds each form element to the post list [associated array/hash]. If a delimiter was supplied
 * when setting the form [see DivPopup2.formSet], then the popup identifier/delimiter prefix will
 * be removed from the post name.
 *
 *    _nvp           - name/value pairs [asscoiated array/hash]; default none
 *    _changed_only  - add only those elements that have changed
 *    _prefix        - a string that overrides the id of the popup when building the post
 *    returns - POST arguments
 *              adds them to _nvp if supplied
 */
DivPopup2.prototype.getPost = function(_nvp, _changed_only, _prefix)
{
	if(typeof _nvp !== 'object') _nvp = {};
	if(typeof this.nodes !== 'object') this.getNodeIds();
	if(typeof _changed_only === 'undefined') _changed_only = false;
	if(typeof _prefix !== 'string') _prefix = this.id;

	var nodes = this.nodes,
	delimiter = this.idDelimiter === null ? null : [_prefix, this.idDelimiter].join(''),
	re = delimiter !== null ? new RegExp(delimiter) : null,
	name, n_name, node, chk, changed;

	if(_changed_only) {
		// no changes - nothing to add
		if(typeof this.changedTotal !== 'number' || this.changedTotal < 1) return _nvp;

		changed = this.changed;
	}

	for(name in nodes) {

		if(re !== null && !re.test(name)) continue;

		if(_changed_only && (typeof changed[name] === 'undefined' || changed[name] === null)) {
			continue;
		}

		n_name = delimiter !== null ? name.replace(delimiter, '') : name;

		// add each form element to the post
		switch((node = nodes[name]).nodeName) {
		case 'INPUT':
			if(node.type === 'checkbox') _nvp[n_name] = node.checked ? 'Y' : 'N';
			else _nvp[n_name] = strTrim(node.value);
			break;

		case 'TEXTAREA':
			_nvp[n_name] = strTrim(node.value);
			break;

		case 'SELECT':
			if(node.type === 'select-one') {
				if(node.options.length) {
					_nvp[n_name] = strTrim(node.options[node.selectedIndex].value);
				}
			}
			else {
				var a = [];
				for(var i = 0, o = node.options, len = o.length; i < len; i++) {
					if(o[i].selected) a[a.length] = o[i].value;
				}
				_nvp[n_name] = a;
			}
			break;

		default:
			continue;
		}

		// encode
		if(typeof node.divPopup2 === 'object' && typeof node.divPopup2.chk === 'object') {
			if(typeof (chk = node.divPopup2.chk).encode === 'boolean' && chk.encode) {
				_nvp[n_name] = encodeURIComponent(_nvp[n_name]);
			}
		}
	}

	return _nvp;
};



/* Set the popup title (also set the minimised title)
 *
 *    _text   - title text
 *              if NULL or empty, will clear the title text
 */
DivPopup2.prototype.setTitle = function(_text)
{
	if(typeof this.popup === 'undefined') return;

	var title = this.title;

	if(typeof title.id === 'undefined' || title.id === null) {
		title.id = getObject([this.id, 'TitleText'].join(''));
	}

	title.id.innerHTML = (title.text = _text) !== null && _text.length ? _text : '';
};



/* Set the title buttons.
 *
 *    _buttons   - associated array describing which buttons to hide/display
 *                 see DivPopup2 constructor for format
 */
DivPopup2.prototype.setTitleButtons = function(_buttons)
{
	if(typeof this.popup === 'undefined') return;

	var title = this.title,
	html = [],
	id = typeof title.buttonsId === 'undefined' || title.buttonsId === null
		? (title.buttonId = getObject([this.id, 'TitleButtonC'].join('')))
		: title.buttonId,
	order = ['help', 'min', 'max', 'close'],
	i = 0, len = order.length;

	if(typeof _buttons !== 'object' || _buttons !== null) {

		var self = this,
		cfg = document.divPopup2;

		fn = function(_btn) {
			if(typeof _buttons[_btn] === 'boolean' && _buttons[_btn]) {
				htmlwBegin(html, 'div',
						   {
							   'class'  : ['button ', _btn].join(''),
							   'onclick': ['DivPopup2._HOnclick(this,\'',
										   self.id,
										   '\',\'',
										   _btn, '\')'].join('')
						   },
						   {'endNode': true});

				if(_btn === 'min' && typeof cfg.minContainer === 'undefined') {
					var c = (cfg.minContainer = document.createElement('div'));
					c.id = 'divPopup2MinContainer';
					document.body.appendChild(c);
				}
			}
		};

		for(; i < len; i++) fn(order[i]);
	}

	id.innerHTML = html.join('');

	if(html.length) removeClass(id, 'divPopup2DisplayNone');
	else addClass(id, 'divPopup2DisplayNone');


	// adjust width of move container
	if(this.moveable) this._resizeMoveContainer();
};



/* Set the tab row.
 *
 *    _row - associated array describing which buttons to add to the row.
 *           see DivPopup2 constructor for format
 */
DivPopup2.prototype.setTabRow = function(_row)
{
	if(typeof this.popup === 'undefined') return;

	var t = typeof this.tabRow === 'undefined'
		? (this.tabRow = {'id': getObject([this.id, 'TabContainer'].join(''))})
		: this.tabRow,
	len = _row.length,
	html = [],
	id = this.id,
	selected = false,
	className;

	t.row = _row;

	if(len) {
		for(var i = len - 1; i >= 0; i--) {

			// -only 1 can be selected
			if(typeof _row[i].selected !== 'boolean' || selected) _row[i].selected = false;
			else if(!selected && _row[i].selected) selected = true;

			className = typeof _row[i].className === 'string' && _row[i].className.length
				? [' ', _row[i].className].join('') : null;

			htmlwBegin(html,
					   'div',
					   {
						   'id'     : (_row[i].id = [id, 'Tab', i].join('')),
						   'onclick': 'DivPopup2._HTabOnclick(this)',
						   'class'  : [_row[i].selected ? 'selected ' : '',
									   className !== null ? className : '',
									   i + 1 === len ? 'last' : ''].join('')
					   });

			htmlwBegin(html, 'div', {'class': 'leftBorder'}, {'endNode': true});
			htmlwBegin(html, 'div', {'class': 'center'}, {'data': _row[i].text});
			htmlwBegin(html, 'div', {'class': 'rightBorder'}, {'endNode': true});

			htmlwEnd(html, 'div');
		}

		t.id.innerHTML = html.join('');
		removeClass(t.id, 'divPopup2DisplayNone');
	}
	else {
		addClass(t.id, 'divPopup2DisplayNone');
	}
};



/* Get the selected Tab.
 *
 *    returns - selected Tab or null if not found
 */
DivPopup2.prototype.getTabRowSelected = function()
{
	if(typeof this.tabRow === 'undefined') return null;

	var row = this.tabRow.row,
	i = 0,
	len = row.length;

	for(; i < len; i++) {
		if(row[i].selected) return row[i];
	}

	return null;
};



/* Enable/Disable the submit buttons
 *
 *   _enable - enable/disable the buttons; default false
 */
DivPopup2.prototype.enableSubmitButtons = function(_enable)
{
	var b = this.submitButtons,
	len = b.length;
	if(!len) return;

	if(typeof _enable === 'undefined') _enable = false;

	for(var i = 0; i < len; i++) {
		if(typeof b[i] === 'string') b[i] = getObject(b[i]);
		if(_enable) removeClass(b[i], 'disable');
		else {
			addClass(b[i], 'disable');
			err.reset();
		}
	}
};



/**********************************************************************
 * Div Popup - Forms
 *********************************************************************/

/* Set the form data.
 * Call on the receipt of JSON data and/or displaying the popup.
 *
 *   _opt   - optional arguments [associated array/hash]
 *             'data'         - data object [associated array/hash]; default null
 *                              Data is copied into the form object, which is then overriden by any
 *                              form change [see DivPopup.formTrackChange]
 *             'trackchanges' - track the changes on a form item/node; default true
 *             'delimiter'    - delimiter between popup identifier and form input name; default null
 *                              It is recomended that each form input has have popup id prefixed,
 *                              while data name does not. The input and data name should be the same
 *                              Set to null if no prefix is used
 */
DivPopup2.prototype.formSet = function(_opt)
{
	this.changed = {};
	this.changedTotal = 0;

	this.enableSubmitButtons(false);

	var def = {
		'data'          : null,
		'trackChanges'  : true,
		'delimiter'     : null
	};
	_opt = associatedArray(def, _opt);

	if(typeof this.nodes === 'undefined') this.getNodeIds();

	var nodes = this.nodes,
	data = _opt.data,
	trackChanges = _opt.trackChanges,
	readOnly = this.readOnly,
	delimiter = _opt.delimiter,
	id = _opt.delimiter === null ? null : [this.id, _opt.delimiter].join(''),
	name, d_name, n;

	for(name in nodes) {

		n = nodes[name];
		if(!readOnly && trackChanges) this.formNodeTrackChange(n);

		if(data === null) continue;

		d_name = id === null ? name : name.replace(id, '');
		if(typeof data[d_name] !== 'undefined') DivPopup2.formNodeSet(n, data[d_name]);
	}

	this.idDelimiter   = _opt.delimiter;
};



/* Set a form node/element.
 *
 *   _node   - node
 *             can be supplied as string (identifier) or DOM object
 *   _value  - value to set
 */
DivPopup2.formNodeSet = function(_node, _value)
{
	if(typeof _node === 'string') _node = getObject(_node);

	switch(_node.nodeName) {
	case 'INPUT':
		if(_node.type === 'checkbox') _node.checked = _value === 'Y';
		else _node.value = _value;
		break;

	case 'TEXTAREA':
		_node.value = _value;
		break;

	case 'SELECT':
		if(_node.type === 'select-one') {
			_node.selectedIndex = 0;
			for(var i = 0, o = _node.options, len = o.length; i < len; i++) {
				if(o[i].value === _value) {
					_node.selectedIndex = i;
					break;
				}
			}
		}
		else if(_node.type === 'select-multiple') {
			for(var i = 0, o = _node.options, len = o.length; i < len; i++) {
				o[i].selected = _value.indexOf(o[i].value) !== -1;
			}
		}
		break;

	case 'SPAN':
	case 'DIV':
		_node.innerHTML = _value;
		break;
	}

	// store original value
	if(typeof _node.divPopup2 === 'undefined') _node.divPopup2 = {};
	_node.divPopup2.value = _value;
};



/* Track the changes on a form node/element.
 * If an item changes, then we store within a cache and enable the submit button[s].
 *
 *   _node   - node
 *             can be supplied as string (identifier) or DOM object
 */
DivPopup2.prototype.formNodeTrackChange = function(_node)
{
	if(this.readOnly) return;

	if(typeof _node === 'string') _node = getObject(_node);

	// only track input nodes
	if(typeof _node.type === 'undefined' || _node.type === null || !_node.type.length) {
		return;
	}

	var self = this;

	// checkbox
	if(
		_node.type === 'checkbox' &&
		(typeof _node.onclick !== 'function' || _node.onclick === null)
	) {
		_node.onclick = function() { self.formEnableSubmit(this); };
	}
	// non text
	else if(
		_node.type !== 'text' && _node.type !== 'textarea' &&
		(typeof _node.onchange !== 'function' || _node.onchange === null)
	) {
		_node.onchange = function() { self.formEnableSubmit(this); };
	}

	// text
	else if(typeof _node.onkeyup !== 'function' || _node.onkeyup === null) {
		_node.onkeyup = function(_e) { self.formEnableSubmit(this, null, _e); };
	}
};



/* Enable/Disable the submit buttons if a change has been detected.
 *
 *    _node  - node to check
 *    _diff  - is node different; default none
 *             if not specified, then check node data against saved data [see DivPopup2.formNodeSet]
 *    _e     - event object. don't check for diff if TAB key was pressed
 */
DivPopup2.prototype.formEnableSubmit = function(_node, _diff, _e)
{
	if(this.readOnly) return;

	var event = window.event;
	if(
		(typeof _e !== 'undefined' && _e !== null && _e.keyCode === 9) ||
		(typeof event !== 'undefined' && event !== null && event.keyCode === 9)
	) return;

	if(typeof _node === 'string') _node = getObject(_node);

	// only track input nodes
	if(typeof _node.type === 'undefined' || _node.type === null || !_node.type.length) {
		return;
	}


	// get value
	var value = typeof _node.divPopup2 === 'object' && typeof _node.divPopup2.value !== 'undefined'
		? _node.divPopup2.value : '';

	// get name
	var name = typeof _node.id === 'undefined' || !_node.id.length ? _node.name : _node.id;
	if(typeof name !== 'string' || name === null || !name.length) return;


	// detemine if different
	if(typeof _diff === 'undefined' || _diff === null) {

		var type = _node.type,
		m;

		// text
		if(type === 'text' || type === 'textarea') {
			_diff = _node.value !== value;
		}

		// checkbox
		else if(type === 'checkbox') {
			_diff = (_node.checked && value === 'N') || (!_node.checked && value === 'Y');
		}

		// select
		else if(type === 'select-one') {
			_diff = _node.options[_node.selectedIndex].value != value;
		}

		// multi-select
		else if(type === 'select-multiple') {
			_diff = false;

			var s = [],
			o = _node.options,
			i = 0,
			len = o.length;

			for(; i < len; i++) if(o[i].selected) s[s.length] = o[i].value;
			if(typeof value === 'string') {
				_diff = s.length != 1 || s[0] !== value;
			}
			else if(!(_diff = s.length !== value.length)) {

				// -different selections
				for(i = 0, len = s.length; i < len && !_diff; i++) {
					_diff = value.indexOf(s[i]) !== -1;
				}

				// -not selected
				if(!_diff) {
					for(i = 0, len = value.length; i < len && !_diff; i++) {
						_diff = s.indexOf(value[i]) !== -1;
					}
				}
			}
		}

		else {
			return;
		}
	}

	// value changed
	if(_diff) {
		if(typeof this.changed[name] !== 'undefined') return;
		this.changed[name] = 1;
		this.changedTotal++;
	}
	else {
		if(typeof this.changed[name] !== 'undefined') {
			// Only remove the changed element if it already exists as a field
			// that has been changed
			delete this.changed[name];
			this.changedTotal += (this.changedTotal ? -1 : 0)
		}
	}

	// enable/disable the submit buttons
	this.enableSubmitButtons(this.changedTotal);
};



/* Register a format check against a form item.
 * The registered checks will be called by submit.
 *
 *    _node  - form item
 *             string (identifier) or DOM object
 *    _type  - type of format check; default text
 *             (text|int|float|date|interval|price|multi)
 *    _opt   - optional arguments [associated array/hash]; default null
 *              'label'     - item label (used within error messages)
 *              'encode'    - item will be encoded when posted
 *              ...         - arguments specific to _type checks
 */
DivPopup2.prototype.chkRegister = function(_node, _type, _opt)
{
	if(typeof _node === 'string') _node = getObject(_node);
	if(typeof _node === 'undefined' || _node === null) {
		DivPopup2._error('Invalid item');
	}

	var name = typeof _node.id === 'undefined' || !_node.id.length ? _node.name : _node.id;
	if(typeof name !== 'string' || name === null || !name.length) {
		DivPopup2._error('Invalid item, no name or identifier');
	}

	if(typeof _opt !== 'object') {
		_opt = {};
	}

	_opt.type = typeof _type === 'undefined' ? 'text' : _type;


	// no label, then find associated label element
	if(typeof _opt.label === 'undefined') {
		var parent = _node.parentNode,
		label = parent.getElementsByTagName('label');
		if(label.length != 1) {
			DivPopup2._error(['Cannot find associated label for \'', name, '\''].join(''));
		}

		_opt.label = label[0].innerHTML.toLowerCase();
	}


	// store check options within item
	if(typeof _node.divPopup2 === 'undefined') _node.divPopup2 = {};
	_node.divPopup2.chk = _opt;
};



/* Check ALL the changed items we detected via DivPopup2.formNodeTrackChange
 *
 * Fires the following notifications (if defined by a child):
 *    _onChkChanged()  - on completion of checking changed nodes
 */
DivPopup2.prototype.chkChanged = function(_changed)
{
	err.reset();
	if(this.readOnly || typeof this.nodes === 'undefined') this.getNodeIds();

	var nodes = this.nodes,
	name, n, p, chk;

	if(typeof _changed === 'undefined') _changed = this.changed;

	for(name in _changed) {
		if(
			typeof nodes[name] === 'undefined' ||
			typeof (n = nodes[name]).divPopup2 !== 'object' ||
			typeof (p = n.divPopup2).chk !== 'object'
		) {
			continue;
		}

		switch((chk = p.chk).type) {
		case 'text':
			this.chkText(n, chk.label, chk);
			break;
		case 'int':
			this.chkInt(n, chk.label, chk);
			break;
		case 'float':
			this.chkFloat(n, chk.label, chk);
			break;
		case 'date':
			this.chkDate(n, chk.label, chk);
			break;
		case 'interval':
			this.chkInterval(n, chk.label, chk);
			break;
		case 'price':
			this.chkPrice(n, chk.label, chk);
			break;
		case 'multi':
			this.chkMulti(n, chk.label, chk);
			break;
		}
	}

	if(typeof this._onChkChanged === 'function') this._onChkChanged();
};



/* Add an error to the global error object.
 * NB: Allows a child to override if translations are needed, or not using the global error object
 *
 *   _desc - error description
 *           generally denotes the invalid column name
 */
DivPopup2.prototype.chkAddErr = function(_desc, _node)
{
	err.add(['Invalid ', _desc].join(''));

	if(typeof _node !== 'undefined') {
		err.addNode(_node);
	}
};



/* Check text/textarea.
 *
 *   _node   - node to check
 *             string (identifier) or DOM object
 *   _desc   - error description
 *   _opt    - optional arguments [associated array/hash]
 *               'sChecked'   - node has a checkbox which enables/disables the input; default null
 *                              should point to the checkbox
 *               'minLen'     - minimum length; default 0
 *               'maxLen'     - maximum length; default 0
 *               'like'       - SQL like syntax, overrides opt.re; default false
 *               'valChars'   - valid characters only; default false
 *               're'         - check against regualar expression; default null
 *   returns - true if valid; false if failed
 */
DivPopup2.prototype.chkText = function(_node, _desc, _opt)
{
	if(this.readOnly) return true;

	if(typeof _node === 'string') _node = getObject(_node);
	if(!/^INPUT|TEXTAREA|SELECT$/.test(_node.nodeName)) return true;
	if(_node.nodeName === 'SELECT' && _node.type !== 'select-one') return true;

	var def = {
		'sChecked': null,
		'minLen'  : 0,
		'maxLen'  : 0,
		'like'    : false,
		'valChars': false,
		're'      : null,
		'null'    : false
	}, v;

	v = _node.nodeName === 'SELECT'
		? strTrim(_node.options[_node.selectedIndex].value)
		: strTrim(_node.value);

	_opt = associatedArray(def, _opt);

	// node has a disabled/enable toggle
	if(
		_opt.sChecked !== null &&
		typeof _opt.sChecked === 'object' &&
		_opt.sChecked.checked
	) {
		return true;
	}

	// is null
	if(_opt['null'] && !v.length) return true;

	// SQL 'like' syntax
	if(_opt.like) _opt.re = /^[A-Za-z0-9 _@\.\\%\*\/]+$/;


	// check manadatory
	if(_opt.re === null) {
		if(!ckMandatory(v, _opt.minLen, _opt.maxLen, _opt.valChars)) {
			this.chkAddErr(_desc, _node);
			return false;
		}
	}

	// check against pattern
	else {
		if(!_opt.re.test(v)) {
			this.chkAddErr(_desc, _node);
			return false;
		}
	}

	return true;
};



/* Check integer.
 *
 *   _node   - node to check
 *             string (identifier) or DOM object
 *   _desc   - error description
 *   _opt    - optional arguments [associated array/hash]
 *               'sChecked'   - node has a checkbox which enables/disables the input; default null
 *                              should point to the checkbox
 *               'minLen'     - minimum length; default 0
 *               'maxLen'     - maximum length; default 0
 *               'min'        - minimum number; default null
 *               'max'        - maximum number; default null
 *               'pm'         - allow a +- prefix on the number; default true
 *   returns - true if valid; false if failed
 */
DivPopup2.prototype.chkInt = function(_node, _desc, _opt)
{
	if(this.readOnly) return true;

	if(typeof _node === 'string') _node = getObject(_node);
	if(!/^INPUT|TEXTAREA$/.test(_node.nodeName)) return true;

	var def = {
		'sChecked': null,
		'minLen'  : 0,
		'maxLen'  : 0,
		'min'     : null,
		'max'     : null,
		'pm'      : true
	},
	v = strTrim(_node.value);

	_opt = associatedArray(def, _opt);


	// node has a disabled/enable toggle
	if(
		_opt.sChecked !== null &&
		typeof _opt.sChecked === 'object' &&
		_opt.sChecked.checked
	) {
		return true;
	}


	// check integer
	if(!ckInteger(v, _opt.pm, _opt.minLen, _opt.maxLen)) {
		this.chkAddErr(_desc, _node);
		return false;
	}


	// check value
	if(_opt.min || _opt.max) {
		v = parseInt(v);
		if(isNaN(v) || (_opt.min && v < _opt.min) || (_opt.max && v > _opt.max)) {
			this.chkAddErr(_desc, _node);
			return false;
		}
	}

	return true;
};



/* Check float.
 *
 *   _node   - node to check
 *             string (identifier) or DOM object
 *   _desc   - error description
 *   _opt    - optional arguments [associated array/hash]
 *               'sChecked'   - node has a checkbox which enables/disables the input; default null
 *                              should point to the checkbox
 *               'minLen'     - minimum length; default 0
 *               'maxLen'     - maximum length; default 0
 *               'min'        - minimum number; default null
 *               'max'        - maximum number; default null
 *               'pm'         - allow a +- prefix on the number; default true
 *               'dp'         - decimal places; default 2
 *               'null'       - allow null/empty; default false
 *   returns - true if valid; false if failed
 */
DivPopup2.prototype.chkFloat = function(_node, _desc, _opt)
{
	if(this.readOnly) return true;

	if(typeof _node === 'string') _node = getObject(_node);
	if(!/^INPUT|TEXTAREA$/.test(_node.nodeName)) return true;

	var def = {
		'sChecked': null,
		'minLen'  : 0,
		'maxLen'  : 0,
		'min'     : null,
		'max'     : null,
		'pm'      : true,
		'dp'      : 2,
		'null'    : false
	},
	v = strTrim(_node.value);

	_opt = associatedArray(def, _opt);


	// node has a disabled/enable toggle
	if(
		_opt.sChecked !== null &&
		typeof _opt.sChecked === 'object' &&
		_opt.sChecked.checked
	) {
		return true;
	}


	// is null
	if(_opt['null'] && !v.length) return true;


	// check float
	var exp = ['^((', _opt.pm ? '[+-]?' : '', '([1-9]\\d*|0))(\\.\\d{0,', _opt.dp, '})?|\\.\d{1,',
			   _opt.dp, '})$'].join('');
	exp = new RegExp(exp);

	if(
		!exp.test(v) ||
		(_opt.minLen !== 0 && v.length < _opt.minLen) ||
		(_opt.maxLen !== 0 && v.length > _opt.maxLen)
	) {
		this.chkAddErr(_desc, _node);
		return false;
	}


	// check value
	if(_opt.min || _opt.max) {
		v = parseInt(v);
		if(isNaN(v) || (_opt.min && v < _opt.min) || (_opt.max && v > _opt.max)) {
			this.chkAddErr(_desc, _node);
			return false;
		}
	}


	return true;
};



/* Check ISO 8601 formatted date.
 *
 *   _node   - node to check
 *             string (identifier) or DOM object
 *   _desc   - error description
 *   _opt    - optional arguments [associated array/hash]
 *               'sChecked'   - node has a checkbox which enables/disables the input; default null
 *                              should point to the checkbox
 *               'date'       - date [YYYY-DD-MM]; default true
 *               'time'       - time [HH:MM:SS]; default true
 *               'null'       - condider null date as valid; default false
 *   returns - true if valid; false if failed
 */
DivPopup2.prototype.chkDate = function(_node, _desc, _opt)
{
	if(this.readOnly) return true;

	if(typeof _node === 'string') _node = getObject(_node);
	if(!/^INPUT|TEXTAREA$/.test(_node.nodeName)) return true;

	var def = {
		'sChecked': null,
		'date'    : true,
		'time'    : true,
		'null'    : false
	},
	v = strTrim(_node.value);

	_opt = associatedArray(def, _opt);


	// node has a disabled/enable toggle
	if(
		_opt.sChecked !== null &&
		typeof _opt.sChecked === 'object' &&
		_opt.sChecked.checked
	) {
		return true;
	}

	// is null
	if(_opt['null'] && !v.length) return true;

	// check date
	var exp = !_opt.date && !_opt.time ? null
		: _opt.date && _opt.time ? Date.inf_exp
		: _opt.date ? Date.inf_date_exp
		: Date.inf_time_exp;

	if(typeof exp === 'undefined') {
		DivPopup2._error('Date not installed');
	}

	if(exp === null || !exp.test(v)) {
		this.chkAddErr(_desc, _node);
		return false;
	}

	return true;
};



/* Check formatted interval.
 *
 *   _node   - node to check
 *             string (identifier) or DOM object
 *   _desc   - error description
 *   _opt    - optional arguments [associated array/hash]
 *               'sChecked'   - node has a checkbox which enables/disables the input; default null
 *                              should point to the checkbox
 *               'interval'   - interval [HH:MM:SS]; default true
 *               'null'       - condider null interval as valid; default false
 *   returns - true if valid; false if failed
 */
DivPopup2.prototype.chkInterval = function(_node, _desc, _opt)
{
	if(this.readOnly) return true;

	if(typeof _node === 'string') _node = getObject(_node);
	if(!/^INPUT|TEXTAREA$/.test(_node.nodeName)) return true;

	var def = {
		'sChecked' : null,
		'interval' : true,
		'null'     : false
	},
	v = strTrim(_node.value);

	_opt = associatedArray(def, _opt);

	// node has a disabled/enable toggle
	if(
		_opt.sChecked !== null &&
		typeof _opt.sChecked === 'object' &&
		_opt.sChecked.checked
	) {
		return true;
	}

	// is null
	if(_opt['null'] && !v.length) return true;

	// check interval
	var exp = /^(-?)(\d\d):([0-5]\d):([0-5]\d)$/;

	if(!exp.test(v) || /^(-?)00:00:00$/.test(v)) {
		this.chkAddErr(_desc, _node);
		return false;
	}

	return true;
};



/* Check price (decimal or fractional).
 *
 *   _node   - node to check
 *             string (identifier) or DOM object
 *   _desc   - error description
 *   _opt    - optional arguments [associated array/hash]
 *               'sChecked'   - node has a checkbox which enables/disables the input; default null
 *               'fractional' - fractional price allowed; default true
 *               'decimal'    - decimal price allowed; default true
 *   returns - true if valid; false if failed
 */
DivPopup2.prototype.chkPrice = function(_node, _desc, _opt)
{
	if(this.readOnly) return true;

	if(typeof _node === 'string') _node = getObject(_node);
	if(!/^INPUT|TEXTAREA$/.test(_node.nodeName)) return true;

	var def = {
		'sChecked'  : null,
		'fractional': true,
		'decimal'   : true
	},
	v = strTrim(_node.value);

	_opt = associatedArray(def, _opt);


	// node has a disabled/enable toggle
	if(
		_opt.sChecked !== null &&
		typeof _opt.sChecked === 'object' &&
		_opt.sChecked.checked
	) {
		return true;
	}


	// check price
	if(
		(!_opt.fractional && !_opt.decimal) ||
		(_opt.fractional && _opt.decimal && !ckPrice(v)) ||
		(_opt.fractional && !_opt.decimal && !ckFracPrice(v)) ||
		(!_opt.fractional && _opt.decimal && !ckDecPrice(v))
	) {
		this.chkAddErr(_desc, _node);
		return false;
	}

	return true;
};



/* Check multi-select box has at least 'n' selected items
 *
 *   _node   - node to check
 *             string (identifier) or DOM object
 *   _desc   - error description
 *   _opt    - optional arguments [associated array/hash]
 *               'sChecked'   - node has a checkbox which enables/disables the input; default null
 *               'min'        - minimum number of selected items; default 1
 *&              'max'        - maximum number of selected items; default null
 *   returns - true if valid; false if failed
 */
DivPopup2.prototype.chkMulti = function(_node, _desc, _opt)
{
	if(this.readOnly) return true;

	if(typeof _node === 'string') _node = getObject(_node);
	if(_node.nodeName !== 'SELECT') return true;

	var def = {
		'sChecked': null,
		'min'     : 1,
		'max'     : null
	};

	_opt = associatedArray(def, _opt);


	// node has a disabled/enable toggle
	if(
		_opt.sChecked !== null &&
		typeof _opt.sChecked === 'object' &&
		_opt.sChecked.checked
	) {
		return true;
	}

	if(_opt.min === null && _opt.max === null) return true;

	var o = _node.options,
	i = 0,
	len = o.length,
	total = 0;

	for(; i < len; i++) if(o[i].selected) total++;

	if((_opt.min !== null && total < _opt.min) || (_opt.max !== null && total > _opt.max)) {
		this.chkAddErr(_desc, _node);
		return false;
	}

	return true;
};



/**********************************************************************
 * Div Popup - Private
 *********************************************************************/

/* Private method to initialise the popup.
 *
 *    _opt  - optional arguments
 *            see DivPopup2 constructor for format
 */
DivPopup2.prototype._init = function(_opt)
{
	var cfg = document.divPopup2,
	def = {
		'modal'         : true,
		'id'            : null,
		'title'         : null,
		'tButtons'      : {'help': false, 'min': false, 'max': false, 'close': true},
		'className'     : null,
		'moveable'      : true,
		'width'         : 0,
		'height'        : 0,
		'rButtons'      : [{
								'text'  : 'Cancel',
								'fn'    : 'close'
							},
							{
								'text'   : 'Ok',
								'fn'     : 'submit',
								'disable': true,
								'submit' : true,
								'id'     : 'Submit'
							}
						  ],
		'lButtons'      : null,
		'helpPage'      : null,
		'readOnly'      : false,
		'tabRow'        : null,
		'formHTML'      : null,
		'formPost'      : null,
		'requestBroker' : cfg.requestBroker,
		'getPriority'   : cfg.getPriority,
		'getAction'     : cfg.getAction,
		'submitPriority': cfg.postPriority,
		'submitAction'  : cfg.postAction
	},
	d;

	_opt = associatedArray(def, _opt);

	// initialise modal popup container
	if((this.modal = _opt.modal) && typeof cfg.modalContainer === 'undefined') {

		d = getObject('divPopup2ModalContainer');
		if(!d) {
			d = document.createElement('div');
			d.id = 'divPopup2ModalContainer';
			d.className = ['divPopup2DisplayNone', cfg.browser].join(' ');
			document.body.appendChild(d);
		}
		else {
			addClass(d, 'divPopup2DisplayNone');
		}

		// resize browser window event handler
		if(window.addEventListener) {
			window.addEventListener('resize', DivPopup2._resizeModalContainer, false);
		}
		else if(window.attachEvent) {
			window.attachEvent('onresize', DivPopup2._resizeModalContainer);
		}

		cfg.modalContainer = d;
	}

	// initialise move ghost
	if((this.moveable = _opt.moveable) && typeof cfg.ghost === 'undefined') {

		d = getObject('divPopup2Ghost');
		if(!d) {
			d = document.createElement('div');
			d.id = 'divPopup2Ghost';
			d.className = ['divPopup2DisplayNone', cfg.browser].join(' ');
			document.body.appendChild(d);
		}
		else {
			addClass(d, 'divPopup2DisplayNone');
		}

		cfg.ghost = d;
	}


	// popup details
	this.id  = _opt.id;
	this.opt = _opt;
	this.readOnly = _opt.readOnly;
	this.helpPage = _opt.helpPage;
	this.submitButtons = [];

	this.requestBroker = _opt.requestBroker;
	this.postPriority  = _opt.postPriority;
	this.postAction = _opt.postAction;
	this.submitPriority  = _opt.submitPriority;
	this.submitAction = _opt.submitAction;

	if(_opt.formPost !== null) _opt.formHTML = null;

	// -title
	this.title = {};
	this.title.text = _opt.title;
	this.title.buttons = _opt.tButtons;
};



/* Private method to throw an exception
 *
 *    _msg - message
 */
DivPopup2._error = function(_msg)
{
	throw ['DivPopup2: ', _msg].join('');
};



/* Private method to create/build the popup.
 *
 *    returns - true if successfully create the popup, false if failed
 */
DivPopup2.prototype._create = function()
{
	var opt = this.opt;

	// get the HTML from server
	if(opt.formPost != null) {
		if(
			this.requestBroker === null ||
			typeof this.requestBroker !== 'object' ||
			opt.getAction === null ||
			typeof opt.getAction !== 'string' ||
			!opt.getAction.length
		) {
			DivPopup2._error('Request broker is not defined correctly');
		}

		// -blocking
		var self = this;
		this.requestBroker.send({
			'priority' : opt.getPriority,
			'method'   : 'POST',
			'action'   : opt.getAction,
			'post'     : {'popup': opt.formPost},
			'async'    : false,
			'callback' : function(_resp) { self._create_cb(_resp); },
			'debug'    : true,
			'cb_http_err' : true
		});

		if(this.opt.formHTML === null) return false;
	}


	var id = this.id,
	p = typeof id === 'string' ? getObject(id) : id,
	title = this.title,
	append = false,
	moveable = this.moveable;

	// popup exists
	// -assume that all the components are present!
	if(p) {
		if(p.nodeType !== 'DIV') {
			DivPopup2._error([typeof id === 'string' ? id : id.id, ' is not a DIV'].join(''));
		}

		this.setTitle(title.text);
	}

	// new popup
	else {
		p = document.createElement('div');
		p.id = id;

		// -title container
		var html = [];

		htmlwBegin(html, 'div', {'class': 'titleContainer', 'id': [id, 'Title'].join('')});

		if(moveable) {
			htmlwBegin(html, 'div', {'class': 'moveContainer', 'id': [id, 'TitleMove'].join('')});
		}

		htmlwBegin(html,
				   moveable ? 'span' : 'div',
				   {'class': 'text', 'id': [id, 'TitleText'].join('')},
				   {'data': title.text, 'endNode': true});

		if(moveable) htmlwEnd(html, 'div');

		htmlwBegin(html,
				   'div',
				   {
					   'class': 'titleButtonContainer divPopup2DisplayNone',
					   'id'   : [id, 'TitleButtonC'].join('')
				   },
				   {'endNode': true});

		htmlwEnd(html, 'div');

		// -tab container
		if(opt.tabRow !== null && typeof opt.tabRow === 'object') {
			htmlwBegin(html,
					   'div',
					   {
						   'class': 'tabContainer divPopup2DisplayNone',
						   'id'   : [id, 'TabContainer'].join('')
					   },
					   {'endNode': true});
		}

		// -form container
		htmlwBegin(html,
				   'div',
				   {
					   'class': 'formContainer divPopup2DisplayNone',
					   'id'   : [id, 'FormContainer'].join('')
				   },
				   {'endNode':  true});

		// -button container
		htmlwBegin(html, 'div',
				   {
					   'class': ['buttonContainer divPopup2NonSelectable',
								 opt.lButtons || opt.rButtons
								 ? '' : ' divPopup2DisplayNone'].join(''),
					   'id'   : [id, 'ButtonContainer'].join('')
				   });

		// -button left container
		htmlwBegin(html, 'div',
					{
						'class': 'left',
						'id': [id, 'ButtonLeft'].join('')
					},
					{'endNode': true});

		// -button right container
		htmlwBegin(html, 'div',
					{
						'class': 'right',
						'id': [id, 'ButtonRight'].join('')
					},
					{'endNode': true});

		// Close button container
		htmlwEnd(html, 'div');

		p.innerHTML = html.join('');
		document.body.appendChild(p);

		html = [];
		if(opt.lButtons) DivPopup2._addButtons(id, html, opt.lButtons, this.submitButtons);
		getObject([id, 'ButtonLeft'].join('')).innerHTML = html.join('');

		html = [];
		if(opt.rButtons) DivPopup2._addButtons(id, html, opt.rButtons, this.submitButtons);
		getObject([id, 'ButtonRight'].join('')).innerHTML = html.join('');
	}

	// class details
	(this.popup = p).className = ['divPopup2DisplayNone divPopup2',
								  document.divPopup2.browser,
								  opt.className !== null ? opt.className : '',
								  this.modal ? 'modal' : ''].join(' ');

	// dimensions
	if(opt.width) p.style.minWidth = p.style.width = [opt.width, 'px'].join('');
	if(opt.height) p.style.minHeight = p.style.height = [opt.height, 'px'].join('');

	p.divPopup2 = this;

	// events
	if(this.moveable) {
		var mid = (this.title.moveId = getObject([id, 'TitleMove'].join(''))),
		self = this;

		mid.onmousedown = function(_e) { self._HMoveStart(_e); };
	}


	// title buttons
	this.setTitleButtons(title.buttons);


	// tab-row
	if(opt.tabRow !== null && typeof opt.tabRow === 'object') {
		this.setTabRow(opt.tabRow);
	}


	// add form container
	// -form is either a DOM object or identifier
	//  or JSON repsonseText
	if(opt.formHTML) {
		p = (this.formContainer = getObject([id, 'FormContainer'].join('')));
		if(opt.formPost === null && (typeof opt.formHTML === 'string' || opt.formHTML === null)) {
			opt.formHTML = getObject(opt.formHTML);
		}

		if(opt.formHTML !== null) {
			if(opt.formPost === null) p.appendChild(opt.formHTML);
			else p.innerHTML = opt.formHTML;
			removeClass(p, 'divPopup2DisplayNone');
		}
	}

	delete this.opt;

	return true;
};



/* Private method to handle POST request callback.
 * Sets the formHTML.
 *
 *    _resp  - AJAX response.
 */
DivPopup2.prototype._create_cb = function(_resp)
{

	if(_resp.status == 401 ||
	   _resp.status == 403) {
		//login check error
		var d = parseJSON(_resp.responseText);
		if(d.error.status != 1) {
			// If it's just a permission error then the login_form = 0
			new Error(d.error).log(d.error.message);
			return;
		}
		return;
	}
	else if(_resp.status !== 200) {
		var m = ['Failed to load request '];
		m[m.length] = '- ';
		m[m.length] = _resp.status;
		m[m.length] = ' ';
		m[m.length] = _resp.statusText;
		m = m.join('');

		if(window.errorfire) errorfire('RequestBroker._cb: ', m);
		if(window.PopupAlert) {
			PopupAlert(document.title, m);
		}
		else if(
			typeof document.divPopup2 === 'object' &&
			typeof document.divPopup2.genericAlert === 'object'
		) {
			Alert2.popup(document.title, m, {
				'stdAlert': typeof document.divPopup2.genericAlert.popup !== 'object',
				'center'  : true
			});
		}
		return;
	}

	this.opt.formHTML = _resp.responseText;
};



/* Private method to handle POST submit callback.
 * Does nothing - child's responsibility
 *
 *    _resp   - AJAX response.
 *    _button - button which triggered submit request
 */
DivPopup2.prototype._submit_cb = function(_resp, _button)
{
};



/* Private (class) method to add left and right bottom buttons
 *
 *    _id      - popup identifier
 *    _html    - HTML content array
 *    _buttons - button details
 *               see DivPopup2 constructor for format
 *    _submit  - submit array
 *               collects the submit buttons (automatically enabled/disabled if a change has been
 *               detected within the form)
 */
DivPopup2._addButtons = function(_id, _html, _buttons, _submit)
{
	var disable, id, className, space,
	i = 0,
	len = _buttons.length,
	label, labelClass, labelId;

	for(; i < len; i++) {
		disable = typeof _buttons[i].disable === 'boolean' && _buttons[i].disable;
		id = typeof _buttons[i].id === 'string' && _buttons[i].id.length ? _buttons[i].id : null;
		className = typeof _buttons[i].className === 'string' && _buttons[i].className.length
			? [' ', _buttons[i].className].join('') : '';
		space = i + 1 != len && (typeof _buttons[i].noSpace !== 'boolean' || !_buttons[i].noSpace);

		if(typeof _buttons[i].label === 'object' && _buttons[i].label != null) {
			labelClass = typeof (label = _buttons[i].label).className === 'string'
							? label.className : '';
			labelId = typeof label.id === 'string' ? label.id : null;

			htmlwBegin(_html, 'div',
						{
							'class'  : ['label ',
									   labelClass].join(''),
							'id' : labelId !== null ? (labelId = [_id, labelId].join('')) : null
						},
						{'data' : label.text});
		}

		htmlwBegin(_html, 'div',
				   {
					   'class'  : ['button',
								   disable ? ' disable' : '',
								   className].join(''),
					   'onclick': ['DivPopup2._HOnclick(this,\'',
								   _id,
								   '\',\'',
								   _buttons[i].fn,
								   '\')'].join(''),
						'id'    :  id !== null ? (id = [_id, id].join('')) : null
				   });

		if(typeof _buttons[i].nocontent === 'boolean' && _buttons[i].nocontent) {
			_html[_html.length] = _buttons[i].text;
		} else {
			htmlwBegin(_html, 'div', {'class': 'left'}, {'endNode': true});
			htmlwBegin(_html, 'div', {'class': 'content'}, {'data': _buttons[i].text});
			htmlwBegin(_html, 'div', {'class': 'right'}, {'endNode': true});
		}

		htmlwEnd(_html, 'div');

		if(
			typeof _submit === 'object' &&
			id !== null &&
			typeof _buttons[i].submit === 'boolean' &&
			_buttons[i].submit
		) {
			_submit[_submit.length] = id;
		}
	}
};



/* Private (CLASS) procedure to change/set the text of a button
 */
DivPopup2._setButtons = function(_id, _text)
{
	var html = [];

	if(typeof _id === 'string') _id = getObject(_id);
	if(!_id) return;

	htmlwBegin(html, 'div', {'class': 'left'}, {'endNode': true});
	htmlwBegin(html, 'div', {'class': 'content'}, {'data': _text});
	htmlwBegin(html, 'div', {'class': 'right'}, {'endNode': true});

	_id.innerHTML = html.join('');
};



/* Private method to display the popup.
 *
 *    _center  - center the popup
 */
DivPopup2.prototype._display = function(_center)
{
	var cfg = document.divPopup2;

	// modal popup
	// -display the modal container underneath the popup so nothing can be selected except the popup
	if(this.modal && !cfg.total) {

		DivPopup2._resizeModalContainer();
		removeClass(cfg.modalContainer, 'divPopup2DisplayNone');
	}

	this.popup.style.zIndex = cfg.modalContainer.style.zIndex = cfg.baseZIndex + cfg.total++;
	removeClass(this.popup, 'divPopup2DisplayNone');


	// hide minimised version of the popup
	if(typeof this.minPopup === 'object' && this.minPopup.offsetWidth) {
		cfg.minContainer.removeChild(this.minPopup);
	}


	// need to resize the move container, since title buttons have been adjusted while closed
	if(typeof this.title._resizeMoveContainer === 'boolean') {
		this._resizeMoveContainer();
	}

	if(_center) this.center();

	if(typeof this._onDisplay === 'function') this._onDisplay();
};



/* Private function to display the draggable ghost box.
 */
DivPopup2.prototype._displayGhost = function()
{
	var g = document.divPopup2.ghost,
	s = g.style,
	popup = this.popup,
	pos;

	if(typeof this.pos === 'undefined') pos = (this.pos = new Dimension(popup));
	else (pos = this.pos).get();

	// position the ghost over our popup
	s.zIndex = popup.style.zIndex + 1;
	s.top = [pos.top, 'px'].join('');
	s.left = [pos.left, 'px'].join('');
	s.width = [pos.width, 'px'].join('');
	s.height = [pos.height, 'px'].join('');

	removeClass(g, 'divPopup2DisplayNone');
};



/* Private method to resize the move container within the title bar.
 */
DivPopup2.prototype._resizeMoveContainer = function()
{
	var w = getElementWidth(this.popup),
	title = this.title;

	if(!w) {
		title._resizeMoveContainer = true;
		return;
	}

	title.moveId.style.width = [w - getElementWidth(title.buttonId) - 10, 'px'].join('');

	if(typeof title.resizeMoveContainer === 'boolean') {
		delete title.resizeMoveContainer;
	}
};



/* Private (class) method to resize the modal container.
 */
DivPopup2._resizeModalContainer = function()
{
	var c = document.divPopup2.modalContainer;

	if(!browser.ie && !browser.chrome) {
		c.style.height = window.scrollMaxY
			? [window.scrollMaxY + window.innerHeight, 'px'].join('')
			: '100%';
		c.style.width = window.scrollMaxX
			? [window.scrollMaxX + window.innerWidth, 'px'].join('')
			: '100%';
	}
	else if(browser.ie7) {
		var e = document.documentElement;
		c.style.height = [e.scrollHeight > e.offsetHeight ? e.scrollHeight : e.offsetHeight,
						  'px'].join('');
		c.style.width = [e.scrollWidth > e.offsetWidth ? e.scrollWidth : e.offsetWidth,
						 'px'].join('');
	}
	else {
		var e = document.documentElement;
		c.style.height = [e.scrollHeight, 'px'].join('');
		c.style.width = [e.scrollWidth, 'px'].join('');
	}
};



/* Private method to resize the form container.
 *
 *    _maximised  - flag to denote if form is to be maximised
 */
DivPopup2.prototype._resizeFormContainer = function(_maximised)
{
	if(typeof this.formContainer === 'undefined') return;

	var c = this.formContainer,
	h;

	// maximise the form
	if(_maximised) {

		var title = this.title,
		id = this.id,
		tab = typeof this.tabRow === 'object' ? this.tabRow.id.offsetHeight : 0;

		if(typeof title.id === 'undefined' || title.id === null) {
			title.id = getObject([id, 'Title'].join(''));
		}
		if(typeof this.buttonContainer === 'undefined') {
			this.buttonContainer = getObject([id, 'ButtonContainer'].join(''));
		}

		h = getWindowInnerHeight() -
			(tab + title.id.offsetHeight + this.buttonContainer.offsetHeight);

		c.style.height = [h, 'px'].join('');
	}

	// form back to original size
	else {
		c.style.height = '';
		h = 0;
	}

	if(typeof _maximised === 'undefined' && this.moveable) this._resizeMoveContainer();

	if(typeof this._onResizeFormContainer === 'function') this._onResizeFormContainer(h);
};



/* Private method to set the inner dimensions of the browser (draggable boundary)
 */
DivPopup2.prototype._setMinMaxInnerWindow = function()
{
	var scroll = getScrollXY(),
	x = scroll.x,
	y = scroll.y,
	v, pos;

	if(typeof this.pos === 'undefined') pos = (this.pos = new Dimension(popup));
	else (pos = this.pos).get();

	pos.minX = 1 + x;
	pos.minY = y;
	pos.maxX = (v = getWindowInnerWidth() - pos.width - 5 + x) <= 1
		? getWindowInnerWidth() - 2
		: v;
	pos.maxY = (v = getWindowInnerHeight() - pos.height - 2 + y) <= 1
		? getWindowInnerHeight() - 1
		: v;
};



/* Private method to set the alternate syle for alternating
 * row groups.
 *   _form The selected tab form
 */
DivPopup2.prototype._setAlternate = function(_form)
{
	var div, i, len, idx, fn;

	if(typeof _form === 'undefined') {
		var r = this.tabRow.row;
		for(i = 0, len = r.length; i < len; i++) {
			if(r[i].selected) {
				if(typeof (_form = r[i].formId) === 'string') _form = getObject(r[i].formId);
			}
		}
	}

	div = _form.getElementsByTagName('div');
	idx = 0;

	for(i = 0, len = div.length; i < len; i++) {
		if(hasClass(div[i], 'rowGroup') && div[i].offsetHeight) {
			fn = (idx % 2 === 0) ? addClass : removeClass;
			fn(div[i], 'alternate');
			idx++;
		}
	}
};


/**********************************************************************
 * Div Popup - Event Handlers
 *********************************************************************/

/* Private (class) method to handle bottom button onclick.
 *
 *    _button   - button object which triggered the onlick
 *    _popup    - popup
 *                can be supplied as a string (popup.id) or popup DOM object
 *    _onclick  - onlick function
 *                [close|cancel|help|min|max]
 *                if non of the above, then calls _HDefaultOnclick if defined by child
 */
DivPopup2._HOnclick = function(_button, _popup, _onclick)
{
	if(_button.className.indexOf('disable') !== -1) return;

	if(typeof _popup === 'string') _popup = getObject(_popup);
	if(_popup === null || typeof _popup.divPopup2 === 'undefined') return;

	_popup = _popup.divPopup2;


	// handle button click
	switch(_onclick) {
	case 'close':
	case 'cancel':
		if(typeof document.divPopup2.buttonAnimation === 'function') {
			document.divPopup2.buttonAnimation(_button, true);
		}
		_popup.close();
		break;

	case 'submit':
		if(typeof document.divPopup2.buttonAnimation === 'function') {
			document.divPopup2.buttonAnimation(_button, true);
		}
		_popup.submit(_button);
		break;

	case 'help':
		_popup.help();
		break;

	case 'min':
		_popup.min();
		break;

	case 'max':
		_popup.max();
		break;

	case 'closeMin':
		_popup.closeMin();
		break;

	default:
		if(typeof document.divPopup2.buttonAnimation === 'function') {
			document.divPopup2.buttonAnimation(_button, true);
		}
		if(typeof _popup._HDefaultOnclick === 'function') {
			_popup._HDefaultOnclick(_button, _onclick);
		}
		break;
	}
};



/* Tab onclick handler.
 * Select the clicked tab, and de-select previous tab
 *
 * Fires the following notifications (if defined by a child):
 *   _onHTabOnclick(_tab, selected, deselected)  - sucessfully selected/deselected a tab
 *
 *   _tab  - tab clicked
 */
DivPopup2._HTabOnclick = function(_tab)
{
	if(typeof _tab.className !== 'undefined'
				&& _tab.className.indexOf('selected') !== -1) return;

	// find popup details
	var popup = _tab.parentNode.parentNode;
	if(
		typeof popup.divPopup2 !== 'object' ||
		typeof (popup = popup.divPopup2).tabRow !== 'object'
	) {
		return;
	}


	// select this tab and unselect old tab
	var r = popup.tabRow.row,
	i = 0,
	len = r.length,
	selected = null,
	deselected = null;

	for(; i < len; i++) {
		if(typeof r[i].id === 'string') r[i].id = getObject(r[i].id);
		if(typeof r[i].formId === 'string') r[i].formId = getObject(r[i].formId);

		if(r[i].selected) {
			deselected = r[i];
			r[i].selected = false;
			removeClass(r[i].id, 'selected');
			addClass(r[i].formId, 'divPopup2DisplayNone');
		}
		else if(r[i].id === _tab) {
			selected = r[i];
			r[i].selected = true;
			select = i;
			addClass(r[i].id, 'selected');
			removeClass(r[i].formId, 'divPopup2DisplayNone');
		}
	}

	if(typeof popup._onHTabOnclick === 'function') {
		popup._onHTabOnclick(_tab, selected, deselected, popup);
	}
};



/* Private method to handle a minimised popup click.
 * Re-opens the popup
 */
DivPopup2.prototype._HMinOnclick = function()
{
	this.open();

	if(typeof this._onHMinOnclick === 'function') this._onHMinOnclick();
};



/* Private method to start moving the popup.
 * Creates the events which monitors the dragging and when the dragging ends
 *
 *    _e  - event object
 */
DivPopup2.prototype._HMoveStart = function(_e)
{
	if(typeof this.maxPopup === 'object') return;

	if(typeof this._onMoveStart === 'function') this._onMoveStart(_e);

	this._displayGhost();
	document.divPopup2.ghost.evXY = getEventXY(_e);

	this._setMinMaxInnerWindow();

	var self = this;
	document.onmousemove = function(_ev) { self._HMove(_ev); };
	document.onmouseup = function(_ev) { self._HMoveEnd(_ev); };

	addClass(document.body, 'divPopup2NonSelectable');
};



/* Private method to monitor the movement of the ghost popup
 *
 *    _e  - event object
 */
DivPopup2.prototype._HMove = function(_e)
{
	var ed = getEventXY(_e),
	ghost = document.divPopup2.ghost,
	x = getElementLeft(ghost),
	y = getElementTop(ghost),
	pos = this.pos,
	nx, ny;

	// keep within boundaries of the inner window
	nx = (nx = x + (ed.x - ghost.evXY.x)) < pos.minX ? pos.minX : nx > pos.maxX ? pos.maxX : nx;
	ny = (ny = y + (ed.y - ghost.evXY.y)) < pos.minY ? pos.minY : ny > pos.maxY ? pos.maxY : ny;

	// keep track of current mouse X/Y co-ordinates
	ghost.evXY = ed;

	// move the ghost to new position
	moveXY(ghost, nx, ny);

	if(typeof this._onMove === 'function') this._onMove(nx, ny);

	return false;
};



/* Private method to end the movement of the ghost popup and move the popup into it's final position
 *
 *    _e  - event object
 */
DivPopup2.prototype._HMoveEnd = function(_e)
{
	document.onmousemove = null;
	document.onmouseup = null;

	// move popup to ghost's position
	var ghost = document.divPopup2.ghost;
	moveXY(this.popup, ghost.style.left, ghost.style.top);

	addClass(ghost, 'divPopup2DisplayNone');

	if(typeof this._onMoveEnd === 'function') this._onMoveEnd();

	removeClass(document.body, 'divPopup2NonSelectable');
};



/**********************************************************************
 * Startup
 *********************************************************************/

DivPopup2.init();
