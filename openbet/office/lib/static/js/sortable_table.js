/*
 * $Id: sortable_table.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $
 * Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
 *
 * OpenBet Office
 * A sortable table
 */

if(window.cvsID) {
	cvsID('sortable_table',
		  '$Id: sortable_table.js,v 1.1 2011/10/06 13:11:22 xbourgui Exp $',
		  'office');
}

if(document.Package) {
	document.Package.provide('office', 'sortable_table');
	document.Package.require('office', 'base');
	document.Package.require('office', 'form');
}



/*******************************************************************************
 * Sortable Table Class
 ******************************************************************************/

/*
 * SortableTable Constructor
 *
 *   _table   - the html table element (not id) that needs to be converted
 *   _row     - row element (not id) within thead which has sortable links
 *              if not specified then 1st row within thead
 *
 */
function SortableTable(_table, _row) {

	if(arguments.length > 0) {
		this.init(_table, _row);
	}
}



/*
 * SortableTable Class Init
 *
 *   _table   - the html table element (not id) that needs to be converted
 *   _row     - row element (not id) within thead which has sortable links
 *              if not specified then 1st row within thead
 *
 * Those header cells within the row element with a style class starting
 * with "colheadSort" will be turned into sortable column headers. If
 * any of those cells also have class "desc", then they will default to
 * sorting in descending order when first clicked.
 *
 */
SortableTable.prototype.init = function(_table, _row) {

	// set up some variables
	this.table = _table;
	this.thead = this.table.getElementsByTagName('thead')[0];
	this.tbody = this.table.getElementsByTagName('tbody')[0];

	// pointer to self
	var _this = this;

	// which row should we add the column links
	// - if _row is not specified, then 1st row of thead
	if(typeof _row == 'undefined' || _row == null) {
		_row = this.thead.rows[0];
	}
	this.theadRow = _row;

	// go through each col in selected row, adding column links
	var i, cell, toggleLink, cellClasses, defaultDirection;
	for(i = 0; i < _row.cells.length; i++) {
		cell = _row.cells[i];
		cellClasses = ' ' + cell.className + ' ';
		if (cellClasses.indexOf(' colheadSort') > -1) {
			if (cellClasses.indexOf(' desc ') > -1) {
				defaultDirection = 'desc';
			} else {
				defaultDirection = 'asc';
			}
			toggleLink = new SortableTable._ToggleLink(_this, cell, defaultDirection);
		}
	}

	// the custom sort type arrays
	this._customMakeKeyFunc = new Array(0);
	this._customCmpKeyFunc  = new Array(0);

	// keep a pointer to the toggleLink that was last used to sort
	this.lastToggleLink = null;
}



/*
 * Function to sort a table by a particular column
 * The header row for the column must have one of the following classes:
 *   colheadSortText       - sort alphabetically (ignoring case and any
 *                           leading | character).
 *   colheadSortNumber     - sort numerically (uses parseFloat).
 *   colheadSort<sortType> - custom sort registered with addSortType.
 * TBODY rows can also be assigned classes:
 *   rowSortChild   - this row should not be sorted, but can move since it
 *                    will remain in the same relative position to the
 *                    last row without any special sort class.
 * Parameters:
 *   columnIndex - the index of the column (starting from 0) by which to sort
 *   direction   - direction (ascending or descending)
 *
 */
