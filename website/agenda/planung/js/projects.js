if (window.namespace_projects_js) throw "stop"; window.namespace_projects_js = true;
"use strict";

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

function edit_project(elem, name){

    if ($('#edit_'+name).css('display')=='none'){
        $('#view_'+name).hide();
        $('#assign_'+name).hide();
        $('#edit_'+name).show();
        elem.text(elem.data("cancel"));
        elem.addClass("text");
    }else{
        cancel_edit_project(elem, name);
    }
    return false;
}

function cancel_edit_project(elem, name){
    $('#edit_'+name).hide();
    $('#assign_'+name).hide();
    $('#view_'+name).show();
    elem.text(elem.data("action"));
    elem.removeClass("text");
    return false;
}

function add_project(){
    $('.editor').hide();
    $('#edit_new').show();
    return false;
}

document.addEventListener("DOMContentLoaded",
    function(){
        showDatePicker('input.date');
    }
);

