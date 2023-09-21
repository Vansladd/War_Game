/*
 * $Id: date.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * Date prototypes to extend date handling
 */

if(window.cvsID) {
	cvsID('date', '$Id: date.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $', 'office');
}

if(document.Package) {
	document.Package.provide('office', 'date');
}


/**********************************************************************
 * Date class
 *********************************************************************/

Date.nameOfMonth  = new Array("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
							  "Aug", "Sep", "Oct", "Nov", "Dec");
Date.nameOfDay    = new Array("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
Date.correction   = 0;
Date.inf_date_exp = /^([1-9]\d\d\d)-(0[1-9]|1[0-2])-(0[1-9]|[1-2]\d|3[0-1])$/;
Date.inf_time_exp = /^([0-1]\d|2[0-3]):([0-5]\d):([0-5]\d)$/;
Date.inf_exp      = /^([1-9]\d\d\d)-(0[1-9]|1[0-2])-(0[1-9]|[1-2]\d|3[0-1]) ([0-1]\d|2[0-3]):([0-5]\d):([0-5]\d)$/;



// compare two dates
Date.prototype.equalDate = function(_d)
{
	return this.getFullYear() == _d.getFullYear() &&
	    this.getMonth() == _d.getMonth() &&
	    this.getDate() == _d.getDate();
};



// compare two times
Date.prototype.equalTime = function(_d)
{
	return this.getHours() == _d.getHours() &&
	    this.getMinutes() == _d.getMinutes() &&
	    this.getSeconds() == _d.getSeconds();
};



// compare seconds
Date.prototype.equals = function(_d)
{
	return (this.compare(_d) == 0);
};



// compare seconds
Date.prototype.compare = function (_d)
{
	return _d.getSeconds() - this.getSeconds();
};



// number of days in the month
Date.getDaysInMonth = function(_year, _month)
{
	return (new Array(31, (_year % 4 == 0 ? 29 : 28), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31))[_month];
};



// number of days in a month
Date.prototype.getDaysInMonth = function ()
{
	return Date.getDaysInMonth(this.getFullYear(), this.getMonth());
};



// gets the name of a date
Date.prototype.nameOfMonth = function ()
{
	return Date.nameOfMonth[this.getMonth()];
};



// get the name of a day
Date.prototype.nameOfDay = function ()
{
	return Date.nameOfMonth[this.getDay()];
};



// sets the value of a date
Date.prototype.set = function(year, month, date)
{
	month = Math.max(month, 0);
	month = Math.min(month, 11);

	date  = Math.max(date, 1);
	date  = Math.min(date, Date.getDaysInMonth(year, month));

	this.setFullYear(year, month, date);
};



// sets just the time part of the date
Date.prototype.setTimePart = function(hours, minutes, seconds)
{
	hours = Math.max(hours, 0);
	hours = Math.min(hours, 23);

	minutes  = Math.max(minutes, 0);
	minutes  = Math.min(minutes, 59);

	seconds  = Math.max(seconds, 0);
	seconds  = Math.min(seconds, 59);

	this.setHours(hours);
	this.setMinutes(minutes);
	this.setSeconds(seconds);
};



// changes the date, but instead of limiting the date
// moves the month, year on or back
Date.prototype.bump = function(_year, _month, _date, _hour, _minute, _second)
{
	if(_second == null) _second = this.getSeconds();
	if(_hour == null) _hour = this.getHours();
	if(_minute == null) _minute = this.getMinutes();
	if(_second < 0) {
		_minute--;
		_second = 59;
	}
	else if (_second > 59) {
		_minute++;
		_second = 0;
	}

	if(_minute < 0) {
		_hour--;
		_minute = 59;
	}
	else if (_minute > 59) {
		_hour++;
		_minute = 0;
	}

	if(_hour < 0) {
		_date--;
		_hour = 23;
	} else if (_hour > 23) {
		_date++;
		_hour = 0;
	}

	if(_date < 0) {
		_month--;
		_date = this.getDaysInMonth();
	}
	if(_date > this.getDaysInMonth()) {
		_month++;
		_date = 1;
	}
	if(_month < 0) {
		_year--;
		_month = 11;
	}
	if(_month > 11) {
		_year++;
		_month = 0;
	}

	this.set(_year, _month, _date);
	this.setTimePart(_hour, _minute, _second);
};



// bump the hour
Date.prototype.prevHour = function()
{
	this.bump(this.getFullYear(), this.getMonth(), this.getDate(), this.getHours() - 1);
};



// next hour
Date.prototype.nextHour = function()
{
	this.bump(this.getFullYear(), this.getMonth(), this.getDate(), this.getHours() + 1);
};



// changes the date to the previous date
Date.prototype.prevDate = function()
{
	this.bump(this.getFullYear(), this.getMonth(), this.getDate() - 1);
};



// changes the date to the next date
Date.prototype.nextDate = function()
{
	this.bump(this.getFullYear(), this.getMonth(), this.getDate() + 1);
};



// changes the date to the previous month
Date.prototype.prevMonth = function()
{
	this.bump(this.getFullYear(), this.getMonth() - 1, this.getDate());
};



// changes the date to the next month
Date.prototype.nextMonth = function()
{
	this.bump(this.getFullYear(), this.getMonth() + 1, this.getDate());
};



// changes the date to the previous year
Date.prototype.prevYear = function()
{
	this.bump(this.getFullYear() - 1,  this.getMonth(), this.getDate());
};



// changes the date to the next year
Date.prototype.nextYear = function()
{
	this.bump(this.getFullYear() + 1, this.getMonth(), 1);
};



//  Function to support hour clicker - Adds one hour, but stops when hour gets out of bounds
Date.prototype.incrHour = function(hrIncr)
{
	var hour = this.getHours();
	hour += hrIncr;
	if (hour <0) {
		hour = 0;
		}
	if (hour > 23) {
		hour = 23;
	}
	this.setTimePart(hour,this.getMinutes(),this.getSeconds());
};



//  Function to support minute clicker.
//  Will round time to nearest n minutes, as specified in call
//  As a corollary will zero the seconds part
Date.prototype.incrMin = function(incrMin)
{
	var minutes = this.getMinutes(),
		remainder = minutes % incrMin;

	//  First round to the nearest increment
	if (incrMin > 0) {
		minutes -= remainder;
	} else {
		if (remainder > 0) minutes -= remainder + incrMin;
	}

	var hours = this.getHours();

	//  Now add the increment
	minutes += incrMin;

	//  make sure we don't go out of bounds
	if (minutes > 59) {
		if (hours<23) {
			minutes = 0;
			hours ++;
		} else {
			minutes = 59;
		}
	}
	if (minutes < 0) {
		if (hours > 0) {
			minutes += 60;
			hours--;
		} else {
			minutes = 0;
		}
	}
	this.setTimePart(hours, minutes, 0);
};



// conversion function to change dates into informix format, if full is specified
// the whole date is converted
Date.prototype.toInformixString = function(_full)
{
	var year = this.getFullYear(),
		month = (this.getMonth() + 1 < 10 ? "0" : "") + (this.getMonth() + 1),
		date = (this.getDate() < 10 ? "0" : "") + this.getDate(),
		hours = (this.getHours() < 10 ? "0" : "") + this.getHours(),
		minutes = (this.getMinutes() < 10 ? "0" : "") + this.getMinutes(),
		seconds = (this.getSeconds() < 10 ? "0" : "") + this.getSeconds(),
		inf =  year + "-" + month + "-" + date;

	if(_full) inf += " " + hours + ":" + minutes + ":" + seconds;

	return inf;
};



// set this from an informix date, automatically detects the length
Date.prototype.fromInformixStringDate = function(_inf)
{
	if(_inf.length != 10) return false;

	var r = Date.inf_date_exp.exec(_inf);
	if(!r || r.length != 4) return false;

	this.set(toInt(r[1]), toInt(r[2]) - 1, toInt(r[3]));

	return true;
};



// set this from an informix time
Date.prototype.fromInformixStringTime = function(_inf)
{
	if(_inf.length == 5) _inf = [_inf, ':00'].join('');
	else if(_inf.length != 8) return false;

	var r = Date.inf_time_exp.exec(_inf);
	if(!r || r.length != 4) return false;

	this.setTimePart(toInt(r[1]), toInt(r[2]), toInt(r[3]));

	return true;
};



// set this from an informix timestamp
Date.prototype.fromInformixString = function(_inf)
{
	if(_inf.length == 8) {
		return this.fromInformixStringTime(_inf);
	}
	else if(_inf.length == 10) {
		return this.fromInformixStringDate(_inf);
	}
	else if(_inf.length == 19 && _inf.substring(10, 11) == " ") {
		return this.fromInformixStringDate(_inf.substring(0, 10)) &&
			this.fromInformixStringTime(_inf.substring(11, 19));
	}


	return false;
};



// a utility function to show a sort format date
Date.prototype.toShortFormat = function ()
{
	return this.nameOfDay().substring(0,2) + ' ' + this.getDate() + ' ' +
	    this.nameOfMonth() + ' ' + (this.getFullYear()+'').substring(2);
};



// Correct discrepancy between server and client
Date.prototype.correct = function()
{
	this.setTime(this.getTime() + Date.correction);
};



// Add a zero
Date._addZero = function(_n)
{
	return ((_n < 10) ? '0' : '') + _n;
};


// use the 12 Hour clock
Date._getMeridiemHours = function(_n)
{
	return (_n <= 12) ? _n : _n - 12;
};

// Return the current meridiem (am or pm)
Date._getMeridiem = function(_n)
{
	return (_n < 12) ? 'AM' : 'PM';
};

// Format a date
//
//   %a - day of week
//   %b - month
//   %Y - full year
//   %y - year
//   %m - month
//   %d - date
//   %H - hour
//   %I - hour (12-hour clock)
//   %M - minute
//   %S - second
//   %p - AM/PM
//
Date.prototype.format = function(_fmt)
{
	if (!_fmt) {
		_fmt = "%a %b %m %H:%M:%S %Y";
	}

	_fmt = _fmt.replace(/%Y/g, this.getFullYear());
	_fmt = _fmt.replace(/%y/g, this.getYear());
	_fmt = _fmt.replace(/%m/g, Date._addZero(this.getMonth() + 1));
	_fmt = _fmt.replace(/%b/g, Date.nameOfMonth[this.getMonth()]);
	_fmt = _fmt.replace(/%d/g, Date._addZero(this.getDate()));
	_fmt = _fmt.replace(/%a/g, Date.nameOfDay[this.getDay()]);
	_fmt = _fmt.replace(/%H/g, Date._addZero(this.getHours()));
	_fmt = _fmt.replace(/%I/g, Date._getMeridiemHours(this.getHours()));
	_fmt = _fmt.replace(/%M/g, Date._addZero(this.getMinutes()));
	_fmt = _fmt.replace(/%S/g, Date._addZero(this.getSeconds()));
	_fmt = _fmt.replace(/%p/g, Date._getMeridiem(this.getHours()));

	return _fmt;
};

