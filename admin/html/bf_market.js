
function go_bf_mkt_depth_popup(bf_exch_id,bf_ev_mkt_id, bf_ev_oc_id, bf_asian_id, oc_desc) {
	var popup = window.open("##TP_CGI_URL##?action=ADMIN::BETFAIR_MKT::GoBFSelnDepth&BFExchId="+bf_exch_id+"&BFEvMktId="+bf_ev_mkt_id+"&BFEvOcId="+bf_ev_oc_id+"&BFAsianId="+bf_asian_id+"&OcDesc="+oc_desc,
                "popup",
                "toolbar=no,location=no,status=no,menubar=no,scrollbars=yes,resizable=yes,height=600,width=280");
	popup.focus();
}

function go_bf_place_order(oc_id, oc_desc, bf_exch_id, bf_ev_mkt_id, bf_ev_oc_id, bf_asian_id, type, classId) {
	var popup = window.open(
		"##TP_CGI_URL##?action=ADMIN::BETFAIR_ORDER::GoBFPlaceOrder&OcId="+oc_id+"&OcDesc="+oc_desc+"&BFExchId="+bf_exch_id+"&BFEvMktId="+bf_ev_mkt_id+"&BFEvOcId="+bf_ev_oc_id+"&BFAsianId="+bf_asian_id+"&BFOrderType="+type+"&ClassId="+classId,
                "popup",
                "toolbar=no,location=no,status=no,menubar=no,scrollbars=yes,resizable=yes,height=300,width=600");
	popup.focus();
}

function go_bf_orders_popup(oc_id) {
	var popup = window.open(
		"##TP_CGI_URL##?action=ADMIN::BETFAIR_ORDER::GoBFSelnOrderDetails&OcId="+oc_id,
                "popup",
                "toolbar=no,location=no,status=no,menubar=no,scrollbars=yes,resizable=yes,height=400,width=800");
	popup.focus();
}

var bf_selns = new Array ();
##TP_LOOP seln_idx {[tpGetVar NumSelns]}##
	bf_selns[##TP_TCL {tpBufWrite [tpGetVar seln_idx]}##]=new Array(2)
	bf_selns[##TP_TCL {tpBufWrite [tpGetVar seln_idx]}##][0]= "##TP_OcId##";
	bf_selns[##TP_TCL {tpBufWrite [tpGetVar seln_idx]}##][1]= "##TP_BFOcMapId##";
##TP_ENDLOOP##


function bf_upd_seln(b)
{
	b.disabled = true;
	b.value = "Busy...";
	
	for (i=0;i<bf_selns.length;i++) {
		if (bf_selns[i][1] != "") {
			var bf_liquidity_chk = document.getElementById("BFLiquidity_" + bf_selns[i][0]);
			var bf_liq_val	= document.getElementById("BFLiquidityVal_" + bf_selns[i][0])
			if (bf_liquidity_chk.checked) {
				bf_liq_val.value = "N";
			} else {
				bf_liq_val.value = "Y";
			}
		}
	}	
	
	b.form.action.value = "ADMIN::BETFAIR_SELN::GoBFUpdSeln"
	b.form.submit();
	return true;
}


function write_select_margin(sel)
{
	var i;

	for (i = 0; i <= 5; ) {
		if (sel.length && i == sel) {
			document.writeln ('<option value="' + i + '" selected>' + i + '</option>');
		} else {
			document.writeln ('<option value="' + i + '">' + i + '</option>');
		}
		i = Math.round((i+0.05)*100)/100;
	}
}