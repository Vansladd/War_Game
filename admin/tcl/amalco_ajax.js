/*
 * $Header: /cvsroot-openbet/training/admin/tcl/amalco_ajax.js,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
 *
 * Utility functions for Asynchronous JavaScript and XML (AJAX)
 */

/*
 *	Returns a browser independant XMLHttpRequest object, or false on error.
 */
// GLOBAL ajax counter
// add to user_id to enforce non-cached response.
var ajax_counter = 0;

/*
 *	Returns a browser independant XMLHttpRequest object, or false on error.
 */
function getHttpRequestObject() {
	var httpReq = false;
	
	// Mozilla/Safari/IE7+
	if (window.XMLHttpRequest) {
		try {
			httpReq = new XMLHttpRequest();
			// Some versions of Mozilla are reported as locking up when anything other than XML is returned
			// IE7 doesn't like overrideMimeType, only call this if its supported.
			if (httpReq.overrideMimeType)   {
				httpReq.overrideMimeType("text/xml");
			}
		}  catch (e) {
			httpReq = false;
		}
	} else if (window.ActiveXObject) {
		// IE6 or less
		try {
			httpReq = new window.ActiveXObject("Msxml2.XMLHTTP");
		} catch (e) {
			try {
				httpReq = new window.ActiveXObject("Microsoft.XMLHTTP");
			} catch (e) {
				httpReq = false;
			}
		}
	}
	return httpReq;
}

// Performs an ajax request
// Arguments:
// - url - a url built of all the arguments for the ajax call
// - func - the function that is to be calles on success
// - errfunc - the function to be called on error
// - async - send asyncronously - this is recommended for all requests,
//                                it stops the browser from seizing up
//                                whilst it waits for a response

function Ajax(url, func, errfunc, async) {

	var httpReq = getHttpRequestObject();

	if (!errfunc) {
		errfunc = standardErr;
	}

	if (httpReq) {

		httpReq.open("GET", url, async);
		httpReq.onreadystatechange = function() {
			// check for the correct readyState
			if (httpReq.readyState == 4) {
				// check that the request was sent and returned without error
				if (httpReq.status == 200) {
					func(httpReq);
				} else {
					errfunc(httpReq.status);
				}
			}
		}

		httpReq.send(null);
	} else {
		alert('Your browser does not support this functionality.');
	}
}

/*
 * This is a standard error function for the AJAX call. If no errfunc is specified in Ajax()
 * this function will be called.
 */
function standardErr(errorCode) {
	alert('Error '+errorCode+': An error has occurred. Please try again later.');
}

/*
 * Create a stub URL with all mandatory values
 * uses ajax_counter defined on all pages.
 */
function createUrlStub (action,user_id) {

	// add ajax_counter to the user id and append into URL, set the defined action.
	var n = user_id + ajax_counter;
	var url = '?action='+action+'&n='+n;

	// increase the ajax counter
	ajax_counter++;

	return url
}

/*
 * Append to a URL an items content given its id.
 */
function appendToUrl(url,id,type) {
	
	if (type == 'input') {
		url_part = '&'+ id + '=' + document.getElementById(id).value;
	} else {
		url_part = '&'+ id + '=' + document.getElementById(id).innerHTML;
	}

	url = url + url_part;

	return url;
}

/*
 * Determine if an error occurred
 */

/*
 * This is an example AJAX function using the above library
 * Note uses the standard error function
 */

/*
function do_example_ajax (user_id) {

	var url = createUrlStub('some_action',user_id);
	url = appendToUrl('url','some_input_id','input');

	var async = true;

	Ajax(url,'callback_func', false, async);
}

*/

/*
 * This is an example callback function
 */

/*
function callback_function (httpReq) {

	// get the return message
	var ret_val = unescape(httpReq.responseText);

	// do something with it
	document.getElementById('to_update').innerHTML = ret_val;

}
*/
