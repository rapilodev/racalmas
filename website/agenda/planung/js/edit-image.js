function updateCheckBox(selector, value){
    $(selector).attr('value', value)
    if (value==1){
        $(selector).prop( "checked", true );
    } else {
        $(selector).prop( "checked", false );
    }
}

function updatePublicCheckbox(elem){
    console.log(elem.prop('checked'))
    if (elem.prop('checked')){
        console.log( 'set public' );
        updateCheckBox(elem, 1);
    }else{
        console.log( 'unset public' );
        updateCheckBox(elem, 0);
    }
}


$(document).ready(
    function(){
        var publicCheckbox=$("#img_editor input[name='public']");

        updatePublicCheckbox( publicCheckbox );
        publicCheckbox.change(
            function(){
                updatePublicCheckbox($(this));
            }
        )
        console.log("image handler initialized");
        pageLeaveHandler();
    }
);

