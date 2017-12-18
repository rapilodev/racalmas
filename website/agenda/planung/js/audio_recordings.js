
function showProgress(){
    $('#progress').slideDown();
    return false;
}

function playAudio(path){
    var url='../../agenda_files/recordings/'+path;
    var win = window.open(url, '_blank');
}

$( document ).ready(
    function() {
        var number = 1+Math.floor(11 * Math.random());
        $('#progress img').attr("src", "/agenda/image/upload/bird"+number+".gif");
    }
);
