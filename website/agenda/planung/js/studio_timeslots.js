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

function updateWeekdays(){
    $('.schedule input.datetimepicker').each(
        function(){
            var weekday=getWeekday(parseDateTime($(this).val()));
            $(this).parent().prev().html(weekday);
        }
    );
}

function showDates(){
    var date=$('#show_date select').val();

    var url='studio_timeslots.cgi?';
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

$(document).ready(
    function(){
    setupLocalization(function(){
        addBackButton();
        updateWeekdays();
    });

    $("#tabs").tabs({
        activate: function(){
            console.log("set style");
            $('.tablesorter-scroller-header').css('width','95%');
            $('.tablesorter-scroller-table').css('width','95%');
            $('.tablesorter-scroller-header table').css('width','95%');
            $('.tablesorter-scroller-table table').css('width','95%');
        }
    });
    $('#tabs').removeClass('ui-widget ui-widget-content ui-corner-all');

       initTextWidth();

    setTextWidth('.datetimepicker.start',     130);
    setTextWidth('.datetimepicker.end',       130);
    setTextWidth('.datetimepicker.end_date',  90);
    setTextWidth('.datetimepicker.weekday',   20);
    setTextWidth('.datetimepicker.frequency', 20);

    initRegions(region);

    showDateTimePicker('.datetimepicker.start', {
        onSelect: function(){updateWeekdays();}
    });
    showDateTimePicker('.datetimepicker.end', {
        onSelect: function(){updateWeekdays();}
    });
    showDatePicker('.datetimepicker.end_date', {
        onSelect: function(){updateWeekdays();}
    });

    setSelectedOptions();

    showYearPicker('#show_date', {
        onSelect: function(){
            showDates();
        }
    });
    showDates();                
});



