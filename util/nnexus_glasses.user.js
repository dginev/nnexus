// ==UserScript==
// @name NNexus Glasses
// @namespace http://nnexus.mathweb.org
// @description Enables a NNexus auto-link pass over each page in the namespace
// @include http://dlmf.nist.gov/*
// ==/UserScript==
var body = document.getElementsByTagName("body")[0];
var markup = body.innerHTML;
var params = "body="+encodeURIComponent(markup);
// Localhost for now, expect support at http://nnexus.mathweb.org
var url = "http://127.0.0.1:3000/linkentry";
req = new XMLHttpRequest();
req.open("POST",url,true);
req.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
req.setRequestHeader("Content-length", params.length);
req.onreadystatechange = function () {
	if (req.readyState === 4) {
		var response = JSON.parse(req.responseText);
		body.innerHTML = response.payload;
	}
};
req.send(params);