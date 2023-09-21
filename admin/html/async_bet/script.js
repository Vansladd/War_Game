/*
	$Id: script.js,v 1.1.1.1 2011/10/04 10:54:26 xbourgui Exp $
	Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
*/

##TP_TCL {tpSetVar ADD_SCRIPT_TAG 0}##
##TP_PLAY JS_WriteSelect.html##
##TP_PLAY JS_ValFuncs.html##



/**********************************************************************
 * Utilities
 *********************************************************************/

// sniff out problem browsers
// SniffBrowser() function is defined in  base.js . Please make sure to refernce base.js , if you want to use this file.
var browser = new SniffBrowser();


// form-validation error list
var err = new Error();
function Error() {

	var errorList = "";
	var total = 0


	// any errors
	this.isErr = function() {
		return this.total;
	}


	// reset the error-list
	this.reset = function() {

		this.errorList = "";
		this.total = 0;
	}


	// add an error
	this.add = function(str) {

		if (this.errorList.length > 0) {
			this.errorList += "\n";
		}
		this.errorList += str;
		this.total++;
	}


	// display the error list within an alert
	this.alert = function() {
		alert(this.errorList);
	}
}


// get object for the different types of browsers
function getObject(objectId) {

	if(document.getElementById && document.getElementById(objectId)) {
		return document.getElementById(objectId);
	}
	else if(document.all && document.all(objectId)) {
		return document.all(objectId);
	}
	else if(document.layers && document.layers[objectId]) {
		return getObjNN4(document, objectId);
	}

	return null;
}


// get the style object for the different types of browsers
function getStyleObject(objectId) {

	if(document.getElementById && document.getElementById(objectId)) {
		return document.getElementById(objectId).style;
	}
	else if(document.all && document.all(objectId)) {
		return document.all(objectId).style;
	}
	else if(document.layers && document.layers[objectId]) {
		return getObjNN4(document, objectId);
	}

	return false;
}


// find an object (NS4 only)
function getObjNN4(obj, name) {

	var x = obj.layers;
	var foundLayer;

	for(var i=0; i < x.length; i++) {
		if(x[i].id == name) {
			foundLayer = x[i];
		}
		else if(x[i].layers.length) {
			var tmp = getObjNN4(x[i], name);
		}
		if(tmp) {
			foundLayer = tmp;
		}
	}

	return foundLayer;
}


// change style class of an element
function changeClass(Elem, Class) {

	var elem;

	if(document.getElementById) {
		elem = document.getElementById(Elem);
	}
	else if(document.all){
		elem = document.all[Elem];
	}
	if(browser.op5 || browser.op6) {
		elem.style.className = Class;
	}
	else {
		elem.className = Class;
	}
}


// hide or show a page element
function changeObjectDisplay(objectId, newDisplay) {

	var styleObject = getStyleObject(objectId, document);
	if(styleObject) {
		styleObject.display = newDisplay;
		return true;
	}

	return false;
}


// get the Y co-ordinate of an element
function getElementTop(Elem) {

	var elem, yPos, tempEl;

	if(browser.ns4) {
		elem = getObjNN4(document, Elem);
		return elem.pageY;
	}

	if(document.getElementById) {
		elem = document.getElementById(Elem);
	} else if (document.all) {
		elem = document.all[Elem];
	}
	yPos = elem.offsetTop;
	tempEl = elem.offsetParent;
	while(tempEl != null) {
		yPos += tempEl.offsetTop;
		tempEl = tempEl.offsetParent;
	}
	return yPos;
}


// get the X co-ordinate of an element
function getElementLeft(Elem) {

	var elem, xPos, tempEl;

	if(browser.ns4) {
		elem = getObjNN4(document, Elem);
		return elem.pageX;
	}

	if(document.getElementById) {
		elem = document.getElementById(Elem);
	} else if (document.all){
		elem = document.all[Elem];
	}
	xPos = elem.offsetLeft;
	tempEl = elem.offsetParent;
	while(tempEl != null) {
		xPos += tempEl.offsetLeft;
		tempEl = tempEl.offsetParent;
	}

	return xPos;
}


// get an element's width
function getElementWidth(Elem) {

	var elem, xPos;

	if(browser.ns4) {
		elem = getObjNN4(document, Elem);
		return elem.clip.width;
	}

	if(document.getElementById) {
		elem = document.getElementById(Elem);
	} else if(document.all) {
		elem = document.all[Elem];
	}

	if(browser.op5) {
		xPos = elem.style.pixelWidth;
	}
	else {
		xPos = elem.offsetWidth;
	}

	return xPos;
}


