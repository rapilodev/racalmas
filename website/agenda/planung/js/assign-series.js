if (window.namespace_assign_series_js) throw "stop"; window.namespace_assign_series_js = true;

function assign_series(project_id, studio_id, series_id) {
    if (project_id == '') return false;
    if (studio_id == '') return false;
    if (series_id == '') return false;

    $('#assignments_form input[name="series_id"]').val(series_id);
    $('#assignments_form input[name="action"]').val("assign_series");
    //var url="assign-series.cgi?project_id="+project_id+'&studio_id='+studio_id+'&series_id='+series_id+'&action=assign_series';
    //console.log("url:"+url);
    $('#assignments_form').submit();
    return false;
}

function unassign_series(project_id, studio_id, series_id) {
    if (project_id == '') return false;
    if (studio_id == '') return false;
    if (series_id == '') return false;

    $('#assignments_form input[name="series_id"]').val(series_id);
    $('#assignments_form input[name="action"]').val("unassign_series");
    alert("unassign");
    //var url="assign-series.cgi?project_id="+project_id+'&studio_id='+studio_id+'&series_id='+series_id+'&action=unassign_series';
    //console.log("url:"+url);
    $('#assignments_form').submit();
    return false;
}

// init function
window.calcms ??= {};
window.calcms.init_assign_series = function(el) {

};