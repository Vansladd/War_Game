function addDynamic(id)
{
	addDynamic(id, '');
}

function addDynamic(id, startText)
{
	document.write('<DIV ID="' + id + '">' + startText + '</DIV>');
}

function changeHTML(id,html)
{
	if (document.getElementById)
	{
		x = document.getElementById(id);
		x.innerHTML = html;
	}
	else if (document.all)
	{
		x = document.all[id];
		x.innerHTML = html;
	}
	else if (document.layers)
	{
		x = document.layers[id];
		x.document.open();
		x.document.write(text);
		x.document.close();
	}
}