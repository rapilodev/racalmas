if (window.namespace_edit_series_js) throw "stop"; window.namespace_edit_series_js = true;
"use strict";

//todo: reload content only
function loadSeries(projectId, studioId, seriesId) {
    loadUrl("series.cgi?" + new URLSearchParams({
        action: "show_series",
        project_id : projectId,
        studio_id : studioId,
        series_id : seriesId,
    }).toString());
}


async function saveSeries(selector, action, ) {
    let params = formToParams(document.querySelector(selector));
    params.append("action", action);
    let json = await postJson("series.cgi", params);
    if (!json) return;
    if(json.status != 'series saved') return showError(loc.label_error);
    showInfo(loc.label_saved);
}

// set checkbox values checked depending on value
function initCheckBoxes() {
    $('div.editor input[type="checkbox"]').each(
        function() {
            if ($(this).attr('value') == '1') {
                $(this).attr('value', '1');
                $(this).attr('checked', 'checked');
            } else {
                $(this).attr('value', '0');
                $(this).attr('checked', null);
            }
        }
    );
}

// add checkbox handler to change value on click
function addCheckBoxHandler() {
    $('div.editor input[type="checkbox"]').click(
        function() {
            if ($(this).attr('value') == '1') {
                $(this).attr('value', '0');
            } else {
                $(this).attr('value', '1');
            }
        }
    );
}

// show/hide series member edit
function edit_series_members(series_id) {
    $('.edit_series_members_' + series_id).toggle();
}

// show/hide schedule fields for all schedules
function updateScheduleFields() {
    document.querySelectorAll('div.schedule').forEach(schedule => {
        const type = schedule.querySelector('select[name="period_type"]').value;
        const get = cls => schedule.querySelector(`div.cell.${cls}`);
        const cells = {
            frequency: get('frequency'),
            end: get('end'),
            weekday: get('schedule_weekday'),
            weekOfMonth: get('week_of_month'),
            month: get('schedule_month'),
            nextDay: get('nextDay')
        };
        const visible = new Set(
            type === 'days' ? [cells.frequency, cells.end] :
            type === 'week_of_month' ? [cells.end, cells.weekday, cells.weekOfMonth, cells.month, cells.nextDay] :
            []
        );
        // 'single' type leaves visible empty (everything hidden)
    
        Object.entries(cells).filter(Boolean).forEach(([key, cell]) => {
            cell.style.display = visible.has(cell) ? '' : 'none';
        });
    });
}

// preselect options in select boxes
function setSelectedOptions() {
    $('#tabs-schedule select').each(
        function() {
            var value = $(this).attr('value');
            if (value == null) return;
            if (value == '') return;
            $(this).children().each(
                function() {
                    if ($(this).attr('value') == value) {
                        $(this).attr('selected', 'selected');
                    }
                }
            );
        }
    );
}

function initSelectChangeHandler(selector, name, title) {
    $(selector).each(
        function() {
            //replace select by input, if no matching field
            var value = $(this).attr('value');

            //check if a child is selected
            var found = 0;
            $(this).children().each(function() {
                if (found == 1) return;
                if ($(this).attr('value') == value) {
                    found = 1;
                    $(this).attr('selected');
                } else {
                    $(this).removeAttr('selected');
                }
            });
            if (found == 1) {
                return;
            }

            // find option with empty value
            var loc = getLocalization();
            $(this).children().each(function() {
                if ($(this).attr('value') == '') {
                    // add selected option
                    $(this).parent().append('<option value="' + value + '" selected="1">' + value + ' Min</option>');
                    // add option to edit field
                    $(this).parent().append(
                        loc[title] + '<br>' + '<input name="' + name + '" value="' + value + '" class="' + name + '">'
                    );
                }
            });
        }
    );
}

