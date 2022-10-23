var region='<TMPL_VAR loc.region escape=js>';

function add_studio(){
    $('.editor').hide();
    $('#edit_new').show();
    return false;
}

function edit_studio(elem, name){
    if ($('#edit_'+name).css('display')=='none'){
        $('#view_'+name).hide();
        $('#edit_'+name).show();
        elem.text(elem.data("cancel"));
        elem.addClass("text");
    }else{
        cancel_edit_studio(elem, name);
    }
    return false;
}

function cancel_edit_studio(elem, name){
    $('#edit_'+name).hide();
    $('#view_'+name).show();
    elem.text(elem.data("action"));
    elem.removeClass("text");
    return false;
}