SortableTable.prototype.sort = function(columnIndex, direction) {

	var i, j, txt, key, num, func;

	// get the sort type
	var th_cell_classes = ' ' + this.theadRow.cells[columnIndex].className + ' ';
	var sortMatch = th_cell_classes.match(/\s(colheadSort\S+)\s/);
	if (sortMatch != null) {
		var sort_type = sortMatch[1];
	} else {
		return;
	}

	// get the array of rows
	var rows = this.tbody.rows;

	// some rows are not sorted and follow their parent instead
	var childrenOf   = new Array();
	var lastNonChild = -1;

	// Encode the contents of the given column for each row into
	// an array containing the sort key and the row index.
	var sortKeys = new Array();
	for(i = 0; i < rows.length; i++) {
		var rowClasses = ' ' + rows[i].className + ' ';
		if (rowClasses.indexOf(' rowSortChild ') > -1 && lastNonChild > -1) {
			// Skip this row and instead add it to the list of children
			// of the last non child row.
			var children = childrenOf[lastNonChild];
			children[children.length] = i;
			continue;
		} else {
			lastNonChild = i;
			childrenOf[i] = new Array();
		}
		if (sort_type == 'colheadSortText') {
			// get the text out of the cell (first 50 chars is fine)
			txt = SortableTable._extractText(rows[i].cells[columnIndex], 50);
			// ignore any leading pipe
			if (txt.charAt(0) == '|') {
				txt = txt.substr(1);
			}
			// don't care about case
			txt = txt.toLowerCase();
			sortKeys[sortKeys.length] = [ txt, i ];
		} else if (sort_type == 'colheadSortNumber') {
			txt = SortableTable._extractText(rows[i].cells[columnIndex], 18);
			key = parseFloat(txt);
			if (isNaN(key)) {
				key = Number.MAX_VALUE;
			}
			sortKeys[sortKeys.length] = [ key, i ];
		} else {
			// get all the text out of the cell
			txt = SortableTable._extractText(rows[i].cells[columnIndex]);
			// use the custom make key function (if supplied) to turn the text
			// into a sortable key
			func = this._customMakeKeyFunc[sort_type];
			if (func) {
				key = func.apply(this, [ txt ] );
			} else {
				key = txt;
			}
			sortKeys[sortKeys.length] = [ key, i ];
		}
	}

	// Calculate the direction multiplier.
	var dirMul;
	if(direction == 'desc') {
		dirMul = -1;
	} else {
		dirMul = 1;
	}

	/* Sort tke keys. We take care to:
	 * 1) Use the custom compare key function (if supplied) to compare
	 *    the sort keys (which are in the first element of each subarray).
	 *    If not supplied, we sort using the javascript operators.
	 * 2) Ensure the sort is stable (i.e. doesn't move rows with equal
	 *    sort keys) by comparing rows ids when the sort keys are equal.
	 * 3) Take into account the direction multiplier from above.
	*/
	func = this._customCmpKeyFunc[sort_type];
	if (func) {
		sortKeys.sort(function (a,b) {
			var d = func.apply(null, [ a[0] , b[0] ] );
			if (!isNaN(d) && d != 0) {
				return dirMul * d;
			} else {
				return (a[1] - b[1]);
			}
		});
	} else {
		sortKeys.sort(function (a, b) {
			if (a[0] < b[0]) {
				return -dirMul;
			} else if  (a[0] == b[0]) {
				return (a[1] - b[1]);
			} else {
				return dirMul;
			}
		});
	}

	// Remove all the rows, then put them back in according to the
	// order of our sort keys.
	var newRows = new Array(rows.length);
	for(i = 0; i < rows.length; i++) {
		newRows[i] = rows[i];
	}
	removeAllChildren(this.tbody);
	var r, sort_key;
	for (i = 0; i < sortKeys.length; i++) {
		sort_key = sortKeys[i];
		// the second element tells us the row number.
		var r = sort_key[1];
		this.tbody.appendChild(newRows[r]);
		var children = childrenOf[r];
		for (j = 0; j < children.length; j++) {
			this.tbody.appendChild(newRows[children[j]]);
		}
	}

	this._fireEvent('sort', this);
}



/*
 * The Sortable table class should be able to handle event listeners
 *
 *   sortableTable - the sortable table of which this link is a member
 *   direction     - table cell, the table header cell (th) into which this
 *                   toggle link should be created
 *
 */
SortableTable.prototype._eventListeners = {
	'sort': []
}



/*
 * Add an event listener.
 *
 *   You can prevent the event completing by returning false.
 *
 *   Example:
 *
 *   function callback(e) {
 *      alert("Target of event is " + e.target);
 *      return true;
 *   }
 *
 *   Listenable.addEventListener("click", callback);
 *
 *      type     - type of event
 *      callback - function to callback, or string to evaluate
 *
*/
SortableTable.prototype.addEventListener = function(type, callback) {

   if (!this._eventListeners[type])
      throw("Unknown event type " + type);

   this._eventListeners[type].push(callback);
}



/*
 * Fire an event.
 *
 *   type          - type of event
 *   target        - target of the event, should be 'this' (optional)
 *   relatedTarget - related target of event (optional)
 *   which         - key modifiers or mouse button pressed (optional)
 *
*/
SortableTable.prototype._fireEvent =
	function(type, target, relatedTarget, which) {

	// don't create any object unless we really need to
	if (this._eventListeners[type].length == 0)
		return true;

	// this variable name mean that the string can reference 'event'
	var event = new Object();

	event.type = type;
	event.target = target; // aka srcElement, usually 'this'

	event.relatedTarget = relatedTarget; // aka toElement or fromElement
	event.which = which; // aka keyCode


	for(var i = 0; i < this._eventListeners[type].length; i++) {
		var eventListener = this._eventListeners[type][i];

	// must make sure that all of these are be evaluated
		try {
		if (!(typeof(eventListener) == "function" ? eventListener(event) :
				(eval(eventListener) || true)))
			return false;
		} catch(e) {
			window.status = e.message;
		}
	}
	return true;
}



