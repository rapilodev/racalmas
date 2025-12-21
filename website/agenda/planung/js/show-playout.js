if (window.namespace_show_playout_js) throw "stop"; window.namespace_show_playout_js = true;
"use strict";

function showTable(){
    $('#playout-table').tablesorter({
        widgets: ["filter"],
        usNumberFormat : false
    });
}

document.addEventListener("DOMContentLoaded",
    function(){
        showTable();
    }
);

