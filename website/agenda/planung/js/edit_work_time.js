if (window.namespace_edit_work_time_js) throw "stop"; window.namespace_edit_work_time_js = true;
"use strict";

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
    }else if(type=='days'){
        $('#'+id+' div.cell.frequency').show();
        $('#'+id+' div.cell.end').show();
        $('#'+id+' div.cell.schedule_weekday').hide();
        $('#'+id+' div.cell.week_of_month').hide();
        $('#'+id+' div.cell.schedule_month').hide();
    }else if(type=='week_of_month'){
        $('#'+id+' div.cell.frequency').hide();
        $('#'+id+' div.cell.end').show();
        $('#'+id+' div.cell.schedule_weekday').show();
        $('#'+id+' div.cell.week_of_month').show();
        $('#'+id+' div.cell.schedule_month').show();
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
    $('div.row.schedule select').each(
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

function initSelectChangeHandler(selector, name, title){
    var loc = getLocalization();
    $(selector).each(
        function() {
            //replace select by input, if no matching field
            var value=$(this).attr('value');

            //check if a child is selected
            var found=0;
            $(this).children().each(function(){
                if (found==1) return;
                if ($(this).attr('value')==value){
                    found=1;
                }
            });
            if(found==1)return;

            // find option with empty value
            $(this).children().each(function(){
                if ($(this).attr('value')==''){
                    $(this).parent().html(
                        loc[title]+'<br>'
                        +'<input name="'+name+'" value="'+value+'" class="'+name+'">'
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
            var loc = getLocalization();
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

// change create schedule button name (add/remove)
function updateScheduleButtonName(){
    var buttonChecked=$('#schedule_add input[name="exclude"]');
    var loc = getLocalization();

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


document.addEventListener("DOMContentLoaded",
    async function(){
        await loadLocalization();
        addBackButton();

        showDateTimePicker('.datetimepicker.start');
        showDatePicker('.datetime.end');

        initCheckBoxes();
        addCheckBoxHandler();

        updateScheduleButtonName();
        initScheduleFields();
        setSelectedOptions();

        //if value is not selected in a option, replace select box by input field
        initSelectChangeHandler('#tabs-schedule .frequency select', 'frequency', 'frequency_days');
        addSelectChangeHandler( '#tabs-schedule .frequency select', 'frequency', 'frequency_days');

        initSelectChangeHandler('#tabs-schedule .duration select', 'duration', 'duration_in_minutes');
        addSelectChangeHandler( '#tabs-schedule .duration select', 'duration', 'duration_in_minutes');

        setInputWidth();

        $('table#schedule_table').tablesorter({
            widgets: ["filter"],
              usNumberFormat : false
        });

    }
);

// init function
window.calcms??={};
window.calcms.init_edit_worktime_js = function(el){
}

