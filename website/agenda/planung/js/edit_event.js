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
    //$('#selectRerun input:radio').attr("value","0");
    //$('#selectRerun input:radio').prop("checked",false);
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

    var url='selectEvent.cgi?'
    url+='project_id='+getProjectId();
    url+='&studio_id='+getStudioId();
    url+='&series_id='+getUrlParameter('series_id');
    url+='&event_id='+getUrlParameter('event_id');
    url+="&resultElemId="+encodeURIComponent(resultSelector);
    url+="&till_date="+tillDate;
    url+="&selectRange=1";
    
    updateContainer('import_rerun', url);
}

function selectOtherEvent(resultSelector){
    $('#edit_event').hide();
    $('#import_rerun').show();
    $('#import_rerun_header').show('slideUp');
    if ($('#import_rerun_header').css('display')=='none')return;

    var url='selectEvent.cgi?'
    url+='project_id='+getProjectId();
    url+='&studio_id='+getStudioId();
    url+='&series_id='+getUrlParameter('series_id');
    url+='&event_id='+getUrlParameter('event_id');
    url+="&resultElemId="+encodeURIComponent(resultSelector);
    url+="&selectRange=1";
    url+="&selectProjectStudio=1";
    url+="&selectSeries=1";
    
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
        hideSelectRerun();
    });   
}

function loadEvent(projectId,studioId,seriesId,eventId, callback){

    var url="event.cgi";
    url+="?project_id="+projectId;
    url+="&studio_id="+studioId;
    url+="&series_id="+seriesId;
    url+="&event_id="+eventId;
    url+="&action=get_json";
    url+="&json=1";
    url+="&get_rerun=1";
    console.log("loadEvent: "+url)
    
    $.getJSON( url, function( event ) {
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
        
        if (callback!=null) callback();
        console.log("loadEvent done")
    });
}

// load series selection
function selectChangeSeries(resultSelector){
    var url='selectSeries.cgi?'
    url+='project_id='+getProjectId();
    url+='&studio_id='+getStudioId();
    url+='&series_id='+getUrlParameter('series_id');
    url+="&resultElemId="+encodeURIComponent(resultSelector);
    url+="&selectSeries=1";
    //console.log(url);
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

    var url='series.cgi?';
    url += '&project_id='+projectId;
    url += '&studio_id='+studioId;
    url += '&series_id='+seriesId;
    url += '&event_id='+eventId;
    url += '&new_series_id='+newSeriesId;
    url += '&action=reassign_event';
    
	$.post(
		url, 
		function(data){
            var url='event.cgi?';
            url += '&project_id='+projectId;
            url += '&studio_id='+studioId;
            url += '&series_id='+newSeriesId;
            url += '&event_id='+eventId;
            url += '&action=edit';
            window.location.href = url;
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

$(document).ready(
    function(){
        initRegions(region);
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

        pageLeaveHandler();

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
        console.log("done")
    }
);

