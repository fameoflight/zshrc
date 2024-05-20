// ==UserScript==
// @name         Charles Schwab Enahancements
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  Improve Schwab Experience
// @author       Hemant Verma
// @match        https://client.schwab.com/*
// @grant        none
// ==/UserScript==

(function() {
    // delete bottom quote box
    // Note(hemantv): I find it very annoying and never really use it

    document.getElementById('lblComplianceNo').remove();

    document.getElementById('quickQuote').remove();

    document.getElementsByClassName('section-footnotes')[0].remove();

    document.getElementById('footer').remove();
})();


