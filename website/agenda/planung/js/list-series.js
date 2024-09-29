function add_series(){
    $('#edit_new').toggle();
    return false;
}

function view_series_details(series_id, studio_id, project_id){
    var elem=$('.series_details_'+series_id).prev();
    if(elem.hasClass('active')){
        elem.removeClass('active');
        $('.series_details_'+series_id).slideToggle(
            function(){
                $('#series_details_'+series_id).html('');
            }
        );
    }else{
        elem.addClass('active');
        var url="series.cgi?project_id="+project_id+"&studio_id="+studio_id+"&series_id="+series_id+"&action=show";
        load(url);
    }
}


function searchEventsAt(selector, searchValue){
    $(selector).each(function(){
        if(searchValue==''){
            $(this).show();
            return;
        }
        var text=$(this).text().toLowerCase();
        if(text.indexOf(searchValue)!=-1){
            $(this).show();
        }else{
            $(this).hide();
        }
    });
}

function searchEvents(){
    var searchValue=$('#searchField').val().toLowerCase();
    searchValue=searchValue.trim().replace(/\s+/g, ' ');

    if (searchValue=='') {
        $('#clearSearch').hide();
    }else{
        $('#clearSearch').show();
    };
    searchEventsAt('#newSeries a', searchValue);
    searchEventsAt('#oldSeries a', searchValue);
}

function clearSearch(){
    $('#searchField').val('');
    searchEvents();
}


$( document ).ready(
    function() {
        var series=$('div#newSeries div').length+$('div#oldSeries div').length;
        if(series<40)series=40;
        $('#content').css('height', series*1.7+'rem' );
        searchEvents();
    }
);
