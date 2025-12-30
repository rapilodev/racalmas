if (window.namespace_user_stats_js) throw "stop"; window.namespace_user_stats_js = true;
"use strict";

document.addEventListener("DOMContentLoaded",
    function(){
        $('table#user_stats_table').tablesorter({
            widgets: ["filter"],
            usNumberFormat : false
        });
    }
);

// init function
window.calcms ??= {};
window.calcms.init_user_stats = function(el) {
}
