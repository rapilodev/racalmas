

// choose action depending on selected tab
function imageAction(filename){
    if(selectedImageTab=='select'){
        selectThisImage(filename);
        return false;
    }
    if(selectedImageTab=='edit'){
        editImage(filename);
        return false;
    }
}

// get current selected tab by tabs-id
function getSelectedTab(id){
    var selector='#'+id+" li.ui-tabs-active a";
    var tabValue=$(selector).attr("value");
    return tabValue;
}


//select image load into selectImage box
function selectImage(project_id, studio_id, id, value, imageUrl, series_id){
    selectImageId=id;
    value=value.replace(/[^a-zA-Z0-9]/g,'%');
    var url="image.cgi?search="+encodeURIComponent(value)+'&project_id='+project_id+'&studio_id='+studio_id;
    if((series_id!=null)&&(series_id != '')){
        url+='&series_id='+series_id;
    }
    if(imageUrl!=null){
        var filename=imageUrl.split('%2F').pop();
        url+='&filename='+filename;
    }
    $('#selectImage').load(url);
    $('#selectImage').dialog({
        appendTo: "#content",
		title:"select image",
		width:"980",
		height:640
    });
    return false;    
}

// set editor image and image url to selected image
function selectThisImage(filename){
    var url=('/agenda_files/media/thumbs/'+filename);
    $('#'+selectImageId).val(url);
    $('#imagePreview').prop('src',url);

    try{
        $('#selectImage').dialog('close');
    }catch(e){
        $('#selectImage').parent().remove();
        $('html').append('<div id="selectImage"></div>');
    };
    return false;
}

// update selectImage container by images matching to search
function searchImage(){
    var url='image.cgi?project_id='+project_id+'&studio_id='+studio_id;

    var value=$('#image_manager input[name=search]').val();
    value=value.replace(/[^a-zA-Z0-9]/g,'%');
    if (value!=null) url+='&search='+encodeURIComponent(value)

    value=$('#image_manager input[name=filename]').val();
    if (value!=null) url+='&filename='+encodeURIComponent(value);

    if(selectedImageTab=='edit'){
        url+='#image-tabs-edit'
    }
    updateContainer('selectImage',url, function(){
        $( "#image-tabs" ).tabs();
        $( "#image-tabs" ).tabs( "option", "active", 1 );
    });
    //
    return false;
}

// open dialog to edit image properties
function editImage(filename){
	$("#img_editor").load(
	    'image.cgi?show='+filename+'&template=image_edit.html&project_id='+project_id+'&studio_id='+studio_id,
		function(){
			$('#img_editor').dialog({
               appendTo: "#content",
				width:"100%",
				height:430
			});
		}
	);
}

// open dialog to show image preview
function showImage(url){
	$("#img_image").html('<img src="'+url+'" onclick="$(\'#img_image\').dialog(\'close\');return false;"/>');
	$("#img_image").dialog({
        appendTo: "#content",
		width:"100%",
		height:660
	});
}

// save image 
function saveImage(id, filename) {
	var url='image.cgi?save_image='+filename+'&project_id='+project_id+'&studio_id='+studio_id;

    //remove error field
    if($('#image-tabs .error').length>0){
        $('#image-tabs div.error').remove();
    }

	if (url!='') $.post(
		url, 
		$("#save_img_"+id).serialize(), 
		function(data){
            var lines=data.split(/\n/);
            for (index in lines){
                var line=lines[index];
                if(contains(line,'ERROR:')){
                    //add error field
                    if($('#image-tabs .error').length==0){
                        $('#image-tabs').append('<div class="error"></div>');
                    }
                    $('#image-tabs div.error').append(line);
                }
            };
		    //console.log(data);
            console.log("save "+id);
			hideImageDetails('img_'+id, filename);
		} 
	);
	return false;
}

// delete image 
function askDeleteImage(id, filename) {
    commitAction("delete image", function(){ deleteImage(id, filename) } );
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
function hideImageDetails(id,filename){
	try{$('#img_editor').dialog('close');}catch(e){}
	try{$('#img_image').dialog("close");}catch(e){}

	$("#"+id).load('image.cgi?show='+filename+'&template=image_single.html&project_id='+project_id+'&studio_id='+studio_id);
	return false;
}

// show image url
function showImageUrl(id){
	var el=document.getElementById(id);
	var input_id=id+'_input';
	var text='<input id="'+input_id+'" value="{{thumbs/'+id+'|title}}" title="3fach-Klick zum Markieren!">';
	if (el.innerHTML==text){
		el.innerHTML='';
	}else{
		el.innerHTML=text;
		var input=document.getElementById(input_id);
		input.focus();
		input.select();
		input.createTextRange().execCommand("Copy");
	}
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


