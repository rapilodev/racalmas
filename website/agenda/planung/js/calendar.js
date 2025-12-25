if (window.namespace_calendar_js) throw "stop"; window.namespace_calendar_js = true;
"use strict";

var days = 1;
var leftMouseButton = 1;
var middleMouseButton = 2;
var rightMouseButton = 3;

// Internal state to prevent navigation being "one step behind"
var _viewDate = null;

// --- Date & Navigation Helpers ---

function currentDate() {
    if (_viewDate) {
        return _viewDate;
    }
    const urlParams = new URLSearchParams(location.search);
    const urlDate = urlParams.get("date");
    _viewDate = urlDate || formatDate(new Date());
    return _viewDate;
}

function getJumpRange() {
    let r = parseInt($("#range").val());
    if (isNaN(r)) {
        return 7;
    }
    return r;
}

function previousDate() {
    const range = getJumpRange();
    const d = addDays(currentDate(), -range);
    return formatDate(d);
}

function nextDate() {
    const range = getJumpRange();
    const d = addDays(currentDate(), range);
    return formatDate(d);
}

// --- Layout & UI ---

function cancel_edit_event() {
    $('#calendar').show();
    $('#event_editor').hide();
    resizeCalendarTable();
    stopMouseTracking();
    return false;
}

function setupMenuHeight() {
    if (!isTableView()) {
        return;
    }
    var top = $('#calcms_nav').height();
    if ($('#calendar').length == 0) {
        return top;
    }
    var weekdays = document.querySelector("#weekdays");
    var weekday_height = 0;
    var dayDivs = weekdays.querySelectorAll("td div");
    dayDivs.forEach((div) => {
        let height = div.offsetHeight + 14;
        if (height > weekday_height) {
            weekday_height = height;
        }
    });
    top += weekday_height;
    top -= 9;
    return top;
}

function resizeCalendarTable() {
    if (!isTableView()) {
        return;
    }
    const cal = document.getElementById('calendar');
    if (!cal) {
        return;
    }
    const content = document.getElementById('content');
    const height = window.innerHeight - setupMenuHeight();
    cal.querySelector('tbody').style.height = `${height}px`;

    const width = fullwidth(cal);
    content.style.maxWidth = `${width}px`;

    const columnSpacing = 24;
    const weekCount = cal.querySelectorAll('th.week').length;
    const space = weekCount * columnSpacing;
    const tdCol0 = cal.querySelector('td.col0');
    const timeElements = Array.from(tdCol0.querySelectorAll('.time'));
    const time = timeElements.find(el => !el.classList.contains('now'));
    if (!time) {
        return;
    }

    const dateWidth = fullwidth(time);
    const dateHeight = 0.5 * fullheight(time);
    const cols = cal.querySelectorAll('th.col1').length;

    let colWidth = Math.round((width - dateWidth - space) / cols) - 20;
    colWidth = dateHeight * Math.round(colWidth / dateHeight);

    const targetCols = cal.querySelectorAll('.col1, .col1 > div');
    targetCols.forEach(el => {
        el.style.width = `${colWidth}px`;
        el.style.maxWidth = `${colWidth}px`;
    });
}

function setSelectedOptions() {
    $('#content select').each(function() {
        var value = $(this).attr('value');
        if (value == null) {
            return;
        }
        $(this).children().each(function() {
            if ($(this).attr('value') == value) {
                $(this).attr('selected', 'selected');
            }
        });
    });
}

// --- URL & Content Loading ---

function update_url(url) {
    if (url == null) {
        url = update_urlParameters();
    }
    url = removeUrlParameter(url, 'part');
    url = url.replace("calendar-content.cgi", "calendar.cgi");

    const urlObj = new URL(url, window.location.origin);
    const d = urlObj.searchParams.get("date");
    if (d) {
        _viewDate = d;
    }

    history.pushState(null, null, url);
    appendHistory(url, 'replace');
}

function isTableView() {
    return !isListView();
}

function isListView() {
    const isListParam = getUrlParameter('list') == '1';
    const isEventsRange = $('#range').val() == 'events';
    return isListParam || isEventsRange;
}

