// ==UserScript==
// @name NNexus Glasses
// @namespace http://nnexus.mathweb.org
// @description Enables a NNexus auto-link pass over each page in the namespace
// @include http://dlmf.nist.gov/*
// @include http://www.zentralblatt-math.org/zbmath/*
// @include http://www.zentralblatt-math.org/zmath/*
// @include http://en.wikipedia.org/*
// @include http://arxmliv.kwarc.info/files/*
// @include http://search.mathweb.org/zbl-sandbox/*
// @include http://www.bbc.co.uk/sport/0/*
// @include https://zbmath.org/*
// @include http://mmlquery.mizar.org/*
// ==/UserScript==
var body = document.getElementsByTagName("body")[0];
if (! body) {body = document.documentElement;}
var markup = body.innerHTML;
// Prepare page for auto-linking at the showcase server
var params = "body="+encodeURIComponent(markup);
var url = "//nnexus.mathweb.org/linkentry";
req = new XMLHttpRequest();
req.open("POST",url,true);
req.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
req.setRequestHeader("Content-length", params.length);
req.onreadystatechange = function () {
  if (req.readyState === 4) {
    var response = JSON.parse(req.responseText);
    // Rewrite the page with the now embedded NNexus links
    body.innerHTML = response.payload;
  }
};
req.send(params); 

// Style the links
function addCss(cssString) {
  var head = document.getElementsByTagName('head')[0];
  if (!head) {return};
  var newCss = document.createElement('style');
  newCss.type = "text/css";
  newCss.innerHTML = cssString;
  head.appendChild(newCss);
}
addCss('a.nnexus_concept:link {color:#FFCC00 !important;}\
a.nnexus_concept:visited {color:#995C00 !important;}\
a.nnexus_concept:hover {color:#FF9900 !important;}\
a.nnexus_concept:active {}\
a.nnexus_concepts:link {color:#FF944D !important;}\
a.nnexus_concepts:visited {color:#B26836 !important;}\
a.nnexus_concepts:hover {color:#E68545 !important;}\
a.nnexus_concepts:active {}'); 