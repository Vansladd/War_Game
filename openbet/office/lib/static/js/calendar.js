/*
 * $Id: calendar.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Calander-div handler
 */

if(window.cvsID) {
	cvsID('calendar', '$Id: calendar.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'calendar');
	document.Package.require('office', 'date');
	document.Package.require('office', 'base');
}

document.calenderPng = null;

//  Do we need to to the layering hack for IE
var useIframeHack = ( navigator.appVersion.search(/MSIE/) != -1);

//  Do we need to catch double clicks to make spinner conrol responsive in IE
var useDblClicks = ( navigator.appVersion.search(/MSIE/) != -1);


/**********************************************************************
 * Calendar class
 *********************************************************************/

// constructor
function Calendar(
	_input,
	_childInput,
	_showTime,
	_def,
	_img,
	_showCurrentTime,
	_setSelectedDate,
	_disableTimeInput,
	_minClickSize)
{
	if(_showTime == null) _showTime = false;

	this.input      = _input;
	this.childInput = _childInput;
	this.showTime   = _showTime;
	this.def        = _def;
	this.onSelect   = null;
	this.showCurrentTime = typeof _showCurrentTime === 'boolean' && _showCurrentTime;
	this.setSelectedDate = typeof _setSelectedDate === 'boolean' && _setSelectedDate;

	if(Calendar.container == null) {
		var c = (Calendar.container = document.createElement("div"));
		c.id = "calendar";
		c.style.zIndex = 103;
		document.body.appendChild(c);

		if(useIframeHack) {
			var f = (Calendar.iframehack = document.createElement("iframe"));
			f.className = "iframehack";
			f.id="iframehack";
			f.frameBorder = 0;
			document.body.appendChild(Calendar.iframehack);
		}

		// Paint the calendar, we will use DHTML to change
		Calendar.firstDraw(_disableTimeInput,_minClickSize);
	}

	// the click image to pop the calendar up
	var img;
	if(typeof _img === "undefined" || _img === null) {
		img = document.createElement("img");
		img.src = document.calendarPng;
		img.style.cursor = "pointer";
		img.style.verticalAlign = "middle";
		img.style.paddingBottom = '3px';
		img.style.paddingLeft = '2px';
		img.onclick = Calendar.show;
		img.id = ["calendarImg", Calendar.maxID++].join('');
	}
	else {
		img = _img;
	}

	if(this.input && (typeof _img === "undefined" || _img === null)) {
		img.className = this.input.name;
		var nextNode = null,
		isNext = false,
		nodes = this.input.parentNode.childNodes,
		input = this.input,
		node;

		for(i in nodes) {
			node = nodes[i];

			if(isNext) {
				if(typeof node.nodeType != 'undefined') {
					nextNode = node;
				}
				break;
			}

			if(node == input) {
				isNext = true;
			}
		}

		if(nextNode != null) {
			input.parentNode.insertBefore(img, nextNode);
		}
		else {
			input.parentNode.appendChild(img);
		}
	}

	this.selectedDate = new Date();
	this.currentDate  = new Date();

	Calendar.calendars[img.id] = this;
}



// on load, hunt down inputs with a calendar class name
Calendar._load = function()
{
	var inputs = document.getElementsByTagName("input"),
	input, showTime, def, childInput, pos, child, _char, cn;

	for(i in inputs) {
		input = inputs[i];

		cn = input.className;

		// ie bug
		if(typeof cn !== 'string' || cn.indexOf("calendar") === -1) continue;

		showTime = false;
		def = null;

		if(cn.indexOf("time") >= 0) showTime = true;
		if(cn.indexOf("lo") >= 0) def = "lo";
		if(cn.indexOf("mid") >= 0) def = "mid";
		if(cn.indexOf("high") >= 0) def = "high";

		childInput = null;
		if(cn.indexOf("child=") >= 0) {
			pos = cn.indexOf("child=")+6;

			child = "";

			_char = cn.charAt(pos);

			while((pos<cn.length) && (_char != ' ')) {
				child = child.concat(_char);
				pos++;
				_char = cn.charAt(pos);
			}

			childInput = document.getElementsByName(child)[0];
		}

		new Calendar(input, childInput, showTime, def);
	}
};



// first draw
// _disableTimeInput - boolean - should we disable the Input field for time for manual edit
// _minClickSize - number - time in minutes for the fine grained increment decrement links
// in bottom right of calendar
Calendar.firstDraw = function(_disableTimeInput, _minClickSize)
{
	var today = new Date(),
	html = [],
	i, row, col;

	if (typeof _minClickSize === 'undefined' || _minClickSize === null) {
		_minClickSize = 5;
	}

	html[html.length] = "<table cellspacing='0'>";

	html[html.length] = "<tr>";
	html[html.length] = "<td colspan='7' class='yearMonth' nowrap>";

	// month control
	html[html.length] = "<a id='calPrevMonth' href='javascript: Calendar.calendar.currentDate.prevMonth(); ";
	html[html.length] = "Calendar.update();'>";
	html[html.length] = Calendar.prevSymbol;
	html[html.length] = "</a> ";
	html[html.length] = "<select id='CalendarMonthSel' onChange='";
	html[html.length] = "Calendar.calendar.currentDate.setMonth(this.selectedIndex);";
	html[html.length] = "Calendar.update();'>";

	for(i = 0; i < 12; i++) {
		html[html.length] = "<option>";
		html[html.length] = Date.nameOfMonth[i];
		html[html.length] = "</option>";
	}
	html[html.length] = "</select>";
	html[html.length] = " <a id='calNextMonth' href='javascript: Calendar.calendar.currentDate.nextMonth(); ";
	html[html.length] = "Calendar.update();'>";
	html[html.length] = Calendar.nextSymbol;
	html[html.length] = "</a>";

	// year control
	html[html.length] = " ";
	html[html.length] = "<a id='calPrevYear' href='javascript: Calendar.calendar.currentDate.prevYear(); ";
	html[html.length] = "Calendar.update();'>";
	html[html.length] = Calendar.prevSymbol;
	html[html.length] = "</a> ";
	html[html.length] = "<select id='CalendarYearSel' onChange='";
	html[html.length] =
		"Calendar.calendar.currentDate.setYear(this.options[this.selectedIndex].text);";
	html[html.length] = "Calendar.update();' class=calendar>";

	html[html.length] = "</select>";
	html[html.length] = " <a id='calNextYear' href='javascript: Calendar.calendar.currentDate.nextYear();";
	html[html.length] = "Calendar.update();'>";
	html[html.length] = Calendar.nextSymbol;
	html[html.length] = "</a>";

	// add the name of days, use 14% to keep it spaced equally
	html[html.length] = "</td></tr><tr>";
	for(i = 0; i < 7; i++) {
		html[html.length] = "<td class='dayName' width='14%'>";
		html[html.length] = Date.nameOfDay[i].substring(0,2);
		html[html.length] = "</td>";
	}

	html[html.length] = browser.chrome ? "</tr>" : "</tr><tr>";

	//  Just build the table with 5 rows (the maximum possible) + 5 columns
	for (row = 0; row < 6; row++) {
		html[html.length] = "<tr>";
		for (col=0; col < 7; col++) {
			html[html.length] = "<td id='Cal_";
			html[html.length] = row;
			html[html.length] = "_";
			html[html.length] = col;
			html[html.length] = "' >";
			html[html.length] = "X";
			html[html.length] = "</td>";
		}
		html[html.length] = "</tr>";
	}

	// add some more controls
	html[html.length] = "<tr id='CalTimeRow'>";

	/* N.B. As IE misses some clicks with the onClick when clicking rapidly (it thinks two
	 *      sucessive clicks are a double click) we use the double click handler as well to
	 *      ensure the clicker is reponsive in IE
	 */
	html[html.length] = "<td class='CalClicker'><a class='CalClicker' ";
	html[html.length] = "onDblClick='Calendar.hrDblClick(-1);' onClick='Calendar.hrClick(-1); ";
	html[html.length] = "return false;' href='#'>&nbsp;-&nbsp;</a></td>";
	html[html.length] = "<td class='CalClicker'><a class='CalClicker' ";
	html[html.length] = "onDblClick='Calendar.hrDblClick(+1);' onClick='Calendar.hrClick(+1); ";
	html[html.length] = "return false;' href='#'>&nbsp;+&nbsp;</a></td>";
	html[html.length] = "<td id='CalTimeTd' colspan='3' style='text-align: center;'>";
	html[html.length] = "<span id='CalTimeSpan'><input type='text' id='CalTimeInput' size='10' ";
	html[html.length] = "maxlength='8' onKeyUp='Calendar.fromTime(event);' ";
	if(_disableTimeInput) {
		html[html.length] = "disabled";
	}
	html[html.length] = "></span>";
	html[html.length] = "</td>";
	html[html.length] = "<td class='CalClicker'><a class='CalClicker' ";
	html[html.length] = ["onDblClick='Calendar.minDblClick(",_minClickSize,");' "].join('');
	html[html.length] = ["onClick='Calendar.minClick(-",_minClickSize,"); "].join('');
	html[html.length] = ["return false;' href='#'>&nbsp;-",_minClickSize,"&nbsp;</a></td>"].join('');
	html[html.length] = "<td class='CalClicker'><a class='CalClicker' ";
	html[html.length] = ["onDblClick='Calendar.minDblClick(+",_minClickSize,");' "].join('');
	html[html.length] = ["onClick='Calendar.minClick(+", _minClickSize,"); "].join('');
	html[html.length] = ["return false;' href='#'>&nbsp;+",_minClickSize,"&nbsp;</a></td>"].join('');
	html[html.length] = "</tr>";
	html[html.length] = "</table>";

	Calendar.container.innerHTML = html.join('');

	for (row = 0; row < 6; row++) {
		for (col=0; col < 7; col++) {
			Calendar.calCells[row*7 + col] =
				document.getElementById(["Cal_", row, "_", col].join(''));
		}
	}
};



//  Updates the calendar for a new month
Calendar.update = function()
{
	var today = new Date();

	// select the month in the select list
	document.getElementById("CalendarMonthSel").selectedIndex =
		Calendar.calendar.currentDate.getMonth();

	//  Populate the year select
	var yearSel = document.getElementById("CalendarYearSel"),
	cnt = 0,
	curYear = Calendar.calendar.currentDate.getFullYear(),
	row = 0,
	col = 0,
	i, j, curDay, isToday, isSelected, isWeekend, clazz, script;

	for(i = curYear - Calendar.yearRange; i <= curYear + Calendar.yearRange; i++) {
		yearSel.options[cnt] = new Option (i,i);
		cnt++;
	}

	//  Select the year
	yearSel.selectedIndex = Calendar.yearRange;

	// Put some padding in place for the first days
	Calendar.calendar.currentDate.set(Calendar.calendar.currentDate.getFullYear(),
	Calendar.calendar.currentDate.getMonth(), 1);

	curDay = Calendar.calendar.currentDate.getDay();

	for (i = 0; i < curDay; i++) {
		document.getElementById(["Cal_0_", i].join('')).innerHTML = "&nbsp";
		col++;
	}

	for(i = 1; i <= Calendar.calendar.currentDate.getDaysInMonth(); i++) {
		Calendar.calendar.currentDate.setDate(i);

		if(i > 1 && Calendar.calendar.currentDate.getDay() == 0) {
			row++;
			col = 0;
		}

		isToday = Calendar.calendar.currentDate.equalDate(today);
		isSelected =
		    Calendar.calendar.currentDate.equalDate(Calendar.calendar.selectedDate);
		isWeekend =
		    Calendar.calendar.currentDate.getDay() == 0 ||
		    Calendar.calendar.currentDate.getDay() == 6;

		// we style the anchor today's style before the selectedDate style,
		// but the td the otherway around
		clazz = isSelected ? "selectedDate" :
		    isToday ? "today" :
		    isWeekend ? "weekend" : "date";

		script = ["Calendar.select(",
				  Calendar.calendar.currentDate.getFullYear(),
				  ", ",
				  Calendar.calendar.currentDate.getMonth(),
				  ", ",
				  i,
				  ", ",
				  Calendar.calendar.showTime,
				  ");"].join('');

		Calendar.calCells[row*7 + col].innerHTML =
			["<a href='javascript: ", script, "' class='", clazz, "'>", i, "</a>"].join('');
		col++;
	}

	//  Finish off the row
	for (i=col; i < 7; i++) {
		Calendar.calCells[row*7 + i].innerHTML = "&nbsp;";
	}
	row++;
	// Finish off the rest of the columns
	for (i=row; i < 6; i++) {
		for (j=0; j < 7; j++) {
			Calendar.calCells[i*7 + j].innerHTML = "&nbsp;";
		}
	}

	Calendar.calendar.currentDate.setDate(1);
	if(Calendar.calendar.showTime) {
		document.getElementById("CalTimeRow").style.display="";

		if(Calendar.calendar.showCurrentTime) {
			// When displaying the time display the current time
			var currDate = new Date();
			Calendar.calendar.selectedDate.setTimePart(currDate.getHours(),
								   currDate.getMinutes(),
								   currDate.getSeconds());
		}
		document.getElementById("CalTimeInput").value =
			Calendar.calendar.selectedDate.format("%H:%M:%S");
	} else {
		document.getElementById("CalTimeRow").style.display="none";
	}
};



// select the specifed date
Calendar.select = function(_year, _month, _date)
{
	var cal = Calendar.calendar,
	selectedDate = cal.selectedDate,
	oldValue = cal.input.value,
	showTime = cal.showTime;

	if(!selectedDate) selectedDate = new Date();

	// Reset any old value, and get the date from scratch, support call#23926
	selectedDate.set(null,null,null);

	selectedDate.set(_year, _month, _date);

	cal.input.value = selectedDate.toInformixString(showTime);

	// if the child input is not null, was blank, or was the same as the
	// value used to be, update it to the new value
	if(
		(cal.childInput !== null) &&
		((cal.childInput.value === '') || (cal.childInput.value === oldValue))
	) {
		cal.childInput.value = selectedDate.toInformixString(showTime);
	}

	// if we have an onSelect callback then call it now
	Calendar.callSelectHandler();

	// we may need to change the visibility of popup calendars
	Calendar.hide();
};



// set onSelect callback function
Calendar.prototype.setOnSelect = function(_callback)
{
	this.onSelect = _callback;
};



/* Set onHide callback
 *
 *   _cb  - callback
 */
Calendar.prototype.setOnHide = function(_cb)
{
	this.onHide = _cb;
};



// Call the user onSelect callback if it is defined
Calendar.callSelectHandler = function ()
{
	if(Calendar.calendar.onSelect) {
		var cal = Calendar.calendar;
		cal.onSelect(cal,
					 cal.input,
					 cal.childInput,
					 cal.selectedDate.toInformixString(cal.showTime));
	}
};



// display the calendar
Calendar.show = function(_e)
{
	if(!_e) {
		_e = window.event;
	}

	if(document.addEventListener) {
		document.addEventListener("mousedown", Calendar.hide, true);
	}
	else {
		document.attachEvent("onmousedown", Calendar.hide);
	}

	var t = _e.target ? _e.target : _e.srcElement;

	// don't show the calendar if the input is disabled
	if(t.disabled) {
		return;
	}

	// we're showing the calendar for this item
	var cal = (Calendar.calendar = Calendar.calendars[t.id]),
	container = (Calendar.wrapper !== null && typeof Calendar.wrapper === 'object') ? Calendar.wrapper.style : Calendar.container.style,
	top_value;

	Calendar.fromInput();

	if(useIframeHack) {
		var iframehack = Calendar.iframehack.style;

		iframehack.left =
			[(_e.pageX ? _e.pageX : _e.clientX + document.body.scrollLeft), 'px'].join('');

		// Support Call #35815 - Do not go outside the page
		top_value = (_e.pageY ? _e.pageY : _e.clientY + document.body.scrollTop) - 75;
		if(top_value < 0) {
			top_value = 0;
		}
		iframehack.top = [top_value, 'px'].join('');
		iframehack.display = "block";
	}

	container.left =
		[(_e.pageX ? _e.pageX : _e.clientX + document.body.scrollLeft), 'px'].join('');


	// Support Call #35815 - Do not go outside the page
	top_value = (_e.pageY ? _e.pageY : _e.clientY + document.body.scrollTop) - 75;
	if(top_value < 0) {
		top_value = 0;
	}
	container.top = [top_value, 'px'].join('');
	container.display = "block";


	// use the selected date, instead of 'now'!
	if(cal.setSelectedDate) {
		var d = cal.selectedDate;
		cal.currentDate.set(d.getFullYear(), d.getMonth(), d.getDate());
	}

	Calendar.update();
};



// hide the calendar
Calendar.hide = function(_e)
{
	if(!_e) {
		_e = window.event;
	}

	// if trigger by an event, this needs to one where the parent is ours
	if(_e) {
		var t = _e.target ? _e.target : _e.srcElement;

		while(t != null) {
			if(t.id == "calendar") {
				return;
			}
			t = t.parentNode;
		}
	}

	if(Calendar.container != null) {

		if(document.removeEventListener) {
			document.removeEventListener("mousedown", Calendar.hide, true);
		}
		else {
			document.detachEvent("onmousedown", Calendar.hide);
		}

		// Check to see if we are using a wrapper
		if (Calendar.wrapper !== null && typeof Calendar.wrapper === 'object') {
			Calendar.wrapper.style.display = "none";
		}
		else {
			Calendar.container.style.display = "none";
		}

		if(useIframeHack) {
			Calendar.iframehack.style.display =  "none";
		}

		var cal = Calendar.calendar;
		if(
			typeof cal === 'object' &&
			cal !== null &&
			typeof cal.onHide === 'function' &&
			cal.onHide !== null
		) {
			cal.onHide();
		}
	}
};



// user the value of the input to set the time part of the selected date
Calendar.fromTime = function(_e)
{
	if(!_e) {
		_e = window.event;
	}

	var t = _e.target ? _e.target : _e.srcElement,
	cal = Calendar.calendar,
	d = new Date(cal.selectedDate);

	if(!d.fromInformixString(t.value)) return;

	if(cal.selectedDate === d) return;

	cal.selectedDate = d;
	cal.input.value = cal.selectedDate.toInformixString(cal.showTime);
};



// set the date from this input
Calendar.fromInput = function()
{
	var d = new Date(),
	cal = Calendar.calendar,
	v = strTrim(cal.input.value, ' ');

	d.fromInformixString(v);
	cal.selectedDate = d;

	if(!v.length) {
		if(cal.def != null) {
			switch (cal.def) {
				case "lo":
					cal.selectedDate.setTimePart(0, 0, 0);
					break;
				case "mid":
					cal.selectedDate.setTimePart(12, 0, 0);
					break;
				case "high":
					cal.selectedDate.setTimePart(23, 59, 59);
					break;
				default:
					throw "Unknown default value";
			}
		}
		else if(cal.setSelectedDate) {
			cal.selectedDate = new Date();
		}
	}
};



//  Used when the hour clicker is clicked
Calendar.hrClick = function(incrHr)
{
	Calendar.calendar.selectedDate.incrHour(incrHr);
	document.getElementById("CalTimeInput").value =
			Calendar.calendar.selectedDate.format("%H:%M:%S");
	Calendar.calendar.input.value =
	Calendar.calendar.selectedDate.toInformixString(Calendar.calendar.showTime);
	Calendar.callSelectHandler();
};



//  Used from double click handler
Calendar.hrDblClick = function(incrHr)
{
	//  In IE the second click of a double click only fires the onDblClick handler
	//  whereas in Moz it fires onClick and onDblClick handlers.
	//  So in Moz we ignore the onDblClick handler to avoid double increments
	if(useDblClicks) {
		Calendar.hrClick(incrHr);
	}
};



//  Used when the minute clicker is clicked
Calendar.minClick = function(incrMin)
{
	Calendar.calendar.selectedDate.incrMin(incrMin);
	document.getElementById("CalTimeInput").value =
			Calendar.calendar.selectedDate.format("%H:%M:%S");
	Calendar.calendar.input.value =
	Calendar.calendar.selectedDate.toInformixString(Calendar.calendar.showTime);
	Calendar.callSelectHandler();
};



//  used for Double click handlers
Calendar.minDblClick = function(incrMin)
{
	if(useDblClicks) {
		Calendar.minClick(incrMin);
	}
};



/**********************************************************************
 * Calendar class attributes
 *********************************************************************/

Calendar.container       = null;
Calendar.wrapper         = null;
Calendar.calendar        = null;
Calendar.prevSymbol      = "&#171;";
Calendar.nextSymbol      = "&#187;";
Calendar.yearRange       = 6;
Calendar.calendars       = [];
Calendar.maxID           = 0;
Calendar.calCells        = [];

