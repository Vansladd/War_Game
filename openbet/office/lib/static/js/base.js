/*
 * $Id: base.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Base Javascript
 */

if(window.cvsID) {
	cvsID('base', '$Id: base.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

document.tocMinus = null;
document.tocPlus  = null;


if(document.Package) {
	document.Package.provide('office', 'base');
}


/**********************************************************************
 * Browser
 *********************************************************************/

// sniff out problem browsers
function SniffBrowser()
{
	var a = (this.agt = navigator.userAgent.toLowerCase()),
	i;

	this.ns4      = document.layers;

	this.op5      = a.indexOf("Opera 5") !== -1 || a.indexOf("Opera/5") !== -1;
	this.op6      = a.indexOf("Opera 6") !== -1 || a.indexOf("Opera/6") !== -1;
	this.op8      = a.indexOf("Opera 8") !== -1 || a.indexOf("Opera/8") !== -1;
	this.op9      = a.indexOf("Opera 9") !== -1 || a.indexOf("Opera/9") !== -1;
	this.op       = this.op5 || this.op6 || this.op8 || this.op9;

	this.safari   = a.indexOf("safari") !== -1;

	this.ie       = a.indexOf("msie") !== -1;
	this.ie7      = a.indexOf("msie 7") !== -1;
	this.ie8      = a.indexOf("msie 8") !== -1;
	this.ie9      = a.indexOf("msie 9") !== -1;
	this.mac_ie   = this.mac && this.ie;

	this.chrome   = a.indexOf("chrome") !== -1;
	this.webkit   = a.indexOf("applewebkit") !== -1;

	this.gecko    = a.indexOf("gecko") !== -1;
	this.ffox     = a.indexOf("firefox") !== -1;
	this.ffox3    = a.indexOf("firefox/3") !== -1;
	this.ffox35   = a.indexOf("firefox/3.5") !== -1;
	this.ffox36   = a.indexOf("firefox/3.6") !== -1;

	// major version only
	this.ffox_ver = (i = a.indexOf("firefox/")) !== -1 ? parseFloat(a.substr(i + 8)) : NaN;

	this.mac      = a.indexOf("macintosh") !== -1;
	this.linux    = a.indexOf("linux") !== -1;
	this.windows  = a.indexOf("windows") !== -1;

	this.lin_ff = this.linux && this.ffox;
	this.win_ff = this.windows && this.ffox;
	this.mac_ff = this.mac && this.ffox;

	this.lin_crm = this.linux && this.chrome;
	this.win_crm = this.windows && this.chrome;
}
var browser = new SniffBrowser();



// IE specific APIs...
if(!browser.ie || browser.op) {

	// swap node
	function swapNode(_node, _base)
	{
		var p = _node.parentNode,
			s = _node.nextSibling;

		if(!this.parentNode) {
			if(typeof _base == 'undefined') return null;
		}
		else {
			_base = this;
		}

		_base.parentNode.replaceChild(_node, _base);
		p.insertBefore(_base, s);

		return _base;
	}


	// remove node
	function removeNode(_node)
	{
		if(!this.parentNode) {
			if(typeof _node == 'undefined') return null;
		}
		else {
			_node = this;
		}

		_node.parentNode.removeChild(_node);
		return _node;
	}

	// Safari 2.0.* does not support prototype on Node, or allow Node to be modifed,
	// therefore, use functions directly
	if(self.Node && self.Node.prototype) {
		Node.prototype.swapNode = swapNode;
		Node.prototype.removeNode = removeNode;
	}
}



// Array.indexOf for IE and any other browser that doesn't support it.
if(!Array.prototype.indexOf) {

	Array.prototype.indexOf = function(_elt)
	{
		var len = this.length,
		from = Number(arguments[1]) || 0;

		from = (from < 0) ? Math.ceil(from) : Math.floor(from);
		if (from < 0) from += len;

		for (; from < len; from++) {
			if (from in this && this[from] === _elt) return from;
		}

		return -1;
	};
}



/**********************************************************************
 * DOM
 *********************************************************************/

/* Get object for the different types of browsers
 *
 *   _objectId  - object identifier to find (string)
 *   returns    - DOM object, or null if not found or bad _objectId
 */
function getObject(_objectId)
{
	if(typeof _objectId !== 'string' || _objectId === null || !_objectId.length) return null;

	if(document.getElementById && document.getElementById(_objectId)) {
		return document.getElementById(_objectId);
	}
	if(document.all && document.all(_objectId)) {
		return document.all(_objectId);
	}
	if(document.layers && document.layers[_objectId]) {
		return getObjNN4(document, _objectId);
	}

	return null;
}



// find an object (NS4 only)
function getObjNN4(_obj, _name)
{
	var x = _obj.layers,
	foundLayer,
	i = 0
	len = x.length,
	tmp;

	for(; i < len; i++) {
		if(x[i].id == _name) {
			foundLayer = x[i];
		}
		else if(x[i].layers.length) {
			tmp = get_objNN4(x[i], _name);
		}
		if(tmp) {
			foundLayer = tmp;
		}
	}

	return foundLayer;
}



// get the style object for the different types of browsers
function getStyleObject(_elem)
{
	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(typeof _elem !== 'object' || _elem === null) return null;

	return _elem.style;
}



// get a css rule
function getCSSRule(_href, _selectorText)
{
	var i = 0,
	len = document.styleSheets.length,
	sheets, txt, rules, j, len2;

	_selectorText = _selectorText.toLowerCase();

	for(; i < len; i++) {
		sheets = document.styleSheets[i];
		if(sheets.href === null && _href !== document.cgiURL) continue;                     /* Safari/Firefox3 has no internal style url */
		else if(
			((sheets.href === null || !sheets.href.length) && _href === document.cgiURL) || /* Safari/IE has no internal style url */
			sheets.href.indexOf(_href) > -1                                                 /* Firefox2 internal syle has href == cgi URL */
		) {
			rules = sheets.cssRules ? sheets.cssRules : sheets.rules;

			for(j = 0, len2 = rules.length; j < len2; j++) {
				txt = rules[j].selectorText.toLowerCase();
				if(txt.indexOf(_selectorText) > -1) {
					return rules[j];
				}
			}
		}
	}

	return null;
}



/* Get CSS rules in one 'sitting'
 * getCSSRule is expensive, since it searches the CSS documents for the requested selectorText,
 * whiel getCSSRules will get all selectors, and will be the responsibility of the caller to
 * capture the rules of intrest
 *
 *   _cache   - CSS cache to store the rules
 *   _href    - CSS HREF list
 *   _cb      - Selector collection callback, signature:
 *                 function(_cache, _selectorText, _rule)
 */
function getCSSRules(_cache, _href, _cb)
{
	var i = 0,
	len = _href.length,
	s_len = document.styleSheets.length,
	h, s, sheets, rules, r, r_len;

	for(; i < len; i++) {

		h = _href[i];

		for(s = 0; s < s_len; s++) {
			sheets = document.styleSheets[s];
			if(sheets.href === null && h !== document.cgiURL) {
				continue;
			}
			else if(
				((sheets.href === null || !sheets.href.length) && h === document.cgiURL) ||
				sheets.href.indexOf(h) > -1
			) {
				rules = sheets.cssRules ? sheets.cssRules : sheets.rules;

				for(r = 0, r_len = rules.length; r < r_len; r++) {
					_cb(_cache, rules[r].selectorText, rules[r]);
				}
			}
		}
	}
}



// change style class of an element
function changeClass(_elem, _class)
{
	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(typeof _elem !== 'object' || _elem === null) return;

	if(browser.op5 || browser.op6) _elem.style.className = _class;
	else _elem.className = _class;
}



// add a className to an element if it's not already present
function addClass(_elem, _class)
{
	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(typeof _elem !== 'object' || _elem === null) return;

	var c;

	if(browser.op5 || browser.op6) {
		if((c = _elem.style.className).indexOf(_class) == -1) {
			_elem.style.className = [c, ' ', _class].join('');
		}
	}
	else {
		if((c = _elem.className).indexOf(_class) == -1) {
			_elem.className = [c, ' ', _class].join('');
		}
	}
}



/* Determines whether or not an element has the passed class
 *   _elem The DOM element (STRING|OBJ) to check against
 *   _class The CSS class name we want to lookup in the element
 * Returns a boolean.
 *   True if _elem has the class _class
 *   False otherwise
 * Is compatible with commonest browsers.
 */
function hasClass(_elem, _class)
{
	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(typeof _elem !== 'object' || _elem === null) return;

	var re = new RegExp(['\\b', _class, '\\b'].join('')),
	result = false,
	c;

	if(browser.op5 || browser.op6) {
		if((c = _elem.style.className).indexOf(_class) != -1) {
			result = re.test(c);
		}
	}
	else {
		if((c = _elem.className).indexOf(_class) != -1) {
			result = re.test(c);
		}
	}

	return result;
}



// remove a class from an element
function removeClass(_elem, _class)
{
	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(typeof _elem !== 'object' || _elem === null) return;

	var re = new RegExp(['\\b', _class, '\\b'].join('')),
	c;

	if(browser.op5 || browser.op6) {
		if((c = _elem.style.className).indexOf(_class) != -1) {
			_elem.style.className =  c.replace(re, "");
		}
	}
	else {
		if((c = _elem.className).indexOf(_class) != -1) {
			_elem.className = c.replace(re, "");
		}
	}

}



// hide or show a page element
function changeObjectDisplay(_objectId, _newDisplay)
{
	var styleObject = getStyleObject(_objectId, document);

	if(styleObject !== null) {
		styleObject.display = _newDisplay;
		return true;
	}

	return false;
}



// find out if an element is currently displayed
function isDisplayed(_elem)
{
	if(typeof _elem === 'string') _elem = getObject(_elem);
	if(typeof _elem !== 'object' || _elem === null) return false;

	return _elem.clientWidth > 0;
}



// hide or show a page element
function changeObjectVisibility(_objectId, _newVisibility)
{
	var styleObject = getStyleObject(_objectId, document);

	if(styleObject !== null) {
		styleObject.visibility = _newVisibility;
		return true;
	}

	return false;
}



// move an element to a new set of X + Y co-ordinates
function moveXY(_obj, _x, _y)
{
	var obj = getStyleObject(_obj);
	if(obj === null) {
		return;
	}

	_x = parseInt(_x);
	_y = parseInt(_y);

	if(browser.ns4) {
		obj.top = _y;
		obj.left = _x;
	}
	else if(browser.op5) {
		obj.pixelTop = _y;
		obj.pixelLeft = _x;
	}
	else {
		obj.top = [_y, 'px'].join('');
		obj.left = [_x, 'px'].join('');
	}
}



// resize an element to a new width & height
function resizeXY(_obj, _x, _y)
{
	var obj = getStyleObject(_obj);
	if(obj === null) {
		return;
	}

	_x = parseInt(_x);
	_y = parseInt(_y);

	if(browser.ns4) {
		obj.height = _y;
		obj.width = _x;
	}
	else if(browser.op5) {
		// TODO! I don't know what to put here
	}
	else {
		obj.height = [_y, 'px'].join('');
		obj.width = [_x, 'px'].join('')
	}
}



// Add a form variable
function insertInputObj(_form, _type, _id, _name, _value)
{
	var doc = _form.ownerDocument;

	if(browser.ie && !browser.ie9){
		// there is a bug in older IE versions in assigning name to objects created by
		// createElement function, however, IE9 does not support angle brackets in createElement
		inputObj = doc.createElement(['<input name=\"', _name, '\">'].join(''));
	}
	else {
		inputObj = doc.createElement('input');
		inputObj.name = _name;
	}

	inputObj.type  = _type;
	inputObj.id    = _id;
	inputObj.value = _value;

	_form.appendChild(inputObj);

	return inputObj;
}



// insert some HTML on the end of an element
function insertHtml(_element, _html)
{
	if(browser.ie || browser.op8) {
		_element.insertAdjacentHTML("beforeEnd", _html);
	}
	else {
		var r = document.createRange(),
		parseNode;

		r.setStartBefore(_element);
		parsedNode = r.createContextualFragment(_html);
		_element.appendChild(parsedNode);
	}
}



// Recursively get all the text of a tag.
// i.e., running it on <span>Click <a href="#">here</a> to continue</span>
// returns Click here to continue
//
// It is best to trim the final result for leading and trailing whitespace
// NodeTypes: 3 is a text node, 1 is a normal element node
function getNodeText(_node)
{
	if(typeof _node !== 'object' && !(_node = getObject(_node))) return '';

	var result = new Array(),
	children = _node.childNodes,
	i = 0,
	len = children.length,
	nodeType;

	for(; i < len; i++) {

		nodeType = children[i].nodeType;
		if(nodeType === 3) {
			result[result.length] = children[i].nodeValue;
		} else if(nodeType === 1) {
			result[result.length] = getNodeText(children[i]);
		}
	}

	return result.join('');
}



// get all the nodes with an id and add to a hash
function getNodeIds(_node, _o)
{
	if(typeof _o === 'undefined') _o = new Object();
	if(typeof _node === 'undefined' || !_node) return _o;

	var i = 0,
	children = _node.childNodes,
	len = children.length,
	node;

	if(typeof _node.id !== 'undefined' && _node.id.length) _o[_node.id] = _node;

	for(; i < len; i++) {
		node = children[i];
		if(node.childNodes.length) getNodeIds(node, _o);

		if(typeof node.id !== 'undefined' && node.id.length) _o[node.id] = node;
	}

	return _o;
}



// add/set text to a node
function addText(_node, _text, _add_nbsp)
{
	var t = typeof _text === 'string' ? _text : _text.join("");

	// empty string, then add non-breaking space (hex)
	// - IE does not render any styles if empty cell
	if(browser.ie && !t.length && (typeof _add_nbsp === 'undefined' || _add_nbsp)) t = '\u00a0';

	if(_node.childNodes.length) _node.firstChild.data = t;
	else _node.appendChild(document.createTextNode(t));
}



// a general function to delete all children of a tag
function removeAllChildren(parent)
{
	var children = parent.childNodes,
	i = 0,
	length = children.length,
	child;

	for(; i < length; i++) {

		// always remove the first child
		child = children[0];
		child.removeNode(true);
	}
}



/**********************************************************************
 * Events
 *********************************************************************/

/* Get event pageX/clientX and pageY/clientY
 *
 *   _e       - event; default window.event
 *   _returns - object [associated array]
 *              x  - pageX/clientX
 *              y  - pageY/clientY
 */
function getEventXY(_e)
{
	_e = typeof _e === 'undefined' ? window.event : _e;

	return {
		x: browser.ie8 ? _e.getAttribute('clientX') : (_e.pageX ? _e.pageX : _e.clientX),
		y: browser.ie8 ? _e.getAttribute('clientY') : (_e.pageY ? _e.pageY : _e.clientY)
	};
}


/* Get event pageY/clientY
 *
 *   _e       - event; default window.event
 *   _returns - pageY/clientY
 */
function getEventY(_e)
{
	_e = typeof _e === 'undefined' ? window.event : _e;

	return browser.ie8 ? _e.getAttribute('clientY') : (_e.pageY ? _e.pageY : _e.clientY);
}



/* Get event pageX/clientX
 *
 *   _e       - event; default window.event
 *   _returns - pageX/clientX
 */
function getEventX(_e)
{
	_e = typeof _e === 'undefined' ? window.event : _e;

	return browser.ie8 ? _e.getAttribute('clientX') : (_e.pageX ? _e.pageX : _e.clientX);
}



/**********************************************************************
 * Misc
 *********************************************************************/

// set a anchor target to 'officePane' frame if present, else sets to '_top'
function officePaneTarget(_anchorId)
{
	var anchor = getObject(_anchorId);
	if(anchor) {
		anchor.target = parent.parent && parent.parent.officePane
			? 'officePane' : '_top';
	}
}



// setup inheritance between a superclass and a subclass
function setupInheritance(_super, _sub)
{
	_sub.prototype = new _super();
	_sub.prototype.conscructor = _sub;
	_sub.superclass = _super.prototype;
}



// parse int
function toInt(_str, _pm)
{
	if(ckInteger(_str, _pm, 0, 0)) {
		var i = 0,
		len = _str.length;

		while(i < len && _str.substring(i, 1) === '0') i++;
		return parseInt(_str.substring(i, len));
	}

	return _str;
}



// string format
// usage: Stirng.format('text {0} {1} {2}', arg1, arg2, arg3,....)
if(!String.format) {
	String.format = function( text )
	{
		if(arguments.length <= 1) return text;

		// decrement to move to the second argument in the array
		var tokenCount = arguments.length - 2,
		token = 0;

		for(; token <= tokenCount; token++) {
			text = text.replace(new RegExp( ["\\{", token, "\\}"].join(''), "gi" ),
								arguments[token + 1]);
		}

		return text;
	};
}



/* Build an associated array.
 * Sets default options within the array
 *
 *   _def    - default options
 *   _opt    - assocuiated array; default none
 *   returns - _opt or _def if _opt is not defined
 */
function associatedArray(_def, _opt)
{
	if(typeof _opt == 'undefined') return _def;

	for(var i in _def) if(typeof _opt[i] === 'undefined') _opt[i] = _def[i];
	return _opt;
}



/**********************************************************************
 * HTML Utilities
 **********************************************************************/

/* Add a HTML node to a html array, e.g. <node....
 *
 *   _html - html array
 *   _node - node name
 *   _attr - attributes (associated array)
 *   _opt  - optional arguments (associated array)
 *           data  - node data/text
 *                   will automatically add an 'end' node
 *           end   - add an end, e.g. "/>"
 */
function htmlwBegin(_html, _node, _attr, _opt)
{
	_html[_html.length] = '<';
	_html[_html.length] = _node;

	for(var a in _attr) {
		if(_attr[a] === null || !_attr[a].length) continue;
		_html[_html.length] = [' ', a, '=\"', _attr[a], '\"'].join('');
	}

	if(typeof _opt === 'object') {
		if(typeof _opt.data === 'string') {
			_html[_html.length] = '>';
			if(_opt.data.length) _html[_html.length] = _opt.data;
			htmlwEnd(_html, _node);
		}
		else if(typeof _opt.endNode === 'boolean' && _opt.endNode) {
			_html[_html.length] = '>';
			htmlwEnd(_html, _node);
		}
		else if(typeof _opt.end === 'boolean' && _opt.end) {
			_html[_html.length] = '/>';
		}
	}
	else {
		_html[_html.length] = '>';
	}
}



/* Add a HTML node end to a html array, e.g. </node>
 *
 *   _html  - html array
 *   _node  - node name
 */
function htmlwEnd(_html, _node)
{
	_html[_html.length] = '</';
	_html[_html.length] = _node;
	_html[_html.length] = '>';
}
