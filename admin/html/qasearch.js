// QAS functionality for admin screens

function QASearch(reg_form,addr_select)
{
	this.addr_street_1 = reg_form.addr_street_1;
	this.addr_street_2 = reg_form.addr_street_2;
	this.addr_street_3 = reg_form.addr_street_3;
	this.addr_street_4 = reg_form.addr_street_4;
	this.addr_city = reg_form.addr_city;
	this.addr_postcode = reg_form.addr_postcode;
	this.addr_select = addr_select;
	this.qas_return_type = null;
	this.qas_return_types = { SINGLE: 0, MULTIPLE: 1 };

	// reference to "Find Address" button
	this.find_address_button = reg_form.find_address_button;
}



// Address lookup (AJAX)
QASearch.prototype.lookup_address = function()
{
	var obj = this;
	var completed_fields = 0;

	// Get lookup data
	var qry_string = '?action=ADMIN::QAS::DoAddressLookup'
	if (this.addr_street_1 && this.addr_street_1.value != '' && this.addr_street_1.value != undefined) {
		completed_fields++;
		qry_string += '&addr_street_1=' + this.addr_street_1.value;
	}
	if (this.addr_street_2 && this.addr_street_2.value != '' && this.addr_street_2.value != undefined) {
		completed_fields++;
		qry_string += '&addr_street_2=' + this.addr_street_2.value;
	}
	if (this.addr_street_3 && this.addr_street_3.value != '' && this.addr_street_3.value != undefined) {
		completed_fields++;
		qry_string += '&addr_street_3=' + this.addr_street_3.value;
	}
	if (this.addr_street_4 && this.addr_street_4.value != '' && this.addr_street_4.value != undefined) {
		completed_fields++;
		qry_string += '&addr_street_4=' + this.addr_street_4.value;
	}
	if (this.addr_city && this.addr_city.value != '' && this.addr_city.value != undefined) {
		completed_fields++;
		qry_string += '&addr_city=' + this.addr_city.value;
	}
	if (this.addr_postcode && this.addr_postcode.value != '' && this.addr_postcode.value != undefined) {
		completed_fields++;
		qry_string += '&addr_postcode=' + this.addr_postcode.value;
	}
	
	// Don't allow blank searches.
	if (!completed_fields) {
		alert ("Sorry, you may not search without entering any details");
		return false;
	}

	// Disable the search button
	this.find_address_button.disabled = true;
	this.find_address_button.value = "Searching ...";

	// this call is asynchronous, button will be re-enabled by the callback
	HttpRequest(document.cgi_url + qry_string, 'GET', function(req) { obj._lookup_address_callback(req); }, null, true);

	return false;
};



// Address refine (AJAX)
QASearch.prototype.lookup_refine = function()
{
	if (typeof this.addr_select.selectedIndex == 'undefined' || this.addr_select.selectedIndex < 0) { return; }

	var obj = this,
	    sel = this.addr_select.options[this.addr_select.selectedIndex];

	if (sel.value) {
		// Send request
		HttpRequest(document.cgi_url + '?action=ADMIN::QAS::DoAddressRefine&addr_id=' + sel.value, 'GET', function(req) { obj._lookup_address_callback(req); }, null, false);
	}
	return false;
};



// Address lookup callback, populates the combo with
QASearch.prototype._lookup_address_callback = function(req)
{
	// Enable the search button again
	this.find_address_button.disabled = false;
	this.find_address_button.value = "Find Address...";

	var data = eval( '(' + req.responseText + ')' );
	if (data.result == 'OK') {
		// Different cases
		if (data.pick_list) {
			// Build multiple select.
			var o = this.addr_select;
			o.options.length = 0;

			for (var i=0; i<data.pick_list.length; i++) {
				var item=data.pick_list[i];
				if (item.addr_id == "ERROR") {
					alert('Sorry, your search has returned an error.\n Please try again.');
					this.addr_postcode.focus();
					return;
				}
				o.options[o.options.length] = new Option(item.partial_address, item.addr_id);
			}

			this.qas_return_type = this.qas_return_types.MULTIPLE
			this.after_lookup_tasks();
		} else if (data.address) {
			// Single address
			if(this.addr_street_1) { this.addr_street_1.value = data.address.street_1; }
			if(this.addr_street_2) {this.addr_street_2.value = data.address.street_2; }
			if(this.addr_city ) {this.addr_city.value     = data.address.city; }
			if(this.addr_postcode ) {this.addr_postcode.value = data.address.postcode; }

			this.qas_return_type = this.qas_return_types.SINGLE
			this.after_lookup_tasks();
		} else {
			// If data is OK, but we have no picklist, then we have too many results or an error
			alert('Sorry your search criteria was too vague and has returned too many results.\n Please provide more data');
			this.addr_postcode.focus();
		}
	} else if (data.result == 'TOO_MANY') {
		// Too many results
		alert(' Sorry your search criteria was too vague and has returned too many results.\n Please provide more data');
		this.addr_postcode.focus();
	} else {
		// An error has occured.
		this.addr_postcode.focus();
	}

};

// Function to perform any necessary changes to the page after a lookup
// Will be overridden with specific tasks in each page
QASearch.prototype.after_lookup_tasks = function () {};
