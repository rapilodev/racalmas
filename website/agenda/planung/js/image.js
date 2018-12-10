
var windowOffsetX=0;
var windowOffsetY=0;

// get current selected tab by tabs-id
function getSelectedTab(id){
    var selector = '#'+id+" li.ui-tabs-active a";
    var tabValue = $(selector).attr("value");
    return tabValue;
}

function setActiveImage(elem){
    $('div.image').removeClass("active");

    if (elem){
        $(elem).addClass("active");
    }else{
        $('div.images div.image').first().addClass("active");
    }
}

// open dialog to show or edit image properties
function updateImageEditor(elem, filename, target, project_id, studio_id, series_id, event_id, pid){
	var url='image.cgi?show='+filename;
    url += '&template=image_edit.html';
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



// save image 
function saveImage(id, filename) {

    $('#imageEditor #status').html('');
    console.log("save image "+id);

	var url='image.cgi?save_image='+filename+'&project_id='+project_id+'&studio_id='+studio_id;
	$.post(
		url, 
		$("#save_img_"+id).serialize(), 
		function(data){
            var errorFound=0;

            var lines=data.split(/\n/);
            for (index in lines){
                var line=lines[index];
                if(contains(line,'ERROR:')){
                    //add error field
                    if( $('#imageEditor #status .error').length==0 ){
                        $('#imageEditor #status').append('<div class="error"></div>');
                    }
                    $('#imageEditor #status div.error').append(line);
                    errorFound++;
                }
            };
		    //console.log(data);
            if (errorFound==0){
                $('#imageEditor #status').append('<div class="ok">saved</div>');
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

// close all open dialogs
function hideImageDetails(id, filename){
	try{$('#img_editor').dialog('close');}catch(e){}

    var url='image.cgi?show='+filename+'&template=image_single.html&project_id='+project_id+'&studio_id='+studio_id;
    console.log("hideImageDetails, load url="+url)
	$("#"+id).load(url);
	return false;
}

// zoom all images in
function increaseImageSize(){
    var value=$('#content div.image').css('width');
    value=value.replace(/[^0-9]/g,'');
    if(value>200)return;
    value=parseInt(value*1.3);
    $('#content div.image').css('width', value+'px');
    $('#content div.image div').css('width', (value-12)+'px');
    $('#content div.image').css('height', value+'px');
    $('#content div.image').css('background-size', value+'px');
}

// zoom all images out
function decreaseImageSize(){
    var value=$('#content div.image').css('width');
    value=value.replace(/[^0-9]/g,'');
    if(value<50)return;
    value=parseInt(value/1.3);
    $('#content div.image').css('width', value+'px');
    $('#content div.image div').css('width', (value-12)+'px');
    $('#content div.image').css('height', value+'px');
    $('#content div.image').css('background-size', value+'px');
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
        if ( window.location.href.indexOf("&filename=") > 0)
            setActiveImage();
    }
);


/*
function hideContent(){
    $('.editor').hide();

    $(window).resize(function () {
       $('.ui-dialog').css({
            'width':  $(window).width()  - windowOffsetX,
            'height': $(window).height() - windowOffsetY,
            'position': 'absolute',
            'left':   0,
            'top':    0,
            modal: true
       });

       var imagesPos= $('div.images').position();
       var height = ( $(window).height() - imagesPos.top );
       if(height<64) height = 64;
       console.log("windowHeight="+$(window).height()+" div.images.pos.top="+imagesPos.top)
       $('div.images').css("height", height +"px");

    }).resize();

    return false;
}

function showContent(){
    $('.editor').show();
    $('#selectImage').remove();
    return false;
}


//select image load into selectImage box
function selectImageOld(project_id, studio_id, imageId, searchValue, imageUrl, series_id){
    selectImageId = imageId;
    searchValue = searchValue.replace(/[^a-zA-Z0-9]/g,'%');

    var url="image.cgi?search="+encodeURIComponent(searchValue)+'&project_id='+project_id+'&studio_id='+studio_id;

    if( (series_id!=null) && (series_id != '') ){
        url+='&series_id='+series_id;
    }

    if(imageUrl!=null){
        var filename=imageUrl.split('%2F').pop();
        url+='&filename='+filename;
    }

    var x = $(window).width()  - windowOffsetX;
    var y = $(window).height() - windowOffsetY;
    console.log("selectImage(), load url="+url);


    $('#selectImage').remove();
    $('body').append('<div id="selectImage"></div>');

    $('#selectImage').load(
        url, 
        function(){
            hideContent();
            $('#selectImage').dialog({
                appendTo: "#content",
		        title: "select image",
                top: 0,
                left: 0,
		        width: x,
		        height: y,
		        close: function( event, ui ) {
		            showContent();
                    $('#selectImage').remove();
		        }
            });
            updateImageEditor(filename);
        }
    );

    return false;    
}

// set editor image and image url to selected image
function selectThisImage(filename){
    $('#'+selectImageId).val(filename);

    var url = 'showImage.cgi?project_id='+project_id+'&studio_id='+studio_id+'&filename=' + filename;
    console.log("select image "+url);
    $('#imagePreview').prop('src',url);

    showContent(); 
    return false;
}

*/

