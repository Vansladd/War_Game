/*
 * $Id: xml.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2007 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * XML Javascript Utilities
 */

if(window.cvsID) {
	cvsID('xml', '$Id: xml.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

document.xmlUri = null;

if(document.Package) {
	document.Package.provide('office', 'xml');
	document.Package.require('office', 'base');
}



// set the xml namespace we are currently interested in
function setXMLUri(_uri)
{
	document.xmlUri = _uri;
}



// Cross browser function to return elements from xml by tag name when
// using namespaces
function getXMLElementsByTagName(_xml, _tag, _uri)
{
	// in ie you use the full name including namespace
	if (browser.ie && !browser.op) {
		return _xml.getElementsByTagName(_tag);

	// other browsers you must strip off and use getElementsByTagNameNS
	} else {

		//strip off the namespace
		 _tag = _tag.substr(_tag.indexOf(':') + 1, _tag.length);

		// use the global ns uri
		if (typeof _uri == 'undefined') {
			_uri = document.xmlUri;
		}

		return _xml.getElementsByTagNameNS(_uri, _tag);
	}
}