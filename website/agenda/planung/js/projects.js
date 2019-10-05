
function edit_project_assignments(name){
    if ($('#assign_'+name).css('display')=='none'){
        $('#view_'+name).hide();
        $('#edit_'+name).hide();
        $('#assign_'+name).show();
    }else{
        cancel_edit_project_assignments(name);
    }
    return false;
}

function cancel_edit_project_assignments(name){
    $('#edit_'+name).hide();
    $('#assign_'+name).hide();
    $('#view_'+name).show();
    return false;
}

function edit_project(name){
    if ($('#edit_'+name).css('display')=='none'){
        $('#view_'+name).hide();
        $('#assign_'+name).hide();
        $('#edit_'+name).show();
    }else{
        cancel_edit_project(name);
    }
    return false;
}

function cancel_edit_project(name){
    $('#edit_'+name).hide();
    $('#assign_'+name).hide();
    $('#view_'+name).show();
    return false;
}

function add_project(){
    $('.editor').hide();
    $('#edit_new').show();
    return false;
}

$(document).ready(
    function(){
        initRegions(region);
        showDatePicker('input.date');
    }
);

