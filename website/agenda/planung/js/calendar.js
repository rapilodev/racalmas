if (window.namespace_calendar_js) throw "stop"; window.namespace_calendar_js = true;
"use strict";

var days = 1;

var leftMouseButton = 1;
var middleMouseButton = 2;
var rightMouseButton = 3;

function currentDate() {
    return new URLSearchParams(location.search).get("date") || formatDate(new Date());
}

function previousDate() {
    const range = parseInt($("#range").val());
    const d =   addDays(currentDate(), -range);
    const result = formatDate(d);
    return result;
}

function nextDate() {
    const range = parseInt($("#range").val());
    const d =   addDays(currentDate(), range);
    const result = formatDate(d);
    return result;
}

function cancel_edit_event() {
    $('#calendar').show();
    //$('#calendar_weekdays').show();
    $('#event_editor').hide();
    resizeCalendarTable();
    stopMouseTracking();
    return false;
}

function setupMenuHeight() {
    if (!isTableView())return;
    var top = $('#calcms_nav').height();
    if ($('#calendar').length == 0) return top;
    var weekdays = document.querySelector("#weekdays");
    var weekday_height = 0;
    weekdays.querySelectorAll("td div").forEach(
        (div) => {
            let height = div.offsetHeight + 14;
            if (height > weekday_height) weekday_height = height;
        }
    );
    top += weekday_height;
    top +=  1 - 10;
    return top;
}

function resizeCalendarTable() {
    if (!isTableView())return;
    const cal = document.getElementById('calendar');
    if (!cal) return; // Exit if #calendar doesn't exist
    const content = document.getElementById('content');

    const height = window.innerHeight - setupMenuHeight();
    cal.querySelector('tbody').style.height = `${height}px`;

    const width = fullwidth(cal);
    content.style.maxWidth = `${width}px`;

    const columnSpacing = 24;
    const weekCount = cal.querySelectorAll('th.week').length;
    const space = weekCount * columnSpacing;
    const tdCol0 = cal.querySelector('td.col0')
    const time = Array.from(tdCol0.querySelectorAll('.time'))
        .find(el => !el.classList.contains('now'));
    const dateWidth = fullwidth(time);
    const dateHeight = 0.5 * fullheight(time);

    const cols = cal.querySelectorAll('th.col1').length;
    let colWidth = Math.round((width - dateWidth - space) / cols) - 20;
    colWidth = dateHeight * Math.round(colWidth / dateHeight);

    cal.querySelectorAll('.col1, .col1 > div').forEach(
        el => el.style.width = el.style.maxWidth = `${colWidth}px`
    );
}

// preselect options in select boxes
function setSelectedOptions() {
    $('#content select').each(function() {
        var value = $(this).attr('value');
        if (value == null) return;
        $(this).children().each(
            function() {
                if ($(this).attr('value') == value) {
                    $(this).attr('selected', 'selected');
                }
            }
        );
    });
}

function update_url(url) {
    if (url == null) {
        url = update_urlParameters();
    }
    url = removeUrlParameter(url, 'part');
    //replace current in history
    url = url.replace("calendar-content.cgi", "calendar.cgi");
    history.pushState(null, null, url);
    appendHistory(url, 'replace');
}

function isTableView() {
    return !isListView();
}
function isListView() {
    return getUrlParameter('list') == '1' || $('#range').val() == 'events';
}