function update_urlParameters(url) {
    if (url == null) {
        url = window.location.href;
    }
    url = url.replace("calendar-content.cgi", "calendar.cgi");

    url = setUrlParameter(url, 'project_id', $('#project_id').val());
    url = setUrlParameter(url, 'studio_id', $('#studio_id').val());
    url = setUrlParameter(url, 'date', currentDate());
    url = setUrlParameter(url, 's', isChecked('#show_schedule') ? 1 : 0);
    url = setUrlParameter(url, 'e', isChecked('#show_events') ? 1 : 0);

    if (isTableView()) {
        url = setUrlParameter(url, 'w', isChecked('#show_worktime') ? 1 : 0);
        url = setUrlParameter(url, 'p', isChecked('#show_playout') ? 1 : 0);
        url = setUrlParameter(url, 'day_start', $('#day_start').val());
        var range = $('#range').val();
        if (range == 'events') {
            url = setUrlParameter(url, 'list', 1);
        } else {
            url = setUrlParameter(url, 'range', $('#range').val());
        }
    }
    return url;
}

function loadCalendarTable(url, mouseButton) {
    if (isListView()) {
        throw Error("wrong mode");
    }

    const urlObj = new URL(url, window.location.origin);
    const targetDate = urlObj.searchParams.get("date");

    if (targetDate) {
        _viewDate = targetDate;
        const formatted = formatLocalDate(targetDate);
        $('#current_date').html(formatted);
    }

    if ((mouseButton != null) && (mouseButton == middleMouseButton)) {
        openNewTab(url);
        return true;
    }

    url = setUrlParameter(url, 'part', '1');
    url = url.replace("calendar.cgi", "calendar-content.cgi");
    $('#calendarTable').addClass("loading");

    updateContainer('calendarTable', url, function() {
        $('#calendarTable').removeClass("loading");
        setupCalendar();
        update_url(url);
        initRmsPlot();
        setColors();
        resizeCalendarTable();
    });
}

function loadCalendarList(url) {
    document.title = "Sendungen ";
    url = setUrlParameter(url, 'part', '1');
    url = url.replace("calendar.cgi", "calendar-content.cgi");
    updateContainer('calendarTable', url, function() {
        $('#calendarTable').removeClass("loading");
        setupCalendar();
        update_url(url);
        setColors();
    });
}

// --- Filter Visibility Controls ---

function show_events() {
    let val = isChecked('#show_events') ? '' : 'none';
    $('#calendar .event, #event_list .event').css("display", val);
}

function show_schedule() {
    let val = isChecked('#show_schedule') ? '' : 'none';
    $('#calendar .schedule, #event_list .schedule').css("display", val);
}

function show_worktime() {
    let val = isChecked('#show_worktime') ? '' : 'none';
    $('#calendar .work, #event_list .work').css("display", val);
}

function show_playout() {
    let val = isChecked('#show_playout') ? '' : 'none';
    $('#calendar .play, #event_list .play').css("display", val);
}

// --- Mouse Tracking Logic ---

function getNearestDatetime() {
    var date = "test";
    var hour = "00";
    var minute = "00";
    var xMin = 9999999;
    var yMin = 9999999;

    $('#calendar tr#weekdays div.date').each(function() {
        var xpos = $(this).offset().left;
        var offset = $(this).width() / 2;
        var delta = Math.abs(mouseX - xpos - offset);
        if (delta < xMin) {
            xMin = delta;
            date = $(this).attr('date');
        }
    });

    $('#calendar div.time').each(function() {
        var ypos = $(this).offset().top;
        var offset = $(this).height() / 2;
        var delta = (mouseY - ypos - offset);
        var absDelta = Math.abs(delta);
        if (absDelta < yMin) {
            yMin = absDelta;
            hour = $(this).attr('time').substr(0, 2);
        }
    });

    if (parseInt(hour) < startOfDay) {
        date = formatDate(addDays(date, 1));
    }

    minute = 0;
    yMin = 9999999999;
    $('#calendar div.time').each(function() {
        var ypos = $(this).offset().top;
        var offset = $(this).height() / 2;
        var delta = (mouseY - ypos - offset);
        var absDelta = Math.abs(delta);
        if (absDelta < yMin) {
            yMin = absDelta;
            hour = $(this).attr('time').substr(0, 2);
            var height = $(this).height() + 14;
            var m = ((delta + height * 1.5) - 8) % height;
            m = m * 60 / height;
            minute = Math.floor(m / 15) * 15;
            minute = (minute + 60) % 60;
            if (minute < 10) {
                minute = '0' + minute;
            }
        }
    });
    return date + " " + hour + ":" + minute + ":00";
}

