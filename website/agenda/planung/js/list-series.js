if (window.namespace_list_series_js) throw "stop"; window.namespace_list_series_js = true;
"use strict";

function addSeries() {
    $('#add-series').toggle();
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

function view_series_details(project_id, studio_id, series_id) {
    var elem=$('.series_details_'+series_id).prev();
    if(elem.hasClass('active')){
        elem.removeClass('active');
        $('.series_details_'+series_id).slideToggle(
            () =>  $('#series_details_'+series_id).html('')
        );
    } else {
        elem.addClass('active');
        showSeries(project_id,studio_id,series_id);
    }
}

function clearSearch() {
    $('#searchField').val('');
    searchEvents();
}

async function createSeries(form) {
    var formData = new FormData(form.get(0));
    formData.append("action", "create_series");
    let response = await fetch("series.cgi?",{
        method: 'POST',
        cache: "no-store",
        body: new URLSearchParams(formData)
    });
    if (response.status == 500) { showError(response.statusText); return }
    let json = await response.json();
    console.log(json)
    if (json.error) return showError(json.error);
    if (json.status != "series created") return showError("Could not create series");
    showSeries(json.entry.project_id, json.entry.studio_id, json.entry.series_id);
    $('#add-series').show();
}

// init function
window.calcms ??= {};
window.calcms.init_list_series = function(el) {
    search.onInput = (query) => {
        const elems = document.querySelectorAll("#newSeries a, #oldSeries a");
        query = query.toLowerCase();
        elems.forEach(elem => {
            const text = elem.textContent.toLowerCase();
            elem.style.display = text.includes(query) ? "" : "none";
        });
    };
};
