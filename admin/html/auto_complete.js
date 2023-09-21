##TP_COMMENT Copyright (c) 2008 Orbis Technology Limited. All rights reserved.##
<!-- $Id: auto_complete.js,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $ -->

/** Need to provide the getSuggestions() and getSuggestionLimit() functions from the sourcing file
**
** getSuggestions() should return an array of the possible options
**
** getSuggestionLimit() should return an integer specifying the maximum number of options there can
** be for the option list to be displayed
**/

var suggestions = getSuggestions();
var descriptions = getDescriptions();
var suggestionLimit = getSuggestionLimit();
var suggestionList = new Array();
var descriptionList = new Array();
var suggestionElement;
var suggestionIndex = -1;
var oldText;
var enteredText;
var keyPressed;
var textLimit;

var unSelectedBackground = "white";
var unSelectedForeground = "black";
var selectedBackground   = "#24467a";
var selectedForeground   = "white";



// initialise
//  - set up the suggestion list
//  - kick off the text checker
//  - create the key handlers
function ac_init() {
	suggestionElement = document.getElementById("ac_output");
	suggestionElement.style.background = unSelectedBackground;
	suggestionElement.style.color = unSelectedForeground;
	
	textLimit = document.getElementById("ac_text").maxLength;
	
	window.setInterval("ac_lookAt()", 100);
	ac_setVisible("hidden");
	document.onkeydown = ac_keyPressedGetter; //needed for Opera...
	document.onkeyup = ac_keyPressedHandler;
}



// Shows or hides the suggestion list
function ac_setVisible(visible) {
	var x = document.getElementById("ac_shadow");
	var t = document.getElementById("ac_text");
	x.style.position = 'absolute';
	x.style.top =  (ac_findPosY(t)+3)+"px";
	x.style.left = (ac_findPosX(t)+2)+"px";
	x.style.visibility = visible;
}



// Finds x position of html element
function ac_findPosX(obj) {
	var curleft = 0;
	if (obj.offsetParent) {
		while (obj.offsetParent) {
			curleft += obj.offsetLeft;
			obj = obj.offsetParent;
		}
	} else if (obj.x) {
		curleft += obj.x;
	}
	return curleft;
}



// Finds y position of html element
function ac_findPosY(obj) {
	var curtop = 0;
	if (obj.offsetParent) {
		curtop += obj.offsetHeight;
		while (obj.offsetParent) {
			curtop += obj.offsetTop;
			obj = obj.offsetParent;
		}
	} else if (obj.y) {
		curtop += obj.y;
		curtop += obj.height;
	}
	return curtop;
}



// Called everytime we need to check the users input, handles what action to take
function ac_lookAt() {
	var ins = document.getElementById("ac_text").value;
	
	if (oldText == ins) {
		return;
	//} else if (ins.length == textLimit) {
	//	ac_setVisible("hidden");
	//	suggestionIndex = -1;
	} else if (suggestionIndex > -1);
	else if (ins.length > 0) {
		ac_getWords(ins);
		if (suggestionList.length > 0) {
			ac_clearOutput();
			for (var i = 0; i < suggestionList.length; ++i) {
				ac_addWord (suggestionList[i], descriptionList[i]);
			}
			ac_setVisible("visible");
			enteredText = document.getElementById("ac_text").value;
		} else {
			ac_setVisible("hidden");
			suggestionIndex = -1;
		}
	} else {
		ac_setVisible("hidden");
		suggestionIndex = -1;
	}
	oldText = ins;
}



// Adds a word to the suggestion list
function ac_addWord(word, description) {
	var sp = document.createElement("div");
	sp.appendChild(document.createTextNode(word));
	sp.appendChild(document.createTextNode(" - " + description));
	sp.onmouseover = ac_mouseHandler;
	sp.onmouseout = ac_mouseHandlerOut;
	sp.onclick = ac_mouseClick;
	suggestionElement.appendChild(sp);
}



