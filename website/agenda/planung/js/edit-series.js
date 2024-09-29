/*
    show a series, its template, users and events
*/


// set checkbox values checked depending on value
function initCheckBoxes(){
    $('div.editor input[type="checkbox"]').each(
        function () {
            if ($(this).attr('value')=='1'){
                $(this).attr('value','1');
                $(this).attr('checked','checked');
            }else{
                $(this).attr('value','0');
                $(this).attr('checked',null);
            }
        }
    );
}

// add checkbox handler to change value on click
function addCheckBoxHandler(){
    $('div.editor input[type="checkbox"]').click(
        function () {
            if ($(this).attr('value')=='1'){
                $(this).attr('value','0');
            }else{
                $(this).attr('value','1');
            }
        }
    );
}

// show/hide series member edit
function edit_series_members(series_id){
    $('.edit_series_members_'+series_id).toggle();
}

// show/hide schedule fields depending on period type for a given schedule element
function showScheduleFields(id){
    var select='#'+id+' select[name="period_type"]';
    var type=$(select).val();
    //hide and show values for different schedule types
    if (type=='single'){
        $('#'+id+' div.cell.frequency').hide();
        $('#'+id+' div.cell.end').hide();
        $('#'+id+' div.cell.schedule_weekday').hide();
        $('#'+id+' div.cell.week_of_month').hide();
        $('#'+id+' div.cell.schedule_month').hide();
        $('#'+id+' div.cell.nextDay').hide();
    }else if(type=='days'){
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
    }
}

// show/hide schedule fields for all schedules
function initScheduleFields(){
    $('div.row.schedule form').each(function(){
        var id = $(this).attr('id');
        if(contains(id,'schedule_'))showScheduleFields(id);
    });

}

// preselect options in select boxes
function setSelectedOptions(){
    $('#tabs-schedule select').each(
        function(){
            var value=$(this).attr('value');
            if (value==null) return;
            if (value=='') return;
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

function initSelectChangeHandler(selector, name, title){
    $(selector).each(
        function(){
            //replace select by input, if no matching field
            var value=$(this).attr('value');

            //check if a child is selected
            var found=0;
            $(this).children().each(function(){
                if (found==1) return;
                if ($(this).attr('value')==value){
                    found=1;
                    $(this).attr('selected');
                }else{
                    $(this).removeAttr('selected');
                }
            });
            if(found==1){
                return;
            }

            // find option with empty value
            $(this).children().each(function(){
                if ($(this).attr('value')==''){
                    // add selected option
                    $(this).parent().append('<option value="'+value+'" selected="1">'+value+' Min</option>');
                    // add option to edit field
                    $(this).parent().append(
                        loc[title]+'<br>'+'<input name="'+name+'" value="'+value+'" class="'+name+'">'
                    );
                }
            });
            setInputWidth();
        }
    );
}

//add handler to replace select boxes by input fields if choosen value is empty
function addSelectChangeHandler(selector, name, title){
    $(selector).each(
        function(){
            $(this).change(function(){
                if($(this).val()==''){
                    //replace select by input, copy value from select to input,
                    var value=$(this).attr('value');
                    $(this).parent().html(
                        loc[title]+'<br>'
                        +'<input name="'+name+'" value="'+value+'" class="'+name+'">'
                    );
                }else{
                    //set selected value to select
                    $(this).attr('value',$(this).val());
                }
                setInputWidth();
            });
        }
    );
}

// print selected weekday before datetime picker
function updateWeekdays(){
    $('.schedule input.datetimepicker.start').each(
        function(){
            var weekday=getWeekday(parseDateTime($(this).val()));
            if (weekday==null) weekday='';
            if (weekday=='undefined,') weekday='';
            $(this).parent().prev().html(weekday);
        }
    );

    $('#tabs-events td.date').each(
        function(){
            var weekday=getWeekday(parseDateTime($(this).text()));
            //console.log(weekday)
            if (weekday==null) weekday='';
            if (weekday=='undefined,') weekday='';
            $(this).prev().html(weekday);
        }
    );
}

// change create schedule button name (add/remove)
function updateScheduleButtonName(){
    var buttonChecked=$('#schedule_add input[name="exclude"]');

    if(buttonChecked.prop('checked')){
        $('#addScheduleButton').text(loc['label_remove_schedule']);
    }else{
        $('#addScheduleButton').text(loc['label_add_schedule']);
    }
}

// set css class on parent div to add margin on input fields
function setInputWidth(){
    $('#content .editor div.cell input').each(function(){
        $(this).parent().addClass('containsInput');
        $(this).parent().removeClass('containsSelect');
    });
    $('#content .editor div.cell select').each(function(){
        $(this).parent().addClass('containsSelect');
        $(this).parent().removeClass('containsInput');
    });

    $('#content .editor div.cell select[name="period_type"]').each(function(){
        if($(this).val()=='single'){
            $(this).parent().addClass('isSingle');
            $(this).addClass('isSingle');
        }else{
            $(this).parent().removeClass('isSingle');
            $(this).removeClass('isSingle');
        }
    });

}

function checkExcerptField(){
    var elem = $('textarea[name="excerpt"]');
    if (elem.length==0) return;
    var length = elem.val().length;
    console.log("length="+length);
    if (length > 250){
        $('#excerpt_too_long').show();
    }else{
        $('#excerpt_too_long').hide();
    }
}

function checkFields(){
    checkExcerptField();
    $('textarea[name="excerpt"]').on("keyup", function(){
        checkExcerptField();
    });
}


$(document).ready(
    function(){
        setupLocalization(
            function(){
                addBackButton();
                updateWeekdays();
            }
        );

        showDateTimePicker('input.datetimepicker.start', {
            onSelect: function(){updateWeekdays();}
        });
        showDatePicker ('input.datetimepicker.end', {
            onSelect: function(){updateWeekdays();}
        });

        initCheckBoxes();
        addCheckBoxHandler();

        setTabs('#tabs');

        updateScheduleButtonName();
        initScheduleFields();
        setSelectedOptions();

        //if value is not selected in a option, replace select box by input field
        initSelectChangeHandler('#tabs-schedule .frequency select', 'frequency', 'frequency_days');
        addSelectChangeHandler( '#tabs-schedule .frequency select', 'frequency', 'frequency_days');

        initSelectChangeHandler('#tabs-schedule .duration select', 'duration', 'duration_in_minutes');
        addSelectChangeHandler( '#tabs-schedule .duration select', 'duration', 'duration_in_minutes');

        setInputWidth();

        checkFields();

//        $('#content div.cell input').change( function(){setInputWidth()});
//        $('#content div.cell select').change(function(){setInputWidth()});

        $('textarea').autosize();

        $('table#schedule_table').tablesorter({
            widgets: ["filter"],
              usNumberFormat : false
        });

    }
);


