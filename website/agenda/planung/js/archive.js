function download(id, name){
    //alert(id +" "+ name);
    $.getJSON(
        'archive.cgi?get_link='+name,
        function(data){
            //alert(data);
            $.each(data, 
                function(key, val) {
                    $('#'+id).html(val);
                }
            );
        }
    );
}