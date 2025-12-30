if (window.namespace_select_event_js) throw "stop"; window.namespace_select_event_js = true;
"use strict";

function updateProjectStudioId(){
    var elem=$('#selectEvent #selectProjectStudio');
    if (elem.length==0)return;

    var fields=elem.val().split("_");
    if (fields.length !=2) return;

    var projectId = fields[0];
    var studioId  = fields[1];
    $('#selectEvent #projectId').attr('value', projectId);
    $('#selectEvent #studioId').attr('value', studioId);
}

function updateSeriesId(){
    var elem=$('#selectEvent #selectSeries');
    if (elem.length==0)return;

    var seriesId = elem.val();
    $('#selectEvent #seriesId').attr('value', seriesId);
}

function updateDateRange(){
    var elem=$('#selectEvent #year');
    if (elem.length==0)return;

    var year=$(elem).val();
    var fromDate=year+'-01-01';
    var tillDate=year+'-12-31';
    if((year<1900)||(year>2100)){
        fromDate='';
        tillDate='';
    }
    $('#selectEvent #fromDate').attr('value', fromDate);
    $('#selectEvent #tillDate').attr('value', tillDate);
}

function updateEventSelection(resultElemId){
    updateProjectStudioId();
    updateSeriesId();
    updateDateRange();

    var projectId = $('#selectEvent #projectId').val();
    var studioId  = $('#selectEvent #studioId').val();
    var seriesId  = $('#selectEvent #seriesId').val();
    //var eventId   = $('#selectEvent #eventId').val();
    var from_date = $('#selectEvent #fromDate').val();
    var till_date = $('#selectEvent #tillDate').val();

    if (projectId == null) return;
    if (studioId  == null) return;
    if (seriesId  == null) return;
    //if (year      == null) return;

    const params = new URLSearchParams({
      project_id: getProjectId(),
      studio_id: getStudioId(),
      p_id: projectId,
      s_id: studioId,
      series_id: seriesId,
      resultElemId: resultElemId
    });

    if (from_date) params.set("from_date", from_date);
    if (till_date) params.set("till_date", till_date);
    if ($('#selectEvent #selectProjectStudio').length) params.set("selectProjectStudio", 1);
    if ($('#selectEvent #selectSeries').length) params.set("selectSeries", 1);
    if ($('#selectEvent #year').length) params.set("selectRange", 1);
    let url = `select-event.cgi?${params.toString()}`;
    let elem=$("#selectEvent").parent();
    url = parseUrl(url);
    console.log(url);
    $(elem).load(url);
}

// set selected eventId at external result selector
async function selectEventAction(resultElemId){
    var projectId = $('#selectEvent #projectId').val();
    var studioId  = $('#selectEvent #studioId').val();
    var seriesId  = $('#selectEvent #seriesId').val();
    var eventId   = $('#selectEvent #eventId').val();
    if (eventId<=0) return;

    var filterProjectStudio =  $('#selectEvent #selectProjectStudio').length!=0 ? 1:0;
    var filterSeries        =  $('#selectEvent #selectSeries').length!=0 ? 1:0;

    const params = new URLSearchParams({
      project_id: getProjectId(),
      studio_id: getStudioId(),
      series_id: getUrlParameter("series_id"),
      filter_project_studio: filterProjectStudio,
      filter_series: filterSeries,
      selected_project: projectId,
      selected_studio: studioId,
      selected_series: seriesId,
      selected_event: eventId
    });
    const url = `user-selected-event.cgi?${params.toString()}`;
    let json = await getJson(url);
    if (!json) return;

    console.log(`set: "${resultElemId}"="${eventId}"`)
    // set the result value
    $('#'+resultElemId).val( eventId );
    // trigger the change event for invisble form elements
    $('#'+resultElemId).trigger('change');
    return 1;
}

// init function
window.calcms ??= {};
window.calcms.init_select_event = function(el) {
    console.log("init select_event")
    updateProjectStudioId();
    updateSeriesId();
    updateDateRange();
};