// get an element's height
function getElementHeight(Elem) {

	var elem, xPos;

	if(browser.ns4) {
		elem = getObjNN4(document, Elem);
		return elem.clip.height;
	}

	if(document.getElementById) {
		elem = document.getElementById(Elem);
	} else if (document.all) {
		elem = document.all[Elem];
	}

	if(browser.op5) {
		xPos = elem.style.pixelHeight;
	} else {
		xPos = elem.offsetHeight;
	}

	return xPos;
}


// move an element to a new set of X + Y co-ordinates
function moveXY(Obj, x, y) {

	var obj = getStyleObject(Obj)

	if(browser.ns4) {
		obj.top = y;
		obj.left = x;
	}
	else if(browser.op5) {
		obj.pixelTop = y;
		obj.pixelLeft = x;
	}
	else {
		obj.top = y + 'px';
		obj.left = x + 'px';
	}
}


// Add a form variable
function insertInputObj(form, type, id, name, value) {

	var doc = form.ownerDocument;

	if(browser.ie && !browser.ie9){
                        
             inputObj = doc.createElement(['<input name=\"', name, '\">'].join(''));
     	        	
	} else {
		inputObj = doc.createElement("input");
		inputObj.name = name;
	}

	inputObj.type  = type;
	inputObj.id    = id;
	inputObj.value = value;

	form.appendChild(inputObj);
}


/**********************************************************************
 * Popup
 *********************************************************************/

// popup a div, near some element
var currPopupDiv = '';
function popupDiv(popupName, elemName, yOffset, formName, formData) {

	// button td dimensions
	var x = getElementLeft(elemName);
	var y = getElementTop(elemName);
	var w = getElementWidth(elemName);

	// re-position
	if(elemName == 'actionCancelButton' && popupName == 'actionPopup') {
		moveXY(popupName, 550, 700);
	} else if(elemName == 'actionDeclineButton' && popupName == 'actionPopup') {
		moveXY(popupName, 350, 700);
	} else {
		moveXY(popupName, x + w + 15, y - yOffset);
	}

	// display
	changeObjectDisplay(popupName, '');
	currPopupDiv = popupName;

	if (formData != null) {
		try {
			document.getElementById(formData).focus();
		} catch(err) {
			//Couldn't set the focus
		}
	}

	// copy the form-data from the main-form
	if(formName) {
		eval("document.forms['" + formName + "']." + formData + ".value=document.forms['bet_action']." + formData + ".value");
	}
}


// close a popup div
function closePopupDiv(popupName) {

	changeObjectDisplay(popupName, 'none');
	currPopupDiv = '';
}


// on clicking outside of a popup div, close it
function hidePopupOnClick(evt) {

	if(!window.event && evt && currPopupDiv.length) {
		try {
			var t = evt.originalTarget;
			while(t.parentNode != null) {
				if(t.id == currPopupDiv) {
					return;
				}
				t = t.parentNode;
			}
			closePopupDiv(currPopupDiv, 'none');
		}
		catch(e) {}
	}
	else if(window.event && currPopupDiv.length) {
		var t = window.event.srcElement;
		while(t.parentElement != null) {
			if(t.id == currPopupDiv) {
				return;
			}
			t = t.parentElement;
		}
		closePopupDiv(currPopupDiv, 'none');
	}
}


/**********************************************************************
 * Leg Events
 *********************************************************************/

// clicking on a leg row
function legOnClick(leg, legSort) {

	if(selectedLeg == leg) {
		return;
	}

	// The customer tab is the same one for all legs.
	if (selectedDD != 'cust') {
		changeObjectDisplay(selectedDD + '_' + leg, '');
		changeObjectDisplay(selectedDD + '_' + selectedLeg, 'none');
	
		changeObjectDisplay('dd_caption_' + selectedDD + "_"  + selectedLeg, '');
		changeObjectDisplay('dd_update_msg_' + selectedDD + "_"  + selectedLeg, 'none');
	}

	selectedLeg = leg;
	selectedLegSort = legSort;
	displayStkLPButtons();
}


// mouse move over a dd-title cell
function ddOnMouseOver(dd) {

	if(dd != selectedDD) {
		changeClass(dd, 'bordered_title_hover');
	}
}


// mouse moves out of a dd-ttile dd cell
function ddOnMouseOut(dd) {

	if(dd != selectedDD) {
		changeClass(dd, 'bordered_title');
	}
}