var mouseX = 0;
var mouseY = 0;
var mouseMoved = false;
var mouseUpdate = false;
var mouse_update_id = null;

function showMouse() {
    if (!isTableView()) {
        return;
    }
    $("#calendar").off('mousemove').on('mousemove', (event) => {
        mouseX = event.pageX;
        mouseY = event.pageY;
        mouseMoved = true;
    });
    if (mouse_update_id !== null) {
        clearInterval(mouse_update_id);
    }
    mouse_update_id = setInterval(() => {
        if (!mouseMoved || mouseUpdate) {
            return;
        }
        mouseMoved = false;
        mouseUpdate = true;
        const posText = getNearestDatetime();
        $('#position').text(posText);
        mouseUpdate = false;
    }, 200);
}

function stopMouseTracking() {
    if (mouse_update_id !== null) {
        clearInterval(mouse_update_id);
        mouse_update_id = null;
    }
    $("#calendar").off('mousemove');
}

// --- Action & Event Handlers ---

function handleEvent(id, event) {
    var field = id.split('_');
    field.shift(); // class
    var project_id = field.shift();
    var studio_id = field.shift();
    var series_id = field.shift();
    var event_id = field.shift();
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
    var field = id.split('_');
    field.shift();
    var project_id = field.shift();
    var studio_id = field.shift();
    var series_id = field.shift();
    var event_id = field.shift();
    if (checkStudio() == 0 || project_id < 0 || event_id < 0) {
        return;
    }
    $('#assign_series_events input[name="event_id"]').attr('value', event_id);
    show_not_assigned_to_series_dialog();
}

function handleSchedule(id, start_date, event) {
    var field = id.split('_');
    field.shift();
    var project_id = field.shift();
    var studio_id = field.shift();
    var series_id = field.shift();
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
    var field = id.split('_');
    field.shift();
    var project_id = field.shift();
    var studio_id = field.shift();
    var series_id = field.shift();
    if (project_id < 0 || studio_id < 0) {
        return;
    }
    const startTime = getNearestDatetime();
    show_schedule_series_dialog(project_id, studio_id, series_id, startTime);
}

function handleWorktime(id, event) {
    var field = id.split('_');
    field.shift();
    var project_id = field.shift();
    var studio_id = field.shift();
    var schedule_id = field.shift();
    if (checkStudio() == 0 || project_id < 0 || schedule_id < 0) {
        return;
    }
    var startDate = $('#' + id).attr("start");
    var params = new URLSearchParams({ action: "show_new_event_from_schedule", project_id, studio_id, schedule_id, start_date: startDate });
    var url = "work-time.cgi?" + params.toString();
    if (event.which == 1) {
        loadUrl(url);
    }
    if (event.which == 2) {
        openNewTab(url);
    }
}

// --- Dialogs ---

function checkStudio() {
    if ($('#studio_id').val() != '-1') {
        return 1;
    }
    showDialog({ title: "please select a studio" });
    return 0;
}

function show_not_assigned_to_series_dialog() {
    var loc = getLocalization();
    showDialog({
        title: loc['label_event_not_assigned_to_series'],
        buttons: {
            Cancel: function() { $(this).closest('div#dialog').remove(); }
        }
    });
}

