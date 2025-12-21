if (window.namespace_series_js) throw "stop"; window.namespace_series_js = true;
"use strict";

function addSeries() {
    $('#edit_new').toggle();
    return false;
}

function showSeries(project_id, studio_id, series_id, tab) {
    loadUrl("series.cgi?" + new URLSearchParams({
        action: "show_series",
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
    }).toString() + tab);
}

function view_series_details(project_id, studio_id, series_id) {
    var elem = $('.series_details_' + series_id).prev();
    if (elem.hasClass('active')) {
        elem.removeClass('active');
        $('.series_details_' + series_id).slideToggle(
            () => $('#series_details_' + series_id).html('')
        );
    } else {
        elem.addClass('active');
        showSeries(project_id, studio_id, series_id);
    }
}
