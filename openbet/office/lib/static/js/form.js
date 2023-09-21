/*
 * $Id: form.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Form utilities
 */

if(window.cvsID) {
	cvsID('form', '$Id: form.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}


var redirect = null;


if(document.Package) {
	document.Package.provide('office', 'form');

	document.Package.require('office', 'base');
	document.Package.require('office', 'alert');
	document.Package.require('office', 'date');
}


/**********************************************************************
 * Form Error Class
 *********************************************************************/

// form-validation error list
function Error()
{
	this.errorList = [];
	this.errorNode = [];


	// any errors
	this.isErr = function()
	{
		return this.errorList.length;
	};


	// reset the error-list
	this.reset = function()
	{
		var i = 0, len = this.errorNode.length;
		for(; i < len; i++) {
			removeClass(this.errorNode[i], 'error');
		}
		this.errorList = [];
		this.errorNode = [];
	};


	// add an error
	this.add = function(_str)
	{
		this.errorList[this.errorList.length] = _str;
	};

	this.addNode = function(_node)
	{
		addClass(_node, 'error');
		this.errorNode[this.errorNode.length] = _node;
	};

	// display the error list within an alert
	this.alert = function()
	{
		if(this.errorList.length) alert(this.errorList.join('\n'));
	};


	// display the error list within a Div Popup Alert
	this.divAlert = function(_title, _callback)
	{
		if(this.errorList.length) {
			PopupAlert(_title, this.errorList.join('\n'), _callback);
		}
	};


	this.divAlert2 = function(_title, _opt)
	{
		if(this.errorList.length) {
			Alert2.popup(_title, this.errorList.join('<br\>'), _opt);
		}
	};
}
var err = new Error();



/**********************************************************************
 * Utilities
 *********************************************************************/

// trim a string
function strTrim(_src, _delim)
{
	var r = [],
	b = [],
	i = 0,
	len = _src.length,
	c;

	if(typeof _delim === 'undefined' || _delim === null || !_delim.length) _delim = ' ';

	for(; i < len; i++) {
		c = _src.charAt(i);
		if(_delim.indexOf(c) >= 0) {
			b[b.length] = c;
		} else {
			if(r.length > 0) r[r.length] = b.join('');
			b = [];
			r[r.length] = c;
		}
	}

	return r.join('');
}



/* The preferred function to trim a string (leading and trailing chars)
 *
 * _src - string to trim
 * _delim - character to trim (expects a single character)
 *
 * returns - trimmed string
 */
function strTrimLT(_src, _delim)
{
	var len = _src.length,
	i, c, last;

	if(typeof _delim === 'undefined' || _delim === null || !_delim.length) _delim = ' ';

	// trim from left
	for(i = 0; i < len; i++) {
		c = _src.charAt(i);
		if(_delim !== c) {
			// substring only if necessary
			if(i !== 0) _src = _src.substring(i);
			break;
		}
	}

	// found at least one instance of non-delimiter character
	if(i < len) {
		// trim from right
		last = _src.length - 1;
		for(i = last; i > -1; i--) {
			c = _src.charAt(i);
			if(_delim !== c) {
				// substring only if necessary
				if(i !== last) _src = _src.substring(0, i + 1);
				break;
			}
		}
	}
	else {
		// string is empty or made of delimiting characters - return empty
		_src = '';
	}

	return _src;
}



// check a mandatory string
function ckMandatory(_str, _minLen, _maxLen, _valChars)
{
	if(
		_str.length <= 0 ||
		(_minLen !== 0 && _str.length < _minLen) ||
		(_maxLen !== 0 && _str.length > _maxLen)
	) {
		return false;
	}


	return _valChars ? /^[A-Za-z0-9\_\-]*$/.test(_str) : true;
}



// check an integer
function ckInteger(_str, _pm, _minLen, _maxLen)
{
	var exp = _pm ? /^[+-]?\d*$/ : /^\d*$/;
	if(!exp.test(_str)) return false;

	if((_minLen !== 0 && _str.length < _minLen) || (_maxLen !== 0 && _str.length > _maxLen)) {
		return false;
	}

	return true;
}



// check a float value
function ckFloat(_str, _pm, _minLen, _maxLen)
{
	if(_str === '') return false;

	var exp = _pm ? /^(([+-]?[1-9]\d*|[+-]?0)(\.\d{0,2})?|\.\d{1,2})$/
	              : /^(([1-9]\d*|0)(\.\d{0,2})?|\.\d{1,2})$/;
	if(!exp.test(_str)) return false;

	if((_minLen !== 0 && _str.length < _minLen) || (_maxLen !== 0 && _str.length > _maxLen)) {
		return false;
	}

	return true;
}



// check a decimal price value (max 3dp)
function ckDecPrice(_str)
{
	if(_str === '') return false;
	if(!/^(([1-9][\d,]*|0)(\.\d{0,3})?|\.\d{1,3})$/.test(_str)) return false;

	if(parseFloat(_str) <= 1) return false;

	return true;
}



// check a fraction price value
function ckFracPrice(_str)
{
	if(_str === '') return false;

	return /^[1-9][0-9]*\/[1-9][0-9]*$/.test(_str);
}



// check a price value
// -price might be fractional or decimal
function ckPrice(_str)
{
	return ckDecPrice(_str) || ckFracPrice(_str);
}



// cheap + cheerful url checker
function ckURL(_url)
{
	var exp =
		/^[a-zA-Z]{3,}:\/\/[\-a-zA-Z0-9\.]+\/*[\-a-zA-Z0-9\/\\%_.]*\?*[\-a-zA-Z0-9\/\\%_.=&]*$/;

	/*Fixes formatting bug caused by regexp above*/
	return exp.test(_url);
}



// check informix date
function ckInfDate(_str, _full, _date, _time)
{
	var exp;

	if(typeof _date !== 'undefined' && _date) exp = Date.inf_date_exp;
	else if(typeof _time !== 'undefined' && _time) exp = Date.inf_time_exp;
	else exp = Date.inf_exp;

	return exp.test(_str);
}



// submit a form
function submitOBForm(_name, _action, _button)
{
	var f = document.forms[_name];

	if(_button) {
		_button.value = "Busy...";
		_button.disabled = true;
	}

	var actionObj = getObject([_name, 'Action'].join(''));
	if (actionObj == null) {
		insertInputObj(f, 'hidden', [_name, 'Action'].join(''), 'action', _action);
	} else {
		if (!browser.ie) {
			actionObj.name = 'action';
		}
		actionObj.value = _action;
	}
	if(redirect != null) insertInputObj(f, 'hidden', 'location', 'location', redirect);

	f.submit();

	return true;
}



// reset a form
function resetForm(_name)
{
	var f = document.forms[_name],
	i = 0,
	len = f.length;

	for(; i < len; i++) {
		if(f[i].type === "text") f[i].value = "";
		else if(f[i].type === "checkbox") f[i].checked = 0;
		else if(f[i].type === "select-one") f[i].selectedIndex = 0;
	}
}



// write a select input box
function writeSelect()
{
	var sel = arguments[0],
	i = 1,
	len = arguments.length,
	n, v, sel_tag;

	for(; i < len; i += 2) {
		v = arguments[i];
		n = arguments[i + 1];
		sel_tag = (sel == v) ? " selected" : "";
		document.writeln(['<option value=\"', v, '\"', sel_tag, '>', n, '</option>'].join(''));
	}
}



/* update a set of checkboxes from a string
 *
 *    _f              - the html form element
 *    _checkBoxPrefix - the common prefix that each checkbox name will have
 *    _string         - the string which contains the values
 *    _stringType     - COMMA | CHAR
 *                      how string is separated (comma sep, 1 char per value etc)
 */
function setCheckBoxesFromString(_f, _checkBoxPrefix, _string, _stringType)
{
	var length = _checkBoxPrefix.length,
	inputs = _f.getElementsByTagName('input'),
	i = 0,
	len = inputs.length,
	values = _splitString(_string, _stringType),
	input, checkBox;

	for(; i < len; i++) {
		input = inputs[i];
		if(input.type != 'checkbox' || input.name.substr(0, length) != _checkBoxPrefix) {
			continue;
		}
		input.checked = false;
	}


	// for each value 'tick' the corresponding checkbox
	for(i = 0, len = values.length; i < len; i++) {

		// try to get the checkbox
		checkBox = f[_checkBoxPrefix + values[i]];
		if(checkBox) checkBox.checked = true;
	}
}



/* Get a string from a set of checkboxes
 *
 *    f              - the html form element
 *    _checkBoxPrefix - the common prefix that each checkbox name will have
 *    _stringType     - COMMA | CHAR
 *                     how string is separated (comma sep, 1 char per value etc)
 */
function getStringFromCheckBoxes(f, _checkBoxPrefix, _stringType)
{
	var length = _checkBoxPrefix.length,
	result = new Array(),
	counter = 0,
	inputs = f.getElementsByTagName('input'),
	i = 0,
	len = inputs.length,
	input;

	for(; i < len; i++) {
		input = inputs[i];
		if(input.type !== 'checkbox' || input.name.substr(0, length) != _checkBoxPrefix) {
			continue;
		}
		if(input.checked) {
			result[counter] = input.value;
			counter++;
		}
	}

	return _joinArray(result, _stringType);
}



// split up a string into an array, based on type
function _splitString(_string, _stringType)
{
	var result;

	if(_stringType == 'COMMA') {
		result = _string.split(',');
		return result;
	}
	else if(_stringType == 'CHAR') {
		result = new Array();
		var length = _string.length,
			i = 0;

		for(; i < length; i++) result[i] = _string.charAt(i);
		return result;
	}

	return new Array();
}



// join an array into a string, based on type
function _joinArray(_array, _stringType)
{
	if(_stringType != 'CHAR' && _stringType != 'COMMA') return '';

	// at the moment, all the type does is indicate the delimiter :)
	var result = '',
	i = 0,
	len = _array,length;

	for(; i < len; i++) {
		result += _array[i];
		if(_stringType === 'COMMA' && i < (_array.length-1)) result += ',';
	}

	return result;
}



// pad a string with zeros
function zeroPad(_val, _n)
{
	var s = _val.toString();

	if(s.length < _n) {
		var p = '',
		j = parseInt(_n) - s.length,
		i = 0;

		for(; i < j; i++) p += '0';
	}
	else {
		return s;
	}

	return p + s;
}



// add commas to a number (represented as a string)
function addCommas(_n)
{
	var rgx = /^(([+-]?[1-9][\d,]*|[+-]?0)(\.\d{0,3})?|\.\d{1,3})$/;

	if(!rgx.test(_n)) return _n;

	var x = _n.split('.'),
	x1 = x[0],
	x2 = x.length > 1 ? ['.', x[1]].join('') : '';

	rgx = /(\d+)(\d{3})/;

	while(rgx.test(x1)) {
		x1 = x1.replace(rgx, '$1,$2');
	}

	return [x1, x2].join('');
}



// get the selected option's value from a select box
function getSelectedValue(_sel)
{
	return _sel.type && _sel.type == 'select-one'
		? _sel.options[_sel.selectedIndex].value
		: null;
}