// clicking on a dd-title dd cell
function ddOnClick(dd) {

	if(selectedDD == dd) {
		return;
	}

	changeClass(selectedDD, 'bordered_title');
	changeClass(dd, 'bordered_title_selected');

	// The Customer tab is common for all legs
	if (selectedDD == 'cust') {
		changeObjectDisplay(selectedDD + '_', 'none');
		changeObjectDisplay('dd_caption_' + selectedDD + '_', '');
	} else {
		changeObjectDisplay(selectedDD + '_' + selectedLeg, 'none');
		changeObjectDisplay('dd_caption_' + selectedDD + '_'  + selectedLeg, '');
		changeObjectDisplay('dd_update_msg_' + selectedDD + '_'  + selectedLeg, 'none');
	}

	if (dd == 'cust') {
		changeObjectDisplay(dd + '_', '');
	} else {
		changeObjectDisplay(dd + '_' + selectedLeg, '');
	}

	selectedDD = dd;
}


/**********************************************************************
 * Form Validation
 *********************************************************************/

// validate an Informix style date & time
function isInformixTime(tm) {

	var exp = /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/;

	return exp.test(strTrim(tm, " "));
}


// round a float to 2 decimal places
function roundFloat(n) {

	var s = "" + Math.round(n * 100) / 100
	var i = s.indexOf('.')

	if(i < 0) {
		return s + ".00"
	}

	var t = s.substring(0, i + 1) + s.substring(i + 1, i + 3)
	if(i + 2 == s.length) {
		t += "0"
	}

	return t;
}


// submit a form
function submitForm(selButton, formName) {

	var f = document.forms[formName];

	f.selected_leg.value = selectedLeg;
	f.selected_dd.value  = selectedDD;

	// copy the bet-action details
	if(formName != 'bet_action') {
		copyToBetAction(formName);
	}

	selButton.value = "Busy...";
	selButton.disabled = true;

	f.submit();
}

// validate update dd-event form
function updDDEv(selButton, formName) {

	var f = document.forms[formName];
	var max_bet     = strTrim(f.ev_max_bet.value, " ");
	var min_bet     = strTrim(f.ev_min_bet.value, " ");
	var Liability   = strTrim(f.Liability.value, " ");
	var start_time  = strTrim(f.start_time.value, " ");
	var suspend_at  = strTrim(f.suspend_at.value, " ");

	##TP_IF {[OT_CfgGet FUNC_LAY_TO_LOSE 0] && [OT_CfgGet FUNC_LAY_TO_LOSE_EV 0]}##
	var LeastMaxBet = strTrim(f.LeastMaxBet.value, " ");
	var MostMaxBet  = strTrim(f.MostMaxBet.value, " ");
	var LayToLose   = strTrim(f.LayToLose.value, " ");
	##TP_ENDIF##

	// Remove the numeric comma separation
	Liability   = Liability.replace(/,/g, "");
	LeastMaxBet = LeastMaxBet.replace(/,/g, "");
	MostMaxBet  = MostMaxBet.replace(/,/g, "");
	LayToLose   = LayToLose.replace(/,/g, "");

	err.reset();

	if(!isInformixTime(start_time)) {
		err.add("Start time must be of the format yyyy-mm-dd hh:mm:ss");
	}

	if(suspend_at.length && !isInformixTime(suspend_at)) {
		err.add("Suspend At must be of the format yyyy-mm-dd hh:mm:ss");
	}

	if(min_bet.length) {
		if(!isMoney(roundFloat(min_bet), false)) {
			err.add("Min Bet must be a monetary value");
		}
	}

	if(max_bet.length) {
		if(!isMoney(roundFloat(max_bet), false)) {
			err.add("Max Bet must be a monetary value");
		}
	}

	if(Liability.length) {
		if(!isMoney(roundFloat(Liability), false)) {
			err.add("Liability must be a monetary value");
		}
	}

	##TP_IF {[OT_CfgGet FUNC_LAY_TO_LOSE 0] && [OT_CfgGet FUNC_LAY_TO_LOSE_EV 0]}##
	if(LeastMaxBet.length) {
		if(!isMoney(roundFloat(LeastMaxBet), false)) {
			err.add("Least Max Bet must be a monetary value");
		}
	}

	if(MostMaxBet.length) {
		if(!isMoney(roundFloat(MostMaxBet), false)) {
			err.add("Most Max Bet must be a monetary value");
		}
	}

	if(LayToLose.length) {
		if(!isMoney(roundFloat(LayToLose), false)) {
			err.add("Lay To Lose must be a monetary value");
		}
	}
	##TP_ENDIF##

	if(!err.isErr() && min_bet.length && max_bet.length && parseFloat(min_bet) > parseFloat(max_bet)) {
		err.add("Min Bet must be smaller than Max Bet");
	}

	if(err.isErr()) {
		err.alert();
	}
	else {
		f.Liability.value = Liability;
		##TP_IF {[OT_CfgGet FUNC_LAY_TO_LOSE 0] && [OT_CfgGet FUNC_LAY_TO_LOSE_EV 0]}##
		f.LeastMaxBet.value = LeastMaxBet;
		f.MostMaxBet.value = MostMaxBet;
		f.LayToLose.value = LayToLose;
		##TP_ENDIF##
		submitForm(selButton, formName);
	}
}