function show_schedule_series_dialog(project_id, studio_id, series_id, start_date) {
    var loc = getLocalization();
    var listParams = new URLSearchParams({ action: "list_series", json: 1, project_id, studio_id });
    jQuery.getJSON("series.cgi?" + listParams.toString()).done(function(data) {
        var html = `<table><tr><td>${loc['label_series']}</td><td><select id="series_select">`;
        for (const serie of data["series"]) {
            let name = serie['has_single_events'] == '1' ? loc['single_events'] : (serie["series_name"] || '');
            let titleText = serie["title"] ? ' - ' + serie["title"] : '';
            html += `<option value="${serie["series_id"] || -1}">${name}${titleText}</option>`;
        }
        html += `</select></td></tr><tr><td>${loc["label_date"]}</td><td><input id="series_date"></td></tr>
                 <tr><td>${loc["label_duration"]}</td><td><input id="series_duration" value="60"></td></tr></table>`;
        showDialog({
            title: loc['label_schedule_series'],
            content: html,
            width: "50rem",
            buttons: {
                "Schedule": function() {
                    var params = new URLSearchParams({
                        action: 'show_series',
                        project_id,
                        studio_id,
                        series_id: $('#series_select').val(),
                        start: $('#series_date').val(),
                        duration: $('#series_duration').val(),
                        show_hint_to_add_schedule: 1
                    });
                    loadUrl('series.cgi?' + params.toString() + '#tabs-schedule');
                },
                Cancel: function() { $(this).closest('div#dialog').remove(); }
            }
        });
        $('#series_date').val(start_date);
        var dateObj = parseDateTime(start_date);
        showDateTimePicker('#series_date', { date: dateObj });
    });
}

// --- Visual Features (RMS, Colors) ---

function initRmsPlot() {
    $("#calendar div.play").hover(
        function() {
            var plot = $(this).attr("rms");
            var id = $(this).attr("id");
            var field = id.split('_');
            var project_id = field[1];
            var studio_id = field[2];
            var start = $(this).attr("start");
            if (!project_id || !studio_id || !start) {
                return;
            }
            if (!$(this).hasClass("clickHandler")) {
                $(this).addClass("clickHandler").click(function(e) {
                    e.stopImmediatePropagation();
                    showRmsPlot(id, project_id, studio_id, start, $(this));
                });
            }
            if (!$(this).hasClass("rms_image") && plot) {
                $(this).addClass("rms_image");
                var imgId = createId("rms_img");
                var url = '/media/playout/' + plot;
                var img = `<img src="${url}">`;
                var del = `onclick="deleteFromPlayout('${imgId}', '${project_id}', '${studio_id}', '${start}')"`;
                var details = `<div id="${imgId}" class="rms_detail" style="display:none"><div class="image">${img}</div><div class="text">${$(this).html()}</div><button ${del}>delete</button></div>`;
                $(this).prepend(img + details);
            }
            $(this).find('img').show();
        },
        function() {
            if ($(this).attr("rms")) {
                $(this).find('img').hide();
            }
        }
    );
}

function showRmsPlot(id, pid, sid, start, elem) {
    showDialog({
        width: 940,
        height: 560,
        content: elem.html(),
        buttons: { Close: function() { $(this).closest('div#dialog').remove(); } }
    });
}

function deleteFromPlayout(id, pid, sid, start) {
    var params = new URLSearchParams({ action: 'delete', project_id: pid, studio_id: sid, start_date: start });
    $('#' + id).load('playout.cgi?' + params.toString());
}

function setColors() {
    var elem = $('.schedule').get(0);
    if (!elem) {
        return;
    }
    var col1 = window.getComputedStyle(elem).backgroundColor;
    var col2 = col1.replace('rgb', 'rgba').replace(')', ', 0.4)');
    var gradient = `repeating-linear-gradient(to bottom, ${col1}, ${col1} 1px, ${col2} 1px, ${col2} 2px)`;
    $('.schedule').css('background', gradient);
}

function createId(prefix) {
    var randomStr = Math.random().toString(16).substr(2, 8);
    return prefix + '_' + randomStr;
}

// --- Initialization ---

function setDatePicker() {
    $('#selectDate').off().on('click', function() {
        let dp = showDatePicker('#selectDate', {
            wrap: true,
            onSelect: function(dates) {
                var formatted = formatDate(dates[0]);
                var url = setUrlParameter(window.location.href, 'date', formatted);
                loadCalendarTable(url);
            }
        });
        dp.setDate(currentDate());
        dp.toggle();
    });
    initTodayButton();
}

function initTodayButton() {
    $('button#setToday').on('mousedown', function(e) {
        let url = removeUrlParameter(update_urlParameters(), 'date');
        if (e.which == leftMouseButton) {
            loadCalendarTable(url);
        }
        if (e.which == middleMouseButton) {
            openNewTab(url);
        }
    });
}

