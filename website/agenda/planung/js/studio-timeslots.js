if (window.namespace_studio_timeslotes_js) throw "stop"; window.namespace_studio_timeslots_js = true;
"use strict";

// preselect options in select boxes
function setSelectedOptions(){
    $('#edit_schedule select').each(
        function(){
            var value=$(this).attr('value');
            if (value==null) return;
            $(this).children().each(
                function(){
                    if ($(this).attr('value')==value){
                        $(this).attr('selected','selected');
                    }
                }
            );
        }
    );
}

function showDates(){
    var date=$('#show_date select').val();

    var url='studio-timeslots.cgi?';
    url+='project_id='+getProjectId();
    url+='&studio_id='+getStudioId();
    url+='&action=show_dates';
    url+='&show_date='+date;

    updateContainer(
        'show_schedule',
        url,
        function(){
            initTable();
        }
    );
}

function initTable(){
    $('#schedule_table').tablesorter({
        widgets: ["filter","scroller"],
            widgetOptions : {
                scroller_height : 500,
                scroller_width : '100%',
                scroller_barWidth : 18,
                scroller_upAfterSort: true,
                scroller_jumpToHeader: true,
                scroller_idPrefix : 's_'
            },
              usNumberFormat : false
    });
    $('.tablesorter-scroller-header').css('width','95%');
    $('.tablesorter-scroller-table').css('width','95%');
    $('.tablesorter-scroller-header table').css('width','95%');
    $('.tablesorter-scroller-table table').css('width','95%');
}

// show/hide schedule fields depending on period type for a given schedule element
function showScheduleFields(id){
    var select='#'+id+' select[name="period_type"]';
    var type=$(select).val();
    //hide and show values for different schedule types
    if (type=='days' || type=='') {
        $('#'+id+' div.cell.frequency').show();
        $('#'+id+' div.cell.end').show();
        $('#'+id+' div.cell.schedule_weekday').hide();
        $('#'+id+' div.cell.week_of_month').hide();
        $('#'+id+' div.cell.schedule_month').hide();
        $('#'+id+' div.cell.nextDay').hide();
    }else if(type=='week_of_month'){
        $('#'+id+' div.cell.frequency').hide();
        $('#'+id+' div.cell.end').show();
        $('#'+id+' div.cell.schedule_weekday').show();
        $('#'+id+' div.cell.week_of_month').show();
        $('#'+id+' div.cell.schedule_month').show();
        $('#'+id+' div.cell.nextDay').show();
    }else{
        alert("invalid schedule type");
    }
}

function initScheduleFields(){
    $('div.row.schedule form').each(function(){
        var id = $(this).attr('id');
        if(contains(id,'schedule_'))showScheduleFields(id);
    });
}

// init function
window.calcms ??= {};
window.calcms.studio_timeslot = async function(el) {
    await loadLocalization();
    addBackButton();
    
    setTabs('#tabs');
    initTextWidth();
    
    setTextWidth('.datetimepicker.start',     130);
    setTextWidth('.datetimepicker.end',       130);
    setTextWidth('.datepicker.end_date',  90);
    setTextWidth('.datetimepicker.weekday',   20);
    setTextWidth('.datetimepicker.frequency', 20);
    
    showDateTimePicker('.datetimepicker.start');
    showDateTimePicker('.datetimepicker.end');
    showDatePicker('.datepicker.end_date');
    
    initScheduleFields();
    setSelectedOptions();
    
    showYearPicker('#show_date', {
        onSelect: function(){
            showDates();
        }
    });
    showDates();
};
