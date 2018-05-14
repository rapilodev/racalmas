
var windowOffsetX=32;
var windowOffsetY=32;

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
        $('div.image').first().addClass("active");
    }
}

// open dialog to show or edit image properties
function updateImageEditor(filename, elem){
	var url='image.cgi?show='+filename+'&template=image_edit.html&project_id='+project_id+'&studio_id='+studio_id
    console.log("updateImageEditor "+url);

	$("#img_editor").load(
        url,
        function(){
            setActiveImage(elem);
        }
	);
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

// update selectImage container by images matching to search
function searchImage(){
    var url='image.cgi?project_id='+project_id+'&studio_id='+studio_id;

    var value=$('#image_manager input[name=search]').val();
    value=value.replace(/[^a-zA-Z0-9]/g,'%');
    if (value!=null) url+='&search='+encodeURIComponent(value)

    var filename=$('#image_manager input[name=filename]').val();
    var filename = filename.replace(/^.*[\\\/]/, '')
    if (filename!=null) url+='&filename='+encodeURIComponent(filename);

    if(selectedImageTab!='upload'){
        url+='#image-tabs-select'
    }

    console.log("searchImage(), load url="+url)
    updateContainer('selectImage', url, function(){
        $( "#image-tabs" ).tabs();
        if (filename!=null) updateImageEditor(encodeURIComponent(filename));
    });
    return false;
}    

function hideContent(){

    $(window).resize(function () {
       $('.ui-dialog').css({
            'width':  $(window).width()  - windowOffsetX,
            'height': $(window).height() - windowOffsetY,
            'left':   windowOffsetX/2+'px',
            'top':    windowOffsetY/2+'px',
            modal: true
       });
    }).resize();

    /*
    $('.editor').each(
        function(){
            $(this).hide();
        }
    );
    */
    return false;
}

function showContent(){
    /*
    $('.editor').each(
        function(){
            $(this).show();
        }
    );
    */
    $('#selectImage').remove();
    return false;
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


//select image load into selectImage box
function selectImage(project_id, studio_id, imageId, searchValue, imageUrl, series_id){
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

    var x=$(window).width()  - windowOffsetX;
    var y=$(window).height() - windowOffsetY;
    console.log("selectImage(), load url="+url)

    $('#selectImage').remove();
    $('body').append('<div id="selectImage"></div>');
    
    $('#selectImage').load(
        url, 
        function(){
            hideContent();

            $('#selectImage').dialog({
                appendTo: "#content",
		        title:"select image",
		        width:x,
		        height:y,
		        close: function( event, ui ) { 
		            showContent();
                    $('.ui-dialog').remove();
		        }
            });
            updateImageEditor(filename);
        }
    );

    return false;    
}


