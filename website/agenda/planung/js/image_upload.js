// init upload
function initUploadDialog(){
    //console.log("init upload dialog")
    if(!$('#uploader').hasClass("init")){
        $('#uploader').fileUploader();
        $('#uploader').addClass("init");
        //remove multiple buttons
        var c=0;
        $('#img_upload #px_button').each(
            function(){
                if (c>0){
                    $(this).remove();
                }
                c++;
            }
        );
    }
	return false;
}

// prepare for new init
function closeImageUpload(){
    $('#uploader').removeClass("init");
    $('#pxupload_form').remove();
    $('#pxupload1_frame').remove();
    $('#px_display').remove();
}


function insertPicture(name, description, filename) {
	try {
		markup='{{ thumbs//'+filename;
		if (description !=''){
			markup+=' | '+description;
		}else{
			if (name !='') markup+=' | '+name
		}
		markup+=' }}'
		markup+="\n"
		parent.$.markItUp( { replaceWith:markup } );
		parent.$('#images').dialog("close");
	} catch(e) {
		alert("No markItUp! Editor found");
	}
}

function image_upload_dialog(){
	$('#img_upload').dialog({
		title:"image upload",
		width:600,
		height:320
	});
	return false;
}

function image_upload_callback(result){
	result.contents().find("#message").html();
    var output = '<br />' + $(this).contents().find("#message").html();
	$(id + "_text .status").html(output);
}

$(document).ready(
	function() {
		//$('#uploader').fileUploader();
	}
)