// validate update dd-market form
function updDDMkt(selButton, formName) {

	var f = document.forms[formName];
	var max_bet      = strTrim(f.max_bet.value, " ");
	var min_bet      = strTrim(f.min_bet.value, " ");
	var max_mult_bet = strTrim(f.max_mult_bet.value, " ");
	var win_lp       = strTrim(f.win_lp.value, " ");
	var win_sp       = strTrim(f.win_sp.value, " ");
	var win_ep       = strTrim(f.win_ep.value, " ");
	var place_lp     = strTrim(f.place_lp.value, " ");
	var place_sp     = strTrim(f.place_sp.value, " ");
	var place_ep     = strTrim(f.place_ep.value, " ");
	var acc_min      = strTrim(f.acc_min.value, " ");
	var acc_max      = strTrim(f.acc_max.value, " ");
	var bir_delay    = strTrim(f.bir_delay.value, " ");
	var bir_index    = strTrim(f.bir_index.value, " ");
	var liab_limit   = strTrim(f.liab_limit.value, " ");
	// Remove the numeric comma separation
	max_bet      = max_bet.replace(/,/g, "");
	min_bet      = min_bet.replace(/,/g, "");
	max_mult_bet = max_mult_bet.replace(/,/g, "");
	win_lp       = win_lp.replace(/,/g, "");
	win_sp       = win_sp.replace(/,/g, "");
	win_ep       = win_ep.replace(/,/g, "");
	place_lp     = place_lp.replace(/,/g, "");
	place_sp     = place_sp.replace(/,/g, "");
	place_ep     = place_ep.replace(/,/g, "");
	liab_limit   = liab_limit.replace(/,/g, "");

	err.reset();

	if(acc_min.length) {
		if(!isInt8(acc_min, false) || parseInt(acc_min) == 0 || parseInt(acc_min) > 25) {
			err.add("Min Accumulator must be an integer between 1 and 25");
		}
	}

	if(acc_max.length) {
		if(!isInt8(acc_max, false) || parseInt(acc_max) == 0 || parseInt(acc_max) > 25) {
			err.add("Max Accumulator must be an integer between 1 and 25");
		}
	}

	if(!err.isErr() && acc_min.length && acc_max.length && acc_min > acc_max) {
		err.add("Min Accumulator cannot be greate than Max Accumulator");
	}

	if(bir_index.length) {
		if(!isInt8(bir_index, false)) {
			err.add("BIR Index must be an integer");
		}
	}

	if(bir_delay.length) {
		if(!isInt8(bir_delay, false)) {
			err.add("BIR Delay must be an integer");
		}
	}

	if(liab_limit.length) {
		if(!isMoney(roundFloat(liab_limit), false)) {
			err.add("Liability Limit must be a monetary value");
		}
	}

	if(min_bet.length) {
		if(!isMoney(roundFloat(min_bet), false)) {
			err.add("Min Bet must be a monetary value");
		}
	}

	if(max_bet.length) {
		if(!isMoney(roundFloat(max_bet), false)) {
			err.add("Max Bet must be a monetary value");
		}
	}

	if(max_mult_bet.length) {
		if(!isMoney(roundFloat(max_mult_bet), false)) {
			err.add("Max Multiple Bet must be a monetary value");
		}
	}

	if(win_lp.length) {
		if(!isMoney(roundFloat(win_lp), false)) {
			err.add("Win LP must be a monetary value");
		}
	}

	if(win_sp.length) {
		if(!isMoney(roundFloat(win_sp), false)) {
			err.add("Win SP must be a monetary value");
		}
	}

	if(win_ep.length) {
		if(!isMoney(roundFloat(win_ep), false)) {
			err.add("Win EP must be a monetary value");
		}
	}

	if(place_lp.length) {
		if(!isMoney(roundFloat(place_lp), false)) {
			err.add("Place LP must be a monetary value");
		}
	}

	if(place_sp.length) {
		if(!isMoney(roundFloat(place_sp), false)) {
			err.add("Place SP must be a monetary value");
		}
	}

	if(place_ep.length) {
		if(!isMoney(roundFloat(place_ep), false)) {
			err.add("Place EP must be a monetary value");
		}
	}

	if(!err.isErr() && min_bet.length && max_bet.length && parseFloat(min_bet) > parseFloat(max_bet)) {
		err.add("Min Bet must be smaller than Max Bet");
	}

	if(err.isErr()) {
		err.alert();
	}
	else {
		f.min_bet.value = min_bet;
		f.max_bet.value = max_bet;
		f.max_mult_bet.value = max_mult_bet;
		f.win_lp.value = win_lp;
		f.win_sp.value = win_sp;
		f.win_ep.value = win_ep;
		f.place_lp.value = place_lp;
		f.place_sp.value = place_sp;
		f.place_ep.value = place_ep;
		f.liab_limit.value = liab_limit;
		submitForm(selButton, formName);
	}
}


