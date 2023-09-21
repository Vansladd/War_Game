// $Id: list.js,v 1.1.1.1 2011/10/04 10:54:26 xbourgui Exp $
// (C) 2009 Orbis Technology Ltd. All rights reserved.
//
// This object List allows to add and delete elements automatically and to write the list to an chose html element.


// constructor
function List() {
	this.storage    = new Array();
	this.index      = new Array();
	this.length     = 0;
};

List.prototype.add = function (_el) {
	this.storage[_el] = 1;
	this.index.push(_el);
	this.length++;
}

List.prototype.del = function (_el) {
	this.storage[_el] = 0;
	this.length--;
}

List.prototype.exists = function (_el) {
	if (this.storage[_el] == undefined || this.storage[_el] == 0) {
		return 0;
	} else {
		return 1;
	}
}

List.prototype.toggle = function (_el) {
	if (this.exists(_el)) {
		this.del(_el);
	} else {
		this.add(_el);
	}
}

List.prototype.join = function (sep) {

	// default value
	if (sep == "") {
		var sep = ",";	
	}

	var to_string  = "";

	for (var i = 0; i < this.index.length; i++) {
		var idx = this.index[i];
		var rg = new RegExp(idx);
		if (this.exists(idx) && !rg.test(to_string)) {
			to_string += idx + sep;
		}
	}
	// Removing trailing separator
	to_string = to_string.substring(0, to_string.length - 1);
	return to_string;
}

List.prototype.pop = function () {
	var idx = this.index.pop();
	while (!this.exists(idx)) {
		idx = this.index.pop();
	}
	return idx;
}

List.prototype.length = function () {
	return this.length;
}