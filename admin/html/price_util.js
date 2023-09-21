
// $Id: price_util.js,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $

//utility functions for front-end price calculations


//returns an array of lp_num and lp_den
function parsePrice(price) {

	if ( price == null || price == '' ) {
		return new Array('ERR','');
	}

	var res = new Array();
	var lp=price.split('/',2);

	if ( lp[1] != null && lp[1] != '') {
		res = lp;
	}

	else {

		try {
			price = parseFloat(price);
			res = dec2frac(price-1);
		} catch(e) {
			res[0] = 'ERR';
			res[1] = '';
		}
	}

	return res;

}


//returns fraction from a decimal number.
function dec2frac(decimal) {

	if ( decimal == null || decimal == '' ) {
		throw 'ERR';
	}

	if  ( Math.abs(decimal - Math.round(decimal)) <= 0.000001 ) {
		return new Array(Math.round(decimal),1);
	}

	//initialise fraction
	var z = decimal;
	var n = 1;
	var d = 1;
	var epsilon = 0.000001;
	var z1 = z;
	var n1 = n;
	var d1 = d;
	var d2 = 0;

	while ( Math.abs( parseFloat(n/d) - decimal) > epsilon ) {

		z = 1 / (z1 - Math.floor(z1));
		d = parseFloat(d1*Math.floor(z)) + d2 ;
		n = Math.round(decimal * d );

		z1 = z;
		n1 = n;
		d2 = d1;
		d1 = d;

	}

	return new Array(n,d);


}


//calculates the overround for a market.
function calculateMargin(mktOcs,mktOcPrices) {

	var res = 0.0 ;

	for (var i = 0; i < mktOcs.length; i++) {
		var ocId = mktOcs[i];
		if ( mktOcPrices[ocId][1] != '' && mktOcPrices[ocId][2] != '' ) {
			res +=   mktOcPrices[ocId][2]  / ( parseFloat(mktOcPrices[ocId][1]) + parseFloat(mktOcPrices[ocId][2]) );
		}
	}

	return 100*res;
}

//updates front-end price infos.
//returns overround
function calculateNewMargin(ev_oc_id,price,mktOcs,mktOcPrices) {

	var lp = parsePrice(price);

	if (mktOcPrices[ev_oc_id] == null )  {

		mktOcPrices[ev_oc_id] = new Array();
		mktOcs.push(ev_oc_id);

	}

	mktOcPrices[ev_oc_id][1] = (lp[0] != null && lp[0] != 'ERR') ? lp[0] : '';
	mktOcPrices[ev_oc_id][2] = (lp[1] != null && lp[0] != 'ERR') ? lp[1] : '';

	return calculateMargin(mktOcs,mktOcPrices);

}

// simplify a price to its lowest terms
function simplifyPrice(num, den) {

	if (den != 0) {
		var gcd = getGreatestCommonDivisor(num,den);

		num = eval(num/gcd);
		den = eval(den/gcd);
	}

	var res = new Array();
	res[0] = num;
	res[1] = den;

	return res;
}

// greatest common denominator
function getGreatestCommonDivisor(num, den) {

	if (den == 0) {
		return 1;
	}

	var r;

	if (den > num) {
		r = den;
		den = num;
		num = r;
	}

	while (1) {
		r = eval(num % den);

		if (r==0) {
			return den;
		}

		num = den;
		den = r;
	}
}

