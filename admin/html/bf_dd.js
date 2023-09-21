function go_bf_dd_popup(ev_class_id,ev_type_id) {
        var str = "BF_TypeFilter_name_"+ev_type_id;
	bf_match_name= document.getElementById(str).value;
        popup = window.open("##TP_CGI_URL##?action=ADMIN::BETFAIR_DD::GoBfTypeDD&ev_class_id="+ev_class_id+"&ev_type_id="+ev_type_id+"&bf_match_name="+bf_match_name,
                                "popup",
                                "toolbar=no,location=no,status=no,menubar=no,scrollbars=yes,resizable=yes,height=400,width=600");
        popup.focus();
}

function go_bf_dd_class_popup(ev_class_id,ev_type_id) {
        var str = "BF_TypeFilter_name_"+ev_type_id;
	bf_match_name= document.getElementById(str).value;
        popup = window.open("##TP_CGI_URL##?action=ADMIN::BETFAIR_DD::GoBfClassDD&ev_class_id="+ev_class_id+"&ev_type_id="+ev_type_id+"&bf_match_name="+bf_match_name,
                                "popup",
                                "toolbar=no,location=no,status=no,menubar=no,scrollbars=yes,resizable=yes,height=400,width=600");
        popup.focus();
}


function set_vals(bf_ev_items_id,ev_type_id,bf_name) {
        f = document.fmtype;
        if (!f) {
                alert("unable to find form fmtype");
                return;
        }
                
        var str1 = "BF_TypeFilter_name_"+ev_type_id;
        document.getElementById(str1).value = bf_name;

        var str = "BF_TypeFilter_"+ev_type_id;
        document.getElementById(str).value = bf_ev_items_id;
}


