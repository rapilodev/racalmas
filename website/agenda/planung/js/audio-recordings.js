
function showProgress(){
    $('#progress').slideDown();
    return false;
}

function hideProgress(){
    $('#progress').slideUp();
    return false;
}

function playAudio(path){
    var url='recordings/'+path;
    var win = window.open(url, '_blank');
}

function changeFile(fileInput){
    var file = fileInput.files[0];
    var size = file.size / (1000*1000);
    $('#uploadSize').html(size + " MB");
    if (size > 700){
        $('#uploadButton').hide();
        showError("file is too large. maximum size is 700 MB!");
    }else{
        $('#uploadButton').show();
    }
}

function showError(error){
    $('#error').html(error);
    $('#error').show();
}

function hideError(){
    $('#error').hide();
}

function showFinished(){
    $('#info').html("upload finished");
    $('#info').show();
}

function hideFinished(){
    $('#info').hide();
}

function roundSize(size){
    const MB = 1000*1000;
    var value= Math.round(size/MB);
    value += '';
    //if (value.indexOf('.')<0)value+='.0';
    return value;
}

function formatTime(duration){
    if (duration > 3600) return Math.ceil(duration/3600) + " hours";
    if (duration > 60)   return Math.ceil(duration/60)   + " minutes";
    return duration += " seconds";
}

function uploadFile(uploadButton){
    hideFinished();
    hideError();
    showProgress();
    var request=$.ajax({
        url: 'audio-recordings.cgi',
        type: 'POST',
        data: new FormData($('#audio_recordings_upload')[0]),
        cache: false,
        contentType: false,
        processData: false,
        xhr: function() {
            var start = Math.floor(Date.now()/1000);
            var update = start;
            var xhr = new window.XMLHttpRequest();
            $('#uploadButton').hide();
            if (xhr.upload) {
                $('#progress_done').html(0);
                $('#progress_todo').html(100);
                $('#progress_done').css("width", 0 + "%")
                $('#progress_todo').css("width", (100)+ "%")
                $('#progress_container').show();

                xhr.upload.addEventListener(
                    'progress', 
                    function(data) {
                        if (!data.lengthComputable) return;
                        let now = Math.floor(Date.now()/1000);
                        if (now == update) return;
                        update = now;

                        let loaded = roundSize(data.loaded);
                        if (loaded == 0) return;
                        let total = roundSize(data.total);
                        let duration = now - start;
                        if (duration == 0) return;
                        let remaining = Math.round( (duration * data.total / data.loaded) - duration );
                        remaining = formatTime(remaining);
                        duration = formatTime(duration);
  
                        var perc = Math.round(100*loaded/total);
                        $('#progress_done').css("width", perc + "%")
                        $('#progress_todo').css("width", (100-perc)+ "%")
                        $('#progress_done').html(loaded + " MB");
                        $('#progress_todo').html(remaining+" left");

                        let content = total + " MB<br>";
                         $('#progressLabel').html(content);
                    } , 
                    false
                );
            }
            return xhr;
        }
    });
    
    request.fail(
        function(jqXHR, textStatus, errorThrown ){
            showError("error: "+errorThrown);
            hideProgress();
            hideFinished();
            $('#uploadButton').show();
        }
    );

    request.done(
        function(data){
            showFinished();
            hideProgress();
            hideError();
            $('#uploadButton').show();
        }
    );
}


$( document ).ready(
    function() {
        $('#file').on( 'change', 
            function(){
                changeFile( this );
                return false;
            }
        );

        $('#uploadButton').on( 'click', 
            function(){
                uploadFile( this );
                return false;
            }
        );

        var number = 1+Math.floor(11 * Math.random());
        $('#progress img').attr("src", "/agenda/planung/image/upload/bird"+number+".gif");
    }
);
