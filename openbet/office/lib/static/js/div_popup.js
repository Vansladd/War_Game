/*
 * $Id: div_popup.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Div Popup management
 */

if(window.cvsID) {
	cvsID('div_popup', '$Id: div_popup.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

window.curDivPopup         = null;
window.focusedDivPopup     = null;
window.prevFocusedDivPopup = [];

if(document.Package) {
	document.Package.provide('office', 'div_popup');

	document.Package.require('office', 'base');
	document.Package.require('office', 'dimension');
	document.Package.require('office', 'xmlhttp');
}


/**********************************************************************
 * Div Popup Class (draggable)
 *********************************************************************/

function DivPopup(_id, _titleId, _minX, _minY, _maxX, _maxY, _closeButton, _titleSpan)
{
	if(arguments.length > 0) {
		this.init(_id, _titleId, _minX, _minY, _maxX, _maxY, _closeButton, _titleSpan);
	}
}



// an init method
DivPopup.prototype.init = function(
	_id,
	_titleId,
	_minX,
	_minY,
	_maxX,
	_maxY,
	_closeButton,
	_titleSpan
) {
	// popup identifiers
	this.id      = getObject(_id);
	this.titleId = getObject(_titleId);

	// does the popup have a modal parent (legacy)
	this.modalParent   = this.id.parentNode.className.indexOf('modalPopup') != -1
		? this.id.parentNode : null;

	// are we using a global modal container; recommended
	// -modalPopup class is not suppoted in IE since the transparent background color
	//  is not fully supported
	// -reduces browser resources since we only have 1 div
	// -disable the container by setting obj.noModalParent = true
	this.noModalParent = false;
	if(!this.modalParent && typeof document.modalPopupContainer === 'undefined') {
		if((document.modalPopupContainer = getObject('modalPopupContainer'))) {
			document.modalPopupContainer.total = 0;
		}
	}


	// popup dimensions (if not displayed, then these will not be set)
	this.dim = new Dimension(_id);

	// reference to this object within title
	if(this.titleId != null) {
		this.titleId.divPopup = this;
	}

	// reference to this object within the div
	if(this.id != null) {
		this.id.divPopup = this;
	}

	// last event X + Y positions
	this.evX = 0;
	this.evY = 0;

	// min X + Y
	this.minX = typeof _minX == 'undefined' || _minX === null ? 0 : _minX;
	this.minY = typeof _minY == 'undefined' || _minY === null ? 0 : _minY;

	// max X + Y
	this.maxX = typeof _maxX == 'undefined' || _maxX === null ? 0 : _maxX;
	this.maxY = typeof _maxY == 'undefined' || _maxY === null ? 0 : _maxY;

	// offset X + Y parents
	this.offsetXParent = true;
	this.offsetYParent = true;

	// track form element focus
	this.focus = null;

	// associated form
	this.form = null;

	// associated table
	this.table = null;

	// set up styles for the titlebar
	this.unFocusedTitleClass = 'popupTitleDisabled';
	this.focusedTitleClass   = 'popupTitle';

	// user supplied event handlers
	if(!this.onDragStart) {
		this.onDragStart = new Function();
	}

	if(!this.onDragEnd) {
		this.onDragEnd = new Function();
	}

	if(!this.onDrag) {
		this.onDrag = new Function();
	}

	this.onFocus = new Function();

	// create a span within the title div that contains the title text
	if((typeof _titleSpan === 'undefined' || _titleSpan) && this.titleId) {
		var _titleText = this.titleId.innerHTML;
		this.titleId.innerHTML = '';
		this.titleSpan = document.createElement('span');
		this.titleSpan.innerHTML = _titleText;
		this.titleId.appendChild(this.titleSpan);
	}
	if(this.titleId) this.enableDragging();

	// add a close button to the titlebar
	if(typeof _closeButton === 'undefined' || _closeButton) {
		var img = document.createElement('img');

		// setup the image
		img.src = document.gifURL + '/div_popup_close.gif';
		img.border = 0;
		img.style.cursor = 'pointer';
		img.style.right = '5px';
		img.style.top = '5px';
		img.style.position = 'absolute';
		img.style.zIndex = 102;

		// by default, close the popup if clicked
		var _this = this;
		img.onclick = function() {_this.close();};

		// add
		this.closeButton = img;
		if(this.titleId) this.titleId.appendChild(img);
	}

	// by default have the div popups modal
	this.modal = true;

	// by default, use lightweight dragging
	this.dragStyle = 'lightWeight';
};



// set the text of the titlebar
DivPopup.prototype.setTitle = function(text)
{
	if(typeof this.titleSpan === 'object') this.titleSpan.innerHTML = text;
};



// disable the close button
DivPopup.prototype.disableCloseButton = function()
{
	if(typeof this.closeButton === 'object') this.closeButton.style.display = 'none';
};



// enable the close button
DivPopup.prototype.enableCloseButton = function()
{
	if(typeof this.closeButton === 'object') this.closeButton.style.display = '';
};



// specify a function to call when close button clicked
DivPopup.prototype.setOnClose = function(func)
{
	if(typeof this.closeButton === 'object') this.closeButton.onclick = func;
};



// open/display the popup-div
DivPopup.prototype.open = function()
{
	curDivPopup = this;

	// modal popup
	if(this.modalParent) {
		this.modalParent.style.display = '';
		this.modalParent.style.zIndex = this.id.style.zIndex;
	}
	// -modal popup but using a global container
	else if(!this.noModalParent && document.modalPopupContainer) {
		var c = document.modalPopupContainer;
		if(!c.total) {

			resizeModalPopupContainer();

			// on window resize, reset the container width
			if(window.addEventListener) {
				window.addEventListener('resize', resizeModalPopupContainer, false);
			}
			else if(window.attachEvent) {
				window.attachEvent('onresize', resizeModalPopupContainer);
			}

			c.style.display = '';
		}
		c.total++;
	}

	if(this.modalParent || this.noModalParent || !document.modalPopupContainer) {
		var f, f_len, j,
			i = 0,
			len = document.forms.length;

		for(; i < len; i++) {
			f = document.forms[i];
			for(j = 0, f_len = f.length; j < f_len; j++) {
				if(typeof f[j].ignore_disabled == 'undefined' || !f[j].ignore_disabled) {

					if(f != this.form) {
						if(typeof f[j].p_disabled == 'undefined') {
							f[j].p_disabled = f[j].disabled ? 2 : 1;
						}
						else {
							f[j].p_disabled++;
						}
						f[j].disabled = true;
					}
					else {
						f[j].disabled = false;
					}
				}
			}
		}
	}

	this.id.style.display = '';
	this.fitToContents();

	// mark this div as the one with the 'focus'
	focusDiv(this);
	return true;
};



// adjust the width of the popup/table
DivPopup.prototype.fitToContents = function(padding)
{
	// adjust the width of the popup/table
	var iWidth = getElementWidth(this.id.id);
	var tWidth = this.table ? getElementWidth(this.table.id) : 0;

	if(padding && padding > 0) {
		tWidth = parseInt(tWidth) + padding;
	}

	if(this.table && iWidth < tWidth) {
		this.id.style.width = String.format('{0}px', tWidth + 4);
	}
	else if(this.table && tWidth < iWidth) {
		this.table.style.width = String.format('{0}px', iWidth - 6);
	}

	this.dim.get();
};



// set the minX/Y and maxX/Y to size of viewable/inner window
// - set window dimensions for dragging
DivPopup.prototype.setMinMaxInnerWindow = function(_doOffset, _minY)
{
	// Default value
	if(typeof doOffset == 'undefined') _doOffset = 0;
	if(typeof _minY == 'undefined') _minY = 1;

	var x = 0,
		y = 0,
		v;

	// Need to offset, if the page has been scrolled
	if(_doOffset) {
		if(window.pageYOffset) {
			x = window.pageXOffset;
			y = window.pageYOffset;
		}
		else if(document.documentElement && document.documentElement.scrollTop) {
			x = document.documentElement.scrollLeft;
			y = document.documentElement.scrollTop;
		}
		else if(document.body) {
			x = document.body.scrollLeft;
			y = document.body.scrollTop;
		}
	}

	this.minX = 1 + x;
	this.minY = _minY + y;
	this.maxX = (v = getWindowInnerWidth() - this.dim.width - 2 + x) <= 1
		? getWindowInnerWidth()
		: v;
	this.maxY = (v = getWindowInnerHeight() - this.dim.height - 2 + y) <= 1
		? getWindowInnerHeight()
		: v;
};



// center the div within the viewable/inner window
DivPopup.prototype.centerInnerWindow = function(doOffset)
{
	// Default value
	if(typeof doOffset === "undefined") {
		doOffset = 0;
	}

	if(this.id === null) {
		return;
	}

	var x = (getWindowInnerWidth() / 2) - (this.dim.width / 2),
	y = (getWindowInnerHeight() / 2) - (this.dim.height / 2);

	if(y < 0) y = 10;
	if(x < 0) x = 10;

	if(doOffset) {
		// Need to offset, if the page has been scrolled
		if (window.pageYOffset) {
			x += window.pageXOffset;
			y += window.pageYOffset;
		}
		else if (document.documentElement && document.documentElement.scrollTop) {
			x += document.documentElement.scrollLeft;
			y += document.documentElement.scrollTop;
		}
		else if (document.body) {
			x += document.body.scrollLeft;
			y += document.body.scrollTop;
		}
	}

	moveXY(this.id.id, x, y);
	this.dim.get();
};



// track focus within the popup-div
DivPopup.prototype.trackFocus = function()
{
	if(this.form == null) {
		return;
	}
	var f = this.form;
	for(var i = 0; f && i < f.length; i++) {
		if(f[i].type != 'hidden') {
			f[i].onfocus = divFormFocus;
			f[i].divPopup = this;
		}
	}
};



// close/hide the popup-div
DivPopup.prototype.close = function(e)
{
	// modal popup
	if(this.modalParent != null) {
		this.modalParent.style.display = 'none';
		this.modalParent.style.zIndex = 0;
	}
	// -modal popup but using a global container
	else if(!this.noModalParent && document.modalPopupContainer) {
		var c = document.modalPopupContainer;
		c.total = c.total ? c.total - 1 : 0;
		if(!c.total) {
			c.style.display = 'none';

			if(window.removeEventListener) {
				window.removeEventListener('resize', resizeModalPopupContainer, false);
			}
			else if(window.detachEvent) {
				window.detachEvent('onresize', resizeModalPopupContainer);
			}
		}
	}

	// enable all the other forms that are not part of the div
	if(this.modalParent || this.noModalParent || !document.modalPopupContainer) {
		var f, f_len, j,
			i = 0,
			len = document.forms.length;

		for(; i < len; i++) {
			f = document.forms[i];
			for(j = 0, f_len = f.length; f != this.form && j < f_len; j++) {
				if(typeof f[j].ignore_disabled == 'undefined' || !f[j].ignore_disabled) {
					f[j].disabled = --f[j].p_disabled;
				}
			}
		}
	}

	// release focus
	_unfocusDiv();

	this.id.style.display = 'none';

	return true;
};



// start dragging the popup-div
DivPopup.prototype.dragStart = function(_e)
{
	this.id.evX = _e.clientX;
	this.id.evY = _e.clientY;

	this.onDragStart(this.evX, this.evY);

	document.onmousemove = dragDiv;
	document.onmouseup   = dragStop;

	// if light weight dragging used, drag an empty outline around
	// else drag the actual div around
	if(this.dragStyle == 'lightWeight') {
		DivPopup.setupOutlineDiv(this.id);
		var outlineDiv = DivPopup.getOutlineDiv();
		outlineDiv.evX = _e.clientX;
		outlineDiv.evY = _e.clientY;
	} else {

		// make the popup transparent
		this.id.style.opacity = 0.6;
	}

	// call drag to ensure the evX, evY are consistent
	this.drag(_e);

	return false;
};



// drag the popup-div
DivPopup.prototype.drag = function(_e)
{
	var ey = _e.clientY;
	var ex = _e.clientX;

	var div = (this.dragStyle == 'lightWeight') ?
		DivPopup.getOutlineDiv() :
		this.id;

	if(this.dragStyle == 'lightWeight') {
		var x  = getElementLeft(div.id);
		var y  = getElementTop(div.id);
	} else {
		var x  = getElementLeft(div.id, this.offsetXParent);
		var y  = getElementTop(div.id, this.offsetYParent);
	}
	var nx;
	var ny;

	nx = x + (ex - div.evX);
	ny = y + (ey - div.evY);

	nx = this.minX != null && nx < this.minX ? this.minX
		: this.maxX != null && nx > this.maxX ? this.maxX : nx;
	ny = this.minY != null && ny < this.minY ? this.minY
		: this.maxY != null && ny > this.maxY ? this.maxY : ny;

	moveXY(div.id, nx, ny);

	div.evX = ex;
	div.evY = ey;

	this.dim.get(true);

	this.onDrag(nx, ny);

	return false;
};


// stop dragging the popup-div
DivPopup.prototype.dragStop = function(_e)
{
	if(this.focus) {
		this.focus.focus();
	}

	document.onmousemove = null;
	document.onmouseup   = null;
	this.focus           = null;
	curDivPopup          = this.form ? curDivPopup : null;

	if(this.dragStyle == 'lightWeight') {
		var outlineDiv = DivPopup.getOutlineDiv();
		moveXY(this.id.id, outlineDiv.style.left, outlineDiv.style.top);
		outlineDiv.style.display = 'none';
	} else {
		// popup no longer needs to be transparent
		this.id.style.opacity = 1;
	}

	this.onDragEnd();
};



// don't allow the popup-div to be dragged
DivPopup.prototype.disableDragging = function()
{
	if(this.titleId != null) {
		this.titleId.onmousedown  = '';
		this.titleId.style.cursor = 'default';
	}

	if(typeof this.titleSpan === 'object') {
		this.titleSpan.onmousedown  = '';
		this.titleSpan.style.cursor = 'default';
	}
};



// set up the popup-div so that it can be dragged
DivPopup.prototype.enableDragging = function()
{
	if(this.titleId != null) {
		this.titleId.onmousedown  = dragDivStart;
		this.titleId.style.cursor = 'move';
	}

	if(typeof this.titleSpan === 'object') {
		this.titleSpan.onmousedown  = dragDivStart;
		this.titleSpan.style.cursor = 'move';
	}
};



/**********************************************************************
 * DIV Popup Event Handlers
 *
 *  Each div popup can define two variables for itself,
 *  zIndexFocused and zIndexUnfocused.
 *  This way, some div popups can always be set to always be below
 *  other div popups.
 *
 *********************************************************************/

// give the 'focus' to a new div
function focusDiv(div, _prev)
{
	if(div == null) {
		return;
	}


	// push div onto focused div chain
	if(typeof _prev !== 'boolean' || _prev) {
		prevFocusedDivPopup.push(div);
	}


	// take the focus away from the currently focused div
	_unfocusDiv(false);

	div.titleId.className = div.focusedTitleClass;
	focusedDivPopup = div;
	curDivPopup = div;


	// if this popup has a value defined use it instead
	var zIndex = 101;
	if(focusedDivPopup.zIndexFocused) {
		zIndex = focusedDivPopup.zIndexFocused;
	}
	focusedDivPopup.id.style.zIndex =
		zIndex + (!focusedDivPopup.noModalParent && document.modalPopupContainer ? 2 : 1);

	if(focusedDivPopup.modalParent) {
		focusedDivPopup.modalParent.style.zIndex = zIndex + 1;
	}
	else if(!focusedDivPopup.noModalParent && document.modalPopupContainer) {
		document.modalPopupContainer.style.zIndex = zIndex + 1;
	}
}



// private function to take the 'focus' away from the currently focused div
function _unfocusDiv(_prev)
{
	if(typeof _prev !== 'boolean') _prev = true;


	if(focusedDivPopup != null) {

		// if this popup has a value defined use it instead
		var zIndex = 100;
		if(focusedDivPopup.zIndexUnfocused) {
			zIndex = focusedDivPopup.zIndexUnfocused;
		}

		focusedDivPopup.titleId.className = focusedDivPopup.unFocusedTitleClass;
		focusedDivPopup.id.style.zIndex = zIndex;

		if(focusedDivPopup.modalParent) {
			focusedDivPopup.modalParent.style.zIndex = zIndex;
		}
		else if(document.modalPopupContainer) {
			document.modalPopupContainer.style.zIndex = 99;
		}
	}


	// foucs on previously opened popup
	if(_prev) {
		prevFocusedDivPopup.pop();

		var len = prevFocusedDivPopup.length;

		if(len) focusDiv(prevFocusedDivPopup[len - 1], false);
		else curDivPopup = null;
	}
	else {
		curDivPopup = null;
	}
}



// start dragging a popup-div
function dragDivStart(_e)
{
	var div = null;
	if(typeof _e == 'undefined') {
		_e = window.event;
		if(_e.srcElement.divPopup) {
			div = _e.srcElement.divPopup;
		}
	}
	else if(_e.target.divPopup) {
		div = _e.target.divPopup;
	}

	if(div) {
		if(curDivPopup && curDivPopup.modal &&
			curDivPopup.id.id != div.id.id) {
			div = null;
		}
		else {
			curDivPopup = div;
		}
	}

	focusDiv(div);

	return div ? div.dragStart(_e) : false;
}



// drag a popup-div
function dragDiv(_e)
{
	if(typeof _e == 'undefined') {
		_e = window.event;
	}

	return curDivPopup ? curDivPopup.drag(_e) : false;
}



// stop dragging a popup-div
function dragStop(_e)
{
	if(typeof _e == 'undefined') {
		_e = window.event;
	}

	return curDivPopup ? curDivPopup.dragStop(_e) : false;
}



// track focus within popup-div form
function divFormFocus(_e)
{
	var target = (typeof _e == 'undefined')
		? window.event.srcElement : _e.target;
	if(typeof target.divPopup != 'undefined') target.divPopup.focus = target;
}



/*******************************************************************************
 * Resizable Div Popup
 *   'extends' Div Popup
 ******************************************************************************/

setupInheritance(DivPopup, ResizableDivPopup);

function ResizableDivPopup(_id, _titleId, _minX, _minY, _maxX, _maxY)
{
	if(arguments.length > 0) {
		this.init(_id, _titleId, _minX, _minY, _maxX, _maxY);
	}
}



// set up this DivPopup as resizable
ResizableDivPopup.prototype.init = function(_id, _titleId, _minX, _minY, _maxX, _maxY)
{
	// call the super class's init
	ResizableDivPopup.superclass.init.call(
		this, _id, _titleId, _minX, _minY, _maxX, _maxY
	);

	if(!this.onResizeStart) {
		this.onResizeStart = new Function();
	}

	if(!this.onResizeEnd) {
		this.onResizeEnd = new Function();
	}

	if(!this.onResize) {
		this.onResize = new Function();
	}

	// create a small div for the resize handle (in the bottom right corner)
	this.resizeDivObj = document.createElement('div');
	this.resizeDivObj.id = _id + '_resize';

	this.resizeDivObj.style.position = 'absolute';
	this.resizeDivObj.style.bottom   = '0px';
	this.resizeDivObj.style.right    = '0px';
	this.resizeDivObj.style.zIndex   = 999;
	this.resizeDivObj.onmousedown    = resizeDivStart;
	this.resizeDivObj.divPopup       = this;
	this.resizeDivObj.className      = 'resize';
	this.resizeDivObj.style.cursor   = 'se-resize';
	this.id.appendChild(this.resizeDivObj);
	this.resizeStyle = 'lightWeight';

	// start resizing the popup-div
	this.resizeStart = function(_e) {

		this.id.evX = _e.clientX;
		this.id.evY = _e.clientY;

		this.onResizeStart(this.id.evX, this.id.evY);

		document.onmousemove = resizeDiv;
		document.onmouseup   = resizeStop;

		// if light weight resizing used, resize an empty outline, else drag
		// the actual div around
		if(this.resizeStyle == 'lightWeight') {
			DivPopup.setupOutlineDiv(this.id);
			var outlineDiv = DivPopup.getOutlineDiv();
			outlineDiv.evX = _e.clientX;
			outlineDiv.evY = _e.clientY;
		}

		// call resize to ensure that the evX, evY are consistent
		this.resize(_e);

		return false;
	};


	// resize the popup-div
	this.resize = function(_e) {

		var ey = _e.clientY;
		var ex = _e.clientX;

		var div = (this.resizeStyle == 'lightWeight') ?
			DivPopup.getOutlineDiv() :
			this.id;

		if(this.resizeStyle == 'lightWeight') {
			var x  = getElementLeft(div.id);
			var y  = getElementTop(div.id);
	 	} else {
			var x  = getElementLeft(div.id, this.offsetXParent);
			var y  = getElementTop(div.id, this.offsetYParent);
		}

		resizeXY(div.id, ex-x, ey-y);

		div.evX = ex-x;
		div.evY = ey-y;

		this.dim.get(true);

		this.onResize(ex-x, ey-y);

		return false;
	};


	// stop resizing the popup-div
	this.resizeStop = function(_e) {

		if(this.focus) {
			this.focus.focus();
		}

		document.onmousemove = null;
		document.onmouseup   = null;
		this.focus           = null;
		curDivPopup          = this.form ? curDivPopup : null;

		if(this.resizeStyle == 'lightWeight') {
			var outlineDiv = DivPopup.getOutlineDiv();
			resizeXY(this.id.id, outlineDiv.style.width, outlineDiv.style.height);
			outlineDiv.style.display = 'none';
		}

		var div = (this.resizeStyle == 'lightWeight') ?
			DivPopup.getOutlineDiv() :
			this.id;
		this.onResizeEnd(div.evX, div.evY);
	};
};



/*******************************************************************************
 * Resizable Div Popup Event Handlers
 ******************************************************************************/

// start resizing a popup-div
function resizeDivStart(_e)
{
	var div = null;
	if(typeof _e == 'undefined') {
		_e = window.event;
		if(_e.srcElement.divPopup) {
			div = _e.srcElement.divPopup;
		}
	} else if(_e.target.divPopup) {
		div = _e.target.divPopup;
	}

	if(div) {
		if(curDivPopup && curDivPopup.id.id != div.id.id) {
			div = null;
		} else {
			curDivPopup = div;
		}
	}
	return div ? div.resizeStart(_e) : false;
}



// resize a popup-div
function resizeDiv(_e)
{
	if(typeof _e == 'undefined') {
		_e = window.event;
	}

	return curDivPopup ? curDivPopup.resize(_e) : false;
}



// stop resizing the popup div
function resizeStop(_e)
{
	if(typeof _e == 'undefined') {
		_e = window.event;
	}

	return curDivPopup ? curDivPopup.resizeStop(_e) : false;
}



/*******************************************************************************
 * Alert Div Popup Class (draggable)
 * - extends DivPopup
 ******************************************************************************/

setupInheritance(DivPopup, AlertDivPopup);

function AlertDivPopup(_id, _titleId, _form, _table)
{
	if(arguments.length > 0) {
		this.init(_id, _titleId, _form, _table);
	}
}



// init alert
AlertDivPopup.prototype.init = function(_id, _titleId, _form, _table)
{
	// call the super class's init
	AlertDivPopup.superclass.init.call(this, _id, _titleId);

	this.form  = document.forms[_form];
	this.table = getObject(_table);
	this.trackFocus();

	// increase the z-order
	this.id.style.zIndex = 103;
	this.zIndexFocused = 103;

	// current popup
	this.curDivPopup = null;
};



// open the alert
AlertDivPopup.prototype.open = function(_title, _msg, _callback)
{
	// set the close callback if provided
	if (typeof(_callback) != "undefined") {
		this.callback = _callback;

	// otherwise remove so don't use an old callback
	} else {
		this.callback = null;
	}

	// disable the the currently open popup
	if(curDivPopup && curDivPopup.titleId) {
		curDivPopup.titleId.onmousedown = null;
		changeClass(curDivPopup.titleId.id, 'popupTitleDisabled');
	}

	this.curDivPopup = curDivPopup;
	curDivPopup      = null;

	// on clicking ok, close the popup
	this.form.alert = this;
	this.form.onsubmit = function() {
		this.button = 'submit';
		this.alert.close();
		return false;
	};

	// set the alert text
	this.setText(_title, _msg);

	// open the alert
	AlertDivPopup.superclass.open.call(this);
	this.setMinMaxInnerWindow();

	// position the alert
	if(!this.curDivPopup) {
		this.centerInnerWindow();
	}
	else {
		var y = this.curDivPopup.dim.top + (this.dim.height / 2);
		var x = (this.curDivPopup.dim.left / 2) + this.dim.width;

		moveXY(this.id.id, x, y);
		this.dim.get();
	}
};



// close the alert
AlertDivPopup.prototype.close = function()
{
	AlertDivPopup.superclass.close.call(this);
	curDivPopup = this.curDivPopup;

	if(curDivPopup && curDivPopup.titleId) {
		curDivPopup.titleId.onmousedown = dragDivStart;
		changeClass(curDivPopup.titleId.id, 'popupTitle');
	}

	// call the callback if we have one
	if(this.callback) {
		this.callback();
	}
};



// set alert text
AlertDivPopup.prototype.setText = function(_title, _msg)
{
	this.titleId.innerHTML = _title;
	getObject('alertMsg').innerHTML = _msg.replace(/\n/gi, '<br \\>');
};




/*******************************************************************************
 * Question Div Popup Class (draggable)
 * - extends AlertDivPopup
 ******************************************************************************/

setupInheritance(AlertDivPopup, QuestionDivPopup);

function QuestionDivPopup()
{
	this.init();
}



// init question alert
QuestionDivPopup.prototype.init = function()
{
	// call the super class's init
	QuestionDivPopup.superclass.init.call(
		this, 'questionDiv', 'questionTitle', 'questionForm', 'questionTable');
};



// open the alert
QuestionDivPopup.prototype.open = function(_callback, _title, _msg)
{
	// action on the yes button
	this.form.yes.onclick = function() {
		this.form.button = 'onclick';
		this.form.alert.close();
	};

	// open the alert
	QuestionDivPopup.superclass.open.call(this, _title, _msg, _callback);
};



// close the alert
QuestionDivPopup.prototype.close = function()
{
	var cb = this.callback;
	this.callback = null;

	// close the alert
	QuestionDivPopup.superclass.close.call(this);

	// call the callback
	this.callback = cb;
	if(this.callback) {
		this.callback(this.form.button == 'submit' ? 'no' : 'yes');
	}
};


// set alert text
QuestionDivPopup.prototype.setText = function(_title, _msg)
{
	this.titleId.innerHTML = _title;
	getObject('questionMsg').innerHTML = _msg;
};



/**********************************************************************
 * Lightweight dragging
 *********************************************************************/

var _outlineDiv;

// get the outline div (creating it if necc)
DivPopup.getOutlineDiv = function()
{
	if(!_outlineDiv) {
		_outlineDiv = document.createElement('div');
		_outlineDiv.id = '_outlineDiv';
		_outlineDiv.style.position = 'absolute';
		_outlineDiv.style.border = '1px solid black';
		_outlineDiv.style.background = 'transparent';
		document.body.appendChild(_outlineDiv);
	}

	return _outlineDiv;
};



// set up the outline div to be the same size as the div to drag
DivPopup.setupOutlineDiv = function(divToDrag)
{
	var div = DivPopup.getOutlineDiv();
	div.style.top     = String.format('{0}px', getElementTop(divToDrag.id));
	div.style.left    = String.format('{0}px', getElementLeft(divToDrag.id));
	div.style.width   = String.format('{0}px', getElementWidth(divToDrag.id));
	div.style.height  = String.format('{0}px', getElementHeight(divToDrag.id));
	div.innerHTML     = '&nbsp';
	div.style.zIndex  = 999;
	div.style.display = '';
};



/**********************************************************************
 * Utils
 *********************************************************************/

// Div Popup Dynamic Loading
function DivPopupLoad(_id, _name, _action)
{
	// already loaded?
	if(!getObject(_id)) {

		var http = getXMLHttpRequest();
		if(!http) {
			return -1;
		}

		// if no action supplied, then use the office package
		if(typeof _action == 'undefined' || _action.length == 0) {
			_action = ['?action=ob_office::GoPopup&popup=', _name].join('');
		}

		var url = [document.cgiURL, _action].join('');

		// blocking!
		http.open("GET", url, false);
		http.send(null);
		if(http.status != 200) {
			return http.status;
		}

		var body = document.getElementsByTagName('body');
		if(!body || !body.length) {
			return -2;
		}
		insertHtml(body[0], http.responseText);
	}

	return 200;
}



// select a popup tab division (DivPopup Tab list)
function popupTab(_span, _tab, _popup)
{
	if(_span.className == 'selected') {
		return;
	}

	// get all the popup divs
	var divs = getObject(_popup).getElementsByTagName('div');

	// find the tab list
	var tabDiv = null, i;
	for(i = 0; i < divs.length; i++) {
		if(divs[i].className == 'popupTabList') {
			tabDiv = divs[i];
			break;
		}
	}
	if(!tabDiv) {
		return;
	}

	// un-select current tab
	var spans = tabDiv.getElementsByTagName('span');
	for(i = 0; i < spans.length; i++) {
		if(spans[i].className == 'selected') {
			spans[i].className = '';
			break;
		}
	}

	// select tab-list
	_span.className = 'selected';

	// display current tab division (hide all others)
	for(i = 0; i < divs.length; i++) {
		if(divs[i].className == 'popupTab') {
			divs[i].style.display = divs[i].id == _tab ? '' : 'none';
		}
	}
}



// adjust the Modal Popup Container width + height
// -componsate for scrollbars
function resizeModalPopupContainer()
{
	var c = document.modalPopupContainer;

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
}
