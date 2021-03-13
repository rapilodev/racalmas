
// get current selected tab by tabs-id
function getSelectedTab(id){
    var selector = '#'+id+" li.active a";
    var tabValue = $(selector).attr("value");
    return tabValue;
}

function setActiveImage(elem){
    if ( !elem ) elem = $('div.images div.image').first();
    $('div.image').removeClass("active");
    $('div.image').addClass("inactive");
    elem.addClass("active");
    elem.removeClass("inactive");
}

function updateActiveImage(){
    $('div.images div.image.active').click();
}

// show or edit image properties
function updateImageEditor(elem, filename, target, project_id, studio_id, series_id, event_id, pid){
    var url='image.cgi?show='+filename;
    url += '&template=edit-image.html';
    url += '&target=' + target;
    url += '&project_id='+project_id;
    url += '&studio_id='+studio_id;
    if ( (series_id != null) && (series_id != '') ) url += '&series_id='+series_id;
    if ( (event_id != null)  && (event_id != '')  ) url += '&event_id='+event_id;
    if ( (pid != null)  && (pid != '')  ) url += '&pid='+pid;

    console.log("updateImageEditor "+url);

    $("#img_editor").load(
        url,
        function(){
            setActiveImage(elem);
        }
    );
}

// build search url and load
function searchImage(target, project_id, studio_id, series_id, event_id, pid){
    var url='image.cgi?';

    var value=$('#image_manager input[name=search]').val();
    value=value.replace(/[^a-zA-Z0-9]/g,'%');
    if (value!=null) url+='&search='+encodeURIComponent(value)

    var filename=$('#image_manager input[name=filename]').val();
    var filename = filename.replace(/^.*[\\\/]/, '')
    if (filename!=null) url+='&filename='+encodeURIComponent(filename);

    url += '&target=' + target;
    url += '&project_id='+project_id;
    url += '&studio_id='+studio_id;
    if ( (series_id != null) && (series_id != '') ) url += '&series_id='+series_id;
    if ( (event_id != null)  && (event_id != '')  ) url += '&event_id='+event_id;
    if ( (pid != null)  && (pid != '')  ) url += '&pid='+pid;


    load(url);
}    

// disable public, save and update form on success
function depublishImage(id, filename){
    $('#save_img_'+id+' input[name="public"]').val("0");
    saveImage(id, filename);
}

// enable public and save and update form on success
function publishImage(id, filename){
    $('#save_img_'+id+' input[name="public"]').val("1");
    saveImage(id, filename);
}

// save image 
function saveImage(id, filename) {

    $('#imageEditor #status').html('');
    console.log("save image "+id+" ");

    var url='image.cgi?save_image='+filename+'&project_id='+project_id+'&studio_id='+studio_id;
    $.post(
        url, 
        $("#save_img_"+id).serialize(), 
        function(data){
            var errorFound=0;
            data.split(/\n/).forEach(
                function(line){
                    if(contains(line, 'ERROR:')){
                        //add error field
                        if( $('#imageEditor #status .error').length==0 ){
                            $('#imageEditor #status').append('<div class="error"></div>');
                        }
                        $('#imageEditor #status div.error').append(line);
                        errorFound++;
                    }
               }
            );
            if (errorFound==0){
                $('#imageEditor #status').append('<div class="ok">saved</div>');
                updateActiveImage();
            }
            hideImageDetails('img_'+id, filename);
        } 
    );
    return false;
}

// delete image 
function askDeleteImage(id, filename) {
    commitAction("delete image", 
        function(){ 
            deleteImage(id, filename) 
        } 
    );
}

// delete image 
function deleteImage(id, filename) {
    //alert("deleteImage");return;
    $("#"+id).load('image.cgi?delete_image='+filename+'&project_id='+project_id+'&studio_id='+studio_id);
    hideImageDetails('img_'+id, filename);
    $("#"+id).hide('drop');
    return false;
}

function hideImageDetails(id, filename){
    var url='image.cgi?show='+filename+'&template=image-single.html&project_id='+project_id+'&studio_id='+studio_id;
    console.log("hideImageDetails, load url="+url)
    $("#"+id).load(url);
    return false;
}

function selectImage( searchValue, imageUrl, target, project_id, studio_id, series_id, event_id, pid){
    searchValue = searchValue.replace(/[^a-zA-Z0-9]/g,'%');

    var url="image.cgi";
    url += "?target="+target;
    url += '&project_id='+project_id
    url += '&studio_id='+studio_id;

    if( (series_id!=null) && (series_id != '') ){
        url+='&series_id='+series_id;
    }
    if( (event_id!=null) && (event_id != '') ){
        url+='&event_id='+event_id;
    }
    if( (pid!=null) && (pid != '') ){
        url+='&pid='+pid;
    }

   url += "&search="+encodeURIComponent(searchValue)
 
    if(imageUrl!=null){
        var filename=imageUrl.split('%2F').pop();
        url+='&filename='+filename;
    }
    load(url);
}

function assignImage(filename, target, project_id, studio_id, series_id, event_id, pid){
    var url = target +".cgi";
    url += "?setImage=" + filename;
    url += '&project_id=' + project_id;
    url += '&studio_id=' + studio_id;

    if( (series_id != null) && (series_id != '') ){
        url += '&series_id=' + series_id;
    }

    if( (event_id != null) && (event_id != '') ){
        url += '&event_id=' + event_id;
    }

    if( (pid!=null) && (pid != '') ){
        url+='&pid='+pid;
    }

    load(url);
}

$(document).ready(
    function(){

        $('div.images').on( 'click', 'div.image', function(){
            var elem      = $(this);
            var filename  = elem.attr("filename");
            elem = elem.parent();
            var target    = elem.attr("target");
            var projectId = elem.attr("projectId");
            var studioId  = elem.attr("studioId");
            var seriesId  = elem.attr("seriesId");
            var eventId   = elem.attr("eventId");
            var pid       = elem.attr("pid");
 
            updateImageEditor($(this), filename, target, projectId, studioId, seriesId, eventId, pid); 
            return false;
        });

        if ( window.location.href.indexOf("&filename=") > 0)
            setActiveImage();
            updateActiveImage();
    }
);


