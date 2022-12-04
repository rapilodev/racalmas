$(document).ready(
    function(){
        $('table#user_stats_table').tablesorter({
            widgets: ["filter"],
            usNumberFormat : false
        });
    }
);
