var green = "#6f6";

function updateCalendarLink(){
    var link=$('a#menu_calendar');
    var url=link.attr('href');
    date=$('#start_date').attr('value');
    date=parseDateTime(date);
    date=formatDate(date);
    url=setUrlParameter(url, "date", date);
    link.attr('href',url);
}

function onDateModified(){
    var value=addMinutes($('#start_date').val(), $('#duration').val());
    $('#end_date').html(value);

    var startDate=parseDateTime($('#start_date').val());
    var weekday=getWeekday(startDate);
    $('#start_date_weekday').html(weekday);

    updateCalendarLink();
}

function selectRerun(resultSelector, tillDate){
    $('#selectRerun').show();
    $('#selectRerun input:radio.default').attr("value","1");
    $('#selectRerun input:radio.default').prop("checked",true);
    $('#selectRerun input:radio.default').click();
    $('.buttons').hide();
}

// hide buttons and events
function hideSelectRerun(resultSelector, tillDate){
    $('#selectRerun').hide();
    $('#import_rerun_header').hide('slideUp');
    $('#import_rerun').hide();

    $('.buttons').show();
    $('#edit_event').show();
}

function selectOldEventFromSeries(resultSelector, tillDate){
    $('#edit_event').hide();
    $('#import_rerun').show();
    $('#import_rerun_header').show('slideUp');
    if ($('#import_rerun_header').css('display')=='none')return;

    var url='select-event.cgi?' + new URLSearchParams({
        action : "edit",
        project_id : getProjectId(),
        studio_id : getStudioId(),
        series_id : getUrlParameter('series_id'),
        event_id : getUrlParameter('event_id'),
        resultElemId: resultSelector,
        till_date: tillDate,
        selectRange: 1
    }).toString();

    updateContainer('import_rerun', url);
}

function selectOtherEvent(resultSelector){
    $('#edit_event').hide();
    $('#import_rerun').show();
    $('#import_rerun_header').show('slideUp');
    if ($('#import_rerun_header').css('display')=='none')return;

    var url='select-event.cgi?' + new URLSearchParams({
        project_id : getProjectId(),
        studio_id : getStudioId(),
        series_id : getUrlParameter('series_id'),
        event_id : getUrlParameter('event_id'),
        resultElemId: resultSelector,
        selectRange: 1,
        selectProjectStudio: 1,
        selectSeries: 1,
    }).toString();
    updateContainer('import_rerun', url);
}

function copyFromEvent(resultSelector){
    resultSelector='#'+resultSelector;
    var eventId=$(resultSelector).val();
    if (eventId<=0){
        alert("no valid event selected");
        return
    }

    var projectId = $('#selectEvent #projectId').val();
    var studioId  = $('#selectEvent #studioId').val();
    var seriesId  = $('#selectEvent #seriesId').val();
    var eventId   = $('#selectEvent #eventId').val();

    loadEvent(projectId, studioId, seriesId, eventId, function(){
        console.log("loadEvent:",projectId, studioId, seriesId, eventId)
        console.log("loadEvent.callback: hideSelectRerun")
        hideSelectRerun();
        console.log("loadEvent.callback: updateCheckbox")
        updateCheckBox( "#edit_event input[name='published']", 1);
        console.log("loadEvent.callback: done")
    });
    console.log("copyFromEvent done")
    return 1;
}

async function loadEvent(projectId,studioId,seriesId,eventId, callback){

    var url="broadcast.cgi" + new URLSearchParams({
        action: "get_json",
        project_id : projectId,
        studio_id : studioId,
        series_id : seriesId,
        event_id : eventId,
        json: 1,
        get_rerun: 1,
    }).toString();
    console.log("modifyEvent:" + url);
    let response = await fetch(url, {
        method: 'GET',
        cache: "no-store",
    });
    let json = await response.json();
    console.log(json)
    if (json.error) showError(json.error);
    else callback(json);

    console.log("loadEvent: "+url)
    var event = json;
    $("#edit_event input[name='title']").attr('value', event.title)
    $("#edit_event input[name='user_title']").attr('value', event.user_title)
    $("#edit_event input[name='episode']").attr('value', event.episode)

    updateCheckBox( "#edit_event input[name='live']", event.live);
    updateCheckBox( "#edit_event input[name='published']", event.published);
    updateCheckBox( "#edit_event input[name='archived']", event.archived);
    updateCheckBox( "#edit_event input[name='rerun']", event.rerun);
    updateCheckBox( "#edit_event input[name='playout']", event.playout);
    updateCheckBox( "#edit_event input[name='draft']", event.draft);

    $("#edit_event textarea[name='excerpt'").html(event.excerpt);
    $("#edit_event textarea[name='user_excerpt'").html(event.user_excerpt);
    $("#edit_event textarea[name='topic']").html(event.topic);
    $("#edit_event textarea[name='content']").html(event.content);

    updateImage("#edit_event input[name='image']", event.image);
    $("#edit_event input[name='podcast_url']").attr('value', event.podcast_url);
    $("#edit_event input[name='archive_url']").attr('value', event.archive_url);

    updateDuration("#edit_event #duration", event.duration);

    if (callback != null) callback();
    console.log("loadEvent done")
}

