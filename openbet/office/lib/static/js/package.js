/*
 * $Id: package.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Javascript package manager, allows you to check depedencies between
 * individual scripts and load them automatically.
 */

if(window.cvsID) {
	cvsID('package', '$Id: package.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}


/**********************************************************************
 * Package Name Type Mapping
 *********************************************************************/

function PackageName(_type, _name)
{
	this.type = _type;
	this.name = _name;

	// match a name
	this.match = function(_type, _name) {
		return this.type == _type && this.name == _name;
	};
}



/**********************************************************************
 * Package Type URL Mapping
 *********************************************************************/

function PackageURL(_type, _url)
{
	this.type = _type;
	this.url  = _url;


	// match a url
	this.match = function(_type, _url) {
		return this.type == _type && this.url == _url;
	};
}



/**********************************************************************
 * Package Class
 *********************************************************************/

function Package()
{
	this.pkg     = new Array();
	this.urlMap  = new Array();
	this.version = null;


	// map url with type
	this.mapURL = function(_type, _url, _version) {

		for(var i = 0; i < this.urlMap.length; i++) {
			if(this.urlMap[i].match(_type, _url)) {
				return;
			}
		}

		this.urlMap[this.urlMap.length] = new PackageURL(_type, _url);

		if(typeof _version != 'undefined' && _version.length) this.version = _version;
	};


	// provide a package (set)
	this.provide = function(_type, _pkg) {

		for(var i = 0; i < this.pkg.length; i++) {
			if(this.pkg[i].match(_type, _pkg)) {
				return;
			}
		}

		this.pkg[this.pkg.length] = new PackageName(_type, _pkg);
	};


	// require a package (load/get)
	this.require = function(_type, _pkg) {

		var i = 0,
			len = this.pkg.length;

		for(; i < len; i++) {
			if(this.pkg[i].match(_type, _pkg)) return;
		}

		// find the url for type
		var url = null;
		for(i = 0, len = this.urlMap.length; url == null && i < len; i++) {
			if(this.urlMap[i].type == _type) url = this.urlMap[i].url;
		}
		if(url == null) return;

		// automatically source the files
		var script = document.createElement("script");
		script.language = 'javascript';
		script.type     = 'text/javascript';
		script.src      = url + '/' + _pkg + ".js";
		if(this.version != null && this.version.length) script.src += this.version;

		document.getElementsByTagName("head")[0].appendChild(script);
	};
}
document.Package = new Package();