function update_urlParameters(url) {
    if (url==null)    url = window.location.href;
    url = url.replace("calendar-content.cgi", "calendar.cgi");

    url = setUrlParameter(url, 'project_id', $('#project_id').val());
    url = setUrlParameter(url, 'studio_id', $('#studio_id').val());
    url = setUrlParameter(url, 's', isChecked('#show_schedule') ? 1 : 0);
    url = setUrlParameter(url, 'e', isChecked('#show_events') ? 1 : 0);
    if(isTableView()){
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

function show_events() {
    let val = isChecked('#show_events') ? '' : 'none';
    $('#calendar .event').css("display",  val);
    $('#event_list .event').css("display", val);
}

function show_schedule() {
    let val = isChecked('#show_schedule') ? '' : 'none';
    $('#calendar .schedule').css("display", val);
    $('#event_list .schedule').css("display", val);
}

function show_worktime() {
    let val = isChecked('#show_worktime') ? '': 'none';
    $('#calendar .work').css("display", val);
    $('#event_list .work').css("display", val);
}

function show_playout() {
    let val = isChecked('#show_playout') ? '': 'none';
    $('#calendar .play').css("display", val);
    $('#event_list .play').css("display", val);
}

//get date and time from column and row to select a timeslot
function getNearestDatetime() {
    var date = "test";
    var hour = "00";
    var minute = "00";

    var xMin = 9999999;
    var yMin = 9999999;

    //get date
    $('#calendar tr#weekdays div.date').each(
        function() {
            var xpos = $(this).offset().left;
            var offset = $(this).width() / 2;
            var delta = Math.abs(mouseX - xpos - offset);
            if (delta < xMin) {
                xMin = delta;
                date = $(this).attr('date');
            }
        }
    );

    //get time
    $('#calendar div.time').each(
        function() {
            var ypos = $(this).offset().top;
            var offset = $(this).height() / 2;
            var delta = (mouseY - ypos - offset);
            var distance = Math.abs(delta);
            if (distance < yMin) {
                yMin = delta;
                hour = $(this).attr('time').substr(0, 2);
            }
        }
    );

    //add a day, if time < startOfDay
    if (parseInt(hour) < startOfDay) {
        date = addDays(date, 1);
        date = formatDate(date);
    }

    minute = 0;
    yMin = 9999999999;
    $('#calendar div.time').each(
        function() {
            var ypos = $(this).offset().top;
            var offset = $(this).height() / 2;
            var delta = (mouseY - ypos - offset);
            var distance = Math.abs(delta);
            if (distance < yMin) {
                yMin = delta;
                hour = $(this).attr('time').substr(0, 2);
                var height = $(this).height() + 14;
                var m = ((delta + height * 1.5) - 8) % height;
                m = m * 60 / height;
                minute = Math.floor(m / 15) * 15;
                minute = (minute + 60) % 60;
                if (minute < 10) minute = '0' + minute;
            }
        }
    );
    return date + " " + hour + ":" + minute + ":00";
}

var mouseX = 0;
var mouseY = 0;
var mouseMoved = false;
var mouseUpdate = false;
var mouse_update_id=null;
function showMouse() {
    if (!isTableView())return;
    //if mouse moves save position
    $("#calendar").off('mousemove').on('mousemove', (event) => {
        mouseX = event.pageX;
        mouseY = event.pageY;
        mouseMoved = true;
    });

    if (mouse_update_id !== null) {
        clearInterval(mouse_update_id);
    }

    mouse_update_id = setInterval(
        () => {
            if (!mouseMoved || mouseUpdate) return;
            mouseMoved = false;
            mouseUpdate = true;

            const text = getNearestDatetime();
            $('#position').text(text);

            mouseUpdate = false;
        }, 200
    );
}

// NEW: Add cleanup function
function stopMouseTracking() {
    if (mouse_update_id !== null) {
        clearInterval(mouse_update_id);
        mouse_update_id = null;
    }
    $("#calendar").off('mousemove');
}

function checkStudio() {
    if ($('#studio_id').val() != '-1') return 1;
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
    jQuery.getJSON(
        "series.cgi?" + new URLSearchParams({
            action: "list_series",
            json: 1,
            project_id: project_id,
            studio_id: studio_id
        }).toString()
    ).done(function(data) {
        var html = '';
        html += "<table><tr><td>" + loc['label_series'] + "</td>";
        html += '<td><select id="series_select" name="series_id">';
        for (const serie of data["series"]) {
            let id = serie["series_id"] || -1;
            let duration = serie["duration"] || 0;
            let name = serie["series_name"] || '';
            let title = serie["title"] || '';
            if (serie['has_single_events'] == '1') name = loc['single_events'];
            if (title != '') title = ' - ' + title;
            html += '<option value="' + id + '" duration="' + duration + '">' + name + title + '</option>' + "\n";
        }
        html += '</select></td></tr>';
        html += '<tr>';
        html += '    <td>' + loc["label_date"] + "</td>";
        html += '    <td><input id="series_date" name="start_date" value=""></td>';
        html += '</tr>';
        html += '<tr>';
        html += '    <td>' + loc["label_duration"] + '</td>';
        html += '    <td><input id="series_duration" value="60"></td>';
        html += '</tr>';
        html += '</table>';

        showDialog({
            title: loc['label_schedule_series'],
            content: html,
            width: "50rem",
            height: "15rem",
            buttons: {
                "Schedule": function() {
                    var series_id = $('#dialog #series_select').val();
                    var duration = $('#dialog #series_duration').val();
                    var start_date = $('#dialog #series_date').val();
                    var params = new URLSearchParams({
                      action: 'show_series',
                      project_id: project_id,
                      studio_id: studio_id,
                      series_id: series_id,
                      start: start_date,
                      duration: duration,
                      show_hint_to_add_schedule: 1
                    });
                    var url = 'series.cgi?' + params.toString() + '#tabs-schedule';                    
                    loadUrl(url);
                },
                Cancel: function() { $(this).closest('div#dialog').remove() }
            }
        });
        $('#series_date').attr('value', start_date);
        showDateTimePicker('#series_date', {
            date: parseDateTime(start_date)
        });

    }).fail(function(jqxhr, textStatus, error) {
        alert(error);
    });
}

function setDatePicker() {
    $('#selectDate').off().on('click', function() {
        console.log("click");
        let datePicker = showDatePicker('#selectDate', {
            wrap: true,
            onSelect: function(dates, inst) {
                var date = dates[0];
                var url = setUrlParameter(window.location.href, 'date', formatDate(date));
                loadCalendarTable(url);
            }
        });
        datePicker.setDate(currentDate());
        datePicker.toggle();
    });
    initTodayButton();
}

// add name=value to current url
function getUrl(name, value) {
    let url = update_urlParameters();
    if ((name == null) || (value == null)) return url;
    url = setUrlParameter(url, name, value);
    return url;
}

function updateDayStart() {
    var params = new URLSearchParams({
      project_id: getProjectId(),
      studio_id: getStudioId(),
      day_start: $('#day_start').val()
    });

    var url = 'set-user-day-start.cgi?' + params.toString();
    $.get(url);
}


function initTodayButton() {
    $('button#setToday').on('mousedown', function(event) {
        let url = update_urlParameters();
        url = removeUrlParameter(url, 'date');
        if (event.which == leftMouseButton) {
            loadCalendarTable(url);
        }
        if (event.which == middleMouseButton) {
            openNewTab(url);
        }
    })
    return true;
}

function getSwitch(id, text, active, klass) {
    if (active) active = 'checked="checked"';
    var html = '';
    html += '<div class="switch ' + klass + '">'
    html += '<label>'
    html += text
    html += '<input id="' + id + '" type="checkbox" ' + active + '>'
    html += '<span class="lever"></span>'
    html += '</label>'
    html += '</div>'
    return html;
}

function createId(prefix) {
    function s4() {
        return Math.floor((1 + Math.random()) * 0x10000)
            .toString(16)
            .substring(1);
    }
    return prefix + '_' + s4() + s4();
}

function showRmsPlot(id, project_id, studio_id, start, elem) {
    showDialog({
        width: 940,
        height: 560,
        content: elem.html(),
        buttons: {
            Close: function() { $(this).closest('div#dialog').remove(); }
        },
        onOpen: function() { $(this).scrollTop(0); }
    });
    return false;
}

function deleteFromPlayout(id, projectId, studioId, start) {
    var params = new URLSearchParams({
      action: 'delete',
      project_id: projectId,
      studio_id: studioId,
      start_date: start
    });
    var url = 'playout.cgi?' + params.toString();
    $('#' + id).load(url);
    return false;
}

function quoteAttr(attr) {
    return "'" + attr + "'";
}

function initRmsPlot() {
    $("#calendar div.play").hover(
        function() {
            var plot = $(this).attr("rms");
            var id = $(this).attr("id");
            var field = id.split('_');
            var classname = field.shift();
            var project_id = field.shift();
            var studio_id = field.shift();
            var start = $(this).attr("start")

            if (project_id == null) return;
            if (studio_id == null) return;
            if (start == null) return;

            if (!$(this).hasClass("clickHandler")) {
                $(this).addClass("clickHandler");
                $(this).click(function(event) {
                    event.stopImmediatePropagation();
                    showRmsPlot(id, project_id, studio_id, start, $(this));
                });
            }

            if ((!$(this).hasClass("rms_image")) && (plot != null)) {
                $(this).addClass("rms_image");

                var content = $(this).html();
                var id = createId("rms_img");
                var url = '/media/playout/' + plot;
                var img = '<img src="' + url + '" ></img>';
                var deleteHandler = 'onclick="deleteFromPlayout(' + quoteAttr(id) + ", " + quoteAttr(project_id) + ", " + quoteAttr(studio_id) + ", " + quoteAttr(start) + ')"';

                var details = '';
                details += '<div id="' + id + '" class="rms_detail" style="display:none">';
                details += '<div class="image">' + img + '</div>';
                details += '<div class="text">' + content + '</div>';
                if (start != null) details += '<button ' + deleteHandler + '>delete</button>';
                details += "</div>";
                $(this).prepend(img + details);
            }

            $(this).find('img').each(function() {
                $(this).show();
            });

        },
        function() {
            var plot = $(this).attr("rms");
            if (plot == null) return;
            $(this).find('img').hide();
        }
    );
}

function loadCalendarList(url) {
    document.title = "Sendungen " ;
    url = setUrlParameter(url, 'part', '1');
    url = url.replace("calendar.cgi", "calendar-content.cgi");
    updateContainer('calendarTable', url, function() {
        $('#calendarTable').removeClass("loading");
        setupCalendar();
        update_url(url);
        setColors();
    });
};

function loadCalendarTable(url, mouseButton) {
    if (isListView())throw Error("wrong mode");
    
    $('#current_date').html(formatLocalDate(currentDate()));

    
    
    // open calendar in new tab on middle mouse button
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

function getMouseOverText(elem) {
    if (elem.attr('title') != null) return elem.attr('title');
    if (elem.hasClass('event') || elem.parent().hasClass('event'))
        return 'click to edit show'
    if (elem.hasClass('schedule') || elem.parent().hasClass('schedule'))
        return 'click to create show'
    if (elem.hasClass('no_series') || elem.parent().hasClass('no_series'))
        return 'please create a series for this show'
    if (elem.hasClass('work') || elem.parent().hasClass('work'))
        return 'edit work schedule'
    if (elem.hasClass('grid') || elem.parent().hasClass('grid'))
        return 'click to create schedule'
    return '';
}

function setup_filter() {
    var html = '';
    html += getSwitch('show_events', label_events || "label", true);
    html += getSwitch('show_schedule', label_schedule || "schedule", true);
    $('#toolbar').append(html);

    if (getUrlParameter('s') == '0') unselectCheckbox('#show_schedule');
    if (getUrlParameter('e') == '0') unselectCheckbox('#show_events');
    show_schedule();
    show_events();

    $('#show_events').off();
    $('#show_events').on("click", function() {
        show_events();
        update_url();
    });
    $('#show_schedule').off();
    $('#show_schedule').on("click",
        function() {
            show_schedule();
            update_url();
        }
    );

    if(isTableView()){
        let html = '';
        html += getSwitch('show_playout', label_playout || "playout", true);
        html += getSwitch('show_worktime', label_worktime || "worktime", false);
        $('#toolbar').append(html);

        if (getUrlParameter('p') == '0') unselectCheckbox('#show_playout');
        if (getUrlParameter('w') == '0') unselectCheckbox('#show_worktime');
        show_playout();
        show_worktime();
        $('#show_playout').off();
        $('#show_playout').on("click", function() {
            show_playout();
            update_url();
        });
        $('#show_worktime').off();
        $('#show_worktime').on("click", function() {
            show_worktime();
            if (isChecked('#show_worktime')) {
                unselectCheckbox('#show_events');
                unselectCheckbox('#show_schedule');
                unselectCheckbox('#show_playout');
            } else {
                selectCheckbox('#show_events');
                selectCheckbox('#show_schedule');
                selectCheckbox('#show_playout');
            }
            show_events();
            show_schedule();
            show_playout();
            update_url();
        });
    }

}

function setup_actions() {
    //edit existing event
    var baseElement = isTableView() ? '#calendar' : '#event_list';
    $(baseElement).off();
    $(baseElement).on("mousedown", ".event", function(event) {
        handleEvent($(this).attr("id"), event);
    });

    //create series or assign to event
    $(baseElement).on("click", ".event.no_series", function() {
        handleUnassignedEvent($(this).attr("id"));
    });

    $(baseElement).on("mousedown", ".schedule", function(event) {
        handleSchedule($(this).attr("id"), $(this).attr("start"), event);
    });

    //create schedule within studio timeslots
    $(baseElement).on("click", ".grid", function() {
        handleGrid($(this).attr("id"));
    });

    // edit work schedule
    $(baseElement).on("mousedown", ".work", function(event) {
        handleWorktime($(this).attr("id"), event);
    });
}

function setup_date_select() {
    if (!isTableView()) return;
    $('#previous_month').off();
    $('#previous_month').on('mouseup', function(event) {
        var url = getUrl('date', previousDate());
        if (event.which == leftMouseButton) {
            loadCalendarTable(url);
        }
        if (event.which == middleMouseButton) {
            openNewTab(url);
        }
    });

    $('#next_month').off();
    $('#next_month').on('mouseup', function(event) {
        var url = getUrl('date', nextDate());
        if (event.which == leftMouseButton) {
            loadCalendarTable(url);
        }
        if (event.which == middleMouseButton) {
            openNewTab(url);
        }
    });

    $('#current_date').html(formatLocalDate(currentDate()));
    if (isTableView()) {
        resizeCalendarTable();

        $(window).resize(function() {
            resizeCalendarTable();
            setupMenu()
        });
    }
    
}

function setupCalendar() {
    let title = $('#project_id option:selected').text() + "/" + $('#studio_id option:selected').text() + " " + currentDate();
    setup_actions();

    if (isTableView()) {
        document.title = "Kalender " + title; 
        setup_date_select();
        showMouse();
        $('#calendar > table > tbody > tr > td > div').mouseover(function() {
            var text = getMouseOverText($(this));
            if ($(this).attr("title") == text) return;
            $(this).attr("title", text);
        });
    }

    if (isListView()) {
        document.title = "Sendungen " + title; 
        if ($('#event_list').length) {
            $('#toolbar').css({"top": "3rem",})
        }
        if ($('#event_list table').length != 0) {
            $('#event_list table').tablesorter({
                widgets: ["filter"],
                usNumberFormat: false
            });
        }
        $('#event_list table > tbody > tr').mouseover(function() {
            var text = getMouseOverText($(this));
            if ($(this).attr("title") == text) return;
            $(this).attr("title", text);
        });
        
    }

    $('#editSeries').on("click",
        function() {
            var id = $('#event_list tbody tr').first().attr('id');
            const [className, projectId, studioId, seriesId] = id.split('_');//.split('_');
            var url = 'series.cgi' + new URLSearchParams({
                project_id: projectId,
                studio_id: studioId,
                series_id: seriesId,
                action: 'show_series'
            }).toString();
            loadUrl(url);
        }
    );
    //disable context menu
    document.oncontextmenu = function() { return false; };
}

function handleEvent(id, event) {
    var field = id.split('_');
    var classname = field.shift();
    var project_id = field.shift();
    var studio_id = field.shift();
    var series_id = field.shift();
    var event_id = field.shift();

    if (project_id < 0) { alert("please select a project"); return; }
    if (studio_id < 0) { alert("please select a studio"); return; }
    if (series_id < 0) return;
    if (event_id < 0) return;
    var url = 'broadcast.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        event_id: event_id,
        action: 'edit'
    }).toString();
    if (event.which == 1) {
        loadUrl(url);
    }
    if (event.which == 2) {
        openNewTab(url);
    }
}

function handleUnassignedEvent(id) {
    var field = id.split('_');
    var classname = field.shift();
    var project_id = field.shift();
    var studio_id = field.shift();
    var series_id = field.shift();
    var event_id = field.shift();

    if (checkStudio() == 0) return;
    if (project_id < 0) return;
    if (studio_id < 0) return;
    if (event_id < 0) return;
    $('#assign_series_events input[name="event_id"]').attr('value', event_id);

    show_not_assigned_to_series_dialog();
}

function handleSchedule(id, start_date, event) {
    var field = id.split('_');
    var classname = field.shift();
    var project_id = field.shift();
    var studio_id = field.shift();
    var series_id = field.shift();

    if (checkStudio() == 0) return;
    if (project_id < 0) return;
    if (studio_id < 0) return;
    if (series_id < 0) return;

    if (event.which == 1) {
        //left click: create event from schedule
        var url = "broadcast.cgi?" + new URLSearchParams({
            action: "show_new_event_from_schedule",
            project_id: project_id,
            studio_id: studio_id,
            series_id: series_id,
            start_date: start_date
        }).toString();
        loadUrl(url);
        /*
        console.log(url);
        let response = await fetch(url, {
            //method: 'POST',
            cache: "no-store"
        });
        let json = await response.json();
        if (json.error) showError(json.error);
        else {
            var url="broadcast.cgi?" + new URLSearchParams({
                action : "edit",
                project_id : project_id,
                studio_id : studio_id,
                series_id : series_id,
                event_id : json.entry.event_id
            }).toString();
            loadUrl(url);
        }
        */
    }
    if (event.which == 3) {
        //right click: remove schedule
        var url = "series.cgi?" + new URLSearchParams({
            action: "show_series",
            project_id: project_id,
            studio_id: studio_id,
            series_id: series_id,
            start: start_date,
            exclude: 1,
            show_hint_to_add_schedule:1,
        }).toString() + '#tabs-schedule';
        loadUrl(url);
    }
}

function handleGrid(id) {
    var field = id.split('_');
    var classname = field.shift();
    var project_id = field.shift();
    var studio_id = field.shift();
    var series_id = field.shift();//to be selected

    if (project_id < 0) return;
    if (studio_id < 0) return;

    var start_date = getNearestDatetime();
    show_schedule_series_dialog(project_id, studio_id, series_id, start_date);
}

function handleWorktime(id, event) {
    var field = id.split('_');
    var classname = field.shift();
    var project_id = field.shift();
    var studio_id = field.shift();
    var schedule_id = field.shift();

    if (checkStudio() == 0) return;
    if (project_id < 0) return;
    if (studio_id < 0) return;
    if (schedule_id < 0) return;
    var start_date = $('#'+id).attr("start");

    var url = "work-time.cgi?" + new URLSearchParams({
        action: "show_new_event_from_schedule",
        project_id: project_id,
        studio_id: studio_id,
        schedule_id: schedule_id,
        start_date: start_date,
    }).toString();
    if (event.which == 1) {
        loadUrl(url);
    }
    if (event.which == 2) {
        openNewTab(url)
    }
}


function hexToRgbA(hex) {
    var c;
    if (/^#([A-Fa-f0-9]{3}){1,2}$/.test(hex)) {
        c = hex.substring(1).split('');
        if (c.length == 3) {
            c = [c[0], c[0], c[1], c[1], c[2], c[2]];
        }
        c = '0x' + c.join('');
        return 'rgba(' + [(c >> 16) & 255, (c >> 8) & 255, c & 255].join(',') + ',1)';
    }
    throw new Error('Bad Hex');
}

function setColors() {
    var elem = $('.schedule').get(0);
    if (elem == null) return;
    var col1 = window.getComputedStyle(elem).backgroundColor;
    var col2 = col1.replace('rgb', 'rgba').replace(')', ', 0.4)')
    $('.schedule').css('background', 
        `repeating-linear-gradient(to bottom, ${col1}, ${col1} 1px, ${col2} 1px, ${col2} 2px)`
    );
}

function setupScrollbar() {
    document.body.style.overflowY = 'hidden';
    var body = document.querySelector('body');
    body.addEventListener('keydown', e => {
      var el = document.querySelector('.table-scroll');
      const k = e.key;
      const h = el.clientHeight;
      const s = k === 'ArrowDown' ? 200 : k === 'ArrowUp' ? -200 : k === 'PageDown' ? h : k === 'PageUp' ? -h : 0;
      if (s) { el.scrollBy({top:s, behavior: 'smooth'}); e.preventDefault(); }
    });
    
}

$(window).on('beforeunload', function() {
    stopMouseTracking();
});

// init function
window.calcms??={};
console.log("define init_calendar")
window.calcms.init_calendar = function(el) {
    console.log("init_calendar")
    setDatePicker();
    let url = update_urlParameters();
    console.log(url)
    if (isListView()){
        loadCalendarList(url);
    } else if (isTableView()) {
        resizeCalendarTable();
        setSelectedOptions();
        $('#toolbar select#range').on('change', () => {
            let url = update_urlParameters();
            loadCalendarTable(url);
        });
        $('#toolbar select#day_start').on('change', () => {
            updateDayStart();
            let url = update_urlParameters();
            loadCalendarTable(url);
        });
        let url = update_urlParameters();
        loadCalendarTable(url);
    }
    setup_filter();
    //setupScrollbar();
}
