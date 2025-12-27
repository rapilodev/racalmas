if (window.namespace_select_series_js) throw "stop"; window.namespace_select_series_js = true;
"use strict";

function parseUrl(url) {
    return url.toString();
}

function updateProjectStudioId(){
    var elem=$('#selectSeries #selectProjectStudio');
    if (elem.length==0)return;

    var fields=elem.val().split("_");
    if (fields.length !=2) return;

    var projectId = fields[0];
    var studioId  = fields[1];
    $('#selectSeries #projectId').attr('value', projectId);
    $('#selectSeries #studioId').attr('value', studioId);
}

function updateSeriesSelection(resultElemId){
    updateProjectStudioId();

    var projectId = $('#selectSeries #projectId').val();
    var studioId  = $('#selectSeries #studioId').val();
    var seriesId  = $('#selectSeries #selectSeriesId').val();

    if (projectId == null) return;
    if (studioId  == null) return;
    if (seriesId  == null) return;

    var url="select-series.cgi";
    url+="?project_id="   + getProjectId();
    url+="&studio_id="    + getStudioId();
    url+="&p_id="         + projectId;
    url+="&s_id="         + studioId;
    url+="&series_id="    + seriesId;
    url+="&resultElemId=" + encodeURIComponent(resultElemId);
    url+="&selectSeries=1";

    var elem=$('#selectSeries #selectProjectStudio');
    if (elem.length!=0){
        url+="&selectProjectStudio=1";
    }

    url = parseUrl(url);
    var elem=$("#selectSeries").parent();
    console.log(url);
    $(elem).load(url);
}

function selectSeriesAction(resultElemId){
    var seriesId=$('#selectSeries #selectSeriesId').val();
    //if (seriesId<=0) return;
    // set the result value
    $('#'+resultElemId).val( seriesId );
    // trigger the change event for invisble form elements
    $('#'+resultElemId).trigger('change');
}

// init function
window.calcms ??= {};
window.calcms.select_series = function(el) {
    updateProjectStudioId();
    console.log("yes")
};