function setup_filter() {
    var eventsLabel = label_events || "events";
    var scheduleLabel = label_schedule || "schedule";
    $('.sidebar').append(getSwitch('show_events', eventsLabel, true));
    $('.sidebar').append(getSwitch('show_schedule', scheduleLabel, true));

    if (getUrlParameter('s') == '0') {
        unselectCheckbox('#show_schedule');
    }
    if (getUrlParameter('e') == '0') {
        unselectCheckbox('#show_events');
    }

    show_schedule();
    show_events();

    $('#show_events, #show_schedule').on("click", function() {
        show_events();
        show_schedule();
        update_url();
    });

    if (isTableView()) {
        var playoutLabel = label_playout || "playout";
        var workLabel = label_worktime || "work";
        $('.sidebar').append(getSwitch('show_playout', playoutLabel, true));
        $('.sidebar').append(getSwitch('show_worktime', workLabel, false));

        if (getUrlParameter('p') == '0') {
            unselectCheckbox('#show_playout');
        }
        if (getUrlParameter('w') == '0') {
            unselectCheckbox('#show_worktime');
        }

        show_playout();
        show_worktime();

        $('#show_playout, #show_worktime').on("click", function() {
            show_playout();
            show_worktime();
            update_url();
        });
    }
}

function getSwitch(id, text, active, klass) {
    var cssClass = klass || '';
    var checked = active ? 'checked' : '';
    return `<div class="switch ${cssClass}"><label>${text}<input id="${id}" type="checkbox" ${checked}><span class="lever"></span></label></div>`;
}

function setup_actions() {
    var base = isTableView() ? '#calendar' : '#event_list';
    $(base).off().on("mousedown", ".event", function(e) {
        handleEvent($(this).attr("id"), e);
    });
    $(base).on("click", ".event.no_series", function() {
        handleUnassignedEvent($(this).attr("id"));
    });
    $(base).on("mousedown", ".schedule", function(e) {
        handleSchedule($(this).attr("id"), $(this).attr("start"), e);
    });
    $(base).on("click", ".grid", function() {
        handleGrid($(this).attr("id"));
    });
    $(base).on("mousedown", ".work", function(e) {
        handleWorktime($(this).attr("id"), e);
    });
}

function setup_date_select() {
    if (!isTableView()) {
        return;
    }
    $('#previous_month, #next_month').off().on('mouseup', function(e) {
        if (e.which == rightMouseButton) {
            return;
        }
        var date = (this.id === 'next_month') ? nextDate() : previousDate();
        var url = setUrlParameter(update_urlParameters(), 'date', date);
        loadCalendarTable(url, e.which);
    });
    const headerDate = formatLocalDate(currentDate());
    $('#current_date').html(headerDate);
    resizeCalendarTable();
    $(window).resize(() => {
        resizeCalendarTable();
        if (typeof setupMenu === 'function') {
            setupMenu();
        }
    });
}

function setupCalendar() {
    setup_actions();
    if (isTableView()) {
        setup_date_select();
        showMouse();
        $('#calendar .col1 > div').mouseover(function() {
            const tip = getMouseOverText($(this));
            $(this).attr("title", tip);
        });
    }
    document.oncontextmenu = () => false;
}

function getMouseOverText(elem) {
    if (elem.attr('title')) {
        return elem.attr('title');
    }
    if (elem.hasClass('event')) {
        return 'click to edit show';
    }
    if (elem.hasClass('schedule')) {
        return 'click to create show';
    }
    return '';
}

function updateDayStart() {
    var params = new URLSearchParams({
        project_id: getProjectId(),
        studio_id: getStudioId(),
        day_start: $('#day_start').val()
    });
    $.get('set-user-day-start.cgi?' + params.toString());
}

window.calcms ??= {};
window.calcms.init_calendar = function(el) {
    let url = update_urlParameters();
    if (isListView()) {
        loadCalendarList(url);
        return;
    }
    if (isTableView()) {
        _viewDate = null;
        setup_filter();
        setSelectedOptions();
        setDatePicker();
        let url = update_urlParameters();
        resizeCalendarTable();
        $('.sidebar select#range, .sidebar select#day_start').on('change', (e) => {
            if (e.target.id === 'day_start') {
                updateDayStart();
            }
            loadCalendarTable(update_urlParameters());
        });
        loadCalendarTable(url);
    }
};

$(window).on('beforeunload', () => {
    stopMouseTracking();
});