//add handler to replace select boxes by input fields if choosen value is empty
function addSelectChangeHandler(selector, name, title) {
    $(selector).each(
        function() {
            $(this).change(function() {
                var loc = getLocalization();
                if ($(this).val() == '') {
                    //replace select by input, copy value from select to input,
                    var value = $(this).attr('value');
                    $(this).parent().html(
                        loc[title] + '<br>'
                        + '<input name="' + name + '" value="' + value + '" class="' + name + '">'
                    );
                } else {
                    $(this).attr('value', $(this).val());
                }
            });
        }
    );
}

// change create schedule button name (add/remove)
function updateScheduleButtonName() {
    var buttonChecked = $('#schedule_add input[name="exclude"]');
    var loc = getLocalization();
    if (buttonChecked.prop('checked')) {
        $('#addScheduleButton').text(loc['label_remove_schedule']);
    } else {
        $('#addScheduleButton').text(loc['label_add_schedule']);
    }
}

function checkExcerptField() {
    var elem = $('textarea[name="excerpt"]');
    if (elem.length == 0) return;
    var length = elem.val().length;
    if (length > 250) {
        $('#excerpt_too_long').show();
    } else {
        $('#excerpt_too_long').hide();
    }
}

function checkFields() {
    checkExcerptField();
    $('textarea[name="excerpt"]').on("keyup", function() {
        checkExcerptField();
    });
}

async function addUser(form) {
    let json = await postJson("series.cgi", {
        action: "add_user",
        project_id: form.find("input[name='project_id']").val(),
        studio_id: form.find("input[name='studio_id']").val(),
        series_id: form.find("input[name='series_id']").val(),
        user_id: form.find("select[name='user_id'] option").filter(':selected').val(),
    });
    if (!json) return;
    showSeries(
        form.find("input[name='project_id']").val(),
        form.find("input[name='studio_id']").val(),
        form.find("input[name='series_id']").val(),
        "#tabs-members"
    );
    showInfo("User added");
}

function commitRemoveUser(project_id, studio_id, series_id, user_id) {
    let dialog = commitAction(
        '<TMPL_VAR .loc.button_remove_member escape=js>',
        async function() {
            let json = await postJson("series.cgi", {
                action: "remove_user",
                project_id: project_id,
                studio_id: studio_id,
                series_id: series_id,
                user_id: user_id,
            });
            if (!json) return;
            showInfo("User removed");
            $('tr#edit_series_members_' + user_id).remove();
            dialog.remove();
        }
    );
}

function commitDeleteSeries(project_id, studio_id, series_id) {
    commitAction('<TMPL_VAR .loc.button_remove_series escape=js>',
        async function() {
            let json = await postJson("series.cgi", {
                action: "delete_series",
                project_id: project_id,
                studio_id: studio_id,
                series_id: series_id,
            });
            if (!json) return;
            showInfo("Series removed");
        }
    );
}

function showSeries(project_id, studio_id, series_id, tab) {
    loadUrl("series.cgi?" + new URLSearchParams({
        action: "show_series",
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
    }).toString() + tab);
}

async function saveSchedule(form) {
    var formData = new FormData(form.get(0));
    formData.append("action", "save_schedule");
    let json = await postJson("series.cgi", formData);
    if (!json) return;
    showInfo("schedule saved");
    if (json.status == "schedule added") {
        showSeries(
            form.find("input[name='project_id']").val(),
            form.find("input[name='studio_id']").val(),
            form.find("input[name='series_id']").val(),
            '#tabs-schedule'
        );
    }
}

async function deleteSchedule(form) {
    commitAction('<TMPL_VAR .loc.button_delete_schedule escape=js>',
        async function() {
            var formData = new FormData(form.get(0));
            formData.append("action", "delete_schedule");
            let json = await postJson("series.cgi", formData);
            showInfo("schedule deleted");
            if (!json) return;
            showSeries(
                form.find("input[name='project_id']").val(),
                form.find("input[name='studio_id']").val(),
                form.find("input[name='series_id']").val(),
                '#tabs-schedule'
            );
        });
}

