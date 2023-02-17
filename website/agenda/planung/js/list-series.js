function add_series(){
    $('#edit_new').toggle();
    return false;
}

function showSeries(project_id, studio_id, series_id, tab) {
    loadUrl( "series.cgi?" + new URLSearchParams({
        action: "show_series",
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
    }).toString() + tab);
}

function view_series_details(project_id, studio_id, series_id){
    var elem=$('.series_details_'+series_id).prev();
    if(elem.hasClass('active')){
        elem.removeClass('active');
        $('.series_details_'+series_id).slideToggle(
            function(){
                $('#series_details_'+series_id).html('');
            }
        );
    } else {
        elem.addClass('active');
        showSeries(project_id,studio_id,series_id);
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

async function createSeries(form){
    var formData = new FormData(form.get(0));
    formData.append("action", "create_series");
    let response = await fetch("series.cgi?",{
        method: 'POST',
        cache: "no-store",
        body: new URLSearchParams(formData)
    });
    if (response.status != 200) { showError(response.statusText); return }
    let json = await response.json();
    if (json.error) return showError(json.error);
    if (json.status != "series created") return "could not create series";
    showInfo("schedule created");
    showSeries(
        form.find("input[name='project_id']").val(),
        form.find("input[name='studio_id']").val(),
        form.find("input[name='series_id']").val(),
    );
}

$( document ).ready(
    function() {
        var series=$('div#newSeries div').length+$('div#oldSeries div').length;
        if(series<40)series=40;
        $('#content').css('height', series*1.7+'rem' );
        searchEvents();
    }
);