// validate update dd-outcome form
function updDDOc(selButton, formName) {

	var f = document.forms[formName];
	var max_mult_bet  = strTrim(f.max_mult_bet.value, " ");
	var min_bet       = strTrim(f.min_bet.value, " ");
	var lp_max_bet    = strTrim(f.lp_max_bet.value, " ");
	var sp_max_bet    = strTrim(f.sp_max_bet.value, " ");
	var ep_max_bet    = strTrim(f.ep_max_bet.value, " ");
	var lp_max_place  = strTrim(f.lp_max_place.value, " ");
	var sp_max_place  = strTrim(f.sp_max_place.value, " ");
	var ep_max_place  = strTrim(f.ep_max_place.value, " ");
	var max_total     = strTrim(f.max_total.value, " ");
	var lp            = strTrim(f.lp.value, " ");
	var sp            = strTrim(f.sp.value, " ");
	var fc_stk_limit  = strTrim(f.fc_stk_limit.value, " ");
	var tc_stk_limit  = strTrim(f.tc_stk_limit.value, " ");
	// Remove the numeric comma separation
	min_bet      = min_bet.replace(/,/g,"");
	lp_max_bet   = lp_max_bet.replace(/,/g,"");
	sp_max_bet   = sp_max_bet.replace(/,/g,"");
	lp_max_place = lp_max_place.replace(/,/g,"");
	sp_max_place = sp_max_place.replace(/,/g,"");
	max_total    = max_total.replace(/,/g, "");
	fc_stk_limit = fc_stk_limit.replace(/,/g, "");
	tc_stk_limit = tc_stk_limit.replace(/,/g, "");

	err.reset();


	if(min_bet.length) {
		if(!isMoney(roundFloat(min_bet), false)) {
			err.add("Min Bet must be a monetary value");
		}
	}

	if(max_mult_bet.length) {
		if(!isMoney(roundFloat(max_mult_bet), false)) {
			err.add("Max Multiple Bet must be a monetary value");
		}
	}

	if(lp_max_bet.length) {
		if(!isMoney(roundFloat(lp_max_bet), false)) {
			err.add("Max Bet (LP) must be a monetary value");
		}
	}

	if(sp_max_bet.length) {
		if(!isMoney(roundFloat(sp_max_bet), false)) {
			err.add("Max Bet (SP) must be a monetary value");
		}
	}

	if(ep_max_bet.length) {
		if(!isMoney(roundFloat(ep_max_bet), false)) {
			err.add("Max Bet (EP) must be a monetary value");
		}
	}

	if(lp_max_bet.length) {
		if(!isMoney(roundFloat(lp_max_place), false)) {
			err.add("Max Place (LP) must be a monetary value");
		}
	}

	if(sp_max_bet.length) {
		if(!isMoney(roundFloat(sp_max_bet), false)) {
			err.add("Max Place (SP) must be a monetary value");
		}
	}

	if(ep_max_place.length) {
		if(!isMoney(roundFloat(ep_max_place), false)) {
			err.add("Max Place (EP) must be a monetary value");
		}
	}

	if(fc_stk_limit.length) {
		if(!isMoney(roundFloat(fc_stk_limit), false)) {
			err.add("Forecast Stake Limit must be a monetary value");
		}
	}

	if(tc_stk_limit.length) {
		if(!isMoney(roundFloat(tc_stk_limit), false)) {
			err.add(" Tricast Stake Limit must be a monetary value");
		}
	}

	if(!err.isErr() && min_bet.length && sp_max_bet.length && parseFloat(min_bet) > parseFloat(sp_max_bet)) {
		err.add("Min Bet must be smaller than Max Bet (SP)");
	}

	if(max_total.length) {
		if(!isMoney(roundFloat(max_total), false)) {
			err.Add("Max Total must be a monetary value");
		}
	}

	if(f.lp_avail.value == "Y") {
		if(!lp.length) {
			err.add("Invalid Fixed/Live Price");
		}
	}

	if(err.isErr()) {
		err.alert();
	}
	else {
		f.min_bet.value = min_bet;
		f.max_mult_bet.value = max_mult_bet;
		f.lp_max_bet.value = lp_max_bet;
		f.sp_max_bet.value = sp_max_bet;
		f.lp_max_bet.value = lp_max_bet;
		f.sp_max_bet.value = sp_max_bet;
		f.fc_stk_limit.value = fc_stk_limit;
		f.tc_stk_limit.value = tc_stk_limit;
		f.max_total.value = max_total;
		submitForm(selButton, formName);
	}
}

