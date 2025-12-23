if (window.namespace_show_playout_js) throw "stop"; window.namespace_show_playout_js = true;
"use strict";

function showTable(){
    $('#playout-table').tablesorter({
        widgets: ["filter"],
        usNumberFormat : false
    });
}

// init function
window.calcms ??= {};
window.calcms.show_playout = function(el) {
    showTable();
};