/*
 * Register a custom sort type.
 *
 * Parameters:
 *   type        - custom sort type name.
 *   makeKeyFunc - function to make sort key from cell text.
 *                 [Can be null, in which case the text is the sort key]
 *   cmpKeyFunc  - function to compart two sort keys; must return -ve number,
 *                 zero or +ve number.
 *                 [Can be null, in which case the keys are sorted using
 *                  the javascript comparison operators.]
 *
 * Example:
 *   addSortType('NiceDate', function (txt) {
 *       // try to turn the text from HH:MM:SS dd-mm-yyyy format
 *       // into yyyymmddHHMMSS format (which we can sort textually)
 *       var dateRE = /^(\d\d):(\d\d):(\d\d) (\d\d)-(\d\d)-(\d\d)$/;
 *       var match = dateRE.exec(txt);
 *       if (match) {
 *          var iso_date = '' + match[6] + match[5] + match[4]
 *                            + match[1] + match[2] + match[3];
 *          return iso_date;
 *       } else {
 *          return '';
 *       }
 *   }, null);
 *
*/
SortableTable.prototype.addSortType = function(sort_type, makeKeyFunc, cmpKeyFunc) {
	this._customMakeKeyFunc['colheadSort' + sort_type] = makeKeyFunc;
	this._customCmpKeyFunc['colheadSort' + sort_type] = cmpKeyFunc;
}



/*******************************************************************************
 * Toggle Link class
 ******************************************************************************/

/*
 * Toggle Link class
 *
 * A link that allows sorting by a column, toggling the dir each time it
 * is clicked.
 *
 *   sortableTable - the sortable table of which this link is a member
 *   tableCell        - table cell, the table header cell (th) into which this
 *                      toggle link should be created
 *   defaultDirection - initial sort direction (desc or asc). Default is asc.
 *
 */
SortableTable._ToggleLink = function(sortableTable, tableCell, defaultDirection) {

	this.sortableTable = sortableTable;
	this.tableCell = tableCell;
	if (defaultDirection == 'desc') {
		this.direction = 'desc';
	} else {
		this.direction = 'asc';
	}
	tableCell.toggle_link = this;

	// why have a variable called temp? so that the link's onClick event handler
	// knows which Toggle Link to call. You can't use 'this' in the onClick def
	// because in that context, 'this' will refer to the link!
	var _this = this;

	var cellContents = this.tableCell.innerHTML;
	removeAllChildren(this.tableCell);

	// store this link so we can revert back on toggle
	this.link = document.createElement('a');
	this.link.href = 'javascript:void(0)';
	this.link.innerHTML = cellContents;
	this.text = cellContents;

	this.tableCell.appendChild(this.link);
	this.link.onclick = function(e) {
		_this.toggle();
	}
}



/*
 * Sorts the table by the current direction, then toggles the
 * direction (between asc and desc)
 *
 */
SortableTable._ToggleLink.prototype.toggle = function() {

	// hide the up/down arrow on previous sortable link
	var prev = this.sortableTable.prevToggleLink;
	if(prev && this != prev) {
		removeAllChildren(prev.tableCell);
		prev.tableCell.appendChild(prev.link);
	}

	var _this = this;
	this.sortableTable.prevToggleLink = this;

	this.sortableTable.sort(this.tableCell.cellIndex, this.direction);
	this.direction = (this.direction == 'desc' ? 'asc' : 'desc');

	var link = document.createElement('a');
	link.href = 'javascript:void(0)';

	link.innerHTML = this.text + ' ' +
		(this.direction == 'desc' ? '&uarr;' : '&darr;');

	removeAllChildren(this.tableCell);

	this.tableCell.appendChild(link);
	link.onclick = function(e) {
		_this.toggle();
	}
}



/*******************************************************************************
 * Utility setup functions
 ******************************************************************************/

// convert every table with class='sortable' to a sortable table
function setupSortableTables() {

	var tables = document.getElementsByTagName('table');
	var i, table, sortableTable;
	for(i = 0; i < tables.length; i++) {

		table = tables[i];
		var table_classes = ' ' + table.className + ' ';
		if (table_classes.indexOf(' sortable ') > -1) {
			sortableTable = new SortableTable(table);
		}

	}
}



/*******************************************************************************
 * Any other internal utility functions needed by SortableTable
 ******************************************************************************/

// extract any text from inside an HTML element.
// max_chars is optional.
// leading and trailing whitespace is ignored.
SortableTable._extractText = function(elem, max_chars) {

	if (isNaN(max_chars)) {
		max_chars = 99999;
	}

	// get the inner HTML
	var html = elem.innerHTML;
	var txt = '';
	var closeBracket = 0;
	var openBracket;

	// ignore anything between < and >.
	while (txt.length < max_chars) {
		var openBracket = html.indexOf('<', closeBracket);
		if (openBracket < 0) {
			txt += html.substr(closeBracket).replace(/^\s+|\s+$/g, '');
			break;
		}
		txt += html.substring(closeBracket, openBracket).replace(/^\s+|\s+$/g, '');
		openBracket++;
		closeBracket = html.indexOf('>', openBracket);
		if (closeBracket < 0) {
			break;
		}
		closeBracket++;
	}

	if (txt.length > max_chars) {
		return txt.substring(0, max_chars);
	} else {
		return txt;
	}
}
