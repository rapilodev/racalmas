if (window.namespace_list_events_js) throw "stop"; window.namespace_list_events_js = true;
"use strict";

function initSearch() {
    const search = document.querySelector('#search');

    const rows = document.querySelectorAll("tr");
    search.onInput = (query) => {
        query = query.toLowerCase();
        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            row.style.display = text.includes(query) ? "" : "none";
        });
    };
    
    search.onSearch = (query) => {
        loadUrl("list-events.cgi?" + new URLSearchParams({
            action: "search",
            project_id: getUrlParameter('project_id'),
            studio_id: getUrlParameter('studio_id'),
            search: query
        }).toString());
    }
}

function update_urlParameters(url) {
    if (url == null) {
        url = window.location.href;
    }
    url = setUrlParameter(url, 'project_id', $('#project_id').val());
    url = setUrlParameter(url, 'studio_id', $('#studio_id').val());
    url = setUrlParameter(url, 's', isChecked('#show_schedule') ? 1 : 0);
    url = setUrlParameter(url, 'e', isChecked('#show_events') ? 1 : 0);

    return url;
}

function update_url(url) {
    if (url == null) url = update_urlParameters();
    const urlObj = new URL(url, window.location.origin);
    const d = urlObj.searchParams.get("date");
    history.pushState(null, null, url);
    appendHistory(url, 'replace');
}

// init function
window.calcms ??= {};
window.calcms.init_list_events = async function(el) {
    await loadLocalization('calendar');
    initSearch();
    let url = update_url();
    setColors();
    setup_actions();
    document.querySelectorAll('table td.start_date').forEach(el => {
        el.innerHTML = DTF.datetime(el.innerHTML);
    });

    document.querySelectorAll('table td.start_date').forEach(el => {
        el.innerHTML = DTF.datetime(el.innerHTML);
    });
    $('#editSeries').attr('data-href',
        "series.cgi?" + new URLSearchParams({
            action: "show_series",
            project_id: getUrlParameter('project_id'),
            studio_id: getUrlParameter('studio_id'),
            series_id: getUrlParameter('series_id'),
        }).toString()
    );
    return;
};

