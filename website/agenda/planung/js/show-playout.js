
function showTable(){
    $('#playout-table').tablesorter({
        widgets: ["filter"],
        usNumberFormat : false
    });
}

$(document).ready(
    function(){
        showTable();
    }
);

