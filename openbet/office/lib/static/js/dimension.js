/*
 * $Id: dimension.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Dimension utilities
 */

if(window.cvsID) {
	cvsID('dimension', '$Id: dimension.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'dimension');

	document.Package.require('office', 'base');
}


/**********************************************************************
 * Dimension Class
 *********************************************************************/

function Dimension(_id, _offsetParent)
{
	// object identifier
	this.id = typeof _id === 'string' ? getObject(_id) : _id;

	// get the dimensions
	this.get = function(_offsetParent)
	{
		if(this.id === null) return;

		// legacy
		if(typeof _id._offsetParent !== 'undefined') {
			this.top = getElementTop(this.id, _offsetParent);
			this.left = getElementLeft(this.id, _offsetParent);
		}
		else {
			var d = getElementPos(_id);
			this.top = d.top;
			this.left = d.left;
		}
		this.x = this.left;
		this.y = this.top;
		this.width = getElementWidth(this.id);
		this.height = getElementHeight(this.id);
	};

	this.get(_offsetParent);
}



/**********************************************************************
 * Dimension Utilities
 *********************************************************************/

/* Get window/browser inner height
 *
 *   returns - window's inner height
 */
function getWindowInnerHeight()
{
	if(!browser.op && document.documentElement.clientHeight) {
		return document.documentElement.clientHeight;
	}
	else if(document.body.clientHeight) {
		return document.body.clientHeight;
	}

	return window.innerHeight;
}



/* Get window/browser inner width
 *
 *   returns - window's inner width
 */
function getWindowInnerWidth()
{
	if(!browser.op && document.documentElement.clientWidth) {
		return document.documentElement.clientWidth;
	}
	else if(document.body.clientWidth) {
		return document.body.clientWidth;
	}

	return window.innerWidth;
}



/* Get the Y/top co-ordinate of an element
 * Legacy.
 *
 *   _elem         - DOM element or element identifier
 *   _offsetParent - offset parent; default none
 *                   recommend getElementPos()
 *   returns       - Y/top co-ordinate
 */
function getElementTop(_elem, _offsetParent)
{
	if(_elem === null || typeof _elem === 'undefined') return 0;

	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(!_elem) return 0;

	if(browser.ns4) return _elem.pageY;

	var yPos = _elem.offsetTop,
	tempEl = _elem._offsetParent;

	while((typeof _offsetParent === 'undefined' || _offsetParent) && tempEl != null) {
		yPos += tempEl.offsetTop;
		tempEl = tempEl._offsetParent;
	}

	return yPos;
}



/* Get the X/left co-ordinate of an element
 *
 *   _elem         - DOM element or element identifier
 *   _offsetParent - offsert parent; default none
 *                   recommend getElementPos()
 *   returns       - X/top co-ordinate
 */
function getElementLeft(_elem, _offsetParent)
{
	if(_elem === null || typeof _elem === 'undefined') return 0;

	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(!_elem) return 0;

	if(browser.ns4) return _elem.pageX;

	var xPos = _elem.offsetLeft,
	tempEl = _elem._offsetParent;

	while((typeof _offsetParent === 'undefined' || _offsetParent) && tempEl != null) {
		xPos += tempEl.offsetLeft;
		tempEl = tempEl._offsetParent;
	}

	return xPos;
}



/* Get the left and top 'absolute' dimension
 * -sum of the element and element's parent[s] dimensions
 *
 *   _elem   - DOM element or element idenitifer
 *   returns - object [associated array]:
 *             left - left position
 *             top  - top position
 */
function getElementPos(_elem)
{
	var left = 0,
	top = 0;

	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(!_elem) return null;

	if(browser.ns4) return {'left': _elem.pageX, 'top': _elem.pageY};

	if(_elem.offsetParent) {
		do {
			left += _elem.offsetLeft;
			top += _elem.offsetTop;
		} while ((_elem = _elem.offsetParent));
	}

	return {'left': left, 'top': top};
}



/* Get an element's width
 *
 *   _elem         - DOM element or element identifier
 *   returns       - width
 */
function getElementWidth(_elem)
{
	if(_elem === null || typeof _elem === 'undefined') return 0;

	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(!_elem) return 0;

	return browser.op5
		? _elem.style.pixelWidth
		: (browser.ns4 ? _elem.clip.width : _elem.offsetWidth);
}



/* Get an element's height
 *
 *   _elem         - DOM element or element identifier
 *   returns       - height
 */
function getElementHeight(_elem)
{
	if(_elem === null || typeof _elem === 'undefined') return 0;

	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(!_elem) return 0;

	return browser.op5
		? _elem.style.pixelHeight
		: (browser.ns4 ? _elem.clip.height : _elem.offsetHeight);
}



/* Get the browser's scroll X + Y offsets
 *
 *   return - object [associated array]:
 *            x  - X offset
 *            y  - Y offser
 */
function getScrollXY()
{
	// Netscape compliant
	if(typeof(window.pageYOffset) === 'number') {
		return {y: window.pageYOffset, x: window.pageXOffset};
	}

	// DOM compliant
	else if(document.body && (document.body.scrollLeft || document.body.scrollTop)) {
		return {y: document.body.scrollTop, x: document.body.scrollLeft};
	}

	// IE6 standards compliant mode
	else if(
		document.documentElement &&
		(document.documentElement.scrollLeft || document.documentElement.scrollTop)
	) {
		return {y: document.documentElement.scrollTop, x: document.documentElement.scrollLeft};
	}

	return {x: 0, y: 0};
}
