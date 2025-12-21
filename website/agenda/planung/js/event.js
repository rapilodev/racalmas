if (window.namespace_event_js) throw "stop"; window.namespace_event_js = true;
"use strict";

// TODO: add project_id
function edit_event(event_id, series_id, studio_id, project_id, hide_series){
    var elem=$('#event_'+event_id);
    if(elem.hasClass('active')){
        elem.removeClass('active');
        $('#event_container_'+event_id).slideToggle(
            function(){
                $('#event_details_'+event_id).html('');
            }
        );
    }else{
        elem.addClass('active');
        var url="broadcast.cgi?project_id="+project_id+"&studio_id="+studio_id+"&series_id="+series_id+"&event_id="+event_id+"&action=edit";
        if ((hide_series!=null) && (hide_series!=''))url+='&hide_series=1';
        loadUrl(url);
    }
}
