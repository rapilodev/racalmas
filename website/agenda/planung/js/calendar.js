if (window.namespace_calendar_js) throw "stop"; window.namespace_calendar_js = true;
"use strict";

var days = 1;
var leftMouseButton = 1;
var middleMouseButton = 2;
var rightMouseButton = 3;

var _viewDate = null;
function currentDate() {
    if (_viewDate) return _viewDate;
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
    stopMouseTracking();
    return false;
}

function resizeCalendarTable() {
    if (!isTableView()) return;
    const cal = document.getElementById('calendar');
    if (!cal) return;

    const calRect = cal.getBoundingClientRect();
    const content = document.getElementById('content');
    const tdCol0 = cal.querySelector('td.col0');
    const timeEl = tdCol0?.querySelector('.time:not(.now)');
    
    // Query collections for counts
    const weekHeaders = cal.querySelectorAll('th.week');
    const col1Headers = cal.querySelectorAll('th.col1');

    if (!timeEl) return;
    const timeRect = timeEl.getBoundingClientRect();

    // --- PHASE 2: CALCULATE (No DOM interaction) ---
    const width = calRect.width;
    const dateWidth = timeRect.width;
    const dateHeight = 0.5 * timeRect.height;
    
    const weekCount = weekHeaders.length;
    const cols = col1Headers.length;
    const space = weekCount * 24;

    let colWidth = Math.round((width - dateWidth - space) / cols) - 20;
    colWidth = dateHeight * Math.round(colWidth / dateHeight);

    requestAnimationFrame(() => {
        cal.style.setProperty('--calendar-col-width', `${colWidth}px`);
        if (content) content.style.maxWidth = `${width}px`;
        show_events();
    });
}