function processAction(popupName, elemName, yOffset, formName, formData) {

	var source = document.getElementById('source').value;

	if (source != 'P' && source != 'N') {
		var actionForm = document.forms['bet_action'];

		if (popupName == 'actionAcceptPopup') {
			var selButton = document.forms['bet_accept_action'].accept_button;
			actionForm.action.value  = 'ADMIN::ASYNC_BET::DoActAccept';
			submitForm(selButton, 'bet_action');
		} else {
			popupDiv(popupName, elemName, yOffset, formName, formData)
			return
		}

		if (confirm("Close the Auto Referral Betting Window now?")) {
			window.close();
		}
	} else {
		popupDiv(popupName, elemName, yOffset, formName, formData)
		return
	}
}

// bet-action
function betAction(selButton, formName, action) {

	var f = document.forms[formName];

	f.action.value = action;
	var selButtonvalue = selButton.value;
	submitForm(selButton, formName);
	if (selButtonvalue!="Refresh" && confirm("Close the Auto Referral Betting Window now?")) {
		window.close();
	}
	
}

// bet-action accept
function betActionAccept(selButton) {

	var acceptForm = document.forms['bet_accept_action'];
	var actionForm = document.forms['bet_action'];

	if(selButton.value == 'Back') {
		closePopupDiv('actionAcceptPopup');
	} else {

		actionForm.bet_reason.value = acceptForm.bet_reason.value;
		actionForm.action.value  = 'ADMIN::ASYNC_BET::DoActAccept';

		submitForm(selButton, 'bet_action');
		if (confirm("Close the Auto Referral Betting Window now?")) {
			window.close();
		}

		closePopupDiv('actionAcceptPopup');

	}
}

// bet-action cancel
function betActionCancel(selButton) {

	var cancelForm = document.forms['bet_cancel_action'];
	var actionForm = document.forms['bet_action'];

	if(selButton.value == 'Back') {
		closePopupDiv('actionCancelPopup');
	} else {

		actionForm.comment.value = cancelForm.comment.value;
		actionForm.action.value  = 'ADMIN::ASYNC_BET::DoActCancel';

		submitForm(selButton, 'bet_action');
		if (confirm("Close the Auto Referral Betting Window now?")) {
			window.close();
		}

		closePopupDiv('actionCancelPopup');

	}
}


// bet-action decline
function betActionDecline(selButton) {

	var declineForm = document.forms['bet_decline_action'];
	var actionForm = document.forms['bet_action'];

	if(selButton.value == 'Back') {
		closePopupDiv('actionDeclinePopup');
	} else {

		var rc = declineForm.reason_code;
		var idx = rc.selectedIndex;
		var source = document.getElementById('source').value;

		if (source == 'P' || source == 'N') {
			var rt  = strTrim(declineForm.bet_reason.value, " ").length;
		} else {
			var rt = 0;
		}

		// Workaround for Opera bug
		if (idx == -1) {
			idx = 0;
		}

		if(idx != 0) {
			actionForm.reason_code.value = rc.options[idx].value;
		} else if (rt > 0) {
			actionForm.bet_reason.value = declineForm.bet_reason.value;
		} else {
			err.reset();
			err.add("Invalid reason");
			err.alert();
			closePopupDiv('actionDeclinePopup');
			return;
	}

		actionForm.action.value      = 'ADMIN::ASYNC_BET::DoActDecline';

		submitForm(selButton, 'bet_action');
		if (confirm("Close the Auto Referral Betting Window now?")) {
			window.close();
		}

		closePopupDiv('actionDeclinePopup');

	}
}


