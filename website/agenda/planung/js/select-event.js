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
    var eventId   = $('#selectEvent #eventId').val();
    var from_date = $('#selectEvent #fromDate').val();
    var till_date = $('#selectEvent #tillDate').val();

    if (projectId == null) return;
    if (studioId  == null) return;
    if (seriesId  == null) return;
    if (year      == null) return;

    var url="select-event.cgi";
    url+="?project_id="   + getProjectId();
    url+="&studio_id="    + getStudioId();
    url+="&p_id="         + projectId;
    url+="&s_id="         + studioId;
    url+="&series_id="    + seriesId;
    url+="&resultElemId=" + encodeURIComponent(resultElemId);
    
    if (from_date !=""){
        url+="&from_date=" +encodeURIComponent(from_date);
    }

    if (till_date != ""){
        url+="&till_date=" +encodeURIComponent(till_date);
    }
    
    var elem=$('#selectEvent #selectProjectStudio');
    if (elem.length!=0){
        url+="&selectProjectStudio=1";
    }

    var elem=$('#selectEvent #selectSeries');
    if (elem.length!=0){
        url+="&selectSeries=1";
    }

    var elem=$('#selectEvent #year');
    if (elem.length!=0){
        url+="&selectRange=1";
    }
    
    var elem=$("#selectEvent").parent();
    $(elem).load(url);
}

// set selected eventId at external result selector
function selectEventAction(resultElemId){


    var projectId = $('#selectEvent #projectId').val();
    var studioId  = $('#selectEvent #studioId').val();
    var seriesId  = $('#selectEvent #seriesId').val();
    var eventId   = $('#selectEvent #eventId').val();
    if (eventId<=0) return;

    var filterProjectStudio =  $('#selectEvent #selectProjectStudio').length!=0 ? 1:0;
    var filterSeries        =  $('#selectEvent #selectSeries').length!=0 ? 1:0;
    
    var url = "user-selected-event.cgi";
    url += "?project_id="            + getProjectId();
    url += "&studio_id="             + getStudioId();
    url += "&series_id="             + getUrlParameter("series_id");
    url += "&filter_project_studio=" + filterProjectStudio;
    url += "&filter_series="         + filterSeries;
    url += "&selected_project="   + projectId;
    url += "&selected_studio="    + studioId;
    url += "&selected_series="    + seriesId;
    url += "&selected_event="     + eventId;
    $.get(url).done(function() {
        console.log("success: "+url)
    }).fail(function() {
        console.log("failed: "+url)
    });

    // set the result value
    $('#'+resultElemId).val( eventId );
    // trigger the change event for invisble form elements
    $('#'+resultElemId).trigger('change');
}

$(document).ready(
    function(){
        updateProjectStudioId();
        updateSeriesId();
        updateDateRange();
    }
);

