/*
 * $Id: xmlhttp.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * getXMLHttpRequest
 *
 * Note: base.js should be sourced as well before using this library
 */

if(window.cvsID) {
	cvsID('xmlhttp', '$Id: xmlhttp.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'xmlhttp');
	document.Package.require('office', 'base');
}

/**********************************************************************
 * getXMLHttpRequest
 *********************************************************************/

function getXMLHttpRequest()
{
	var httpReq = false;

	try {
		// non-IE and IE7
		httpReq = new XMLHttpRequest();

		// Some versions of Mozilla are reported as locking up when anything
		// other than XML is returned
		if (httpReq.overrideMimeType) {
			httpReq.overrideMimeType("text/xml");
		}
	}
	catch(e) {
		// IE (not IE7)
		var type = ['MSXML2.XMLHTTP.3.0','MSXML2.XMLHTTP','Microsoft.XMLHTTP'],
			i = 0,
			len = type.length;

		for(; i < len; i++){
			try {
				httpReq = new ActiveXObject(type[i]);
				break;
			} catch(e) {}
		}

	} finally {
		return httpReq;
	}
}



/* AJAX (get|post) HTTP Request.
 *
 *    _method               - GET or POST
 *    _callback             - function to call on receiving response
 *    _post.                - post parameters
 *    _varAsync.            - optional. Default true.
 *                            Should the request be non-blocking?
 *    _extra_hdrs           - optional. Default null.
 *                            Extra HTTP headers to add to the request
 *    _error_check_callback - optional. Function to call to check for errors
 *    _error_callback       - optional. Function to call when _error_check_callback
 *                            encounters an error
 */
function HttpRequest(_url, _method, _callback, _post, _varAsync, _extra_hdrs, _error_check_callback, _error_callback)
{
	var req = getXMLHttpRequest();
	if(!req) {
		alert("Your browser does not support AJAX, please upgrade");
		return;
	}

	if(typeof _varAsync === 'undefined' || typeof _varAsync === 'object') {
		// Misuse of arguments. Set to default.
		_varAsync = true;
		_extra_hdrs = null;
	}

	req.open(_method, _url, _varAsync);
	req.setRequestHeader("Content-Type", "application/x-www-form-urlencoded;");

	if (typeof _extra_hdrs === 'object' && _extra_hdrs !== null) {
		var hdr;
		for (hdr in _extra_hdrs) {
			req.setRequestHeader(hdr, _extra_hdrs[hdr]);
		}
	}


	// non-blocking
	if(_varAsync) {
		req.onreadystatechange = function() {
			if(req.readyState == 4) {
				if (browser.ie) req.onreadystatechange = new Function;
				if (typeof _error_callback === 'function' &&
					typeof _error_check_callback === 'function' &&
					_error_check_callback(req.status) == false) {
					return _error_callback(req);
				}
				_callback(req);
			}
		};
	}

	if(_method == "POST") req.send(_post);
	else req.send(null);

	// blocking
	if(!_varAsync) _callback(req);

	return req;
}



/* toggle AJAX image busy-indicator
 *
 *  _id     - indicator identifier
 *            should include the class http_indicator
 *  _enable - flag to enable or disbale the indicator
 */
function HttpIndicator(_id, _enable)
{
	var obj = getObject(_id);

	if(obj && obj.className.indexOf('http_indicator') > -1) {
		obj.style.backgroundImage = _enable
			? ['url(', document.ajaxIndicator.src, ')'].join('')
			: 'none';
	}
}
