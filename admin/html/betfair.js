##TP_IF {[tpGetVar BfType 0]==1}##
	
	var all_type_names = new Array ();
	var all_type_ids   = new Array ();
	##TP_LOOP bf_class_idx {[tpGetVar BFNumClasses 0]}##
	all_type_names[##TP_BFClassId##] = new Array (##TP_LOOP bf_type_idx {$CLASS([tpGetVar bf_class_idx],types)}####TP_IF {[tpGetVar bf_type_idx]>0}##,##TP_ENDIF##"##TP_BFTypeName##"##TP_ENDLOOP##);
	all_type_ids[##TP_BFClassId##] = new Array (##TP_LOOP bf_type_idx {$CLASS([tpGetVar bf_class_idx],types)}####TP_IF {[tpGetVar bf_type_idx]>0}##,##TP_ENDIF##"##TP_BFTypeId##"##TP_ENDLOOP##);
	##TP_ENDLOOP##

	function update_types (form) {

		var class_list = form.BFCatId;
		var type_options = form.BFClassId.options;

		var cId = class_list.options[class_list.selectedIndex].value;
		var cName = class_list.options[class_list.selectedIndex].text;

		// Delete everything
		type_options.length=0;

		if (cId != "0") {
			var class_type_names = all_type_names[cId];
			var class_type_ids = all_type_ids[cId];

			for (i=0;i<class_type_names.length;i++) {
				type_options[type_options.length] =
					new Option( class_type_names[i], class_type_ids[i] );
			}
		}

		type_options.selectedIndex = 0;
	}

	function update_assign (b) {

		var ids = document.forms['type'].BFIdList.value;
		var t_options = b.BFClassId.options;
		var t_len = t_options.length;
		var assigned_options = b.BFAssigned.options;
		var assigned_len = assigned_options.length;
		var tId = null;
		var tName = null;		
		var fnd = false;

		for (j=0;j<t_len;j++) {

			if (t_options[j].selected) {
			
				tId = t_options[j].value;
				tName = t_options[j].text;

				if (assigned_len == 0) {
					assigned_options[assigned_len] = new Option(tName, tId);
					assigned_len = assigned_options.length;
					ids = tId;
					document.forms['type'].BFIdList.value = ids
					return;
				}
				
				for (i=0; i < assigned_len; i++) {
					if (assigned_options[i].value == tId) {
						alert(tName+ " is already assigned to this event type.");
						ids = ids + "|" + tId;
						document.forms['type'].BFIdList.value = ids		
						return;
					} 
				}

				assigned_options[assigned_len] = new Option(tName, tId);
				assigned_len = assigned_options.length;
				ids = ids + "|" + tId;
			} 
		}
		document.forms['type'].BFIdList.value = ids
	}

	function remove_assigned (form) {

		var assigned_list = form.BFAssigned;
		var assigned_len = assigned_list.options.length;
		var idx = assigned_list.selectedIndex;
		var assigned_options = assigned_list.options;
		var tId = null;
		var tName = null;
		var j = 0;
		var rm_ids = document.forms['type'].BFIdRMList.value;
		var ids = document.forms['type'].BFIdList.value;
		var assigned_options_new = new Array();

		for (i=0;i<assigned_len;i++) {
					
			if (i != idx) {
				tId = assigned_list.options[i].value;
				tName = assigned_list.options[i].text;
				assigned_options_new[j] = new Option(tName, tId);
				if (j != 0) {
					ids = ids + "|" + tId; 
				} else {
					ids = tId;
				}
				j++;
			} else {
				tId = assigned_list.options[i].value;
				assigned_options[i] = null;
				if (rm_ids == "") {
					rm_ids = tId;
				} else {
					rm_ids = rm_ids + "|" + tId;
				}
				assigned_len = assigned_len - 1;
			}
		}

		assigned_options = assigned_options_new;
		document.forms['type'].BFIdRMList.value = rm_ids;
		document.forms['type'].BFIdList.value = ids;
	}
	##TP_TCL {tpSetVar BfType 0}##
##TP_ENDIF##

function go_bf_pb_upd_popup(bf_order_id) {
  	var popup = window.open("##TP_CGI_URL##?action=ADMIN::BETFAIR_PASSBET::GoBFPassbet&BFPassBetId="+bf_order_id,
		"popup",
		"toolbar=no,location=no,status=no,menubar=no,scrollbars=yes,resizable=yes,height=200,width=700");
	popup.focus();
}

function go_bf_order_upd_popup(bf_order_id) {
	var popup = window.open("##TP_CGI_URL##?action=ADMIN::BETFAIR_ORDER::GoBFOrderUpd&BFOrderId="+bf_order_id,
		"popup",
		"toolbar=no,location=no,status=no,menubar=no,scrollbars=yes,resizable=yes,height=400,width=700");
	popup.focus();
}
