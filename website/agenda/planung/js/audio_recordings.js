
function showProgress(){
    $('#progress').slideDown();
    return false;
}

function hideProgress(){
    $('#progress').slideUp();
    return false;
}

function playAudio(path){
    var url='../../agenda_files/recordings/'+path;
    var win = window.open(url, '_blank');
}

function changeFile(fileInput){
    var file = fileInput.files[0];
    var size = file.size / (1000*1000);
    $('#uploadSize').html(size + " MB");
    if (size > 300){
        $('#uploadButton').hide();
        showError("file is too large. maximum size is 300 MB! Please use MP3, 192 kHz, CBR, 44100 Hz, 16bit");
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
    var MB=1000*1000;
    var value= Math.round(size*10/MB)/10;
    value+='';
    if (value.indexOf('.')<0)value+='.0';
    return value;
}

function uploadFile(uploadButton){
    hideFinished();
    hideError();
    showProgress();
    $.ajax({
        url: 'audio_recordings.cgi',
        type: 'POST',
        data: new FormData($('#audio_recordings_upload')[0]),
        cache: false,
        contentType: false,
        processData: false,
        xhr: function() {
            var start = new Date();
            var myXhr = $.ajaxSettings.xhr();
            if (myXhr.upload) {
                var c=0;
                var oldRemaining=0;
                myXhr.upload.addEventListener(
                    'progress', 
                    function(data) {
                        if (!data.lengthComputable) return;
                        c++;

                        var loaded=roundSize(data.loaded);
                        var total=roundSize(data.total);
                        $('#progressBar').attr("value", loaded);
                        $('#progressBar').attr("max", total);

                        if (c<2)return;
                        c=0;

                        var duration=(new Date().getTime() - start.getTime()) / 1000 ;
                        var bitrate = loaded / duration;

                        //var remaining = Math.round(bitrate * ( total - loaded) );
                        var remaining = Math.round( (duration * data.total / data.loaded) - duration );
                        if (oldRemaining == 0) oldRemaining = remaining;
                        if (duration>30) remaining= oldRemaining*0.5 + remaining*0.5;
                        oldRemaining=remaining;

                        var content = loaded + " of " + total + " MB<br>";
                        content += '<div class="thin">';
                        content += "finished in " + Math.round(remaining) + " seconds<br>";
                        content += "took " + Math.round(duration) + " seconds<br>";
                        content += '</div>'
                        $('#progressLabel').html(content);
                    } , 
                    false
                );
            }
            return myXhr;
        },
    }).error(
        function(jqXHR, textStatus, errorThrown ){
            showError("error: "+errorThrown);
            hideProgress();
            hideFinished();
        }
    ).done(
        function(data){
            showFinished();
            hideProgress();
            hideError();
            //setTimeout(function() { location.reload() }, 1000);
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
        $('#progress img').attr("src", "/agenda/image/upload/bird"+number+".gif");
    }
);
