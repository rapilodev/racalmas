var region='<TMPL_VAR loc.region escape=js>';

function edit_studio(name){
    if ($('#edit_'+name).css('display')=='none'){
        $('#view_'+name).hide();
        $('#edit_'+name).show();
    }else{
        cancel_edit_studio(name);
    }
    return false;
}
function add_studio(){
    $('.editor').hide();
    $('#edit_new').show();
    return false;
}
function cancel_edit_studio(name){
    $('#edit_'+name).hide();
    $('#view_'+name).show();
    return false;
}

