function ShowDefMtchStr (b,t)
{
	var val = document.getElementById('BfDefSearchOpt').checked;
	if (t == "BfDefSearchOpt")
	{
		if (val)
		{
			document.getElementsByName('MktGrpBFDesc')[0].value = "##TP_BfDefMatchString##";
		} else
		{
			var BfDesc = "##TP_MktGrpBFDesc##";
			document.getElementsByName('MktGrpBFDesc')[0].value = BfDesc;
		}
	}
	if (t == "MktGrpBFDesc")
	{
		document.getElementById('BfDefSearchOpt').checked = false;
	}
}