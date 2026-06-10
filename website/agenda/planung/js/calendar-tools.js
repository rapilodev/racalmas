if (window.namespace_calendar_tools_js) throw "stop"; window.namespace_calendar_tools_js = true;
"use strict";

function setColors() {
    var elem = $('.schedule').get(0);
    if (!elem)  return;
    var col1 = window.getComputedStyle(elem).backgroundColor;
    var col2 = col1.replace('rgb', 'rgba').replace(')', ', 0.4)');
    var gradient = `repeating-linear-gradient(to bottom, ${col1}, ${col1} 1px, ${col2} 1px, ${col2} 2px)`;
    $('.schedule').css('background', gradient);
}

function show_events() {
    const val = isChecked('#show_events') ? 'block' : 'none';
    const root = document.getElementById('calendar');
    if (root) root.style.setProperty('--event-display', val);
}

function show_schedule() {
    let val = isChecked('#show_schedule') ? '' : 'none';
    const root = document.getElementById('calendar');
    if (root) root.style.setProperty('--schedule-display', val);
}

function show_worktime() {
    let val = isChecked('#show_worktime') ? '' : 'none';
    const root = document.getElementById('calendar');
    if (root) root.style.setProperty('--worktime-display', val);
}

function show_playout() {
    let val = isChecked('#show_playout') ? '' : 'none';
    const root = document.getElementById('calendar');
    if (root) root.style.setProperty('--playout-display', val);
}

function setup_actions() {
    var base = $('#event_list, #calendar').first();

    base.off().on("mousedown", ".event", function(e) {
        handleEvent($(this).attr("id"), e);
    });
    base.on("click", ".event.no_series", function() {
        handleUnassignedEvent($(this).attr("id"));
    });
    base.on("mousedown", ".schedule", function(e) {
        handleSchedule($(this).attr("id"), $(this).attr("start"), e);
    });
    base.on("click", ".grid", function() {
        handleGrid($(this).attr("id"));
    });
    base.on("mousedown", ".work", function(e) {
        handleWorktime($(this).attr("id"), e);
    });
}

function handleEvent(id, event) {
    const [, project_id, studio_id, series_id, event_id] = id.split('_');
    if (project_id < 0 || studio_id < 0 || series_id < 0 || event_id < 0) {
        return;
    }
    var params = new URLSearchParams({ project_id, studio_id, series_id, event_id, action: 'edit' });
    var url = 'broadcast.cgi?' + params.toString();
    if (event.which == 1) {
        loadUrl(url);
    }
    if (event.which == 2) {
        openNewTab(url);
    }
}

function handleUnassignedEvent(id) {
    const [, project_id, studio_id, series_id, event_id] = id.split('_');
    if (checkStudio() == 0 || project_id < 0 || event_id < 0) {
        return;
    }
    $('#assign_series_events input[name="event_id"]').attr('value', event_id);
    show_not_assigned_to_series_dialog();
}

function handleSchedule(id, start_date, event) {
    const [, project_id, studio_id, series_id, event_id] = id.split('_');
    if (checkStudio() == 0 || project_id < 0 || studio_id < 0 || series_id < 0) {
        return;
    }
    if (event.which == 1) {
        var params = new URLSearchParams({ action: "show_new_event_from_schedule", project_id, studio_id, series_id, start_date });
        var url = "broadcast.cgi?" + params.toString();
        loadUrl(url);
    }
    if (event.which == 3) {
        var params = new URLSearchParams({ action: "show_series", project_id, studio_id, series_id, start: start_date, exclude: 1, show_hint_to_add_schedule: 1 });
        var url = "series.cgi?" + params.toString() + '#tabs-schedule';
        loadUrl(url);
    }
}

function handleGrid(id) {
    const [, project_id, studio_id, series_id, event_id] = id.split('_');
    if (project_id < 0 || studio_id < 0) {
        return;
    }
    const startTime = getNearestDatetime();
    show_schedule_series_dialog(project_id, studio_id, series_id, startTime);
}

function handleWorktime(id, event) {
    const [, project_id, studio_id, work_id] = id.split('_');
    if (checkStudio() == 0 || project_id < 0 || work_id < 0) {
        return;
    }
    var startDate = $('#' + id).attr("start");
    var params = new URLSearchParams({ action: "show_new_event_from_schedule", project_id, studio_id, work_id, start_date: startDate });
    var url = "work-time.cgi?" + params.toString();
    if (event.which == 1) {
        loadUrl(url);
    }
    if (event.which == 2) {
        openNewTab(url);
    }
}
