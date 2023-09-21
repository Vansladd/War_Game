/* $Id: request_broker.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2010 Orbis Technology Ltd. All rights reserved.
 *
 * The Request Broker provides prioritised asynchronous AJAX queues. Each priority is
 * assigned a queue (associated array indexed by the priority) that serialises the requests. The
 * requests are still asynchronous, but ordered!
 *
 * The broker will handle any errors with the request before calling the user supplied 'callback'.
 *
 * Use the broker in environments which you cannot control the ordering of the AJAX requests.
 */

if(window.cvsID) {
	cvsID('request_broker',
		  '$Id: request_broker.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $',
		  'office');
}



/**********************************************************************
 * RequestBroker - Public
 *********************************************************************/

/* Constructor
 *
 *   _opt - optional arguments (associated array)
 *          'url'           - server url; default null (must be supplied per send request)
 *          'indicator_cb'  - indicator/animated-GIF callback function; default null
 *                            signature:
 *                               function name(_enable) { ... }
 *                            where
 *                               _enable - if true then should start animated GIF, else stop
 *          'max_priority'  - maximum priority; default 10
 *                            keep this maximum small, as can impact performance
 *          'extra_hdrs'    - Extra HTTP headers to add when sending request using
 *                            HttpRequest. Should be an object in the form
 *                            {'h1': 'v1', 'h2': 'v2', etc}; default none
 */
function RequestBroker(_opt)
{
	this._init(_opt);
}



/* Send a request.
 *
 * The request might not be sent immediately if busy, but will be queued. Duplicate request will
 * ignored.
 *
 *   _opt - optional arguments (associated array)
 *          'priority'        - request pririty; default 0
 *                              the request is added to the queue indexed by the priority, lowest
 *                              priority takes precedence
 *          'url'             - server url; default this.url
 *                              if not supplied will use url set on construction
 *          'method'          - HTTP method (GET|POST); default 'POST'
 *          'action'          - POST action argument; default null
 *                              only applicable if POSTing an associated array
 *          'post'            - post/get arguments; default null
 *                              can be supplied as a string, e.g. '&name=value&name1=value1...'
 *                              or as an associated array (name value pairs)
 *                              if supplying an associated array, then action must be supplied
 *          'async'           - Asynchronous request; default true
 *                              if non-async, the request is not queued and is sent immeditatly,
 *                              regadless of priority and queue size
 *          'callback'        - request callback; default null
 *                              called on successully reciving an AJAX response
 *                              signature:
 *                              function name(_response) { ... }
 *                              where:
 *                              _response    AJAX response object
 *          'cb_http_err'     - will the request callback handle HTTP status checks; default false
 *                              if true, the request broker will not check and report a bad HTTP
 *                              status, it will become the responsibility of the callback to check
 *          'extra_hdrs'      - Extra HTTP headers to add when sending request using
 *                              HttpRequest. Should be an object in the form
 *                              {'h1': 'v1', 'h2': 'v2', etc}; default this.extra_hdrs
 *                              If not supplied will use extra_hdrs set on construction
 *          'debug'           - debug mode; default false
 *                              logs messages to firebug if enabled (printfire must be enabled)
 *          'log_time'        - Capture the date before sending the http request and the date when receiving the
 *                              response, and store the diff in the response object
 *          'nocache'         - Generates a random number on the url of the request in order to
 *                               prevent caching
 *          'timeoutmsecs'    - if supplied it will invalidate the request after N msecs. This
 *                              means that should a response arrive after that time it will be
 *                              ignored, and timeoutcallback supplied will be executed at that
 *                              point.
 *          'timeoutcallback' - must be supplied along with timeoutmsecs and will be executed
 *                              upon timeout
 */
