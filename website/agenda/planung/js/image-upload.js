function initUploadDialog(){
    var url='image-upload.cgi?project_id='+ getProjectId()+"&studio_id="+getStudioId();
    updateContainer("image-tabs-upload", url, pageLeaveHandler);
}

function uploadImage(){
    console.log("upload")
    var form=$("#img_upload");
    var fd = new FormData(form[0]);
    var rq = $.ajax({
        url: 'image-upload.cgi',
        type: 'POST',
        data: fd,
        cache: false,
        contentType: false,
        processData: false
    });

    rq.done( function(data){
        $("#image-tabs-upload").html(data);

        var image_id = $("#upload_image_id").html();
        var filename = $("#upload_image_filename").html();
        var title    = $("#upload_image_title").html();
        var quote    = "'";

        //remove existing image from list
        $('#imageList div.images #img_'+image_id).remove();

        var url='show-image.cgi?project_id='+getProjectId()+'&studio_id='+getStudioId()+'&type=icon&filename='+filename;

        var html = '<div';
        html += ' id="img_' + image_id + '"';
        html += ' class="image" ';
        html += ' title="' + title + '" ';
        html += ' style="background-image:url(' + url + ')"';
        html += ' filename="' + filename + '"';
        html += '>';
        html += '    <div class="label">'+title+'</div>';
        html += '</div>';

        //add image to list
        $('#imageList div.images').prepend(html);

        console.log("done")
        return false;
    });

    rq.fail( function(){
        console.log("Fail")
    });

    return false;
};