// load series selection
function selectChangeSeries(resultSelector){
    var url='select-series.cgi?' + new URLSearchParams({
        project_id : getProjectId(),
        studio_id : getStudioId(),
        series_id : getUrlParameter('series_id'),
        resultElemId: resultSelector,
        selectSeries: 1,
    }).toString();
    console.log(url);
    updateContainer('changeSeriesContainer', url, function(){
        $('#selectSeries').removeClass('panel');
        $('#selectChangeSeries').addClass('panel');
        $('div.buttons').hide();
        $('#selectChangeSeries').show('slideUp');
    });
}

// will be fired on updatine resultSelector of series selection
function changeSeries(seriesId){
    var projectId= $('#selectSeries #projectId').val();
    var studioId= $('#selectSeries #studioId').val();
    var seriesId= getUrlParameter('series_id');
    var eventId= getUrlParameter('event_id');
    var newSeriesId= $('#changeSeriesId').val();

    if (projectId <=0 ) return;
    if (studioId <=0 ) return;
    if (seriesId <=0 ) return;
    if (eventId <=0 ) return;
    if (newSeriesId <=0 ) return;

    $('div.buttons').show();
    $('#selectChangeSeries').hide('slideUp');

    console.log('move to '+projectId+', '+studioId+', '+seriesId+', '+eventId+' -> series '+newSeriesId);
    $.post(
        url="series.cgi?" + new URLSearchParams({
            action: "reassign_event",
            project_id : projectId,
            studio_id : studioId,
            series_id : seriesId,
            event_id : eventId,
            new_series_id: newSeriesId,
        }).toString(),
        function(data){
            loadUrl("broadcast.cgi?" + new URLSearchParams({
                action: "edit",
                project_id : projectId,
                studio_id : studioId,
                series_id : newSeriesId,
                event_id : eventId,
            }).toString());
        }
    );
    return false;
}

// hide change series on abort
function hideChangeSeries(){
    $('#selectChangeSeries').hide('slideUp');
    $('#changeSeriesContainer').html('');
    $('div.buttons').show();
}

var durationUpdated=0;

function updateDuration(selector, value){
    $(selector+" option").each(function(){
        if ($(this).attr('value')==value){
            $(this).attr('selected','selected');
            durationUpdated=1;
            //console.log("updated "+value)
        }else{
            $(this).removeAttr('selected');
            //console.log("removed "+value)
        }
    })
    if(durationUpdated==0){
        console.log("added "+value)
        $(selector).append('<option value="'+value+'">'+value+'</option>');
    }
}

function updateImage(selector, value){
    if (value == null) {
        console.log("update image with null");
        return;
    }
    value=value.replace("http://","//");
    $(selector).attr('value', value);
    $(selector).parent().find('button img').attr('src',value);
}

function updateCheckBox(selector, value){
    $(selector).attr('value', value)
    if (value==1){
        $(selector).prop( "checked", true );
    } else {
        $(selector).prop( "checked", false );
    }
}

function checkExcerptField(){
    var elem=$('textarea[name="excerpt"]');
    if (elem.length==0) return 0;
    var length = elem.val().length;
    console.log("length="+length);
    if (length > 250){
        $('#excerpt_too_long').show();
    }else{
        $('#excerpt_too_long').hide();
    }
    return 1;
}

function checkExcerptExtensionField(){
    var elem=$('textarea[name="user_excerpt"]');
    if (elem.length==0) return 0;
    var length = elem.val().length;
    console.log("length="+length);
    if (length > 250){
        $('#excerpt_extension_too_long').show();
    }else{
        $('#excerpt_extension_too_long').hide();
    }
    return 1;
}

function checkFields(){
    if (checkExcerptField()){
        $('textarea[name="excerpt"]').on("keyup", function(){
            checkExcerptField();
        });
    }

    if (checkExcerptExtensionField()){
        $('textarea[name="user_excerpt"]').on("keyup", function(){
            checkExcerptExtensionField();
        });
    }
}