RequestBroker.prototype.send = function(_opt)
{
	var def = {
		'priority'        : 0,
		'url'             : this.url,
		'method'          : 'POST',
		'action'          : null,
		'post'            : null,
		'async'           : true,
		'callback'        : null,
		'cb_http_err'     : false,
		'debug'           : false,
		'log_time'        : false,
		'extra_hdrs'      : this.extra_hdrs,
		'nocache'         : false,
		'timeoutmsecs'    : this.timeoutValue,
		'timeoutcallback' : this.timeoutCallback,
		'abortOnTimeout'  : this.abortOnTimeout
	},
	a = ['url', 'method', 'callback'],
	i = 0,
	c;

	_opt = associatedArray(def, _opt);

	if(_opt.debug && (!window.printfire || typeof window.printfire !== 'function')) {
		_opt.debug = false;
	}


	// convert post arguments if supplied as an object
	if(_opt.method === 'POST' && typeof _opt.post === 'object') {
		_opt.post = RequestBroker.build_post(_opt.action, _opt.post);
	}


	// non-async request sent immediately
	if(!_opt.async) {
		this._send(null, _opt);
		return;
	}


	// add arguments to queue, indexed by priority
	var queue = this.queue,
	p = _opt.priority,
	len;

	if(typeof queue[p] === 'undefined') queue[p] = [];

	// -check if the request is already within the queue
	_opt.checksum = [_opt.url, _opt.method, _opt.post].join('|');
	for(i = 0, a = queue[p], len = a.length; i < len; i++) {
		if(a[i].checksum === _opt.checksum) {
			if(_opt.debug) {
				printfire('RequestBroker.send: ignorning duplicate request ', _opt.checksum);
			}
			return;
		}
	}

	if(_opt.nocache) {
		var msg = [];

		msg[msg.length] = _opt.url;
		if(_opt.url.search("\\?") >= 0) {
			msg[msg.length] = '&no_cache=';
		}
		else {
			msg[msg.length] = '?no_cache=';
		}
		msg[msg.length] = _opt.req_num;
		_opt.url = msg.join('');
	}

	if(
		typeof _opt.timeoutmsecs === 'number' &&
		_opt.timeoutmsecs > 0 &&
		typeof _opt.timeoutcallback === 'function'
	) {
		var self = this;
		_opt.timeoutId = setTimeout(function() { self._timeout_cb(_opt) }, _opt.timeoutmsecs);
	}

	// -push request to queue
	a[a.length] = _opt;


	// send
	this._send(_opt.debug);
};



/* Build a post request
 *
 *   _action  - post action
 *   _nvp     - name value list
 *   returns  - post request (string of name value pairs delimited by =)
 */
RequestBroker.build_post = function(_action, _nvp)
{
	var post = [['action=', _action].join('')],
	name, i, len, a;

	for(name in _nvp) {
		if(_nvp[name] === null) continue;

		if(typeof _nvp[name] === 'object') {
			for(i = 0, a = _nvp[name], len = a.length; i < len; i++) {
				post[post.length] = ['&', name, '=', a[i]].join('');
			}
		}
		else {
			post[post.length] = ['&', name, '=', _nvp[name]].join('');
		}
	}

	return post.join('');
};



/**********************************************************************
 * RequestBroker - Private
 *********************************************************************/

/* Constructor
 * [see RequestBroker]
 */
RequestBroker.prototype._init = function(_opt)
{
	var def = {
		'url'            : null,
		'indicator_cb'   : null,
		'max_priority'   : 10,
		'extra_hdrs'     : null,
		'timeoutmsecs'   : null,
		'timeoutcallback': null,
		'abortOnTimeout' : false
	};

	_opt = associatedArray(def, _opt);

	this.queue           = {};
	this.busy            = false;
	this.req_num         = 1;
	this.url             = _opt.url;
	this.indicator_cb    = _opt.indicator_cb;
	this.max_priority    = _opt.max_priority;
	this.extra_hdrs      = _opt.extra_hdrs;
	this.timeoutCallback = _opt.timeoutcallback;
	this.timeoutValue    = _opt.timeoutmsecs;
	this.httpRequest     = null;
	this.abortOnTimeout  = _opt.abortOnTimeout;
};



/* Private function to send a request.
 *
 * If trying to send an asynchrouns request, looks on the all the priority queues (starting at 0)
 * for the next request and sends to server. If busy, will immediately return and wait for the
 * current request to finish and send.
 * If the queues are empty, exits
 *
 * Will send a synchrouns request immediately.
 *
 *   _debug - debug mode (logs to firebug); default none
 *   _req   - synchrounous request; default none;
 *            if supplied, then will send synchrounously, else looks on the queue
 *
 */
