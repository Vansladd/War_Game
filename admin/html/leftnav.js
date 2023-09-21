##TP_COMMENT Copyright (c) 2003 Orbis Technology Limited. All rights reserved.##
<!-- $Id: leftnav.js,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $ -->

function node(id) {
	var theNode = document.getElementById(id+"+");
	if (theNode.innerHTML == "+") {
		openNode(id);
	} else {
		closeNode(id);
	}
}

function openNode(id) {
	var theNode = document.getElementById(id+"+");
	theNode.innerHTML = "-&nbsp;";
	var theBody = document.getElementById("_"+id);
	theBody.style.display = "block";
}

function closeNode(id) {
	var theNode = document.getElementById(id+"+");
	theNode.innerHTML = "+";
	var theBody = document.getElementById("_"+id);
	theBody.style.display = "none";
}