function setSelectedOptions() {
    const selects = document.querySelectorAll('#content select[value]');
    selects.forEach(s => s.value = s.getAttribute('value'));
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
    return isListParam || isEventsRange || $('#event_list').length;
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

let isCalendarLoading = false;

async function loadCalendarTable(url, mouseButton) {
    if (isCalendarLoading) return;

    if (isListView()) throw Error("wrong mode");
    if (mouseButton === middleMouseButton) {
            openNewTab(url);
            return true;
        }
    const urlObj = new URL(url, window.location.origin);
    const targetDate = urlObj.searchParams.get("date");

    if (targetDate) {
        _viewDate = targetDate;
        $('#current_date').html(formatLocalDate(targetDate));
    }

    url = setUrlParameter(url, 'part', '1');
    url = url.replace("calendar.cgi", "calendar-content.cgi");
    try {
        isCalendarLoading = true;
        $('#calendarTable').addClass("loading");
        await loadHtmlFragment({
            url: url,
            target: '#calendarTable'
        });
        setupCalendar();
        update_url(url);
        resizeCalendarTable();
    } finally{
        isCalendarLoading = false;
        $('#calendarTable').removeClass("loading");
    }
    initRmsPlot();
    setColors();
}

async function loadCalendarList(url) {
    console.log("loadCalendarList");
    document.title = "Sendungen ";
    url = setUrlParameter(url, 'part', '1');
    url = url.replace("calendar.cgi", "calendar-content.cgi");
    await loadHtmlFragment({
        url: url,
        target: '#calendarTable'
    });
    $('#calendarTable').removeClass("loading");
    setupCalendar();
    update_url(url);
    setColors();
}

// --- Filter Visibility Controls ---

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

function getNearestDatetime() {
    let date = "";
    let hour = "00";
    let xMin = Infinity;
    let yMin = Infinity;

    const dateDivs = $('#calendar tr#weekdays div.date');
    const timeDivs = $('#calendar div.time');

    dateDivs.each(function() {
        const offset = $(this).offset();
        const delta = Math.abs(mouseX - offset.left - ($(this).width() / 2));
        if (delta < xMin) {
            xMin = delta;
            date = $(this).attr('date');
        }
    });

    let minute = 0;
    timeDivs.each(function() {
        const offset = $(this).offset();
        const height = $(this).height() + 14;
        const delta = mouseY - offset.top - (height / 2);
        const absDelta = Math.abs(delta);

        if (absDelta < yMin) {
            yMin = absDelta;
            hour = $(this).attr('time').substr(0, 2);
            let m = ((delta + height * 1.5) - 8) % height;
            m = m * 60 / height;
            minute = Math.floor(m / 15) * 15;
            minute = String((minute + 60) % 60).padStart(2, '0');
        }
    });

    if (parseInt(hour) < startOfDay) date = formatDate(addDays(date, 1));
    return `${date} ${hour}:${minute}:00`;
}

let rafId = null;
let mouseX = 0, mouseY = 0;
let mouseMoved = false;

function showMouse() {
    if (!isTableView()) return;

    const calendar = document.getElementById('calendar');
    $(calendar).off('mousemove').on('mousemove', (e) => {
        mouseX = e.pageX;
        mouseY = e.pageY;
        mouseMoved = true;
    });

    const updateLoop = () => {
        if (mouseMoved) {
            // Calculate once instead of searching DOM
            const posText = getNearestDatetime();
            $('#position').text(formatLocalDateTime(posText));
            mouseMoved = false;
        }
        rafId = requestAnimationFrame(updateLoop);
    };

    if (rafId) cancelAnimationFrame(rafId);
    rafId = requestAnimationFrame(updateLoop);
}

function stopMouseTracking() {
    if (rafId) cancelAnimationFrame(rafId);
    $("#calendar").off('mousemove');
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
        return loc['label_edit_show'];
    }
    if (elem.hasClass('schedule')) {
        return loc['label_create_show'];
    }
    if (elem.hasClass('grid')) {
        return loc['label_create_schedule'];
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

function initSearch() {
    const search = document.querySelector('#search');
    search.onInput = (query) => {
        const elems = document.querySelectorAll("div.event, div.schedule, div.play");
        query = query.toLowerCase();
        elems.forEach(elem => {
            const text = elem.textContent.toLowerCase();
            elem.style.display = text.includes(query) ? "" : "none";
        });
    };
    search.onSearch = (query) => loadUrl(
        "list-events.cgi?" + new URLSearchParams({
            action: "search",
            project_id: getUrlParameter('project_id'),
            studio_id: getUrlParameter('studio_id'),
            search: query
        }).toString()
    );
}

function initSidebar(config, params, date) {
    const className = 'sidebar';
    let sidebar = `<div class="${className}">`;
    sidebar += `
        <div class="row">
            <div id="previous_month">
                <button class="primary" id="previous"
                    aria-label="${loc.label_cal_nav_prev}"
                    ><sprite-icon name="navigate-before"></sprite-icon></button>
            </div>
            <div id="selectDate" data-toggle>
                <input id="start_date" data-input/>
                <div id="current_date">${year_month}</div>
            </div>
            <div id="next_month">
                <button id="next" class="primary"
                    aria-label="${loc.label_cal_nav_next}"
                    ><sprite-icon name="navigate-next"></sprite-icon></button>
            </div>
            <button id="setToday" class="primary">
                <sprite-icon name="calendar"></sprite-icon>
                ${loc.button_today}
            </button>
        </div>
    `;

    if (isTableView()) {
        const ranges = {
            [loc.label_month]: 'month',
            [loc.label_4_weeks]: '28',
            [loc.label_2_weeks]: '14',
            [loc.label_1_week]: '7',
            [loc.label_day]: '1'
        };
        sidebar += `<select id="range" name="range" value="${range}">`;

        const rangeKeys = [
            loc.label_month,
            loc.label_4_weeks,
            loc.label_2_weeks,
            loc.label_1_week,
            loc.label_day
        ];

        for (const range of rangeKeys) {
            const value = ranges[range] || '';
            sidebar += `<option name="${range}" value="${value}">${range}</option>`;
        }
        sidebar += "</select>";

        const dayStart = day_start !== undefined ? day_start : '';
        sidebar += `<select id="day_start" name="day_start" value="${dayStart}">`;
        for (let hour = 0; hour <= 24; hour++) {
            const selected = hour == dayStart ? 'selected="selected"' : '';
            const formattedHour = String(hour).padStart(2, '0') + ':00';
            sidebar += `<option value="${hour}" ${selected}>${formattedHour}</option>`;
        }
        sidebar += `</select>`;
    }
    sidebar += `<search-input id="search" placeholder="${loc.button_search}"></search-input>`;
    if (isListView()) {
        sidebar += `
            <button is="link-button" id="editSeries">
                <sprite-icon name="edit"></sprite-icon>
                ${loc.button_edit_series}
            </button>
        `;
    }
    sidebar += `</div>`;
    const calendarTable = document.getElementById('calendarTable');
    calendarTable.insertAdjacentHTML('beforebegin', sidebar);
}

window.calcms ??= {};
window.calcms.init_calendar = async function(el) {
    await loadLocalization('calendar');
    let url = update_urlParameters();
    initSidebar();
    initSearch();
    if (isTableView()) {
        _viewDate = null;
        window.onpopstate = function() {
            _viewDate = null;
            location.reload();
        };

        const resizeObserver = new ResizeObserver(() => {
            requestAnimationFrame(resizeCalendarTable);
        }).observe(document.getElementById('calendarTable'));

        setup_filter();
        setSelectedOptions();
        setDatePicker();
        let url = update_urlParameters();
        $('.sidebar select#range, .sidebar select#day_start').on('change', (e) => {
            if (e.target.id === 'day_start') {
                updateDayStart();
            }
            loadCalendarTable(update_urlParameters());
        });
        loadCalendarTable(url);
    }
};

window.calcms.init_event_list = async function(el) {
    await loadLocalization('calendar');
    let url = update_url();
    setColors();
    setup_actions();
    document.querySelectorAll('table td.start_date').forEach(el => {
        el.innerHTML = DTF.datetime(el.innerHTML);
    });

    if (isListView()) {
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
    }
    return;
};

$(window).on('beforeunload', () => {
    stopMouseTracking();
});
