function download(id, name){
    $.getJSON(
        'archive.cgi?get_link='+name,
        function(data){
            $.each(data,
                function(key, val) {
                    $('#'+id).html(val);
                }
            );
        }
    );
}