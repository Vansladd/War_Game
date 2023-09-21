
/**********************************************************************
 * $Id: input_util.js,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
 * Javascript Utilities for checking forms
 * 
 *********************************************************************/

//  Check if _str is an unsigned integer.
//  i.e. O, 23 , 45 etc...

function isValidInteger(_str ) {

        var exp =/^\s*[0-9]+\s*$/;
        if(!exp.test(_str)) {
                return false;
        }

        return true;
}

// Checks for a valid signed integer
// e.g. +3, -22, 56
function isValidSignedInteger(_str ) {

        var exp =/^\s*[+-]?[0-9]+\s*$/;
        if(!exp.test(_str)) {
                return false;
        }

        return true;
}

//  Checks for a monetary value,
//  i.e Assumes a decimal with two decimal places (optional).
// e.g. 3 3000 3.34 0.32
//  but not 3.3 4.556565 .4343 +56 -56.23

function isValidMoney(_str) {
	var exp = /^\s*\d+(\.\d\d)?\s*$/
	if (!exp.test(_str)) {
		return false;
	}
	return true 
}

//  Checks for a signed monetary value,
//  i.e Assumes a decimal with two optional decimal places (optional).
//  Also optionally allows a sign to be specified in front
function isValidSignedMoney(_str) {
	var exp = /^\s*[+-]?\d+(\.\d\d)?\s*$/
	if (!exp.test(_str)) {
		return false;
	}
	return true 
}



// cheap + cheerful url checker
function isValidURL(_url) {
        var exp = /^[a-zA-Z]{3,}:\/\/[\-a-zA-Z0-9\.]+\/*[\-a-zA-Z0-9\/\\%_.]*\?*[\-a-zA-Z0-9\/\\%_.=&]*$/;
        /*Fixes formatting bug caused by regexp above*/
        return exp.test(_url);
}


// check informix date
//  Use where the date can be either date or date time
//  e.g. Valid: 2005-02-02 "2005-03-04 20:33:30"  
function isValidInfDate(_date) {
        var exp = /^\s*\d\d\d\d-\d\d-\d\d( \d\d:\d\d:\d\d)?\s*$/;
        return exp.test(_date);
}

// check informix date
//  Use where a Date time is required
//  e.g. Valid: "2005-03-04 20:33:30"
//  Not valid 2005-02-02
function isValidInfDateTime(_date) {
        var exp = /^\s*\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\s*$/;
        return exp.test(_date);
}

//  Checks to see if a number is a valid Decimal
//  Uses reg exp rather than parseFloat
//  e.g.  Valid: 3 3.4 3.455 4.566767 0.343443
//    Not Valid: .33 4.5.5   3434,434 4.3e45 
function isValidDecimal(_str) {
	var exp = /^\s*[+-]?\d+(\.\d+)?\s*$/	
	return exp.test(_str)
}


//  Checks whether an odds value is valid
//  Checks for +ve and negative odds
//  TODO:
function isValidDecFracOdds(_str) {
	return true;
}

