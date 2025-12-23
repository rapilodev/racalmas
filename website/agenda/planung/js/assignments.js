f(window.namespace_assignments_js) throw "stop"; window.namespace_assignments_js = true;
"use strict";

var event_id = '<TMPL_VAR event_id escape=js>';

var event_ids = [];

function assign_series_events(project_id, studio_id, series_id) {
    if (project_id == '') return false;
    if (studio_id == '') return false;
    if (series_id == '') return false;

    $('#assignments_form input[name="series_id"]').val(series_id);

    event_ids = [];
    $('input[type=checkbox]:checked').each(
        function() {
            event_ids.push($(this).val())
        }
    );
    var event_id = event_ids.join(',');
    $('#assignments_form input[name="event_ids"]').val(event_id);

    var url = "assignments.cgi?project_id=" + project_id + '&studio_id=' + studio_id + '&series_id=' + series_id + '&event_ids=' + event_id + '&action=assign_events';
    console.log(url);
    $('#assignments_form').submit();
    return false;
}

function clear_selection() {
    $('#tabs-assignments input[type=checkbox]:checked').prop('checked', false);
}

selected = 0;
function select_all() {
    clear_selection();
    selected = 0;
    $('#tabs-assignments input[type=checkbox]').each(
        function() {
            if ($(this).parent().parent().css('display') == 'none') return;
            $(this).prop('checked', true);
            selected++;
        }
    );
    console.log(selected + " selected")
}

// init function
window.calcms ??= {};
window.calcms.init_assignments = function(el) {

    $('table#assignment_table').tablesorter({
        widgets: ["filter"],
        usNumberFormat: false
    });
};

