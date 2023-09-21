/*
 * $Id: menu.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Menu Handling
 */

if(window.cvsID) {
	cvsID('_menu', '$Id: menu.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'menu');
	document.Package.require('office', 'base');
	document.Package.require('office', 'div_popup');
}



/**********************************************************************
 * Horizontal Menu
 *********************************************************************/

// init
function hmenuInit(_name, _dropdown) {

	var root = getObject(_name);
	if(!root) {
		return;
	}

	// IE does not support css element:hover, except for <a...> elements
	// therefore, use some javascript
	// NB: currentStyle restricts the Javascript to IE only
	if(_dropdown && document.all && root.currentStyle) {

		var lis = root.getElementsByTagName("LI");
		for(var i = 0; i < lis.length; i++) {
			if(lis[i].lastChild.tagName == "UL") {
				lis[i].onmouseover = function() {
					if(root.className != 'disabled') {
						this.lastChild.style.display = "block";
						this.className = 'over';
					}
				}
				lis[i].onmouseout = function() {
				   this.lastChild.style.display = "none";
				   this.className = '';
				}
			} else {
				lis[i].onmouseover = function() {
					if(root.className != 'disabled') {
						this.className = 'over';
					}
				}
				lis[i].onmouseout = function() {
				   this.className = '';
				}
			}
		}
	}

	// if the root node's parent is a div
	if(root && root.parentNode && root.parentNode.nodeName == "DIV") {

		// adjust the width of the div to match the size of the menu
		// - when the browser is resized, the menu will not move!!
		var total = 0, width = 0, w
		for(var i = 0; i < root.childNodes.length; i++) {
			if(root.childNodes[i].nodeName == "LI") {
				total++;
				w = browser.op5 ? root.childNodes[i].pixelWidth
				                : root.childNodes[i].offsetWidth;
				if(w > width) {
					width = w;
				}
			}
		}
		width += total * 12;    // compensate for borders + padding!
		root.parentNode.style.width = (width * total) + 'px';

		// non IE: quick hack to move the menu div over the 1st ul...?
		if(browser.ffox || browser.op) {
			root.parentNode.style.top = '-0.8em';
		}
	}

	hmenuEnable(_name, true);
}



// enable/disable a horizontal menu
function hmenuEnable(_name, _enable) {

	var root = getObject(_name);
	if(root) {
		root.className = _enable ? '' : 'disabled';
	}
}



/**********************************************************************
 * Office Menu
 *********************************************************************/

// init
function officeMenuInit() {

	var total = 0, width = 0, w
	var div = getObject('officeMenu');
	if(!div) {
		return;
	}

	for(var i = 0; i < div.childNodes.length; i++) {
		if(div.childNodes[i].nodeName == "UL") {
			var ul = div.childNodes[i];
			for(var j = 0; j < ul.childNodes.length; j++) {
				if(ul.childNodes[j].nodeName == "LI") {
					total++;
					w = browser.op5 ? ul.childNodes[j].pixelWidth
									: ul.childNodes[j].offsetWidth;
					if(w > width) {
						width = w;
					}
				}
			}
			break;
		}
	}
	width += total * 12;    // compensate for borders!
	div.style.width = (width * total) + 'px';

	// non IE: quick hack to move the menu div over the 1st ul...?
	if(browser.ffox || browser.op) {
		div.style.top = '-0.8em';
	}
}


// selecting a office-menu item
function officeMenuSelect(_anchor) {

	var dc = document.cookie,
	po_loc = parent.officePane.window.location.toString(),
	idx = po_loc.indexOf('/'),
	subString = po_loc.substring(idx);

	if(dc.indexOf('expanded_nodes') > -1 && subString.indexOf('admin') > -1) {
		saveAdminMenuState();
	}

	var li = _anchor.parentNode;
	if(li.id != 'current') {
		var current = document.getElementById('current');

		var tab_prefix = 'state_' + current.firstChild.firstChild.nodeValue;
		if(dc.indexOf(tab_prefix) > -1) {
			try {
				var url = parent.officePane.MainArea.window.location.toString();
			} catch (err) {
				var url = "";
			}
			var frame = parent.officePane.window.location.toString();
			if (frame == url) {
				try {
					url = parent.officePane.MainArea.window.document.referrer.toString();
				}  catch (err) {
					var url = "";
				}
			}
			if (frame != url) {
				document.cookie = tab_prefix + '=' + escape(url);
			}
			else {
				document.cookie = tab_prefix + '=' + escape("");
			}
		}

		if(current) {
			var d = new Date();
			current.id = 'item' + d.getTime();
		}
		li.id = 'current';
	}
}



// contains code for remembering expanded menu items in admin
function saveAdminMenuState() {

	var root = parent.officePane.TopBar.window.document.getElementById('vclickMenu');
	if(root) {
		var expanded_nodes = new Array();
		var span = root.getElementsByTagName('SPAN');
		for(var i = 0; i < span.length; i++) {
			if(span[i].parentNode.tagName == "LI") {
				// find expanded nodes
				var ul = span[i].parentNode.getElementsByTagName('UL');
				if(ul.length && ul[0].style.display == 'block') {
					expanded_nodes.push(i);
				}
			}
		}
		document.cookie = "expanded_nodes=" + escape(expanded_nodes.join(':'));
	}
}



// restores the last location visited in the current tab
function restoreTabLocation() {

	if(typeof parent.parent.officeMenu == 'undefined') {
		return;
	}

	var dc  = document.cookie;
	var tab = parent.parent.officeMenu.window.document.getElementById('current').firstChild.firstChild.nodeValue;
	var tab_prefix = 'state_' + tab;
	var url_start   = dc.indexOf(tab_prefix);
	if(url_start > -1) {
		var url_end = (dc.indexOf(';',url_start) != -1 ? dc.indexOf(';',url_start) : dc.length);
		if(url_end - url_start > tab_prefix.length + 1) {
			var url = unescape(dc.substring(url_start + tab_prefix.length + 1, url_end));
			try {
				parent.MainArea.window.location = url;
			} catch (err) {}
		}
	}
}



/**********************************************************************
 * Vertical Menu with onclick expand/collapse
 *********************************************************************/

function vclickMenuInit(_name) {

	var root = getObject(_name);
	if(!root) {
		return;
	}

// find the last state of the menu on admin screens
	var dc        = document.cookie;
	var en_start  = dc.indexOf('expanded_nodes');
	var loc       = parent.window.location.toString();
	var exp_nodes = (en_start > -1 && loc.indexOf('admin')>-1);
	if(exp_nodes) {
		var en_end = (dc.indexOf(';',en_start) != -1 ? dc.indexOf(';',en_start) : dc.length);
		if(en_end - en_start > 15) {
			var expanded_nodes = unescape(dc.substring(en_start + 15 , en_end)).split(':');
		}
	}

	var span = root.getElementsByTagName('SPAN');
	for(var i = 0; i < span.length; i++) {
		if(span[i].parentNode.tagName == "LI") {

			// IE does not support css element:hover, except for <a...>
			if(browser.ie) {
				span[i].onmouseover = function() {
					this.className = 'over';
				}
				span[i].onmouseout = function() {
					this.className = '';
				}
			}

			// onclick, then expand/collapse
			span[i].onclick = function() {
				var ul = this.parentNode.getElementsByTagName('UL');
				if(ul.length) {
					if(ul[0].style.display != 'block') {
						ul[0].style.display = 'block';
						if(document.tocMinus) {
							this.style.backgroundImage =
							    'url(' + document.tocMinus.src + ')';
						}
					}
					else {
						ul[0].style.display = 'none';
						if(document.tocPlus) {
							this.style.backgroundImage =
							    'url(' + document.tocPlus.src + ')';
						}
					}
				}
			}

			// expand relevant nodes if necessary
			if(exp_nodes && expanded_nodes && i == expanded_nodes[0]) {
				expanded_nodes.shift();
				var ul = span[i].parentNode.getElementsByTagName('UL');
				ul[0].style.display = 'block';
				// add the toc-minus image
				if(document.tocMinus) {
					span[i].style.backgroundImage =
					    'url(' + document.tocMinus.src + ')';
				}
			}
			else {
				// add the toc-plus image
				if(document.tocPlus) {
					span[i].style.backgroundImage =
					    'url(' + document.tocPlus.src + ')';
				}
			}
		}
	}
}



/**********************************************************************
 * Utility
 *********************************************************************/

// hide a menu item
function menuHide(_id, _hide) {

	var root = getObject(_id);
	if(root) {
		root.className = _hide ? 'hide' : '';
	}
}



// disable a menu item
function menuDisable(_id, _disable) {

	var root = getObject(_id);
	if(root) {
		root.className = _disable ? 'disabled' : '';
	}
}
