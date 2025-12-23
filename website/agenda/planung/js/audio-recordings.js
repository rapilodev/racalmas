if (window.namespace_audio_recordings_js) throw "stop"; window.namespace_audio_recordings_js = true;
"use strict";

function showProgress(){
    $('#progress').slideDown(() => $('#progress').addClass('progress-visible'));
    return false;
}

function hideProgress(){
    $('#progress').slideUp(() => $('#progress').removeClass('progress-visible'));
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
    if (size < 1){
        $('#uploadButton').hide();
        showError("File is too small!");
    } else if (size > 700){
        $('#uploadButton').hide();
        showError("File is too big!");
    }else{
        $('#uploadButton').show();
        $('#uploadButton').focus();
    }
}

function showInfoAndReload(s) {
    $('#info').show();
    $('#info').html(s);
    window.location.reload();
}

function hideInfo() {
    $('#info').hide();
}
function hideError() {
    $('#error').hide();
}

function roundSize(size) {
    const MB = 1000 * 1000;
    var value = Math.round(size / MB);
    value += '';
    return value;
}

function formatTime(duration){
    if (duration > 3600) return Math.ceil(duration/3600) + " hours";
    if (duration > 60)   return Math.ceil(duration/60)   + " minutes";
    return duration += " seconds";
}

function uploadFile(uploadButton){
    hideInfo();
    hideError();
    showProgress();
    $.ajax({
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
                        document.title = perc + "%" + $('#title').text();

                        let content = total + " MB<br>";
                         $('#progressLabel').html(content);
                    } ,
                    false
                );
            }
            return xhr;
        }
    }).fail(
        function(jqXHR, textStatus, errorThrown) {
            showError("error: " + errorThrown);
            hideProgress();
            hideInfo();
            $('#uploadButton').show();
        }
    ).done(
        function(data) {
            hideProgress();
            hideError();
            $('#uploadButton').show();
            console.log(data)
            if (data.error) {
                showError("error: " + data.error);
            } else {
                showInfoAndReload("upload finished");
        }
        }
    );
}

async function deleteFile(elem) {
    hideInfo();
    hideError();

    let form = elem.closest('form');
    let data = new URLSearchParams();
    for (let pair of new FormData(form.get(0))) {
        data.append(pair[0], pair[1]);
    }
    let response = await fetch("audio-recordings.cgi", {
        method: 'POST',
        body: data,
        cache: "no-store",
    });
    let json = await response.json();
    if (json.error) {
        showError(json.error);
    } else {
        elem.closest('tr').fadeOut();
        $('#info').html(s);
    }
}

// init function
window.calcms??={};
window.calcms.init_audio_recordings = function(el){
    
    $('#uploadButton').on('click', function() {
        uploadFile(this);
        return false;
    });
    $('#uploadButton').hide();

    $('#deleteButton').on('click', function() {
        deleteFile($(this));
        return false;
    });

    $('#file').on('change', function() {
        changeFile(this);
        return false;
    });

    var number = 1 + Math.floor(11 * Math.random());
    $('#progress img').attr("src", "/agenda/planung/image/upload/bird" + number + ".gif");
};