// bet-action stake
function betActionStake(el_, orgStakePerLine) {

	var stakeForm  = document.forms['bet_stake_action'];
	var actionForm = document.forms['bet_action'];

	if (el_.name == 'max_bet_link') {
		stakeForm.stake_per_line.value = orgStakePerLine;
	}
	else if(el_.name == 'button_stake_back') {
		closePopupDiv('actionStakePopup');
	}
	else if(el_.name == 'button_stake_clear') {
		actionForm.stake_per_line.value = '';
		closePopupDiv('actionStakePopup');
		changeObjectDisplay('betDetailsActionStake', 'none');
		displayStkLPButtons();
	}
	else {
		err.reset();
		var stakePerLine = strTrim(stakeForm.stake_per_line.value, " ");
		stakePerLine = stakePerLine.replace(/,/g, "");
		if(stakePerLine.length) {
			if(!isMoney(roundFloat(stakePerLine))) {
			err.add("Invalid stake-per-line");
			}
			else if(parseFloat(stakePerLine) >= parseFloat(orgStakePerLine)) {
				err.add("New stake-per-line must be smaller than bet's stake_per_line (" + orgStakePerLine + ")");
			}
		}

		if(err.isErr()) {
			err.alert();
		}
		else {
			actionForm.stake_per_line.value = stakePerLine;
			changeObjectDisplay('betDetailsActionStake', stakePerLine.length ? '' : 'none');
			if(stakePerLine.length) {
				getObject('betDetailsActionStake').innerHTML = '(New Offer: ' + roundFloat(stakePerLine) + ')';
			}

			displayStkLPButtons();
			closePopupDiv('actionStakePopup');
		}
	}
}


// bet-action leg type
function betActionLeg(selButton, orgLeg) {

	var legForm  = document.forms['bet_leg_action'];
	var actionForm = document.forms['bet_action'];

	if(selButton.value == 'Back') {
		closePopupDiv('actionLegTypePopup');
	}
	else if(selButton.value == 'Clear') {
		actionForm.leg_type.value = '';
		closePopupDiv('actionLegTypePopup');
		changeObjectDisplay('betLegActionPrice_' + leg, 'none');
		displayStkLPButtons();
	}
	else {
		err.reset();
		var leg_type = legForm.leg_type.value;

		if (leg_type != "W" && leg_type != "E" && leg_type != "P" ) {
			err.add("Invalid leg type (W/E/P)");
		} else if (leg_type == orgLeg) {
			err.add("Must offer different Bet Terms.");
		} else if (leg_type == "E" || leg_type == "W"  || leg_type == "P") {
			actionForm.leg_type.value = leg_type;
			actionForm.action.value = 'ADMIN::ASYNC_BET::GoBet';
			submitForm(selButton, 'bet_action');
		}
		else {
			actionForm.leg_type.value = leg_type;
			displayStkLPButtons();
			closePopupDiv('actionLegTypePopup');
		}

		if(err.isErr()) {
			err.alert();
		}
	}
}

// bet-action price
function betActionPrice(selButton, leg, orgLP, ep_active) {

	var lpForm  = document.forms['bet_price_action_' + leg];
	var actionForm = document.forms['bet_action'];

	if(selButton.value == 'Back') {
		closePopupDiv('actionPricePopup_' + leg);
	} else if(selButton.value == 'Clear') {
		eval("actionForm.lp_" + leg + ".value = ''");
		closePopupDiv('actionPricePopup_' + leg, 'none');
		changeObjectDisplay('betLegActionPrice_' + leg, 'none');
		displayStkLPButtons();
	} else {
		err.reset();
		var lp = strTrim(eval("lpForm.lp_" + leg + ".value"), " ");

		if (lp == orgLP) {
			err.add("New price must be different to leg's bet price (" + orgLP + ")");
		}

		if (lp.toUpperCase() == 'SP' && ep_active == 'Y') {
			err.add("Starting prices cannot be offered in Early Price markets");
		}

		if(err.isErr()) {
			err.alert();
		} else {

			eval("actionForm.lp_" + leg + ".value = lp");
			changeObjectDisplay('betLegActionPrice_' + leg, lp.length ? '' : 'none');
			if(lp.length) {
				getObject('betLegActionPrice_' + leg).innerHTML = lp;
			}

			displayStkLPButtons();
			closePopupDiv('actionPricePopup_' + leg);
		}
	}
}

