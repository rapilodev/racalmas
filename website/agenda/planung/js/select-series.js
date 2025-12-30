if (window.namespace_select_series_js) throw "stop"; window.namespace_select_series_js = true;
"use strict";

function parseUrl(url) {
    return url.toString();
}

function updateProjectStudioId() {
    var elem = $('#selectSeries #selectProjectStudio');
    if (elem.length == 0) return;

    var fields = elem.val().split("_");
    if (fields.length != 2) return;

    var projectId = fields[0];
    var studioId = fields[1];
    $('#selectSeries #projectId').attr('value', projectId);
    $('#selectSeries #studioId').attr('value', studioId);
}

function updateSeriesSelection(resultElemId) {
    updateProjectStudioId();

    var projectId = $('#selectSeries #projectId').val();
    var studioId = $('#selectSeries #studioId').val();
    var seriesId = $('#selectSeries #selectSeriesId').val();

    if (projectId == null) return;
    if (studioId == null) return;
    if (seriesId == null) return;

    const params = new URLSearchParams({
        project_id: getProjectId(),
        studio_id: getStudioId(),
        p_id: projectId,
        s_id: studioId,
        series_id: seriesId,
        resultElemId: resultElemId,
        selectSeries: 1
    });
    const $elem = $('#selectSeries #selectProjectStudio');
    if ($elem.length) {
        params.append('selectProjectStudio', '1');
    }
    let url = `select-series.cgi?${params.toString()}`;
    console.log(url);

    var elem = $("#selectSeries").parent();
    $(elem).load(url);
}

function selectSeriesAction(resultElemId) {
    var seriesId = $('#selectSeries #selectSeriesId').val();
    $('#' + resultElemId).val(seriesId);
    $('#' + resultElemId).trigger('change');
}

// init function
window.calcms ??= {};
window.calcms.init_select_series = function(el) {
    updateProjectStudioId();
    console.log("yes")
};