// Clears all words from the suggestion list
function ac_clearOutput() {
	while (suggestionElement.hasChildNodes()) {
		noten = suggestionElement.firstChild;
		suggestionElement.removeChild(noten);
	}
	suggestionIndex = -1;
}



// Gets all valid words to add to the suggestion list
function ac_getWords(beginning) {
	suggestionList = new Array();
	descriptionList = new Array();
	
	for (var i = 0; i < suggestions.length; ++i) {
		var j = -1;
		var correct = 1;
		while (correct == 1 && ++j < beginning.length) {
			if (suggestions[i].charAt(j) != beginning.charAt(j)) {
				correct = 0;
			}
		}
		if (correct == 1) {
			suggestionList[suggestionList.length] = suggestions[i];
			descriptionList[descriptionList.length] = descriptions[i];
		}
		
		if (suggestionList.length > suggestionLimit) {
			suggestionList = new Array();
			descriptionList = new Array();
			break;
		}
	}
}



// Sets the colour of the selected suggestion 
function ac_setColor (_posi, _color, _forg) {
	suggestionElement.childNodes[_posi].style.background = _color;
	suggestionElement.childNodes[_posi].style.color = _forg;
}



// key down action handler
function ac_keyPressedGetter(event) {
	if (!event && window.event) {
		event = window.event;
	}
	if (event) {
		keyPressed = event.keyCode;
	} else {
		keyPressed = event.which;
	}
}



// key up action handler
function ac_keyPressedHandler(event) {
	if (document.getElementById("ac_shadow").style.visibility == "visible") {
		var textfield = document.getElementById("ac_text");
		if (keyPressed == 40) { //Key down
			if (suggestionList.length > 0 && suggestionIndex < suggestionList.length - 1) {
				if (suggestionIndex >= 0) {
					ac_setColor(suggestionIndex, unSelectedBackground, unSelectedForeground);
				} else { 
					enteredText = textfield.value;
				}
				ac_setColor(++suggestionIndex, selectedBackground, selectedForeground);
				textfield.value = suggestionElement.childNodes[suggestionIndex].firstChild.nodeValue;
			}
		} else if (keyPressed == 38) { //Key up
			if (suggestionList.length > 0 && suggestionIndex >= 0) {
				if (suggestionIndex >= 1) {
					ac_setColor(suggestionIndex, unSelectedBackground, unSelectedForeground);
					ac_setColor(--suggestionIndex, selectedBackground, selectedForeground);
					textfield.value = suggestionElement.childNodes[suggestionIndex].firstChild.nodeValue;
				} else {
					ac_setColor(suggestionIndex, unSelectedBackground, unSelectedForeground);
					textfield.value = enteredText;
					textfield.focus();
					suggestionIndex--;
				}
			}
		} else if (keyPressed == 27) { // Esc
			textfield.value = enteredText;
			ac_setVisible("hidden");
			suggestionIndex = -1;
			oldText = enteredText;
		} else if (keyPressed == 13) { // Enter
			ac_setVisible("hidden");
			suggestionIndex = -1;
		} else if (keyPressed == 8) { // Backspace
			suggestionIndex = -1;
			oldText = -1;
		}
	}
}



// Mouse handler - for when the pointer enters an area
var ac_mouseHandler = function() {
	for (var i=0; i < suggestionList.length; ++i) {
		ac_setColor (i, unSelectedBackground, unSelectedForeground);
	}

	this.style.background = selectedBackground;
	this.style.color= selectedForeground;
}



// Mouse handler - for when the pointer leaves an area
var ac_mouseHandlerOut = function() {
	this.style.background = unSelectedBackground;
	this.style.color= unSelectedForeground;
}



// Mouse handler - for user clicks
var ac_mouseClick = function() {
	document.getElementById("ac_text").value = this.firstChild.nodeValue;
	ac_setVisible("hidden");
	suggestionIndex = -1;
	oldText = this.firstChild.nodeValue;
}