function listEvents(project_id, studio_id, series_id) {
    loadUrl('calendar.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        list: 1,
    }).toString());
}

function showNewEvent(project_id, studio_id, series_id) {
    loadUrl('broadcast.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        action: 'show_new_event',
    }).toString());
}


function showHistory(project_id, studio_id, series_id) {
    loadUrl('event-history.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        action: 'show_new_event',
    }).toString());
}

async function rebuildEpisodes(project_id, studio_id, series_id) {
    var json = await postJson('series.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        action: 'set_rebuild_episodes',
    }).toString());
    if (!json) return;
    showInfo("episodes rebuit");
}

async function previewRebuildEpisodes(project_id, studio_id, series_id) {
    let json = await getJson('series.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        action: 'preview_rebuild_episodes',
    }).toString());
    console.log(json)
    if (!json) return;

    const doc = document.createElement("div");
    doc.classList.add("class", "card");
    doc.classList.add("class", "scrollable");
    doc.setAttribute("id", "rebuild");

    var loc = getLocalization();
    const closeButton = document.createElement("button");
    closeButton.setAttribute("class", "right")
    closeButton.textContent = loc["button_close"];
    closeButton.addEventListener("click", () => {
        $("#rebuild").remove();
        $("#tabs").show();
    });    
    doc.append(closeButton)
    
    if(json.result.total==0){
        doc.append(loc["no_action_needed"])
        showInfo(loc["no_action_needed"]);
    }

    //#if (json.result.changes > 0 && json.result.conflicts > 0) {
        const button = document.createElement("button");
        button.textContent = loc["button_commit"];
        button.addEventListener("click", async () => {
            await rebuildEpisodes(project_id, studio_id, series_id);
            $("#rebuild").remove();
            $("#tabs").show();
        });
        doc.append(button);
    //}
    const table = document.createElement("table");
    const thead = document.createElement("thead");
    const tr = document.createElement("tr");
    for (let col of json.cols) {
        const td = document.createElement("td");
        td.textContent = col;
        tr.appendChild(td)
    }
    thead.appendChild(tr)
    table.appendChild(thead)
    doc.appendChild(table)

    const tbody = document.createElement("tbody");
    table.appendChild(tbody)
    for (let row of json.rows) {
        row.start = DTF.datetime(row.start)
        if (row.recurrence=="0") row.recurrence = "-";
        console.log(row.recurrence_start)
        row.recurrence_start = row.recurrence_start ? DTF.datetime(row.recurrence_start) : '-';
        const tr = document.createElement("tr");
        tr.classList.add(row.class)
        for (let col of json.cols) {
            const td = document.createElement("td");
            td.textContent = row[col];
            tr.appendChild(td)
        }
        tbody.appendChild(tr)
    }
    $(table).tablesorter({
        widgets: ["filter"],
        usNumberFormat: false
    });

    $("#rebuild").remove();
    $("#tabs").hide();
    $("#tabs").after($(doc));
}

// init function
window.calcms??={};
window.calcms.init_edit_series = async function(el) {
    await loadLocalization();
    
    showDateTimePicker('input.datetimepicker.start');
    showDatePicker('input.datetimepicker.end');
    
    initCheckBoxes();
    addCheckBoxHandler();
    
    updateScheduleButtonName();
    updateScheduleFields();
    setSelectedOptions();
    
    //if value is not selected in a option, replace select box by input field
    initSelectChangeHandler('#tabs-schedule .frequency select', 'frequency', 'frequency_days');
    addSelectChangeHandler('#tabs-schedule .frequency select', 'frequency', 'frequency_days');
    
    initSelectChangeHandler('#tabs-schedule .duration select', 'duration', 'duration_in_minutes');
    addSelectChangeHandler('#tabs-schedule .duration select', 'duration', 'duration_in_minutes');
    
    checkFields();
    
    $('table#schedule_table').tablesorter({
        widgets: ["filter"],
        usNumberFormat: false
    });

    registerImageHandler();
}