RequestBroker.prototype._send = function(_debug, _req)
{
	// find next request
	if(typeof _req === 'undefined') {

		// busy
		if(this.busy) {
			if(typeof _debug === 'boolean' && _debug) {
				printfire('RequestBroker._send: busy');
			}
			return;
		}

		var queue = this.queue,
		priority = 0,
		p;


		// find the lowest priority number
		for(; priority <= 100; priority++) {
			for(p in queue) {
				if(p <= priority && queue[p].length) {
					priority = p;
					break;
				}
			}
			if(priority === p) break;
		}

		// queue empty
		if(typeof queue[priority] === 'undefined' || !queue[priority].length) {
			return;
		}


		// get 1st item (oldest) in the queue
		_req = queue[priority].shift();
	}

	var self = this;


	// send request
	this._indicator(true);
	if(_req.debug) {
		printfire('RequestBroker._send: ',
				  (_req.num = this.req_num++),
				  _req.priority,
				  _req.async,
				  _req.url,
				  _req.method,
				  _req.post);

		if(_req.log_time) {
			_req.serverTime = new Date().getTime();
		}
	}

	// -denote busy if sending an asynchronous request
	//  only sending 1 async at a time
	if(_req.async) this.busy = true;

	this.httpRequest = HttpRequest(_req.url,
						_req.method,
						function(_r) { self._cb(_req, _r); },
						_req.post,
						_req.async,
						_req.extra_hdrs);
};



/* Private function to handle an AJAX response callback
 * Will display an error if the status is not 200, else calls the user-supplied callback.
 * When complete, and handling an asynchrounous request, re-calls _send to process next request.
 *
 * Callback is protected by a try-catch block, exceptions will be logged on firebug or an alert
 *
 *   _req   - request
 *   _resp  - AJAX response
 */
RequestBroker.prototype._cb = function(_req, _resp)
{
	if(_req.debug) {
		printfire('RequestBroker._cb: ', _req.num, _req.priority, _resp.status, _resp.statusText);

		if(_req.log_time) {
			// store data for logging request time
			var time = new Date().getTime();

			_resp.processTime = {
				'action' : _req.action,
				'server' : time - _req.serverTime,
				'client' : time
			};
		}
	}


	// clear timeout
	if(_req.timeoutId) {
		clearTimeout(_req.timeoutId);
		_req.timeoutId = 0;
	}


	// bad response
	// -report the error, unless the callback is configured to handle the error
	if(!_req.cb_http_err && _resp.status !== 200) {
		var m = ['Failed to load request '];
		if(_req.debug) {
			m[m.length] = '(',
			m[m.length] = _req.num,
			m[m.length] = ') ';
		}
		m[m.length] = '- ';
		m[m.length] = _resp.status;
		m[m.length] = ' ';
		m[m.length] = _resp.statusText;
		m = m.join('');

		if(window.errorfire) errorfire('RequestBroker._cb: ', m);
		if(
			typeof document.divPopup2 === 'object' &&
			typeof document.divPopup2.genericAlert === 'object'
		) {
			Alert2.popup(document.title, m, {
				'stdAlert': typeof document.divPopup2.genericAlert !== 'object',
				'center'  : true
			});
		}
	}

	// request callback
	else {
		try {
			if(typeof _req.callback === 'function')  _req.callback(_resp);
		}
		catch(_e) {
			var m = ['Failed to call callback '];
			if(_req.debug) {
				m[m.length] = '(',
				m[m.length] = _req.num,
				m[m.length] = ') ';
			}
			m[m.length] = _e.message;
			m = m.join('');

			if(window.errorfire) errorfire('RequestBroker._cb: ', m);
			if(
				typeof document.divPopup2 === 'object' &&
				typeof document.divPopup2.genericAlert === 'object'
			) {
				Alert2.popup(document.title, m, {
					'stdAlert': typeof document.divPopup2.genericAlert !== 'object',
					'center'  : true
				});
			}
		}
	}


	// next request
	if(_req.async) {
		this.busy = false;
		this._send();
	}


	this._indicator(false);
};



/* Private function to handle an indicator
 * Will enable indicator on first request, and stop on the last
 *
 *   _enable  - enable the indicator
 */
RequestBroker.prototype._indicator = function(_enable)
{
	if(this.indicator_cb === null) return;

	if(_enable) {
		if(typeof this.indicator_count === 'undefined') this.indicator_count = 1;
		else this.indicator_count++;

		if(this.indicator_count === 1) this.indicator_cb(true);
	}
	else if(--this.indicator_count === 0) {
		this.indicator_cb(false);
	}
};



/* Private function to handle TimeOuts
 * Will invalidate the callback and execute timeoutcallback
 *
 * _req - request
 */
RequestBroker.prototype._timeout_cb = function(_req)
{
	if(_req.abortOnTimeout) {
		var req = this.httpRequest;

		// Cancel RequestBroker callback
		req.onreadystatechange = null;

		// Abort request
		req.abort();

		// Free up request broker
		this.busy = false;
		this._indicator(false);
	}

	_req.timeoutId = 0;

	// Cancel request specific callback
	_req.callback  = null;

	// Execute request specific timeout callback
	_req.timeoutcallback();
};
