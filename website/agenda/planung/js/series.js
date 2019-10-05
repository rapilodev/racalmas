function add_series(){
    $('#edit_new').toggle();
    return false;
}

function view_series_details(series_id, studio_id, project_id){
    var elem=$('.series_details_'+series_id).prev();
    if(elem.hasClass('active')){
        elem.removeClass('active');
        $('.series_details_'+series_id).slideToggle(
            function(){
                $('#series_details_'+series_id).html('');
            }
        );
    }else{
        elem.addClass('active');
        var url="series.cgi?project_id="+project_id+"&studio_id="+studio_id+"&series_id="+series_id+"&action=show";
        load(url);
    }
}

/*

function edit_series(name){
    if ($('#edit_'+name).css('display')=='none'){
        $('#edit_'+name).show();
    }else{
        cancel_edit_series(name);
    }
    return false;
}

function cancel_edit_series(name){
    $('#edit_'+name).hide();
    return false;
}

/*
function edit_scan(name){
    if ($('#scan_'+name).css('display')=='none'){
        $('#scan_'+name).show();
    }else{
        cancel_edit_scan(name);
    }
    return false;
}

function cancel_edit_scan(name){
    $('#scan_'+name).hide();
    return false;
}

function edit_schedule(name){
    if ($('#edit_schedule_'+name).css('display')=='none'){
        $('#edit_schedule_'+name).show();
    }else{
        cancel_edit_schedule(name);
    }
    return false;
}

function cancel_edit_schedule(name){
    $('#edit_schedule_'+name).hide();
    return false;
}

function show_schedule(name){
    if ($('#show_schedule_'+name).css('display')=='none'){
        $('#show_schedule_'+name).show();
    }else{
        hide_schedule(name);
    }
    return false;
}

function hide_schedule(name){
    $('#show_schedule_'+name).hide();
    return false;
}

*/