// bet-action accept
function betActionSubmitOff(selButton) {

	var submitOffForm = document.forms['bet_stakelp_action'];
	var actionForm = document.forms['bet_action'];

	if(selButton.value == 'Back') {
		closePopupDiv('actionAcceptPopup');
	} else {
		checkAndConfirmOffer();
	}
}

function goCustBetTotals(custId) {

	var url = "##TP_CGI_URL##?action=ADMIN::CUST_TOTALS::GoCustBetTotals&Popup=1&CustId=" + custId;
	window.open(
		url,
		"Customer Bet Totals",
		"toolbar=no,location=no,directories=no,menubar=no,resizable=yes,scrollbars=yes,width=600,height=500"
	);

	return false;
}

// Toggle the display of a div
function toggleDivDisplay(div_obj) {

	var display = getStyleObject(div_obj).display;

	if (display == 'block') {
		changeObjectDisplay(div_obj,'none');
	} else {
		changeObjectDisplay(div_obj,'block');
	}
}

/**********************************************************************
 * Clock Utils
 *********************************************************************/

// Provides the counting clock
var clockID = 0;
var tDate = new Date();

// Show the time
function showTime() {

	var mins, sec;

	var mins = Number(tDate.getMinutes());

	if (mins < 10) mins = "0" + mins;

	sec = Number(tDate.getSeconds());

	if (sec < 10) sec = "0" + sec;

	getObject("clock").innerHTML = "" + tDate.getHours() + ":" + mins + ":" + sec;
}

// Update the clock
function updateClock() {
	if (clockID) {
		clearTimeout(clockID);
		clockID  = 0;
	}

	tDate.setTime(tDate.getTime() + 1000);

	showTime();

	clockID = setTimeout("updateClock()", 1000);
}

// Start the clock
function startClock (y, m, d, h, m, s) {
	tDate = new Date(y, m, d, h, m, s);

	updateClock();
}

/**********************************************************************
 * Cookie Utils
 *********************************************************************/

function getCookie(NameOfCookie) {

	if (document.cookie.length > 0) {
		begin = document.cookie.indexOf(NameOfCookie+"=");
		if (begin != -1) {
			begin += NameOfCookie.length+1;
			end = document.cookie.indexOf(";", begin);
			if (end == -1) end = document.cookie.length;
			return document.cookie.substring(begin, end);
		}
	}
	return "";

}

function setCookie(NameOfCookie, value, expiredays) {

	var ExpireDate = new Date ();
	ExpireDate.setTime(ExpireDate.getTime() + (expiredays * 24 * 3600 * 1000));
	document.cookie = NameOfCookie + "=" + value + ((expiredays == null) ? "" : "; expires=" + ExpireDate.toGMTString());

}

/**********************************************************************
 * Ajax Utils
 *********************************************************************/

function asynchProcessHTMLResponse(httpReq,call_back_func,error_msg) {
	if (!httpReq) return

	if (httpReq.status==200) {
		// Should be passing a function here because eval-ing a function
		// name in a string is flaky, but accommodate for both.
		if (typeof call_back_func == "function") {
			call_back_func(httpReq.responseText);
		} else {
			eval(call_back_func+"('"+httpReq.responseText+"')");
		}
	} else {
		// Error response
		eval(call_back_func+"('"+error_msg+"')");
	}
}

/**********************************************************************
 * Input Utils
 *********************************************************************/
function ensureInputElemCanonical(_el) {
	var numeric = /\d+/;
	var money = /(\d+)\.(\d*)/;

	if (_el.className == 'canonicalMoney' && _el.value != "") {
		var numeric_value = _el.value.match(numeric);
		var money_value = _el.value.match(money);
	
		if (money_value != null) {
	
			if (money_value[2].length == 0) {
				_el.value = money_value[0] + '00';
			} else if (money_value[2].length == 1) {
				_el.value = money_value[0] + '0';
			} else if (money_value[2].length > 2) {
				var cut = money_value[2].length - 2;
				_el.value = money_value[0].substring(0, money_value[0].length - cut);
			}
		} else if (numeric_value != null) {
			_el.value = numeric_value[0] + '.00';
		} else {
			_el.value = "";
			alert('Sorry, just monetary values are allowed in this field');
		}
	}
	return true;
}