function copyEventToClipboard(){
    var text = $('textarea[name="excerpt"]').val()+"\n";
    if ($('textarea[name="user_excerpt"]').val()) text += $('textarea[name="user_excerpt"]').val()+"\n";
    text += $('textarea[name="topic"]').val()+"\n\n";
    text += $('textarea[name="content"]').val()+"\n";

    text = '<textarea style="none" id="clipboard">' + text + '</textarea>';
    $('body').append(text);

    var copyText = document.getElementById('clipboard');
    copyText.select();
    copyText.setSelectionRange(0, 99999);
    document.execCommand("copy");
    $(copyText).remove();
    showInfo("copied")
}

function listEvents(project_id, studio_id, series_id) {
    loadUrl( 'calendar.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        list: 1,
    }).toString());
}

function deleteFromSchedule(project_id, studio_id, series_id, start) {
    loadUrl( 'series.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        start: start,
        exclude: 1,
        show_hint_to_add_schedule: 1
    }).toString() + '#tabs-schedule');
}

async function modifyEvent(elem, action, callback){
    let form = elem.closest('form');
    let url = form.attr('action');
    let data = new URLSearchParams();
    data.append("action",action);
    for (let pair of new FormData(form.get(0))) {
        data.append(pair[0], pair[1]);
    }
    console.log("modifyEvent:" + url);
    let response = await fetch(url, {
        method: 'POST',
        body: data,
        cache: "no-store",
    });
    let json = await response.json();
    console.log(json)
    if (json.error) showError(json.error);
    else callback(json);
}

function createEvent2(elem, action){
    modifyEvent(elem, action, function(json){
        if (json.status == "created"){
            showInfo("created");
            let event = json.entry;
            let url="event.cgi?" + new URLSearchParams({
                action : "edit",
                project_id : event.project_id,
                studio_id : event.studio_id,
                series_id : event.series_id,
                event_id : event.event_id
            }).toString();
            loadUrl(url);
        } else showError("Could not create event");
    })
}

async function saveEvent(elem, action){
    console.log("saveEvent")
    modifyEvent(elem, action, function(json){
        if (json.status == "saved") showInfo("event saved");
        else showError(json.error);
    })
}

async function deleteEvent(elem, action){
    console.log("deleteElem");
    let form = elem.closest('form');
    let event_id = form.find("input[name='event_id']").val();
    commitForm('event_'+event_id, 'delete', 'delete event', function(){
        modifyEvent(elem, action, function(json) {
            if (json.status == "deleted") {
                showInfo("Event deleted");
                $('#content').remove();
                getBack();
            } else showError(json.error);
        })
    })
}

function uploadRecording(project_id, studio_id, series_id, event_id){
    loadUrl( "audio-recordings.cgi?" + new URLSearchParams({
        action: "show",
        project_id : project_id,
        studio_id : studio_id,
        series_id : series_id,
        event_id : event_id,
    }).toString());
}

function downloadRecording(project_id, studio_id, series_id, event_id){
    loadUrl( "event.cgi?" + new URLSearchParams({
        action: "download",
        project_id : project_id,
        studio_id : studio_id,
        series_id : series_id,
        event_id : event_id
    }).toString());
}

async function loadHelpTexts () {
    var url = "help-texts.cgi?" + new URLSearchParams({
        project_id : getProjectId(),
        studio_id : getStudioId(),
        action : "get_json",
        json: 1,
        get_rerun: 1,
    }).toString();
    console.log("modifyEvent:" + url);
    let response = await fetch(url, {
        method: 'GET',
        cache: "no-store",
    });
    let json = await response.json();
    console.log(json)
    if (json.error){
        showError(json.error);
        return
    }

    var data = json;
    for (col in data){
        let value = data[col];
        console.log(col+" "+value)
        $(`input[name="${col}"]`).hover(function() {
            $(this).attr("title",value)
        });
        $(`textarea[class="${col}"]`).hover(function() {
            $(this).attr("title",value)
        });
    }
}

$(document).ready(
    function() {
        showDateTimePicker('#start_date');

        $('input[type="checkbox"]').click(
            function(){
                if ($(this).attr('value')=='1'){
                    $(this).attr('value','0');
                }else{
                    $(this).attr('value','1');
                }
            }
        );

        if($('#calendar').length==0){
            $('#back_to_calendar').hide();
        }
        onDateModified();

        checkFields();

        $('textarea').autosize();

        // unset published on setting draft
        $("#edit_event input[name='draft']").change(
            function(){
                if ($(this).val()==1){
                    console.log( 'unset published' );
                    updateCheckBox("#edit_event input[name='published']", 0);
                }
            }
        )
        loadHelpTexts();
        console.log("done");
    }
);

