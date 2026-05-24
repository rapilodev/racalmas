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

// init function
window.calcms ??= {};
window.calcms.init_list_events = function(el) {
    initSearch();
};

